//
//  SecureSession.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation
import CryptoKit

internal struct SecureSession: Sendable {
    let peerIdentity: SecureConnectionManager.DeviceIdentity
    let sessionKey: SymmetricKey
    let establishedAt: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(establishedAt) > 3600 // 1 hour
    }
}
