/****************************************************************************
 *
 * HILM Ground Control — Flight Database Manager Implementation
 *
 ****************************************************************************/

#include "FlightDatabase.h"
#include "FlightDatabaseWorker.h"
#include "FlightDataQueryModel.h"
#include "TelemetryCollector.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"

#include <QQmlEngine>
#include <QJSEngine>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QFile>

Q_LOGGING_CATEGORY(FlightDatabaseLog, "FlightDatabaseLog")

FlightDatabase *FlightDatabase::_instance = nullptr;

FlightDatabase *FlightDatabase::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)
    return instance();
}

FlightDatabase *FlightDatabase::instance()
{
    if (!_instance) {
        _instance = new FlightDatabase();
    }
    return _instance;
}

FlightDatabase::FlightDatabase(QObject *parent)
    : QObject(parent)
{
    _flightsModel  = new FlightDataQueryModel(this);
    _vehiclesModel = new FlightDataQueryModel(this);
    _eventsModel   = new FlightDataQueryModel(this);
}

FlightDatabase::~FlightDatabase()
{
    // Stop all collectors
    qDeleteAll(_collectors);
    _collectors.clear();

    // Stop worker thread
    if (_worker) {
        _worker->stop();
        _worker->wait();
        delete _worker;
        _worker = nullptr;
    }
}

void FlightDatabase::init()
{
    qCDebug(FlightDatabaseLog) << "Initializing flight database...";

    // Create and start worker thread
    _worker = new FlightDatabaseWorker(this);
    _worker->setDatabasePath(_databaseFilePath());

    // Connect worker signals
    connect(_worker, &FlightDatabaseWorker::databaseReady,
            this,    &FlightDatabase::_onDatabaseReady);
    connect(_worker, &FlightDatabaseWorker::databaseError,
            this,    &FlightDatabase::_onDatabaseError);
    connect(_worker, &FlightDatabaseWorker::flightsResult,
            this,    &FlightDatabase::_onFlightsResult);
    connect(_worker, &FlightDatabaseWorker::vehiclesResult,
            this,    &FlightDatabase::_onVehiclesResult);
    connect(_worker, &FlightDatabaseWorker::fleetSummaryResult,
            this,    &FlightDatabase::_onFleetSummaryResult);
    connect(_worker, &FlightDatabaseWorker::flightEventsResult,
            this,    &FlightDatabase::_onFlightEventsResult);
    connect(_worker, &FlightDatabaseWorker::batteryTrendResult,
            this,    &FlightDatabase::_onBatteryTrendResult);
    connect(_worker, &FlightDatabaseWorker::flightActivityResult,
            this,    &FlightDatabase::_onFlightActivityResult);
    connect(_worker, &FlightDatabaseWorker::telemetryResult,
            this,    &FlightDatabase::_onTelemetryResult);
    connect(_worker, &FlightDatabaseWorker::flightPathResult,
            this,    &FlightDatabase::_onFlightPathResult);
    connect(_worker, &FlightDatabaseWorker::flightStarted,
            this,    &FlightDatabase::_onFlightStarted);

    _worker->start();

    // Connect to MultiVehicleManager
    _multiVehicleManager = MultiVehicleManager::instance();
    _setupConnections();

    // Register existing vehicles
    if (_multiVehicleManager && _multiVehicleManager->vehicles()) {
        for (int i = 0; i < _multiVehicleManager->vehicles()->count(); i++) {
            Vehicle *vehicle = qobject_cast<Vehicle *>(_multiVehicleManager->vehicles()->get(i));
            if (vehicle) {
                _vehicleAdded(vehicle);
            }
        }
    }
}

void FlightDatabase::_setupConnections()
{
    if (!_multiVehicleManager) return;

    connect(_multiVehicleManager, &MultiVehicleManager::vehicleAdded,
            this,                 &FlightDatabase::_vehicleAdded);
    connect(_multiVehicleManager, &MultiVehicleManager::vehicleRemoved,
            this,                 &FlightDatabase::_vehicleRemoved);
}

QString FlightDatabase::_databaseFilePath() const
{
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                            + QDir::separator() + QStringLiteral("FlightData");
    return dataDir + QDir::separator() + QStringLiteral("hilm_flights.db");
}

// ── Vehicle lifecycle ──────────────────────────────────────────

