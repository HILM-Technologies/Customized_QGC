/****************************************************************************
 *
 * HILM Ground Control — Fleet Analytics & Mission History
 * Database-backed view with flight history, alerts, fleet performance charts
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts

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
    property var _flightDb:        QGroundControl.flightDatabase

    // ── Active tab: 0 = Mission History, 1 = Alerts & Events, 2 = Fleet Performance
    property int _activeTab: 0

    // ── Filter state ────────────────────────────────────────
    property string _filterVehicleUid: ""
    property int    _filterDays:       30
    property string _filterStatus:     ""

    // ── Flight detail drill-down ────────────────────────────
    property int  _selectedFlightId: -1
    property bool _showFlightDetail: false

    // ── Computed fleet stats ────────────────────────────────
    // Use DB stats when ready, fallback to live
    property int    _totalVehicles:   _flightDb && _flightDb.ready ? _flightDb.totalVehicles : (_vehicles ? _vehicles.count : 0)
    property real   _avgBattery:      _flightDb && _flightDb.ready ? _flightDb.avgBatteryEndPct : _computeAvgBattery()
    property string _totalFlightTime: _flightDb && _flightDb.ready ? _flightDb.totalFlightHours.toFixed(1) + "h" : _computeTotalFlightTime()
    property int    _totalMissions:   _flightDb && _flightDb.ready ? _flightDb.totalFlights : 0
    property string _successRate:     _flightDb && _flightDb.ready ? _flightDb.successRate.toFixed(1) + "%" : "--"

    // Alerts model (live)
    ListModel { id: _alertsModel }

    Component.onCompleted: {
        _collectAlerts()
        if (_flightDb && _flightDb.ready) {
            _refreshDbData()
        }
    }

    // Refresh when DB becomes ready
    Connections {
        target: _flightDb
        function onReadyChanged()          { if (_flightDb.ready) _refreshDbData() }
        function onFleetSummaryChanged()   { /* properties auto-update via bindings */ }
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
        onTriggered: { _collectAlerts() }
    }

    // Periodic live alerts refresh (every 5s)
    Timer {
        id: _statsRefresh
        interval: 5000
        repeat: true
        running: _root.visible
        onTriggered: _collectAlerts()
    }

    // ── Helper functions ────────────────────────────────────
    function _refreshDbData() {
        if (!_flightDb) return
        _flightDb.queryFleetSummary()
        _flightDb.queryFlights(_filterVehicleUid, _getDateFrom(), "", _filterStatus, 100)
        _flightDb.queryVehicles()
        _flightDb.queryFlightActivity(_filterDays)
    }

    function _getDateFrom() {
        if (_filterDays <= 0) return ""
        var d = new Date()
        d.setDate(d.getDate() - _filterDays)
        return d.toISOString()
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

    function _collectAlerts() {
        _alertsModel.clear()
        if (!_vehicles) return
        var now = new Date()
        var timeStr = Qt.formatTime(now, "HH:mm")

        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            if (!v) continue

            if (v.communicationLost) {
                _alertsModel.append({
                    severity: "ERROR", message: "Drone " + v.id + " communication lost",
                    timestamp: timeStr, vehicleId: v.id
                })
            }

            if (v.batteries && v.batteries.count > 0) {
                var pct = v.batteries.get(0).percentRemaining.value
                if (!isNaN(pct) && pct > 0 && pct < 30) {
                    _alertsModel.append({
                        severity: pct < 10 ? "ERROR" : "WARNING",
                        message: "Drone " + v.id + " low battery (" + pct.toFixed(0) + "%)",
                        timestamp: timeStr, vehicleId: v.id
                    })
                }
            }

            if (v.gps) {
                var satCount = v.gps.count.value
                if (!isNaN(satCount) && satCount < 6 && satCount > 0) {
                    _alertsModel.append({
                        severity: "WARNING",
                        message: "Drone " + v.id + " low GPS satellites (" + satCount + ")",
                        timestamp: timeStr, vehicleId: v.id
                    })
                }
            }

            if (v.armed) {
                _alertsModel.append({
                    severity: "INFO",
                    message: "Drone " + v.id + (v.flying ? " is in flight" : " is armed"),
                    timestamp: timeStr, vehicleId: v.id
                })
            }
        }

        if (_alertsModel.count === 0) {
            _alertsModel.append({
                severity: "OK", message: "All systems nominal — no active alerts",
                timestamp: timeStr, vehicleId: 0
            })
        }
    }

    function _formatDuration(sec) {
        if (sec <= 0) return "--"
        var h = Math.floor(sec / 3600)
        var m = Math.floor((sec % 3600) / 60)
        var s = Math.floor(sec % 60)
        if (h > 0) return h + "h " + m + "m"
        if (m > 0) return m + "m " + s + "s"
        return s + "s"
    }

    function _formatDistance(meters) {
        if (meters <= 0) return "--"
        if (meters >= 1000) return (meters / 1000).toFixed(1) + " km"
        return meters.toFixed(0) + " m"
    }

    // ════════════════════════════════════════════════════════
    // MAIN LAYOUT
    // ════════════════════════════════════════════════════════

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: _pad * 2
        spacing: _pad * 1.5
        visible: !_showFlightDetail

        // ── HEADER ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad

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

            // DB status indicator
            Rectangle {
                visible: _flightDb
                width: _dbStatusText.implicitWidth + _pad * 1.5
                height: _fontSize * 1.6
                radius: _fontSize * 0.8
                color: _flightDb && _flightDb.ready ? Qt.rgba(0.298, 0.686, 0.314, 0.15)
                                                     : Qt.rgba(1, 0.596, 0, 0.15)
                QGCLabel {
                    id: _dbStatusText
                    anchors.centerIn: parent
                    text: _flightDb && _flightDb.ready ? "DB Connected" : "DB Loading..."
                    color: _flightDb && _flightDb.ready ? _okColor : _warnColor
                    font.pixelSize: _fontSize * 0.6
                    font.bold: true
                }
            }

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
                    onClicked: _refreshDbData()
                }
            }
        }

        // ── STATS CARDS ROW ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad

            StatsCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: _fontSize * 6.5
                label:    "Total Flights"
                value:    _totalMissions.toString()
                accent:   _teal
                iconSrc:  "/InstrumentValueIcons/target.svg"
            }

            StatsCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: _fontSize * 6.5
                label:    "Flight Hours"
                value:    _totalFlightTime
                accent:   _teal
                iconSrc:  "/InstrumentValueIcons/time.svg"
            }

            StatsCard {
                Layout.fillWidth:       true
                Layout.preferredHeight: _fontSize * 6.5
                label:    "Avg Battery"
                value:    _avgBattery > 0 ? _avgBattery.toFixed(0) + "%" : "--"
                accent:   _avgBattery < 20 ? _errColor : (_avgBattery < 50 ? _warnColor : _okColor)
                iconSrc:  "/InstrumentValueIcons/battery-half.svg"
            }

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
        Row {
            Layout.fillWidth: true
            spacing: _pad * 0.8

            Repeater {
                model: ["MISSION HISTORY", "ALERTS & EVENTS", "FLEET PERFORMANCE"]
                Rectangle {
                    width:  _tabLabel.implicitWidth + _pad * 3
                    height: _fontSize * 3.0
                    radius: _fontSize * 0.4
                    color:  _activeTab === index ? Qt.rgba(0, 0.749, 1.0, 0.12) : "transparent"
                    border.color: _activeTab === index ? _teal : _tealBorder
                    border.width: 1
                    QGCLabel {
                        id: _tabLabel
                        anchors.centerIn: parent
                        text:           modelData
                        color:          _activeTab === index ? _teal : _dimText
                        font.pixelSize: _fontSize * 0.82
                        font.bold:      _activeTab === index
                        font.letterSpacing: 0.5
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
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

            // ─────────── Tab 0: MISSION HISTORY (DB-backed) ─
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

                    // Section header with filters
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
                            text:               "Flight Log"
                            color:              _teal
                            font.pixelSize:     _fontSize * 0.85
                            font.bold:          true
                            font.letterSpacing: 0.8
                        }

                        Item { Layout.fillWidth: true }

                        // Date filter chips
                        Row {
                            spacing: _pad * 0.4
                            Repeater {
                                model: [
                                    { label: "7D",  days: 7 },
                                    { label: "30D", days: 30 },
                                    { label: "ALL", days: 0 }
                                ]
                                Rectangle {
                                    width: _chipLabel.implicitWidth + _pad * 1.5
                                    height: _fontSize * 1.8
                                    radius: _fontSize * 0.9
                                    color: _filterDays === modelData.days ? _tealDim : "transparent"
                                    border.color: _filterDays === modelData.days ? _teal : _tealBorder
                                    border.width: 1

                                    QGCLabel {
                                        id: _chipLabel
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: _filterDays === modelData.days ? _teal : _dimText
                                        font.pixelSize: _fontSize * 0.65
                                        font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            _filterDays = modelData.days
                                            _refreshDbData()
                                        }
                                    }
                                }
                            }
                        }

                        QGCLabel {
                            text:           (_flightDb && _flightDb.flightsModel ? _flightDb.flightsModel.count : 0) + " flights"
                            color:          _dimText
                            font.pixelSize: _fontSize * 0.725
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

                            QGCLabel { text: "FLIGHT";    color: _dimText; font.pixelSize: _fontSize * 0.72; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.20 }
                            QGCLabel { text: "VEHICLE";   color: _dimText; font.pixelSize: _fontSize * 0.72; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.15 }
                            QGCLabel { text: "DURATION";  color: _dimText; font.pixelSize: _fontSize * 0.72; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.15 }
                            QGCLabel { text: "DISTANCE";  color: _dimText; font.pixelSize: _fontSize * 0.72; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.15 }
                            QGCLabel { text: "DATE";      color: _dimText; font.pixelSize: _fontSize * 0.72; font.bold: true; font.letterSpacing: 1; Layout.preferredWidth: parent.width * 0.15 }
                            QGCLabel { text: "STATUS";    color: _dimText; font.pixelSize: _fontSize * 0.72; font.bold: true; font.letterSpacing: 1; Layout.fillWidth: true }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                    // Flight rows from DB
                    Repeater {
                        model: _flightDb ? _flightDb.flightsModel : null

                        Rectangle {
                            Layout.fillWidth: true
                            height: _fontSize * 3.2
                            radius: _fontSize * 0.3
                            color:  _mhMa.containsMouse ? Qt.rgba(1,1,1,0.03) : "transparent"

                            MouseArea {
                                id: _mhMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var row = _flightDb.flightsModel.get(index)
                                    if (row) {
                                        _selectedFlightId = row.flightId
                                        _showFlightDetail = true
                                        _flightDb.queryTelemetry(row.flightId)
                                        _flightDb.queryFlightEvents(row.flightId)
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: _pad
                                anchors.rightMargin: _pad
                                spacing: _pad

                                QGCLabel {
                                    Layout.preferredWidth: parent.width * 0.20
                                    text: "Flight #" + model.flightId
                                    color: "white"
                                    font.pixelSize: _fontSize * 0.8
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                QGCLabel {
                                    Layout.preferredWidth: parent.width * 0.15
                                    text: model.vehicleName ? model.vehicleName : ("Drone #" + model.vehicleId)
                                    color: _dimText
                                    font.pixelSize: _fontSize * 0.75
                                }

                                QGCLabel {
                                    Layout.preferredWidth: parent.width * 0.15
                                    text: _formatDuration(model.durationSec)
                                    color: _dimText
                                    font.pixelSize: _fontSize * 0.75
                                }

                                QGCLabel {
                                    Layout.preferredWidth: parent.width * 0.15
                                    text: _formatDistance(model.flightDistanceM)
                                    color: _dimText
                                    font.pixelSize: _fontSize * 0.75
                                }

                                QGCLabel {
                                    Layout.preferredWidth: parent.width * 0.15
                                    text: model.armedAt ? model.armedAt.substring(0, 10) : "--"
                                    color: _dimText
                                    font.pixelSize: _fontSize * 0.75
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: _fontSize * 1.4

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width:  _statusLbl.implicitWidth + _pad * 2
                                        height: _fontSize * 1.4
                                        radius: _fontSize * 0.7
                                        color: {
                                            if (model.status === "COMPLETED") return Qt.rgba(0.298, 0.686, 0.314, 0.15)
                                            if (model.status === "IN_PROGRESS") return _tealDim
                                            if (model.status === "ABORTED") return Qt.rgba(1, 0.596, 0, 0.15)
                                            return Qt.rgba(1, 0.322, 0.322, 0.15)
                                        }

                                        QGCLabel {
                                            id: _statusLbl
                                            anchors.centerIn: parent
                                            text: model.status
                                            color: {
                                                if (model.status === "COMPLETED") return _okColor
                                                if (model.status === "IN_PROGRESS") return _teal
                                                if (model.status === "ABORTED") return _warnColor
                                                return _errColor
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

                    // Empty state
                    QGCLabel {
                        visible: !_flightDb || !_flightDb.flightsModel || _flightDb.flightsModel.count === 0
                        Layout.fillWidth: true
                        Layout.topMargin: _fontSize * 3
                        horizontalAlignment: Text.AlignHCenter
                        text: "No flights recorded yet\nArm a vehicle to start recording flight data"
                        color: _dimText
                        font.pixelSize: _fontSize * 0.85
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
                                font.pixelSize: _fontSize * 0.725
                            }
                        }

                        Item { Layout.fillWidth: true }

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
                                font.pixelSize: _fontSize * 0.72
                                font.bold: true
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                    // Live alert items
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

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text:  model.message
                                    color: "white"
                                    font.pixelSize: _fontSize * 0.8
                                    elide: Text.ElideRight
                                }

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
                                font.pixelSize: _fontSize * 0.72
                                font.bold: true
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }

                    // ── Flight Activity Chart ───────────────
                    Rectangle {
                        width: parent.width
                        height: _fontSize * 16
                        radius: _fontSize * 0.5
                        color: Qt.rgba(1, 1, 1, 0.02)
                        border.color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        visible: _flightDb && _flightDb.flightActivityData.length > 0

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: _pad

                            QGCLabel {
                                text: "Flight Activity (Last " + _filterDays + " Days)"
                                color: _dimText
                                font.pixelSize: _fontSize * 0.75
                                font.bold: true
                                font.letterSpacing: 0.5
                            }

                            ChartView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                antialiasing: true
                                backgroundColor: "transparent"
                                legend.visible: false
                                margins.top: 0
                                margins.bottom: 0
                                margins.left: 0
                                margins.right: 0

                                BarSeries {
                                    id: _activitySeries
                                    axisX: BarCategoryAxis {
                                        id: _activityXAxis
                                        labelsColor: _dimText
                                        labelsFont.pixelSize: _fontSize * 0.5
                                        gridVisible: false
                                    }
                                    axisY: ValueAxis {
                                        id: _activityYAxis
                                        labelsColor: _dimText
                                        labelsFont.pixelSize: _fontSize * 0.5
                                        gridLineColor: Qt.rgba(1,1,1,0.06)
                                        min: 0
                                    }
                                }

                                Connections {
                                    target: _flightDb
                                    function onFlightActivityChanged() {
                                        _activitySeries.clear()
                                        var data = _flightDb.flightActivityData
                                        if (data.length === 0) return

                                        var categories = []
                                        var counts = []
                                        var maxCount = 0
                                        for (var i = 0; i < data.length; i++) {
                                            var dateStr = data[i].date.substring(5)  // MM-DD
                                            if (categories.indexOf(dateStr) === -1) {
                                                categories.push(dateStr)
                                                counts.push(data[i].flightCount)
                                            } else {
                                                var idx = categories.indexOf(dateStr)
                                                counts[idx] += data[i].flightCount
                                            }
                                            if (counts[counts.length - 1] > maxCount)
                                                maxCount = counts[counts.length - 1]
                                        }

                                        _activityXAxis.categories = categories
                                        _activityYAxis.max = Math.max(5, maxCount + 1)

                                        var barSet = _activitySeries.append("Flights", counts)
                                        barSet.color = _teal
                                        barSet.borderColor = "transparent"
                                    }
                                }
                            }
                        }
                    }

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

                    // ── Drone cards grid (live + historical) ─
                    Grid {
                        id: _droneGrid
                        visible: _vehicles && _vehicles.count > 0
                        width: parent.width
                        columns: 2
                        spacing: _pad

                        Repeater {
                            model: _vehicles

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

                                    // Card header
                                    Item {
                                        width:  parent.width
                                        height: _fontSize * 2.4

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
                                                font.pixelSize: _fontSize * 0.72
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }

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

                                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

                                    // Live stats
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

                                    DroneStatRow {
                                        width: parent.width
                                        label: "Link Quality"
                                        value: {
                                            var rssi = _v.rcRSSI
                                            if (isNaN(rssi) || rssi < 0) return "--"
                                            return Math.min(100, rssi).toFixed(0) + "%"
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

                                    Item {
                                        width:  parent.width
                                        height: _gpsLabel.height

                                        QGCLabel {
                                            id: _gpsLabel
                                            anchors.left: parent.left
                                            text:  "GPS Satellites"
                                            color: _dimText
                                            font.pixelSize: _fontSize * 0.7
                                        }
                                        QGCLabel {
                                            anchors.right: parent.right
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
                                                return isNaN(s) ? _dimText : (s < 6 ? _warnColor : _okColor)
                                            }
                                            font.pixelSize: _fontSize * 0.8
                                            font.bold: true
                                        }
                                    }

                                    // ── View History button ──
                                    Rectangle {
                                        width: parent.width
                                        height: _fontSize * 2.2
                                        radius: _fontSize * 0.35
                                        color: _viewHistMa.containsMouse ? _tealDim : "transparent"
                                        border.color: _tealBorder
                                        border.width: 1

                                        QGCLabel {
                                            anchors.centerIn: parent
                                            text: "View Flight History"
                                            color: _teal
                                            font.pixelSize: _fontSize * 0.7
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: _viewHistMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                // Switch to Mission History tab filtered to this vehicle
                                                _activeTab = 0
                                                // For now just refresh — full vehicle filter TBD
                                                _refreshDbData()
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
    }

    // ════════════════════════════════════════════════════════
    // FLIGHT DETAIL VIEW (drill-down)
    // ════════════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        color: "#0D1117"
        visible: _showFlightDetail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: _pad * 2
            spacing: _pad * 1.5

            // Back button
            RowLayout {
                Layout.fillWidth: true
                spacing: _pad

                Rectangle {
                    width:  _fontSize * 2.5
                    height: _fontSize * 2.5
                    radius: _fontSize * 0.4
                    color: _backMa.containsMouse ? _tealDim : "transparent"
                    border.color: _tealBorder
                    border.width: 1

                    QGCLabel {
                        anchors.centerIn: parent
                        text: "<"
                        color: _teal
                        font.pixelSize: _fontSize * 1.2
                        font.bold: true
                    }

                    MouseArea {
                        id: _backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: _showFlightDetail = false
                    }
                }

                QGCLabel {
                    text: "Flight #" + _selectedFlightId + " — Detail View"
                    color: "white"
                    font.pixelSize: _fontSize * 1.3
                    font.bold: true
                }

                Item { Layout.fillWidth: true }
            }

            // Telemetry chart
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: _fontSize * 20
                radius: _fontSize * 0.5
                color: Qt.rgba(1, 1, 1, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: _pad

                    QGCLabel {
                        text: "Altitude & Speed Timeline"
                        color: _dimText
                        font.pixelSize: _fontSize * 0.8
                        font.bold: true
                    }

                    ChartView {
                        id: _detailChart
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        antialiasing: true
                        backgroundColor: "transparent"
                        legend.labelColor: _dimText

                        LineSeries {
                            id: _altSeries
                            name: "Altitude (m)"
                            color: _teal
                            width: 2
                            axisX: ValueAxis {
                                id: _detailXAxis
                                titleText: "Time (s)"
                                titleBrush: _dimText
                                labelsColor: _dimText
                                labelsFont.pixelSize: _fontSize * 0.5
                                gridLineColor: Qt.rgba(1,1,1,0.06)
                            }
                            axisY: ValueAxis {
                                id: _detailYAxis
                                titleText: "Altitude (m)"
                                titleBrush: _dimText
                                labelsColor: _dimText
                                labelsFont.pixelSize: _fontSize * 0.5
                                gridLineColor: Qt.rgba(1,1,1,0.06)
                            }
                        }

                        LineSeries {
                            id: _spdSeries
                            name: "Speed (m/s)"
                            color: _okColor
                            width: 2
                            axisX: _detailXAxis
                            axisYRight: ValueAxis {
                                id: _detailYRight
                                titleText: "Speed (m/s)"
                                titleBrush: _dimText
                                labelsColor: _dimText
                                labelsFont.pixelSize: _fontSize * 0.5
                                gridLineColor: "transparent"
                            }
                        }

                        Connections {
                            target: _flightDb
                            function onTelemetryDataChanged() {
                                _altSeries.clear()
                                _spdSeries.clear()
                                var data = _flightDb.telemetryData
                                if (data.length === 0) return

                                var maxAlt = 10, maxSpd = 5, maxT = 1
                                for (var i = 0; i < data.length; i++) {
                                    var t = data[i].timestampMs / 1000.0
                                    var alt = data[i].altRelM || 0
                                    var spd = data[i].groundSpeedMps || 0
                                    _altSeries.append(t, alt)
                                    _spdSeries.append(t, spd)
                                    if (alt > maxAlt) maxAlt = alt
                                    if (spd > maxSpd) maxSpd = spd
                                    if (t > maxT) maxT = t
                                }
                                _detailXAxis.min = 0
                                _detailXAxis.max = maxT
                                _detailYAxis.min = 0
                                _detailYAxis.max = maxAlt * 1.1
                                _detailYRight.min = 0
                                _detailYRight.max = maxSpd * 1.1
                            }
                        }
                    }
                }
            }

            // Events timeline
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: _fontSize * 0.5
                color: Qt.rgba(1, 1, 1, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: _pad
                    spacing: _pad * 0.5

                    QGCLabel {
                        text: "Flight Events"
                        color: _dimText
                        font.pixelSize: _fontSize * 0.8
                        font.bold: true
                    }

                    QGCFlickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: _eventsRepCol.height
                        clip: true

                        Column {
                            id: _eventsRepCol
                            width: parent.width
                            spacing: _pad * 0.4

                            Repeater {
                                model: _flightDb ? _flightDb.eventsModel : null

                                RowLayout {
                                    width: _eventsRepCol.width
                                    spacing: _pad

                                    Rectangle {
                                        width: _fontSize * 0.6
                                        height: _fontSize * 0.6
                                        radius: width / 2
                                        color: {
                                            if (model.severity === "ERROR")   return _errColor
                                            if (model.severity === "WARNING") return _warnColor
                                            if (model.severity === "CRITICAL") return _errColor
                                            return _teal
                                        }
                                    }

                                    QGCLabel {
                                        text: _formatDuration(model.timestampMs / 1000)
                                        color: _dimText
                                        font.pixelSize: _fontSize * 0.7
                                        Layout.preferredWidth: _fontSize * 5
                                    }

                                    QGCLabel {
                                        text: model.eventType
                                        color: _teal
                                        font.pixelSize: _fontSize * 0.7
                                        font.bold: true
                                        Layout.preferredWidth: _fontSize * 8
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: model.details || ""
                                        color: _dimText
                                        font.pixelSize: _fontSize * 0.7
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            QGCLabel {
                                visible: !_flightDb || !_flightDb.eventsModel || _flightDb.eventsModel.count === 0
                                text: "No events recorded for this flight"
                                color: _dimText
                                font.pixelSize: _fontSize * 0.8
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

    component StatsCard: Rectangle {
        property string label
        property string value
        property color  accent: _teal
        property string iconSrc: ""

        radius: _fontSize * 0.5
        color:  _cardBg
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        QGCLabel {
            anchors.left:    parent.left
            anchors.top:     parent.top
            anchors.margins: _pad
            text:               label
            color:              _dimText
            font.pixelSize:     _fontSize * 0.75
            font.letterSpacing: 0.3
        }

        QGCLabel {
            anchors.left:       parent.left
            anchors.bottom:     parent.bottom
            anchors.leftMargin: _pad
            anchors.bottomMargin: _pad
            text:           value
            color:          "white"
            font.pixelSize: _fontSize * 1.9
            font.bold:      true
        }

        QGCColoredImage {
            visible: iconSrc !== ""
            anchors.right:   parent.right
            anchors.top:     parent.top
            anchors.margins: _pad
            width:    _fontSize * 1.6
            height:   _fontSize * 1.6
            source:   iconSrc
            color:    accent
            fillMode: Image.PreserveAspectFit
        }
    }

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

            Item {
                width:  parent.width
                height: _dsrLabel.height

                QGCLabel {
                    id: _dsrLabel
                    anchors.left: parent.left
                    text:  label
                    color: _dimText
                    font.pixelSize: _fontSize * 0.7
                }
                QGCLabel {
                    anchors.right: parent.right
                    text:  value
                    color: barColor
                    font.pixelSize: _fontSize * 0.8
                    font.bold: true
                }
            }

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
