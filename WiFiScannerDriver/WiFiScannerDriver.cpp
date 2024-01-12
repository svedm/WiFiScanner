//
//  WiFiScannerDriver.cpp
//  WiFiScannerDriver
//
//  Created by Svetoslav on 10.01.2024.
//

#include <os/log.h>

#include <DriverKit/IOUserServer.h>
#include <DriverKit/DriverKit.h>
#include <USBDriverKit/USBDriverKit.h>

#include "WiFiScannerDriver.h"
#include "IOBufferMemoryDescriptorUtility.h"

struct WiFiScannerDriver_IVars {
    IOUSBHostInterface* interface = nullptr;
    IOUSBHostPipe* inPipe = nullptr;
    IOUSBHostPipe* outPipe = nullptr;
    uint16_t inMaxPacketSize = 64;
};

bool WiFiScannerDriver::init(void)
{
    IOLog("WiFiScannerDriver::init");

    ivars = IONewZero(WiFiScannerDriver_IVars, 1);
    return super::init();
}

kern_return_t IMPL(WiFiScannerDriver, Start)
{
    IOLog("WiFiScannerDriver::Start");

    kern_return_t ret;
    ret = Start(provider, SUPERDISPATCH);

    if (ret != kIOReturnSuccess) {
        IOLog("WiFiScannerDriver start failed with error %s", IOService::StringFromReturn(ret));
        return ret;
    }

    
    ivars->interface = OSDynamicCast(IOUSBHostInterface, provider);

    ret = RegisterService();
    return ret;
}

kern_return_t IMPL(WiFiScannerDriver, Stop)
{
    IOLog("WiFiScannerDriver::Stop");
    kern_return_t ret = Stop(provider, SUPERDISPATCH);

    return ret;
}

void WiFiScannerDriver::free(void)
{
    IOLog("WiFiScannerDriver::free");

    OSSafeReleaseNULL(ivars->interface);
    OSSafeReleaseNULL(ivars->inPipe);
    OSSafeReleaseNULL(ivars->outPipe);
    IOSafeDeleteNULL(ivars, WiFiScannerDriver_IVars, 1);

    return super::free();
}

kern_return_t WiFiScannerDriver::openDevice()
{
    kern_return_t ret = kIOReturnSuccess;

    const IOUSBConfigurationDescriptor* cfg_descriptor = ivars->interface->CopyConfigurationDescriptor();
    const IOUSBInterfaceDescriptor* int_descriptor = ivars->interface->GetInterfaceDescriptor(cfg_descriptor);

    ret = ivars->interface->Open(this, 0, NULL);
    if (ret != kIOReturnSuccess) {
        IOLog("Open interface failed with %x", ret);
        return ret;
    }

    IOLog("Open interface success %x", ret);

    const IOUSBEndpointDescriptor* endpointDescriptor = NULL;

    while((endpointDescriptor = IOUSBGetNextEndpointDescriptor(
                                                               cfg_descriptor,
                                                               int_descriptor,
                                                               (IOUSBDescriptorHeader*)endpointDescriptor
                                                               )) != NULL)
    {
        if (endpointDescriptor->bEndpointAddress == 0x83) {
            IOLog("inPipe found");
            ret = ivars->interface->CopyPipe(endpointDescriptor->bEndpointAddress, &ivars->inPipe);
            ivars->inMaxPacketSize = endpointDescriptor->wMaxPacketSize;
        }
        if (endpointDescriptor->bEndpointAddress == 0x3) {
            IOLog("outPipe found");
            ret = ivars->interface->CopyPipe(endpointDescriptor->bEndpointAddress, &ivars->outPipe);
        }
    }

    return ret;
}

kern_return_t WiFiScannerDriver::closeDevice()
{
    kern_return_t ret = kIOReturnSuccess;

    ret = ivars->inPipe->Abort(kIOUSBAbortSynchronous, kIOReturnAborted, NULL);
    if (ret != kIOReturnSuccess) {
        IOLog("Close inPipe failed with %x", ret);
        return ret;
    }
    ret = ivars->outPipe->Abort(kIOUSBAbortSynchronous, kIOReturnAborted, NULL);
    if (ret != kIOReturnSuccess) {
        IOLog("Close outPipe failed with %x", ret);
        return ret;
    }
    ret = ivars->interface->Close(this, NULL);
    if (ret != kIOReturnSuccess) {
        IOLog("Close interface failed with %x", ret);
        return ret;
    }

    return ret;
}

kern_return_t WiFiScannerDriver::writeToPipe(OSData *data)
{
    kern_return_t ret = kIOReturnSuccess;
    IOMemoryDescriptor* memoryDescriptor = nullptr;
    IOBufferMemoryDescriptorUtility::createWithBytes(data->getBytesNoCopy(), data->getLength(), &memoryDescriptor);
    uint32_t bytesTransferred = 0;
    ret = ivars->outPipe->IO(memoryDescriptor, (uint32_t)data->getLength(), &bytesTransferred, 1000 * 3);
    memoryDescriptor->release();

    IOLog("writeToPipe ended with %s bytesTransferred: %d", IOService::StringFromReturn(ret), bytesTransferred);

    return ret;
}

kern_return_t WiFiScannerDriver::readFromPipe(IOMemoryDescriptor* buffer, uint32_t* bytesTransferred)
{
    kern_return_t ret = kIOReturnSuccess;
    uint64_t bufferLength = 0;
    buffer->GetLength(&bufferLength);

    *bytesTransferred = 0;
    ret = ivars->inPipe->IO(buffer, (uint32_t)bufferLength, bytesTransferred, 1000 * 3);

    IOLog("readFromPipe ended with %s bytesTransferred: %d", IOService::StringFromReturn(ret), *bytesTransferred);

    return ret;
}

uint16_t WiFiScannerDriver::getMaxPacketSize()
{
    return ivars->inMaxPacketSize;
}

kern_return_t IMPL(WiFiScannerDriver, NewUserClient)
{
    IOLog("WiFiScannerDriver NewUserClient");
    kern_return_t ret = kIOReturnSuccess;
    IOService* client = nullptr;

    ret = Create(this, "UserClientProperties", &client);
    if (ret != kIOReturnSuccess)
    {
        IOLog("NewUserClient() - Failed to create UserClientProperties with error: 0x%08x.", ret);
        return ret;
    }

    *userClient = OSDynamicCast(IOUserClient, client);
    if (*userClient == NULL)
    {
        IOLog("NewUserClient() - Failed to cast new client.");
        client->release();
        return kIOReturnError;
    }

    return ret;
}
