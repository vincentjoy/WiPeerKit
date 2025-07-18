//
//  EncryptionError.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 16/07/25.
//

// MARK: - Encryption Errors

import Foundation

enum EncryptionError: LocalizedError, Sendable {
    case invalidKeySize
    case encryptionFailed
    case decryptionFailed
    case invalidCiphertext
    
    var errorDescription: String? {
        switch self {
        case .invalidKeySize:
            return "Invalid key size. Expected 256-bit (32 bytes) key."
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidCiphertext:
            return "Invalid ciphertext format"
        }
    }
}
