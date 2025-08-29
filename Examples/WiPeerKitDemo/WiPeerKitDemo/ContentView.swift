//
//  ContentView.swift
//  WiPeerKitDemo
//
//  Created by Vincent Joy on 29/08/25.
//

import SwiftUI
import WiPeerKit

struct ContentView: View {
    @StateObject private var viewModel = PeerViewModel()
    @State private var showingSettings = false
    @State private var showingConnectionRequest = false
    @State private var pendingDevice: SecureConnectionManager.DeviceIdentity?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Connection Status Bar
                    ConnectionStatusView(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Main Content
                    if case WiPeerKit.ConnectionState.connected = .connected {
                        ChatView(viewModel: viewModel)
                    } else {
                        DiscoveryView(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("WiPeerKit Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
            }
            .alert("Connection Request", isPresented: $showingConnectionRequest) {
                
                if let device = pendingDevice {
                    Text("\(device.name) wants to connect\n\nFingerprint: \(device.fingerprint)")
                } else {
                    Text("Incoming connection request")
                }
                
                
                Button("Accept") {
                    viewModel.approveConnection(true)
                }
                
                Button("Reject", role: .cancel) {
                    viewModel.approveConnection(false)
                }
            }
            .onReceive(viewModel.connectionRequestPublisher) { device in
                pendingDevice = device
                showingConnectionRequest = true
            }
        }
    }
}

#Preview {
    ContentView()
}
