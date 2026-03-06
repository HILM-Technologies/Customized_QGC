/****************************************************************************
 *
 * (c) 2009-2025 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/
#include "VideoFeedItem.h"
#include "Vehicle.h"
#include "VideoManager.h"
#include "QGCCameraManager.h"

// Include VideoReceiver header
#include "VideoReceiver/VideoReceiver.h"

#include <QDateTime>
#include <QDebug>

static const int STATS_UPDATE_INTERVAL_MS = 1000;

VideoFeedItem::VideoFeedItem(Vehicle* vehicle, QObject* parent)
    : QObject(parent)
      , _vehicle(vehicle)
      , _videoReceiver(nullptr)
      , _statsTimer(nullptr)
      , _vehicleId(vehicle->id())
      , _hasVideo(false)
      , _recording(false)
      , _focused(false)
      , _resolution("N/A")
      , _fps(0.0)
      , _bitrateStr("0 kbps")
      , _bitrate(0)
      , _droppedFrames(0)
      , _lastFrameCount(0)
      , _lastStatsUpdate(0)
      , _optimizedForSurveillance(false)
{
    _setupConnections();
    _updateVideoReceiver();

    // Create stats timer
    _statsTimer = new QTimer(this);
    _statsTimer->setInterval(STATS_UPDATE_INTERVAL_MS);
    connect(_statsTimer, &QTimer::timeout, this, &VideoFeedItem::_updateVideoStats);
}

VideoFeedItem::~VideoFeedItem()
{
    if (_recording) {
        stopRecording();
    }

    if (_statsTimer) {
        _statsTimer->stop();
    }
}

void VideoFeedItem::_setupConnections()
{
    if (!_vehicle) {
        return;
    }

    // Connect to vehicle signals
    connect(_vehicle, &Vehicle::armedChanged,
            this, &VideoFeedItem::_vehicleArmedChanged);
}

QString VideoFeedItem::vehicleName() const
{
    if (_vehicle) {
        // Use vehicle ID as name
        return QString("Vehicle %1").arg(_vehicleId);
    }
    return QString("Vehicle %1").arg(_vehicleId);
}

QGCCameraManager* VideoFeedItem::cameraManager() const
{
    return _vehicle ? _vehicle->cameraManager() : nullptr;
}

void VideoFeedItem::setFocused(bool focused)
{
    if (_focused != focused) {
        _focused = focused;

        qDebug() << "Feed" << _vehicleId << "focus changed to" << focused;

        emit focusedChanged();
    }
}

void VideoFeedItem::startRecording()
{
    if (_recording || !_hasVideo) {
        qDebug() << "Cannot start recording - recording:" << _recording << "hasVideo:" << _hasVideo;
        return;
    }

    qDebug() << "Starting recording for vehicle" << _vehicleId;

    // Use VideoManager to start recording (it manages the active receiver)
    VideoManager* videoMgr = VideoManager::instance();
    if (videoMgr) {
        videoMgr->startRecording(QString()); // Empty string = auto-generate filename
    }
}

void VideoFeedItem::stopRecording()
{
    if (!_recording) {
        return;
    }

    qDebug() << "Stopping recording for vehicle" << _vehicleId;

    // Use VideoManager to stop recording
    VideoManager* videoMgr = VideoManager::instance();
    if (videoMgr) {
        videoMgr->stopRecording();
    }
}

void VideoFeedItem::takeSnapshot()
{
    if (!_hasVideo) {
        qDebug() << "Cannot take snapshot - no video";
        return;
    }

    qDebug() << "Taking snapshot for vehicle" << _vehicleId;

    // Use VideoManager to grab image
    VideoManager* videoMgr = VideoManager::instance();
    if (videoMgr) {
        QString filename; // Empty = auto-generate
        videoMgr->grabImage(filename);
    }
}

void VideoFeedItem::switchCamera(int cameraId)
{
    qDebug() << "Switching to camera" << cameraId << "for vehicle" << _vehicleId;

    QGCCameraManager* camMgr = cameraManager();
    if (camMgr) {
        // Camera switching would be implemented via camera manager
        qWarning() << "Camera switching not yet implemented";
    }
}

void VideoFeedItem::optimizeForSurveillance(bool optimize)
{
    if (_optimizedForSurveillance != optimize) {
        _optimizedForSurveillance = optimize;

        qDebug() << "Surveillance optimization for vehicle" << _vehicleId << ":" << optimize;
    }
}

void VideoFeedItem::_updateVideoReceiver()
{
    // For now, we monitor the VideoManager's state
    // In a full implementation, each vehicle would have its own receiver
    // but the current QGC architecture uses a single active receiver

    VideoManager* videoMgr = VideoManager::instance();
    if (videoMgr) {
        // Connect to VideoManager signals to track video state
        connect(videoMgr, &VideoManager::streamingChanged,
                this, &VideoFeedItem::_onVideoRunningChanged, Qt::UniqueConnection);
        connect(videoMgr, &VideoManager::recordingChanged,
                this, &VideoFeedItem::recordingChanged, Qt::UniqueConnection);
        connect(videoMgr, &VideoManager::hasVideoChanged,
                this, &VideoFeedItem::_onVideoRunningChanged, Qt::UniqueConnection);
        connect(videoMgr, &VideoManager::videoSizeChanged,
                this, &VideoFeedItem::_onVideoSizeChanged, Qt::UniqueConnection);

        // Initial state update
        _onVideoRunningChanged();
    }

    emit videoReceiverChanged();
}

void VideoFeedItem::_onVideoRunningChanged()
{
    VideoManager* videoMgr = VideoManager::instance();
    if (!videoMgr) {
        return;
    }

    // Check if video is active based on VideoManager state
    bool videoRunning = videoMgr->hasVideo() && videoMgr->streaming();

    if (_hasVideo != videoRunning) {
        _hasVideo = videoRunning;

        if (_hasVideo) {
            _startStatsTimer();
            qDebug() << "Video started for vehicle" << _vehicleId;
        } else {
            _stopStatsTimer();
            qDebug() << "Video stopped for vehicle" << _vehicleId;

            // Reset stats
            _resolution = "N/A";
            _fps = 0.0;
            _bitrateStr = "0 kbps";
            _bitrate = 0;
            _droppedFrames = 0;

            emit resolutionChanged();
            emit fpsChanged();
            emit bitrateChanged();
            emit droppedFramesChanged();
        }

        emit hasVideoChanged();
    }

    // Update recording state
    bool nowRecording = videoMgr->recording();
    if (_recording != nowRecording) {
        _recording = nowRecording;
        emit recordingChanged();
    }
}

void VideoFeedItem::_onVideoSizeChanged()
{
    VideoManager* videoMgr = VideoManager::instance();
    if (!videoMgr) {
        return;
    }

    QSize size = videoMgr->videoSize();
    QString newResolution = QString("%1x%2").arg(size.width()).arg(size.height());

    if (_resolution != newResolution && size.isValid()) {
        _resolution = newResolution;
        emit resolutionChanged();
    }
}

void VideoFeedItem::_vehicleArmedChanged(bool armed)
{
    Q_UNUSED(armed)
    // Auto-start recording when armed (optional feature)
    // if (armed && !_recording && _hasVideo) {
    //     startRecording();
    // }
}

void VideoFeedItem::_startStatsTimer()
{
    if (_statsTimer && !_statsTimer->isActive()) {
        _lastStatsUpdate = QDateTime::currentMSecsSinceEpoch();
        _lastFrameCount = 0;
        _statsTimer->start();
    }
}

void VideoFeedItem::_stopStatsTimer()
{
    if (_statsTimer && _statsTimer->isActive()) {
        _statsTimer->stop();
    }
}

void VideoFeedItem::_updateVideoStats()
{
    VideoManager* videoMgr = VideoManager::instance();
    if (!videoMgr || !_hasVideo) {
        return;
    }

    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
    qint64 deltaTime = currentTime - _lastStatsUpdate;

    if (deltaTime <= 0) {
        return;
    }

    // Get resolution from VideoManager
    QSize size = videoMgr->videoSize();
    if (size.isValid()) {
        QString newResolution = QString("%1x%2").arg(size.width()).arg(size.height());
        if (_resolution != newResolution) {
            _resolution = newResolution;
            emit resolutionChanged();
        }
    }

    // FPS estimation (simplified - would need frame counting from actual receiver)
    // For now, use a reasonable default when streaming
    double newFps = videoMgr->streaming() ? 30.0 : 0.0;
    if (qAbs(_fps - newFps) > 0.5) {
        _fps = newFps;
        emit fpsChanged();
    }

    _lastStatsUpdate = currentTime;

    // Bitrate - not exposed by VideoManager, would need receiver access
    // Placeholder for now
    qint64 newBitrate = _hasVideo ? 2500000 : 0; // 2.5 Mbps estimate
    if (_bitrate != newBitrate) {
        _bitrate = newBitrate;
        _bitrateStr = _formatBitrate(newBitrate);
        emit bitrateChanged();
    }
}

QString VideoFeedItem::_formatBitrate(qint64 bps)
{
    if (bps < 1000) {
        return QString("%1 bps").arg(bps);
    } else if (bps < 1000000) {
        return QString("%1 kbps").arg(bps / 1000.0, 0, 'f', 1);
    } else {
        return QString("%1 Mbps").arg(bps / 1000000.0, 0, 'f', 2);
    }
}
