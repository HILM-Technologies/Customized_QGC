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

import QGroundControl
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.Controls

Item {
    id:     root
    clip:   true

    property bool useSmallFont: true

    property double _ar:                QGroundControl.videoManager.gstreamerEnabled
                                            ? QGroundControl.videoManager.videoSize.width / QGroundControl.videoManager.videoSize.height
                                            : QGroundControl.videoManager.aspectRatio
    property bool   _showGrid:          QGroundControl.settingsManager.videoSettings.gridLines.rawValue
    property var    _dynamicCameras:    globals.activeVehicle ? globals.activeVehicle.cameraManager : null
    property bool   _connected:         globals.activeVehicle ? !globals.activeVehicle.communicationLost : false
    property int    _curCameraIndex:    _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property bool   _isCamera:          _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    property var    _camera:            _isCamera ? _dynamicCameras.cameras.get(_curCameraIndex) : null
    property bool   _hasZoom:           _camera && _camera.hasZoom
    property int    _fitMode:           QGroundControl.settingsManager.videoSettings.videoFit.rawValue

    property bool   _isMode_FIT_WIDTH:  _fitMode === 0
    property bool   _isMode_FIT_HEIGHT: _fitMode === 1
    property bool   _isMode_FILL:       _fitMode === 2
    property bool   _isMode_NO_CROP:    _fitMode === 3

    function getWidth() {
        return videoBackground.getWidth()
    }
    function getHeight() {
        return videoBackground.getHeight()
    }

    property double _thermalHeightFactor: 0.85 //-- TODO

        // ── HILM-styled "no video" placeholder ───────────────────────────────
        Item {
            id:           noVideo
            anchors.fill: parent
            visible:      !(QGroundControl.videoManager.decoding)

            readonly property bool _streamEnabled: QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue

            // Dark background
            Rectangle { anchors.fill: parent; color: Qt.rgba(0.04, 0.06, 0.06, 1.0) }

            // Dot-grid
            Canvas {
                anchors.fill: parent; opacity: 0.08
                Component.onCompleted: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.fillStyle = "#00C8C8"
                    var sp = ScreenTools.defaultFontPixelHeight * 1.6
                    for (var x = 0; x <= width + sp; x += sp)
                        for (var y = 0; y <= height + sp; y += sp) {
                            ctx.beginPath(); ctx.arc(x, y, 0.9, 0, Math.PI * 2); ctx.fill()
                        }
                }
            }

            // Top accent line
            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                height: 2; opacity: 0.55
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.3; color: "#00C8C8" }
                    GradientStop { position: 0.7; color: "#00C8C8" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Center content
            Column {
                anchors.centerIn: parent
                spacing:          ScreenTools.defaultFontPixelHeight * 0.55

                // Camera icon
                Canvas {
                    anchors.horizontalCenter: parent.horizontalCenter
                    property real _sz: useSmallFont
                                           ? ScreenTools.defaultFontPixelHeight * 2.8
                                           : ScreenTools.defaultFontPixelHeight * 4.5
                    width: _sz; height: _sz * 0.76
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var cx = width / 2, cy = height / 2
                        var bw = width * 0.72, bh = height * 0.64
                        var x0 = cx - bw/2, y0 = cy - bh/2
                        var rr = bw * 0.08
                        ctx.strokeStyle = "#00C8C8"; ctx.lineJoin = "round"; ctx.lineCap = "round"
                        // Body
                        ctx.globalAlpha = 0.55; ctx.lineWidth = width * 0.055
                        ctx.beginPath()
                        ctx.moveTo(x0 + rr, y0)
                        ctx.lineTo(x0 + bw - rr, y0); ctx.quadraticCurveTo(x0 + bw, y0, x0 + bw, y0 + rr)
                        ctx.lineTo(x0 + bw, y0 + bh - rr); ctx.quadraticCurveTo(x0 + bw, y0 + bh, x0 + bw - rr, y0 + bh)
                        ctx.lineTo(x0 + rr, y0 + bh); ctx.quadraticCurveTo(x0, y0 + bh, x0, y0 + bh - rr)
                        ctx.lineTo(x0, y0 + rr); ctx.quadraticCurveTo(x0, y0, x0 + rr, y0)
                        ctx.closePath(); ctx.stroke()
                        // Viewfinder bump
                        var bumpW = bw * 0.22, bumpH = bh * 0.26
                        ctx.globalAlpha = 0.55; ctx.lineWidth = width * 0.048
                        var bx = cx - bumpW/2, by = y0 - bumpH + (width * 0.055) / 2
                        ctx.beginPath()
                        ctx.moveTo(bx + rr*0.5, by)
                        ctx.lineTo(bx + bumpW - rr*0.5, by); ctx.quadraticCurveTo(bx + bumpW, by, bx + bumpW, by + rr*0.5)
                        ctx.lineTo(bx + bumpW, by + bumpH); ctx.lineTo(bx, by + bumpH)
                        ctx.lineTo(bx, by + rr*0.5); ctx.quadraticCurveTo(bx, by, bx + rr*0.5, by)
                        ctx.closePath(); ctx.stroke()
                        // Lens outer
                        ctx.globalAlpha = 0.82; ctx.lineWidth = width * 0.050
                        ctx.beginPath(); ctx.arc(cx, cy + bh * 0.04, bh * 0.28, 0, Math.PI * 2); ctx.stroke()
                        // Lens inner fill
                        ctx.globalAlpha = 0.20; ctx.fillStyle = "#00C8C8"
                        ctx.beginPath(); ctx.arc(cx, cy + bh * 0.04, bh * 0.14, 0, Math.PI * 2); ctx.fill()
                    }
                }

                // Status label
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           noVideo._streamEnabled ? qsTr("WAITING FOR VIDEO") : qsTr("VIDEO DISABLED")
                    color:          "#00C8C8"
                    font.bold:      true
                    font.letterSpacing: 2.5
                    font.pixelSize: useSmallFont
                                        ? ScreenTools.defaultFontPixelHeight * 0.75
                                        : ScreenTools.defaultFontPixelHeight * 1.05
                }

                // Subtitle (full-size view only)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible:        !useSmallFont
                    text:           noVideo._streamEnabled
                                        ? qsTr("Check video source in settings")
                                        : qsTr("Enable streaming in Application Settings")
                    color:          Qt.rgba(1, 1, 1, 0.32)
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                }
            }

            // Configure feed button (full-size only)
            Rectangle {
                anchors.bottom:           parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin:     ScreenTools.defaultFontPixelHeight * 0.9
                visible:                  !useSmallFont
                width:  cfgLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 2.8
                height: cfgLabel.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.45
                radius: height / 2
                color:  cfgArea.containsMouse ? Qt.rgba(0, 0.784, 0.784, 0.18) : Qt.rgba(0, 0.784, 0.784, 0.07)
                border.color: Qt.rgba(0, 0.784, 0.784, cfgArea.containsMouse ? 0.65 : 0.28)
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }

                Text {
                    id:               cfgLabel
                    anchors.centerIn: parent
                    text:             qsTr("\u2699  Configure Feed")
                    color:            Qt.rgba(0, 0.784, 0.784, cfgArea.containsMouse ? 1.0 : 0.75)
                    font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.68
                    Behavior on color { ColorAnimation { duration: 130 } }
                }

                MouseArea {
                    id:           cfgArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    mainWindow.showSettingsTool()
                }
            }
        }

    Rectangle {
        id:             videoBackground
        anchors.fill:   parent
        color:          "black"
        visible:        QGroundControl.videoManager.decoding
        function getWidth() {
            if(_ar != 0.0){
                if(_isMode_FIT_HEIGHT
                        || (_isMode_FILL && (root.width/root.height < _ar))
                        || (_isMode_NO_CROP && (root.width/root.height > _ar))){
                    // This return value has different implications depending on the mode
                    // For FIT_HEIGHT and FILL
                    //    makes so the video width will be larger than (or equal to) the screen width
                    // For NO_CROP Mode
                    //    makes so the video width will be smaller than (or equal to) the screen width
                    return root.height * _ar
                }
            }
            return root.width
        }
        function getHeight() {
            if(_ar != 0.0){
                if(_isMode_FIT_WIDTH
                        || (_isMode_FILL && (root.width/root.height > _ar))
                        || (_isMode_NO_CROP && (root.width/root.height < _ar))){
                    // This return value has different implications depending on the mode
                    // For FIT_WIDTH and FILL
                    //    makes so the video height will be larger than (or equal to) the screen height
                    // For NO_CROP Mode
                    //    makes so the video height will be smaller than (or equal to) the screen height
                    return root.width * (1 / _ar)
                }
            }
            return root.height
        }
        Component {
            id: videoBackgroundComponent
            QGCVideoBackground {
                id:             videoContent
                objectName:     "videoContent"

                Connections {
                    target: QGroundControl.videoManager
                    function onImageFileChanged(filename) {
                        videoContent.grabToImage(function(result) {
                            if (!result.saveToFile(filename)) {
                                console.error('Error capturing video frame');
                            }
                        });
                    }
                }

                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.33
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.66
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.33
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.66
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
            }
        }
        Loader {
            // GStreamer is causing crashes on Lenovo laptop OpenGL Intel drivers. In order to workaround this
            // we don't load a QGCVideoBackground object when video is disabled. This prevents any video rendering
            // code from running. Hence the Loader to completely remove it.
            height:             parent.getHeight()
            width:              parent.getWidth()
            anchors.centerIn:   parent
            visible:            QGroundControl.videoManager.decoding
            sourceComponent:    videoBackgroundComponent

            property bool videoDisabled: QGroundControl.settingsManager.videoSettings.videoSource.rawValue === QGroundControl.settingsManager.videoSettings.disabledVideoSource
        }

        //-- Thermal Image
        Item {
            id:                 thermalItem
            width:              height * QGroundControl.videoManager.thermalAspectRatio
            height:             _camera ? (_camera.thermalMode === MavlinkCameraControl.THERMAL_FULL ? parent.height : (_camera.thermalMode === MavlinkCameraControl.THERMAL_PIP ? ScreenTools.defaultFontPixelHeight * 12 : parent.height * _thermalHeightFactor)) : 0
            anchors.centerIn:   parent
            visible:            QGroundControl.videoManager.hasThermal && _camera.thermalMode !== MavlinkCameraControl.THERMAL_OFF
            function pipOrNot() {
                if(_camera) {
                    if(_camera.thermalMode === MavlinkCameraControl.THERMAL_PIP) {
                        anchors.centerIn    = undefined
                        anchors.top         = parent.top
                        anchors.topMargin   = mainWindow.header.height + (ScreenTools.defaultFontPixelHeight * 0.5)
                        anchors.left        = parent.left
                        anchors.leftMargin  = ScreenTools.defaultFontPixelWidth * 12
                    } else {
                        anchors.top         = undefined
                        anchors.topMargin   = undefined
                        anchors.left        = undefined
                        anchors.leftMargin  = undefined
                        anchors.centerIn    = parent
                    }
                }
            }
            Connections {
                target:                 _camera
                function onThermalModeChanged() { thermalItem.pipOrNot() }
            }
            onVisibleChanged: {
                thermalItem.pipOrNot()
            }
            QGCVideoBackground {
                id:             thermalVideo
                objectName:     "thermalVideo"
                anchors.fill:   parent
                opacity:        _camera ? (_camera.thermalMode === MavlinkCameraControl.THERMAL_BLEND ? _camera.thermalOpacity / 100 : 1.0) : 0
            }
        }
        //-- Zoom
        PinchArea {
            id:             pinchZoom
            enabled:        _hasZoom
            anchors.fill:   parent
            onPinchStarted: pinchZoom.zoom = 0
            onPinchUpdated: {
                if(_hasZoom) {
                    var z = 0
                    if(pinch.scale < 1) {
                        z = Math.round(pinch.scale * -10)
                    } else {
                        z = Math.round(pinch.scale)
                    }
                    if(pinchZoom.zoom != z) {
                        _camera.stepZoom(z)
                    }
                }
            }
            property int zoom: 0
        }
    }
}
