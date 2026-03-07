import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    clip: true

    property string streamName: "Camera"
    property string streamId: "cam0"
    property string rtspUrl: ""
    property bool isFullscreen: false
    property bool isConnected: false
    property bool isRecording: false
    property bool showHeader: true
    property bool showBorder: true

    signal fullscreenRequested()

    Connections {
        target: QGroundControl.videoManager
        function onCustomStreamStreamingChanged(name, active) {
            if (name === streamId) {
                isConnected = active
            }
        }
    }

    Component.onDestruction: {
        QGroundControl.videoManager.removeCustomStream(streamId)
    }

    // Main Container
    Rectangle {
        id: container
        anchors.fill: parent
        color: "#0a0a0a"
        radius: 8
        border.color: showBorder ? (hoverArea.containsMouse ? "#0066cc" : "#2d2d2d") : "transparent"
        border.width: showBorder ? 2 : 0

        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }

        // Video Background
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            color: "black"
            radius: 6
            clip: true

            QGCVideoBackground {
                anchors.fill: parent
                objectName: streamId

                Component.onCompleted: {
                    console.log("VideoFeed completed for:", streamId)
                    QGroundControl.videoManager.addCustomStream(streamId, rtspUrl)
                    QGroundControl.videoManager.setCustomStreamWidget(streamId, this)
                    root.isConnected = QGroundControl.videoManager.isCustomStreamStreaming(streamId)
                }
            }

            // No stream overlay
            Rectangle {
                anchors.fill: parent
                color: "#0D1117"
                visible: !isConnected

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignHCenter
                        width:    52
                        height:   52
                        source:   "/qmlimages/CameraIcon.svg"
                        color:    Qt.rgba(0, 0.749, 1.0, 0.65)
                        fillMode: Image.PreserveAspectFit
                    }

                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text:           qsTr("No active stream")
                        font.pixelSize: 13
                        color:          Qt.rgba(1, 1, 1, 0.55)
                    }
                }
            }
        }

        // Top Bar - Stream Name and Status
        Rectangle {
            id: topBar
            visible: root.showHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            height: 36
            radius: 6
            color: "#cc000000"

            opacity: hoverArea.containsMouse || isRecording ? 1.0 : 0.7
            Behavior on opacity { NumberAnimation { duration: 200 } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // Connection Status Indicator
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: isConnected ? "#00cc66" : "#ff4444"

                    SequentialAnimation on scale {
                        running: isConnected
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.2; duration: 1000 }
                        NumberAnimation { to: 1.0; duration: 1000 }
                    }
                }

                // Stream Name
                QGCLabel {
                    Layout.fillWidth: true
                    text: streamName
                    color: "white"
                    font.bold: true
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                // Recording Indicator
                Rectangle {
                    visible: isRecording
                    width: 60
                    height: 20
                    radius: 10
                    color: "#cc000000"
                    border.color: "#ff4444"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: "#ff4444"

                            SequentialAnimation on opacity {
                                running: isRecording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 800 }
                                NumberAnimation { to: 1.0; duration: 800 }
                            }
                        }

                        Text {
                            text: "REC"
                            color: "#ff4444"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                }

                // Stream Resolution/Quality
                Rectangle {
                    visible: isConnected
                    width: 60
                    height: 20
                    radius: 4
                    color: "#cc000000"
                    border.color: "#00cc66"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "1080p"
                        color: "#00cc66"
                        font.pixelSize: 9
                        font.bold: true
                    }
                }
            }
        }

        // Bottom Control Bar (appears on hover)
        Rectangle {
            id: bottomBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            height: 44
            radius: 6
            color: "#dd000000"

            opacity: hoverArea.containsMouse ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                // Stream Info
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    QGCLabel {
                        text: qsTr("RTSP Stream")
                        font.pixelSize: 9
                        color: "#999999"
                    }
                    QGCLabel {
                        text: rtspUrl
                        font.pixelSize: 10
                        color: "#cccccc"
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }

                // Control Buttons
                Repeater {
                    model: [
                        {icon: "◼", tooltip: "Stop", color: "#ff4444"},
                        {icon: "📷", tooltip: "Snapshot", color: "#0066cc"},
                        {icon: isFullscreen ? "⊟" : "⊞", tooltip: isFullscreen ? "Exit Fullscreen" : "Fullscreen", color: "#0066cc"}
                    ]

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 6
                        color: btnMouseArea.containsMouse ? modelData.color : "#404040"
                        border.color: "#505050"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: "white"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: btnMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (index === 2) { // Fullscreen button
                                    root.fullscreenRequested()
                                } else if (index === 1) { // Snapshot
                                    console.log("Snapshot:", streamId)
                                } else if (index === 0) { // Stop
                                    console.log("Stop stream:", streamId)
                                }
                            }
                        }

                        // Tooltip
                        Rectangle {
                            visible: btnMouseArea.containsMouse
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tooltipText.width + 12
                            height: 22
                            radius: 4
                            color: "#dd000000"
                            border.color: "#404040"
                            border.width: 1

                            Text {
                                id: tooltipText
                                anchors.centerIn: parent
                                text: modelData.tooltip
                                color: "white"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }

        // Stream Statistics Overlay (top-right corner)
        Rectangle {
            visible: isConnected && hoverArea.containsMouse
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            anchors.topMargin: 52
            width: 100
            height: statsLayout.height + 12
            radius: 6
            color: "#dd000000"
            border.color: "#2d2d2d"
            border.width: 1

            opacity: hoverArea.containsMouse ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            ColumnLayout {
                id: statsLayout
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: [
                        {label: "FPS", value: "30"},
                        {label: "Bitrate", value: "2.5M"},
                        {label: "Latency", value: "45ms"}
                    ]

                    RowLayout {
                        spacing: 8

                        QGCLabel {
                            text: modelData.label + ":"
                            font.pixelSize: 9
                            color: "#999999"
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: modelData.value
                            font.pixelSize: 9
                            font.bold: true
                            color: "#00cc66"
                        }
                    }
                }
            }
        }

        // Hover Area for entire feed
        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton
        }
    }
}
    // Subtle shadow effect
    /*DropShadow {
        anchors.fill: container
        source: container
        horizontalOffset: 0
        verticalOffset: 4
        radius: 12
        samples: 16
        color: "#40000000"
        visible: hoverArea.containsMouse
    }
}

// Fallback for DropShadow if not available
Item {
    id: dropShadowFallback
    // Empty fallback component
}

// Simple replacement if DropShadow is not available
Component {
    id: dropShadowComponent
    Item {}
}
