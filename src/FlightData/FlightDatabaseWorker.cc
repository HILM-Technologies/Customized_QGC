/****************************************************************************
 *
 * HILM Ground Control — Flight Database Worker Implementation
 *
 ****************************************************************************/

#include "FlightDatabaseWorker.h"

#include <QtSql/QSqlDatabase>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>
#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QDateTime>

Q_LOGGING_CATEGORY(FlightDatabaseWorkerLog, "FlightDatabaseWorkerLog")

FlightDatabaseWorker::FlightDatabaseWorker(QObject *parent)
    : QThread(parent)
{
}

FlightDatabaseWorker::~FlightDatabaseWorker()
{
    stop();
    wait();
}

void FlightDatabaseWorker::enqueueTask(const FlightDataTask &task)
{
    QMutexLocker lock(&_taskQueueMutex);
    _taskQueue.enqueue(task);
    _waitCondition.wakeOne();
}

void FlightDatabaseWorker::stop()
{
    _stopping = true;
    FlightDataTask shutdownTask;
    shutdownTask.type = FlightDataTaskType::Shutdown;
    enqueueTask(shutdownTask);
}

void FlightDatabaseWorker::run()
{
    if (!_initDatabase()) {
        emit databaseError(QStringLiteral("Failed to initialize flight database"));
        return;
    }

    emit databaseReady();

    while (!_stopping) {
        FlightDataTask task;
        {
            QMutexLocker lock(&_taskQueueMutex);
            if (_taskQueue.isEmpty()) {
                _waitCondition.wait(&_taskQueueMutex);
                if (_taskQueue.isEmpty() || _stopping) {
                    continue;
                }
            }
            task = _taskQueue.dequeue();
        }

        if (task.type == FlightDataTaskType::Shutdown) {
            break;
        }

        _runTask(task);
    }

    // Close database
    _db.reset();
    QSqlDatabase::removeDatabase(kSessionName);
    qCDebug(FlightDatabaseWorkerLog) << "Flight database worker stopped";
}

bool FlightDatabaseWorker::_initDatabase()
{
    // Ensure directory exists
    QFileInfo fi(_databasePath);
    QDir dir = fi.dir();
    if (!dir.exists()) {
        dir.mkpath(QStringLiteral("."));
    }

    _db = std::make_shared<QSqlDatabase>(QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), kSessionName));
    _db->setDatabaseName(_databasePath);
    _db->setConnectOptions(QStringLiteral("QSQLITE_BUSY_TIMEOUT=5000"));

    if (!_db->open()) {
        qCCritical(FlightDatabaseWorkerLog) << "Failed to open flight database:" << _db->lastError().text();
        return false;
    }

    // WAL mode for concurrent read/write
    QSqlQuery query(*_db);
    query.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    query.exec(QStringLiteral("PRAGMA synchronous=NORMAL"));
    query.exec(QStringLiteral("PRAGMA foreign_keys=ON"));

    return _createSchema(*_db);
}

