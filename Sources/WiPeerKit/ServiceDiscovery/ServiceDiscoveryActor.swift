//
//  ServiceDiscoveryActor.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 16/07/25.
//

@preconcurrency import Foundation
@preconcurrency import Network
@preconcurrency import Combine

/// Handles mDNS/Bonjour service discovery
actor ServiceDiscoveryActor: ServiceDiscoveryProtocol {
    
    // MARK: - Properties
    
    private let serviceType = "_wipeerkit._tcp."
    private let serviceDomain = "local."
    
    private var netService: NetService?
    private var netServiceBrowser: NetServiceBrowser?
    private var services: [NetService] = []
    
    private var _discoveredPeers: [WiPeerKit.DiscoveredPeer] = []
    private let discoveredPeersSubject = PassthroughSubject<[WiPeerKit.DiscoveredPeer], Never>()
    
    var discoveredPeers: [WiPeerKit.DiscoveredPeer] {
        _discoveredPeers
    }
    
    var discoveredPeersPublisher: AnyPublisher<[WiPeerKit.DiscoveredPeer], Never> {
        discoveredPeersSubject.eraseToAnyPublisher()
    }
    
    private let delegate: ServiceDiscoveryDelegate
    
    // MARK: - Initialization
    
    init() {
        self.delegate = ServiceDiscoveryDelegate()
        setupDelegateCallbacks()
    }
    
    // MARK: - ServiceDiscoveryProtocol Methods
    
    func startAdvertising(serviceName: String?) {
        stopAdvertising()
        
        let name = serviceName ?? ProcessInfo.processInfo.hostName
        let port = findAvailablePort()
        
        netService = NetService(
            domain: serviceDomain,
            type: serviceType,
            name: name,
            port: Int32(port)
        )
        
        netService?.delegate = delegate
        netService?.publish()
    }
    
    func stopAdvertising() {
        netService?.stop()
        netService = nil
    }
    
    func startBrowsing() {
        stopBrowsing()
        
        netServiceBrowser = NetServiceBrowser()
        netServiceBrowser?.delegate = delegate
        netServiceBrowser?.searchForServices(
            ofType: serviceType,
            inDomain: serviceDomain
        )
    }
    
    func stopBrowsing() {
        netServiceBrowser?.stop()
        netServiceBrowser = nil
        services.removeAll()
        _discoveredPeers = []
        discoveredPeersSubject.send([])
    }
    
    // MARK: - Private Methods
    
    nonisolated private func setupDelegateCallbacks() {
        
        // Adding `@Sendable` to the closure.
        // This explicitly tells the compiler that the closure is safe to send across
        // concurrency domains, even though `NetService` is not a Sendable type.
        // This is a necessary concession when working with older, delegate-based APIs.
        
        delegate.onServiceFound = { @Sendable [weak self] service in
            Task {
                await self?.handleServiceFound(service)
            }
        }
        
        delegate.onServiceRemoved = { @Sendable [weak self] service in
            Task {
                await self?.handleServiceRemoved(service)
            }
        }
        
        delegate.onServiceResolved = { @Sendable [weak self] service in
            Task {
                await self?.handleServiceResolved(service)
            }
        }
    }
    
    private func handleServiceFound(_ service: NetService) {
        services.append(service)
        service.delegate = delegate
        service.resolve(withTimeout: 5.0)
    }
    
    private func handleServiceRemoved(_ service: NetService) {
        services.removeAll { $0 == service }
        updateDiscoveredPeers()
    }
    
    private func handleServiceResolved(_ service: NetService) {
        updateDiscoveredPeers()
    }
    
    private func findAvailablePort() -> UInt16 {
        // In a real implementation, we'd bind to port 0 and let the system assign
        // For now, using a fixed port in the dynamic range
        return 8888
    }
    
    private func updateDiscoveredPeers() {
        let peers = services.compactMap { service -> WiPeerKit.DiscoveredPeer? in
            guard let addresses = service.addresses, !addresses.isEmpty else {
                return WiPeerKit.DiscoveredPeer(
                    id: service.name,
                    name: service.name
                )
            }
            
            // Extract host and port from the first address
            if let (host, port) = parseAddress(addresses.first!) {
                return WiPeerKit.DiscoveredPeer(
                    id: service.name,
                    name: service.name,
                    host: host,
                    port: Int(port)
                )
            }
            
            return nil
        }
        
        _discoveredPeers = peers
        discoveredPeersSubject.send(peers)
    }
    
    private func parseAddress(_ data: Data) -> (String, UInt16)? {
        // Simple IPv4 parsing
        let bytes = [UInt8](data)
        guard bytes.count >= 6 else { return nil }
        
        if bytes[1] == 2 { // AF_INET
            let port = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
            let host = "\(bytes[4]).\(bytes[5]).\(bytes[6]).\(bytes[7])"
            return (host, port)
        }
        
        return nil
    }
}
