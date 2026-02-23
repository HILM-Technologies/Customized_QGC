/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// ─────────────────────────────────────────────────────────────────────────────
//  TelemetryValuesBar  –  HILM futuristic telemetry card
//  Shows drone ID badge + armed status + live telemetry values
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id:             control
    implicitWidth:  mainLayout.width + (_toolsMargin * 2)
    implicitHeight: mainLayout.height + (_toolsMargin * 2)

    property real extraWidth:               0
    property alias factValueGrid:           factValueGrid
    property alias settingsGroup:           factValueGrid.settingsGroup
    property alias specificVehicleForCard:  factValueGrid.specificVehicleForCard

    // ── HILM design tokens ────────────────────────────────────────────────────
    readonly property color _teal:       "#00C8C8"
    readonly property color _tealBorder: Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property color _tealDim:    Qt.rgba(0, 0.784, 0.784, 0.14)
    readonly property color _cardBg:     Qt.rgba(0.04, 0.06, 0.06, 0.92)
    readonly property color _okColor:    "#4CAF50"
    readonly property color _warnColor:  "#FF9800"

    // Active vehicle for badge (specific card vehicle, or active vehicle if null)
    property var _displayVehicle: (specificVehicleForCard !== null && specificVehicleForCard !== undefined)
                                      ? specificVehicleForCard
                                      : QGroundControl.multiVehicleManager.activeVehicle

    // ── Card background ───────────────────────────────────────────────────────
    Rectangle {
        id:           backgroundRect
        width:        control.width + extraWidth
        height:       control.height
        color:        _cardBg
        radius:       ScreenTools.defaultFontPixelWidth / 2
        border.color: _tealBorder
        border.width: 1
    }

    ColumnLayout {
        id:              mainLayout
        anchors.margins: _toolsMargin
        anchors.bottom:  parent.bottom
        anchors.left:    parent.left
        spacing:         Math.round(ScreenTools.defaultFontPixelHeight * 0.28)

        // ── Drone ID + armed status badge row ─────────────────────────────────
        RowLayout {
            spacing: Math.round(ScreenTools.defaultFontPixelWidth * 0.6)

            // Drone ID pill
            Rectangle {
                height:       droneIdLabel.implicitHeight + 4
                width:        droneIdLabel.implicitWidth  + 10
                radius:       height / 2
                color:        _tealDim
                border.color: _tealBorder
                border.width: 1

                Text {
                    id:                droneIdLabel
                    anchors.centerIn:  parent
                    text:              _displayVehicle ? ("DRONE\u00A0" + _displayVehicle.id) : "NO VEHICLE"
                    color:             _teal
                    font.pixelSize:    Math.round(ScreenTools.defaultFontPixelHeight * 0.58)
                    font.bold:         true
                    font.letterSpacing: 1.2
                }
            }

            // Status dot
            Rectangle {
                width:  Math.round(ScreenTools.defaultFontPixelHeight * 0.42)
                height: width
                radius: width / 2
                color:  _displayVehicle && _displayVehicle.armed ? _okColor : _warnColor
            }

            // ARMED / DISARMED label
            Text {
                text:              _displayVehicle && _displayVehicle.armed ? "ARMED" : "DISARMED"
                color:             _displayVehicle && _displayVehicle.armed
                                       ? _okColor
                                       : Qt.rgba(1, 0.596, 0, 0.85)
                font.pixelSize:    Math.round(ScreenTools.defaultFontPixelHeight * 0.52)
                font.letterSpacing: 0.8
                font.bold:         true
            }
        }

        // ── Settings unlock row ───────────────────────────────────────────────
        RowLayout {
            visible: factValueGrid.settingsUnlocked

            QGCColoredImage {
                source:             "qrc:/InstrumentValueIcons/lock-open.svg"
                mipmap:             true
                width:              ScreenTools.minTouchPixels * 0.75
                height:             width
                sourceSize.width:   width
                color:              _teal
                fillMode:           Image.PreserveAspectFit

                QGCMouseArea {
                    anchors.fill: parent
                    onClicked:    factValueGrid.settingsUnlocked = false
                }
            }
        }

        // ── Telemetry data grid ───────────────────────────────────────────────
        HorizontalFactValueGrid {
            id: factValueGrid
        }
    }

    QGCMouseArea {
        id:                         mouseArea
        x:                          mainLayout.x
        y:                          mainLayout.y
        width:                      mainLayout.width
        height:                     mainLayout.height
        acceptedButtons:            Qt.LeftButton | Qt.RightButton
        propagateComposedEvents:    true
        visible:                    !factValueGrid.settingsUnlocked

        onClicked: (mouse) => {
            if (!ScreenTools.isMobile && mouse.button === Qt.RightButton) {
                factValueGrid.settingsUnlocked = true
                mouse.accepted = true
            }
        }

        onPressAndHold: {
            factValueGrid.settingsUnlocked = true
            mouse.accepted = true
        }
    }
}
