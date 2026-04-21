/****************************************************************************
 *
 * HILM Ground Control — Telemetry Collector Implementation
 *
 ****************************************************************************/

#include "TelemetryCollector.h"
#include "FlightDatabase.h"
#include "Vehicle.h"
#include "BatteryFactGroupListModel.h"
#include "VehicleGPSFactGroup.h"
#include "Fact.h"

#include <QGeoCoordinate>
#include <QJsonArray>
#include <QJsonDocument>

TelemetryCollector::TelemetryCollector(Vehicle *vehicle, FlightDatabase *db, QObject *parent)
    : QObject(parent)
    , _vehicle(vehicle)
    , _db(db)
{
    // Determine vehicle UID (prefer hardware UID, fallback to ID string)
    const quint64 uid = _vehicle->vehicleUID();
    _vehicleUid = uid > 0 ? QString::number(uid, 16)
                          : QStringLiteral("mavid_%1").arg(_vehicle->id());

    // Register/update the vehicle in the database
    QVariantMap vparams;
    vparams[QStringLiteral("vehicleUid")]       = _vehicleUid;
    vparams[QStringLiteral("vehicleId")]        = _vehicle->id();
    vparams[QStringLiteral("vehicleType")]      = static_cast<int>(_vehicle->vehicleType());
    vparams[QStringLiteral("firmwareType")]     = static_cast<int>(_vehicle->firmwareType());
    vparams[QStringLiteral("firmwareVersion")]  = QStringLiteral("%1.%2.%3")
                                                      .arg(_vehicle->firmwareMajorVersion())
                                                      .arg(_vehicle->firmwareMinorVersion())
                                                      .arg(_vehicle->firmwarePatchVersion());
    vparams[QStringLiteral("motorCount")]       = _vehicle->motorCount();
    _db->enqueueUpsertVehicle(vparams);

    // Connect vehicle signals
    connect(_vehicle, &Vehicle::armedChanged,
            this,     &TelemetryCollector::_onArmedChanged);
    connect(_vehicle, &Vehicle::flyingChanged,
            this,     &TelemetryCollector::_onFlyingChanged);
    connect(_vehicle, &Vehicle::flightModeChanged,
            this,     &TelemetryCollector::_onFlightModeChanged);

    // Sample timer (only runs while armed)
    _sampleTimer.setInterval(kSampleIntervalMs);
    connect(&_sampleTimer, &QTimer::timeout,
            this,          &TelemetryCollector::_onSampleTimer);

    // If vehicle is already armed when collector is created
    if (_vehicle->armed()) {
        _onArmedChanged(true);
    }
}

TelemetryCollector::~TelemetryCollector()
{
    _sampleTimer.stop();
    _flushBatch();

    // If still in flight, end it as ABORTED
    if (_flightActive && _currentFlightId > 0) {
        _endFlight();
    }
}

void TelemetryCollector::setCurrentFlightId(int flightId)
{
    _currentFlightId = flightId;
}

// ── Signal handlers ────────────────────────────────────────────

void TelemetryCollector::_onArmedChanged(bool armed)
{
    if (armed) {
        _startFlight();
    } else {
        _endFlight();
    }
}

void TelemetryCollector::_onFlyingChanged(bool flying)
{
    if (_currentFlightId < 0) return;

    if (flying) {
        QVariantMap params;
        params[QStringLiteral("flightId")] = _currentFlightId;
        _db->enqueueUpdateTakeoff(params);
        _insertEvent(QStringLiteral("TAKEOFF"), QStringLiteral("INFO"),
                     QStringLiteral("Vehicle airborne"));
    } else {
        QVariantMap params;
        params[QStringLiteral("flightId")] = _currentFlightId;
        _db->enqueueUpdateLanding(params);
        _insertEvent(QStringLiteral("LANDING"), QStringLiteral("INFO"),
                     QStringLiteral("Vehicle landed"));
    }
}

void TelemetryCollector::_onFlightModeChanged(const QString &flightMode)
{
    if (_currentFlightId < 0) return;
    _insertEvent(QStringLiteral("MODE_CHANGE"), QStringLiteral("INFO"),
                 QStringLiteral("Flight mode changed to %1").arg(flightMode),
                 0, flightMode);
}

void TelemetryCollector::_onSampleTimer()
{
    if (!_flightActive || _currentFlightId < 0) return;
    _captureSnapshot();
}

// ── Flight lifecycle ───────────────────────────────────────────

