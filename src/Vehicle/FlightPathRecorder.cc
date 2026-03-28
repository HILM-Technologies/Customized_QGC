/****************************************************************************
 *
 * HILM Ground Control — Flight Path Recorder
 *
 ****************************************************************************/

#include "FlightPathRecorder.h"
#include "Vehicle.h"

#include <QDateTime>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtMath>

#include <QGCLoggingCategory.h>
QGC_LOGGING_CATEGORY(FlightPathRecorderLog, "FlightPathRecorder")

// ──────────────────────────────────────────────────────────────
// Construction
// ──────────────────────────────────────────────────────────────

FlightPathRecorder::FlightPathRecorder(Vehicle* vehicle, QObject* parent)
    : QObject(parent)
    , _vehicle(vehicle)
{
    _sampleTimer.setTimerType(Qt::PreciseTimer);
    connect(&_sampleTimer, &QTimer::timeout, this, &FlightPathRecorder::_recordSample);

    _elapsedTicker.setInterval(1000);
    connect(&_elapsedTicker, &QTimer::timeout, this, &FlightPathRecorder::_tickElapsed);
}

// ──────────────────────────────────────────────────────────────
// Properties
// ──────────────────────────────────────────────────────────────

int FlightPathRecorder::elapsedSeconds() const
{
    return _recording ? static_cast<int>(_elapsed.elapsed() / 1000) : 0;
}

void FlightPathRecorder::setIntervalMs(int ms)
{
    ms = qBound(500, ms, 10000);
    if (ms != _intervalMs) {
        _intervalMs = ms;
        if (_recording)
            _sampleTimer.setInterval(_intervalMs);
        emit intervalMsChanged();
    }
}

// ──────────────────────────────────────────────────────────────
// Recording control
// ──────────────────────────────────────────────────────────────

void FlightPathRecorder::startRecording()
{
    if (_recording)
        return;

    _waypoints.clear();
    _totalDistanceM = 0;
    _homePosition = _vehicle->homePosition();

    _recording = true;
    _elapsed.start();
    _sampleTimer.start(_intervalMs);
    _elapsedTicker.start();

    // Capture first sample immediately
    _recordSample();

    qCDebug(FlightPathRecorderLog) << "Recording started for vehicle" << _vehicle->id();
    emit recordingChanged();
    emit waypointCountChanged();
}

void FlightPathRecorder::stopRecording()
{
    if (!_recording)
        return;

    _sampleTimer.stop();
    _elapsedTicker.stop();
    _recording = false;

    qCDebug(FlightPathRecorderLog) << "Recording stopped. Waypoints:" << _waypoints.size()
                                   << "Distance:" << _totalDistanceM << "m";
    emit recordingChanged();
    emit recordingStopped();
}

void FlightPathRecorder::clearRecording()
{
    _waypoints.clear();
    _totalDistanceM = 0;
    emit waypointCountChanged();
}

// ──────────────────────────────────────────────────────────────
// Sampling
// ──────────────────────────────────────────────────────────────

void FlightPathRecorder::_recordSample()
{
    if (!_vehicle)
        return;

    const QGeoCoordinate coord = _vehicle->coordinate();
    if (!coord.isValid())
        return;

    // Skip if too close to last recorded point (vehicle hovering)
    if (!_waypoints.isEmpty()) {
        const double dist = _waypoints.last().coordinate.distanceTo(coord);
        if (dist < kMinSampleDistM)
            return;
        _totalDistanceM += dist;
    }

    if (_waypoints.size() >= kMaxRawWaypoints) {
        qCWarning(FlightPathRecorderLog) << "Max raw waypoints reached, stopping.";
        stopRecording();
        return;
    }

    RecordedWaypoint wp;
    wp.coordinate       = coord;
    wp.altitudeRelative = _vehicle->altitudeRelative()->rawValue().toDouble();
    wp.heading          = _vehicle->heading()->rawValue().toDouble();
    wp.groundSpeed      = _vehicle->groundSpeed()->rawValue().toDouble();
    wp.timestampMs      = _elapsed.elapsed();

    _waypoints.append(wp);
    emit waypointCountChanged();
}

void FlightPathRecorder::_tickElapsed()
{
    emit elapsedSecondsChanged();
}

// ──────────────────────────────────────────────────────────────
// Douglas-Peucker path simplification
// ──────────────────────────────────────────────────────────────

