/****************************************************************************
 *
 * HILM Ground Control — Right Panel (Quick Actions + Live Video)
 * Collapsible: click arrow to expand/collapse horizontally
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Item {
    id: rightPanelRoot

    // Expanded = full panel, Collapsed = just the arrow tab
    property bool expanded: true

    readonly property real _expandedWidth:  ScreenTools.defaultFontPixelWidth * 54
    readonly property real _collapsedWidth: ScreenTools.defaultFontPixelWidth * 2.5
    readonly property real _tabWidth:       ScreenTools.defaultFontPixelWidth * 2.5

    width:  expanded ? _expandedWidth : _collapsedWidth
    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

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

    // Responsive: scale action button height based on available panel height
    // On small screens (Android) buttons shrink, on large screens they stay comfortable
    readonly property real _actionBtnHeight: Math.max(ScreenTools.defaultFontPixelHeight * 2.8,
                                                       Math.min(ScreenTools.defaultFontPixelHeight * 3.6,
                                                                rightPanelRoot.height * 0.055))
    readonly property real _sectionGap:      Math.max(_pad * 0.8, rightPanelRoot.height * 0.012)

    property var _activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    property var _guidedController: globals.guidedControllerFlyView
    property var _emergency:        _activeVehicle ? _activeVehicle.emergencyController : null

    // Emergency state helpers
    property bool _emergencySelecting:  _emergency ? _emergency.selectingTarget : false
    property bool _emergencyTargetSet:  _emergency ? _emergency.targetSelected  : false
    property bool _emergencyActive:     _emergency ? _emergency.emergencyActive : false
    property bool _emergencyEngaged:    _emergencySelecting || _emergencyTargetSet || _emergencyActive

    // ══════════════════════════════════════════════
    // Toggle arrow tab (always visible on left edge)
    // ══════════════════════════════════════════════
    Rectangle {
        id: toggleTab
        anchors.left:           parent.left
        anchors.verticalCenter: parent.verticalCenter
        width:                  _tabWidth
        height:                 ScreenTools.defaultFontPixelHeight * 4
        radius:                 ScreenTools.defaultFontPixelHeight * 0.3
        color:                  toggleArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.15) : Qt.rgba(0, 0, 0, 0.70)
        border.width:           1
        border.color:           toggleArea.containsMouse ? _tealBorder : Qt.rgba(1, 1, 1, 0.10)
        z:                      2

        QGCLabel {
            anchors.centerIn: parent
            text:               expanded ? "\u203A" : "\u2039"
            color:              _teal
            font.pointSize:     ScreenTools.defaultFontPointSize * 1.4
            font.bold:          true
        }

        MouseArea {
            id:             toggleArea
            anchors.fill:   parent
            hoverEnabled:   true
            onClicked:      expanded = !expanded
        }
    }

    // ══════════════════════════════════════════════
    // Main panel body
    // ══════════════════════════════════════════════
    Rectangle {
        id: panelBody
        anchors.left:   toggleTab.right
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        radius:         ScreenTools.defaultFontPixelHeight * 0.4
        color:          Qt.rgba(0, 0, 0, 0.80)
        border.width:   1
        border.color:   Qt.rgba(1, 1, 1, 0.06)
        clip:           true
        visible:        expanded
        opacity:        expanded ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        ColumnLayout {
            anchors.fill:       parent
            anchors.margins:    _pad * 1.2
            spacing:            0   // We control all spacing via topMargin

            // ══════════════════════════════════
            // QUICK ACTIONS header
            // ══════════════════════════════════
            QGCLabel {
                text:               "QUICK ACTIONS"
                color:              _teal
                font.pointSize:     ScreenTools.defaultFontPointSize * 0.8
                font.bold:          true
                font.letterSpacing: 1.2
                Layout.topMargin:   _pad * 0.5
            }

            // 2x2 Action Grid
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: _pad * 0.6
                columns:          2
                rowSpacing:       _pad * 0.5
                columnSpacing:    _pad * 0.5

                // ── ARM
                Rectangle {
                    id: armBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: _actionBtnHeight
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                    color:                  armArea.containsMouse ? "#1E4D1E" : "#142D14"
                    border.width:           1.5
                    border.color:           armArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.55) : Qt.rgba(0, 0.749, 1.0, 0.28)
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
                            font.pointSize:     ScreenTools.defaultFontPointSize * 0.75
                            font.bold:          true
                            font.letterSpacing: 0.5
                        }
                    }

                    MouseArea {
                        id: armArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            if (_activeVehicle)
                                _activeVehicle.armed = true
                        }
                    }
                }

                // ── DISARM
                Rectangle {
                    id: disarmBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: _actionBtnHeight
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                    color:                  disarmArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.width:           1
                    border.color:           disarmArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.35) : Qt.rgba(1, 1, 1, 0.10)
                    opacity:                _activeVehicle ? 1.0 : 0.45

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing:          _pad * 0.3

                        QGCColoredImage {
                            Layout.alignment:   Qt.AlignHCenter
                            width:              ScreenTools.defaultFontPixelHeight * 1.4
                            height:             width
                            source:             "/qmlimages/Disarmed.svg"
                            color:              Qt.rgba(1, 1, 1, 0.85)
                            fillMode:           Image.PreserveAspectFit
                        }
                        QGCLabel {
                            Layout.alignment:   Qt.AlignHCenter
                            text:               "DISARM"
                            color:              Qt.rgba(1, 1, 1, 0.85)
                            font.pointSize:     ScreenTools.defaultFontPointSize * 0.75
                            font.bold:          true
                            font.letterSpacing: 0.5
                        }
                    }

                    MouseArea {
                        id: disarmArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            if (_activeVehicle)
                                _activeVehicle.armed = false
                        }
                    }
                }

                // ── RTL
                Rectangle {
                    id: rtlBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: _actionBtnHeight
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                    color:                  rtlArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.width:           1
                    border.color:           rtlArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.35) : Qt.rgba(1, 1, 1, 0.10)
                    opacity:                _activeVehicle ? 1.0 : 0.45

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing:          _pad * 0.3

                        QGCColoredImage {
                            Layout.alignment:   Qt.AlignHCenter
                            width:              ScreenTools.defaultFontPixelHeight * 1.4
                            height:             width
                            source:             "/qmlimages/Plan.svg"
                            color:              Qt.rgba(1, 1, 1, 0.85)
                            fillMode:           Image.PreserveAspectFit
                        }
                        QGCLabel {
                            Layout.alignment:   Qt.AlignHCenter
                            text:               "RTL"
                            color:              Qt.rgba(1, 1, 1, 0.85)
                            font.pointSize:     ScreenTools.defaultFontPointSize * 0.75
                            font.bold:          true
                            font.letterSpacing: 0.5
                        }
                    }

                    MouseArea {
                        id: rtlArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            if (_activeVehicle)
                                _activeVehicle.guidedModeRTL(false)
                        }
                    }
                }

                // ── EMERGENCY (stateful)
                Rectangle {
                    id: emergencyBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: _actionBtnHeight
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                    border.width:           1.5
                    border.color:           emergencyArea.containsMouse ? Qt.lighter(_errColor, 1.2) : _errColor
                    opacity:                _activeVehicle ? 1.0 : 0.45

                    color: {
                        if (_emergencyActive)    return Qt.rgba(1, 0, 0, 0.25)
                        if (_emergencySelecting) return Qt.rgba(1, 0.6, 0, 0.15)
                        if (_emergencyTargetSet) return Qt.rgba(1, 0, 0, 0.15)
                        return emergencyArea.containsMouse ? Qt.rgba(1, 0, 0, 0.16) : "#2D1414"
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
                            font.pointSize:     ScreenTools.defaultFontPointSize * 0.7
                            font.bold:          true
                            font.letterSpacing: 0.3
                        }
                    }

                    MouseArea {
                        id: emergencyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            if (!_activeVehicle || !_emergency) return
                            if (_emergencyActive || _emergencySelecting || _emergencyTargetSet) return
                            _emergency.startEmergencySelect()
                        }
                    }
                }
            }

            // ══════════════════════════════════
            // EMERGENCY DEPLOYMENT PANEL
            // ══════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: _pad * 0.6
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

                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.7
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

                    // DEPLOY NOW
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
                                width: ScreenTools.defaultFontPixelHeight * 0.8; height: width
                                source: "/qmlimages/Yield.svg"; color: "white"; fillMode: Image.PreserveAspectFit
                            }
                            QGCLabel {
                                text: "DEPLOY NOW"; color: "white"
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.8
                                font.bold: true; font.letterSpacing: 0.8
                            }
                        }
                        MouseArea { id: deployArea; anchors.fill: parent; hoverEnabled: true
                            onClicked: { if (_emergency) _emergency.deployEmergency() }
                        }
                    }

                    // RETURN HOME
                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                        color:                  rthArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.18) : Qt.rgba(0, 0.749, 1.0, 0.10)
                        border.width: 1; border.color: Qt.rgba(0, 0.749, 1.0, 0.32)
                        visible: _emergencyActive

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: _pad * 0.4
                            QGCColoredImage {
                                width: ScreenTools.defaultFontPixelHeight * 0.8; height: width
                                source: "/qmlimages/Plan.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                            }
                            QGCLabel {
                                text: "RETURN HOME"; color: _teal
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.75
                                font.bold: true; font.letterSpacing: 0.5
                            }
                        }
                        MouseArea { id: rthArea; anchors.fill: parent; hoverEnabled: true
                            onClicked: { if (_emergency) _emergency.returnToHome() }
                        }
                    }

                    // CANCEL
                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                        radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                        color:                  cancelArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : _cardBg
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10)

                        QGCLabel {
                            anchors.centerIn: parent
                            text: "CANCEL"; color: _dimText
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.7
                            font.bold: true; font.letterSpacing: 0.5
                        }
                        MouseArea { id: cancelArea; anchors.fill: parent; hoverEnabled: true
                            onClicked: { if (_emergency) _emergency.cancelEmergency() }
                        }
                    }
                }
            }

            // ── Gap before START PATROL
            Item { Layout.preferredHeight: _sectionGap }

            // ── START PATROL
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
                        width: ScreenTools.defaultFontPixelHeight * 0.85; height: width
                        source: "/qmlimages/PaperPlane.svg"; color: "#000000"; fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        text: "START PATROL"; color: "#000000"
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.8
                        font.bold: true; font.letterSpacing: 0.8
                    }
                }
                MouseArea {
                    id: patrolArea; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (_activeVehicle)
                            _guidedController.confirmAction(_guidedController.actionStartMission)
                    }
                }
            }

            // ── Gap + Separator before LIVE VIDEO
            Item { Layout.preferredHeight: _sectionGap }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Item { Layout.preferredHeight: _sectionGap * 0.5 }

            // ══════════════════════════════════
            // LIVE VIDEO header
            // ══════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing:          _pad * 0.4

                QGCLabel {
                    text:               "LIVE VIDEO"
                    color:              _teal
                    font.pointSize:     ScreenTools.defaultFontPointSize * 0.8
                    font.bold:          true
                    font.letterSpacing: 1.2
                    Layout.fillWidth:   true
                }

                // GRID button
                Rectangle {
                    width:   gridRow.implicitWidth + _pad * 1.4
                    height:  gridRow.implicitHeight + _pad * 0.5
                    radius:  height / 2
                    color:   gridArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : _cardBg
                    border.width: 1
                    border.color: gridArea.containsMouse ? _tealBorder : Qt.rgba(1, 1, 1, 0.12)

                    RowLayout {
                        id: gridRow
                        anchors.centerIn: parent
                        spacing: _pad * 0.3
                        // Grid icon (4-square grid)
                        Grid {
                            columns: 2
                            spacing: ScreenTools.defaultFontPixelHeight * 0.08
                            Layout.alignment: Qt.AlignVCenter

                            Repeater {
                                model: 4
                                Rectangle {
                                    width:  ScreenTools.defaultFontPixelHeight * 0.22
                                    height: width
                                    radius: ScreenTools.defaultFontPixelHeight * 0.03
                                    color:  _teal
                                }
                            }
                        }
                        QGCLabel {
                            text: "GRID"; color: _teal
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.65; font.bold: true
                        }
                    }

                    MouseArea {
                        id: gridArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            mainWindow.showVideoWallView()
                        }
                    }
                }

                // Expand to Video Wall arrow
                Rectangle {
                    width:   ScreenTools.defaultFontPixelHeight * 1.3
                    height:  width
                    radius:  ScreenTools.defaultFontPixelHeight * 0.2
                    color:   expandVideoArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.10) : "transparent"

                    // Diagonal expand arrow (↗)
                    QGCLabel {
                        anchors.centerIn: parent
                        text:             "\u2197"
                        color:            _teal
                        font.pointSize:   ScreenTools.defaultFontPointSize * 0.85
                    }

                    MouseArea {
                        id: expandVideoArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            mainWindow.showVideoWallView()
                        }
                    }
                }
            }

            // ── Gap before video
            Item { Layout.preferredHeight: _sectionGap * 0.5 }

            // ── Video area (fills remaining vertical space)
            Rectangle {
                id: videoArea
                Layout.fillWidth:   true
                Layout.fillHeight:  true
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 6
                radius:             ScreenTools.defaultFontPixelHeight * 0.35
                color:              Qt.rgba(0, 0.05, 0.08, 0.60)
                border.width:       1
                border.color:       Qt.rgba(0, 0.749, 1.0, 0.12)
                clip:               true

                Item {
                    id:             _videoContainer
                    anchors.fill:   parent
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing:          _pad
                    visible:          _videoContainer.children.length <= 0 ||
                                      (!QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.decoding)

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignHCenter
                        width: ScreenTools.defaultFontPixelHeight * 2.8; height: width
                        source: "/qmlimages/CameraIcon.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                        opacity: 0.6
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No active video stream"; color: Qt.rgba(1, 1, 1, 0.55)
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.75
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Select armed drone"; color: Qt.rgba(1, 1, 1, 0.35)
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.65
                    }
                }
            }

            // ── Gap before controls
            Item { Layout.preferredHeight: _sectionGap * 0.5 }

            // ══════════════════════════════════
            // TRACK | RECORD | SNAPSHOT
            // ══════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing:          _pad * 0.5

                // TRACK (placeholder)
                Rectangle {
                    id: trackBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                    color:                  trackArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.10) : Qt.rgba(0, 0.05, 0.08, 0.40)
                    border.width:           1
                    border.color:           trackArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.40) : Qt.rgba(0, 0.749, 1.0, 0.18)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing:          _pad * 0.4

                        QGCColoredImage {
                            width:    ScreenTools.defaultFontPixelHeight * 0.7
                            height:   width
                            source:   "/qmlimages/TrackingIcon.svg"
                            color:    _teal
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text:           "TRACK"
                            color:          _teal
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.65
                            font.bold:      true
                            font.letterSpacing: 0.3
                        }
                    }

                    MouseArea {
                        id: trackArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            // TODO: implement target tracking
                        }
                    }
                }

                // RECORD (toggles video recording)
                Rectangle {
                    id: recordBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                    color: {
                        if (_isRecording) return recordArea.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.30) : Qt.rgba(1, 0.2, 0.2, 0.18)
                        return recordArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.10) : Qt.rgba(0, 0.05, 0.08, 0.40)
                    }
                    border.width: 1
                    border.color: _isRecording ? Qt.rgba(1, 0.2, 0.2, 0.50)
                                               : (recordArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.40) : Qt.rgba(0, 0.749, 1.0, 0.18))

                    property bool _isRecording: QGroundControl.videoManager.recording

                    RowLayout {
                        anchors.centerIn: parent
                        spacing:          _pad * 0.4

                        // Dot indicator
                        Rectangle {
                            width:   ScreenTools.defaultFontPixelHeight * 0.45
                            height:  width
                            radius:  width / 2
                            color:   recordBtn._isRecording ? _errColor : _teal

                            SequentialAnimation on opacity {
                                running: recordBtn._isRecording
                                loops:   Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }
                        QGCLabel {
                            text:           recordBtn._isRecording ? "STOP" : "RECORD"
                            color:          recordBtn._isRecording ? _errColor : _teal
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.65
                            font.bold:      true
                            font.letterSpacing: 0.3
                        }
                    }

                    MouseArea {
                        id: recordArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            if (recordBtn._isRecording) {
                                QGroundControl.videoManager.stopRecording()
                            } else {
                                QGroundControl.videoManager.startRecording()
                            }
                        }
                    }
                }

                // SNAPSHOT (captures video frame as JPG)
                Rectangle {
                    id: snapshotBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                    color:                  snapshotArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.10) : Qt.rgba(0, 0.05, 0.08, 0.40)
                    border.width:           1
                    border.color:           snapshotArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.40) : Qt.rgba(0, 0.749, 1.0, 0.18)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing:          _pad * 0.4

                        QGCColoredImage {
                            width:    ScreenTools.defaultFontPixelHeight * 0.7
                            height:   width
                            source:   "/qmlimages/CameraIcon.svg"
                            color:    _teal
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text:           "SNAPSHOT"
                            color:          _teal
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.65
                            font.bold:      true
                            font.letterSpacing: 0.3
                        }
                    }

                    MouseArea {
                        id: snapshotArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            QGroundControl.videoManager.grabImage()
                        }
                    }
                }
            }

            // Small bottom padding
            Item { Layout.preferredHeight: _pad * 0.3 }
        }
    }
}