void TelemetryCollector::_startFlight()
{
    if (_flightActive) return;
    _flightActive = true;

    // Reset tracking
    _maxAltitudeRelM      = 0;
    _maxGroundSpeedMps    = 0;
    _maxDistanceFromHomeM = 0;
    _gpsSatellitesSum     = 0;
    _gpsSatellitesSamples = 0;
    _lowBatteryFired      = false;
    _gpsLowFired          = false;
    _snapshotBatch.clear();
    _currentFlightId = -1;  // Will be set by _onFlightStarted callback

    _flightElapsed.start();

    // Build start-flight params
    QVariantMap params;
    params[QStringLiteral("vehicleUid")]  = _vehicleUid;
    params[QStringLiteral("vehicleId")]   = _vehicle->id();
    params[QStringLiteral("flightMode")]  = _vehicle->flightMode();
    params[QStringLiteral("batteryPct")]  = _getBatteryPct();

    const QGeoCoordinate home = _vehicle->homePosition();
    if (home.isValid()) {
        params[QStringLiteral("homeLat")]     = home.latitude();
        params[QStringLiteral("homeLon")]     = home.longitude();
        params[QStringLiteral("homeAltAmsl")] = home.altitude();
    }

    _db->enqueueStartFlight(params);

    _insertEvent(QStringLiteral("ARMED"), QStringLiteral("INFO"),
                 QStringLiteral("Vehicle armed"));

    // Start periodic sampling
    _sampleTimer.start();
}

void TelemetryCollector::_endFlight()
{
    if (!_flightActive) return;
    _flightActive = false;
    _sampleTimer.stop();

    // Flush remaining telemetry
    _flushBatch();

    _insertEvent(QStringLiteral("DISARMED"), QStringLiteral("INFO"),
                 QStringLiteral("Vehicle disarmed"));

    if (_currentFlightId > 0) {
        const double durationSec = _flightElapsed.elapsed() / 1000.0;
        const double avgSats = _gpsSatellitesSamples > 0
                                   ? _gpsSatellitesSum / _gpsSatellitesSamples
                                   : 0;

        QVariantMap params;
        params[QStringLiteral("flightId")]          = _currentFlightId;
        params[QStringLiteral("vehicleUid")]        = _vehicleUid;
        params[QStringLiteral("durationSec")]       = durationSec;
        params[QStringLiteral("flightDistanceM")]   = _vehicle->flightDistance()->rawValue().toDouble();
        params[QStringLiteral("maxAltitudeRelM")]   = _maxAltitudeRelM;
        params[QStringLiteral("maxGroundSpeedMps")] = _maxGroundSpeedMps;
        params[QStringLiteral("maxDistanceFromHomeM")] = _maxDistanceFromHomeM;
        params[QStringLiteral("flightMode")]        = _vehicle->flightMode();
        params[QStringLiteral("batteryPct")]        = _getBatteryPct();
        params[QStringLiteral("gpsSatellitesAvg")]  = avgSats;
        params[QStringLiteral("mavlinkLossPct")]    = _vehicle->mavlinkLossPercent();
        params[QStringLiteral("status")]            = QStringLiteral("COMPLETED");

        _db->enqueueEndFlight(params);

        // Store simplified flight path from telemetry snapshots
        // Build path JSON from captured coordinates
        _buildAndStoreFlightPath();
    }

    _currentFlightId = -1;
}

// ── Telemetry capture ──────────────────────────────────────────

void TelemetryCollector::_captureSnapshot()
{
    const QGeoCoordinate coord = _vehicle->coordinate();
    const double altRel   = _vehicle->altitudeRelative()->rawValue().toDouble();
    const double altAmsl  = _vehicle->altitudeAMSL()->rawValue().toDouble();
    const double heading  = _vehicle->heading()->rawValue().toDouble();
    const double gspd     = _vehicle->groundSpeed()->rawValue().toDouble();
    const double aspd     = _vehicle->airSpeed()->rawValue().toDouble();
    const double climb    = _vehicle->climbRate()->rawValue().toDouble();
    const double dhome    = _vehicle->distanceToHome()->rawValue().toDouble();
    const double bpct     = _getBatteryPct();
    const double bv       = _getBatteryVoltage();
    const double bc       = _getBatteryCurrent();
    const int    gsat     = _getGpsSatellites();
    const double ghdop    = _getGpsHdop();
    const int    thr      = _vehicle->throttlePct()->rawValue().toInt();

    // Update max tracking
    if (altRel > _maxAltitudeRelM)      _maxAltitudeRelM = altRel;
    if (gspd > _maxGroundSpeedMps)      _maxGroundSpeedMps = gspd;
    if (dhome > _maxDistanceFromHomeM)  _maxDistanceFromHomeM = dhome;

    _gpsSatellitesSum += gsat;
    _gpsSatellitesSamples++;

    // Check battery threshold
    if (!_lowBatteryFired && bpct >= 0 && bpct < 30) {
        _lowBatteryFired = true;
        _insertEvent(QStringLiteral("LOW_BATTERY"), QStringLiteral("WARNING"),
                     QStringLiteral("Battery below 30%%: %1%%").arg(bpct, 0, 'f', 1),
                     bpct);
    }

    // Check GPS degradation
    if (!_gpsLowFired && gsat > 0 && gsat < 6) {
        _gpsLowFired = true;
        _insertEvent(QStringLiteral("GPS_DEGRADED"), QStringLiteral("WARNING"),
                     QStringLiteral("GPS satellites: %1").arg(gsat),
                     gsat);
    } else if (_gpsLowFired && gsat >= 6) {
        _gpsLowFired = false;  // Reset when recovered
    }

    // Build snapshot
    QVariantMap snap;
    snap[QStringLiteral("flightId")]       = _currentFlightId;
    snap[QStringLiteral("timestampMs")]    = _flightElapsed.elapsed();
    snap[QStringLiteral("lat")]            = coord.latitude();
    snap[QStringLiteral("lon")]            = coord.longitude();
    snap[QStringLiteral("altRelM")]        = altRel;
    snap[QStringLiteral("altAmslM")]       = altAmsl;
    snap[QStringLiteral("headingDeg")]     = heading;
    snap[QStringLiteral("groundSpeedMps")] = gspd;
    snap[QStringLiteral("airSpeedMps")]    = aspd;
    snap[QStringLiteral("climbRateMps")]   = climb;
    snap[QStringLiteral("distanceToHomeM")]= dhome;
    snap[QStringLiteral("batteryPct")]     = bpct;
    snap[QStringLiteral("batteryVoltage")] = bv;
    snap[QStringLiteral("batteryCurrent")] = bc;
    snap[QStringLiteral("gpsSatellites")]  = gsat;
    snap[QStringLiteral("gpsHdop")]        = ghdop;
    snap[QStringLiteral("flightMode")]     = _vehicle->flightMode();
    snap[QStringLiteral("throttlePct")]    = thr;

    _snapshotBatch.append(snap);

    if (_snapshotBatch.size() >= kBatchSize) {
        _flushBatch();
    }
}

