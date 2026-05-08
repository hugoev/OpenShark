#include "PcapFileIO.h"
#include "../dissect/PacketDissector.h"
#include <pcap.h>
#include <cstring>

std::vector<DissectedPacket> PcapFileIO::readPcap(const QString &path, QString &errorOut)
{
    char errbuf[PCAP_ERRBUF_SIZE];
    pcap_t *handle = pcap_open_offline(path.toUtf8().constData(), errbuf);
    if (!handle) {
        errorOut = QString("Cannot open file: %1").arg(errbuf);
        return {};
    }

    std::vector<DissectedPacket> packets;
    uint64_t id = 1;
    struct pcap_pkthdr *header;
    const uint8_t     *data;
    int rc;

    int datalink = pcap_datalink(handle);
    while ((rc = pcap_next_ex(handle, &header, &data)) == 1) {
        double ts = double(header->ts.tv_sec) + double(header->ts.tv_usec) / 1e6;
        packets.push_back(PacketDissector::dissect(id++, ts, data, header->caplen, datalink));
    }

    if (rc == -1)
        errorOut = QString("Read error: %1").arg(pcap_geterr(handle));

    pcap_close(handle);
    return packets;
}

bool PcapFileIO::writePcap(const QString &path,
                            const std::vector<DissectedPacket> &packets,
                            QString &errorOut)
{
    char errbuf[PCAP_ERRBUF_SIZE];
    pcap_t *dead = pcap_open_dead(DLT_EN10MB, 65535);
    if (!dead) { errorOut = "pcap_open_dead failed"; return false; }

    pcap_dumper_t *dumper = pcap_dump_open(dead, path.toUtf8().constData());
    if (!dumper) {
        errorOut = QString("Cannot write file: %1").arg(pcap_geterr(dead));
        pcap_close(dead);
        return false;
    }

    for (const auto &pkt : packets) {
        struct pcap_pkthdr hdr;
        memset(&hdr, 0, sizeof(hdr));
        hdr.ts.tv_sec  = time_t(pkt.timestamp);
        hdr.ts.tv_usec = suseconds_t((pkt.timestamp - double(hdr.ts.tv_sec)) * 1e6);
        hdr.caplen = hdr.len = uint32_t(pkt.raw.size());
        pcap_dump(reinterpret_cast<u_char*>(dumper), &hdr, pkt.raw.data());
    }

    pcap_dump_close(dumper);
    pcap_close(dead);
    return true;
}
