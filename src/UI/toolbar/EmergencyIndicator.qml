import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: control
    anchors.top:    parent.top
    anchors.bottom: parent.bottom
    width:          emergencyIcon.width * 1.4

    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var emergency:     activeVehicle ? activeVehicle.emergencyController : null

    QGCPalette { id: qgcPal }

    // ── Icon tint: red normally · amber when target selected · bright pulsing red when active
    readonly property color _colorNormal:   qgcPal.colorRed
    readonly property color _colorSelected: "#FF9800"   // amber — target set
    readonly property color _colorActive:   "#FF2222"   // bright red — deploying

    property color _iconColor: {
        if (!emergency)                   return _colorNormal
        if (emergency.emergencyActive)    return _colorActive
        if (emergency.targetSelected)     return _colorSelected
        return _colorNormal
    }

    QGCColoredImage {
        id:               emergencyIcon
        anchors.centerIn: parent
        height:           parent.height * 0.72
        width:            height
        source:           "/qmlimages/EmergencyDeployment.svg"
        fillMode:         Image.PreserveAspectFit
        sourceSize.height: height
        color:            control._iconColor
    }

    // Pulsing scale when actively selecting or deploying
    SequentialAnimation {
        id:      pulseAnim
        running: emergency && (emergency.selectingTarget || emergency.emergencyActive)
        loops:   Animation.Infinite

        NumberAnimation {
            target:   emergencyIcon
            property: "scale"
            from:     1.0
            to:       1.18
            duration: 600
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target:   emergencyIcon
            property: "scale"
            from:     1.18
            to:       1.0
            duration: 600
            easing.type: Easing.InOutSine
        }
    }

    // Reset scale when animation stops
    onVisibleChanged: if (!visible) emergencyIcon.scale = 1.0
    Connections {
        target:   emergency
        function onEmergencyActiveChanged()  { if (!emergency.emergencyActive && !emergency.selectingTarget) emergencyIcon.scale = 1.0 }
        function onSelectingTargetChanged()  { if (!emergency.emergencyActive && !emergency.selectingTarget) emergencyIcon.scale = 1.0 }
    }

    // Small state dot indicator (bottom-right corner of icon)
    Rectangle {
        id:                       stateDot
        anchors.right:            emergencyIcon.right
        anchors.bottom:           emergencyIcon.bottom
        width:                    ScreenTools.defaultFontPixelHeight * 0.55
        height:                   width
        radius:                   width / 2
        visible:                  emergency !== null && (emergency.targetSelected || emergency.emergencyActive)
        color:                    emergency && emergency.emergencyActive ? _colorActive : _colorSelected
        border.color:             Qt.rgba(0, 0, 0, 0.5)
        border.width:             1
    }

    MouseArea {
        anchors.fill: parent
        onClicked:    mainWindow.showIndicatorDrawer(emergencyPage, control)
    }

    Component {
        id: emergencyPage
        EmergencyIndicatorPage { }
    }
}
