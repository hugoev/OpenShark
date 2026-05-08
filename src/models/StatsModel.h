#pragma once
#include <QObject>
#include <QVariantList>
#include <QHash>
#include <QString>
#include <deque>
#include <vector>
#include <cstdint>

#include "../dissect/DissectedPacket.h"

struct ThroughputSample {
    qint64  timestamp; // msec since epoch
    quint64 bytes;
    quint64 packets;
};

struct TopTalker {
    QString ip;
    quint64 packets;
    quint64 bytes;
};

class StatsModel : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList throughputSamples READ throughputSamples NOTIFY statsChanged)
    Q_PROPERTY(QVariantList protocolCounts    READ protocolCounts    NOTIFY statsChanged)
    Q_PROPERTY(QVariantList topTalkers        READ topTalkers        NOTIFY statsChanged)
    Q_PROPERTY(quint64 totalPackets READ totalPackets NOTIFY statsChanged)
    Q_PROPERTY(quint64 totalBytes   READ totalBytes   NOTIFY statsChanged)

public:
    explicit StatsModel(QObject *parent = nullptr);

    QVariantList throughputSamples() const;
    QVariantList protocolCounts()    const;
    QVariantList topTalkers()        const;

    quint64 totalPackets() const { return m_totalPackets; }
    quint64 totalBytes()   const { return m_totalBytes; }

    void ingestBatch(const std::vector<DissectedPacket> &batch);
    Q_INVOKABLE void clear();

signals:
    void statsChanged();

private:
    void flushCurrentSecond();

    static constexpr int WINDOW_SECS = 60;

    // Throughput — accumulated per second
    qint64  m_currentSecond = 0;
    quint64 m_secBytes   = 0;
    quint64 m_secPackets = 0;
    std::deque<ThroughputSample> m_samples; // last 60 seconds

    // Protocol breakdown
    QHash<QString, quint64> m_protoCount;

    // Top talkers
    QHash<QString, quint64> m_talkerBytes;
    QHash<QString, quint64> m_talkerPackets;

    quint64 m_totalPackets = 0;
    quint64 m_totalBytes   = 0;
};
