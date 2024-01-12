//
//  WiFiNetwork.swift
//  WiFiScanner
//
//  Created by Svetoslav Karasev on 11.01.2024.
//

import Foundation

struct WiFiNetwork: Identifiable {
    var id: String {
        "\(ssid)\(rssi)"
    }

    let ssid: String
    let rssi: Int

    init(ssid: String, rssi: Int) {
        self.ssid = ssid
        self.rssi = rssi
    }

    init(network: wifi_network) {
        let ssidBytes = withUnsafeBytes(of: network) { [UInt8]($0) }
        ssid = String(cString: ssidBytes)
        rssi = Int(network.rssi)
    }
}
