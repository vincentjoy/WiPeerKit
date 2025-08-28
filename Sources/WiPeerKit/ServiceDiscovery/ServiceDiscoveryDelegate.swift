//
//  ServiceDiscoveryDelegate.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 16/07/25.
//

@preconcurrency import Foundation
@preconcurrency import Network

/// Thread-safe delegate handler for NetService
final class ServiceDiscoveryDelegate: NSObject, NetServiceDelegate, NetServiceBrowserDelegate, @unchecked Sendable {
    var onServiceFound: ((NetService) -> Void)?
    var onServiceRemoved: ((NetService) -> Void)?
    var onServiceResolved: ((NetService) -> Void)?
    
    // MARK: - NetServiceDelegate
    
    func netServiceDidPublish(_ sender: NetService) {
        print("Service published: \(sender.name)")
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Failed to publish service: \(errorDict)")
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        onServiceResolved?(sender)
    }
    
    // MARK: - NetServiceBrowserDelegate
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        onServiceFound?(service)
    }
     
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        onServiceRemoved?(service)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Failed to search for services: \(errorDict)")
    }
}
