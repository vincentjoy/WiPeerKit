# WiPeerKit Examples

This directory contains sample applications demonstrating how to use WiPeerKit in real-world scenarios.

## 📱 iOS Demo App (WiPeerKitDemo)

A complete SwiftUI chat application showcasing all WiPeerKit features.

### Features Demonstrated

- ✅ Device discovery and advertising
- ✅ Secure PIN-based authentication
- ✅ End-to-end encrypted messaging
- ✅ Real-time connection status
- ✅ Trust management for devices
- ✅ Beautiful, production-ready UI

### Running the Demo

1. **Open the Project**
   ```bash
   cd Examples/WiPeerKitDemo
   open WiPeerKitDemo.xcodeproj
   ```

2. **Configure Signing**
   - Select the WiPeerKitDemo target
   - Go to "Signing & Capabilities"
   - Select your development team

3. **Run on Device**
   - Select your iOS device (simulator won't work for local network)
   - Press ⌘R to build and run

4. **Test with Two Devices**
   - Install on two iOS devices on the same Wi-Fi network
   - On Device A: Tap "Advertise" and note the PIN
   - On Device B: Tap "Browse", select Device A, enter PIN
   - Start chatting securely!

### Requirements

- iOS 14.0+
- Xcode 15.0+
- Physical iOS devices (local network features don't work in simulator)
- Devices must be on the same Wi-Fi network

### Project Structure

```
WiPeerKitDemo/
├── WiPeerKitDemoApp.swift    # App entry point
├── Views/
│   ├── ContentView.swift      # Main view
│   ├── DiscoveryView.swift    # Peer discovery UI
│   ├── ChatView.swift         # Messaging interface
│   └── SettingsView.swift    # Configuration options
├── ViewModels/
│   └── PeerViewModel.swift    # Business logic
└── Models/
    └── Message.swift          # Data models
```

### Key Implementation Points

The demo app shows best practices for:

1. **Initialization**
   ```swift
   let peerKit = WiPeerKit()
   let connectionManager = try SecureConnectionManager(authMethod: .pin("123456"))
   ```

2. **Discovery**
   ```swift
   peerKit.startBrowsing()
   peerKit.$discoveredPeers.sink { peers in
       // Update UI with discovered devices
   }
   ```

3. **Secure Connection**
   ```swift
   try await peerKit.secureConnectWithAuth(to: peer, using: connectionManager)
   ```

4. **Messaging**
   ```swift
   try await peerKit.send(message: "Hello, secure world!")
   ```

## 🖥️ macOS CLI Demo

See `Tools/WiPeerKitCLI` for a command-line demonstration of WiPeerKit features.

## 🎯 Other Examples (Coming Soon)

- **File Transfer Demo** - Large file sharing between devices
- **Gaming Demo** - Real-time multiplayer game
- **Audio Chat Demo** - Voice communication over local network
- **SwiftUI + UIKit Demo** - Mixed UI framework usage

## Contributing Examples

We welcome example contributions! If you've built something cool with WiPeerKit:

1. Create a new folder under `Examples/`
2. Include a README with setup instructions
3. Ensure it works with the latest WiPeerKit version
4. Submit a pull request

## Troubleshooting

### "Local Network Permission Denied"
- Go to Settings → Privacy & Security → Local Network
- Enable permission for WiPeerKitDemo

### "No Devices Found"
- Ensure both devices are on the same Wi-Fi network
- Check that neither device is using VPN
- Restart the app on both devices

### "Connection Failed"
- Verify the PIN is entered correctly
- Ensure both apps are in the foreground
- Check firewall settings on your router

## Support

For issues or questions about the examples:
- Open an issue on GitHub
- Check existing issues for solutions
- Include device models and iOS versions in bug reports