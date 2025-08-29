//
//  Message.swift
//  WiPeerKitDemo
//
//  Created by Vincent Joy on 29/08/25.
//

import Foundation

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isOutgoing: Bool
    let timestamp = Date()
    var isSystemMessage = false
}

enum DiscoveryMode {
    case advertise
    case browse
    case off
}

enum AuthMode {
    case pin
    case manual
    case trusted
}
