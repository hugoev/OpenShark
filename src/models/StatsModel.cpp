#include "StatsModel.h"
#include <QDateTime>
#include <QVariantMap>
#include <algorithm>

StatsModel::StatsModel(QObject *parent) : QObject(parent)
{
    m_currentSecond = QDateTime::currentSecsSinceEpoch();
}

void StatsModel::ingestBatch(const std::vector<DissectedPacket> &batch)
{
    if (batch.empty()) return;

    qint64 nowSec = QDateTime::currentSecsSinceEpoch();
    if (nowSec != m_currentSecond) {
        flushCurrentSecond();
        m_currentSecond = nowSec;
        m_secBytes = m_secPackets = 0;
    }

    for (const auto &pkt : batch) {
        m_secBytes   += pkt.length;
        m_secPackets += 1;
        m_totalBytes   += pkt.length;
        m_totalPackets += 1;

        QString proto(protocolName(pkt.topProtocol));
        m_protoCount[proto]++;

        if (!pkt.srcIp.empty()) {
            QString src = QString::fromStdString(pkt.srcIp);
            m_talkerBytes  [src] += pkt.length;
            m_talkerPackets[src]++;
        }
    }

    emit statsChanged();
}

void StatsModel::flushCurrentSecond()
{
    if (m_secPackets == 0) return;
    ThroughputSample s;
    s.timestamp = m_currentSecond * 1000;
    s.bytes     = m_secBytes;
    s.packets   = m_secPackets;
    m_samples.push_back(s);
    while (int(m_samples.size()) > WINDOW_SECS)
        m_samples.pop_front();
}

QVariantList StatsModel::throughputSamples() const
{
    QVariantList out;
    for (const auto &s : m_samples) {
        QVariantMap m;
        m["timestamp"] = s.timestamp;
        m["bytes"]     = quint64(s.bytes);
        m["packets"]   = quint64(s.packets);
        out.append(m);
    }
    return out;
}

QVariantList StatsModel::protocolCounts() const
{
    // Sort by count descending
    QVector<QPair<QString,quint64>> sorted;
    for (auto it = m_protoCount.begin(); it != m_protoCount.end(); ++it)
        sorted.append({it.key(), it.value()});
    std::sort(sorted.begin(), sorted.end(),
              [](const auto &a, const auto &b){ return a.second > b.second; });

    QVariantList out;
    for (const auto &[name, count] : sorted) {
        QVariantMap m;
        m["protocol"] = name;
        m["count"]    = quint64(count);
        out.append(m);
    }
    return out;
}

QVariantList StatsModel::topTalkers() const
{
    QVector<QPair<QString,quint64>> sorted;
    for (auto it = m_talkerBytes.begin(); it != m_talkerBytes.end(); ++it)
        sorted.append({it.key(), it.value()});
    std::sort(sorted.begin(), sorted.end(),
              [](const auto &a, const auto &b){ return a.second > b.second; });

    QVariantList out;
    int limit = qMin(int(sorted.size()), 10);
    for (int i = 0; i < limit; ++i) {
        QVariantMap m;
        m["ip"]      = sorted[i].first;
        m["bytes"]   = quint64(sorted[i].second);
        m["packets"] = quint64(m_talkerPackets.value(sorted[i].first, 0));
        out.append(m);
    }
    return out;
}

void StatsModel::clear()
{
    m_samples.clear();
    m_protoCount.clear();
    m_talkerBytes.clear();
    m_talkerPackets.clear();
    m_totalPackets = m_totalBytes = 0;
    m_secBytes = m_secPackets = 0;
    emit statsChanged();
}
