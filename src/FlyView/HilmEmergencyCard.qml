/****************************************************************************
 *
 * HILM Ground Control — Emergency Deployment Card (Map Overlay)
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: emergencyCard

    width:   cardLayout.implicitWidth + _margin * 3
    height:  cardLayout.implicitHeight + _margin * 2
    radius:  ScreenTools.defaultFontPixelHeight * 0.3
    color:   Qt.rgba(0, 0, 0, 0.80)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.12)

    readonly property color _teal:    "#00BFFF"
    readonly property color _dimText: Qt.rgba(1, 1, 1, 0.50)
    readonly property real  _margin:  ScreenTools.defaultFontPixelWidth * 0.8

    signal selectLocationClicked()

    ColumnLayout {
        id:             cardLayout
        anchors.centerIn: parent
        spacing:        _margin * 0.8

        // Header
        QGCLabel {
            text:               "Emergency Deployment"
            color:              "white"
            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.8
            font.bold:          true
        }

        // SELECT LOCATION button
        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
            radius:                 ScreenTools.defaultFontPixelHeight * 0.25
            color:                  Qt.rgba(1, 1, 1, 0.08)
            border.width:           1
            border.color:           Qt.rgba(1, 1, 1, 0.15)

            RowLayout {
                anchors.centerIn: parent
                spacing:          _margin * 0.4

                QGCColoredImage {
                    width:      ScreenTools.defaultFontPixelHeight * 0.8
                    height:     width
                    source:     "/qmlimages/Gps.svg"
                    color:      "white"
                    fillMode:   Image.PreserveAspectFit
                }
                QGCLabel {
                    text:               "SELECT LOCATION"
                    color:              "white"
                    font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.7
                    font.bold:          true
                    font.letterSpacing: 0.5
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked:    emergencyCard.selectLocationClicked()
            }
        }
    }
}
