//
//  DiscoveryView.swift
//  WiPeerKitDemo
//
//  Created by Vincent Joy on 29/08/25.
//

import SwiftUI
import WiPeerKit

struct DiscoveryView: View {
    @ObservedObject var viewModel: PeerViewModel
    @State private var showingPINEntry = false
    @State private var enteredPIN = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Mode Selection
            Picker("Mode", selection: $viewModel.discoveryMode) {
                Text("Advertise").tag(DiscoveryMode.advertise)
                Text("Browse").tag(DiscoveryMode.browse)
                Text("Off").tag(DiscoveryMode.off)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: viewModel.discoveryMode) { newMode in
                viewModel.updateDiscoveryMode(newMode)
            }
            
            // PIN Display (when advertising)
            if viewModel.isAdvertising && !viewModel.currentPIN.isEmpty {
                VStack(spacing: 8) {
                    Text("Connection PIN")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.formatPIN(viewModel.currentPIN))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                    
                    Text("Share this PIN with the connecting device")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.blue.opacity(0.1))
                )
                .padding(.horizontal)
            }
            
            // Discovered Peers List
            if viewModel.isBrowsing {
                if viewModel.discoveredPeers.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Searching for nearby devices...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.discoveredPeers, id: \.id) { peer in
                                PeerRowView(peer: peer) {
                                    showingPINEntry = true
                                    viewModel.selectedPeer = peer
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            
            Spacer()
        }
        .padding(.top)
        .alert("Enter PIN", isPresented: $showingPINEntry) {
            TextField("6-digit PIN", text: $enteredPIN)
                .keyboardType(.numberPad)
            
            Button("Connect") {
                if let peer = viewModel.selectedPeer {
                    viewModel.connectToPeer(peer, pin: enteredPIN)
                }
                enteredPIN = ""
            }
            
            Button("Cancel", role: .cancel) {
                enteredPIN = ""
            }
        }
    }
}