void TelemetryCollector::_flushBatch()
{
    if (_snapshotBatch.isEmpty()) return;
    _db->enqueueTelemetryBatch(_snapshotBatch);
    _snapshotBatch.clear();
}

// ── Helper: build flight path from snapshots ───────────────────

void TelemetryCollector::_buildAndStoreFlightPath()
{
    // We don't have the full telemetry here (it was already flushed to DB).
    // Instead, we'll collect path points from the vehicle's trajectory.
    // For now, we let the FleetView query telemetry_snapshots directly
    // for map rendering. If a FlightPathRecorder is active, that path
    // can also be stored. This is a lightweight placeholder.

    // A more sophisticated approach: query the DB worker for the telemetry
    // of this flight and build a simplified path. For Phase 1, we skip this
    // since telemetry_snapshots already contain lat/lon for map rendering.
}

// ── Event helper ───────────────────────────────────────────────

void TelemetryCollector::_insertEvent(const QString &eventType, const QString &severity,
                                      const QString &details, double valueNumeric,
                                      const QString &valueText)
{
    if (_currentFlightId < 0) return;

    QVariantMap params;
    params[QStringLiteral("flightId")]     = _currentFlightId;
    params[QStringLiteral("timestampMs")]  = _flightActive ? _flightElapsed.elapsed() : 0;
    params[QStringLiteral("eventType")]    = eventType;
    params[QStringLiteral("severity")]     = severity;
    params[QStringLiteral("details")]      = details;
    params[QStringLiteral("valueNumeric")] = valueNumeric;
    params[QStringLiteral("valueText")]    = valueText;
    _db->enqueueInsertEvent(params);
}

// ── Battery/GPS accessors ──────────────────────────────────────

double TelemetryCollector::_getBatteryPct() const
{
    QmlObjectListModel *batteries = _vehicle->batteries();
    if (batteries && batteries->count() > 0) {
        auto *bg = qobject_cast<BatteryFactGroup *>(batteries->get(0));
        if (bg) {
            return bg->percentRemaining()->rawValue().toDouble();
        }
    }
    return -1;
}

double TelemetryCollector::_getBatteryVoltage() const
{
    QmlObjectListModel *batteries = _vehicle->batteries();
    if (batteries && batteries->count() > 0) {
        auto *bg = qobject_cast<BatteryFactGroup *>(batteries->get(0));
        if (bg) {
            return bg->voltage()->rawValue().toDouble();
        }
    }
    return 0;
}

double TelemetryCollector::_getBatteryCurrent() const
{
    QmlObjectListModel *batteries = _vehicle->batteries();
    if (batteries && batteries->count() > 0) {
        auto *bg = qobject_cast<BatteryFactGroup *>(batteries->get(0));
        if (bg) {
            return bg->current()->rawValue().toDouble();
        }
    }
    return 0;
}

int TelemetryCollector::_getGpsSatellites() const
{
    auto *gps = qobject_cast<VehicleGPSFactGroup *>(_vehicle->gpsFactGroup());
    if (gps) {
        return gps->count()->rawValue().toInt();
    }
    return 0;
}

double TelemetryCollector::_getGpsHdop() const
{
    auto *gps = qobject_cast<VehicleGPSFactGroup *>(_vehicle->gpsFactGroup());
    if (gps) {
        return gps->hdop()->rawValue().toDouble();
    }
    return 0;
}
