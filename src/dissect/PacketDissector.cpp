#include "PacketDissector.h"
#include <netinet/in.h>
#include <arpa/inet.h>
#include <cstring>
#include <format>

static constexpr uint16_t ETH_TYPE_IPv4 = 0x0800;
static constexpr uint16_t ETH_TYPE_IPv6 = 0x86DD;
static constexpr uint16_t ETH_TYPE_ARP  = 0x0806;
static constexpr uint8_t  IP_PROTO_ICMP = 1;
static constexpr uint8_t  IP_PROTO_TCP  = 6;
static constexpr uint8_t  IP_PROTO_UDP  = 17;
static constexpr uint8_t  IP_PROTO_ICMPv6 = 58;

static constexpr int DLT_NULL_BSD  = 0;   // BSD loopback (host-endian AF_*)
static constexpr int DLT_EN10MB   = 1;   // Ethernet
static constexpr int DLT_RAW_BSD  = 12;  // Raw IP (BSD)
static constexpr int DLT_LOOP     = 108; // OpenBSD loopback (big-endian AF_*)
static constexpr int DLT_RAW_LINUX= 101; // Raw IP (Linux)

DissectedPacket PacketDissector::dissect(uint64_t id, double ts,
                                         const uint8_t *data, uint32_t len,
                                         int datalink)
{
    DissectedPacket pkt;
    pkt.id          = id;
    pkt.timestamp   = ts;
    pkt.length      = len;
    pkt.raw.assign(data, data + len);
    pkt.topProtocol = Protocol::Unknown;

    switch (datalink) {
    case DLT_EN10MB:
        if (len >= 14) parseEthernet(pkt, data, len, 0);
        break;

    case DLT_NULL_BSD:
    case DLT_LOOP: {
        // 4-byte address-family header (host-endian for NULL, big-endian for LOOP)
        if (len < 5) break;
        uint32_t af;
        if (datalink == DLT_LOOP)
            af = (uint32_t(data[0])<<24)|(uint32_t(data[1])<<16)|(uint32_t(data[2])<<8)|data[3];
        else
            memcpy(&af, data, 4);
        if      (af == 2  && len >= 24) parseIPv4(pkt, data + 4, len - 4, 4);
        else if ((af == 24 || af == 28 || af == 30) && len >= 44)
                                        parseIPv6(pkt, data + 4, len - 4, 4);
        break;
    }

    case DLT_RAW_BSD:
    case DLT_RAW_LINUX:
        if (len < 1) break;
        if      ((data[0] >> 4) == 4 && len >= 20) parseIPv4(pkt, data, len, 0);
        else if ((data[0] >> 4) == 6 && len >= 40) parseIPv6(pkt, data, len, 0);
        break;

    default:
        // Unknown link type — try Ethernet as a best guess
        if (len >= 14) parseEthernet(pkt, data, len, 0);
        break;
    }

    return pkt;
}

void PacketDissector::parseEthernet(DissectedPacket &pkt, const uint8_t *data,
                                     uint32_t len, uint32_t base)
{
    Layer eth;
    eth.protocol   = Protocol::Ethernet;
    eth.label      = "Ethernet II";
    eth.baseOffset = base;

    pkt.dstMac = macToString(data);
    pkt.srcMac = macToString(data + 6);
    uint16_t etherType = (uint16_t(data[12]) << 8) | data[13];

    eth.fields.push_back({"Destination", pkt.dstMac,                          0,  6});
    eth.fields.push_back({"Source",      pkt.srcMac,                          6,  6});
    eth.fields.push_back({"EtherType",   std::format("0x{:04X}", etherType), 12,  2});
    pkt.layers.push_back(std::move(eth));

    const uint8_t *payload = data + 14;
    uint32_t       payLen  = len  - 14;
    uint32_t       payBase = base + 14;

    if      (etherType == ETH_TYPE_IPv4 && payLen >= 20) parseIPv4(pkt, payload, payLen, payBase);
    else if (etherType == ETH_TYPE_IPv6 && payLen >= 40) parseIPv6(pkt, payload, payLen, payBase);
    else if (etherType == ETH_TYPE_ARP  && payLen >= 28) parseARP (pkt, payload, payLen, payBase);
}

