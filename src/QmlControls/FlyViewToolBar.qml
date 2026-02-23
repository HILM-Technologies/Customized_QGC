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
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Item {
    required property var guidedValueSlider
    required property bool utmspSliderTrigger

    id:     control
    width:  parent.width
    height: ScreenTools.toolbarHeight

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property color  _mainStatusBGColor: "#00C8C8"
    property real   _leftRightMargin:   ScreenTools.defaultFontPixelWidth * 0.75
    property var    _guidedController:  globals.guidedControllerFlyView

    // ── HILM design tokens ────────────────────────────────────────────────────
    readonly property color _teal:       "#00C8C8"
    readonly property color _tealDim:    Qt.rgba(0, 0.784, 0.784, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property real  _hpad:       ScreenTools.defaultFontPixelWidth * 0.9
    readonly property real  _pillH:      ScreenTools.toolbarHeight * 0.58
    readonly property real  _pillR:      4

    function dropMainStatusIndicatorTool() {
        mainStatusIndicator.dropMainStatusIndicator();
    }

    QGCPalette { id: qgcPal }

    // ── Toolbar background ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:        Qt.rgba(10/255, 12/255, 12/255, 0.92)
    }
    // Teal gradient fade from left
    Rectangle {
        height: parent.height
        width:  parent.width * 0.45
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0, 0.196, 0.196, 0.85) }
            GradientStop { position: 0.6; color: Qt.rgba(0, 0.784, 0.784, 0.08) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    // Bottom border
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        height:         1
        color:          _tealBorder
    }

    QGCFlickable {
        anchors.fill:       parent
        contentWidth:       toolBarLayout.width
        flickableDirection: Flickable.HorizontalFlick

        Row {
            id:      toolBarLayout
            height:  parent.height
            spacing: 0

            // ══════════════════════════════════════════════════════════════════
            //  LEFT PANEL
            // ══════════════════════════════════════════════════════════════════
            Item {
                id:     leftPanel
                width:  leftPanelLayout.implicitWidth
                height: parent.height

                RowLayout {
                    id:      leftPanelLayout
                    height:  parent.height
                    spacing: _hpad

                    // ── HILM logo ─────────────────────────────────────────────
                    RowLayout {
                        id:      mainStatusLayout
                        height:  parent.height
                        spacing: 0

                        Rectangle {
                            Layout.fillHeight: true
                            width:             hilmLogoRow.implicitWidth + _hpad * 2
                            color:             logoMouseArea.pressed
                                                   ? Qt.rgba(0, 0.784, 0.784, 0.25)
                                                   : "transparent"

                            Row {
                                id:              hilmLogoRow
                                anchors.centerIn: parent
                                spacing:          ScreenTools.defaultFontPixelWidth * 0.75

                                Image {
                                    source:   "/res/HilmLogo.svg"
                                    height:   ScreenTools.defaultFontPixelHeight * 1.8
                                    width:    height
                                    fillMode: Image.PreserveAspectFit
                                    smooth:   true
                                    mipmap:   true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text:               qsTr("HILM")
                                    color:              _teal
                                    font.bold:          true
                                    font.letterSpacing: 2
                                    font.pointSize:     ScreenTools.defaultFontPointSize
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id:           logoMouseArea
                                anchors.fill: parent
                                // Single click → landing page
                                // Long-press  → tool select dialog (advanced)
                                onClicked:     mainWindow.showLandingPage()
                                onPressAndHold: mainWindow.showToolSelectDialog()
                            }
                        }

                        MainStatusIndicator {
                            id:                mainStatusIndicator
                            Layout.fillHeight: true
                        }
                    }

                    // ── Disconnect (comm lost) ────────────────────────────────
                    QGCButton {
                        id:      disconnectButton
                        text:    qsTr("Disconnect")
                        onClicked: _activeVehicle.closeVehicle()
                        visible: _activeVehicle && _communicationLost
                    }

                    // ── STATUS pill label + separator ─────────────────────────
                    Row {
                        spacing:             _hpad * 0.5
                        Layout.alignment:    Qt.AlignVCenter
                        visible:             _activeVehicle !== null

                        // Separator
                        Rectangle {
                            width:                  1
                            height:                 _pillH * 0.8
                            color:                  _tealBorder
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // MODE pill wrapper
                        Rectangle {
                            height:                 _pillH
                            width:                  modePillRow.implicitWidth + _hpad * 1.5
                            anchors.verticalCenter: parent.verticalCenter
                            color:                  _tealDim
                            border.color:           _tealBorder
                            border.width:           1
                            radius:                 _pillR

                            Row {
                                id:              modePillRow
                                anchors.centerIn: parent
                                spacing:          ScreenTools.defaultFontPixelWidth * 0.5

                                Text {
                                    text:                   qsTr("MODE")
                                    color:                  _dimText
                                    font.pointSize:         ScreenTools.smallFontPointSize * 0.85
                                    font.letterSpacing:     0.8
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                FlightModeIndicator {
                                    height:                 _pillH * 0.82
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════════
            //  CENTER PANEL — guided action confirm (unchanged)
            // ══════════════════════════════════════════════════════════════════
            Item {
                id:     centerPanel
                width:  Math.max(
                            guidedActionConfirm.visible ? guidedActionConfirm.width : 0,
                            control.width - (leftPanel.width + rightPanel.width)
                        )
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    color:        qgcPal.windowTransparent
                }

                GuidedActionConfirm {
                    id:                       guidedActionConfirm
                    height:                   parent.height
                    anchors.horizontalCenter: parent.horizontalCenter
                    guidedController:         control._guidedController
                    guidedValueSlider:        control.guidedValueSlider
                    utmspSliderTrigger:       control.utmspSliderTrigger
                    messageDisplay:           guidedActionMessageDisplay
                }
            }

            // ══════════════════════════════════════════════════════════════════
            //  RIGHT PANEL — indicator pills with teal left separator
            // ══════════════════════════════════════════════════════════════════
            Item {
                id:     rightPanel
                width:  rightSep.width + flyViewIndicators.width + _hpad
                height: parent.height

                // Teal left-edge separator (matches Mode pill separator)
                Rectangle {
                    id:                     rightSep
                    width:                  1
                    height:                 _pillH * 0.8
                    anchors.verticalCenter: parent.verticalCenter
                    color:                  _tealBorder
                }

                FlyViewToolBarIndicators {
                    id:           flyViewIndicators
                    height:       parent.height
                    anchors.left: rightSep.right
                }
            }
        }
    }

    // ── Guided action message display (unchanged) ─────────────────────────────
    Rectangle {
        id:                         guidedActionMessageDisplay
        anchors.top:                control.bottom
        anchors.topMargin:          _margins
        x:                          control.mapFromItem(guidedActionConfirm.parent, guidedActionConfirm.x, 0).x
                                        + (guidedActionConfirm.width - guidedActionMessageDisplay.width) / 2
        width:                      messageLabel.contentWidth + (_margins * 2)
        height:                     messageLabel.contentHeight + (_margins * 2)
        color:                      qgcPal.windowTransparent
        radius:                     ScreenTools.defaultBorderRadius
        visible:                    guidedActionConfirm.visible

        QGCLabel {
            id:       messageLabel
            x:        _margins
            y:        _margins
            width:    ScreenTools.defaultFontPixelWidth * 30
            wrapMode: Text.WordWrap
            text:     guidedActionConfirm.message
        }

        PropertyAnimation {
            id:       messageOpacityAnimation
            target:   guidedActionMessageDisplay
            property: "opacity"
            from:     1
            to:       0
            duration: 500
        }

        Timer {
            id:          messageFadeTimer
            interval:    4000
            onTriggered: messageOpacityAnimation.start()
        }
    }

    ParameterDownloadProgress {
        anchors.fill: parent
    }
}
