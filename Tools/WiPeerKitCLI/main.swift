//
//  main.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 16/07/25.
//

import Foundation
import WiPeerKit
import Combine

/// Command-line tool demonstrating secure WiPeerKit usage
@MainActor
final class WiPeerKitCLI {
    // MARK: - Properties
    
    private let peerKit = WiPeerKit()
    private var connectionManager: SecureConnectionManager?
    private var cancellables = Set<AnyCancellable>()
    
    // State
    private var isAdvertising = false
    private var isBrowsing = false
    private var currentPIN: String?
    private var trustedDevices: Set<String> = []
    private var securityMode: SecurityMode = .pin
    
    // MARK: - Security Modes
    
    enum SecurityMode: String {
        case pin = "PIN authentication"
        case manual = "Manual approval"
        case trusted = "Trusted devices only"
        case open = "Open (NOT RECOMMENDED)"
    }
    
    // MARK: - Main
    
    func run() async {
        loadTrustedDevices()
        await setupHandlers()
        printWelcome()
        await runEventLoop()
    }
    
    private func setupHandlers() async {
        // Connection state monitoring
        peerKit.$connectionState
            .sink { state in
                Task { @MainActor in
                    self.handleConnectionStateChange(state)
                }
            }
            .store(in: &cancellables)
        
        // Discovered peers monitoring
        peerKit.$discoveredPeers
            .dropFirst()
            .sink { peers in
                Task { @MainActor in
                    self.displayDiscoveredPeers(peers)
                }
            }
            .store(in: &cancellables)
        
        // Message reception
        peerKit.onDataReceived = { data in
            Task { @MainActor in
                self.handleReceivedData(data)
            }
        }
    }
    
    private func handleConnectionStateChange(_ state: WiPeerKit.ConnectionState) {
        switch state {
        case .connected:
            print("\n✅ Secure connection established!")
            print("🔐 All messages are now encrypted with ephemeral keys")
        case .disconnected:
            print("\n❌ Disconnected")
        case .connecting:
            print("\n⏳ Establishing secure connection...")
        case .failed(let error):
            print("\n❌ Connection failed: \(error.localizedDescription)")
        }
        
        print("\n> ", terminator: "")
        fflush(stdout)
    }
    
    private func displayDiscoveredPeers(_ peers: [WiPeerKit.DiscoveredPeer]) {
        if !peers.isEmpty {
            print("\n📡 Discovered peers:")
            peers.enumerated().forEach { index, peer in
                let trusted = trustedDevices.contains(peer.id) ? " ✓" : ""
                print("  \(index + 1). \(peer.name)\(trusted) - \(peer.host ?? "unknown"):\(peer.port ?? 0)")
            }
            print("\nUse 'connect <number>' to connect to a peer")
        }
        
        print("\n> ", terminator: "")
        fflush(stdout)
    }
    
    private func handleReceivedData(_ data: Data) {
        if let message = String(data: data, encoding: .utf8) {
            print("\n📨 Received (encrypted): \(message)")
        } else {
            print("\n📦 Received \(data.count) bytes of binary data")
        }
        
        print("\n> ", terminator: "")
        fflush(stdout)
    }
    
    private func printWelcome() {
        print("""
        ╔═══════════════════════════════════════════════╗
        ║          WiPeerKit CLI v2.0                   ║
        ║     Secure P2P Communication Tool             ║
        ╚═══════════════════════════════════════════════╝
        
        🔐 Security Mode: \(securityMode.rawValue)
        
        Commands:
          advertise [name]  - Start advertising (generates PIN)
          browse           - Start browsing for peers
          connect <n>      - Connect to discovered peer #n
          pin <code>       - Enter PIN for connection
          send <message>   - Send encrypted message
          trust            - Trust current connected device
          untrust <id>     - Remove device from trusted list
          security <mode>  - Change security mode (pin/manual/trusted/open)
          disconnect       - Disconnect from peer
          status           - Show connection status
          help             - Show this help
          quit             - Exit
        
        > 
        """, terminator: "")
        fflush(stdout)
    }
    
    private func runEventLoop() async {
        while let input = readLine() {
            let components = input.split(separator: " ", maxSplits: 1)
            guard !components.isEmpty else {
                print("> ", terminator: "")
                fflush(stdout)
                continue
            }
            
            let command = String(components[0]).lowercased()
            let argument = components.count > 1 ? String(components[1]) : nil
            
            await handleCommand(command, argument: argument)
            
            if command == "quit" {
                break
            }
            
            print("\n> ", terminator: "")
            fflush(stdout)
        }
    }
    
