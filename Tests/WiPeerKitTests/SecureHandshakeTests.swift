//
//  SecureHandshakeTests.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 24/07/25.
//

@preconcurrency import XCTest
@preconcurrency import CryptoKit
@testable import WiPeerKit

// MARK: - Secure Handshake Tests

final class SecureHandshakeTests: XCTestCase {
    
    func testHandshakeMessageSerialization() throws {
        // Given
        let message = SecureHandshakeActor.HandshakeMessage(
            type: .publicKey,
            publicKey: Data(repeating: 42, count: 64),
            timestamp: Date(),
            deviceId: "test-device"
        )
        
        // When
        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(
            SecureHandshakeActor.HandshakeMessage.self,
            from: encoded
        )
        
        // Then
        XCTAssertEqual(decoded.type, message.type)
        XCTAssertEqual(decoded.publicKey, message.publicKey)
        XCTAssertEqual(decoded.deviceId, message.deviceId)
    }
    
    func testCompleteHandshakeFlow() async throws {
        // Given
        let alice = SecureHandshakeActor()
        let bob = SecureHandshakeActor()
        
        // When - Alice initiates
        let aliceInit = try await alice.initiateKeyExchange()
        
        // Bob responds
        let (bobResponse, bobKey) = try await bob.respondToKeyExchange(aliceInit)
        
        // Alice completes
        let aliceKey = try await alice.completeKeyExchange(bobResponse)
        
        // Then - Both have the same key
        XCTAssertEqual(
            aliceKey.withUnsafeBytes { Data($0) },
            bobKey.withUnsafeBytes { Data($0) }
        )
    }
    
    func testHandshakeTimeout() async throws {
        // Given
        let handshake = SecureHandshakeActor()
        
        // Create message with old timestamp
        let oldMessage = SecureHandshakeActor.HandshakeMessage(
            type: .publicKey,
            publicKey: Data(repeating: 1, count: 64),
            timestamp: Date(timeIntervalSinceNow: -60), // 1 minute old
            deviceId: "old-device"
        )
        
        let messageData = try JSONEncoder().encode(oldMessage)
        
        // When/Then
        do {
            _ = try await handshake.respondToKeyExchange(messageData)
            XCTFail("Should throw timeout error")
        } catch SecurityError.handshakeTimeout {
            // Expected
        }
    }
}
