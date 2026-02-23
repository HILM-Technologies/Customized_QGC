import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// ─────────────────────────────────────────────────────────────────────────────
//  GeoFenceEditor  –  HILM teal-themed geo-fence configuration panel
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root
    height: mainCol.height

    property var myGeoFenceController
    property var flightMap

    // ── Design tokens (HILM palette) ─────────────────────────────────────────
    readonly property color _teal:           "#00C8C8"
    readonly property color _tealDim:        Qt.rgba(0, 0.784, 0.784, 0.14)
    readonly property color _tealBorder:     Qt.rgba(0, 0.784, 0.784, 0.32)
    readonly property color _cardBg:         Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:        Qt.rgba(1, 1, 1, 0.50)
    readonly property real  _r:              ScreenTools.defaultFontPixelWidth * 0.7
    readonly property real  _pad:            ScreenTools.defaultFontPixelWidth
    readonly property real  _gap:            ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real  _editFieldWidth: Math.min(width - _pad * 2, ScreenTools.defaultFontPixelWidth * 15)

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Column {
        id:      mainCol
        width:   parent.width
        spacing: _gap

        // ╔══════════════════════════════════════════════════════════════════╗
        //  HEADER CARD
        // ╚══════════════════════════════════════════════════════════════════╝
        Rectangle {
            width:        parent.width
            height:       ScreenTools.defaultFontPixelHeight * 4.2
            radius:       _r
            color:        _tealDim
            border.color: _tealBorder
            border.width: 1

            Rectangle {
                id:                     hAccentBar
                width:                  3
                height:                 parent.height * 0.55
                radius:                 2
                color:                  _teal
                anchors.left:           parent.left
                anchors.leftMargin:     _pad
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.left:           hAccentBar.right
                anchors.leftMargin:     _pad * 0.75
                anchors.right:          parent.right
                anchors.rightMargin:    _pad
                anchors.verticalCenter: parent.verticalCenter
                spacing:                3

                Text {
                    width:              parent.width
                    text:               qsTr("GEO FENCE")
                    color:              _teal
                    font.bold:          true
                    font.letterSpacing: 2.0
                    font.pointSize:     ScreenTools.defaultFontPointSize * 0.85
                    elide:              Text.ElideRight
                }
                Text {
                    width:          parent.width
                    text:           qsTr("Define virtual boundaries for safe flight operations")
                    color:          _dimText
                    font.pointSize: ScreenTools.smallFontPointSize
                    wrapMode:       Text.NoWrap
                    elide:          Text.ElideRight
                }
            }
        }

        // ╔══════════════════════════════════════════════════════════════════╗
        //  CONTENT CARD
        // ╚══════════════════════════════════════════════════════════════════╝
        Rectangle {
            width:        parent.width
            height:       fenceColumn.height + _pad * 2
            radius:       _r
            color:        _cardBg
            border.color: _tealBorder
            border.width: 1

            Column {
                id:              fenceColumn
                anchors.top:     parent.top
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.margins: _pad
                spacing:         _pad * 0.75

                // Description / unsupported notice
                Text {
                    width:          parent.width
                    wrapMode:       Text.WordWrap
                    color:          myGeoFenceController.supported ? _dimText : Qt.rgba(1, 1, 1, 0.8)
                    font.pointSize: myGeoFenceController.supported ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize
                    text:           myGeoFenceController.supported
                                        ? qsTr("GeoFencing allows you to set a virtual fence around the area you want to fly in.")
                                        : qsTr("This vehicle does not support GeoFence.")
                }

                // Param rows
                Column {
                    width:   parent.width
                    spacing: _pad * 0.75
                    visible: myGeoFenceController.supported

                    Repeater {
                        model: myGeoFenceController.params

                        Item {
                            width:  fenceColumn.width
                            height: textField.height

                            property bool showCombo: modelData.enumStrings.length > 0

                            QGCLabel {
                                id:               textFieldLabel
                                anchors.baseline: textField.baseline
                                text:             myGeoFenceController.paramLabels[index]
                            }

                            FactTextField {
                                id:            textField
                                anchors.right: parent.right
                                width:         _editFieldWidth
                                showUnits:     true
                                fact:          modelData
                                visible:       !parent.showCombo
                            }

                            FactComboBox {
                                anchors.right: parent.right
                                width:         _editFieldWidth
                                indexModel:    false
                                fact:          parent.showCombo ? modelData : _nullFact
                                visible:       parent.showCombo

                                property var _nullFact: Fact { }
                            }
                        }
                    }

                    // ── Divider
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(0, 0.784, 0.784, 0.25) }

                    // ── Insert section
                    Text {
                        text:               qsTr("INSERT FENCE")
                        color:              _teal
                        font.bold:          true
                        font.letterSpacing: 1.5
                        font.pointSize:     ScreenTools.smallFontPointSize
                    }

                    QGCButton {
                        width: parent.width
                        text:  qsTr("Polygon Fence")
                        onClicked: {
                            var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                            var tl   = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false)
                            var br   = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false)
                            myGeoFenceController.addInclusionPolygon(tl, br)
                        }
                    }

                    QGCButton {
                        width: parent.width
                        text:  qsTr("Circular Fence")
                        onClicked: {
                            var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                            var tl   = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false)
                            var br   = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false)
                            myGeoFenceController.addInclusionCircle(tl, br)
                        }
                    }

                    // ── Polygon Fences
                    SectionHeader {
                        id:            polygonSection
                        anchors.left:  parent.left
                        anchors.right: parent.right
                        text:          qsTr("Polygon Fences")
                    }

                    Text {
                        text:           qsTr("None")
                        color:          _dimText
                        font.pointSize: ScreenTools.smallFontPointSize
                        visible:        polygonSection.checked && myGeoFenceController.polygons.count === 0
                    }

                    GridLayout {
                        width:   parent.width
                        columns: 3
                        flow:    GridLayout.TopToBottom
                        visible: polygonSection.checked && myGeoFenceController.polygons.count > 0

                        QGCLabel { text: qsTr("Inclusion"); Layout.column: 0; Layout.alignment: Qt.AlignHCenter }
                        Repeater {
                            model: myGeoFenceController.polygons
                            QGCCheckBox { checked: object.inclusion; onClicked: object.inclusion = checked; Layout.alignment: Qt.AlignHCenter }
                        }
                        QGCLabel { text: qsTr("Edit"); Layout.column: 1; Layout.alignment: Qt.AlignHCenter }
                        Repeater {
                            model: myGeoFenceController.polygons
                            QGCRadioButton {
                                checked:          _interactive
                                Layout.alignment: Qt.AlignHCenter
                                property bool _interactive: object.interactive
                                on_InteractiveChanged: checked = _interactive
                                onClicked: { myGeoFenceController.clearAllInteractive(); object.interactive = checked }
                            }
                        }
                        QGCLabel { text: qsTr("Delete"); Layout.column: 2; Layout.alignment: Qt.AlignHCenter }
                        Repeater {
                            model: myGeoFenceController.polygons
                            QGCButton { text: qsTr("Del"); Layout.alignment: Qt.AlignHCenter; onClicked: myGeoFenceController.deletePolygon(index) }
                        }
                    }

                    // ── Circular Fences
                    SectionHeader {
                        id:            circleSection
                        anchors.left:  parent.left
                        anchors.right: parent.right
                        text:          qsTr("Circular Fences")
                    }

                    Text {
                        text:           qsTr("None")
                        color:          _dimText
                        font.pointSize: ScreenTools.smallFontPointSize
                        visible:        circleSection.checked && myGeoFenceController.circles.count === 0
                    }

                    GridLayout {
                        width:   parent.width
                        columns: 4
                        flow:    GridLayout.TopToBottom
                        visible: polygonSection.checked && myGeoFenceController.circles.count > 0

                        QGCLabel { text: qsTr("Inclusion"); Layout.column: 0; Layout.alignment: Qt.AlignHCenter }
                        Repeater {
                            model: myGeoFenceController.circles
                            QGCCheckBox { checked: object.inclusion; onClicked: object.inclusion = checked; Layout.alignment: Qt.AlignHCenter }
                        }
                        QGCLabel { text: qsTr("Edit"); Layout.column: 1; Layout.alignment: Qt.AlignHCenter }
                        Repeater {
                            model: myGeoFenceController.circles
                            QGCRadioButton {
                                checked:          _interactive
                                Layout.alignment: Qt.AlignHCenter
                                property bool _interactive: object.interactive
                                on_InteractiveChanged: checked = _interactive
                                onClicked: { myGeoFenceController.clearAllInteractive(); object.interactive = checked }
                            }
                        }
                        QGCLabel { text: qsTr("Radius"); Layout.column: 2; Layout.alignment: Qt.AlignHCenter }
                        Repeater {
                            model: myGeoFenceController.circles
                            FactTextField { fact: object.radius; Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter }
                        }
                        QGCLabel { text: qsTr("Delete"); Layout.column: 3; Layout.alignment: Qt.AlignHCenter }
                        Repeater {
                            model: myGeoFenceController.circles
                            QGCButton { text: qsTr("Del"); Layout.alignment: Qt.AlignHCenter; onClicked: myGeoFenceController.deleteCircle(index) }
                        }
                    }

                    // ── Breach Return Point
                    SectionHeader {
                        id:            breachReturnSection
                        anchors.left:  parent.left
                        anchors.right: parent.right
                        text:          qsTr("Breach Return Point")
                    }

                    QGCButton {
                        width:   parent.width
                        text:    qsTr("Add Breach Return Point")
                        visible: breachReturnSection.visible && !myGeoFenceController.breachReturnPoint.isValid
                        onClicked: myGeoFenceController.breachReturnPoint = flightMap.center
                    }

                    QGCButton {
                        width:   parent.width
                        text:    qsTr("Remove Breach Return Point")
                        visible: breachReturnSection.visible && myGeoFenceController.breachReturnPoint.isValid
                        onClicked: myGeoFenceController.breachReturnPoint = QtPositioning.coordinate()
                    }

                    Column {
                        width:   parent.width
                        spacing: _pad * 0.5
                        visible: breachReturnSection.visible && myGeoFenceController.breachReturnPoint.isValid

                        Text {
                            text:           qsTr("Altitude")
                            color:          _dimText
                            font.pointSize: ScreenTools.smallFontPointSize
                        }
                        FactTextField {
                            width: parent.width
                            fact:  myGeoFenceController.breachReturnAltitude
                        }
                    }
                }
            }
        }
    }
}