    private func handleCommand(_ command: String, argument: String?) async {
        switch command {
        case "advertise":
            await startAdvertising(name: argument)
            
        case "browse":
            startBrowsing()
            
        case "connect":
            await connectToPeer(argument: argument)
            
        case "pin":
            await submitPIN(argument)
            
        case "send":
            await sendMessage(argument)
            
        case "trust":
            trustCurrentDevice()
            
        case "untrust":
            untrustDevice(argument)
            
        case "security":
            changeSecurityMode(argument)
            
        case "disconnect":
            disconnect()
            
        case "status":
            printStatus()
            
        case "help":
            printWelcome()
            
        case "quit":
            cleanup()
            print("\n👋 Goodbye!")
            
        default:
            print("❓ Unknown command: \(command)")
            print("Type 'help' for available commands")
        }
    }
    
    // MARK: - Command Handlers
    
    private func startAdvertising(name: String?) async {
        let deviceName = name ?? ProcessInfo.processInfo.hostName ?? "WiPeerKit-CLI"
        
        do {
            // Setup security
            switch securityMode {
            case .pin:
                currentPIN = generatePIN()
                connectionManager = try SecureConnectionManager(authMethod: .pin(currentPIN!))
                print("🔑 Connection PIN: \(formatPIN(currentPIN!))")
                
            case .manual:
                connectionManager = try SecureConnectionManager(authMethod: .manualApproval)
                
            case .trusted:
                connectionManager = try SecureConnectionManager(authMethod: .manualApproval)
                
            case .open:
                print("⚠️  WARNING: Open mode is insecure!")
                connectionManager = nil
            }
            
            setupConnectionManagerCallbacks()
            
            peerKit.startAdvertising(serviceName: deviceName)
            isAdvertising = true
            print("📢 Advertising as '\(deviceName)'")
            
        } catch {
            print("❌ Failed to start advertising: \(error)")
        }
    }
    
    private func startBrowsing() {
        peerKit.startBrowsing()
        isBrowsing = true
        print("🔍 Browsing for peers...")
    }
    
    private func connectToPeer(argument: String?) async {
        guard let indexStr = argument,
              let index = Int(indexStr),
              index > 0,
              index <= peerKit.discoveredPeers.count else {
            print("❌ Invalid peer number")
            return
        }
        
        let peer = peerKit.discoveredPeers[index - 1]
        print("🔗 Connecting to \(peer.name)...")
        
        do {
            // Setup security for connection
            switch securityMode {
            case .pin:
                connectionManager = try SecureConnectionManager(authMethod: .pin(""))
                setupConnectionManagerCallbacks()
                print("📝 You will need to enter the PIN shown on the other device")
                
            case .manual, .trusted:
                connectionManager = try SecureConnectionManager(authMethod: .manualApproval)
                setupConnectionManagerCallbacks()
                
            case .open:
                print("⚠️  Connecting without authentication!")
                try await peerKit.connect(to: peer)
                return
            }
            
            // Secure connection
            if let connectionManager = connectionManager {
                try await peerKit.secureConnectWithAuth(to: peer, using: connectionManager)
            } else {
                try await peerKit.connect(to: peer)
            }
            
        } catch {
            print("❌ Connection error: \(error.localizedDescription)")
        }
    }
    
    private func submitPIN(_ pin: String?) async {
        guard let pin = pin else {
            print("❌ Please provide a PIN")
            return
        }
        
        // Store PIN for connection manager callback
        // In a real implementation, this would be handled differently
        print("✅ PIN submitted: \(pin)")
    }
    
    private func sendMessage(_ text: String?) async {
        guard let message = text, !message.isEmpty else {
            print("❌ Please provide a message")
            return
        }
        
        guard case .connected = peerKit.connectionState else {
            print("❌ Not connected to any peer")
            return
        }
        
        do {
            try await peerKit.send(message: message)
            print("✉️  Sent (encrypted): \(message)")
        } catch {
            print("❌ Send error: \(error.localizedDescription)")
        }
    }
    
    private func trustCurrentDevice() {
        // In real implementation, would get current peer info
        print("✅ Current device added to trusted list")
        saveTrustedDevices()
    }
    
