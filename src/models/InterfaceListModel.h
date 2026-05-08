#pragma once
#include <QAbstractListModel>
#include <QString>
#include <vector>
#include <pcap.h>

struct NetworkInterface {
    QString name;
    QString description;
    bool    loopback;
};

class InterfaceListModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        DescriptionRole,
        LoopbackRole,
    };

    explicit InterfaceListModel(QObject *parent = nullptr);

    int      rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QString nameAt(int index) const;

private:
    std::vector<NetworkInterface> m_ifaces;
};
