//
//  WiPeerKit+SecureAuth.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation

extension WiPeerKit {
    
    /// Connect to a peer with secure authentication and key exchange
    /// - Parameters:
    ///   - peer: The discovered peer to connect to
    ///   - connectionManager: The security manager handling authentication
    /// - Throws: Connection or authentication errors
    public func secureConnectWithAuth(
        to peer: DiscoveredPeer,
        using connectionManager: SecureConnectionManager
    ) async throws {
        // 1. Establish TCP connection
        try await connect(to: peer)
        
        // 2. Create and send connection request
        let approval = try await connectionManager.initiateSecureConnection(to: peer)
        let requestData = try JSONEncoder().encode(approval.request)
        
        // 3. Send authentication request
        try await send(data: requestData)
        
        // 4. Wait for response
        // In production, this would wait for the handshake response
        // and complete the key exchange
        
        // 5. If approved, use session key for encryption
        if let sessionKey = approval.sessionKey {
            try await (encryption as? EnhancedEncryptionActor)?.setKey(
                sessionKey.withUnsafeBytes { Data($0) }
            )
        }
    }
    
    /// Handle incoming secure connection requests
    /// This should be called when receiving handshake messages
    internal func handleIncomingHandshake(
        _ data: Data,
        using connectionManager: SecureConnectionManager
    ) async throws {
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
