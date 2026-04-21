/****************************************************************************
 *
 * HILM Ground Control — Flight Database Worker
 * QThread-based async database writer. Modeled on QGCTileCacheWorker.
 * Owns its own QSqlDatabase connection; receives work via a task queue.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QMutex>
#include <QtCore/QQueue>
#include <QtCore/QString>
#include <QtCore/QThread>
#include <QtCore/QWaitCondition>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>

#include <memory>
#include <atomic>

#include "FlightDataModels.h"

Q_DECLARE_LOGGING_CATEGORY(FlightDatabaseWorkerLog)

class QSqlDatabase;

// ── Task types ─────────────────────────────────────────────────
enum class FlightDataTaskType {
    UpsertVehicle,
    StartFlight,
    EndFlight,
    UpdateFlightTakeoff,
    UpdateFlightLanding,
    InsertTelemetryBatch,
    InsertEvent,
    StoreMission,
    StoreFlightPath,
    QueryFlights,
    QueryTelemetry,
    QueryFlightPath,
    QueryVehicles,
    QueryFleetSummary,
    QueryFlightEvents,
    QueryBatteryTrend,
    QueryFlightActivity,
    DeleteOldData,
    UpdateVehicleStats,
    Shutdown
};

struct FlightDataTask
{
    FlightDataTaskType type;
    QVariantMap        params;
    QVariantList       batchData;
};

// ── Worker thread ──────────────────────────────────────────────
class FlightDatabaseWorker : public QThread
{
    Q_OBJECT

public:
    explicit FlightDatabaseWorker(QObject *parent = nullptr);
    ~FlightDatabaseWorker() override;

    void setDatabasePath(const QString &path) { _databasePath = path; }
    void enqueueTask(const FlightDataTask &task);
    void stop();

signals:
    void databaseReady();
    void databaseError(const QString &error);

    // Query result signals
    void flightsResult(const QVariantList &flights);
    void telemetryResult(int flightId, const QVariantList &snapshots);
    void flightPathResult(int flightId, const QVariantList &path);
    void vehiclesResult(const QVariantList &vehicles);
    void fleetSummaryResult(const QVariantMap &summary);
    void flightEventsResult(int flightId, const QVariantList &events);
    void batteryTrendResult(const QString &vehicleUid, const QVariantList &trend);
    void flightActivityResult(const QVariantList &activity);

    // Write result signals
    void flightStarted(int flightId, const QString &vehicleUid);
    void flightEnded(int flightId);
    void vehicleStatsUpdated(const QString &vehicleUid);

protected:
    void run() override;

private:
    bool _initDatabase();
    bool _createSchema(QSqlDatabase &db);
    void _runTask(const FlightDataTask &task);

    // Write operations
    void _upsertVehicle(const QVariantMap &params);
    void _startFlight(const QVariantMap &params);
    void _endFlight(const QVariantMap &params);
    void _updateFlightTakeoff(const QVariantMap &params);
    void _updateFlightLanding(const QVariantMap &params);
    void _insertTelemetryBatch(const QVariantList &batch);
    void _insertEvent(const QVariantMap &params);
    void _storeMission(const QVariantMap &params);
    void _storeFlightPath(const QVariantMap &params);
    void _updateVehicleStats(const QVariantMap &params);
    void _deleteOldData(const QVariantMap &params);

    // Read operations
    void _queryFlights(const QVariantMap &params);
    void _queryTelemetry(const QVariantMap &params);
    void _queryFlightPath(const QVariantMap &params);
    void _queryVehicles(const QVariantMap &params);
    void _queryFleetSummary();
    void _queryFlightEvents(const QVariantMap &params);
    void _queryBatteryTrend(const QVariantMap &params);
    void _queryFlightActivity(const QVariantMap &params);

    std::shared_ptr<QSqlDatabase> _db;
    QMutex          _taskQueueMutex;
    QQueue<FlightDataTask> _taskQueue;
    QWaitCondition  _waitCondition;
    QString         _databasePath;
    std::atomic_bool _stopping{false};

    static constexpr const char *kSessionName = "FlightDataSession";
};
