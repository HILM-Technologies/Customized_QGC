import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: control
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: emergencyIcon.width * 1.1

    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var emergency: activeVehicle ? activeVehicle.emergencyController : null

    QGCPalette { id: qgcPal }

    QGCColoredImage {
        id: emergencyIcon
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: height
        source: "/qmlimages/EmergencyDeployment.svg"
        fillMode: Image.PreserveAspectFit
        sourceSize.height: height
        color: qgcPal.colorRed     // ALWAYS RED
    }

    MouseArea {
        anchors.fill: parent
        onClicked: mainWindow.showIndicatorDrawer(emergencyPage, control)
    }

    Component {
        id: emergencyPage
        EmergencyIndicatorPage { }
    }
}
