//
//  WiPeerKit+SecureHandShake+Client.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation

// MARK: - Server-Side Handshake Handling

extension WiPeerKit {
    
    /// Handle incoming connections with key exchange
    func handleIncomingHandshake(_ data: Data) async throws {
        guard let enhancedEncryption = encryption as? EnhancedEncryptionActor else {
            return
        }
        
        // Server responds to handshake
        let response = try await enhancedEncryption.respondToKeyExchange(data)
        let framedResponse = await messageProtocol.frameMessage(response)
        
        // Send response back
        try await tcpTransport.send(data: framedResponse)
        
        // Connection is now secure
        print("✅ Incoming connection secured with ephemeral keys")
    }
}

// MARK: - Message Type Detection

extension WiPeerKit {
    
    enum InternalMessageType {
        case handshake
        case userData
        
        static func detect(from data: Data) -> InternalMessageType {
            // Simple detection: check if it's valid JSON with HandshakeMessage structure
            if let _ = try? JSONDecoder().decode(SecureHandshakeActor.HandshakeMessage.self, from: data) {
                return .handshake
            }
            return .userData
        }
    }
    
    /// Enhanced message handling with handshake support
    private func handleReceivedDataWithHandshake(_ data: Data) async {
        await messageProtocol.processIncomingData(data) { [weak self] completeMessage in
            guard let self = self else { return }
            
            // Detect message type
            switch InternalMessageType.detect(from: completeMessage) {
            case .handshake:
                // Handle key exchange
                do {
                    try await self.handleIncomingHandshake(completeMessage)
                } catch {
                    print("Handshake error: \(error)")
                }
                
            case .userData:
                // Normal message - decrypt and deliver
                do {
                    let decryptedData = try await self.encryption.decrypt(completeMessage)
                    await self.onDataReceived?(decryptedData)
                } catch {
                    print("Decryption error: \(error)")
                }
            }
        }
    }
}
