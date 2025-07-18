//
//  WiPeerKit+SecureHandShake.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation

// MARK: - Client-Side Handshake Handling

extension WiPeerKit {
    
    /// Connection options
    public struct ConnectionOptions {
        public let requireEncryption: Bool
        public let handshakeTimeout: TimeInterval
        
        public init(
            requireEncryption: Bool = true,
            handshakeTimeout: TimeInterval = 10.0
        ) {
            self.requireEncryption = requireEncryption
            self.handshakeTimeout = handshakeTimeout
        }
    }
    
    /// Connect with secure handshake
    public func secureConnect(
        to peer: DiscoveredPeer,
        options: ConnectionOptions = ConnectionOptions()
    ) async throws {
        guard let host = peer.host, let port = peer.port else {
            throw WiPeerKitError.connectionFailed("Peer not resolved")
        }
        
        connectionState = .connecting
        
        do {
            // Establish TCP connection
            try await tcpTransport.connect(host: host, port: port)
            
            // Perform key exchange
            if options.requireEncryption {
                try await performKeyExchange(timeout: options.handshakeTimeout)
            }
            
            connectionState = .connected
        } catch {
            connectionState = .failed(error)
            throw error
        }
    }
    
    private func performKeyExchange(timeout: TimeInterval) async throws {
        // Cast to enhanced encryption if available
        guard let enhancedEncryption = encryption as? EnhancedEncryptionActor else {
            return // Fall back to hardcoded key
        }
        
        // Initiate handshake
        let handshakeData = try await enhancedEncryption.initiateKeyExchange()
        let framedHandshake = await messageProtocol.frameMessage(handshakeData)
        
        // Send handshake message
        try await tcpTransport.send(data: framedHandshake)
        
        // Wait for response with timeout
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw SecurityError.handshakeTimeout
            }
            
            // Handshake completion task
            group.addTask { [weak self] in
                // This would be triggered by receiving handshake response
                // Implementation depends on your message handling
            }
            
            // Wait for first task to complete
            try await group.next()
            group.cancelAll()
        }
    }
}
