#pragma once
#include "DissectedPacket.h"
#include <cstddef>

class PacketDissector
{
public:
    // datalink: DLT_* value from pcap_datalink().  Defaults to DLT_EN10MB (1).
    static DissectedPacket dissect(uint64_t id, double ts,
                                   const uint8_t *data, uint32_t len,
                                   int datalink = 1);

private:
    // base = absolute byte offset of `data` within the full frame
    static void parseEthernet(DissectedPacket &pkt, const uint8_t *data, uint32_t len, uint32_t base);
    static void parseIPv4    (DissectedPacket &pkt, const uint8_t *data, uint32_t len, uint32_t base);
    static void parseIPv6    (DissectedPacket &pkt, const uint8_t *data, uint32_t len, uint32_t base);
    static void parseARP     (DissectedPacket &pkt, const uint8_t *data, uint32_t len, uint32_t base);
    static void parseTCP     (DissectedPacket &pkt, const uint8_t *data, uint32_t len, uint32_t base);
    static void parseUDP     (DissectedPacket &pkt, const uint8_t *data, uint32_t len, uint32_t base);
    static void parseICMP    (DissectedPacket &pkt, const uint8_t *data, uint32_t len, uint32_t base);
    static void parseDNS     (DissectedPacket &pkt, const uint8_t *data, uint32_t len, uint32_t base);
    static void parseHTTP    (DissectedPacket &pkt, const uint8_t *data, uint32_t len, uint32_t base);
    static void parseTLS     (DissectedPacket &pkt, const uint8_t *data, uint32_t len, uint32_t base);

    static std::string macToString (const uint8_t *b);
    static std::string ipv4ToString(const uint8_t *b);
    static std::string ipv6ToString(const uint8_t *b);
};
