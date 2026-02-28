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
    property int    _activeTab:       0   // 0=CREATE, 1=SAVED
    property string _routeName:       ""
    property var    _selectedDroneIds: []
    property bool   _autoTakeoff:     true
    property bool   _autoRTL:         true
    property bool   _lowBatterySafe:  true
    property bool   _scheduleEnabled: false
    property string _startTime:       ""
    property string _endTime:         ""
    property bool   _deployPending:   false
    property bool   _scheduleSaved:   false

    // Feedback timer for schedule save
    Timer {
        id: scheduleSavedTimer
        interval: 2000
        onTriggered: root._scheduleSaved = false
    }

    // Switch to FlyView when upload completes after Deploy
    Connections {
        target: _planMaster
        function onSyncInProgressChanged() {
            if (!_planMaster.syncInProgress && root._deployPending) {
                root._deployPending = false
                mainWindow.showFlyView()
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

    // Waypoint count (subtract home position item)
    readonly property int _waypointCount: _missionCtrl ? Math.max(0, _missionCtrl.visualItems.count - 1) : 0

    // Find the takeoff item (first non-home item) for altitude binding
    property var _takeoffItem: {
        if (!_missionCtrl || !_missionCtrl.visualItems) return null
        for (var i = 1; i < _missionCtrl.visualItems.count; i++) {
            var item = _missionCtrl.visualItems.get(i)
            if (item && item.altitude) return item
        }
        return null
    }

    function toggleDrone(vehicleId) {
        var ids = _selectedDroneIds.slice()
        var idx = ids.indexOf(vehicleId)
        if (idx >= 0) ids.splice(idx, 1)
        else ids.push(vehicleId)
        _selectedDroneIds = ids
    }

    function isDroneSelected(vehicleId) {
        return _selectedDroneIds.indexOf(vehicleId) >= 0
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

        // ── HEADER ──
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
                    text:               "MISSION BUILDER"
                    color:              _teal
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.95
                    font.bold:          true
                    font.letterSpacing: 1.2
                }
                QGCLabel {
                    text:           "Plan patrols, inspections & autonomous operations"
                    color:          _dimText
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                }
            }
        }

        // ── CREATE | SAVED tab bar ──
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
                    text:             "CREATE"
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
                sourceComponent: _activeTab === 0 ? createTabComponent : savedTabComponent
            }
        }
    }

    // ══════════════════════════════════════════════
    // CREATE TAB
    // ══════════════════════════════════════════════
    Component {
        id: createTabComponent

        ColumnLayout {
            width:   parent ? parent.width : 100
            spacing: _pad * 0.4

            // ── ROUTE NAME ──
            QGCLabel {
                text:               "ROUTE NAME"
                color:              _teal
                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                font.bold:          true
                font.letterSpacing: 0.8
                Layout.topMargin:   _pad * 0.5
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.10)

                TextInput {
                    anchors.fill:           parent
                    anchors.leftMargin:     _pad * 1.2
                    anchors.rightMargin:    _pad * 1.2
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "white"
                    font.pixelSize:         ScreenTools.defaultFontPixelHeight * 0.7
                    text:                   _routeName
                    onTextChanged:          _routeName = text
                    clip:                   true

                    Text {
                        anchors.fill:          parent
                        verticalAlignment:     Text.AlignVCenter
                        text:                  "e.g., Perimeter Patrol Alpha"
                        color:                 Qt.rgba(1, 1, 1, 0.25)
                        font:                  parent.font
                        visible:               !parent.text && !parent.activeFocus
                    }
                }
            }

            // ── ASSIGN DRONES ──
            Item { Layout.preferredHeight: _sectionGap * 0.5 }

            RowLayout {
                Layout.fillWidth: true
                QGCLabel {
                    text:               "ASSIGN DRONES"
                    color:              _teal
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                    font.bold:          true
                    font.letterSpacing: 0.8
                    Layout.fillWidth:   true
                }
                QGCLabel {
                    text:           _selectedDroneIds.length + " selected"
                    color:          _dimText
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                }
            }

            // Drone cards
            Repeater {
                model: _vehicles

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: droneCardCol.implicitHeight + _pad * 1.6
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                    color:                  _droneSelected ? Qt.rgba(0, 0.749, 1.0, 0.06) : Qt.rgba(1, 1, 1, 0.03)
                    border.width:           1
                    border.color:           _droneSelected ? _tealBorder : Qt.rgba(1, 1, 1, 0.06)

                    property var  _vehicle:       object
                    property bool _droneSelected: root.isDroneSelected(_vehicle ? _vehicle.id : -1)
                    property bool _isFlying:      _vehicle ? (_vehicle.armed && _vehicle.flying) : false
                    property bool _isArmed:       _vehicle ? _vehicle.armed : false

                    property string _statusText: {
                        if (_isFlying) return "ACTIVE"
                        if (_isArmed)  return "ARMED"
                        return "IDLE"
                    }
                    property color _statusColor: {
                        if (_isFlying) return _okColor
                        if (_isArmed)  return _warnColor
                        return _dimText
                    }

                    ColumnLayout {
                        id: droneCardCol
                        anchors.left:    parent.left
                        anchors.right:   parent.right
                        anchors.top:     parent.top
                        anchors.margins: _pad * 0.8
                        spacing:         _pad * 0.3

                        // Name row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: _pad * 0.5

                            // Selection checkbox
                            Rectangle {
                                width:        ScreenTools.defaultFontPixelHeight * 0.9
                                height:       width
                                radius:       ScreenTools.defaultFontPixelHeight * 0.15
                                color:        _droneSelected ? _teal : "transparent"
                                border.width: 1
                                border.color: _droneSelected ? _teal : _dimText

                                QGCLabel {
                                    anchors.centerIn: parent
                                    text:      "\u2713"
                                    color:     "#000000"
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                    visible:   _droneSelected
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 0
                                QGCLabel {
                                    text:           _vehicle ? qsTr("Vehicle") + " " + _vehicle.id : ""
                                    color:          "white"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                                    font.bold:      true
                                }
                                QGCLabel {
                                    text:           _vehicle ? _vehicle.vehicleTypeString : ""
                                    color:          _dimText
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                }
                            }

                            // Status badge
                            Rectangle {
                                width:  statusLabel.implicitWidth + _pad * 1.2
                                height: statusLabel.implicitHeight + _pad * 0.4
                                radius: height / 2
                                color:  Qt.rgba(_statusColor.r, _statusColor.g, _statusColor.b, 0.15)
                                border.width: 1
                                border.color: Qt.rgba(_statusColor.r, _statusColor.g, _statusColor.b, 0.4)

                                QGCLabel {
                                    id: statusLabel
                                    anchors.centerIn: parent
                                    text:           _statusText
                                    color:          _statusColor
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.45
                                    font.bold:      true
                                    font.letterSpacing: 0.3
                                }
                            }
                        }

                        // Telemetry row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: _pad * 1.2

                            // Battery
                            Row {
                                spacing: _pad * 0.3
                                QGCColoredImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: ScreenTools.defaultFontPixelHeight * 0.6; height: width
                                    source: "/qmlimages/Battery.svg"; color: "white"; fillMode: Image.PreserveAspectFit
                                }
                                QGCLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: _vehicle && _vehicle.batteries.count > 0
                                          ? _vehicle.batteries.get(0).percentRemaining.valueString + "%" : "--"
                                    color: "white"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                }
                            }
                            // Signal
                            Row {
                                spacing: _pad * 0.3
                                QGCColoredImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: ScreenTools.defaultFontPixelHeight * 0.6; height: width
                                    source: "/qmlimages/Signal100.svg"; color: "white"; fillMode: Image.PreserveAspectFit
                                }
                                QGCLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: _vehicle ? (_vehicle.rcRSSI > 0 ? _vehicle.rcRSSI + "%" : "95%") : "--"
                                    color: "white"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                }
                            }
                            // SAT
                            Row {
                                spacing: _pad * 0.3
                                QGCColoredImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: ScreenTools.defaultFontPixelHeight * 0.6; height: width
                                    source: "/qmlimages/Gps.svg"; color: "white"; fillMode: Image.PreserveAspectFit
                                }
                                QGCLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: _vehicle && _vehicle.gps
                                          ? _vehicle.gps.count.rawValue + " SAT" : "-- SAT"
                                    color: "white"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.toggleDrone(_vehicle ? _vehicle.id : -1)
                    }
                }
            }

            // Warning if no drones selected
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  Qt.rgba(1, 0.6, 0, 0.08)
                border.width:           1
                border.color:           Qt.rgba(1, 0.6, 0, 0.25)
                visible:                _vehicles && _vehicles.count > 0 && _selectedDroneIds.length === 0

                RowLayout {
                    anchors.centerIn: parent
                    spacing: _pad * 0.4
                    QGCLabel {
                        text:           "\u26A0"
                        color:          _warnColor
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                    }
                    QGCLabel {
                        text:           "Select at least one drone for this mission"
                        color:          _warnColor
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                    }
                }
            }

            // ── LOOP MODE ──
            Item { Layout.preferredHeight: _sectionGap * 0.5 }

            RowLayout {
                Layout.fillWidth: true
                spacing: _pad * 0.5
                QGCColoredImage {
                    width: ScreenTools.defaultFontPixelHeight * 0.7; height: width
                    source: "/qmlimages/Plan.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                }
                QGCLabel {
                    text:               "LOOP MODE"
                    color:              _teal
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                    font.bold:          true
                    font.letterSpacing: 0.8
                }
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.10)

                QGCComboBox {
                    id: loopModeComboBox
                    anchors.fill:       parent
                    anchors.margins:    1
                    model:              ["FOREVER (CONTINUOUS)", "LOOP N TIMES", "RUN FOR DURATION"]
                    currentIndex:       _patrolCtrl ? _patrolCtrl.loopsMode : 0
                    onActivated: function(index) {
                        if (_patrolCtrl) _patrolCtrl.loopsMode = index
                    }
                }
            }

            // Loop count input (visible when LOOP N TIMES selected)
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.10)
                visible:                _patrolCtrl && loopModeComboBox.currentIndex === 1

                RowLayout {
                    anchors.fill:    parent
                    anchors.margins: _pad * 0.8

                    QGCLabel {
                        text:             "Number of Loops"
                        color:            "white"
                        font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.65
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width:        ScreenTools.defaultFontPixelWidth * 8
                        height:       ScreenTools.defaultFontPixelHeight * 1.8
                        radius:       ScreenTools.defaultFontPixelHeight * 0.2
                        color:        Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: _tealBorder

                        TextInput {
                            anchors.fill:        parent
                            anchors.leftMargin:  _pad
                            anchors.rightMargin: _pad
                            verticalAlignment:   Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            color:               "white"
                            font.pixelSize:      ScreenTools.defaultFontPixelHeight * 0.7
                            font.bold:           true
                            font.family:         ScreenTools.normalFontFamily
                            inputMethodHints:    Qt.ImhDigitsOnly
                            text:                _patrolCtrl ? _patrolCtrl.loops.toString() : "3"
                            validator:           IntValidator { bottom: 1; top: 999 }
                            onEditingFinished:   if (_patrolCtrl) _patrolCtrl.loops = parseInt(text)
                        }
                    }
                }
            }

            // Duration input (visible when RUN FOR DURATION selected)
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.10)
                visible:                _patrolCtrl && loopModeComboBox.currentIndex === 2

                RowLayout {
                    anchors.fill:    parent
                    anchors.margins: _pad * 0.8

                    QGCLabel {
                        text:             "Duration (minutes)"
                        color:            "white"
                        font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.65
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width:        ScreenTools.defaultFontPixelWidth * 8
                        height:       ScreenTools.defaultFontPixelHeight * 1.8
                        radius:       ScreenTools.defaultFontPixelHeight * 0.2
                        color:        Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: _tealBorder

                        TextInput {
                            anchors.fill:        parent
                            anchors.leftMargin:  _pad
                            anchors.rightMargin: _pad
                            verticalAlignment:   Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            color:               "white"
                            font.pixelSize:      ScreenTools.defaultFontPixelHeight * 0.7
                            font.bold:           true
                            font.family:         ScreenTools.normalFontFamily
                            inputMethodHints:    Qt.ImhDigitsOnly
                            text:                _patrolCtrl ? _patrolCtrl.duration.toString() : "20"
                            validator:           IntValidator { bottom: 1; top: 300 }
                            onEditingFinished:   if (_patrolCtrl) _patrolCtrl.duration = parseInt(text)
                        }
                    }
                }
            }

            // ── PATROL SPEED ──
            Item { Layout.preferredHeight: _sectionGap * 0.3 }

            RowLayout {
                Layout.fillWidth: true
                spacing: _pad * 0.5

                QGCColoredImage {
                    width: ScreenTools.defaultFontPixelHeight * 0.7; height: width
                    source: "/qmlimages/Gears.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                }
                QGCLabel {
                    text:               "PATROL SPEED"
                    color:              _teal
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                    font.bold:          true
                    font.letterSpacing: 0.8
                    Layout.fillWidth:   true
                }
                QGCLabel {
                    text:           (_patrolCtrl ? _patrolCtrl.speed.toFixed(1) : "5.0") + " m/s"
                    color:          _dimText
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                }
            }

            QGCSlider {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.0
                from:                   1
                to:                     15
                value:                  _patrolCtrl ? _patrolCtrl.speed : 5
                onPressedChanged:       if (!pressed && _patrolCtrl) _patrolCtrl.speed = value
            }

            // ── MISSION OPTIONS ──
            Item { Layout.preferredHeight: _sectionGap * 0.5 }

            QGCLabel {
                text:               "MISSION OPTIONS"
                color:              _teal
                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                font.bold:          true
                font.letterSpacing: 0.8
            }

            // Auto Takeoff
            Item {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2

                QGCLabel {
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   "Auto Takeoff"
                    color:                  "white"
                    font.pixelSize:         ScreenTools.defaultFontPixelHeight * 0.7
                }
                QGCCheckBoxSlider {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked:                _autoTakeoff
                    onClicked:              _autoTakeoff = checked
                }
            }

            // Takeoff Altitude
            Item {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.5
                visible:                _autoTakeoff

                QGCLabel {
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   "Takeoff Altitude"
                    color:                  "white"
                    font.pixelSize:         ScreenTools.defaultFontPixelHeight * 0.7
                }

                Row {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing:                _pad * 0.5

                    Rectangle {
                        width:          ScreenTools.defaultFontPixelWidth * 8
                        height:         ScreenTools.defaultFontPixelHeight * 1.8
                        radius:         ScreenTools.defaultFontPixelHeight * 0.2
                        color:          Qt.rgba(1, 1, 1, 0.06)
                        border.width:   1
                        border.color:   _tealBorder

                        TextInput {
                            id:                     takeoffAltInput
                            anchors.fill:           parent
                            anchors.leftMargin:     _pad
                            anchors.rightMargin:    _pad
                            verticalAlignment:      Text.AlignVCenter
                            horizontalAlignment:    Text.AlignRight
                            color:                  "white"
                            font.pixelSize:         ScreenTools.defaultFontPixelHeight * 0.7
                            font.bold:              true
                            font.family:            ScreenTools.normalFontFamily
                            inputMethodHints:       Qt.ImhFormattedNumbersOnly
                            text:                   _takeoffItem ? _takeoffItem.altitude.value.toFixed(1) : "10.0"
                            onEditingFinished: {
                                if (_takeoffItem) {
                                    _takeoffItem.altitude.value = parseFloat(text)
                                }
                            }
                        }
                    }

                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text:           "m"
                        color:          _dimText
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                    }
                }
            }

            // Auto RTL
            Item {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2

                QGCLabel {
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   "Auto RTL"
                    color:                  "white"
                    font.pixelSize:         ScreenTools.defaultFontPixelHeight * 0.7
                }
                QGCCheckBoxSlider {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked:                _autoRTL
                    onClicked:              _autoRTL = checked
                }
            }

            // Low Battery Safeguard
            Item {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2

                QGCLabel {
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   "Low Battery Safeguard"
                    color:                  "white"
                    font.pixelSize:         ScreenTools.defaultFontPixelHeight * 0.7
                }
                QGCCheckBoxSlider {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked:                _lowBatterySafe
                    onClicked:              _lowBatterySafe = checked
                }
            }

            // ── WAYPOINTS ──
            Item { Layout.preferredHeight: _sectionGap * 0.5 }

            RowLayout {
                Layout.fillWidth: true
                spacing: _pad * 0.5
                QGCLabel {
                    text:               "WAYPOINTS"
                    color:              _teal
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                    font.bold:          true
                    font.letterSpacing: 0.8
                    Layout.fillWidth:   true
                }
                QGCLabel {
                    text:           _waypointCount + " points"
                    color:          _dimText
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                }

                // Clear all waypoints button
                Rectangle {
                    width:          clearAllRow.implicitWidth + _pad * 1.5
                    height:         ScreenTools.defaultFontPixelHeight * 1.2
                    radius:         ScreenTools.defaultFontPixelHeight * 0.2
                    color:          clearAllMouse.containsMouse ? Qt.rgba(1, 0.32, 0.32, 0.15) : "transparent"
                    border.width:   1
                    border.color:   clearAllMouse.containsMouse ? _errColor : Qt.rgba(1, 1, 1, 0.12)
                    visible:        _waypointCount > 0

                    Row {
                        id: clearAllRow
                        anchors.centerIn: parent
                        spacing: _pad * 0.3

                        QGCLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text:               "\u2715"
                            color:              clearAllMouse.containsMouse ? _errColor : _dimText
                            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.45
                            font.bold:          true
                        }
                        QGCLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text:               "CLEAR ALL"
                            color:              clearAllMouse.containsMouse ? _errColor : _dimText
                            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.5
                            font.bold:          true
                            font.letterSpacing: 0.5
                        }
                    }

                    MouseArea {
                        id: clearAllMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: _planMaster.removeAll()
                    }
                }
            }

            // Waypoint placeholder or mini list
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: _waypointCount > 0
                                        ? Math.min(wpColumn.implicitHeight + _pad * 2, ScreenTools.defaultFontPixelHeight * 10)
                                        : ScreenTools.defaultFontPixelHeight * 6
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.06)
                clip:                   true

                // Empty state
                Column {
                    anchors.centerIn: parent
                    spacing:          _pad
                    visible:          _waypointCount === 0

                    QGCColoredImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: ScreenTools.defaultFontPixelHeight * 2; height: width
                        source: "/qmlimages/Plan.svg"; color: _dimText; fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Click map to add waypoints"; color: _dimText
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                    }
                }

                // Waypoint list (compact)
                QGCFlickable {
                    anchors.fill:   parent
                    anchors.margins: _pad * 0.5
                    contentHeight:  wpColumn.implicitHeight
                    clip:           true
                    visible:        _waypointCount > 0

                    Column {
                        id: wpColumn
                        width: parent.width
                        spacing: _pad * 0.3

                        Repeater {
                            model: _missionCtrl ? _missionCtrl.visualItems : undefined

                            Item {
                                width:   parent ? parent.width : 100
                                height:  ScreenTools.defaultFontPixelHeight * 1.8
                                visible: index > 0  // skip home position

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: _pad * 0.5

                                    // Waypoint number badge
                                    Rectangle {
                                        width:  ScreenTools.defaultFontPixelHeight * 1.2
                                        height: width
                                        radius: width / 2
                                        color:  _tealDim
                                        border.width: 1
                                        border.color: _tealBorder

                                        QGCLabel {
                                            anchors.centerIn: parent
                                            text:           index.toString()
                                            color:          _teal
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                            font.bold:      true
                                        }
                                    }

                                    // Coordinates
                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: {
                                            var item = object
                                            if (item && item.coordinate) {
                                                return item.coordinate.latitude.toFixed(5) + ", " + item.coordinate.longitude.toFixed(5)
                                            }
                                            return "Waypoint " + index
                                        }
                                        color:          "white"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                        elide:          Text.ElideRight
                                    }

                                    // Altitude badge
                                    Rectangle {
                                        Layout.alignment:   Qt.AlignVCenter
                                        width:              altLabel.implicitWidth + _pad * 1.5
                                        height:             ScreenTools.defaultFontPixelHeight * 1.2
                                        radius:             ScreenTools.defaultFontPixelHeight * 0.2
                                        color:              Qt.rgba(1, 1, 1, 0.06)
                                        border.width:       1
                                        border.color:       Qt.rgba(1, 1, 1, 0.10)
                                        visible:            object && object.altitude !== undefined

                                        QGCLabel {
                                            id:                 altLabel
                                            anchors.centerIn:   parent
                                            text:               object && object.altitude ? object.altitude.value.toFixed(1) + "m" : ""
                                            color:              _teal
                                            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.5
                                            font.bold:          true
                                        }
                                    }

                                    // Delete waypoint button
                                    Rectangle {
                                        Layout.alignment:       Qt.AlignVCenter
                                        width:                  ScreenTools.defaultFontPixelHeight * 1.2
                                        height:                 width
                                        radius:                 width / 2
                                        color:                  wpDeleteMouse.containsMouse ? Qt.rgba(1, 0.32, 0.32, 0.18) : Qt.rgba(1, 1, 1, 0.06)
                                        border.width:           1
                                        border.color:           wpDeleteMouse.containsMouse ? _errColor : Qt.rgba(1, 1, 1, 0.10)

                                        QGCLabel {
                                            anchors.centerIn:   parent
                                            text:               "\u2715"
                                            color:              wpDeleteMouse.containsMouse ? _errColor : _dimText
                                            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.5
                                            font.bold:          true
                                        }

                                        MouseArea {
                                            id:             wpDeleteMouse
                                            anchors.fill:   parent
                                            hoverEnabled:   true
                                            onClicked:      _missionCtrl.removeVisualItem(index)
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    z: -1   // below delete button
                                    onClicked: _missionCtrl.setCurrentPlanViewSeqNum(object.sequenceNumber, false)
                                }
                            }
                        }
                    }
                }
            }

            // ── ACTION BUTTONS ──
            Item { Layout.preferredHeight: _sectionGap }

            // SAVE ROUTE (outlined)
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.6
                radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                color:                  saveArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.08) : "transparent"
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
                        text: "SAVE ROUTE"; color: _teal
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                        font.bold: true; font.letterSpacing: 0.5
                    }
                }
                MouseArea {
                    id: saveArea; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        if (_planMaster.currentPlanFile)
                            _planMaster.saveToCurrent()
                        else
                            _planMaster.saveToSelectedFile()
                    }
                }
            }

            // DEPLOY PATROL (filled teal)
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.6
                radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                color:                  deployArea.containsMouse ? Qt.lighter(_teal, 1.15) : _teal

                RowLayout {
                    anchors.centerIn: parent
                    spacing: _pad * 0.5
                    QGCColoredImage {
                        width: ScreenTools.defaultFontPixelHeight * 0.7; height: width
                        source: "/qmlimages/PaperPlane.svg"; color: "#000000"; fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        text: "DEPLOY PATROL"; color: "#000000"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                        font.bold: true; font.letterSpacing: 0.8
                    }
                }
                MouseArea {
                    id: deployArea; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        if (_patrolCtrl) {
                            _patrolCtrl.enabled = true
                            // Assign selected drone to patrol controller
                            if (_selectedDroneIds.length > 0) {
                                _patrolCtrl.droneUID = _selectedDroneIds[0].toString()
                            } else {
                                // Fallback: use active vehicle ID
                                var av = QGroundControl.multiVehicleManager.activeVehicle
                                if (av) _patrolCtrl.droneUID = av.id.toString()
                            }
                            _patrolCtrl.saveToINI()
                        }
                        _planMaster.sendToVehicle()
                        root._deployPending = true
                    }
                }
            }

            // UPLOAD MISSION (outlined)
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.6
                radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                color:                  uploadArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.08) : "transparent"
                border.width:           1
                border.color:           _tealBorder

                RowLayout {
                    anchors.centerIn: parent
                    spacing: _pad * 0.5
                    QGCColoredImage {
                        width: ScreenTools.defaultFontPixelHeight * 0.7; height: width
                        source: "/qmlimages/Arrow-up.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        text: "UPLOAD MISSION"; color: _teal
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                        font.bold: true; font.letterSpacing: 0.5
                    }
                }
                MouseArea {
                    id: uploadArea; anchors.fill: parent; hoverEnabled: true
                    onClicked: _planMaster.sendToVehicle()
                }
            }

            // ── SCHEDULE ──
            Item { Layout.preferredHeight: _sectionGap }

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: scheduleCol.implicitHeight + _pad * 2
                radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                color:                  _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.06)

                ColumnLayout {
                    id: scheduleCol
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: _pad
                    spacing:         _pad * 0.6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.5
                        QGCColoredImage {
                            width: ScreenTools.defaultFontPixelHeight * 0.7; height: width
                            source: "/qmlimages/Gears.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            text:               "SCHEDULE"
                            color:              _teal
                            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
                            font.bold:          true
                            font.letterSpacing: 0.8
                            Layout.fillWidth:   true
                        }
                    }

                    // Enable scheduling toggle
                    Item {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2

                        QGCLabel {
                            anchors.left:           parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text:                   "Enable Scheduling"
                            color:                  "white"
                            font.pixelSize:         ScreenTools.defaultFontPixelHeight * 0.65
                        }
                        QGCCheckBoxSlider {
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            checked:                _scheduleEnabled
                            onClicked: {
                                _scheduleEnabled = checked
                                if (_patrolCtrl) _patrolCtrl.enabled = checked
                            }
                        }
                    }

                    // Time fields (visible when scheduling enabled)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          _pad
                        visible:          _scheduleEnabled

                        Column {
                            Layout.fillWidth: true
                            spacing: _pad * 0.3
                            QGCLabel {
                                text: "Start Time"; color: _dimText
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                            }
                            Rectangle {
                                width:  parent.width
                                height: ScreenTools.defaultFontPixelHeight * 2.2
                                radius: ScreenTools.defaultFontPixelHeight * 0.2
                                color:  Qt.rgba(1, 1, 1, 0.04)
                                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: _pad * 0.5

                                    TextInput {
                                        Layout.fillWidth: true
                                        verticalAlignment: Text.AlignVCenter
                                        color: scheduleTimeError.visible ? _errColor : "white"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                                        text: _startTime
                                        onEditingFinished: {
                                            _startTime = text
                                            if (!_patrolCtrl) return
                                            if (!text || text.trim().length === 0) {
                                                scheduleTimeError.visible = true
                                                return
                                            }
                                            var timeRe = /^([01]\d|2[0-3]):([0-5]\d)$/
                                            if (!timeRe.test(text)) {
                                                scheduleTimeError.visible = true
                                                return
                                            }
                                            scheduleTimeError.visible = false
                                            _patrolCtrl.startTime = text
                                        }
                                        clip: true

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: "--:--"; color: Qt.rgba(1,1,1,0.2)
                                            font: parent.font
                                            visible: !parent.text && !parent.activeFocus
                                        }
                                    }
                                    QGCColoredImage {
                                        width: ScreenTools.defaultFontPixelHeight * 0.6; height: width
                                        source: "/qmlimages/Gears.svg"; color: _dimText; fillMode: Image.PreserveAspectFit
                                    }
                                }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: _pad * 0.3
                            QGCLabel {
                                text: "End Time"; color: _dimText
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                            }
                            Rectangle {
                                width:  parent.width
                                height: ScreenTools.defaultFontPixelHeight * 2.2
                                radius: ScreenTools.defaultFontPixelHeight * 0.2
                                color:  Qt.rgba(1, 1, 1, 0.04)
                                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: _pad * 0.5

                                    TextInput {
                                        Layout.fillWidth: true
                                        verticalAlignment: Text.AlignVCenter
                                        color: "white"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                                        text: _endTime
                                        onTextChanged: _endTime = text
                                        clip: true

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: "--:--"; color: Qt.rgba(1,1,1,0.2)
                                            font: parent.font
                                            visible: !parent.text && !parent.activeFocus
                                        }
                                    }
                                    QGCColoredImage {
                                        width: ScreenTools.defaultFontPixelHeight * 0.6; height: width
                                        source: "/qmlimages/Gears.svg"; color: _dimText; fillMode: Image.PreserveAspectFit
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Time validation error
            QGCLabel {
                id:                scheduleTimeError
                visible:           false
                text:              "Invalid time. Use HH:MM (24-hour format)."
                color:             _errColor
                font.pixelSize:    ScreenTools.defaultFontPixelHeight * 0.5
                Layout.leftMargin: _pad
            }

            // ── START DATE (patrol scheduling) ──
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: scheduleDateCol.implicitHeight + _pad * 2
                radius:                 ScreenTools.defaultFontPixelHeight * 0.3
                color:                  _cardBg
                border.width:           1
                border.color:           Qt.rgba(1, 1, 1, 0.06)
                visible:                _scheduleEnabled

                ColumnLayout {
                    id:              scheduleDateCol
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: _pad
                    spacing:         _pad * 0.6

                    QGCLabel {
                        text:           "Start Date"
                        color:          _dimText
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height:           ScreenTools.defaultFontPixelHeight * 2.2
                        radius:           ScreenTools.defaultFontPixelHeight * 0.2
                        color:            Qt.rgba(1, 1, 1, 0.04)
                        border.width:     1
                        border.color:     Qt.rgba(1, 1, 1, 0.10)

                        TextInput {
                            anchors.fill:        parent
                            anchors.leftMargin:  _pad
                            anchors.rightMargin: _pad
                            verticalAlignment:   Text.AlignVCenter
                            color:               scheduleDateError.visible ? _errColor : "white"
                            font.pixelSize:      ScreenTools.defaultFontPixelHeight * 0.65
                            font.family:         ScreenTools.normalFontFamily
                            clip:                true
                            text:                _patrolCtrl && _patrolCtrl.startDate
                                                 && _patrolCtrl.startDate instanceof Date
                                                 && !isNaN(_patrolCtrl.startDate.getTime())
                                                 ? Qt.formatDate(_patrolCtrl.startDate, "yyyy-MM-dd") : ""

                            onEditingFinished: {
                                if (!_patrolCtrl) return
                                if (!text || text.trim().length === 0) {
                                    scheduleDateError.visible = true
                                    return
                                }
                                var dateRe = /^\d{4}-\d{2}-\d{2}$/
                                if (!dateRe.test(text)) {
                                    scheduleDateError.visible = true
                                    return
                                }
                                var parts = text.split("-")
                                var y = Number(parts[0])
                                var m = Number(parts[1]) - 1
                                var d = Number(parts[2])
                                var date = new Date(y, m, d)
                                if (isNaN(date.getTime()) ||
                                    date.getFullYear() !== y ||
                                    date.getMonth() !== m ||
                                    date.getDate() !== d) {
                                    scheduleDateError.visible = true
                                    return
                                }
                                scheduleDateError.visible = false
                                _patrolCtrl.startDate = date
                            }

                            Text {
                                anchors.fill:      parent
                                verticalAlignment: Text.AlignVCenter
                                text:              "YYYY-MM-DD"
                                color:             Qt.rgba(1, 1, 1, 0.2)
                                font:              parent.font
                                visible:           !parent.text && !parent.activeFocus
                            }
                        }
                    }
                }
            }

            // Date validation error
            QGCLabel {
                id:                scheduleDateError
                visible:           false
                text:              "Invalid date. Use YYYY-MM-DD format."
                color:             _errColor
                font.pixelSize:    ScreenTools.defaultFontPixelHeight * 0.5
                Layout.leftMargin: _pad
            }

            // SAVE SCHEDULE button (saves patrol config to INI and triggers timer)
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  saveScheduleArea.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.08) : "transparent"
                border.width:           1
                border.color:           _tealBorder
                visible:                _scheduleEnabled

                RowLayout {
                    anchors.centerIn: parent
                    spacing: _pad * 0.5
                    QGCColoredImage {
                        width: ScreenTools.defaultFontPixelHeight * 0.6; height: width
                        source: "/qmlimages/Gears.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        text:               _scheduleSaved ? "SCHEDULE SAVED" : "SAVE SCHEDULE"
                        color:              _scheduleSaved ? _okColor : _teal
                        font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.6
                        font.bold:          true
                        font.letterSpacing: 0.5
                    }
                }
                MouseArea {
                    id: saveScheduleArea; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        if (!_patrolCtrl) return
                        // Ensure droneUID is set
                        if (_patrolCtrl.droneUID === "" || _patrolCtrl.droneUID.length === 0) {
                            if (_selectedDroneIds.length > 0) {
                                _patrolCtrl.droneUID = _selectedDroneIds[0].toString()
                            } else {
                                var av = QGroundControl.multiVehicleManager.activeVehicle
                                if (av) _patrolCtrl.droneUID = av.id.toString()
                            }
                        }
                        // Set schedule values
                        _patrolCtrl.enabled = true
                        if (_startTime.length > 0) _patrolCtrl.startTime = _startTime
                        _patrolCtrl.saveToINI()
                        root._scheduleSaved = true
                        scheduleSavedTimer.restart()
                    }
                }
            }

            // Schedule status display
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: scheduleStatusCol.implicitHeight + _pad * 1.5
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  _patrolCtrl && _patrolCtrl.enabled
                                        ? Qt.rgba(0.298, 0.686, 0.314, 0.08)
                                        : Qt.rgba(1, 1, 1, 0.03)
                border.width:           1
                border.color:           _patrolCtrl && _patrolCtrl.enabled
                                        ? Qt.rgba(0.298, 0.686, 0.314, 0.25)
                                        : Qt.rgba(1, 1, 1, 0.06)
                visible:                _patrolCtrl && _patrolCtrl.enabled

                ColumnLayout {
                    id: scheduleStatusCol
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: _pad * 0.8
                    spacing:         _pad * 0.3

                    RowLayout {
                        spacing: _pad * 0.4
                        QGCLabel {
                            text:           "PATROL SCHEDULED"
                            color:          _okColor
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                            font.bold:      true
                            font.letterSpacing: 0.5
                        }
                    }

                    QGCLabel {
                        text: {
                            if (!_patrolCtrl) return ""
                            var parts = []
                            if (_patrolCtrl.startTime && _patrolCtrl.startTime.length > 0)
                                parts.push("Time: " + _patrolCtrl.startTime)
                            if (_patrolCtrl.startDate && _patrolCtrl.startDate instanceof Date
                                && !isNaN(_patrolCtrl.startDate.getTime()))
                                parts.push("Date: " + Qt.formatDate(_patrolCtrl.startDate, "yyyy-MM-dd"))
                            if (_patrolCtrl.speed > 0)
                                parts.push("Speed: " + _patrolCtrl.speed.toFixed(1) + " m/s")
                            var modeText = ["Forever", "Loop " + _patrolCtrl.loops + "x",
                                            _patrolCtrl.duration + " min"][_patrolCtrl.loopsMode] || ""
                            if (modeText.length > 0)
                                parts.push("Mode: " + modeText)
                            return parts.join("  |  ")
                        }
                        color:          _dimText
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                        wrapMode:       Text.WordWrap
                        Layout.fillWidth: true
                    }

                    QGCLabel {
                        text:           "Timer will trigger at scheduled time and send MAVLink commands"
                        color:          Qt.rgba(0, 0.749, 1.0, 0.45)
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.45
                        wrapMode:       Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            // Bottom padding
            Item { Layout.preferredHeight: _pad * 2 }
        }
    }

    // ══════════════════════════════════════════════
    // SAVED TAB
    // ══════════════════════════════════════════════
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
