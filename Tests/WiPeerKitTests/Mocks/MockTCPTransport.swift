//
//  MockTCPTransport.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 17/07/25.
//

import XCTest
@preconcurrency import Combine
@testable import WiPeerKit

actor MockTCPTransport: TCPTransportProtocol {
    private var _connectionState: TCPConnectionState = .disconnected
    private let connectionStateSubject = PassthroughSubject<TCPConnectionState, Never>()
    
    var connectionState: TCPConnectionState {
        _connectionState
    }
    
    var connectionStatePublisher: AnyPublisher<TCPConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    private var onDataReceived: (@Sendable (Data) async -> Void)?
    private var sentData: [Data] = []
    private var connectCalled = false
    
    func setDataHandler(_ handler: @escaping @Sendable (Data) async -> Void) {
        onDataReceived = handler
    }
    
    func connect(host: String, port: Int) async throws {
        connectCalled = true
        _connectionState = .connected
        connectionStateSubject.send(.connected)
    }
    
    func disconnect() {
        _connectionState = .disconnected
        connectionStateSubject.send(.disconnected)
    }
    
    func send(data: Data) async throws {
        sentData.append(data)
    }
    
    func startListening(on port: UInt16) async throws {}
    func stopListening() {}
    
    func simulateDataReception(_ data: Data) async {
        await onDataReceived?(data)
    }
    
    func getSentData() -> [Data] {
        sentData
    }
    
    func wasConnectCalled() -> Bool {
        connectCalled
    }
}
