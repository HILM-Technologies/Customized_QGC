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
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

AbstractButton   {
    id:         control
    checkable:  true
    padding:    0

    // ── HILM design tokens ───────────────────────────────────────
    readonly property color _teal:      "#00C8C8"
    readonly property color _tealDim:   Qt.rgba(0, 0.784, 0.784, 0.22)
    readonly property color _tealBorder:Qt.rgba(0, 0.784, 0.784, 0.45)

    property bool _showBorder:      qgcPal.globalTheme === QGCPalette.Light
    property int  _sliderInset:     2
    property bool _showHighlight:   enabled && (pressed || checked)

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    contentItem: Item {
        implicitWidth:  (label.visible ? label.contentWidth + ScreenTools.defaultFontPixelWidth : 0) + indicator.width
        implicitHeight: label.contentHeight

        QGCLabel {
            id:             label
            anchors.left:   parent.left
            text:           visible ? control.text : "X"
            visible:        control.text !== ""
        }

        Rectangle {
            id:                     indicator
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            height:                 ScreenTools.defaultFontPixelHeight
            width:                  height * 2
            radius:                 height / 2
            color:                  checked ? _teal : (control.enabled && control.hovered ? _tealDim : qgcPal.button)
            border.width:           checked ? 0 : 1
            border.color:           control.enabled && control.hovered ? _tealBorder : Qt.rgba(1,1,1,0.15)

            Behavior on color        { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x:                      checked ? indicator.width - width - _sliderInset : _sliderInset
                height:                 parent.height - (_sliderInset * 2)
                width:                  height
                radius:                 height / 2
                color:                  checked ? "#000000" : "white"

                Behavior on x     { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: 150 } }
            }
        }
    }
}
