/****************************************************************************
 *
 * HILM Ground Control — Vehicle Setup & Calibration
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:    _root
    color: "#0D1117"

    // ── HILM design tokens ──────────────────────────────────
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property color _okColor:    "#4CAF50"
    readonly property color _warnColor:  "#FF9800"
    readonly property color _errColor:   "#FF5252"

    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth * 1.2
    readonly property real  _fontSize:   ScreenTools.defaultFontPixelHeight

    // ── Data sources ────────────────────────────────────────
    property var  _activeVehicle:  QGroundControl.multiVehicleManager.activeVehicle
    property bool _vehicleAvail:   QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable
    property var  _autopilot:      _activeVehicle ? _activeVehicle.autopilotPlugin : null
    property var  _components:     (_autopilot && _vehicleAvail) ? _autopilot.vehicleComponents : []

    // ── Tabs: 0=FLEET MANAGEMENT, 1=GENERAL, 2=RADIO, 3=SENSORS, 4=COMPANION COMPUTER
    property int _activeTab: 1

    // ── Which section is expanded (empty = none) ────────────
    property string _expandedSection: ""

    // ── Component helpers ───────────────────────────────────
    function _findComponent(name) {
        for (var i = 0; i < _components.length; i++) {
            if (_components[i].name.toLowerCase().indexOf(name.toLowerCase()) >= 0)
                return _components[i]
        }
        return null
    }

    property var _airframeComp:    _findComponent("Airframe")
    property var _sensorsComp:     _findComponent("Sensors")
    property var _radioComp:       _findComponent("Radio")
    property var _flightModesComp: _findComponent("Flight Modes")
    property var _powerComp:       _findComponent("Power")
    property var _safetyComp:      _findComponent("Safety")
    property var _tuningComp:      _findComponent("Tuning")
    property var _actuatorComp:    _findComponent("Actuator")

    function _refreshComponents() {
        _airframeComp    = _findComponent("Airframe")
        _sensorsComp     = _findComponent("Sensors")
        _radioComp       = _findComponent("Radio")
        _flightModesComp = _findComponent("Flight Modes")
        _powerComp       = _findComponent("Power")
        _safetyComp      = _findComponent("Safety")
        _tuningComp      = _findComponent("Tuning")
        _actuatorComp    = _findComponent("Actuator")
        _expandedSection = ""
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged()                    { _refreshComponents() }
        function onParameterReadyVehicleAvailableChanged()   { _refreshComponents() }
    }

    // ── Public API for MainWindow ───────────────────────────
    function showParametersPanel()  { _activeTab = 1; _expandedSection = "parameters" }
    function showVehicleComponentPanel(vehicleComponent) {
        var n = vehicleComponent.name.toLowerCase()
        if (n.indexOf("sensor") >= 0)       _activeTab = 3
        else if (n.indexOf("radio") >= 0)   _activeTab = 2
        else                                 _activeTab = 1
    }

    DeadMouseArea { anchors.fill: parent }

    // ════════════════════════════════════════════════════════
    // MAIN LAYOUT
    // ════════════════════════════════════════════════════════

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: _pad * 2
        spacing: _pad * 1.2

        // ── HEADER ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: _pad * 0.3

            QGCLabel {
                text:               "Vehicle Setup & Calibration"
                color:              "white"
                font.pixelSize:     _fontSize * 1.4
                font.bold:          true
                font.letterSpacing: 1
            }

            QGCLabel {
                text:           "Configure drone parameters and perform calibrations"
                color:          _dimText
                font.pixelSize: _fontSize * 0.75
            }
        }

        // ── TAB BAR ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad * 0.5

            Repeater {
                model: ["FLEET MANAGEMENT", "GENERAL", "RADIO", "SENSORS", "COMPANION COMPUTER"]

                Rectangle {
                    Layout.fillWidth: true
                    height: _fontSize * 2.8
                    radius: _fontSize * 0.4
                    color:  _activeTab === index ? _teal : "transparent"
                    border.color: _activeTab === index ? _teal : _tealBorder
                    border.width: 1

                    QGCLabel {
                        anchors.centerIn: parent
                        text:           modelData
                        color:          _activeTab === index ? "#000000" : _dimText
                        font.pixelSize: _fontSize * 0.7
                        font.bold:      _activeTab === index
                        font.letterSpacing: 0.8
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: { _activeTab = index; _expandedSection = "" }
                    }
                }
            }
        }

        // ── TAB CONTENT ─────────────────────────────────────
        Rectangle {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            color:  "transparent"
            clip:   true

            // ─── TAB 0: FLEET MANAGEMENT (placeholder) ─────
            Item {
                anchors.fill: parent
                visible: _activeTab === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: _fontSize

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignHCenter
                        width:  _fontSize * 4; height: width
                        source: "/qmlimages/Quad.svg"; color: _teal
                        fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "FLEET MANAGEMENT"; color: "white"
                        font.pixelSize: _fontSize * 1.2; font.bold: true; font.letterSpacing: 1.5
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Fleet management configuration coming soon"
                        color: _dimText; font.pixelSize: _fontSize * 0.8
                    }
                }
            }

            // ─── TAB 1: GENERAL ─────────────────────────────
            Item {
                anchors.fill: parent
                visible: _activeTab === 1

                // No vehicle
                ColumnLayout {
                    anchors.centerIn: parent; spacing: _fontSize
                    visible: !_vehicleAvail

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignHCenter
                        width: _fontSize * 4; height: width
                        source: "/qmlimages/Gears.svg"; color: _teal
                        fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Connect a vehicle to configure settings"
                        color: _dimText; font.pixelSize: _fontSize * 0.9
                    }
                }

                // Vehicle connected
                QGCFlickable {
                    anchors.fill: parent
                    contentHeight: _generalCol.height + _pad * 2
                    clip: true
                    visible: _vehicleAvail

                    ColumnLayout {
                        id: _generalCol
                        width: parent.width
                        spacing: _pad

                        // ── Vehicle Information card ─────────
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: _vInfoCol.implicitHeight + _pad * 3
                            radius: _fontSize * 0.4
                            color:  _cardBg
                            border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                            ColumnLayout {
                                id: _vInfoCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad * 1.5 }
                                spacing: _pad

                                QGCLabel {
                                    text: "Vehicle Information"; color: "white"
                                    font.pixelSize: _fontSize * 1.1; font.bold: true
                                }

                                // Vehicle Name
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: _pad * 0.4
                                    QGCLabel { text: "Vehicle Name"; color: "white"; font.pixelSize: _fontSize * 0.8; font.bold: true }
                                    Rectangle {
                                        Layout.fillWidth: true; height: _fontSize * 2.8; radius: _fontSize * 0.3
                                        color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                        QGCLabel {
                                            anchors { fill: parent; margins: _pad }
                                            verticalAlignment: Text.AlignVCenter
                                            text: _activeVehicle ? (_activeVehicle.defaultName || ("Vehicle " + _activeVehicle.id)) : "--"
                                            color: "white"; font.pixelSize: _fontSize * 0.85; elide: Text.ElideRight
                                        }
                                    }
                                }

                                // Vehicle Type — click expands Airframe inline
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: _pad * 0.4
                                    QGCLabel { text: "Vehicle Type"; color: "white"; font.pixelSize: _fontSize * 0.8; font.bold: true }
                                    Rectangle {
                                        Layout.fillWidth: true; height: _fontSize * 2.8; radius: _fontSize * 0.3
                                        color: Qt.rgba(1,1,1,0.06); border.color: _expandedSection === "airframe" ? _tealBorder : Qt.rgba(1,1,1,0.1); border.width: 1
                                        RowLayout {
                                            anchors { fill: parent; margins: _pad }
                                            QGCLabel {
                                                Layout.fillWidth: true
                                                text: _activeVehicle ? _activeVehicle.vehicleTypeString : "SELECT VEHICLE TYPE"
                                                color: _activeVehicle && _activeVehicle.vehicleTypeString ? "white" : _dimText
                                                font.pixelSize: _fontSize * 0.85
                                            }
                                            QGCColoredImage {
                                                width: _fontSize; height: width
                                                source: "/InstrumentValueIcons/arrow-simple-down.svg"
                                                color: _dimText; fillMode: Image.PreserveAspectFit
                                                rotation: _expandedSection === "airframe" ? 180 : 0
                                                Behavior on rotation { NumberAnimation { duration: 200 } }
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: _expandedSection = (_expandedSection === "airframe") ? "" : "airframe"
                                        }
                                    }
                                }
                            }
                        }

                        // ── Airframe expanded inline ────────
                        Rectangle {
                            Layout.fillWidth: true
                            visible: _expandedSection === "airframe" && _airframeComp
                            implicitHeight: visible ? _root.height * 0.55 : 0
                            Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                            radius: _fontSize * 0.4; color: _cardBg
                            border.color: _tealBorder; border.width: 1
                            clip: true

                            Loader {
                                anchors.fill: parent
                                source: (_expandedSection === "airframe" && _airframeComp) ? _airframeComp.setupSource : ""
                                property var vehicleComponent: _airframeComp
                            }
                        }

                        // ── Flight Modes card ───────────────
                        SetupCard {
                            sectionKey:  "flightmodes"
                            title:       "Flight Modes"
                            comp:        _flightModesComp
                            showSummary: true
                        }

                        // ── Power & Battery card ────────────
                        SetupCard {
                            sectionKey:  "power"
                            title:       "Power & Battery"
                            comp:        _powerComp
                            showSummary: true
                        }

                        // ── Safety & Failsafe card ──────────
                        SetupCard {
                            sectionKey:  "safety"
                            title:       "Safety & Failsafe"
                            comp:        _safetyComp
                            showSummary: true
                        }

                        // ── Tuning card ─────────────────────
                        SetupCard {
                            sectionKey: "tuning"
                            title:      "Tuning"
                            comp:       _tuningComp
                        }

                        // ── Actuators / Motors card ─────────
                        SetupCard {
                            sectionKey: "actuator"
                            title:      "Actuators / Motors"
                            comp:       _actuatorComp
                        }

                        // ── Joystick card ───────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            visible: _vehicleAvail && joystickManager.joysticks.length > 0
                            implicitHeight: _joyRow.implicitHeight + _pad * 2.5
                            radius: _fontSize * 0.4; color: _cardBg
                            border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                            RowLayout {
                                id: _joyRow
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad * 1.5 }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: "Joystick"; color: "white"
                                    font.pixelSize: _fontSize * 1.0; font.bold: true
                                }

                                Rectangle {
                                    width: _joyLabel.implicitWidth + _pad * 3; height: _fontSize * 2.2
                                    radius: _fontSize * 0.3; color: _expandedSection === "joystick" ? Qt.rgba(1,1,1,0.1) : _teal

                                    QGCLabel {
                                        id: _joyLabel; anchors.centerIn: parent
                                        text: _expandedSection === "joystick" ? "COLLAPSE" : "CONFIGURE"
                                        color: _expandedSection === "joystick" ? _teal : "#000000"
                                        font.pixelSize: _fontSize * 0.65; font.bold: true; font.letterSpacing: 0.8
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: _expandedSection = (_expandedSection === "joystick") ? "" : "joystick"
                                    }
                                }
                            }
                        }

                        // Joystick expanded
                        Rectangle {
                            Layout.fillWidth: true
                            visible: _expandedSection === "joystick"
                            implicitHeight: visible ? _root.height * 0.55 : 0
                            Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                            radius: _fontSize * 0.4; color: _cardBg
                            border.color: _tealBorder; border.width: 1; clip: true

                            Loader {
                                anchors.fill: parent
                                source: _expandedSection === "joystick" ? "qrc:/qml/QGroundControl/VehicleSetup/JoystickConfig.qml" : ""
                            }
                        }

                        // ── Firmware card ───────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            visible: !ScreenTools.isMobile && QGroundControl.corePlugin.options.showFirmwareUpgrade
                            implicitHeight: _fwRow.implicitHeight + _pad * 2.5
                            radius: _fontSize * 0.4; color: _cardBg
                            border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                            RowLayout {
                                id: _fwRow
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad * 1.5 }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: "Firmware Update"; color: "white"
                                    font.pixelSize: _fontSize * 1.0; font.bold: true
                                }

                                Rectangle {
                                    width: _fwLabel.implicitWidth + _pad * 3; height: _fontSize * 2.2
                                    radius: _fontSize * 0.3; color: _expandedSection === "firmware" ? Qt.rgba(1,1,1,0.1) : _teal

                                    QGCLabel {
                                        id: _fwLabel; anchors.centerIn: parent
                                        text: _expandedSection === "firmware" ? "COLLAPSE" : "OPEN"
                                        color: _expandedSection === "firmware" ? _teal : "#000000"
                                        font.pixelSize: _fontSize * 0.65; font.bold: true; font.letterSpacing: 0.8
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: _expandedSection = (_expandedSection === "firmware") ? "" : "firmware"
                                    }
                                }
                            }
                        }

                        // Firmware expanded
                        Rectangle {
                            Layout.fillWidth: true
                            visible: _expandedSection === "firmware"
                            implicitHeight: visible ? _root.height * 0.55 : 0
                            Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                            radius: _fontSize * 0.4; color: _cardBg
                            border.color: _tealBorder; border.width: 1; clip: true

                            Loader {
                                anchors.fill: parent
                                source: _expandedSection === "firmware" ? "qrc:/qml/QGroundControl/VehicleSetup/FirmwareUpgrade.qml" : ""
                            }
                        }

                        // ── Advanced Parameters card ────────
                        Rectangle {
                            Layout.fillWidth: true
                            visible: QGroundControl.corePlugin.showAdvancedUI
                            implicitHeight: _paramRow.implicitHeight + _pad * 2.5
                            radius: _fontSize * 0.4; color: _cardBg
                            border.color: _tealBorder; border.width: 1

                            RowLayout {
                                id: _paramRow
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad * 1.5 }

                                QGCColoredImage {
                                    width: _fontSize * 1.4; height: width
                                    source: "/InstrumentValueIcons/gear.svg"; color: _teal
                                    fillMode: Image.PreserveAspectFit
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: "Advanced Parameters"; color: "white"
                                    font.pixelSize: _fontSize * 0.9; font.bold: true
                                }

                                Rectangle {
                                    width: _paramLabel.implicitWidth + _pad * 3; height: _fontSize * 2.2
                                    radius: _fontSize * 0.3; color: _expandedSection === "parameters" ? Qt.rgba(1,1,1,0.1) : _teal

                                    QGCLabel {
                                        id: _paramLabel; anchors.centerIn: parent
                                        text: _expandedSection === "parameters" ? "COLLAPSE" : "OPEN"
                                        color: _expandedSection === "parameters" ? _teal : "#000000"
                                        font.pixelSize: _fontSize * 0.65; font.bold: true; font.letterSpacing: 0.8
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: _expandedSection = (_expandedSection === "parameters") ? "" : "parameters"
                                    }
                                }
                            }
                        }

                        // Parameters expanded
                        Rectangle {
                            Layout.fillWidth: true
                            visible: _expandedSection === "parameters"
                            implicitHeight: visible ? _root.height * 0.6 : 0
                            Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                            radius: _fontSize * 0.4; color: _cardBg
                            border.color: _tealBorder; border.width: 1; clip: true

                            Loader {
                                anchors.fill: parent
                                source: _expandedSection === "parameters" ? "qrc:/qml/QGroundControl/VehicleSetup/SetupParameterEditor.qml" : ""
                            }
                        }



                        Item { height: _pad * 2 }
                    }
                }
            }

            // ─── TAB 2: RADIO ───────────────────────────────
            Item {
                anchors.fill: parent
                visible: _activeTab === 2

                ColumnLayout {
                    anchors.centerIn: parent; spacing: _fontSize
                    visible: !_vehicleAvail || !_radioComp

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignHCenter
                        width: _fontSize * 4; height: width
                        source: "/qmlimages/Gears.svg"; color: _teal
                        fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: _vehicleAvail ? "Radio component not available for this vehicle" : "Connect a vehicle to configure radio"
                        color: _dimText; font.pixelSize: _fontSize * 0.9
                    }
                }

                Loader {
                    anchors.fill: parent
                    visible: _vehicleAvail && _radioComp !== null
                    source: (_activeTab === 2 && _radioComp) ? _radioComp.setupSource : ""
                    property var vehicleComponent: _radioComp
                }
            }

            // ─── TAB 3: SENSORS ─────────────────────────────
            Item {
                anchors.fill: parent
                visible: _activeTab === 3

                ColumnLayout {
                    anchors.centerIn: parent; spacing: _fontSize
                    visible: !_vehicleAvail || !_sensorsComp

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignHCenter
                        width: _fontSize * 4; height: width
                        source: "/qmlimages/Gears.svg"; color: _teal
                        fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: _vehicleAvail ? "Sensor component not available for this vehicle" : "Connect a vehicle to calibrate sensors"
                        color: _dimText; font.pixelSize: _fontSize * 0.9
                    }
                }

                Loader {
                    anchors.fill: parent
                    visible: _vehicleAvail && _sensorsComp !== null
                    source: (_activeTab === 3 && _sensorsComp) ? _sensorsComp.setupSource : ""
                    property var vehicleComponent: _sensorsComp
                }
            }

            // ─── TAB 4: COMPANION COMPUTER (placeholder) ────
            Item {
                anchors.fill: parent
                visible: _activeTab === 4

                ColumnLayout {
                    anchors.centerIn: parent; spacing: _fontSize

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignHCenter
                        width: _fontSize * 4; height: width
                        source: "/qmlimages/Gears.svg"; color: _teal
                        fillMode: Image.PreserveAspectFit
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "COMPANION COMPUTER"; color: "white"
                        font.pixelSize: _fontSize * 1.2; font.bold: true; font.letterSpacing: 1.5
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Companion computer configuration coming soon"
                        color: _dimText; font.pixelSize: _fontSize * 0.8
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════
    // INLINE COMPONENT: SetupCard — collapsible card
    // ════════════════════════════════════════════════════════

    component SetupCard: ColumnLayout {
        required property string sectionKey
        required property string title
        required property var    comp
        property bool showSummary: false

        Layout.fillWidth: true
        visible: comp !== null
        spacing: 0

        // ── Header card ─────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: _scContent.implicitHeight + _pad * 2.5
            radius: _fontSize * 0.4
            color:  _cardBg
            border.color: _expandedSection === sectionKey ? _tealBorder : Qt.rgba(1,1,1,0.06)
            border.width: 1

            ColumnLayout {
                id: _scContent
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad * 1.5 }
                spacing: _pad * 0.6

                // Title row
                RowLayout {
                    Layout.fillWidth: true

                    QGCLabel {
                        Layout.fillWidth: true
                        text: title; color: "white"
                        font.pixelSize: _fontSize * 1.0; font.bold: true
                    }

                    // Setup status dot
                    Rectangle {
                        width: _fontSize * 0.7; height: width; radius: width / 2
                        color: comp && comp.setupComplete ? _okColor : _errColor
                        visible: comp !== null && comp.requiresSetup
                    }

                    // Configure / Collapse button
                    Rectangle {
                        width: _scBtnLabel.implicitWidth + _pad * 3; height: _fontSize * 2.2
                        radius: _fontSize * 0.3
                        color: _expandedSection === sectionKey ? Qt.rgba(1,1,1,0.1) : _teal

                        QGCLabel {
                            id: _scBtnLabel; anchors.centerIn: parent
                            text: _expandedSection === sectionKey ? "COLLAPSE" : "CONFIGURE"
                            color: _expandedSection === sectionKey ? _teal : "#000000"
                            font.pixelSize: _fontSize * 0.65; font.bold: true; font.letterSpacing: 0.8
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: _expandedSection = (_expandedSection === sectionKey) ? "" : sectionKey
                        }
                    }
                }

                // Summary (compact, clipped to max 6 lines)
                Item {
                    Layout.fillWidth: true
                    implicitHeight: showSummary && _expandedSection !== sectionKey ? Math.min(_summaryLoader.item ? _summaryLoader.item.implicitHeight : (_fontSize * 8), _fontSize * 8) : 0
                    visible: implicitHeight > 0
                    clip: true

                    Loader {
                        id: _summaryLoader
                        width: parent.width
                        source: (showSummary && comp) ? comp.summaryQmlSource : ""
                        property var vehicleComponent: comp
                    }
                }
            }
        }

        // ── Expanded setup page ─────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: _expandedSection === sectionKey && comp !== null
            implicitHeight: visible ? _root.height * 0.55 : 0
            Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
            radius: _fontSize * 0.4; color: _cardBg
            border.color: _tealBorder; border.width: 1
            clip: true

            Loader {
                anchors.fill: parent
                source: (_expandedSection === sectionKey && comp) ? comp.setupSource : ""
                property var vehicleComponent: comp
            }
        }
    }
}
