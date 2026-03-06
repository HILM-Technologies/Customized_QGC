/****************************************************************************
 *
 * (c) 2009-2025 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "SurveillanceManager.h"
#include "VideoFeedItem.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"

#include <QQmlEngine>
#include <QJSEngine>
#include <QDebug>

Q_LOGGING_CATEGORY(SurveillanceLog, "SurveillanceLog")

SurveillanceManager* SurveillanceManager::_instance = nullptr;

SurveillanceManager* SurveillanceManager::create(QQmlEngine* qmlEngine, QJSEngine* jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)

    // Return the singleton instance
    // QML takes ownership, but we retain a static pointer
    return instance();
}

SurveillanceManager* SurveillanceManager::instance()
{
    if (!_instance) {
        _instance = new SurveillanceManager();
    }
    return _instance;
}

SurveillanceManager::SurveillanceManager(QObject* parent)
    : QObject(parent)
      , _multiVehicleManager(nullptr)
      , _videoFeeds(nullptr)
      , _focusedFeed(nullptr)
      , _active(false)
      , _gridLayout(LAYOUT_2X2)
      , _recordingAll(false)
{
    _videoFeeds = new QmlObjectListModel(this);

    // Get MultiVehicleManager singleton
    _multiVehicleManager = MultiVehicleManager::instance();
    _setupConnections();

    // Add existing vehicles
    if (_multiVehicleManager && _multiVehicleManager->vehicles()) {
        for (int i = 0; i < _multiVehicleManager->vehicles()->count(); i++) {
            Vehicle* vehicle = qobject_cast<Vehicle*>(_multiVehicleManager->vehicles()->get(i));
            if (vehicle) {
                _vehicleAdded(vehicle);
            }
        }
    }
}

SurveillanceManager::~SurveillanceManager()
{
    _cleanup();
}

void SurveillanceManager::_setupConnections()
{
    if (!_multiVehicleManager) {
        return;
    }

    connect(_multiVehicleManager, &MultiVehicleManager::vehicleAdded,
            this, &SurveillanceManager::_vehicleAdded);
    connect(_multiVehicleManager, &MultiVehicleManager::vehicleRemoved,
            this, &SurveillanceManager::_vehicleRemoved);
}

void SurveillanceManager::_cleanup()
{
    // Clear all feeds
    while (_videoFeeds->count() > 0) {
        VideoFeedItem* feed = qobject_cast<VideoFeedItem*>(_videoFeeds->get(0));
        if (feed) {
            _videoFeeds->removeOne(feed);
            _feedMap.remove(feed->vehicleId());
            feed->deleteLater();
        }
    }
    _feedMap.clear();
}

void SurveillanceManager::setActive(bool active)
{
    if (_active != active) {
        _active = active;

        if (_active) {
            qCDebug(SurveillanceLog) << "Surveillance mode ACTIVATED";
            // Optimize for multi-stream when active
            for (VideoFeedItem* feed : _feedMap.values()) {
                feed->optimizeForSurveillance(true);
            }
        } else {
            qCDebug(SurveillanceLog) << "Surveillance mode DEACTIVATED";
            // Restore normal mode
            for (VideoFeedItem* feed : _feedMap.values()) {
                feed->optimizeForSurveillance(false);
            }
            clearFocus();
        }

        emit activeChanged();
    }
}

void SurveillanceManager::setGridLayout(int layout)
{
    if (_gridLayout != layout && layout >= LAYOUT_2X2 && layout <= LAYOUT_4X4) {
        _gridLayout = layout;
        qCDebug(SurveillanceLog) << "Grid layout changed to:" << layout;
        emit gridLayoutChanged();
    }
}

void SurveillanceManager::setFocusedFeed(VideoFeedItem* feed)
{
    if (_focusedFeed != feed) {
        // Clear previous focus
        if (_focusedFeed) {
            _focusedFeed->setFocused(false);
        }

        _focusedFeed = feed;

        // Set new focus
        if (_focusedFeed) {
            _focusedFeed->setFocused(true);
        }

        emit focusedFeedChanged();
    }
}

void SurveillanceManager::clearFocus()
{
    setFocusedFeed(nullptr);
}

int SurveillanceManager::getGridColumns() const
{
    switch (_gridLayout) {
        case LAYOUT_2X2: return 2;
        case LAYOUT_3X3: return 3;
        case LAYOUT_4X4: return 4;
        default: return 2;
    }
}

int SurveillanceManager::getGridRows() const
{
    return getGridColumns(); // Square grid
}

void SurveillanceManager::startRecordingAll()
{
    qCDebug(SurveillanceLog) << "Starting recording on all feeds";
    for (VideoFeedItem* feed : _feedMap.values()) {
        if (feed->hasVideo() && !feed->recording()) {
            feed->startRecording();
        }
    }
    _updateRecordingAll();
}

void SurveillanceManager::stopRecordingAll()
{
    qCDebug(SurveillanceLog) << "Stopping recording on all feeds";
    for (VideoFeedItem* feed : _feedMap.values()) {
        if (feed->recording()) {
            feed->stopRecording();
        }
    }
    _updateRecordingAll();
}

void SurveillanceManager::takeSnapshotAll()
{
    qCDebug(SurveillanceLog) << "Taking snapshot on all feeds";
    for (VideoFeedItem* feed : _feedMap.values()) {
        if (feed->hasVideo()) {
            feed->takeSnapshot();
        }
    }
}

void SurveillanceManager::_vehicleAdded(Vehicle* vehicle)
{
    if (!vehicle) {
        return;
    }

    int vehicleId = vehicle->id();

    // Check if feed already exists
    if (_feedMap.contains(vehicleId)) {
        qCWarning(SurveillanceLog) << "Feed already exists for vehicle" << vehicleId;
        return;
    }

    qCDebug(SurveillanceLog) << "Adding video feed for vehicle" << vehicleId;

    // Create new video feed item
    VideoFeedItem* feed = new VideoFeedItem(vehicle, this);

    // Connect signals
    connect(feed, &VideoFeedItem::recordingChanged,
            this, &SurveillanceManager::_onFeedRecordingChanged);

    // Add to model and map
    _videoFeeds->append(feed);
    _feedMap.insert(vehicleId, feed);

    // If surveillance is active, optimize this feed
    if (_active) {
        feed->optimizeForSurveillance(true);
    }

    emit feedAdded(feed);
    emit activeFeedCountChanged();
}

void SurveillanceManager::_vehicleRemoved(Vehicle* vehicle)
{
    if (!vehicle) {
        return;
    }

    int vehicleId = vehicle->id();
    VideoFeedItem* feed = _findFeedByVehicleId(vehicleId);

    if (feed) {
        qCDebug(SurveillanceLog) << "Removing video feed for vehicle" << vehicleId;

        // Clear focus if this feed was focused
        if (_focusedFeed == feed) {
            clearFocus();
        }

        _videoFeeds->removeOne(feed);
        _feedMap.remove(vehicleId);

        emit feedRemoved(vehicleId);
        emit activeFeedCountChanged();

        feed->deleteLater();
    }
}

void SurveillanceManager::_onFeedRecordingChanged()
{
    _updateRecordingAll();
}

void SurveillanceManager::_updateRecordingAll()
{
    bool allRecording = false;

    if (_feedMap.count() > 0) {
        allRecording = true;
        for (VideoFeedItem* feed : _feedMap.values()) {
            if (feed->hasVideo() && !feed->recording()) {
                allRecording = false;
                break;
            }
        }
    }

    if (_recordingAll != allRecording) {
        _recordingAll = allRecording;
        emit recordingAllChanged();
    }
}

VideoFeedItem* SurveillanceManager::_findFeedByVehicleId(int vehicleId)
{
    return _feedMap.value(vehicleId, nullptr);
}
