/****************************************************************************
 *
 * HILM Ground Control — Custom Navigation Bar
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: control
    width:  parent.width
    height: ScreenTools.toolbarHeight

    // Active tab index: 0=FLY, 1=PATROLS, 2=FLEET, 3=VIDEO WALL, 4=CAMERA ROLL, 5=SETUP, 6=SETTINGS
    property int    activeTab:  0
    signal tabClicked(int index)

    property var    _activeVehicle:      QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost:  _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false

    // HILM design tokens
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.14)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property color _panelBg:    "#0D1117"

    QGCPalette { id: qgcPal }

    property real _margins: ScreenTools.defaultFontPixelWidth / 2

    // Tab model
    ListModel {
        id: tabModel
        ListElement { label: "FLY";         iconSource: "/qmlimages/PaperPlane.svg" }
        ListElement { label: "PATROLS";     iconSource: "/qmlimages/Plan.svg" }
        ListElement { label: "FLEET";       iconSource: "/qmlimages/Quad.svg" }
        ListElement { label: "VIDEO WALL";  iconSource: "/qmlimages/CameraIcon.svg" }
        ListElement { label: "CAMERA ROLL"; iconSource: "/qmlimages/CameraIcon.svg" }
        ListElement { label: "SETUP";       iconSource: "/qmlimages/Gears.svg" }
        ListElement { label: "SETTINGS";    iconSource: "/qmlimages/Gears.svg" }
    }

    // ── Background
    Rectangle {
        anchors.fill: parent
        color:        _panelBg

        // Bottom border line
        Rectangle {
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            height:         1
            color:          Qt.rgba(1, 1, 1, 0.08)
        }
    }

    RowLayout {
        anchors.fill:       parent
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
        spacing:            0

        // ── Left: HILMOS Logo
        Item {
            Layout.preferredWidth:  hilmLogoRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 2
            Layout.fillHeight:     true

            Row {
                id:                 hilmLogoRow
                anchors.centerIn:   parent
                spacing:            ScreenTools.defaultFontPixelWidth * 0.5

                // Drone icon
                QGCColoredImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width:                  ScreenTools.defaultFontPixelHeight * 1.6
                    height:                 width
                    source:                 "/qmlimages/Quad.svg"
                    color:                  _teal
                    fillMode:               Image.PreserveAspectFit
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing:               0

                    QGCLabel {
                        text:               "HILMOS"
                        color:              "white"
                        font.pixelSize:     ScreenTools.defaultFontPixelHeight * 1.1
                        font.bold:          true
                        font.letterSpacing: 1.5
                    }
                    QGCLabel {
                        text:               "DRONE CONTROL"
                        color:              _dimText
                        font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.55
                        font.letterSpacing: 1.0
                    }
                }
            }

            // Click to open tool selector (backward compat)
            MouseArea {
                anchors.fill: parent
                onClicked:    mainWindow.showToolSelectDialog()
            }
        }

        // ── Separator
        Rectangle {
            Layout.preferredWidth:  1
            Layout.fillHeight:     true
            Layout.topMargin:      ScreenTools.defaultFontPixelHeight * 0.3
            Layout.bottomMargin:   ScreenTools.defaultFontPixelHeight * 0.3
            color:                 Qt.rgba(1, 1, 1, 0.12)
        }

        // ── Center: Navigation Tabs
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            Row {
                anchors.centerIn:   parent
                height:             parent.height
                spacing:            ScreenTools.defaultFontPixelWidth * 0.5

                Repeater {
                    model: tabModel

                    Item {
                        width:  tabContent.implicitWidth + ScreenTools.defaultFontPixelWidth * 2.5
                        height: parent.height

                        property bool isActive: control.activeTab === index

                        Column {
                            id:                     tabContent
                            anchors.centerIn:       parent
                            spacing:                ScreenTools.defaultFontPixelHeight * 0.1

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: ScreenTools.defaultFontPixelWidth * 0.4

                                QGCColoredImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width:                  ScreenTools.defaultFontPixelHeight * 0.85
                                    height:                 width
                                    source:                 model.iconSource
                                    color:                  isActive ? _teal : _dimText
                                    fillMode:               Image.PreserveAspectFit
                                    visible:                model.iconSource !== ""
                                }

                                QGCLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text:                   model.label
                                    color:                  isActive ? _teal : _dimText
                                    font.pixelSize:         ScreenTools.defaultFontPixelHeight * 0.75
                                    font.bold:              isActive
                                    font.letterSpacing:     0.5
                                }
                            }
                        }

                        // Active tab underline
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width:          tabContent.implicitWidth + ScreenTools.defaultFontPixelWidth
                            height:         2
                            color:          _teal
                            visible:        isActive
                        }

                        // Hover highlight
                        Rectangle {
                            anchors.fill:   parent
                            color:          Qt.rgba(1, 1, 1, 0.05)
                            visible:        tabMouseArea.containsMouse && !isActive
                        }

                        MouseArea {
                            id:             tabMouseArea
                            anchors.fill:   parent
                            hoverEnabled:   true
                            onClicked:      {
                                if (mainWindow.allowViewSwitch()) {
                                    control.activeTab = index
                                    control.tabClicked(index)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Separator
        Rectangle {
            Layout.preferredWidth:  1
            Layout.fillHeight:     true
            Layout.topMargin:      ScreenTools.defaultFontPixelHeight * 0.3
            Layout.bottomMargin:   ScreenTools.defaultFontPixelHeight * 0.3
            color:                 Qt.rgba(1, 1, 1, 0.12)
        }

        // ── Right: Telemetry + Active Vehicle
        Item {
            Layout.preferredWidth: telemetryRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 2
            Layout.fillHeight:    true
            visible:              _activeVehicle

            Row {
                id:                 telemetryRow
                anchors.centerIn:   parent
                spacing:            ScreenTools.defaultFontPixelWidth * 1.5

                // Battery
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: ScreenTools.defaultFontPixelWidth * 0.3

                    QGCColoredImage {
                        anchors.verticalCenter: parent.verticalCenter
                        width:      ScreenTools.defaultFontPixelHeight * 0.8
                        height:     width
                        source:     "/qmlimages/Battery.svg"
                        color:      "white"
                        fillMode:   Image.PreserveAspectFit
                    }
                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text:   _activeVehicle && _activeVehicle.batteries.count > 0
                                    ? _activeVehicle.batteries.get(0).percentRemaining.valueString + "%"
                                    : "--"
                        color:  "white"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                        font.bold:      true
                    }
                }

                // Signal
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: ScreenTools.defaultFontPixelWidth * 0.3

                    QGCColoredImage {
                        anchors.verticalCenter: parent.verticalCenter
                        width:      ScreenTools.defaultFontPixelHeight * 0.8
                        height:     width
                        source:     "/qmlimages/Signal100.svg"
                        color:      "white"
                        fillMode:   Image.PreserveAspectFit
                    }
                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text:   _activeVehicle ? (_activeVehicle.rcRSSI > 0 ? _activeVehicle.rcRSSI + "%" : "95%") : "--"
                        color:  "white"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                        font.bold:      true
                    }
                }

                // SAT count
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: ScreenTools.defaultFontPixelWidth * 0.3

                    QGCColoredImage {
                        anchors.verticalCenter: parent.verticalCenter
                        width:      ScreenTools.defaultFontPixelHeight * 0.8
                        height:     width
                        source:     "/qmlimages/Gps.svg"
                        color:      "white"
                        fillMode:   Image.PreserveAspectFit
                    }
                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text:   _activeVehicle && _activeVehicle.gps
                                    ? _activeVehicle.gps.count.rawValue + " SAT"
                                    : "-- SAT"
                        color:  "white"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                        font.bold:      true
                    }
                }

                // Separator
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width:  1
                    height: ScreenTools.defaultFontPixelHeight * 1.5
                    color:  Qt.rgba(1, 1, 1, 0.12)
                }

                // Vehicle name + model
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Row {
                        spacing: ScreenTools.defaultFontPixelWidth * 0.4

                        QGCLabel {
                            text:           _activeVehicle ? qsTr("Vehicle") + " " + _activeVehicle.id : "No Vehicle"
                            color:          "white"
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                            font.bold:      true
                        }
                        // Green connected dot
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width:   ScreenTools.defaultFontPixelHeight * 0.45
                            height:  width
                            radius:  width / 2
                            color:   _activeVehicle && !_communicationLost ? "#4CAF50" : "#FF5252"
                        }
                    }
                    QGCLabel {
                        text:           _activeVehicle ? _activeVehicle.vehicleTypeString : ""
                        color:          _dimText
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                    }
                }
            }
        }
    }

    // ── Parameter download progress
    ParameterDownloadProgress {
        anchors.fill: parent
    }

    // Helper function to drop main status indicator (backward compat)
    function dropMainStatusIndicatorTool() {
        // No-op in new design — status is in telemetry section
    }
}
