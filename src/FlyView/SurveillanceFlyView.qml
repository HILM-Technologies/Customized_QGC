/*import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
//import QGroundControl.ScreenTools
//import QGroundControl.Palette

/// Main surveillance view showing video grid
Rectangle {
    id: root

    color: qgcPal.window

    property var surveillanceManager: SurveillanceManager
    property bool showControls: true

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    // Top control bar
    Rectangle {
        id: controlBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: ScreenTools.defaultFontPixelHeight * 3
        color: Qt.rgba(0, 0, 0, 0.8)
        visible: showControls
        z: 100

        RowLayout {
            anchors.fill: parent
            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("Surveillance Mode")
                font.bold: true
                font.pointSize: ScreenTools.mediumFontPointSize
                color: "white"
            }

            Rectangle {
                width: 1
                Layout.fillHeight: true
                color: Qt.rgba(1, 1, 1, 0.3)
            }

            QGCLabel {
                text: qsTr("Layout:")
                color: "white"
            }

            QGCButton {
                text: "2×2"
                checkable: true
                checked: surveillanceManager.gridLayout === 0
                onClicked: surveillanceManager.gridLayout = 0
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5
            }

            QGCButton {
                text: "3×3"
                checkable: true
                checked: surveillanceManager.gridLayout === 1
                onClicked: surveillanceManager.gridLayout = 1
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5
            }

            QGCButton {
                text: "4×4"
                checkable: true
                checked: surveillanceManager.gridLayout === 2
                onClicked: surveillanceManager.gridLayout = 2
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5
            }

            Rectangle {
                width: 1
                Layout.fillHeight: true
                color: Qt.rgba(1, 1, 1, 0.3)
            }

            QGCButton {
                text: surveillanceManager.recordingAll ? qsTr("⏹ Stop All") : qsTr("⏺ Record All")
                onClicked: {
                    if (surveillanceManager.recordingAll) {
                        surveillanceManager.stopRecordingAll()
                    } else {
                        surveillanceManager.startRecordingAll()
                    }
                }
                highlighted: surveillanceManager.recordingAll
            }

            QGCButton {
                text: qsTr("📷 Snapshot All")
                onClicked: surveillanceManager.takeSnapshotAll()
            }

            Item { Layout.fillWidth: true }

            QGCLabel {
                text: qsTr("Feeds: %1").arg(surveillanceManager.activeFeedCount)
                color: "white"
            }

            QGCButton {
                text: qsTr("Exit")
                onClicked: surveillanceManager.active = false
            }
        }
    }

    // Video grid container
    Item {
        id: gridContainer
        anchors.top: controlBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5

        // Focused view (full screen single feed)
        Loader {
            id: focusedViewLoader
            anchors.fill: parent
            active: surveillanceManager.focusedFeed !== null
            visible: active
            z: 10

            sourceComponent: VideoFeedCell {
                videoFeed: surveillanceManager.focusedFeed
                showFullControls: true

                // Exit button for focused view
                QGCButton {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: ScreenTools.defaultFontPixelHeight
                    text: qsTr("⛶ Exit Focus")
                    onClicked: surveillanceManager.clearFocus()
                    z: 100
                }
            }
        }

        // Grid view
        Grid {
            id: videoGrid
            anchors.fill: parent
            visible: !focusedViewLoader.active

            columns: surveillanceManager.getGridColumns()
            rows: surveillanceManager.getGridRows()
            columnSpacing: ScreenTools.defaultFontPixelHeight * 0.5
            rowSpacing: ScreenTools.defaultFontPixelHeight * 0.5

            // Calculate cell dimensions
            property real cellWidth: (width - (columns - 1) * columnSpacing) / columns
            property real cellHeight: (height - (rows - 1) * rowSpacing) / rows

            // Show all cells (filled and empty)
            Repeater {
                model: videoGrid.columns * videoGrid.rows

                VideoFeedCell {
                    width: videoGrid.cellWidth
                    height: videoGrid.cellHeight

                    // Get the feed for this index, or null if none available
                    videoFeed: {
                        if (index < surveillanceManager.videoFeeds.count) {
                            return surveillanceManager.videoFeeds.get(index)
                        }
                        return null
                    }

                    onDoubleClicked: {
                        if (videoFeed) {
                            surveillanceManager.focusedFeed = videoFeed
                        }
                    }

                    // Empty cell styling
                    color: videoFeed ? "black" : Qt.rgba(0.1, 0.1, 0.1, 1)
                    border.color: videoFeed ? (videoFeed.focused ? qgcPal.colorYellow : Qt.rgba(1, 1, 1, 0.3)) : Qt.rgba(1, 1, 1, 0.15)
                }
            }
        }
    }

    // No feeds message (only show when no vehicles at all)
    Rectangle {
        anchors.centerIn: gridContainer
        width: parent.width * 0.5
        height: ScreenTools.defaultFontPixelHeight * 6
        visible: surveillanceManager.activeFeedCount === 0 && !focusedViewLoader.active
        color: Qt.rgba(0, 0, 0, 0.7)
        radius: ScreenTools.defaultFontPixelHeight * 0.5
        border.color: qgcPal.text
        border.width: 2
        z: 5

        Column {
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelHeight

            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("No Video Feeds Available")
                font.pointSize: ScreenTools.largeFontPointSize
                font.bold: true
            }

            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Connect vehicles with video streams to begin surveillance")
                font.pointSize: ScreenTools.mediumFontPointSize
                color: Qt.rgba(1, 1, 1, 0.7)
            }
        }
    }
}

*/
/*
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    anchors.fill: parent

    property int columns: SurveillanceManager.getGridColumns
    property int rows: SurveillanceManager.getGridRows
    property int cellCount: columns * rows

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // =========================
        // TOP BAR – GRID CONTROLS
        // =========================
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            QGCLabel {
                text: qsTr("Layout:")
            }

            QGCButton {
                text: "2×2"
                checkable: true
                checked: SurveillanceManager.gridLayout === 0
                onClicked: SurveillanceManager.gridLayout = 0
            }

            QGCButton {
                text: "3×3"
                checkable: true
                checked: SurveillanceManager.gridLayout === 1
                onClicked: SurveillanceManager.gridLayout = 1
            }

            QGCButton {
                text: "4×4"
                checkable: true
                checked: SurveillanceManager.gridLayout === 2
                onClicked: SurveillanceManager.gridLayout = 2
            }

            Item { Layout.fillWidth: true } // spacer
        }

        // =========================
        // VIDEO GRID
        // =========================
        GridLayout {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true

            columns: root.columns
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: root.cellCount

                VideoFeed {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    streamName: "cam" + index
                    rtspUrl: "rtsp://192.168.1.17:8554/mystream" + index
                }
            }
        }
    }
    /*Component.onCompleted: {
           Qt.callLater(function() {

               for (let i = 0; i < cellCount; i++) {
                   let name = "cam" + i
                   let url  = "rtsp://192.168.1.17:8554/mystream" + i

                   console.log("Registering stream:", name)

                   QGroundControl.videoManager.addCustomStream(name, url)
               }

           })
       }

}

/* // =========================
 // EMPTY STATE
 // =========================
 QGCLabel {
     anchors.centerIn: parent
     visible: SurveillanceManager.videoFeeds.count === 0
     text: qsTr("No active video feeds")
     opacity: 0.5
 }*/
/*
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    anchors.fill: parent

    property int columns: SurveillanceManager.getGridColumns
    property int rows: SurveillanceManager.getGridRows
    property int cellCount: columns * rows
    property int fullscreenIndex: -1

    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"
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

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    SurveillanceManager.gridLayout = modelData.value
                                    fullscreenIndex = -1
                                }
                            }

                            // Hover effect
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "white"
                                opacity: mouseArea.containsMouse && SurveillanceManager.gridLayout !== modelData.value ? 0.1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: parent.MouseArea.clicked()
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
                        rtspUrl: "rtsp://192.168.1.17:8554/mystream" + index
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
*/
/*
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    anchors.fill: parent

    property int columns: SurveillanceManager.getGridColumns
    property int rows: SurveillanceManager.getGridRows
    property int cellCount: columns * rows
    property int fullscreenIndex: -1

    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"
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
                        rtspUrl: "rtsp://192.168.1.17:8554/mystream" + index
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
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.settings 1.0

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
