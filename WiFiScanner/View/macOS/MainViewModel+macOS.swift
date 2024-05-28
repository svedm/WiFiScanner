//
//  MainViewModel.swift
//  WiFiScanner
//
//  Created by Svetoslav on 10.01.2024.
//

import Foundation
import SystemExtensions
import OSLog

final class DriverLoadingStateMachine {

    enum State {
        case unloaded
        case activating
        case deactivating
        case needsApproval
        case activated
        case activationError
        case checking
    }

    enum Event {
        case activationStarted
        case promptForApproval
        case requestFinished
        case requestFailed
        case checkStarted
        case propertiesFound
        case deactivationStarted
    }

    static func process(_ state: State, _ event: Event) -> State {

        switch state {
        case .unloaded:
            switch event {
            case .activationStarted:
                return .activating
            case .deactivationStarted:
                return .deactivating
            case .checkStarted:
                return .checking
            case .promptForApproval, .requestFinished, .requestFailed:
                return .activationError
            case .propertiesFound:
                return .activated
            }

        case .activating, .needsApproval:
            switch event {
            case .activationStarted:
                return .activating
            case .deactivationStarted:
                return .deactivating
            case .promptForApproval:
                return .needsApproval
            case .requestFinished:
                return .activated
            case .requestFailed:
                return .activationError
            case .checkStarted:
                return .checking
            case .propertiesFound:
                return .activated
            }
        case .deactivating:
            switch event {
            case .activationStarted:
                return .activating
            case .deactivationStarted:
                return .deactivating
            case .promptForApproval:
                return .needsApproval
            case .requestFinished:
                return .unloaded
            case .requestFailed:
                return .activationError
            case .checkStarted:
                return .checking
            case .propertiesFound:
                return .activated
            }

        case .activated:
            switch event {
            case .activationStarted:
                return .activating
            case .deactivationStarted:
                return .deactivating
            case .promptForApproval, .requestFailed:
                return .activationError
            case .requestFinished:
                return .activated
            case .checkStarted:
                return .checking
            case .propertiesFound:
                return .activated
            }

        case .activationError:
            switch event {
            case .activationStarted:
                return .activating
            case .deactivationStarted:
                return .deactivating
            case .promptForApproval, .requestFinished, .requestFailed:
                return .activationError
            case .checkStarted:
                return .checking
            case .propertiesFound:
                return .activated
            }

        case .checking:
            switch event {
            case .activationStarted:
                return .activating
            case .deactivationStarted:
                return .deactivating
            case .promptForApproval, .requestFinished:
                return .activationError
            case .requestFailed:
                return .unloaded
            case .checkStarted:
                return .checking
            case .propertiesFound:
                return .activated
            }
        }
    }
}

@MainActor
final class MainViewModel: NSObject, ObservableObject {

    // Your dext may not start in unloaded state every time. Add logic or states to check this.
    @Published var state: DriverLoadingStateMachine.State = .unloaded
    @Published var connected = false
    @Published var networks: [WiFiNetwork] = []
    @Published var isScanning = false

    private let dextIdentifier = "net.svedm.WiFiScanner.WiFiScannerDriver"
    private let driverService = DriverService()

    public var dextLoadingState: String {
        switch state {
        case .unloaded:
            return "WiFiScannerDriver isn't loaded."
        case .activating:
            return "Activating driver, please wait."
        case .needsApproval:
            return "Please follow the prompt to approve driver."
        case .activated:
            return "driver has been activated and is ready to use."
        case .activationError:
            return "driver has experienced an error during activation.\nPlease check the logs to find the error."
        case .checking:
            return "Trying to find driver in system"
        case .deactivating:
            return "Deactivating driver"
        }
    }

    override init() {
        super.init()
    }

    func activateMyDext() {
        activateExtension(dextIdentifier)
    }

    /// - Tag: ActivateExtension
    func activateExtension(_ dextIdentifier: String) {

        let request = OSSystemExtensionRequest
            .activationRequest(forExtensionWithIdentifier: dextIdentifier, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)

        state = DriverLoadingStateMachine.process(state, .activationStarted)
    }

    func deactivateExtension() {

        let request = OSSystemExtensionRequest
            .deactivationRequest(forExtensionWithIdentifier: dextIdentifier, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)

        state = DriverLoadingStateMachine.process(state, .deactivationStarted)

        // Update your state machine with deactivation states and process that change here
    }

    func checkDextState() {
        let request = OSSystemExtensionRequest
            .propertiesRequest(forExtensionWithIdentifier: dextIdentifier, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)

        state = DriverLoadingStateMachine.process(state, .checkStarted)
    }

    func connectToClient() {
        connected = driverService.connectToClient()
    }

    func communicate() async {
        isScanning = true
        networks = await self.driverService.scanForNetworks()
        isScanning = false
    }

    func disconnect() {
        driverService.disconnect()
        connected = false
    }
}

extension MainViewModel: OSSystemExtensionRequestDelegate {

    func request(
        _ request: OSSystemExtensionRequest,
         actionForReplacingExtension existing: OSSystemExtensionProperties,
         withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {

        var replacementAction: OSSystemExtensionRequest.ReplacementAction

        os_log("sysex actionForReplacingExtension: %@ %@", existing, ext)

        // Add appropriate logic here to determine if the extension should be
        // replaced by the new extension. Common things to check for include
        // testing whether the new extension's version number is newer than
        // the current version number, or that the bundleIdentifier has changed.
        // For simplicity, this sample always replaces the current extension
        // with the new one.
        replacementAction = .replace

        // The upgrade case may require a separate set of states.
        state = DriverLoadingStateMachine.process(state, .activationStarted)

        return replacementAction
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        os_log("sysex requestNeedsUserApproval")

        state = DriverLoadingStateMachine.process(state, .promptForApproval)
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        os_log("sysex didFinishWithResult: %d", result.rawValue)

        // The "result" may be "willCompleteAfterReboot", which would require another state.
        // This sample ignores this state for simplicity, but a production app should check for it.

        state = DriverLoadingStateMachine.process(state, .requestFinished)
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        os_log("sysex didFailWithError: %@", error.localizedDescription)

        // Some possible errors to check for:
        // Error 4: The dext identifier string in the code needs to match the one used in the project settings.
        // Error 8: Indicates a signing problem. During development, set signing to "automatic" and "sign to run locally". See README.md for more.

        // While this app only logs errors, production apps should provide feedback to customers about any errors encountered while loading the dext.

        state = DriverLoadingStateMachine.process(state, .requestFailed)
    }

    func request(_ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
        os_log("sysex foundProperties \(properties)")

        state = DriverLoadingStateMachine.process(state, !properties.isEmpty ? .propertiesFound : .requestFailed )
    }
}
