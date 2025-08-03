//
//  SecureConnectionManagerTests.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 24/07/25.
//

@preconcurrency import XCTest
@preconcurrency import CryptoKit
@testable import WiPeerKit

// MARK: - Secure Connection Manager Tests

@MainActor
final class SecureConnectionManagerTests: XCTestCase {
    
    var connectionManager: SecureConnectionManager!
    
    override func setUp() async throws {
        try await super.setUp()
        connectionManager = try SecureConnectionManager(authMethod: .pin("123456"))
    }
    
    override func tearDown() async throws {
        connectionManager = nil
        try await super.tearDown()
    }
    
    func testConnectionRequestCreation() async throws {
        // Given
        let peer = WiPeerKit.DiscoveredPeer(
            id: "test-peer",
            name: "Test Device",
            host: "192.168.1.100",
            port: 8888
        )
        
        // When
        let approval = try await connectionManager.initiateSecureConnection(to: peer)
        
        // Then
        XCTAssertNotNil(approval.request)
        XCTAssertEqual(approval.request.identity.name, UIDevice.current.name)
        XCTAssertNotNil(approval.request.signature)
        XCTAssertFalse(approval.isApproved) // Not approved yet
    }
    
    func testPINAuthentication() async throws {
        // Given - Create connection with PIN auth
        let pinManager = try SecureConnectionManager(authMethod: .pin("425817"))
        
        // Setup PIN callback
        pinManager.onPinRequested = {
            return "425817" // Correct PIN
        }
        
        // When - Create connection request
        let peer = WiPeerKit.DiscoveredPeer(id: "test", name: "Test", host: "localhost", port: 8888)
        let approval = try await pinManager.initiateSecureConnection(to: peer)
        
        // Then
        XCTAssertNotNil(approval.request.authProof)
        XCTAssertEqual(approval.request.authProof?.type, .pin)
        
        // Verify PIN hash
        let pinHash = SHA256.hash(data: "425817".data(using: .utf8)!)
        XCTAssertEqual(approval.request.authProof?.data, Data(pinHash))
    }
    
    func testConnectionRequestValidation() async throws {
        // Given - Create a valid request
        let peer = WiPeerKit.DiscoveredPeer(id: "test", name: "Test", host: "localhost", port: 8888)
        let approval = try await connectionManager.initiateSecureConnection(to: peer)
        let requestData = try JSONEncoder().encode(approval.request)
        
        // Setup approval callback
        connectionManager.onConnectionRequest = { device in
            return true // Approve
        }
        
        // When - Validate the request
        let validationResult = try await connectionManager.validateConnectionRequest(requestData)
        
        // Then
        XCTAssertTrue(validationResult.isApproved)
        XCTAssertNotNil(validationResult.sessionKey)
    }
    
    func testExpiredRequestRejection() async throws {
        // Given - Create request with old timestamp
        var request = SecureConnectionManager.ConnectionRequest(
            identity: SecureConnectionManager.DeviceIdentity(
                id: UUID(),
                publicKey: Data(),
                name: "Test",
                modelIdentifier: "Test",
                certificateHash: nil
            ),
            timestamp: Date(timeIntervalSinceNow: -60), // 1 minute ago
            nonce: Data((0..<32).map { _ in UInt8.random(in: 0...255) }),
            signature: Data(),
            authProof: nil
        )
        
        // When/Then
        do {
            let requestData = try JSONEncoder().encode(request)
            _ = try await connectionManager.validateConnectionRequest(requestData)
            XCTFail("Should throw expired request error")
        } catch SecurityError.expiredRequest {
            // Expected
        }
    }
    
    func testTrustedDeviceAuthentication() async throws {
        // Given
        let trustedDevices = [
            SecureConnectionManager.DeviceIdentity(
                id: UUID(),
                publicKey: Data(repeating: 1, count: 64),
                name: "Trusted Device",
                modelIdentifier: "iPhone14,2",
                certificateHash: nil
            )
        ]
        
        let trustedManager = try SecureConnectionManager(
            authMethod: .trustedDevices(trustedDevices)
        )
        
        // When - Try to connect with trusted device
        // Implementation would check if device is in trusted list
        
        // Then
        // Verify trusted device is automatically approved
    }
}
