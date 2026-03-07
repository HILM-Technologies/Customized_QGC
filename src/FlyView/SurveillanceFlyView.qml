import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    anchors.fill: parent

    property int columns: SurveillanceManager.getGridColumns
    property int rows: SurveillanceManager.getGridRows
    property int cellCount: columns * rows
    property int fullscreenIndex: -1
    property string rtspBaseUrl: rtspSettings.baseUrl

    Settings {
        id: rtspSettings
        category: "SurveillanceRTSP"
        property string baseUrl: "rtsp://192.168.1.17:8554/mystream"
    }

    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"
    }

    // ===========================
    // RTSP URL CONFIG DIALOG
    // ===========================
    Rectangle {
        id: urlConfigDialog
        visible: false
        anchors.centerIn: parent
        width: 500
        height: 160
        radius: 10
        color: "#2d2d2d"
        border.color: "#0088ff"
        border.width: 2
        z: 1000

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: qsTr("Configure RTSP Base URL")
                color: "#ffffff"
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                text: qsTr("Stream index is appended automatically  (e.g. base_url + 0, + 1, …)")
                color: "#aaaaaa"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 6
                    color: "#1a1a1a"
                    border.color: urlField.activeFocus ? "#0088ff" : "#505050"
                    border.width: 1

                    TextInput {
                        id: urlField
                        anchors.fill: parent
                        anchors.margins: 8
                        text: rtspSettings.baseUrl
                        color: "#ffffff"
                        font.pixelSize: 13
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        selectionColor: "#0066cc"
                    }
                }

                Rectangle {
                    width: 70
                    height: 36
                    radius: 6
                    color: applyMouseArea.containsMouse ? "#0088ff" : "#0066cc"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Apply")
                        color: "white"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        id: applyMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            rtspSettings.baseUrl = urlField.text
                            root.rtspBaseUrl = urlField.text
                            urlConfigDialog.visible = false
                        }
                    }
                }

                Rectangle {
                    width: 70
                    height: 36
                    radius: 6
                    color: cancelMouseArea.containsMouse ? "#ff4444" : "#404040"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        color: "white"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: cancelMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: urlConfigDialog.visible = false
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // =========================
        // TOP BAR – ENHANCED CONTROLS
        // =========================
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: "#2d2d2d"
            radius: 8
            border.color: "#3d3d3d"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                // Logo/Title Section
                RowLayout {
                    spacing: 8

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 6
                        color: "#0066cc"

                        Text {
                            anchors.centerIn: parent
                            text: "◉"
                            font.pixelSize: 20
                            color: "white"
                        }
                    }

                    QGCLabel {
                        text: qsTr("Surveillance Monitor")
                        font.pixelSize: 16
                        font.bold: true
                        color: "#ffffff"
                    }
                }

                Rectangle {
                    width: 1
                    height: 32
                    color: "#3d3d3d"
                }

                // Layout Controls
                RowLayout {
                    spacing: 4

                    QGCLabel {
                        text: qsTr("Grid:")
                        color: "#cccccc"
                        font.pixelSize: 13
                    }

                    Repeater {
                        model: [
                            {text: "2×2", value: 0},
                            {text: "3×3", value: 1},
                            {text: "4×4", value: 2}
                        ]

                        Rectangle {
                            width: 60
                            height: 36
                            radius: 6
                            color: SurveillanceManager.gridLayout === modelData.value ? "#0066cc" : "#404040"
                            border.color: SurveillanceManager.gridLayout === modelData.value ? "#0088ff" : "#505050"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.text
                                color: "white"
                                font.pixelSize: 13
                                font.bold: SurveillanceManager.gridLayout === modelData.value
                            }

                            // Hover effect overlay
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "white"
                                opacity: gridButtonMouseArea.containsMouse && SurveillanceManager.gridLayout !== modelData.value ? 0.1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: gridButtonMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    SurveillanceManager.gridLayout = modelData.value
                                    fullscreenIndex = -1
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Stats Section
                Rectangle {
                    width: 180
                    height: 36
                    radius: 6
                    color: "#1a1a1a"
                    border.color: "#3d3d3d"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12

                        RowLayout {
                            spacing: 6
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: "#00cc66"

                                SequentialAnimation on opacity {
                                    running: true
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 800 }
                                    NumberAnimation { to: 1.0; duration: 800 }
                                }
                            }
                            QGCLabel {
                                text: qsTr("Active:")
                                font.pixelSize: 11
                                color: "#999999"
                            }
                            QGCLabel {
                                text: root.cellCount
                                font.pixelSize: 12
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 20
                            color: "#3d3d3d"
                        }

                        RowLayout {
                            spacing: 6
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: "#ff4444"
                            }
                            QGCLabel {
                                text: qsTr("Recording")
                                font.pixelSize: 11
                                color: "#999999"
                            }
                        }
                    }
                }

                // Configure URL Button
                Rectangle {
                    width: 110
                    height: 36
                    radius: 6
                    color: configMouseArea.containsMouse ? "#0088ff" : "#404040"
                    border.color: "#505050"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "⚙"
                            color: "white"
                            font.pixelSize: 16
                        }

                        Text {
                            text: qsTr("RTSP URL")
                            color: "white"
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: configMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            urlField.text = rtspSettings.baseUrl
                            urlConfigDialog.visible = true
                        }
                    }
                }

                // Fullscreen Exit Button
                Rectangle {
                    visible: fullscreenIndex >= 0
                    width: 36
                    height: 36
                    radius: 6
                    color: mouseAreaExit.containsMouse ? "#ff4444" : "#404040"
                    border.color: "#505050"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    MouseArea {
                        id: mouseAreaExit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fullscreenIndex = -1
                    }
                }

                // Close Surveillance Button
                Rectangle {
                    width: 100
                    height: 36
                    radius: 6
                    color: closeMouseArea.containsMouse ? "#ff4444" : "#404040"
                    border.color: "#505050"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "✕"
                            color: "white"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            text: qsTr("Close")
                            color: "white"
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: closeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            QGroundControl.surveillanceManager.active = false
                        }
                    }
                }
            }
        }

        // =========================
        // VIDEO GRID WITH ANIMATION
        // =========================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridLayout {
                id: grid
                anchors.fill: parent
                columns: fullscreenIndex >= 0 ? 1 : root.columns
                rowSpacing: 8
                columnSpacing: 8

                Behavior on columns {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: root.cellCount

                    VideoFeed {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: fullscreenIndex === -1 || fullscreenIndex === index

                        streamName: "Camera " + (index + 1)
                        streamId: "cam" + index
                        rtspUrl: root.rtspBaseUrl + index
                        isFullscreen: fullscreenIndex === index

                        onFullscreenRequested: {
                            fullscreenIndex = fullscreenIndex === index ? -1 : index
                        }

                        // Smooth transition
                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }
                        opacity: visible ? 1.0 : 0.0
                    }
                }
            }
        }
    }
}
