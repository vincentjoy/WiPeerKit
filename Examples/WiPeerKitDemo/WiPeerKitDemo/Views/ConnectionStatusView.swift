//
//  ConnectionStatusView.swift
//  WiPeerKitDemo
//
//  Created by Vincent Joy on 29/08/25.
//

import SwiftUI
import WiPeerKit

struct ConnectionStatusView: View {
    @ObservedObject var viewModel: PeerViewModel
    
    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 2)
                        .scaleEffect(viewModel.isAnimating ? 2 : 1)
                        .opacity(viewModel.isAnimating ? 0 : 1)
                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: viewModel.isAnimating)
                )
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Security indicator
            if case WiPeerKit.ConnectionState.connected = viewModel.connectionState {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        )
    }
    
    private var statusColor: Color {
        switch viewModel.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .failed: return .red
        }
    }
    
    private var statusText: String {
        switch viewModel.connectionState {
        case .connected:
            return "Connected to \(viewModel.connectedPeerName ?? "peer")"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return viewModel.isAdvertising ? "Advertising" : (viewModel.isBrowsing ? "Browsing" : "Not connected")
        case .failed(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}
