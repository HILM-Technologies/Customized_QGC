/****************************************************************************
 *
 * HILM Ground Control — Video Wall View
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

import QGC
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Item {
    id: root

    // ── Design tokens
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.18)
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.40)
    readonly property color _cardBg:     "#0A1018"
    readonly property color _panelBg:    "#0B1320"
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.65)

    // ── State
    property int  gridLayout:     0        // 0=2×2  1=3×3  2=1+3  3=4×4
    property int  fullscreenIdx:  -1
    property int  selectedIdx:    0        // which card is focused
    property bool recordingAll:   false

    property var  _vehicles:      QGroundControl.multiVehicleManager.vehicles

    function _gridCols() {
        if (gridLayout === 1) return 3
        if (gridLayout === 2) return 2
        if (gridLayout === 3) return 4
        return 2
    }
    function _gridRows() {
        if (gridLayout === 1) return 3
        if (gridLayout === 2) return 3
        if (gridLayout === 3) return 4
        return 2
    }
    function _cellCount() {
        if (gridLayout === 2) return 4
        return _gridCols() * _gridRows()
    }

    Settings {
        id: rtspSettings
        category: "SurveillanceRTSP"
        property string baseUrl: "rtsp://127.0.0.1:8554/"
    }

    // ── Background
    Rectangle { anchors.fill: parent; color: _panelBg }

    // ── RTSP URL Config Dialog
    Rectangle {
        id:           urlDialog
        visible:      false
        anchors.centerIn: parent
        width:        480; height: 148
        radius:       10
        color:        "#161D27"
        border.color: _teal; border.width: 1
        z:            1000

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 10

            QGCLabel { text: qsTr("Configure RTSP Base URL"); color: "white"; font.pixelSize: 13; font.bold: true }
            QGCLabel {
                text: qsTr("Stream index appended automatically: base_url + 0, + 1, …")
                color: _dimText; font.pixelSize: 10
                wrapMode: Text.WordWrap; Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; height: 34; radius: 6; color: "#0D1117"
                    border.color: urlInput.activeFocus ? _teal : Qt.rgba(1,1,1,0.15); border.width: 1
                    TextInput {
                        id: urlInput; anchors.fill: parent; anchors.margins: 8
                        text: rtspSettings.baseUrl; color: "white"; font.pixelSize: 12
                        clip: true; verticalAlignment: TextInput.AlignVCenter; selectionColor: _teal
                    }
                }
                Rectangle {
                    width: 64; height: 34; radius: 6
                    color: applyHov.containsMouse ? _teal : "#005fa3"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    QGCLabel { anchors.centerIn: parent; text: qsTr("Apply"); color: "white"; font.pixelSize: 12; font.bold: true }
                    MouseArea { id: applyHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { rtspSettings.baseUrl = urlInput.text; urlDialog.visible = false }
                    }
                }
                Rectangle {
                    width: 64; height: 34; radius: 6
                    color: cancelHov.containsMouse ? "#993333" : "#333"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    QGCLabel { anchors.centerIn: parent; text: qsTr("Cancel"); color: "white"; font.pixelSize: 12 }
                    MouseArea { id: cancelHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: urlDialog.visible = false
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ══════════════════════════════════════
        // HEADER
        // ══════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            height: 52
            color:  Qt.rgba(1,1,1,0.03)
            radius: 8
            border.color: Qt.rgba(1,1,1,0.07); border.width: 1

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12

                // Screen icon + title
                QGCColoredImage {
                    width: 18; height: 18
                    source:   "/qmlimages/TrackVehicle.svg"
                    color:    _teal
                    fillMode: Image.PreserveAspectFit
                }
                QGCLabel {
                    text:           qsTr("VIDEO WALL")
                    color:          "white"
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.85
                    font.bold:      true
                    font.letterSpacing: 1.2
                }

                Rectangle { width: 1; height: 24; color: Qt.rgba(1,1,1,0.12) }

                QGCLabel {
                    text:           _vehicles ? _vehicles.count + qsTr(" active feeds") : qsTr("0 active feeds")
                    color:          _dimText
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                }

                Item { Layout.fillWidth: true }

                // Grid layout buttons
                Row {
                    spacing: 4

                    // 2×2
                    Rectangle {
                        width: 36; height: 32; radius: 5
                        color:        gridLayout === 0 ? _tealDim : Qt.rgba(1,1,1,0.05)
                        border.color: gridLayout === 0 ? _teal    : Qt.rgba(1,1,1,0.12); border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Grid { anchors.centerIn: parent; columns: 2; spacing: 2
                            Repeater { model: 4; Rectangle { width: 6; height: 6; radius: 1; color: gridLayout === 0 ? _teal : Qt.rgba(1,1,1,0.4) } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { gridLayout = 0; fullscreenIdx = -1 } }
                    }

                    // 1+3
                    Rectangle {
                        width: 36; height: 32; radius: 5
                        color:        gridLayout === 2 ? _tealDim : Qt.rgba(1,1,1,0.05)
                        border.color: gridLayout === 2 ? _teal    : Qt.rgba(1,1,1,0.12); border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Item {
                            anchors.centerIn: parent; width: 18; height: 14
                            Rectangle { x:0; y:0; width: 10; height: 14; radius: 1; color: gridLayout === 2 ? _teal : Qt.rgba(1,1,1,0.4) }
                            Column { x: 13; spacing: 2
                                Repeater { model: 3; Rectangle { width: 5; height: 4; radius: 1; color: gridLayout === 2 ? _teal : Qt.rgba(1,1,1,0.4) } }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { gridLayout = 2; fullscreenIdx = -1 } }
                    }

                    // 3×3
                    Rectangle {
                        width: 36; height: 32; radius: 5
                        color:        gridLayout === 1 ? _tealDim : Qt.rgba(1,1,1,0.05)
                        border.color: gridLayout === 1 ? _teal    : Qt.rgba(1,1,1,0.12); border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Grid { anchors.centerIn: parent; columns: 3; spacing: 2
                            Repeater { model: 9; Rectangle { width: 4; height: 4; radius: 1; color: gridLayout === 1 ? _teal : Qt.rgba(1,1,1,0.4) } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { gridLayout = 1; fullscreenIdx = -1 } }
                    }

                    // 4×4
                    Rectangle {
                        width: 36; height: 32; radius: 5
                        color:        gridLayout === 3 ? _tealDim : Qt.rgba(1,1,1,0.05)
                        border.color: gridLayout === 3 ? _teal    : Qt.rgba(1,1,1,0.12); border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Grid { anchors.centerIn: parent; columns: 4; spacing: 2
                            Repeater { model: 16; Rectangle { width: 3; height: 3; radius: 1; color: gridLayout === 3 ? _teal : Qt.rgba(1,1,1,0.4) } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { gridLayout = 3; fullscreenIdx = -1 } }
                    }
                }

                Rectangle { width: 1; height: 24; color: Qt.rgba(1,1,1,0.12) }

                // RECORD ALL
                Rectangle {
                    height: 32; width: recRow.implicitWidth + 20; radius: 5
                    color:        recHov.containsMouse ? Qt.rgba(1, 0.26, 0.26, 0.15) : Qt.rgba(1,1,1,0.05)
                    border.color: recHov.containsMouse ? "#FF5252" : Qt.rgba(1,1,1,0.12); border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Row {
                        id: recRow; anchors.centerIn: parent; spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7; height: 7; radius: 4
                            color: recordingAll ? "#FF5252" : Qt.rgba(1,1,1,0.5)
                            SequentialAnimation on opacity {
                                running: recordingAll; loops: Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 600 }
                                NumberAnimation { to: 1.0; duration: 600 }
                            }
                        }
                        QGCLabel { text: qsTr("RECORD ALL"); color: recHov.containsMouse ? "#FF5252" : Qt.rgba(1,1,1,0.7); font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5 }
                    }
                    MouseArea { id: recHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: recordingAll = !recordingAll }
                }

                // SNAPSHOT ALL
                Rectangle {
                    height: 32; width: snapRow.implicitWidth + 20; radius: 5
                    color:        snapHov.containsMouse ? _tealDim : Qt.rgba(1,1,1,0.05)
                    border.color: snapHov.containsMouse ? _teal : Qt.rgba(1,1,1,0.12); border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Row {
                        id: snapRow; anchors.centerIn: parent; spacing: 6
                        QGCColoredImage {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13; height: 13; source: "/qmlimages/CameraIcon.svg"
                            color: snapHov.containsMouse ? _teal : Qt.rgba(1,1,1,0.7); fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel { text: qsTr("SNAPSHOT ALL"); color: snapHov.containsMouse ? _teal : Qt.rgba(1,1,1,0.7); font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5 }
                    }
                    MouseArea { id: snapHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: console.log("Snapshot all") }
                }

                // Exit fullscreen
                Rectangle {
                    visible: fullscreenIdx >= 0
                    width: 32; height: 32; radius: 5
                    color: exitHov.containsMouse ? "#993333" : Qt.rgba(1,1,1,0.05)
                    border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                    QGCLabel { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 14 }
                    MouseArea { id: exitHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fullscreenIdx = -1 }
                }
            }
        }

        // ══════════════════════════════════════
        // VIDEO GRID
        // ══════════════════════════════════════
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            GridLayout {
                anchors.fill:  parent
                columns:       fullscreenIdx >= 0 ? 1 : _gridCols()
                rowSpacing:    8
                columnSpacing: 8

                Repeater {
                    model: _cellCount()

                    // ── Feed Card
                    Item {
                        id:    feedCard
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        Layout.rowSpan:    (gridLayout === 2 && index === 0) ? 3 : 1
                        visible: fullscreenIdx === -1 || fullscreenIdx === index
                        opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 180 } }

                        property var    _vehicle:   (_vehicles && index < _vehicles.count) ? _vehicles.get(index) : null
                        property bool   _active:    _vehicle ? _vehicle.armed : false
                        property string _name:      _vehicle ? (qsTr("Vehicle ") + _vehicle.id) : (qsTr("Camera ") + (index + 1))
                        property string _mode:      _vehicle ? _vehicle.flightMode : ""
                        property string _battery:   (_vehicle && _vehicle.batteries && _vehicle.batteries.count > 0)
                                                        ? _vehicle.batteries.get(0).percentRemaining.valueString + "%" : "--"
                        property string _signal:    _vehicle ? (_vehicle.rcRSSI > 0 ? _vehicle.rcRSSI + "%" : "95%") : "--"

                        // Status
                        property string _statusLabel: {
                            if (!_vehicle) return "OFFLINE"
                            if (_vehicle.armed) return "ACTIVE"
                            return "IDLE"
                        }
                        property color _statusBg: {
                            if (_statusLabel === "ACTIVE") return Qt.rgba(0, 0.55, 0.33, 0.18)
                            if (_statusLabel === "IDLE")   return Qt.rgba(1, 1, 1, 0.06)
                            return Qt.rgba(1, 1, 1, 0.04)
                        }
                        property color _statusColor: {
                            if (_statusLabel === "ACTIVE") return "#00D97E"
                            if (_statusLabel === "IDLE")   return Qt.rgba(1,1,1,0.4)
                            return Qt.rgba(1,1,1,0.25)
                        }
                        property bool _selected: selectedIdx === index

                        // ── Outer glow for selected card
                        Rectangle {
                            anchors.fill:    parent
                            anchors.margins: -2
                            radius:          10
                            color:           "transparent"
                            border.color:    feedCard._selected ? Qt.rgba(0, 0.749, 1.0, 0.50) : "transparent"
                            border.width:    3
                            visible:         feedCard._selected
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color:  _cardBg
                            radius: 8
                            // Selected = bright teal; unselected = dim teal
                            border.color: feedCard._selected
                                          ? _teal
                                          : Qt.rgba(0, 0.749, 1.0, 0.30)
                            border.width: feedCard._selected ? 1 : 1
                            Behavior on border.color { ColorAnimation { duration: 200 } }

                            // Light dim overlay for unselected cards
                            Rectangle {
                                anchors.fill: parent
                                radius:       8
                                color:        Qt.rgba(0, 0, 0, feedCard._selected ? 0.0 : 0.18)
                                z:            10
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            // ── Video area (VideoFeed handles stream)
                            Item {
                                anchors.fill:        parent
                                anchors.topMargin:   52
                                anchors.bottomMargin: 0
                                clip: true

                                VideoFeed {
                                    anchors.fill:  parent
                                    streamName:    feedCard._name
                                    streamId:      "cam" + (feedCard._vehicle ? feedCard._vehicle.id : index)
                                    rtspUrl:       feedCard._vehicle ? (rtspSettings.baseUrl + feedCard._vehicle.id) : ""
                                    isFullscreen:  fullscreenIdx === index
                                    showHeader:    false
                                    showBorder:    false
                                    onFullscreenRequested: fullscreenIdx = fullscreenIdx === index ? -1 : index
                                }
                            }

                            // ── Top info bar (two-line: name+badge / battery+signal+mode)
                            Rectangle {
                                id:     topBar
                                anchors.top:   parent.top
                                anchors.left:  parent.left
                                anchors.right: parent.right
                                height: 52
                                color:  Qt.rgba(0, 0, 0, 0.40)
                                radius: 8
                                Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 8; color: parent.color }

                                ColumnLayout {
                                    anchors.fill:    parent
                                    anchors.margins: 8
                                    anchors.topMargin: 7
                                    spacing: 3

                                    // Line 1: broadcast icon + name + status badge
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        QGCColoredImage {
                                            width: 12; height: 12
                                            source:   "/res/broadcast.svg"
                                            color:    _teal
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        QGCLabel {
                                            text:           feedCard._name
                                            color:          "white"
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.80
                                            font.bold:      true
                                            elide:          Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            height: 17
                                            width:  statusLabel.implicitWidth + 10
                                            radius: 3
                                            color:  feedCard._statusBg
                                            border.color: feedCard._statusColor; border.width: 1
                                            QGCLabel {
                                                id:             statusLabel
                                                anchors.centerIn: parent
                                                text:           feedCard._statusLabel
                                                color:          feedCard._statusColor
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.60
                                                font.bold:      true
                                                font.letterSpacing: 0.4
                                            }
                                        }
                                    }

                                    // Line 2: battery icon+% · signal icon+% · mode
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        // Battery
                                        Row {
                                            spacing: 4
                                            QGCColoredImage { anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; source: "/qmlimages/Battery.svg"; color: _teal; fillMode: Image.PreserveAspectFit }
                                            QGCLabel { anchors.verticalCenter: parent.verticalCenter; text: feedCard._battery; color: "white"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68 }
                                        }

                                        // Signal
                                        Row {
                                            spacing: 4
                                            QGCColoredImage { anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; source: "/qmlimages/Signal100.svg"; color: _teal; fillMode: Image.PreserveAspectFit }
                                            QGCLabel { anchors.verticalCenter: parent.verticalCenter; text: feedCard._signal; color: "white"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68 }
                                        }

                                        // Flight mode
                                        QGCLabel {
                                            visible: feedCard._mode !== ""
                                            text:    feedCard._mode
                                            color:   Qt.rgba(1,1,1,0.70)
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }

                            // ── Bottom hover controls
                            Rectangle {
                                id:     bottomBar
                                anchors.bottom: parent.bottom
                                anchors.left:   parent.left
                                anchors.right:  parent.right
                                anchors.margins: 6
                                height: 36
                                radius: 6
                                color:  Qt.rgba(0, 0, 0, 0.70)
                                opacity: cardHover.containsMouse ? 1.0 : 0.0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 180 } }

                                Row {
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 8; spacing: 4
                                    // Mute
                                    Rectangle { width: 28; height: 28; radius: 5; color: muteHov.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                                        QGCColoredImage { anchors.centerIn: parent; width: 13; height: 13; source: "/InstrumentValueIcons/volume-up.svg"; color: Qt.rgba(1,1,1,0.6); fillMode: Image.PreserveAspectFit }
                                        MouseArea { id: muteHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                                    }
                                    // Snapshot
                                    Rectangle { width: 28; height: 28; radius: 5; color: snapCardHov.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                                        QGCColoredImage { anchors.centerIn: parent; width: 13; height: 13; source: "/qmlimages/CameraIcon.svg"; color: Qt.rgba(1,1,1,0.7); fillMode: Image.PreserveAspectFit }
                                        MouseArea { id: snapCardHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: console.log("Snapshot:", index) }
                                    }
                                    // Stop/record
                                    Rectangle { width: 28; height: 28; radius: 5; color: stopHov.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                                        Rectangle { anchors.centerIn: parent; width: 9; height: 9; radius: 1; color: Qt.rgba(1,1,1,0.7) }
                                        MouseArea { id: stopHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                                    }
                                }

                                // Expand button
                                Rectangle {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 8
                                    width: 28; height: 28; radius: 5
                                    color: expandHov.containsMouse ? _tealDim : "transparent"
                                    border.color: expandHov.containsMouse ? _teal : "transparent"; border.width: 1
                                    QGCColoredImage { anchors.centerIn: parent; width: 13; height: 13; source: "/InstrumentValueIcons/screen-full.svg"; color: expandHov.containsMouse ? _teal : Qt.rgba(1,1,1,0.7); fillMode: Image.PreserveAspectFit }
                                    MouseArea { id: expandHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: fullscreenIdx = fullscreenIdx === index ? -1 : index
                                    }
                                }
                            }

                            // Hover + click-to-select capture
                            MouseArea {
                                id:              cardHover
                                anchors.fill:    parent
                                hoverEnabled:    true
                                propagateComposedEvents: true
                                onClicked: (mouse) => {
                                    selectedIdx = index
                                    mouse.accepted = false
                                }
                            }
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════
        // BOTTOM STATUS BAR
        // ══════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            height: 30
            color:  Qt.rgba(0, 0, 0, 0.35)
            radius: 6
            border.color: Qt.rgba(1,1,1,0.06); border.width: 1

            RowLayout {
                anchors.fill:    parent
                anchors.margins: 10
                spacing:         0

                // Live streaming dot
                Rectangle {
                    width: 7; height: 7; radius: 4; color: "#00D97E"
                    SequentialAnimation on opacity {
                        running: true; loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 900 }
                        NumberAnimation { to: 1.0; duration: 900 }
                    }
                }
                Item { width: 6 }
                QGCLabel { text: qsTr("Live Streaming"); color: "#00D97E"; font.pixelSize: 10; font.bold: true }

                Item { width: 14 }
                Rectangle { width: 1; height: 14; color: Qt.rgba(1,1,1,0.12) }
                Item { width: 14 }

                QGCLabel { text: qsTr("Recording: ") + (recordingAll ? _cellCount() : 0) + qsTr(" feeds"); color: _dimText; font.pixelSize: 10 }

                Item { width: 14 }
                Rectangle { width: 1; height: 14; color: Qt.rgba(1,1,1,0.12) }
                Item { width: 14 }

                QGCLabel { text: qsTr("Total bandwidth: 12.4 Mbps"); color: _dimText; font.pixelSize: 10 }

                Item { Layout.fillWidth: true }

                // RTSP config button
                Item {
                    implicitWidth:  rtspRow.implicitWidth
                    implicitHeight: rtspRow.implicitHeight

                    Row {
                        id: rtspRow
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        QGCLabel { text: "⚙"; color: rtspLinkHov.containsMouse ? _teal : _dimText; font.pixelSize: 11 }
                        QGCLabel {
                            text:  qsTr("RTSP URL")
                            color: rtspLinkHov.containsMouse ? _teal : _dimText
                            font.pixelSize: 10
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        id:          rtspLinkHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: { urlInput.text = rtspSettings.baseUrl; urlDialog.visible = true }
                    }
                }

                Item { width: 14 }
                Rectangle { width: 1; height: 14; color: Qt.rgba(1,1,1,0.12) }
                Item { width: 14 }

                QGCLabel { text: qsTr("Stream resolution: 1920×1080 @ 30fps"); color: _dimText; font.pixelSize: 10 }
            }
        }
    }
}
