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
    var onServiceFound: (@Sendable (NetService) async -> Void)?
    var onServiceRemoved: (@Sendable (NetService) async -> Void)?
    var onServiceResolved: (@Sendable (NetService) async -> Void)?
    
    // MARK: - NetServiceDelegate
    
    func netServiceDidPublish(_ sender: NetService) {
        print("Service published: \(sender.name)")
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Failed to publish service: \(errorDict)")
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        Task {
            await onServiceResolved?(sender)
        }
    }
    
    // MARK: - NetServiceBrowserDelegate
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Task {
            await onServiceFound?(service)
        }
    }
     
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        Task {
            await onServiceRemoved?(service)
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Failed to search for services: \(errorDict)")
    }
}
