//
//  SettingsView.swift
//  WiPeerKitDemo
//
//  Created by Vincent Joy on 29/08/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: PeerViewModel
    @Environment(\.dismiss) var dismiss
    @State private var deviceName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Device") {
                    HStack {
                        Text("Device Name")
                        Spacer()
                        TextField("Name", text: $deviceName)
                            .multilineTextAlignment(.trailing)
                            .onAppear {
                                deviceName = viewModel.deviceName
                            }
                            .onSubmit {
                                viewModel.deviceName = deviceName
                            }
                    }
                    
                    HStack {
                        Text("Device ID")
                        Spacer()
                        Text(viewModel.deviceID)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Security") {
                    Picker("Authentication", selection: $viewModel.authMode) {
                        Text("PIN").tag(AuthMode.pin)
                        Text("Manual Approval").tag(AuthMode.manual)
                        Text("Trusted Only").tag(AuthMode.trusted)
                    }
                    
                    if viewModel.authMode == .trusted {
                        if viewModel.trustedDevices.isEmpty {
                            Text("No trusted devices")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(viewModel.trustedDevices, id: \.self) { device in
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundColor(.green)
                                    Text(device)
                                    Spacer()
                                    Button(action: { viewModel.removeTrustedDevice(device) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Framework")
                        Spacer()
                        Text("WiPeerKit 2.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
