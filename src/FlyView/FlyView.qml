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
import QtQuick.Dialogs
import QtQuick.Layouts

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.UTMSP
import QGroundControl.Viewer3D

Item {
    id: _root

    // These should only be used by MainRootWindow
    property var planController:    _planController
    property var guidedController:  _guidedController

    // Properties of UTM adapter
    property bool utmspSendActTrigger: false

    PlanMasterController {
        id:                     _planController
        flyView:                true
        Component.onCompleted:  start()
    }

    property bool   _mainWindowIsMap:       mapControl.pipState.state === mapControl.pipState.fullState
    property bool   _isFullWindowItemDark:  _mainWindowIsMap ? mapControl.isSatelliteMap : true
    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property var    _missionController:     _planController.missionController
    property var    _geoFenceController:    _planController.geoFenceController
    property var    _rallyPointController:  _planController.rallyPointController
    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2
    property var    _guidedController:      guidedActionsController
    property var    _guidedValueSlider:     guidedValueSlider
    property var    _widgetLayer:           widgetLayer
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 0.75
    property rect   _centerViewport:        Qt.rect(0, 0, width, height)
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 30
    property var    _mapControl:            mapControl
    property real   _widgetMargin:          ScreenTools.defaultFontPixelWidth * 0.75

    property real   _fullItemZorder:    0
    property real   _pipItemZorder:     QGroundControl.zOrderWidgets

    function _calcCenterViewPort() {
        var newToolInset = Qt.rect(0, 0, width, height)
        toolstrip.adjustToolInset(newToolInset)
    }

    function dropMainStatusIndicatorTool() {
        // No-op — toolbar is now HilmNavigationBar at MainWindow level
    }

    QGCToolInsets {
        id:                     _toolInsets
        topEdgeLeftInset:       0
        topEdgeCenterInset:     0
        topEdgeRightInset:      0
        leftEdgeBottomInset:    _pipView.leftEdgeBottomInset
        bottomEdgeLeftInset:    _pipView.bottomEdgeLeftInset
    }

    Item {
        id:                 mapHolder
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.bottom:     hilmStatusBar.top

        FlyViewMap {
            id:                     mapControl
            planMasterController:   _planController
            rightPanelWidth:        ScreenTools.defaultFontPixelHeight * 9
            pipView:                _pipView
            pipMode:                !_mainWindowIsMap
            toolInsets:             customOverlay.totalToolInsets
            mapName:                "FlightDisplayView"
            enabled:                !viewer3DWindow.isOpen
        }

        FlyViewVideo {
            id:         videoControl
            pipView:    _pipView
        }

        PipView {
            id:                     _pipView
            parent:                 hilmRightPanel.videoContainer
            fullParent:             mapHolder
            anchors.fill:           parent
            item1IsFullSettingsKey: "MainFlyWindowIsMap"
            item1:                  mapControl
            item2:                  QGroundControl.videoManager.hasVideo ? videoControl : null
            show:                   QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.fullScreen &&
                                        (videoControl.pipState.state === videoControl.pipState.pipState || mapControl.pipState.state === mapControl.pipState.pipState)
            z:                      QGroundControl.zOrderWidgets

            property real leftEdgeBottomInset:  0
            property real bottomEdgeLeftInset:  0
        }

        // ── HILM Fleet Panel (Left Side — full height)
        HilmFleetPanel {
            id:                     hilmFleetPanel
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.topMargin:      _widgetMargin
            anchors.bottomMargin:   _widgetMargin
            anchors.leftMargin:     _widgetMargin
            z:                      QGroundControl.zOrderWidgets
        }

        // ── HILM Right Panel (Quick Actions + Live Video)
        HilmRightPanel {
            id:                     hilmRightPanel
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.right:          parent.right
            anchors.topMargin:      _widgetMargin
            anchors.bottomMargin:   _widgetMargin
            anchors.rightMargin:    _widgetMargin
            z:                      QGroundControl.zOrderWidgets
        }

        FlyViewWidgetLayer {
            id:                     widgetLayer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           hilmFleetPanel.right
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : hilmRightPanel.left
            anchors.margins:        _widgetMargin
            anchors.topMargin:      _widgetMargin
            z:                      _fullItemZorder + 2 // we need to add one extra layer for map 3d viewer (normally was 1)
            parentToolInsets:       _toolInsets
            mapControl:             _mapControl
            visible:                !QGroundControl.videoManager.fullScreen
            isViewer3DOpen:         viewer3DWindow.isOpen
        }

        FlyViewCustomLayer {
            id:                 customOverlay
            anchors.fill:       widgetLayer
            z:                  _fullItemZorder + 2
            parentToolInsets:   widgetLayer.totalToolInsets
            mapControl:         _mapControl
            visible:            !QGroundControl.videoManager.fullScreen
        }

        // Development tool for visualizing the insets for a paticular layer, show if needed
        FlyViewInsetViewer {
            id:                     widgetLayerInsetViewer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
            z:                      widgetLayer.z + 1
            insetsToView:           widgetLayer.totalToolInsets
            visible:                false
        }

        GuidedActionsController {
            id:                 guidedActionsController
            missionController:  _missionController
            guidedValueSlider:     _guidedValueSlider
        }

        //-- Guided value slider (e.g. altitude)
        GuidedValueSlider {
            id:                 guidedValueSlider
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            anchors.topMargin:  0
            z:                  QGroundControl.zOrderTopMost
            visible:            false
        }

        Viewer3D {
            id: viewer3DWindow
            anchors.fill: parent
        }
    }

    UTMSPActivationStatusBar {
        activationStartTimestamp:   UTMSPStateStorage.startTimeStamp
        activationApproval:         UTMSPStateStorage.showActivationTab && QGroundControl.utmspManager.utmspVehicle.vehicleActivation
        flightID:                   UTMSPStateStorage.flightID
        anchors.fill:               parent

        function onActivationTriggered(value) {
            _root.utmspSendActTrigger = value
        }
    }

    // ── Bottom Status Bar
    HilmStatusBar {
        id:                 hilmStatusBar
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.bottom:     parent.bottom
        z:                  QGroundControl.zOrderWidgets
    }

    // FlyViewToolBar replaced by HilmNavigationBar at MainWindow level

    // Floating GuidedActionConfirm (was previously in FlyViewToolBar center panel)
    GuidedActionConfirm {
        id:                         guidedActionConfirm
        anchors.top:                parent.top
        anchors.topMargin:          ScreenTools.defaultFontPixelHeight * 0.5
        anchors.horizontalCenter:   parent.horizontalCenter
        z:                          QGroundControl.zOrderTopMost
        height:                     ScreenTools.toolbarHeight
        guidedController:           _guidedController
        guidedValueSlider:          _guidedValueSlider
        utmspSliderTrigger:         utmspSendActTrigger
        messageDisplay:             guidedActionMessageDisplay
    }

    Rectangle {
        id:                         guidedActionMessageDisplay
        anchors.top:                guidedActionConfirm.bottom
        anchors.topMargin:          _margins
        anchors.horizontalCenter:   parent.horizontalCenter
        width:                      guidedMessageLabel.contentWidth + (_margins * 4)
        height:                     guidedMessageLabel.contentHeight + (_margins * 4)
        color:                      Qt.rgba(0, 0, 0, 0.75)
        radius:                     ScreenTools.defaultFontPixelHeight * 0.25
        visible:                    guidedActionConfirm.visible
        z:                          QGroundControl.zOrderTopMost

        QGCLabel {
            id:         guidedMessageLabel
            x:          _margins * 2
            y:          _margins * 2
            width:      ScreenTools.defaultFontPixelWidth * 30
            wrapMode:   Text.WordWrap
            text:       guidedActionConfirm.message
        }
    }

    // Enhanced Surveillance toggle button - middle left, visible only when video is enabled
    Rectangle {
        id: surveillanceButton
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: ScreenTools.defaultFontPixelHeight * 0.5
        width: surveillanceButtonContent.width + 24
        height: 120
        radius: 8
        visible: QGroundControl.videoManager.hasVideo && !QGroundControl.surveillanceManager.active
        z: QGroundControl.zOrderWidgets + 1

        color: surveillanceMouseArea.containsMouse ? "#2d2d2d" : "#1a1a1a"
        border.color: surveillanceMouseArea.containsMouse ? "#0066cc" : "#2d2d2d"
        border.width: 2

        // Smooth transitions
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
        Behavior on opacity { NumberAnimation { duration: 300 } }
        opacity: visible ? 1.0 : 0.0

        // Subtle glow effect when hovered
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.color: "#0066cc"
            border.width: surveillanceMouseArea.containsMouse ? 1 : 0
            opacity: 0.3
            Behavior on border.width { NumberAnimation { duration: 200 } }
        }

        ColumnLayout {
            id: surveillanceButtonContent
            anchors.centerIn: parent
            spacing: 8

            // Camera icon with animation
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 48
                height: 48
                radius: 24
                color: surveillanceMouseArea.containsMouse ? "#0066cc" : "#404040"
                border.color: "#0088ff"
                border.width: 2

                Behavior on color { ColorAnimation { duration: 200 } }

                // Animated recording indicator
                Rectangle {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    radius: 12
                    color: "#ff4444"

                    SequentialAnimation on scale {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.2; duration: 1000; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
                    }

                    // Inner dot
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        radius: 6
                        color: "white"
                    }
                }

                // Corner grid icon overlay
                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -4
                    text: "⊞"
                    font.pixelSize: 16
                    color: "white"
                    style: Text.Outline
                    styleColor: "#000000"
                }
            }

            // Label
            QGCLabel {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Surveillance")
                font.pixelSize: 13
                font.bold: true
                color: surveillanceMouseArea.containsMouse ? "#ffffff" : "#cccccc"
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            // Subtitle
            QGCLabel {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Monitor")
                font.pixelSize: 10
                color: "#999999"
            }
        }

        MouseArea {
            id: surveillanceMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                QGroundControl.surveillanceManager.active = true
            }
        }

        // Tooltip on hover
        Rectangle {
            visible: surveillanceMouseArea.containsMouse
            anchors.left: parent.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: tooltipLabel.width + 16
            height: tooltipLabel.height + 12
            radius: 6
            color: "#dd000000"
            border.color: "#404040"
            border.width: 1

            QGCLabel {
                id: tooltipLabel
                anchors.centerIn: parent
                text: qsTr("Open multi-camera\nsurveillance view")
                font.pixelSize: 11
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
            }

            // Arrow pointer
            Canvas {
                anchors.right: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 12
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.fillStyle = "#dd000000"
                    ctx.beginPath()
                    ctx.moveTo(8, 6)
                    ctx.lineTo(0, 0)
                    ctx.lineTo(0, 12)
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }
    }

    // Surveillance view overlay
    Loader {
        id: surveillanceLoader
        anchors.fill: parent
        active: QGroundControl.surveillanceManager.active
        visible: active
        z: QGroundControl.zOrderTopMost  // Make sure it's on top of everything

        sourceComponent: SurveillanceFlyView {
            anchors.fill: parent
        }
    }
}
