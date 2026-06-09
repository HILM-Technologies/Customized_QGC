/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
import QtQuick.Dialogs
import Qt.labs.animation

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

Map {
    id: _map

    plugin:     Plugin { name: "QGroundControl" }
    opacity:    0.99 // https://bugreports.qt.io/browse/QTBUG-82185

    property string mapName:                        'defaultMap'
    property bool   isSatelliteMap:                 activeMapType.name.indexOf("Satellite") > -1 || activeMapType.name.indexOf("Hybrid") > -1
    property var    gcsPosition:                    QGroundControl.qgcPositionManger.gcsPosition
    property real   gcsHeading:                     QGroundControl.qgcPositionManger.gcsHeading
    property bool   allowGCSLocationCenter:         false   ///< true: map will center/zoom to gcs location one time
    property bool   allowVehicleLocationCenter:     false   ///< true: map will center/zoom to vehicle location one time
    property bool   firstGCSPositionReceived:       false   ///< true: first gcs position update was responded to
    property bool   firstVehiclePositionReceived:   false   ///< true: first vehicle position update was responded to
    property bool   planView:                       false   ///< true: map being using for Plan view, items should be draggable
    property bool   showZoomControls:               false   ///< show +/- zoom buttons
    property real   zoomControlsRightInset:         ScreenTools.defaultFontPixelWidth * 2   ///< zoom buttons right margin

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle
    property var    _activeVehicleCoordinate:   _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()

    function setVisibleRegion(region) {
        // TODO: Is this still necessary with Qt 5.11?
        // This works around a bug on Qt where if you set a visibleRegion and then the user moves or zooms the map
        // and then you set the same visibleRegion the map will not move/scale appropriately since it thinks there
        // is nothing to do.
        let maxZoomLevel = 20
        _map.visibleRegion = QtPositioning.rectangle(QtPositioning.coordinate(0, 0), QtPositioning.coordinate(0, 0))
        _map.visibleRegion = region
        if (_map.zoomLevel > maxZoomLevel) {
            _map.zoomLevel = maxZoomLevel
        }
    }

    function _possiblyCenterToVehiclePosition() {
        if (!firstVehiclePositionReceived && allowVehicleLocationCenter && _activeVehicleCoordinate.isValid) {
            firstVehiclePositionReceived = true
            center = _activeVehicleCoordinate
            zoomLevel = QGroundControl.flightMapInitialZoom
        }
    }

    function centerToSpecifiedLocation() {
        specifyMapPositionDialog.createObject(mainWindow).open()
    }

    Component {
        id: specifyMapPositionDialog
        EditPositionDialog {
            title:                  qsTr("Specify Position")
            coordinate:             center
            onCoordinateChanged:    center = coordinate
        }
    }

    // Center map to gcs location
    onGcsPositionChanged: {
        if (gcsPosition.isValid && allowGCSLocationCenter && !firstGCSPositionReceived && !firstVehiclePositionReceived) {
            firstGCSPositionReceived = true
            //-- Only center on gsc if we have no vehicle (and we are supposed to do so)
            var _activeVehicleCoordinate = _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()
            if(QGroundControl.settingsManager.flyViewSettings.keepMapCenteredOnVehicle.rawValue || !_activeVehicleCoordinate.isValid)
                center = gcsPosition
        }
    }

    function updateActiveMapType() {
        var settings =  QGroundControl.settingsManager.flightMapSettings
        var fullMapName = settings.mapProvider.value + " " + settings.mapType.value

        for (var i = 0; i < _map.supportedMapTypes.length; i++) {
            if (fullMapName === _map.supportedMapTypes[i].name) {
                _map.activeMapType = _map.supportedMapTypes[i]
                return
            }
        }
    }

    on_ActiveVehicleCoordinateChanged: _possiblyCenterToVehiclePosition()

    onMapReadyChanged: {
        if (_map.mapReady) {
            updateActiveMapType()
            _possiblyCenterToVehiclePosition()
        }
    }

    Connections {
        target: QGroundControl.settingsManager.flightMapSettings.mapType
        function onRawValueChanged() { updateActiveMapType() }
    }

    Connections {
        target: QGroundControl.settingsManager.flightMapSettings.mapProvider
        function onRawValueChanged() { updateActiveMapType() }
    }

    signal mapPanStart
    signal mapPanStop
    signal mapClicked(var position)

    PinchHandler {
        id:     pinchHandler
        target: null

        property var pinchStartCentroid

        onActiveChanged: {
            if (active) {
                pinchStartCentroid = _map.toCoordinate(pinchHandler.centroid.position, false)
            }
        }
        onScaleChanged: (delta) => {
            let newZoomLevel = Math.max(_map.zoomLevel + Math.log2(delta), 0)
            _map.zoomLevel = newZoomLevel
            _map.alignCoordinateToPoint(pinchStartCentroid, pinchHandler.centroid.position)
        }
    }

    // Wheel zoom via MouseArea (classic path) so it also works over remote desktop.
    // NoButton keeps panning on the touch area.
    MouseArea {
        anchors.fill:            parent
        acceptedButtons:         Qt.NoButton
        propagateComposedEvents: true
        onWheel: (wheel) => {
            var step = 0.0
            if (wheel.angleDelta.y !== 0)      step = wheel.angleDelta.y / 120.0
            else if (wheel.pixelDelta.y !== 0) step = wheel.pixelDelta.y / 50.0
            if (step !== 0.0) {
                _map.zoomLevel = Math.max(_map.minimumZoomLevel,
                                    Math.min(_map.maximumZoomLevel, _map.zoomLevel + step * 0.5))
            }
            wheel.accepted = true
        }
    }

    // Keyboard zoom (Ctrl +/-); avoids stealing +/-/= from text fields.
    Shortcut {
        sequences:   [StandardKey.ZoomIn, "Ctrl+="]
        enabled:     _map.visible
        onActivated: _map.zoomLevel = Math.min(_map.maximumZoomLevel, _map.zoomLevel + 1)
    }
    Shortcut {
        sequences:   [StandardKey.ZoomOut]
        enabled:     _map.visible
        onActivated: _map.zoomLevel = Math.max(_map.minimumZoomLevel, _map.zoomLevel - 1)
    }

    // We specifically do not use a DragHandler for panning. It just causes too many problems if you overlay anything else like a Flickable above it.
    // Causes all sorts of crazy problems where dragging/scrolling  no longerr works on items above in the hierarchy.
    // Since we are using a MouseArea we also can't use TapHandler for clicks. So we handle that here as well.
    MultiPointTouchArea {
        anchors.fill: parent
        maximumTouchPoints: 1
        mouseEnabled: true

        property bool dragActive: false
        property real lastMouseX
        property real lastMouseY

        onPressed: (touchPoints) => {
            lastMouseX = touchPoints[0].x
            lastMouseY = touchPoints[0].y
        }

        onGestureStarted: (gesture) => {
            dragActive = true
            gesture.grab()
            mapPanStart()
        }

        onUpdated: (touchPoints) => {
            if (dragActive) {
                let deltaX = touchPoints[0].x - lastMouseX
                let deltaY = touchPoints[0].y - lastMouseY
                if (Math.abs(deltaX) >= 1.0 || Math.abs(deltaY) >= 1.0) {
                    _map.pan(lastMouseX - touchPoints[0].x, lastMouseY - touchPoints[0].y)
                    lastMouseX = touchPoints[0].x
                    lastMouseY = touchPoints[0].y
                }
            }
        }

        onReleased: (touchPoints) => {
            if (dragActive) {
                _map.pan(lastMouseX - touchPoints[0].x, lastMouseY - touchPoints[0].y)
                dragActive = false
                mapPanStop()
            } else {
                mapClicked(Qt.point(touchPoints[0].x, touchPoints[0].y))
            }
        }
    }

    // Cross cursor while picking an emergency target; inert + passes wheel otherwise.
    MouseArea {
        anchors.fill: parent
        enabled: _activeVehicle && _activeVehicle.emergencyController
                 && _activeVehicle.emergencyController.selectingTarget
        hoverEnabled: enabled
        acceptedButtons: Qt.NoButton    // does NOT steal clicks
        propagateComposedEvents: true
        z: 999999                       // always on top
        cursorShape: Qt.CrossCursor
        onWheel: (wheel) => { wheel.accepted = false }   // let the map zoom
    }

    // Transparent +/- zoom buttons (enable via showZoomControls)
    Column {
        id:                       _zoomControls
        visible:                  _map.showZoomControls
        z:                        1000
        anchors.right:            parent.right
        anchors.rightMargin:      _map.zoomControlsRightInset
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     ScreenTools.defaultFontPixelHeight * 2
        spacing:                  ScreenTools.defaultFontPixelHeight * 0.5

        Repeater {
            model: [ { sym: "+", delta: 1 }, { sym: "−", delta: -1 } ]
            delegate: Rectangle {
                width:        ScreenTools.defaultFontPixelHeight * 2.6
                height:       width
                radius:       width * 0.25
                color:        zoomBtnArea.pressed ? Qt.rgba(0, 0, 0, 0.75)
                                  : (zoomBtnArea.containsMouse ? Qt.rgba(0, 0, 0, 0.60) : Qt.rgba(0, 0, 0, 0.45))
                border.color: Qt.rgba(1, 1, 1, 0.25)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text:             modelData.sym
                    color:            "white"
                    font.pixelSize:   ScreenTools.defaultFontPixelHeight * 1.4
                    font.bold:        true
                }

                MouseArea {
                    id:           zoomBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        var nz = _map.zoomLevel + modelData.delta
                        _map.zoomLevel = Math.max(_map.minimumZoomLevel, Math.min(_map.maximumZoomLevel, nz))
                    }
                }
            }
        }
    }

    /// Ground Station location
    MapQuickItem {
        anchorPoint.x:  sourceItem.width / 2
        anchorPoint.y:  sourceItem.height / 2
        visible:        gcsPosition.isValid
        coordinate:     gcsPosition

        sourceItem: Image {
            id:             mapItemImage
            source:         isNaN(gcsHeading) ? "/res/QGCLogoFull.svg" : "/res/QGCLogoArrow.svg"
            mipmap:         true
            antialiasing:   true
            fillMode:       Image.PreserveAspectFit
            height:         ScreenTools.defaultFontPixelHeight * (isNaN(gcsHeading) ? 1.75 : 2.5 )
            sourceSize.height: height
            transform: Rotation {
                origin.x:       mapItemImage.width  / 2
                origin.y:       mapItemImage.height / 2
                angle:          isNaN(gcsHeading) ? 0 : gcsHeading
            }
        }
    }
} // Map
