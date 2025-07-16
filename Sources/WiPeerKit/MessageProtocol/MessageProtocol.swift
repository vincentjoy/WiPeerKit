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
        
        // Read length prefix
        let lengthData = receiveBuffer.prefix(headerSize)
        let length = lengthData.withUnsafeBytes { bytes in
            bytes.load(as: UInt32.self).bigEndian
        }
        
        // Validate length
        guard length > 0 && length <= 1_048_576 else { // Max 1MB per message
            // Invalid message, clear buffer
            receiveBuffer.removeAll()
            return nil
        }
        
        let totalMessageSize = headerSize + Int(length)
        
        // Check if we have the complete message
        guard receiveBuffer.count >= totalMessageSize else {
            return nil
        }
        
        // Extract message
        let messageData = receiveBuffer.subdata(in: headerSize..<totalMessageSize)
        
        // Remove processed data from buffer
        receiveBuffer.removeFirst(totalMessageSize)
        
        return messageData
    }
}
