//
//  TCPTransport.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 16/07/25.
//

import Foundation
import Network
import Combine

/// Handles raw TCP socket communication using Network framework
actor TCPTransportActor: TCPTransportProtocol {
    
    // MARK: - Properties
    
    private var _connectionState: TCPConnectionState = .disconnected
    private let connectionStateSubject = PassthroughSubject<TCPConnectionState, Never>()
    
    var connectionState: TCPConnectionState {
        _connectionState
    }
    
    var connectionStatePublisher: AnyPublisher<TCPConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    private var onDataReceived: (@Sendable (Data) async -> Void)?
    
    private var connection: NWConnection?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.wipeerkit.tcp")
    
    // MARK: - TCPTransportProtocol Methods
    
    func setDataHandler(_ handler: @escaping @Sendable (Data) async -> Void) {
        onDataReceived = handler
    }
    
    func connect(host: String, port: Int) async throws {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )
        
        let parameters = NWParameters.tcp
        parameters.prohibitedInterfaceTypes = [.cellular] // WiFi only
        
        let connection = NWConnection(to: endpoint, using: parameters)
        self.connection = connection
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { [weak self] state in
                Task {
                    await self?.handleConnectionStateUpdate(state, continuation: continuation)
                }
            }
            
            connection.start(queue: queue)
        }
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        _connectionState = .disconnected
        connectionStateSubject.send(.disconnected)
    }
    
    func send(data: Data) async throws {
        guard let connection = connection else {
            throw WiPeerKit.WiPeerKitError.notConnected
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    func startListening(on port: UInt16) throws {
        let parameters = NWParameters.tcp
        parameters.prohibitedInterfaceTypes = [.cellular]
        
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
        
        listener?.newConnectionHandler = { [weak self] connection in
            Task {
                await self?.handleNewConnection(connection)
            }
        }
        
        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Listener ready on port \(port)")
            case .failed(let error):
                print("Listener failed: \(error)")
            default:
                break
            }
        }
        
        listener?.start(queue: queue)
    }
    
    func stopListening() {
        listener?.cancel()
        listener = nil
    }
    
    // MARK: - Private Methods
    
    private func handleConnectionStateUpdate(_ state: NWConnection.State, continuation: CheckedContinuation<Void, Error>?) {
        switch state {
        case .ready:
            _connectionState = .connected
            connectionStateSubject.send(.connected)
            startReceiving()
            continuation?.resume()
            
        case .failed(let error):
            _connectionState = .failed(error)
            connectionStateSubject.send(.failed(error))
            continuation?.resume(throwing: error)
            
        case .cancelled:
            _connectionState = .disconnected
            connectionStateSubject.send(.disconnected)
            
        default:
            break
        }
    }
    
    private func startReceiving() {
        receiveData()
    }
    
    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task {
                await self?.handleReceivedData(data: data, isComplete: isComplete, error: error)
            }
        }
    }
    
    private func handleReceivedData(data: Data?, isComplete: Bool, error: Error?) {
        if let data = data, !data.isEmpty {
            Task {
                await onDataReceived?(data)
            }
        }
        
        if isComplete {
            _connectionState = .disconnected
            connectionStateSubject.send(.disconnected)
        } else if error == nil {
            receiveData() // Continue receiving
        } else if let error = error {
            _connectionState = .failed(error)
            connectionStateSubject.send(.failed(error))
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        // If we already have a connection, reject the new one
        if self.connection != nil {
            connection.cancel()
            return
        }
        
        self.connection = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleConnectionStateUpdate(state, continuation: nil)
            }
        }
        
        connection.start(queue: queue)
    }
}