bool FlightDatabaseWorker::_createSchema(QSqlDatabase &db)
{
    QSqlQuery q(db);

    // Schema info
    if (!q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS schema_info ("
        "  key   TEXT PRIMARY KEY NOT NULL,"
        "  value TEXT NOT NULL"
        ")"))) {
        qCCritical(FlightDatabaseWorkerLog) << "Failed to create schema_info:" << q.lastError().text();
        return false;
    }

    // Check schema version
    q.exec(QStringLiteral("SELECT value FROM schema_info WHERE key='schema_version'"));
    if (!q.next()) {
        // First time - insert version
        q.exec(QStringLiteral("INSERT INTO schema_info (key, value) VALUES ('schema_version', '1')"));
        q.exec(QStringLiteral("INSERT INTO schema_info (key, value) VALUES ('created_at', '%1')")
                   .arg(QDateTime::currentDateTimeUtc().toString(Qt::ISODate)));
    }

    // Vehicles table
    if (!q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS vehicles ("
        "  vehicle_uid          TEXT PRIMARY KEY NOT NULL,"
        "  vehicle_id           INTEGER NOT NULL,"
        "  vehicle_type         INTEGER NOT NULL,"
        "  firmware_type        INTEGER NOT NULL,"
        "  firmware_version     TEXT DEFAULT '',"
        "  vehicle_name         TEXT DEFAULT '',"
        "  motor_count          INTEGER DEFAULT 0,"
        "  first_seen_at        TEXT NOT NULL,"
        "  last_seen_at         TEXT NOT NULL,"
        "  total_flights        INTEGER DEFAULT 0,"
        "  total_flight_time_sec REAL DEFAULT 0,"
        "  total_distance_m     REAL DEFAULT 0,"
        "  notes                TEXT DEFAULT ''"
        ")"))) {
        qCCritical(FlightDatabaseWorkerLog) << "Failed to create vehicles:" << q.lastError().text();
        return false;
    }
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_vehicles_id ON vehicles(vehicle_id)"));

    // Flights table
    if (!q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS flights ("
        "  flight_id            INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  vehicle_uid          TEXT NOT NULL REFERENCES vehicles(vehicle_uid),"
        "  vehicle_id           INTEGER NOT NULL,"
        "  armed_at             TEXT NOT NULL,"
        "  disarmed_at          TEXT,"
        "  takeoff_at           TEXT,"
        "  landing_at           TEXT,"
        "  duration_sec         REAL DEFAULT 0,"
        "  flight_distance_m    REAL DEFAULT 0,"
        "  max_altitude_rel_m   REAL DEFAULT 0,"
        "  max_ground_speed_mps REAL DEFAULT 0,"
        "  max_distance_from_home_m REAL DEFAULT 0,"
        "  home_lat             REAL,"
        "  home_lon             REAL,"
        "  home_alt_amsl        REAL,"
        "  flight_mode_at_start TEXT DEFAULT '',"
        "  flight_mode_at_end   TEXT DEFAULT '',"
        "  battery_start_pct    REAL,"
        "  battery_end_pct      REAL,"
        "  gps_satellites_avg   REAL,"
        "  mavlink_loss_pct     REAL,"
        "  status               TEXT DEFAULT 'IN_PROGRESS',"
        "  notes                TEXT DEFAULT ''"
        ")"))) {
        qCCritical(FlightDatabaseWorkerLog) << "Failed to create flights:" << q.lastError().text();
        return false;
    }
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_flights_vehicle ON flights(vehicle_uid)"));
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_flights_armed_at ON flights(armed_at)"));

    // Telemetry snapshots
    if (!q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS telemetry_snapshots ("
        "  snapshot_id          INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  flight_id            INTEGER NOT NULL REFERENCES flights(flight_id),"
        "  timestamp_ms         INTEGER NOT NULL,"
        "  lat                  REAL,"
        "  lon                  REAL,"
        "  alt_rel_m            REAL,"
        "  alt_amsl_m           REAL,"
        "  heading_deg          REAL,"
        "  ground_speed_mps     REAL,"
        "  air_speed_mps        REAL,"
        "  climb_rate_mps       REAL,"
        "  distance_to_home_m   REAL,"
        "  battery_pct          REAL,"
        "  battery_voltage      REAL,"
        "  battery_current      REAL,"
        "  gps_satellites       INTEGER,"
        "  gps_hdop             REAL,"
        "  flight_mode          TEXT,"
        "  throttle_pct         INTEGER"
        ")"))) {
        qCCritical(FlightDatabaseWorkerLog) << "Failed to create telemetry_snapshots:" << q.lastError().text();
        return false;
    }
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_telemetry_flight ON telemetry_snapshots(flight_id)"));
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_telemetry_ts ON telemetry_snapshots(flight_id, timestamp_ms)"));

    // Missions
    if (!q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS missions ("
        "  mission_id           INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  vehicle_uid          TEXT REFERENCES vehicles(vehicle_uid),"
        "  flight_id            INTEGER REFERENCES flights(flight_id),"
        "  mission_name         TEXT DEFAULT '',"
        "  created_at           TEXT NOT NULL,"
        "  uploaded_at          TEXT,"
        "  completed_at         TEXT,"
        "  waypoint_count       INTEGER DEFAULT 0,"
        "  plan_json            TEXT,"
        "  status               TEXT DEFAULT 'CREATED',"
        "  source               TEXT DEFAULT 'PLANNED'"
        ")"))) {
        qCCritical(FlightDatabaseWorkerLog) << "Failed to create missions:" << q.lastError().text();
        return false;
    }
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_missions_vehicle ON missions(vehicle_uid)"));
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_missions_flight ON missions(flight_id)"));

    // Flight events
    if (!q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS flight_events ("
        "  event_id             INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  flight_id            INTEGER NOT NULL REFERENCES flights(flight_id),"
        "  timestamp_ms         INTEGER NOT NULL,"
        "  event_type           TEXT NOT NULL,"
        "  severity             TEXT DEFAULT 'INFO',"
        "  details              TEXT DEFAULT '',"
        "  value_numeric        REAL,"
        "  value_text           TEXT DEFAULT ''"
        ")"))) {
        qCCritical(FlightDatabaseWorkerLog) << "Failed to create flight_events:" << q.lastError().text();
        return false;
    }
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_events_flight ON flight_events(flight_id)"));
    q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS idx_events_type ON flight_events(event_type)"));

    // Flight paths (compressed for map rendering)
    if (!q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS flight_paths ("
        "  path_id              INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  flight_id            INTEGER NOT NULL UNIQUE REFERENCES flights(flight_id),"
        "  path_json            TEXT NOT NULL"
        ")"))) {
        qCCritical(FlightDatabaseWorkerLog) << "Failed to create flight_paths:" << q.lastError().text();
        return false;
    }

    qCDebug(FlightDatabaseWorkerLog) << "Flight database schema created/verified at:" << _databasePath;
    return true;
}

