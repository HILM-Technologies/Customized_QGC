/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.FlyView

Item {
    property real   _margin:              ScreenTools.defaultFontPixelWidth / 2
    property real   _widgetHeight:        ScreenTools.defaultFontPixelHeight * 2.5
    property var    _guidedController:    globals.guidedControllerFlyView
    property var    _activeVehicle:       QGroundControl.multiVehicleManager.activeVehicle
    property var    selectedVehicles:     QGroundControl.multiVehicleManager.selectedVehicles

    // ── HILM design tokens ────────────────────────────────────────────────────
    readonly property color _teal:       "#00C8C8"
    readonly property color _tealDim:    Qt.rgba(0, 0.784, 0.784, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property color _okColor:    "#4CAF50"
    readonly property color _warnColor:  "#FF9800"
    readonly property real  _r:          ScreenTools.defaultFontPixelWidth * 0.7
    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth * 0.75

    implicitHeight: vehicleList.contentHeight

    function armAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            if (selectedVehicles.get(i).armed === false) return true
        }
        return false
    }
    function disarmAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            if (selectedVehicles.get(i).armed === true) return true
        }
        return false
    }
    function startAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            var v = selectedVehicles.get(i)
            if (v.armed === true && v.flightMode !== v.missionFlightMode) return true
        }
        return false
    }
    function pauseAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            var v = selectedVehicles.get(i)
            if (v.armed === true && v.pauseVehicleSupported) return true
        }
        return false
    }
    function selectVehicle(vehicleId)   { QGroundControl.multiVehicleManager.selectVehicle(vehicleId) }
    function deselectVehicle(vehicleId) { QGroundControl.multiVehicleManager.deselectVehicle(vehicleId) }
    function toggleSelect(vehicleId) {
        if (!vehicleSelected(vehicleId)) selectVehicle(vehicleId)
        else deselectVehicle(vehicleId)
    }
    function selectAll() {
        var vehicles = QGroundControl.multiVehicleManager.vehicles
        for (var i = 0; i < vehicles.count; i++) {
            var id = vehicles.get(i).id
            if (!vehicleSelected(id)) selectVehicle(id)
        }
    }
    function deselectAll() { QGroundControl.multiVehicleManager.deselectAllVehicles() }
    function vehicleSelected(vehicleId) {
        for (var i = 0; i < selectedVehicles.count; i++) {
            if (vehicleId === selectedVehicles.get(i).id) return true
        }
        return false
    }

    QGCPalette { id: qgcPal }

    // ═════════════════════════════════════════════════════════════════════════
    //  VEHICLE CARD LIST
    // ═════════════════════════════════════════════════════════════════════════
    QGCListView {
        id:           vehicleList
        anchors.fill: parent
        spacing:      _pad
        orientation:  ListView.Vertical
        model:        QGroundControl.multiVehicleManager.vehicles
        cacheBuffer:  Math.max(height * 2, 0)
        clip:         true

        delegate: Rectangle {
            width:        vehicleList.width
            height:       cardColumn.implicitHeight + _pad * 2
            radius:       _r
            color:        QGroundControl.multiVehicleManager.activeVehicle === _vehicle
                              ? _tealDim : _cardBg
            border.color: vehicleSelected(_vehicle ? _vehicle.id : -1) ? _teal : _tealBorder
            border.width: vehicleSelected(_vehicle ? _vehicle.id : -1) ? 2 : 1

            property var _vehicle: object

            QGCMouseArea {
                anchors.fill: parent
                onClicked:    toggleSelect(_vehicle.id)
            }

            Column {
                id:              cardColumn
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.top:     parent.top
                anchors.margins: _pad
                spacing:         _pad * 0.6

                // ── Header: checkbox · ID · LIVE badge ────────────────────────
                Row {
                    width:   parent.width
                    height:  ScreenTools.defaultFontPixelHeight * 1.6
                    spacing: _pad * 0.5

                    // Checkbox
                    Rectangle {
                        width:                  12
                        height:                 12
                        anchors.verticalCenter: parent.verticalCenter
                        radius:                 3
                        border.width:           1.5
                        border.color:           _teal
                        color:                  vehicleSelected(_vehicle ? _vehicle.id : -1) ? _teal : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text:             "✓"
                            font.pixelSize:   8
                            font.bold:        true
                            color:            "#000"
                            visible:          vehicleSelected(_vehicle ? _vehicle.id : -1)
                        }
                    }

                    // Vehicle ID
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:                   qsTr("✈  VEHICLE ") + (_vehicle ? _vehicle.id : "")
                        color:                  _teal
                        font.bold:              true
                        font.letterSpacing:     1.2
                        font.pointSize:         ScreenTools.defaultFontPointSize * 0.85
                    }

                    // Spacer
                    Item { width: parent.width - 12 - _pad * 0.5 - (ScreenTools.defaultFontPixelWidth * 10) - liveBadge.width - _pad * 0.5; height: 1 }

                    // LIVE badge
                    Rectangle {
                        id:                     liveBadge
                        anchors.verticalCenter: parent.verticalCenter
                        width:                  liveRow.implicitWidth + _pad
                        height:                 ScreenTools.defaultFontPixelHeight * 1.1
                        radius:                 height / 2
                        border.width:           1
                        border.color:           _okColor
                        color:                  Qt.rgba(76/255, 175/255, 80/255, 0.12)

                        Row {
                            id:              liveRow
                            anchors.centerIn: parent
                            spacing:         3
                            Rectangle {
                                width: 5; height: 5; radius: 3
                                color: _okColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text:                   qsTr("LIVE")
                                color:                  _okColor
                                font.bold:              true
                                font.pointSize:         ScreenTools.smallFontPointSize * 0.8
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // ── Divider ───────────────────────────────────────────────────
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(0, 0.784, 0.784, 0.18) }

                // ── Mode + Arm state badges ───────────────────────────────────
                Row {
                    width:   parent.width
                    spacing: _pad * 0.5

                    Rectangle {
                        radius: 3
                        color:  Qt.rgba(1, 1, 1, 0.08)
                        width:  modeText.implicitWidth + _pad
                        height: modeText.implicitHeight + 4
                        Text {
                            id:               modeText
                            anchors.centerIn: parent
                            text:             _vehicle ? _vehicle.flightMode : "—"
                            color:            Qt.rgba(1, 1, 1, 0.85)
                            font.pointSize:   ScreenTools.smallFontPointSize
                        }
                    }

                    Rectangle {
                        radius:       3
                        color:        _vehicle && _vehicle.armed ? Qt.rgba(1, 0.596, 0, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: _vehicle && _vehicle.armed ? Qt.rgba(1, 0.596, 0, 0.45) : Qt.rgba(1, 1, 1, 0.15)
                        width:        armText.implicitWidth + _pad
                        height:       armText.implicitHeight + 4
                        Text {
                            id:               armText
                            anchors.centerIn: parent
                            text:             _vehicle && _vehicle.armed ? qsTr("ARMED") : qsTr("DISARMED")
                            color:            _vehicle && _vehicle.armed ? _warnColor : _dimText
                            font.bold:        true
                            font.pointSize:   ScreenTools.smallFontPointSize * 0.85
                        }
                    }
                }

                // ── Compass + telemetry ───────────────────────────────────────
                Row {
                    width:   parent.width
                    spacing: _pad

                    IntegratedCompassAttitude {
                        compassRadius:             _widgetHeight / 2 - attitudeSize / 2
                        compassBorder:             0
                        attitudeSize:              ScreenTools.defaultFontPixelWidth / 2
                        attitudeSpacing:           attitudeSize / 2
                        usedByMultipleVehicleList: true
                        vehicle:                   _vehicle
                    }

                    QGCFlickable {
                        width:         parent.width - _widgetHeight - _pad
                        height:        telemetryBar.height
                        contentWidth:  telemetryBar.width
                        contentHeight: telemetryBar.height

                        TelemetryValuesBar {
                            id:                     telemetryBar
                            settingsGroup:          factValueGrid.vehicleCardSettingsGroup
                            specificVehicleForCard: _vehicle
                        }
                    }
                }
            }
        }
    }
}
