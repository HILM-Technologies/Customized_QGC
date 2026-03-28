/****************************************************************************
 *
 * HILM Ground Control — Right Panel (Quick Actions + Live Video)
 * Collapsible: click arrow to expand/collapse horizontally
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtCore

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Item {
    id: rightPanelRoot

    // Expanded = full panel, Collapsed = just the arrow tab
    property bool expanded: true

    readonly property real _expandedWidth:  ScreenTools.defaultFontPixelWidth * 58
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
    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth * 1.4

    // Action button height — tall enough to match Figma square-ish proportions
    readonly property real _actionBtnHeight: Math.max(ScreenTools.defaultFontPixelHeight * 3.8,
                                                       Math.min(ScreenTools.defaultFontPixelHeight * 4.6,
                                                                rightPanelRoot.height * 0.10))
    readonly property real _sectionGap:      _pad * 1.2

    // ── Multi-selection from fleet panel
    property var selectedVehicles:  []
    property int selectionRevision: 0

    // Returns selected vehicles if any, otherwise the active vehicle as a single-element array
    function targetVehicles() {
        // Read selectionRevision to ensure binding updates
        void selectionRevision
        if (selectedVehicles.length > 0)
            return selectedVehicles
        if (_activeVehicle)
            return [_activeVehicle]
        return []
    }

    property var _activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    property var _guidedController: globals.guidedControllerFlyView
    property var _emergency:        _activeVehicle ? _activeVehicle.emergencyController : null

    // RTSP base URL — shared with VideoWallView
    Settings {
        id: rtspSettings
        category: "SurveillanceRTSP"
        property string baseUrl: "rtsp://127.0.0.1:8554/"
    }

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
            anchors.margins:    _pad * 1.4
            spacing:            0   // We control all spacing via topMargin

            // ══════════════════════════════════
            // QUICK ACTIONS header
            // ══════════════════════════════════
            QGCLabel {
                text:               "QUICK ACTIONS"
                color:              _teal
                font.pointSize:     ScreenTools.defaultFontPointSize * 0.9
                font.bold:          true
                font.letterSpacing: 1.5
                Layout.topMargin:   _pad * 0.4
            }

            // 2x2 Action Grid
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: _pad * 0.8
                columns:          2
                rowSpacing:       _pad * 0.7
                columnSpacing:    _pad * 0.7

                // ── ARM  (green power-button glow)
                Item {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: _actionBtnHeight

                    // outer glow ring
                    Rectangle {
                        anchors.centerIn: parent
                        width:   parent.width  + ScreenTools.defaultFontPixelHeight * 0.9
                        height:  parent.height + ScreenTools.defaultFontPixelHeight * 0.9
                        radius:  ScreenTools.defaultFontPixelHeight * 0.7
                        color:   "transparent"
                        border.width: 2
                        border.color: Qt.rgba(0.30, 0.87, 0.30, 0.18)
                        visible: _activeVehicle ? true : false
                    }
                    // inner glow ring
                    Rectangle {
                        anchors.centerIn: parent
                        width:   parent.width  + ScreenTools.defaultFontPixelHeight * 0.35
                        height:  parent.height + ScreenTools.defaultFontPixelHeight * 0.35
                        radius:  ScreenTools.defaultFontPixelHeight * 0.55
                        color:   "transparent"
                        border.width: 1.5
                        border.color: Qt.rgba(0.30, 0.87, 0.30, 0.35)
                        visible: _activeVehicle ? true : false
                    }

                    Rectangle {
                        id: armBtn
                        anchors.fill: parent
                        radius:       ScreenTools.defaultFontPixelHeight * 0.35
                        color:        armArea.containsMouse ? "#1A3D1A" : "#0D2010"
                        border.width: 1.5
                        border.color: armArea.containsMouse ? "#4CAF50" : "#2E7D32"
                        opacity:      _activeVehicle ? 1.0 : 0.45

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing:          _pad * 0.5

                            QGCColoredImage {
                                Layout.alignment:   Qt.AlignHCenter
                                width:              ScreenTools.defaultFontPixelHeight * 2.0
                                height:             width
                                source:             "/res/power-button.svg"
                                color:              armArea.containsMouse ? "#66BB6A" : "#4CAF50"
                                fillMode:           Image.PreserveAspectFit
                            }
                            QGCLabel {
                                Layout.alignment:   Qt.AlignHCenter
                                text:               "ARM"
                                color:              armArea.containsMouse ? "#66BB6A" : "#4CAF50"
                                font.pointSize:     ScreenTools.defaultFontPointSize * 0.85
                                font.bold:          true
                                font.letterSpacing: 0.8
                            }
                        }

                        MouseArea {
                            id: armArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                var targets = targetVehicles()
                                for (var i = 0; i < targets.length; i++)
                                    targets[i].armed = true
                            }
                        }
                    }
                }

                // ── DISARM  (neutral power-button)
                Item {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: _actionBtnHeight

                    Rectangle {
                        id: disarmBtn
                        anchors.fill: parent
                        radius:       ScreenTools.defaultFontPixelHeight * 0.35
                        color:        disarmArea.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: disarmArea.containsMouse ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.14)
                        opacity:      _activeVehicle ? 1.0 : 0.45

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing:          _pad * 0.5

                            QGCColoredImage {
                                Layout.alignment:   Qt.AlignHCenter
                                width:              ScreenTools.defaultFontPixelHeight * 2.0
                                height:             width
                                source:             "/res/power-button.svg"
                                color:              disarmArea.containsMouse ? Qt.rgba(1,1,1,0.95) : Qt.rgba(1,1,1,0.70)
                                fillMode:           Image.PreserveAspectFit
                            }
                            QGCLabel {
                                Layout.alignment:   Qt.AlignHCenter
                                text:               "DISARM"
                                color:              disarmArea.containsMouse ? Qt.rgba(1,1,1,0.95) : Qt.rgba(1,1,1,0.70)
                                font.pointSize:     ScreenTools.defaultFontPointSize * 0.85
                                font.bold:          true
                                font.letterSpacing: 0.8
                            }
                        }

                        MouseArea {
                            id: disarmArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                var targets = targetVehicles()
                                for (var i = 0; i < targets.length; i++)
                                    targets[i].armed = false
                            }
                        }
                    }
                }

                // ── RTL  (home icon, teal accent on hover)
                Item {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: _actionBtnHeight

                    Rectangle {
                        id: rtlBtn
                        anchors.fill: parent
                        radius:       ScreenTools.defaultFontPixelHeight * 0.35
                        color:        rtlArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: rtlArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.55) : Qt.rgba(1, 1, 1, 0.14)
                        opacity:      _activeVehicle ? 1.0 : 0.45

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing:          _pad * 0.5

                            QGCColoredImage {
                                Layout.alignment:   Qt.AlignHCenter
                                width:              ScreenTools.defaultFontPixelHeight * 2.0
                                height:             width
                                source:             "/InstrumentValueIcons/home.svg"
                                color:              rtlArea.containsMouse ? _teal : Qt.rgba(1,1,1,0.80)
                                fillMode:           Image.PreserveAspectFit
                            }
                            QGCLabel {
                                Layout.alignment:   Qt.AlignHCenter
                                text:               "RTL"
                                color:              rtlArea.containsMouse ? _teal : Qt.rgba(1,1,1,0.80)
                                font.pointSize:     ScreenTools.defaultFontPointSize * 0.85
                                font.bold:          true
                                font.letterSpacing: 0.8
                            }
                        }

                        MouseArea {
                            id: rtlArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                var targets = targetVehicles()
                                for (var i = 0; i < targets.length; i++)
                                    targets[i].guidedModeRTL(false)
                            }
                        }
                    }
                }

                // ── EMERGENCY  (pulsing red glow)
                Item {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: _actionBtnHeight

                    property real _glowPulse: 0.0

                    SequentialAnimation on _glowPulse {
                        running: true
                        loops:   Animation.Infinite
                        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.0; duration: 900; easing.type: Easing.InOutSine }
                    }

                    // outer glow ring (pulsing)
                    Rectangle {
                        anchors.centerIn: parent
                        width:   parent.width  + ScreenTools.defaultFontPixelHeight * 1.0
                        height:  parent.height + ScreenTools.defaultFontPixelHeight * 1.0
                        radius:  ScreenTools.defaultFontPixelHeight * 0.7
                        color:   "transparent"
                        border.width: 2
                        border.color: Qt.rgba(1, 0.15, 0.15, parent._glowPulse * 0.22)
                    }
                    // inner glow ring (pulsing)
                    Rectangle {
                        anchors.centerIn: parent
                        width:   parent.width  + ScreenTools.defaultFontPixelHeight * 0.4
                        height:  parent.height + ScreenTools.defaultFontPixelHeight * 0.4
                        radius:  ScreenTools.defaultFontPixelHeight * 0.55
                        color:   "transparent"
                        border.width: 1.5
                        border.color: Qt.rgba(1, 0.15, 0.15, 0.22 + parent._glowPulse * 0.32)
                    }

                    Rectangle {
                        id: emergencyBtn
                        anchors.fill: parent
                        radius:       ScreenTools.defaultFontPixelHeight * 0.35
                        border.width: 1.5
                        border.color: emergencyArea.containsMouse ? Qt.lighter(_errColor, 1.2) : _errColor
                        opacity:      _activeVehicle ? 1.0 : 0.45

                        color: {
                            if (_emergencyActive)    return Qt.rgba(1, 0, 0, 0.28)
                            if (_emergencySelecting) return Qt.rgba(1, 0.6, 0, 0.18)
                            if (_emergencyTargetSet) return Qt.rgba(1, 0, 0, 0.18)
                            return emergencyArea.containsMouse ? Qt.rgba(1, 0, 0, 0.18) : "#1A0808"
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing:          _pad * 0.5

                            QGCColoredImage {
                                Layout.alignment:   Qt.AlignHCenter
                                width:              ScreenTools.defaultFontPixelHeight * 2.0
                                height:             width
                                source:             "/InstrumentValueIcons/exclamation-outline.svg"
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
                                font.pointSize:     ScreenTools.defaultFontPointSize * 0.85
                                font.bold:          true
                                font.letterSpacing: 0.8
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

                // ── TAKEOFF  (full-width, teal accent — active when armed & on ground)
                Item {
                    Layout.fillWidth:       true
                    Layout.columnSpan:      2
                    Layout.preferredHeight: _actionBtnHeight

                    property bool _canTakeoff: {
                        var targets = targetVehicles()
                        for (var i = 0; i < targets.length; i++) {
                            if (targets[i].armed && !targets[i].flying)
                                return true
                        }
                        return false
                    }

                    Rectangle {
                        id: takeoffBtn
                        anchors.fill: parent
                        radius:       ScreenTools.defaultFontPixelHeight * 0.35
                        color:        takeoffArea.containsMouse && parent._canTakeoff
                                        ? Qt.rgba(0, 0.749, 1.0, 0.20)
                                        : Qt.rgba(0, 0.749, 1.0, 0.07)
                        border.width: 1.5
                        border.color: parent._canTakeoff
                                        ? (takeoffArea.containsMouse ? _teal : Qt.rgba(0, 0.749, 1.0, 0.55))
                                        : Qt.rgba(1, 1, 1, 0.12)
                        opacity:      _activeVehicle ? 1.0 : 0.45

                        RowLayout {
                            anchors.centerIn: parent
                            spacing:          _pad * 0.7

                            QGCColoredImage {
                                width:    ScreenTools.defaultFontPixelHeight * 1.6
                                height:   width
                                source:   "/qmlimages/takeoff.svg"
                                color:    parent.parent.parent._canTakeoff
                                            ? (takeoffArea.containsMouse ? Qt.lighter(_teal, 1.15) : _teal)
                                            : Qt.rgba(1, 1, 1, 0.35)
                                fillMode: Image.PreserveAspectFit
                            }
                            QGCLabel {
                                text:               "TAKEOFF"
                                color:              parent.parent.parent._canTakeoff
                                                        ? (takeoffArea.containsMouse ? Qt.lighter(_teal, 1.15) : _teal)
                                                        : Qt.rgba(1, 1, 1, 0.35)
                                font.pointSize:     ScreenTools.defaultFontPointSize * 0.85
                                font.bold:          true
                                font.letterSpacing: 0.8
                            }
                        }

                        MouseArea {
                            id:          takeoffArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            enabled:      takeoffBtn.parent._canTakeoff
                            onClicked: {
                                var targets = targetVehicles()
                                for (var i = 0; i < targets.length; i++) {
                                    if (targets[i].armed && !targets[i].flying) {
                                        QGroundControl.multiVehicleManager.activeVehicle = targets[i]
                                        _guidedController.confirmAction(_guidedController.actionTakeoff)
                                    }
                                }
                            }
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
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.2
                radius:                 ScreenTools.defaultFontPixelHeight * 0.4
                color:                  patrolArea.containsMouse ? Qt.lighter(_teal, 1.12) : _teal
                visible:                !_emergencyEngaged

                RowLayout {
                    anchors.centerIn: parent
                    spacing:          _pad * 0.7
                    QGCColoredImage {
                        width: ScreenTools.defaultFontPixelHeight * 1.1; height: width
                        source: "/qmlimages/PaperPlane.svg"; color: "#000000"; fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        text: "START PATROL"; color: "#000000"
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                        font.bold: true; font.letterSpacing: 1.0
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
                color: Qt.rgba(1, 1, 1, 0.10)
            }

            Item { Layout.preferredHeight: _sectionGap * 0.7 }

            // ══════════════════════════════════
            // LIVE VIDEO header
            // ══════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing:          _pad * 0.5

                QGCLabel {
                    text:               "LIVE VIDEO"
                    color:              _teal
                    font.pointSize:     ScreenTools.defaultFontPointSize * 0.9
                    font.bold:          true
                    font.letterSpacing: 1.5
                    Layout.fillWidth:   true
                }

                // GRID button
                Rectangle {
                    width:   gridRow.implicitWidth + _pad * 1.8
                    height:  gridRow.implicitHeight + _pad * 0.8
                    radius:  height / 2
                    color:   gridArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : _cardBg
                    border.width: 1
                    border.color: gridArea.containsMouse ? _tealBorder : Qt.rgba(1, 1, 1, 0.15)

                    RowLayout {
                        id: gridRow
                        anchors.centerIn: parent
                        spacing: _pad * 0.5
                        // Grid icon (4-square grid)
                        Grid {
                            columns: 2
                            spacing: ScreenTools.defaultFontPixelHeight * 0.12
                            Layout.alignment: Qt.AlignVCenter

                            Repeater {
                                model: 4
                                Rectangle {
                                    width:  ScreenTools.defaultFontPixelHeight * 0.28
                                    height: width
                                    radius: ScreenTools.defaultFontPixelHeight * 0.04
                                    color:  _teal
                                }
                            }
                        }
                        QGCLabel {
                            text: "GRID"; color: _teal
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.75; font.bold: true
                            font.letterSpacing: 0.5
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
                    width:   ScreenTools.defaultFontPixelHeight * 1.6
                    height:  width
                    radius:  ScreenTools.defaultFontPixelHeight * 0.25
                    color:   expandVideoArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.12) : "transparent"

                    // Diagonal expand arrow (↗)
                    QGCLabel {
                        anchors.centerIn: parent
                        text:             "\u2197"
                        color:            _teal
                        font.pointSize:   ScreenTools.defaultFontPointSize * 1.0
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
            Item { Layout.preferredHeight: _sectionGap * 0.6 }

            // ── Video area (fills remaining vertical space)
            Rectangle {
                id: videoArea
                Layout.fillWidth:   true
                Layout.fillHeight:  true
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 8
                radius:             ScreenTools.defaultFontPixelHeight * 0.5
                color:              Qt.rgba(0, 0.04, 0.07, 0.70)
                border.width:       1
                border.color:       Qt.rgba(0, 0.749, 1.0, 0.18)
                clip:               true

                // Hidden container kept for backward compat (PipView parenting)
                Item {
                    id:             _videoContainer
                    anchors.fill:   parent
                    visible:        false
                }

                // ── Persistent video sink (never destroyed, just swaps streams) ──
                property string opsStreamId:   ""
                property string opsStreamName: ""
                property bool   opsConnected:  false

                Rectangle {
                    id: opsVideoSinkRect
                    anchors.fill: parent
                    anchors.margins: 2
                    color: "black"
                    radius: ScreenTools.defaultFontPixelHeight * 0.4
                    clip: true
                    visible: videoArea.opsStreamId !== ""

                    QGCVideoBackground {
                        id: opsVideoWidget
                        anchors.fill: parent
                    }
                }

                // Connection status listener
                Connections {
                    target: QGroundControl.videoManager
                    function onCustomStreamStreamingChanged(name, active) {
                        if (name === videoArea.opsStreamId) {
                            videoArea.opsConnected = active
                        }
                    }
                }

                // Header overlay
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.3
                    height: ScreenTools.defaultFontPixelHeight * 1.8
                    radius: ScreenTools.defaultFontPixelHeight * 0.3
                    color: "#cc000000"
                    visible: videoArea.opsStreamId !== ""

                    Row {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.3
                        spacing: ScreenTools.defaultFontPixelHeight * 0.3

                        Rectangle {
                            width: ScreenTools.defaultFontPixelHeight * 0.45
                            height: width
                            radius: width / 2
                            color: videoArea.opsConnected ? "#4CAF50" : "#FF5252"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        QGCLabel {
                            text: videoArea.opsStreamName
                            color: "white"
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Phase 2: create new stream (after old one is removed)
                Timer {
                    id: opsCreateTimer
                    interval: 500
                    repeat: false
                    property int    pendingId:   -1
                    property string pendingUrl:  ""
                    property string pendingName: ""

                    onTriggered: {
                        if (pendingId < 0) return
                        var sid = "ops_vehicle_" + pendingId
                        console.log("OPS Video: creating stream", sid, "URL:", pendingUrl)
                        videoArea.opsStreamId   = sid
                        videoArea.opsStreamName = pendingName
                        videoArea.opsConnected  = false
                        QGroundControl.videoManager.addCustomStream(sid, pendingUrl)
                        QGroundControl.videoManager.setCustomStreamWidget(sid, opsVideoWidget)
                        videoArea.opsConnected = QGroundControl.videoManager.isCustomStreamStreaming(sid)
                    }
                }

                // Watch active vehicle — only create stream when user clicks GRID button
                // (not auto-created on vehicle connect, to avoid GStreamer crash when no RTSP server)
                property int opsCurrentVehicleId: _activeVehicle ? _activeVehicle.id : -1
                property bool opsVideoRequested: false  // set true when user explicitly requests video

                onOpsCurrentVehicleIdChanged: {
                    console.log("OPS Video: vehicle changed to", opsCurrentVehicleId)

                    // Remove old stream (if any)
                    if (videoArea.opsStreamId !== "") {
                        console.log("OPS Video: removing old stream", videoArea.opsStreamId)
                        QGroundControl.videoManager.removeCustomStream(videoArea.opsStreamId)
                        videoArea.opsStreamId  = ""
                        videoArea.opsConnected = false
                    }

                    // Only create new stream if video was explicitly requested
                    if (opsCurrentVehicleId > 0 && opsVideoRequested) {
                        opsCreateTimer.pendingId   = opsCurrentVehicleId
                        opsCreateTimer.pendingUrl  = rtspSettings.baseUrl + opsCurrentVehicleId
                        opsCreateTimer.pendingName = "Drone " + opsCurrentVehicleId
                        opsCreateTimer.restart()
                    }
                }

                function startVideoForCurrentVehicle() {
                    if (opsCurrentVehicleId <= 0) return
                    opsVideoRequested = true
                    opsCreateTimer.pendingId   = opsCurrentVehicleId
                    opsCreateTimer.pendingUrl  = rtspSettings.baseUrl + opsCurrentVehicleId
                    opsCreateTimer.pendingName = "Drone " + opsCurrentVehicleId
                    opsCreateTimer.restart()
                }

                // No stream overlay
                Rectangle {
                    anchors.fill: parent
                    color: "#0D1117"
                    radius: ScreenTools.defaultFontPixelHeight * 0.4
                    visible: videoArea.opsStreamId !== "" && !videoArea.opsConnected

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: _pad * 0.8

                        QGCColoredImage {
                            Layout.alignment: Qt.AlignHCenter
                            width: ScreenTools.defaultFontPixelHeight * 2.5; height: width
                            source: "/qmlimages/CameraIcon.svg"; color: Qt.rgba(0, 0.749, 1.0, 0.65)
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Connecting..."; color: Qt.rgba(1, 1, 1, 0.55)
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.8
                        }
                    }
                }

                // Placeholder when no video stream active
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing:          _pad * 1.2
                    visible:          videoArea.opsStreamId === ""

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignHCenter
                        width: ScreenTools.defaultFontPixelHeight * 3.4; height: width
                        source: "/qmlimages/CameraIcon.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                        opacity: 0.55
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No active video stream"; color: Qt.rgba(1, 1, 1, 0.55)
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.82
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: _activeVehicle ? "Tap to connect video feed" : "Select armed drone"
                        color: Qt.rgba(1, 1, 1, 0.32)
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.72
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  _activeVehicle ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (_activeVehicle) {
                                videoArea.startVideoForCurrentVehicle()
                            }
                        }
                    }
                }
            }

            // ── Gap before controls
            Item { Layout.preferredHeight: _sectionGap * 0.6 }

            // ══════════════════════════════════
            // TRACK | RECORD | SNAPSHOT
            // ══════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing:          _pad * 0.7

                // TRACK (placeholder)
                Rectangle {
                    id: trackBtn
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.8
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.4
                    color:                  trackArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.10) : Qt.rgba(0, 0.05, 0.08, 0.50)
                    border.width:           1
                    border.color:           trackArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.45) : Qt.rgba(0, 0.749, 1.0, 0.22)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing:          _pad * 0.5

                        QGCColoredImage {
                            width:    ScreenTools.defaultFontPixelHeight * 0.95
                            height:   width
                            source:   "/qmlimages/TrackingIcon.svg"
                            color:    _teal
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text:           "TRACK"
                            color:          _teal
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.75
                            font.bold:      true
                            font.letterSpacing: 0.5
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
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.8
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.4
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
                        spacing:          _pad * 0.5

                        // Dot indicator
                        Rectangle {
                            width:   ScreenTools.defaultFontPixelHeight * 0.58
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
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.75
                            font.bold:      true
                            font.letterSpacing: 0.5
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
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.8
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.4
                    color:                  snapshotArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.10) : Qt.rgba(0, 0.05, 0.08, 0.50)
                    border.width:           1
                    border.color:           snapshotArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.45) : Qt.rgba(0, 0.749, 1.0, 0.22)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing:          _pad * 0.5

                        QGCColoredImage {
                            width:    ScreenTools.defaultFontPixelHeight * 0.95
                            height:   width
                            source:   "/qmlimages/CameraIcon.svg"
                            color:    _teal
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text:           "SNAPSHOT"
                            color:          _teal
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.75
                            font.bold:      true
                            font.letterSpacing: 0.5
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
            Item { Layout.preferredHeight: _pad * 0.8 }
        }
    }
}
