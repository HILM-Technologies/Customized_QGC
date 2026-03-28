/****************************************************************************
 *
 * HILM Ground Control — Flight Path Recorder
 *
 * Records the vehicle's flight path during manual control and converts it
 * to a standard QGC .plan mission file for replay.
 *
 ****************************************************************************/

#pragma once

#include <QGeoCoordinate>
#include <QJsonDocument>
#include <QObject>
#include <QTimer>
#include <QVector>
#include <QElapsedTimer>

class Vehicle;

struct RecordedWaypoint {
    QGeoCoordinate coordinate;      // lat, lon, AMSL alt
    double         altitudeRelative; // alt relative to home
    double         heading;          // degrees 0–360
    double         groundSpeed;      // m/s
    qint64         timestampMs;      // ms since recording started
};

class FlightPathRecorder : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool    recording          READ recording          NOTIFY recordingChanged)
    Q_PROPERTY(int     waypointCount      READ waypointCount      NOTIFY waypointCountChanged)
    Q_PROPERTY(int     elapsedSeconds     READ elapsedSeconds     NOTIFY elapsedSecondsChanged)
    Q_PROPERTY(int     intervalMs         READ intervalMs         WRITE setIntervalMs   NOTIFY intervalMsChanged)
    Q_PROPERTY(double  totalDistanceM     READ totalDistanceM     NOTIFY waypointCountChanged)

public:
    explicit FlightPathRecorder(Vehicle* vehicle, QObject* parent = nullptr);
    ~FlightPathRecorder() override = default;

    bool   recording()       const { return _recording; }
    int    waypointCount()   const { return _waypoints.size(); }
    int    elapsedSeconds()  const;
    int    intervalMs()      const { return _intervalMs; }
    double totalDistanceM()  const { return _totalDistanceM; }

    void setIntervalMs(int ms);

    Q_INVOKABLE void startRecording();
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE void clearRecording();

    /// Save the recorded path as a standard .plan file.
    /// @param filePath  Absolute path (e.g. "C:/missions/recorded.plan")
    /// @return true on success
    Q_INVOKABLE bool saveToFile(const QString& filePath) const;

    /// Build the .plan JSON without writing to disk (for "Open in Plan View").
    Q_INVOKABLE QJsonDocument toJsonDocument() const;

    /// Return a simplified copy of the waypoints (Douglas-Peucker).
    QVector<RecordedWaypoint> simplifiedPath(double toleranceM = 2.0) const;

signals:
    void recordingChanged();
    void waypointCountChanged();
    void elapsedSecondsChanged();
    void intervalMsChanged();
    void recordingStopped();          // emitted with path ready

private slots:
    void _recordSample();
    void _tickElapsed();

private:
    QJsonObject _buildMissionJson(const QVector<RecordedWaypoint>& wps) const;
    static QVector<RecordedWaypoint> _douglasPeucker(const QVector<RecordedWaypoint>& pts,
                                                     int start, int end, double toleranceM);
    static double _perpendicularDistanceM(const QGeoCoordinate& point,
                                          const QGeoCoordinate& lineStart,
                                          const QGeoCoordinate& lineEnd);

    Vehicle*                   _vehicle   = nullptr;
    bool                       _recording = false;
    int                        _intervalMs = 1500;   // default 1.5 s
    double                     _totalDistanceM = 0;
    QTimer                     _sampleTimer;
    QTimer                     _elapsedTicker;       // fires every 1 s for UI
    QElapsedTimer              _elapsed;
    QGeoCoordinate             _homePosition;
    QVector<RecordedWaypoint>  _waypoints;

    static constexpr double    kMinSampleDistM  = 0.5;   // skip if closer
    static constexpr int       kMaxRawWaypoints = 3000;
};
