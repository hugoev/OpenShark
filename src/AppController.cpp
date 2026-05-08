#include "AppController.h"
#include <QTimer>

AppController::AppController(QObject *parent)
    : QObject(parent)
    , m_packets    (std::make_unique<PacketListModel>())
    , m_interfaces (std::make_unique<InterfaceListModel>())
    , m_networkMap (std::make_unique<NetworkMapModel>())
    , m_stats      (std::make_unique<StatsModel>())
{
    m_drainTimer = new QTimer(this);
    m_drainTimer->setInterval(33); // ~30 Hz
    connect(m_drainTimer, &QTimer::timeout, this, &AppController::onDrainTimer);
}

AppController::~AppController() { stopCapture(); }

void AppController::startCapture(const QString &iface, const QString &filter)
{
    if (m_capturing) return;

    m_capture = std::make_unique<PacketCapture>(iface.toStdString(), filter.toStdString());

    QString err;
    if (!m_capture->open(err)) {
        emit error(err);
        m_capture.reset();
        return;
    }

    m_activeInterface = iface;
    emit activeInterfaceChanged();
    m_capture->start();
    m_capturing = true;
    emit capturingChanged();
    m_drainTimer->start();
}

void AppController::stopCapture()
{
    if (!m_capturing) return;
    m_drainTimer->stop();
    if (m_capture) { m_capture->stop(); m_capture.reset(); }
    m_capturing = false;
    emit capturingChanged();
}

void AppController::clearPackets()
{
    m_packets->clear();
    m_networkMap->clear();
    m_stats->clear();
    m_packetCount = 0;
    emit packetCountChanged();
}

void AppController::setDisplayFilter(const QString &filter)
{
    m_packets->setDisplayFilter(filter);
}

void AppController::loadFile(const QString &path)
{
    QString err;
    auto packets = PcapFileIO::readPcap(path, err);
    if (!err.isEmpty()) { emit error(err); return; }
    if (packets.empty()) return;

    clearPackets();
    m_packets->appendBatch(packets);
    m_networkMap->ingestBatch(packets);
    m_stats->ingestBatch(packets);
    m_packetCount = packets.size();
    m_activeInterface = "File: " + path.section('/', -1);
    emit activeInterfaceChanged();
    emit packetCountChanged();
}

void AppController::saveCapture(const QString &path)
{
    const auto &pkts = m_packets->allPackets();
    if (pkts.empty()) { emit error("No packets to save"); return; }
    QString err;
    if (!PcapFileIO::writePcap(path, pkts, err))
        emit error(err);
}

void AppController::onDrainTimer()
{
    if (!m_capture) return;
    auto batch = m_capture->drain(512);
    if (batch.empty()) return;

    m_packets->appendBatch(batch);
    m_networkMap->ingestBatch(batch);
    m_stats->ingestBatch(batch);

    m_packetCount += batch.size();
    emit packetCountChanged();
}
