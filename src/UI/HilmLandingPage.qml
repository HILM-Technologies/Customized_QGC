/****************************************************************************
 * HILM Landing Page — futuristic mission-control home screen
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    // ── HILM design tokens ─────────────────────────────────────────────────
    readonly property color _teal:       "#00C8C8"
    readonly property color _tealMid:    Qt.rgba(0, 0.784, 0.784, 0.65)
    readonly property color _tealBorder: Qt.rgba(0, 0.784, 0.784, 0.45)
    readonly property color _tealHover:  Qt.rgba(0, 0.784, 0.784, 0.16)
    readonly property color _bg:         Qt.rgba(0.033, 0.040, 0.040, 1.0)
    readonly property color _cardBg:     Qt.rgba(0.06,  0.08,  0.08,  1.0)
    readonly property real  _fh:         ScreenTools.defaultFontPixelHeight
    readonly property real  _fw:         ScreenTools.defaultFontPixelWidth

    // ── Card definitions (ID-referenced so Repeater can access safely) ─────
    property var cardModel: [
        { id: "fly",      title: "FLY",       tag: "LIVE VIEW",    desc: "Real-time monitoring\n& fleet control",      icon: "fly",      shortcut: "F" },
        { id: "plan",     title: "PLAN",       tag: "MISSION",      desc: "Design & upload\nflight waypoints",          icon: "plan",     shortcut: "P" },
        { id: "config",   title: "CONFIGURE",  tag: "VEHICLE",      desc: "Sensors, parameters\n& calibration",         icon: "config",   shortcut: "C" },
        { id: "settings", title: "SETTINGS",   tag: "APPLICATION",  desc: "Links, preferences\n& connections",          icon: "settings", shortcut: "S" },
        { id: "analyze",  title: "ANALYZE",    tag: "DATA",         desc: "Logs, telemetry\n& inspection",              icon: "analyze",  shortcut: "A" }
    ]

    // ── Full dark background ───────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: _bg }

    // ── Dot-grid background ────────────────────────────────────────────────
    Canvas {
        anchors.fill: parent
        opacity:      0.18
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#00C8C8"
            var sp = _fh * 1.9
            for (var x = 0; x <= width + sp; x += sp)
                for (var y = 0; y <= height + sp; y += sp) {
                    ctx.beginPath(); ctx.arc(x, y, 1.0, 0, Math.PI * 2); ctx.fill()
                }
        }
    }

    // ── Animated scan line ─────────────────────────────────────────────────
    Rectangle {
        x: 0; width: parent.width; height: 2; opacity: 0.10
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.50; color: "#00C8C8"    }
            GradientStop { position: 1.00; color: "transparent" }
        }
        NumberAnimation on y { from: 0; to: root.height; duration: 5000; loops: Animation.Infinite; easing.type: Easing.Linear }
    }

    // ── Top accent line ────────────────────────────────────────────────────
    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 3
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.25; color: "#00C8C8"    }
            GradientStop { position: 0.75; color: "#00C8C8"    }
            GradientStop { position: 1.00; color: "transparent" }
        }
    }

    // ── Corner L brackets ─────────────────────────────────────────────────
    Canvas {
        width: _fh * 5; height: _fh * 5; opacity: 0.35
        onPaint: {
            var ctx = getContext("2d"); ctx.strokeStyle = "#00C8C8"; ctx.lineWidth = 1.8
            ctx.beginPath(); ctx.moveTo(0, height * 0.5); ctx.lineTo(0, 0); ctx.lineTo(width * 0.5, 0); ctx.stroke()
        }
    }
    Canvas {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        width: _fh * 5; height: _fh * 5; opacity: 0.35
        onPaint: {
            var ctx = getContext("2d"); ctx.strokeStyle = "#00C8C8"; ctx.lineWidth = 1.8
            ctx.beginPath(); ctx.moveTo(width * 0.5, height); ctx.lineTo(width, height); ctx.lineTo(width, height * 0.5); ctx.stroke()
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  MAIN LAYOUT
    // ══════════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: _fw * 2.5
        spacing:         _fh * 1.0

        // ── HEADER ────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth:      true
            Layout.preferredHeight: root.height * 0.24

            Column {
                anchors.centerIn: parent
                spacing:          _fh * 0.50

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: _fw * 1.8

                    Image {
                        source: "/res/HilmLogo.svg"
                        height: _fh * 4.2; width: height
                        fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: _fh * 0.08

                        Text {
                            text: "HILM"; color: _teal; font.bold: true
                            font.letterSpacing: 10; font.pixelSize: _fh * 3.0
                        }
                        Text {
                            text: "DRONE CONTROL SYSTEM"; color: _tealMid
                            font.letterSpacing: 4.5; font.pixelSize: _fh * 0.70
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: _fw * 48; height: 1
                    color: Qt.rgba(0, 0.784, 0.784, 0.30)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: _fw * 2.0

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: QGroundControl.qgcVersion; color: Qt.rgba(1,1,1,0.28)
                        font.pixelSize: _fh * 0.62
                    }

                    Text { text: "·"; color: _tealBorder; font.pixelSize: _fh * 0.9; anchors.verticalCenter: parent.verticalCenter }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        property int vc: QGroundControl.multiVehicleManager.vehicles.count
                        width:  chipText.implicitWidth + _fw * 2.4
                        height: chipText.implicitHeight + _fh * 0.32
                        radius: height / 2
                        color:  vc > 0 ? Qt.rgba(0, 0.784, 0.784, 0.14) : Qt.rgba(1,1,1,0.05)
                        border.color: vc > 0 ? _tealBorder : Qt.rgba(1,1,1,0.12)
                        border.width: 1

                        Rectangle {
                            id: pulseDot; x: _fw * 0.9; width: 5; height: 5; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: parent.vc > 0 ? _teal : Qt.rgba(1,1,1,0.25)
                            SequentialAnimation on opacity {
                                running: parent.parent.vc > 0; loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 800 }
                                NumberAnimation { to: 1.00; duration: 800 }
                            }
                        }

                        Text {
                            id: chipText
                            x: pulseDot.x + pulseDot.width + _fw * 0.65
                            anchors.verticalCenter: parent.verticalCenter
                            property int vc: QGroundControl.multiVehicleManager.vehicles.count
                            text:  vc > 0 ? (vc + (vc === 1 ? " VEHICLE ONLINE" : " VEHICLES ONLINE")) : "NO VEHICLES CONNECTED"
                            color: vc > 0 ? _teal : Qt.rgba(1,1,1,0.28)
                            font.bold: vc > 0; font.letterSpacing: 1.2; font.pixelSize: _fh * 0.62
                        }
                    }
                }
            }
        }

        // ── NAVIGATION CARDS ──────────────────────────────────────────────
        Row {
            id:               cardsRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing:          _fw * 1.4

            Repeater {
                model: root.cardModel           // reference root directly — no parent.parent

                Item {
                    id:     cardItem
                    width:  (cardsRow.width - (4 * cardsRow.spacing)) / 5
                    height: cardsRow.height

                    // Staggered slide-up entrance
                    property int _idx: index
                    opacity: 0; y: _fh * 3

                    Component.onCompleted: slideIn.start()

                    SequentialAnimation {
                        id: slideIn
                        PauseAnimation { duration: cardItem._idx * 75 }
                        ParallelAnimation {
                            NumberAnimation { target: cardItem; property: "opacity"; to: 1.0; duration: 350; easing.type: Easing.OutCubic }
                            NumberAnimation { target: cardItem; property: "y";       to: 0;   duration: 350; easing.type: Easing.OutCubic }
                        }
                    }

                    // ── Card ───────────────────────────────────────────────
                    Rectangle {
                        id:           card
                        anchors.fill: parent
                        radius:       8
                        color:        hover.containsMouse ? _tealHover : _cardBg
                        border.color: hover.containsMouse ? _teal : _tealBorder
                        border.width: hover.containsMouse ? 2.0 : 1.0

                        scale: hover.pressed ? 0.96 : (hover.containsMouse ? 1.025 : 1.0)

                        Behavior on scale        { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                        Behavior on color        { ColorAnimation  { duration: 150 } }
                        Behavior on border.color { ColorAnimation  { duration: 150 } }
                        Behavior on border.width { NumberAnimation { duration: 150 } }

                        // Top accent bar (slides in on hover)
                        Rectangle {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            height: 3; radius: 3; color: _teal
                            opacity: hover.containsMouse ? 1.0 : 0
                            Behavior on opacity { NumberAnimation { duration: 160 } }
                        }

                        // Shortcut key badge
                        Rectangle {
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.margins: _fw * 0.6
                            width: kText.implicitWidth + _fw; height: kText.implicitHeight + _fh * 0.22
                            radius: 3
                            color: Qt.rgba(0, 0.784, 0.784, hover.containsMouse ? 0.22 : 0.10)
                            border.color: Qt.rgba(0, 0.784, 0.784, 0.38); border.width: 1
                            Text { id: kText; anchors.centerIn: parent; text: modelData.shortcut; color: _tealMid; font.bold: true; font.pixelSize: _fh * 0.60 }
                        }

                        // ── Content column ─────────────────────────────────
                        Column {
                            anchors.centerIn: parent
                            spacing:          _fh * 0.75
                            width:            parent.width - _fw * 2

                            // Futuristic Canvas icon
                            Canvas {
                                id:               iconCanvas
                                anchors.horizontalCenter: parent.horizontalCenter
                                width:            _fh * 4.6
                                height:           _fh * 4.6
                                property string iconType: modelData.icon
                                property bool   hovered:  hover.containsMouse

                                Component.onCompleted: requestPaint()
                                onIconTypeChanged: requestPaint()
                                onHoveredChanged:  requestPaint()
                                onWidthChanged:    requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cx = width / 2, cy = height / 2
                                    var R  = Math.min(width, height) * 0.42
                                    ctx.strokeStyle = "#00C8C8"
                                    ctx.fillStyle   = "#00C8C8"
                                    ctx.lineCap     = "round"
                                    ctx.lineJoin    = "round"

                                    // ── Circle background ────────────────────
                                    ctx.globalAlpha = hovered ? 0.18 : 0.09
                                    ctx.beginPath(); ctx.arc(cx, cy, R * 1.18, 0, Math.PI * 2)
                                    ctx.fillStyle = "#00C8C8"; ctx.fill()
                                    ctx.globalAlpha = hovered ? 0.70 : 0.40
                                    ctx.lineWidth = width * 0.028
                                    ctx.beginPath(); ctx.arc(cx, cy, R * 1.18, 0, Math.PI * 2); ctx.stroke()
                                    ctx.globalAlpha = 1.0
                                    ctx.fillStyle = "#00C8C8"

                                    if (iconType === "fly") {
                                        // ── Drone top-view ─────────────────
                                        var ar = R * 0.68
                                        ctx.lineWidth = width * 0.055
                                        // Arms
                                        var arms = [[-1,-1],[1,-1],[-1,1],[1,1]]
                                        for (var a = 0; a < arms.length; a++) {
                                            ctx.beginPath()
                                            ctx.moveTo(cx, cy)
                                            ctx.lineTo(cx + arms[a][0] * ar, cy + arms[a][1] * ar)
                                            ctx.globalAlpha = (a < 2) ? 1.0 : 0.55
                                            ctx.stroke()
                                        }
                                        ctx.globalAlpha = 1.0
                                        // Propeller circles
                                        var pr = R * 0.27
                                        var pd = R * 0.67
                                        ctx.lineWidth = width * 0.038
                                        for (var p = 0; p < 4; p++) {
                                            var px = cx + arms[p][0] * pd, py = cy + arms[p][1] * pd
                                            ctx.globalAlpha = (p < 2) ? 0.95 : 0.50
                                            ctx.beginPath(); ctx.arc(px, py, pr, 0, Math.PI * 2); ctx.stroke()
                                            // Cross blades
                                            ctx.lineWidth = width * 0.025
                                            ctx.beginPath()
                                            ctx.moveTo(px - pr * 0.65, py); ctx.lineTo(px + pr * 0.65, py); ctx.stroke()
                                            ctx.beginPath()
                                            ctx.moveTo(px, py - pr * 0.65); ctx.lineTo(px, py + pr * 0.65); ctx.stroke()
                                            ctx.lineWidth = width * 0.038
                                        }
                                        ctx.globalAlpha = 1.0
                                        // Central body
                                        ctx.beginPath(); ctx.arc(cx, cy, R * 0.13, 0, Math.PI * 2); ctx.fill()
                                        // Front indicator dot
                                        ctx.globalAlpha = 0.75
                                        ctx.beginPath(); ctx.arc(cx, cy - R * 0.42, R * 0.075, 0, Math.PI * 2); ctx.fill()
                                        ctx.globalAlpha = 1.0

                                    } else if (iconType === "plan") {
                                        // ── Mission waypoints + path ────────
                                        var wpts = [
                                            [cx - R * 0.68, cy + R * 0.58],
                                            [cx + R * 0.05, cy - R * 0.18],
                                            [cx + R * 0.65, cy - R * 0.62]
                                        ]
                                        // Dashed path line
                                        ctx.lineWidth = width * 0.038
                                        ctx.globalAlpha = 0.75
                                        ctx.setLineDash([5, 4])
                                        ctx.beginPath()
                                        ctx.moveTo(wpts[0][0], wpts[0][1])
                                        for (var wp = 1; wp < wpts.length; wp++)
                                            ctx.lineTo(wpts[wp][0], wpts[wp][1])
                                        ctx.stroke()
                                        ctx.setLineDash([])
                                        ctx.globalAlpha = 1.0
                                        // Waypoint pins
                                        var wpColors = ["#00C8C8", "#00C8C8", "#FF9800"]
                                        var wpSizes  = [R*0.16, R*0.12, R*0.16]
                                        for (var wi = 0; wi < wpts.length; wi++) {
                                            ctx.fillStyle = wpColors[wi]
                                            ctx.beginPath(); ctx.arc(wpts[wi][0], wpts[wi][1], wpSizes[wi], 0, Math.PI * 2); ctx.fill()
                                            // Ring around start & end
                                            if (wi !== 1) {
                                                ctx.lineWidth = width * 0.028
                                                ctx.strokeStyle = wpColors[wi]
                                                ctx.globalAlpha = 0.45
                                                ctx.beginPath(); ctx.arc(wpts[wi][0], wpts[wi][1], wpSizes[wi] * 1.9, 0, Math.PI * 2); ctx.stroke()
                                                ctx.globalAlpha = 1.0
                                            }
                                        }
                                        ctx.fillStyle = "#00C8C8"; ctx.strokeStyle = "#00C8C8"

                                    } else if (iconType === "config") {
                                        // ── Gear / cog ────────────────────
                                        var teeth  = 8
                                        var outerR = R * 0.90
                                        var innerR = R * 0.63
                                        var tW     = (Math.PI * 2 / teeth) * 0.42
                                        ctx.lineWidth = width * 0.035
                                        ctx.beginPath()
                                        for (var t = 0; t < teeth; t++) {
                                            var a1 = (t / teeth) * Math.PI * 2 - Math.PI / 2
                                            var a2 = a1 + tW
                                            var a3 = a1 + (Math.PI * 2 / teeth) - tW
                                            var a4 = a1 + (Math.PI * 2 / teeth)
                                            if (t === 0) ctx.moveTo(cx + innerR * Math.cos(a1), cy + innerR * Math.sin(a1))
                                            ctx.lineTo(cx + innerR * Math.cos(a1), cy + innerR * Math.sin(a1))
                                            ctx.lineTo(cx + outerR * Math.cos(a2), cy + outerR * Math.sin(a2))
                                            ctx.lineTo(cx + outerR * Math.cos(a3), cy + outerR * Math.sin(a3))
                                            ctx.lineTo(cx + innerR * Math.cos(a4), cy + innerR * Math.sin(a4))
                                        }
                                        ctx.closePath()
                                        ctx.stroke()
                                        // Inner ring
                                        ctx.beginPath(); ctx.arc(cx, cy, R * 0.30, 0, Math.PI * 2); ctx.stroke()
                                        // Center dot
                                        ctx.beginPath(); ctx.arc(cx, cy, R * 0.10, 0, Math.PI * 2); ctx.fill()

                                    } else if (iconType === "settings") {
                                        // ── Three slider tracks ────────────
                                        var tLen = R * 1.50
                                        var tX0  = cx - tLen / 2
                                        var tYs  = [cy - R * 0.58, cy, cy + R * 0.58]
                                        var tPos = [0.30, 0.65, 0.45]   // thumb positions
                                        for (var s = 0; s < 3; s++) {
                                            var sY  = tYs[s]
                                            var sXT = tX0 + tPos[s] * tLen
                                            // Full dim track
                                            ctx.lineWidth = width * 0.030
                                            ctx.globalAlpha = 0.22
                                            ctx.beginPath(); ctx.moveTo(tX0, sY); ctx.lineTo(tX0 + tLen, sY); ctx.stroke()
                                            // Active portion
                                            ctx.globalAlpha = 1.0
                                            ctx.lineWidth = width * 0.038
                                            ctx.beginPath(); ctx.moveTo(tX0, sY); ctx.lineTo(sXT, sY); ctx.stroke()
                                            // Thumb
                                            ctx.globalAlpha = 0.85
                                            ctx.lineWidth = width * 0.048
                                            ctx.beginPath(); ctx.arc(sXT, sY, R * 0.115, 0, Math.PI * 2)
                                            var oldFill = ctx.fillStyle
                                            ctx.fillStyle = "#0A1010"; ctx.fill()
                                            ctx.fillStyle = "#00C8C8"
                                            ctx.lineWidth = width * 0.038; ctx.stroke()
                                            ctx.globalAlpha = 1.0
                                        }

                                    } else if (iconType === "analyze") {
                                        // ── ECG / telemetry waveform ───────
                                        var wX0 = cx - R * 0.92
                                        var wX1 = cx + R * 0.92
                                        var wW  = wX1 - wX0
                                        var amp = R * 0.46
                                        ctx.lineWidth = width * 0.042
                                        // Dim baseline
                                        ctx.globalAlpha = 0.18
                                        ctx.lineWidth = width * 0.022
                                        ctx.beginPath(); ctx.moveTo(wX0, cy); ctx.lineTo(wX1, cy); ctx.stroke()
                                        // Vertical grid lines
                                        for (var g = 1; g < 5; g++) {
                                            var gX = wX0 + g * wW / 5
                                            ctx.beginPath(); ctx.moveTo(gX, cy - amp * 1.15); ctx.lineTo(gX, cy + amp * 0.7); ctx.stroke()
                                        }
                                        ctx.globalAlpha = 1.0
                                        ctx.lineWidth = width * 0.042
                                        // ECG waveform
                                        ctx.beginPath()
                                        ctx.moveTo(wX0, cy)
                                        ctx.lineTo(wX0 + wW * 0.18, cy)
                                        ctx.lineTo(wX0 + wW * 0.27, cy - amp * 0.28)
                                        ctx.lineTo(wX0 + wW * 0.33, cy - amp * 1.00)
                                        ctx.lineTo(wX0 + wW * 0.39, cy + amp * 0.55)
                                        ctx.lineTo(wX0 + wW * 0.45, cy)
                                        ctx.lineTo(wX0 + wW * 0.52, cy)
                                        ctx.lineTo(wX0 + wW * 0.58, cy - amp * 0.55)
                                        ctx.lineTo(wX0 + wW * 0.65, cy)
                                        ctx.lineTo(wX0 + wW * 0.72, cy + amp * 0.25)
                                        ctx.lineTo(wX0 + wW * 0.78, cy - amp * 0.38)
                                        ctx.lineTo(wX0 + wW * 0.85, cy)
                                        ctx.lineTo(wX1, cy)
                                        ctx.stroke()
                                        // Highlight dot at peak
                                        ctx.globalAlpha = 0.90
                                        ctx.beginPath(); ctx.arc(wX0 + wW * 0.33, cy - amp, R * 0.09, 0, Math.PI * 2); ctx.fill()
                                        ctx.globalAlpha = 1.0
                                    }
                                }
                            }

                            // Title + tag
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: _fh * 0.12

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.title; color: _teal; font.bold: true
                                    font.letterSpacing: 3.5; font.pixelSize: _fh * 1.0
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.tag; color: _tealMid
                                    font.letterSpacing: 2.0; font.pixelSize: _fh * 0.65
                                }
                            }

                            // Divider
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * 0.55; height: 1
                                color: hover.containsMouse ? Qt.rgba(0, 0.784, 0.784, 0.55) : Qt.rgba(0, 0.784, 0.784, 0.28)
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            // Description
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.desc
                                color: hover.containsMouse ? Qt.rgba(1,1,1,0.75) : Qt.rgba(1,1,1,0.38)
                                font.pixelSize: _fh * 0.70
                                horizontalAlignment: Text.AlignHCenter
                                lineHeight: 1.45
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            // "OPEN →"
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "OPEN  \u2192"; color: _teal; font.bold: true
                                font.letterSpacing: 2; font.pixelSize: _fh * 0.65
                                opacity: hover.containsMouse ? 0.88 : 0
                                Behavior on opacity { NumberAnimation { duration: 170 } }
                            }
                        }

                        MouseArea {
                            id:           hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                switch (modelData.id) {
                                case "fly":      mainWindow.showFlyView();                                 break
                                case "plan":     mainWindow.showPlanView();                                break
                                case "config":   mainWindow.showFlyView(); mainWindow.showVehicleConfig(); break
                                case "settings": mainWindow.showFlyView(); mainWindow.showSettingsTool();  break
                                case "analyze":  mainWindow.showFlyView(); mainWindow.showAnalyzeTool();   break
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── FOOTER ────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth:      true
            Layout.preferredHeight: _fh * 2.0

            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                height: 1; color: Qt.rgba(0, 0.784, 0.784, 0.15)
            }

            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                spacing: _fw * 1.5

                Text { text: "\u00A9 HILM SYSTEMS"; color: Qt.rgba(1,1,1,0.15); font.letterSpacing: 2; font.pixelSize: _fh * 0.58 }

                Repeater {
                    model: QGroundControl.multiVehicleManager.vehicles
                    Row {
                        anchors.verticalCenter: parent.verticalCenter; spacing: _fw * 0.7
                        Rectangle { width: 6; height: 6; radius: 3; anchors.verticalCenter: parent.verticalCenter; color: object.armed ? "#FF9800" : _teal }
                        Text { text: "V" + object.id + " \u00B7 " + (object.armed ? "ARMED" : "READY"); color: Qt.rgba(1,1,1,0.30); font.pixelSize: _fh * 0.58 }
                    }
                }
            }

            Text {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: "Click a panel to launch  \u00B7  Press Esc to return here from any view"
                color: Qt.rgba(1,1,1,0.15); font.pixelSize: _fh * 0.58; font.italic: true
            }
        }
    }

    // ── Bottom accent line ─────────────────────────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 3
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.25; color: "#00C8C8"    }
            GradientStop { position: 0.75; color: "#00C8C8"    }
            GradientStop { position: 1.00; color: "transparent" }
        }
    }
}
