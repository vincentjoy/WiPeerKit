//
//  SecureIntegrationTests.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 24/07/25.
//

@preconcurrency import XCTest
@preconcurrency import CryptoKit
@testable import WiPeerKit

// MARK: - Integration Tests with Security

final class SecureIntegrationTests: XCTestCase {
    
    func testEndToEndSecureConnection() async throws {
        // Given
        let alice = await TestSecureServer()
        let bob = await TestSecureClient()
        
        // Start server with PIN authentication
        try await alice.startWithPIN("123456")
        
        // Bob connects with correct PIN
        await bob.setPin("123456")
        try await bob.connectSecurely(host: "localhost", port: 8890)
        
        // Send encrypted message
        let testMessage = "Secret message with authentication!"
        try await bob.send(message: testMessage)
        
        // Verify message received
        let expectation = expectation(description: "Message received")
        
        await alice.setMessageHandler { message in
            XCTAssertEqual(message, testMessage)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testConnectionRejectionWithWrongPIN() async throws {
        // Given
        let server = await TestSecureServer()
        let client = await TestSecureClient()
        
        try await server.startWithPIN("123456")
        
        // When - Try with wrong PIN
        await client.setPin("654321")
        
        // Then
        do {
            try await client.connectSecurely(host: "localhost", port: 8890)
            XCTFail("Should fail with wrong PIN")
        } catch {
            // Expected
        }
    }
    
    func testTrustedDeviceReconnection() async throws {
        // Given - First connection with PIN
        let server = await TestSecureServer()
        let client = await TestSecureClient()
        
        try await server.startWithPIN("123456")
        await client.setPin("123456")
        
        // First connection
        try await client.connectSecurely(host: "localhost", port: 8890)
        
        // Save as trusted
        await server.trustCurrentDevice()
        
        // Disconnect
        await client.disconnect()
        
        // When - Reconnect without PIN
        await client.setPin(nil)
        try await client.connectSecurely(host: "localhost", port: 8890)
        
        // Then - Should connect without PIN
        if await client.isConnected() {} else {
            XCTFail("Should fail with not connected")
        }
    }
}
