//
//  KeyExchangeProtocol.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation

/// Protocol for key exchange mechanisms
protocol KeyExchangeProtocol: Sendable {
    func generateKeyPair() throws -> (publicKey: Data, privateKey: Data)
    func deriveSharedSecret(publicKey: Data, privateKey: Data) throws -> Data
}
