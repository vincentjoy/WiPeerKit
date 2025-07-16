// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Combine

/// Main entry point for WiPeerKit framework
@MainActor
public final class WiPeerKit: Sendable {
    
    // MARK: - Public Types
    
    /// Represents a discovered peer on the network
    public struct DiscoveredPeer: Equatable, Sendable {
        public let id: String
        public let name: String
        public let host: String?
        public let port: Int?
        
        internal init(id: String, name: String, host: String? = nil, port: Int? = nil) {
            self.id = id
            self.name = name
            self.host = host
            self.port = port
        }
    }
    
    /// Connection state
    public enum ConnectionState: Sendable {
        case disconnected
        case connecting
        case connected
        case failed(Error)
    }
    
    /// Framework errors
    public enum WiPeerKitError: LocalizedError, Sendable {
        case advertisingFailed
        case browsingFailed
        case connectionFailed(String)
        case encryptionFailed
        case decryptionFailed
        case invalidMessage
        case notConnected
        
        public var errorDescription: String? {
            switch self {
            case .advertisingFailed:
                return "Failed to advertise service"
            case .browsingFailed:
                return "Failed to browse for services"
            case .connectionFailed(let message):
                return "Connection failed: \(message)"
            case .encryptionFailed:
                return "Failed to encrypt data"
            case .decryptionFailed:
                return "Failed to decrypt data"
            case .invalidMessage:
                return "Received invalid message format"
            case .notConnected:
                return "Not connected to any peer"
            }
        }
    }
}
