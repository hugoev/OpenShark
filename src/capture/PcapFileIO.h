#pragma once
#include <QString>
#include <vector>
#include "../dissect/DissectedPacket.h"

class PcapFileIO
{
public:
    // Read all packets from a .pcap file. Returns empty on error.
    static std::vector<DissectedPacket> readPcap(const QString &path, QString &errorOut);

    // Write packets to a .pcap file. Returns false on error.
    static bool writePcap(const QString &path,
                          const std::vector<DissectedPacket> &packets,
                          QString &errorOut);
};