void PacketDissector::parseIPv4(DissectedPacket &pkt, const uint8_t *data,
                                 uint32_t len, uint32_t base)
{
    uint8_t  ihl      = (data[0] & 0x0F) * 4;
    uint8_t  dscp     = data[1] >> 2;
    uint16_t totalLen = (uint16_t(data[2]) << 8) | data[3];
    uint16_t id16     = (uint16_t(data[4]) << 8) | data[5];
    uint8_t  ttl      = data[8];
    uint8_t  proto    = data[9];
    uint16_t checksum = (uint16_t(data[10]) << 8) | data[11];

    pkt.srcIp = ipv4ToString(data + 12);
    pkt.dstIp = ipv4ToString(data + 16);

    Layer ip;
    ip.protocol   = Protocol::IPv4;
    ip.label      = "Internet Protocol Version 4";
    ip.baseOffset = base;
    ip.fields.push_back({"Version",         "4",                                   0, 1});
    ip.fields.push_back({"Header Length",   std::format("{} bytes", ihl),          0, 1});
    ip.fields.push_back({"DSCP",            std::to_string(dscp),                  1, 1});
    ip.fields.push_back({"Total Length",    std::to_string(totalLen),              2, 2});
    ip.fields.push_back({"Identification",  std::format("0x{:04X}", id16),         4, 2});
    ip.fields.push_back({"TTL",             std::to_string(ttl),                   8, 1});
    ip.fields.push_back({"Protocol",        std::to_string(proto),                 9, 1});
    ip.fields.push_back({"Checksum",        std::format("0x{:04X}", checksum),    10, 2});
    ip.fields.push_back({"Source",          pkt.srcIp,                            12, 4});
    ip.fields.push_back({"Destination",     pkt.dstIp,                            16, 4});
    pkt.layers.push_back(std::move(ip));

    if (ihl >= len) return;
    const uint8_t *transport = data + ihl;
    uint32_t       transLen  = len  - ihl;
    uint32_t       transBase = base + ihl;

    if      (proto == IP_PROTO_TCP  && transLen >= 20) parseTCP (pkt, transport, transLen, transBase);
    else if (proto == IP_PROTO_UDP  && transLen >= 8)  parseUDP (pkt, transport, transLen, transBase);
    else if (proto == IP_PROTO_ICMP && transLen >= 8)  parseICMP(pkt, transport, transLen, transBase);
}

