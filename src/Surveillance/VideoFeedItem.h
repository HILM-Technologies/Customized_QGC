/****************************************************************************
 *
 * (c) 2009-2025 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QObject>
#include <QTimer>
#include <QString>
#include <QtQmlIntegration/QtQmlIntegration>

// Forward declarations
class Vehicle;
class VideoReceiver;
class QGCCameraManager;

/// Represents a single video feed from a vehicle in surveillance mode
class VideoFeedItem : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("VideoFeedItem is created by SurveillanceManager")

   public:
    explicit VideoFeedItem(Vehicle* vehicle, QObject* parent = nullptr);
    ~VideoFeedItem();

    // Properties
    Q_PROPERTY(int              vehicleId       READ vehicleId      CONSTANT)
    Q_PROPERTY(QString          vehicleName     READ vehicleName    NOTIFY vehicleNameChanged)
    Q_PROPERTY(bool             hasVideo        READ hasVideo       NOTIFY hasVideoChanged)
    Q_PROPERTY(bool             recording       READ recording      NOTIFY recordingChanged)
    Q_PROPERTY(bool             focused         READ focused        WRITE setFocused    NOTIFY focusedChanged)
    Q_PROPERTY(VideoReceiver*   videoReceiver   READ videoReceiver  NOTIFY videoReceiverChanged)
    Q_PROPERTY(QGCCameraManager* cameraManager  READ cameraManager  CONSTANT)

    // Video stats
    Q_PROPERTY(QString          resolution      READ resolution     NOTIFY resolutionChanged)
    Q_PROPERTY(double           fps             READ fps            NOTIFY fpsChanged)
    Q_PROPERTY(QString          bitrate         READ bitrate        NOTIFY bitrateChanged)
    Q_PROPERTY(int              droppedFrames   READ droppedFrames  NOTIFY droppedFramesChanged)

    // Getters
    int                 vehicleId()     const { return _vehicleId; }
    QString             vehicleName()   const;
    bool                hasVideo()      const { return _hasVideo; }
    bool                recording()     const { return _recording; }
    bool                focused()       const { return _focused; }
    VideoReceiver*      videoReceiver() const { return _videoReceiver; }
    QGCCameraManager*   cameraManager() const;

    QString             resolution()    const { return _resolution; }
    double              fps()           const { return _fps; }
    QString             bitrate()       const { return _bitrateStr; }
    int                 droppedFrames() const { return _droppedFrames; }

    // Setters
    void setFocused(bool focused);

    // Invokable methods
    Q_INVOKABLE void startRecording();
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE void takeSnapshot();
    Q_INVOKABLE void switchCamera(int cameraId);

    // Internal methods
    void optimizeForSurveillance(bool optimize);

   signals:
    void vehicleNameChanged();
    void hasVideoChanged();
    void recordingChanged();
    void focusedChanged();
    void videoReceiverChanged();
    void resolutionChanged();
    void fpsChanged();
    void bitrateChanged();
    void droppedFramesChanged();

   private slots:
    void _updateVideoReceiver();
    void _updateVideoStats();
    void _onVideoRunningChanged();
    void _onVideoSizeChanged();
    void _vehicleArmedChanged(bool armed);

   private:
    void _setupConnections();
    void _startStatsTimer();
    void _stopStatsTimer();
    QString _formatBitrate(qint64 bps);

    Vehicle*            _vehicle;
    VideoReceiver*      _videoReceiver;
    QTimer*             _statsTimer;

    int                 _vehicleId;
    bool                _hasVideo;
    bool                _recording;
    bool                _focused;

    // Video statistics
    QString             _resolution;
    double              _fps;
    QString             _bitrateStr;
    qint64              _bitrate;
    int                 _droppedFrames;

    // Frame counting for FPS calculation
    qint64              _lastFrameCount;
    qint64              _lastStatsUpdate;

    // Optimization flags
    bool                _optimizedForSurveillance;
};

// Declare opaque pointer for Qt meta-type system
Q_DECLARE_OPAQUE_POINTER(VideoReceiver*)
Q_DECLARE_METATYPE(VideoReceiver*)

Q_DECLARE_OPAQUE_POINTER(QGCCameraManager*)
Q_DECLARE_METATYPE(QGCCameraManager*)
