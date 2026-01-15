import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ToolIndicatorPage {
    id: root
    waitForParameters: false
    showExpand: false

    property var v: QGroundControl.multiVehicleManager.activeVehicle
    property var emergency: v ? v.emergencyController : null

    contentComponent: ColumnLayout {
        spacing: ScreenTools.defaultFontPixelWidth

        SettingsGroupLayout {
            heading: qsTr("Emergency Deployment")

            QGCLabel {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: emergency && emergency.emergencyActive
                      ? qsTr("🚨 Emergency mode active")
                      : emergency && emergency.selectingTarget
                            ? qsTr("🗺️ Click on the map to select emergency location")
                            : emergency && emergency.targetSelected
                                  ? qsTr("📍 Emergency location selected. Ready to deploy.")
                                  : qsTr("Deploy drone immediately to a selected emergency location.")
            }

            // --------------------------------------------------
            // Select Emergency Location
            // --------------------------------------------------
            QGCButton {
                Layout.fillWidth: true

                text: emergency && emergency.selectingTarget
                      ? qsTr("Click on map to select…")
                      : qsTr("Select Emergency Location")

                enabled: emergency && !emergency.emergencyActive

                onClicked: {
                    emergency.startEmergencySelect()

                    mainWindow.showFlyView()

                    mainWindow.closeIndicatorDrawer()
                }
            }

            // --------------------------------------------------
            // Deploy
            // --------------------------------------------------
            QGCButton {
                Layout.fillWidth: true
                text: qsTr("Deploy Emergency")
                enabled: emergency && emergency.targetSelected && !emergency.emergencyActive
                onClicked: emergency.deployEmergency()
            }

            // --------------------------------------------------
            // Return Home
            // --------------------------------------------------
            QGCButton {
                Layout.fillWidth: true
                text: qsTr("Return To Home")
                enabled: emergency && emergency.emergencyActive
                onClicked: emergency.returnToHome()
            }

            // --------------------------------------------------
            // Cancel
            // --------------------------------------------------
            QGCButton {
                Layout.fillWidth: true
                text: qsTr("Cancel Emergency")
                visible: emergency && (emergency.emergencyActive || emergency.selectingTarget || emergency.targetSelected)
                onClicked: emergency.cancelEmergency()
            }
        }
    }
}
