#include "InterfaceListModel.h"
#include <pcap.h>

InterfaceListModel::InterfaceListModel(QObject *parent)
    : QAbstractListModel(parent)
{
    refresh();
}

int InterfaceListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return int(m_ifaces.size());
}

QHash<int, QByteArray> InterfaceListModel::roleNames() const
{
    return {
        {NameRole,        "name"},
        {DescriptionRole, "description"},
        {LoopbackRole,    "loopback"},
    };
}

QVariant InterfaceListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= int(m_ifaces.size())) return {};
    const auto &iface = m_ifaces[index.row()];
    switch (role) {
    case NameRole:        return iface.name;
    case DescriptionRole: return iface.description;
    case LoopbackRole:    return iface.loopback;
    default:              return {};
    }
}

void InterfaceListModel::refresh()
{
    char errbuf[PCAP_ERRBUF_SIZE];
    pcap_if_t *devs = nullptr;

    beginResetModel();
    m_ifaces.clear();

    if (pcap_findalldevs(&devs, errbuf) == 0 && devs) {
        for (pcap_if_t *d = devs; d; d = d->next) {
            NetworkInterface ni;
            ni.name     = QString::fromUtf8(d->name);
            ni.description = d->description ? QString::fromUtf8(d->description) : ni.name;
            ni.loopback = (d->flags & PCAP_IF_LOOPBACK) != 0;
            m_ifaces.push_back(std::move(ni));
        }
        pcap_freealldevs(devs);
    }

    endResetModel();
}

QString InterfaceListModel::nameAt(int index) const
{
    if (index < 0 || index >= int(m_ifaces.size())) return {};
    return m_ifaces[index].name;
}
