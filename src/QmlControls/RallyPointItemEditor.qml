import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id:     root
    height: _currentItem ? valuesRect.y + valuesRect.height + (_margin * 2) : titleBar.y + titleBar.height + _margin
    color:  _currentItem ? Qt.rgba(0, 0.784, 0.784, 0.22) : Qt.rgba(1, 1, 1, 0.04)
    radius: _radius
    border.color: Qt.rgba(0, 0.784, 0.784, 0.32)
    border.width: 1

    signal clicked()

    property var rallyPoint ///< RallyPoint object associated with editor
    property var controller ///< RallyPointController

    property bool   _currentItem:       rallyPoint ? rallyPoint === controller.currentRallyPoint : false
    property color  _outerTextColor:    Qt.rgba(1, 1, 1, _currentItem ? 1.0 : 0.75)

    readonly property real  _margin:      ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _radius:      ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _titleHeight: ScreenTools.defaultFontPixelHeight * 2

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // Background click handler — emits clicked() for list-selection.
    // Declared first so it sits behind all children in z-order; the
    // hamburger's own MouseArea (deeper in the tree) still wins for its area.
    MouseArea {
        anchors.fill: parent
        onClicked:    root.clicked()
    }

    Item {
        id:                 titleBar
        anchors.margins:    _margin
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        height:             _titleHeight

        MissionItemIndexLabel {
            id:                     indicator
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           parent.left
            label:                  "R"
            checked:                true
        }

        QGCLabel {
            anchors.leftMargin:     _margin
            anchors.left:           indicator.right
            anchors.verticalCenter: parent.verticalCenter
            text:                   qsTr("Rally Point")
            color:                  _outerTextColor
        }

        QGCColoredImage {
            id:                     hamburger
            anchors.rightMargin:    _margin
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            width:                  ScreenTools.defaultFontPixelWidth * 2
            height:                 width
            sourceSize.height:      height
            source:                 "qrc:/qmlimages/Hamburger.svg"
            color:                  _outerTextColor

            MouseArea {
                anchors.fill:   parent
                onClicked:      hamburgerMenu.popup()

                QGCMenu {
                    id: hamburgerMenu

                    QGCMenuItem {
                        text:           qsTr("Delete")
                        onTriggered:    controller.removePoint(rallyPoint)
                    }
                }
            }
        }
    } // Item - titleBar

    Rectangle {
        id:                 valuesRect
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        titleBar.bottom
        height:             valuesGrid.height + (_margin * 2)
        color:              Qt.rgba(0, 0.784, 0.784, 0.08)
        visible:            _currentItem
        radius:             _radius

        GridLayout {
            id:                 valuesGrid
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        parent.top
            rowSpacing:         _margin
            columnSpacing:      _margin
            rows:               rallyPoint ? rallyPoint.textFieldFacts.length : 0
            flow:               GridLayout.TopToBottom

            Repeater {
                model: rallyPoint ? rallyPoint.textFieldFacts : 0
                QGCLabel {
                    text:  modelData.name + ":"
                    color: Qt.rgba(1, 1, 1, 0.75)
                }
            }

            Repeater {
                model: rallyPoint ? rallyPoint.textFieldFacts : 0
                FactTextField {
                    Layout.fillWidth: true
                    showUnits:        true
                    fact:             modelData
                }
            }
        } // GridLayout
    } // Rectangle
} // Rectangle
