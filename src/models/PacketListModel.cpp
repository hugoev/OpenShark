#include "PacketListModel.h"
#include <QDateTime>
#include <QVariantList>
#include <algorithm>
#include <cmath>
#include <optional>
#include <initializer_list>
#include <utility>

PacketListModel::PacketListModel(QObject *parent)
    : QAbstractListModel(parent)
{}

int PacketListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return int(m_filtered.size());
}

QHash<int, QByteArray> PacketListModel::roleNames() const
{
    return {
        {IdRole,            "packetId"},
        {TimestampRole,     "timestamp"},
        {SrcIpRole,         "srcIp"},
        {DstIpRole,         "dstIp"},
        {SrcPortRole,       "srcPort"},
        {DstPortRole,       "dstPort"},
        {ProtocolRole,      "protocol"},
        {ProtocolColorRole, "protocolColor"},
        {LengthRole,        "length"},
        {SummaryRole,       "summary"},
        {BookmarkedRole,    "bookmarked"},
    };
}

QVariant PacketListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= int(m_filtered.size()))
        return {};

    const DissectedPacket &pkt = m_all[m_filtered[index.row()]];

    switch (role) {
    case IdRole:            return quint64(pkt.id);
    case TimestampRole: {
        // Format as HH:mm:ss.uuu
        auto secs  = qint64(std::floor(pkt.timestamp));
        auto usecs = qint64((pkt.timestamp - std::floor(pkt.timestamp)) * 1e6);
        QDateTime dt = QDateTime::fromSecsSinceEpoch(secs);
        return dt.toString("HH:mm:ss.") + QString("%1").arg(usecs / 1000, 3, 10, QChar('0'));
    }
    case SrcIpRole:         return QString::fromStdString(pkt.srcIp);
    case DstIpRole:         return QString::fromStdString(pkt.dstIp);
    case SrcPortRole:       return pkt.srcPort;
    case DstPortRole:       return pkt.dstPort;
    case ProtocolRole:      return QString(protocolName(pkt.topProtocol));
    case ProtocolColorRole: return protocolColor(pkt.topProtocol);
    case LengthRole:        return pkt.length;
    case BookmarkedRole:    return m_bookmarks.count(pkt.id) > 0;
    case SummaryRole: {
        QString src = QString::fromStdString(pkt.srcIp);
        QString dst = QString::fromStdString(pkt.dstIp);
        if (pkt.srcPort) src += QString(":%1").arg(pkt.srcPort);
        if (pkt.dstPort) dst += QString(":%1").arg(pkt.dstPort);
        return QString("%1  →  %2").arg(src, dst);
    }
    default: return {};
    }
}

void PacketListModel::appendBatch(const std::vector<DissectedPacket> &batch)
{
    if (batch.empty()) return;

    std::vector<int> newFiltered;
    int base = int(m_all.size());
    m_all.reserve(m_all.size() + batch.size());

    for (auto &pkt : batch) {
        m_all.push_back(pkt);
        if (matchesFilter(pkt))
            newFiltered.push_back(base + int(newFiltered.size()));
    }

    if (!newFiltered.empty()) {
        int first = int(m_filtered.size());
        beginInsertRows({}, first, first + int(newFiltered.size()) - 1);
        m_filtered.insert(m_filtered.end(), newFiltered.begin(), newFiltered.end());
        endInsertRows();
        emit countChanged();
    }
}

void PacketListModel::clear()
{
    beginResetModel();
    m_all.clear();
    m_filtered.clear();
    m_bookmarks.clear();
    endResetModel();
    emit countChanged();
}

void PacketListModel::setDisplayFilter(const QString &filter)
{
    if (m_filter == filter) return;
    m_filter = filter;

    beginResetModel();
    m_filtered.clear();
    for (int i = 0; i < int(m_all.size()); ++i)
        if (matchesFilter(m_all[i])) m_filtered.push_back(i);
    endResetModel();
    emit countChanged();
}

QVariantMap PacketListModel::packetDetail(int index) const
{
    if (index < 0 || index >= int(m_filtered.size())) return {};
    const DissectedPacket &pkt = m_all[m_filtered[index]];

    QVariantList layers;
    for (const auto &layer : pkt.layers) {
        QVariantMap lm;
        lm["label"]    = QString::fromStdString(layer.label);
        lm["protocol"] = QString(protocolName(layer.protocol));

        QVariantList fields;
        for (const auto &f : layer.fields) {
            QVariantMap fm;
            fm["name"]           = QString::fromStdString(f.name);
            fm["value"]          = QString::fromStdString(f.value);
            fm["byteOffset"]     = f.byteOffset;
            fm["byteLength"]     = f.byteLength;
            fm["absoluteOffset"] = layer.baseOffset + f.byteOffset;
            fields.append(fm);
        }
        lm["fields"] = fields;
        layers.append(lm);
    }

    // Raw bytes as JS array for HexView
    const auto &raw = pkt.raw;
    QVariantList rawBytes;
    rawBytes.reserve(int(raw.size()));
    for (uint8_t b : raw) rawBytes.append(int(b));

    QVariantMap result;
    result["layers"]   = layers;
    result["rawBytes"] = rawBytes;
    result["length"]   = uint(raw.size());
    return result;
}

