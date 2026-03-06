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
#include <QMap>
#include <QtQmlIntegration/QtQmlIntegration>

#include "QmlObjectListModel.h"

class Vehicle;
class VideoFeedItem;
class MultiVehicleManager;
class QQmlEngine;
class QJSEngine;

Q_DECLARE_LOGGING_CATEGORY(SurveillanceLog)

/// Manages surveillance mode for multi-vehicle video monitoring
/// Similar to CCTV camera wall systems
/// Uses singleton pattern consistent with QGC v5.0+ architecture
class SurveillanceManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

   public:
    // QML Singleton factory method (required for QML_SINGLETON)
    static SurveillanceManager* create(QQmlEngine* qmlEngine, QJSEngine* jsEngine);

    // C++ Singleton access
    static SurveillanceManager* instance();

    // Properties
    Q_PROPERTY(bool                 active          READ active         WRITE setActive         NOTIFY activeChanged)
    Q_PROPERTY(QmlObjectListModel*  videoFeeds      READ videoFeeds     CONSTANT)
    Q_PROPERTY(int                  gridLayout      READ gridLayout     WRITE setGridLayout     NOTIFY gridLayoutChanged)
    Q_PROPERTY(bool                 recordingAll    READ recordingAll   NOTIFY recordingAllChanged)
    Q_PROPERTY(int                  activeFeedCount READ activeFeedCount NOTIFY activeFeedCountChanged)
    Q_PROPERTY(VideoFeedItem*       focusedFeed     READ focusedFeed    WRITE setFocusedFeed    NOTIFY focusedFeedChanged)
    Q_PROPERTY(int getGridColumns READ getGridColumns NOTIFY gridLayoutChanged)
    Q_PROPERTY(int getGridRows    READ getGridRows    NOTIFY gridLayoutChanged)


    // Getters
    bool                active()            const { return _active; }
    QmlObjectListModel* videoFeeds()        const { return _videoFeeds; }
    int                 gridLayout()        const { return _gridLayout; }
    bool                recordingAll()      const { return _recordingAll; }
    int                 activeFeedCount()   const { return _videoFeeds->count(); }
    VideoFeedItem*      focusedFeed()       const { return _focusedFeed; }

    // Setters
    void setActive(bool active);
    void setGridLayout(int layout);
    void setFocusedFeed(VideoFeedItem* feed);

    // Invokable methods
    Q_INVOKABLE void startRecordingAll();
    Q_INVOKABLE void stopRecordingAll();
    Q_INVOKABLE void takeSnapshotAll();
    Q_INVOKABLE void clearFocus();
    Q_INVOKABLE int  getGridColumns() const;
    Q_INVOKABLE int  getGridRows() const;

   signals:
    void activeChanged();
    void gridLayoutChanged();
    void recordingAllChanged();
    void activeFeedCountChanged();
    void focusedFeedChanged();
    void feedAdded(VideoFeedItem* feed);
    void feedRemoved(int vehicleId);

   private slots:
    void _vehicleAdded(Vehicle* vehicle);
    void _vehicleRemoved(Vehicle* vehicle);
    void _onFeedRecordingChanged();
    void _updateRecordingAll();

   private:
    explicit SurveillanceManager(QObject* parent = nullptr);
    ~SurveillanceManager();

    // Prevent copying
    SurveillanceManager(const SurveillanceManager&) = delete;
    SurveillanceManager& operator=(const SurveillanceManager&) = delete;

    void _setupConnections();
    void _cleanup();
    VideoFeedItem* _findFeedByVehicleId(int vehicleId);

    MultiVehicleManager*            _multiVehicleManager;
    QmlObjectListModel*             _videoFeeds;
    QMap<int, VideoFeedItem*>       _feedMap;
    VideoFeedItem*                  _focusedFeed;
    bool                            _active;
    int                             _gridLayout;        // 0=2x2, 1=3x3, 2=4x4
    bool                            _recordingAll;

    static constexpr int LAYOUT_2X2 = 0;
    static constexpr int LAYOUT_3X3 = 1;
    static constexpr int LAYOUT_4X4 = 2;

    static SurveillanceManager* _instance;
};

// Forward declare the pointer as opaque for Qt's meta-type system
Q_DECLARE_OPAQUE_POINTER(VideoFeedItem*)
Q_DECLARE_METATYPE(VideoFeedItem*)
