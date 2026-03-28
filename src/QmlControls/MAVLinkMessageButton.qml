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

Button {
    id:                 control
    autoExclusive:      true
    leftPadding:        ScreenTools.defaultFontPixelWidth
    rightPadding:       leftPadding

    property real _compIDWidth: ScreenTools.defaultFontPixelWidth * 3
    property real _hzWidth:     ScreenTools.defaultFontPixelWidth * 6
    property real _nameWidth:   nameLabel.contentWidth

    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)

    background: Rectangle {
        anchors.fill:   parent
        color:          checked ? _tealDim : "transparent"
        radius:         ScreenTools.defaultFontPixelHeight * 0.3
        border.width:   checked ? 1 : 0
        border.color:   checked ? _tealBorder : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        // Hover effect
        Rectangle {
            anchors.fill: parent
            radius:       parent.radius
            color:        Qt.rgba(0, 0.749, 1.0, 0.06)
            visible:      control.hovered && !control.checked
        }
    }

    property double messageHz:  0
    property int    compID:     0

    contentItem: RowLayout {
        id:         rowLayout
        spacing:    ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text:                   control.compID
            color:                  checked ? _teal : Qt.rgba(1,1,1,0.40)
            verticalAlignment:      Text.AlignVCenter
            Layout.minimumHeight:   ScreenTools.isMobile ? (ScreenTools.defaultFontPixelHeight * 2) : (ScreenTools.defaultFontPixelHeight * 1.5)
            Layout.minimumWidth:    _compIDWidth
            font.family:            ScreenTools.fixedFontFamily
        }
        QGCLabel {
            id:                     nameLabel
            text:                   control.text
            color:                  checked ? "#FFFFFF" : Qt.rgba(1,1,1,0.70)
            Layout.fillWidth:       true
            Layout.alignment:       Qt.AlignVCenter
            font.bold:              checked
        }
        QGCLabel {
            color:                  checked ? _teal : Qt.rgba(1,1,1,0.40)
            text:                   messageHz.toFixed(1) + 'Hz'
            horizontalAlignment:    Text.AlignRight
            Layout.minimumWidth:    _hzWidth
            Layout.alignment:       Qt.AlignVCenter
            font.family:            ScreenTools.fixedFontFamily
        }
    }

    Component.onCompleted: maxButtonWidth = Math.max(maxButtonWidth, _compIDWidth + _hzWidth + _nameWidth + (rowLayout.spacing * 2) + (control.leftPadding * 2))
}
