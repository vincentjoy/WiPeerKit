//
//  EncryptionActor.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 16/07/25.
//

import Foundation
import CryptoKit

/// AES-GCM encryption implementation
actor EncryptionActor: EncryptionProtocol {
    
    // MARK: - Properties
    
    private var symmetricKey: SymmetricKey
    
    // MARK: - Constants
    
    private let nonceSize = 12 // 96 bits for AES-GCM
    private let tagSize = 16   // 128 bits
    
    // MARK: - Initialization
    
    init() {
        // Default hardcoded key for demo purposes
        // In production, this should be properly negotiated
        let keyData = Data(repeating: 0x42, count: 32) // 256-bit key
        self.symmetricKey = SymmetricKey(data: keyData)
    }
    
    init(key: Data) throws {
        guard key.count == 32 else {
            throw EncryptionError.invalidKeySize
        }
        self.symmetricKey = SymmetricKey(data: key)
    }
    
    // MARK: - EncryptionProtocol Methods
    
    func encrypt(_ data: Data) throws -> Data {
        // Generate random nonce
        let nonce = AES.GCM.Nonce()
        
        // Encrypt the data
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce)
        
        // Combine nonce + ciphertext + tag
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return combined
    }
    
    func decrypt(_ data: Data) throws -> Data {
        // Extract components from combined data
        guard data.count > nonceSize + tagSize else {
            throw EncryptionError.invalidCiphertext
        }
        
        // Create sealed box from combined data
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        
        // Decrypt
        let plaintext = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        return plaintext
    }
    
    func setKey(_ key: Data) throws {
        guard key.count == 32 else {
            throw EncryptionError.invalidKeySize
        }
        self.symmetricKey = SymmetricKey(data: key)
    }
}