bool PacketListModel::matchesFilter(const DissectedPacket &pkt) const
{
    if (m_filter.isEmpty()) return true;

    // Simple field equality: ip.src == x, tcp.port == y, protocol == TLS
    // Also substring match on IPs/protocol name
    QString f = m_filter.trimmed();

    auto check = [&](const QString &key, const QString &val) -> std::optional<bool> {
        if (!f.startsWith(key + " == ") && !f.startsWith(key + "==")) return std::nullopt;
        QString rhs = f.mid(f.indexOf("==") + 2).trimmed().remove('"');
        return val.compare(rhs, Qt::CaseInsensitive) == 0;
    };

    for (auto &[key, val] : std::initializer_list<std::pair<QString,QString>>{
            {"ip.src",   QString::fromStdString(pkt.srcIp)},
            {"ip.dst",   QString::fromStdString(pkt.dstIp)},
            {"protocol", QString(protocolName(pkt.topProtocol))},
            {"tcp.port", QString::number(pkt.srcPort)},
            {"tcp.port", QString::number(pkt.dstPort)},
        }) {
        if (auto r = check(key, val); r.has_value()) return *r;
    }

    // Fallback: substring match across src/dst IPs and protocol name
    QString haystack = QString::fromStdString(pkt.srcIp + " " + pkt.dstIp + " " + protocolName(pkt.topProtocol));
    return haystack.contains(f, Qt::CaseInsensitive);
}

void PacketListModel::toggleBookmark(int index)
{
    if (index < 0 || index >= int(m_filtered.size())) return;
    uint64_t id = m_all[m_filtered[index]].id;
    if (m_bookmarks.count(id)) m_bookmarks.erase(id);
    else                        m_bookmarks.insert(id);
    auto idx = createIndex(index, 0);
    emit dataChanged(idx, idx, {BookmarkedRole});
}

QVariantMap PacketListModel::followStream(int index) const
{
    if (index < 0 || index >= int(m_filtered.size())) return {};
    const DissectedPacket &seed = m_all[m_filtered[index]];

    // Only TCP-based protocols
    if (seed.topProtocol != Protocol::TCP &&
        seed.topProtocol != Protocol::HTTP &&
        seed.topProtocol != Protocol::TLS)
        return {};

    QString seedSrcIp  = QString::fromStdString(seed.srcIp);
    QString seedDstIp  = QString::fromStdString(seed.dstIp);
    uint16_t seedSPort = seed.srcPort;
    uint16_t seedDPort = seed.dstPort;

    // Normalize stream key so direction doesn't matter for grouping
    QString keyA = seedSrcIp + ":" + QString::number(seedSPort);
    QString keyB = seedDstIp + ":" + QString::number(seedDPort);
    bool swapped = (keyA > keyB);
    if (swapped) { std::swap(keyA, keyB); }

    struct Seg { uint32_t seq; bool fromA; std::vector<uint8_t> data; };
    std::vector<Seg> segments;

    for (const auto &pkt : m_all) {
        if (pkt.tcpPayload.empty()) continue;
        QString ps = QString::fromStdString(pkt.srcIp);
        QString pd = QString::fromStdString(pkt.dstIp);
        QString ka = ps + ":" + QString::number(pkt.srcPort);
        QString kb = pd + ":" + QString::number(pkt.dstPort);
        bool matchFwd = (ka == keyA && kb == keyB);
        bool matchRev = (ka == keyB && kb == keyA);
        if (!matchFwd && !matchRev) continue;
        segments.push_back({pkt.tcpSeq, matchFwd != swapped, pkt.tcpPayload});
    }

    std::stable_sort(segments.begin(), segments.end(),
        [](const Seg &a, const Seg &b) { return a.seq < b.seq; });

    auto bytesToText = [](const std::vector<uint8_t> &bytes) -> QString {
        QString out;
        out.reserve(int(bytes.size()));
        for (uint8_t b : bytes) {
            if (b == '\n')                    out += '\n';
            else if (b == '\r')               {}
            else if (b >= 0x20 && b < 0x7F)   out += QChar(b);
            else                               out += '.';
        }
        return out;
    };

    // Build interleaved segment list for QML
    QVariantList segList;
    for (auto &s : segments) {
        QVariantMap m;
        m["text"]    = bytesToText(s.data);
        m["fromClient"] = s.fromA;
        segList.append(m);
    }

    QVariantMap result;
    result["segments"]    = segList;
    result["streamKey"]   = keyA + " ↔ " + keyB;
    result["segmentCount"] = int(segments.size());
    return result;
}

QVariantList PacketListModel::searchAll(const QString &query) const
{
    QVariantList result;
    if (query.trimmed().isEmpty()) return result;
    QString q = query.trimmed();
    for (int i = 0; i < int(m_filtered.size()); ++i) {
        const DissectedPacket &pkt = m_all[m_filtered[i]];
        QString haystack = QString::fromStdString(pkt.srcIp) + " " +
                           QString::fromStdString(pkt.dstIp) + " " +
                           QString::number(pkt.srcPort) + " " +
                           QString::number(pkt.dstPort) + " " +
                           QString(protocolName(pkt.topProtocol));
        if (haystack.contains(q, Qt::CaseInsensitive))
            result.append(i);
    }
    return result;
}

QString PacketListModel::protocolColor(Protocol p)
{
    switch (p) {
    case Protocol::TCP:   return "#2979ff"; // blue
    case Protocol::UDP:   return "#00bcd4"; // cyan
    case Protocol::TLS:   return "#7c4dff"; // purple
    case Protocol::DNS:   return "#ff9100"; // orange
    case Protocol::HTTP:  return "#00c853"; // green
    case Protocol::ICMP:  return "#e31937"; // signal red
    case Protocol::ICMPv6:return "#f44336";
    case Protocol::ARP:   return "#ff6d00"; // deep orange
    case Protocol::IPv4:  return "#546e7a";
    case Protocol::IPv6:  return "#455a64";
    default:              return "#616161";
    }
}
