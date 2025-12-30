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

    property var patrolController   // injected from PlanView.qml

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
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: patrolController ? patrolController.startTime : "22:00"
                    placeholderText: "HH:MM"
                    onEditingFinished: if (patrolController) patrolController.startTime = text
                }

                // ---------- ACTIONS ----------
                QGCButton {
                    text: qsTr("Apply Patrol Settings")
                    anchors.left: parent.left
                    anchors.right: parent.right
                    onClicked: if (patrolController) patrolController.saveToINI();
                }

                QGCButton {
                    text: qsTr("Reset")
                    anchors.left: parent.left
                    anchors.right: parent.right
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

                            // ✅ Selection visuals
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
                        selectDroneDialog.close()
                    }
                }
            }
        }
    }
}

