//
//  IOBufferMemoryDescriptorUtility.h
//  WiFiScanner
//
//  Created by Svetoslav Karasev on 10.01.2024.
//

#ifndef IOBufferMemoryDescriptorUtility_h
#define IOBufferMemoryDescriptorUtility_h

#pragma once

#include <DriverKit/DriverKit.h>
#include <DriverKit/IOBufferMemoryDescriptor.h>
#include <DriverKit/OSCollections.h>

namespace IOBufferMemoryDescriptorUtility {

inline kern_return_t createWithBytes(const void* bytes, size_t length, IOMemoryDescriptor** memory) {
  if (!bytes || !memory) {
    return kIOReturnBadArgument;
  }

  IOBufferMemoryDescriptor* m = nullptr;
  auto kr = IOBufferMemoryDescriptor::Create(kIOMemoryDirectionInOut, length, 0, &m);
  if (kr == kIOReturnSuccess) {
    uint64_t address;
    uint64_t len;
    m->Map(0, 0, 0, 0, &address, &len);

    if (length != len) {
      kr = kIOReturnNoMemory;
      goto error;
    }

    memcpy(reinterpret_cast<void*>(address), bytes, length);
  }

  *memory = m;

  return kr;

error:
  if (m) {
    OSSafeReleaseNULL(m);
  }

  return kr;
}

inline kern_return_t readBytes(void* readBuffer, size_t length, IOBufferMemoryDescriptor** mappedMemory)
{
    IOMemoryMap* map { nullptr };

    // Create mapping in caller's address space
    auto ret = (*mappedMemory)->CreateMapping(kIOMemoryMapReadOnly, 0, 0, length, 0, &map);

    if (ret != kIOReturnSuccess)
    {
        IOLog("IOBufferMemoryDescriptorUtility::readBytes Error in creating read memory map");
        goto exit;
    }

    // Integrity check
    if (map->GetLength() != length) {
        IOLog("IOBufferMemoryDescriptorUtility::readBytes Mapping length doesn't match");
        ret = kIOReturnNoMemory;
        goto exit;
    }

    // Fun part
    memcpy(readBuffer, reinterpret_cast<void*>(map->GetAddress()), map->GetLength());

exit:
    OSSafeReleaseNULL(map);
    return ret;
}

} // namespace IOBufferMemoryDescriptorUtility

#endif /* IOBufferMemoryDescriptorUtility_h */
