//
//  SecureHandshakeActor.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation
import CryptoKit

/// Handles secure key exchange during connection establishment
actor SecureHandshakeActor {
    
    // MARK: - Types
    
    enum HandshakeState {
        case idle
        case waitingForPublicKey
        case completed(symmetricKey: SymmetricKey)
        case failed(Error)
    }
    
    struct HandshakeMessage: Codable {
        enum MessageType: String, Codable {
            case publicKey
            case acknowledgment
        }
        
        let type: MessageType
        let publicKey: Data?
        let timestamp: Date
        let deviceId: String
    }
    
    // MARK: - Properties
    
    private var state: HandshakeState = .idle
    private let keyExchange = DiffieHellmanKeyExchange()
    private var localKeyPair: (publicKey: Data, privateKey: Data)?
    private let deviceId = UUID().uuidString
    
    // MARK: - Public Methods
    
    /// Initiates key exchange as the connection initiator
    func initiateKeyExchange() async throws -> Data {
        // Generate local key pair
        let keyPair = try keyExchange.generateKeyPair()
        localKeyPair = keyPair
        state = .waitingForPublicKey
        
        // Create handshake message
        let message = HandshakeMessage(
            type: .publicKey,
            publicKey: keyPair.publicKey,
            timestamp: Date(),
            deviceId: deviceId
        )
        
        return try JSONEncoder().encode(message)
    }
    
    /// Responds to a key exchange request
    func respondToKeyExchange(_ data: Data) async throws -> (response: Data, symmetricKey: SymmetricKey) {
        let message = try JSONDecoder().decode(HandshakeMessage.self, from: data)
        
        guard message.type == .publicKey,
              let remotePublicKey = message.publicKey else {
            throw WiPeerKit.WiPeerKitError.invalidMessage
        }
        
        // Verify timestamp (prevent replay attacks)
        let timeDifference = abs(message.timestamp.timeIntervalSinceNow)
        guard timeDifference < 30 else { // 30 second window
            throw SecurityError.handshakeTimeout
        }
        
        // Generate local key pair
        let keyPair = try keyExchange.generateKeyPair()
        localKeyPair = keyPair
        
        // Derive shared secret
        let sharedSecret = try keyExchange.deriveSharedSecret(
            publicKey: remotePublicKey,
            privateKey: keyPair.privateKey
        )
        
        // Create symmetric key
        let symmetricKey = SymmetricKey(data: sharedSecret)
        state = .completed(symmetricKey: symmetricKey)
        
        // Create response
        let response = HandshakeMessage(
            type: .publicKey,
            publicKey: keyPair.publicKey,
            timestamp: Date(),
            deviceId: deviceId
        )
        
        return (try JSONEncoder().encode(response), symmetricKey)
    }
    
    /// Completes key exchange as the initiator
    func completeKeyExchange(_ data: Data) async throws -> SymmetricKey {
        guard case .waitingForPublicKey = state,
              let localKeyPair = localKeyPair else {
            throw SecurityError.invalidHandshakeState
        }
        
        let message = try JSONDecoder().decode(HandshakeMessage.self, from: data)
        
        guard message.type == .publicKey,
              let remotePublicKey = message.publicKey else {
            throw WiPeerKit.WiPeerKitError.invalidMessage
        }
        
        // Derive shared secret
        let sharedSecret = try keyExchange.deriveSharedSecret(
            publicKey: remotePublicKey,
            privateKey: localKeyPair.privateKey
        )
        
        // Create symmetric key
        let symmetricKey = SymmetricKey(data: sharedSecret)
        state = .completed(symmetricKey: symmetricKey)
        
        return symmetricKey
    }
    
    /// Gets the current symmetric key if handshake is complete
    func getSymmetricKey() -> SymmetricKey? {
        if case .completed(let key) = state {
            return key
        }
        return nil
    }
}
