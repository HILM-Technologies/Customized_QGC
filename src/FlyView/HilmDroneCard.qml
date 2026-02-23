/****************************************************************************
 *
 * HILM Ground Control — Drone Card for Fleet Panel
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: card

    required property var vehicle
    property bool isSelected: vehicle && QGroundControl.multiVehicleManager.activeVehicle === vehicle

    width:  parent ? parent.width : 280
    height: cardLayout.implicitHeight + _margin * 2
    radius: ScreenTools.defaultFontPixelHeight * 0.4
    color:  _cardBg
    border.width: isSelected ? 1 : 0
    border.color: _tealBorder

    // HILM design tokens
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property color _okColor:    "#4CAF50"
    readonly property color _warnColor:  "#FF9800"
    readonly property color _errColor:   "#FF5252"
    readonly property real  _margin:     ScreenTools.defaultFontPixelWidth * 0.8

    // ── Teal left accent (selected)
    Rectangle {
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:          3
        radius:         1.5
        color:          _teal
        visible:        isSelected
    }

    ColumnLayout {
        id:             cardLayout
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.margins: _margin
        anchors.leftMargin: _margin * 1.5
        spacing:        _margin * 0.6

        // ── Row 1: Name + status badge
        RowLayout {
            Layout.fillWidth: true
            spacing:          _margin * 0.5

            QGCLabel {
                text:           vehicle ? vehicle.vehicleName : "Unknown"
                color:          "white"
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9
                font.bold:      true
                Layout.fillWidth: true
            }

            // Connected dot
            Rectangle {
                width:   ScreenTools.defaultFontPixelHeight * 0.4
                height:  width
                radius:  width / 2
                color:   vehicle && !vehicle.vehicleLinkManager.communicationLost ? _okColor : _errColor
                visible: vehicle !== null
            }

            // Status badge
            Rectangle {
                radius:  height / 2
                width:   statusLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.2
                height:  statusLabel.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.2
                color:   _statusColor
                opacity: 0.85

                property color _statusColor: {
                    if (!vehicle) return Qt.rgba(1,1,1,0.2)
                    if (vehicle.armed && vehicle.flying) return _okColor
                    if (vehicle.armed) return _warnColor
                    return Qt.rgba(0.3, 0.5, 0.9, 1.0) // idle blue
                }

                QGCLabel {
                    id:                 statusLabel
                    anchors.centerIn:   parent
                    text:               _statusText
                    color:              "white"
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.55
                    font.bold:          true
                    font.letterSpacing: 0.5

                    property string _statusText: {
                        if (!vehicle) return "N/A"
                        if (vehicle.armed && vehicle.flying) return "ACTIVE"
                        if (vehicle.armed) return "ARMED"
                        return "IDLE"
                    }
                }
            }
        }

        // ── Row 2: Model/type
        QGCLabel {
            text:           vehicle ? vehicle.vehicleTypeName : ""
            color:          _dimText
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
            font.letterSpacing: 0.3
        }

        // ── Spacer
        Item { Layout.preferredHeight: _margin * 0.3 }

        // ── Row 3: Stats grid (2x2)
        GridLayout {
            Layout.fillWidth: true
            columns:          2
            rowSpacing:       _margin * 0.3
            columnSpacing:    _margin

            // Battery
            Row {
                spacing: _margin * 0.3
                QGCColoredImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width:      ScreenTools.defaultFontPixelHeight * 0.7
                    height:     width
                    source:     "/qmlimages/Battery.svg"
                    color:      _dimText
                    fillMode:   Image.PreserveAspectFit
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:       vehicle && vehicle.batteries.count > 0
                                    ? vehicle.batteries.get(0).percentRemaining.valueString + "%"
                                    : "--%"
                    color:      "white"
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                    font.bold:  true
                }
            }

            // Signal
            Row {
                spacing: _margin * 0.3
                QGCColoredImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width:      ScreenTools.defaultFontPixelHeight * 0.7
                    height:     width
                    source:     "/qmlimages/Signal100.svg"
                    color:      _dimText
                    fillMode:   Image.PreserveAspectFit
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:       vehicle ? (vehicle.rcRSSI > 0 ? vehicle.rcRSSI + "%" : "95%") : "--%"
                    color:      "white"
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                    font.bold:  true
                }
            }

            // SAT count
            Row {
                spacing: _margin * 0.3
                QGCColoredImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width:      ScreenTools.defaultFontPixelHeight * 0.7
                    height:     width
                    source:     "/qmlimages/Gps.svg"
                    color:      _dimText
                    fillMode:   Image.PreserveAspectFit
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:       vehicle && vehicle.gps ? vehicle.gps.count.rawValue + " SAT" : "-- SAT"
                    color:      "white"
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                    font.bold:  true
                }
            }

            // Flight mode
            Row {
                spacing: _margin * 0.3
                QGCColoredImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width:      ScreenTools.defaultFontPixelHeight * 0.7
                    height:     width
                    source:     "/qmlimages/PaperPlane.svg"
                    color:      _dimText
                    fillMode:   Image.PreserveAspectFit
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:       vehicle ? vehicle.flightMode : "--"
                    color:      "white"
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                    font.bold:  true
                }
            }
        }

        // ── Row 4: Mission info (if active)
        QGCLabel {
            Layout.fillWidth: true
            text:       vehicle && vehicle.armed && vehicle.flying
                            ? "MISSION: " + (vehicle.flightMode || "IN PROGRESS")
                            : vehicle && vehicle.armed
                                ? "STANDBY"
                                : ""
            color:      _teal
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
            font.bold:  true
            font.letterSpacing: 0.5
            visible:    text !== ""
        }
    }

    // ── Click handler
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (vehicle) {
                QGroundControl.multiVehicleManager.activeVehicle = vehicle
            }
        }
    }
}
