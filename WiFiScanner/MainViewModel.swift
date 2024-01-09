//
//  MainViewModel.swift
//  WiFiScanner
//
//  Created by Svetoslav on 10.01.2024.
//

import Foundation
import SystemExtensions

final class DriverLoadingStateMachine {

    enum State {
        case unloaded
        case activating
        case needsApproval
        case activated
        case activationError
        case checking
    }

    enum Event {
        case activationStarted
        case promptForApproval
        case activationFinished
        case activationFailed
        case checkStarted
        case propertiesFound
    }

    static func process(_ state: State, _ event: Event) -> State {

        switch state {
        case .unloaded:
            switch event {
            case .activationStarted:
                return .activating
            case .checkStarted:
                return .checking
            case .promptForApproval, .activationFinished, .activationFailed:
                return .activationError
            case .propertiesFound:
                return .activated
            }

        case .activating, .needsApproval:
            switch event {
            case .activationStarted:
                return .activating
            case .promptForApproval:
                return .needsApproval
            case .activationFinished:
                return .activated
            case .activationFailed:
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
            case .promptForApproval, .activationFailed:
                return .activationError
            case .activationFinished:
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
            case .promptForApproval, .activationFinished, .activationFailed:
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
            case .promptForApproval, .activationFinished:
                return .activationError
            case .activationFailed:
                return .unloaded
            case .checkStarted:
                return .checking
            case .propertiesFound:
                return .activated
            }
        }
    }
}

class MainViewModel: NSObject,ObservableObject  {

    // Your dext may not start in unloaded state every time. Add logic or states to check this.
    @Published var state: DriverLoadingStateMachine.State = .unloaded

    private let dextIdentifier: String = "net.svedm.WiFiScanner.WiFiScannerDriver"

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
        }
    }

    func activateMyDext() {
        activateExtension(dextIdentifier)
    }

    /// - Tag: ActivateExtension
    func activateExtension(_ dextIdentifier: String) {

        let request = OSSystemExtensionRequest
            .activationRequest(forExtensionWithIdentifier: dextIdentifier,
                               queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)

        state = DriverLoadingStateMachine.process(state, .activationStarted)
    }

    // This method isn't used in this example, but is provided for completeness.
    func deactivateExtension() {

        let request = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: dextIdentifier, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)

        // Update your state machine with deactivation states and process that change here
    }

    func checkDextState() {
        let request = OSSystemExtensionRequest
            .propertiesRequest(forExtensionWithIdentifier: dextIdentifier, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)

        state = DriverLoadingStateMachine.process(state, .checkStarted)
    }
}

extension MainViewModel: OSSystemExtensionRequestDelegate {

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {

        var replacementAction: OSSystemExtensionRequest.ReplacementAction

        print("sysex actionForReplacingExtension: %@ %@", existing, ext)

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

        print("sysex requestNeedsUserApproval")

        state = DriverLoadingStateMachine.process(state, .promptForApproval)
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {

        print("sysex didFinishWithResult: %d", result.rawValue)

        // The "result" may be "willCompleteAfterReboot", which would require another state.
        // This sample ignores this state for simplicity, but a production app should check for it.

        state = DriverLoadingStateMachine.process(state, .activationFinished)
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {

        print("sysex didFailWithError: %@", error.localizedDescription)

        // Some possible errors to check for:
        // Error 4: The dext identifier string in the code needs to match the one used in the project settings.
        // Error 8: Indicates a signing problem. During development, set signing to "automatic" and "sign to run locally". See README.md for more.

        // While this app only logs errors, production apps should provide feedback to customers about any errors encountered while loading the dext.

        state = DriverLoadingStateMachine.process(state, .activationFailed)
    }

    func request(_ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
        print("sysex foundProperties \(properties)")

        state = DriverLoadingStateMachine.process(state, !properties.isEmpty ? .propertiesFound : .activationFailed )
    }
}
