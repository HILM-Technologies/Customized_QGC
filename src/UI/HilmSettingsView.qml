/****************************************************************************
 *
 * HILM Ground Control — Settings View
 * Full-screen HILM-themed settings with AI Detection placeholder
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id: _root
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

    readonly property real _pad:      ScreenTools.defaultFontPixelWidth * 1.8
    readonly property real _fontSize: ScreenTools.defaultFontPixelHeight
    // Scale up base point size so all derived sizes are readable (Figma match)
    readonly property real _fontPt:   ScreenTools.defaultFontPointSize * 1.45
    readonly property real _maxW:     parent.width * 0.92

    // ── QGC Settings Managers ───────────────────────────────
    property var  _settingsManager:    QGroundControl.settingsManager
    property var  _appSettings:        _settingsManager.appSettings
    property var  _flyViewSettings:    _settingsManager.flyViewSettings
    property var  _planViewSettings:   _settingsManager.planViewSettings
    property var  _videoSettings:      _settingsManager.videoSettings
    property var  _videoManager:       QGroundControl.videoManager
    property var  _flightMapSettings:  _settingsManager.flightMapSettings
    property var  _adsbSettings:       _settingsManager.adsbVehicleManagerSettings
    property var  _mavlinkSettings:    _settingsManager.mavlinkSettings
    property var  _brandImageSettings: _settingsManager.brandImageSettings
    property var  _mapsSettings:       _settingsManager.mapsSettings
    property var  _viewer3DSettings:   _settingsManager.viewer3DSettings
    property var  _autoConnectSettings: _settingsManager.autoConnectSettings
    property var  _unitsSettings:      _settingsManager.unitsSettings
    property var  _activeVehicle:      QGroundControl.multiVehicleManager.activeVehicle
    property var  _mapEngineManager:   QGroundControl.mapEngineManager
    property Fact _appFontPointSize:   _appSettings.appFontPointSize

    // Video helpers
    property string _videoSource:          _videoSettings.videoSource.rawValue
    property bool   _isStreamSource:       _videoManager.isStreamSource
    property bool   _isRTSP:              _isStreamSource && (_videoSource === _videoSettings.rtspVideoSource)
    property bool   _isTCP:               _isStreamSource && (_videoSource === _videoSettings.tcpVideoSource)
    property bool   _isUDP264:            _isStreamSource && (_videoSource === _videoSettings.udp264VideoSource)
    property bool   _isUDP265:            _isStreamSource && (_videoSource === _videoSettings.udp265VideoSource)
    property bool   _isMPEGTS:            _isStreamSource && (_videoSource === _videoSettings.mpegtsVideoSource)
    property bool   _requiresUDPUrl:      _isUDP264 || _isUDP265 || _isMPEGTS
    property bool   _videoAutoStreamConfig: _videoManager.autoStreamConfigured
    property bool   _videoSourceDisabled: _videoSource === _videoSettings.disabledVideoSource

    // Telemetry helpers
    property bool   _disableAllDataPersistence: _appSettings.disableAllPersistence.rawValue
    property bool   _isAPM:               _activeVehicle ? _activeVehicle.apmFirmware : true
    property bool   _showAPMStreamRates:  QGroundControl.apmFirmwareSupported && _settingsManager.apmMavlinkStreamRateSettings.visible && _isAPM

    // App logging helpers
    property bool _logListReady: false

    // NTRIP (moved to root for SettingsCard child visibility)
    property var  _ntrip:          _settingsManager.ntripSettings

    // Remote ID (moved to root for SettingsCard child visibility)
    property var  _ridSettings:    _settingsManager.remoteIDSettings
    property var  _activeRID:      _activeVehicle && _activeVehicle.remoteIDManager ? _activeVehicle.remoteIDManager : null
    property bool _ridCommsGood:   _activeRID ? _activeRID.commsGood : false
    property int  _ridRegion:      _ridSettings ? _ridSettings.region.rawValue : 0
    property bool _isEU:           _ridRegion === 1
    property bool _isFAA:          _ridRegion === 0

    // PX4 Log Transfer (moved to root for SettingsCard child visibility)
    property var  _px4LogMgr:      _activeVehicle ? _activeVehicle.mavlinkLogManager : null
    property int  _px4SelectedCount: 0

    // ── AI Detection placeholder state ──────────────────────
    property bool _aiEnabled:        true
    property int  _aiModelIndex:     0
    property int  _aiVariantIndex:   1
    property int  _aiThresholdIndex: 1
    property int  _aiHwAccelIndex:   1
    property bool _aiAutoSave:       true
    property bool _aiAlertOnDetect:  true
    property bool   _showMarketplace: false
    property string _searchText:      ""

    // All section descriptors for match-count computation
    readonly property var _sectionTags: [
        "AI Detection Models ai detection confidence threshold hardware acceleration gpu cuda model variant auto-save alert",
        "AI Model Marketplace install browse vehicle human inspection building solar wind turbine power line",
        "General language color scheme audio mute font scaling save path locale settings clear reset",
        "Units metric imperial distance speed temperature area horizontal vertical",
        "Fly View fly checklist joystick instrument guided virtual 3d view multi-vehicle map centering",
        "Plan View plan mission altitude vtol waypoint sequence takeoff landing gate condition",
        "Video rtsp stream camera udp tcp decoder gstreamer recording format storage aspect ratio latency",
        "Notifications Alerts notification alert battery geofence connection lost mission complete",
        "Maps map satellite terrain mapbox esri cache offline tiles osm token provider tianditu vworld",
        "Comm Links serial udp tcp bluetooth autoconnect nmea gps baudrate link connection pixhawk sik",
        "Telemetry mavlink heartbeat log forwarding csv system id apm stream rates",
        "ADSB Server adsb aircraft traffic host port connect",
        "NTRIP RTK gps rtcm correction mountpoint username password spartn whitelist",
        "Remote ID rid faa eu broadcast operator basic self emergency drone location",
        "PX4 Log Transfer px4 ulog flight data manager vehicle logs",
        "App Logging debug categories gstreamer filter",
        "Advanced brand images logo indoor outdoor icon custom",
        "Help documentation guide forum ardupilot px4",
        "Mock Link mock vehicle simulate px4 apm arducopter arduplane ardusub ardurover generic",
        "Debug font pixel screen density platform qt",
        "Palette Test palette color theme window button text",
        "About HILMOS version platform email website hilmos hilmtec tameem"
    ]

    property int _matchCount: {
        if (_searchText.length === 0) return _sectionTags.length
        var q = _searchText.toLowerCase()
        var n = 0
        for (var i = 0; i < _sectionTags.length; i++) {
            if (_sectionTags[i].toLowerCase().indexOf(q) >= 0) n++
        }
        return n
    }

    // AI placeholder data
    readonly property var _aiModels:     ["VEHICLE & HUMAN DETECTION", "POWER LINE INSPECTION", "BUILDING FACADE CLEANING", "WIND TURBINE BLADE INSPECTION", "SOLAR PANEL INSPECTION"]
    readonly property var _aiVariants:   ["NANO  60 FPS \u00b7 82%", "MEDIUM  45 FPS \u00b7 89%", "LARGE  25 FPS \u00b7 94%", "PRO  12 FPS \u00b7 96%"]
    readonly property var _aiThresholds: ["LOW (30%) - PERMISSIVE", "MEDIUM (50%) - BALANCED", "HIGH (70%) - STRICT", "VERY HIGH (90%) - MAXIMUM"]
    readonly property var _aiHwAccel:    ["CPU ONLY", "NVIDIA GPU (CUDA)", "OPENCL GPU"]

    // ════════════════════════════════════════════════════════
    // MAIN SCROLLABLE CONTENT
    // ════════════════════════════════════════════════════════

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: _mainCol.height + _pad * 6
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: _mainCol
            x: Math.max(_pad, (parent.width - width) / 2)
            y: _pad * 2
            width: Math.min(parent.width - _pad * 2, _maxW)
            spacing: _pad * 2.5

            // ── HEADER ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: _pad

                Rectangle {
                    width: _fontSize * 2.8; height: width
                    radius: _fontSize * 0.5; color: _tealDim
                    QGCColoredImage {
                        anchors.centerIn: parent; width: _fontSize * 1.6; height: width
                        source: "/InstrumentValueIcons/cog.svg"; color: _teal
                        fillMode: Image.PreserveAspectFit
                    }
                }

                ColumnLayout {
                    spacing: 2
                    QGCLabel { text: "HILMOS Settings"; color: "white"; font.pointSize: _fontPt * 1.5; font.bold: true; font.letterSpacing: 1 }
                    QGCLabel { text: "Configure system preferences and application settings"; color: _dimText; font.pointSize: _fontPt * 0.75 }
                }
            }

            // ── SEARCH BAR ──────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: _fontSize * 3.4
                radius: _fontSize * 0.6
                color:  _searchText.length > 0 ? Qt.rgba(0, 0.749, 1.0, 0.06) : Qt.rgba(1, 1, 1, 0.04)
                border.color: _searchField.activeFocus ? _teal
                            : (_searchText.length > 0 ? _tealBorder : Qt.rgba(1, 1, 1, 0.1))
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                // Outer glow ring when focused
                Rectangle {
                    anchors { fill: parent; margins: -3 }
                    radius: parent.radius + 3
                    color: "transparent"
                    border.color: _teal
                    border.width: 2
                    opacity: _searchField.activeFocus ? 0.22 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin:  _pad * 1.2
                    anchors.rightMargin: _pad * 0.8
                    spacing: _pad * 0.8

                    // Search icon
                    QGCColoredImage {
                        width: _fontSize * 1.15; height: width
                        source: "/InstrumentValueIcons/magnify.svg"
                        color:  _searchField.activeFocus || _searchText.length > 0 ? _teal : _dimText
                        fillMode: Image.PreserveAspectFit
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    // TextInput + placeholder
                    Item {
                        Layout.fillWidth: true
                        height: parent.height

                        TextInput {
                            id: _searchField
                            anchors.fill: parent
                            color: "white"
                            font.pointSize: _fontPt * 0.9
                            selectionColor:    Qt.rgba(0, 0.749, 1.0, 0.45)
                            selectedTextColor: "white"
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: _root._searchText = text
                            Keys.onEscapePressed: { text = ""; focus = false }
                        }

                        QGCLabel {
                            anchors.fill: parent
                            text:    "Search settings…  try 'video', 'rtsp', 'map', 'alerts', 'telemetry'…"
                            color:   Qt.rgba(1, 1, 1, 0.22)
                            font.pointSize: _fontPt * 0.9
                            visible: _searchField.text.length === 0
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Match count badge
                    Rectangle {
                        visible: _searchText.length > 0
                        implicitWidth: _cntLabel.implicitWidth + _pad * 1.4
                        height: _fontSize * 1.65
                        radius: height / 2
                        color:  _matchCount > 0 ? _tealDim : Qt.rgba(1, 0.1, 0.1, 0.18)
                        border.color: _matchCount > 0 ? _tealBorder : Qt.rgba(1, 0.2, 0.2, 0.45)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        QGCLabel {
                            id: _cntLabel
                            anchors.centerIn: parent
                            text:  _matchCount > 0 ? _matchCount + " found" : "no results"
                            color: _matchCount > 0 ? _teal : _errColor
                            font.pointSize: _fontPt * 0.65
                            font.bold: true
                        }
                    }

                    // Clear (✕) button
                    Rectangle {
                        visible: _searchText.length > 0
                        width: _fontSize * 1.9; height: width; radius: width / 2
                        color: _xArea.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        QGCLabel {
                            anchors.centerIn: parent
                            text:  "✕"
                            color: _xArea.containsMouse ? _errColor : _dimText
                            font.pointSize: _fontPt * 0.85
                            font.bold: true
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: _xArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: { _searchField.text = ""; _searchField.forceActiveFocus() }
                        }
                    }
                }
            }

            // ── NO RESULTS MESSAGE ───────────────────────────
            Rectangle {
                visible: _searchText.length > 0 && _matchCount === 0
                Layout.fillWidth: true
                height: _noResCol.height + _pad * 4
                radius: _fontSize * 0.6
                color: Qt.rgba(1, 1, 1, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.06); border.width: 1

                ColumnLayout {
                    id: _noResCol
                    anchors.centerIn: parent
                    spacing: _pad * 0.5

                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No settings found for  \"" + _searchText + "\""
                        color: _dimText
                        font.pointSize: _fontPt * 0.95
                    }
                    QGCLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Try: 'video', 'rtsp', 'map', 'link', 'rtk', 'alerts', 'telemetry'…"
                        color: Qt.rgba(1, 1, 1, 0.25)
                        font.pointSize: _fontPt * 0.75
                    }
                }
            }

            // ════════════════════════════════════════════════
            // SECTION 1: AI DETECTION MODELS (placeholder)
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/radar.svg"
                heading: "AI Detection Models"
                keywords: "ai detection confidence threshold hardware acceleration gpu cuda model variant auto-save alert camera analysis"
                hasAction: true
                actionText: _showMarketplace ? "HIDE MARKETPLACE" : "BROWSE MARKETPLACE"
                actionIcon: "/InstrumentValueIcons/list.svg"
                onActionClicked: _showMarketplace = !_showMarketplace

                // Processing Location
                Rectangle {
                    Layout.fillWidth: true
                    height: _procLocRow.height + _pad * 2
                    radius: _fontSize * 0.4
                    color: Qt.rgba(1,1,1,0.03)
                    border.color: Qt.rgba(1,1,1,0.08); border.width: 1

                    RowLayout {
                        id: _procLocRow
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: _pad; spacing: _pad

                        QGCColoredImage {
                            width: _fontSize * 1.2; height: width
                            source: "/InstrumentValueIcons/cog.svg"; color: _teal
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel { text: "Processing Location"; color: "white"; font.pointSize: _fontPt * 0.8; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: _plText.implicitWidth + _pad * 2; height: _fontSize * 1.6
                            radius: _fontSize * 0.3; color: _tealDim; border.color: _tealBorder; border.width: 1
                            QGCLabel { id: _plText; anchors.centerIn: parent; text: "QGC Host PC"; color: _teal; font.pointSize: _fontPt * 0.65; font.bold: true }
                        }
                    }
                }

                QGCLabel { Layout.fillWidth: true; text: "AI models run locally on this computer for real-time video analysis. No cloud connection required."; color: _dimText; font.pointSize: _fontPt * 0.65; wrapMode: Text.WordWrap }

                // Separator
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Enable AI Detection
                HilmSettingRow {
                    Layout.fillWidth: true
                    label: "Enable AI Detection"
                    description: "Activate AI models for real-time video analysis"
                    QGCCheckBoxSlider { checked: _aiEnabled; onClicked: _aiEnabled = checked }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Active AI Model
                ColumnLayout {
                    Layout.fillWidth: true; spacing: _pad * 0.3
                    QGCLabel { text: "Active AI Model"; color: "white"; font.pointSize: _fontPt * 0.8; font.bold: true }
                    HilmComboBox { Layout.fillWidth: true; model: _aiModels; currentIndex: _aiModelIndex; onActivated: (i) => _aiModelIndex = i }
                    QGCLabel { text: "Switch between detection models based on mission type"; color: _dimText; font.pointSize: _fontPt * 0.6 }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Model Variant
                ColumnLayout {
                    Layout.fillWidth: true; spacing: _pad * 0.3
                    QGCLabel { text: "Model Variant (Speed vs Accuracy)"; color: "white"; font.pointSize: _fontPt * 0.8; font.bold: true }
                    HilmComboBox { Layout.fillWidth: true; model: _aiVariants; currentIndex: _aiVariantIndex; onActivated: (i) => _aiVariantIndex = i }
                    RowLayout {
                        spacing: _pad * 0.3
                        QGCLabel { text: "\uD83D\uDCA1"; font.pointSize: _fontPt * 0.7 }
                        QGCLabel { text: "Choose Nano/Lite for older hardware or real-time requirements. Choose Large/Pro for maximum detection accuracy."; color: _dimText; font.pointSize: _fontPt * 0.6; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Active model info card
                Rectangle {
                    Layout.fillWidth: true
                    height: _modelInfoCol.height + _pad * 2
                    radius: _fontSize * 0.4
                    color: Qt.rgba(1,1,1,0.03); border.color: Qt.rgba(1,1,1,0.08); border.width: 1

                    ColumnLayout {
                        id: _modelInfoCol
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.margins: _pad
                        spacing: _pad * 0.5

                        RowLayout {
                            spacing: _pad * 0.5
                            Rectangle { width: _fontSize * 2; height: width; radius: _fontSize * 0.35; color: Qt.rgba(0.6, 0, 0.8, 0.25)
                                QGCLabel { anchors.centerIn: parent; text: "\uD83D\uDE97"; font.pointSize: _fontPt * 1.0 }
                            }
                            ColumnLayout { spacing: 1
                                QGCLabel { text: _aiModels[_aiModelIndex]; color: "white"; font.pointSize: _fontPt * 0.85; font.bold: true }
                                QGCLabel { text: "Security & Surveillance"; color: _teal; font.pointSize: _fontPt * 0.6 }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                        ModelInfoRow { label: "Category:"; value: "Security & Surveillance" }
                        ModelInfoRow { label: "Model Status:"; value: "Loaded & Ready"; valueColor: _okColor }
                        ModelInfoRow { label: "Performance:"; value: ["60 FPS", "45 FPS", "25 FPS", "12 FPS"][_aiVariantIndex] }
                        ModelInfoRow { label: "Accuracy:"; value: ["82%", "89%", "94%", "96%"][_aiVariantIndex] }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Detection Confidence Threshold
                ColumnLayout {
                    Layout.fillWidth: true; spacing: _pad * 0.3
                    QGCLabel { text: "Detection Confidence Threshold"; color: "white"; font.pointSize: _fontPt * 0.8; font.bold: true }
                    HilmComboBox { Layout.fillWidth: true; model: _aiThresholds; currentIndex: _aiThresholdIndex; onActivated: (i) => _aiThresholdIndex = i }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Auto-Save Detections
                HilmSettingRow { Layout.fillWidth: true; label: "Auto-Save Detections"; description: "Automatically save images when objects are detected"
                    QGCCheckBoxSlider { checked: _aiAutoSave; onClicked: _aiAutoSave = checked }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Alert on Detection
                HilmSettingRow { Layout.fillWidth: true; label: "Alert on Detection"; description: "Send notification when target objects are found"
                    QGCCheckBoxSlider { checked: _aiAlertOnDetect; onClicked: _aiAlertOnDetect = checked }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Hardware Acceleration
                ColumnLayout {
                    Layout.fillWidth: true; spacing: _pad * 0.3
                    QGCLabel { text: "Hardware Acceleration"; color: "white"; font.pointSize: _fontPt * 0.8; font.bold: true }
                    HilmComboBox { Layout.fillWidth: true; model: _aiHwAccel; currentIndex: _aiHwAccelIndex; onActivated: (i) => _aiHwAccelIndex = i }
                    QGCLabel { text: "GPU acceleration recommended for real-time processing"; color: _dimText; font.pointSize: _fontPt * 0.6 }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Resource Usage
                ColumnLayout {
                    Layout.fillWidth: true; spacing: _pad * 0.5
                    QGCLabel { text: "Resource Usage"; color: "white"; font.pointSize: _fontPt * 0.8; font.bold: true; Layout.bottomMargin: _pad * 0.3 }
                    ResourceBar { Layout.fillWidth: true; label: "CPU Usage"; value: 23; barColor: _okColor }
                    ResourceBar { Layout.fillWidth: true; label: "GPU Usage"; value: 67; barColor: "#E040FB" }
                    ResourceBar { Layout.fillWidth: true; label: "RAM Usage"; value: 26; barColor: _teal; suffix: "4.2 GB / 16 GB" }
                }
            }

            // ── AI MODEL MARKETPLACE (expandable) ───────────
            SettingsCard {
                Layout.fillWidth: true
                keywords: "marketplace install browse vehicle human inspection building solar wind turbine power line"
                visible: _showMarketplace
                heading: "AI Model Marketplace"
                headingDesc: "Browse and install specialized detection models"
                iconSrc: "/InstrumentValueIcons/list.svg"
                hasAction: true
                actionText: "2 of 5 Installed"
                actionIsLabel: true

                Repeater {
                    model: ListModel {
                        ListElement { name: "Vehicle & Human Detection"; category: "Security & Surveillance"; desc: "Real-time detection of vehicles, pedestrians, and cyclists for surveillance and security patrols"; size: "89.2 MB"; variants: "4 variants"; accuracy: "92% max accuracy"; installed: true; active: true; iconChar: "\uD83D\uDE97"; iconBg: "#40800080" }
                        ListElement { name: "Power Line Inspection"; category: "Infrastructure Inspection"; desc: "Automated detection of cables, insulators, and defects in electrical infrastructure"; size: "124.8 MB"; variants: "3 variants"; accuracy: "95% max accuracy"; installed: true; active: false; iconChar: "\u26A1"; iconBg: "#40FFD700" }
                        ListElement { name: "Building Facade Cleaning"; category: "Building Maintenance"; desc: "Identify dirt, stains, and areas requiring maintenance on building exteriors"; size: "156.3 MB"; variants: "3 variants"; accuracy: "94% max accuracy"; installed: false; active: false; iconChar: "\uD83C\uDFE2"; iconBg: "#400088CC" }
                        ListElement { name: "Wind Turbine Blade Inspection"; category: "Renewable Energy"; desc: "Detect cracks, erosion, and structural damage on wind turbine blades"; size: "198.5 MB"; variants: "3 variants"; accuracy: "96% max accuracy"; installed: false; active: false; iconChar: "\uD83C\uDF2C"; iconBg: "#400088CC" }
                        ListElement { name: "Solar Panel Inspection"; category: "Renewable Energy"; desc: "Identify hot spots, cracks, and efficiency issues in solar panel arrays"; size: "142.6 MB"; variants: "3 variants"; accuracy: "95% max accuracy"; installed: false; active: false; iconChar: "\u2600"; iconBg: "#40FFA000" }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: _mpCardCol.height + _pad * 2
                        radius: _fontSize * 0.5
                        color: Qt.rgba(1,1,1,0.02)
                        border.color: model.active ? _tealBorder : Qt.rgba(1,1,1,0.08)
                        border.width: model.active ? 2 : 1

                        ColumnLayout {
                            id: _mpCardCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: _pad
                            spacing: _pad * 0.5

                            // Header row
                            RowLayout {
                                Layout.fillWidth: true; spacing: _pad

                                Rectangle {
                                    width: _fontSize * 2.8; height: width
                                    radius: _fontSize * 0.5; color: model.iconBg
                                    QGCLabel { anchors.centerIn: parent; text: model.iconChar; font.pointSize: _fontPt * 1.3 }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2

                                    RowLayout {
                                        spacing: _pad * 0.5
                                        QGCLabel { text: model.name; color: "white"; font.pointSize: _fontPt * 0.9; font.bold: true }
                                        // Active badge
                                        Rectangle {
                                            visible: model.active
                                            width: _actText.implicitWidth + _pad * 1.5; height: _fontSize * 1.3
                                            radius: _fontSize * 0.3; color: Qt.rgba(0, 0.749, 1, 0.15)
                                            RowLayout { anchors.centerIn: parent; spacing: 3
                                                QGCLabel { text: "\u26A1"; font.pointSize: _fontPt * 0.5 }
                                                QGCLabel { id: _actText; text: "Active"; color: _teal; font.pointSize: _fontPt * 0.55; font.bold: true }
                                            }
                                        }
                                        // Installed check
                                        Rectangle {
                                            visible: model.installed && !model.active
                                            width: _chkText.implicitWidth + _pad; height: _fontSize * 1.3
                                            radius: _fontSize * 0.3; color: "transparent"
                                            QGCLabel { id: _chkText; anchors.centerIn: parent; text: "\u2713"; color: _okColor; font.pointSize: _fontPt * 0.65 }
                                        }
                                    }

                                    QGCLabel { text: model.category; color: _teal; font.pointSize: _fontPt * 0.6 }
                                }
                            }

                            QGCLabel { Layout.fillWidth: true; text: model.desc; color: _dimText; font.pointSize: _fontPt * 0.7; wrapMode: Text.WordWrap }

                            // Stats row
                            RowLayout {
                                Layout.fillWidth: true; spacing: _pad * 1.5
                                RowLayout {
                                    spacing: 4
                                    QGCLabel { text: "\uD83D\uDCE6"; font.pointSize: _fontPt * 0.6 }
                                    QGCLabel { text: model.size; color: _dimText; font.pointSize: _fontPt * 0.65 }
                                }
                                RowLayout {
                                    spacing: 4
                                    QGCLabel { text: "\u2699"; font.pointSize: _fontPt * 0.6 }
                                    QGCLabel { text: model.variants; color: _dimText; font.pointSize: _fontPt * 0.65 }
                                }
                                QGCLabel { text: model.accuracy; color: _dimText; font.pointSize: _fontPt * 0.65 }
                            }

                            // Action buttons
                            RowLayout {
                                Layout.fillWidth: true; spacing: _pad

                                // ACTIVATE button (for installed but not active)
                                Rectangle {
                                    visible: model.installed && !model.active
                                    width: _activateText.implicitWidth + _pad * 3; height: _fontSize * 2
                                    radius: _fontSize * 0.35; color: _tealDim; border.color: _tealBorder; border.width: 1
                                    RowLayout { anchors.centerIn: parent; spacing: _pad * 0.3
                                        QGCLabel { text: "\u26A1"; font.pointSize: _fontPt * 0.7 }
                                        QGCLabel { id: _activateText; text: "ACTIVATE"; color: _teal; font.pointSize: _fontPt * 0.65; font.bold: true }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {} }
                                }

                                // UNINSTALL button (for installed but not active)
                                Rectangle {
                                    visible: model.installed && !model.active
                                    width: _uninstText.implicitWidth + _pad * 3; height: _fontSize * 2
                                    radius: _fontSize * 0.35; color: Qt.rgba(1,0.322,0.322,0.1); border.color: Qt.rgba(1,0.322,0.322,0.3); border.width: 1
                                    QGCLabel { id: _uninstText; anchors.centerIn: parent; text: "UNINSTALL"; color: _errColor; font.pointSize: _fontPt * 0.65; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {} }
                                }

                                // INSTALL MODEL button (for not installed)
                                Rectangle {
                                    visible: !model.installed
                                    width: _installText.implicitWidth + _pad * 3; height: _fontSize * 2
                                    radius: _fontSize * 0.35; color: _teal
                                    RowLayout { anchors.centerIn: parent; spacing: _pad * 0.3
                                        QGCLabel { text: "\u2193"; color: "#000000"; font.pointSize: _fontPt * 0.8; font.bold: true }
                                        QGCLabel { id: _installText; text: "INSTALL MODEL"; color: "#000000"; font.pointSize: _fontPt * 0.65; font.bold: true }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {} }
                                }

                                Item { Layout.fillWidth: true }

                                // Installed label
                                QGCLabel { visible: model.installed; text: "\u2713 Installed"; color: _okColor; font.pointSize: _fontPt * 0.65 }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════
            // SECTION 2: GENERAL
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/cog.svg"
                heading: "General"
                keywords: "language color scheme audio mute font scaling save path locale settings clear reset ui"

                LabelledFactComboBox {
                    Layout.fillWidth: true; label: qsTr("Language")
                    fact: _appSettings.qLocaleLanguage; indexModel: false
                    visible: _appSettings.qLocaleLanguage.visible
                }

                LabelledFactComboBox {
                    Layout.fillWidth: true; label: qsTr("Color Scheme")
                    fact: _appSettings.indoorPalette; indexModel: false
                    visible: _appSettings.indoorPalette.visible
                }

                LabelledFactComboBox {
                    Layout.fillWidth: true; label: qsTr("Stream GCS Position")
                    fact: _appSettings.followTarget; indexModel: false
                    visible: _appSettings.followTarget.visible
                }

                FactCheckBoxSlider {
                    Layout.fillWidth: true; text: qsTr("Mute all audio output")
                    fact: _appSettings.audioMuted; visible: fact.visible
                }

                FactCheckBoxSlider {
                    Layout.fillWidth: true; text: fact.shortDescription
                    fact: _appSettings.androidDontSaveToSDCard; visible: fact.visible
                }

                QGCCheckBoxSlider {
                    Layout.fillWidth: true; text: qsTr("Clear all settings on next start"); checked: false
                    onClicked: { if (checked) QGroundControl.deleteAllSettingsNextBoot(); else QGroundControl.clearDeleteAllSettingsNextBoot() }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: ScreenTools.defaultFontPixelWidth * 2
                    visible: _appFontPointSize.visible
                    QGCLabel { Layout.fillWidth: true; text: qsTr("UI Scaling") }
                    RowLayout {
                        spacing: ScreenTools.defaultFontPixelWidth * 2
                        QGCButton { Layout.preferredWidth: height; height: _scaleLbl.height * 1.5; text: "-"
                            onClicked: { if (_appFontPointSize.value > _appFontPointSize.min) _appFontPointSize.value = _appFontPointSize.value - 1 }
                        }
                        QGCLabel { id: _scaleLbl; width: ScreenTools.defaultFontPixelWidth * 6
                            text: (_appFontPointSize.value / ScreenTools.platformFontPointSize * 100).toFixed(0) + "%"
                        }
                        QGCButton { Layout.preferredWidth: height; height: _scaleLbl.height * 1.5; text: "+"
                            onClicked: { if (_appFontPointSize.value < _appFontPointSize.max) _appFontPointSize.value = _appFontPointSize.value + 1 }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: ScreenTools.defaultFontPixelWidth * 2
                    visible: _appSettings.savePath.visible && !ScreenTools.isMobile
                    ColumnLayout { Layout.fillWidth: true; spacing: 0
                        QGCLabel { text: qsTr("Application Load/Save Path") }
                        QGCLabel { Layout.fillWidth: true; font.pointSize: ScreenTools.smallFontPointSize
                            text: _appSettings.savePath.rawValue === "" ? qsTr("<default location>") : _appSettings.savePath.value; elide: Text.ElideMiddle }
                    }
                    QGCButton { text: qsTr("Browse"); onClicked: _savePathDialog.openForLoad()
                        QGCFileDialog { id: _savePathDialog; title: qsTr("Choose the location to save/load files")
                            folder: _appSettings.savePath.rawValue; selectFolder: true
                            onAcceptedForLoad: (file) => _appSettings.savePath.rawValue = file }
                    }
                }
            }

            // ════════════════════════════════════════════════
            // SECTION 3: UNITS
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/dashboard.svg"
                heading: "Units"
                keywords: "metric imperial distance speed temperature area horizontal vertical measurement"
                visible: _unitsSettings.visible

                Repeater {
                    model: [_unitsSettings.horizontalDistanceUnits, _unitsSettings.verticalDistanceUnits, _unitsSettings.areaUnits, _unitsSettings.speedUnits, _unitsSettings.temperatureUnits]
                    LabelledFactComboBox { Layout.fillWidth: true; label: modelData.shortDescription; fact: modelData; indexModel: false }
                }
            }

            // ════════════════════════════════════════════════
            // SECTION 4: FLY VIEW
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/airplane.svg"
                heading: "Fly View"
                keywords: "fly checklist joystick instrument guided virtual 3d view multi-vehicle map centering takeoff land"

                // General toggles
                FactCheckBoxSlider {
                    Layout.fillWidth: true; text: qsTr("Use Preflight Checklist")
                    fact: _settingsManager.appSettings.useChecklist
                    visible: fact.visible && QGroundControl.corePlugin.options.preFlightChecklistUrl.toString().length
                }
                FactCheckBoxSlider {
                    Layout.fillWidth: true; text: qsTr("Enforce Preflight Checklist")
                    fact: _settingsManager.appSettings.enforceChecklist
                    visible: fact.visible; enabled: _settingsManager.appSettings.useChecklist.value
                }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Enable Multi-Vehicle Panel"); fact: _settingsManager.appSettings.enableMultiVehiclePanel; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Keep Map Centered On Vehicle"); fact: _flyViewSettings.keepMapCenteredOnVehicle; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Show Telemetry Log Replay Status Bar"); fact: _flyViewSettings.showLogReplayStatusBar; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Show simple camera controls (DIGICAM_CONTROL)"); fact: _flyViewSettings.showSimpleCameraControl; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Update return to home position based on device location"); fact: _flyViewSettings.updateHomePosition; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Show Joystick Status in Toolbar"); fact: _flyViewSettings.showJoystickIndicatorInToolbar; visible: fact.visible }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Guided Commands sub-header
                QGCLabel { text: "Guided Commands"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Minimum Altitude"); fact: _flyViewSettings.guidedMinimumAltitude; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Maximum Altitude"); fact: _flyViewSettings.guidedMaximumAltitude; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Go To Location Max Distance"); fact: _flyViewSettings.maxGoToLocationDistance; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Loiter Radius in Forward Flight"); fact: _flyViewSettings.forwardFlightGoToLocationLoiterRad; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Require Confirmation for Go To Location"); fact: _flyViewSettings.goToLocationRequiresConfirmInGuided; visible: fact.visible }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Virtual Joystick sub-header
                QGCLabel { text: "Virtual Joystick"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true; visible: _settingsManager.appSettings.virtualJoystick.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Enabled"); fact: _settingsManager.appSettings.virtualJoystick; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Auto-Center Throttle"); fact: _settingsManager.appSettings.virtualJoystickAutoCenterThrottle; visible: fact.visible; enabled: _settingsManager.appSettings.virtualJoystick.rawValue }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Left-Handed Mode (swap sticks)"); fact: _settingsManager.appSettings.virtualJoystickLeftHandedMode; visible: fact.visible; enabled: _settingsManager.appSettings.virtualJoystick.rawValue }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Instrument Panel
                QGCLabel { text: "Instrument Panel"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true; visible: _flyViewSettings.showAdditionalIndicatorsCompass.visible || _flyViewSettings.lockNoseUpCompass.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Show additional heading indicators on Compass"); fact: _flyViewSettings.showAdditionalIndicatorsCompass; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Lock Compass Nose-Up"); fact: _flyViewSettings.lockNoseUpCompass; visible: fact.visible }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06); visible: _viewer3DSettings.visible }

                // 3D View
                QGCLabel { text: "3D View"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true; visible: _viewer3DSettings.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Enabled"); fact: _viewer3DSettings.enabled; visible: _viewer3DSettings.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Average Building Level Height"); fact: _viewer3DSettings.buildingLevelHeight; visible: fact.visible; enabled: _viewer3DSettings.enabled.rawValue }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Vehicles Altitude Bias"); fact: _viewer3DSettings.altitudeBias; visible: fact.visible; enabled: _viewer3DSettings.enabled.rawValue }
            }

            // ════════════════════════════════════════════════
            // SECTION 5: PLAN VIEW
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/map.svg"
                heading: "Plan View"
                keywords: "plan mission altitude vtol waypoint sequence takeoff landing gate condition"

                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Default Mission Altitude"); fact: _appSettings.defaultMissionItemAltitude; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("VTOL Transition Distance"); fact: _planViewSettings.vtolTransitionDistance; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Use MAV_CMD_CONDITION_GATE for pattern generation"); fact: _planViewSettings.useConditionGate; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Missions do not require takeoff item"); fact: _planViewSettings.takeoffItemNotRequired; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Allow configuring multiple landing sequences"); fact: _planViewSettings.allowMultipleLandingPatterns; visible: fact.visible }
            }

            // ════════════════════════════════════════════════
            // SECTION 6: VIDEO
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/camera.svg"
                heading: "Video"
                keywords: "rtsp stream camera udp tcp decoder gstreamer recording format storage aspect ratio latency url source"
                visible: _videoSettings.visible

                // Source
                QGCLabel { text: "Video Source"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }
                LabelledFactComboBox { Layout.fillWidth: true; label: qsTr("Source"); fact: _videoSettings.videoSource; indexModel: false; visible: fact.visible }

                // Connection URLs
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06); visible: !_videoSourceDisabled && !_videoAutoStreamConfig && (_isTCP || _isRTSP || _requiresUDPUrl) }
                QGCLabel { text: "Connection"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true; visible: !_videoSourceDisabled && !_videoAutoStreamConfig && (_isTCP || _isRTSP || _requiresUDPUrl) }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("RTSP URL"); fact: _videoSettings.rtspUrl; visible: _isRTSP && fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("TCP URL"); fact: _videoSettings.tcpUrl; visible: _isTCP && fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("UDP URL"); fact: _videoSettings.udpUrl; visible: _requiresUDPUrl && fact.visible }

                // Settings
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06); visible: !_videoSourceDisabled }
                QGCLabel { text: "Settings"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true; visible: !_videoSourceDisabled }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Aspect Ratio"); fact: _videoSettings.aspectRatio; visible: !_videoAutoStreamConfig && _isStreamSource && fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Stop recording when disarmed"); fact: _videoSettings.disableWhenDisarmed; visible: !_videoAutoStreamConfig && _isStreamSource && fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Low Latency Mode"); fact: _videoSettings.lowLatencyMode; visible: !_videoAutoStreamConfig && _isStreamSource && fact.visible && _videoManager.gstreamerEnabled }
                LabelledFactComboBox { Layout.fillWidth: true; label: fact.shortDescription; fact: _videoSettings.forceVideoDecoder; visible: fact.visible; indexModel: false }

                // Local Storage
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }
                QGCLabel { text: "Local Video Storage"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }
                LabelledFactComboBox { Layout.fillWidth: true; label: qsTr("Record File Format"); fact: _videoSettings.recordingFormat; visible: fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Auto-Delete Saved Recordings"); fact: _videoSettings.enableStorageLimit; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Max Storage Usage"); fact: _videoSettings.maxVideoSize; visible: fact.visible; enabled: _videoSettings.enableStorageLimit.rawValue }
            }

            // ════════════════════════════════════════════════
            // SECTION 7: NOTIFICATIONS & ALERTS (HILM)
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/exclamation-outline.svg"
                heading: "Notifications & Alerts"
                keywords: "notification alert battery geofence connection lost mission complete breach warning"

                HilmSettingRow { Layout.fillWidth: true; label: "Low Battery Alert"; description: "Alert when drone battery falls below threshold"
                    QGCCheckBoxSlider { checked: true }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }
                HilmSettingRow { Layout.fillWidth: true; label: "Mission Complete Notification"; description: "Notify when a mission has been completed"
                    QGCCheckBoxSlider { checked: true }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }
                HilmSettingRow { Layout.fillWidth: true; label: "Geofence Breach Alert"; description: "Alert when a drone exits its geofence boundary"
                    QGCCheckBoxSlider { checked: true }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }
                HilmSettingRow { Layout.fillWidth: true; label: "Connection Lost Alert"; description: "Alert when communication with a drone is lost"
                    QGCCheckBoxSlider { checked: true }
                }
            }

            // ════════════════════════════════════════════════
            // SECTION 8: MAPS
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/map.svg"
                heading: "Maps"
                keywords: "satellite terrain mapbox esri cache offline tiles osm token provider tianditu vworld openaip mapbox"

                Component.onCompleted: _mapEngineManager.loadTileSets()

                // Provider / Type / Elevation
                QGCLabel { text: "Map Selection"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }

                LabelledComboBox {
                    Layout.fillWidth: true; label: qsTr("Provider")
                    model: _mapEngineManager.mapProviderList
                    onActivated: (index) => { _flightMapSettings.mapProvider.rawValue = comboBox.textAt(index); _flightMapSettings.mapType.rawValue = _mapEngineManager.mapTypeList(comboBox.textAt(index))[0] }
                    Component.onCompleted: { var i = comboBox.find(_flightMapSettings.mapProvider.rawValue); comboBox.currentIndex = i < 0 ? 0 : i }
                }

                LabelledComboBox {
                    Layout.fillWidth: true; label: qsTr("Type")
                    model: _mapEngineManager.mapTypeList(_flightMapSettings.mapProvider.rawValue)
                    onActivated: (index) => { _flightMapSettings.mapType.rawValue = comboBox.textAt(index) }
                    Component.onCompleted: { var i = comboBox.find(_flightMapSettings.mapType.rawValue); comboBox.currentIndex = i < 0 ? 0 : i }
                }

                LabelledComboBox {
                    Layout.fillWidth: true; label: qsTr("Elevation Provider")
                    model: _mapEngineManager.elevationProviderList
                    onActivated: (index) => { _flightMapSettings.elevationMapProvider.rawValue = comboBox.textAt(index) }
                    Component.onCompleted: { var i = comboBox.find(_flightMapSettings.elevationMapProvider.rawValue); comboBox.currentIndex = i < 0 ? 0 : i }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Tokens
                QGCLabel { text: "Map Tokens"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("TianDiTu"); fact: _appSettings.tiandituToken; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Mapbox"); fact: _appSettings.mapboxToken; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Esri"); fact: _appSettings.esriToken; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("VWorld"); fact: _appSettings.vworldToken; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("OpenAIP"); fact: _appSettings.openaipToken; visible: fact.visible }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Mapbox
                QGCLabel { text: "Mapbox Login"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true; visible: _appSettings.mapboxAccount.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Account"); fact: _appSettings.mapboxAccount; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Map Style"); fact: _appSettings.mapboxStyle; visible: fact.visible }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Custom URL
                QGCLabel { text: "Custom Map URL"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true; visible: _appSettings.customURL.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Server URL"); fact: _appSettings.customURL; visible: fact.visible }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Cache
                QGCLabel { text: "Tile Cache"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Max Cache Disk Size (MB)"); fact: _mapsSettings.maxCacheDiskSize; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Max Cache Memory Size (MB)"); fact: _mapsSettings.maxCacheMemorySize; visible: fact.visible }
            }

            // ════════════════════════════════════════════════
            // SECTION 9: COMM LINKS
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/link.svg"
                heading: "Comm Links"
                keywords: "serial udp tcp bluetooth autoconnect nmea gps baudrate connection pixhawk sik librepilot zeroconf"
                visible: _autoConnectSettings.visible

                property var _linkManager: QGroundControl.linkManager

                QGCLabel { text: "AutoConnect"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }

                Repeater {
                    id: _autoConnectRepeater
                    model: [_autoConnectSettings.autoConnectPixhawk, _autoConnectSettings.autoConnectSiKRadio, _autoConnectSettings.autoConnectLibrePilot, _autoConnectSettings.autoConnectUDP, _autoConnectSettings.autoConnectZeroConf, _autoConnectSettings.autoConnectRTKGPS]
                    property var names: [qsTr("Pixhawk"), qsTr("SiK Radio"), qsTr("LibrePilot"), qsTr("UDP"), qsTr("Zero-Conf"), qsTr("RTK")]
                    FactCheckBoxSlider { Layout.fillWidth: true; text: _autoConnectRepeater.names[index]; fact: modelData; visible: modelData.visible }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // NMEA GPS
                QGCLabel { text: "NMEA GPS"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true; visible: _autoConnectSettings.autoConnectNmeaPort.visible }

                LabelledComboBox {
                    id: _nmeaPortCombo
                    Layout.fillWidth: true; label: qsTr("Device")
                    visible: _autoConnectSettings.autoConnectNmeaPort.visible
                    model: ListModel {}
                    onActivated: (index) => { if (index !== -1) _autoConnectSettings.autoConnectNmeaPort.value = comboBox.textAt(index) }
                    Component.onCompleted: {
                        var m = []; m.push(qsTr("Disabled")); m.push(qsTr("UDP Port"))
                        if (QGroundControl.linkManager.serialPorts.length === 0) { m.push(qsTr("Serial <none available>")) }
                        else { for (var i in QGroundControl.linkManager.serialPorts) m.push(QGroundControl.linkManager.serialPorts[i]) }
                        _nmeaPortCombo.model = m
                        var idx = _nmeaPortCombo.comboBox.find(_autoConnectSettings.autoConnectNmeaPort.valueString)
                        _nmeaPortCombo.currentIndex = idx
                    }
                }

                LabelledComboBox {
                    id: _nmeaBaudCombo
                    Layout.fillWidth: true; label: qsTr("Baudrate")
                    visible: _nmeaPortCombo.currentText !== "UDP Port" && _nmeaPortCombo.currentText !== "Disabled" && _autoConnectSettings.autoConnectNmeaBaud.visible
                    model: QGroundControl.linkManager.serialBaudRates
                    onActivated: (index) => { if (index !== -1) _autoConnectSettings.autoConnectNmeaBaud.value = parseInt(comboBox.textAt(index)) }
                    Component.onCompleted: { var idx = _nmeaBaudCombo.comboBox.find(_autoConnectSettings.autoConnectNmeaBaud.valueString); _nmeaBaudCombo.currentIndex = idx }
                }

                LabelledFactTextField {
                    Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40
                    visible: _nmeaPortCombo.currentText === "UDP Port"
                    label: qsTr("NMEA stream UDP port"); fact: _autoConnectSettings.nmeaUdpPort
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Configured Links
                QGCLabel { text: "Configured Links"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }

                Repeater {
                    model: QGroundControl.linkManager.linkConfigurations

                    RowLayout {
                        Layout.fillWidth: true; spacing: _pad
                        visible: !object.dynamic

                        QGCLabel { Layout.fillWidth: true; text: object.name; color: "white"; font.pointSize: _fontPt * 0.85 }

                        QGCColoredImage {
                            width: ScreenTools.minTouchPixels; height: width; sourceSize.height: height
                            fillMode: Image.PreserveAspectFit; mipmap: true; smooth: true
                            color: object.link ? _dimText : _teal; source: "/res/pencil.svg"
                            enabled: !object.link
                            QGCMouseArea {
                                fillItem: parent
                                onClicked: {
                                    var editingConfig = QGroundControl.linkManager.startConfigurationEditing(object)
                                    _linkDialogComponent.createObject(mainWindow, { editingConfig: editingConfig, originalConfig: object }).open()
                                }
                            }
                        }

                        QGCColoredImage {
                            width: ScreenTools.minTouchPixels; height: width; sourceSize.height: height
                            fillMode: Image.PreserveAspectFit; mipmap: true; smooth: true
                            color: _errColor; source: "/res/TrashDelete.svg"
                            QGCMouseArea {
                                fillItem: parent
                                onClicked: mainWindow.showMessageDialog(qsTr("Delete Link"), qsTr("Are you sure you want to delete '%1'?").arg(object.name), Dialog.Ok | Dialog.Cancel, function() { QGroundControl.linkManager.removeConfiguration(object) })
                            }
                        }

                        QGCButton {
                            text: object.link ? qsTr("Disconnect") : qsTr("Connect")
                            onClicked: { if (object.link) object.link.disconnect(); else QGroundControl.linkManager.createConnectedLink(object) }
                        }
                    }
                }

                LabelledButton {
                    Layout.fillWidth: true; label: qsTr("Add New Link"); buttonText: qsTr("Add")
                    onClicked: {
                        var editingConfig = QGroundControl.linkManager.createConfiguration(ScreenTools.isSerialAvailable ? LinkConfiguration.TypeSerial : LinkConfiguration.TypeUdp, "")
                        _linkDialogComponent.createObject(mainWindow, { editingConfig: editingConfig, originalConfig: null }).open()
                    }
                }
            }

            // ════════════════════════════════════════════════
            // SECTION 10: TELEMETRY
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/network.svg"
                heading: "Telemetry"
                keywords: "mavlink heartbeat log forwarding csv system id apm stream rates link status"

                // Ground Station
                QGCLabel { text: "Ground Station"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("MAVLink System ID"); fact: _mavlinkSettings.gcsMavlinkSystemID }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Emit heartbeat"); fact: _mavlinkSettings.sendGCSHeartbeat }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // MAVLink Forwarding
                QGCLabel { text: "MAVLink Forwarding"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Enable"); fact: _mavlinkSettings.forwardMavlink; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: qsTr("Host name"); fact: _mavlinkSettings.forwardMavlinkHostName; visible: fact.visible; enabled: _mavlinkSettings.forwardMavlink.rawValue }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06); visible: !_disableAllDataPersistence }

                // Logging
                QGCLabel { text: "Logging"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true; visible: !_disableAllDataPersistence }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Save log after each flight"); fact: _mavlinkSettings.telemetrySave; visible: !_disableAllDataPersistence && fact.visible }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Save logs even if vehicle was not armed"); fact: _mavlinkSettings.telemetrySaveNotArmed; visible: !_disableAllDataPersistence && fact.visible; enabled: _mavlinkSettings.telemetrySave.rawValue }
                FactCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Save CSV log of telemetry data"); fact: _mavlinkSettings.saveCsvTelemetry; visible: !_disableAllDataPersistence && fact.visible }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Link Status
                QGCLabel { text: "Link Status"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }
                LabelledLabel { Layout.fillWidth: true; label: qsTr("Total messages sent"); labelText: _activeVehicle ? _activeVehicle.mavlinkSentCount : qsTr("Not Connected") }
                LabelledLabel { Layout.fillWidth: true; label: qsTr("Total messages received"); labelText: _activeVehicle ? _activeVehicle.mavlinkReceivedCount : qsTr("Not Connected") }
                LabelledLabel { Layout.fillWidth: true; label: qsTr("Total message loss"); labelText: _activeVehicle ? _activeVehicle.mavlinkLossCount : qsTr("Not Connected") }
                LabelledLabel { Layout.fillWidth: true; label: qsTr("Loss rate"); labelText: _activeVehicle ? _activeVehicle.mavlinkLossPercent.toFixed(0) + "%" : qsTr("Not Connected") }
            }

            // ════════════════════════════════════════════════
            // SECTION 11: ADSB SERVER
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/airplane.svg"
                heading: "ADSB Server"
                keywords: "adsb aircraft traffic host port connect ads-b"
                visible: _adsbSettings.visible

                FactCheckBoxSlider { Layout.fillWidth: true; text: _adsbSettings.adsbServerConnectEnabled.shortDescription; fact: _adsbSettings.adsbServerConnectEnabled; visible: fact.visible }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _adsbSettings.adsbServerHostAddress.shortDescription; fact: _adsbSettings.adsbServerHostAddress; visible: fact.visible; enabled: _adsbSettings.adsbServerConnectEnabled.rawValue }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _adsbSettings.adsbServerPort.shortDescription; fact: _adsbSettings.adsbServerPort; visible: fact.visible; enabled: _adsbSettings.adsbServerConnectEnabled.rawValue }
            }

            // ════════════════════════════════════════════════
            // SECTION 12: NTRIP / RTK
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/radio.svg"
                heading: "NTRIP / RTK"
                keywords: "gps rtcm correction mountpoint username password spartn whitelist ntrip rtk"
                visible: _settingsManager.ntripSettings.visible

                FactCheckBoxSlider { Layout.fillWidth: true; text: _ntrip.ntripServerConnectEnabled.shortDescription; fact: _ntrip.ntripServerConnectEnabled; visible: fact.visible }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ntrip.ntripServerHostAddress.shortDescription; fact: _ntrip.ntripServerHostAddress; visible: fact.visible; enabled: _ntrip.ntripServerConnectEnabled.rawValue }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ntrip.ntripServerPort.shortDescription; fact: _ntrip.ntripServerPort; visible: fact.visible; enabled: _ntrip.ntripServerConnectEnabled.rawValue }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ntrip.ntripUsername.shortDescription; fact: _ntrip.ntripUsername; visible: fact.visible; enabled: _ntrip.ntripServerConnectEnabled.rawValue }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ntrip.ntripPassword.shortDescription; fact: _ntrip.ntripPassword; visible: fact.visible; enabled: _ntrip.ntripServerConnectEnabled.rawValue; textField.echoMode: TextInput.Password }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ntrip.ntripMountpoint.shortDescription; fact: _ntrip.ntripMountpoint; visible: fact.visible; enabled: _ntrip.ntripServerConnectEnabled.rawValue }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ntrip.ntripWhitelist.shortDescription; fact: _ntrip.ntripWhitelist; visible: fact.visible; enabled: _ntrip.ntripServerConnectEnabled.rawValue }
                FactCheckBoxSlider { Layout.fillWidth: true; text: _ntrip.ntripUseSpartn.shortDescription; fact: _ntrip.ntripUseSpartn; visible: fact.visible; enabled: false }
            }

            // ════════════════════════════════════════════════
            // SECTION 13: REMOTE ID
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/shield.svg"
                heading: "Remote ID"
                keywords: "rid faa eu broadcast operator basic self emergency drone location utm"
                visible: _settingsManager.remoteIDSettings.visible

                // Status Flags (visible when connected)
                RowLayout {
                    Layout.fillWidth: true; spacing: _pad
                    visible: _activeVehicle

                    Repeater {
                        model: [
                            { label: "ARM STATUS", good: _activeRID ? _activeRID.armStatusGood : false, vis: _ridCommsGood },
                            { label: "RID COMMS",  good: _activeRID ? _activeRID.commsGood : false, vis: true },
                            { label: "GCS GPS",    good: _activeRID ? _activeRID.gcsGPSGood : false, vis: _ridCommsGood },
                            { label: "BASIC ID",   good: _activeRID ? _activeRID.basicIDGood : false, vis: _ridCommsGood },
                            { label: "OPERATOR ID", good: _activeRID ? _activeRID.operatorIDGood : false, vis: _ridCommsGood }
                        ]

                        Rectangle {
                            Layout.fillWidth: true; height: _fontSize * 3; radius: 5
                            visible: modelData.vis
                            color: modelData.good ? _okColor : _errColor
                            QGCLabel { anchors.centerIn: parent; text: modelData.label; font.bold: true; font.pointSize: _fontPt * 0.65; color: "white"; horizontalAlignment: Text.AlignHCenter }
                        }
                    }
                }

                // Arm Status Error
                QGCLabel {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; color: _errColor; font.pointSize: _fontPt * 0.75
                    visible: _activeRID ? !_activeRID.armStatusGood : false
                    text: _activeRID ? "Arm Status Error: " + _activeRID.armStatusError : ""
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Region
                LabelledFactComboBox { Layout.fillWidth: true; label: _ridSettings.region.shortDescription; fact: _ridSettings.region; visible: fact.visible }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Basic ID
                QGCLabel { text: "Basic ID"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }
                QGCLabel { Layout.fillWidth: true; text: "If Basic ID is already set on the RID device, this will be registered as Basic ID 2"; color: _dimText; font.pointSize: _fontPt * 0.6; wrapMode: Text.WordWrap }

                FactCheckBoxSlider { id: _ridSendBasicID; Layout.fillWidth: true; text: qsTr("Broadcast"); fact: _ridSettings.sendBasicID; visible: fact.visible }
                LabelledFactComboBox { Layout.fillWidth: true; label: _ridSettings.basicIDType.shortDescription; fact: _ridSettings.basicIDType; indexModel: false; visible: fact.visible; enabled: _ridSendBasicID.fact.rawValue }
                LabelledFactComboBox { Layout.fillWidth: true; label: _ridSettings.basicIDUaType.shortDescription; fact: _ridSettings.basicIDUaType; indexModel: false; visible: fact.visible; enabled: _ridSendBasicID.fact.rawValue }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ridSettings.basicID.shortDescription; fact: _ridSettings.basicID; visible: fact.visible; enabled: _ridSendBasicID.fact.rawValue; textField.maximumLength: 20 }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Operator ID
                QGCLabel { text: "Operator ID"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }

                FactCheckBoxSlider { id: _ridSendOpID; Layout.fillWidth: true; text: qsTr("Broadcast") + (_isEU ? " (EU Required)" : ""); fact: _ridSettings.sendOperatorID; visible: fact.visible; enabled: _isFAA }
                LabelledFactComboBox { Layout.fillWidth: true; label: _ridSettings.operatorIDType.shortDescription; fact: _ridSettings.operatorIDType; indexModel: false; visible: fact.visible && (fact.enumValues.length > 1) }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ridSettings.operatorID.shortDescription; fact: _ridSettings.operatorID; visible: fact.visible; textField.maximumLength: 20 }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Self ID
                QGCLabel { text: "Self ID"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }
                QGCLabel { Layout.fillWidth: true; text: "If an emergency is declared, Emergency Text will be broadcast even if Broadcast is not enabled."; color: _dimText; font.pointSize: _fontPt * 0.6; wrapMode: Text.WordWrap }

                FactCheckBoxSlider { id: _ridSendSelfID; Layout.fillWidth: true; text: qsTr("Broadcast"); fact: _ridSettings.sendSelfID; visible: fact.visible }
                LabelledFactComboBox { Layout.fillWidth: true; label: qsTr("Broadcast Message"); fact: _ridSettings.selfIDType; indexModel: false; visible: fact.visible; enabled: _ridSendSelfID.fact.rawValue }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ridSettings.selfIDFree.shortDescription; fact: _ridSettings.selfIDFree; visible: fact.visible; enabled: _ridSendSelfID.fact.rawValue; textField.maximumLength: 23 }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ridSettings.selfIDExtended.shortDescription; fact: _ridSettings.selfIDExtended; visible: fact.visible; enabled: _ridSendSelfID.fact.rawValue; textField.maximumLength: 23 }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ridSettings.selfIDEmergency.shortDescription; fact: _ridSettings.selfIDEmergency; visible: fact.visible; textField.maximumLength: 23 }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Ground Station Location
                QGCLabel { text: "Ground Station Location"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }

                LabelledFactComboBox { Layout.fillWidth: true; label: _ridSettings.locationType.shortDescription; fact: _ridSettings.locationType; indexModel: false }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ridSettings.latitudeFixed.shortDescription; fact: _ridSettings.latitudeFixed; textField.maximumLength: 20; enabled: _ridSettings.locationType.rawValue === 1 }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ridSettings.longitudeFixed.shortDescription; fact: _ridSettings.longitudeFixed; textField.maximumLength: 20; enabled: _ridSettings.locationType.rawValue === 1 }
                LabelledFactTextField { Layout.fillWidth: true; textFieldPreferredWidth: ScreenTools.defaultFontPixelWidth * 40; label: _ridSettings.altitudeFixed.shortDescription; fact: _ridSettings.altitudeFixed; textField.maximumLength: 20; enabled: _ridSettings.locationType.rawValue === 1 }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06); visible: _isEU }

                // EU Vehicle Info
                QGCLabel { text: "EU Vehicle Info"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true; visible: _isEU }

                QGCCheckBoxSlider {
                    Layout.fillWidth: true; text: qsTr("Provide Information"); visible: _isEU && _ridSettings.classificationType.visible
                    checked: _ridSettings.classificationType.rawValue === 1
                    onClicked: _ridSettings.classificationType.rawValue = checked ? 1 : 0
                }
                LabelledFactComboBox { Layout.fillWidth: true; label: _ridSettings.categoryEU.shortDescription; fact: _ridSettings.categoryEU; indexModel: false; visible: _isEU && fact.visible; enabled: _ridSettings.classificationType.rawValue === 1 }
                LabelledFactComboBox { Layout.fillWidth: true; label: _ridSettings.classEU.shortDescription; fact: _ridSettings.classEU; indexModel: false; visible: _isEU && fact.visible; enabled: _ridSettings.classificationType.rawValue === 1 }
            }

            // ════════════════════════════════════════════════
            // SECTION 14: ADVANCED
            // ════════════════════════════════════════════════

            // ════════════════════════════════════════════════
            // PX4 LOG TRANSFER (fully inlined)
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/cloud-upload.svg"
                heading: "PX4 Log Transfer"
                keywords: "px4 ulog flight data manager logs upload download"
                visible: QGroundControl.corePlugin.options.showPX4LogTransferOptions && (_activeVehicle ? _activeVehicle.px4Firmware : true)

                // MAVLink 2.0 Logging
                QGCLabel { text: "MAVLink 2.0 Logging (PX4 Pro Only)"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }

                RowLayout {
                    Layout.fillWidth: true; spacing: _pad
                    QGCButton { text: qsTr("Start Logging"); enabled: _px4LogMgr && !_px4LogMgr.logRunning && _px4LogMgr.canStartLog && !_disableAllDataPersistence; onClicked: _px4LogMgr.startLogging() }
                    QGCButton { text: qsTr("Stop Logging"); enabled: _px4LogMgr && _px4LogMgr.logRunning && !_disableAllDataPersistence; onClicked: _px4LogMgr.stopLogging() }
                    Item { Layout.fillWidth: true }
                    QGCLabel { text: _px4LogMgr ? (_px4LogMgr.logRunning ? "Logging active..." : "Idle") : "Not connected"; color: _px4LogMgr && _px4LogMgr.logRunning ? _okColor : _dimText; font.pointSize: _fontPt * 0.75 }
                }

                QGCCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Enable automatic logging"); checked: _px4LogMgr ? _px4LogMgr.enableAutoStart : false; enabled: !_disableAllDataPersistence; onClicked: { if (_px4LogMgr) _px4LogMgr.enableAutoStart = checked } }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Upload Settings
                QGCLabel { text: "Log Upload Settings"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }

                RowLayout { Layout.fillWidth: true; spacing: _pad
                    QGCLabel { text: qsTr("Email address:"); color: "white"; font.pointSize: _fontPt * 0.8 }
                    QGCTextField { id: _px4Email; Layout.fillWidth: true; text: _px4LogMgr ? _px4LogMgr.emailAddress : ""; enabled: !_disableAllDataPersistence; onEditingFinished: { if (_px4LogMgr) _px4LogMgr.emailAddress = text } }
                }
                RowLayout { Layout.fillWidth: true; spacing: _pad
                    QGCLabel { text: qsTr("Description:"); color: "white"; font.pointSize: _fontPt * 0.8 }
                    QGCTextField { id: _px4Desc; Layout.fillWidth: true; text: _px4LogMgr ? _px4LogMgr.description : ""; enabled: !_disableAllDataPersistence; onEditingFinished: { if (_px4LogMgr) _px4LogMgr.description = text } }
                }
                RowLayout { Layout.fillWidth: true; spacing: _pad
                    QGCLabel { text: qsTr("Upload URL:"); color: "white"; font.pointSize: _fontPt * 0.8 }
                    QGCTextField { id: _px4Url; Layout.fillWidth: true; text: _px4LogMgr ? _px4LogMgr.uploadURL : ""; enabled: !_disableAllDataPersistence; onEditingFinished: { if (_px4LogMgr) _px4LogMgr.uploadURL = text } }
                }
                RowLayout { Layout.fillWidth: true; spacing: _pad
                    QGCLabel { text: qsTr("Video URL:"); color: "white"; font.pointSize: _fontPt * 0.8 }
                    QGCTextField { Layout.fillWidth: true; text: _px4LogMgr ? _px4LogMgr.videoURL : ""; enabled: !_disableAllDataPersistence; onEditingFinished: { if (_px4LogMgr) _px4LogMgr.videoURL = text } }
                }

                QGCCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Make log publicly available"); checked: _px4LogMgr ? _px4LogMgr.publicLog : false; enabled: !_disableAllDataPersistence; onClicked: { if (_px4LogMgr) _px4LogMgr.publicLog = checked } }
                QGCCheckBoxSlider { id: _px4AutoUpload; Layout.fillWidth: true; text: qsTr("Enable automatic log uploads"); checked: _px4LogMgr ? _px4LogMgr.enableAutoUpload : false; enabled: !_disableAllDataPersistence; onClicked: { if (_px4LogMgr) _px4LogMgr.enableAutoUpload = checked } }
                QGCCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Delete log file after uploading"); checked: _px4LogMgr ? _px4LogMgr.deleteAfterUpload : false; enabled: _px4AutoUpload.checked && !_disableAllDataPersistence; onClicked: { if (_px4LogMgr) _px4LogMgr.deleteAfterUpload = checked } }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Saved Log Files
                QGCLabel { text: "Saved Log Files"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }

                Rectangle {
                    Layout.fillWidth: true; height: _fontSize * 14
                    radius: _fontSize * 0.4; color: Qt.rgba(1,1,1,0.03); border.color: Qt.rgba(1,1,1,0.08); border.width: 1

                    QGCListView {
                        anchors.fill: parent; anchors.margins: _pad; clip: true
                        model: _px4LogMgr ? _px4LogMgr.logFiles : null

                        delegate: RowLayout {
                            width: parent ? parent.width : 0; spacing: _pad
                            QGCCheckBox { checked: object.selected; enabled: !object.writing && !object.uploading; onClicked: object.selected = checked }
                            QGCLabel { Layout.fillWidth: true; text: object.name; color: object.writing ? _warnColor : "white"; font.pointSize: _fontPt * 0.75 }
                            QGCLabel { text: object.uploaded ? qsTr("Uploaded") : Number(object.size).toLocaleString(Qt.locale(), 'f', 0); visible: !object.uploading; color: _dimText; font.pointSize: _fontPt * 0.7 }
                            ProgressBar { visible: object.uploading && !object.uploaded; from: 0; to: 100; value: object.progress * 100.0; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 20 }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: _pad
                    QGCButton { text: qsTr("Check All"); enabled: _px4LogMgr && !_px4LogMgr.uploading && !_px4LogMgr.logRunning; onClicked: { for (var i = 0; i < _px4LogMgr.logFiles.count; i++) _px4LogMgr.logFiles.get(i).selected = true } }
                    QGCButton { text: qsTr("Check None"); enabled: _px4LogMgr && !_px4LogMgr.uploading && !_px4LogMgr.logRunning; onClicked: { for (var i = 0; i < _px4LogMgr.logFiles.count; i++) _px4LogMgr.logFiles.get(i).selected = false } }
                    QGCButton { text: qsTr("Delete Selected"); enabled: _px4LogMgr && !_px4LogMgr.uploading && !_px4LogMgr.logRunning; onClicked: mainWindow.showMessageDialog(qsTr("Delete Logs"), qsTr("Confirm deleting selected log files?"), Dialog.Yes | Dialog.No, function() { _px4LogMgr.deleteLog() }) }
                    QGCButton {
                        text: _px4LogMgr && _px4LogMgr.uploading ? qsTr("Cancel Upload") : qsTr("Upload Selected")
                        enabled: _px4LogMgr && !_px4LogMgr.logRunning
                        onClicked: {
                            if (_px4LogMgr.uploading) { mainWindow.showMessageDialog(qsTr("Cancel Upload"), qsTr("Confirm canceling the upload?"), Dialog.Yes | Dialog.No, function() { _px4LogMgr.cancelUpload() }) }
                            else { if (_px4LogMgr.emailAddress === "") mainWindow.showMessageDialog(qsTr("MAVLink Logging"), qsTr("Please enter an email address before uploading."), Dialog.Close, null); else mainWindow.showMessageDialog(qsTr("Upload Logs"), qsTr("Confirm uploading selected log files?"), Dialog.Yes | Dialog.No, function() { _px4LogMgr.uploadLog() }) }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════
            // APP LOGGING (fully inlined)
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/code.svg"
                heading: "App Logging"
                keywords: "debug categories gstreamer filter logging console output"

                // GStreamer Debug Level
                LabelledFactComboBox {
                    Layout.fillWidth: true; label: qsTr("GStreamer Debug Level")
                    fact: _appSettings.gstDebugLevel; visible: fact.visible
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Debug Message Log
                QGCLabel { text: "Debug Messages"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }

                Rectangle {
                    Layout.fillWidth: true; height: _fontSize * 16
                    radius: _fontSize * 0.4; color: Qt.rgba(1,1,1,0.03); border.color: Qt.rgba(1,1,1,0.08); border.width: 1

                    QGCListView {
                        id: _appLogListView
                        anchors.fill: parent; anchors.margins: _pad; clip: true
                        model: debugMessageModel

                        delegate: Rectangle {
                            width: _appLogListView.width; height: _appLogField.height + _pad * 0.5
                            color: index % 2 === 0 ? "transparent" : Qt.rgba(1,1,1,0.02)
                            QGCLabel { id: _appLogField; width: parent.width; text: display; wrapMode: Text.Wrap; font.pointSize: _fontPt * 0.65; color: _dimText; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Component.onCompleted: { _logListReady = true; _appLogListView.positionViewAtEnd() }

                        Connections {
                            target: debugMessageModel
                            function onDataChanged() { if (_appLogFollowTail.checked && _logListReady) _appLogListView.positionViewAtEnd() }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: _pad

                    QGCButton {
                        text: qsTr("Save App Log")
                        onClicked: _appLogSaveDialog.openForSave()

                        QGCFileDialog {
                            id: _appLogSaveDialog
                            folder: QGroundControl.settingsManager.appSettings.logSavePath
                            nameFilters: [qsTr("Log files (*.txt)"), qsTr("All Files (*)")]
                            title: qsTr("Select log save file")
                            onAcceptedForSave: (file) => { debugMessageModel.writeMessages(file) }
                        }
                    }

                    QGCButton {
                        id: _appLogFollowTail; text: qsTr("Show Latest"); checkable: true; checked: true
                        onCheckedChanged: { if (checked && _logListReady) _appLogListView.positionViewAtEnd() }
                    }

                    Item { Layout.fillWidth: true }

                    QGCButton {
                        text: qsTr("Set Logging")
                        onClicked: _loggingFiltersDialog.createObject(mainWindow).open()
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                // Logging Categories inline
                QGCLabel { text: "Logging Categories"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }

                Flow {
                    Layout.fillWidth: true; spacing: _pad * 0.5

                    Repeater {
                        model: QGroundControl.flatLoggingCategoriesModel()
                        QGCCheckBoxSlider {
                            Layout.fillWidth: true; Layout.maximumHeight: visible ? implicitHeight : 0
                            text: object.fullCategory; visible: object.enabled; checked: object.enabled
                            onClicked: object.enabled = checked
                        }
                    }

                    QGCButton { text: qsTr("Disable All"); onClicked: QGroundControl.disableAllLoggingCategories() }
                }
            }

            // ════════════════════════════════════════════════
            // DEBUG (debug only)
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/bug.svg"
                heading: "Debug"
                keywords: "font pixel screen density platform qt device ratio"
                visible: ScreenTools.isDebug

                GridLayout {
                    Layout.fillWidth: true; columns: 2; columnSpacing: _pad * 2; rowSpacing: _pad * 0.5

                    QGCLabel { text: "Qt Platform:"; color: _dimText } QGCLabel { text: Qt.platform.os; color: "white" }
                    QGCLabel { text: "Default font width:"; color: _dimText } QGCLabel { text: ScreenTools.defaultFontPixelWidth.toFixed(1); color: "white" }
                    QGCLabel { text: "Default font height:"; color: _dimText } QGCLabel { text: ScreenTools.defaultFontPixelHeight.toFixed(1); color: "white" }
                    QGCLabel { text: "Default font point size:"; color: _dimText } QGCLabel { text: ScreenTools.defaultFontPointSize.toFixed(1); color: "white" }
                    QGCLabel { text: "Screen size:"; color: _dimText } QGCLabel { text: Screen.width + " x " + Screen.height; color: "white" }
                    QGCLabel { text: "Screen desktop:"; color: _dimText } QGCLabel { text: Screen.desktopAvailableWidth + " x " + Screen.desktopAvailableHeight; color: "white" }
                    QGCLabel { text: "Pixel density:"; color: _dimText } QGCLabel { text: Screen.pixelDensity.toFixed(4); color: "white" }
                    QGCLabel { text: "Device pixel ratio:"; color: _dimText } QGCLabel { text: Screen.devicePixelRatio.toFixed(2); color: "white" }
                }
            }

            // ════════════════════════════════════════════════
            // PALETTE TEST (debug only)
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/color-palette.svg"
                heading: "Palette Test"
                keywords: "palette color theme window button text"
                visible: ScreenTools.isDebug

                QGCPalette { id: _testPal; colorGroupEnabled: true }

                GridLayout {
                    Layout.fillWidth: true; columns: 4; columnSpacing: _pad; rowSpacing: _pad * 0.5

                    Repeater {
                        model: [
                            { name: "window", c: _testPal.window }, { name: "windowShade", c: _testPal.windowShade },
                            { name: "windowShadeDark", c: _testPal.windowShadeDark }, { name: "text", c: _testPal.text },
                            { name: "button", c: _testPal.button }, { name: "buttonText", c: _testPal.buttonText },
                            { name: "buttonHighlight", c: _testPal.buttonHighlight }, { name: "primaryButton", c: _testPal.primaryButton },
                            { name: "textField", c: _testPal.textField }, { name: "textFieldText", c: _testPal.textFieldText },
                            { name: "colorGreen", c: _testPal.colorGreen }, { name: "colorRed", c: _testPal.colorRed }
                        ]

                        RowLayout {
                            spacing: _pad * 0.5
                            Rectangle { width: _fontSize * 2; height: _fontSize * 1.5; radius: 3; color: modelData.c; border.color: Qt.rgba(1,1,1,0.2); border.width: 1 }
                            QGCLabel { text: modelData.name; color: _dimText; font.pointSize: _fontPt * 0.7 }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════
            // HELP
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/information-outline.svg"
                heading: "Help"

                Repeater {
                    model: [
                        { label: "QGroundControl User Guide", url: "https://docs.qgroundcontrol.com" },
                        { label: "PX4 Users Discussion Forum", url: "http://discuss.px4.io/c/qgroundcontrol" },
                        { label: "ArduPilot Discussion Forum", url: "https://discuss.ardupilot.org/c/ground-control-software/qgroundcontrol" },
                        { label: "QGroundControl Discord", url: "https://discord.com/channels/1022170275984457759/1022185820683255908" }
                    ]

                    RowLayout {
                        Layout.fillWidth: true; spacing: _pad
                        QGCLabel { text: modelData.label; color: "white"; font.pointSize: _fontPt * 0.8 }
                        Item { Layout.fillWidth: true }
                        QGCLabel {
                            text: "<a href=\"" + modelData.url + "\">" + modelData.url.replace(/https?:\/\//, "") + "</a>"
                            color: _teal; font.pointSize: _fontPt * 0.7; linkColor: _teal
                            onLinkActivated: (link) => Qt.openUrlExternally(link)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════
            // MOCK LINK (Debug)
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/bug.svg"
                heading: "Mock Link"
                keywords: "mock vehicle simulate px4 apm arducopter arduplane ardusub ardurover generic"
                visible: ScreenTools.isDebug

                QGCCheckBoxSlider {
                    id: _mockSendStatus
                    Layout.fillWidth: true; text: qsTr("Send status text + voice")
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                QGCLabel { text: "Create Mock Vehicles"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true }

                GridLayout {
                    Layout.fillWidth: true; columns: 2; columnSpacing: _pad; rowSpacing: _pad

                    QGCButton { Layout.fillWidth: true; text: qsTr("PX4 Vehicle"); onClicked: QGroundControl.startPX4MockLink(_mockSendStatus.checked) }
                    QGCButton { Layout.fillWidth: true; text: qsTr("Generic Vehicle"); onClicked: QGroundControl.startGenericMockLink(_mockSendStatus.checked) }
                    QGCButton { Layout.fillWidth: true; text: qsTr("APM ArduCopter"); visible: QGroundControl.hasAPMSupport; onClicked: QGroundControl.startAPMArduCopterMockLink(_mockSendStatus.checked) }
                    QGCButton { Layout.fillWidth: true; text: qsTr("APM ArduPlane"); visible: QGroundControl.hasAPMSupport; onClicked: QGroundControl.startAPMArduPlaneMockLink(_mockSendStatus.checked) }
                    QGCButton { Layout.fillWidth: true; text: qsTr("APM ArduSub"); visible: QGroundControl.hasAPMSupport; onClicked: QGroundControl.startAPMArduSubMockLink(_mockSendStatus.checked) }
                    QGCButton { Layout.fillWidth: true; text: qsTr("APM ArduRover"); visible: QGroundControl.hasAPMSupport; onClicked: QGroundControl.startAPMArduRoverMockLink(_mockSendStatus.checked) }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

                QGCButton { Layout.fillWidth: true; text: qsTr("Stop One MockLink"); onClicked: QGroundControl.stopOneMockLink() }
            }

            // ════════════════════════════════════════════════
            // BRAND IMAGES & ADVANCED
            // ════════════════════════════════════════════════

            SettingsCard {
                Layout.fillWidth: true
                iconSrc: "/InstrumentValueIcons/cog.svg"
                heading: "Advanced"
                keywords: "brand images logo indoor outdoor icon custom"

                // Brand Images
                QGCLabel { text: "Brand Images"; color: _teal; font.pointSize: _fontPt * 0.8; font.bold: true; visible: _brandImageSettings.visible && !ScreenTools.isMobile }

                RowLayout {
                    Layout.fillWidth: true; spacing: ScreenTools.defaultFontPixelWidth * 2
                    visible: _brandImageSettings.visible && _brandImageSettings.userBrandImageIndoor.visible && !ScreenTools.isMobile
                    ColumnLayout { Layout.fillWidth: true; spacing: 0
                        QGCLabel { text: qsTr("Indoor Image") }
                        QGCLabel { Layout.fillWidth: true; font.pointSize: ScreenTools.smallFontPointSize; text: _brandImageSettings.userBrandImageIndoor.valueString.replace("file:///", ""); elide: Text.ElideMiddle; visible: _brandImageSettings.userBrandImageIndoor.valueString.length > 0 }
                    }
                    QGCButton { text: qsTr("Browse"); onClicked: _indoorBrowse.openForLoad()
                        QGCFileDialog { id: _indoorBrowse; title: qsTr("Choose custom brand image file"); folder: _brandImageSettings.userBrandImageIndoor.rawValue.replace("file:///", ""); selectFolder: false; onAcceptedForLoad: (file) => _brandImageSettings.userBrandImageIndoor.rawValue = "file:///" + file }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: ScreenTools.defaultFontPixelWidth * 2
                    visible: _brandImageSettings.visible && _brandImageSettings.userBrandImageOutdoor.visible && !ScreenTools.isMobile
                    ColumnLayout { Layout.fillWidth: true; spacing: 0
                        QGCLabel { text: qsTr("Outdoor Image") }
                        QGCLabel { Layout.fillWidth: true; font.pointSize: ScreenTools.smallFontPointSize; text: _brandImageSettings.userBrandImageOutdoor.valueString.replace("file:///", ""); elide: Text.ElideMiddle; visible: _brandImageSettings.userBrandImageOutdoor.valueString.length > 0 }
                    }
                    QGCButton { text: qsTr("Browse"); onClicked: _outdoorBrowse.openForLoad()
                        QGCFileDialog { id: _outdoorBrowse; title: qsTr("Choose custom brand image file"); folder: _brandImageSettings.userBrandImageOutdoor.rawValue.replace("file:///", ""); selectFolder: false; onAcceptedForLoad: (file) => _brandImageSettings.userBrandImageOutdoor.rawValue = "file:///" + file }
                    }
                }

                LabelledButton {
                    Layout.fillWidth: true; label: qsTr("Reset Images"); buttonText: qsTr("Reset")
                    visible: _brandImageSettings.visible && !ScreenTools.isMobile
                    onClicked: { _brandImageSettings.userBrandImageIndoor.rawValue = ""; _brandImageSettings.userBrandImageOutdoor.rawValue = "" }
                }
            }

            // ════════════════════════════════════════════════════════
            // ABOUT
            // ════════════════════════════════════════════════════════
            Rectangle {
                id: _aboutCard
                Layout.fillWidth: true
                implicitHeight:   _aboutLayout.implicitHeight + _pad * 3
                radius:           _fontSize * 0.6
                color:            _cardBg
                border.color:     Qt.rgba(1, 1, 1, 0.06)
                border.width:     1

                // Search filtering
                readonly property bool _searchMatch: _root._searchText.length === 0 ||
                    ("about hilmos version platform support website hilmtec tameem"
                        .indexOf(_root._searchText.toLowerCase()) >= 0)
                Binding {
                    when:        _root._searchText.length > 0 && !_aboutCard._searchMatch
                    target:      _aboutCard
                    property:    "visible"
                    value:       false
                    restoreMode: Binding.RestoreBindingOrValue
                }

                ColumnLayout {
                    id:              _aboutLayout
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: _pad * 1.5
                    spacing:         _pad * 0.9

                    // ── Card header: icon + title
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.9

                        Rectangle {
                            width: _fontSize * 2.4; height: width
                            radius: _fontSize * 0.4; color: _tealDim
                            QGCColoredImage {
                                anchors.centerIn: parent
                                width: _fontSize * 1.3; height: width
                                source: "/InstrumentValueIcons/information-outline.svg"
                                color: _teal; fillMode: Image.PreserveAspectFit
                            }
                        }
                        QGCLabel {
                            text: "About HILMOS"; color: "white"
                            font.pointSize: _fontPt * 1.25; font.bold: true; font.letterSpacing: 0.5
                        }
                        Item { Layout.fillWidth: true }
                    }

                    // ── Meta rows
                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel { text: "Version:";  color: _dimText; font.pointSize: _fontPt * 0.8; Layout.preferredWidth: _pad * 6 }
                        Item { Layout.fillWidth: true }
                        QGCLabel { text: "1.0.0 MVP (March 2026)"; color: "white"; font.pointSize: _fontPt * 0.8; font.bold: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel { text: "Platform:"; color: _dimText; font.pointSize: _fontPt * 0.8; Layout.preferredWidth: _pad * 6 }
                        Item { Layout.fillWidth: true }
                        QGCLabel { text: "QGroundControl Integration"; color: "white"; font.pointSize: _fontPt * 0.8; font.bold: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel { text: "Email:";   color: _dimText; font.pointSize: _fontPt * 0.8; Layout.preferredWidth: _pad * 6 }
                        Item { Layout.fillWidth: true }
                        QGCLabel {
                            text: "tameem@hilmtec.com"; color: _teal
                            font.pointSize: _fontPt * 0.8; font.bold: true
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("mailto:tameem@hilmtec.com") }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel { text: "Website:"; color: _dimText; font.pointSize: _fontPt * 0.8; Layout.preferredWidth: _pad * 6 }
                        Item { Layout.fillWidth: true }
                        QGCLabel {
                            text: "www.hilmtec.com"; color: _teal
                            font.pointSize: _fontPt * 0.8; font.bold: true
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("https://www.hilmtec.com/") }
                        }
                    }

                    // ── Divider
                    Rectangle {
                        Layout.fillWidth: true; Layout.topMargin: _pad * 0.2; Layout.bottomMargin: _pad * 0.2
                        height: 1; color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // ── Tagline
                    QGCLabel {
                        Layout.fillWidth: true; Layout.bottomMargin: _pad * 0.3
                        text: "HILMOS AI Co-Pilot \u2014 Intelligent autonomous drone surveillance for security patrols, " +
                              "emergency response, and mixed-fleet management. Eliminating vendor lock-in, one mission at a time."
                        color: Qt.rgba(0, 0.749, 1.0, 0.65)
                        font.pointSize: _fontPt * 0.72; wrapMode: Text.WordWrap; lineHeight: 1.45
                    }
                }
            }

            // Bottom spacer
            Item { Layout.fillWidth: true; height: _pad * 2 }

        } // end ColumnLayout
    } // end QGCFlickable

    // ════════════════════════════════════════════════════════
    // LOGGING FILTERS DIALOG
    // ════════════════════════════════════════════════════════

    Component {
        id: _loggingFiltersDialog

        QGCPopupDialog {
            title:   qsTr("Logging")
            buttons: Dialog.Close

            ColumnLayout {
                width: maxContentAvailableWidth

                SettingsGroupLayout {
                    heading:          qsTr("Search")
                    Layout.fillWidth: true

                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          ScreenTools.defaultFontPixelHeight / 2

                        QGCTextField {
                            id:               _logSearchText
                            Layout.fillWidth: true
                            text:             ""
                        }

                        QGCButton {
                            text:      qsTr("Clear")
                            onClicked: _logSearchText.text = ""
                        }
                    }
                }

                SettingsGroupLayout {
                    heading:          qsTr("Enabled Categories")
                    Layout.fillWidth: true

                    Flow {
                        Layout.fillWidth: true
                        spacing:          ScreenTools.defaultFontPixelHeight / 2

                        Repeater {
                            model: QGroundControl.flatLoggingCategoriesModel()

                            QGCCheckBoxSlider {
                                Layout.fillWidth:     true
                                Layout.maximumHeight: visible ? implicitHeight : 0
                                text:                 object.fullCategory
                                visible:              object.enabled
                                checked:              object.enabled
                                onClicked:            object.enabled = checked
                            }
                        }

                        QGCButton {
                            text:      qsTr("Disable All")
                            onClicked: QGroundControl.disableAllLoggingCategories()
                        }
                    }
                }

                // Tree view (shown when not filtering)
                Flow {
                    Layout.fillWidth: true
                    spacing:          ScreenTools.defaultFontPixelHeight / 2
                    visible:          _logSearchText.text === ""

                    Repeater {
                        model: QGroundControl.treeLoggingCategoriesModel()

                        ColumnLayout {
                            spacing: ScreenTools.defaultFontPixelHeight / 2

                            RowLayout {
                                spacing: ScreenTools.defaultFontPixelWidth

                                QGCLabel {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth
                                    text:                  object.expanded ? qsTr("-") : qsTr("+")
                                    horizontalAlignment:   Text.AlignLeft
                                    visible:               object.children

                                    QGCMouseArea {
                                        anchors.fill: parent
                                        onClicked:    object.expanded = !object.expanded
                                    }
                                }

                                QGCCheckBoxSlider {
                                    Layout.fillWidth: true
                                    text:             object.shortCategory
                                    checked:          object.enabled
                                    onClicked:        object.enabled = checked
                                }
                            }

                            Repeater {
                                model: object.expanded ? object.children : undefined

                                QGCCheckBoxSlider {
                                    Layout.fillWidth: true
                                    text:             "   " + object.shortCategory
                                    checked:          object.enabled
                                    onClicked:        object.enabled = checked
                                }
                            }
                        }
                    }
                }

                // Flat filtered view (shown when searching)
                Flow {
                    Layout.fillWidth: true
                    spacing:          ScreenTools.defaultFontPixelHeight / 2
                    visible:          _logSearchText.text !== ""

                    Repeater {
                        model: QGroundControl.flatLoggingCategoriesModel()

                        QGCCheckBoxSlider {
                            Layout.fillWidth:     true
                            Layout.maximumHeight: visible ? implicitHeight : 0
                            text:                 object.fullCategory
                            visible:              text.match(`(${_logSearchText.text})`, "i")
                            checked:              object.enabled
                            onClicked:            object.enabled = checked
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════
    // LINK EDIT DIALOG
    // ════════════════════════════════════════════════════════

    Component {
        id: _linkDialogComponent

        QGCPopupDialog {
            title:                  originalConfig ? qsTr("Edit Link") : qsTr("Add New Link")
            buttons:                Dialog.Save | Dialog.Cancel
            acceptButtonEnabled:    _linkNameField.text !== ""

            property var originalConfig
            property var editingConfig

            onAccepted: {
                _linkSettingsLoader.item.saveSettings()
                editingConfig.name = _linkNameField.text
                if (originalConfig) {
                    QGroundControl.linkManager.endConfigurationEditing(originalConfig, editingConfig)
                } else {
                    editingConfig.dynamic = false
                    QGroundControl.linkManager.endCreateConfiguration(editingConfig)
                }
            }

            onRejected: QGroundControl.linkManager.cancelConfigurationEditing(editingConfig)

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                RowLayout {
                    Layout.fillWidth: true; spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("Name") }
                    QGCTextField { id: _linkNameField; Layout.fillWidth: true; text: editingConfig.name; placeholderText: qsTr("Enter name") }
                }

                QGCCheckBoxSlider { Layout.fillWidth: true; text: qsTr("Automatically Connect on Start"); checked: editingConfig.autoConnect; onCheckedChanged: editingConfig.autoConnect = checked }
                QGCCheckBoxSlider { Layout.fillWidth: true; text: qsTr("High Latency"); checked: editingConfig.highLatency; onCheckedChanged: editingConfig.highLatency = checked }

                LabelledComboBox {
                    label: qsTr("Type"); enabled: originalConfig == null
                    model: QGroundControl.linkManager.linkTypeStrings
                    Component.onCompleted: comboBox.currentIndex = editingConfig.linkType
                    onActivated: (index) => { if (index !== editingConfig.linkType) { var name = _linkNameField.text; editingConfig = QGroundControl.linkManager.createConfiguration(index, name) } }
                }

                Loader {
                    id: _linkSettingsLoader; source: subEditConfig.settingsURL
                    property var subEditConfig:      editingConfig
                    property int _firstColumnWidth:  ScreenTools.defaultFontPixelWidth * 12
                    property int _secondColumnWidth: ScreenTools.defaultFontPixelWidth * 30
                    property int _rowSpacing:        ScreenTools.defaultFontPixelHeight / 2
                    property int _colSpacing:        ScreenTools.defaultFontPixelWidth / 2
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════
    // INLINE COMPONENTS
    // ════════════════════════════════════════════════════════

    // Settings section card
    component SettingsCard: Rectangle {
        id: _card
        default property alias content: _cardContent.data
        property string heading: ""
        property string headingDesc: ""
        property string iconSrc: ""
        property bool   hasAction: false
        property string actionText: ""
        property string actionIcon: ""
        property bool   actionIsLabel: false

        signal actionClicked()

        // Search filtering: set keywords for terms beyond the heading
        property string keywords: ""
        readonly property bool _searchMatch: _root._searchText.length === 0 ||
            (heading.toLowerCase() + " " + keywords.toLowerCase())
                .indexOf(_root._searchText.toLowerCase()) >= 0

        // Override visible when search is active and this card doesn't match;
        // restores the original external visible binding when search clears.
        Binding {
            when:        _root._searchText.length > 0 && !_card._searchMatch
            target:      _card
            property:    "visible"
            value:       false
            restoreMode: Binding.RestoreBindingOrValue
        }

        radius: _fontSize * 0.6
        color: _cardBg
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        implicitHeight: _cardContent.height + _pad * 4

        ColumnLayout {
            id: _cardContent
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: _pad * 2.5
            spacing: _pad * 1.5

            // Header row
            RowLayout {
                Layout.fillWidth: true; spacing: _pad

                Rectangle {
                    visible: iconSrc !== ""; width: _fontSize * 2.4; height: width
                    radius: _fontSize * 0.4; color: _tealDim
                    QGCColoredImage { anchors.centerIn: parent; width: _fontSize * 1.3; height: width; source: iconSrc; color: _teal; fillMode: Image.PreserveAspectFit }
                }

                ColumnLayout {
                    spacing: 2
                    QGCLabel { text: heading; color: "white"; font.pointSize: _fontPt * 1.25; font.bold: true; font.letterSpacing: 0.5 }
                    QGCLabel { text: headingDesc; color: _dimText; font.pointSize: _fontPt * 0.8; visible: headingDesc !== "" }
                }

                Item { Layout.fillWidth: true }

                // Action button / label
                Rectangle {
                    visible: hasAction && !actionIsLabel
                    width: _actionRow.implicitWidth + _pad * 3; height: _fontSize * 2.6
                    radius: _fontSize * 0.4; color: _tealDim; border.color: _tealBorder; border.width: 1
                    RowLayout { id: _actionRow; anchors.centerIn: parent; spacing: _pad * 0.5
                        QGCColoredImage { visible: actionIcon !== ""; width: _fontSize * 1.0; height: width; source: actionIcon; color: _teal; fillMode: Image.PreserveAspectFit }
                        QGCLabel { text: actionText; color: _teal; font.pointSize: _fontPt * 0.7; font.bold: true; font.letterSpacing: 0.5 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: _card.actionClicked() }
                }

                QGCLabel { visible: hasAction && actionIsLabel; text: actionText; color: _teal; font.pointSize: _fontPt * 0.7 }
            }
        }
    }

    // Model info row (label: value)
    component ModelInfoRow: RowLayout {
        property string label
        property string value
        property color  valueColor: "white"
        Layout.fillWidth: true; spacing: _pad
        Layout.topMargin: _pad * 0.3; Layout.bottomMargin: _pad * 0.3
        QGCLabel { text: label; color: _dimText; font.pointSize: _fontPt * 0.8 }
        Item { Layout.fillWidth: true }
        QGCLabel { text: value; color: valueColor; font.pointSize: _fontPt * 0.8; font.bold: true }
    }

    // Setting row with label + description + control slot
    component HilmSettingRow: RowLayout {
        property string label
        property string description: ""
        spacing: _pad * 1.5
        Layout.topMargin: _pad * 0.4; Layout.bottomMargin: _pad * 0.4
        ColumnLayout { Layout.fillWidth: true; spacing: 2
            QGCLabel { text: label; color: "white"; font.pointSize: _fontPt * 1.0; font.bold: true }
            QGCLabel { text: description; color: _dimText; font.pointSize: _fontPt * 0.8; visible: description !== ""; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
    }

    // HILM-styled ComboBox
    component HilmComboBox: QGCComboBox {
        font.pointSize: _fontPt * 0.9
    }

    // Resource usage bar
    component ResourceBar: ColumnLayout {
        property string label
        property int    value: 0
        property color  barColor: _teal
        property string suffix: ""
        spacing: _pad * 0.2

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: label; color: _dimText; font.pointSize: _fontPt * 0.7 }
            Item { Layout.fillWidth: true }
            QGCLabel { text: suffix !== "" ? suffix : (value + "%"); color: "white"; font.pointSize: _fontPt * 0.7; font.bold: true }
        }

        Rectangle {
            Layout.fillWidth: true; height: _fontSize * 0.4; radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.08)
            Rectangle {
                width: Math.max(0, Math.min(1, value / 100)) * parent.width
                height: parent.height; radius: parent.radius; color: barColor
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            }
        }
    }
}
