//
//  WiFiScannerDriverClient.cpp
//  WiFiScannerDriver
//
//  Created by Svetoslav Karasev on 10.01.2024.
//

#include <stdio.h>
#include <DriverKit/DriverKit.h>
#include "WiFiScannerDriverClient.h"

bool WiFiScannerDriverClient::init(void)
{
    IOLog("WiFiScannerDriverClient:init");
    bool result = super::init();
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

    super::free();
}
