import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ToolIndicatorPage {
    id:                root
    waitForParameters: false
    showExpand:        false

    property var v:         QGroundControl.multiVehicleManager.activeVehicle
    property var emergency: v ? v.emergencyController : null

    // Derived state helpers
    readonly property bool _active:   emergency !== null && emergency.emergencyActive
    readonly property bool _selecting: emergency !== null && emergency.selectingTarget
    readonly property bool _selected: emergency !== null && emergency.targetSelected

    contentComponent: ColumnLayout {
        spacing: ScreenTools.defaultFontPixelWidth * 0.75

        // ── Colour-coded status bar ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height:           statusLabel.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.8
            radius:           4
            color: {
                if (_active)     return Qt.rgba(0.8, 0,    0,    0.30)
                if (_selecting)  return Qt.rgba(0.8, 0.35, 0,    0.30)
                if (_selected)   return Qt.rgba(0,   0.55, 0.55, 0.20)
                return Qt.rgba(1, 1, 1, 0.06)
            }
            border.color: {
                if (_active)    return "#FF4444"
                if (_selecting) return "#FF9800"
                if (_selected)  return "#00C8C8"
                return Qt.rgba(1, 1, 1, 0.15)
            }
            border.width: 1

            QGCLabel {
                id:                statusLabel
                anchors.centerIn:  parent
                width:             parent.width - ScreenTools.defaultFontPixelWidth * 2
                wrapMode:          Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.bold:         _active || _selecting
                text: {
                    if (_active)    return qsTr("\uD83D\uDEA8  Emergency deployment active")
                    if (_selecting) return qsTr("\uD83D\uDDFA\uFE0F  Click on the map to set target location")
                    if (_selected)  return qsTr("\uD83D\uDCCD  Target set \u2014 ready to deploy")
                    return qsTr("Deploy drone immediately to a selected emergency location.")
                }
            }
        }

        SettingsGroupLayout {
            heading: qsTr("Emergency Deployment")

            // ── Step 1: Select location ───────────────────────────────────────
            QGCButton {
                Layout.fillWidth: true
                text:             _selecting
                                      ? qsTr("Selecting\u2026 (click map)")
                                      : qsTr("1. Select Emergency Location")
                enabled:          emergency !== null && !_active
                highlighted:      _selecting

                onClicked: {
                    emergency.startEmergencySelect()
                    mainWindow.showFlyView()
                    mainWindow.closeIndicatorDrawer()
                }
            }

            // ── Step 2: Deploy ────────────────────────────────────────────────
            QGCButton {
                Layout.fillWidth: true
                text:             qsTr("2. Deploy Now")
                enabled:          _selected && !_active
                // Visually prominent when ready
                opacity:          enabled ? 1.0 : 0.45

                background: Rectangle {
                    radius:       4
                    color:        parent.enabled
                                      ? (parent.pressed ? Qt.rgba(0.8, 0, 0, 0.9) : Qt.rgba(0.7, 0, 0, 0.75))
                                      : Qt.rgba(0.4, 0.4, 0.4, 0.4)
                    border.color: parent.enabled ? "#FF4444" : Qt.rgba(1,1,1,0.15)
                    border.width: 1
                }

                contentItem: Text {
                    text:                   parent.text
                    color:                  parent.enabled ? "white" : Qt.rgba(1,1,1,0.4)
                    font.bold:              parent.enabled
                    font.pixelSize:         ScreenTools.defaultFontPixelHeight * 0.82
                    horizontalAlignment:    Text.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                }

                onClicked: emergency.deployEmergency()
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height:           1
                color:            Qt.rgba(1, 1, 1, 0.12)
                visible:          _active
            }

            // ── Return home (when active) ─────────────────────────────────────
            QGCButton {
                Layout.fillWidth: true
                text:             qsTr("Return To Home")
                visible:          _active
                enabled:          _active
                onClicked:        emergency.returnToHome()
            }

            // ── Cancel (when any emergency state is set) ──────────────────────
            QGCButton {
                Layout.fillWidth: true
                text:             qsTr("Cancel Emergency")
                visible:          emergency !== null && (_active || _selecting || _selected)
                onClicked:        emergency.cancelEmergency()
            }
        }
    }
}
