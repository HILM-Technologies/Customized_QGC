import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.UTMSP

// ─────────────────────────────────────────────────────────────────────────────
//  PlanToolBarIndicators  –  HILM futuristic pill-style action buttons
// ─────────────────────────────────────────────────────────────────────────────
RowLayout {
    required property var planMasterController

    id:      root
    spacing: Math.round(ScreenTools.defaultFontPixelWidth * 0.6)

    property var  _planMasterController:  planMasterController
    property var  _missionController:     _planMasterController.missionController
    property var  _geoFenceController:    _planMasterController.geoFenceController
    property var  _rallyPointController:  _planMasterController.rallyPointController
    property bool _controllerOffline:     _planMasterController.offline
    property var  _controllerDirty:       _planMasterController.dirty
    property var  _syncInProgress:        _planMasterController.syncInProgress
    property var  _visualItems:           _missionController.visualItems
    property bool _hasPlanItems:          _planMasterController.containsItems
    property bool _utmspEnabled:          QGroundControl.utmspSupported

    // ── Design tokens ─────────────────────────────────────────────────────────
    readonly property color _teal:       "#00C8C8"
    readonly property color _tealDim:    Qt.rgba(0, 0.784, 0.784, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property color _pillBg:     Qt.rgba(0, 0.15, 0.15, 0.25)
    readonly property real  _pillH:      Math.round(ScreenTools.defaultFontPixelHeight * 1.75)
    readonly property real  _pillR:      _pillH / 2
    readonly property real  _hpad:       ScreenTools.defaultFontPixelWidth
    readonly property real  _fsize:      Math.round(ScreenTools.defaultFontPixelHeight * 0.72)

    // ── Button actions ────────────────────────────────────────────────────────
    function _uploadClicked() {
        if (_utmspEnabled) {
            QGroundControl.utmspManager.utmspVehicle.triggerActivationStatusBar(true);
            UTMSPStateStorage.removeFlightPlanState = true
            UTMSPStateStorage.indicatorDisplayStatus = true
        }
        _planMasterController.upload();
    }

    function _downloadClicked() {
        if (_planMasterController.dirty) {
            mainWindow.showMessageDialog(qsTr("Download"),
                                         qsTr("You have unsaved/unsent changes. Downloading from the Vehicle will lose these changes. Are you sure?"),
                                         Dialog.Yes | Dialog.Cancel,
                                         function() { _planMasterController.loadFromVehicle() })
        } else {
            _planMasterController.loadFromVehicle()
        }
    }

    function _openButtonClicked() {
        if (_planMasterController.dirty) {
            mainWindow.showMessageDialog(qsTr("Open Plan"),
                                        qsTr("You have unsaved/unsent changes. Loading a new Plan will lose these changes. Are you sure?"),
                                        Dialog.Yes | Dialog.Cancel,
                                        function() { _planMasterController.loadFromSelectedFile() } )
        } else {
            _planMasterController.loadFromSelectedFile()
        }
    }

    function _saveButtonClicked() {
        if(_planMasterController.currentPlanFile !== "") {
            _planMasterController.saveToCurrent()
            mainWindow.showMessageDialog(qsTr("Save"),
                                        qsTr("Plan saved to `%1`").arg(_planMasterController.currentPlanFile),
                                        Dialog.Ok)
        } else {
            _planMasterController.saveToSelectedFile()
        }
    }

    function _saveAsKMLClicked() {
        if (_visualItems.count > 1) {
            _planMasterController.saveKmlToSelectedFile()
        }
    }

    function _storageClearButtonClicked() {
        mainWindow.showMessageDialog(qsTr("Clear"),
                                     qsTr("Are you sure you want to remove all the items from the plan editor?"),
                                     Dialog.Yes | Dialog.Cancel,
                                     function() { _planMasterController.removeAll(); })
    }

    function _vehicleClearButtonClicked() {
        mainWindow.showMessageDialog(qsTr("Clear"),
                                     qsTr("Are you sure you want to remove the plan from the vehicle and the plan editor?"),
                                     Dialog.Yes | Dialog.Cancel,
                                     function() {
                                        _planMasterController.removeAllFromVehicle();
                                        if (_utmspEnabled) {
                                            _resetRegisterFlightPlan = true;
                                            QGroundControl.utmspManager.utmspVehicle.triggerActivationStatusBar(false);
                                            UTMSPStateStorage.startTimeStamp = "";
                                            UTMSPStateStorage.showActivationTab = false;
                                            UTMSPStateStorage.flightID = "";
                                            UTMSPStateStorage.enableMissionUploadButton = false;
                                            UTMSPStateStorage.indicatorPendingStatus = true;
                                            UTMSPStateStorage.indicatorApprovedStatus = false;
                                            UTMSPStateStorage.indicatorActivatedStatus = false;
                                            UTMSPStateStorage.currentStateIndex = 0}})
    }

    function _clearClicked() {
        if (_planMasterController.offline) {
            _storageClearButtonClicked();
        } else {
            _vehicleClearButtonClicked();
        }
    }

    QGCPalette { id: qgcPal }

    // ── OPEN ──────────────────────────────────────────────────────────────────
    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        height:           _pillH
        width:            openLabel.implicitWidth + _hpad * 2.5
        radius:           _pillR
        color:            openHover.containsMouse ? _tealDim : _pillBg
        border.color:     _tealBorder
        border.width:     1
        opacity:          !_planMasterController.syncInProgress ? 1.0 : 0.35

        Text {
            id:               openLabel
            anchors.centerIn: parent
            text:             qsTr("OPEN")
            color:            "#FFFFFF"
            font.pixelSize:   _fsize
            font.letterSpacing: 1.2
        }

        MouseArea {
            id:           openHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            enabled:      !_planMasterController.syncInProgress
            onClicked:    _openButtonClicked()
        }
    }

    // ── SAVE / SAVE AS ────────────────────────────────────────────────────────
    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        height:           _pillH
        width:            saveLabel.implicitWidth + _hpad * 2.5
        radius:           _pillR
        color:            saveHover.containsMouse
                              ? Qt.rgba(0, 0.784, 0.784, 0.22)
                              : (_controllerDirty ? _tealDim : _pillBg)
        border.color:     _controllerDirty ? _teal : _tealBorder
        border.width:     1
        opacity:          (!_syncInProgress && _hasPlanItems) ? 1.0 : 0.35

        Text {
            id:               saveLabel
            anchors.centerIn: parent
            text:             _planMasterController.currentPlanFile === "" ? qsTr("SAVE AS") : qsTr("SAVE")
            color:            _controllerDirty ? _teal : Qt.rgba(1, 1, 1, 0.85)
            font.pixelSize:   _fsize
            font.letterSpacing: 1.2
        }

        MouseArea {
            id:           saveHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            enabled:      !_syncInProgress && _hasPlanItems
            onClicked:    _saveButtonClicked()
        }
    }

    // ── UPLOAD ────────────────────────────────────────────────────────────────
    Rectangle {
        id:               uploadPill
        Layout.alignment: Qt.AlignVCenter
        height:           _pillH
        width:            uploadLabel.implicitWidth + _hpad * 2.5
        radius:           _pillR
        visible:          !_syncInProgress

        property bool _enabled: _utmspEnabled
            ? (!_syncInProgress && UTMSPStateStorage.enableMissionUploadButton)
            : (!_syncInProgress && _hasPlanItems)

        color: !_enabled
                   ? Qt.rgba(0, 0.2, 0.2, 0.12)
                   : (uploadHover.containsMouse
                      ? Qt.rgba(0, 0.784, 0.784, 0.35)
                      : Qt.rgba(0, 0.784, 0.784, 0.22))
        border.color: _enabled ? _teal : _tealBorder
        border.width: 1

        Text {
            id:               uploadLabel
            anchors.centerIn: parent
            text:             qsTr("UPLOAD")
            color:            uploadPill._enabled ? _teal : Qt.rgba(1, 1, 1, 0.32)
            font.pixelSize:   _fsize
            font.letterSpacing: 1.2
            font.bold:        uploadPill._enabled
        }

        MouseArea {
            id:           uploadHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            enabled:      uploadPill._enabled
            onClicked:    _uploadClicked()
        }
    }

    // ── CLEAR ─────────────────────────────────────────────────────────────────
    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        height:           _pillH
        width:            clearLabel.implicitWidth + _hpad * 2.5
        radius:           _pillR
        color:            clearHover.containsMouse ? Qt.rgba(1, 0.18, 0.18, 0.18) : _pillBg
        border.color:     clearHover.containsMouse ? Qt.rgba(1, 0.32, 0.32, 0.6) : _tealBorder
        border.width:     1
        opacity:          !_syncInProgress ? 1.0 : 0.35

        Text {
            id:               clearLabel
            anchors.centerIn: parent
            text:             qsTr("CLEAR")
            color:            clearHover.containsMouse ? "#FF6B6B" : Qt.rgba(1, 1, 1, 0.85)
            font.pixelSize:   _fsize
            font.letterSpacing: 1.2
        }

        MouseArea {
            id:           clearHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            enabled:      !_syncInProgress
            onClicked:    _clearClicked()
        }
    }

    // ── MORE OPTIONS (≡) ──────────────────────────────────────────────────────
    Rectangle {
        id:               hamburgerPill
        Layout.alignment: Qt.AlignVCenter
        height:           _pillH
        width:            _pillH * 1.15
        radius:           _pillR
        color:            hamburgerHover.containsMouse ? _tealDim : _pillBg
        border.color:     _tealBorder
        border.width:     1

        // Three horizontal lines (hamburger icon)
        Column {
            anchors.centerIn: parent
            spacing:          3.5

            Repeater {
                model: 3
                Rectangle {
                    width:  Math.round(_pillH * 0.40)
                    height: 1.5
                    radius: 1
                    color:  Qt.rgba(1, 1, 1, 0.82)
                }
            }
        }

        MouseArea {
            id:           hamburgerHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked: {
                let position = Qt.point(hamburgerPill.width, hamburgerPill.height / 2)
                position = hamburgerPill.mapToItem(globals.parent, position)
                var dropPanel = hamburgerDropPanelComponent.createObject(
                    mainWindow, { clickRect: Qt.rect(position.x, position.y, 0, 0) })
                dropPanel.open()
            }
        }
    }

    // ── Hamburger drop panel ──────────────────────────────────────────────────
    Component {
        id: hamburgerDropPanelComponent

        DropPanel {
            id: dropPanel

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 2

                    QGCButton {
                        Layout.fillWidth: true
                        text:    qsTr("Save as KML")
                        enabled: !_syncInProgress && _hasPlanItems

                        onClicked: {
                            dropPanel.close()
                            _saveAsKMLClicked()
                        }
                    }

                    QGCButton {
                        Layout.fillWidth: true
                        text:    qsTr("Download")
                        enabled: _utmspEnabled ? !_syncInProgress && UTMSPStateStorage.enableMissionDownloadButton : !_syncInProgress
                        visible: !_syncInProgress

                        onClicked: {
                            dropPanel.close()
                            _downloadClicked()
                        }
                    }
                }
            }
        }
    }
}