void FlightDatabaseWorker::_runTask(const FlightDataTask &task)
{
    switch (task.type) {
    case FlightDataTaskType::UpsertVehicle:       _upsertVehicle(task.params);         break;
    case FlightDataTaskType::StartFlight:         _startFlight(task.params);           break;
    case FlightDataTaskType::EndFlight:           _endFlight(task.params);             break;
    case FlightDataTaskType::UpdateFlightTakeoff: _updateFlightTakeoff(task.params);   break;
    case FlightDataTaskType::UpdateFlightLanding: _updateFlightLanding(task.params);   break;
    case FlightDataTaskType::InsertTelemetryBatch:_insertTelemetryBatch(task.batchData); break;
    case FlightDataTaskType::InsertEvent:         _insertEvent(task.params);           break;
    case FlightDataTaskType::StoreMission:        _storeMission(task.params);          break;
    case FlightDataTaskType::StoreFlightPath:     _storeFlightPath(task.params);       break;
    case FlightDataTaskType::UpdateVehicleStats:  _updateVehicleStats(task.params);    break;
    case FlightDataTaskType::DeleteOldData:       _deleteOldData(task.params);         break;
    case FlightDataTaskType::QueryFlights:        _queryFlights(task.params);          break;
    case FlightDataTaskType::QueryTelemetry:      _queryTelemetry(task.params);        break;
    case FlightDataTaskType::QueryFlightPath:     _queryFlightPath(task.params);       break;
    case FlightDataTaskType::QueryVehicles:       _queryVehicles(task.params);         break;
    case FlightDataTaskType::QueryFleetSummary:   _queryFleetSummary();                break;
    case FlightDataTaskType::QueryFlightEvents:   _queryFlightEvents(task.params);     break;
    case FlightDataTaskType::QueryBatteryTrend:   _queryBatteryTrend(task.params);     break;
    case FlightDataTaskType::QueryFlightActivity: _queryFlightActivity(task.params);   break;
    case FlightDataTaskType::Shutdown:            break;
    }
}

// ── Write Operations ───────────────────────────────────────────

void FlightDatabaseWorker::_upsertVehicle(const QVariantMap &params)
{
    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "INSERT INTO vehicles (vehicle_uid, vehicle_id, vehicle_type, firmware_type, "
        "firmware_version, vehicle_name, motor_count, first_seen_at, last_seen_at) "
        "VALUES (:uid, :vid, :vtype, :ftype, :fver, :vname, :mcnt, :now, :now) "
        "ON CONFLICT(vehicle_uid) DO UPDATE SET "
        "last_seen_at=:now, vehicle_id=:vid, firmware_version=:fver, vehicle_name=:vname"
    ));
    const QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    q.bindValue(QStringLiteral(":uid"),   params.value(QStringLiteral("vehicleUid")));
    q.bindValue(QStringLiteral(":vid"),   params.value(QStringLiteral("vehicleId")));
    q.bindValue(QStringLiteral(":vtype"), params.value(QStringLiteral("vehicleType")));
    q.bindValue(QStringLiteral(":ftype"), params.value(QStringLiteral("firmwareType")));
    q.bindValue(QStringLiteral(":fver"),  params.value(QStringLiteral("firmwareVersion")));
    q.bindValue(QStringLiteral(":vname"), params.value(QStringLiteral("vehicleName"), QString()));
    q.bindValue(QStringLiteral(":mcnt"),  params.value(QStringLiteral("motorCount"), 0));
    q.bindValue(QStringLiteral(":now"),   now);

    if (!q.exec()) {
        qCWarning(FlightDatabaseWorkerLog) << "Upsert vehicle failed:" << q.lastError().text();
    }
}

