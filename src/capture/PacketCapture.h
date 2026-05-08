#pragma once
#include <string>
#include <thread>
#include <atomic>
#include <vector>
#include <pcap.h>

#include <QString>
#include "RingBuffer.h"
#include "../dissect/DissectedPacket.h"

class PacketCapture
{
public:
    PacketCapture(std::string iface, std::string filter);
    ~PacketCapture();

    bool open(QString &errorOut);
    void start();
    void stop();

    // Drain up to `max` dissected packets into caller's vector.
    std::vector<DissectedPacket> drain(std::size_t max);

private:
    static void pcapCallback(uint8_t *user,
                              const struct pcap_pkthdr *header,
                              const uint8_t *data);
    void captureLoop();

    std::string m_iface;
    std::string m_filter;

    pcap_t     *m_handle   = nullptr;
    int         m_datalink = 1; // DLT_EN10MB default
    std::thread m_thread;
    std::atomic<bool> m_running{false};
    std::atomic<uint64_t> m_nextId{1};

    static constexpr std::size_t BufCap = 1u << 16; // 65536 slots
    RingBuffer<DissectedPacket, BufCap> m_ring;
};
