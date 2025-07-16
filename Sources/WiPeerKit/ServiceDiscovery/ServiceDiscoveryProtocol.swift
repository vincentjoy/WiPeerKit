//
//  ServiceDiscoveryProtocol.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 16/07/25.
//

import Foundation
import Combine

protocol ServiceDiscoveryProtocol: Actor {
    var discoveredPeers: [WiPeerKit.DiscoveredPeer] { get async }
    var discoveredPeersPublisher: AnyPublisher<[WiPeerKit.DiscoveredPeer], Never> { get }
    func startAdvertising(serviceName: String?) async
    func stopAdvertising() async
    func startBrowsing() async
    func stopBrowsing() async
}
