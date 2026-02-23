/****************************************************************************
 *
 * HILM Ground Control — Fleet Panel (Left Side — Full Height)
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Rectangle {
    id: fleetPanel

    width:   ScreenTools.defaultFontPixelWidth * 32
    radius:  ScreenTools.defaultFontPixelHeight * 0.4
    color:   Qt.rgba(0, 0, 0, 0.80)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.06)
    clip:    true

    // HILM design tokens
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth

    property var _vehicleModel: QGroundControl.multiVehicleManager.vehicles

    ColumnLayout {
        id:              panelContent
        anchors.fill:    parent
        anchors.margins: _pad * 1.0
        spacing:         _pad * 0.8

        // ── Header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin:  _pad * 0.3
            Layout.rightMargin: _pad * 0.3

            QGCLabel {
                text:               "MULTI-DRONE FLEET"
                color:              _teal
                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.7
                font.bold:          true
                font.letterSpacing: 0.8
                Layout.fillWidth:   true
            }
            QGCLabel {
                text:               _vehicleModel ? _vehicleModel.count + " Units" : "0 Units"
                color:              _dimText
                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.6
            }
        }

        // ── Vehicle List (scrollable, fills remaining space)
        QGCFlickable {
            Layout.fillWidth:   true
            Layout.fillHeight:  true
            contentHeight:      vehicleColumn.implicitHeight
            clip:               true

            ColumnLayout {
                id:     vehicleColumn
                width:  parent.width
                spacing: _pad * 0.8

                Repeater {
                    model: _vehicleModel

                    delegate: HilmDroneCard {
                        Layout.fillWidth: true
                        vehicle:          object
                    }
                }

                // Empty state
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 8
                    visible: !_vehicleModel || _vehicleModel.count === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: _pad * 1.2

                        QGCColoredImage {
                            Layout.alignment: Qt.AlignHCenter
                            width:            ScreenTools.defaultFontPixelHeight * 2.5
                            height:           width
                            source:           "/qmlimages/Quad.svg"
                            color:            _dimText
                            fillMode:         Image.PreserveAspectFit
                        }
                        QGCLabel {
                            Layout.alignment: Qt.AlignHCenter
                            text:             "No drones connected"
                            color:            _dimText
                            font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.65
                        }
                        QGCLabel {
                            Layout.alignment: Qt.AlignHCenter
                            text:             "Connect a vehicle to see fleet"
                            color:            Qt.rgba(1, 1, 1, 0.3)
                            font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.55
                        }
                    }
                }
            }
        }
    }
}
