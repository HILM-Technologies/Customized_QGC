/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed under the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Button {
    id:             control
    padding:        ScreenTools.defaultFontPixelWidth * 0.6
    leftPadding:    ScreenTools.defaultFontPixelWidth * 1.0
    rightPadding:   ScreenTools.defaultFontPixelWidth * 1.2
    hoverEnabled:   !ScreenTools.isMobile
    autoExclusive:  true

    // ── HILM design tokens ──────────────────────────────────────
    readonly property color _teal:      "#00C8C8"
    readonly property color _tealDim:   Qt.rgba(0, 0.784, 0.784, 0.14)
    readonly property color _tealBorder:Qt.rgba(0, 0.784, 0.784, 0.40)

    property color textColor: (checked || pressed)
                                  ? "#000000"
                                  : Qt.rgba(1, 1, 1, 0.68)
    property color iconColor: (checked || pressed)
                                  ? "#000000"
                                  : _teal

    QGCPalette {
        id:                 qgcPal
        colorGroupEnabled:  control.enabled
    }

    // ── Background pill ─────────────────────────────────────────
    background: Rectangle {
        radius:       height * 0.30
        color:        (control.checked || control.pressed)
                          ? control._teal
                          : (control.enabled && control.hovered)
                            ? control._tealDim
                            : "transparent"
        border.color: (control.checked || control.pressed)
                          ? "transparent"
                          : (control.enabled && control.hovered)
                            ? control._tealBorder
                            : "transparent"
        border.width: 1

        Behavior on color        { ColorAnimation { duration: 130 } }
        Behavior on border.color { ColorAnimation { duration: 130 } }
    }

    // ── Content row: icon + label ────────────────────────────────
    contentItem: RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth * 0.75

        QGCColoredImage {
            source:             control.icon.source
            color:              control.iconColor
            width:              ScreenTools.defaultFontPixelHeight * 1.1
            height:             ScreenTools.defaultFontPixelHeight * 1.1
            fillMode:           Image.PreserveAspectFit
            mipmap:             true

            Behavior on color { ColorAnimation { duration: 130 } }
        }

        QGCLabel {
            id:                  displayText
            Layout.fillWidth:    true
            text:                control.text
            color:               control.textColor
            horizontalAlignment: QGCLabel.AlignLeft
            font.bold:           control.checked
            font.letterSpacing:  control.checked ? 0.5 : 0

            Behavior on color { ColorAnimation { duration: 130 } }
        }
    }
}
