//
//  ConnectionApproval.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation
import CryptoKit

public struct ConnectionApproval: Sendable {
    public let request: SecureConnectionManager.ConnectionRequest
    public let isApproved: Bool
    public let sessionKey: SymmetricKey?
}
