#include "PacketCapture.h"
#include "../dissect/PacketDissector.h"
#include <QString>

PacketCapture::PacketCapture(std::string iface, std::string filter)
    : m_iface(std::move(iface)), m_filter(std::move(filter))
{}

PacketCapture::~PacketCapture()
{
    stop();
}

bool PacketCapture::open(QString &errorOut)
{
    char errbuf[PCAP_ERRBUF_SIZE];

    m_handle = pcap_open_live(m_iface.c_str(),
                              65535,  // snaplen — full frame
                              1,      // promiscuous
                              100,    // read timeout ms
                              errbuf);
    if (!m_handle) {
        errorOut = QString("pcap_open_live: %1").arg(errbuf);
        return false;
    }

    if (!m_filter.empty()) {
        struct bpf_program fp;
        if (pcap_compile(m_handle, &fp, m_filter.c_str(), 1, PCAP_NETMASK_UNKNOWN) < 0) {
            errorOut = QString("pcap_compile: %1").arg(pcap_geterr(m_handle));
            pcap_close(m_handle);
            m_handle = nullptr;
            return false;
        }
        if (pcap_setfilter(m_handle, &fp) < 0) {
            errorOut = QString("pcap_setfilter: %1").arg(pcap_geterr(m_handle));
            pcap_freecode(&fp);
            pcap_close(m_handle);
            m_handle = nullptr;
            return false;
        }
        pcap_freecode(&fp);
    }

    m_datalink = pcap_datalink(m_handle);
    return true;
}

void PacketCapture::start()
{
    m_running.store(true, std::memory_order_relaxed);
    m_thread = std::thread(&PacketCapture::captureLoop, this);
}

void PacketCapture::stop()
{
    if (!m_running.exchange(false)) return;
    if (m_handle) pcap_breakloop(m_handle);
    if (m_thread.joinable()) m_thread.join();
    if (m_handle) {
        pcap_close(m_handle);
        m_handle = nullptr;
    }
}

std::vector<DissectedPacket> PacketCapture::drain(std::size_t max)
{
    std::vector<DissectedPacket> out;
    out.reserve(max);
    m_ring.drain(out, max);
    return out;
}

void PacketCapture::captureLoop()
{
    pcap_loop(m_handle, 0, &PacketCapture::pcapCallback,
              reinterpret_cast<uint8_t*>(this));
}

void PacketCapture::pcapCallback(uint8_t *user,
                                  const struct pcap_pkthdr *header,
                                  const uint8_t *data)
{
    auto *self = reinterpret_cast<PacketCapture*>(user);
    if (!self->m_running.load(std::memory_order_relaxed)) return;

    uint64_t id = self->m_nextId.fetch_add(1, std::memory_order_relaxed);
    double   ts = double(header->ts.tv_sec) + double(header->ts.tv_usec) / 1e6;

    auto pkt = PacketDissector::dissect(id, ts, data, header->caplen, self->m_datalink);
    self->m_ring.push(std::move(pkt));
}
