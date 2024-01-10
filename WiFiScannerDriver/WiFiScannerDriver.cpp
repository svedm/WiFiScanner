//
//  WiFiScannerDriver.cpp
//  WiFiScannerDriver
//
//  Created by Svetoslav on 10.01.2024.
//

#include <os/log.h>

#include <DriverKit/IOUserServer.h>
#include <DriverKit/DriverKit.h>

#include "WiFiScannerDriver.h"

kern_return_t IMPL(WiFiScannerDriver, Start)
{
    kern_return_t ret;
    ret = Start(provider, SUPERDISPATCH);

    if (ret != kIOReturnSuccess) {
        IOLog("WiFiScannerDriver start failed with error %s", IOService::StringFromReturn(ret));
        return ret;
    }

    IOLog("Hello World");

    ret = RegisterService();
    return ret;
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
