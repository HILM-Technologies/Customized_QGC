import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: patrolEditorRect
    radius: _radius
    color: qgcPal.buttonHighlight
    width: parent.width
    height: patrolItems.y + patrolItems.height + (_margin * 2)

    property var patrolController

    readonly property real _margin: ScreenTools.defaultFontPixelWidth / 2
    readonly property real _radius: ScreenTools.defaultFontPixelWidth / 2

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // ---------- TITLE ----------
    QGCLabel {
        id: patrolLabel
        text: qsTr("Autonomous Patrol")
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: _margin
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
    }

    // ---------- INNER PANEL ----------
    Rectangle {
        id: patrolItems
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: patrolLabel.bottom
        anchors.margins: _margin
        radius: _radius
        color: qgcPal.windowShadeDark

        height: contentColumn.y + contentColumn.height + (_margin * 2)

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: _margin
            spacing: _margin

            // ---------- DESCRIPTION ----------
            QGCLabel {
                anchors.left: parent.left
                anchors.right: parent.right
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
                text: qsTr("Configure autonomous patrol behavior such as speed, loop mode, and schedule.")
            }

            // ---------- ENABLE ----------
            QGCCheckBoxSlider {
                text: qsTr("Enable Patrol Mode")
                checked: patrolController ? patrolController.enabled : false
                onClicked: if (patrolController) patrolController.enabled = checked
            }

            // ---------- ENABLED CONTENT ----------
            Column {
                visible: patrolController && patrolController.enabled
                spacing: _margin
                anchors.left: parent.left
                anchors.right: parent.right

                // ---------- DRONE SELECTION ----------
                QGCLabel { text: qsTr("Selected Drone") }

                QGCTextField {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    readOnly: true
                    text: patrolController && patrolController.droneUID !== ""
                          ? patrolController.droneUID
                          : qsTr("No drone selected")
                }

                QGCButton {
                    text: qsTr("Select Drone…")
                    anchors.left: parent.left
                    anchors.right: parent.right
                    enabled: patrolController && patrolController.availableDrones.length > 0
                    onClicked: selectDroneDialog.open()
                }


                // ---------- SPEED ----------
                QGCLabel { text: qsTr("Patrol Speed (m/s)") }

                Row {
                    spacing: _margin
                    anchors.left: parent.left
                    anchors.right: parent.right

                    QGCSlider {
                        id: speedSlider
                        width: parent.width - speedValue.width - _margin
                        from: 1
                        to: 15
                        value: patrolController ? patrolController.speed : 5
                        onValueChanged: if (patrolController) patrolController.speed = value
                    }

                    QGCLabel {
                        id: speedValue
                        text: speedSlider.value.toFixed(1) + " m/s"
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // ---------- LOOP MODE ----------
                QGCLabel { text: qsTr("Loop Behavior") }

                QGCComboBox {
                    id: loopModeCombo
                    Layout.fillWidth: true

                    model: [
                        qsTr("Loop Forever"),     // 0 → PatrolLoopMode::Forever
                        qsTr("Loop N Times"),     // 1 → PatrolLoopMode::NTimes
                        qsTr("Run for Duration")  // 2 → PatrolLoopMode::Duration
                    ]

                    currentIndex: patrolController ? patrolController.loopsMode : 0

                    onActivated: function(index) {
                        if (!patrolController) {
                            return
                        }
                        patrolController.loopsMode = index
                    }
                }


                // ---------- N LOOPS ----------
                Column {
                    visible: loopModeCombo.currentIndex === 1
                    spacing: _margin

                    QGCLabel { text: qsTr("Number of Loops") }

                    QGCTextField {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: patrolController ? patrolController.loops.toString() : "3"
                        validator: IntValidator { bottom: 1; top: 999 }
                        onEditingFinished: if (patrolController) patrolController.loops = parseInt(text)
                    }
                }

                // ---------- DURATION ----------
                Column {
                    visible: loopModeCombo.currentIndex === 2
                    spacing: _margin

                    QGCLabel { text: qsTr("Patrol Duration (minutes)") }

                    QGCTextField {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: patrolController ? patrolController.duration.toString() : "20"
                        validator: IntValidator { bottom: 1; top: 300 }
                        onEditingFinished: if (patrolController) patrolController.duration = parseInt(text)
                    }
                }

                // ---------- START TIME ----------
                QGCLabel { text: qsTr("Scheduled Start Time") }

                QGCTextField {
                    id: startTimeField
                    anchors.left: parent.left
                    anchors.right: parent.right
                    placeholderText: "HH:MM"
                    text: patrolController ? patrolController.startTime : ""

                    onEditingFinished: {
                        if (!patrolController)
                            return

                        var parts = text.split(":")
                        if (parts.length !== 2) {
                            startTimeError.visible = true
                            applyPatrolSettings.enabled = false
                            return
                        }

                        var h = parseInt(parts[0])
                        var m = parseInt(parts[1])

                        if (isNaN(h) || isNaN(m) || h < 0 || h > 23 || m < 0 || m > 59) {
                            startTimeError.visible = true
                            applyPatrolSettings.enabled = false
                            return
                        }

                        startTimeError.visible = false
                        applyPatrolSettings.enabled = true
                        patrolController.startTime = text
                    }
                }

                QGCLabel {
                    id: startTimeError
                    visible: false
                    color: qgcPal.warningText
                    text: qsTr("Invalid time. Use HH:MM (24-hour).")
                    font.pixelSize: ScreenTools.smallFontPixelSize
                }

                // ---------- START DATE ----------
                QGCLabel { text: qsTr("Scheduled Start Date") }

                QGCTextField {
                    id: startDateField
                    anchors.left: parent.left
                    anchors.right: parent.right
                    placeholderText: "YYYY-MM-DD"

                    text: patrolController &&
                          patrolController.startDate &&
                          !isNaN(patrolController.startDate.getTime())
                          ? Qt.formatDate(patrolController.startDate, "yyyy-MM-dd")
                          : ""

                    onEditingFinished: {
                        if (!patrolController)
                            return

                        var parts = text.split("-")
                        if (parts.length !== 3) {
                            startDateError.visible = true
                            applyPatrolSettings.enabled = false
                            return
                        }

                        var y = parseInt(parts[0])
                        var m = parseInt(parts[1]) - 1
                        var d = parseInt(parts[2])

                        var date = new Date(y, m, d)

                        // Validate exact date match (prevents Feb 30 etc.)
                        if (isNaN(date.getTime()) ||
                                date.getFullYear() !== y ||
                                date.getMonth() !== m ||
                                date.getDate() !== d) {

                            startDateError.visible = true
                            applyPatrolSettings.enabled = false
                            return
                        }

                        startDateError.visible = false
                        applyPatrolSettings.enabled = true
                        patrolController.startDate = date
                    }
                }

                QGCLabel {
                    id: startDateError
                    visible: false
                    color: qgcPal.warningText
                    text: qsTr("Invalid date. Use YYYY-MM-DD.")
                    font.pixelSize: ScreenTools.smallFontPixelSize
                }

                // ---------- ACTIONS ----------
                QGCButton {
                    id: applyPatrolSettings
                    text: qsTr("Apply Patrol Settings")
                    anchors.left: parent.left
                    anchors.right: parent.right
                    enabled: patrolController && patrolController.availableDrones.length > 0
                    onClicked: if (patrolController) patrolController.saveToINI();
                }

                QGCButton {
                    text: qsTr("Reset")
                    anchors.left: parent.left
                    anchors.right: parent.right
                    enabled: patrolController && patrolController.availableDrones.length > 0
                    onClicked: if (patrolController) patrolController.removeAll()
                }
            }
        }
    }
    Popup {
        id: selectDroneDialog
        modal: true
        focus: true
        width: patrolEditorRect.width * 0.9
        height: 300
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        ColumnLayout {
            anchors.fill: parent
            spacing: ScreenTools.defaultFontPixelHeight / 2

            QGCLabel {
                text: qsTr("Select Drone")
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: qgcPal.windowShade

                ScrollView {
                    anchors.fill: parent

                    ListView {
                        id: droneListView
                        width: parent.width
                        clip: true

                        currentIndex: -1
                        focus: true

                        model: patrolController
                               ? patrolController.availableDrones
                               : []

                        delegate: Rectangle {
                            width: droneListView.width
                            height: ScreenTools.defaultFontPixelHeight * 2
                            radius: 4

                            // Selection visuals
                            color: ListView.isCurrentItem
                                   ? qgcPal.buttonHighlight
                                   : "transparent"

                            border.width: ListView.isCurrentItem ? 2 : 0
                            border.color: qgcPal.buttonHighlight

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                text: modelData
                                color: ListView.isCurrentItem
                                       ? qgcPal.buttonText
                                       : qgcPal.text
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    droneListView.currentIndex = index
                                }
                                onDoubleClicked: {
                                    patrolController.droneUID = modelData
                                    var id = parseInt(modelData)
                                    if (!isNaN(id)) {
                                        QGroundControl.multiVehicleManager.deselectAllVehicles()
                                        QGroundControl.multiVehicleManager.selectVehicle(id)
                                        // QGroundControl.multiVehicleManager.setActiveVehicle(
                                        //             QGroundControl.multiVehicleManager.getVehicleById(id)
                                        //             )
                                    }
                                    selectDroneDialog.close()
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: ScreenTools.defaultFontPixelWidth

                QGCButton {
                    text: qsTr("Cancel")
                    onClicked: selectDroneDialog.close()
                }

                QGCButton {
                    text: qsTr("OK")
                    enabled: droneListView.currentIndex >= 0
                    onClicked: {
                        patrolController.droneUID =
                                patrolController.availableDrones[droneListView.currentIndex]
                        var id = parseInt(patrolController.droneUID)
                        if (!isNaN(id)) {
                            QGroundControl.multiVehicleManager.deselectAllVehicles()
                            QGroundControl.multiVehicleManager.selectVehicle(id)
                            // QGroundControl.multiVehicleManager.setActiveVehicle(
                            //             QGroundControl.multiVehicleManager.getVehicleById(id)
                            //             )
                        }
                        selectDroneDialog.close()
                    }
                }
            }
        }
    }
}

