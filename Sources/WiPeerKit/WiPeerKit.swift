// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
@preconcurrency import Combine

/// Main entry point for WiPeerKit framework
@MainActor
public final class WiPeerKit: Sendable {
    
    // MARK: - Public Types
    
    /// Represents a discovered peer on the network
    public struct DiscoveredPeer: Equatable, Sendable {
        public let id: String
        public let name: String
        public let host: String?
        public let port: Int?
        
        internal init(id: String, name: String, host: String? = nil, port: Int? = nil) {
            self.id = id
            self.name = name
            self.host = host
            self.port = port
        }
    }
    
    /// Connection state
    public enum ConnectionState: Sendable {
        case disconnected
        case connecting
        case connected
        case failed(Error)
    }
    
    /// Framework errors
    public enum WiPeerKitError: LocalizedError, Sendable {
        case advertisingFailed
        case browsingFailed
        case connectionFailed(String)
        case encryptionFailed
        case decryptionFailed
        case invalidMessage
        case notConnected
        
        public var errorDescription: String? {
            switch self {
            case .advertisingFailed:
                return "Failed to advertise service"
            case .browsingFailed:
                return "Failed to browse for services"
            case .connectionFailed(let message):
                return "Connection failed: \(message)"
            case .encryptionFailed:
                return "Failed to encrypt data"
            case .decryptionFailed:
                return "Failed to decrypt data"
            case .invalidMessage:
                return "Received invalid message format"
            case .notConnected:
                return "Not connected to any peer"
            }
        }
    }
    
    // MARK: - Properties
    
    /// Current connection state
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    
    /// Currently discovered peers
    @Published public private(set) var discoveredPeers: [DiscoveredPeer] = []
    
    /// Received data callback
    public var onDataReceived: (@Sendable (Data) -> Void)?
    
    // MARK: - Private Properties
    
    private let serviceDiscovery: ServiceDiscoveryActor
    private let tcpTransport: TCPTransportActor
    private let encryption: EncryptionActor
    private let messageProtocol: MessageProtocolActor
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize WiPeerKit with default configuration
    public init() {
        self.serviceDiscovery = ServiceDiscoveryActor()
        self.tcpTransport = TCPTransportActor()
        self.encryption = EncryptionActor()
        self.messageProtocol = MessageProtocolActor()
        
        Task {
            await setupBindings()
        }
    }
    
    /// Initialize WiPeerKit with custom components (for testing)
    internal init(
        serviceDiscovery: ServiceDiscoveryActor,
        tcpTransport: TCPTransportActor,
        encryption: EncryptionActor,
        messageProtocol: MessageProtocolActor
    ) {
        self.serviceDiscovery = serviceDiscovery
        self.tcpTransport = tcpTransport
        self.encryption = encryption
        self.messageProtocol = messageProtocol
        
        Task {
            await setupBindings()
        }
    }
    
    // MARK: - Public Methods
    
    /// Start advertising this device as available for connections
    /// - Parameter serviceName: Optional custom service name (defaults to device name)
    public func startAdvertising(serviceName: String? = nil) {
        Task {
            await serviceDiscovery.startAdvertising(serviceName: serviceName)
        }
    }
    
    /// Stop advertising this device
    public func stopAdvertising() {
        Task {
            await serviceDiscovery.stopAdvertising()
        }
    }
    
    /// Start browsing for other devices
    public func startBrowsing() {
        Task {
            await serviceDiscovery.startBrowsing()
        }
    }
    
    /// Stop browsing for other devices
    public func stopBrowsing() {
        Task {
            await serviceDiscovery.stopBrowsing()
        }
    }
    
    /// Connect to a discovered peer
    /// - Parameter peer: The peer to connect to
    public func connect(to peer: DiscoveredPeer) async throws {
        guard let host = peer.host, let port = peer.port else {
            throw WiPeerKitError.connectionFailed("Peer not resolved")
        }
        
        connectionState = .connecting
        
        do {
            try await tcpTransport.connect(host: host, port: port)
            connectionState = .connected
        } catch {
            connectionState = .failed(error)
            throw WiPeerKitError.connectionFailed(error.localizedDescription)
        }
    }
    
    /// Disconnect from current peer
    public func disconnect() {
        Task {
            await tcpTransport.disconnect()
            connectionState = .disconnected
        }
    }
    
    /// Send data to connected peer
    /// - Parameter data: Raw data to send
    public func send(data: Data) async throws {
        guard case .connected = connectionState else {
            throw WiPeerKitError.notConnected
        }
        
        // Encrypt the data
        let encryptedData = try await encryption.encrypt(data)
        
        // Frame the message
        let framedMessage = await messageProtocol.frameMessage(encryptedData)
        
        // Send via transport
        try await tcpTransport.send(data: framedMessage)
    }
    
    /// Send string message to connected peer
    /// - Parameter message: String message to send
    public func send(message: String) async throws {
        guard let data = message.data(using: .utf8) else {
            throw WiPeerKitError.invalidMessage
        }
        try await send(data: data)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() async {
        // Service discovery bindings
        await serviceDiscovery.discoveredPeersPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peers in
                Task { @MainActor in
                    self?.discoveredPeers = peers
                }
            }
            .store(in: &cancellables)
        
        // Transport data reception
        await tcpTransport.setDataHandler { [weak self] data in
            Task { @MainActor in
                await self?.handleReceivedData(data)
            }
        }
        
        // Transport connection state
        await tcpTransport.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .connected:
                        self?.connectionState = .connected
                    case .disconnected:
                        self?.connectionState = .disconnected
                    case .failed(let error):
                        self?.connectionState = .failed(error)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleReceivedData(_ data: Data) async {
        await messageProtocol.processIncomingData(data) { [weak self] completeMessage in
            Task { @MainActor in
                guard let self = self else { return }
                
                do {
                    // Decrypt the message
                    let decryptedData = try await self.encryption.decrypt(completeMessage)
                    
                    // Notify the client
                    self.onDataReceived?(decryptedData)
                } catch {
                    print("Failed to decrypt message: \(error)")
                }
            }
        }
    }
}
