//
//  wifi.h
//  WiFiScanner
//
//  Created by Svetoslav Karasev on 11.01.2024.
//

#ifndef wifi_h
#define wifi_h

typedef struct {
    uint8_t ssid[33];
    int8_t rssi;
} wifi_network;

#endif /* wifi_h */
