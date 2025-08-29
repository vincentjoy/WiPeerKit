//
//  MessageBubble.swift
//  WiPeerKitDemo
//
//  Created by Vincent Joy on 29/08/25.
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isOutgoing {
                Spacer()
            }
            
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isOutgoing ? Color.blue : Color(.systemGray5))
                    )
                    .foregroundColor(message.isOutgoing ? .white : .primary)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: message.isOutgoing ? .trailing : .leading)
            
            if !message.isOutgoing {
                Spacer()
            }
        }
    }
}