void FlightDatabaseWorker::_startFlight(const QVariantMap &params)
{
    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "INSERT INTO flights (vehicle_uid, vehicle_id, armed_at, home_lat, home_lon, home_alt_amsl, "
        "flight_mode_at_start, battery_start_pct, status) "
        "VALUES (:uid, :vid, :armed_at, :hlat, :hlon, :halt, :fmode, :bpct, 'IN_PROGRESS')"
    ));
    q.bindValue(QStringLiteral(":uid"),      params.value(QStringLiteral("vehicleUid")));
    q.bindValue(QStringLiteral(":vid"),      params.value(QStringLiteral("vehicleId")));
    q.bindValue(QStringLiteral(":armed_at"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    q.bindValue(QStringLiteral(":hlat"),     params.value(QStringLiteral("homeLat")));
    q.bindValue(QStringLiteral(":hlon"),     params.value(QStringLiteral("homeLon")));
    q.bindValue(QStringLiteral(":halt"),     params.value(QStringLiteral("homeAltAmsl")));
    q.bindValue(QStringLiteral(":fmode"),    params.value(QStringLiteral("flightMode")));
    q.bindValue(QStringLiteral(":bpct"),     params.value(QStringLiteral("batteryPct")));

    if (q.exec()) {
        const int flightId = q.lastInsertId().toInt();
        const QString uid = params.value(QStringLiteral("vehicleUid")).toString();
        qCDebug(FlightDatabaseWorkerLog) << "Flight started: id=" << flightId << "vehicle=" << uid;
        emit flightStarted(flightId, uid);
    } else {
        qCWarning(FlightDatabaseWorkerLog) << "Start flight failed:" << q.lastError().text();
    }
}

void FlightDatabaseWorker::_endFlight(const QVariantMap &params)
{
    const int flightId = params.value(QStringLiteral("flightId")).toInt();

    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "UPDATE flights SET "
        "disarmed_at=:disarmed, duration_sec=:dur, flight_distance_m=:dist, "
        "max_altitude_rel_m=:maxalt, max_ground_speed_mps=:maxspd, "
        "max_distance_from_home_m=:maxhome, flight_mode_at_end=:fmode, "
        "battery_end_pct=:bpct, gps_satellites_avg=:gpsavg, mavlink_loss_pct=:mloss, "
        "status=:status "
        "WHERE flight_id=:fid"
    ));
    q.bindValue(QStringLiteral(":disarmed"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    q.bindValue(QStringLiteral(":dur"),      params.value(QStringLiteral("durationSec")));
    q.bindValue(QStringLiteral(":dist"),     params.value(QStringLiteral("flightDistanceM")));
    q.bindValue(QStringLiteral(":maxalt"),   params.value(QStringLiteral("maxAltitudeRelM")));
    q.bindValue(QStringLiteral(":maxspd"),   params.value(QStringLiteral("maxGroundSpeedMps")));
    q.bindValue(QStringLiteral(":maxhome"),  params.value(QStringLiteral("maxDistanceFromHomeM")));
    q.bindValue(QStringLiteral(":fmode"),    params.value(QStringLiteral("flightMode")));
    q.bindValue(QStringLiteral(":bpct"),     params.value(QStringLiteral("batteryPct")));
    q.bindValue(QStringLiteral(":gpsavg"),   params.value(QStringLiteral("gpsSatellitesAvg")));
    q.bindValue(QStringLiteral(":mloss"),    params.value(QStringLiteral("mavlinkLossPct")));
    q.bindValue(QStringLiteral(":status"),   params.value(QStringLiteral("status"), QStringLiteral("COMPLETED")));
    q.bindValue(QStringLiteral(":fid"),      flightId);

    if (q.exec()) {
        qCDebug(FlightDatabaseWorkerLog) << "Flight ended: id=" << flightId;
        emit flightEnded(flightId);
    } else {
        qCWarning(FlightDatabaseWorkerLog) << "End flight failed:" << q.lastError().text();
    }
}

void FlightDatabaseWorker::_updateFlightTakeoff(const QVariantMap &params)
{
    QSqlQuery q(*_db);
    q.prepare(QStringLiteral("UPDATE flights SET takeoff_at=:t WHERE flight_id=:fid"));
    q.bindValue(QStringLiteral(":t"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    q.bindValue(QStringLiteral(":fid"), params.value(QStringLiteral("flightId")));
    if (!q.exec()) {
        qCWarning(FlightDatabaseWorkerLog) << "Update takeoff failed:" << q.lastError().text();
    }
}

void FlightDatabaseWorker::_updateFlightLanding(const QVariantMap &params)
{
    QSqlQuery q(*_db);
    q.prepare(QStringLiteral("UPDATE flights SET landing_at=:t WHERE flight_id=:fid"));
    q.bindValue(QStringLiteral(":t"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    q.bindValue(QStringLiteral(":fid"), params.value(QStringLiteral("flightId")));
    if (!q.exec()) {
        qCWarning(FlightDatabaseWorkerLog) << "Update landing failed:" << q.lastError().text();
    }
}

void FlightDatabaseWorker::_insertTelemetryBatch(const QVariantList &batch)
{
    if (batch.isEmpty()) return;

    _db->transaction();
    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "INSERT INTO telemetry_snapshots "
        "(flight_id, timestamp_ms, lat, lon, alt_rel_m, alt_amsl_m, heading_deg, "
        "ground_speed_mps, air_speed_mps, climb_rate_mps, distance_to_home_m, "
        "battery_pct, battery_voltage, battery_current, gps_satellites, gps_hdop, "
        "flight_mode, throttle_pct) "
        "VALUES (:fid, :ts, :lat, :lon, :altrel, :altamsl, :hdg, :gspd, :aspd, "
        ":climb, :dhome, :bpct, :bv, :bc, :gsat, :ghdop, :fmode, :thr)"
    ));

    for (const QVariant &item : batch) {
        const QVariantMap m = item.toMap();
        q.bindValue(QStringLiteral(":fid"),     m.value(QStringLiteral("flightId")));
        q.bindValue(QStringLiteral(":ts"),      m.value(QStringLiteral("timestampMs")));
        q.bindValue(QStringLiteral(":lat"),     m.value(QStringLiteral("lat")));
        q.bindValue(QStringLiteral(":lon"),     m.value(QStringLiteral("lon")));
        q.bindValue(QStringLiteral(":altrel"),  m.value(QStringLiteral("altRelM")));
        q.bindValue(QStringLiteral(":altamsl"), m.value(QStringLiteral("altAmslM")));
        q.bindValue(QStringLiteral(":hdg"),     m.value(QStringLiteral("headingDeg")));
        q.bindValue(QStringLiteral(":gspd"),    m.value(QStringLiteral("groundSpeedMps")));
        q.bindValue(QStringLiteral(":aspd"),    m.value(QStringLiteral("airSpeedMps")));
        q.bindValue(QStringLiteral(":climb"),   m.value(QStringLiteral("climbRateMps")));
        q.bindValue(QStringLiteral(":dhome"),   m.value(QStringLiteral("distanceToHomeM")));
        q.bindValue(QStringLiteral(":bpct"),    m.value(QStringLiteral("batteryPct")));
        q.bindValue(QStringLiteral(":bv"),      m.value(QStringLiteral("batteryVoltage")));
        q.bindValue(QStringLiteral(":bc"),      m.value(QStringLiteral("batteryCurrent")));
        q.bindValue(QStringLiteral(":gsat"),    m.value(QStringLiteral("gpsSatellites")));
        q.bindValue(QStringLiteral(":ghdop"),   m.value(QStringLiteral("gpsHdop")));
        q.bindValue(QStringLiteral(":fmode"),   m.value(QStringLiteral("flightMode")));
        q.bindValue(QStringLiteral(":thr"),     m.value(QStringLiteral("throttlePct")));

        if (!q.exec()) {
            qCWarning(FlightDatabaseWorkerLog) << "Insert telemetry failed:" << q.lastError().text();
        }
    }
    _db->commit();
}

void FlightDatabaseWorker::_insertEvent(const QVariantMap &params)
{
    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "INSERT INTO flight_events (flight_id, timestamp_ms, event_type, severity, details, value_numeric, value_text) "
        "VALUES (:fid, :ts, :etype, :sev, :det, :vnum, :vtxt)"
    ));
    q.bindValue(QStringLiteral(":fid"),   params.value(QStringLiteral("flightId")));
    q.bindValue(QStringLiteral(":ts"),    params.value(QStringLiteral("timestampMs")));
    q.bindValue(QStringLiteral(":etype"), params.value(QStringLiteral("eventType")));
    q.bindValue(QStringLiteral(":sev"),   params.value(QStringLiteral("severity"), QStringLiteral("INFO")));
    q.bindValue(QStringLiteral(":det"),   params.value(QStringLiteral("details"), QString()));
    q.bindValue(QStringLiteral(":vnum"),  params.value(QStringLiteral("valueNumeric")));
    q.bindValue(QStringLiteral(":vtxt"),  params.value(QStringLiteral("valueText"), QString()));

    if (!q.exec()) {
        qCWarning(FlightDatabaseWorkerLog) << "Insert event failed:" << q.lastError().text();
    }
}

void FlightDatabaseWorker::_storeMission(const QVariantMap &params)
{
    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "INSERT INTO missions (vehicle_uid, flight_id, mission_name, created_at, "
        "waypoint_count, plan_json, status, source) "
        "VALUES (:uid, :fid, :name, :created, :wpc, :pjson, :status, :source)"
    ));
    q.bindValue(QStringLiteral(":uid"),     params.value(QStringLiteral("vehicleUid")));
    q.bindValue(QStringLiteral(":fid"),     params.value(QStringLiteral("flightId")));
    q.bindValue(QStringLiteral(":name"),    params.value(QStringLiteral("missionName"), QString()));
    q.bindValue(QStringLiteral(":created"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    q.bindValue(QStringLiteral(":wpc"),     params.value(QStringLiteral("waypointCount"), 0));
    q.bindValue(QStringLiteral(":pjson"),   params.value(QStringLiteral("planJson"), QString()));
    q.bindValue(QStringLiteral(":status"),  params.value(QStringLiteral("status"), QStringLiteral("CREATED")));
    q.bindValue(QStringLiteral(":source"),  params.value(QStringLiteral("source"), QStringLiteral("PLANNED")));

    if (!q.exec()) {
        qCWarning(FlightDatabaseWorkerLog) << "Store mission failed:" << q.lastError().text();
    }
}

void FlightDatabaseWorker::_storeFlightPath(const QVariantMap &params)
{
    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "INSERT OR REPLACE INTO flight_paths (flight_id, path_json) VALUES (:fid, :path)"
    ));
    q.bindValue(QStringLiteral(":fid"),  params.value(QStringLiteral("flightId")));
    q.bindValue(QStringLiteral(":path"), params.value(QStringLiteral("pathJson")));

    if (!q.exec()) {
        qCWarning(FlightDatabaseWorkerLog) << "Store flight path failed:" << q.lastError().text();
    }
}