double FlightPathRecorder::_perpendicularDistanceM(const QGeoCoordinate& point,
                                                    const QGeoCoordinate& lineStart,
                                                    const QGeoCoordinate& lineEnd)
{
    // Use cross-track distance approximation
    const double dTotal = lineStart.distanceTo(lineEnd);
    if (dTotal < 0.01)
        return lineStart.distanceTo(point);

    const double dStartToPoint = lineStart.distanceTo(point);
    const double dEndToPoint   = lineEnd.distanceTo(point);
    const double dStartToEnd   = dTotal;

    // Heron's formula for triangle area, then h = 2*area / base
    const double s = (dStartToPoint + dEndToPoint + dStartToEnd) / 2.0;
    const double areaSquared = s * (s - dStartToPoint) * (s - dEndToPoint) * (s - dStartToEnd);
    if (areaSquared <= 0)
        return 0;

    return 2.0 * qSqrt(areaSquared) / dStartToEnd;
}

QVector<RecordedWaypoint> FlightPathRecorder::_douglasPeucker(
    const QVector<RecordedWaypoint>& pts, int start, int end, double toleranceM)
{
    if (end - start < 2)
        return pts.mid(start, end - start + 1);

    double maxDist = 0;
    int    maxIdx  = start;
    const auto& first = pts[start].coordinate;
    const auto& last  = pts[end].coordinate;

    for (int i = start + 1; i < end; ++i) {
        const double d = _perpendicularDistanceM(pts[i].coordinate, first, last);
        if (d > maxDist) {
            maxDist = d;
            maxIdx  = i;
        }
    }

    if (maxDist > toleranceM) {
        auto left  = _douglasPeucker(pts, start, maxIdx, toleranceM);
        auto right = _douglasPeucker(pts, maxIdx, end, toleranceM);
        // Remove duplicate midpoint
        left.removeLast();
        left.append(right);
        return left;
    }

    // All points within tolerance — keep only endpoints
    return { pts[start], pts[end] };
}

QVector<RecordedWaypoint> FlightPathRecorder::simplifiedPath(double toleranceM) const
{
    if (_waypoints.size() <= 2)
        return _waypoints;

    return _douglasPeucker(_waypoints, 0, _waypoints.size() - 1, toleranceM);
}

// ──────────────────────────────────────────────────────────────
// Mission JSON generation
// ──────────────────────────────────────────────────────────────

