//
//  Communication.h
//  WiFiScanner
//
//  Created by Svetoslav Karasev on 10.01.2024.
//

#ifndef Communication_h
#define Communication_h

const uint32_t MessageType_RegisterAsyncCallback = 0;
const uint32_t MessageType_Scan = 1;
const uint32_t MessageType_Read_Response = 2;

typedef struct {
} CommunicationData;

typedef enum {
    commandTypeSearch = 1
} CommandType;

typedef struct {
    uint8_t bytes[64];
    size_t size;
} BufferData;

#endif /* Communication_h */