void FlightDatabaseWorker::_updateVehicleStats(const QVariantMap &params)
{
    const QString uid = params.value(QStringLiteral("vehicleUid")).toString();

    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "UPDATE vehicles SET "
        "total_flights = (SELECT COUNT(*) FROM flights WHERE vehicle_uid=:uid AND status='COMPLETED'),"
        "total_flight_time_sec = COALESCE((SELECT SUM(duration_sec) FROM flights WHERE vehicle_uid=:uid AND status='COMPLETED'), 0),"
        "total_distance_m = COALESCE((SELECT SUM(flight_distance_m) FROM flights WHERE vehicle_uid=:uid AND status='COMPLETED'), 0) "
        "WHERE vehicle_uid=:uid"
    ));
    q.bindValue(QStringLiteral(":uid"), uid);

    if (q.exec()) {
        emit vehicleStatsUpdated(uid);
    } else {
        qCWarning(FlightDatabaseWorkerLog) << "Update vehicle stats failed:" << q.lastError().text();
    }
}

void FlightDatabaseWorker::_deleteOldData(const QVariantMap &params)
{
    const int days = params.value(QStringLiteral("olderThanDays"), 365).toInt();
    const QString cutoff = QDateTime::currentDateTimeUtc().addDays(-days).toString(Qt::ISODate);

    _db->transaction();
    QSqlQuery q(*_db);

    // Delete telemetry for old flights
    q.exec(QStringLiteral(
        "DELETE FROM telemetry_snapshots WHERE flight_id IN "
        "(SELECT flight_id FROM flights WHERE armed_at < '%1')").arg(cutoff));

    // Delete events for old flights
    q.exec(QStringLiteral(
        "DELETE FROM flight_events WHERE flight_id IN "
        "(SELECT flight_id FROM flights WHERE armed_at < '%1')").arg(cutoff));

    // Delete paths for old flights
    q.exec(QStringLiteral(
        "DELETE FROM flight_paths WHERE flight_id IN "
        "(SELECT flight_id FROM flights WHERE armed_at < '%1')").arg(cutoff));

    // Delete old flights themselves
    q.exec(QStringLiteral("DELETE FROM flights WHERE armed_at < '%1'").arg(cutoff));

    _db->commit();

    // Vacuum to reclaim space
    q.exec(QStringLiteral("VACUUM"));

    qCDebug(FlightDatabaseWorkerLog) << "Deleted flight data older than" << days << "days";
}

