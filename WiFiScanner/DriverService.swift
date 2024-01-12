//
//  DriverService.swift
//  WiFiScanner
//
//  Created by Svetoslav Karasev on 10.01.2024.
//

import Foundation
import OSLog

final class DriverService {
    private typealias NewDataAction = () -> Void

    private let serviceName = "WiFiScannerDriver"

    private var connection: io_connect_t = 0
    private var asyncRef: io_async_ref64_t = (0, 0, 0, 0, 0, 0, 0, 0)
    private var sharedMemoryAddress: mach_vm_address_t = 0
    private var sharedMemorySize: mach_vm_size_t = 0

    private let notificationPort = IONotificationPortCreate(kIOMainPortDefault)
    private lazy var machNotificationPort = IONotificationPortGetMachPort(notificationPort)
    private lazy var runLoopSource = IONotificationPortGetRunLoopSource(notificationPort)

    private var receivedData = Data()
    private var continuation: CheckedContinuation<[WiFiNetwork], Never>?

    // You can't use self from c callback
    private static var newDataNotifications: [NewDataAction] = []

    private lazy var asyncCallback: IOAsyncCallback = { (
        _ refcon: UnsafeMutableRawPointer?,
        _ result: IOReturn,
        _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
        _ numArgs: UInt32
    ) -> Void in
        Task.detached(priority: .userInitiated) {
            DriverService.newDataNotifications.forEach { $0() }
        }
    }

    init() {
        Self.newDataNotifications.append(readNewData)
    }

    deinit {
        Self.newDataNotifications = []
    }

    func isAvailable() -> Bool {
        IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching(serviceName)) != 0
    }

    func connectToClient() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching(serviceName))
        os_log("Service finding result %d", service)

        guard service != 0 else { return false }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)

        IOObjectRelease(service)

        print("Service opened with result \(String(cString: mach_error_string(result)))")

        guard result == kIOReturnSuccess else {
            return false
        }

        setupAsyncCommunication()
        registerAsyncCallback()
        setupSharedMemory()

        return true
    }

    func scanForNetworks() async -> [WiFiNetwork] {
        receivedData = .init()
        sendCommand(MessageType_Scan)

        return await withCheckedContinuation { [weak self] (continuation: CheckedContinuation<[WiFiNetwork], Never>) in
            self?.continuation = continuation
        }
    }

    func disconnect() {
        let result = IOServiceClose(connection)
        print("Service closed with result \(String(cString: mach_error_string(result)))")
    }

    private func setupAsyncCommunication() {
        let globalRunLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(globalRunLoop, runLoopSource?.takeUnretainedValue(), .defaultMode)

        withUnsafePointer(to: asyncCallback) { asyncPtr in
            asyncPtr.withMemoryRebound(
                to: io_user_reference_t.self,
                capacity: MemoryLayout<io_user_reference_t>.size
            ) { castedPtr in
                withUnsafeMutableBytes(of: &asyncRef) { ptr in
                    let ptr = ptr.baseAddress?.assumingMemoryBound(to: io_user_reference_t.self)
                    ptr?[kIOAsyncCalloutFuncIndex] = castedPtr.pointee
                }
            }
        }
    }

    private func registerAsyncCallback() {
        var inputStruct = CommunicationData()
        var outputStruct = CommunicationData()
        let inputSize = MemoryLayout<CommunicationData>.size
        var outputSize = MemoryLayout<CommunicationData>.size


        withUnsafeMutablePointer(to: &asyncRef) { ptr in
            ptr.withMemoryRebound(to: UInt64.self, capacity: MemoryLayout<UInt64>.size) { asyncPtr in
                let result = IOConnectCallAsyncStructMethod(
                    connection,
                    MessageType_RegisterAsyncCallback,
                    machNotificationPort,
                    asyncPtr,
                    UInt32(kIOAsyncCalloutCount),
                    &inputStruct,
                    inputSize,
                    &outputStruct,
                    &outputSize
                )

                os_log("IOConnectCallStructMethod with result: 0x%08x.\n", result);
            }
        }
    }

    private func setupSharedMemory() {
        let result = IOConnectMapMemory64(
            connection,
            0,
            mach_task_self_,
            &sharedMemoryAddress,
            &sharedMemorySize,
            kIOMapAnywhere
        )
        if result != kIOReturnSuccess {
            os_log("IOConnectMapMemory64 failed with \(String(cString: mach_error_string(result)))")
        }
    }

    private func sendCommand(_ command: UInt32) {
        var inputStruct = CommunicationData()
        let inputSize = MemoryLayout<CommunicationData>.size

        withUnsafeMutablePointer(to: &asyncRef) { ptr in
            ptr.withMemoryRebound(to: UInt64.self, capacity: MemoryLayout<UInt64>.size) { asyncPtr in
                let result = IOConnectCallAsyncStructMethod(
                    connection,
                    command,
                    machNotificationPort,
                    asyncPtr,
                    UInt32(kIOAsyncCalloutCount),
                    &inputStruct,
                    inputSize,
                    nil,
                    nil
                )

                os_log("IOConnectCallStructMethod with result: \(String(cString: mach_error_string(result)))");
            }
        }
    }

    private func readNewData() {
        guard 
            var sharedMemoryData = UnsafeMutablePointer<BufferData>(bitPattern: Int(sharedMemoryAddress))?.pointee
        else { return }

        os_log("\(sharedMemoryData.size) bytes received")

        var last = false

        if sharedMemoryData.size != 0 {
            let array = withUnsafeBytes(of: &sharedMemoryData.bytes) { buf in
                [UInt8](buf)
            }
            last = array[sharedMemoryData.size-1 ] == 0b11111111 // stop byte
            let size = last ? sharedMemoryData.size - 1 : sharedMemoryData.size

            receivedData.append(contentsOf: Array(array[0..<size]))
        }

        if !last {
            sendCommand(MessageType_Read_Response)
        } else {
            let networksList = receivedData.withUnsafeBytes { ptr in
                ptr.bindMemory(to: wifi_network.self)
            }.compactMap { WiFiNetwork(network: $0) }

            continuation?.resume(with: .success(networksList))
        }
    }
}

