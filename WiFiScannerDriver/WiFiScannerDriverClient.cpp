//
//  WiFiScannerDriverClient.cpp
//  WiFiScannerDriver
//
//  Created by Svetoslav Karasev on 10.01.2024.
//

#include <stdio.h>
#include <cstring>
#include <stdlib.h>
#include <DriverKit/DriverKit.h>
#include "WiFiScannerDriverClient.h"
#include "WiFiScannerDriver.h"
#include "../Common/Communication.h"
#include "IOBufferMemoryDescriptorUtility.h"

struct WiFiScannerDriverClient_IVars {
    OSAction* callbackAction = nullptr;
    IOBufferMemoryDescriptor* buffer = nullptr;
    size_t counter = 0;
    uint16_t maxPacketSize = 64;

    WiFiScannerDriver* driver = nullptr;
};

bool WiFiScannerDriverClient::init(void)
{
    IOLog("WiFiScannerDriverClient:init");
    bool result = super::init();

    ivars = IONewZero(WiFiScannerDriverClient_IVars, 1);

    return result;
}

kern_return_t IMPL(WiFiScannerDriverClient, Start)
{
    IOLog("WiFiScannerDriverClient Start");

    kern_return_t ret = Start(provider, SUPERDISPATCH);

    ivars->driver = OSDynamicCast(WiFiScannerDriver, provider);

    ivars->driver->openDevice();
    ivars->maxPacketSize = ivars->driver->getMaxPacketSize();

    return ret;
}

kern_return_t IMPL(WiFiScannerDriverClient, Stop)
{
    IOLog("WiFiScannerDriverClient Stop");

    ivars->driver->closeDevice();

    kern_return_t ret = Stop(provider, SUPERDISPATCH);

    return ret;
}

void WiFiScannerDriverClient::free(void)
{
    IOLog("WiFiScannerDriverClient free");

    OSSafeReleaseNULL(ivars->callbackAction);
    OSSafeReleaseNULL(ivars->buffer);
    OSSafeReleaseNULL(ivars->driver);
    IOSafeDeleteNULL(ivars, WiFiScannerDriverClient_IVars, 1);

    super::free();
}

kern_return_t WiFiScannerDriverClient::ExternalMethod(uint64_t selector,
                                                      IOUserClientMethodArguments* arguments,
                                                      const IOUserClientMethodDispatch* dispatch,
                                                      OSObject* target,
                                                      void* reference)
{
    kern_return_t ret = kIOReturnSuccess;

    IOLog("WiFiScannerDriverClient ExternalMethod called with %llu", selector);

    switch (selector) {
        case MessageType_RegisterAsyncCallback:
        {
            ivars->callbackAction = arguments->completion;
            ivars->callbackAction->retain();
        } break;
        case MessageType_Scan:
        {
            sendScanRequest();

        } break;
        case MessageType_Read_Response:
        {
            readResponse();
        } break;
        default:
            break;
    }

    return ret;
}

kern_return_t IMPL(WiFiScannerDriverClient, CopyClientMemoryForType)
{
    IOLog("WiFiScannerDriverClient::CopyClientMemoryForType()");

    kern_return_t res;
    if (type == 0)
    {
        res = IOBufferMemoryDescriptor::Create(kIOMemoryDirectionInOut, sizeof(BufferData), 0, &ivars->buffer);
        if (res != kIOReturnSuccess)
        {
            IOLog("WiFiScannerDriverClient::CopyClientMemoryForType(): IOBufferMemoryDescriptor::Create failed: 0x%x", res);
        }
        else
        {
            ivars->buffer->retain();
            *memory = ivars->buffer; // returned with refcount 1
        }
    }
    else
    {
        res = this->CopyClientMemoryForType(type, options, memory, SUPERDISPATCH);
    }
    return res;
}

void WiFiScannerDriverClient::sendScanRequest()
{
    CommandType command = commandTypeSearch;
    uint8_t buf[] = { static_cast<uint8_t>(command) };
    OSData* sendData = OSData::withBytes(&buf, sizeof(buf));
    ivars->driver->writeToPipe(sendData);
    sendData->release();

    BufferData result = { .bytes = { 0 }, .size = 0 };
    callAsyncCompletion(&result);
}

void WiFiScannerDriverClient::readResponse()
{
    IOBufferMemoryDescriptor* readBuffer = nullptr;
    kern_return_t ret = IOBufferMemoryDescriptor::Create(kIOMemoryDirectionInOut, ivars->maxPacketSize, 0, &readBuffer);

    if (ret != kIOReturnSuccess) {
        IOLog("Can't create buffer");
        return;
    }

    uint32_t bytesRead = 0;
    BufferData result = { .bytes = {0}, .size = bytesRead };

    ret = ivars->driver->readFromPipe(readBuffer, &bytesRead);

    if (ret == kIOReturnSuccess) {
        IOBufferMemoryDescriptorUtility::readBytes(&result.bytes, bytesRead, &readBuffer);
        result.size = bytesRead;
    } else {
        result = { .bytes = {0}, .size = bytesRead };
    }
    readBuffer->release();

    callAsyncCompletion(&result);
}

void WiFiScannerDriverClient::callAsyncCompletion(void* result)
{
    IOAddressSegment range = {};
    ivars->buffer->GetAddressRange(&range);
    memcpy(reinterpret_cast<void*>(range.address), result, sizeof(BufferData));

    CommunicationData* data = { };
    uint64_t asyncData[3] = { 2 };
    memcpy(asyncData + 1, &data, sizeof(CommunicationData));
    AsyncCompletion(ivars->callbackAction, kIOReturnSuccess, asyncData, 3);
}
