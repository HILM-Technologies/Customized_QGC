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

// ─────────────────────────────────────────────────────────────────────────────
//  PlanViewToolBar  –  HILM futuristic dark toolbar for Plan view
// ─────────────────────────────────────────────────────────────────────────────
Rectangle {
    id: _root
    width:  parent.width
    height: ScreenTools.toolbarHeight
    color:  Qt.rgba(0.035, 0.05, 0.05, 1.0)

    property var planMasterController

    property var  _activeVehicle:          QGroundControl.multiVehicleManager.activeVehicle
    property real _controllerProgressPct:  planMasterController.missionController.progressPct

    // ── Design tokens ─────────────────────────────────────────────────────────
    readonly property color _teal:       "#00C8C8"
    readonly property color _tealDim:    Qt.rgba(0, 0.784, 0.784, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property real  _pillH:      Math.round(ScreenTools.defaultFontPixelHeight * 1.75)
    readonly property real  _hpad:       ScreenTools.defaultFontPixelWidth

    QGCPalette { id: qgcPal }

    // ── Bottom teal accent line ───────────────────────────────────────────────
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        height:         1
        color:          _tealBorder
    }

    // ── Exit Plan pill button ─────────────────────────────────────────────────
    Item {
        id:                     exitPlanPill
        anchors.left:           parent.left
        anchors.leftMargin:     _hpad
        anchors.verticalCenter: parent.verticalCenter
        height:                 _pillH
        width:                  exitPillBg.width

        Rectangle {
            id:           exitPillBg
            height:       parent.height
            width:        exitPillRow.implicitWidth + _hpad * 2.2
            radius:       height / 2
            color:        exitHover.containsMouse ? _tealDim : Qt.rgba(0, 0.196, 0.196, 0.2)
            border.color: _teal
            border.width: 1

            Row {
                id:              exitPillRow
                anchors.centerIn: parent
                spacing:          Math.round(ScreenTools.defaultFontPixelWidth * 0.5)

                Text {
                    text:                   "\u2190"
                    color:                  _teal
                    font.bold:              true
                    font.pixelSize:         Math.round(ScreenTools.defaultFontPixelHeight * 0.82)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text:                   qsTr("EXIT PLAN")
                    color:                  "#FFFFFF"
                    font.letterSpacing:     1.5
                    font.pixelSize:         Math.round(ScreenTools.defaultFontPixelHeight * 0.74)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        MouseArea {
            id:           exitHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked: {
                if (mainWindow.allowViewSwitch()) {
                    mainWindow.showFlyView()
                }
            }
        }
    }

    // ── "PLAN EDITOR" dim label ───────────────────────────────────────────────
    Text {
        id:                     planLabel
        anchors.left:           exitPlanPill.right
        anchors.leftMargin:     _hpad * 1.5
        anchors.verticalCenter: parent.verticalCenter
        text:                   "PLAN EDITOR"
        color:                  _teal
        font.letterSpacing:     2.5
        font.bold:              true
        font.pixelSize:         Math.round(ScreenTools.defaultFontPixelHeight * 0.63)
        opacity:                0.45
    }

    // ── Tool buttons strip (horizontally scrollable) ──────────────────────────
    QGCFlickable {
        id:                  toolsFlickable
        anchors.left:        planLabel.right
        anchors.leftMargin:  _hpad
        anchors.rightMargin: _hpad
        anchors.top:         parent.top
        anchors.bottom:      parent.bottom
        anchors.right:       parent.right
        contentWidth:        toolIndicators.width
        flickableDirection:  Flickable.HorizontalFlick

        PlanToolBarIndicators {
            id:                   toolIndicators
            anchors.top:          parent.top
            anchors.bottom:       parent.bottom
            planMasterController: _root.planMasterController
        }
    }

    // ── Thin teal progress bar (bottom edge) ─────────────────────────────────
    Rectangle {
        id:             progressBar
        anchors.left:   parent.left
        anchors.bottom: parent.bottom
        height:         3
        width:          _controllerProgressPct * parent.width
        color:          _teal
        visible:        false

        onVisibleChanged: {
            if (visible) {
                largeProgressBar._userHide = false
            }
        }
    }

    // ── Large progress overlay ────────────────────────────────────────────────
    Rectangle {
        id:      largeProgressBar
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height:         parent.height
        color:          Qt.rgba(0.035, 0.05, 0.05, 0.95)
        visible:        _showLargeProgress

        property bool _userHide:          false
        property bool _showLargeProgress: progressBar.visible && !_userHide && qgcPal.globalTheme === QGCPalette.Light

        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) { largeProgressBar._userHide = false }
        }

        Rectangle {
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          _controllerProgressPct * parent.width
            color:          _tealDim
        }

        Text {
            anchors.centerIn: parent
            text:             qsTr("Syncing Mission")
            color:            _teal
            font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.9
            visible:          _controllerProgressPct !== 1
        }

        Text {
            anchors.centerIn: parent
            text:             qsTr("Done")
            color:            _teal
            font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.9
            visible:          _controllerProgressPct === 1
        }

        Text {
            property real _margin: ScreenTools.defaultFontPixelWidth / 2
            anchors.margins: _margin
            anchors.right:   parent.right
            anchors.bottom:  parent.bottom
            text:            qsTr("Click anywhere to hide")
            color:           Qt.rgba(1, 1, 1, 0.4)
            font.pixelSize:  Math.round(ScreenTools.defaultFontPixelHeight * 0.65)
        }

        MouseArea {
            anchors.fill: parent
            onClicked:    largeProgressBar._userHide = true
        }
    }

    // ── Progress signal handler ───────────────────────────────────────────────
    Connections {
        target: planMasterController.missionController

        function onProgressPctChanged(progressPct) {
            if (progressPct === 1) {
                if (_root.visible) {
                    resetProgressTimer.start()
                } else {
                    progressBar.visible = false
                }
            } else if (progressPct > 0) {
                progressBar.visible = true
            }
        }
    }

    Timer {
        id:          resetProgressTimer
        interval:    3000
        onTriggered: progressBar.visible = false
    }
}
