//
//  TestSecureClient.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

@preconcurrency import XCTest
@testable import WiPeerKit

actor TestSecureClient {
    private let tcpTransport = TCPTransportActor()
    private let encryption = EnhancedEncryptionActor()
    private let messageProtocol = MessageProtocolActor()
    private let connectionManager: SecureConnectionManager
    
    var pin: String?
    
    init() async {
        connectionManager = try! SecureConnectionManager(authMethod: .manualApproval)
        
        
        await connectionManager.setPinRequest { [weak self] in
            return await self?.pin
        }
    }
    
    func connectSecurely(host: String, port: Int) async throws {
        try await tcpTransport.connect(host: host, port: port)
        
        // Perform handshake
        let handshakeData = try await encryption.initiateKeyExchange()
        let framedHandshake = await messageProtocol.frameMessage(handshakeData)
        try await tcpTransport.send(data: framedHandshake)
        
        // Wait for response and complete handshake
        // ... implementation
    }
    
    func send(message: String) async throws {
        guard let data = message.data(using: .utf8) else { return }
        
        let encryptedData = try await encryption.encrypt(data)
        let framedMessage = await messageProtocol.frameMessage(encryptedData)
        
        try await tcpTransport.send(data: framedMessage)
    }
    
    func disconnect() async {
        await tcpTransport.disconnect()
    }
    
    func isConnected() async -> Bool {
        if case TCPConnectionState.connected = await tcpTransport.connectionState {
            return true
        }
        return false
    }
}
