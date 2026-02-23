/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Used as the base class control for nboth VehicleGPSIndicator and RTKGPSIndicator

Item {
    id:             control
    width:          gpsIndicatorRow.width
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool   _rtkConnected:  QGroundControl.gpsRtk.connected.value

    QGCPalette { id: qgcPal }

    Row {
        id:             gpsIndicatorRow
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth * 0.55

        // RTK label (rotated, only when RTK connected)
        QGCLabel {
            rotation:               90
            text:                   qsTr("RTK")
            color:                  qgcPal.windowTransparentText
            anchors.verticalCenter: parent.verticalCenter
            visible:                _rtkConnected
            font.pointSize:         ScreenTools.defaultFontPointSize * 0.55
        }

        // GPS satellite icon
        QGCColoredImage {
            width:              height
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            source:             "/qmlimages/Gps.svg"
            fillMode:           Image.PreserveAspectFit
            sourceSize.height:  height
            opacity:            (_activeVehicle && _activeVehicle.gps.count.value >= 0) ? 1 : 0.5
            color:              qgcPal.windowTransparentText
        }

        // SAT count — labeled
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing:                ScreenTools.defaultFontPixelWidth * 0.28
            visible:                _activeVehicle && _activeVehicle.gps.count.value >= 0

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:           qsTr("SAT")
                color:          Qt.rgba(1, 1, 1, 0.38)
                font.pointSize: ScreenTools.defaultFontPointSize * 0.58
                font.letterSpacing: 0.6
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:           _activeVehicle ? _activeVehicle.gps.count.valueString : "--"
                color:          qgcPal.windowTransparentText
                font.bold:      true
                font.pointSize: ScreenTools.defaultFontPointSize * 0.78
            }
        }

        // Mid-dot separator
        QGCLabel {
            anchors.verticalCenter: parent.verticalCenter
            text:    "\u00B7"
            color:   Qt.rgba(1, 1, 1, 0.22)
            font.pointSize: ScreenTools.defaultFontPointSize * 0.80
            visible: _activeVehicle && !isNaN(_activeVehicle.gps.hdop.value)
        }

        // HDOP — labeled
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing:                ScreenTools.defaultFontPixelWidth * 0.28
            visible:                _activeVehicle && !isNaN(_activeVehicle.gps.hdop.value)

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:           qsTr("HDOP")
                color:          Qt.rgba(1, 1, 1, 0.38)
                font.pointSize: ScreenTools.defaultFontPointSize * 0.58
                font.letterSpacing: 0.6
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:           _activeVehicle ? _activeVehicle.gps.hdop.value.toFixed(1) : "--"
                color:          qgcPal.windowTransparentText
                font.bold:      true
                font.pointSize: ScreenTools.defaultFontPointSize * 0.78
            }
        }
    }

    MouseArea {
        anchors.fill:   parent
        onClicked:      mainWindow.showIndicatorDrawer(gpsIndicatorPage, control)
    }

    Component {
        id: gpsIndicatorPage

        GPSIndicatorPage { }
    }
}
