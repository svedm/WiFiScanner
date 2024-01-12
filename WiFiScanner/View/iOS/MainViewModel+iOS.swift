//
//  MainViewModel.swift
//  WiFiScanner
//
//  Created by Svetoslav on 10.01.2024.
//

import UIKit
import OSLog

@MainActor
final class MainViewModel: ObservableObject {

    @Published var serviceAvailable = false
    @Published var networks: [WiFiNetwork] = []
    @Published var isScanning = false
    @Published var isConnected = false

    private let dextIdentifier = "net.svedm.WiFiScanner.WiFiScannerDriver"
    private let driverService = DriverService()

    func activateMyDext() {
        guard let url =  URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func connectToClient() {
        isConnected = driverService.connectToClient()
    }

    func communicate() async {
        isScanning = true
        networks = await self.driverService.scanForNetworks()
        isScanning = false
    }

    func disconnect() {
        driverService.disconnect()
        isConnected = false
    }

    func checkService() {
        serviceAvailable = driverService.isAvailable()
    }
}
