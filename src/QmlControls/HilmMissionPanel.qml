/****************************************************************************
 *
 * HILM Ground Control — Mission Builder Panel (right side of PlanView)
 * Replaces PlanViewRightPanel with HILM-styled mission building UI.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

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

    // Autonomous Patrol (scheduled/looping) requires a HILM companion computer,
    // enabled in the Network tab. (Quick Fly is NOT gated — it works on stock PX4.)
    property bool _companionEnabled: QGroundControl.settingsManager.appSettings.companionComputerEnabled.rawValue

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

    // Editing layers — kept in sync with PlanView's _editingLayer via requestedEditingLayer.
    readonly property int layerMission: 1
    readonly property int layerFence:   2
    readonly property int layerRally:   3

    // The layer PlanView should switch to for the active tab. FENCE/RALLY make their
    // respective map visuals interactive; everything else edits the mission.
    readonly property int requestedEditingLayer:
        _activeTab === 1 ? layerFence :
        _activeTab === 2 ? layerRally : layerMission

    // State
    property int    _activeTab:       0       // 0=BUILD, 1=FENCE, 2=RALLY, 3=SAVED
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
                // Kick off the uploaded mission on the same vehicle that received it.
                // Without this the plan sits idle on ArduPilot: sendToVehicle() only
                // uploads items — startMission() switches to Auto/Guided, arms, and
                // sends MAV_CMD_MISSION_START so takeoff → waypoint → land actually runs.
                if (!_planMaster.offline && _planMaster.managerVehicle) {
                    _planMaster.managerVehicle.startMission()
                }
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

    // MAV_CMD values used to detect a mission that already terminates itself.
    readonly property int _cmdNavLand:      21
    readonly property int _cmdNavRtl:       20
    readonly property int _cmdNavVtolLand:  85

    // If the mission's last item isn't already a return/land command, append an
    // RTL so the vehicle comes home instead of holding at the last waypoint.
    // Idempotent — deploying twice won't stack multiple RTLs.
    function _ensureMissionEndsWithReturn() {
        if (!_missionCtrl || !_missionCtrl.visualItems) return
        var items = _missionCtrl.visualItems
        var lastIdx = items.count - 1
        if (lastIdx <= 0) return   // only home present; nothing to append to

        var last = items.get(lastIdx)
        // SimpleMissionItem exposes an integer `command`. ComplexMissionItems
        // (surveys, structure scans, landing patterns) don't — for those we
        // still append RTL as the next terminal step.
        if (last && typeof last.command === "number") {
            if (last.command === _cmdNavRtl ||
                last.command === _cmdNavLand ||
                last.command === _cmdNavVtolLand) {
                return
            }
        }

        // insertLandItem() maps to NAV_RETURN_TO_LAUNCH for copters (see
        // MissionController.cc). The coordinate arg is unused for RTL — pass
        // the last item's coordinate so the visual anchors near that point.
        var coord = (last && last.coordinate && last.coordinate.isValid)
                    ? last.coordinate
                    : ((_checkVehicle && _checkVehicle.coordinate) ? _checkVehicle.coordinate : null)
        _missionCtrl.insertLandItem(coord, items.count, false)
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
        // Guarantee the plan terminates with a return so the vehicle doesn't
        // hover at the last waypoint after finishing.
        _ensureMissionEndsWithReturn()
        _uploadStatus = "uploading"
        _deployPending = true
        _planMaster.sendToVehicle()
    }

    function armQuickFly() {
        if (!_planMaster) return
        _planMaster.removeAll()
        _quickFlyArmed = true
    }

    // Assemble and deploy a full Quick Fly mission from one map click.
    // Sequence: TAKEOFF (at vehicle position) → WAYPOINT (clicked point) → RTL.
    // insertLandItem() emits MAV_CMD_NAV_RETURN_TO_LAUNCH for copters, so the
    // vehicle returns home instead of holding at the last waypoint.
    function buildAndDeployQuickFly(destinationCoord) {
        if (!_planMaster || !_missionCtrl) return
        // Consume the armed flag first so any downstream signals don't re-enter.
        _quickFlyArmed = false

        _planMaster.removeAll()

        // Prefer the live vehicle position for the takeoff visual; fall back to
        // the destination if the vehicle hasn't published its coordinate yet.
        var takeoffCoord = (_checkVehicle && _checkVehicle.coordinate && _checkVehicle.coordinate.isValid)
                           ? _checkVehicle.coordinate
                           : destinationCoord

        var takeoff = _missionCtrl.insertTakeoffItem(takeoffCoord, 1, false)
        if (takeoff && takeoff.altitude && _defaultAltitude > 0) {
            takeoff.altitude.rawValue = _defaultAltitude
        }

        var wp = _missionCtrl.insertSimpleMissionItem(destinationCoord, 2, false)
        if (wp && wp.altitude && _defaultAltitude > 0) {
            wp.altitude.rawValue = _defaultAltitude
        }

        // For copters insertLandItem() actually inserts a NAV_RETURN_TO_LAUNCH
        // command (see MissionController.cc). The coordinate argument is unused
        // for RTL — it's just required by the signature.
        _missionCtrl.insertLandItem(destinationCoord, 3, false)

        deployMission()
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

        // ── BUILD | FENCE | RALLY | SAVED tab bar
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: _pad * 0.3
            spacing:          _pad * 0.35

            Repeater {
                model: [
                    { key: 0, label: "BUILD" },
                    { key: 1, label: "FENCE" },
                    { key: 2, label: "RALLY" },
                    { key: 3, label: "SAVED" }
                ]
                delegate: Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                    color:                  _activeTab === modelData.key ? _teal : _cardBg
                    border.width:           _activeTab === modelData.key ? 0 : 1
                    border.color:           Qt.rgba(1, 1, 1, 0.08)

                    QGCLabel {
                        anchors.centerIn:   parent
                        text:               modelData.label
                        color:              _activeTab === modelData.key ? "#000000" : _dimText
                        font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.62
                        font.bold:          _activeTab === modelData.key
                        font.letterSpacing: 0.3
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    _activeTab = modelData.key
                    }
                }
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
                sourceComponent: _activeTab === 0 ? buildTabComponent :
                                 _activeTab === 1 ? fenceTabComponent :
                                 _activeTab === 2 ? rallyTabComponent :
                                                    savedTabComponent
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

            // ── QUICK FLY card (works on stock PX4/ArduPilot too — not gated)
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
                                        id: wpExpanded
                                        Layout.fillWidth: true
                                        spacing: _pad * 0.5
                                        visible: _expandedWpIdx === index

                                        // Yaw (param4) fact, if this item type supports it
                                        property var _yawFact: {
                                            if (!object || !object.nanFacts) return null
                                            for (var i = 0; i < object.nanFacts.count; i++) {
                                                var f = object.nanFacts.get(i)
                                                if (f && f.name && f.name.toLowerCase().indexOf("yaw") !== -1)
                                                    return f
                                            }
                                            return null
                                        }

                                        // Hold/hover (param1) fact, present on waypoints (not takeoff)
                                        property var _holdFact: {
                                            if (!object || !object.textFieldFacts) return null
                                            for (var i = 0; i < object.textFieldFacts.count; i++) {
                                                var f = object.textFieldFacts.get(i)
                                                if (f && f.name && f.name.toLowerCase().indexOf("hold") !== -1)
                                                    return f
                                            }
                                            return null
                                        }

                                        // Advanced (camera/gimbal/radius) section open state
                                        property bool _advOpen: false

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
                                            text:           "🕐  HOVER AT POINT" + (_holdFact ? "  —  NOW " + _holdFact.rawValue.toFixed(0) + "s" : "")
                                            color:          _holdFact && _holdFact.rawValue > 0 ? _teal : _dimText
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                            font.bold:      true
                                            font.letterSpacing: 1.0
                                            Layout.topMargin: _pad * 0.3
                                            visible:        _holdFact !== null
                                        }
                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 5
                                            columnSpacing: _pad * 0.25
                                            visible: _holdFact !== null
                                            Repeater {
                                                model: [{ k: "OFF", v: 0 },
                                                        { k: "5S", v: 5 },
                                                        { k: "10S", v: 10 },
                                                        { k: "30S", v: 30 },
                                                        { k: "60S", v: 60 }]
                                                delegate: Rectangle {
                                                    // Hover = NAV_WAYPOINT param1 ("Hold"); read via object (resolves in delegates)
                                                    property var _hoverFact: {
                                                        if (!object || !object.textFieldFacts) return null
                                                        for (var i = 0; i < object.textFieldFacts.count; i++) {
                                                            var f = object.textFieldFacts.get(i)
                                                            if (f && f.name && f.name.toLowerCase().indexOf("hold") !== -1)
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
                                        // Custom hover time — type any value (overrides the presets above)
                                        // Fact lookup is local via `object` (same as the preset buttons),
                                        // which avoids QML scope-resolution issues in nested items.
                                        RowLayout {
                                            id: customHoverRow
                                            property var _holdFactLocal: {
                                                if (!object || !object.textFieldFacts) return null
                                                for (var i = 0; i < object.textFieldFacts.count; i++) {
                                                    var f = object.textFieldFacts.get(i)
                                                    if (f && f.name && f.name.toLowerCase().indexOf("hold") !== -1)
                                                        return f
                                                }
                                                return null
                                            }
                                            Layout.fillWidth: true
                                            visible:          _holdFactLocal !== null
                                            spacing:          _pad * 0.4
                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text:             "Custom hover (sec)"
                                                color:            "white"
                                                font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.55
                                            }
                                            Rectangle {
                                                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 12
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.9
                                                radius:                 ScreenTools.defaultFontPixelHeight * 0.2
                                                color:                  Qt.rgba(1, 1, 1, 0.08)
                                                border.width:           1
                                                border.color:           hoverInput.activeFocus ? _teal : Qt.rgba(1, 1, 1, 0.20)
                                                TextInput {
                                                    id:                  hoverInput
                                                    anchors.fill:        parent
                                                    anchors.margins:     _pad * 0.4
                                                    verticalAlignment:   TextInput.AlignVCenter
                                                    horizontalAlignment: TextInput.AlignHCenter
                                                    color:               "white"
                                                    font.bold:           true
                                                    font.pixelSize:      ScreenTools.defaultFontPixelHeight * 0.7
                                                    selectByMouse:       true
                                                    inputMethodHints:    Qt.ImhDigitsOnly
                                                    validator:           IntValidator { bottom: 0; top: 3600 }
                                                    text: {
                                                        var f = customHoverRow._holdFactLocal
                                                        return f ? f.rawValue.toFixed(0) : "0"
                                                    }
                                                    onActiveFocusChanged: if (activeFocus) selectAll()
                                                    onEditingFinished: {
                                                        var f = customHoverRow._holdFactLocal
                                                        if (!f) return
                                                        f.rawValue = parseInt(text.length ? text : "0")
                                                    }
                                                    Connections {
                                                        target: customHoverRow._holdFactLocal
                                                        function onRawValueChanged() {
                                                            var f = customHoverRow._holdFactLocal
                                                            hoverInput.text = f ? f.rawValue.toFixed(0) : "0"
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Yaw / heading (optional — waypoints & takeoff)
                                        // Fact lookup is local via `object`, matching the preset-button pattern.
                                        QGCLabel {
                                            text:           "🧭  YAW / HEADING"
                                            color:          _dimText
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                            font.bold:      true
                                            font.letterSpacing: 1.0
                                            Layout.topMargin: _pad * 0.3
                                            visible:        wpExpanded._yawFact !== null
                                        }
                                        // Yaw: always-editable compass heading input, 0-360°.
                                        // NaN = "auto" (face next WP). "AUTO" button clears to NaN.
                                        RowLayout {
                                            id: yawRow
                                            property var _yawFactLocal: {
                                                if (!object || !object.nanFacts) return null
                                                for (var i = 0; i < object.nanFacts.count; i++) {
                                                    var f = object.nanFacts.get(i)
                                                    if (f && f.name && f.name.toLowerCase().indexOf("yaw") !== -1)
                                                        return f
                                                }
                                                return null
                                            }
                                            Layout.fillWidth: true
                                            visible:          _yawFactLocal !== null
                                            spacing:          _pad * 0.4
                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text:             "Compass heading (0-360°)"
                                                color:            "white"
                                                font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.55
                                            }
                                            // AUTO toggle: clears yaw to NaN so PX4 uses MPC_YAW_MODE default
                                            Rectangle {
                                                id:                     yawAutoBtn
                                                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 6
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.9
                                                radius:                 ScreenTools.defaultFontPixelHeight * 0.2
                                                property bool _isAuto:  yawRow._yawFactLocal ? isNaN(yawRow._yawFactLocal.rawValue) : true
                                                color:                  _isAuto ? _tealDim : Qt.rgba(1, 1, 1, 0.04)
                                                border.width:           1
                                                border.color:           _isAuto ? _teal : Qt.rgba(1, 1, 1, 0.20)
                                                QGCLabel {
                                                    anchors.centerIn: parent
                                                    text:             "AUTO"
                                                    color:            yawAutoBtn._isAuto ? _teal : "white"
                                                    font.bold:        true
                                                    font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.55
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape:  Qt.PointingHandCursor
                                                    onClicked: {
                                                        var f = yawRow._yawFactLocal
                                                        if (f) f.rawValue = NaN
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 10
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.9
                                                radius:                 ScreenTools.defaultFontPixelHeight * 0.2
                                                color:                  Qt.rgba(1, 1, 1, 0.08)
                                                border.width:           1
                                                border.color:           yawInput.activeFocus ? _teal : Qt.rgba(1, 1, 1, 0.20)
                                                TextInput {
                                                    id:                  yawInput
                                                    anchors.fill:        parent
                                                    anchors.margins:     _pad * 0.4
                                                    verticalAlignment:   TextInput.AlignVCenter
                                                    horizontalAlignment: TextInput.AlignHCenter
                                                    color:               "white"
                                                    font.bold:           true
                                                    font.pixelSize:      ScreenTools.defaultFontPixelHeight * 0.7
                                                    selectByMouse:       true
                                                    inputMethodHints:    Qt.ImhFormattedNumbersOnly
                                                    validator:           DoubleValidator { bottom: 0; top: 360; decimals: 1 }
                                                    text: {
                                                        var f = yawRow._yawFactLocal
                                                        if (!f) return ""
                                                        var v = f.rawValue
                                                        if (isNaN(v)) return ""
                                                        var display = ((v % 360) + 360) % 360
                                                        return display.toFixed(1)
                                                    }
                                                    onActiveFocusChanged: if (activeFocus) selectAll()
                                                    onEditingFinished: {
                                                        var f = yawRow._yawFactLocal
                                                        if (!f) return
                                                        if (!text.length) { f.rawValue = NaN; return }
                                                        var v = parseFloat(text)
                                                        if (isNaN(v)) { f.rawValue = NaN; return }
                                                        v = ((v % 360) + 360) % 360
                                                        if (v > 180) v -= 360
                                                        f.rawValue = v
                                                    }
                                                    Connections {
                                                        target: yawRow._yawFactLocal
                                                        function onRawValueChanged() {
                                                            var f = yawRow._yawFactLocal
                                                            if (!f) { yawInput.text = ""; return }
                                                            var v = f.rawValue
                                                            if (isNaN(v)) { yawInput.text = ""; return }
                                                            var d = ((v % 360) + 360) % 360
                                                            yawInput.text = d.toFixed(1)
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Advanced (camera · gimbal · acceptance/pass radius) — collapsible
                                        Rectangle {
                                            Layout.fillWidth:       true
                                            Layout.topMargin:       _pad * 0.3
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                                            radius:                 ScreenTools.defaultFontPixelHeight * 0.2
                                            color:                  advHdrArea.containsMouse ? _tealDim : Qt.rgba(1, 1, 1, 0.04)
                                            border.width:           1
                                            border.color:           Qt.rgba(1, 1, 1, 0.10)
                                            RowLayout {
                                                anchors.fill:        parent
                                                anchors.leftMargin:  _pad * 0.5
                                                anchors.rightMargin: _pad * 0.5
                                                QGCLabel {
                                                    Layout.fillWidth:   true
                                                    text:               "⚙  ADVANCED  (camera · gimbal · radius)"
                                                    color:              _dimText
                                                    font.bold:          true
                                                    font.letterSpacing: 1.0
                                                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.55
                                                }
                                                QGCLabel {
                                                    text:           wpExpanded._advOpen ? "⌃" : "⌄"
                                                    color:          _teal
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9
                                                }
                                            }
                                            MouseArea {
                                                id:           advHdrArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape:  Qt.PointingHandCursor
                                                onClicked:    wpExpanded._advOpen = !wpExpanded._advOpen
                                            }
                                        }
                                        // Advanced content — native ColumnLayout children so they stay clickable
                                        ColumnLayout {
                                            id:               wpAdvCol
                                            Layout.fillWidth: true
                                            visible:          wpExpanded._advOpen
                                            spacing:          _pad * 0.4

                                            property var _cam: object.cameraSection

                                            // Hold / Acceptance / Pass radius — explicit label + input rows
                                            QGCLabel {
                                                text:               "📐  HOLD · ACCEPTANCE · PASS RADIUS"
                                                color:              _dimText
                                                font.bold:          true
                                                font.letterSpacing: 1.0
                                                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.55
                                            }
                                            Repeater {
                                                model: object.textFieldFacts
                                                delegate: RowLayout {
                                                    Layout.fillWidth:       true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.9
                                                    spacing:                _pad * 0.4
                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        text:             object.name
                                                        color:            "white"
                                                        font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.6
                                                    }
                                                    FactTextField {
                                                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 12
                                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.6
                                                        fact:                   object
                                                        textColor:              "white"
                                                    }
                                                }
                                            }
                                            // Acceptance & Pass radius (firmware hides these from textFieldFacts) — waypoints only
                                            Repeater {
                                                model: (object.command === 16)   // MAV_CMD_NAV_WAYPOINT
                                                       ? [ { lbl: "Acceptance (m)", f: object.acceptanceRadius },
                                                           { lbl: "Pass Radius (m)", f: object.passRadius } ]
                                                       : []
                                                delegate: RowLayout {
                                                    Layout.fillWidth:       true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.9
                                                    spacing:                _pad * 0.4
                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        text:             modelData.lbl
                                                        color:            "white"
                                                        font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.6
                                                    }
                                                    FactTextField {
                                                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 12
                                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.6
                                                        fact:                   modelData.f
                                                        textColor:              "white"
                                                    }
                                                }
                                            }

                                            // Camera action (buttons — this panel has no dropdowns)
                                            QGCLabel {
                                                text:               "📷  CAMERA"
                                                color:              _dimText
                                                font.bold:          true
                                                font.letterSpacing: 1.0
                                                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.55
                                                visible:            wpAdvCol._cam && wpAdvCol._cam.available
                                            }
                                            GridLayout {
                                                Layout.fillWidth: true
                                                columns:          2
                                                columnSpacing:    _pad * 0.25
                                                rowSpacing:       _pad * 0.25
                                                visible:          wpAdvCol._cam && wpAdvCol._cam.available
                                                Repeater {
                                                    model: wpAdvCol._cam ? wpAdvCol._cam.cameraAction.enumStrings : []
                                                    delegate: Rectangle {
                                                        Layout.fillWidth:       true
                                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.7
                                                        property bool _sel: wpAdvCol._cam && wpAdvCol._cam.cameraAction.enumIndex === index
                                                        radius:       ScreenTools.defaultFontPixelHeight * 0.2
                                                        color:        _sel ? _tealDim : Qt.rgba(1, 1, 1, 0.04)
                                                        border.width: 1
                                                        border.color: _sel ? _teal : Qt.rgba(1, 1, 1, 0.10)
                                                        QGCLabel {
                                                            anchors.fill:        parent
                                                            anchors.margins:     _pad * 0.2
                                                            horizontalAlignment: Text.AlignHCenter
                                                            verticalAlignment:   Text.AlignVCenter
                                                            text:                modelData
                                                            color:               _sel ? _teal : "white"
                                                            font.bold:           true
                                                            font.pixelSize:      ScreenTools.defaultFontPixelHeight * 0.5
                                                            elide:               Text.ElideRight
                                                        }
                                                        MouseArea {
                                                            anchors.fill:    parent
                                                            preventStealing: true
                                                            cursorShape:     Qt.PointingHandCursor
                                                            onClicked: if (wpAdvCol._cam) wpAdvCol._cam.cameraAction.value = wpAdvCol._cam.cameraAction.enumValues[index]
                                                        }
                                                    }
                                                }
                                            }
                                            LabelledFactTextField {
                                                Layout.fillWidth: true
                                                label:            qsTr("Interval (s)")
                                                fact:             wpAdvCol._cam ? wpAdvCol._cam.cameraPhotoIntervalTime : null
                                                visible:          wpAdvCol._cam && wpAdvCol._cam.cameraAction.rawValue === 1
                                            }
                                            LabelledFactTextField {
                                                Layout.fillWidth: true
                                                label:            qsTr("Distance (m)")
                                                fact:             wpAdvCol._cam ? wpAdvCol._cam.cameraPhotoIntervalDistance : null
                                                visible:          wpAdvCol._cam && wpAdvCol._cam.cameraAction.rawValue === 2
                                            }

                                            // Gimbal (checkbox + pitch/yaw fields)
                                            QGCCheckBox {
                                                id:        gimbalChk
                                                text:      qsTr("Gimbal")
                                                visible:   wpAdvCol._cam && wpAdvCol._cam.available
                                                checked:   wpAdvCol._cam ? wpAdvCol._cam.specifyGimbal : false
                                                onClicked: if (wpAdvCol._cam) wpAdvCol._cam.specifyGimbal = checked
                                            }
                                            LabelledFactTextField {
                                                Layout.fillWidth: true
                                                label:            qsTr("Pitch")
                                                fact:             wpAdvCol._cam ? wpAdvCol._cam.gimbalPitch : null
                                                enabled:          gimbalChk.checked
                                                visible:          gimbalChk.visible && gimbalChk.checked
                                            }
                                            LabelledFactTextField {
                                                Layout.fillWidth: true
                                                label:            qsTr("Yaw")
                                                fact:             wpAdvCol._cam ? wpAdvCol._cam.gimbalYaw : null
                                                enabled:          gimbalChk.checked
                                                visible:          gimbalChk.visible && gimbalChk.checked
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
                                visible:        _companionEnabled   // patrol loop — companion-computer only
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
                                visible: _companionEnabled   // patrol loop config — companion-computer only
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

                        // Schedule subsection (Autonomous Patrol — companion-computer feature)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: _companionEnabled ? _pad * 0.4 : 0
                            Layout.preferredHeight: schedCol.implicitHeight + _pad * 1.2
                            radius: ScreenTools.defaultFontPixelHeight * 0.25
                            color:  Qt.rgba(1, 1, 1, 0.02)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            visible: _companionEnabled

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

    // ── Fence tab
    Component {
        id: fenceTabComponent

        ColumnLayout {
            id:      fenceRoot
            width:   parent ? parent.width : 100
            spacing: _pad * 0.6

            // Returns the map viewport corners — new fences span the visible area (same as QGC).
            function _viewportCorners() {
                var vp = editorMap.centerViewport
                return {
                    tl: editorMap.toCoordinate(Qt.point(vp.x, vp.y), false),
                    br: editorMap.toCoordinate(Qt.point(vp.x + vp.width, vp.y + vp.height), false)
                }
            }

            Item { Layout.preferredHeight: _pad * 0.4 }

            // ── Intro / support state
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: fenceIntroCol.implicitHeight + _pad * 2
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.10)

                ColumnLayout {
                    id: fenceIntroCol
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: _pad
                    spacing:         _pad * 0.4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.5
                        QGCLabel { text: "🛡"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9 }
                        QGCLabel {
                            text:           "GEOFENCE"
                            color:          _teal
                            font.bold:      true
                            font.letterSpacing: 1.0
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                            Layout.fillWidth: true
                        }
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode:         Text.WordWrap
                        color:            _dimText
                        font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.55
                        text: _fenceCtrl && _fenceCtrl.supported
                              ? "Set a virtual fence around the area you want to fly in. Drag the fence handles on the map to reshape."
                              : "This vehicle does not support GeoFence."
                    }
                }
            }

            // Everything below requires fence support
            ColumnLayout {
                Layout.fillWidth: true
                spacing:          _pad * 0.6
                visible:          _fenceCtrl && _fenceCtrl.supported

                // ── Insert GeoFence — buttons map to addInclusionPolygon / addInclusionCircle
                QGCLabel {
                    text:               "INSERT GEOFENCE"
                    color:              _dimText
                    font.bold:          true
                    font.letterSpacing: 1.0
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.55
                    Layout.topMargin:   _pad * 0.3
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: _pad * 0.5

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                        radius: ScreenTools.defaultFontPixelHeight * 0.25
                        color:  addPolyArea.containsMouse ? _tealDim : _cardBg
                        border.width: 1
                        border.color: _tealBorder
                        QGCLabel {
                            anchors.centerIn: parent
                            text: "▱  Polygon Fence"
                            color: _teal
                            font.bold: true
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                        }
                        MouseArea {
                            id: addPolyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                var c = fenceRoot._viewportCorners()
                                _fenceCtrl.addInclusionPolygon(c.tl, c.br)
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                        radius: ScreenTools.defaultFontPixelHeight * 0.25
                        color:  addCircArea.containsMouse ? _tealDim : _cardBg
                        border.width: 1
                        border.color: _tealBorder
                        QGCLabel {
                            anchors.centerIn: parent
                            text: "◯  Circular Fence"
                            color: _teal
                            font.bold: true
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                        }
                        MouseArea {
                            id: addCircArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                var c = fenceRoot._viewportCorners()
                                _fenceCtrl.addInclusionCircle(c.tl, c.br)
                            }
                        }
                    }
                }

                // ── Polygon fences list
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.06); Layout.topMargin: _pad * 0.3 }
                QGCLabel {
                    text:               "POLYGON FENCES"
                    color:              _dimText
                    font.bold:          true
                    font.letterSpacing: 1.0
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.55
                }
                QGCLabel {
                    text:           "None"
                    color:          Qt.rgba(1, 1, 1, 0.3)
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                    visible:        !_fenceCtrl.polygons || _fenceCtrl.polygons.count === 0
                }
                // Header row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: _pad * 0.4
                    visible: _fenceCtrl.polygons && _fenceCtrl.polygons.count > 0
                    QGCLabel { text: "#";        color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 3 }
                    QGCLabel { text: "Include";  color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7; horizontalAlignment: Text.AlignHCenter }
                    QGCLabel { text: "Edit";     color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5; horizontalAlignment: Text.AlignHCenter }
                    Item { Layout.fillWidth: true }
                    QGCLabel { text: "Delete";   color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; horizontalAlignment: Text.AlignRight }
                }
                Repeater {
                    model: _fenceCtrl.polygons
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.4

                        QGCLabel {
                            text: "P" + (index + 1)
                            color: "white"
                            font.bold: true
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 3
                        }
                        // Inclusion (keep-in) vs exclusion (keep-out) fence
                        QGCCheckBox {
                            checked:          object.inclusion
                            onClicked:        object.inclusion = checked
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7
                            Layout.alignment: Qt.AlignHCenter
                        }
                        // Edit radio — makes only this polygon interactive so its vertices are draggable on the map
                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 5
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.4
                            color: "transparent"
                            Rectangle {
                                anchors.centerIn: parent
                                width:  ScreenTools.defaultFontPixelHeight * 1.1
                                height: width
                                radius: width / 2
                                color:  "transparent"
                                border.width: 1.5
                                border.color: object.interactive ? _teal : Qt.rgba(1, 1, 1, 0.3)
                                // Filled dot when this polygon is the interactive one
                                Rectangle {
                                    anchors.centerIn: parent
                                    width:  parent.width * 0.5
                                    height: width
                                    radius: width / 2
                                    color:  _teal
                                    visible: object.interactive
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                // Clear others first so only one shape is editable at a time (QGC behaviour)
                                onClicked: {
                                    _fenceCtrl.clearAllInteractive()
                                    object.interactive = true
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        // Delete this polygon
                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.7
                            radius: ScreenTools.defaultFontPixelHeight * 0.2
                            color:  delPolyArea.containsMouse ? Qt.rgba(1, 0.32, 0.32, 0.16) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 0.32, 0.32, 0.4)
                            QGCLabel { anchors.centerIn: parent; text: "Del"; color: _errColor; font.bold: true; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55 }
                            MouseArea {
                                id: delPolyArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    _fenceCtrl.deletePolygon(index)
                            }
                        }
                    }
                }

                // ── Circular fences list
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.06); Layout.topMargin: _pad * 0.3 }
                QGCLabel {
                    text:               "CIRCULAR FENCES"
                    color:              _dimText
                    font.bold:          true
                    font.letterSpacing: 1.0
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.55
                }
                QGCLabel {
                    text:           "None"
                    color:          Qt.rgba(1, 1, 1, 0.3)
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                    visible:        !_fenceCtrl.circles || _fenceCtrl.circles.count === 0
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: _pad * 0.4
                    visible: _fenceCtrl.circles && _fenceCtrl.circles.count > 0
                    QGCLabel { text: "#";       color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 3 }
                    QGCLabel { text: "Inc";     color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4; horizontalAlignment: Text.AlignHCenter }
                    QGCLabel { text: "Edit";    color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4; horizontalAlignment: Text.AlignHCenter }
                    QGCLabel { text: "Radius";  color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                    QGCLabel { text: "Del";     color: _dimText; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7; horizontalAlignment: Text.AlignRight }
                }
                Repeater {
                    model: _fenceCtrl.circles
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.4

                        QGCLabel {
                            text: "C" + (index + 1)
                            color: "white"
                            font.bold: true
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 3
                        }
                        // Inclusion (keep-in) vs exclusion (keep-out) fence
                        QGCCheckBox {
                            checked:          object.inclusion
                            onClicked:        object.inclusion = checked
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4
                            Layout.alignment: Qt.AlignHCenter
                        }
                        // Edit radio — makes only this circle interactive so it can be dragged/resized on the map
                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 4
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.4
                            color: "transparent"
                            Rectangle {
                                anchors.centerIn: parent
                                width:  ScreenTools.defaultFontPixelHeight * 1.1
                                height: width
                                radius: width / 2
                                color:  "transparent"
                                border.width: 1.5
                                border.color: object.interactive ? _teal : Qt.rgba(1, 1, 1, 0.3)
                                // Filled dot when this circle is the interactive one
                                Rectangle {
                                    anchors.centerIn: parent
                                    width:  parent.width * 0.5
                                    height: width
                                    radius: width / 2
                                    color:  _teal
                                    visible: object.interactive
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                // Clear others first so only one shape is editable at a time (QGC behaviour)
                                onClicked: {
                                    _fenceCtrl.clearAllInteractive()
                                    object.interactive = true
                                }
                            }
                        }
                        // Circle radius fact — edits the same value as dragging the ring on the map
                        FactTextField {
                            fact:                   object.radius
                            Layout.fillWidth:       true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.7
                        }
                        // Delete this circle
                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 7
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.7
                            radius: ScreenTools.defaultFontPixelHeight * 0.2
                            color:  delCircArea.containsMouse ? Qt.rgba(1, 0.32, 0.32, 0.16) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 0.32, 0.32, 0.4)
                            QGCLabel { anchors.centerIn: parent; text: "Del"; color: _errColor; font.bold: true; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55 }
                            MouseArea {
                                id: delCircArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    _fenceCtrl.deleteCircle(index)
                            }
                        }
                    }
                }

                // ── Breach return point — where the vehicle heads if it breaches the fence
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.06); Layout.topMargin: _pad * 0.3 }
                QGCLabel {
                    text:               "BREACH RETURN POINT"
                    color:              _dimText
                    font.bold:          true
                    font.letterSpacing: 1.0
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.55
                }
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    radius: ScreenTools.defaultFontPixelHeight * 0.25
                    color:  breachArea.containsMouse ? _tealDim : _cardBg
                    border.width: 1
                    border.color: _tealBorder
                    QGCLabel {
                        anchors.centerIn: parent
                        text:  _fenceCtrl.breachReturnPoint.isValid ? "✕  Remove Breach Return Point" : "＋  Add Breach Return Point"
                        color: _fenceCtrl.breachReturnPoint.isValid ? _errColor : _teal
                        font.bold: true
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                    }
                    MouseArea {
                        id: breachArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        // Toggle: an invalid coordinate clears the point, map center sets it (same as QGC)
                        onClicked: {
                            if (_fenceCtrl.breachReturnPoint.isValid)
                                _fenceCtrl.breachReturnPoint = QtPositioning.coordinate()
                            else
                                _fenceCtrl.breachReturnPoint = editorMap.center
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: _pad * 0.4
                    visible: _fenceCtrl.breachReturnPoint.isValid
                    QGCLabel {
                        text: "Altitude (m)"
                        color: "white"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                        Layout.fillWidth: true
                    }
                    FactTextField {
                        fact:                   _fenceCtrl.breachReturnAltitude
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 14
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.9
                    }
                }
            }

            Item { Layout.preferredHeight: _pad * 1.5 }
        }
    }

    // ── Rally tab
    Component {
        id: rallyTabComponent

        ColumnLayout {
            width:   parent ? parent.width : 100
            spacing: _pad * 0.6

            Item { Layout.preferredHeight: _pad * 0.4 }

            // ── Intro / support state
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: rallyIntroCol.implicitHeight + _pad * 2
                radius:                 ScreenTools.defaultFontPixelHeight * 0.35
                color:                  _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.10)

                ColumnLayout {
                    id: rallyIntroCol
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: _pad
                    spacing:         _pad * 0.4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.5
                        QGCLabel { text: "🚩"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9 }
                        QGCLabel {
                            text:           "RALLY POINTS"
                            color:          _teal
                            font.bold:      true
                            font.letterSpacing: 1.0
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                            Layout.fillWidth: true
                        }
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode:         Text.WordWrap
                        color:            _dimText
                        font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.55
                        text: _rallyCtrl && _rallyCtrl.supported
                              ? "Rally points are alternate landing points used during a Return to Launch (RTL). Tap the map to add one, or use the button below."
                              : "This vehicle does not support Rally Points."
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing:          _pad * 0.6
                visible:          _rallyCtrl && _rallyCtrl.supported

                // Add at map center
                Rectangle {
                    Layout.fillWidth:       true
                    Layout.topMargin:       _pad * 0.2
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    radius: ScreenTools.defaultFontPixelHeight * 0.25
                    color:  addRallyArea.containsMouse ? _tealDim : _cardBg
                    border.width: 1
                    border.color: _tealBorder
                    QGCLabel {
                        anchors.centerIn: parent
                        text: "＋  Add Rally Point (map center)"
                        color: _teal
                        font.bold: true
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                    }
                    MouseArea {
                        id: addRallyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        // Convenience add; tapping the map also adds points while the RALLY tab is active
                        onClicked:    _rallyCtrl.addPoint(editorMap.center)
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.06); Layout.topMargin: _pad * 0.3 }

                QGCLabel {
                    text:           "None yet — tap the map or use the button above"
                    color:          Qt.rgba(1, 1, 1, 0.3)
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                    visible:        !_rallyCtrl.points || _rallyCtrl.points.count === 0
                }

                // One card per rally point (mirrors RallyPointItemEditor.qml)
                Repeater {
                    model: _rallyCtrl.points
                    delegate: Rectangle {
                        id: rallyCard
                        Layout.fillWidth:       true
                        Layout.preferredHeight: rallyCardCol.implicitHeight + _pad
                        radius:        ScreenTools.defaultFontPixelHeight * 0.25
                        color:         Qt.rgba(1, 1, 1, 0.03)
                        border.width:  1
                        // Highlight the card the controller currently considers selected
                        property bool _isCurrent: object === _rallyCtrl.currentRallyPoint
                        border.color:  _isCurrent ? _teal : Qt.rgba(1, 1, 1, 0.08)

                        // Background tap selects this point (buttons/fields above still get their own clicks)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    _rallyCtrl.currentRallyPoint = object
                        }

                        ColumnLayout {
                            id: rallyCardCol
                            anchors.left:    parent.left
                            anchors.right:   parent.right
                            anchors.top:     parent.top
                            anchors.margins: _pad * 0.6
                            spacing:         _pad * 0.4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: _pad * 0.5

                                // "R#" badge
                                Rectangle {
                                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.5
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                                    radius: width / 2
                                    color:  _teal
                                    QGCLabel {
                                        anchors.centerIn: parent
                                        text: "R" + (index + 1)
                                        color: "#000000"
                                        font.bold: true
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                    }
                                }
                                QGCLabel {
                                    text: "Rally Point " + (index + 1)
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                    Layout.fillWidth: true
                                }
                                // Delete this rally point
                                Rectangle {
                                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.7
                                    radius: ScreenTools.defaultFontPixelHeight * 0.2
                                    color:  delRallyArea.containsMouse ? Qt.rgba(1, 0.32, 0.32, 0.16) : Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 0.32, 0.32, 0.4)
                                    QGCLabel { anchors.centerIn: parent; text: "Del"; color: _errColor; font.bold: true; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55 }
                                    MouseArea {
                                        id: delRallyArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape:  Qt.PointingHandCursor
                                        onClicked:    _rallyCtrl.removePoint(object)
                                    }
                                }
                            }

                            // Editable lat/lon/alt facts — only for the selected point (same facts QGC edits)
                            Repeater {
                                model: rallyCard._isCurrent && object ? object.textFieldFacts : 0
                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    spacing: _pad * 0.4
                                    QGCLabel {
                                        text: modelData.name
                                        color: "white"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                        Layout.fillWidth: true
                                    }
                                    FactTextField {
                                        fact:                   modelData
                                        showUnits:              true
                                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 16
                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: _pad * 1.5 }
        }
    }
}