void PacketDissector::parseIPv6(DissectedPacket &pkt, const uint8_t *data,
                                 uint32_t len, uint32_t base)
{
    uint8_t  nextHdr  = data[6];
    uint8_t  hopLimit = data[7];
    uint32_t flowLabel = ((uint32_t(data[1]) & 0x0F) << 16) |
                          (uint32_t(data[2]) << 8) | data[3];

    pkt.srcIp = ipv6ToString(data + 8);
    pkt.dstIp = ipv6ToString(data + 24);

    Layer ip;
    ip.protocol   = Protocol::IPv6;
    ip.label      = "Internet Protocol Version 6";
    ip.baseOffset = base;
    ip.fields.push_back({"Version",      "6",                                       0,  1});
    ip.fields.push_back({"Flow Label",   std::format("0x{:05X}", flowLabel),        1,  3});
    ip.fields.push_back({"Next Header",  std::to_string(nextHdr),                   6,  1});
    ip.fields.push_back({"Hop Limit",    std::to_string(hopLimit),                  7,  1});
    ip.fields.push_back({"Source",       pkt.srcIp,                                 8, 16});
    ip.fields.push_back({"Destination",  pkt.dstIp,                                24, 16});
    pkt.layers.push_back(std::move(ip));

    const uint8_t *transport = data + 40;
    uint32_t       transLen  = len  - 40;
    uint32_t       transBase = base + 40;

    if      (nextHdr == IP_PROTO_TCP    && transLen >= 20) parseTCP (pkt, transport, transLen, transBase);
    else if (nextHdr == IP_PROTO_UDP    && transLen >= 8)  parseUDP (pkt, transport, transLen, transBase);
    else if (nextHdr == IP_PROTO_ICMPv6 && transLen >= 8) {
        pkt.topProtocol = Protocol::ICMPv6;
        Layer l;
        l.protocol   = Protocol::ICMPv6;
        l.label      = "ICMPv6";
        l.baseOffset = transBase;
        l.fields.push_back({"Type", std::to_string(transport[0]), 0, 1});
        l.fields.push_back({"Code", std::to_string(transport[1]), 1, 1});
        l.fields.push_back({"Checksum", std::format("0x{:04X}", (uint16_t(transport[2])<<8)|transport[3]), 2, 2});
        pkt.layers.push_back(std::move(l));
    }
}

void PacketDissector::parseARP(DissectedPacket &pkt, const uint8_t *data,
                                uint32_t len, uint32_t base)
{
    uint16_t op = (uint16_t(data[6]) << 8) | data[7];
    Layer arp;
    arp.protocol   = Protocol::ARP;
    arp.label      = "Address Resolution Protocol";
    arp.baseOffset = base;
    arp.fields.push_back({"Hardware Type",   std::format("0x{:04X}", (uint16_t(data[0])<<8)|data[1]), 0, 2});
    arp.fields.push_back({"Protocol Type",   std::format("0x{:04X}", (uint16_t(data[2])<<8)|data[3]), 2, 2});
    arp.fields.push_back({"Operation",       op == 1 ? "Request" : "Reply",  6,  2});
    arp.fields.push_back({"Sender MAC",      macToString(data + 8),           8,  6});
    arp.fields.push_back({"Sender IP",       ipv4ToString(data + 14),        14,  4});
    arp.fields.push_back({"Target MAC",      macToString(data + 18),         18,  6});
    arp.fields.push_back({"Target IP",       ipv4ToString(data + 24),        24,  4});
    pkt.layers.push_back(std::move(arp));
    pkt.topProtocol = Protocol::ARP;
    pkt.srcIp = ipv4ToString(data + 14);
    pkt.dstIp = ipv4ToString(data + 24);
}

