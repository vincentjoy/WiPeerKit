//
//  PeerRowView.swift
//  WiPeerKitDemo
//
//  Created by Vincent Joy on 29/08/25.
//

import SwiftUI
import WiPeerKit

struct PeerRowView: View {
    let peer: WiPeerKit.DiscoveredPeer
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "iphone")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(peer.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let host = peer.host {
                        Text("\(host):\(peer.port ?? 0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
