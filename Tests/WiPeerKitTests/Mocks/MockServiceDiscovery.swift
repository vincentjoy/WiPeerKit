//
//  MockServiceDiscovery.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 17/07/25.
//

@preconcurrency import Combine
@testable import WiPeerKit

actor MockServiceDiscovery: ServiceDiscoveryProtocol {
    private var _discoveredPeers: [WiPeerKit.DiscoveredPeer] = []
    private let discoveredPeersSubject = PassthroughSubject<[WiPeerKit.DiscoveredPeer], Never>()
    
    var discoveredPeers: [WiPeerKit.DiscoveredPeer] {
        _discoveredPeers
    }
    
    var discoveredPeersPublisher: AnyPublisher<[WiPeerKit.DiscoveredPeer], Never> {
        discoveredPeersSubject.eraseToAnyPublisher()
    }
    
    private var advertisingStarted = false
    private var browsingStarted = false
    
    func startAdvertising(serviceName: String?) {
        advertisingStarted = true
    }
    
    func stopAdvertising() {
        advertisingStarted = false
    }
    
    func startBrowsing() {
        browsingStarted = true
    }
    
    func stopBrowsing() {
        browsingStarted = false
        _discoveredPeers = []
        discoveredPeersSubject.send([])
    }
    
    func simulatePeerDiscovery(_ peer: WiPeerKit.DiscoveredPeer) {
        _discoveredPeers.append(peer)
        discoveredPeersSubject.send(_discoveredPeers)
    }
    
    func isAdvertising() -> Bool {
        advertisingStarted
    }
    
    func isBrowsing() -> Bool {
        browsingStarted
    }
}