void PacketDissector::parseTCP(DissectedPacket &pkt, const uint8_t *data,
                                uint32_t len, uint32_t base)
{
    pkt.srcPort = (uint16_t(data[0]) << 8) | data[1];
    pkt.dstPort = (uint16_t(data[2]) << 8) | data[3];
    uint32_t seq        = (uint32_t(data[4])<<24)|(uint32_t(data[5])<<16)|(uint32_t(data[6])<<8)|data[7];
    uint32_t ack        = (uint32_t(data[8])<<24)|(uint32_t(data[9])<<16)|(uint32_t(data[10])<<8)|data[11];
    uint8_t  dataOffset = (data[12] >> 4) * 4;
    uint8_t  flags      = data[13];
    uint16_t window     = (uint16_t(data[14])<<8)|data[15];

    std::string flagStr;
    if (flags & 0x02) flagStr += "SYN ";
    if (flags & 0x10) flagStr += "ACK ";
    if (flags & 0x01) flagStr += "FIN ";
    if (flags & 0x04) flagStr += "RST ";
    if (flags & 0x08) flagStr += "PSH ";
    if (flags & 0x20) flagStr += "URG ";
    if (!flagStr.empty() && flagStr.back() == ' ') flagStr.pop_back();

    Layer tcp;
    tcp.protocol   = Protocol::TCP;
    tcp.label      = "Transmission Control Protocol";
    tcp.baseOffset = base;
    tcp.fields.push_back({"Source Port",      std::to_string(pkt.srcPort),           0, 2});
    tcp.fields.push_back({"Destination Port", std::to_string(pkt.dstPort),           2, 2});
    tcp.fields.push_back({"Sequence Number",  std::to_string(seq),                   4, 4});
    tcp.fields.push_back({"Ack Number",       std::to_string(ack),                   8, 4});
    tcp.fields.push_back({"Data Offset",      std::format("{} bytes", dataOffset),  12, 1});
    tcp.fields.push_back({"Flags",            flagStr,                               13, 1});
    tcp.fields.push_back({"Window",           std::to_string(window),               14, 2});
    pkt.tcpSeq = seq;
    pkt.layers.push_back(std::move(tcp));
    pkt.topProtocol = Protocol::TCP;

    if (dataOffset < len) {
        const uint8_t *app    = data + dataOffset;
        uint32_t       appLen = len  - dataOffset;
        uint32_t       appBase= base + dataOffset;
        pkt.tcpPayload.assign(app, app + appLen);

        if ((pkt.dstPort == 443 || pkt.srcPort == 443) && appLen >= 5)
            parseTLS(pkt, app, appLen, appBase);
        else if ((pkt.dstPort == 80 || pkt.srcPort == 80) && appLen > 4)
            parseHTTP(pkt, app, appLen, appBase);
    }
}

void PacketDissector::parseUDP(DissectedPacket &pkt, const uint8_t *data,
                                uint32_t len, uint32_t base)
{
    pkt.srcPort = (uint16_t(data[0]) << 8) | data[1];
    pkt.dstPort = (uint16_t(data[2]) << 8) | data[3];
    uint16_t udpLen  = (uint16_t(data[4]) << 8) | data[5];
    uint16_t chksum  = (uint16_t(data[6]) << 8) | data[7];

    Layer udp;
    udp.protocol   = Protocol::UDP;
    udp.label      = "User Datagram Protocol";
    udp.baseOffset = base;
    udp.fields.push_back({"Source Port",      std::to_string(pkt.srcPort),          0, 2});
    udp.fields.push_back({"Destination Port", std::to_string(pkt.dstPort),          2, 2});
    udp.fields.push_back({"Length",           std::to_string(udpLen),               4, 2});
    udp.fields.push_back({"Checksum",         std::format("0x{:04X}", chksum),      6, 2});
    pkt.layers.push_back(std::move(udp));
    pkt.topProtocol = Protocol::UDP;

    if ((pkt.dstPort == 53 || pkt.srcPort == 53) && len > 8)
        parseDNS(pkt, data + 8, len - 8, base + 8);
}

void PacketDissector::parseICMP(DissectedPacket &pkt, const uint8_t *data,
                                 uint32_t len, uint32_t base)
{
    static const char* typeNames[] = {
        "Echo Reply","","","Destination Unreachable","","","","","Echo Request",
        "Router Advertisement","Router Solicitation","Time Exceeded"
    };
    uint8_t  type    = data[0];
    uint8_t  code    = data[1];
    uint16_t chksum  = (uint16_t(data[2]) << 8) | data[3];

    Layer icmp;
    icmp.protocol   = Protocol::ICMP;
    icmp.label      = "Internet Control Message Protocol";
    icmp.baseOffset = base;
    std::string typeNameStr = (type < 12 && typeNames[type][0]) ? typeNames[type] : std::to_string(type);
    icmp.fields.push_back({"Type",     typeNameStr,                        0, 1});
    icmp.fields.push_back({"Code",     std::to_string(code),              1, 1});
    icmp.fields.push_back({"Checksum", std::format("0x{:04X}", chksum),   2, 2});
    if (type == 8 || type == 0) {
        uint16_t id  = (uint16_t(data[4]) << 8) | data[5];
        uint16_t seq = (uint16_t(data[6]) << 8) | data[7];
        icmp.fields.push_back({"Identifier",       std::to_string(id),  4, 2});
        icmp.fields.push_back({"Sequence Number",  std::to_string(seq), 6, 2});
    }
    pkt.layers.push_back(std::move(icmp));
    pkt.topProtocol = Protocol::ICMP;
}