void FlightDatabase::_vehicleAdded(Vehicle *vehicle)
{
    if (!vehicle || vehicle->isOfflineEditingVehicle()) return;

    const int vehicleId = vehicle->id();
    if (_collectors.contains(vehicleId)) return;

    qCDebug(FlightDatabaseLog) << "Creating telemetry collector for vehicle" << vehicleId;

    auto *collector = new TelemetryCollector(vehicle, this, this);
    _collectors.insert(vehicleId, collector);
}

void FlightDatabase::_vehicleRemoved(Vehicle *vehicle)
{
    if (!vehicle) return;

    const int vehicleId = vehicle->id();
    TelemetryCollector *collector = _collectors.take(vehicleId);
    if (collector) {
        qCDebug(FlightDatabaseLog) << "Removing telemetry collector for vehicle" << vehicleId;
        collector->deleteLater();
    }
}

// ── Worker result handlers ─────────────────────────────────────

void FlightDatabase::_onDatabaseReady()
{
    _ready = true;
    emit readyChanged();
    qCDebug(FlightDatabaseLog) << "Flight database ready at:" << _databaseFilePath();

    // Initial data load
    queryFleetSummary();
    queryFlights();
    queryVehicles();
}

void FlightDatabase::_onDatabaseError(const QString &error)
{
    qCCritical(FlightDatabaseLog) << "Flight database error:" << error;
}

void FlightDatabase::_onFlightsResult(const QVariantList &flights)
{
    _flightsModel->setData(flights);
}

void FlightDatabase::_onVehiclesResult(const QVariantList &vehicles)
{
    _vehiclesModel->setData(vehicles);
}

void FlightDatabase::_onFleetSummaryResult(const QVariantMap &summary)
{
    _totalFlights     = summary.value(QStringLiteral("totalFlights")).toInt();
    _totalVehicles    = summary.value(QStringLiteral("totalVehicles")).toInt();
    _totalFlightHours = summary.value(QStringLiteral("totalFlightHours")).toDouble();
    _totalDistanceKm  = summary.value(QStringLiteral("totalDistanceKm")).toDouble();
    _avgBatteryEndPct = summary.value(QStringLiteral("avgBatteryEndPct")).toDouble();
    _successRate      = summary.value(QStringLiteral("successRate")).toDouble();
    emit fleetSummaryChanged();
}

void FlightDatabase::_onFlightEventsResult(int flightId, const QVariantList &events)
{
    Q_UNUSED(flightId)
    _eventsModel->setData(events);
}

void FlightDatabase::_onBatteryTrendResult(const QString &vehicleUid, const QVariantList &trend)
{
    Q_UNUSED(vehicleUid)
    _batteryTrendData = trend;
    emit batteryTrendChanged();
}

void FlightDatabase::_onFlightActivityResult(const QVariantList &activity)
{
    _flightActivityData = activity;
    emit flightActivityChanged();
}

void FlightDatabase::_onTelemetryResult(int flightId, const QVariantList &snapshots)
{
    Q_UNUSED(flightId)
    _telemetryData = snapshots;
    emit telemetryDataChanged();
}

void FlightDatabase::_onFlightPathResult(int flightId, const QVariantList &path)
{
    Q_UNUSED(flightId)
    _flightPathData = path;
    emit flightPathChanged();
}

void FlightDatabase::_onFlightStarted(int flightId, const QString &vehicleUid)
{
    Q_UNUSED(vehicleUid)

    // Notify relevant collector about its flight ID
    for (auto *collector : std::as_const(_collectors)) {
        if (collector->vehicleUid() == vehicleUid) {
            collector->setCurrentFlightId(flightId);
            break;
        }
    }
}

// ── QML-invokable queries ──────────────────────────────────────

void FlightDatabase::queryFlights(const QString &vehicleUid,
                                  const QString &dateFrom,
                                  const QString &dateTo,
                                  const QString &status,
                                  int limit)
{
    if (!_worker) return;

    FlightDataTask task;
    task.type = FlightDataTaskType::QueryFlights;
    task.params[QStringLiteral("vehicleUid")] = vehicleUid;
    task.params[QStringLiteral("dateFrom")]   = dateFrom;
    task.params[QStringLiteral("dateTo")]     = dateTo;
    task.params[QStringLiteral("status")]     = status;
    task.params[QStringLiteral("limit")]      = limit;
    _worker->enqueueTask(task);
}

