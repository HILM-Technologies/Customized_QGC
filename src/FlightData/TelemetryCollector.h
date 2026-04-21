/****************************************************************************
 *
 * HILM Ground Control — Telemetry Collector
 * Per-vehicle data capture. Connects to Vehicle signals, runs periodic
 * sampling timer while armed, detects events (arm/disarm, takeoff, landing,
 * mode changes, battery thresholds).
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QElapsedTimer>
#include <QtCore/QVariantList>

class Vehicle;
class FlightDatabase;

class TelemetryCollector : public QObject
{
    Q_OBJECT

public:
    explicit TelemetryCollector(Vehicle *vehicle, FlightDatabase *db, QObject *parent = nullptr);
    ~TelemetryCollector() override;

    QString vehicleUid() const { return _vehicleUid; }
    void setCurrentFlightId(int flightId);

private slots:
    void _onArmedChanged(bool armed);
    void _onFlyingChanged(bool flying);
    void _onFlightModeChanged(const QString &flightMode);
    void _onSampleTimer();

private:
    void _startFlight();
    void _endFlight();
    void _captureSnapshot();
    void _flushBatch();
    void _buildAndStoreFlightPath();
    void _insertEvent(const QString &eventType, const QString &severity,
                      const QString &details = QString(),
                      double valueNumeric = 0, const QString &valueText = QString());
    double _getBatteryPct() const;
    double _getBatteryVoltage() const;
    double _getBatteryCurrent() const;
    int    _getGpsSatellites() const;
    double _getGpsHdop() const;

    Vehicle         *_vehicle = nullptr;
    FlightDatabase  *_db = nullptr;
    QTimer           _sampleTimer;
    QElapsedTimer    _flightElapsed;

    QString _vehicleUid;
    int     _currentFlightId  = -1;
    bool    _flightActive     = false;

    // Telemetry batch buffer
    QVariantList _snapshotBatch;
    static constexpr int kBatchSize = 10;
    static constexpr int kSampleIntervalMs = 3000;

    // In-flight max tracking
    double _maxAltitudeRelM       = 0;
    double _maxGroundSpeedMps     = 0;
    double _maxDistanceFromHomeM  = 0;
    double _gpsSatellitesSum      = 0;
    int    _gpsSatellitesSamples  = 0;

    // Threshold event tracking (avoid duplicate events)
    bool   _lowBatteryFired  = false;
    bool   _gpsLowFired      = false;
};