void PacketDissector::parseDNS(DissectedPacket &pkt, const uint8_t *data,
                                uint32_t len, uint32_t base)
{
    if (len < 12) return;
    uint16_t txId    = (uint16_t(data[0]) << 8) | data[1];
    uint16_t flags   = (uint16_t(data[2]) << 8) | data[3];
    uint16_t qdCount = (uint16_t(data[4]) << 8) | data[5];
    uint16_t anCount = (uint16_t(data[6]) << 8) | data[7];
    bool     isReply = (flags >> 15) & 1;

    // Extract first query name
    std::string qname;
    uint32_t off = 12;
    while (off < len && data[off]) {
        uint8_t labelLen = data[off++];
        if (off + labelLen > len) break;
        if (!qname.empty()) qname += '.';
        qname.append(reinterpret_cast<const char*>(data + off), labelLen);
        off += labelLen;
    }

    Layer dns;
    dns.protocol   = Protocol::DNS;
    dns.label      = "Domain Name System";
    dns.baseOffset = base;
    dns.fields.push_back({"Transaction ID", std::format("0x{:04X}", txId),     0, 2});
    dns.fields.push_back({"Flags",          std::format("0x{:04X}", flags),    2, 2});
    dns.fields.push_back({"Type",           isReply ? "Response" : "Query",    2, 2});
    dns.fields.push_back({"Questions",      std::to_string(qdCount),           4, 2});
    dns.fields.push_back({"Answer RRs",     std::to_string(anCount),           6, 2});
    if (!qname.empty())
        dns.fields.push_back({"Query Name", qname, 12, uint32_t(off - 12)});
    pkt.layers.push_back(std::move(dns));
    pkt.topProtocol = Protocol::DNS;
}

void PacketDissector::parseHTTP(DissectedPacket &pkt, const uint8_t *data,
                                 uint32_t len, uint32_t base)
{
    std::string first;
    for (uint32_t i = 0; i < len && i < 256; ++i) {
        if (data[i] == '\r' || data[i] == '\n') break;
        first.push_back(char(data[i]));
    }
    if (first.empty()) return;

    Layer http;
    http.protocol   = Protocol::HTTP;
    http.label      = "Hypertext Transfer Protocol";
    http.baseOffset = base;
    http.fields.push_back({"First Line", first, 0, uint32_t(first.size())});

    // Parse headers
    uint32_t pos = uint32_t(first.size()) + 2; // skip first line + CRLF
    while (pos < len) {
        uint32_t lineStart = pos;
        while (pos < len && data[pos] != '\r' && data[pos] != '\n') pos++;
        if (pos == lineStart) break;
        std::string header(reinterpret_cast<const char*>(data + lineStart), pos - lineStart);
        auto colon = header.find(':');
        if (colon != std::string::npos) {
            std::string name  = header.substr(0, colon);
            std::string value = header.substr(colon + 2);
            if (name == "Host" || name == "Content-Type" || name == "Content-Length")
                http.fields.push_back({name, value, lineStart, uint32_t(pos - lineStart)});
        }
        if (pos < len && data[pos] == '\r') pos++;
        if (pos < len && data[pos] == '\n') pos++;
    }

    pkt.layers.push_back(std::move(http));
    pkt.topProtocol = Protocol::HTTP;
}

