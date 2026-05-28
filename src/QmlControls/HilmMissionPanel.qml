/****************************************************************************
 *
 * HILM Ground Control — Mission Builder Panel (right side of PlanView)
 * Replaces PlanViewRightPanel with HILM-styled mission building UI.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id: root

    required property var planMasterController
    required property var editorMap

    // Controller shortcuts
    property var _planMaster:       planMasterController
    property var _missionCtrl:      planMasterController.missionController
    property var _patrolCtrl:       planMasterController.patrolController
    property var _fenceCtrl:        planMasterController.geoFenceController
    property var _rallyCtrl:        planMasterController.rallyPointController
    property var _vehicles:         QGroundControl.multiVehicleManager.vehicles

    // HILM design tokens
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property color _errColor:   "#FF5252"
    readonly property color _warnColor:  "#FF9800"
    readonly property color _okColor:    "#4CAF50"
    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth * 0.8
    readonly property real  _sectionGap: ScreenTools.defaultFontPixelHeight * 0.9

    // State
    property int    _activeTab:       0       // 0=BUILD, 1=SAVED
    property string _missionName:     ""
    property var    _selectedDroneIds: []
    property real   _defaultAltitude: 30
    property string _repeatChoice:    "Once"  // Once | 2× | 5× | 10× | Continuous
    property string _cruiseChoice:    "MEDIUM" // SLOW | MEDIUM | FAST | MAX
    property int    _expandedWpIdx:   -1      // visualItems index expanded (-1 = none)
    property bool   _advancedOpen:    false
    property bool   _quickFlyArmed:   false   // next map click commits a one-tap mission
    property bool   _scheduleEnabled: false
    property string _startTime:       ""
    property bool   _deployPending:   false
    property bool   _scheduleSaved:   false

    // Upload status: "idle", "uploading", "success", "error"
    property string _uploadStatus:    "idle"
    property bool   _uploadInProgress: _planMaster ? _planMaster.syncInProgress : false

    // Feedback timer for schedule save
    Timer {
        id: scheduleSavedTimer
        interval: 2000
        onTriggered: root._scheduleSaved = false
    }

    // Clear upload success/error banner after 3s
    Timer {
        id: uploadStatusTimer
        interval: 3000
        onTriggered: root._uploadStatus = "idle"
    }

    // Switch to FlyView when upload completes after Deploy
    Connections {
        target: _planMaster
        function onSyncInProgressChanged() {
            if (!_planMaster.syncInProgress && root._deployPending) {
                root._deployPending = false
                root._uploadStatus = "success"
                uploadStatusTimer.restart()
                mainWindow.showFlyView()
            }
            // Track upload completion for non-deploy uploads
            if (!_planMaster.syncInProgress && root._uploadStatus === "uploading") {
                root._uploadStatus = "success"
                uploadStatusTimer.restart()
            }
        }
    }

    // Fallback timer — if offline or upload is instant, switch after 800ms
    Timer {
        id: deployFallbackTimer
        interval: 800
        running: root._deployPending
        onTriggered: {
            if (root._deployPending) {
                root._deployPending = false
                mainWindow.showFlyView()
            }
        }
    }

    // Waypoint count (subtract home)
    readonly property int _waypointCount: _missionCtrl ? Math.max(0, _missionCtrl.visualItems.count - 1) : 0

    // First non-home item — used as the takeoff anchor when wiring default altitude.
    property var _takeoffItem: {
        if (!_missionCtrl || !_missionCtrl.visualItems) return null
        for (var i = 1; i < _missionCtrl.visualItems.count; i++) {
            var item = _missionCtrl.visualItems.get(i)
            if (item && item.altitude) return item
        }
        return null
    }

    // Cruise speed presets (m/s) for the panel buttons.
    readonly property var _cruisePresets: ({ "SLOW": 4, "MEDIUM": 8, "FAST": 14, "MAX": 20 })

    // Active vehicle used for pre-flight checks.
    property var _checkVehicle: {
        if (_selectedDroneIds.length > 0) {
            for (var i = 0; i < _vehicles.count; i++) {
                var v = _vehicles.get(i)
                if (v && _selectedDroneIds.indexOf(v.id) >= 0) return v
            }
        }
        return QGroundControl.multiVehicleManager.activeVehicle
    }

    readonly property bool _checkHasWp:      _waypointCount > 0
    readonly property bool _checkLaunchZone: _checkVehicle && _checkVehicle.coordinate.isValid
    readonly property bool _checkDrone:      _checkVehicle !== null && _checkVehicle !== undefined
    readonly property real _checkBatteryPct: {
        if (!_checkVehicle || !_checkVehicle.batteries || _checkVehicle.batteries.count === 0) return 0
        var b = _checkVehicle.batteries.get(0)
        return b && b.percentRemaining ? b.percentRemaining.rawValue : 0
    }
    readonly property bool _checkBattery:    _checkBatteryPct >= 25
    readonly property bool _allChecksPass:   _checkHasWp && _checkLaunchZone && _checkDrone && _checkBattery

    function toggleDrone(vehicleId) {
        // Single-select for the new design — newest tap replaces prior selection.
        _selectedDroneIds = [vehicleId]
    }

    function isDroneSelected(vehicleId) {
        return _selectedDroneIds.indexOf(vehicleId) >= 0
    }

    function pickDroneAuto() {
        // Auto-pick: first connected vehicle.
        if (_vehicles.count > 0) {
            var v = _vehicles.get(0)
            if (v) _selectedDroneIds = [v.id]
        }
    }

    function clearAllWaypoints() {
        if (_planMaster) _planMaster.removeAll()
        _expandedWpIdx = -1
    }

    function deployMission() {
        if (!_planMaster) return
        // Apply mission name + repeat to patrol controller if non-default.
        if (_patrolCtrl) {
            if (_missionName.length > 0) _patrolCtrl.routeName = _missionName
            switch (_repeatChoice) {
                case "Once":       _patrolCtrl.loopsMode = 1; _patrolCtrl.loops = 1;  break
                case "2×":         _patrolCtrl.loopsMode = 1; _patrolCtrl.loops = 2;  break
                case "5×":         _patrolCtrl.loopsMode = 1; _patrolCtrl.loops = 5;  break
                case "10×":        _patrolCtrl.loopsMode = 1; _patrolCtrl.loops = 10; break
                case "Continuous": _patrolCtrl.loopsMode = 0;                          break
            }
        }
        _uploadStatus = "uploading"
        _deployPending = true
        _planMaster.sendToVehicle()
    }

    // QUICK FLY: when armed, the next map drop in PlanView auto-inserts the
    // takeoff + land items. Watch the visualItems count cross from 1 (home only)
    // to >1 (something dropped) and immediately deploy + switch to FlyView.
    Connections {
        target: _missionCtrl ? _missionCtrl.visualItems : null
        function onCountChanged() {
            if (!root._quickFlyArmed) return
            if (_missionCtrl.visualItems.count > 1) {
                root._quickFlyArmed = false
                root.deployMission()
            }
        }
    }

    function armQuickFly() {
        if (!_planMaster) return
        _planMaster.removeAll()
        _quickFlyArmed = true
    }

    // ══════════════════════════════════════════════
    // Panel background
    // ══════════════════════════════════════════════
    Rectangle {
        id: panelBg
        anchors.fill: parent
        radius:       ScreenTools.defaultFontPixelHeight * 0.3
        color:        Qt.rgba(0, 0, 0, 0.85)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
        clip:         true
    }

    DeadMouseArea { anchors.fill: parent }

    // ══════════════════════════════════════════════
    // Main content
    // ══════════════════════════════════════════════
    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: _pad * 1.5
        spacing:         _pad * 0.5

        // ── Header
        RowLayout {
            Layout.fillWidth: true
            spacing:          _pad

            QGCColoredImage {
                width:    ScreenTools.defaultFontPixelHeight * 1.4
                height:   width
                source:   "/qmlimages/Plan.svg"
                color:    _teal
                fillMode: Image.PreserveAspectFit
            }
            Column {
                Layout.fillWidth: true
                spacing: 0
                QGCLabel {
                    text:               "PLAN A MISSION"
                    color:              _teal
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.95
                    font.bold:          true
                    font.letterSpacing: 1.2
                }
                QGCLabel {
                    text:           "Tap the map → review → deploy"
                    color:          _dimText
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                }
            }
        }

        // ── BUILD | SAVED tab bar
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: _pad * 0.3
            spacing:          _pad * 0.5

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  _activeTab === 0 ? _teal : _cardBg
                border.width:           _activeTab === 0 ? 0 : 1
                border.color:           Qt.rgba(1, 1, 1, 0.08)

                QGCLabel {
                    anchors.centerIn: parent
                    text:             "BUILD"
                    color:            _activeTab === 0 ? "#000000" : _dimText
                    font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.7
                    font.bold:        _activeTab === 0
                    font.letterSpacing: 0.5
                }
                MouseArea { anchors.fill: parent; onClicked: _activeTab = 0 }
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  _activeTab === 1 ? _teal : _cardBg
                border.width:           _activeTab === 1 ? 0 : 1
                border.color:           Qt.rgba(1, 1, 1, 0.08)

                QGCLabel {
                    anchors.centerIn: parent
                    text:             "SAVED"
                    color:            _activeTab === 1 ? "#000000" : _dimText
                    font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.7
                    font.bold:        _activeTab === 1
                    font.letterSpacing: 0.5
                }
                MouseArea { anchors.fill: parent; onClicked: _activeTab = 1 }
            }
        }

        // ── Separator ──
        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

        // ── Scrollable tab content ──
        QGCFlickable {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            contentHeight:     tabLoader.item ? tabLoader.item.implicitHeight : 0
            clip:              true

            Loader {
                id:    tabLoader
                width: parent.width
                sourceComponent: _activeTab === 0 ? buildTabComponent : savedTabComponent
            }
        }
    }


    // ── Build tab
    Component {
        id: buildTabComponent

        ColumnLayout {
            width:   parent ? parent.width : 100
            spacing: _pad * 0.6

            Item { Layout.preferredHeight: _pad * 0.4 }

            // ── QUICK FLY card
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: quickFlyCol.implicitHeight + _pad * 2.4
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  _cardBg
                border.width:           1
                border.color:           _quickFlyArmed ? _okColor : Qt.rgba(1, 1, 1, 0.10)

                ColumnLayout {
                    id: quickFlyCol
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: _pad * 1.2
                    spacing:         _pad * 0.6

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                        radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                        color:                  qfArea.containsMouse ? Qt.lighter(_okColor, 1.1) : _okColor

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: _pad * 0.5
                            QGCLabel { text: "⚡"; color: "#000000"; font.bold: true; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9 }
                            QGCLabel {
                                text:           _quickFlyArmed ? "TAP MAP TO FLY" : "QUICK FLY"
                                color:          "#000000"
                                font.bold:      true
                                font.letterSpacing: 0.8
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                            }
                        }
                        MouseArea {
                            id: qfArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    armQuickFly()
                        }
                    }

                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text:           "Fly to <b>one point</b> and auto-return. Click anywhere on the map."
                        textFormat:     Text.RichText
                        color:          _dimText
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                        wrapMode:       Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // ── "OR BUILD A MULTI-WAYPOINT ROUTE" divider
            QGCLabel {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: _pad * 0.6
                text:               "OR BUILD A MULTI-WAYPOINT ROUTE"
                color:              _dimText
                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.52
                font.letterSpacing: 1.4
                font.bold:          true
            }

            // ── Step 1: Drop waypoints
            Rectangle {
                Layout.fillWidth:       true
                Layout.topMargin:       _pad * 0.3
                Layout.preferredHeight: stepWpCol.implicitHeight + _pad * 2
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  _cardBg
                border.width:           1
                border.color:           _checkHasWp ? _okColor : _tealBorder

                ColumnLayout {
                    id: stepWpCol
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: _pad
                    spacing:         _pad * 0.5

                    // Header row: ① + title + subtitle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.6

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.6
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.6
                            radius: width / 2
                            color:  _checkHasWp ? _okColor : "transparent"
                            border.width: _checkHasWp ? 0 : 1.5
                            border.color: _teal
                            QGCLabel {
                                anchors.centerIn: parent
                                text:           _checkHasWp ? "✓" : "1"
                                color:          _checkHasWp ? "#000000" : _teal
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                                font.bold:      true
                            }
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 0
                            QGCLabel {
                                text:           "Drop waypoints"
                                color:          "white"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                                font.bold:      true
                            }
                            QGCLabel {
                                text: {
                                    if (!_checkHasWp) return "Click the map to add waypoints. Tap a waypoint below to set its altitude or hover time."
                                    var d = _missionCtrl.missionTotalDistance
                                    var dStr = (d / 1000).toFixed(2) + " km"
                                    return _waypointCount + " waypoints · " + dStr + " · tap a row to edit"
                                }
                                color:          _dimText
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                wrapMode:       Text.WordWrap
                                width:          parent.width
                            }
                        }
                    }

                    // ── Waypoint list
                    Repeater {
                        model: _missionCtrl ? _missionCtrl.visualItems : null
                        delegate: Item {
                            visible: index > 0    // skip home item
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? wpCard.implicitHeight : 0

                            Rectangle {
                                id: wpCard
                                anchors.left:  parent.left
                                anchors.right: parent.right
                                radius:        ScreenTools.defaultFontPixelHeight * 0.25
                                color:         Qt.rgba(1, 1, 1, 0.03)
                                border.width:  1
                                border.color:  _expandedWpIdx === index ? _teal : Qt.rgba(1, 1, 1, 0.08)
                                implicitHeight: wpInner.implicitHeight + _pad

                                ColumnLayout {
                                    id: wpInner
                                    anchors.left:    parent.left
                                    anchors.right:   parent.right
                                    anchors.top:     parent.top
                                    anchors.margins: _pad * 0.6
                                    spacing:         _pad * 0.5

                                    // Compact summary row
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: _pad * 0.5

                                        QGCLabel {
                                            text:           "WP " + index
                                            color:          "white"
                                            font.bold:      true
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                                        }
                                        Rectangle {
                                            Layout.preferredWidth:  altLabel.implicitWidth + _pad * 0.8
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.2
                                            radius: ScreenTools.defaultFontPixelHeight * 0.18
                                            color:  Qt.rgba(0, 0.749, 1.0, 0.12)
                                            border.width: 1
                                            border.color: _tealBorder
                                            QGCLabel {
                                                id: altLabel
                                                anchors.centerIn: parent
                                                text: object && object.altitude
                                                        ? object.altitude.rawValue.toFixed(0) + "M"
                                                        : "—"
                                                color: _teal
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                                font.bold: true
                                            }
                                        }
                                        QGCLabel {
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignRight
                                            elide: Text.ElideRight
                                            text: object && object.coordinate
                                                    ? object.coordinate.latitude.toFixed(3) + ", " +
                                                      object.coordinate.longitude.toFixed(3)
                                                    : ""
                                            color: _dimText
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                        }
                                        QGCLabel {
                                            text:           _expandedWpIdx === index ? "⌃" : "⌄"
                                            color:          _teal
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape:  Qt.PointingHandCursor
                                            onClicked: {
                                                _expandedWpIdx = (_expandedWpIdx === index) ? -1 : index
                                                if (_missionCtrl)
                                                    _missionCtrl.setCurrentPlanViewSeqNum(object.sequenceNumber, false)
                                            }
                                        }
                                    }

                                    // ── Expanded editor
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: _pad * 0.5
                                        visible: _expandedWpIdx === index

                                        // Altitude header
                                        QGCLabel {
                                            text:           "↑  ALTITUDE"
                                            color:          _dimText
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                            font.bold:      true
                                            font.letterSpacing: 1.0
                                            Layout.topMargin: _pad * 0.3
                                        }

                                        // Altitude stepper + value
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: _pad * 0.3

                                            Rectangle {
                                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.6
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.6
                                                radius: width / 2
                                                color: minusArea.containsMouse ? _tealDim : "transparent"
                                                border.width: 1
                                                border.color: _tealBorder
                                                QGCLabel { anchors.centerIn: parent; text: "−"; color: _teal; font.bold: true }
                                                MouseArea {
                                                    id: minusArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape:  Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (object && object.altitude) {
                                                            var v = Math.max(0, object.altitude.rawValue - 5)
                                                            object.altitude.rawValue = v
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                                                radius: ScreenTools.defaultFontPixelHeight * 0.2
                                                color: Qt.rgba(1, 1, 1, 0.06)
                                                border.width: 1
                                                border.color: Qt.rgba(1, 1, 1, 0.10)
                                                QGCLabel {
                                                    anchors.centerIn: parent
                                                    text: object && object.altitude ? object.altitude.rawValue.toFixed(0) : "—"
                                                    color: "white"
                                                    font.bold: true
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                                                }
                                            }
                                            QGCLabel { text: "m"; color: _dimText; font.bold: true }

                                            Rectangle {
                                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.6
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.6
                                                radius: width / 2
                                                color: plusArea.containsMouse ? _tealDim : "transparent"
                                                border.width: 1
                                                border.color: _tealBorder
                                                QGCLabel { anchors.centerIn: parent; text: "+"; color: _teal; font.bold: true }
                                                MouseArea {
                                                    id: plusArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape:  Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (object && object.altitude)
                                                            object.altitude.rawValue = object.altitude.rawValue + 5
                                                    }
                                                }
                                            }
                                        }

                                        // Altitude presets
                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 5
                                            columnSpacing: _pad * 0.25
                                            Repeater {
                                                model: [15, 30, 50, 80, 100]
                                                delegate: Rectangle {
                                                    property bool _selected: object && object.altitude && Math.abs(object.altitude.rawValue - modelData) < 0.5
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.6
                                                    radius: ScreenTools.defaultFontPixelHeight * 0.2
                                                    color: _selected ? _tealDim : Qt.rgba(1, 1, 1, 0.04)
                                                    border.width: 1
                                                    border.color: _selected ? _teal : Qt.rgba(1, 1, 1, 0.10)
                                                    QGCLabel {
                                                        anchors.centerIn: parent
                                                        text: modelData + "M"
                                                        color: _selected ? _teal : "white"
                                                        font.bold: true
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: { if (object && object.altitude) object.altitude.rawValue = modelData }
                                                    }
                                                }
                                            }
                                        }

                                        // Speed
                                        QGCLabel {
                                            text:           "⊘  SPEED TO THIS WAYPOINT"
                                            color:          _dimText
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                            font.bold:      true
                                            font.letterSpacing: 1.0
                                            Layout.topMargin: _pad * 0.3
                                        }
                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 4
                                            columnSpacing: _pad * 0.25
                                            Repeater {
                                                model: [{ k: "SLOW",   v: 4 },
                                                        { k: "MEDIUM", v: 8 },
                                                        { k: "FAST",   v: 14 },
                                                        { k: "MAX",    v: 20 }]
                                                delegate: Rectangle {
                                                    property var _speed: object && object.speedSection && object.speedSection.flightSpeed
                                                                            ? object.speedSection.flightSpeed.rawValue : -1
                                                    property bool _selected: Math.abs(_speed - modelData.v) < 0.5
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.0
                                                    radius: ScreenTools.defaultFontPixelHeight * 0.2
                                                    color: _selected ? _tealDim : Qt.rgba(1, 1, 1, 0.04)
                                                    border.width: 1
                                                    border.color: _selected ? _teal : Qt.rgba(1, 1, 1, 0.10)
                                                    Column {
                                                        anchors.centerIn: parent
                                                        spacing: 1
                                                        QGCLabel {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            text: modelData.k
                                                            color: _selected ? _teal : "white"
                                                            font.bold: true
                                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                                        }
                                                        QGCLabel {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            text: modelData.v + " M/S"
                                                            color: _dimText
                                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.45
                                                        }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (object && object.speedSection) {
                                                                object.speedSection.specifyFlightSpeed = true
                                                                object.speedSection.flightSpeed.rawValue = modelData.v
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Hover at point
                                        QGCLabel {
                                            text:           "🕐  HOVER AT POINT  (for inspection / photo)"
                                            color:          _dimText
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                            font.bold:      true
                                            font.letterSpacing: 1.0
                                            Layout.topMargin: _pad * 0.3
                                        }
                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 5
                                            columnSpacing: _pad * 0.25
                                            Repeater {
                                                model: [{ k: "—",  v: 0 },
                                                        { k: "5S", v: 5 },
                                                        { k: "10S", v: 10 },
                                                        { k: "30S", v: 30 },
                                                        { k: "60S", v: 60 }]
                                                delegate: Rectangle {
                                                    // Hover lives in NAV_WAYPOINT param1 ("Hold" textField fact).
                                                    property var _hoverFact: {
                                                        if (!object || !object.textFieldFacts) return null
                                                        for (var i = 0; i < object.textFieldFacts.count; i++) {
                                                            var f = object.textFieldFacts.get(i)
                                                            if (f && (f.name === "Hold" || f.name === "Hold time" || f.name === "Hold Time"))
                                                                return f
                                                        }
                                                        return null
                                                    }
                                                    property bool _selected: _hoverFact && Math.abs(_hoverFact.rawValue - modelData.v) < 0.5
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.7
                                                    radius: ScreenTools.defaultFontPixelHeight * 0.2
                                                    color: _selected ? _tealDim : Qt.rgba(1, 1, 1, 0.04)
                                                    border.width: 1
                                                    border.color: _selected ? _teal : Qt.rgba(1, 1, 1, 0.10)
                                                    opacity: _hoverFact ? 1.0 : 0.5
                                                    QGCLabel {
                                                        anchors.centerIn: parent
                                                        text:  modelData.k
                                                        color: _selected ? _teal : "white"
                                                        font.bold: true
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        enabled: _hoverFact !== null
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: { if (_hoverFact) _hoverFact.rawValue = modelData.v }
                                                    }
                                                }
                                            }
                                        }

                                        // Remove
                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.topMargin: _pad * 0.3
                                            Layout.preferredWidth:  removeRow.implicitWidth + _pad * 1.4
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                                            radius: ScreenTools.defaultFontPixelHeight * 0.2
                                            color:  removeArea.containsMouse ? Qt.rgba(1, 0.32, 0.32, 0.16) : "transparent"
                                            RowLayout {
                                                id: removeRow
                                                anchors.centerIn: parent
                                                spacing: _pad * 0.3
                                                QGCLabel { text: "🗑"; color: _errColor }
                                                QGCLabel {
                                                    text:           "REMOVE WP " + index
                                                    color:          _errColor
                                                    font.bold:      true
                                                    font.letterSpacing: 1.0
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                                }
                                            }
                                            MouseArea {
                                                id: removeArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape:  Qt.PointingHandCursor
                                                onClicked: {
                                                    if (_missionCtrl) _missionCtrl.removeVisualItem(index)
                                                    _expandedWpIdx = -1
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Step 2: Pre-flight check
            Rectangle {
                Layout.fillWidth:       true
                Layout.topMargin:       _pad * 0.4
                Layout.preferredHeight: stepCheckCol.implicitHeight + _pad * 2
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  _cardBg
                border.width:           1
                border.color:           _allChecksPass ? _okColor : _tealBorder

                ColumnLayout {
                    id: stepCheckCol
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: _pad
                    spacing:         _pad * 0.45

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.6

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.6
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.6
                            radius: width / 2
                            color:  _allChecksPass ? _okColor : "transparent"
                            border.width: _allChecksPass ? 0 : 1.5
                            border.color: _teal
                            QGCLabel {
                                anchors.centerIn: parent
                                text:           _allChecksPass ? "✓" : "2"
                                color:          _allChecksPass ? "#000000" : _teal
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                                font.bold:      true
                            }
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 0
                            QGCLabel {
                                text:           "Pre-flight check"
                                color:          "white"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                                font.bold:      true
                            }
                            QGCLabel {
                                text:           _allChecksPass ? "Ready to deploy" : "Resolve the items below first"
                                color:          _allChecksPass ? _okColor : _warnColor
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                            }
                        }
                    }

                    // Check rows
                    Repeater {
                        model: [
                            { ok: _checkHasWp,
                              good: _waypointCount + " waypoints set",
                              bad:  "Add at least one waypoint" },
                            { ok: _checkLaunchZone,
                              good: "Launch zone: " + (_checkVehicle ? (_checkVehicle.vehicleName || "vehicle") + "'s current position" : ""),
                              bad:  "Launch zone: no vehicle position" },
                            { ok: _checkDrone,
                              good: "Drone: " + (_checkVehicle ? (_checkVehicle.vehicleName || "selected") : ""),
                              bad:  "Drone: none selected" },
                            { ok: _checkBattery,
                              good: "Battery: " + _checkBatteryPct.toFixed(0) + "% (needs ≥ 25%)",
                              bad:  "Battery: " + _checkBatteryPct.toFixed(0) + "% (needs ≥ 25%)" }
                        ]
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: _pad * 0.4
                            Rectangle {
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.9
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.9
                                radius: width / 2
                                color:  modelData.ok ? _okColor : "transparent"
                                border.width: modelData.ok ? 0 : 1.5
                                border.color: _warnColor
                                QGCLabel {
                                    anchors.centerIn: parent
                                    text:           modelData.ok ? "✓" : "⚠"
                                    color:          modelData.ok ? "#000000" : _warnColor
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                    font.bold:      true
                                }
                            }
                            QGCLabel {
                                text:           modelData.ok ? modelData.good : modelData.bad
                                color:          modelData.ok ? "white" : _warnColor
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Mission summary (visible when ready)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: _pad * 0.4
                        Layout.preferredHeight: summaryCol.implicitHeight + _pad * 1.4
                        radius: ScreenTools.defaultFontPixelHeight * 0.25
                        color:  Qt.rgba(0.30, 0.69, 0.31, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(0.30, 0.69, 0.31, 0.30)
                        visible: _allChecksPass

                        ColumnLayout {
                            id: summaryCol
                            anchors.left:    parent.left
                            anchors.right:   parent.right
                            anchors.top:     parent.top
                            anchors.margins: _pad * 0.8
                            spacing:         _pad * 0.2

                            QGCLabel {
                                text:           "MISSION SUMMARY"
                                color:          _dimText
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                font.bold:      true
                                font.letterSpacing: 1.0
                            }
                            QGCLabel {
                                text: "🛩 <b>" + (_checkVehicle ? (_checkVehicle.vehicleName || "Drone") : "Drone")
                                      + "</b> will fly " + _waypointCount + " waypoints"
                                textFormat: Text.RichText
                                color: "white"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                            }
                            QGCLabel {
                                text: {
                                    var d = _missionCtrl ? _missionCtrl.missionTotalDistance : 0
                                    var t = _missionCtrl ? _missionCtrl.missionTime : 0
                                    return "📏 ~ " + (d / 1000).toFixed(2) + " km in ~ " +
                                            Math.max(1, Math.round(t / 60)) + " min"
                                }
                                color: "white"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                            }
                            QGCLabel {
                                text: "🚀 Cruise: " + _cruiseChoice.toLowerCase() +
                                      " (" + _cruisePresets[_cruiseChoice] + " m/s)"
                                color: "white"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                            }
                            QGCLabel {
                                text:           "🔁 Repeats: " + _repeatChoice
                                color:          "white"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                            }
                            QGCLabel {
                                text:           "🏠 Auto-returns to launch when done"
                                color:          "white"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                            }
                        }
                    }
                }
            }

            // ── Advanced settings (collapsible)
            Rectangle {
                Layout.fillWidth:       true
                Layout.topMargin:       _pad * 0.4
                Layout.preferredHeight: advCol.implicitHeight + _pad * 1.4
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.08)

                ColumnLayout {
                    id: advCol
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: _pad
                    spacing:         _pad * 0.5

                    // Header (toggle row)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.5

                        QGCColoredImage {
                            width: ScreenTools.defaultFontPixelHeight * 0.9; height: width
                            source: "/qmlimages/Gears.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text:           "ADVANCED SETTINGS"
                            color:          "white"
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                            font.bold:      true
                            font.letterSpacing: 1.0
                        }
                        Item { Layout.fillWidth: true }
                        QGCLabel {
                            text:           _advancedOpen ? "⌃" : "⌄"
                            color:          _teal
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    _advancedOpen = !_advancedOpen
                        }
                    }

                    // Expanded body
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.5
                        visible: _advancedOpen

                        // Mission name
                        QGCLabel { text: "Mission name"; color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55 }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.0
                            radius: ScreenTools.defaultFontPixelHeight * 0.2
                            color:  Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            TextInput {
                                anchors.fill:        parent
                                anchors.leftMargin:  _pad
                                anchors.rightMargin: _pad
                                verticalAlignment:   Text.AlignVCenter
                                color:               "white"
                                font.pixelSize:      ScreenTools.defaultFontPixelHeight * 0.65
                                font.family:         ScreenTools.normalFontFamily
                                clip:                true
                                text:                _missionName
                                onTextChanged:       _missionName = text
                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Mission " + Qt.formatTime(new Date(), "hh:mm")
                                    color: Qt.rgba(1, 1, 1, 0.2)
                                    font: parent.font
                                    visible: !parent.text && !parent.activeFocus
                                }
                            }
                        }

                        // Drone
                        QGCLabel { text: "Drone"; color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55 }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.0
                            radius: ScreenTools.defaultFontPixelHeight * 0.2
                            color:  droneDropArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin:  _pad
                                anchors.rightMargin: _pad
                                QGCLabel {
                                    text: {
                                        if (_selectedDroneIds.length === 0) return "AUTO-PICK BEST AVAILABLE"
                                        return _checkVehicle ? (_checkVehicle.vehicleName || ("Vehicle " + _checkVehicle.id)) : ""
                                    }
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                    Layout.fillWidth: true
                                }
                                QGCLabel { text: "⌄"; color: _teal; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8 }
                            }
                            MouseArea {
                                id: droneDropArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    droneMenu.open()
                            }
                            Menu {
                                id: droneMenu
                                background: Rectangle {
                                    implicitWidth:  ScreenTools.defaultFontPixelWidth * 22
                                    color:          Qt.rgba(0, 0, 0, 0.95)
                                    border.width:   1
                                    border.color:   _tealBorder
                                    radius:         ScreenTools.defaultFontPixelHeight * 0.2
                                }
                                MenuItem {
                                    id: autoPickMI
                                    text: "Auto-pick best available"
                                    height: ScreenTools.defaultFontPixelHeight * 2.2
                                    property bool _selected: _selectedDroneIds.length === 0
                                    contentItem: RowLayout {
                                        spacing: _pad * 0.3
                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text:           autoPickMI.text
                                            color:          autoPickMI._selected || autoPickMI.highlighted ? "#000000" : "white"
                                            font.bold:      autoPickMI._selected
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding:    _pad
                                        }
                                        QGCLabel {
                                            text:           "✓"
                                            color:          "#000000"
                                            font.bold:      true
                                            visible:        autoPickMI._selected
                                            rightPadding:   _pad
                                        }
                                    }
                                    background: Rectangle {
                                        color: autoPickMI._selected || autoPickMI.highlighted ? _teal : "transparent"
                                    }
                                    onTriggered: _selectedDroneIds = []
                                }
                                Repeater {
                                    model: _vehicles
                                    MenuItem {
                                        id: vehMI
                                        height: ScreenTools.defaultFontPixelHeight * 2.2
                                        text: object ? ((object.vehicleName || ("Vehicle " + object.id))) : ""
                                        property bool _selected: object && _selectedDroneIds.length > 0 && _selectedDroneIds[0] === object.id
                                        contentItem: RowLayout {
                                            spacing: _pad * 0.3
                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text:           vehMI.text
                                                color:          vehMI._selected || vehMI.highlighted ? "#000000" : "white"
                                                font.bold:      vehMI._selected
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                                                verticalAlignment: Text.AlignVCenter
                                                leftPadding:    _pad
                                            }
                                            QGCLabel {
                                                text:           "✓"
                                                color:          "#000000"
                                                font.bold:      true
                                                visible:        vehMI._selected
                                                rightPadding:   _pad
                                            }
                                        }
                                        background: Rectangle {
                                            color: vehMI._selected || vehMI.highlighted ? _teal : "transparent"
                                        }
                                        onTriggered: { if (object) _selectedDroneIds = [object.id] }
                                    }
                                }
                            }
                        }

                        // Default altitude + Repeat row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: _pad * 0.5

                            Column {
                                Layout.fillWidth: true
                                spacing: 4
                                QGCLabel { text: "Default altitude (m)"; color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55 }
                                Rectangle {
                                    width: parent.width
                                    height: ScreenTools.defaultFontPixelHeight * 2.0
                                    radius: ScreenTools.defaultFontPixelHeight * 0.2
                                    color:  Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.10)
                                    TextInput {
                                        anchors.fill:        parent
                                        anchors.leftMargin:  _pad
                                        anchors.rightMargin: _pad
                                        verticalAlignment:   Text.AlignVCenter
                                        color:               "white"
                                        font.pixelSize:      ScreenTools.defaultFontPixelHeight * 0.65
                                        font.family:         ScreenTools.normalFontFamily
                                        validator:           DoubleValidator { bottom: 0; top: 500 }
                                        text:                _defaultAltitude.toString()
                                        onTextChanged: {
                                            var v = parseFloat(text)
                                            if (!isNaN(v)) _defaultAltitude = v
                                        }
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 4
                                QGCLabel { text: "Repeat"; color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55 }
                                Rectangle {
                                    width: parent.width
                                    height: ScreenTools.defaultFontPixelHeight * 2.0
                                    radius: ScreenTools.defaultFontPixelHeight * 0.2
                                    color:  repeatDropArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.10)
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin:  _pad
                                        anchors.rightMargin: _pad
                                        QGCLabel {
                                            text:           _repeatChoice.toUpperCase()
                                            color:          "white"
                                            font.bold:      true
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                            Layout.fillWidth: true
                                        }
                                        QGCLabel { text: "⌄"; color: _teal; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8 }
                                    }
                                    MouseArea {
                                        id: repeatDropArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape:  Qt.PointingHandCursor
                                        onClicked:    repeatMenu.open()
                                    }
                                    Menu {
                                        id: repeatMenu
                                        background: Rectangle {
                                            implicitWidth:  ScreenTools.defaultFontPixelWidth * 16
                                            color:          Qt.rgba(0, 0, 0, 0.95)
                                            border.width:   1
                                            border.color:   _tealBorder
                                            radius:         ScreenTools.defaultFontPixelHeight * 0.2
                                        }
                                        Repeater {
                                            model: ["Once", "2×", "5×", "10×", "Continuous"]
                                            MenuItem {
                                                id: repeatMI
                                                height: ScreenTools.defaultFontPixelHeight * 2.2
                                                text: modelData
                                                property bool _selected: _repeatChoice === modelData
                                                contentItem: RowLayout {
                                                    spacing: _pad * 0.3
                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        text:           repeatMI.text
                                                        color:          repeatMI._selected || repeatMI.highlighted ? "#000000" : "white"
                                                        font.bold:      repeatMI._selected
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                                                        verticalAlignment: Text.AlignVCenter
                                                        leftPadding:    _pad
                                                    }
                                                    QGCLabel {
                                                        text:           "✓"
                                                        color:          "#000000"
                                                        font.bold:      true
                                                        visible:        repeatMI._selected
                                                        rightPadding:   _pad
                                                    }
                                                }
                                                background: Rectangle {
                                                    color: repeatMI._selected || repeatMI.highlighted ? _teal : "transparent"
                                                }
                                                onTriggered: _repeatChoice = modelData
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Default cruise speed
                        QGCLabel {
                            text:           "Default cruise speed  (per-waypoint override available)"
                            color:          _dimText
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                            Layout.topMargin: _pad * 0.2
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: _pad * 0.25
                            Repeater {
                                model: [{ k: "SLOW",   v: 4 },
                                        { k: "MEDIUM", v: 8 },
                                        { k: "FAST",   v: 14 },
                                        { k: "MAX",    v: 20 }]
                                delegate: Rectangle {
                                    property bool _selected: _cruiseChoice === modelData.k
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                                    radius: ScreenTools.defaultFontPixelHeight * 0.2
                                    color: _selected ? _tealDim : Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 1
                                    border.color: _selected ? _teal : Qt.rgba(1, 1, 1, 0.10)
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        QGCLabel {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.k
                                            color: _selected ? _teal : "white"
                                            font.bold: true
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                        }
                                        QGCLabel {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.v + " M/S"
                                            color: _dimText
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.45
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: _cruiseChoice = modelData.k
                                    }
                                }
                            }
                        }

                        // Schedule subsection
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: _pad * 0.4
                            Layout.preferredHeight: schedCol.implicitHeight + _pad * 1.2
                            radius: ScreenTools.defaultFontPixelHeight * 0.25
                            color:  Qt.rgba(1, 1, 1, 0.02)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.08)

                            ColumnLayout {
                                id: schedCol
                                anchors.left:    parent.left
                                anchors.right:   parent.right
                                anchors.top:     parent.top
                                anchors.margins: _pad * 0.7
                                spacing:         _pad * 0.3

                                RowLayout {
                                    Layout.fillWidth: true
                                    QGCLabel {
                                        text:           "🕐 SCHEDULE"
                                        color:          _dimText
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                        font.bold:      true
                                        font.letterSpacing: 1.0
                                        Layout.fillWidth: true
                                    }
                                    QGCLabel {
                                        text:           _scheduleEnabled ? "ON" : "OFF"
                                        color:          _scheduleEnabled ? _okColor : _dimText
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                        font.bold:      true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape:  Qt.PointingHandCursor
                                        onClicked:    _scheduleEnabled = !_scheduleEnabled
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: _pad * 0.4
                                    visible: _scheduleEnabled

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        QGCLabel { text: "Start time"; color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5 }
                                        Rectangle {
                                            width: parent.width
                                            height: ScreenTools.defaultFontPixelHeight * 1.8
                                            radius: ScreenTools.defaultFontPixelHeight * 0.2
                                            color:  Qt.rgba(1, 1, 1, 0.04)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.10)
                                            TextInput {
                                                anchors.fill: parent
                                                anchors.leftMargin:  _pad
                                                anchors.rightMargin: _pad
                                                verticalAlignment: Text.AlignVCenter
                                                color: "white"
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                                font.family: ScreenTools.normalFontFamily
                                                text: _startTime
                                                onTextChanged: _startTime = text
                                                Text {
                                                    anchors.fill: parent
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: "HH:MM"
                                                    color: Qt.rgba(1, 1, 1, 0.2)
                                                    font: parent.font
                                                    visible: !parent.text && !parent.activeFocus
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        QGCLabel { text: "Start date"; color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5 }
                                        Rectangle {
                                            width: parent.width
                                            height: ScreenTools.defaultFontPixelHeight * 1.8
                                            radius: ScreenTools.defaultFontPixelHeight * 0.2
                                            color:  Qt.rgba(1, 1, 1, 0.04)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.10)
                                            TextInput {
                                                id: schedDateInput
                                                anchors.fill: parent
                                                anchors.leftMargin:  _pad
                                                anchors.rightMargin: _pad
                                                verticalAlignment: Text.AlignVCenter
                                                color: "white"
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                                font.family: ScreenTools.normalFontFamily
                                                text: _patrolCtrl && _patrolCtrl.startDate
                                                        && _patrolCtrl.startDate instanceof Date
                                                        && !isNaN(_patrolCtrl.startDate.getTime())
                                                        ? Qt.formatDate(_patrolCtrl.startDate, "yyyy-MM-dd") : ""
                                                onEditingFinished: {
                                                    if (!_patrolCtrl || !text) return
                                                    var dateRe = /^\d{4}-\d{2}-\d{2}$/
                                                    if (!dateRe.test(text)) return
                                                    var parts = text.split("-")
                                                    var d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
                                                    if (!isNaN(d.getTime())) _patrolCtrl.startDate = d
                                                }
                                                Text {
                                                    anchors.fill: parent
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: "YYYY-MM-DD"
                                                    color: Qt.rgba(1, 1, 1, 0.2)
                                                    font: parent.font
                                                    visible: !parent.text && !parent.activeFocus
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: _pad * 0.8 }

            // ── SAVE | DEPLOY actions
            RowLayout {
                Layout.fillWidth: true
                spacing: _pad * 0.5

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    radius: ScreenTools.defaultFontPixelHeight * 0.25
                    color:  saveArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    border.width: 1
                    border.color: _tealBorder
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: _pad * 0.4
                        QGCColoredImage {
                            width: ScreenTools.defaultFontPixelHeight * 0.7; height: width
                            source: "/qmlimages/Plan.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text: "SAVE"; color: _teal
                            font.bold: true; font.letterSpacing: 1.0
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                        }
                    }
                    MouseArea {
                        id: saveArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    _planMaster.saveToSelectedFile()
                    }
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    radius: ScreenTools.defaultFontPixelHeight * 0.25
                    color:  _allChecksPass
                                ? (deployArea.containsMouse ? Qt.lighter(_okColor, 1.1) : _okColor)
                                : Qt.rgba(1, 1, 1, 0.06)
                    border.width: _allChecksPass ? 0 : 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    opacity: _allChecksPass ? 1.0 : 0.55

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: _pad * 0.4
                        QGCLabel { text: "▶"; color: _allChecksPass ? "#000000" : _dimText; font.bold: true }
                        QGCLabel {
                            text: _uploadInProgress ? "DEPLOYING…" : "DEPLOY"
                            color: _allChecksPass ? "#000000" : _dimText
                            font.bold: true; font.letterSpacing: 1.0
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                        }
                    }
                    MouseArea {
                        id: deployArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: _allChecksPass && !_uploadInProgress
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: deployMission()
                    }
                }
            }

            Item { Layout.preferredHeight: _pad * 1.5 }
        }
    }

    // ── Saved tab
    Component {
        id: savedTabComponent

        ColumnLayout {
            width:   parent ? parent.width : 100
            spacing: _pad

            Item { Layout.preferredHeight: _pad }

            // Open saved mission
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.6
                radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                color:                  openArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.08) : "transparent"
                border.width:           1
                border.color:           _tealBorder

                RowLayout {
                    anchors.centerIn: parent
                    spacing: _pad * 0.5
                    QGCColoredImage {
                        width: ScreenTools.defaultFontPixelHeight * 0.7; height: width
                        source: "/qmlimages/Plan.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        text: "OPEN SAVED MISSION"; color: _teal
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                        font.bold: true; font.letterSpacing: 0.5
                    }
                }
                MouseArea {
                    id: openArea; anchors.fill: parent; hoverEnabled: true
                    onClicked: _planMaster.loadFromSelectedFile()
                }
            }

            // Download from vehicle
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.6
                radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                color:                  dlArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.08)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: _pad * 0.5
                    QGCColoredImage {
                        width: ScreenTools.defaultFontPixelHeight * 0.7; height: width
                        source: "/qmlimages/Arrow-down.svg"; color: "white"; fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        text: "DOWNLOAD FROM VEHICLE"; color: "white"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                        font.bold: true; font.letterSpacing: 0.5
                    }
                }
                MouseArea {
                    id: dlArea; anchors.fill: parent; hoverEnabled: true
                    onClicked: _planMaster.loadFromVehicle()
                }
            }

            // Clear all
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.6
                radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                color:                  clearArea.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.08) : _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.08)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: _pad * 0.5
                    QGCLabel {
                        text: "CLEAR ALL"; color: _errColor
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                        font.bold: true; font.letterSpacing: 0.5
                    }
                }
                MouseArea {
                    id: clearArea; anchors.fill: parent; hoverEnabled: true
                    onClicked: _planMaster.removeAll()
                }
            }

            // Placeholder for future file listing
            Item { Layout.preferredHeight: _sectionGap }

            QGCLabel {
                Layout.alignment: Qt.AlignHCenter
                text:           "Saved missions will appear here"
                color:          Qt.rgba(1, 1, 1, 0.2)
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
            }
        }
    }
}
