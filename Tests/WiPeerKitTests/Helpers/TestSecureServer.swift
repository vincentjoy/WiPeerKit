//
//  TestSecureServer.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

@preconcurrency import XCTest
@testable import WiPeerKit

actor TestSecureServer {
    private let tcpTransport = TCPTransportActor()
    private let encryption = EnhancedEncryptionActor()
    private let messageProtocol = MessageProtocolActor()
    private let connectionManager: SecureConnectionManager
    
    private var onMessageReceived: (@Sendable (String) async -> Void)?
    private var currentDeviceIdentity: SecureConnectionManager.DeviceIdentity?
    
    init() async {
        connectionManager = try! SecureConnectionManager(authMethod: .manualApproval)
        
        await tcpTransport.setDataHandler { [weak self] data in
            await self?.handleReceivedData(data)
        }
        
        // Auto-approve for testing
        await connectionManager.setOnConnectionRequest { [weak self] device in
            await self?.setCurrentDeviceIdentity(device)
            return true // Auto-approve for tests
        }
    }
    
    func startWithPIN(_ pin: String) async throws {
        // Reinitialize with PIN auth
        let pinManager = try SecureConnectionManager(authMethod: .pin(pin))
        // Copy callbacks
        let existingCallback = await connectionManager.getOnConnectionRequest()
        await pinManager.setOnConnectionRequest(existingCallback)
        
        try await tcpTransport.startListening(on: 8890)
    }
    
    func trustCurrentDevice() async {
        // In real implementation, would save to trusted devices
    }
    
    func setMessageHandler(_ handler: @escaping @Sendable (String) async -> Void) {
        onMessageReceived = handler
    }
    
    private func setCurrentDeviceIdentity(_ device: SecureConnectionManager.DeviceIdentity) {
        currentDeviceIdentity = device
    }
    
    private func handleReceivedData(_ data: Data) async {
        // Handle handshake or encrypted messages
        // ... implementation
    }
}
