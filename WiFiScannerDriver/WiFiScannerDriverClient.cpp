//
//  WiFiScannerDriverClient.cpp
//  WiFiScannerDriver
//
//  Created by Svetoslav Karasev on 10.01.2024.
//

#include <stdio.h>
#include <cstring>
#include <stdlib.h>
#include <time.h>
#include <DriverKit/DriverKit.h>
#include "WiFiScannerDriverClient.h"
#include "../Common/Communication.h"

struct WiFiScannerDriverClient_IVars {
    OSAction* callbackAction = nullptr;
    IOBufferMemoryDescriptor* buffer = nullptr;
    size_t counter = 0;
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

    return ret;
}

kern_return_t IMPL(WiFiScannerDriverClient, Stop)
{
    IOLog("WiFiScannerDriverClient Stop");

    kern_return_t ret = Stop(provider, SUPERDISPATCH);

    return ret;
}

void WiFiScannerDriverClient::free(void)
{
    IOLog("WiFiScannerDriverClient free");

    OSSafeReleaseNULL(ivars->callbackAction);
    OSSafeReleaseNULL(ivars->buffer);
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

            ivars->counter++;
            BufferData bufferData = { .bytes = "hello", .size = ivars->counter };

            IOAddressSegment range = {};
            ret = ivars->buffer->GetAddressRange(&range);
            if (ret != kIOReturnSuccess) {
                IOLog("Failed to map buffer with error %s", IOService::StringFromReturn(ret));
                break;
            }

            memcpy(reinterpret_cast<void*>(range.address), &bufferData, sizeof(BufferData));

            CommunicationData* data = { };
            uint64_t asyncData[3] = { 2 };
            memcpy(asyncData + 1, &data, sizeof(CommunicationData));

            AsyncCompletion(ivars->callbackAction, kIOReturnSuccess, asyncData, 3);
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
