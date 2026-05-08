#pragma once
#include <cstdint>
#include <string>
#include <vector>

enum class Protocol : uint8_t {
    Unknown, Ethernet, ARP,
    IPv4, IPv6,
    TCP, UDP, ICMP, ICMPv6,
    DNS, HTTP, TLS
};

inline const char* protocolName(Protocol p) {
    switch (p) {
        case Protocol::ARP:    return "ARP";
        case Protocol::IPv4:   return "IPv4";
        case Protocol::IPv6:   return "IPv6";
        case Protocol::TCP:    return "TCP";
        case Protocol::UDP:    return "UDP";
        case Protocol::ICMP:   return "ICMP";
        case Protocol::ICMPv6: return "ICMPv6";
        case Protocol::DNS:    return "DNS";
        case Protocol::HTTP:   return "HTTP";
        case Protocol::TLS:    return "TLS";
        default:               return "???";
    }
}

struct LayerField {
    std::string name;
    std::string value;
    uint32_t    byteOffset;
    uint32_t    byteLength;
};

struct Layer {
    Protocol                protocol;
    std::string             label;
    uint32_t                baseOffset = 0; // byte offset of this layer from frame start
    std::vector<LayerField> fields;
};

struct DissectedPacket {
    uint64_t    id;
    double      timestamp;   // seconds since epoch
    std::string srcMac;
    std::string dstMac;
    std::string srcIp;
    std::string dstIp;
    uint16_t    srcPort = 0;
    uint16_t    dstPort = 0;
    Protocol    topProtocol = Protocol::Unknown;
    uint32_t    length = 0;
    uint32_t    tcpSeq = 0;
    bool        bookmarked = false;

    std::vector<Layer>        layers;
    std::vector<uint8_t>      raw;        // full frame bytes for hex view
    std::vector<uint8_t>      tcpPayload; // TCP application-layer payload
};