// ── Read Operations ────────────────────────────────────────────

void FlightDatabaseWorker::_queryFlights(const QVariantMap &params)
{
    QString sql = QStringLiteral(
        "SELECT f.*, COALESCE(v.vehicle_name, '') as vehicle_name "
        "FROM flights f LEFT JOIN vehicles v ON f.vehicle_uid = v.vehicle_uid "
        "WHERE 1=1 "
    );

    const QString vehicleUid = params.value(QStringLiteral("vehicleUid")).toString();
    const QString dateFrom   = params.value(QStringLiteral("dateFrom")).toString();
    const QString dateTo     = params.value(QStringLiteral("dateTo")).toString();
    const QString status     = params.value(QStringLiteral("status")).toString();
    const int limit          = params.value(QStringLiteral("limit"), 100).toInt();

    if (!vehicleUid.isEmpty()) sql += QStringLiteral(" AND f.vehicle_uid='%1'").arg(vehicleUid);
    if (!dateFrom.isEmpty())   sql += QStringLiteral(" AND f.armed_at >= '%1'").arg(dateFrom);
    if (!dateTo.isEmpty())     sql += QStringLiteral(" AND f.armed_at <= '%1'").arg(dateTo);
    if (!status.isEmpty())     sql += QStringLiteral(" AND f.status='%1'").arg(status);

    sql += QStringLiteral(" ORDER BY f.armed_at DESC LIMIT %1").arg(limit);

    QSqlQuery q(*_db);
    QVariantList results;

    if (q.exec(sql)) {
        while (q.next()) {
            QVariantMap row;
            row[QStringLiteral("flightId")]       = q.value(QStringLiteral("flight_id"));
            row[QStringLiteral("vehicleUid")]     = q.value(QStringLiteral("vehicle_uid"));
            row[QStringLiteral("vehicleId")]      = q.value(QStringLiteral("vehicle_id"));
            row[QStringLiteral("armedAt")]        = q.value(QStringLiteral("armed_at"));
            row[QStringLiteral("disarmedAt")]     = q.value(QStringLiteral("disarmed_at"));
            row[QStringLiteral("takeoffAt")]      = q.value(QStringLiteral("takeoff_at"));
            row[QStringLiteral("landingAt")]      = q.value(QStringLiteral("landing_at"));
            row[QStringLiteral("durationSec")]    = q.value(QStringLiteral("duration_sec"));
            row[QStringLiteral("flightDistanceM")]= q.value(QStringLiteral("flight_distance_m"));
            row[QStringLiteral("maxAltitudeRelM")]= q.value(QStringLiteral("max_altitude_rel_m"));
            row[QStringLiteral("maxGroundSpeedMps")] = q.value(QStringLiteral("max_ground_speed_mps"));
            row[QStringLiteral("maxDistanceFromHomeM")] = q.value(QStringLiteral("max_distance_from_home_m"));
            row[QStringLiteral("flightModeAtStart")] = q.value(QStringLiteral("flight_mode_at_start"));
            row[QStringLiteral("flightModeAtEnd")]   = q.value(QStringLiteral("flight_mode_at_end"));
            row[QStringLiteral("batteryStartPct")]   = q.value(QStringLiteral("battery_start_pct"));
            row[QStringLiteral("batteryEndPct")]     = q.value(QStringLiteral("battery_end_pct"));
            row[QStringLiteral("status")]         = q.value(QStringLiteral("status"));
            row[QStringLiteral("vehicleName")]    = q.value(QStringLiteral("vehicle_name"));
            results.append(row);
        }
    } else {
        qCWarning(FlightDatabaseWorkerLog) << "Query flights failed:" << q.lastError().text();
    }

    emit flightsResult(results);
}

