/****************************************************************************
 *
 * HILM Ground Control — Flight Database Manager
 * Singleton managing flight data persistence. Exposes query models to QML,
 * manages the worker thread, and creates TelemetryCollectors per vehicle.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QObject>
#include <QtCore/QMap>
#include <QtCore/QLoggingCategory>
#include <QtQmlIntegration/QtQmlIntegration>

Q_DECLARE_LOGGING_CATEGORY(FlightDatabaseLog)

class FlightDatabaseWorker;
class FlightDataQueryModel;
class TelemetryCollector;
class Vehicle;
class MultiVehicleManager;
class QQmlEngine;
class QJSEngine;

class FlightDatabase : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(FlightDataQueryModel* flightsModel   READ flightsModel   CONSTANT)
    Q_PROPERTY(FlightDataQueryModel* vehiclesModel  READ vehiclesModel  CONSTANT)
    Q_PROPERTY(FlightDataQueryModel* eventsModel    READ eventsModel    CONSTANT)
    Q_PROPERTY(bool   ready            READ ready            NOTIFY readyChanged)
    Q_PROPERTY(int    totalFlights     READ totalFlights     NOTIFY fleetSummaryChanged)
    Q_PROPERTY(int    totalVehicles    READ totalVehicles    NOTIFY fleetSummaryChanged)
    Q_PROPERTY(double totalFlightHours READ totalFlightHours NOTIFY fleetSummaryChanged)
    Q_PROPERTY(double totalDistanceKm  READ totalDistanceKm  NOTIFY fleetSummaryChanged)
    Q_PROPERTY(double avgBatteryEndPct READ avgBatteryEndPct NOTIFY fleetSummaryChanged)
    Q_PROPERTY(double successRate      READ successRate      NOTIFY fleetSummaryChanged)

    // Chart data (QML-accessible variant lists)
    Q_PROPERTY(QVariantList batteryTrendData    READ batteryTrendData    NOTIFY batteryTrendChanged)
    Q_PROPERTY(QVariantList flightActivityData  READ flightActivityData  NOTIFY flightActivityChanged)
    Q_PROPERTY(QVariantList telemetryData       READ telemetryData       NOTIFY telemetryDataChanged)
    Q_PROPERTY(QVariantList flightPathData      READ flightPathData      NOTIFY flightPathChanged)

public:
    // QML Singleton factory
    static FlightDatabase *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    // C++ Singleton
    static FlightDatabase *instance();

    void init();

    // Property getters
    FlightDataQueryModel *flightsModel()  const { return _flightsModel; }
    FlightDataQueryModel *vehiclesModel() const { return _vehiclesModel; }
    FlightDataQueryModel *eventsModel()   const { return _eventsModel; }
    bool   ready()            const { return _ready; }
    int    totalFlights()     const { return _totalFlights; }
    int    totalVehicles()    const { return _totalVehicles; }
    double totalFlightHours() const { return _totalFlightHours; }
    double totalDistanceKm()  const { return _totalDistanceKm; }
    double avgBatteryEndPct() const { return _avgBatteryEndPct; }
    double successRate()      const { return _successRate; }

    QVariantList batteryTrendData()   const { return _batteryTrendData; }
    QVariantList flightActivityData() const { return _flightActivityData; }
    QVariantList telemetryData()      const { return _telemetryData; }
    QVariantList flightPathData()     const { return _flightPathData; }

    // QML-invokable queries
    Q_INVOKABLE void queryFlights(const QString &vehicleUid = QString(),
                                  const QString &dateFrom = QString(),
                                  const QString &dateTo = QString(),
                                  const QString &status = QString(),
                                  int limit = 100);
    Q_INVOKABLE void queryVehicles();
    Q_INVOKABLE void queryFleetSummary();
    Q_INVOKABLE void queryTelemetry(int flightId);
    Q_INVOKABLE void queryFlightPath(int flightId);
    Q_INVOKABLE void queryFlightEvents(int flightId);
    Q_INVOKABLE void queryBatteryTrend(const QString &vehicleUid, int lastN = 20);
    Q_INVOKABLE void queryFlightActivity(int days = 30);
    Q_INVOKABLE void deleteOldFlights(int olderThanDays = 365);

    // File write helper for CSV export — returns true on success
    Q_INVOKABLE bool writeTextFile(const QString &filePath, const QString &content);

    // Called by TelemetryCollector
    void enqueueUpsertVehicle(const QVariantMap &params);
    void enqueueStartFlight(const QVariantMap &params);
    void enqueueEndFlight(const QVariantMap &params);
    void enqueueUpdateTakeoff(const QVariantMap &params);
    void enqueueUpdateLanding(const QVariantMap &params);
    void enqueueTelemetryBatch(const QVariantList &batch);
    void enqueueInsertEvent(const QVariantMap &params);
    void enqueueStoreFlightPath(const QVariantMap &params);
    void enqueueUpdateVehicleStats(const QString &vehicleUid);

signals:
    void readyChanged();
    void fleetSummaryChanged();
    void batteryTrendChanged();
    void flightActivityChanged();
    void telemetryDataChanged();
    void flightPathChanged();

private slots:
    void _vehicleAdded(Vehicle *vehicle);
    void _vehicleRemoved(Vehicle *vehicle);

    // Worker result handlers
    void _onDatabaseReady();
    void _onDatabaseError(const QString &error);
    void _onFlightsResult(const QVariantList &flights);
    void _onVehiclesResult(const QVariantList &vehicles);
    void _onFleetSummaryResult(const QVariantMap &summary);
    void _onFlightEventsResult(int flightId, const QVariantList &events);
    void _onBatteryTrendResult(const QString &vehicleUid, const QVariantList &trend);
    void _onFlightActivityResult(const QVariantList &activity);
    void _onTelemetryResult(int flightId, const QVariantList &snapshots);
    void _onFlightPathResult(int flightId, const QVariantList &path);
    void _onFlightStarted(int flightId, const QString &vehicleUid);

private:
    explicit FlightDatabase(QObject *parent = nullptr);
    ~FlightDatabase() override;
    FlightDatabase(const FlightDatabase &) = delete;
    FlightDatabase &operator=(const FlightDatabase &) = delete;

    void _setupConnections();
    QString _databaseFilePath() const;

    MultiVehicleManager              *_multiVehicleManager = nullptr;
    FlightDatabaseWorker             *_worker = nullptr;
    FlightDataQueryModel             *_flightsModel = nullptr;
    FlightDataQueryModel             *_vehiclesModel = nullptr;
    FlightDataQueryModel             *_eventsModel = nullptr;
    QMap<int, TelemetryCollector *>   _collectors;  // vehicleId -> collector

    bool   _ready            = false;
    int    _totalFlights     = 0;
    int    _totalVehicles    = 0;
    double _totalFlightHours = 0;
    double _totalDistanceKm  = 0;
    double _avgBatteryEndPct = 0;
    double _successRate      = 0;

    QVariantList _batteryTrendData;
    QVariantList _flightActivityData;
    QVariantList _telemetryData;
    QVariantList _flightPathData;

    static FlightDatabase *_instance;
};
