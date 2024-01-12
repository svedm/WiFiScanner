//
//  NetworkListItem.swift
//  WiFiScanner
//
//  Created by Svetoslav Karasev on 12.01.2024.
//

import SwiftUI

struct NetworkListItem: View {
    let network: WiFiNetwork

    var body: some View {
        VStack(alignment: .leading) {
            Text(network.ssid)
                .font(.title2)
            Text("rssi: \(network.rssi)dBm")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }
}

#Preview {
    NetworkListItem(network: .init(ssid: "Olololo", rssi: -30))
        .frame(width: 200, height: 50)
}
