# WiPeerKit

A production-ready Swift framework for secure peer-to-peer communication over local networks, featuring automatic device discovery, end-to-end encryption, and robust authentication.

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20macOS%2011%2B-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## Features

- 🔍 **Automatic Device Discovery** - mDNS/Bonjour service discovery
- 🔐 **End-to-End Encryption** - AES-256-GCM with Diffie-Hellman key exchange  
- 🛡️ **Robust Authentication** - PIN, QR code, and trusted device support
- 🔌 **Direct TCP Connections** - Low-latency peer-to-peer communication
- 🎯 **Swift 6 Concurrency** - Complete data race safety with actors
- 🧪 **Comprehensive Testing** - Unit and integration tests included
- 📱 **Easy Integration** - Clean API with SwiftUI support

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Security](#security)
- [Advanced Usage](#advanced-usage)
- [Sample Apps](#sample-apps)
- [Architecture](#architecture)
- [API Reference](#api-reference)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Requirements

- iOS 14.0+ / macOS 11.0+
- Swift 6.0+
- Xcode 15.0+

### Info.plist Configuration

Add these entries to your app's Info.plist:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses the local network to discover and communicate with nearby devices.</string>

<key>NSBonjourServices</key>
<array>
    <string>_wipeerkit._tcp</string>
</array>
```

## Quick Start

### Basic Usage (Secure by Default)

```swift
import WiPeerKit

// Initialize with secure defaults
let peerKit = WiPeerKit()
let connectionManager = try SecureConnectionManager(authMethod: .pin("123456"))

// Set up handlers
peerKit.onDataReceived = { data in
    if let message = String(data: data, encoding: .utf8) {
        print("Received: \(message)")
    }
}

connectionManager.onConnectionRequest = { device in
    // Show UI for user approval
    print("Connection from: \(device.name)")
    print("Fingerprint: \(device.fingerprint)")
    return true // or false to reject
}

// Start advertising
peerKit.startAdvertising(serviceName: "My Device")

// Or browse for peers
peerKit.startBrowsing()
```

### Secure Connection Flow

```swift
// 1. Discover peers
peerKit.$discoveredPeers
    .sink { peers in
        for peer in peers {
            print("Found: \(peer.name)")
        }
    }
    .store(in: &cancellables)

// 2. Connect with authentication
if let peer = peerKit.discoveredPeers.first {
    do {
        // This will trigger PIN verification
        try await peerKit.secureConnectWithAuth(
            to: peer,
            using: connectionManager
        )
        print("Secure connection established!")
    } catch {
        print("Connection failed: \(error)")
    }
}

// 3. Send encrypted messages
try await peerKit.send(message: "Hello, secure world!")
```

## Security

### Authentication Methods

WiPeerKit supports multiple authentication methods to prevent unauthorized connections:

#### 1. PIN-Based Authentication

```swift
// Initialize with PIN
let connectionManager = try SecureConnectionManager(
    authMethod: .pin("425817")
)

// The connecting device must enter this PIN
connectionManager.onPinRequested = {
    // Show PIN entry UI
    return enteredPin
}
```

#### 2. QR Code Authentication

```swift
// Generate QR code for pairing
let qrData = try connectionManager.generateQRCode()
let qrImage = QRCodeGenerator.generate(from: qrData)

// Scan QR code on other device
let connectionManager = try SecureConnectionManager(
    authMethod: .qrCode(scannedData)
)
```

#### 3. Manual Approval

```swift
let connectionManager = try SecureConnectionManager(
    authMethod: .manualApproval
)

connectionManager.onConnectionRequest = { device in
    // Show approval dialog
    let alert = UIAlertController(
        title: "Connection Request",
        message: "\(device.name) wants to connect\nFingerprint: \(device.fingerprint)",
        preferredStyle: .alert
    )
    // ... handle user response
}
```

#### 4. Trusted Devices

```swift
// First connection uses PIN
// Then save as trusted
if userApprovesDevice {
    try connectionManager.addTrustedDevice(device)
}

// Future connections are automatic
let connectionManager = try SecureConnectionManager(
    authMethod: .trustedDevices(savedDevices)
)
```

### Encryption Details

- **Algorithm**: AES-256-GCM (Authenticated Encryption)
- **Key Exchange**: ECDH using P-256 curve
- **Key Derivation**: HKDF-SHA256
- **Perfect Forward Secrecy**: New keys for each session
- **Replay Protection**: Timestamp validation

### Security Best Practices

1. **Always use authentication** - Never use the basic connection without authentication
2. **Verify fingerprints** - For sensitive data, manually verify device fingerprints
3. **Implement timeouts** - Set appropriate timeouts for authentication
4. **Audit connections** - Log all connection attempts
5. **Regular key rotation** - For long-lived connections, implement key rotation

## Advanced Usage

### Custom Service Types

```swift
// Use app-specific service type for isolation
let customServiceType = "_myapp-v1._tcp"
peerKit.startAdvertising(
    serviceName: "Device Name",
    serviceType: customServiceType
)
```

### Connection Options

```swift
let options = WiPeerKit.ConnectionOptions(
    requireEncryption: true,
    handshakeTimeout: 15.0,
    maxMessageSize: 1_048_576 // 1MB
)

try await peerKit.secureConnect(to: peer, options: options)
```

### Message Framing

```swift
// Send structured data
struct GameState: Codable {
    let players: [Player]
    let score: Int
}

let gameState = GameState(...)
let data = try JSONEncoder().encode(gameState)
try await peerKit.send(data: data)
```

### Streaming Large Files

```swift
// Send file in chunks
let fileURL = URL(fileURLWithPath: "large-file.zip")
let fileHandle = try FileHandle(forReadingFrom: fileURL)

let chunkSize = 65536 // 64KB chunks
while let chunk = fileHandle.readData(ofLength: chunkSize), !chunk.isEmpty {
    try await peerKit.send(data: chunk)
}
```

### Custom Authentication

```swift
// Implement custom authentication
class BiometricAuthenticationMethod: AuthenticationMethod {
    func authenticate(device: DeviceIdentity) async throws -> Bool {
        let context = LAContext()
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate connection from \(device.name)"
            ) { success, error in
                continuation.resume(returning: success)
            }
        }
    }
}
```

## Sample Apps

### iOS Sample App

A complete SwiftUI chat application demonstrating all features:

```bash
cd Examples/WiPeerKitDemo
open WiPeerKitDemo.xcodeproj
```

Features demonstrated:
- Device discovery with visual feedback
- PIN-based pairing flow
- Encrypted messaging
- Connection status indicators
- Trust management

### Command-Line Tool

A macOS CLI tool for testing and debugging:

```bash
# Build and run
swift run WiPeerKitCLI

# Available commands:
> advertise [name]     # Start advertising
> browse              # Scan for devices
> connect <number>    # Connect to discovered device
> pin <code>         # Enter PIN for authentication
> send <message>     # Send encrypted message
> trust              # Trust current device
> disconnect         # Close connection
> status            # Show connection info
> quit              # Exit
```

Example session:
```bash
$ swift run WiPeerKitCLI

WiPeerKit CLI v2.0
==================

> advertise "My Mac"
📢 Advertising as 'My Mac'
🔑 Connection PIN: 425-817

> status
Service: Advertising ✓
Connected: No
Security: PIN Required
```

## Architecture

### Component Overview

```
┌─────────────────────────────────────┐
│          WiPeerKit (Main API)       │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────┐  ┌──────────────┐ │
│  │  Service    │  │   Secure     │ │
│  │ Discovery   │  │ Connection   │ │
│  └─────────────┘  └──────────────┘ │
│                                     │
│  ┌─────────────┐  ┌──────────────┐ │
│  │    TCP      │  │  Encryption  │ │
│  │ Transport   │  │   (AES-GCM)  │ │
│  └─────────────┘  └──────────────┘ │
│                                     │
│  ┌─────────────┐  ┌──────────────┐ │
│  │  Message    │  │     Key      │ │
│  │  Protocol   │  │   Exchange   │ │
│  └─────────────┘  └──────────────┘ │
└─────────────────────────────────────┘
```

### Actor-Based Concurrency

All components are implemented as actors for thread safety:

```swift
actor ServiceDiscoveryActor    // Manages mDNS operations
actor TCPTransportActor       // Handles socket communication  
actor EncryptionActor         // Cryptographic operations
actor SecureConnectionManager // Authentication & authorization
```

### Data Flow

1. **Discovery**: mDNS advertises/browses for services
2. **Connection**: TCP socket established between peers
3. **Authentication**: Identity verified through chosen method
4. **Key Exchange**: ECDH generates session keys
5. **Communication**: Messages encrypted with AES-GCM

## API Reference

### WiPeerKit

Main entry point for the framework.

```swift
@MainActor
public final class WiPeerKit {
    // Connection state
    @Published public private(set) var connectionState: ConnectionState
    @Published public private(set) var discoveredPeers: [DiscoveredPeer]
    
    // Callbacks
    public var onDataReceived: (@Sendable (Data) -> Void)?
    
    // Discovery
    public func startAdvertising(serviceName: String? = nil)
    public func stopAdvertising()
    public func startBrowsing()
    public func stopBrowsing()
    
    // Connection
    public func connect(to peer: DiscoveredPeer) async throws
    public func secureConnect(to peer: DiscoveredPeer, options: ConnectionOptions) async throws
    public func secureConnectWithAuth(to peer: DiscoveredPeer, using: SecureConnectionManager) async throws
    public func disconnect()
    
    // Communication
    public func send(data: Data) async throws
    public func send(message: String) async throws
}
```

### SecureConnectionManager

Handles authentication and authorization.

```swift
actor SecureConnectionManager {
    // Authentication methods
    enum AuthenticationMethod {
        case pin(String)
        case qrCode(Data)
        case manualApproval
        case trustedDevices([DeviceIdentity])
    }
    
    // Callbacks
    var onConnectionRequest: (@Sendable (DeviceIdentity) async -> Bool)?
    var onPinRequested: (@Sendable () async -> String?)?
    
    // Trust management
    func addTrustedDevice(_ device: DeviceIdentity) async
    func removeTrustedDevice(_ device: DeviceIdentity) async
    func getTrustedDevices() async -> [DeviceIdentity]
}
```

### Types

```swift
// Discovered peer information
public struct DiscoveredPeer: Sendable {
    public let id: String
    public let name: String
    public let host: String?
    public let port: Int?
}

// Connection states
public enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case failed(Error)
}

// Device identity
public struct DeviceIdentity: Sendable {
    public let id: UUID
    public let name: String
    public let fingerprint: String
    public let modelIdentifier: String
}
```

## Testing

### Running Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter SecurityTests

# Run with coverage
swift test --enable-code-coverage
```

### Test Categories

1. **Unit Tests**: Test individual components in isolation
2. **Integration Tests**: Test component interactions
3. **Security Tests**: Verify encryption and authentication
4. **Performance Tests**: Measure throughput and latency

### Writing Tests

```swift
@MainActor
final class MyWiPeerKitTests: XCTestCase {
    func testSecureConnection() async throws {
        // Given
        let alice = WiPeerKit()
        let bob = WiPeerKit()
        
        let aliceManager = try SecureConnectionManager(authMethod: .pin("123456"))
        let bobManager = try SecureConnectionManager(authMethod: .pin("123456"))
        
        // When
        alice.startAdvertising()
        bob.startBrowsing()
        
        // Allow discovery
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Then
        XCTAssertFalse(bob.discoveredPeers.isEmpty)
        
        // Connect securely
        let peer = bob.discoveredPeers.first!
        try await bob.secureConnectWithAuth(to: peer, using: bobManager)
        
        XCTAssertEqual(bob.connectionState, .connected)
    }
}
```

## Troubleshooting

### Common Issues

#### "Local Network Permission Denied"
- Ensure NSLocalNetworkUsageDescription is in Info.plist
- User must grant permission in Settings

#### "No Devices Found"
- Verify both devices are on same Wi-Fi network
- Check firewall settings
- Ensure service type matches

#### "Connection Failed"
- Verify authentication credentials (PIN, etc.)
- Check for timeout issues
- Enable debug logging

### Debug Logging

```swift
// Enable verbose logging
WiPeerKit.enableDebugLogging = true

// Custom log handler
WiPeerKit.logHandler = { level, message in
    print("[\(level)] \(message)")
}
```

### Network Diagnostics

```swift
// Get connection statistics
let stats = await peerKit.getConnectionStats()
print("Bytes sent: \(stats.bytesSent)")
print("Bytes received: \(stats.bytesReceived)")
print("Round trip time: \(stats.roundTripTime)ms")
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint configuration
- Document public APIs
- Add unit tests for new features

## License

WiPeerKit is available under the MIT license. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Apple's Network framework team
- CryptoKit contributors
- Swift community for concurrency feedback

---

For questions and support, please open an issue on GitHub.