void FlightDatabase::queryVehicles()
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::QueryVehicles;
    _worker->enqueueTask(task);
}

void FlightDatabase::queryFleetSummary()
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::QueryFleetSummary;
    _worker->enqueueTask(task);
}

void FlightDatabase::queryTelemetry(int flightId)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::QueryTelemetry;
    task.params[QStringLiteral("flightId")] = flightId;
    _worker->enqueueTask(task);
}

void FlightDatabase::queryFlightPath(int flightId)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::QueryFlightPath;
    task.params[QStringLiteral("flightId")] = flightId;
    _worker->enqueueTask(task);
}

void FlightDatabase::queryFlightEvents(int flightId)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::QueryFlightEvents;
    task.params[QStringLiteral("flightId")] = flightId;
    _worker->enqueueTask(task);
}

void FlightDatabase::queryBatteryTrend(const QString &vehicleUid, int lastN)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::QueryBatteryTrend;
    task.params[QStringLiteral("vehicleUid")] = vehicleUid;
    task.params[QStringLiteral("lastN")]      = lastN;
    _worker->enqueueTask(task);
}

void FlightDatabase::queryFlightActivity(int days)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::QueryFlightActivity;
    task.params[QStringLiteral("days")] = days;
    _worker->enqueueTask(task);
}

void FlightDatabase::deleteOldFlights(int olderThanDays)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::DeleteOldData;
    task.params[QStringLiteral("olderThanDays")] = olderThanDays;
    _worker->enqueueTask(task);
}

bool FlightDatabase::writeTextFile(const QString &filePath, const QString &content)
{
    QString path = filePath;
    if (path.startsWith(QStringLiteral("file:///"))) path = path.mid(8);
    else if (path.startsWith(QStringLiteral("file://"))) path = path.mid(7);

    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        qCWarning(FlightDatabaseLog) << "writeTextFile failed:" << path << ":" << f.errorString();
        return false;
    }
    const QByteArray data = content.toUtf8();
    const qint64 written = f.write(data);
    f.close();
    qCDebug(FlightDatabaseLog) << "writeTextFile: wrote" << written << "bytes to" << path;
    return written == data.size();
}

// ── Enqueue helpers for TelemetryCollector ─────────────────────

void FlightDatabase::enqueueUpsertVehicle(const QVariantMap &params)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::UpsertVehicle;
    task.params = params;
    _worker->enqueueTask(task);
}

void FlightDatabase::enqueueStartFlight(const QVariantMap &params)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::StartFlight;
    task.params = params;
    _worker->enqueueTask(task);
}

void FlightDatabase::enqueueEndFlight(const QVariantMap &params)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::EndFlight;
    task.params = params;
    _worker->enqueueTask(task);

    // Also update vehicle cumulative stats
    const QString uid = params.value(QStringLiteral("vehicleUid")).toString();
    if (!uid.isEmpty()) {
        enqueueUpdateVehicleStats(uid);
    }

    // Refresh queries
    queryFleetSummary();
    queryFlights();
}

void FlightDatabase::enqueueUpdateTakeoff(const QVariantMap &params)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::UpdateFlightTakeoff;
    task.params = params;
    _worker->enqueueTask(task);
}

void FlightDatabase::enqueueUpdateLanding(const QVariantMap &params)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::UpdateFlightLanding;
    task.params = params;
    _worker->enqueueTask(task);
}

void FlightDatabase::enqueueTelemetryBatch(const QVariantList &batch)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::InsertTelemetryBatch;
    task.batchData = batch;
    _worker->enqueueTask(task);
}

void FlightDatabase::enqueueInsertEvent(const QVariantMap &params)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::InsertEvent;
    task.params = params;
    _worker->enqueueTask(task);
}

void FlightDatabase::enqueueStoreFlightPath(const QVariantMap &params)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::StoreFlightPath;
    task.params = params;
    _worker->enqueueTask(task);
}

void FlightDatabase::enqueueUpdateVehicleStats(const QString &vehicleUid)
{
    if (!_worker) return;
    FlightDataTask task;
    task.type = FlightDataTaskType::UpdateVehicleStats;
    task.params[QStringLiteral("vehicleUid")] = vehicleUid;
    _worker->enqueueTask(task);
}