void FlightDatabaseWorker::_queryTelemetry(const QVariantMap &params)
{
    const int flightId = params.value(QStringLiteral("flightId")).toInt();

    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "SELECT * FROM telemetry_snapshots WHERE flight_id=:fid ORDER BY timestamp_ms ASC"
    ));
    q.bindValue(QStringLiteral(":fid"), flightId);

    QVariantList results;
    if (q.exec()) {
        while (q.next()) {
            QVariantMap row;
            row[QStringLiteral("timestampMs")]    = q.value(QStringLiteral("timestamp_ms"));
            row[QStringLiteral("lat")]            = q.value(QStringLiteral("lat"));
            row[QStringLiteral("lon")]            = q.value(QStringLiteral("lon"));
            row[QStringLiteral("altRelM")]        = q.value(QStringLiteral("alt_rel_m"));
            row[QStringLiteral("altAmslM")]       = q.value(QStringLiteral("alt_amsl_m"));
            row[QStringLiteral("headingDeg")]     = q.value(QStringLiteral("heading_deg"));
            row[QStringLiteral("groundSpeedMps")] = q.value(QStringLiteral("ground_speed_mps"));
            row[QStringLiteral("airSpeedMps")]    = q.value(QStringLiteral("air_speed_mps"));
            row[QStringLiteral("climbRateMps")]   = q.value(QStringLiteral("climb_rate_mps"));
            row[QStringLiteral("distanceToHomeM")]= q.value(QStringLiteral("distance_to_home_m"));
            row[QStringLiteral("batteryPct")]     = q.value(QStringLiteral("battery_pct"));
            row[QStringLiteral("batteryVoltage")] = q.value(QStringLiteral("battery_voltage"));
            row[QStringLiteral("flightMode")]     = q.value(QStringLiteral("flight_mode"));
            row[QStringLiteral("throttlePct")]    = q.value(QStringLiteral("throttle_pct"));
            results.append(row);
        }
    }

    emit telemetryResult(flightId, results);
}

void FlightDatabaseWorker::_queryFlightPath(const QVariantMap &params)
{
    const int flightId = params.value(QStringLiteral("flightId")).toInt();

    QSqlQuery q(*_db);
    q.prepare(QStringLiteral("SELECT path_json FROM flight_paths WHERE flight_id=:fid"));
    q.bindValue(QStringLiteral(":fid"), flightId);

    QVariantList path;
    if (q.exec() && q.next()) {
        const QJsonDocument doc = QJsonDocument::fromJson(q.value(0).toString().toUtf8());
        const QJsonArray arr = doc.array();
        for (const QJsonValue &v : arr) {
            path.append(v.toArray().toVariantList());
        }
    }

    emit flightPathResult(flightId, path);
}

void FlightDatabaseWorker::_queryVehicles(const QVariantMap &params)
{
    Q_UNUSED(params)

    QSqlQuery q(*_db);
    QVariantList results;

    if (q.exec(QStringLiteral("SELECT * FROM vehicles ORDER BY last_seen_at DESC"))) {
        while (q.next()) {
            QVariantMap row;
            row[QStringLiteral("vehicleUid")]       = q.value(QStringLiteral("vehicle_uid"));
            row[QStringLiteral("vehicleId")]        = q.value(QStringLiteral("vehicle_id"));
            row[QStringLiteral("vehicleType")]      = q.value(QStringLiteral("vehicle_type"));
            row[QStringLiteral("firmwareType")]     = q.value(QStringLiteral("firmware_type"));
            row[QStringLiteral("firmwareVersion")]  = q.value(QStringLiteral("firmware_version"));
            row[QStringLiteral("vehicleName")]      = q.value(QStringLiteral("vehicle_name"));
            row[QStringLiteral("firstSeenAt")]      = q.value(QStringLiteral("first_seen_at"));
            row[QStringLiteral("lastSeenAt")]       = q.value(QStringLiteral("last_seen_at"));
            row[QStringLiteral("totalFlights")]     = q.value(QStringLiteral("total_flights"));
            row[QStringLiteral("totalFlightTimeSec")] = q.value(QStringLiteral("total_flight_time_sec"));
            row[QStringLiteral("totalDistanceM")]   = q.value(QStringLiteral("total_distance_m"));
            results.append(row);
        }
    }

    emit vehiclesResult(results);
}