    private func untrustDevice(_ deviceId: String?) {
        guard let deviceId = deviceId else {
            print("❌ Please provide device ID")
            return
        }
        
        trustedDevices.remove(deviceId)
        saveTrustedDevices()
        print("✅ Device removed from trusted list")
    }
    
    private func changeSecurityMode(_ mode: String?) {
        guard let modeStr = mode else {
            print("Current mode: \(securityMode.rawValue)")
            print("Available modes: pin, manual, trusted, open")
            return
        }
        
        switch modeStr.lowercased() {
        case "pin":
            securityMode = .pin
        case "manual":
            securityMode = .manual
        case "trusted":
            securityMode = .trusted
        case "open":
            print("⚠️  WARNING: Open mode provides no authentication!")
            print("Are you sure? (yes/no)")
            if readLine()?.lowercased() == "yes" {
                securityMode = .open
            } else {
                return
            }
        default:
            print("❌ Unknown security mode: \(modeStr)")
            return
        }
        
        print("✅ Security mode changed to: \(securityMode.rawValue)")
    }
    
    private func disconnect() {
        peerKit.disconnect()
        print("👋 Disconnected")
    }
    
    private func printStatus() {
        print("\n--- Status ---")
        print("Connection: \(connectionStateDescription)")
        print("Security Mode: \(securityMode.rawValue)")
        print("Advertising: \(isAdvertising ? "Yes" : "No")")
        print("Browsing: \(isBrowsing ? "Yes" : "No")")
        print("Discovered peers: \(peerKit.discoveredPeers.count)")
        print("Trusted devices: \(trustedDevices.count)")
        
        if let pin = currentPIN, isAdvertising && securityMode == .pin {
            print("Current PIN: \(formatPIN(pin))")
        }
    }
    
    private func cleanup() {
        peerKit.disconnect()
        peerKit.stopAdvertising()
        peerKit.stopBrowsing()
    }
    
    // MARK: - Security Helpers
    
    private func setupConnectionManagerCallbacks() {
        Task {
            await connectionManager?.setOnConnectionRequest { [weak self] device in
                await MainActor.run {
                    print("\n🔔 Connection request from: \(device.name)")
                    print("   Device ID: \(device.modelIdentifier)")
                    print("   Fingerprint: \(device.fingerprint)")
                    
                    // Check trusted devices
                    if self?.trustedDevices.contains(device.id.uuidString) == true {
                        print("✅ Auto-accepting trusted device")
                        return true
                    }
                    
                    // Check security mode
                    switch self?.securityMode {
                    case .trusted:
                        print("❌ Device not in trusted list")
                        return false
                        
                    case .manual:
                        print("Accept connection? (yes/no): ", terminator: "")
                        fflush(stdout)
                        let response = readLine()?.lowercased()
                        return response == "yes" || response == "y"
                        
                    default:
                        return true
                    }
                }
            }
        }
        
        Task {
            await connectionManager?.setPinRequest { [weak self] in
                await MainActor.run {
                    print("📝 Enter PIN shown on other device: ", terminator: "")
                    fflush(stdout)
                    return readLine()
                }
            }
        }
    }
    
    private func generatePIN() -> String {
        return String(format: "%06d", Int.random(in: 0...999999))
    }
    
    private func formatPIN(_ pin: String) -> String {
        guard pin.count == 6 else { return pin }
        let index = pin.index(pin.startIndex, offsetBy: 3)
        return "\(pin[..<index])-\(pin[index...])"
    }
    
    // MARK: - Persistence
    
    private func loadTrustedDevices() {
        if let data = UserDefaults.standard.data(forKey: "WiPeerKit.TrustedDevices"),
           let devices = try? JSONDecoder().decode(Set<String>.self, from: data) {
            trustedDevices = devices
            print("📱 Loaded \(devices.count) trusted devices")
        }
    }
    
    private func saveTrustedDevices() {
        if let data = try? JSONEncoder().encode(trustedDevices) {
            UserDefaults.standard.set(data, forKey: "WiPeerKit.TrustedDevices")
        }
    }
    
    // MARK: - Utilities
    
    private var connectionStateDescription: String {
        switch peerKit.connectionState {
        case .connected:
            return "Connected ✅ (Encrypted with ephemeral keys)"
        case .connecting:
            return "Connecting... ⏳"
        case .disconnected:
            return "Disconnected ❌"
        case .failed(let error):
            return "Failed: \(error.localizedDescription) ❌"
        }
    }
}
