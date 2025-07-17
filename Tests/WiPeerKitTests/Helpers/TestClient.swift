//
//  TestClient.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 17/07/25.
//

@preconcurrency import XCTest
@testable import WiPeerKit

actor TestClient {
    private let tcpTransport = TCPTransportActor()
    private let encryption = EncryptionActor()
    private let messageProtocol = MessageProtocolActor()
    
    private var onMessageReceived: (@Sendable (String) async -> Void)?
    
    init() async {
        await tcpTransport.setDataHandler { [weak self] data in
            await self?.handleReceivedData(data)
        }
    }
    
    func setMessageHandler(_ handler: @escaping @Sendable (String) async -> Void) {
        onMessageReceived = handler
    }
    
    func connect(host: String, port: Int) async throws {
        try await tcpTransport.connect(host: host, port: port)
    }
    
    func disconnect() async {
        await tcpTransport.disconnect()
    }
    
    func send(message: String) async throws {
        guard let data = message.data(using: .utf8) else { return }
        
        let encryptedData = try await encryption.encrypt(data)
        let framedMessage = await messageProtocol.frameMessage(encryptedData)
        
        try await tcpTransport.send(data: framedMessage)
    }
    
    private func handleReceivedData(_ data: Data) async {
        await messageProtocol.processIncomingData(data) { [weak self] completeMessage in
            guard let self = self else { return }
            
            do {
                let decryptedData = try await self.encryption.decrypt(completeMessage)
                if let message = String(data: decryptedData, encoding: .utf8) {
                    await self.onMessageReceived?(message)
                }
            } catch {
                print("Client decryption error: \(error)")
            }
        }
    }
}