void FlightDatabaseWorker::_queryFleetSummary()
{
    QVariantMap summary;

    QSqlQuery q(*_db);

    // Total flights
    q.exec(QStringLiteral("SELECT COUNT(*) FROM flights WHERE status='COMPLETED'"));
    summary[QStringLiteral("totalFlights")] = q.next() ? q.value(0).toInt() : 0;

    // Total vehicles
    q.exec(QStringLiteral("SELECT COUNT(*) FROM vehicles"));
    summary[QStringLiteral("totalVehicles")] = q.next() ? q.value(0).toInt() : 0;

    // Total flight hours
    q.exec(QStringLiteral("SELECT COALESCE(SUM(duration_sec), 0) / 3600.0 FROM flights WHERE status='COMPLETED'"));
    summary[QStringLiteral("totalFlightHours")] = q.next() ? q.value(0).toDouble() : 0.0;

    // Total distance
    q.exec(QStringLiteral("SELECT COALESCE(SUM(flight_distance_m), 0) / 1000.0 FROM flights WHERE status='COMPLETED'"));
    summary[QStringLiteral("totalDistanceKm")] = q.next() ? q.value(0).toDouble() : 0.0;

    // Average end battery
    q.exec(QStringLiteral("SELECT AVG(battery_end_pct) FROM flights WHERE status='COMPLETED' AND battery_end_pct >= 0"));
    summary[QStringLiteral("avgBatteryEndPct")] = q.next() ? q.value(0).toDouble() : 0.0;

    // Success rate
    q.exec(QStringLiteral("SELECT COUNT(*) FROM flights"));
    const int total = q.next() ? q.value(0).toInt() : 0;
    q.exec(QStringLiteral("SELECT COUNT(*) FROM flights WHERE status='COMPLETED'"));
    const int completed = q.next() ? q.value(0).toInt() : 0;
    summary[QStringLiteral("successRate")] = total > 0 ? (completed * 100.0 / total) : 0.0;

    emit fleetSummaryResult(summary);
}

void FlightDatabaseWorker::_queryFlightEvents(const QVariantMap &params)
{
    const int flightId = params.value(QStringLiteral("flightId")).toInt();

    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "SELECT * FROM flight_events WHERE flight_id=:fid ORDER BY timestamp_ms ASC"
    ));
    q.bindValue(QStringLiteral(":fid"), flightId);

    QVariantList results;
    if (q.exec()) {
        while (q.next()) {
            QVariantMap row;
            row[QStringLiteral("eventId")]      = q.value(QStringLiteral("event_id"));
            row[QStringLiteral("flightId")]     = q.value(QStringLiteral("flight_id"));
            row[QStringLiteral("timestampMs")]  = q.value(QStringLiteral("timestamp_ms"));
            row[QStringLiteral("eventType")]    = q.value(QStringLiteral("event_type"));
            row[QStringLiteral("severity")]     = q.value(QStringLiteral("severity"));
            row[QStringLiteral("details")]      = q.value(QStringLiteral("details"));
            row[QStringLiteral("valueNumeric")] = q.value(QStringLiteral("value_numeric"));
            row[QStringLiteral("valueText")]    = q.value(QStringLiteral("value_text"));
            results.append(row);
        }
    }

    emit flightEventsResult(flightId, results);
}

void FlightDatabaseWorker::_queryBatteryTrend(const QVariantMap &params)
{
    const QString vehicleUid = params.value(QStringLiteral("vehicleUid")).toString();
    const int lastN = params.value(QStringLiteral("lastN"), 20).toInt();

    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "SELECT armed_at, battery_start_pct, battery_end_pct, duration_sec "
        "FROM flights WHERE vehicle_uid=:uid AND status='COMPLETED' AND battery_end_pct >= 0 "
        "ORDER BY armed_at DESC LIMIT :n"
    ));
    q.bindValue(QStringLiteral(":uid"), vehicleUid);
    q.bindValue(QStringLiteral(":n"), lastN);

    QVariantList results;
    if (q.exec()) {
        while (q.next()) {
            QVariantMap row;
            row[QStringLiteral("armedAt")]         = q.value(QStringLiteral("armed_at"));
            row[QStringLiteral("batteryStartPct")] = q.value(QStringLiteral("battery_start_pct"));
            row[QStringLiteral("batteryEndPct")]   = q.value(QStringLiteral("battery_end_pct"));
            row[QStringLiteral("durationSec")]     = q.value(QStringLiteral("duration_sec"));
            results.append(row);
        }
    }

    emit batteryTrendResult(vehicleUid, results);
}

void FlightDatabaseWorker::_queryFlightActivity(const QVariantMap &params)
{
    const int days = params.value(QStringLiteral("days"), 30).toInt();
    const QString since = QDateTime::currentDateTimeUtc().addDays(-days).toString(Qt::ISODate);

    QSqlQuery q(*_db);
    q.prepare(QStringLiteral(
        "SELECT DATE(armed_at) as flight_date, vehicle_uid, COUNT(*) as flight_count "
        "FROM flights WHERE armed_at >= :since "
        "GROUP BY flight_date, vehicle_uid "
        "ORDER BY flight_date ASC"
    ));
    q.bindValue(QStringLiteral(":since"), since);

    QVariantList results;
    if (q.exec()) {
        while (q.next()) {
            QVariantMap row;
            row[QStringLiteral("date")]        = q.value(QStringLiteral("flight_date"));
            row[QStringLiteral("vehicleUid")]  = q.value(QStringLiteral("vehicle_uid"));
            row[QStringLiteral("flightCount")] = q.value(QStringLiteral("flight_count"));
            results.append(row);
        }
    }

    emit flightActivityResult(results);
}
