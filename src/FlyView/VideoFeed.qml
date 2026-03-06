/*import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls
//import QGroundControl.ScreenTools
//import QGroundControl.Palette

/// Individual video feed cell in surveillance grid
Rectangle {
    id: root

    property var videoFeed: null
    property bool showFullControls: false

    signal doubleClicked()

    color: "black"
    border.color: (videoFeed && videoFeed.focused) ? qgcPal.colorYellow : Qt.rgba(1, 1, 1, 0.3)
    border.width: (videoFeed && videoFeed.focused) ? 3 : 1
    radius: ScreenTools.defaultFontPixelHeight * 0.25

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    // Video display area
    Item {
        id: videoContainer
        anchors.fill: parent
        anchors.margins: 2

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.1, 0.1, 0.1, 1)

            Column {
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelHeight * 0.5
                visible: !videoFeed || !videoFeed.hasVideo

                QGCColoredImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "/qmlimages/CameraIcon.svg"
                    width: ScreenTools.defaultFontPixelHeight * 3
                    height: ScreenTools.defaultFontPixelHeight * 3
                    color: Qt.rgba(1, 1, 1, 0.3)
                    fillMode: Image.PreserveAspectFit
                }

                QGCLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: videoFeed ? (videoFeed.hasVideo ? qsTr("Video Active") : qsTr("No Video Signal")) : qsTr("No Feed")
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font.pointSize: showFullControls ? ScreenTools.largeFontPointSize : ScreenTools.defaultFontPointSize
                }
            }

            // Active indicator when video is present
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0.5, 0, 0.1)
                visible: videoFeed ? videoFeed.hasVideo : false

                QGCLabel {
                    anchors.centerIn: parent
                    text: qsTr("📹 LIVE")
                    font.pointSize: ScreenTools.largeFontPointSize
                    font.bold: true
                    color: Qt.rgba(0, 1, 0, 0.7)
                }
            }
        }
    }

    // Top info overlay
    Rectangle {
        id: topOverlay
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: infoColumn.height + ScreenTools.defaultFontPixelHeight * 0.5
        color: Qt.rgba(0, 0, 0, 0.7)
        visible: videoFeed !== null

        Column {
            id: infoColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.25
            spacing: 2

            QGCLabel {
                text: videoFeed ? videoFeed.vehicleName : ""
                font.bold: true
                font.pointSize: showFullControls ? ScreenTools.largeFontPointSize : ScreenTools.mediumFontPointSize
                color: "white"
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth
                visible: videoFeed ? videoFeed.hasVideo : false

                QGCLabel {
                    text: videoFeed ? videoFeed.resolution : ""
                    font.pointSize: ScreenTools.smallFontPointSize
                    color: Qt.rgba(1, 1, 1, 0.8)
                }

                QGCLabel {
                    text: "•"
                    font.pointSize: ScreenTools.smallFontPointSize
                    color: Qt.rgba(1, 1, 1, 0.8)
                }

                QGCLabel {
                    text: videoFeed ? (videoFeed.fps.toFixed(1) + " fps") : "0.0 fps"
                    font.pointSize: ScreenTools.smallFontPointSize
                    color: Qt.rgba(1, 1, 1, 0.8)
                }

                QGCLabel {
                    text: "•"
                    font.pointSize: ScreenTools.smallFontPointSize
                    color: Qt.rgba(1, 1, 1, 0.8)
                }

                QGCLabel {
                    text: videoFeed ? videoFeed.bitrate : "0 kbps"
                    font.pointSize: ScreenTools.smallFontPointSize
                    color: Qt.rgba(1, 1, 1, 0.8)
                }
            }

            // Dropped frames warning
            QGCLabel {
                text: qsTr("⚠ Dropped: %1 frames").arg(videoFeed ? videoFeed.droppedFrames : 0)
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.colorOrange
                visible: videoFeed ? (videoFeed.droppedFrames > 10) : false
            }
        }

        // Recording indicator
        Rectangle {
            id: recordingIndicator
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.25
            width: ScreenTools.defaultFontPixelHeight * 2
            height: ScreenTools.defaultFontPixelHeight * 1.5
            radius: height / 4
            color: "red"
            visible: videoFeed ? videoFeed.recording : false

            Row {
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                Rectangle {
                    width: ScreenTools.defaultFontPixelHeight * 0.6
                    height: width
                    radius: width / 2
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }

                QGCLabel {
                    text: "REC"
                    font.pointSize: ScreenTools.smallFontPointSize
                    font.bold: true
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            SequentialAnimation on opacity {
                running: recordingIndicator.visible
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
            }
        }
    }

    // Control buttons
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onDoubleClicked: {
            root.doubleClicked()
        }
    }

    Rectangle {
        id: controlsOverlay
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: controlsRow.height + ScreenTools.defaultFontPixelHeight * 0.5
        color: Qt.rgba(0, 0, 0, 0.7)
        visible: (mouseArea.containsMouse || showFullControls) && (videoFeed !== null)

        Row {
            id: controlsRow
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelWidth

            QGCButton {
                text: (videoFeed && videoFeed.recording) ? qsTr("⏹ Stop") : qsTr("⏺ Record")
                onClicked: {
                    if (videoFeed) {
                        if (videoFeed.recording) {
                            videoFeed.stopRecording()
                        } else {
                            videoFeed.startRecording()
                        }
                    }
                }
                enabled: videoFeed ? videoFeed.hasVideo : false
                highlighted: videoFeed ? videoFeed.recording : false
            }

            QGCButton {
                text: qsTr("📷 Snapshot")
                onClicked: {
                    if (videoFeed) {
                        videoFeed.takeSnapshot()
                    }
                }
                enabled: videoFeed ? videoFeed.hasVideo : false
            }

            QGCButton {
                text: (videoFeed && videoFeed.focused) ? qsTr("⛶ Unfocus") : qsTr("⛶ Focus")
                onClicked: {
                    if (videoFeed) {
                        videoFeed.focused = !videoFeed.focused
                    }
                }
                visible: showFullControls
            }
        }
    }

    // Focus indicator border animation
    SequentialAnimation on border.color {
        running: videoFeed ? videoFeed.focused : false
        loops: Animation.Infinite
        ColorAnimation {
            from: qgcPal.colorYellow
            to: Qt.rgba(1, 0.8, 0, 1)
            duration: 1000
        }
        ColorAnimation {
            from: Qt.rgba(1, 0.8, 0, 1)
            to: qgcPal.colorYellow
            duration: 1000
        }
    }

    // Click helper text
    QGCLabel {
        anchors.centerIn: parent
        text: qsTr("Double-click to focus")
        font.pointSize: ScreenTools.smallFontPointSize
        color: Qt.rgba(1, 1, 1, 0.6)
        visible: mouseArea.containsMouse && !showFullControls && videoFeed && videoFeed.hasVideo

        /*background: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.7)
            radius: ScreenTools.defaultFontPixelHeight * 0.25
        }
        padding: ScreenTools.defaultFontPixelHeight * 0.25
    }
}
*/
/*
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root
    radius: 4
    color: qgcPal.window
    border.width: feed && feed.focused ? 2 : 1
    border.color: feed && feed.focused
                  ? qgcPal.warningText
                  : qgcPal.windowShade

    property var feed   // VideoFeedItem*

    QGCPalette { id: qgcPal }

    // ========================
    // VIDEO OUTPUT (CORRECT)
    // ========================
    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        visible: feed && feed.hasVideo
        //source: feed ? feed.videoReceiver : null
        fillMode: VideoOutput.PreserveAspectCrop
    }

    // ========================
    // EMPTY CELL
    // ========================
    QGCLabel {
        anchors.centerIn: parent
        visible: !feed
        text: qsTr("No video feed!")
        opacity: 0.4
    }

    // ========================
    // TOP INFO BAR
    // ========================
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        color: "#66000000"
        visible: true //feed

        RowLayout {
            anchors.fill: parent
            anchors.margins: 6

            QGCLabel {
                text: feed ? feed.vehicleName : ""
                color: "white"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            QGCLabel {
                text: feed && feed.recording ? qsTr("REC") : ""
                color: qgcPal.warningText
                font.bold: true
            }
        }
    }

    // ========================
    // ACTION BUTTONS
    // ========================
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        spacing: 6
        visible: true //feed

        QGCButton {
            text: feed && feed.recording ? qsTr("Stop") : qsTr("Rec")
            onClicked: feed.recording
                       ? feed.stopRecording()
                       : feed.startRecording()
        }

        QGCButton {
            text: qsTr("Snap")
            onClicked: feed.takeSnapshot()
        }

        QGCButton {
            text: qsTr("Focus")
            checkable: true
            checked: feed && feed.focused
            onClicked: {
                checked
                    ? SurveillanceManager.focusedFeed = feed
                    : SurveillanceManager.clearFocus()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: feed
        onDoubleClicked: SurveillanceManager.focusedFeed = feed
    }
}*/
/*
import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import org.freedesktop.gstreamer.Qt6GLVideoItem 1.0

Rectangle {
    id: root
    radius: 4
    color: "black"
    border.width: 1
    border.color: "#404040"

    Component.onCompleted: {
        QGroundControl.videoManager.addCustomStream("cam1", "rtsp://192.168.1.17:8554/mystream")
    }
    QGCPalette { id: qgcPal }

    // ========================
    // VIDEO STREAM
    // ========================
    GstGLQt6VideoItem {
        objectName: "cam1"
        Layout.fillWidth: true
        Layout.fillHeight: true
    }


    // ========================
    // NO VIDEO FALLBACK
    // ========================
    Image {
        anchors.fill: parent
        source: "/res/NoVideoBackground.jpg"
        fillMode: Image.PreserveAspectCrop
        visible: !QGroundControl.videoManager.decoding
    }

    // ========================
    // OVERLAY LABEL
    // ========================
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        color: "#66000000"

        QGCLabel {
            anchors.centerIn: parent
            text: qsTr("Demo Stream")
            color: "white"
            font.bold: true
        }
    }
}
*/
/*
import QtQuick
import QtQuick.Controls
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Rectangle {
    id: root
    radius: 4
    color: "black"

    property string streamName
       property string rtspUrl

    Component {
        id: videoBackgroundComponent
        QGCVideoBackground {
            id:             videoContent
            objectName:     streamName

            Connections {
                target: QGroundControl.videoManager
                function onImageFileChanged(filename) {
                    videoContent.grabToImage(function(result) {
                        if (!result.saveToFile(filename)) {
                            console.error('Error capturing video frame');
                        }
                    });
                }
            }

            Rectangle {
                color:  Qt.rgba(1,1,1,0.5)
                height: parent.height
                width:  1
                x:      parent.width * 0.33
                visible: _showGrid && !QGroundControl.videoManager.fullScreen
            }
            Rectangle {
                color:  Qt.rgba(1,1,1,0.5)
                height: parent.height
                width:  1
                x:      parent.width * 0.66
                visible: _showGrid && !QGroundControl.videoManager.fullScreen
            }
            Rectangle {
                color:  Qt.rgba(1,1,1,0.5)
                width:  parent.width
                height: 1
                y:      parent.height * 0.33
                visible: _showGrid && !QGroundControl.videoManager.fullScreen
            }
            Rectangle {
                color:  Qt.rgba(1,1,1,0.5)
                width:  parent.width
                height: 1
                y:      parent.height * 0.66
                visible: _showGrid && !QGroundControl.videoManager.fullScreen
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        color: "#66000000"

        QGCLabel {
            anchors.centerIn: parent
            text: streamName
            color: "white"
            font.bold: true
        }
    }
}
*/
/*
import QtQuick
import QtQuick.Controls
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Rectangle {
    id: root
    radius: 4
    color: "black"

    property string streamName
    property string rtspUrl

    // Instantiate the video background
    Loader {
        id: videoLoader
        anchors.fill: parent
        sourceComponent: videoBackgroundComponent
    }

    Component {
        id: videoBackgroundComponent

        QGCVideoBackground {
            id: videoContent
            objectName: streamName   // MUST MATCH receiver->setName(name)
            anchors.fill: parent
        }
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            QGroundControl.videoManager.addCustomStream(streamName, rtspUrl)
        })
    }

    Component.onDestruction: {
        QGroundControl.videoManager.removeCustomStream(streamName)
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        color: "#66000000"

        QGCLabel {
            anchors.centerIn: parent
            text: streamName
            color: "white"
            font.bold: true
        }
    }
}
*/
/*
import QtQuick
import QtQuick.Controls
import QGroundControl
import QGroundControl.Controls
//import QGroundControl.FlyView

Item {
    id: root
    clip: true

    property string streamName
    property string rtspUrl

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    QGCVideoBackground {
        anchors.fill: parent
        objectName: streamName

        Component.onCompleted: {
            console.log("VideoFeed completed for:", streamName)
            QGroundControl.videoManager.addCustomStream(streamName, rtspUrl)
            QGroundControl.videoManager.setCustomStreamWidget(streamName, this)        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        color: "#66000000"

        QGCLabel {
            anchors.centerIn: parent
            text: streamName
            color: "white"
            font.bold: true
        }
    }
}
*//*
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    clip: true

    property string streamName: "Camera"
    property string rtspUrl: ""
    property int cameraIndex: 0
    property bool isRecording: false
    property bool isConnected: true
    property bool isFullscreen: false
    property int signalStrength: 3 // 0-3
    property bool motionDetected: false

    signal requestFullscreen()

    // Theme colors
    readonly property color bgDark: "#1a1a1a"
    readonly property color bgCard: "#2d2d2d"
    readonly property color accentColor: "#00a6ff"
    readonly property color warningColor: "#ff9500"
    readonly property color dangerColor: "#ff3b30"
    readonly property color successColor: "#34c759"

    // Simulate connection status (remove in production)
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            isConnected = Math.random() > 0.1
            signalStrength = Math.floor(Math.random() * 4)
        }
    }

    Rectangle {
        id: cellBackground
        anchors.fill: parent
        color: bgCard
        radius: 6
        border.width: mouseArea.containsMouse ? 2 : 1
        border.color: mouseArea.containsMouse ? accentColor : "#3d3d3d"

        Behavior on border.width { NumberAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Video Background
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 4
            color: "black"

            QGCVideoBackground {
                anchors.fill: parent
                objectName: "cam" + cameraIndex
            }

            // No Signal Overlay
            Rectangle {
                anchors.fill: parent
                color: "#1a1a1a"
                visible: !isConnected
                radius: 4

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "⚠"
                        font.pixelSize: 48
                        color: warningColor
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("NO SIGNAL")
                        font.pixelSize: 16
                        font.bold: true
                        color: "#cccccc"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Attempting to reconnect...")
                        font.pixelSize: 11
                        color: "#999999"
                    }

                    // Pulsing animation
                    SequentialAnimation on opacity {
                        running: !isConnected
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.5; duration: 1000 }
                        NumberAnimation { to: 1.0; duration: 1000 }
                    }
                }
            }

            // Motion Detection Overlay
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 3
                border.color: dangerColor
                radius: 4
                visible: motionDetected && isConnected

                SequentialAnimation on opacity {
                    running: motionDetected
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }
        }

        // =========================
        // TOP HEADER BAR
        // =========================
        Rectangle {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 4
            height: 36
            radius: 4
            color: "#cc000000"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // Camera Name & Status
                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        spacing: 6

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: isConnected ? successColor : dangerColor

                            SequentialAnimation on opacity {
                                running: isConnected
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.5; duration: 800 }
                                NumberAnimation { to: 1.0; duration: 800 }
                            }
                        }

                        Text {
                            text: streamName
                            font.pixelSize: 13
                            font.bold: true
                            color: "white"
                        }
                    }

                    Text {
                        text: isConnected ? qsTr("LIVE • %1").arg(Qt.formatTime(new Date(), "hh:mm:ss")) : qsTr("OFFLINE")
                        font.pixelSize: 9
                        color: isConnected ? successColor : "#999999"
                        font.family: "monospace"
                    }
                }

                // Signal Strength Indicator
                Row {
                    spacing: 2
                    visible: isConnected

                    Repeater {
                        model: 3
                        Rectangle {
                            width: 3
                            height: 6 + (index * 3)
                            radius: 1
                            color: index < signalStrength ? accentColor : "#3d3d3d"
                            anchors.bottom: parent.bottom
                        }
                    }
                }

                // Recording Indicator
                Rectangle {
                    width: 24
                    height: 24
                    radius: 3
                    color: isRecording ? dangerColor : "#3d3d3d"
                    visible: isRecording

                    Text {
                        anchors.centerIn: parent
                        text: "●"
                        font.pixelSize: 12
                        color: "white"
                    }

                    SequentialAnimation on opacity {
                        running: isRecording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 800 }
                        NumberAnimation { to: 1.0; duration: 800 }
                    }
                }

                // Motion Detection Badge
                Rectangle {
                    width: 60
                    height: 20
                    radius: 3
                    color: dangerColor
                    visible: motionDetected && isConnected

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("MOTION")
                        font.pixelSize: 9
                        font.bold: true
                        color: "white"
                    }
                }
            }
        }

        // =========================
        // CONTROL OVERLAY (on hover)
        // =========================
        Rectangle {
            id: controlOverlay
            anchors.fill: parent
            anchors.margins: 4
            radius: 4
            color: "#99000000"
            visible: mouseArea.containsMouse && isConnected
            opacity: 0

            Behavior on opacity { NumberAnimation { duration: 200 } }

            states: State {
                when: mouseArea.containsMouse && isConnected
                PropertyChanges { target: controlOverlay; opacity: 1 }
            }

            // Center Control Buttons
            RowLayout {
                anchors.centerIn: parent
                spacing: 16

                // Fullscreen Button
                ToolButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    text: isFullscreen ? "⊡" : "⊞"
                    font.pixelSize: 24
                    ToolTip.text: isFullscreen ? qsTr("Exit Fullscreen") : qsTr("Fullscreen")
                    ToolTip.visible: hovered

                    background: Rectangle {
                        radius: 6
                        color: parent.hovered ? accentColor : "#4d4d4d"
                        border.width: 1
                        border.color: accentColor

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: requestFullscreen()
                }

                // Snapshot Button
                ToolButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    text: "📷"
                    font.pixelSize: 20
                    ToolTip.text: qsTr("Take Snapshot")
                    ToolTip.visible: hovered

                    background: Rectangle {
                        radius: 6
                        color: parent.hovered ? accentColor : "#4d4d4d"
                        border.width: 1
                        border.color: accentColor

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        console.log("Snapshot taken for", streamName)
                        snapshotFeedback.opacity = 1
                    }
                }

                // Record Button
                ToolButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    text: isRecording ? "⏹" : "⏺"
                    font.pixelSize: 24
                    ToolTip.text: isRecording ? qsTr("Stop Recording") : qsTr("Start Recording")
                    ToolTip.visible: hovered

                    background: Rectangle {
                        radius: 6
                        color: parent.hovered ? (isRecording ? dangerColor : accentColor) : "#4d4d4d"
                        border.width: 1
                        border.color: isRecording ? dangerColor : accentColor

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        isRecording = !isRecording
                        console.log(isRecording ? "Recording started" : "Recording stopped", streamName)
                    }
                }
            }

            // Bottom info bar
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                height: 28
                radius: 4
                color: "#cc000000"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    Text {
                        text: qsTr("Resolution: 1920×1080")
                        font.pixelSize: 10
                        color: "#cccccc"
                    }

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        color: "#3d3d3d"
                    }

                    Text {
                        text: qsTr("FPS: 30")
                        font.pixelSize: 10
                        color: "#cccccc"
                    }

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        color: "#3d3d3d"
                    }

                    Text {
                        text: qsTr("Bitrate: 8.2 Mbps")
                        font.pixelSize: 10
                        color: "#cccccc"
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        // Snapshot Flash Effect
        Rectangle {
            id: snapshotFeedback
            anchors.fill: parent
            anchors.margins: 4
            radius: 4
            color: "white"
            opacity: 0

            SequentialAnimation on opacity {
                running: snapshotFeedback.opacity > 0
                NumberAnimation { to: 0.8; duration: 100 }
                NumberAnimation { to: 0; duration: 300 }
            }
        }
    }

    // Mouse Area for hover detection
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true

        onDoubleClicked: {
            requestFullscreen()
        }
    }

    // Initialize video stream
    Component.onCompleted: {
        console.log("VideoFeedCell completed for:", streamName)
        QGroundControl.videoManager.addCustomStream("cam" + cameraIndex, rtspUrl)
        QGroundControl.videoManager.setCustomStreamWidget("cam" + cameraIndex, this)
    }
}*/

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
        border.color: hoverArea.containsMouse ? "#0066cc" : "#2d2d2d"
        border.width: 2

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

            // Connection Lost Overlay
            Rectangle {
                anchors.fill: parent
                color: "#0a0a0a"
                visible: !isConnected

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "⚠"
                        font.pixelSize: 48
                        color: "#ff9900"
                    }

                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Connection Lost")
                        font.pixelSize: 16
                        font.bold: true
                        color: "#ff9900"
                    }

                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Attempting to reconnect...")
                        font.pixelSize: 12
                        color: "#999999"
                    }

                    // Animated dots
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4
                        Repeater {
                            model: 3
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: "#0066cc"

                                SequentialAnimation on opacity {
                                    running: !isConnected
                                    loops: Animation.Infinite
                                    NumberAnimation {
                                        to: 0.2
                                        duration: 400
                                    }
                                    NumberAnimation {
                                        to: 1.0
                                        duration: 400
                                    }
                                    PauseAnimation { duration: index * 200 }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Top Bar - Stream Name and Status
        Rectangle {
            id: topBar
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
