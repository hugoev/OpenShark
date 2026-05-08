#include "NetworkMapModel.h"
#include <QDateTime>
#include <QRandomGenerator>
#include <QVariantMap>
#include <cmath>

NetworkMapModel::NetworkMapModel(QObject *parent) : QObject(parent) {}

void NetworkMapModel::ingestBatch(const std::vector<DissectedPacket> &batch)
{
    if (batch.empty()) return;
    bool changed = false;

    for (const auto &pkt : batch) {
        if (pkt.srcIp.empty() || pkt.dstIp.empty()) continue;

        QString src = QString::fromStdString(pkt.srcIp);
        QString dst = QString::fromStdString(pkt.dstIp);

        // Skip link-local / multicast noise
        if (src.startsWith("224.") || src.startsWith("239.") ||
            src.startsWith("ff")   || dst.startsWith("224.") ||
            dst.startsWith("239.") || dst.startsWith("ff"))
            continue;

        ensureNode(src);
        ensureNode(dst);

        m_nodes[m_nodeIndex[src]].packetCount++;
        m_nodes[m_nodeIndex[src]].bytesTotal += pkt.length;

        QString key = edgeKey(src, dst);
        if (!m_edgeIndex.contains(key)) {
            m_edgeIndex[key] = int(m_edges.size());
            MapEdge e; e.src = src; e.dst = dst;
            m_edges.push_back(e);
        }
        auto &edge = m_edges[m_edgeIndex[key]];
        edge.packets++;
        edge.bytes   += pkt.length;
        edge.lastSeen = QDateTime::currentMSecsSinceEpoch();

        // EMA bandwidth estimate (α = 0.1)
        edge.bandwidth = 0.9 * edge.bandwidth + 0.1 * pkt.length;
        changed = true;
    }

    if (changed) emit graphChanged();
}

void NetworkMapModel::ensureNode(const QString &ip)
{
    if (m_nodeIndex.contains(ip)) return;

    MapNode n;
    n.ip    = ip;
    n.label = ip;
    // Random initial position
    n.x = 0.1 + (QRandomGenerator::global()->bounded(1000)) / 1250.0;
    n.y = 0.1 + (QRandomGenerator::global()->bounded(1000)) / 1250.0;

    m_nodeIndex[ip] = int(m_nodes.size());
    m_nodes.push_back(std::move(n));
}

QString NetworkMapModel::edgeKey(const QString &a, const QString &b) const
{
    return (a < b) ? a + "|" + b : b + "|" + a;
}

QVariantList NetworkMapModel::nodes() const
{
    QVariantList out;
    out.reserve(int(m_nodes.size()));
    for (const auto &n : m_nodes) {
        QVariantMap m;
        m["ip"]          = n.ip;
        m["label"]       = n.label;
        m["packetCount"] = quint64(n.packetCount);
        m["bytesTotal"]  = quint64(n.bytesTotal);
        m["x"]           = n.x;
        m["y"]           = n.y;
        m["pinned"]      = n.pinned;
        out.append(m);
    }
    return out;
}

QVariantList NetworkMapModel::edges() const
{
    QVariantList out;
    out.reserve(int(m_edges.size()));
    for (const auto &e : m_edges) {
        QVariantMap m;
        m["src"]       = e.src;
        m["dst"]       = e.dst;
        m["packets"]   = quint64(e.packets);
        m["bytes"]     = quint64(e.bytes);
        m["bandwidth"] = e.bandwidth;
        out.append(m);
    }
    return out;
}

void NetworkMapModel::pinNode(const QString &ip, double x, double y)
{
    if (!m_nodeIndex.contains(ip)) return;
    auto &n = m_nodes[m_nodeIndex[ip]];
    n.x      = x;
    n.y      = y;
    n.pinned = true;
    emit graphChanged();
}

void NetworkMapModel::clear()
{
    m_nodes.clear();
    m_edges.clear();
    m_nodeIndex.clear();
    m_edgeIndex.clear();
    emit graphChanged();
}
