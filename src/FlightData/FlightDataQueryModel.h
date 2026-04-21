/****************************************************************************
 *
 * HILM Ground Control — Flight Data Query Model
 * QAbstractListModel exposing flight/vehicle query results to QML.
 * Supports role-based access for ListView, Repeater, TableView.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QAbstractListModel>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>

class FlightDataQueryModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit FlightDataQueryModel(QObject *parent = nullptr);

    // QAbstractListModel interface
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return _data.count(); }

    Q_INVOKABLE QVariantMap get(int index) const;
    Q_INVOKABLE void clear();

public slots:
    void setData(const QVariantList &data);

signals:
    void countChanged();

private:
    void _updateRoles(const QVariantMap &sample);

    QVariantList              _data;
    QHash<int, QByteArray>    _roles;
    bool                      _rolesInitialized = false;

    static constexpr int kBaseRole = Qt::UserRole + 1;
};
