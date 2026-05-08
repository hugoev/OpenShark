#pragma once
#include <QObject>
#include <QVariantList>
#include <QHash>
#include <QString>
#include <vector>

#include "../dissect/DissectedPacket.h"

struct MapNode {
    QString  ip;
    QString  label;       // resolved hostname or IP
    quint64  packetCount = 0;
    quint64  bytesTotal  = 0;
    double   x = 0, y = 0;   // layout position (normalised 0-1)
    double   vx = 0, vy = 0; // velocity for force simulation
    bool     pinned = false;
};

struct MapEdge {
    QString  src, dst;
    quint64  packets = 0;
    quint64  bytes   = 0;
    double   bandwidth = 0.0; // bytes/sec EMA
    qint64   lastSeen  = 0;   // msec since epoch
};

class NetworkMapModel : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList nodes READ nodes NOTIFY graphChanged)
    Q_PROPERTY(QVariantList edges READ edges NOTIFY graphChanged)
    Q_PROPERTY(int nodeCount READ nodeCount NOTIFY graphChanged)

public:
    explicit NetworkMapModel(QObject *parent = nullptr);

    QVariantList nodes() const;
    QVariantList edges() const;
    int  nodeCount() const { return int(m_nodes.size()); }

    void ingestBatch(const std::vector<DissectedPacket> &batch);

    Q_INVOKABLE void pinNode(const QString &ip, double x, double y);
    Q_INVOKABLE void clear();

signals:
    void graphChanged();

private:
    void ensureNode(const QString &ip);
    QString edgeKey(const QString &a, const QString &b) const;

    QHash<QString, int>  m_nodeIndex; // ip → index in m_nodes
    std::vector<MapNode> m_nodes;

    QHash<QString, int>  m_edgeIndex; // key → index in m_edges
    std::vector<MapEdge> m_edges;
};
