//
//  SecurityError.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation

public enum SecurityError: LocalizedError, Sendable {
    case handshakeTimeout
    case invalidHandshakeState
    case noSymmetricKey
    case handshakeFailed(String)
    case expiredRequest
    case invalidSignature
    case authenticationCancelled
    case notImplemented
    
    public var errorDescription: String? {
        switch self {
        case .handshakeTimeout:
            return "Key exchange handshake timed out"
        case .invalidHandshakeState:
            return "Invalid handshake state"
        case .noSymmetricKey:
            return "No symmetric key established"
        case .handshakeFailed(let reason):
            return "Handshake failed: \(reason)"
        case .expiredRequest:
            return "Connection request expired"
        case .invalidSignature:
            return "Invalid signature on connection request"
        case .authenticationCancelled:
            return "Authentication cancelled by user"
        case .notImplemented:
            return "Feature not implemented"
        }
    }
}
