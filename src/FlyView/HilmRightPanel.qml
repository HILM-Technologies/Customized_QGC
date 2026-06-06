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
    // drone the panel (telemetry + altitude field) reflects: first selected, else active
    property var _repVehicle: {
        void selectionRevision
        var t = targetVehicles()
        return (t && t.length > 0) ? t[0] : _activeVehicle
    }
    property var _guidedController: globals.guidedControllerFlyView
    property var _emergency:        _activeVehicle ? _activeVehicle.emergencyController : null

    // Video settings — shared with VideoWallView
    property var _videoSettings: QGroundControl.settingsManager.videoSettings

    // Derive the base URL from the active video source setting
    property string _activeBaseUrl: {
        var src = _videoSettings.videoSource.rawValue
        if (src === _videoSettings.rtspVideoSource)
            return _videoSettings.rtspUrl.rawValue
        if (src === _videoSettings.udp264VideoSource || src === _videoSettings.udp265VideoSource || src === _videoSettings.mpegtsVideoSource)
            return _videoSettings.udpUrl.rawValue
        if (src === _videoSettings.tcpVideoSource)
            return _videoSettings.tcpUrl.rawValue
        return ""
    }

    // Build a full stream URL for a given vehicle ID
    function _streamUrl(vehicleId) {
        if (_activeBaseUrl === "") return ""
        var base = _activeBaseUrl
        var src = _videoSettings.videoSource.rawValue
        if (src === _videoSettings.rtspVideoSource) {
            if (base.charAt(base.length - 1) !== '/') base += '/'
            return base + vehicleId
        }
        // UDP/TCP/MPEG-TS: port-based — increment port per vehicle
        var colonIdx = base.lastIndexOf(':')
        if (colonIdx >= 0) {
            var host = base.substring(0, colonIdx)
            var port = parseInt(base.substring(colonIdx + 1))
            if (!isNaN(port)) {
                var scheme = ""
                if (src === _videoSettings.udp264VideoSource)    scheme = "udp://"
                else if (src === _videoSettings.udp265VideoSource) scheme = "udp265://"
                else if (src === _videoSettings.tcpVideoSource)    scheme = "tcp://"
                else if (src === _videoSettings.mpegtsVideoSource) scheme = "mpegts://"
                return scheme + host + ":" + (port + vehicleId)
            }
        }
        return ""
    }

    // Emergency state helpers
    property bool _emergencySelecting:  _emergency ? _emergency.selectingTarget : false
    property bool _emergencyTargetSet:  _emergency ? _emergency.targetSelected  : false
    property bool _emergencyActive:     _emergency ? _emergency.emergencyActive : false
    property bool _emergencyEngaged:    _emergencySelecting || _emergencyTargetSet || _emergencyActive

    // ══════════════════════════════════════════════
    // Flight-mode classification + Quick Actions gating
    //
    // Each Quick Action button is enabled per the action/mode matrix
    // (Manual/Altitude/Stabilized/Acro/Position/Hold/Mission/Takeoff/
    // Land/Safe Recovery/Precision Landing/Follow Target/VTOL Takeoff/
    // Offboard).
    //
    // PX4 and ArduPilot expose different mode strings via Vehicle.flightMode
    // (see src/FirmwarePlugin/*). We deny-list autonomous / returning /
    // externally-controlled modes; anything else is treated as a manual-
    // control mode, so unknown pilot-stick modes from any firmware still
    // enable TAKEOFF / START MISSION.
    // ══════════════════════════════════════════════
    property string _currentMode: _activeVehicle ? _activeVehicle.flightMode : ""
    property bool   _armed:       _activeVehicle ? _activeVehicle.armed     : false
    property bool   _flying:      _activeVehicle ? _activeVehicle.flying    : false

    // Mode strings are the values that Vehicle.flightMode returns. They are
    // defined per firmware in src/FirmwarePlugin/* — strings differ across
    // PX4 / ArduCopter / ArduPlane / ArduSub / ArduRover.
    //
    // Gating uses a DENY list rather than an allow list so unfamiliar
    // pilot-control modes from any firmware default to "manual" and don't
    // accidentally lock the user out. Anything in `_autoModeNames`,
    // `_rtlModeNames`, or `_externalModeNames` is treated as non-manual.

    // Auto / autonomous / special-purpose modes — vehicle is doing
    // something on its own, so manual takeoff / start-mission don't apply.
    readonly property var _autoModeNames: [
        "Acro",
        // Mission / auto-flight
        "Mission", "Auto",
        // Auto takeoff
        "Takeoff", "VTOL Takeoff", "QTakeoff", "QuadPlane Takeoff",
        // Auto land / precision land
        "Land", "Precision Land", "QLand", "QuadPlane Land",
        "Loiter to QLand", "Autoland",
        // Follow
        "Follow Me", "Follow",
        // Other ArduPilot special-purpose
        "Circle", "Brake", "Throw", "Flip", "Autotune", "AutoTune",
        "Avoid ADSB", "ZigZag", "SystemID", "AutoRotate", "Turtle",
        "Thermal", "Learning", "Dock",
        // Not-ready states
        "Initializing", "Ready", "Unknown"
    ]

    // Returning-to-home modes — RTL is disabled here ("already returning").
    readonly property var _rtlModeNames: [
        "Return", "Return to Groundstation",
        "RTL", "Smart RTL", "AutoRTL", "QuadPlane RTL",
        "Safe Recovery"
    ]

    // External-control modes (PX4 Offboard / ArduPilot Guided). Pilot does
    // not have stick control; takeoff is disabled, but START MISSION is
    // allowed (e.g. after a QGC-issued takeoff in ArduPilot Guided, the
    // natural next step is to transition to Auto).
    readonly property var _externalModeNames: [
        "Offboard",
        "Guided", "Guided No GPS", "GuidedNoGPS"
    ]

    // PX4 chains the auto Takeoff mode straight into a mission, so START
    // MISSION is allowed there too (per the action-mode table).
    readonly property var _takeoffOrGuidedNames: [
        "Takeoff",
        "Guided", "Guided No GPS", "GuidedNoGPS"
    ]

    // Case-insensitive lookup — ArduPilot SITL has been observed reporting
    // mode strings in UPPERCASE (e.g. "STABILIZE", "GUIDED") through some
    // telemetry paths, even though the firmware-plugin tables use mixed
    // case ("Stabilize", "Guided"). Compare normalized to avoid mismatches.
    function _modeMatches(list, modeStr) {
        if (!modeStr) return false
        var m = modeStr.toUpperCase()
        for (var i = 0; i < list.length; i++) {
            if (list[i].toUpperCase() === m) return true
        }
        return false
    }
    // manual-control mode for a specific vehicle (not just the active one)
    function _isManualVehicle(v) {
        if (!v) return false
        var m = v.flightMode
        return !_modeMatches(_autoModeNames, m) && !_modeMatches(_rtlModeNames, m) && !_modeMatches(_externalModeNames, m)
    }
    // Armable mode to switch into when a drone can't be armed in its current mode (e.g. Land)
    function _safeArmMode(v) {
        if (v && v.apmFirmware) return "Guided"   // ArduPilot
        return "Position"                         // PX4 (and default)
    }
    property bool _isAutoMode:        _modeMatches(_autoModeNames,        _currentMode)
    property bool _isRtlMode:         _modeMatches(_rtlModeNames,         _currentMode)
    property bool _isExternalMode:    _modeMatches(_externalModeNames,    _currentMode)
    property bool _isTakeoffOrGuided: _modeMatches(_takeoffOrGuidedNames, _currentMode)
    // Manual-control mode = anything that isn't autonomous, returning, or
    // externally controlled. Robust to unknown / new firmware mode strings.
    property bool _isManualMode:      !!_activeVehicle &&
                                      !_isAutoMode && !_isRtlMode && !_isExternalMode

    // Per the action-mode table:
    //   ARM           — only on ground while disarmed
    //   DISARM        — only on ground while armed
    //   RTL           — only while flying and not already returning
    //   TAKEOFF       — armed on ground in a manual-control mode
    //   START MISSION — armed on ground in a manual mode, or while in PX4
    //                   "Takeoff" / ArduPilot "Guided" (chain into Auto)
    // ARM/DISARM/RTL gate on every target drone (selection is same-state)
    property bool _canArm: {
        void selectionRevision
        var t = targetVehicles(); if (!t.length) return false
        for (var i = 0; i < t.length; i++) if (t[i].armed || t[i].flying) return false
        return true
    }
    property bool _canDisarm: {
        void selectionRevision
        var t = targetVehicles(); if (!t.length) return false
        for (var i = 0; i < t.length; i++) if (!t[i].armed || t[i].flying) return false
        return true
    }
    property bool _canRtl: {
        void selectionRevision
        var t = targetVehicles(); if (!t.length) return false
        for (var i = 0; i < t.length; i++) if (!t[i].flying || _modeMatches(_rtlModeNames, t[i].flightMode)) return false
        return true
    }
    property bool _canStartMission: !!_activeVehicle &&  _armed && (
                                        (!_flying && _isManualMode) ||
                                        _isTakeoffOrGuided
                                    )

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
        color:          Qt.rgba(0.04, 0.05, 0.07, 0.94)
        border.width:   1
        border.color:   Qt.rgba(1, 1, 1, 0.06)
        clip:           true
        visible:        expanded
        opacity:        expanded ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // Scrollable column: FLIGHT CONTROLS → telemetry → LIVE VIDEO → GIMBAL.
        Flickable {
            id: panelFlick
            anchors.fill:       parent
            anchors.margins:    _pad * 1.4
            clip:               true
            contentWidth:       width
            contentHeight:      panelColumn.implicitHeight
            boundsBehavior:     Flickable.StopAtBounds
            interactive:        contentHeight > height

            ScrollBar.vertical: ScrollBar {
                id: panelScrollBar
                policy:        contentHeight > parent.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                width:         ScreenTools.defaultFontPixelWidth * 0.7

                contentItem: Rectangle {
                    implicitWidth: ScreenTools.defaultFontPixelWidth * 0.4
                    radius:        width / 2
                    color:         panelScrollBar.pressed ? "#00BFFF" : Qt.rgba(0, 0.749, 1.0, 0.40)
                }
                background: Rectangle {
                    implicitWidth: ScreenTools.defaultFontPixelWidth * 0.7
                    color:         Qt.rgba(1, 1, 1, 0.04)
                    radius:        width / 2
                }
            }

        ColumnLayout {
            id: panelColumn
            width:              parent.width
            spacing:            0   // We control all spacing via topMargin

            // ── FLIGHT CONTROLS header (title + status pill)
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: _pad * 0.4
                spacing: _pad * 0.5

                QGCLabel {
                    text:               "FLIGHT CONTROLS"
                    color:              _teal
                    font.pointSize:     ScreenTools.defaultFontPointSize * 0.9
                    font.bold:          true
                    font.letterSpacing: 1.5
                    Layout.fillWidth:   true
                    elide:              Text.ElideRight
                }

                // Status pill — uses Layout.preferredWidth so RowLayout honours sizing.
                Rectangle {
                    id: statusPill
                    Layout.alignment:       Qt.AlignVCenter
                    Layout.preferredWidth:  statusLabel.implicitWidth + _pad * 1.4
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    radius:                 Layout.preferredHeight / 2

                    property string statusText: {
                        if (!_activeVehicle)          return "OFFLINE"
                        if (_flying && _isRtlMode)    return "RETURNING"
                        if (_flying)                  return _isManualMode ? "FLYING" : "MISSION"
                        if (_armed)                   return "ARMED"
                        return "IDLE"
                    }

                    color: {
                        switch (statusPill.statusText) {
                        case "FLYING":
                        case "HOVERING":
                        case "MISSION":     return Qt.rgba(0, 0.749, 1.0, 0.18)
                        case "RETURNING":   return Qt.rgba(1, 0.596, 0, 0.18)
                        case "ARMED":       return Qt.rgba(0.298, 0.686, 0.314, 0.18)
                        default:            return Qt.rgba(1, 1, 1, 0.06)
                        }
                    }
                    border.width: 1
                    border.color: {
                        switch (statusPill.statusText) {
                        case "FLYING":
                        case "HOVERING":
                        case "MISSION":     return _tealBorder
                        case "RETURNING":   return Qt.rgba(1, 0.596, 0, 0.40)
                        case "ARMED":       return Qt.rgba(0.298, 0.686, 0.314, 0.40)
                        default:            return Qt.rgba(1, 1, 1, 0.15)
                        }
                    }

                    QGCLabel {
                        id: statusLabel
                        anchors.centerIn: parent
                        text: statusPill.statusText
                        color: {
                            switch (statusPill.statusText) {
                            case "FLYING":
                            case "HOVERING":
                            case "MISSION":     return _teal
                            case "RETURNING":   return "#FFB74D"
                            case "ARMED":       return "#81C784"
                            default:            return _dimText
                            }
                        }
                        font.pointSize:     ScreenTools.defaultFontPointSize * 0.65
                        font.bold:          true
                        font.letterSpacing: 0.8
                    }
                }
            }

            // ── PLAN MISSION — switches to Missions tab
            Rectangle {
                Layout.fillWidth:       true
                Layout.topMargin:       _pad * 0.8
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.6
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  planMissionArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.14)
                                                                       : Qt.rgba(0, 0.749, 1.0, 0.06)
                border.width: 1
                border.color: planMissionArea.containsMouse ? _teal : _tealBorder
                opacity:      _activeVehicle ? 1.0 : 0.55

                RowLayout {
                    anchors.centerIn: parent
                    spacing: _pad * 0.6

                    QGCColoredImage {
                        width:    ScreenTools.defaultFontPixelHeight * 1.1
                        height:   width
                        source:   "/qmlimages/PaperPlane.svg"
                        color:    _teal
                        fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        text:               "PLAN MISSION"
                        color:              _teal
                        font.pointSize:     ScreenTools.defaultFontPointSize * 0.85
                        font.bold:          true
                        font.letterSpacing: 0.8
                    }
                }

                MouseArea {
                    id: planMissionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  _activeVehicle ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled:      !!_activeVehicle
                    onClicked: {
                        if (!_activeVehicle) return
                        // Make sure the active vehicle is set, then navigate
                        QGroundControl.multiVehicleManager.activeVehicle = _activeVehicle
                        mainWindow.showPlanView()
                    }
                }
            }

            // ── ARM | DISARM
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: _pad * 0.6
                spacing:          _pad * 0.6

                // ARM
                Rectangle {
                    id: armBtn
                    property var    _armDeferred: []
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.0
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                    color:                  armArea.containsMouse && _canArm
                                                ? "#1A3D1A"
                                                : (_canArm ? "#0D2010" : "#101010")
                    border.width: 1.5
                    border.color: _canArm
                                    ? (armArea.containsMouse ? "#4CAF50" : "#2E7D32")
                                    : Qt.rgba(1, 1, 1, 0.10)
                    opacity:      _canArm ? 1.0 : 0.55

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: _pad * 0.3

                        QGCColoredImage {
                            Layout.alignment: Qt.AlignHCenter
                            width:    ScreenTools.defaultFontPixelHeight * 1.4
                            height:   width
                            source:   "/res/power-button.svg"
                            color:    _canArm ? "#4CAF50" : Qt.rgba(1, 1, 1, 0.35)
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            Layout.alignment:   Qt.AlignHCenter
                            text:               "ARM"
                            color:              _canArm ? "#4CAF50" : Qt.rgba(1, 1, 1, 0.35)
                            font.pointSize:     ScreenTools.defaultFontPointSize * 0.78
                            font.bold:          true
                            font.letterSpacing: 0.8
                        }
                    }

                    MouseArea {
                        id: armArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  _canArm ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled:      _canArm
                        onClicked: {
                            // ARM command itself is unchanged. If a drone is in a non-armable
                            // mode (e.g. Land), switch it to an armable mode first, then arm.
                            var targets = targetVehicles()
                            var deferred = []
                            for (var i = 0; i < targets.length; i++) {
                                var v = targets[i]
                                if (!v) continue
                                if (_isManualVehicle(v)) {
                                    v.armed = true
                                } else {
                                    v.flightMode = _safeArmMode(v)   // PX4: Position, ArduPilot: Guided
                                    deferred.push(v)
                                }
                            }
                            if (deferred.length > 0) {
                                armBtn._armDeferred = deferred
                                armRetryTimer.restart()
                            }
                        }
                    }

                    // Arm the deferred drones once the mode switch has taken effect
                    Timer {
                        id: armRetryTimer
                        interval: 900
                        repeat: false
                        onTriggered: {
                            for (var i = 0; i < armBtn._armDeferred.length; i++) {
                                if (armBtn._armDeferred[i]) armBtn._armDeferred[i].armed = true
                            }
                            armBtn._armDeferred = []
                        }
                    }
                }

                // DISARM
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.0
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                    color:                  disarmArea.containsMouse && _canDisarm
                                                ? Qt.rgba(1, 1, 1, 0.09)
                                                : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: _canDisarm
                                    ? (disarmArea.containsMouse ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.20))
                                    : Qt.rgba(1, 1, 1, 0.10)
                    opacity:      _canDisarm ? 1.0 : 0.55

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: _pad * 0.3

                        QGCColoredImage {
                            Layout.alignment: Qt.AlignHCenter
                            width:    ScreenTools.defaultFontPixelHeight * 1.4
                            height:   width
                            source:   "/res/power-button.svg"
                            color:    _canDisarm ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.30)
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            Layout.alignment:   Qt.AlignHCenter
                            text:               "DISARM"
                            color:              _canDisarm ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.30)
                            font.pointSize:     ScreenTools.defaultFontPointSize * 0.78
                            font.bold:          true
                            font.letterSpacing: 0.8
                        }
                    }

                    MouseArea {
                        id: disarmArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  _canDisarm ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled:      _canDisarm
                        onClicked: {
                            var targets = targetVehicles()
                            for (var i = 0; i < targets.length; i++) targets[i].armed = false
                        }
                    }
                }
            }

            // ── Altitude + TAKEOFF (default = minimumTakeoffAltitudeMeters, user-editable)
            RowLayout {
                id: takeoffRow
                Layout.fillWidth: true
                Layout.topMargin: _pad * 0.6
                spacing:          _pad * 0.6

                // Default altitude seeded from the vehicle's minimum takeoff
                // altitude (or 30m fallback). The user can override by editing
                // the text field below.
                property real _defaultTakeoffAlt: {
                    if (_activeVehicle && _activeVehicle.minimumTakeoffAltitudeMeters)
                        return _activeVehicle.minimumTakeoffAltitudeMeters()
                    return 30.0
                }

                // ground takeoff: every target armed, on ground, manual mode
                property bool _canGroundTakeoff: {
                    void selectionRevision
                    var targets = targetVehicles(); if (!targets.length) return false
                    for (var i = 0; i < targets.length; i++) {
                        if (!targets[i].armed || targets[i].flying || !_isManualVehicle(targets[i])) return false
                    }
                    return true
                }
                // in flight: every target flying and not returning
                property bool _canChangeAlt: {
                    void selectionRevision
                    var targets = targetVehicles(); if (!targets.length) return false
                    for (var i = 0; i < targets.length; i++) {
                        if (!targets[i].flying || _modeMatches(_rtlModeNames, targets[i].flightMode)) return false
                    }
                    return true
                }
                // last commanded altitude per vehicle id
                property var _lastCmdAlt: ({})
                // On the ground, takeoff is always allowed (valid altitude entered).
                // In flight, GO TO ALT requires the typed altitude to differ from
                // this drone's last command (so you don't re-send the same target).
                property bool _altDiffers: {
                    var entered = parseFloat(altField.text)
                    if (!entered || entered <= 0) return false
                    var targets = targetVehicles()
                    for (var i = 0; i < targets.length; i++) {
                        var v = targets[i]
                        if (!v.flying) return true            // on ground → takeoff allowed
                        var key = "" + v.id
                        if (!(key in _lastCmdAlt) || Math.abs(_lastCmdAlt[key] - entered) > 0.001) return true
                    }
                    return false
                }
                // enabled for either action, only if the altitude changed
                property bool _canTakeoff:    (_canGroundTakeoff || _canChangeAlt) && _altDiffers
                property bool _changeAltMode: _canChangeAlt && !_canGroundTakeoff

                // show the selected drone's altitude in the field
                function _fmtAlt(v) { return (v % 1 === 0) ? v.toFixed(0) : v.toFixed(1) }
                function _altForVehicle(v) {
                    if (!v) return _defaultTakeoffAlt
                    var key = "" + v.id
                    if (key in _lastCmdAlt) return _lastCmdAlt[key]                 // last commanded
                    if (v.flying && v.altitudeRelative && !isNaN(v.altitudeRelative.rawValue))
                        return v.altitudeRelative.rawValue                          // current, if flying
                    return _defaultTakeoffAlt                                       // ground default
                }
                function _syncAlt() {
                    if (altField.activeFocus) return   // don't interrupt typing
                    altField.text = _fmtAlt(_altForVehicle(_repVehicle))
                }
                Connections {
                    target: QGroundControl.multiVehicleManager
                    function onActiveVehicleChanged() { takeoffRow._syncAlt() }
                }
                Connections {
                    target: rightPanelRoot
                    function onSelectionRevisionChanged() { takeoffRow._syncAlt() }
                }

                // Altitude input
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.0
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                    color:                  Qt.rgba(1, 1, 1, 0.04)
                    border.width:           1
                    border.color:           altField.activeFocus ? _teal : Qt.rgba(1, 1, 1, 0.15)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin:  _pad * 0.6
                        anchors.rightMargin: _pad * 0.6
                        spacing: _pad * 0.4

                        // Up arrow icon decorating the field
                        QGCColoredImage {
                            width:    ScreenTools.defaultFontPixelHeight * 1.0
                            height:   width
                            source:   "/InstrumentValueIcons/arrow-thin-up.svg"
                            color:    altField.activeFocus ? _teal : Qt.rgba(1, 1, 1, 0.55)
                            fillMode: Image.PreserveAspectFit
                        }

                        TextField {
                            id: altField
                            Layout.fillWidth: true
                            // set per selected drone via takeoffRow._syncAlt()
                            Component.onCompleted: takeoffRow._syncAlt()
                            color: "white"
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                            font.bold: true
                            selectByMouse: true
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            validator: DoubleValidator { bottom: 1.0; top: 1000.0; decimals: 1; notation: DoubleValidator.StandardNotation }
                            background: Rectangle { color: "transparent" }
                            horizontalAlignment: Text.AlignLeft
                        }

                        QGCLabel {
                            text: "m"
                            color: _dimText
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                        }
                    }
                }

                // TAKEOFF
                Rectangle {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 7
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.0
                    radius: ScreenTools.defaultFontPixelHeight * 0.35
                    color: takeoffArea.containsMouse && takeoffRow._canTakeoff
                                ? Qt.rgba(0, 0.749, 1.0, 0.20)
                                : Qt.rgba(0, 0.749, 1.0, 0.07)
                    border.width: 1.5
                    border.color: takeoffRow._canTakeoff
                                ? (takeoffArea.containsMouse ? _teal : _tealBorder)
                                : Qt.rgba(1, 1, 1, 0.12)
                    opacity: takeoffRow._canTakeoff ? 1.0 : 0.55

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: _pad * 0.5

                        QGCColoredImage {
                            width:    ScreenTools.defaultFontPixelHeight * 1.2
                            height:   width
                            source:   "/InstrumentValueIcons/arrow-thin-up.svg"
                            color:    takeoffRow._canTakeoff
                                            ? (takeoffArea.containsMouse ? Qt.lighter(_teal, 1.15) : _teal)
                                            : Qt.rgba(1, 1, 1, 0.35)
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text: takeoffRow._changeAltMode ? "GO TO ALT" : "TAKEOFF"
                            color: takeoffRow._canTakeoff
                                            ? (takeoffArea.containsMouse ? Qt.lighter(_teal, 1.15) : _teal)
                                            : Qt.rgba(1, 1, 1, 0.35)
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.78
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                    }

                    MouseArea {
                        id: takeoffArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  takeoffRow._canTakeoff ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled:      takeoffRow._canTakeoff
                        onClicked: {
                            // Read the user's chosen altitude; fall back to default if invalid.
                            var altMeters = parseFloat(altField.text)
                            if (!altMeters || altMeters <= 0) altMeters = takeoffRow._defaultTakeoffAlt

                            // copy the per-drone map so reassigning re-evaluates bindings
                            var newMap = {}
                            for (var k in takeoffRow._lastCmdAlt) newMap[k] = takeoffRow._lastCmdAlt[k]

                            var targets = targetVehicles()
                            for (var i = 0; i < targets.length; i++) {
                                var v = targets[i]
                                if (v.armed && !v.flying) {
                                    // on ground: take off to entered altitude
                                    QGroundControl.multiVehicleManager.activeVehicle = v
                                    v.guidedModeTakeoff(altMeters)
                                    newMap["" + v.id] = altMeters
                                } else if (v.flying) {
                                    // in flight: convert entered target to a delta
                                    QGroundControl.multiVehicleManager.activeVehicle = v
                                    var cur = (v.altitudeRelative && !isNaN(v.altitudeRelative.rawValue))
                                                ? v.altitudeRelative.rawValue : 0
                                    v.guidedModeChangeAltitude(altMeters - cur, false)
                                    newMap["" + v.id] = altMeters
                                }
                            }
                            takeoffRow._lastCmdAlt = newMap   // disables button until altitude changes
                        }
                    }
                }
            }

            // ── LAND | RTL
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: _pad * 0.6
                spacing: _pad * 0.6

                // LAND
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.0
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                    color:                  landArea.containsMouse && _flying
                                                ? Qt.rgba(1, 0.596, 0, 0.18)
                                                : Qt.rgba(1, 0.596, 0, 0.06)
                    border.width: 1
                    border.color: _flying
                                    ? (landArea.containsMouse ? "#FFB74D" : "#FF9800")
                                    : Qt.rgba(1, 1, 1, 0.12)
                    opacity:      _flying ? 1.0 : 0.55

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: _pad * 0.5

                        QGCColoredImage {
                            width:    ScreenTools.defaultFontPixelHeight * 1.2
                            height:   width
                            source:   "/res/land.svg"
                            color:    _flying ? "#FFB74D" : Qt.rgba(1, 1, 1, 0.35)
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text: "LAND"
                            color: _flying ? "#FFB74D" : Qt.rgba(1, 1, 1, 0.35)
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.78
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                    }

                    MouseArea {
                        id: landArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled:      _flying
                        cursorShape:  _flying ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            var targets = targetVehicles()
                            for (var i = 0; i < targets.length; i++)
                                if (targets[i].flying) targets[i].guidedModeLand()
                        }
                    }
                }

                // RTL
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.0
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                    color:                  rtlArea.containsMouse && _canRtl
                                                ? Qt.rgba(0, 0.749, 1.0, 0.14)
                                                : Qt.rgba(0, 0.749, 1.0, 0.06)
                    border.width: 1
                    border.color: _canRtl
                                    ? (rtlArea.containsMouse ? _teal : _tealBorder)
                                    : Qt.rgba(1, 1, 1, 0.12)
                    opacity:      _canRtl ? 1.0 : 0.55

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: _pad * 0.5

                        QGCColoredImage {
                            width:    ScreenTools.defaultFontPixelHeight * 1.2
                            height:   width
                            source:   "/InstrumentValueIcons/home.svg"
                            color:    _canRtl ? _teal : Qt.rgba(1, 1, 1, 0.35)
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text: "RTL"
                            color: _canRtl ? _teal : Qt.rgba(1, 1, 1, 0.35)
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.78
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                    }

                    MouseArea {
                        id: rtlArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled:      _canRtl
                        cursorShape:  _canRtl ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            var targets = targetVehicles()
                            for (var i = 0; i < targets.length; i++) targets[i].guidedModeRTL(false)
                        }
                    }
                }
            }

            // ── WAYPOINT NAVIGATION — tap, then click map to send a guided goto
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: _pad * 1.0
                spacing:          _pad * 0.4

                QGCColoredImage {
                    width:    ScreenTools.defaultFontPixelHeight * 0.85
                    height:   width
                    source:   "/InstrumentValueIcons/pin.svg"
                    color:    _teal
                    fillMode: Image.PreserveAspectFit
                }
                QGCLabel {
                    Layout.fillWidth:   true
                    text:               "WAYPOINT NAVIGATION"
                    color:              _teal
                    font.pointSize:     ScreenTools.defaultFontPointSize * 0.72
                    font.bold:          true
                    font.letterSpacing: 1.2
                }
            }

            Rectangle {
                id: waypointPickCard

                property bool _picking: mainWindow.hilmWaypointPickActive
                property bool _canPick: _flying && _activeVehicle

                Layout.fillWidth:       true
                Layout.topMargin:       _pad * 0.4
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.0
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color: {
                    if (!_canPick) return Qt.rgba(0, 0.749, 1.0, 0.05)
                    if (_picking)  return Qt.rgba(0, 0.749, 1.0, 0.26)
                    return setWaypointArea.containsMouse
                        ? Qt.rgba(0, 0.749, 1.0, 0.14)
                        : Qt.rgba(0, 0.749, 1.0, 0.05)
                }
                border.width: _picking ? 2 : 1
                border.color: {
                    if (!_canPick) return Qt.rgba(1, 1, 1, 0.10)
                    if (_picking)  return _teal
                    return setWaypointArea.containsMouse ? _teal : _tealBorder
                }
                opacity: _canPick ? 1.0 : 0.55

                RowLayout {
                    anchors.centerIn: parent
                    spacing: _pad * 0.6

                    QGCColoredImage {
                        width:    ScreenTools.defaultFontPixelHeight * 1.1
                        height:   width
                        source:   "/InstrumentValueIcons/pin.svg"
                        color:    waypointPickCard._canPick ? _teal : Qt.rgba(1, 1, 1, 0.35)
                        fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        text: waypointPickCard._picking ? "TAP MAP TO PICK • CANCEL"
                                                        : "SET WAYPOINT ON MAP"
                        color: waypointPickCard._canPick ? _teal : Qt.rgba(1, 1, 1, 0.35)
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.78
                        font.bold: true
                        font.letterSpacing: 0.8
                    }
                }

                MouseArea {
                    id: setWaypointArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled:      waypointPickCard._canPick
                    cursorShape:  waypointPickCard._canPick ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        mainWindow.hilmWaypointPickActive = !mainWindow.hilmWaypointPickActive
                    }
                }
            }

            // ── EMERGENCY STOP — enters target-select mode (EMERGENCY DEPLOYMENT PANEL below takes over)
            Rectangle {
                Layout.fillWidth:       true
                Layout.topMargin:       _pad * 0.8
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.0
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                visible:                !_emergencyEngaged

                color: {
                    if (emergencyStopArea.containsMouse) return Qt.rgba(1, 0.20, 0.20, 0.20)
                    return Qt.rgba(1, 0.20, 0.20, 0.10)
                }
                border.width: 1.5
                border.color: emergencyStopArea.containsMouse ? Qt.lighter(_errColor, 1.2) : _errColor
                opacity:      _activeVehicle ? 1.0 : 0.55

                RowLayout {
                    anchors.centerIn: parent
                    spacing: _pad * 0.5

                    QGCColoredImage {
                        width:    ScreenTools.defaultFontPixelHeight * 1.3
                        height:   width
                        source:   "/InstrumentValueIcons/exclamation-outline.svg"
                        color:    _errColor
                        fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        text: "EMERGENCY STOP"
                        color: _errColor
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                        font.bold: true
                        font.letterSpacing: 1.0
                    }
                }

                MouseArea {
                    id: emergencyStopArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: _activeVehicle ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: !!_activeVehicle && !!_emergency
                    onClicked: {
                        if (!_activeVehicle || !_emergency) return
                        if (_emergencyActive || _emergencySelecting || _emergencyTargetSet) return
                        // Same flow as before: enter target-select mode, then the
                        // operator taps the map → DEPLOY/RTH/CANCEL panel below.
                        _emergency.startEmergencySelect()
                    }
                }
            }

            // ── TELEMETRY (3x2: ALT / SPD / HDG / BAT / GPS / LNK)
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: _pad * 1.0
                columns:          3
                rowSpacing:       _pad * 0.5
                columnSpacing:    _pad * 0.5

                // ALT (relative altitude in meters)
                TelemetryCell {
                    Layout.fillWidth: true
                    label: "ALT"
                    value: {
                        if (!_repVehicle || !_repVehicle.altitudeRelative) return "--"
                        var v = _repVehicle.altitudeRelative.rawValue
                        return isNaN(v) ? "--" : v.toFixed(1) + "m"
                    }
                }

                // SPD (ground speed m/s)
                TelemetryCell {
                    Layout.fillWidth: true
                    label: "SPD"
                    value: {
                        if (!_repVehicle || !_repVehicle.groundSpeed) return "--"
                        var v = _repVehicle.groundSpeed.rawValue
                        return isNaN(v) ? "--" : v.toFixed(1) + "m/s"
                    }
                }

                // HDG (compass heading)
                TelemetryCell {
                    Layout.fillWidth: true
                    label: "HDG"
                    value: {
                        if (!_repVehicle || !_repVehicle.heading) return "--"
                        var v = _repVehicle.heading.rawValue
                        return isNaN(v) ? "--" : v.toFixed(0) + "°"
                    }
                }

                // BAT (battery %)
                TelemetryCell {
                    Layout.fillWidth: true
                    label: "BAT"
                    value: {
                        if (!_repVehicle || !_repVehicle.batteries || _repVehicle.batteries.count === 0) return "--"
                        var bat = _repVehicle.batteries.get(0)
                        if (!bat || !bat.percentRemaining) return "--"
                        var v = bat.percentRemaining.rawValue
                        return (isNaN(v) || v < 0) ? "--" : v.toFixed(0) + "%"
                    }
                    accent: {
                        if (!_repVehicle || !_repVehicle.batteries || _repVehicle.batteries.count === 0) return _dimText
                        var bat = _repVehicle.batteries.get(0)
                        if (!bat || !bat.percentRemaining) return _dimText
                        var v = bat.percentRemaining.rawValue
                        if (isNaN(v) || v < 0) return _dimText
                        if (v < 20) return _errColor
                        if (v < 50) return "#FF9800"
                        return "#4CAF50"
                    }
                }

                // GPS (satellite count)
                TelemetryCell {
                    Layout.fillWidth: true
                    label: "GPS"
                    value: {
                        if (!_repVehicle || !_repVehicle.gps || !_repVehicle.gps.count) return "--"
                        var v = _repVehicle.gps.count.rawValue
                        return isNaN(v) ? "--" : v.toFixed(0)
                    }
                }

                // LNK (RC signal / link quality %)
                TelemetryCell {
                    Layout.fillWidth: true
                    label: "LNK"
                    value: {
                        if (!_repVehicle) return "--"
                        var rssi = _repVehicle.rcRSSI
                        if (isNaN(rssi) || rssi < 0) return "--"
                        return Math.min(100, rssi).toFixed(0) + "%"
                    }
                }
            }

            // ══════════════════════════════════
            // CHANGE MODE — toggle panel with mode chips
            //   HIDDEN per HILMOS UX redesign (modes are managed elsewhere).
            //   Code kept intact so the feature can be re-enabled by simply
            //   flipping `visible: false` to `visible: true` below.
            // ══════════════════════════════════
            Rectangle {
                visible:                false
                Layout.preferredHeight: 0
                Layout.fillWidth:       true
                Layout.topMargin:       0
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  changeModeArea.containsMouse
                                            ? Qt.rgba(0, 0.749, 1.0, 0.14)
                                            : Qt.rgba(0, 0.749, 1.0, 0.06)
                border.width:           1
                border.color:           modePanel.visible
                                            ? _teal
                                            : (changeModeArea.containsMouse
                                                ? Qt.rgba(0, 0.749, 1.0, 0.55)
                                                : Qt.rgba(0, 0.749, 1.0, 0.30))
                opacity:                _activeVehicle ? 1.0 : 0.55

                RowLayout {
                    id: changeModeBtn
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    height:         ScreenTools.defaultFontPixelHeight * 2.8
                    anchors.margins: _pad

                    QGCColoredImage {
                        Layout.alignment:   Qt.AlignVCenter
                        width:              ScreenTools.defaultFontPixelHeight * 1.2
                        height:             width
                        source:             "/qmlimages/PaperPlane.svg"
                        color:              _teal
                        fillMode:           Image.PreserveAspectFit
                    }
                    QGCLabel {
                        Layout.fillWidth:   true
                        text:               "CHANGE MODE"
                        color:              _teal
                        font.pointSize:     ScreenTools.defaultFontPointSize * 0.85
                        font.bold:          true
                        font.letterSpacing: 0.8
                        verticalAlignment:  Text.AlignVCenter
                    }

                    // Current mode indicator (from active vehicle)
                    Rectangle {
                        visible:            _activeVehicle !== null
                        Layout.alignment:   Qt.AlignVCenter
                        width:              currentModeLabel.implicitWidth + _pad * 1.6
                        height:             ScreenTools.defaultFontPixelHeight * 1.4
                        radius:             height / 2
                        color:              Qt.rgba(0, 0.749, 1.0, 0.12)
                        border.width:       1
                        border.color:       Qt.rgba(0, 0.749, 1.0, 0.30)

                        QGCLabel {
                            id:                 currentModeLabel
                            anchors.centerIn:   parent
                            text:               _activeVehicle ? _activeVehicle.flightMode : "--"
                            color:              "white"
                            font.pointSize:     ScreenTools.defaultFontPointSize * 0.7
                            font.bold:          true
                            font.letterSpacing: 0.3
                        }
                    }

                    // Chevron
                    QGCLabel {
                        Layout.alignment: Qt.AlignVCenter
                        text:             modePanel.visible ? "\u25B2" : "\u25BC"
                        color:            _teal
                        font.pointSize:   ScreenTools.defaultFontPointSize * 0.65
                    }
                }

                MouseArea {
                    id:             changeModeArea
                    anchors.fill:   parent
                    hoverEnabled:   true
                    cursorShape:    Qt.PointingHandCursor
                    onClicked:      modePanel.visible = !modePanel.visible
                }
            }

            // Flight mode chips panel (expandable)
            //   HIDDEN per HILMOS UX redesign. Already had visible:false but
            //   we also zero out the preferred height so it can never claim
            //   space even if some other binding flips visibility.
            Rectangle {
                id:                     modePanel
                Layout.fillWidth:       true
                Layout.preferredHeight: visible ? (modePanelContent.implicitHeight + _pad * 1.6) : 0
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  Qt.rgba(0, 0.04, 0.08, 0.90)
                border.width:           1
                border.color:           Qt.rgba(0, 0.749, 1.0, 0.20)
                visible:                false
                clip:                   true

                ColumnLayout {
                    id:                 modePanelContent
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.margins:    _pad * 0.8
                    spacing:            _pad * 0.5

                    // Section label
                    QGCLabel {
                        text:               "SELECT FLIGHT MODE"
                        color:              Qt.rgba(1, 1, 1, 0.45)
                        font.pointSize:     ScreenTools.defaultFontPointSize * 0.65
                        font.bold:          true
                        font.letterSpacing: 1.0
                    }

                    // Mode chips grid
                    Flow {
                        Layout.fillWidth: true
                        spacing:          _pad * 0.5

                        Repeater {
                            model: _activeVehicle ? _activeVehicle.flightModes : []

                            Rectangle {
                                width:   modeChipLabel.implicitWidth + _pad * 2.4
                                height:  ScreenTools.defaultFontPixelHeight * 2.2
                                radius:  ScreenTools.defaultFontPixelHeight * 0.3
                                property bool isCurrentMode: _activeVehicle && _activeVehicle.flightMode === modelData

                                color: {
                                    if (isCurrentMode) return Qt.rgba(0, 0.749, 1.0, 0.18)
                                    return modeChipArea.containsMouse
                                        ? Qt.rgba(0, 0.749, 1.0, 0.12)
                                        : Qt.rgba(1, 1, 1, 0.04)
                                }
                                border.width: isCurrentMode ? 1.5 : 1
                                border.color: {
                                    if (isCurrentMode) return _teal
                                    return modeChipArea.containsMouse
                                        ? Qt.rgba(0, 0.749, 1.0, 0.50)
                                        : Qt.rgba(1, 1, 1, 0.12)
                                }

                                Behavior on color        { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                // Active mode left accent
                                Rectangle {
                                    anchors.left:   parent.left
                                    anchors.top:    parent.top
                                    anchors.bottom: parent.bottom
                                    width:          2.5
                                    radius:         1.5
                                    color:          _teal
                                    visible:        parent.isCurrentMode
                                }

                                QGCLabel {
                                    id:                 modeChipLabel
                                    anchors.centerIn:   parent
                                    text:               modelData
                                    color:              parent.isCurrentMode ? _teal
                                                            : (modeChipArea.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.70))
                                    font.pointSize:     ScreenTools.defaultFontPointSize * 0.75
                                    font.bold:          parent.isCurrentMode || modeChipArea.containsMouse
                                    font.letterSpacing: 0.3
                                }

                                MouseArea {
                                    id:             modeChipArea
                                    anchors.fill:   parent
                                    hoverEnabled:   true
                                    cursorShape:    Qt.PointingHandCursor
                                    onClicked: {
                                        var targets = targetVehicles()
                                        for (var i = 0; i < targets.length; i++) {
                                            targets[i].flightMode = modelData
                                        }
                                        modePanel.visible = false
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

            // ── START PATROL
            //   HIDDEN per HILMOS UX redesign — patrols are now started from
            //   the MISSIONS tab. Keep code around in case we want it back.
            Rectangle {
                visible:                false
                Layout.preferredHeight: 0
                Layout.fillWidth:       true
                radius:                 ScreenTools.defaultFontPixelHeight * 0.4
                color:                  patrolArea.containsMouse ? Qt.lighter(_teal, 1.12) : _teal
                opacity:                _canStartMission ? 1.0 : 0.55

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
                    enabled:     _canStartMission
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

            // ── Video area (fixed-aspect; Flickable scrolls everything else)
            Rectangle {
                id: videoArea
                Layout.fillWidth:       true
                Layout.preferredHeight: Math.max(ScreenTools.defaultFontPixelHeight * 12,
                                                 rightPanelRoot.width * 0.62)
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

                // ── Debounced stream creator ─────────────────────
                // C++ GStreamer pipeline teardown is async. Creating a new
                // stream immediately after stopping the old one races with
                // the cleanup and causes SEH crashes. This timer enforces a
                // minimum delay between destroy and create.
                Timer {
                    id: opsCreateTimer
                    interval: 500
                    repeat: false
                    property int    pendingId:   -1
                    property string pendingUrl:  ""
                    property string pendingName: ""

                    onTriggered: {
                        if (pendingId < 0 || pendingUrl === "") return
                        if (!videoArea.opsViewVisible) return       // panel hid while we were waiting
                        if (videoArea.opsStreamId !== "") return    // already running — don't double-add

                        const sid = "ops_vehicle_" + pendingId
                        console.log("OPS Video: creating stream", sid, "URL:", pendingUrl)
                        try {
                            QGroundControl.videoManager.addCustomStream(sid, pendingUrl)
                            QGroundControl.videoManager.setCustomStreamWidget(sid, opsVideoWidget)
                        } catch (e) {
                            console.warn("OPS Video: failed to create stream", sid, e)
                            return
                        }
                        videoArea.opsStreamId   = sid
                        videoArea.opsStreamName = pendingName
                        videoArea.opsConnected  = QGroundControl.videoManager.isCustomStreamStreaming(sid)
                    }
                }

                // Track active vehicle and parent visibility
                property int  opsCurrentVehicleId: _activeVehicle ? _activeVehicle.id : -1
                property bool opsViewVisible:      rightPanelRoot.visible

                onOpsCurrentVehicleIdChanged: {
                    console.log("OPS Video: vehicle changed to", opsCurrentVehicleId)
                    _teardownStream()
                    if (opsCurrentVehicleId > 0 && opsViewVisible)
                        _createStream(opsCurrentVehicleId)
                }

                onOpsViewVisibleChanged: {
                    if (opsViewVisible) {
                        if (opsCurrentVehicleId > 0 && videoArea.opsStreamId === "")
                            _createStream(opsCurrentVehicleId)
                    } else {
                        _teardownStream()
                    }
                }

                // Explicit cleanup before destruction. Must fire while QML
                // state is still valid so removeCustomStream() can release
                // the GStreamer pipeline cleanly. Without this, the stream
                // would be leaked when the right panel collapses or the app
                // exits, causing a crash on the next create attempt.
                Component.onDestruction: _teardownStream()

                function _teardownStream() {
                    opsCreateTimer.stop()
                    if (videoArea.opsStreamId !== "") {
                        const sid = videoArea.opsStreamId
                        console.log("OPS Video: removing stream", sid)
                        // Clear QML state FIRST so any queued signals referencing
                        // the old ID become no-ops before we call into C++.
                        videoArea.opsStreamId  = ""
                        videoArea.opsConnected = false
                        try {
                            if (QGroundControl.videoManager)
                                QGroundControl.videoManager.removeCustomStream(sid)
                        } catch (e) {
                            console.warn("OPS Video: failed to remove stream", sid, e)
                        }
                    }
                }

                function _createStream(vehicleId) {
                    if (vehicleId <= 0) return
                    const url = rightPanelRoot._streamUrl(vehicleId)
                    if (url === "") return
                    opsCreateTimer.pendingId   = vehicleId
                    opsCreateTimer.pendingUrl  = url
                    opsCreateTimer.pendingName = "Drone " + vehicleId
                    opsCreateTimer.restart()
                }

                function startVideoForCurrentVehicle() {
                    _createStream(opsCurrentVehicleId)
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
                    id:               noStreamPlaceholder
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
                }

                MouseArea {
                    anchors.fill: parent
                    visible:      noStreamPlaceholder.visible
                    enabled:      visible
                    cursorShape:  _activeVehicle ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (_activeVehicle) {
                            videoArea.startVideoForCurrentVehicle()
                        }
                    }
                }
            }

            // ══════════════════════════════════
            // TRACK | RECORD | SNAPSHOT
            //   HIDDEN per HILMOS UX redesign — recording & snapshot will be
            //   moved into the gimbal control card in a follow-up commit.
            //   Code is preserved (visible:false) so it can be reinstated.
            // ══════════════════════════════════
            RowLayout {
                visible:          false
                Layout.preferredHeight: 0
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

            // ── GIMBAL CONTROL — joystick + zoom + RE-CENTER
            Rectangle {
                id: gimbalDock

                property var  _gimbalCtl:       _activeVehicle ? _activeVehicle.gimbalController : null
                property var  _activeGimbal:    _gimbalCtl ? _gimbalCtl.activeGimbal : null
                property bool _gimbalAvailable: _activeGimbal !== null && _activeGimbal !== undefined
                property var  _cameraMgr:       _activeVehicle ? _activeVehicle.cameraManager : null
                property var  _camera:          _cameraMgr ? _cameraMgr.currentCameraInstance : null

                property real _pitch: _activeGimbal && _activeGimbal.absolutePitch
                                        ? _activeGimbal.absolutePitch.rawValue : 0
                property real _yaw:   _activeGimbal && _activeGimbal.absoluteYaw
                                        ? _activeGimbal.absoluteYaw.rawValue : 0

                Layout.fillWidth:       true
                Layout.topMargin:       _sectionGap
                Layout.preferredHeight: gimbalDockCol.implicitHeight + _pad * 1.6
                radius:                 ScreenTools.defaultFontPixelHeight * 0.45
                color:                  Qt.rgba(0, 0.06, 0.10, 0.65)
                border.width:           1
                border.color:           _tealBorder

                // 10Hz throttle: send click-and-point samples (absolute, sticky) while pressed.
                Timer {
                    id: gimbalJoyTimer
                    interval: 100
                    repeat: true
                    running: false
                    onTriggered: {
                        if (gimbalDock._gimbalCtl) {
                            gimbalDock._gimbalCtl.gimbalOnScreenControl(
                                joyHandle.normPan,
                                joyHandle.normTilt,
                                true  /*clickAndPoint*/,
                                false /*clickAndDrag*/,
                                false /*rateControl*/)
                        }
                    }
                }

                ColumnLayout {
                    id: gimbalDockCol
                    anchors.left:        parent.left
                    anchors.right:       parent.right
                    anchors.top:         parent.top
                    anchors.leftMargin:  _pad
                    anchors.rightMargin: _pad
                    anchors.topMargin:   _pad * 0.7
                    spacing:             _pad * 0.4

                    // ── Header: GIMBAL  •  P: +x°  Y: +y°
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.4

                        QGCLabel {
                            text:               "GIMBAL"
                            color:              _teal
                            font.pointSize:     ScreenTools.defaultFontPointSize * 0.72
                            font.bold:          true
                            font.letterSpacing: 1.2
                        }
                        Item { Layout.fillWidth: true }
                        QGCLabel {
                            text:           "P: " + (gimbalDock._pitch >= 0 ? "+" : "") + gimbalDock._pitch.toFixed(0) +
                                            "°  ·  Y: " + (gimbalDock._yaw >= 0 ? "+" : "") + gimbalDock._yaw.toFixed(0) + "°"
                            color:          _dimText
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.75
                            font.bold:      true
                        }
                    }

                    // ── Joystick — circular drag pad with click-to-jump support
                    Item {
                        id: joyArea
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: _pad * 0.2

                        readonly property real _size: Math.min(rightPanelRoot.width * 0.45,
                                                               ScreenTools.defaultFontPixelHeight * 8.5)
                        Layout.preferredWidth:  _size
                        Layout.preferredHeight: _size

                        // ── Visual rings + crosshair + edge labels
                        Rectangle {
                            anchors.fill: parent
                            radius:       width / 2
                            color:        "transparent"
                            border.width: 1.5
                            border.color: _tealBorder
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width:  parent.width * 0.40
                            height: width
                            radius: width / 2
                            color:  "transparent"
                            border.width: 1
                            border.color: Qt.rgba(0, 0.749, 1.0, 0.22)
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter:   parent.verticalCenter
                            width:  1
                            height: parent.height * 0.88
                            color:  Qt.rgba(0, 0.749, 1.0, 0.18)
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter:   parent.verticalCenter
                            width:  parent.width * 0.88
                            height: 1
                            color:  Qt.rgba(0, 0.749, 1.0, 0.18)
                        }
                        QGCLabel {
                            anchors.top: parent.top
                            anchors.topMargin: parent.height * 0.10
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "UP"; color: _dimText
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.65; font.bold: true
                        }
                        QGCLabel {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.10
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "DN"; color: _dimText
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.65; font.bold: true
                        }
                        QGCLabel {
                            anchors.left: parent.left
                            anchors.leftMargin: parent.width * 0.10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "L"; color: _dimText
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.65; font.bold: true
                        }
                        QGCLabel {
                            anchors.right: parent.right
                            anchors.rightMargin: parent.width * 0.10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "R"; color: _dimText
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.65; font.bold: true
                        }

                        // ── Draggable handle (no MouseArea inside — outer one handles input)
                        Rectangle {
                            id: joyHandle

                            readonly property real _radius:    joyArea.width / 2
                            readonly property real _maxOffset: _radius * 0.62
                            readonly property real _diameter:  joyArea.width * 0.22

                            // Normalised pan (-1..+1, right = +) and tilt (+1 = up)
                            property real normPan:  ((x + width / 2) - _radius) / _maxOffset
                            property real normTilt: -(((y + height / 2) - _radius) / _maxOffset)

                            width:  _diameter
                            height: _diameter
                            radius: width / 2
                            color:  joyMouseArea.pressed ? Qt.lighter(_teal, 1.15) : _teal
                            border.width: 2
                            border.color: Qt.rgba(0, 0.749, 1.0, 0.45)

                            // Default centred
                            x: _radius - width / 2
                            y: _radius - height / 2

                            // Snap back to centre with an ease when released
                            Behavior on x { enabled: !joyMouseArea.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                            Behavior on y { enabled: !joyMouseArea.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                            Rectangle {
                                anchors.centerIn: parent
                                width:  parent.width * 0.30
                                height: width
                                radius: width / 2
                                color:  Qt.rgba(1, 1, 1, 0.65)
                            }
                        }

                        // Click/drag anywhere on the pad; handle clamped to a circle.
                        MouseArea {
                            id: joyMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.OpenHandCursor
                            preventStealing: true   // keep events from the Flickable scroll

                            function _placeHandleAt(mx, my) {
                                var cx  = joyArea.width  / 2
                                var cy  = joyArea.height / 2
                                var dx  = mx - cx
                                var dy  = my - cy
                                var d   = Math.sqrt(dx * dx + dy * dy)
                                var max = joyHandle._maxOffset
                                if (d > max && d > 0) {
                                    dx = dx / d * max
                                    dy = dy / d * max
                                }
                                joyHandle.x = cx + dx - joyHandle.width  / 2
                                joyHandle.y = cy + dy - joyHandle.height / 2
                            }

                            onPressed: function(mouse) {
                                _placeHandleAt(mouse.x, mouse.y)
                                if (gimbalDock._gimbalCtl) {
                                    gimbalDock._gimbalCtl.acquireGimbalControl()
                                    gimbalDock._gimbalCtl.gimbalOnScreenControl(
                                        joyHandle.normPan, joyHandle.normTilt,
                                        true, false, false)
                                }
                                gimbalJoyTimer.start()
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed) return
                                _placeHandleAt(mouse.x, mouse.y)
                            }
                            onReleased:  _release()
                            onCanceled:  _release()

                            // Sticky: handle stays where released; only RE-CENTER resets.
                            function _release() {
                                gimbalJoyTimer.stop()
                            }
                        }
                    }

                    // ── Zoom row: [−] ZOOM 1.0x [+]
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: _pad * 0.3
                        spacing: _pad * 0.3

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.9
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.9
                            radius:       width / 2
                            color:        zoomOutArea.containsMouse ? _tealDim : "transparent"
                            border.width: 1
                            border.color: _tealBorder
                            opacity:      gimbalDock._camera ? 1.0 : 0.55
                            QGCLabel {
                                anchors.centerIn: parent
                                text: "−"; color: _teal
                                font.pointSize: ScreenTools.defaultFontPointSize * 1.2; font.bold: true
                            }
                            MouseArea {
                                id: zoomOutArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled:      gimbalDock._camera !== null
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    if (gimbalDock._camera && gimbalDock._camera.stepZoom)
                                        gimbalDock._camera.stepZoom(-1)
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0
                            QGCLabel {
                                Layout.alignment: Qt.AlignHCenter
                                text: "ZOOM"; color: _dimText
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.62; font.bold: true
                                font.letterSpacing: 1.0
                            }
                            QGCLabel {
                                Layout.alignment: Qt.AlignHCenter
                                text: gimbalDock._camera && gimbalDock._camera.zoomLevel !== undefined
                                        ? gimbalDock._camera.zoomLevel.toFixed(1) + "x"
                                        : "1.0x"
                                color: "white"
                                font.pointSize: ScreenTools.defaultFontPointSize * 1.15; font.bold: true
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.9
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.9
                            radius:       width / 2
                            color:        zoomInArea.containsMouse ? _tealDim : "transparent"
                            border.width: 1
                            border.color: _tealBorder
                            opacity:      gimbalDock._camera ? 1.0 : 0.55
                            QGCLabel {
                                anchors.centerIn: parent
                                text: "+"; color: _teal
                                font.pointSize: ScreenTools.defaultFontPointSize * 1.2; font.bold: true
                            }
                            MouseArea {
                                id: zoomInArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled:      gimbalDock._camera !== null
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    if (gimbalDock._camera && gimbalDock._camera.stepZoom)
                                        gimbalDock._camera.stepZoom(1)
                                }
                            }
                        }
                    }

                    // ── RE-CENTER GIMBAL — full-width
                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.topMargin:       _pad * 0.3
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                        radius:       ScreenTools.defaultFontPixelHeight * 0.3
                        color:        recenterArea.containsMouse ? _tealDim : Qt.rgba(0, 0, 0, 0.30)
                        border.width: 1
                        border.color: recenterArea.containsMouse ? _teal : _tealBorder
                        opacity:      gimbalDock._gimbalAvailable ? 1.0 : 0.5

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: _pad * 0.45

                            QGCLabel {
                                text: "↺"; color: _teal
                                font.pointSize: ScreenTools.defaultFontPointSize * 1.05; font.bold: true
                            }
                            QGCLabel {
                                text:           "RE-CENTER GIMBAL"
                                color:          _teal
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.82
                                font.bold:      true
                                font.letterSpacing: 1.0
                            }
                        }

                        MouseArea {
                            id: recenterArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled:      gimbalDock._gimbalAvailable
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                if (gimbalDock._gimbalCtl) {
                                    gimbalDock._gimbalCtl.acquireGimbalControl()
                                    gimbalDock._gimbalCtl.centerGimbal()
                                }
                                // Snap handle back to centre (animated via Behavior).
                                joyHandle.x = joyArea.width  / 2 - joyHandle.width  / 2
                                joyHandle.y = joyArea.height / 2 - joyHandle.height / 2
                            }
                        }
                    }
                }
            }

            // Small bottom padding
            Item { Layout.preferredHeight: _pad * 0.8 }
        }
        } // end Flickable panelFlick
    }

    // ── Inline components

    // Telemetry cell for the 3x2 grid.
    component TelemetryCell: Rectangle {
        property string label: ""
        property string value: "--"
        property color  accent: "white"

        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.6
        radius:                 ScreenTools.defaultFontPixelHeight * 0.25
        color:                  Qt.rgba(1, 1, 1, 0.04)
        border.width:           1
        border.color:           Qt.rgba(1, 1, 1, 0.08)

        QGCLabel {
            anchors.left:       parent.left
            anchors.top:        parent.top
            anchors.leftMargin: _pad * 0.5
            anchors.topMargin:  _pad * 0.2
            text:               parent.label
            color:              _dimText
            font.pointSize:     ScreenTools.defaultFontPointSize * 0.55
            font.letterSpacing: 0.5
            font.bold:          true
        }

        QGCLabel {
            anchors.bottom:       parent.bottom
            anchors.right:        parent.right
            anchors.rightMargin:  _pad * 0.5
            anchors.bottomMargin: _pad * 0.25
            text:                 parent.value
            color:                parent.accent
            font.pointSize:       ScreenTools.defaultFontPointSize * 0.85
            font.bold:            true
        }
    }
}
