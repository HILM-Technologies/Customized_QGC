/****************************************************************************
 *
 * HILM Ground Control — Fleet Panel (Left Side — Full Height)
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Item {
    id: fleetPanel

    property bool _expanded: true
    readonly property real _expandedWidth: ScreenTools.defaultFontPixelWidth * 44
    readonly property real _collapsedWidth: ScreenTools.defaultFontPixelWidth * 2.5

    width: _expanded ? _expandedWidth : _collapsedWidth

    Behavior on width {
        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
    }

    // HILM design tokens
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)
    readonly property real  _pad:        ScreenTools.defaultFontPixelWidth

    property var _vehicleModel: QGroundControl.multiVehicleManager.vehicles

    // ── Multi-selection state
    property var  selectedVehicles: []
    property int  _selectionRev:    0          // bump to trigger binding updates

    function isVehicleSelected(vehicle) {
        // Read _selectionRev so bindings re-evaluate
        void _selectionRev
        if (!vehicle) return false
        for (var i = 0; i < selectedVehicles.length; i++) {
            if (selectedVehicles[i] === vehicle) return true
        }
        return false
    }

    function toggleVehicleSelection(vehicle) {
        if (!vehicle) return
        var idx = -1
        for (var i = 0; i < selectedVehicles.length; i++) {
            if (selectedVehicles[i] === vehicle) { idx = i; break }
        }
        if (idx !== -1)
            selectedVehicles.splice(idx, 1)
        else
            selectedVehicles.push(vehicle)
        _selectionRev++
        selectedVehiclesChanged()
    }

    function selectAll() {
        selectedVehicles = []
        if (_vehicleModel) {
            for (var i = 0; i < _vehicleModel.count; i++)
                selectedVehicles.push(_vehicleModel.get(i))
        }
        _selectionRev++
        selectedVehiclesChanged()
    }

    function unselectAll() {
        selectedVehicles = []
        _selectionRev++
        selectedVehiclesChanged()
    }

    property bool _allSelected: {
        void _selectionRev
        return _vehicleModel
            ? (selectedVehicles.length === _vehicleModel.count && _vehicleModel.count > 0)
            : false
    }

    property bool _hasSelection: {
        void _selectionRev
        return selectedVehicles.length > 0
    }

    // ── Main panel body (stops before collapse handle)
    Rectangle {
        id: panelBody
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        anchors.right:  collapseHandle.left
        radius:         ScreenTools.defaultFontPixelHeight * 0.4
        color:          Qt.rgba(0, 0, 0, 0.80)
        border.width:   1
        border.color:   Qt.rgba(1, 1, 1, 0.06)
        clip:           true
        visible:        _expanded

        ColumnLayout {
            id:              panelContent
            anchors.fill:    parent
            anchors.margins: _pad * 1.2
            spacing:         _pad * 0.8

            // ── Header: title on left, circle badge on right
            Item {
                Layout.fillWidth:   true
                Layout.preferredHeight: titleLabel.implicitHeight

                QGCLabel {
                    id:                 titleLabel
                    anchors.left:       parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text:               "MULTI-DRONE FLEET"
                    color:              _teal
                    font.pointSize:     ScreenTools.defaultFontPointSize * 0.85
                    font.bold:          true
                    font.letterSpacing: 0.8
                }

                // Drone count: bullet + number
                Row {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing:                _pad * 0.4

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:   ScreenTools.defaultFontPixelHeight * 0.75
                        height:  width
                        radius:  width / 2
                        color:   "transparent"
                        border.width: 0.5
                        border.color: _teal
                    }

                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text:           _vehicleModel ? _vehicleModel.count : "0"
                        color:          _teal
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.85
                        font.bold:      true
                    }
                }
            }

            // ── Select All / Unselect All bar
            Item {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.6
                visible:                _vehicleModel && _vehicleModel.count > 0

                // Selected count (left)
                QGCLabel {
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   _hasSelection
                                                ? selectedVehicles.length + " of " + _vehicleModel.count + " selected"
                                                : _vehicleModel.count + " drones"
                    color:                  _hasSelection ? _teal : _dimText
                    font.pointSize:         ScreenTools.defaultFontPointSize * 0.7
                    font.letterSpacing:     0.3
                }

                // Select All / Unselect All button (right)
                Rectangle {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width:                  selectAllLabel.implicitWidth + _pad * 2
                    height:                 ScreenTools.defaultFontPixelHeight * 1.5
                    radius:                 height / 2
                    color:                  selectAllArea.containsMouse
                                                ? Qt.rgba(0, 0.749, 1.0, 0.15)
                                                : "transparent"
                    border.width:           1
                    border.color:           selectAllArea.containsMouse
                                                ? _teal
                                                : Qt.rgba(0, 0.749, 1.0, 0.25)

                    QGCLabel {
                        id:                 selectAllLabel
                        anchors.centerIn:   parent
                        text:               _allSelected ? "UNSELECT ALL" : "SELECT ALL"
                        color:              _teal
                        font.pointSize:     ScreenTools.defaultFontPointSize * 0.65
                        font.bold:          true
                        font.letterSpacing: 0.5
                    }

                    MouseArea {
                        id:           selectAllArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    _allSelected ? unselectAll() : selectAll()
                    }
                }
            }

            // ── Vehicle List (scrollable, fills remaining space)
            QGCFlickable {
                Layout.fillWidth:   true
                Layout.fillHeight:  true
                contentHeight:      vehicleColumn.implicitHeight
                clip:               true

                ColumnLayout {
                    id:     vehicleColumn
                    width:  parent.width
                    spacing: _pad * 1.5

                    Repeater {
                        model: _vehicleModel

                        delegate: HilmDroneCard {
                            Layout.fillWidth: true
                            vehicle:          object
                            isMultiSelected:  fleetPanel.isVehicleSelected(object)

                            onSelectionToggled: function(v) {
                                fleetPanel.toggleVehicleSelection(v)
                            }
                        }
                    }

                    // Empty state
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 8
                        visible: !_vehicleModel || _vehicleModel.count === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: _pad * 1.2

                            QGCColoredImage {
                                Layout.alignment: Qt.AlignHCenter
                                width:            ScreenTools.defaultFontPixelHeight * 2.5
                                height:           width
                                source:           "/qmlimages/Quad.svg"
                                color:            _dimText
                                fillMode:         Image.PreserveAspectFit
                            }
                            QGCLabel {
                                Layout.alignment: Qt.AlignHCenter
                                text:             "No drones connected"
                                color:            _dimText
                                font.pointSize:   ScreenTools.defaultFontPointSize * 0.65
                            }
                            QGCLabel {
                                Layout.alignment: Qt.AlignHCenter
                                text:             "Connect a vehicle to see fleet"
                                color:            Qt.rgba(1, 1, 1, 0.3)
                                font.pointSize:   ScreenTools.defaultFontPointSize * 0.55
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Collapse / Expand handle (overlaps right edge of panel)
    Rectangle {
        id:                     collapseHandle
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter
        width:                  ScreenTools.defaultFontPixelWidth * 2.5
        height:                 ScreenTools.defaultFontPixelHeight * 4
        radius:                 ScreenTools.defaultFontPixelHeight * 0.3
        color:                  handleMouse.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.18) : Qt.rgba(0, 0, 0, 0.70)
        border.width:           1
        border.color:           _tealBorder
        z:                      1   // above panel body

        Text {
            anchors.centerIn: parent
            text:             _expanded ? "\u25C0" : "\u25B6"
            color:            _teal
            font.pointSize:   ScreenTools.defaultFontPointSize * 0.7
        }

        MouseArea {
            id:             handleMouse
            anchors.fill:   parent
            hoverEnabled:   true
            onClicked:      _expanded = !_expanded
        }
    }
}
