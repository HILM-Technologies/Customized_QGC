/****************************************************************************
 *
 * HILM Ground Control — Right Panel (Quick Actions + Live Video)
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Rectangle {
    id: rightPanel

    width:   ScreenTools.defaultFontPixelWidth * 34
    height:  parent ? parent.height : 400
    radius:  ScreenTools.defaultFontPixelHeight * 0.4
    color:   Qt.rgba(0, 0, 0, 0.80)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.06)
    clip:    true

    // Exposed so FlyView can parent PipView inside here
    property alias videoContainer: _videoContainer

    // HILM design tokens
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property color _errColor:   "#FF5252"
    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth * 0.8

    property var _activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    property var _guidedController: globals.guidedControllerFlyView
    property var _emergency:        _activeVehicle ? _activeVehicle.emergencyController : null

    // Emergency state helpers
    property bool _emergencySelecting:  _emergency ? _emergency.selectingTarget : false
    property bool _emergencyTargetSet:  _emergency ? _emergency.targetSelected  : false
    property bool _emergencyActive:     _emergency ? _emergency.emergencyActive : false
    property bool _emergencyEngaged:    _emergencySelecting || _emergencyTargetSet || _emergencyActive

    ColumnLayout {
        anchors.fill:       parent
        anchors.margins:    _pad
        spacing:            _pad * 0.6

        // ══════════════════════════════════
        // QUICK ACTIONS
        // ══════════════════════════════════
        QGCLabel {
            text:               "QUICK ACTIONS"
            color:              _teal
            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.7
            font.bold:          true
            font.letterSpacing: 1.2
            Layout.topMargin:   _pad * 0.2
        }

        // 2x2 Action Grid
        GridLayout {
            Layout.fillWidth: true
            columns:          2
            rowSpacing:       _pad * 0.5
            columnSpacing:    _pad * 0.5

            // ── ARM
            Rectangle {
                id: armBtn
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  armArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.18) : Qt.rgba(0, 0.749, 1.0, 0.08)
                border.width:           1
                border.color:           armArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.40) : Qt.rgba(0, 0.749, 1.0, 0.20)
                opacity:                _activeVehicle ? 1.0 : 0.45

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing:          _pad * 0.3

                    QGCColoredImage {
                        Layout.alignment:   Qt.AlignHCenter
                        width:              ScreenTools.defaultFontPixelHeight * 1.4
                        height:             width
                        source:             "/qmlimages/Armed.svg"
                        color:              _teal
                        fillMode:           Image.PreserveAspectFit
                    }
                    QGCLabel {
                        Layout.alignment:   Qt.AlignHCenter
                        text:               "ARM"
                        color:              _teal
                        font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                        font.bold:          true
                    }
                }

                MouseArea {
                    id: armArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (_activeVehicle) {
                            _guidedController.confirmAction(_guidedController.actionArm)
                        }
                    }
                }
            }

            // ── DISARM
            Rectangle {
                id: disarmBtn
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  disarmArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.10) : _cardBg
                border.width:           1
                border.color:           disarmArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.32) : Qt.rgba(1, 1, 1, 0.08)
                opacity:                _activeVehicle ? 1.0 : 0.45

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing:          _pad * 0.3

                    QGCColoredImage {
                        Layout.alignment:   Qt.AlignHCenter
                        width:              ScreenTools.defaultFontPixelHeight * 1.4
                        height:             width
                        source:             "/qmlimages/Disarmed.svg"
                        color:              "white"
                        fillMode:           Image.PreserveAspectFit
                    }
                    QGCLabel {
                        Layout.alignment:   Qt.AlignHCenter
                        text:               "DISARM"
                        color:              "white"
                        font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                        font.bold:          true
                    }
                }

                MouseArea {
                    id: disarmArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (_activeVehicle) {
                            _guidedController.confirmAction(_guidedController.actionDisarm)
                        }
                    }
                }
            }

            // ── RTL
            Rectangle {
                id: rtlBtn
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  rtlArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.10) : _cardBg
                border.width:           1
                border.color:           rtlArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.32) : Qt.rgba(1, 1, 1, 0.08)
                opacity:                _activeVehicle ? 1.0 : 0.45

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing:          _pad * 0.3

                    QGCColoredImage {
                        Layout.alignment:   Qt.AlignHCenter
                        width:              ScreenTools.defaultFontPixelHeight * 1.4
                        height:             width
                        source:             "/qmlimages/Plan.svg"
                        color:              "white"
                        fillMode:           Image.PreserveAspectFit
                    }
                    QGCLabel {
                        Layout.alignment:   Qt.AlignHCenter
                        text:               "RTL"
                        color:              "white"
                        font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                        font.bold:          true
                    }
                }

                MouseArea {
                    id: rtlArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (_activeVehicle) {
                            _guidedController.confirmAction(_guidedController.actionRTL)
                        }
                    }
                }
            }

            // ── EMERGENCY (stateful)
            Rectangle {
                id: emergencyBtn
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                border.width:           1.5
                border.color:           _errColor

                color: {
                    if (_emergencyActive)
                        return Qt.rgba(1, 0, 0, 0.25)
                    if (_emergencySelecting)
                        return Qt.rgba(1, 0.6, 0, 0.15)
                    if (_emergencyTargetSet)
                        return Qt.rgba(1, 0, 0, 0.15)
                    return emergencyArea.containsMouse ? Qt.rgba(1, 0, 0, 0.14) : Qt.rgba(1, 0, 0, 0.06)
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing:          _pad * 0.2

                    QGCColoredImage {
                        Layout.alignment:   Qt.AlignHCenter
                        width:              ScreenTools.defaultFontPixelHeight * 1.4
                        height:             width
                        source:             "/qmlimages/Yield.svg"
                        color:              _emergencySelecting ? "#FF9800" : _errColor
                        fillMode:           Image.PreserveAspectFit

                        // Pulsing animation when selecting target
                        SequentialAnimation on opacity {
                            running: _emergencySelecting
                            loops:   Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }
                    QGCLabel {
                        Layout.alignment:   Qt.AlignHCenter
                        text: {
                            if (_emergencyActive)    return "ACTIVE"
                            if (_emergencySelecting) return "TAP MAP"
                            if (_emergencyTargetSet) return "READY"
                            return "EMERGENCY"
                        }
                        color:              _emergencySelecting ? "#FF9800" : _errColor
                        font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.55
                        font.bold:          true
                    }
                }

                // Dim when no vehicle
                opacity: _activeVehicle ? 1.0 : 0.45

                MouseArea {
                    id: emergencyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        console.warn("EMERGENCY click: _activeVehicle=" + _activeVehicle +
                                     " _emergency=" + _emergency +
                                     " selecting=" + _emergencySelecting +
                                     " targetSet=" + _emergencyTargetSet +
                                     " active=" + _emergencyActive)
                        if (!_activeVehicle) {
                            console.warn("EMERGENCY: No vehicle connected")
                            return
                        }
                        if (!_emergency) {
                            console.warn("EMERGENCY: No emergencyController on vehicle")
                            return
                        }
                        if (_emergencyActive || _emergencySelecting || _emergencyTargetSet) {
                            console.warn("EMERGENCY: Already engaged, ignoring click")
                            return
                        }
                        console.warn("EMERGENCY: Calling startEmergencySelect()")
                        _emergency.startEmergencySelect()
                    }
                }
            }
        }

        // ══════════════════════════════════
        // EMERGENCY DEPLOYMENT PANEL (visible during emergency states)
        // ══════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: emergencyPanelLayout.implicitHeight + _pad * 1.2
            radius:  ScreenTools.defaultFontPixelHeight * 0.3
            color:   Qt.rgba(1, 0, 0, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 0, 0, 0.25)
            visible: _emergencyEngaged

            ColumnLayout {
                id: emergencyPanelLayout
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.top:     parent.top
                anchors.margins: _pad * 0.6
                spacing:         _pad * 0.5

                // Status text
                QGCLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                    font.bold: true
                    color: {
                        if (_emergencyActive)    return _errColor
                        if (_emergencySelecting) return "#FF9800"
                        return "white"
                    }
                    text: {
                        if (_emergencyActive)    return "EMERGENCY DEPLOYMENT ACTIVE"
                        if (_emergencySelecting) return "SELECT LOCATION ON MAP"
                        if (_emergencyTargetSet) {
                            var coord = _emergency.emergencyCoordinate
                            return "TARGET: " + coord.latitude.toFixed(5) + ", " + coord.longitude.toFixed(5)
                        }
                        return ""
                    }
                }

                // DEPLOY NOW button (visible when target is selected)
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                    color:                  deployArea.containsMouse ? Qt.lighter(_errColor, 1.2) : _errColor
                    visible:                _emergencyTargetSet && !_emergencyActive

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: _pad * 0.4

                        QGCColoredImage {
                            width:    ScreenTools.defaultFontPixelHeight * 0.8
                            height:   width
                            source:   "/qmlimages/Yield.svg"
                            color:    "white"
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text:               "DEPLOY NOW"
                            color:              "white"
                            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.7
                            font.bold:          true
                            font.letterSpacing: 0.8
                        }
                    }

                    MouseArea {
                        id: deployArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (_emergency) _emergency.deployEmergency()
                        }
                    }
                }

                // RETURN HOME button (visible when deployed)
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                    color:                  rthArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.18) : Qt.rgba(0, 0.749, 1.0, 0.10)
                    border.width:           1
                    border.color:           Qt.rgba(0, 0.749, 1.0, 0.32)
                    visible:                _emergencyActive

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: _pad * 0.4

                        QGCColoredImage {
                            width:    ScreenTools.defaultFontPixelHeight * 0.8
                            height:   width
                            source:   "/qmlimages/Plan.svg"
                            color:    _teal
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text:               "RETURN HOME"
                            color:              _teal
                            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                            font.bold:          true
                            font.letterSpacing: 0.5
                        }
                    }

                    MouseArea {
                        id: rthArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (_emergency) _emergency.returnToHome()
                        }
                    }
                }

                // CANCEL button
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                    color:                  cancelArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : _cardBg
                    border.width:           1
                    border.color:           Qt.rgba(1, 1, 1, 0.10)

                    QGCLabel {
                        anchors.centerIn: parent
                        text:               "CANCEL"
                        color:              _dimText
                        font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.6
                        font.bold:          true
                        font.letterSpacing: 0.5
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (_emergency) _emergency.cancelEmergency()
                        }
                    }
                }
            }
        }

        // ── START PATROL button
        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
            radius:                 ScreenTools.defaultFontPixelHeight * 0.3
            color:                  patrolArea.containsMouse ? Qt.lighter(_teal, 1.15) : _teal
            visible:                !_emergencyEngaged

            RowLayout {
                anchors.centerIn: parent
                spacing:          _pad * 0.5

                QGCColoredImage {
                    width:      ScreenTools.defaultFontPixelHeight * 0.85
                    height:     width
                    source:     "/qmlimages/PaperPlane.svg"
                    color:      "#000000"
                    fillMode:   Image.PreserveAspectFit
                }
                QGCLabel {
                    text:               "START PATROL"
                    color:              "#000000"
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.7
                    font.bold:          true
                    font.letterSpacing: 0.8
                }
            }

            MouseArea {
                id: patrolArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (_activeVehicle) {
                        _guidedController.confirmAction(_guidedController.actionStartMission)
                    }
                }
            }
        }

        // ── Separator
        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            Qt.rgba(1, 1, 1, 0.08)
        }

        // ══════════════════════════════════
        // LIVE VIDEO
        // ══════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing:          _pad * 0.4

            QGCLabel {
                text:               "LIVE VIDEO"
                color:              _teal
                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.7
                font.bold:          true
                font.letterSpacing: 1.2
                Layout.fillWidth:   true
            }

            // GRID button
            Rectangle {
                width:   gridRow.implicitWidth + _pad * 1.4
                height:  gridRow.implicitHeight + _pad * 0.5
                radius:  height / 2
                color:   _cardBg
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                RowLayout {
                    id: gridRow
                    anchors.centerIn: parent
                    spacing: _pad * 0.3

                    QGCColoredImage {
                        width:      ScreenTools.defaultFontPixelHeight * 0.6
                        height:     width
                        source:     "/qmlimages/Gears.svg"
                        color:      "white"
                        fillMode:   Image.PreserveAspectFit
                    }
                    QGCLabel {
                        text:           "GRID"
                        color:          "white"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                        font.bold:      true
                    }
                }
            }

            // Expand icon
            QGCColoredImage {
                width:      ScreenTools.defaultFontPixelHeight * 0.7
                height:     width
                source:     "/qmlimages/MaximizeStatic.svg"
                color:      "white"
                fillMode:   Image.PreserveAspectFit
            }
        }

        // ── Video area (PipView will be reparented here from FlyView)
        Rectangle {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 8
            radius:            ScreenTools.defaultFontPixelHeight * 0.35
            color:             Qt.rgba(1, 1, 1, 0.02)
            border.width:      1
            border.color:      Qt.rgba(1, 1, 1, 0.06)
            clip:              true

            // Container where PipView gets reparented
            Item {
                id:             _videoContainer
                anchors.fill:   parent
            }

            // Placeholder — shown when no video
            ColumnLayout {
                anchors.centerIn: parent
                spacing:          _pad
                visible:          _videoContainer.children.length <= 0 ||
                                  (!QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.decoding)

                QGCColoredImage {
                    Layout.alignment:   Qt.AlignHCenter
                    width:              ScreenTools.defaultFontPixelHeight * 2.5
                    height:             width
                    source:             "/qmlimages/CameraIcon.svg"
                    color:              _dimText
                    fillMode:           Image.PreserveAspectFit
                }
                QGCLabel {
                    Layout.alignment:   Qt.AlignHCenter
                    text:               "No active video stream"
                    color:              _dimText
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                }
                QGCLabel {
                    Layout.alignment:   Qt.AlignHCenter
                    text:               "Select armed drone"
                    color:              Qt.rgba(1, 1, 1, 0.3)
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.55
                }
            }
        }

        // ── Bottom video controls
        RowLayout {
            Layout.fillWidth: true
            spacing:          _pad * 0.5

            Repeater {
                model: [
                    { label: "TRACK",    icon: "/qmlimages/TrackingIcon.svg" },
                    { label: "RECORD",   icon: "/qmlimages/CameraIcon.svg" },
                    { label: "SNAPSHOT", icon: "/qmlimages/CameraIcon.svg" }
                ]

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.9
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                    color:                  ctrlArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : _cardBg
                    border.width:           1
                    border.color:           Qt.rgba(1, 1, 1, 0.08)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing:          _pad * 0.25

                        QGCColoredImage {
                            width:      ScreenTools.defaultFontPixelHeight * 0.6
                            height:     width
                            source:     modelData.icon
                            color:      "white"
                            fillMode:   Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text:           modelData.label
                            color:          "white"
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                            font.bold:      true
                        }
                    }

                    MouseArea {
                        id: ctrlArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.label === "SNAPSHOT") {
                                QGroundControl.videoManager.grabImage()
                            }
                        }
                    }
                }
            }
        }
    }
}
