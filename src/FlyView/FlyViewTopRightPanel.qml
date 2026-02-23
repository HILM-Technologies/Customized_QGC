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
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

Rectangle {
    id:             topRightPanel
    width:          contentWidth
    height:         Math.max(contentHeight, minimumHeight)
    color:          Qt.rgba(10/255, 10/255, 10/255, 0.88)
    radius:         ScreenTools.defaultFontPixelHeight / 2
    visible:        !QGroundControl.videoManager.fullScreen && _multipleVehicles && _settingEnableMVPanel
    clip:           true
    border.color:   Qt.rgba(0, 0.784, 0.784, 0.32)
    border.width:   1

    // ── HILM design tokens ────────────────────────────────────────────────────
    readonly property color _teal:       "#00C8C8"
    readonly property color _tealDim:    Qt.rgba(0, 0.784, 0.784, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth * 0.75

    property bool _settingEnableMVPanel: QGroundControl.settingsManager.appSettings.enableMultiVehiclePanel.value
    property bool  _multipleVehicles:    QGroundControl.multiVehicleManager.vehicles.count > 0
    property var   vehicles:             QGroundControl.multiVehicleManager.vehicles
    property var   selectedVehicles:     QGroundControl.multiVehicleManager.selectedVehicles
    property real  contentWidth:         Math.max(
                                             multiVehicleList.implicitWidth,
                                             swipeViewContainer.implicitWidth
                                         ) + ScreenTools.defaultFontPixelHeight
    property real  contentHeight:        Math.min(
                                             maximumHeight,
                                             topRightPanelColumnLayout.implicitHeight
                                                 + topRightPanelColumnLayout.spacing
                                                 * (topRightPanelColumnLayout.children.length - 1)
                                         )
    property real  minimumHeight:        fleetHeader.height + swipeViewContainer.height
    property real  maximumHeight

    QGCPalette { id: qgcPal }

    DeadMouseArea { anchors.fill: parent }

    ColumnLayout {
        id:             topRightPanelColumnLayout
        anchors.fill:   parent
        spacing:        0

        // ── FLEET CONTROL header ──────────────────────────────────────────────
        Rectangle {
            id:               fleetHeader
            Layout.fillWidth: true
            height:           ScreenTools.defaultFontPixelHeight * 2.4
            color:            _tealDim
            radius:           topRightPanel.radius
            // Only round top corners
            Rectangle {
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                height:         parent.radius
                color:          parent.color
            }

            Row {
                anchors.left:           parent.left
                anchors.leftMargin:     _pad
                anchors.right:          parent.right
                anchors.rightMargin:    _pad
                anchors.verticalCenter: parent.verticalCenter
                spacing:                _pad * 0.6

                // Accent bar
                Rectangle {
                    width:                  3
                    height:                 parent.height * 0.7
                    radius:                 2
                    color:                  _teal
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Title
                Text {
                    text:                   qsTr("FLEET CONTROL")
                    color:                  _teal
                    font.bold:              true
                    font.letterSpacing:     2.0
                    font.pointSize:         ScreenTools.defaultFontPointSize * 0.8
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: 1; height: 1; Layout.fillWidth: true }

                // Spacer
                Item {
                    width:  parent.width
                           - 3 - _pad * 0.6        // accent
                           - (ScreenTools.defaultFontPixelWidth * 9)  // title approx
                           - countBadge.width - _pad * 0.6
                           - _pad * 2
                    height: 1
                }

                // Vehicle count badge
                Rectangle {
                    id:                     countBadge
                    anchors.verticalCenter: parent.verticalCenter
                    width:                  Math.max(countText.implicitWidth + _pad, ScreenTools.defaultFontPixelHeight * 1.4)
                    height:                 ScreenTools.defaultFontPixelHeight * 1.3
                    radius:                 height / 2
                    color:                  _teal

                    Text {
                        id:               countText
                        anchors.centerIn: parent
                        text:             QGroundControl.multiVehicleManager.vehicles.count
                        color:            "#000"
                        font.bold:        true
                        font.pointSize:   ScreenTools.smallFontPointSize
                    }
                }
            }
        }

        // ── Thin teal separator ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            _tealBorder
        }

        // ── Vehicle list ──────────────────────────────────────────────────────
        MultiVehicleList {
            id:                    multiVehicleList
            Layout.fillWidth:      true
            Layout.fillHeight:     true

            Rectangle {
                anchors.fill: parent
                visible:      topRightPanel.height === maximumHeight

                Rectangle {
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    height:          1
                    color:           Qt.rgba(0, 0.784, 0.784, 0.2)
                }

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.00; color: topRightPanel.color }
                    GradientStop { position: 0.05; color: "transparent" }
                    GradientStop { position: 0.95; color: "transparent" }
                    GradientStop { position: 1.00; color: topRightPanel.color }
                }

                Rectangle {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    anchors.bottom: parent.bottom
                    height:         1
                    color:          Qt.rgba(0, 0.784, 0.784, 0.2)
                }
            }
        }

        // ── Thin separator before actions ─────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            _tealBorder
        }

        // ── Selection + Action buttons ────────────────────────────────────────
        Rectangle {
            id:               swipeViewContainer
            Layout.fillWidth: true
            implicitHeight:   swipePages.implicitHeight
            implicitWidth:    swipePages.implicitWidth
            color:            "transparent"

            QGCSwipeView {
                id:            swipePages
                anchors.fill:  parent
                spacing:       ScreenTools.defaultFontPixelHeight
                implicitHeight: Math.max(buttonsPage.implicitHeight, photoVideoPage.implicitHeight)
                implicitWidth:  Math.max(buttonsPage.implicitWidth, photoVideoPage.implicitWidth)

                MvPanelPage {
                    id:            buttonsPage
                    implicitHeight: buttonsColumnLayout.implicitHeight + ScreenTools.defaultFontPixelHeight * 2
                    implicitWidth:  buttonsColumnLayout.implicitWidth + ScreenTools.defaultFontPixelHeight * 2

                    ColumnLayout {
                        id:                     buttonsColumnLayout
                        anchors.right:          parent.right
                        anchors.left:           parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:                _pad * 0.75
                        implicitHeight:         Math.max(selectionRowLayout.height, actionRowLayout.height)
                                                    + ScreenTools.defaultFontPixelHeight * 2
                        implicitWidth:          Math.max(selectionRowLayout.width, actionRowLayout.width)
                                                    + ScreenTools.defaultFontPixelHeight * 4

                        // Selection label
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text:             qsTr("MULTI VEHICLE SELECTION")
                            color:            _teal
                            font.bold:        true
                            font.letterSpacing: 1.0
                            font.pointSize:   ScreenTools.smallFontPointSize * 0.9
                        }

                        RowLayout {
                            id:               selectionRowLayout
                            Layout.alignment: Qt.AlignHCenter
                            spacing:          _pad * 0.5

                            QGCButton {
                                text:    qsTr("✓ ALL")
                                enabled: multiVehicleList.selectedVehicles
                                             && multiVehicleList.selectedVehicles.count
                                             !== QGroundControl.multiVehicleManager.vehicles.count
                                onClicked: multiVehicleList.selectAll()
                            }
                            QGCButton {
                                text:    qsTr("✗ NONE")
                                enabled: multiVehicleList.selectedVehicles
                                             && multiVehicleList.selectedVehicles.count > 0
                                onClicked: multiVehicleList.deselectAll()
                            }
                        }

                        // ── Thin divider
                        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(0, 0.784, 0.784, 0.2) }

                        // Actions label
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text:             qsTr("MULTI VEHICLE ACTIONS")
                            color:            _teal
                            font.bold:        true
                            font.letterSpacing: 1.0
                            font.pointSize:   ScreenTools.smallFontPointSize * 0.9
                        }

                        RowLayout {
                            id:               actionRowLayout
                            Layout.alignment: Qt.AlignHCenter
                            spacing:          _pad * 0.5

                            QGCButton {
                                text:                  qsTr("ARM")
                                enabled:               multiVehicleList.armAvailable()
                                onClicked:             _guidedController.confirmAction(_guidedController.actionMVArm)
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.75
                                leftPadding:           0
                                rightPadding:          0
                            }
                            QGCButton {
                                text:                  qsTr("DISARM")
                                enabled:               multiVehicleList.disarmAvailable()
                                onClicked:             _guidedController.confirmAction(_guidedController.actionMVDisarm)
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.75
                                leftPadding:           0
                                rightPadding:          0
                            }
                            QGCButton {
                                text:                  qsTr("START")
                                enabled:               multiVehicleList.startAvailable()
                                onClicked:             _guidedController.confirmAction(_guidedController.actionMVStartMission)
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.75
                                leftPadding:           0
                                rightPadding:          0
                            }
                            QGCButton {
                                text:                  qsTr("PAUSE")
                                enabled:               multiVehicleList.pauseAvailable()
                                onClicked:             _guidedController.confirmAction(_guidedController.actionMVPause)
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.75
                                leftPadding:           0
                                rightPadding:          0
                            }
                        }
                    }
                } // Page 1

                MvPanelPage {
                    id:            photoVideoPage
                    implicitHeight: photoVideoControlLoader.implicitHeight + ScreenTools.defaultFontPixelHeight * 2
                    implicitWidth:  photoVideoControlLoader.implicitWidth + ScreenTools.defaultFontPixelHeight * 2

                    Loader {
                        id:                        photoVideoControlLoader
                        anchors.horizontalCenter:  parent.horizontalCenter
                        sourceComponent:           globals.activeVehicle ? photoVideoControlComponent : undefined

                        property real rightEdgeCenterInset: visible ? parent.width - x : 0

                        Component {
                            id: photoVideoControlComponent
                            PhotoVideoControl { }
                        }
                    }
                } // Page 2
            }

            QGCPageIndicator {
                id:                       pageIndicator
                count:                    swipePages.count
                currentIndex:             swipePages.currentIndex
                anchors.bottom:           parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.margins:          ScreenTools.defaultFontPixelHeight / 4

                delegate: Rectangle {
                    height:  ScreenTools.defaultFontPixelHeight / 2
                    width:   height
                    radius:  width / 2
                    color:   model.index === pageIndicator.currentIndex ? "#00C8C8" : Qt.rgba(0, 0.784, 0.784, 0.25)
                    opacity: model.index === pageIndicator.currentIndex ? 1.0 : 0.4
                }
            }
        }
    }

    property var _guidedController: globals.guidedControllerFlyView
}
