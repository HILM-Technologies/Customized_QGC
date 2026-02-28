/****************************************************************************
 *
 * HILM Ground Control — Fleet Analytics & Mission History
 * Matches Figma: 3-tab layout with stats cards, alerts, fleet performance
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
    property int    _totalVehicles:   _vehicles ? _vehicles.count : 0
    property real   _avgBattery:      _computeAvgBattery()
    property string _totalFlightTime: _computeTotalFlightTime()
    property int    _totalMissions:   _missionHistoryModel.count
    property string _successRate:     _computeSuccessRate()

    // Mission history model
    ListModel { id: _missionHistoryModel }
    // Alerts model
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
        onTriggered: _refreshAll()
    }

    // Periodic stats refresh (every 5s for live telemetry)
    Timer {
        id: _statsRefresh
        interval: 5000
        repeat: true
        running: _root.visible
        onTriggered: _refreshAll()
    }

    // ── Helper functions ────────────────────────────────────
    function _refreshAll() {
        _avgBattery      = _computeAvgBattery()
        _totalFlightTime = _computeTotalFlightTime()
        _successRate     = _computeSuccessRate()
        _collectAlerts()
    }

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

    function _computeTotalFlightTime() {
        if (!_vehicles || _vehicles.count === 0) return "0h"
        var totalSec = 0
        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (v && v.flightTime) {
                var t = v.flightTime.value
                if (!isNaN(t)) totalSec += t
            }
        }
        var hours = Math.floor(totalSec / 3600)
        var mins  = Math.floor((totalSec % 3600) / 60)
        if (hours > 0) return hours + "h"
        return mins + "m"
    }

    function _computeSuccessRate() {
        if (_missionHistoryModel.count === 0) return "--"
        var success = 0
        for (var i = 0; i < _missionHistoryModel.count; i++) {
            var entry = _missionHistoryModel.get(i)
            if (entry.status === "COMPLETED" || entry.status === "UPLOADED")
                success++
        }
        if (_missionHistoryModel.count === 0) return "--"
        return (success / _missionHistoryModel.count * 100).toFixed(1) + "%"
    }

    function _scanMissionFiles() {
        _missionHistoryModel.clear()
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
                            date:        log.date ? Qt.formatDateTime(log.date, "yyyy-MM-dd") : "--"
                        })
                    }
                }
            }
        }
        if (_missionHistoryModel.count === 0) {
            _missionHistoryModel.append({
                missionName: "No missions recorded yet",
                vehicleId: 0, duration: "--", status: "NONE", date: "--"
            })
        }
        _totalMissions = _missionHistoryModel.count
    }

    function _collectAlerts() {
        _alertsModel.clear()
        if (!_vehicles) return
        var now = new Date()
        var timeStr = Qt.formatTime(now, "HH:mm")

        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (!v) continue

            // Communication lost alert
            if (v.communicationLost) {
                _alertsModel.append({
                    severity:  "ERROR",
                    message:   "Drone " + v.id + " communication lost",
                    timestamp: timeStr,
                    vehicleId: v.id
                })
            }

            // Low battery alert
            if (v.batteries && v.batteries.count > 0) {
                var pct = v.batteries.get(0).percentRemaining.value
                if (!isNaN(pct) && pct > 0 && pct < 30) {
                    _alertsModel.append({
                        severity:  pct < 10 ? "ERROR" : "WARNING",
                        message:   "Drone " + v.id + " low battery warning (" + pct.toFixed(0) + "%)",
                        timestamp: timeStr,
                        vehicleId: v.id
                    })
                }
            }

            // GPS quality alert
            if (v.gps) {
                var satCount = v.gps.count.value
                if (!isNaN(satCount) && satCount < 6 && satCount > 0) {
                    _alertsModel.append({
                        severity:  "WARNING",
                        message:   "Drone " + v.id + " low GPS satellites (" + satCount + ")",
                        timestamp: timeStr,
                        vehicleId: v.id
                    })
                }
            }

            // Link quality alert
            var rssi = v.rcRSSI
            if (!isNaN(rssi) && rssi >= 0 && rssi < 50) {
                _alertsModel.append({
                    severity:  "WARNING",
                    message:   "Link quality dropped below 50% for Drone " + v.id,
                    timestamp: timeStr,
                    vehicleId: v.id
                })
            }

            // Armed & flying info
            if (v.armed) {
                _alertsModel.append({
                    severity:  "INFO",
                    message:   "Drone " + v.id + (v.flying ? " is in flight" : " is armed"),
                    timestamp: timeStr,
                    vehicleId: v.id
                })
            }
        }

        if (_alertsModel.count === 0) {
            _alertsModel.append({
                severity: "OK",
                message: "All systems nominal — no active alerts",
                timestamp: timeStr,
                vehicleId: 0
            })
        }
    }

    function _formatBytes(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        return (bytes / 1048576).toFixed(1) + " MB"
    }

    // ════════════════════════════════════════════════════════
    // MAIN LAYOUT
    // ════════════════════════════════════════════════════════

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: _pad * 2
        spacing: _pad * 1.5

        // ── HEADER ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad

            // Shield icon
            Rectangle {
                width:  _fontSize * 2.8
                height: _fontSize * 2.8
                radius: _fontSize * 0.5
                color:  _tealDim

                QGCColoredImage {
                    anchors.centerIn: parent
                    width:    _fontSize * 1.6
                    height:   width
                    source:   "/InstrumentValueIcons/shield.svg"
                    color:    _teal
                    fillMode: Image.PreserveAspectFit
                }
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
                    text:           "Review fleet performance and mission data"
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
                        _refreshAll()
                        _scanMissionFiles()
                    }
                }
            }
        }

        // ── STATS CARDS ROW ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad

            // Card 1: Total Missions
            StatsCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: _fontSize * 6.5
                label:    "Total Missions"
                value:    _totalMissions.toString()
                accent:   _teal
                iconSrc:  "/InstrumentValueIcons/target.svg"
            }

            // Card 2: Flight Hours
            StatsCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: _fontSize * 6.5
                label:    "Flight Hours"
                value:    _totalFlightTime
                accent:   _teal
                iconSrc:  "/InstrumentValueIcons/time.svg"
            }

            // Card 3: Avg Battery
            StatsCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: _fontSize * 6.5
                label:    "Avg Battery"
                value:    _avgBattery > 0 ? _avgBattery.toFixed(0) + "%" : "--"
                accent:   _avgBattery < 20 ? _errColor : (_avgBattery < 50 ? _warnColor : _okColor)
                iconSrc:  "/InstrumentValueIcons/battery-half.svg"
            }

            // Card 4: Success Rate
            StatsCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: _fontSize * 6.5
                label:    "Success Rate"
                value:    _successRate
                accent:   _teal
                iconSrc:  "/InstrumentValueIcons/chart-bar.svg"
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

            // ─────────── Tab 0: MISSION HISTORY ─────────────
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

                    // Section header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.5

                        QGCColoredImage {
                            width:    _fontSize * 1.2
                            height:   width
                            source:   "/InstrumentValueIcons/list.svg"
                            color:    _teal
                            fillMode: Image.PreserveAspectFit
                        }

                        QGCLabel {
                            text:               "Mission Log"
                            color:              _teal
                            font.pixelSize:     _fontSize * 0.85
                            font.bold:          true
                            font.letterSpacing: 0.8
                        }

                        Item { Layout.fillWidth: true }

                        QGCLabel {
                            text:           _totalMissions + " entries"
                            color:          _dimText
                            font.pixelSize: _fontSize * 0.65
                        }
                    }

                    // Column header
                    Rectangle {
                        Layout.fillWidth: true
                        height: _fontSize * 2.2
                        radius: _fontSize * 0.25
                        color:  Qt.rgba(1, 1, 1, 0.02)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: _pad
                            anchors.rightMargin: _pad
                            spacing: _pad

                            QGCLabel { text: "MISSION";  color: _dimText; font.pixelSize: _fontSize * 0.6; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.30 }
                            QGCLabel { text: "VEHICLE";  color: _dimText; font.pixelSize: _fontSize * 0.6; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.15 }
                            QGCLabel { text: "SIZE";     color: _dimText; font.pixelSize: _fontSize * 0.6; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.15 }
                            QGCLabel { text: "DATE";     color: _dimText; font.pixelSize: _fontSize * 0.6; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.15 }
                            QGCLabel { text: "STATUS";   color: _dimText; font.pixelSize: _fontSize * 0.6; font.bold: true; font.letterSpacing: 1; Layout.fillWidth: true }
                        }
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
                                QGCLabel {
                                    Layout.preferredWidth: parent.width * 0.30
                                    text: model.missionName
                                    color: "white"
                                    font.pixelSize: _fontSize * 0.8
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                // Vehicle ID
                                QGCLabel {
                                    Layout.preferredWidth: parent.width * 0.15
                                    text:  model.vehicleId > 0 ? ("Drone #" + model.vehicleId) : "--"
                                    color: _dimText
                                    font.pixelSize: _fontSize * 0.75
                                }

                                // Size
                                QGCLabel {
                                    Layout.preferredWidth: parent.width * 0.15
                                    text:  model.duration
                                    color: _dimText
                                    font.pixelSize: _fontSize * 0.75
                                }

                                // Date
                                QGCLabel {
                                    Layout.preferredWidth: parent.width * 0.15
                                    text:  model.date
                                    color: _dimText
                                    font.pixelSize: _fontSize * 0.75
                                }

                                // Status badge
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: _fontSize * 1.4

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width:  _mhStatusLabel.implicitWidth + _pad * 2
                                        height: _fontSize * 1.4
                                        radius: _fontSize * 0.7
                                        color: {
                                            if (model.status === "UPLOADED" || model.status === "COMPLETED")
                                                return Qt.rgba(0.298, 0.686, 0.314, 0.15)
                                            if (model.status === "LOCAL") return _tealDim
                                            return Qt.rgba(1,1,1,0.05)
                                        }

                                        QGCLabel {
                                            id: _mhStatusLabel
                                            anchors.centerIn: parent
                                            text: model.status
                                            color: {
                                                if (model.status === "UPLOADED" || model.status === "COMPLETED")
                                                    return _okColor
                                                if (model.status === "LOCAL") return _teal
                                                return _dimText
                                            }
                                            font.pixelSize: _fontSize * 0.55
                                            font.bold: true
                                            font.letterSpacing: 0.5
                                        }
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

            // ─────────── Tab 1: ALERTS & EVENTS ─────────────
            QGCFlickable {
                anchors.fill: parent
                anchors.margins: _pad
                contentHeight: _alertsCol.height
                clip: true
                visible: _activeTab === 1

                ColumnLayout {
                    id: _alertsCol
                    width: parent.width
                    spacing: _pad * 0.6

                    // Section header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.5

                        Rectangle {
                            width:  _fontSize * 2
                            height: _fontSize * 2
                            radius: _fontSize * 0.35
                            color:  Qt.rgba(1, 0.596, 0, 0.12)

                            QGCColoredImage {
                                anchors.centerIn: parent
                                width:    _fontSize * 1.1
                                height:   width
                                source:   "/InstrumentValueIcons/exclamation-solid.svg"
                                color:    _warnColor
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        ColumnLayout {
                            spacing: 1

                            QGCLabel {
                                text:               "System Alerts"
                                color:              "white"
                                font.pixelSize:     _fontSize * 0.95
                                font.bold:          true
                                font.letterSpacing: 0.5
                            }

                            QGCLabel {
                                text:           "Real-time vehicle status and warnings"
                                color:          _dimText
                                font.pixelSize: _fontSize * 0.65
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Alert count badge
                        Rectangle {
                            width:  _alertCountText.implicitWidth + _pad * 1.5
                            height: _fontSize * 1.6
                            radius: _fontSize * 0.8
                            color:  _alertsModel.count > 0 && _alertsModel.get(0).severity !== "OK"
                                    ? Qt.rgba(1, 0.322, 0.322, 0.15)
                                    : Qt.rgba(0.298, 0.686, 0.314, 0.15)

                            QGCLabel {
                                id: _alertCountText
                                anchors.centerIn: parent
                                text: _alertsModel.count + " alert" + (_alertsModel.count !== 1 ? "s" : "")
                                color: _alertsModel.count > 0 && _alertsModel.get(0).severity !== "OK"
                                       ? _errColor : _okColor
                                font.pixelSize: _fontSize * 0.6
                                font.bold: true
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                    // Alert items
                    Repeater {
                        model: _alertsModel

                        Rectangle {
                            Layout.fillWidth: true
                            height: _alertRow.height + _pad * 1.6
                            radius: _fontSize * 0.35
                            color: {
                                if (model.severity === "ERROR")   return Qt.rgba(1, 0.322, 0.322, 0.06)
                                if (model.severity === "WARNING") return Qt.rgba(1, 0.596, 0, 0.06)
                                if (model.severity === "INFO")    return Qt.rgba(0, 0.749, 1, 0.06)
                                return Qt.rgba(0.298, 0.686, 0.314, 0.06)
                            }
                            border.color: {
                                if (model.severity === "ERROR")   return Qt.rgba(1, 0.322, 0.322, 0.2)
                                if (model.severity === "WARNING") return Qt.rgba(1, 0.596, 0, 0.2)
                                if (model.severity === "INFO")    return _tealBorder
                                return Qt.rgba(0.298, 0.686, 0.314, 0.2)
                            }
                            border.width: 1

                            RowLayout {
                                id: _alertRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: _pad
                                spacing: _pad

                                // Warning triangle icon
                                Rectangle {
                                    width:  _fontSize * 1.8
                                    height: _fontSize * 1.8
                                    radius: _fontSize * 0.3
                                    color: {
                                        if (model.severity === "ERROR")   return Qt.rgba(1, 0.322, 0.322, 0.15)
                                        if (model.severity === "WARNING") return Qt.rgba(1, 0.596, 0, 0.15)
                                        if (model.severity === "INFO")    return _tealDim
                                        return Qt.rgba(0.298, 0.686, 0.314, 0.15)
                                    }

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        width:    _fontSize * 1.0
                                        height:   width
                                        source:   "/InstrumentValueIcons/exclamation-outline.svg"
                                        color: {
                                            if (model.severity === "ERROR")   return _errColor
                                            if (model.severity === "WARNING") return _warnColor
                                            if (model.severity === "INFO")    return _teal
                                            return _okColor
                                        }
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }

                                // Alert message
                                QGCLabel {
                                    Layout.fillWidth: true
                                    text:  model.message
                                    color: "white"
                                    font.pixelSize: _fontSize * 0.8
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                // Timestamp
                                QGCLabel {
                                    text:  model.timestamp
                                    color: _dimText
                                    font.pixelSize: _fontSize * 0.7
                                }
                            }
                        }
                    }
                }
            }

            // ─────────── Tab 2: FLEET PERFORMANCE ───────────
            QGCFlickable {
                anchors.fill: parent
                anchors.margins: _pad
                contentHeight: _fleetPerfContent.height
                clip: true
                visible: _activeTab === 2

                Column {
                    id: _fleetPerfContent
                    width: parent.width
                    spacing: _pad

                    // Section header
                    RowLayout {
                        width: parent.width
                        spacing: _pad * 0.5

                        QGCColoredImage {
                            width:    _fontSize * 1.2
                            height:   width
                            source:   "/InstrumentValueIcons/radar.svg"
                            color:    _teal
                            fillMode: Image.PreserveAspectFit
                        }

                        QGCLabel {
                            text:               "Fleet Status"
                            color:              _teal
                            font.pixelSize:     _fontSize * 0.85
                            font.bold:          true
                            font.letterSpacing: 0.8
                        }

                        Item { Layout.fillWidth: true }

                        // Vehicle count badge
                        Rectangle {
                            width:  _vcText.implicitWidth + _pad * 1.5
                            height: _fontSize * 1.6
                            radius: _fontSize * 0.8
                            color:  _tealDim

                            QGCLabel {
                                id: _vcText
                                anchors.centerIn: parent
                                text: _totalVehicles + " drone" + (_totalVehicles !== 1 ? "s" : "")
                                color: _teal
                                font.pixelSize: _fontSize * 0.6
                                font.bold: true
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }

                    // No vehicles message
                    QGCLabel {
                        visible: !_vehicles || _vehicles.count === 0
                        width:  parent.width
                        topPadding: _fontSize * 3
                        horizontalAlignment: Text.AlignHCenter
                        text:  "No vehicles connected\nConnect drones to see fleet performance"
                        color: _dimText
                        font.pixelSize: _fontSize * 0.85
                    }

                    // 2-column grid of drone cards
                    Grid {
                        id: _droneGrid
                        visible: _vehicles && _vehicles.count > 0
                        width: parent.width
                        columns: 2
                        spacing: _pad

                        Repeater {
                            model: _vehicles

                            // ── Individual drone card ──
                            Rectangle {
                                width:  (_droneGrid.width - _pad) / 2
                                height: _droneCardCol.height + _pad * 2
                                radius: _fontSize * 0.5
                                color:  Qt.rgba(1, 1, 1, 0.03)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                property var _v: object

                                Column {
                                    id: _droneCardCol
                                    anchors.left:    parent.left
                                    anchors.right:   parent.right
                                    anchors.top:     parent.top
                                    anchors.margins: _pad
                                    spacing: _pad * 0.6

                                    // ── Card header: icon + name + status ──
                                    Item {
                                        width:  parent.width
                                        height: _fontSize * 2.4

                                        // Drone icon (left)
                                        Rectangle {
                                            id: _droneIcon
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width:  _fontSize * 2.2
                                            height: _fontSize * 2.2
                                            radius: _fontSize * 0.4
                                            color:  _tealDim

                                            QGCColoredImage {
                                                anchors.centerIn: parent
                                                width:    _fontSize * 1.3
                                                height:   width
                                                source:   "/qmlimages/Quad.svg"
                                                color:    _teal
                                                fillMode: Image.PreserveAspectFit
                                            }
                                        }

                                        // Name + type (center, fills)
                                        Column {
                                            anchors.left: _droneIcon.right
                                            anchors.leftMargin: _pad * 0.6
                                            anchors.right: _statusPill.left
                                            anchors.rightMargin: _pad * 0.4
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            QGCLabel {
                                                text:  "Drone #" + _v.id
                                                color: "white"
                                                font.pixelSize: _fontSize * 0.85
                                                font.bold: true
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            QGCLabel {
                                                text:  _v.vehicleTypeString || "Multi-Rotor"
                                                color: _dimText
                                                font.pixelSize: _fontSize * 0.6
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }

                                        // Status badge (right)
                                        Rectangle {
                                            id: _statusPill
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width:  _spText.implicitWidth + _pad * 1.5
                                            height: _fontSize * 1.4
                                            radius: _fontSize * 0.7
                                            color: {
                                                if (_v.communicationLost) return Qt.rgba(1, 0.322, 0.322, 0.15)
                                                if (_v.flying)           return Qt.rgba(0, 0.749, 1, 0.15)
                                                if (_v.armed)            return Qt.rgba(1, 0.596, 0, 0.15)
                                                return Qt.rgba(0.298, 0.686, 0.314, 0.15)
                                            }

                                            QGCLabel {
                                                id: _spText
                                                anchors.centerIn: parent
                                                text: {
                                                    if (_v.communicationLost) return "Offline"
                                                    if (_v.flying)           return "Active"
                                                    if (_v.armed)            return "Armed"
                                                    return "Idle"
                                                }
                                                color: {
                                                    if (_v.communicationLost) return _errColor
                                                    if (_v.flying)           return _teal
                                                    if (_v.armed)            return _warnColor
                                                    return _okColor
                                                }
                                                font.pixelSize: _fontSize * 0.55
                                                font.bold: true
                                            }
                                        }
                                    }

                                    // Separator
                                    Rectangle {
                                        width:  parent.width
                                        height: 1
                                        color:  Qt.rgba(1, 1, 1, 0.06)
                                    }

                                    // ── Status: Battery ──
                                    DroneStatRow {
                                        width: parent.width
                                        label: "Battery"
                                        value: {
                                            if (_v.batteries && _v.batteries.count > 0) {
                                                var p = _v.batteries.get(0).percentRemaining.value
                                                return !isNaN(p) ? p.toFixed(0) + "%" : "--"
                                            }
                                            return "--"
                                        }
                                        barPct: {
                                            if (_v.batteries && _v.batteries.count > 0) {
                                                var p = _v.batteries.get(0).percentRemaining.value
                                                return !isNaN(p) ? p / 100 : 0
                                            }
                                            return 0
                                        }
                                        barColor: {
                                            if (!_v.batteries || _v.batteries.count === 0) return _dimText
                                            var p = _v.batteries.get(0).percentRemaining.value
                                            return p < 20 ? _errColor : (p < 50 ? _warnColor : _okColor)
                                        }
                                    }

                                    // ── Status: Link Quality ──
                                    DroneStatRow {
                                        width: parent.width
                                        label: "Link Quality"
                                        value: {
                                            var rssi = _v.rcRSSI
                                            if (isNaN(rssi) || rssi < 0) return "--"
                                            var pct = Math.min(100, rssi)
                                            return pct.toFixed(0) + "%"
                                        }
                                        barPct: {
                                            var rssi = _v.rcRSSI
                                            if (isNaN(rssi) || rssi < 0) return 0
                                            return Math.min(1, rssi / 100)
                                        }
                                        barColor: {
                                            var rssi = _v.rcRSSI
                                            if (isNaN(rssi) || rssi < 0) return _dimText
                                            return rssi < 30 ? _errColor : (rssi < 60 ? _warnColor : _okColor)
                                        }
                                    }

                                    // ── Status: GPS Satellites ──
                                    Item {
                                        width:  parent.width
                                        height: _gpsLabel.height

                                        QGCLabel {
                                            id: _gpsLabel
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text:  "GPS Satellites"
                                            color: _dimText
                                            font.pixelSize: _fontSize * 0.7
                                        }

                                        QGCLabel {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: {
                                                if (_v.gps && _v.gps.count) {
                                                    var s = _v.gps.count.value
                                                    return !isNaN(s) ? s.toString() : "--"
                                                }
                                                return "--"
                                            }
                                            color: {
                                                if (!_v.gps || !_v.gps.count) return _dimText
                                                var s = _v.gps.count.value
                                                if (isNaN(s)) return _dimText
                                                return s < 6 ? _warnColor : _okColor
                                            }
                                            font.pixelSize: _fontSize * 0.8
                                            font.bold: true
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

    // Stats card (top row) — with icon
    component StatsCard: Rectangle {
        property string label
        property string value
        property color  accent: _teal
        property string iconSrc: ""

        radius: _fontSize * 0.5
        color:  _cardBg
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: _pad
            spacing: _pad * 0.3

            // Icon + label row
            RowLayout {
                Layout.fillWidth: true
                spacing: _pad * 0.5

                Rectangle {
                    visible: iconSrc !== ""
                    width:  _fontSize * 1.6
                    height: _fontSize * 1.6
                    radius: _fontSize * 0.3
                    color:  Qt.rgba(accent.r, accent.g, accent.b, 0.12)

                    QGCColoredImage {
                        anchors.centerIn: parent
                        width:    _fontSize * 0.9
                        height:   width
                        source:   iconSrc
                        color:    accent
                        fillMode: Image.PreserveAspectFit
                    }
                }

                QGCLabel {
                    text:               label
                    color:              _dimText
                    font.pixelSize:     _fontSize * 0.6
                    font.bold:          true
                    font.letterSpacing: 0.8
                }
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

    // Drone stat row with progress bar (for Battery, Link Quality)
    component DroneStatRow: Item {
        property string label
        property string value
        property real   barPct:   0
        property color  barColor: _teal

        height: _dsrCol.height

        Column {
            id: _dsrCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: _pad * 0.3

            // Label + value row using anchors
            Item {
                width:  parent.width
                height: _dsrLabel.height

                QGCLabel {
                    id: _dsrLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text:  label
                    color: _dimText
                    font.pixelSize: _fontSize * 0.7
                }

                QGCLabel {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text:  value
                    color: barColor
                    font.pixelSize: _fontSize * 0.8
                    font.bold: true
                }
            }

            // Mini progress bar
            Rectangle {
                width:  parent.width
                height: _fontSize * 0.25
                radius: height / 2
                color:  Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    width:  Math.max(0, Math.min(1, barPct)) * parent.width
                    height: parent.height
                    radius: parent.radius
                    color:  barColor

                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
