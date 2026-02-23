/****************************************************************************
 *
 * HILM Ground Control — Fleet Panel (Left Side)
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Rectangle {
    id: fleetPanel

    property real maximumHeight: 400

    width:   ScreenTools.defaultFontPixelWidth * 18
    height:  Math.min(panelContent.implicitHeight, maximumHeight)
    radius:  ScreenTools.defaultFontPixelHeight * 0.4
    color:   Qt.rgba(0, 0, 0, 0.75)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.06)

    // HILM design tokens
    readonly property color _teal:    "#00BFFF"
    readonly property color _dimText: Qt.rgba(1, 1, 1, 0.50)
    readonly property real  _margin:  ScreenTools.defaultFontPixelWidth * 0.8

    property var _vehicleModel: QGroundControl.multiVehicleManager.vehicles

    ColumnLayout {
        id:             panelContent
        anchors.fill:   parent
        anchors.margins: _margin
        spacing:        _margin * 0.8

        // ── Header
        RowLayout {
            Layout.fillWidth: true

            QGCLabel {
                text:               "MULTI-DRONE FLEET"
                color:              _teal
                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.8
                font.bold:          true
                font.letterSpacing: 1.0
                Layout.fillWidth:   true
            }
            QGCLabel {
                text:               _vehicleModel ? _vehicleModel.count + " Units" : "0 Units"
                color:              _dimText
                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.7
            }
        }

        // ── Separator
        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            Qt.rgba(1, 1, 1, 0.08)
        }

        // ── Vehicle List
        QGCFlickable {
            Layout.fillWidth:   true
            Layout.fillHeight:  true
            contentHeight:      vehicleColumn.implicitHeight
            clip:               true

            ColumnLayout {
                id:     vehicleColumn
                width:  parent.width
                spacing: _margin * 0.6

                Repeater {
                    model: _vehicleModel

                    HilmDroneCard {
                        Layout.fillWidth: true
                        vehicle:          object
                    }
                }

                // Empty state
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4
                    visible: !_vehicleModel || _vehicleModel.count === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: _margin

                        QGCColoredImage {
                            Layout.alignment: Qt.AlignHCenter
                            width:            ScreenTools.defaultFontPixelHeight * 2
                            height:           width
                            source:           "/qmlimages/Quad.svg"
                            color:            _dimText
                            fillMode:         Image.PreserveAspectFit
                        }
                        QGCLabel {
                            Layout.alignment: Qt.AlignHCenter
                            text:             "No drones connected"
                            color:            _dimText
                            font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.7
                        }
                    }
                }
            }
        }
    }
}
