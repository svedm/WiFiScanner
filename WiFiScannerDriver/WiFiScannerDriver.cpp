//
//  WiFiScannerDriver.cpp
//  WiFiScannerDriver
//
//  Created by Svetoslav on 10.01.2024.
//

#include <os/log.h>

#include <DriverKit/IOUserServer.h>
#include <DriverKit/IOLib.h>

#include "WiFiScannerDriver.h"

kern_return_t
IMPL(WiFiScannerDriver, Start)
{
    kern_return_t ret;
    ret = Start(provider, SUPERDISPATCH);
    IOLog("Hello World");
    return ret;
}
