import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// ─────────────────────────────────────────────────────────────────────────────
//  RallyPointEditorHeader  –  HILM teal-themed rally points header panel
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root
    height:         mainCol.height
    implicitHeight: mainCol.height

    property var controller ///< RallyPointController

    // ── Design tokens (HILM palette) ─────────────────────────────────────────
    readonly property color _teal:       "#00C8C8"
    readonly property color _tealDim:    Qt.rgba(0, 0.784, 0.784, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property real  _r:          ScreenTools.defaultFontPixelWidth * 0.7
    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth
    readonly property real  _gap:        ScreenTools.defaultFontPixelHeight * 0.5

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Column {
        id:      mainCol
        width:   parent.width
        spacing: _gap

        // ╔══════════════════════════════════════════════════════════════════╗
        //  HEADER CARD
        // ╚══════════════════════════════════════════════════════════════════╝
        Rectangle {
            width:        parent.width
            height:       ScreenTools.defaultFontPixelHeight * 4.2
            radius:       _r
            color:        _tealDim
            border.color: _tealBorder
            border.width: 1

            Rectangle {
                id:                     hAccentBar
                width:                  3
                height:                 parent.height * 0.55
                radius:                 2
                color:                  _teal
                anchors.left:           parent.left
                anchors.leftMargin:     _pad
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.left:           hAccentBar.right
                anchors.leftMargin:     _pad * 0.75
                anchors.right:          parent.right
                anchors.rightMargin:    _pad
                anchors.verticalCenter: parent.verticalCenter
                spacing:                3

                Text {
                    width:              parent.width
                    text:               qsTr("RALLY POINTS")
                    color:              _teal
                    font.bold:          true
                    font.letterSpacing: 2.0
                    font.pointSize:     ScreenTools.defaultFontPointSize * 0.85
                    elide:              Text.ElideRight
                }
                Text {
                    width:          parent.width
                    text:           qsTr("Alternate landing points for Return to Launch operations")
                    color:          _dimText
                    font.pointSize: ScreenTools.smallFontPointSize
                    wrapMode:       Text.NoWrap
                    elide:          Text.ElideRight
                }
            }
        }

        // ╔══════════════════════════════════════════════════════════════════╗
        //  INFO CARD
        // ╚══════════════════════════════════════════════════════════════════╝
        Rectangle {
            width:        parent.width
            height:       infoText.implicitHeight + _pad * 2
            radius:       _r
            color:        _cardBg
            border.color: _tealBorder
            border.width: 1

            Text {
                id:              infoText
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.top:     parent.top
                anchors.margins: _pad
                text:            qsTr("Rally Points provide alternate landing points when performing a Return to Launch (RTL).")
                color:           _dimText
                font.pointSize:  ScreenTools.smallFontPointSize
                wrapMode:        Text.WordWrap
            }
        }
    }
}
