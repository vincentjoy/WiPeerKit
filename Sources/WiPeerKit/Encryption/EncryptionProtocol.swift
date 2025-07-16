//
//  EncryptionProtocol.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 16/07/25.
//

import Foundation

/// Protocol for encryption functionality
protocol EncryptionProtocol: Actor {
    func encrypt(_ data: Data) async throws -> Data
    func decrypt(_ data: Data) async throws -> Data
    func setKey(_ key: Data) async throws
}
