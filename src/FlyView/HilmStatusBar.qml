/****************************************************************************
 *
 * HILM Ground Control — Bottom Status Bar
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: statusBar

    width:  parent ? parent.width : 800
    height: ScreenTools.defaultFontPixelHeight * 2
    color:  Qt.rgba(0, 0, 0, 0.85)

    // Top border
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:    parent.top
        height:         1
        color:          Qt.rgba(1, 1, 1, 0.08)
    }

    readonly property color _teal:    "#00BFFF"
    readonly property color _dimText: Qt.rgba(1, 1, 1, 0.50)
    readonly property color _okColor: "#4CAF50"
    readonly property color _errColor:"#FF5252"
    readonly property real  _margin:  ScreenTools.defaultFontPixelWidth * 0.8

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _vehicles:      QGroundControl.multiVehicleManager.vehicles

    // System status
    property bool _systemOk: _vehicles && _vehicles.count > 0

    // Count active patrols (armed+flying vehicles)
    property int _activePatrols: {
        var count = 0
        if (_vehicles) {
            for (var i = 0; i < _vehicles.count; i++) {
                var v = _vehicles.get(i)
                if (v && v.armed && v.flying) count++
            }
        }
        return count
    }

    // Flight time from active vehicle
    property string _flightTime: {
        if (!_activeVehicle) return "0h 0m"
        var secs = _activeVehicle.flightTime ? _activeVehicle.flightTime.rawValue : 0
        var hrs = Math.floor(secs / 3600)
        var mins = Math.floor((secs % 3600) / 60)
        return hrs + "h " + mins + "m"
    }

    RowLayout {
        anchors.fill:           parent
        anchors.leftMargin:     _margin * 2
        anchors.rightMargin:    _margin * 2
        spacing:                0

        // ── System Status
        Row {
            spacing: _margin * 0.5

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:   ScreenTools.defaultFontPixelHeight * 0.5
                height:  width
                radius:  width / 2
                color:   _systemOk ? _okColor : _errColor
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:           _systemOk ? "System Operational" : "No Connection"
                color:          _systemOk ? _okColor : _errColor
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                font.bold:      true
            }
        }

        // Separator
        Item { Layout.preferredWidth: _margin * 1.5 }
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.8
            color: Qt.rgba(1, 1, 1, 0.15)
        }
        Item { Layout.preferredWidth: _margin * 1.5 }

        // ── Active Patrols
        QGCLabel {
            text:           "Active Patrols: " + _activePatrols
            color:          _dimText
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
        }

        // Separator
        Item { Layout.preferredWidth: _margin * 1.5 }
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.8
            color: Qt.rgba(1, 1, 1, 0.15)
        }
        Item { Layout.preferredWidth: _margin * 1.5 }

        // ── Total Flight Time
        QGCLabel {
            text:           "Total Flight Time: " + _flightTime
            color:          _dimText
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
        }

        // Spacer
        Item { Layout.fillWidth: true }

        // ── Auto-return info
        Row {
            spacing: _margin * 0.4

            QGCColoredImage {
                anchors.verticalCenter: parent.verticalCenter
                width:      ScreenTools.defaultFontPixelHeight * 0.65
                height:     width
                source:     "/qmlimages/Yield.svg"
                color:      _dimText
                fillMode:   Image.PreserveAspectFit
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:           "Low battery auto-return enabled"
                color:          _dimText
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
            }
        }
    }
}