void PacketDissector::parseTLS(DissectedPacket &pkt, const uint8_t *data,
                                uint32_t len, uint32_t base)
{
    uint8_t contentType = data[0];
    uint8_t majorVer    = data[1];
    uint8_t minorVer    = data[2];

    const char* ctName = (contentType == 22) ? "Handshake"
                       : (contentType == 23) ? "Application Data"
                       : (contentType == 21) ? "Alert"
                       : (contentType == 20) ? "Change Cipher Spec"
                       :                       "Other";

    std::string tlsVer;
    if      (majorVer == 3 && minorVer == 1) tlsVer = "TLS 1.0";
    else if (majorVer == 3 && minorVer == 2) tlsVer = "TLS 1.1";
    else if (majorVer == 3 && minorVer == 3) tlsVer = "TLS 1.2";
    else if (majorVer == 3 && minorVer == 4) tlsVer = "TLS 1.3";
    else                                     tlsVer = std::format("{}.{}", majorVer, minorVer);

    Layer tls;
    tls.protocol   = Protocol::TLS;
    tls.label      = "Transport Layer Security";
    tls.baseOffset = base;
    tls.fields.push_back({"Content Type", ctName,  0, 1});
    tls.fields.push_back({"Version",      tlsVer,  1, 2});
    uint16_t recLen = (uint16_t(data[3]) << 8) | data[4];
    tls.fields.push_back({"Record Length", std::to_string(recLen), 3, 2});

    // SNI from ClientHello
    if (contentType == 22 && len > 9 && data[5] == 0x01) {
        tls.fields.push_back({"Handshake Type", "Client Hello", 5, 1});
        const uint8_t *hs = data + 9;
        uint32_t hsLen    = len  - 9;
        uint32_t o = 34; // skip version(2) + random(32)
        if (o < hsLen) {
            uint8_t sidLen = hs[o++];
            o += sidLen;
        }
        if (o + 2 <= hsLen) {
            uint16_t csLen = (uint16_t(hs[o]) << 8) | hs[o+1]; o += 2 + csLen;
        }
        if (o + 1 <= hsLen) { uint8_t cl = hs[o++]; o += cl; }
        if (o + 2 <= hsLen) {
            uint16_t extTotal = (uint16_t(hs[o]) << 8) | hs[o+1]; o += 2;
            uint32_t extEnd   = o + extTotal;
            while (o + 4 <= hsLen && o < extEnd) {
                uint16_t extType = (uint16_t(hs[o]) << 8) | hs[o+1];
                uint16_t extLen  = (uint16_t(hs[o+2]) << 8) | hs[o+3];
                o += 4;
                if (extType == 0x0000 && extLen > 5) {
                    uint16_t nameLen = (uint16_t(hs[o+3]) << 8) | hs[o+4];
                    if (o + 5 + nameLen <= hsLen) {
                        std::string sni(reinterpret_cast<const char*>(hs + o + 5), nameLen);
                        tls.fields.push_back({"SNI", sni,
                            uint32_t(hs + o + 5 - data),
                            nameLen});
                    }
                }
                o += extLen;
            }
        }
    } else if (contentType == 22 && len > 9 && data[5] == 0x02) {
        tls.fields.push_back({"Handshake Type", "Server Hello", 5, 1});
    }

    pkt.layers.push_back(std::move(tls));
    pkt.topProtocol = Protocol::TLS;
}

std::string PacketDissector::macToString(const uint8_t *b) {
    return std::format("{:02X}:{:02X}:{:02X}:{:02X}:{:02X}:{:02X}",
                       b[0],b[1],b[2],b[3],b[4],b[5]);
}

std::string PacketDissector::ipv4ToString(const uint8_t *b) {
    return std::format("{}.{}.{}.{}", b[0],b[1],b[2],b[3]);
}

std::string PacketDissector::ipv6ToString(const uint8_t *b) {
    char buf[64]; struct in6_addr a; memcpy(&a,b,16);
    inet_ntop(AF_INET6,&a,buf,sizeof(buf)); return buf;
}
