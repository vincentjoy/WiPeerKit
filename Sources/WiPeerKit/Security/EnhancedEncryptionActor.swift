//
//  EnhancedEncryptionActor.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation
import CryptoKit

actor EnhancedEncryptionActor: EncryptionProtocol {
    
    private var symmetricKey: SymmetricKey?
    private let handshake = SecureHandshakeActor()
    
    // MARK: - Key Exchange Methods
    
    func initiateKeyExchange() async throws -> Data {
        try await handshake.initiateKeyExchange()
    }
    
    func handleKeyExchangeResponse(_ data: Data) async throws {
        let key = try await handshake.completeKeyExchange(data)
        self.symmetricKey = key
    }
    
    func respondToKeyExchange(_ data: Data) async throws -> Data {
        let (response, key) = try await handshake.respondToKeyExchange(data)
        self.symmetricKey = key
        return response
    }
    
    // MARK: - Encryption/Decryption
    
    func encrypt(_ data: Data) throws -> Data {
        guard let symmetricKey = symmetricKey else {
            throw SecurityError.noSymmetricKey
        }
        
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce)
        
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return combined
    }
    
    func decrypt(_ data: Data) throws -> Data {
        guard let symmetricKey = symmetricKey else {
            throw SecurityError.noSymmetricKey
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let plaintext = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        return plaintext
    }
    
    func setKey(_ key: Data) throws {
        self.symmetricKey = SymmetricKey(data: key)
    }
    
    func hasEstablishedKey() -> Bool {
        symmetricKey != nil
    }
}