QJsonObject FlightPathRecorder::_buildMissionJson(const QVector<RecordedWaypoint>& wps) const
{
    QJsonArray items;
    int seq = 0;

    // Item 0: Planned home position (required by QGC .plan format)
    {
        QJsonObject home;
        home["autoContinue"] = true;
        home["command"]      = 0;  // placeholder for home
        home["doJumpId"]     = seq + 1;
        home["frame"]        = 0;
        home["type"]         = "SimpleItem";

        QJsonArray coord;
        coord.append(_homePosition.latitude());
        coord.append(_homePosition.longitude());
        coord.append(_homePosition.altitude());
        home["coordinate"] = coord;

        QJsonArray params;
        for (int i = 0; i < 7; ++i) params.append(0);
        home["params"] = params;

        items.append(home);
        seq++;
    }

    // Item 1: NAV_TAKEOFF at first waypoint altitude
    if (!wps.isEmpty()) {
        QJsonObject takeoff;
        takeoff["autoContinue"] = true;
        takeoff["command"]      = 22;  // MAV_CMD_NAV_TAKEOFF
        takeoff["doJumpId"]     = seq + 1;
        takeoff["frame"]        = 3;   // GLOBAL_RELATIVE_ALT
        takeoff["type"]         = "SimpleItem";

        QJsonArray coord;
        coord.append(wps.first().coordinate.latitude());
        coord.append(wps.first().coordinate.longitude());
        coord.append(wps.first().altitudeRelative);
        takeoff["coordinate"] = coord;

        QJsonArray params;
        params.append(0);    // min pitch
        params.append(0);    // empty
        params.append(0);    // empty
        params.append(QJsonValue(QJsonValue::Null)); // yaw = NaN → heading toward next WP
        params.append(wps.first().coordinate.latitude());
        params.append(wps.first().coordinate.longitude());
        params.append(wps.first().altitudeRelative);
        takeoff["params"] = params;

        items.append(takeoff);
        seq++;
    }

    double lastSpeed = -1;

    // Waypoints
    for (int i = 0; i < wps.size(); ++i) {
        const auto& wp = wps[i];

        // Insert DO_CHANGE_SPEED if speed changed significantly (>1 m/s)
        if (lastSpeed >= 0 && qAbs(wp.groundSpeed - lastSpeed) > 1.0) {
            QJsonObject speedCmd;
            speedCmd["autoContinue"] = true;
            speedCmd["command"]      = 178;  // MAV_CMD_DO_CHANGE_SPEED
            speedCmd["doJumpId"]     = seq + 1;
            speedCmd["frame"]        = 0;
            speedCmd["type"]         = "SimpleItem";

            QJsonArray coord;
            coord.append(0); coord.append(0); coord.append(0);
            speedCmd["coordinate"] = coord;

            QJsonArray params;
            params.append(1);                // speed type: ground speed
            params.append(wp.groundSpeed);   // speed m/s
            params.append(-1);               // throttle: no change
            params.append(0);                // empty
            params.append(0); params.append(0); params.append(0);
            speedCmd["params"] = params;

            items.append(speedCmd);
            seq++;
        }
        lastSpeed = wp.groundSpeed;

        // NAV_WAYPOINT
        QJsonObject wpJson;
        wpJson["autoContinue"] = true;
        wpJson["command"]      = 16;  // MAV_CMD_NAV_WAYPOINT
        wpJson["doJumpId"]     = seq + 1;
        wpJson["frame"]        = 3;   // GLOBAL_RELATIVE_ALT
        wpJson["type"]         = "SimpleItem";

        QJsonArray coord;
        coord.append(wp.coordinate.latitude());
        coord.append(wp.coordinate.longitude());
        coord.append(wp.altitudeRelative);
        wpJson["coordinate"] = coord;

        QJsonArray params;
        params.append(0);           // hold time
        params.append(2);           // acceptance radius (2m)
        params.append(0);           // pass-by radius (0 = through WP)
        params.append(QJsonValue(QJsonValue::Null));  // yaw: NaN = face next WP
        params.append(wp.coordinate.latitude());
        params.append(wp.coordinate.longitude());
        params.append(wp.altitudeRelative);
        wpJson["params"] = params;

        items.append(wpJson);
        seq++;
    }

    // RTL at the end
    {
        QJsonObject rtl;
        rtl["autoContinue"] = true;
        rtl["command"]      = 20;  // MAV_CMD_NAV_RETURN_TO_LAUNCH
        rtl["doJumpId"]     = seq + 1;
        rtl["frame"]        = 0;
        rtl["type"]         = "SimpleItem";

        QJsonArray coord;
        coord.append(0); coord.append(0); coord.append(0);
        rtl["coordinate"] = coord;

        QJsonArray params;
        for (int i = 0; i < 7; ++i) params.append(0);
        rtl["params"] = params;

        items.append(rtl);
    }

    QJsonObject mission;
    mission["cruiseSpeed"]  = 15;
    mission["hoverSpeed"]   = 5;
    mission["firmwareType"] = 12;  // PX4
    mission["vehicleType"]  = 2;   // multi-rotor
    mission["version"]      = 2;
    mission["items"]        = items;

    QJsonArray homeCoord;
    homeCoord.append(_homePosition.latitude());
    homeCoord.append(_homePosition.longitude());
    homeCoord.append(_homePosition.altitude());
    mission["plannedHomePosition"] = homeCoord;

    return mission;
}

QJsonDocument FlightPathRecorder::toJsonDocument() const
{
    auto simplified = simplifiedPath(2.0);

    QJsonObject plan;
    plan["fileType"]      = "Plan";
    plan["version"]       = 1;
    plan["groundStation"] = "HILMGroundControl";

    plan["mission"]     = _buildMissionJson(simplified);
    plan["geoFence"]    = QJsonObject{ {"polygon", QJsonArray()}, {"version", 2} };
    plan["rallyPoints"] = QJsonObject{ {"points",  QJsonArray()}, {"version", 2} };

    // Extra metadata (ignored by upstream QGC loader)
    QJsonObject meta;
    meta["recordingDate"]           = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    meta["vehicleId"]               = _vehicle ? _vehicle->id() : -1;
    meta["totalDurationSec"]        = _waypoints.isEmpty() ? 0 : static_cast<int>(_waypoints.last().timestampMs / 1000);
    meta["originalWaypointCount"]   = _waypoints.size();
    meta["simplifiedWaypointCount"] = simplified.size();
    meta["totalDistanceM"]          = _totalDistanceM;
    plan["hilmRecordedPath"] = meta;

    return QJsonDocument(plan);
}

bool FlightPathRecorder::saveToFile(const QString& filePath) const
{
    if (_waypoints.isEmpty()) {
        qCWarning(FlightPathRecorderLog) << "Nothing to save — no waypoints recorded.";
        return false;
    }

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(FlightPathRecorderLog) << "Cannot open file for writing:" << filePath;
        return false;
    }

    file.write(toJsonDocument().toJson());
    file.close();

    qCDebug(FlightPathRecorderLog) << "Saved recorded path to" << filePath;
    return true;
}
