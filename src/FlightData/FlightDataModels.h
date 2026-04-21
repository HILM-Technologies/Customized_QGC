/****************************************************************************
 *
 * HILM Ground Control — Flight Data Models
 * Q_GADGET structs for flight records, vehicle records, telemetry snapshots,
 * and flight events. Used for data transfer between DB worker and QML.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QDateTime>
#include <QtCore/QString>
#include <QtCore/QVariant>
#include <QtCore/QMetaType>

// ── Vehicle Record ─────────────────────────────────────────────
struct VehicleRecord
{
    Q_GADGET
    Q_PROPERTY(QString vehicleUid   MEMBER vehicleUid)
    Q_PROPERTY(int     vehicleId    MEMBER vehicleId)
    Q_PROPERTY(int     vehicleType  MEMBER vehicleType)
    Q_PROPERTY(int     firmwareType MEMBER firmwareType)
    Q_PROPERTY(QString firmwareVersion MEMBER firmwareVersion)
    Q_PROPERTY(QString vehicleName  MEMBER vehicleName)
    Q_PROPERTY(int     motorCount   MEMBER motorCount)
    Q_PROPERTY(QString firstSeenAt  MEMBER firstSeenAt)
    Q_PROPERTY(QString lastSeenAt   MEMBER lastSeenAt)
    Q_PROPERTY(int     totalFlights MEMBER totalFlights)
    Q_PROPERTY(double  totalFlightTimeSec  MEMBER totalFlightTimeSec)
    Q_PROPERTY(double  totalDistanceM      MEMBER totalDistanceM)
    Q_PROPERTY(QString notes        MEMBER notes)

public:
    QString vehicleUid;
    int     vehicleId       = 0;
    int     vehicleType     = 0;
    int     firmwareType    = 0;
    QString firmwareVersion;
    QString vehicleName;
    int     motorCount      = 0;
    QString firstSeenAt;
    QString lastSeenAt;
    int     totalFlights    = 0;
    double  totalFlightTimeSec = 0;
    double  totalDistanceM  = 0;
    QString notes;
};
Q_DECLARE_METATYPE(VehicleRecord)


// ── Flight Record ──────────────────────────────────────────────
struct FlightRecord
{
    Q_GADGET
    Q_PROPERTY(int     flightId     MEMBER flightId)
    Q_PROPERTY(QString vehicleUid   MEMBER vehicleUid)
    Q_PROPERTY(int     vehicleId    MEMBER vehicleId)
    Q_PROPERTY(QString armedAt      MEMBER armedAt)
    Q_PROPERTY(QString disarmedAt   MEMBER disarmedAt)
    Q_PROPERTY(QString takeoffAt    MEMBER takeoffAt)
    Q_PROPERTY(QString landingAt    MEMBER landingAt)
    Q_PROPERTY(double  durationSec  MEMBER durationSec)
    Q_PROPERTY(double  flightDistanceM       MEMBER flightDistanceM)
    Q_PROPERTY(double  maxAltitudeRelM       MEMBER maxAltitudeRelM)
    Q_PROPERTY(double  maxGroundSpeedMps     MEMBER maxGroundSpeedMps)
    Q_PROPERTY(double  maxDistanceFromHomeM  MEMBER maxDistanceFromHomeM)
    Q_PROPERTY(double  homeLat      MEMBER homeLat)
    Q_PROPERTY(double  homeLon      MEMBER homeLon)
    Q_PROPERTY(double  homeAltAmsl  MEMBER homeAltAmsl)
    Q_PROPERTY(QString flightModeAtStart MEMBER flightModeAtStart)
    Q_PROPERTY(QString flightModeAtEnd   MEMBER flightModeAtEnd)
    Q_PROPERTY(double  batteryStartPct   MEMBER batteryStartPct)
    Q_PROPERTY(double  batteryEndPct     MEMBER batteryEndPct)
    Q_PROPERTY(double  gpsSatellitesAvg  MEMBER gpsSatellitesAvg)
    Q_PROPERTY(double  mavlinkLossPct    MEMBER mavlinkLossPct)
    Q_PROPERTY(QString status       MEMBER status)
    Q_PROPERTY(QString vehicleName  MEMBER vehicleName)
    Q_PROPERTY(QString notes        MEMBER notes)

public:
    int     flightId        = 0;
    QString vehicleUid;
    int     vehicleId       = 0;
    QString armedAt;
    QString disarmedAt;
    QString takeoffAt;
    QString landingAt;
    double  durationSec     = 0;
    double  flightDistanceM = 0;
    double  maxAltitudeRelM = 0;
    double  maxGroundSpeedMps   = 0;
    double  maxDistanceFromHomeM = 0;
    double  homeLat         = 0;
    double  homeLon         = 0;
    double  homeAltAmsl     = 0;
    QString flightModeAtStart;
    QString flightModeAtEnd;
    double  batteryStartPct = -1;
    double  batteryEndPct   = -1;
    double  gpsSatellitesAvg = 0;
    double  mavlinkLossPct  = 0;
    QString status          = QStringLiteral("IN_PROGRESS");
    QString vehicleName;
    QString notes;
};
Q_DECLARE_METATYPE(FlightRecord)


// ── Telemetry Snapshot ─────────────────────────────────────────
struct TelemetrySnapshot
{
    Q_GADGET
    Q_PROPERTY(int     snapshotId       MEMBER snapshotId)
    Q_PROPERTY(int     flightId         MEMBER flightId)
    Q_PROPERTY(qint64  timestampMs      MEMBER timestampMs)
    Q_PROPERTY(double  lat              MEMBER lat)
    Q_PROPERTY(double  lon              MEMBER lon)
    Q_PROPERTY(double  altRelM          MEMBER altRelM)
    Q_PROPERTY(double  altAmslM         MEMBER altAmslM)
    Q_PROPERTY(double  headingDeg       MEMBER headingDeg)
    Q_PROPERTY(double  groundSpeedMps   MEMBER groundSpeedMps)
    Q_PROPERTY(double  airSpeedMps      MEMBER airSpeedMps)
    Q_PROPERTY(double  climbRateMps     MEMBER climbRateMps)
    Q_PROPERTY(double  distanceToHomeM  MEMBER distanceToHomeM)
    Q_PROPERTY(double  batteryPct       MEMBER batteryPct)
    Q_PROPERTY(double  batteryVoltage   MEMBER batteryVoltage)
    Q_PROPERTY(double  batteryCurrent   MEMBER batteryCurrent)
    Q_PROPERTY(int     gpsSatellites    MEMBER gpsSatellites)
    Q_PROPERTY(double  gpsHdop          MEMBER gpsHdop)
    Q_PROPERTY(QString flightMode       MEMBER flightMode)
    Q_PROPERTY(int     throttlePct      MEMBER throttlePct)

public:
    int     snapshotId      = 0;
    int     flightId        = 0;
    qint64  timestampMs     = 0;
    double  lat             = 0;
    double  lon             = 0;
    double  altRelM         = 0;
    double  altAmslM        = 0;
    double  headingDeg      = 0;
    double  groundSpeedMps  = 0;
    double  airSpeedMps     = 0;
    double  climbRateMps    = 0;
    double  distanceToHomeM = 0;
    double  batteryPct      = -1;
    double  batteryVoltage  = 0;
    double  batteryCurrent  = 0;
    int     gpsSatellites   = 0;
    double  gpsHdop         = 0;
    QString flightMode;
    int     throttlePct     = 0;
};
Q_DECLARE_METATYPE(TelemetrySnapshot)


// ── Flight Event ───────────────────────────────────────────────
struct FlightEvent
{
    Q_GADGET
    Q_PROPERTY(int     eventId      MEMBER eventId)
    Q_PROPERTY(int     flightId     MEMBER flightId)
    Q_PROPERTY(qint64  timestampMs  MEMBER timestampMs)
    Q_PROPERTY(QString eventType    MEMBER eventType)
    Q_PROPERTY(QString severity     MEMBER severity)
    Q_PROPERTY(QString details      MEMBER details)
    Q_PROPERTY(double  valueNumeric MEMBER valueNumeric)
    Q_PROPERTY(QString valueText    MEMBER valueText)

public:
    int     eventId         = 0;
    int     flightId        = 0;
    qint64  timestampMs     = 0;
    QString eventType;
    QString severity        = QStringLiteral("INFO");
    QString details;
    double  valueNumeric    = 0;
    QString valueText;
};
Q_DECLARE_METATYPE(FlightEvent)


// ── Fleet Summary (computed, not stored) ───────────────────────
struct FleetSummary
{
    Q_GADGET
    Q_PROPERTY(int    totalFlights      MEMBER totalFlights)
    Q_PROPERTY(int    totalVehicles     MEMBER totalVehicles)
    Q_PROPERTY(double totalFlightHours  MEMBER totalFlightHours)
    Q_PROPERTY(double totalDistanceKm   MEMBER totalDistanceKm)
    Q_PROPERTY(double avgBatteryEndPct  MEMBER avgBatteryEndPct)
    Q_PROPERTY(double successRate       MEMBER successRate)

public:
    int    totalFlights     = 0;
    int    totalVehicles    = 0;
    double totalFlightHours = 0;
    double totalDistanceKm  = 0;
    double avgBatteryEndPct = 0;
    double successRate      = 0;
};
Q_DECLARE_METATYPE(FleetSummary)
