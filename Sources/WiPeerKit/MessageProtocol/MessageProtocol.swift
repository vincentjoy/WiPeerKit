//
//  MessageProtocol.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 16/07/25.
//

import Foundation

/// Handles message framing and buffering for reliable message delivery
actor MessageProtocolActor {
    
    // MARK: - Properties
    
    private var receiveBuffer = Data()
    private let headerSize = 4 // 32-bit length prefix
    
    // MARK: - Message Framing
    
    /// Frame a message with length prefix
    /// - Parameter data: The data to frame
    /// - Returns: Framed message ready for transmission
    func frameMessage(_ data: Data) -> Data {
        var framedMessage = Data()
        
        // Add 4-byte length prefix (big-endian)
        var length = UInt32(data.count).bigEndian
        framedMessage.append(Data(bytes: &length, count: MemoryLayout<UInt32>.size))
        
        // Add the actual data
        framedMessage.append(data)
        
        return framedMessage
    }
    
    /// Process incoming data and extract complete messages
    /// - Parameters:
    ///   - data: Incoming data chunk
    ///   - completion: Called for each complete message found
    func processIncomingData(_ data: Data, completion: @Sendable (Data) async -> Void) async {
        // Append new data to buffer
        receiveBuffer.append(data)
        
        // Process all complete messages in buffer
        while let message = extractNextMessage() {
            await completion(message)
        }
    }
    
    /// Reset the receive buffer
    func reset() {
        receiveBuffer.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Extract the next complete message from the buffer
    /// - Returns: Complete message data, or nil if no complete message available
    private func extractNextMessage() -> Data? {
        
        // Need at least header size
        guard receiveBuffer.count >= headerSize else {
            return nil
        }
        
        // Convert first 4 bytes to array for safety
        let headerBytes = [UInt8](receiveBuffer.prefix(4))
        let length = UInt32(headerBytes[0]) << 24 |
        UInt32(headerBytes[1]) << 16 |
        UInt32(headerBytes[2]) << 8 |
        UInt32(headerBytes[3])
        
        // Validate length
        guard length > 0 && length <= 1_048_576 else {
            receiveBuffer.removeAll()
            return nil
        }
        
        let totalMessageSize = headerSize + Int(length)
        
        // Check if we have the complete message
        guard receiveBuffer.count >= totalMessageSize else {
            return nil
        }
        
        // Extract message data (skip header)
        let messageBytes = [UInt8](receiveBuffer.dropFirst(headerSize).prefix(Int(length)))
        let messageData = Data(messageBytes)
        
        // Remove processed data from buffer
        receiveBuffer.removeFirst(totalMessageSize)
        
        return messageData
    }
}
