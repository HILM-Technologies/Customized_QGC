/****************************************************************************
 *
 * HILM Ground Control — Map Legend Overlay
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: legend

    width:   legendLayout.implicitWidth + _margin * 3
    height:  legendLayout.implicitHeight + _margin * 2
    radius:  ScreenTools.defaultFontPixelHeight * 0.3
    color:   Qt.rgba(0, 0, 0, 0.80)

    readonly property real  _margin:  ScreenTools.defaultFontPixelWidth * 0.8
    readonly property color _dimText: Qt.rgba(1, 1, 1, 0.50)

    property var _vehicles: QGroundControl.multiVehicleManager.vehicles

    // Count vehicles by status
    property int _activeCount: {
        var count = 0
        if (_vehicles) {
            for (var i = 0; i < _vehicles.count; i++) {
                var v = _vehicles.get(i)
                if (v && v.armed && v.flying) count++
            }
        }
        return count
    }
    property int _idleCount: {
        var count = 0
        if (_vehicles) {
            for (var i = 0; i < _vehicles.count; i++) {
                var v = _vehicles.get(i)
                if (v && !v.armed) count++
            }
        }
        return count
    }
    property int _chargingCount: 0 // No charging status in MAVLink — placeholder

    ColumnLayout {
        id:             legendLayout
        anchors.centerIn: parent
        spacing:        _margin * 0.5

        // Header
        Row {
            spacing: _margin * 0.4

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
                text:           "Mission Map View"
                color:          "white"
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                font.bold:      true
            }
        }

        // Active
        Row {
            spacing: _margin * 0.5
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: ScreenTools.defaultFontPixelHeight * 0.5; height: width; radius: width/2
                color: "#4CAF50"
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "Active (" + _activeCount + ")"
                color: _dimText
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
            }
        }

        // Idle
        Row {
            spacing: _margin * 0.5
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: ScreenTools.defaultFontPixelHeight * 0.5; height: width; radius: width/2
                color: "#4A90D9"
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "Idle (" + _idleCount + ")"
                color: _dimText
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
            }
        }

        // Charging
        Row {
            spacing: _margin * 0.5
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: ScreenTools.defaultFontPixelHeight * 0.5; height: width; radius: width/2
                color: "#FF9800"
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "Charging (" + _chargingCount + ")"
                color: _dimText
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
            }
        }
    }
}
