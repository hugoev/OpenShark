#pragma once
#include <QAbstractListModel>
#include <QString>
#include <vector>
#include <memory>
#include <unordered_set>

#include "../dissect/DissectedPacket.h"

class PacketListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TimestampRole,
        SrcIpRole, DstIpRole,
        SrcPortRole, DstPortRole,
        ProtocolRole, ProtocolColorRole,
        LengthRole,
        SummaryRole,
        BookmarkedRole,
        InfoRole,
    };

    explicit PacketListModel(QObject *parent = nullptr);

    int      rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void appendBatch(const std::vector<DissectedPacket> &batch);
    void clear();
    void setDisplayFilter(const QString &filter);

    Q_INVOKABLE QVariantMap  packetDetail(int index) const;

    const std::vector<DissectedPacket>& allPackets() const { return m_all; }
    Q_INVOKABLE void         toggleBookmark(int index);
    Q_INVOKABLE QVariantMap  followStream(int index) const;
    Q_INVOKABLE QVariantList searchAll(const QString &query) const;

signals:
    void countChanged();

private:
    bool matchesFilter(const DissectedPacket &pkt) const;
    static QString protocolColor(Protocol p);
    static QString infoString(const DissectedPacket &pkt);

    std::vector<DissectedPacket>  m_all;       // all captured
    std::vector<int>              m_filtered;  // indices into m_all passing display filter
    QString                       m_filter;
    std::unordered_set<uint64_t>  m_bookmarks; // packet IDs that are bookmarked
};
