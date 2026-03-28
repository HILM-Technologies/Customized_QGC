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
    id:     _root
    color:  "#0D1117"
    z:      QGroundControl.zOrderTopMost

    signal popout()

    // ── HILM design tokens ──────────────────────────────────
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)

    readonly property real  _pad:               ScreenTools.defaultFontPixelWidth * 1.2
    readonly property real  _defaultTextHeight: ScreenTools.defaultFontPixelHeight
    readonly property real  _defaultTextWidth:  ScreenTools.defaultFontPixelWidth
    readonly property real  _horizontalMargin:  _defaultTextWidth
    readonly property real  _verticalMargin:    _defaultTextHeight * 0.6
    readonly property real  _buttonWidth:       _defaultTextWidth * 18

    DeadMouseArea {
        anchors.fill: parent
    }

    GeoTagController {
        id: geoController
    }

    // ── Sidebar ─────────────────────────────────────────────
    Rectangle {
        id:             sidebarBg
        width:          buttonScroll.width + _horizontalMargin * 2
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        color:          Qt.rgba(1, 1, 1, 0.03)

        Rectangle {
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          1
            color:          _tealBorder
        }
    }

    QGCFlickable {
        id:                 buttonScroll
        width:              buttonColumn.width
        anchors.topMargin:  _defaultTextHeight
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        anchors.leftMargin: _horizontalMargin
        anchors.left:       parent.left
        contentHeight:      buttonColumn.height
        flickableDirection:  Flickable.VerticalFlick
        clip:               true

        Column {
            id:         buttonColumn
            width:      _maxButtonWidth
            spacing:    _defaultTextHeight * 0.4

            property real _maxButtonWidth: 0

            Component.onCompleted: reflowWidths()

            Connections {
                target:         QGroundControl.settingsManager.appSettings.appFontPointSize
                function onValueChanged(value) { buttonColumn.reflowWidths() }
            }

            function reflowWidths() {
                buttonColumn._maxButtonWidth = 0
                for (var i = 0; i < children.length; i++) {
                    buttonColumn._maxButtonWidth = Math.max(buttonColumn._maxButtonWidth, children[i].width)
                }
                for (var j = 0; j < children.length; j++) {
                    children[j].width = buttonColumn._maxButtonWidth
                }
            }

            Repeater {
                id:     buttonRepeater
                model:  QGroundControl.corePlugin ? QGroundControl.corePlugin.analyzePages : []

                Component.onCompleted:  itemAt(0).checked = true

                SubMenuButton {
                    id:                 subMenu
                    imageResource:      modelData.icon
                    autoExclusive:      true
                    text:               modelData.title

                    onClicked: {
                        panelLoader.source  = modelData.url
                        panelLoader.title   = modelData.title
                        checked             = true
                    }
                }
            }
        }
    }

    // ── Content area ────────────────────────────────────────
    Loader {
        id:                     panelLoader
        anchors.topMargin:      _verticalMargin
        anchors.bottomMargin:   _verticalMargin
        anchors.leftMargin:     _horizontalMargin * 1.5
        anchors.rightMargin:    _horizontalMargin
        anchors.left:           sidebarBg.right
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        source:                 "LogDownloadPage.qml"

        property string title

        Connections {
            target:     panelLoader.item
            function onPopout() { mainWindow.createrWindowedAnalyzePage(panelLoader.title, panelLoader.source) }
        }
    }
}
