/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:             _root
    anchors.fill:   parent
    color:          Qt.rgba(0.035, 0.05, 0.05, 1.0)
    z:              QGroundControl.zOrderTopMost

    signal popout()

    // ── HILM design tokens ──────────────────────────────────────
    readonly property color _teal:       "#00C8C8"
    readonly property color _tealBorder: Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)

    readonly property real _defaultTextHeight: ScreenTools.defaultFontPixelHeight
    readonly property real _defaultTextWidth:  ScreenTools.defaultFontPixelWidth
    readonly property real _horizontalMargin:  _defaultTextWidth / 2
    readonly property real _verticalMargin:    _defaultTextHeight / 2
    readonly property real _navWidth:          _defaultTextWidth * 26

    // Block click event leakage to underlying map.
    DeadMouseArea { anchors.fill: parent }

    // Required by GeoTagPage — must remain at root scope
    GeoTagController { id: geoController }

    QGCPalette { id: qgcPal }

    ButtonGroup { id: buttonGroup }

    // ── Left nav panel card (background) ─────────────────────────
    Rectangle {
        id:             navBg
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:          _navWidth + _horizontalMargin * 3
        color:          _cardBg
    }

    // ── Nav header bar ────────────────────────────────────────────
    Rectangle {
        id:             navHeaderBar
        anchors.left:   parent.left
        anchors.top:    parent.top
        width:          navBg.width
        height:         Math.round(ScreenTools.defaultFontPixelHeight * 2.4)
        color:          Qt.rgba(0, 0.784, 0.784, 0.09)

        Rectangle {
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            height:         1
            color:          _tealBorder
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           parent.left
            anchors.leftMargin:     _horizontalMargin * 2
            text:                   qsTr("ANALYZE TOOLS")
            color:                  _teal
            font.bold:              true
            font.letterSpacing:     2.0
            font.pixelSize:         Math.round(ScreenTools.defaultFontPixelHeight * 0.62)
        }
    }

    // ── Navigation button list ─────────────────────────────────────
    QGCFlickable {
        id:                   buttonScroll
        width:                _navWidth
        anchors.left:         parent.left
        anchors.leftMargin:   _horizontalMargin
        anchors.top:          navHeaderBar.bottom
        anchors.topMargin:    _verticalMargin * 0.5
        anchors.bottom:       parent.bottom
        anchors.bottomMargin: _verticalMargin
        contentHeight:        buttonColumn.height + _verticalMargin
        flickableDirection:   Flickable.VerticalFlick
        clip:                 true

        ColumnLayout {
            id:      buttonColumn
            width:   buttonScroll.width
            spacing: 2

            Repeater {
                id:    buttonRepeater
                model: QGroundControl.corePlugin ? QGroundControl.corePlugin.analyzePages : []

                SettingsButton {
                    Layout.fillWidth:  true
                    text:              modelData.title
                    icon.source:       modelData.icon
                    ButtonGroup.group: buttonGroup

                    onClicked: {
                        panelLoader.source = modelData.url
                        panelLoader.title  = modelData.title
                        checked            = true
                    }

                    Component.onCompleted: {
                        if (index === 0) {
                            checked           = true
                            panelLoader.title = modelData.title
                        }
                    }
                }
            }
        }
    }

    // ── Teal divider line ─────────────────────────────────────────
    Rectangle {
        id:                   divider
        anchors.left:         navBg.right
        anchors.top:          parent.top
        anchors.bottom:       parent.bottom
        anchors.topMargin:    _verticalMargin
        anchors.bottomMargin: _verticalMargin
        width:                1
        color:                _tealBorder
    }

    // ── Content area background — uses qgcPal.window so loaded
    //    pages (which assume standard QGC window background) stay
    //    legible. Rendered BEFORE panelLoader.  ──────────────────
    Rectangle {
        anchors.left:   divider.right
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        color:          qgcPal.window
    }

    // ── Right content panel ───────────────────────────────────────
    Loader {
        id:                   panelLoader
        anchors.left:         divider.right
        anchors.leftMargin:   _horizontalMargin * 2
        anchors.right:        parent.right
        anchors.rightMargin:  _horizontalMargin
        anchors.top:          parent.top
        anchors.topMargin:    _verticalMargin
        anchors.bottom:       parent.bottom
        anchors.bottomMargin: _verticalMargin
        source:               "LogDownloadPage.qml"

        property string title

        Connections {
            target:     panelLoader.item
            function onPopout() { mainWindow.createrWindowedAnalyzePage(panelLoader.title, panelLoader.source) }
        }
    }
}
