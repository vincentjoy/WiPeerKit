//
//  ContentView.swift
//  WiPeerKitDemo
//
//  Created by Vincent Joy on 29/08/25.
//

import SwiftUI

#if canImport(WiPeerKit)
    #warning("WiPeerKit CAN be imported")
#else
    #error("WiPeerKit CANNOT be imported")
#endif

import WiPeerKit

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
