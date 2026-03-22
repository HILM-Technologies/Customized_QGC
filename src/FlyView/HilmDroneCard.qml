/****************************************************************************
 *
 * HILM Ground Control — Drone Card for Fleet Panel
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: card

    property var  vehicle:    null
    property bool isSelected: vehicle && QGroundControl.multiVehicleManager.activeVehicle === vehicle

    width:          parent ? parent.width : 300
    implicitHeight: cardLayout.implicitHeight + _pad * 3.5
    height:         implicitHeight
    radius: ScreenTools.defaultFontPixelHeight * 0.35
    color:        isSelected ? Qt.rgba(0, 0.749, 1.0, 0.06) : Qt.rgba(1, 1, 1, 0.03)
    border.width: 1
    border.color: isSelected ? _teal : Qt.rgba(0, 0.749, 1.0, 0.25)

    Behavior on border.color { ColorAnimation { duration: 180 } }
    Behavior on border.width { NumberAnimation  { duration: 180 } }

    // Inner glow line at top for selected (stays inside card)
    Rectangle {
        anchors.top:   parent.top
        anchors.left:  parent.left
        anchors.right: parent.right
        height:        2
        radius:        parent.radius
        color:         Qt.rgba(0, 0.749, 1.0, 0.35)
        visible:       isSelected
    }

    // HILM design tokens
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.40)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property color _okColor:    "#4CAF50"
    readonly property color _warnColor:  "#FF9800"
    readonly property color _errColor:   "#FF5252"
    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth

    // Vehicle states
    property bool _isConnected:  vehicle && !vehicle.vehicleLinkManager.communicationLost
    property bool _isFlying:     vehicle ? (vehicle.armed && vehicle.flying) : false
    property bool _isArmed:      vehicle ? vehicle.armed : false

    // Status text + color
    property string _statusText: {
        if (!vehicle) return "N/A"
        if (_isFlying)  return "ACTIVE"
        if (_isArmed)   return "ARMED"
        return "IDLE"
    }

    property color _statusColor: {
        if (_statusText === "ACTIVE")   return _okColor
        if (_statusText === "ARMED")    return _warnColor
        return Qt.rgba(0.3, 0.5, 0.9, 1.0)
    }

    // Battery
    property string _batteryText: {
        if (vehicle && vehicle.batteries && vehicle.batteries.count > 0)
            return vehicle.batteries.get(0).percentRemaining.valueString + "%"
        return "--%"
    }

    property color _batteryIconColor: {
        if (vehicle && vehicle.batteries && vehicle.batteries.count > 0) {
            var pct = vehicle.batteries.get(0).percentRemaining.rawValue
            if (pct <= 20) return _errColor
            if (pct <= 40) return _warnColor
        }
        return _dimText
    }

    // ── Teal left accent (selected)
    Rectangle {
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:          3
        radius:         1.5
        color:          _teal
        visible:        isSelected
    }

    ColumnLayout {
        id:                 cardLayout
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        anchors.topMargin:  _pad * 1.5
        anchors.leftMargin: isSelected ? _pad * 2.0 : _pad * 1.5
        anchors.rightMargin: _pad * 1.5
        spacing:            _pad * 0.6

        // ════════════════════════════════════
        // Row 1: Vehicle name + dot + badge
        // ════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad * 0.6

            QGCLabel {
                text:           vehicle ? qsTr("Vehicle") + " " + vehicle.id : "Unknown"
                color:          "white"
                font.pointSize: ScreenTools.defaultFontPointSize * 1.15
                font.bold:      true
                Layout.fillWidth: true
                elide:          Text.ElideRight
            }

            // Connected dot
            Rectangle {
                width:   ScreenTools.defaultFontPixelHeight * 0.4
                height:  width
                radius:  width / 2
                color:   _isConnected ? _okColor : _errColor
                visible: vehicle !== null
            }

            // Recording timer (shown when recording)
            Row {
                spacing: _pad * 0.25
                visible: recordBtn._isRecording

                Rectangle {
                    id: headerRecDot
                    anchors.verticalCenter: parent.verticalCenter
                    width:  ScreenTools.defaultFontPixelHeight * 0.35
                    height: width; radius: width / 2
                    color:  _errColor
                    SequentialAnimation on opacity {
                        running: recordBtn._isRecording
                        loops:   Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                    Binding { target: headerRecDot; property: "opacity"; value: 1.0; when: !recordBtn._isRecording }
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (!vehicle || !vehicle.flightPathRecorder) return ""
                        var secs = vehicle.flightPathRecorder.elapsedSeconds
                        var m = Math.floor(secs / 60)
                        var s = secs % 60
                        return m + ":" + (s < 10 ? "0" : "") + s
                    }
                    color: _errColor
                    font.pointSize: ScreenTools.defaultFontPointSize * 0.7
                    font.bold: true
                }
            }

            // Status badge
            Rectangle {
                radius:  height / 2
                width:   badgeLabel.implicitWidth + _pad * 1.8
                height:  ScreenTools.defaultFontPixelHeight * 1.3
                color:   _statusColor

                QGCLabel {
                    id:                 badgeLabel
                    anchors.centerIn:   parent
                    text:               _statusText
                    color:              "white"
                    font.pointSize:     ScreenTools.defaultFontPointSize * 0.65
                    font.bold:          true
                    font.letterSpacing: 0.5
                }
            }
        }

        // ════════════════════════════════════
        // Row 2: Vehicle type
        // ════════════════════════════════════
        QGCLabel {
            text:           vehicle ? vehicle.vehicleTypeString : ""
            color:          _dimText
            font.pointSize: ScreenTools.defaultFontPointSize * 0.8
            font.letterSpacing: 0.3
            visible:        text !== ""
        }

        // Spacer before stats
        Item { Layout.preferredHeight: _pad * 0.6 }

        // ════════════════════════════════════
        // Stats Row 1: Battery + Signal
        // ════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad * 0.5

            // Battery
            Row {
                Layout.fillWidth: true
                spacing: _pad * 0.4

                QGCColoredImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width:      ScreenTools.defaultFontPixelHeight * 0.9
                    height:     width
                    source:     "/qmlimages/Battery.svg"
                    color:      _batteryIconColor
                    fillMode:   Image.PreserveAspectFit
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:       _batteryText
                    color:      "white"
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                    font.bold:  true
                }
            }

            // Signal
            Row {
                Layout.fillWidth: true
                spacing: _pad * 0.4

                QGCColoredImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width:      ScreenTools.defaultFontPixelHeight * 0.9
                    height:     width
                    source:     "/qmlimages/Signal100.svg"
                    color:      _dimText
                    fillMode:   Image.PreserveAspectFit
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:       vehicle ? (vehicle.rcRSSI > 0 ? vehicle.rcRSSI + "%" : "--%") : "--%"
                    color:      "white"
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                    font.bold:  true
                }
            }
        }

        // ════════════════════════════════════
        // Stats Row 2: SAT + Flight mode
        // ════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad * 0.5

            // SAT count
            Row {
                Layout.fillWidth: true
                spacing: _pad * 0.4

                QGCColoredImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width:      ScreenTools.defaultFontPixelHeight * 0.9
                    height:     width
                    source:     "/qmlimages/Gps.svg"
                    color:      _dimText
                    fillMode:   Image.PreserveAspectFit
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:       vehicle && vehicle.gps ? vehicle.gps.count.rawValue + " SAT" : "-- SAT"
                    color:      "white"
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                    font.bold:  true
                }
            }

            // Flight mode
            Row {
                Layout.fillWidth: true
                spacing: _pad * 0.4

                QGCColoredImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width:      ScreenTools.defaultFontPixelHeight * 0.9
                    height:     width
                    source:     "/qmlimages/PaperPlane.svg"
                    color:      _dimText
                    fillMode:   Image.PreserveAspectFit
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:       vehicle ? vehicle.flightMode : "--"
                    color:      "white"
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                    font.bold:  true
                }
            }
        }

        // ════════════════════════════════════
        // Separator + Mission info
        // ════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: _pad * 0.3
            height:           1
            color:            Qt.rgba(0, 0.749, 1.0, 0.15)
            visible:          missionLabel.visible
        }

        QGCLabel {
            id:             missionLabel
            Layout.fillWidth: true
            text: {
                if (!vehicle) return ""
                if (_isFlying) return "MISSION: " + (vehicle.flightMode || "IN PROGRESS")
                if (_isArmed)  return "STANDBY"
                return ""
            }
            color:          _teal
            font.pointSize: ScreenTools.defaultFontPointSize * 0.85
            font.bold:      true
            font.letterSpacing: 0.5
            visible:        text !== ""
        }

        // ════════════════════════════════════
        // Separator + RECORD MANUAL CONTROL
        // ════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: _pad * 0.3
            height:           1
            color:            Qt.rgba(1, 1, 1, 0.08)
        }

        Rectangle {
            id: recordBtn
            Layout.fillWidth:       true
            Layout.topMargin:       _pad * 0.3
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.6
            radius:                 ScreenTools.defaultFontPixelHeight * 0.35

            property bool _isRecording: vehicle && vehicle.flightPathRecorder ? vehicle.flightPathRecorder.recording : false

            color: {
                if (_isRecording)
                    return recordManualArea.containsMouse ? "#E53935" : _errColor
                return recordManualArea.containsMouse ? Qt.rgba(1, 0.3, 0, 0.12) : "transparent"
            }
            border.width: _isRecording ? 0 : 1
            border.color: Qt.rgba(1, 0.3, 0, 0.45)

            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.centerIn: parent
                spacing:          _pad * 0.6

                // Not recording: pulsing red dot | Recording: white stop square
                Rectangle {
                    id: recIcon
                    width:   ScreenTools.defaultFontPixelHeight * 0.55
                    height:  width
                    radius:  recordBtn._isRecording ? ScreenTools.defaultFontPixelHeight * 0.06 : width / 2
                    color:   recordBtn._isRecording ? "white" : _errColor

                    SequentialAnimation on opacity {
                        running: !recordBtn._isRecording
                        loops:   Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 700 }
                        NumberAnimation { to: 1.0;  duration: 700 }
                    }
                    Binding { target: recIcon; property: "opacity"; value: 1.0; when: recordBtn._isRecording }
                }

                QGCLabel {
                    text: recordBtn._isRecording ? "STOP RECORDING" : "RECORD MANUAL CONTROL"
                    color:              "white"
                    font.pointSize:     ScreenTools.defaultFontPointSize * 0.72
                    font.bold:          true
                    font.letterSpacing: 0.6
                }
            }

            MouseArea {
                id:             recordManualArea
                anchors.fill:   parent
                hoverEnabled:   true
                cursorShape:    Qt.PointingHandCursor
                onClicked: {
                    if (!vehicle || !vehicle.flightPathRecorder)
                        return
                    var rec = vehicle.flightPathRecorder
                    if (rec.recording) {
                        rec.stopRecording()
                    } else {
                        rec.startRecording()
                    }
                }
            }
        }
    }

    // ── Save dialog after recording stops ──
    Connections {
        target: vehicle && vehicle.flightPathRecorder ? vehicle.flightPathRecorder : null
        function onRecordingStopped() {
            _recordSaveDialog.openForSave()
        }
    }

    QGCFileDialog {
        id:             _recordSaveDialog
        title:          qsTr("Save Recorded Flight Path")
        nameFilters:    [qsTr("Plan Files (*.plan)")]
        defaultSuffix:  "plan"
        onAcceptedForSave: (file) => {
            if (vehicle && vehicle.flightPathRecorder) {
                vehicle.flightPathRecorder.saveToFile(file)
            }
            close()
        }
    }

    // ── Click handler (z: -1 so record button stays clickable)
    MouseArea {
        z: -1
        anchors.fill: parent
        onClicked: {
            if (vehicle) {
                QGroundControl.multiVehicleManager.activeVehicle = vehicle
            }
        }
    }
}
