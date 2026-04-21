/****************************************************************************
 *
 * HILM Ground Control — Flight Data Query Model Implementation
 *
 ****************************************************************************/

#include "FlightDataQueryModel.h"

FlightDataQueryModel::FlightDataQueryModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int FlightDataQueryModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return _data.count();
}

QVariant FlightDataQueryModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= _data.count()) {
        return QVariant();
    }

    const QVariantMap row = _data.at(index.row()).toMap();
    const QByteArray roleName = _roles.value(role);
    return row.value(QString::fromLatin1(roleName));
}

QHash<int, QByteArray> FlightDataQueryModel::roleNames() const
{
    return _roles;
}

QVariantMap FlightDataQueryModel::get(int index) const
{
    if (index < 0 || index >= _data.count()) {
        return QVariantMap();
    }
    return _data.at(index).toMap();
}

void FlightDataQueryModel::clear()
{
    if (_data.isEmpty()) return;
    beginResetModel();
    _data.clear();
    endResetModel();
    emit countChanged();
}

void FlightDataQueryModel::setData(const QVariantList &data)
{
    beginResetModel();
    _data = data;

    // Auto-discover roles from first row
    if (!_rolesInitialized && !_data.isEmpty()) {
        _updateRoles(_data.first().toMap());
    }

    endResetModel();
    emit countChanged();
}

void FlightDataQueryModel::_updateRoles(const QVariantMap &sample)
{
    _roles.clear();
    int role = kBaseRole;
    const QStringList keys = sample.keys();
    for (const QString &key : keys) {
        _roles[role++] = key.toLatin1();
    }
    _rolesInitialized = true;
}
