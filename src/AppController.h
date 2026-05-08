#pragma once
#include <QObject>
#include <QString>
#include <QTimer>
#include <memory>

#include "capture/PacketCapture.h"
#include "capture/PcapFileIO.h"
#include "models/PacketListModel.h"
#include "models/InterfaceListModel.h"
#include "models/NetworkMapModel.h"
#include "models/StatsModel.h"

class AppController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(PacketListModel*    packets    READ packets    CONSTANT)
    Q_PROPERTY(InterfaceListModel* interfaces READ interfaces CONSTANT)
    Q_PROPERTY(NetworkMapModel*    networkMap READ networkMap CONSTANT)
    Q_PROPERTY(StatsModel*         stats      READ stats      CONSTANT)
    Q_PROPERTY(bool     capturing       READ capturing       NOTIFY capturingChanged)
    Q_PROPERTY(quint64  packetCount     READ packetCount     NOTIFY packetCountChanged)
    Q_PROPERTY(QString  activeInterface READ activeInterface NOTIFY activeInterfaceChanged)

public:
    explicit AppController(QObject *parent = nullptr);
    ~AppController() override;

    PacketListModel*    packets()    const { return m_packets.get(); }
    InterfaceListModel* interfaces() const { return m_interfaces.get(); }
    NetworkMapModel*    networkMap() const { return m_networkMap.get(); }
    StatsModel*         stats()      const { return m_stats.get(); }

    bool     capturing()       const { return m_capturing; }
    quint64  packetCount()     const { return m_packetCount; }
    QString  activeInterface() const { return m_activeInterface; }

public slots:
    void startCapture(const QString &iface, const QString &filter = {});
    void stopCapture();
    void clearPackets();
    void setDisplayFilter(const QString &filter);
    void loadFile(const QString &path);
    void saveCapture(const QString &path);

signals:
    void capturingChanged();
    void packetCountChanged();
    void activeInterfaceChanged();
    void error(const QString &message);

private:
    void onDrainTimer();

    std::unique_ptr<PacketCapture>      m_capture;
    std::unique_ptr<PacketListModel>    m_packets;
    std::unique_ptr<InterfaceListModel> m_interfaces;
    std::unique_ptr<NetworkMapModel>    m_networkMap;
    std::unique_ptr<StatsModel>         m_stats;

    bool    m_capturing       = false;
    quint64 m_packetCount     = 0;
    QString m_activeInterface;

    QTimer *m_drainTimer = nullptr;
};
