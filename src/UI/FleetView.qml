/****************************************************************************
 *
 * HILM Ground Control — Fleet Analytics & Mission History
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:    _root
    color: "#0D1117"

    // ── HILM design tokens ──────────────────────────────────
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property color _okColor:    "#4CAF50"
    readonly property color _warnColor:  "#FF9800"
    readonly property color _errColor:   "#FF5252"

    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth * 1.2
    readonly property real  _fontSize:   ScreenTools.defaultFontPixelHeight

    // ── Data sources ────────────────────────────────────────
    property var _multiVehicleMgr: QGroundControl.multiVehicleManager
    property var _vehicles:        _multiVehicleMgr ? _multiVehicleMgr.vehicles : null
    property var _activeVehicle:   _multiVehicleMgr ? _multiVehicleMgr.activeVehicle : null

    // ── Active tab: 0 = Mission History, 1 = Alerts & Events, 2 = Fleet Performance
    property int _activeTab: 0

    // ── Computed fleet stats (live from connected vehicles) ─
    property int    _totalVehicles:  _vehicles ? _vehicles.count : 0
    property real   _avgBattery:     _computeAvgBattery()
    property real   _totalFlightDist: _computeTotalFlightDistance()
    property string _totalFlightTime: _computeTotalFlightTime()

    // Mission history model (populated from saved .plan files)
    ListModel { id: _missionHistoryModel }
    // Alerts model (populated from vehicle events)
    ListModel { id: _alertsModel }

    Component.onCompleted: {
        _scanMissionFiles()
        _collectAlerts()
    }

    // Refresh when vehicles change
    Connections {
        target: _multiVehicleMgr
        function onVehicleAdded()   { _refreshTimer.restart() }
        function onVehicleRemoved() { _refreshTimer.restart() }
    }

    Timer {
        id: _refreshTimer
        interval: 1000
        repeat: false
        onTriggered: {
            _avgBattery = _computeAvgBattery()
            _totalFlightDist = _computeTotalFlightDistance()
            _totalFlightTime = _computeTotalFlightTime()
            _collectAlerts()
        }
    }

    // Periodic stats refresh (every 5s for live telemetry)
    Timer {
        id: _statsRefresh
        interval: 5000
        repeat: true
        running: _root.visible
        onTriggered: {
            _avgBattery = _computeAvgBattery()
            _totalFlightDist = _computeTotalFlightDistance()
            _totalFlightTime = _computeTotalFlightTime()
            _collectAlerts()
        }
    }

    // ── Helper functions ────────────────────────────────────
    function _computeAvgBattery() {
        if (!_vehicles || _vehicles.count === 0) return 0
        var sum = 0; var count = 0
        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (v && v.batteries && v.batteries.count > 0) {
                var pct = v.batteries.get(0).percentRemaining.value
                if (!isNaN(pct) && pct > 0) { sum += pct; count++ }
            }
        }
        return count > 0 ? (sum / count) : 0
    }

    function _computeTotalFlightDistance() {
        if (!_vehicles || _vehicles.count === 0) return 0
        var total = 0
        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (v && v.vehicle && v.vehicle.flightDistance) {
                var dist = v.vehicle.flightDistance.value
                if (!isNaN(dist)) total += dist
            }
        }
        return total
    }

    function _computeTotalFlightTime() {
        if (!_vehicles || _vehicles.count === 0) return "0h 0m"
        var totalSec = 0
        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (v && v.vehicle && v.vehicle.flightTime) {
                var t = v.vehicle.flightTime.value
                if (!isNaN(t)) totalSec += t
            }
        }
        var hours = Math.floor(totalSec / 3600)
        var mins = Math.floor((totalSec % 3600) / 60)
        return hours + "h " + mins + "m"
    }

    function _scanMissionFiles() {
        _missionHistoryModel.clear()
        // Add entries from active vehicle mission manager if available
        if (_vehicles) {
            for (var i = 0; i < _vehicles.count; i++) {
                var v = _vehicles.get(i)
                if (v && v.mavlinkLogManager && v.mavlinkLogManager.logFiles) {
                    var logs = v.mavlinkLogManager.logFiles
                    for (var j = 0; j < logs.count; j++) {
                        var log = logs.get(j)
                        _missionHistoryModel.append({
                            missionName: log.name || ("Flight Log " + (j + 1)),
                            vehicleId:   v.id,
                            duration:    _formatBytes(log.size),
                            status:      log.uploaded ? "UPLOADED" : "LOCAL",
                            fileSize:    log.size,
                            isLog:       true
                        })
                    }
                }
            }
        }
        // If no real data, show informational entries
        if (_missionHistoryModel.count === 0) {
            _missionHistoryModel.append({ missionName: "No missions recorded yet", vehicleId: 0, duration: "--", status: "NONE", fileSize: 0, isLog: false })
        }
    }

    function _collectAlerts() {
        _alertsModel.clear()
        if (!_vehicles) return
        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (!v) continue

            // Communication lost alert
            if (v.communicationLost) {
                _alertsModel.append({
                    severity: "ERROR",
                    message:  "Vehicle " + v.id + " — Communication lost",
                    vehicleId: v.id
                })
            }

            // Low battery alert
            if (v.batteries && v.batteries.count > 0) {
                var pct = v.batteries.get(0).percentRemaining.value
                if (!isNaN(pct) && pct > 0 && pct < 20) {
                    _alertsModel.append({
                        severity: pct < 10 ? "ERROR" : "WARNING",
                        message:  "Vehicle " + v.id + " — Battery low (" + pct.toFixed(0) + "%)",
                        vehicleId: v.id
                    })
                }
            }

            // Armed status info
            if (v.armed) {
                _alertsModel.append({
                    severity: "INFO",
                    message:  "Vehicle " + v.id + " — Armed" + (v.flying ? " & Flying" : ""),
                    vehicleId: v.id
                })
            }

            // GPS quality alert
            if (v.gps) {
                var satCount = v.gps.count.value
                if (!isNaN(satCount) && satCount < 6 && satCount > 0) {
                    _alertsModel.append({
                        severity: "WARNING",
                        message:  "Vehicle " + v.id + " — Low GPS satellites (" + satCount + ")",
                        vehicleId: v.id
                    })
                }
            }
        }
        if (_alertsModel.count === 0) {
            _alertsModel.append({ severity: "OK", message: "All systems nominal — no alerts", vehicleId: 0 })
        }
    }

    function _formatBytes(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        return (bytes / 1048576).toFixed(1) + " MB"
    }

    function _formatDistance(meters) {
        if (meters < 1000) return meters.toFixed(0) + " m"
        return (meters / 1000).toFixed(1) + " km"
    }

    // ════════════════════════════════════════════════════════
    // MAIN LAYOUT
    // ════════════════════════════════════════════════════════

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: _pad * 2
        spacing: _pad * 1.5

        // ── HEADER ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: _pad * 0.3

            RowLayout {
                Layout.fillWidth: true
                spacing: _pad

                QGCColoredImage {
                    width:    _fontSize * 2
                    height:   width
                    source:   "/qmlimages/Quad.svg"
                    color:    _teal
                    fillMode: Image.PreserveAspectFit
                }

                ColumnLayout {
                    spacing: 2

                    QGCLabel {
                        text:               "Analytics & Mission History"
                        color:              "white"
                        font.pixelSize:     _fontSize * 1.4
                        font.bold:          true
                        font.letterSpacing: 1
                    }

                    QGCLabel {
                        text:           "Fleet performance overview and historical data"
                        color:          _dimText
                        font.pixelSize: _fontSize * 0.75
                    }
                }

                Item { Layout.fillWidth: true }

                // Refresh button
                Rectangle {
                    width:  _fontSize * 2.5
                    height: _fontSize * 2.5
                    radius: _fontSize * 0.4
                    color:  _refreshMa.containsMouse ? _tealDim : "transparent"
                    border.color: _tealBorder
                    border.width: 1

                    QGCColoredImage {
                        anchors.centerIn: parent
                        width:    _fontSize * 1.2
                        height:   width
                        source:   "/InstrumentValueIcons/refresh.svg"
                        color:    _teal
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        id: _refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            _avgBattery = _computeAvgBattery()
                            _totalFlightDist = _computeTotalFlightDistance()
                            _totalFlightTime = _computeTotalFlightTime()
                            _scanMissionFiles()
                            _collectAlerts()
                        }
                    }
                }
            }
        }

        // ── STATS CARDS ROW ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad

            // Card 1: Connected Drones
            StatsCard {
                Layout.fillWidth: true
                Layout.preferredHeight: _fontSize * 6
                label: "CONNECTED DRONES"
                value: _totalVehicles.toString()
                accent: _teal
            }

            // Card 2: Flight Hours
            StatsCard {
                Layout.fillWidth: true
                Layout.preferredHeight: _fontSize * 6
                label: "FLIGHT TIME"
                value: _totalFlightTime
                accent: _teal
            }

            // Card 3: Avg Battery
            StatsCard {
                Layout.fillWidth: true
                Layout.preferredHeight: _fontSize * 6
                label: "AVG BATTERY"
                value: _avgBattery > 0 ? _avgBattery.toFixed(0) + "%" : "--"
                accent: _avgBattery < 20 ? _errColor : (_avgBattery < 50 ? _warnColor : _okColor)
            }

            // Card 4: Flight Distance
            StatsCard {
                Layout.fillWidth: true
                Layout.preferredHeight: _fontSize * 6
                label: "FLIGHT DISTANCE"
                value: _formatDistance(_totalFlightDist)
                accent: _teal
            }
        }

        // ── TAB BAR ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad * 0.5

            Repeater {
                model: ["MISSION HISTORY", "ALERTS & EVENTS", "FLEET PERFORMANCE"]

                Rectangle {
                    Layout.fillWidth: true
                    height: _fontSize * 2.8
                    radius: _fontSize * 0.4
                    color:  _activeTab === index ? _teal : "transparent"
                    border.color: _activeTab === index ? _teal : _tealBorder
                    border.width: 1

                    QGCLabel {
                        anchors.centerIn: parent
                        text:           modelData
                        color:          _activeTab === index ? "#000000" : _dimText
                        font.pixelSize: _fontSize * 0.7
                        font.bold:      _activeTab === index
                        font.letterSpacing: 0.8
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: _activeTab = index
                    }
                }
            }
        }

        // ── TAB CONTENT ─────────────────────────────────────
        Rectangle {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            color:  _cardBg
            radius: _fontSize * 0.5
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1

            // Tab 0: Mission History
            QGCFlickable {
                anchors.fill: parent
                anchors.margins: _pad
                contentHeight: _missionHistoryCol.height
                clip: true
                visible: _activeTab === 0

                ColumnLayout {
                    id: _missionHistoryCol
                    width: parent.width
                    spacing: _pad * 0.6

                    // Column header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad

                        QGCLabel { text: "MISSION"; color: _dimText; font.pixelSize: _fontSize * 0.65; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.35 }
                        QGCLabel { text: "VEHICLE"; color: _dimText; font.pixelSize: _fontSize * 0.65; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.15 }
                        QGCLabel { text: "SIZE";    color: _dimText; font.pixelSize: _fontSize * 0.65; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.2 }
                        QGCLabel { text: "STATUS";  color: _dimText; font.pixelSize: _fontSize * 0.65; font.bold: true; font.letterSpacing: 1; Layout.fillWidth: true }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                    Repeater {
                        model: _missionHistoryModel

                        Rectangle {
                            Layout.fillWidth: true
                            height: _fontSize * 3.2
                            radius: _fontSize * 0.3
                            color:  _mhMa.containsMouse ? Qt.rgba(1,1,1,0.03) : "transparent"

                            MouseArea {
                                id: _mhMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: _pad
                                anchors.rightMargin: _pad
                                spacing: _pad

                                // Mission name
                                ColumnLayout {
                                    Layout.preferredWidth: parent.width * 0.35
                                    spacing: 2

                                    QGCLabel {
                                        text: model.missionName
                                        color: "white"
                                        font.pixelSize: _fontSize * 0.8
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Vehicle ID
                                QGCLabel {
                                    Layout.preferredWidth: parent.width * 0.15
                                    text:  model.vehicleId > 0 ? ("Drone #" + model.vehicleId) : "--"
                                    color: _dimText
                                    font.pixelSize: _fontSize * 0.75
                                }

                                // Duration/Size
                                QGCLabel {
                                    Layout.preferredWidth: parent.width * 0.2
                                    text:  model.duration
                                    color: _dimText
                                    font.pixelSize: _fontSize * 0.75
                                }

                                // Status badge
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    width:  _statusLabel.implicitWidth + _pad * 2
                                    height: _fontSize * 1.4
                                    radius: _fontSize * 0.7
                                    color: {
                                        if (model.status === "UPLOADED") return Qt.rgba(0.298, 0.686, 0.314, 0.15)
                                        if (model.status === "LOCAL")    return _tealDim
                                        return Qt.rgba(1,1,1,0.05)
                                    }

                                    QGCLabel {
                                        id: _statusLabel
                                        anchors.centerIn: parent
                                        text: model.status
                                        color: {
                                            if (model.status === "UPLOADED") return _okColor
                                            if (model.status === "LOCAL")    return _teal
                                            return _dimText
                                        }
                                        font.pixelSize: _fontSize * 0.6
                                        font.bold: true
                                        font.letterSpacing: 0.5
                                    }
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Qt.rgba(1,1,1,0.04)
                            }
                        }
                    }
                }
            }

            // Tab 1: Alerts & Events
            QGCFlickable {
                anchors.fill: parent
                anchors.margins: _pad
                contentHeight: _alertsCol.height
                clip: true
                visible: _activeTab === 1

                ColumnLayout {
                    id: _alertsCol
                    width: parent.width
                    spacing: _pad * 0.5

                    Repeater {
                        model: _alertsModel

                        Rectangle {
                            Layout.fillWidth: true
                            height: _fontSize * 3.5
                            radius: _fontSize * 0.3
                            color: {
                                if (model.severity === "ERROR")   return Qt.rgba(1, 0.322, 0.322, 0.08)
                                if (model.severity === "WARNING") return Qt.rgba(1, 0.596, 0, 0.08)
                                if (model.severity === "INFO")    return _tealDim
                                return Qt.rgba(0.298, 0.686, 0.314, 0.08)
                            }
                            border.color: {
                                if (model.severity === "ERROR")   return Qt.rgba(1, 0.322, 0.322, 0.3)
                                if (model.severity === "WARNING") return Qt.rgba(1, 0.596, 0, 0.3)
                                if (model.severity === "INFO")    return _tealBorder
                                return Qt.rgba(0.298, 0.686, 0.314, 0.3)
                            }
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: _pad
                                spacing: _pad

                                // Severity dot
                                Rectangle {
                                    width:  _fontSize * 0.6
                                    height: width
                                    radius: width / 2
                                    color: {
                                        if (model.severity === "ERROR")   return _errColor
                                        if (model.severity === "WARNING") return _warnColor
                                        if (model.severity === "INFO")    return _teal
                                        return _okColor
                                    }
                                }

                                // Severity label
                                Rectangle {
                                    width:  _sevText.implicitWidth + _pad
                                    height: _fontSize * 1.3
                                    radius: _fontSize * 0.2
                                    color: Qt.rgba(0,0,0,0.3)

                                    QGCLabel {
                                        id: _sevText
                                        anchors.centerIn: parent
                                        text: model.severity
                                        color: {
                                            if (model.severity === "ERROR")   return _errColor
                                            if (model.severity === "WARNING") return _warnColor
                                            if (model.severity === "INFO")    return _teal
                                            return _okColor
                                        }
                                        font.pixelSize: _fontSize * 0.55
                                        font.bold: true
                                        font.letterSpacing: 0.5
                                    }
                                }

                                // Message
                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: model.message
                                    color: "white"
                                    font.pixelSize: _fontSize * 0.8
                                    elide: Text.ElideRight
                                }

                                // Vehicle badge
                                QGCLabel {
                                    visible: model.vehicleId > 0
                                    text: "Vehicle #" + model.vehicleId
                                    color: _dimText
                                    font.pixelSize: _fontSize * 0.65
                                }
                            }
                        }
                    }
                }
            }

            // Tab 2: Fleet Performance
            QGCFlickable {
                anchors.fill: parent
                anchors.margins: _pad
                contentHeight: _fleetPerfCol.height
                clip: true
                visible: _activeTab === 2

                ColumnLayout {
                    id: _fleetPerfCol
                    width: parent.width
                    spacing: _pad

                    // No vehicles message
                    QGCLabel {
                        visible: !_vehicles || _vehicles.count === 0
                        Layout.fillWidth: true
                        Layout.topMargin: _fontSize * 2
                        horizontalAlignment: Text.AlignHCenter
                        text: "No vehicles connected — connect drones to see fleet performance"
                        color: _dimText
                        font.pixelSize: _fontSize * 0.85
                    }

                    // Per-vehicle performance cards
                    Repeater {
                        model: _vehicles

                        Rectangle {
                            Layout.fillWidth: true
                            height: _vpCardContent.height + _pad * 2
                            radius: _fontSize * 0.4
                            color:  Qt.rgba(1, 1, 1, 0.03)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            property var _v: object

                            ColumnLayout {
                                id: _vpCardContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: _pad
                                spacing: _pad * 0.6

                                // Vehicle header row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: _pad

                                    QGCColoredImage {
                                        width:    _fontSize * 1.8
                                        height:   width
                                        source:   "/qmlimages/Quad.svg"
                                        color:    _teal
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    ColumnLayout {
                                        spacing: 1

                                        QGCLabel {
                                            text: "Drone #" + _v.id
                                            color: "white"
                                            font.pixelSize: _fontSize * 0.9
                                            font.bold: true
                                        }

                                        QGCLabel {
                                            text: _v.vehicleTypeString || "Unknown"
                                            color: _dimText
                                            font.pixelSize: _fontSize * 0.65
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Status badge
                                    Rectangle {
                                        width:  _vpStatusText.implicitWidth + _pad * 2
                                        height: _fontSize * 1.5
                                        radius: _fontSize * 0.75
                                        color: {
                                            if (_v.communicationLost) return Qt.rgba(1,0.322,0.322,0.15)
                                            if (_v.flying)           return Qt.rgba(0,0.749,1,0.15)
                                            if (_v.armed)            return Qt.rgba(1,0.596,0,0.15)
                                            return Qt.rgba(0.298,0.686,0.314,0.15)
                                        }

                                        QGCLabel {
                                            id: _vpStatusText
                                            anchors.centerIn: parent
                                            text: {
                                                if (_v.communicationLost) return "OFFLINE"
                                                if (_v.flying)           return "FLYING"
                                                if (_v.armed)            return "ARMED"
                                                return "IDLE"
                                            }
                                            color: {
                                                if (_v.communicationLost) return _errColor
                                                if (_v.flying)           return _teal
                                                if (_v.armed)            return _warnColor
                                                return _okColor
                                            }
                                            font.pixelSize: _fontSize * 0.6
                                            font.bold: true
                                            font.letterSpacing: 0.5
                                        }
                                    }
                                }

                                // Separator
                                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                                // Stats grid
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 4
                                    rowSpacing: _pad * 0.5
                                    columnSpacing: _pad

                                    // Battery
                                    VehicleStatItem {
                                        label: "BATTERY"
                                        value: (_v.batteries && _v.batteries.count > 0)
                                                   ? _v.batteries.get(0).percentRemaining.value.toFixed(0) + "%"
                                                   : "--"
                                        accent: {
                                            if (!_v.batteries || _v.batteries.count === 0) return _dimText
                                            var p = _v.batteries.get(0).percentRemaining.value
                                            return p < 20 ? _errColor : (p < 50 ? _warnColor : _okColor)
                                        }
                                    }

                                    // Altitude
                                    VehicleStatItem {
                                        label: "ALTITUDE"
                                        value: (_v.vehicle && _v.vehicle.altitudeRelative)
                                                   ? _v.vehicle.altitudeRelative.value.toFixed(1) + " m"
                                                   : "--"
                                        accent: _teal
                                    }

                                    // Ground Speed
                                    VehicleStatItem {
                                        label: "SPEED"
                                        value: (_v.vehicle && _v.vehicle.groundSpeed)
                                                   ? _v.vehicle.groundSpeed.value.toFixed(1) + " m/s"
                                                   : "--"
                                        accent: _teal
                                    }

                                    // GPS Satellites
                                    VehicleStatItem {
                                        label: "GPS SAT"
                                        value: (_v.gps && _v.gps.count)
                                                   ? _v.gps.count.value.toString()
                                                   : "--"
                                        accent: {
                                            if (!_v.gps || !_v.gps.count) return _dimText
                                            var s = _v.gps.count.value
                                            return s < 6 ? _warnColor : _okColor
                                        }
                                    }

                                    // Flight Distance
                                    VehicleStatItem {
                                        label: "DISTANCE"
                                        value: (_v.vehicle && _v.vehicle.flightDistance)
                                                   ? _formatDistance(_v.vehicle.flightDistance.value)
                                                   : "--"
                                        accent: _teal
                                    }

                                    // Distance to Home
                                    VehicleStatItem {
                                        label: "TO HOME"
                                        value: (_v.vehicle && _v.vehicle.distanceToHome)
                                                   ? _formatDistance(_v.vehicle.distanceToHome.value)
                                                   : "--"
                                        accent: _teal
                                    }

                                    // Heading
                                    VehicleStatItem {
                                        label: "HEADING"
                                        value: (_v.vehicle && _v.vehicle.heading)
                                                   ? _v.vehicle.heading.value.toFixed(0) + "°"
                                                   : "--"
                                        accent: _teal
                                    }

                                    // Throttle
                                    VehicleStatItem {
                                        label: "THROTTLE"
                                        value: (_v.vehicle && _v.vehicle.throttlePct)
                                                   ? _v.vehicle.throttlePct.value.toFixed(0) + "%"
                                                   : "--"
                                        accent: _teal
                                    }
                                }

                                // Battery bar
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: _fontSize * 0.4
                                    radius: height / 2
                                    color: Qt.rgba(1,1,1,0.08)

                                    Rectangle {
                                        width: {
                                            if (!_v.batteries || _v.batteries.count === 0) return 0
                                            var p = _v.batteries.get(0).percentRemaining.value
                                            return Math.max(0, Math.min(1, p / 100)) * parent.width
                                        }
                                        height: parent.height
                                        radius: parent.radius
                                        color: {
                                            if (!_v.batteries || _v.batteries.count === 0) return _dimText
                                            var p = _v.batteries.get(0).percentRemaining.value
                                            return p < 20 ? _errColor : (p < 50 ? _warnColor : _okColor)
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

    // ════════════════════════════════════════════════════════
    // INLINE COMPONENTS
    // ════════════════════════════════════════════════════════

    // Stats card (top row)
    component StatsCard: Rectangle {
        property string label
        property string value
        property color  accent: _teal

        radius: _fontSize * 0.5
        color:  _cardBg
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: _pad
            spacing: _pad * 0.3

            QGCLabel {
                text:               label
                color:              _dimText
                font.pixelSize:     _fontSize * 0.6
                font.bold:          true
                font.letterSpacing: 1
            }

            Item { Layout.fillHeight: true }

            QGCLabel {
                text:           value
                color:          accent
                font.pixelSize: _fontSize * 1.8
                font.bold:      true
            }

            // Accent bar
            Rectangle {
                Layout.fillWidth: true
                height: 2
                radius: 1
                color:  accent
                opacity: 0.4
            }
        }
    }

    // Per-vehicle stat item (in GridLayout)
    component VehicleStatItem: ColumnLayout {
        property string label
        property string value
        property color  accent: _teal

        spacing: 2

        QGCLabel {
            text:               label
            color:              _dimText
            font.pixelSize:     _fontSize * 0.5
            font.bold:          true
            font.letterSpacing: 0.8
        }

        QGCLabel {
            text:           value
            color:          accent
            font.pixelSize: _fontSize * 0.85
            font.bold:      true
        }
    }
}
