//
//  PeerViewModel.swift
//  WiPeerKitDemo
//
//  Created by Vincent Joy on 29/08/25.
//

import Foundation
import Combine
import WiPeerKit

@MainActor
class PeerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var connectionState: WiPeerKit.ConnectionState = .disconnected
    @Published var discoveredPeers: [WiPeerKit.DiscoveredPeer] = []
    @Published var messages: [Message] = []
    @Published var isAdvertising = false
    @Published var isBrowsing = false
    @Published var isAnimating = false
    @Published var currentPIN = ""
    @Published var connectedPeerName: String?
    @Published var discoveryMode: DiscoveryMode = .off
    @Published var authMode: AuthMode = .pin
    @Published var trustedDevices: [String] = []
    @Published var selectedPeer: WiPeerKit.DiscoveredPeer?
    
    // Device info
    @Published var deviceName: String = ProcessInfo.processInfo.hostName {
        didSet {
            UserDefaults.standard.set(deviceName, forKey: "deviceName")
        }
    }
    let deviceID = UUID().uuidString.prefix(8).uppercased()
    
    // Connection request publisher
    let connectionRequestPublisher = PassthroughSubject<SecureConnectionManager.DeviceIdentity, Never>()
    
    // MARK: - Private Properties
    private let peerKit = WiPeerKit()
    private var connectionManager: SecureConnectionManager?
    private var cancellables = Set<AnyCancellable>()
    private var pendingConnectionApproval: ((Bool) -> Void)?
    
    // MARK: - Initialization
    init() {
        setupBindings()
        loadSettings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Connection state
        peerKit.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                self?.updateAnimationState(for: state)
                
                if case .connected = state {
                    self?.onConnected()
                } else if case .disconnected = state {
                    self?.onDisconnected()
                }
            }
            .store(in: &cancellables)
        
        // Discovered peers
        peerKit.$discoveredPeers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peers in
                self?.discoveredPeers = peers
            }
            .store(in: &cancellables)
        
        // Received messages
        peerKit.onDataReceived = { [weak self] data in
            Task { @MainActor in
                self?.handleReceivedData(data)
            }
        }
    }
    
    private func loadSettings() {
        if let savedName = UserDefaults.standard.string(forKey: "deviceName") {
            deviceName = savedName
        }
        
        if let savedTrusted = UserDefaults.standard.array(forKey: "trustedDevices") as? [String] {
            trustedDevices = savedTrusted
        }
    }
    
    // MARK: - Discovery
    func updateDiscoveryMode(_ mode: DiscoveryMode) {
        switch mode {
        case .advertise:
            stopBrowsing()
            startAdvertising()
        case .browse:
            stopAdvertising()
            startBrowsing()
        case .off:
            stopAdvertising()
            stopBrowsing()
        }
    }
    
    private func startAdvertising() {
        Task {
            do {
                // Setup connection manager based on auth mode
                switch authMode {
                case .pin:
                    currentPIN = generatePIN()
                    connectionManager = try SecureConnectionManager(authMethod: .pin(currentPIN))
                case .manual:
                    connectionManager = try SecureConnectionManager(authMethod: .manualApproval)
                case .trusted:
                    // Load trusted devices
                    let trustedIdentities = loadTrustedIdentities()
                    connectionManager = try SecureConnectionManager(authMethod: .trustedDevices(trustedIdentities))
                }
                
                setupConnectionManagerCallbacks()
                
                peerKit.startAdvertising(serviceName: deviceName)
                isAdvertising = true
            } catch {
                print("Failed to start advertising: \(error)")
            }
        }
    }
    
    private func stopAdvertising() {
        peerKit.stopAdvertising()
        isAdvertising = false
        currentPIN = ""
    }
    
    private func startBrowsing() {
        peerKit.startBrowsing()
        isBrowsing = true
    }
    
    private func stopBrowsing() {
        peerKit.stopBrowsing()
        isBrowsing = false
    }
    
    // MARK: - Connection
    func connectToPeer(_ peer: WiPeerKit.DiscoveredPeer, pin: String) {
        Task {
            do {
                connectionManager = try SecureConnectionManager(authMethod: .pin(pin))
                setupConnectionManagerCallbacks()
                
                try await peerKit.secureConnectWithAuth(to: peer, using: connectionManager!)
                connectedPeerName = peer.name
            } catch {
                print("Connection failed: \(error)")
                connectionState = .failed(error)
            }
        }
    }
    
    func disconnect() {
        peerKit.disconnect()
        messages.removeAll()
        connectedPeerName = nil
    }
    
    func approveConnection(_ approved: Bool) {
        pendingConnectionApproval?(approved)
        pendingConnectionApproval = nil
    }
    
    // MARK: - Messaging
    func sendMessage(_ text: String) {
        let message = Message(content: text, isOutgoing: true)
        messages.append(message)
        
        Task {
            do {
                try await peerKit.send(message: text)
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        if let text = String(data: data, encoding: .utf8) {
            let message = Message(content: text, isOutgoing: false)
            messages.append(message)
        }
    }
    
    // MARK: - Connection Manager Setup
    private func setupConnectionManagerCallbacks() {
        Task {
            await connectionManager?.setOnConnectionRequest { [weak self] device in
                guard let self = self else { return false }
                
                return await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        self.pendingConnectionApproval = { approved in
                            continuation.resume(returning: approved)
                        }
                        self.connectionRequestPublisher.send(device)
                    }
                }
            }
            
            await connectionManager?.setPinRequest { [weak self] in
                guard let self = self else { return nil }
                
                return await MainActor.run {
                    // In a real app, this would show a PIN entry dialog
                    return self.currentPIN
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func generatePIN() -> String {
        String(format: "%06d", Int.random(in: 0...999999))
    }
    
    func formatPIN(_ pin: String) -> String {
        guard pin.count == 6 else { return pin }
        let index = pin.index(pin.startIndex, offsetBy: 3)
        return "\(pin[..<index])-\(pin[index...])"
    }
    
    private func updateAnimationState(for state: WiPeerKit.ConnectionState) {
        switch state {
        case .connecting:
            isAnimating = true
        default:
            isAnimating = false
        }
    }
    
    private func onConnected() {
        // Add system message
        let message = Message(
            content: "🔐 Secure connection established",
            isOutgoing: false,
            isSystemMessage: true
        )
        messages.append(message)
    }
    
    private func onDisconnected() {
        if !messages.isEmpty {
            let message = Message(
                content: "Connection ended",
                isOutgoing: false,
                isSystemMessage: true
            )
            messages.append(message)
        }
    }
    
    func removeTrustedDevice(_ device: String) {
        trustedDevices.removeAll { $0 == device }
        UserDefaults.standard.set(trustedDevices, forKey: "trustedDevices")
    }
    
    private func loadTrustedIdentities() -> [SecureConnectionManager.DeviceIdentity] {
        // In a real app, this would load actual device identities from Keychain
        return []
    }
}

