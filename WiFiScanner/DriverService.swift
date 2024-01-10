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

    private let notificationPort = IONotificationPortCreate(kIOMainPortDefault)
    private lazy var machNotificationPort = IONotificationPortGetMachPort(notificationPort)
    private lazy var runLoopSource = IONotificationPortGetRunLoopSource(notificationPort)

    // You can't use self from c callback
    private static var newDataNotifications: [NewDataAction] = []

    private lazy var asyncCallback: IOAsyncCallback = { (
        _ refcon: UnsafeMutableRawPointer?,
        _ result: IOReturn,
        _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
        _ numArgs: UInt32
    ) -> Void in
        DriverService.newDataNotifications.forEach { $0() }
    }

    init() {
        Self.newDataNotifications.append(readNewData)
    }

    deinit {
        Self.newDataNotifications = []
    }


    func connectToClient() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching(serviceName))
        os_log("Service finding result %d", service)

        guard service != 0 else { return false }

        var result = IOServiceOpen(service, mach_task_self_, 0, &connection)

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

    func communicate() {
        getDataFromDriver()
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
        var memSize: mach_vm_size_t = 0
        let result = IOConnectMapMemory64(
            connection,
            0,
            mach_task_self_,
            &sharedMemoryAddress,
            &memSize,
            kIOMapAnywhere
        )
        if result != kIOReturnSuccess {
            os_log("IOConnectMapMemory64 failed with \(String(cString: mach_error_string(result)))")
        }
    }

    private func getDataFromDriver() {
        var inputStruct = CommunicationData()
        let inputSize = MemoryLayout<CommunicationData>.size

        withUnsafeMutablePointer(to: &asyncRef) { ptr in
            ptr.withMemoryRebound(to: UInt64.self, capacity: MemoryLayout<UInt64>.size) { asyncPtr in
                let result = IOConnectCallAsyncStructMethod(
                    connection,
                    MessageType_Scan,
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
        let ptr = UnsafeMutablePointer<BufferData>(bitPattern: Int(sharedMemoryAddress))
        print("Received count: \(ptr?.pointee.size)")
    }
}
