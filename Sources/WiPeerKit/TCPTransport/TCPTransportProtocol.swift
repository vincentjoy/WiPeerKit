//
//  TCPTransportProtocol.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 16/07/25.
//

import Foundation
import Combine

/// Protocol for TCP transport functionality
protocol TCPTransportProtocol: Actor {
    var connectionState: TCPConnectionState { get async }
    var connectionStatePublisher: AnyPublisher<TCPConnectionState, Never> { get }
    func connect(host: String, port: Int) async throws
    func disconnect() async
    func send(data: Data) async throws
    func startListening(on port: UInt16) async throws
    func stopListening() async
    func setDataHandler(_ handler: @escaping @Sendable (Data) async -> Void) async
}

/// TCP connection states
enum TCPConnectionState: Sendable {
    case connected
    case disconnected
    case failed(Error)
}
