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

import QGroundControl
import QGroundControl.Controls

// Label control whichs pop up a flight mode change menu when clicked
QGCLabel {
    id:     _root
    text:   currentVehicle ? currentVehicle.flightMode : qsTr("N/A", "No data to display")

    property var    currentVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property real   mouseAreaLeftMargin:    0

    Menu {
        id: flightModesMenu

        background: Rectangle {
            implicitWidth:  ScreenTools.defaultFontPixelWidth * 22
            radius:         ScreenTools.defaultFontPixelHeight * 0.4
            color:          "#0D1117"
            border.width:   1
            border.color:   Qt.rgba(0, 0.749, 1.0, 0.35)

            // Subtle inner top glow line
            Rectangle {
                anchors.top:   parent.top
                anchors.left:  parent.left
                anchors.right: parent.right
                height:        1
                radius:        parent.radius
                color:         Qt.rgba(0, 0.749, 1.0, 0.18)
            }
        }
    }

    Component {
        id: flightModeMenuItemComponent

        MenuItem {
            enabled: true
            onTriggered: currentVehicle.flightMode = text

            contentItem: Text {
                text:                  parent.text
                color:                 parent.highlighted ? "#00BFFF" : "white"
                font.pointSize:        ScreenTools.defaultFontPointSize * 0.85
                font.bold:             parent.highlighted
                font.letterSpacing:    0.4
                verticalAlignment:     Text.AlignVCenter
                leftPadding:           ScreenTools.defaultFontPixelWidth * 1.2
            }

            background: Rectangle {
                implicitHeight: ScreenTools.defaultFontPixelHeight * 2.4
                color:          parent.highlighted
                                    ? Qt.rgba(0, 0.749, 1.0, 0.14)
                                    : "transparent"

                // Teal left accent on highlighted item
                Rectangle {
                    anchors.left:   parent.left
                    anchors.top:    parent.top
                    anchors.bottom: parent.bottom
                    width:          2
                    color:          "#00BFFF"
                    visible:        parent.parent.highlighted
                }
            }
        }
    }

    property var flightModesMenuItems: []

    function updateFlightModesMenu() {
        if (currentVehicle && currentVehicle.flightModeSetAvailable) {
            var i;
            // Remove old menu items
            for (i = 0; i < flightModesMenuItems.length; i++) {
                flightModesMenu.removeItem(flightModesMenuItems[i])
            }
            flightModesMenuItems.length = 0
            // Add new items
            for (i = 0; i < currentVehicle.flightModes.length; i++) {
                var menuItem = flightModeMenuItemComponent.createObject(null, { "text": currentVehicle.flightModes[i] })
                flightModesMenuItems.push(menuItem)
                flightModesMenu.insertItem(i, menuItem)
            }
        }
    }

    Component.onCompleted: _root.updateFlightModesMenu()

    Connections {
        target:                 QGroundControl.multiVehicleManager
        function onActiveVehicleChanged(activeVehicle) { _root.updateFlightModesMenu() }
    }

    Connections {
        target: currentVehicle
        function onFlightModesChanged() { _root.updateFlightModesMenu() }
    }

    MouseArea {
        id:                 mouseArea
        visible:            currentVehicle && currentVehicle.flightModeSetAvailable
        anchors.leftMargin: mouseAreaLeftMargin
        anchors.fill:       parent
        onClicked:          flightModesMenu.popup((_root.width - flightModesMenu.width) / 2, _root.height)
    }
}
