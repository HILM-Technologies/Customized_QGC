import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// ─────────────────────────────────────────────────────────────────────────────
//  PatrolEditor  –  Industry-grade autonomous patrol configuration panel
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root
    width:  parent.width
    height: mainCol.height

    // ── Public property ───────────────────────────────────────────────────────
    property var  patrolController
    property bool _inputsValid:    true

    // ── Feedback state ────────────────────────────────────────────────────────
    property bool _justSaved:      false   // true for 2 s after successful save
    property bool _resetPending:   false   // true while inline reset-confirm is showing

    // Auto-clear the "Saved" flash after 2 seconds
    Timer {
        id:       savedTimer
        interval: 2000
        onTriggered: root._justSaved = false
    }

    // Listen for save completion signal (only fires from saveToINI, not loadFromINI)
    Connections {
        target: patrolController
        function onPatrolConfigChanged(uid) {
            root._justSaved = true
            savedTimer.restart()
            root._resetPending = false   // dismiss any pending reset confirmation
        }
    }

    // ── Design tokens (HILM palette) ─────────────────────────────────────────
    readonly property color _teal:        "#00C8C8"
    readonly property color _tealHover:   "#00DEDE"
    readonly property color _tealDim:     Qt.rgba(0, 0.784, 0.784, 0.14)
    readonly property color _tealBorder:  Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property color _cardBg:      Qt.rgba(1, 1, 1, 0.04)
    readonly property color _divider:     Qt.rgba(1, 1, 1, 0.07)
    readonly property color _dimText:     Qt.rgba(1, 1, 1, 0.50)
    readonly property color _warnColor:   "#FF9800"
    readonly property color _errColor:    "#FF5252"
    readonly property color _okColor:     "#4CAF50"
    readonly property real  _r:           ScreenTools.defaultFontPixelWidth * 0.7
    readonly property real  _pad:         ScreenTools.defaultFontPixelWidth
    readonly property real  _gap:         ScreenTools.defaultFontPixelHeight * 0.5

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // ── Helper functions ──────────────────────────────────────────────────────
    function _loopModeStr() {
        if (!patrolController) return "—"
        var m = patrolController.loopsMode
        if (m === 0) return qsTr("Loop Forever")
        if (m === 1) return qsTr("%1 Loops").arg(patrolController.loops)
        return qsTr("%1 min Duration").arg(patrolController.duration)
    }

    function _schedStr() {
        if (!patrolController) return qsTr("Not scheduled")
        var t = patrolController.startTime
        if (!t || t.trim().length === 0) return qsTr("Not scheduled")
        var d = patrolController.startDate
        var ds = (d && d instanceof Date && !isNaN(d.getTime()))
                 ? Qt.formatDate(d, "dd MMM yyyy") : "—"
        return t + "  ·  " + ds
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  MAIN COLUMN
    // ═════════════════════════════════════════════════════════════════════════
    Column {
        id: mainCol
        width: parent.width
        spacing: _gap

        // ╔══════════════════════════════════════════════════════════════════╗
        //  HEADER CARD  – title + enable toggle
        // ╚══════════════════════════════════════════════════════════════════╝
        Rectangle {
            id: headerCard
            width:  parent.width
            height: ScreenTools.defaultFontPixelHeight * 4.2
            radius: _r
            color:  _tealDim
            border.color: _tealBorder
            border.width: 1

            // Enable toggle — anchored to right, fixed size, never overlaps title
            QGCCheckBoxSlider {
                id:                     enableToggle
                text:                   ""
                anchors.right:          parent.right
                anchors.rightMargin:    _pad
                anchors.verticalCenter: parent.verticalCenter
                checked:                patrolController ? patrolController.enabled : false
                onClicked:              if (patrolController) patrolController.enabled = checked
            }

            // Accent bar
            Rectangle {
                id:                     accentBar
                width:                  3
                height:                 parent.height * 0.55
                radius:                 2
                color:                  _teal
                anchors.left:           parent.left
                anchors.leftMargin:     _pad
                anchors.verticalCenter: parent.verticalCenter
            }

            // Title block — left of accent bar, right stops before toggle
            Column {
                anchors.left:           accentBar.right
                anchors.leftMargin:     _pad * 0.75
                anchors.right:          enableToggle.left
                anchors.rightMargin:    _pad * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing:                3

                Text {
                    width:              parent.width
                    text:               qsTr("AUTONOMOUS PATROL")
                    color:              _teal
                    font.bold:          true
                    font.letterSpacing: 2.0
                    font.pointSize:     ScreenTools.defaultFontPointSize * 0.85
                    elide:              Text.ElideRight
                }
                Text {
                    width:          parent.width
                    text:           qsTr("Schedule and configure automated flight operations")
                    color:          _dimText
                    font.pointSize: ScreenTools.smallFontPointSize
                    wrapMode:       Text.NoWrap
                    elide:          Text.ElideRight
                }
            }
        }

        // ╔══════════════════════════════════════════════════════════════════╗
        //  STATUS CARD  – live summary (always visible)
        // ╚══════════════════════════════════════════════════════════════════╝
        Rectangle {
            width: parent.width
            height: statusCol.height + _pad * 1.5
            radius: _r
            color: _cardBg
            border.color: _tealBorder
            border.width: 1

            Column {
                id: statusCol
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    margins: _pad
                }
                spacing: _pad * 0.7

                // Section header row
                RowLayout {
                    width: parent.width
                    spacing: _pad * 0.5

                    Rectangle { width: 3; height: 13; radius: 1.5; color: _teal }

                    Text {
                        text: qsTr("STATUS")
                        color: _teal
                        font.bold: true
                        font.letterSpacing: 1.8
                        font.pointSize: ScreenTools.smallFontPointSize
                        Layout.fillWidth: true
                    }

                    // Enabled / Disabled badge
                    Rectangle {
                        width: badgeText.implicitWidth + _pad * 1.2
                        height: badgeText.implicitHeight + 5
                        radius: height / 2
                        color:  (patrolController && patrolController.enabled) ? Qt.rgba(0.30, 0.69, 0.31, 0.18) : Qt.rgba(1,1,1,0.06)
                        border.color: (patrolController && patrolController.enabled) ? _okColor : Qt.rgba(1,1,1,0.18)
                        border.width: 1

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text:  (patrolController && patrolController.enabled) ? qsTr("ENABLED") : qsTr("DISABLED")
                            color: (patrolController && patrolController.enabled) ? _okColor : _dimText
                            font.bold: true
                            font.letterSpacing: 1.2
                            font.pointSize: ScreenTools.smallFontPointSize * 0.85
                        }
                    }
                }

                // Status 2×2 grid
                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: _pad * 2
                    rowSpacing: _pad * 0.45

                    Text { text: qsTr("Drone");    color: _dimText; font.pointSize: ScreenTools.smallFontPointSize }
                    Text {
                        text: (patrolController && patrolController.droneUID !== "")
                              ? patrolController.droneUID : qsTr("Not selected")
                        color: qgcPal.text
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text { text: qsTr("Speed");    color: _dimText; font.pointSize: ScreenTools.smallFontPointSize }
                    Text {
                        text: patrolController ? patrolController.speed.toFixed(1) + " m/s" : "—"
                        color: qgcPal.text; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize
                    }

                    Text { text: qsTr("Mode");     color: _dimText; font.pointSize: ScreenTools.smallFontPointSize }
                    Text {
                        text: _loopModeStr()
                        color: qgcPal.text; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize
                    }

                    Text { text: qsTr("Schedule"); color: _dimText; font.pointSize: ScreenTools.smallFontPointSize }
                    Text {
                        text: _schedStr()
                        color: qgcPal.text; font.bold: true; font.pointSize: ScreenTools.smallFontPointSize
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                }
            }
        }

        // ╔══════════════════════════════════════════════════════════════════╗
        //  CONFIGURABLE CONTENT  – visible only when patrol is enabled
        // ╚══════════════════════════════════════════════════════════════════╝
        Column {
            width: parent.width
            spacing: _gap
            visible: patrolController && patrolController.enabled

            // ── DRONE SELECTION ──────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: droneCol.height + _pad * 1.5
                radius: _r
                color: _cardBg
                border.color: _tealBorder
                border.width: 1

                Column {
                    id: droneCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad }
                    spacing: _pad * 0.75

                    // Section header
                    Row {
                        spacing: _pad * 0.5
                        Rectangle { width: 3; height: 13; radius: 1.5; color: _teal; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: qsTr("DRONE SELECTION")
                            color: _teal; font.bold: true; font.letterSpacing: 1.8
                            font.pointSize: ScreenTools.smallFontPointSize
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Drone display + button row
                    RowLayout {
                        width: parent.width
                        spacing: _pad * 0.75

                        Rectangle {
                            Layout.fillWidth: true
                            height: droneIdText.implicitHeight + _pad
                            radius: _r * 0.75
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1

                            RowLayout {
                                anchors { fill: parent; leftMargin: _pad * 0.75; rightMargin: _pad * 0.75 }
                                spacing: _pad * 0.5

                                // Status dot
                                Rectangle {
                                    width: 7; height: 7; radius: 3.5
                                    color: (patrolController && patrolController.droneUID !== "") ? _okColor : _dimText
                                }

                                Text {
                                    id: droneIdText
                                    Layout.fillWidth: true
                                    text: (patrolController && patrolController.droneUID !== "")
                                          ? patrolController.droneUID : qsTr("No drone selected")
                                    color: (patrolController && patrolController.droneUID !== "")
                                           ? qgcPal.text : _dimText
                                    font.pointSize: ScreenTools.defaultFontPointSize
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        QGCButton {
                            text: qsTr("Select")
                            enabled: patrolController && patrolController.availableDrones.length > 0
                            onClicked: selectDroneDialog.open()
                        }
                    }

                    // No vehicles hint
                    Rectangle {
                        width: parent.width
                        height: visible ? noVehicleText.implicitHeight + _pad * 0.8 : 0
                        visible: !patrolController || patrolController.availableDrones.length === 0
                        radius: _r * 0.6
                        color: Qt.rgba(1, 0.596, 0, 0.10)
                        border.color: Qt.rgba(1, 0.596, 0, 0.30)
                        border.width: 1

                        Text {
                            id: noVehicleText
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: _pad * 0.75 }
                            text: qsTr("No vehicles connected — connect a drone to continue")
                            color: _warnColor
                            font.pointSize: ScreenTools.smallFontPointSize
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            // ── FLIGHT PARAMETERS ────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: flightCol.height + _pad * 1.5
                radius: _r
                color: _cardBg
                border.color: _tealBorder
                border.width: 1

                Column {
                    id: flightCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad }
                    spacing: _pad * 0.8

                    // Section header
                    Row {
                        spacing: _pad * 0.5
                        Rectangle { width: 3; height: 13; radius: 1.5; color: _teal; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: qsTr("FLIGHT PARAMETERS")
                            color: _teal; font.bold: true; font.letterSpacing: 1.8
                            font.pointSize: ScreenTools.smallFontPointSize
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Speed
                    Column {
                        width: parent.width
                        spacing: _pad * 0.35

                        RowLayout {
                            width: parent.width
                            Text {
                                text: qsTr("Patrol Speed")
                                color: _dimText
                                font.pointSize: ScreenTools.smallFontPointSize
                                Layout.fillWidth: true
                            }
                            Text {
                                text: speedSlider.value.toFixed(1) + " m/s"
                                color: _teal
                                font.bold: true
                                font.pointSize: ScreenTools.smallFontPointSize
                            }
                        }

                        QGCSlider {
                            id: speedSlider
                            width: parent.width
                            from: 1; to: 15
                            value: patrolController ? patrolController.speed : 5
                            onPressedChanged: {
                                if (!pressed && patrolController) patrolController.speed = value
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: _divider }

                    // Loop mode — label stacked above combo so combo gets full width
                    Column {
                        width: parent.width
                        spacing: _pad * 0.35

                        Text {
                            text:           qsTr("Loop Mode")
                            color:          _dimText
                            font.pointSize: ScreenTools.smallFontPointSize
                        }

                        QGCComboBox {
                            id:           loopModeCombo
                            width:        parent.width
                            model: [
                                qsTr("Loop Forever"),
                                qsTr("Loop N Times"),
                                qsTr("Run for Duration")
                            ]
                            currentIndex: patrolController ? patrolController.loopsMode : 0
                            onActivated:  function(index) {
                                if (patrolController) patrolController.loopsMode = index
                            }
                        }
                    }

                    // Loop count (N times only)
                    RowLayout {
                        width: parent.width
                        spacing: _pad
                        visible: loopModeCombo.currentIndex === 1

                        Text {
                            text:                 qsTr("Loop Count")
                            color:                _dimText
                            font.pointSize:       ScreenTools.smallFontPointSize
                            Layout.minimumWidth:  ScreenTools.defaultFontPixelWidth * 9
                        }

                        QGCTextField {
                            Layout.fillWidth: true
                            text: patrolController && patrolController.loops > 0
                                  ? patrolController.loops.toString() : "3"
                            validator: IntValidator { bottom: 1; top: 999 }
                            onEditingFinished: if (patrolController) patrolController.loops = parseInt(text)
                        }
                    }

                    // Duration (duration mode only)
                    RowLayout {
                        width: parent.width
                        spacing: _pad
                        visible: loopModeCombo.currentIndex === 2

                        Text {
                            text:                qsTr("Duration (min)")
                            color:               _dimText
                            font.pointSize:      ScreenTools.smallFontPointSize
                            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 9
                        }

                        QGCTextField {
                            Layout.fillWidth: true
                            text: patrolController && patrolController.duration > 0
                                  ? patrolController.duration.toString() : "20"
                            validator: IntValidator { bottom: 1; top: 300 }
                            onEditingFinished: if (patrolController) patrolController.duration = parseInt(text)
                        }
                    }
                }
            }

            // ── SCHEDULE ─────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: schedCol.height + _pad * 1.5
                radius: _r
                color: _cardBg
                border.color: _tealBorder
                border.width: 1

                Column {
                    id: schedCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad }
                    spacing: _pad * 0.8

                    // Section header
                    Row {
                        spacing: _pad * 0.5
                        Rectangle { width: 3; height: 13; radius: 1.5; color: _teal; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: qsTr("SCHEDULE")
                            color: _teal; font.bold: true; font.letterSpacing: 1.8
                            font.pointSize: ScreenTools.smallFontPointSize
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Time + Date in two columns
                    RowLayout {
                        width: parent.width
                        spacing: _pad

                        // Start Time
                        Column {
                            Layout.fillWidth: true
                            spacing: _pad * 0.4

                            Text {
                                text: qsTr("Start Time (HH:MM)")
                                color: _dimText
                                font.pointSize: ScreenTools.smallFontPointSize
                            }

                            QGCTextField {
                                id: startTimeField
                                width: parent.width
                                placeholderText: "HH:MM"
                                text: patrolController ? patrolController.startTime : ""

                                onEditingFinished: {
                                    if (!patrolController) return
                                    if (!text || text.trim().length === 0) {
                                        startTimeError.visible = true; _inputsValid = false; return
                                    }
                                    var re = /^([01]\d|2[0-3]):([0-5]\d)$/
                                    if (!re.test(text)) {
                                        startTimeError.visible = true; _inputsValid = false; return
                                    }
                                    startTimeError.visible = false
                                    _inputsValid = true
                                    patrolController.startTime = text
                                }
                            }
                        }

                        // Start Date
                        Column {
                            Layout.fillWidth: true
                            spacing: _pad * 0.4

                            Text {
                                text: qsTr("Start Date (YYYY-MM-DD)")
                                color: _dimText
                                font.pointSize: ScreenTools.smallFontPointSize
                            }

                            QGCTextField {
                                id: startDateField
                                width: parent.width
                                placeholderText: "YYYY-MM-DD"
                                text: patrolController &&
                                      patrolController.startDate &&
                                      patrolController.startDate instanceof Date &&
                                      !isNaN(patrolController.startDate.getTime())
                                      ? Qt.formatDate(patrolController.startDate, "yyyy-MM-dd") : ""

                                onEditingFinished: {
                                    if (!patrolController) return
                                    if (!text || text.trim().length === 0) {
                                        startDateError.visible = true; _inputsValid = false; return
                                    }
                                    if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) {
                                        startDateError.visible = true; _inputsValid = false; return
                                    }
                                    var p = text.split("-")
                                    var y = Number(p[0]), m = Number(p[1]) - 1, d = Number(p[2])
                                    var dt = new Date(y, m, d)
                                    if (isNaN(dt.getTime()) || dt.getFullYear() !== y ||
                                        dt.getMonth() !== m || dt.getDate() !== d) {
                                        startDateError.visible = true; _inputsValid = false; return
                                    }
                                    startDateError.visible = false
                                    _inputsValid = true
                                    patrolController.startDate = dt
                                }
                            }
                        }
                    }

                    // Validation errors
                    Text {
                        id: startTimeError
                        visible: false
                        width: parent.width
                        text: qsTr("Invalid time — use HH:MM (24-hour format)")
                        color: _errColor
                        font.pointSize: ScreenTools.smallFontPointSize
                    }

                    Text {
                        id: startDateError
                        visible: false
                        width: parent.width
                        text: qsTr("Invalid date — use YYYY-MM-DD")
                        color: _errColor
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }

            // ── ACTIONS ──────────────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: _pad * 0.6

                // Apply — styled as primary action button
                Rectangle {
                    id: applyBtn
                    width: parent.width
                    height: applyText.implicitHeight + _pad * 1.5
                    radius: _r

                    property bool _canApply: !root._justSaved &&
                                             patrolController &&
                                             patrolController.availableDrones.length > 0 &&
                                             _inputsValid

                    // Green flash when just saved, teal when ready, dimmed otherwise
                    color: root._justSaved
                           ? Qt.rgba(0.18, 0.65, 0.22, 0.92)
                           : (applyBtn._canApply
                              ? (applyMouse.pressed ? Qt.darker(_teal, 1.25) : _teal)
                              : Qt.rgba(0, 0.784, 0.784, 0.20))
                    opacity: (applyBtn._canApply || root._justSaved) ? 1.0 : 0.5

                    Behavior on color { ColorAnimation { duration: 180 } }

                    // Checkmark icon — visible only during saved flash
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.leftMargin:     _pad * 1.2
                        visible:                root._justSaved
                        text:                   "✓"
                        color:                  "white"
                        font.bold:              true
                        font.pointSize:         ScreenTools.defaultFontPointSize * 1.1
                    }

                    Text {
                        id: applyText
                        anchors.left:           parent.left
                        anchors.right:          parent.right
                        anchors.leftMargin:     _pad * 1.5
                        anchors.rightMargin:    _pad * 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment:    Text.AlignHCenter
                        elide:                  Text.ElideRight
                        text: root._justSaved
                              ? qsTr("SETTINGS SAVED")
                              : ((patrolController && patrolController.dirty)
                                 ? qsTr("APPLY PATROL SETTINGS  ●")
                                 : qsTr("APPLY PATROL SETTINGS"))
                        color: root._justSaved
                               ? "white"
                               : (applyBtn._canApply ? "#001a1a" : qgcPal.buttonText)
                        font.bold:        true
                        font.letterSpacing: root._justSaved ? 2.2 : 1.8
                        font.pointSize:   ScreenTools.defaultFontPointSize * 0.88

                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    MouseArea {
                        id: applyMouse
                        anchors.fill: parent
                        enabled: applyBtn._canApply
                        onClicked: if (patrolController) patrolController.saveToINI()
                    }
                }

                // Reset — ghost button (only active when there are unsaved changes)
                Rectangle {
                    width:   parent.width
                    height:  resetText.implicitHeight + _pad * 1.2
                    radius:  _r
                    visible: !root._resetPending
                    color:   resetMouse.containsMouse
                             ? Qt.rgba(1, 0.596, 0, 0.08)
                             : Qt.rgba(1,1,1,0.04)
                    border.color: resetMouse.containsMouse
                                  ? Qt.rgba(1, 0.596, 0, 0.35)
                                  : Qt.rgba(1,1,1,0.16)
                    border.width: 1
                    // Enabled only when there are unsaved changes to discard
                    opacity: (patrolController && patrolController.dirty) ? 1.0 : 0.35

                    Behavior on color        { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Text {
                        id: resetText
                        anchors.centerIn: parent
                        text:  qsTr("RESET TO SAVED")
                        color: resetMouse.containsMouse ? _warnColor : _dimText
                        font.letterSpacing: 1.5
                        font.pointSize:     ScreenTools.defaultFontPointSize * 0.85

                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id:           resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled:      patrolController && patrolController.dirty
                        onClicked:    root._resetPending = true   // show confirmation
                    }
                }

                // Inline confirmation — replaces Reset button while pending
                Rectangle {
                    width:   parent.width
                    height:  confirmCol.height + _pad * 1.4
                    radius:  _r
                    visible: root._resetPending
                    color:   Qt.rgba(1, 0.596, 0, 0.07)
                    border.color: Qt.rgba(1, 0.596, 0, 0.30)
                    border.width: 1

                    Column {
                        id:             confirmCol
                        anchors {
                            left: parent.left; right: parent.right
                            top: parent.top; margins: _pad * 0.85
                        }
                        spacing: _pad * 0.7

                        // Warning text
                        RowLayout {
                            width: parent.width
                            spacing: _pad * 0.5

                            Text {
                                text:           "⚠"
                                color:          _warnColor
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                            }
                            Text {
                                Layout.fillWidth: true
                                text:   qsTr("Discard all unsaved changes and restore last saved configuration?")
                                color:  _warnColor
                                font.pointSize: ScreenTools.smallFontPointSize
                                wrapMode: Text.WordWrap
                            }
                        }

                        // Cancel / Confirm buttons
                        RowLayout {
                            width:   parent.width
                            spacing: _pad * 0.6

                            // Cancel
                            Rectangle {
                                Layout.fillWidth: true
                                height:      ScreenTools.defaultFontPixelHeight * 2.0
                                radius:      _r
                                color:       cancelResetMouse.pressed
                                             ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05)
                                border.color: Qt.rgba(1,1,1,0.16)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text:       qsTr("KEEP CHANGES")
                                    color:      _dimText
                                    font.pointSize: ScreenTools.smallFontPointSize
                                    font.letterSpacing: 1.2
                                }
                                MouseArea {
                                    id:           cancelResetMouse
                                    anchors.fill: parent
                                    onClicked:    root._resetPending = false
                                }
                            }

                            // Confirm reset
                            Rectangle {
                                Layout.fillWidth: true
                                height:      ScreenTools.defaultFontPixelHeight * 2.0
                                radius:      _r
                                color:       confirmResetMouse.pressed
                                             ? Qt.darker(_warnColor, 1.3) : _warnColor
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    anchors.centerIn: parent
                                    text:       qsTr("DISCARD")
                                    color:      "#1a0d00"
                                    font.bold:  true
                                    font.pointSize: ScreenTools.smallFontPointSize
                                    font.letterSpacing: 1.5
                                }
                                MouseArea {
                                    id:           confirmResetMouse
                                    anchors.fill: parent
                                    onClicked: {
                                        root._resetPending = false
                                        if (patrolController) patrolController.reset()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } // end enabled Column
    } // end mainCol

    // ═════════════════════════════════════════════════════════════════════════
    //  DRONE SELECTION POPUP
    // ═════════════════════════════════════════════════════════════════════════
    Popup {
        id: selectDroneDialog
        modal: true
        focus: true
        width: root.width * 0.92
        height: 310
        x: (root.width  - width)  / 2
        y: (root.height - height) / 2
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: qgcPal.windowShade
            border.color: _tealBorder
            border.width: 1
            radius: _r
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: _pad
            spacing: _pad * 0.75

            // Dialog title
            RowLayout {
                Layout.fillWidth: true

                Rectangle { width: 3; height: 16; radius: 1.5; color: _teal }

                Text {
                    Layout.fillWidth: true
                    leftPadding: _pad * 0.5
                    text: qsTr("SELECT DRONE")
                    color: _teal
                    font.bold: true
                    font.letterSpacing: 2.0
                    font.pointSize: ScreenTools.defaultFontPointSize * 0.88
                }

                Text {
                    text: patrolController
                          ? qsTr("%1 available").arg(patrolController.availableDrones.length)
                          : ""
                    color: _dimText
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: _tealBorder }

            // Drone list
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Qt.rgba(0, 0, 0, 0.15)
                radius: _r * 0.6
                border.color: Qt.rgba(1,1,1,0.07)
                border.width: 1
                clip: true

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 3
                    contentWidth: availableWidth

                    ListView {
                        id: droneListView
                        width: parent.width
                        clip: true
                        currentIndex: -1
                        focus: true
                        model: patrolController ? patrolController.availableDrones : []

                        delegate: Rectangle {
                            width: droneListView.width
                            height: ScreenTools.defaultFontPixelHeight * 2.4
                            radius: _r * 0.6
                            color: ListView.isCurrentItem
                                   ? Qt.rgba(0, 0.784, 0.784, 0.18)
                                   : (itemMouse.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent")
                            border.color: ListView.isCurrentItem ? _teal : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 80 } }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: _pad; rightMargin: _pad
                                }
                                spacing: _pad * 0.75

                                // Selection indicator
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: ListView.isCurrentItem ? _teal : Qt.rgba(1,1,1,0.18)
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData
                                    color: ListView.isCurrentItem ? _teal : qgcPal.text
                                    font.bold: ListView.isCurrentItem
                                    font.pointSize: ScreenTools.defaultFontPointSize
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: ListView.isCurrentItem
                                    text: qsTr("Selected")
                                    color: _teal
                                    font.pointSize: ScreenTools.smallFontPointSize
                                    opacity: 0.75
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: droneListView.currentIndex = index
                                onDoubleClicked: {
                                    patrolController.droneUID = modelData
                                    var id = parseInt(modelData)
                                    if (!isNaN(id)) {
                                        QGroundControl.multiVehicleManager.deselectAllVehicles()
                                        QGroundControl.multiVehicleManager.selectVehicle(id)
                                    }
                                    selectDroneDialog.close()
                                }
                            }
                        }
                    }
                }
            }

            // Dialog buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: _pad * 0.75

                // Cancel
                Rectangle {
                    Layout.fillWidth: true
                    height: ScreenTools.defaultFontPixelHeight * 2.2
                    radius: _r
                    color: cancelMouse.pressed ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.05)
                    border.color: Qt.rgba(1,1,1,0.15)
                    border.width: 1

                    Text {
                        id: cancelTxt
                        anchors.centerIn: parent
                        text: qsTr("CANCEL")
                        color: _dimText
                        font.letterSpacing: 1.2
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                    }
                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        onClicked: selectDroneDialog.close()
                    }
                }

                // Confirm
                Rectangle {
                    Layout.fillWidth: true
                    height: ScreenTools.defaultFontPixelHeight * 2.2
                    radius: _r
                    property bool _ready: droneListView.currentIndex >= 0
                    color: _ready
                           ? (confirmMouse.pressed ? Qt.darker(_teal, 1.25) : _teal)
                           : Qt.rgba(0, 0.784, 0.784, 0.18)
                    opacity: _ready ? 1.0 : 0.5

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: confirmTxt
                        anchors.centerIn: parent
                        text: qsTr("CONFIRM")
                        color: parent._ready ? "#001a1a" : _dimText
                        font.bold: parent._ready
                        font.letterSpacing: 1.5
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                    }

                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        enabled: droneListView.currentIndex >= 0
                        onClicked: {
                            patrolController.droneUID =
                                patrolController.availableDrones[droneListView.currentIndex]
                            var id = parseInt(patrolController.droneUID)
                            if (!isNaN(id)) {
                                QGroundControl.multiVehicleManager.deselectAllVehicles()
                                QGroundControl.multiVehicleManager.selectVehicle(id)
                            }
                            selectDroneDialog.close()
                        }
                    }
                }
            }
        }
    }
}
