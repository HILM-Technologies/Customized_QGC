/****************************************************************************
 *
 * HILM Ground Control — Route Planning Overlay (top-left of PlanView map)
 * Shows Launch Zone status, Quick Mission instructions, Clear Route,
 * Layers selector (STD/DRK/SAT), and waypoint count.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: overlay

    required property var planMasterController
    required property var missionController
    required property var editorMap

    width:  overlayLayout.implicitWidth + _pad * 3
    height: overlayLayout.implicitHeight + _pad * 2.5
    radius: ScreenTools.defaultFontPixelHeight * 0.4
    color:  Qt.rgba(0, 0, 0, 0.80)
    border.width: 1
    border.color: Qt.rgba(0, 0.749, 1.0, 0.18)

    // HILM design tokens
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property color _errColor:   "#FF5252"
    readonly property color _okColor:    "#4CAF50"
    readonly property color _warnColor:  "#FF9800"
    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth * 0.8

    // Waypoint count (subtract home position item at index 0)
    readonly property int _waypointCount: missionController
                                          ? Math.max(0, missionController.visualItems.count - 1) : 0

    // Launch zone status — check if home position is not default (0,0)
    property bool _launchZoneSet: {
        if (!missionController || !missionController.visualItems
            || missionController.visualItems.count === 0) return false
        var homeItem = missionController.visualItems.get(0)
        if (!homeItem || !homeItem.coordinate) return false
        return homeItem.coordinate.latitude !== 0 || homeItem.coordinate.longitude !== 0
    }

    // Clear route feedback state
    property bool _routeCleared: false

    // Layers dropdown expanded state
    property bool _layersExpanded: false

    // Dark mode overlay flag (read by PlanView to show dark tint)
    property bool darkModeEnabled: false

    // Current active map type detection
    property string _activeMapStyle: {
        if (darkModeEnabled) return "DRK"
        var settings = QGroundControl.settingsManager.flightMapSettings
        var typeName = settings.mapType.value
        if (typeName === "Satellite" || typeName === "Hybrid") return "SAT"
        return "STD"
    }

    // Map type setter
    function _setMapType(provider, mapType, dark) {
        var settings = QGroundControl.settingsManager.flightMapSettings
        settings.mapProvider.rawValue = provider
        settings.mapType.rawValue = mapType
        darkModeEnabled = dark ? true : false
        _layersExpanded = false
    }

    Timer {
        id: clearFeedbackTimer
        interval: 2000
        onTriggered: overlay._routeCleared = false
    }

    DeadMouseArea { anchors.fill: parent }

    ColumnLayout {
        id: overlayLayout
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.top:     parent.top
        anchors.margins: _pad * 1.2
        spacing:         _pad * 0.8

        // ── HEADER ──
        RowLayout {
            spacing: _pad * 0.5

            QGCColoredImage {
                width:    ScreenTools.defaultFontPixelHeight * 1.0
                height:   width
                source:   "/qmlimages/Plan.svg"
                color:    _teal
                fillMode: Image.PreserveAspectFit
            }

            QGCLabel {
                text:               "ROUTE PLANNING"
                color:              _teal
                font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.85
                font.bold:          true
                font.letterSpacing: 1.0
            }
        }

        // ── Separator ──
        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            Qt.rgba(1, 1, 1, 0.08)
        }

        // ── LAUNCH ZONE ──
        RowLayout {
            spacing: _pad * 0.5

            QGCColoredImage {
                width:    ScreenTools.defaultFontPixelHeight * 0.8
                height:   width
                source:   "/qmlimages/MapHome.svg"
                color:    _teal
                fillMode: Image.PreserveAspectFit
            }

            QGCLabel {
                text:           "Launch Zone:"
                color:          "white"
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                font.bold:      true
            }

            QGCLabel {
                text:           _launchZoneSet ? "Set" : "Not Set"
                color:          _launchZoneSet ? _okColor : _dimText
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                font.bold:      true
            }
        }

        QGCLabel {
            text:              "Right-click map to set launch zone"
            color:             _dimText
            font.pixelSize:    ScreenTools.defaultFontPixelHeight * 0.55
            Layout.leftMargin: _pad * 0.3
        }

        // ── Separator ──
        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            Qt.rgba(1, 1, 1, 0.06)
        }

        // ── QUICK MISSION ──
        RowLayout {
            spacing: _pad * 0.5

            // CTRL badge
            Rectangle {
                width:  ctrlLabel.implicitWidth + _pad * 1.2
                height: ctrlLabel.implicitHeight + _pad * 0.6
                radius: ScreenTools.defaultFontPixelHeight * 0.15
                color:  _tealDim
                border.width: 1
                border.color: _tealBorder

                QGCLabel {
                    id:             ctrlLabel
                    anchors.centerIn: parent
                    text:           "CTRL"
                    color:          _teal
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                    font.bold:      true
                    font.letterSpacing: 0.3
                }
            }

            QGCLabel {
                text:           "Quick Mission"
                color:          "white"
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                font.bold:      true
            }
        }

        QGCLabel {
            text:              "Click on map to add waypoints"
            color:             _dimText
            font.pixelSize:    ScreenTools.defaultFontPixelHeight * 0.55
            Layout.leftMargin: _pad * 0.3
        }

        QGCLabel {
            text:              "Return to launch is auto-added"
            color:             Qt.rgba(0, 0.749, 1.0, 0.65)
            font.pixelSize:    ScreenTools.defaultFontPixelHeight * 0.5
            Layout.leftMargin: _pad * 0.3
        }

        // ── Waypoint Count (visible when waypoints exist) ──
        RowLayout {
            visible: _waypointCount > 0
            spacing: _pad * 0.5

            Rectangle {
                width:  wpCountLabel.implicitWidth + _pad * 1.2
                height: wpCountLabel.implicitHeight + _pad * 0.6
                radius: height / 2
                color:  _tealDim
                border.width: 1
                border.color: _tealBorder

                QGCLabel {
                    id: wpCountLabel
                    anchors.centerIn: parent
                    text:           _waypointCount
                    color:          _teal
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                    font.bold:      true
                }
            }

            QGCLabel {
                text:           _waypointCount === 1 ? "Waypoint" : "Waypoints"
                color:          "white"
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                font.bold:      true
            }
        }

        // ── Separator ──
        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            Qt.rgba(1, 1, 1, 0.06)
        }

        // ── CLEAR ROUTE + Layers ──
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad * 0.5

            // Clear Route button (with feedback)
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.0
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  _routeCleared
                                        ? Qt.rgba(0.298, 0.686, 0.314, 0.10)
                                        : (clearMouse.containsMouse ? Qt.rgba(1, 0.32, 0.32, 0.10) : "transparent")
                border.width:           1
                border.color:           _routeCleared
                                        ? _okColor
                                        : (clearMouse.containsMouse ? _errColor : Qt.rgba(1, 1, 1, 0.12))

                RowLayout {
                    anchors.centerIn: parent
                    spacing: _pad * 0.4

                    QGCColoredImage {
                        width:    ScreenTools.defaultFontPixelHeight * 0.65
                        height:   width
                        source:   _routeCleared ? "/qmlimages/MapAddMission.svg" : "/res/TrashDelete.svg"
                        color:    _routeCleared ? _okColor : (clearMouse.containsMouse ? _errColor : _dimText)
                        fillMode: Image.PreserveAspectFit
                    }

                    QGCLabel {
                        text:               _routeCleared ? "ROUTE CLEARED" : "CLEAR ROUTE"
                        color:              _routeCleared ? _okColor : (clearMouse.containsMouse ? _errColor : _dimText)
                        font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.6
                        font.bold:          true
                        font.letterSpacing: 0.5
                    }
                }

                MouseArea {
                    id:          clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        planMasterController.removeAll()
                        overlay._routeCleared = true
                        clearFeedbackTimer.restart()
                    }
                }
            }

            // Layers button
            Rectangle {
                id: layersButton
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 2.0
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.0
                radius:                 ScreenTools.defaultFontPixelHeight * 0.25
                color:                  _layersExpanded || layersBtnMouse.containsMouse
                                        ? Qt.rgba(1, 1, 1, 0.08) : _cardBg
                border.width:           1
                border.color:           _layersExpanded ? _tealBorder : Qt.rgba(1, 1, 1, 0.10)

                QGCColoredImage {
                    anchors.centerIn: parent
                    width:    ScreenTools.defaultFontPixelHeight * 0.7
                    height:   width
                    source:   "/res/terrain.svg"
                    color:    _layersExpanded || layersBtnMouse.containsMouse ? _teal : _dimText
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    id:          layersBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked:   overlay._layersExpanded = !overlay._layersExpanded
                }
            }
        }

        // ── LAYERS SELECTOR (expandable) ──
        RowLayout {
            visible:         _layersExpanded
            Layout.fillWidth: true
            spacing:         _pad * 0.4

            // STD pill
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                radius:                 ScreenTools.defaultFontPixelHeight * 0.2
                color:                  _activeMapStyle === "STD" ? _tealDim : _cardBg
                border.width:           1
                border.color:           _activeMapStyle === "STD" ? _teal : Qt.rgba(1, 1, 1, 0.10)

                QGCLabel {
                    anchors.centerIn: parent
                    text:           "STD"
                    color:          _activeMapStyle === "STD" ? _teal : _dimText
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                    font.bold:      true
                    font.letterSpacing: 0.5
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked:    overlay._setMapType("Bing", "Road", false)
                }
            }

            // DRK pill
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                radius:                 ScreenTools.defaultFontPixelHeight * 0.2
                color:                  _activeMapStyle === "DRK" ? _tealDim : _cardBg
                border.width:           1
                border.color:           _activeMapStyle === "DRK" ? _teal : Qt.rgba(1, 1, 1, 0.10)

                QGCLabel {
                    anchors.centerIn: parent
                    text:           "DRK"
                    color:          _activeMapStyle === "DRK" ? _teal : _dimText
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                    font.bold:      true
                    font.letterSpacing: 0.5
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked:    overlay._setMapType("Bing", "Road", true)
                }
            }

            // SAT pill
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                radius:                 ScreenTools.defaultFontPixelHeight * 0.2
                color:                  _activeMapStyle === "SAT" ? _tealDim : _cardBg
                border.width:           1
                border.color:           _activeMapStyle === "SAT" ? _teal : Qt.rgba(1, 1, 1, 0.10)

                QGCLabel {
                    anchors.centerIn: parent
                    text:           "SAT"
                    color:          _activeMapStyle === "SAT" ? _teal : _dimText
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                    font.bold:      true
                    font.letterSpacing: 0.5
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked:    overlay._setMapType("Bing", "Satellite", false)
                }
            }
        }
    }
}
