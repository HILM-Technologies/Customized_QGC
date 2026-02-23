/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed under the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Toolbar

Item {
    implicitWidth: mainLayout.width + _widthMargin

    property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property real _widthMargin:   ScreenTools.defaultFontPixelWidth * 0.75

    // ── HILM design tokens (mirrors FlyViewToolBar.qml) ──────────────────────
    readonly property color _pillBg:     Qt.rgba(0, 0.196, 0.196, 0.28)
    readonly property color _pillBorder: Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property real  _pillH:      ScreenTools.toolbarHeight * 0.58
    readonly property real  _pillR:      4
    readonly property real  _hpad:       ScreenTools.defaultFontPixelWidth * 0.9

    Row {
        id:             mainLayout
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth * 0.75

        // ── App-level indicators (from core plugin) ───────────────────────────
        Repeater {
            id:    appRepeater
            model: QGroundControl.corePlugin.toolBarIndicators

            Item {
                id:             appPill
                anchors.top:    parent.top
                anchors.bottom: parent.bottom

                // Use !== false so indicators without showIndicator stay visible
                property bool _show: appLoader.item ? (appLoader.item.showIndicator !== false) : false
                width:   _show ? appLoader.item.width + _hpad * 2 : 0
                visible: _show

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left:  parent.left
                    anchors.right: parent.right
                    height:        _pillH
                    radius:        _pillR
                    color:         _pillBg
                    border.color:  _pillBorder
                    border.width:  1
                }

                Loader {
                    id:                       appLoader
                    // Constrain to pill height so icons don't overflow the pill border
                    height:                   _pillH
                    anchors.verticalCenter:   parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    source:                   modelData
                }
            }
        }

        // ── Vehicle-specific indicators ───────────────────────────────────────
        Repeater {
            id:    toolIndicatorsRepeater
            model: _activeVehicle ? _activeVehicle.toolIndicators : []

            Item {
                id:             vehiclePill
                anchors.top:    parent.top
                anchors.bottom: parent.bottom

                // Use !== false so indicators without showIndicator stay visible
                property bool _show: vehicleLoader.item ? (vehicleLoader.item.showIndicator !== false) : false
                width:   _show ? vehicleLoader.item.width + _hpad * 2 : 0
                visible: _show

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left:  parent.left
                    anchors.right: parent.right
                    height:        _pillH
                    radius:        _pillR
                    color:         _pillBg
                    border.color:  _pillBorder
                    border.width:  1
                }

                Loader {
                    id:                       vehicleLoader
                    // Constrain to pill height so icons don't overflow the pill border
                    height:                   _pillH
                    anchors.verticalCenter:   parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    source:                   modelData
                }
            }
        }
    }
}
