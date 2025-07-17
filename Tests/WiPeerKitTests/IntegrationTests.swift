//
//  IntegrationTests.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 17/07/25.
//

@preconcurrency import XCTest
@preconcurrency import Network
@testable import WiPeerKit

final class IntegrationTests: XCTestCase, @unchecked Sendable {
    
    var server: TestServer!
    var client: TestClient!
    
    override func setUp() async throws {
        try await super.setUp()
        
        server = await TestServer()
        client = await TestClient()
        
        // Start server
        try await server.start()
    }
    
    override func tearDown() async throws {
        await server?.stop()
        await client?.disconnect()
        
        server = nil
        client = nil
        
        try await super.tearDown()
    }
    
    func testEndToEndCommunication() async throws {
        let messageExpectation = expectation(description: "Message received")
        let testMessage = "Hello from WiPeerKit integration test!"
        
        // Setup server message handler
        await server.setMessageHandler { message in
            XCTAssertEqual(message, testMessage)
            messageExpectation.fulfill()
        }
        
        // Connect client to server
        try await client.connect(host: "localhost", port: 8889)
        
        // Send message
        try await client.send(message: testMessage)
        
        // Wait for message to be received
        await fulfillment(of: [messageExpectation], timeout: 5.0)
    }
    
    func testBidirectionalCommunication() async throws {
        let clientExpectation = expectation(description: "Client received response")
        let serverExpectation = expectation(description: "Server received message")
        
        let clientMessage = "Hello Server!"
        let serverResponse = "Hello Client!"
        
        // Setup handlers
        await server.setMessageHandler { message in
            XCTAssertEqual(message, clientMessage)
            serverExpectation.fulfill()
            
            // Send response
            Task { @MainActor in
                try await self.server.send(message: serverResponse)
            }
        }
        
        await client.setMessageHandler { message in
            XCTAssertEqual(message, serverResponse)
            clientExpectation.fulfill()
        }
        
        // Connect and communicate
        try await client.connect(host: "localhost", port: 8889)
        try await client.send(message: clientMessage)
        
        // Wait for bidirectional communication
        await fulfillment(of: [clientExpectation, serverExpectation], timeout: 5.0)
    }
    
    func testMultipleMessages() async throws {
        let messages = ["Message 1", "Message 2", "Message 3", "Message 4", "Message 5"]
        var receivedMessages: [String] = []
        let allMessagesExpectation = expectation(description: "All messages received")
        
        await server.setMessageHandler { @MainActor message in
            receivedMessages.append(message)
            
            if receivedMessages.count == messages.count {
                allMessagesExpectation.fulfill()
            }
        }
        
        // Connect and send all messages
        try await client.connect(host: "localhost", port: 8889)
        
        for message in messages {
            try await client.send(message: message)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
        }
        
        // Verify all messages received
        await fulfillment(of: [allMessagesExpectation], timeout: 5.0)
        XCTAssertEqual(Set(receivedMessages), Set(messages))
    }
}
