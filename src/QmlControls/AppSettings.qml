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
import QGroundControl.AppSettings

Rectangle {
    id:             settingsView
    anchors.fill:   parent
    color:          Qt.rgba(0.035, 0.05, 0.05, 1.0)
    z:              QGroundControl.zOrderTopMost

    // ── HILM design tokens ──────────────────────────────────────
    readonly property color _teal:       "#00C8C8"
    readonly property color _tealBorder: Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)

    readonly property real _defaultTextHeight: ScreenTools.defaultFontPixelHeight
    readonly property real _defaultTextWidth:  ScreenTools.defaultFontPixelWidth
    readonly property real _horizontalMargin:  _defaultTextWidth / 2
    readonly property real _verticalMargin:    _defaultTextHeight / 2
    // Nav panel wide enough for the longest label ("PX4 Log Transfer")
    readonly property real _navWidth:          _defaultTextWidth * 22

    property bool _first:                  true
    property bool _commingFromRIDSettings: false

    function showSettingsPage(settingsPage) {
        for (var i = 0; i < buttonRepeater.count; i++) {
            var loader = buttonRepeater.itemAt(i)
            if (loader && loader.item && loader.item.text === settingsPage) {
                loader.item.clicked()
                break
            }
        }
    }

    // Block click event leakage to underlying map.
    DeadMouseArea { anchors.fill: parent }

    QGCPalette { id: qgcPal }

    Component.onCompleted: {
        if (globals.commingFromRIDIndicator) {
            rightPanel.source = "qrc:/qml/QGroundControl/AppSettings/RemoteIDSettings.qml"
            globals.commingFromRIDIndicator = false
        } else {
            rightPanel.source = "qrc:/qml/QGroundControl/AppSettings/GeneralSettings.qml"
        }
    }

    SettingsPagesModel { id: settingsPagesModel }
    ButtonGroup       { id: buttonGroup }

    // ── Left nav panel card (background, rendered first / behind buttons) ──
    Rectangle {
        id:             navBg
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:          _navWidth + _horizontalMargin * 3
        color:          _cardBg

        // Teal right-edge separator
        Rectangle {
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          1
            color:          _tealBorder
        }
    }

    // ── Nav header bar — direct sibling of buttonList (valid anchor target) ──
    Rectangle {
        id:             navHeaderBar
        anchors.left:   parent.left
        anchors.top:    parent.top
        width:          navBg.width
        height:         Math.round(ScreenTools.defaultFontPixelHeight * 2.4)
        color:          Qt.rgba(0, 0.784, 0.784, 0.09)

        // Bottom teal line
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
            text:                   qsTr("SYSTEM SETTINGS")
            color:                  _teal
            font.bold:              true
            font.letterSpacing:     2.0
            font.pixelSize:         Math.round(ScreenTools.defaultFontPixelHeight * 0.62)
        }
    }

    // ── Navigation button list ───────────────────────────────────
    QGCFlickable {
        id:                   buttonList
        width:                _navWidth
        anchors.left:         parent.left
        anchors.leftMargin:   _horizontalMargin
        anchors.top:          navHeaderBar.bottom      // sibling — valid anchor
        anchors.topMargin:    _verticalMargin * 0.5
        anchors.bottom:       parent.bottom
        anchors.bottomMargin: _verticalMargin
        contentHeight:        buttonColumn.height + _verticalMargin
        flickableDirection:   Flickable.VerticalFlick
        clip:                 true

        ColumnLayout {
            id:      buttonColumn
            width:   buttonList.width
            spacing: 2

            property real _maxButtonWidth: 0

            Component {
                id: dividerComponent
                Item {
                    height: Math.round(ScreenTools.defaultFontPixelHeight * 0.85)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.right:          parent.right
                        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 0.4
                        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 0.4
                        height:                 1
                        color:                  Qt.rgba(0, 0.784, 0.784, 0.20)
                    }
                }
            }

            Component {
                id: buttonComponent

                SettingsButton {
                    text:               modelName
                    icon.source:        modelIconUrl
                    visible:            modelPageVisible()
                    ButtonGroup.group:  buttonGroup

                    onClicked: {
                        if (mainWindow.allowViewSwitch()) {
                            if (rightPanel.source !== modelUrl) {
                                rightPanel.source = modelUrl
                            }
                            checked = true
                        }
                    }

                    Component.onCompleted: {
                        if (globals.commingFromRIDIndicator) {
                            _commingFromRIDSettings = true
                        }
                        if (_first) {
                            _first = false
                            checked = true
                        }
                        if (_commingFromRIDSettings) {
                            checked = false
                            _commingFromRIDSettings = false
                            if (modelUrl === "qrc:/qml/QGroundControl/AppSettings/RemoteIDSettings.qml") {
                                checked = true
                            }
                        }
                    }
                }
            }

            Repeater {
                id:     buttonRepeater
                model:  settingsPagesModel

                Loader {
                    Layout.fillWidth: true
                    sourceComponent:  _sourceComponent()

                    property var modelName:        name
                    property var modelIconUrl:     iconUrl
                    property var modelUrl:         url
                    property var modelPageVisible: pageVisible

                    function _sourceComponent() {
                        if (name === "Divider") {
                            return dividerComponent
                        } else if (pageVisible()) {
                            return buttonComponent
                        } else {
                            return undefined
                        }
                    }
                }
            }
        }
    }

    // ── Teal divider line at nav panel right edge ────────────────
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

    // ── Content area background — uses qgcPal.window so settings
    //    pages (which assume a standard QGC window background) are
    //    fully legible. Rendered BEFORE rightPanel Loader so it
    //    sits behind the loaded content.  ─────────────────────────
    Rectangle {
        anchors.left:   divider.right
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        color:          qgcPal.window
    }

    // ── Right content panel ──────────────────────────────────────
    Loader {
        id:                   rightPanel
        anchors.left:         divider.right
        anchors.leftMargin:   _horizontalMargin * 2
        anchors.right:        parent.right
        anchors.rightMargin:  _horizontalMargin
        anchors.top:          parent.top
        anchors.topMargin:    _verticalMargin
        anchors.bottom:       parent.bottom
        anchors.bottomMargin: _verticalMargin
    }
}
