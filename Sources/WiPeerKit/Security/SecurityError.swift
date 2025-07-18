//
//  SecurityError.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation

enum SecurityError: LocalizedError, Sendable {
    case handshakeTimeout
    case invalidHandshakeState
    case noSymmetricKey
    case handshakeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .handshakeTimeout:
            return "Key exchange handshake timed out"
        case .invalidHandshakeState:
            return "Invalid handshake state"
        case .noSymmetricKey:
            return "No symmetric key established"
        case .handshakeFailed(let reason):
            return "Handshake failed: \(reason)"
        }
    }
}
