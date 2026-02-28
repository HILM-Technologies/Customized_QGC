/****************************************************************************
 *
 * HILM Ground Control — Mission Map Legend (bottom-left of PlanView map)
 * Shows legend items: Launch Zone, Waypoint, Patrol Route, Return to Launch
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl.Controls

Rectangle {
    id: legend

    width:  legendLayout.implicitWidth + _margin * 3
    height: legendLayout.implicitHeight + _margin * 2
    radius: ScreenTools.defaultFontPixelHeight * 0.3
    color:  Qt.rgba(0, 0, 0, 0.80)

    readonly property real  _margin:  ScreenTools.defaultFontPixelWidth * 0.8
    readonly property color _dimText: Qt.rgba(1, 1, 1, 0.50)
    readonly property color _teal:    "#00BFFF"

    DeadMouseArea { anchors.fill: parent }

    ColumnLayout {
        id:             legendLayout
        anchors.centerIn: parent
        spacing:        _margin * 0.5

        // Header
        QGCLabel {
            text:               "MAP LEGEND"
            color:              _teal
            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.65
            font.bold:          true
            font.letterSpacing: 0.8
        }

        // Launch Zone (Home)
        Row {
            spacing: _margin * 0.5
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: ScreenTools.defaultFontPixelHeight * 0.55; height: width; radius: width / 2
                color: "#4CAF50"
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "Launch Zone (Home)"
                color: _dimText
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
            }
        }

        // Waypoint
        Row {
            spacing: _margin * 0.5
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: ScreenTools.defaultFontPixelHeight * 0.55; height: width; radius: width / 2
                color: _teal
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "Waypoint"
                color: _dimText
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
            }
        }

        // Patrol Route
        Row {
            spacing: _margin * 0.5
            // Solid line representation
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: ScreenTools.defaultFontPixelHeight * 1.2
                height: 2
                color: _teal
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "Patrol Route"
                color: _dimText
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
            }
        }

        // Return to Launch
        Row {
            spacing: _margin * 0.5
            // Dashed line representation
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Repeater {
                    model: 4
                    Rectangle {
                        width:  ScreenTools.defaultFontPixelHeight * 0.2
                        height: 2
                        color:  "#FF5252"
                    }
                }
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "Return to Launch"
                color: _dimText
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
            }
        }
    }
}
