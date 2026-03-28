/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

AnalyzePage {
    id:                 vibrationPage
    pageComponent:      pageComponent
    pageDescription:    qsTr("Analyze vibration associated with your vehicle.")
    allowPopout:        true

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle : QGroundControl.multiVehicleManager.offlineEditingVehicle
    property bool   _available:     !isNaN(_activeVehicle.vibration.xAxis.rawValue)
    property real   _margins:       ScreenTools.defaultFontPixelWidth / 2
    property real   _barWidth:      ScreenTools.defaultFontPixelWidth * 7
    property real   _barHeight:     ScreenTools.defaultFontPixelHeight * 10
    property real   _xValue:        _activeVehicle.vibration.xAxis.rawValue
    property real   _yValue:        _activeVehicle.vibration.yAxis.rawValue
    property real   _zValue:        _activeVehicle.vibration.zAxis.rawValue

    readonly property real  _barMinimum:     0.0
    readonly property real  _barMaximum:     90.0
    readonly property real  _barBadValue:    60.0
    readonly property real  _barMidValue:    30.0

    readonly property color _teal:       "#00BFFF"
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimTxt:     Qt.rgba(1, 1, 1, 0.50)
    readonly property color _okColor:    "#4CAF50"
    readonly property color _warnColor:  "#FF9800"
    readonly property color _errColor:   "#FF5252"

    function _barColor(val) {
        if (val < _barMidValue) return _okColor
        if (val < _barBadValue) return _warnColor
        return _errColor
    }

    QGCPalette { id:qgcPal; colorGroupEnabled: true }

    Component {
        id: pageComponent

        Rectangle {
            width:  childrenRect.width + ScreenTools.defaultFontPixelWidth * 3
            height: childrenRect.height + ScreenTools.defaultFontPixelWidth * 3
            color:  _cardBg
            radius: ScreenTools.defaultFontPixelHeight * 0.5
            border.width: 1
            border.color: _tealBorder

            Item {
                anchors.margins: ScreenTools.defaultFontPixelWidth * 1.5
                anchors.left:    parent.left
                anchors.top:     parent.top
                width:           childrenRect.width
                height:          childrenRect.height

                RowLayout {
                    id:         barRow
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    ColumnLayout {
                        Rectangle {
                            id:                 xBar
                            height:             _barHeight
                            width:              _barWidth
                            Layout.alignment:   Qt.AlignHCenter
                            color:              "transparent"
                            radius:             4
                            border.width:       1
                            border.color:       _tealBorder

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width:          parent.width
                                height:         parent.height * (Math.min(_barMaximum, _xValue) / (_barMaximum - _barMinimum))
                                radius:         4
                                color:          _barColor(_xValue)
                                opacity:        0.8

                                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            }

                            Rectangle {
                                anchors.topMargin:      parent.height * (1.0 - ((_barBadValue - _barMinimum) / (_barMaximum - _barMinimum)))
                                anchors.top:            parent.top
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                width:                  parent.width
                                height:                 1
                                color:                  _errColor
                            }

                            Rectangle {
                                anchors.topMargin:      parent.height * (1.0 - ((_barMidValue - _barMinimum) / (_barMaximum - _barMinimum)))
                                anchors.top:            parent.top
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                width:                  parent.width
                                height:                 1
                                color:                  _warnColor
                            }
                        }

                        QGCLabel {
                            Layout.alignment:   Qt.AlignHCenter
                            text:               qsTr("X (%1)").arg(_xValue.toFixed(0))
                            color:              _barColor(_xValue)
                            font.bold:          true
                        }
                    }

                    ColumnLayout {
                        Rectangle {
                            height:             _barHeight
                            width:              _barWidth
                            Layout.alignment:   Qt.AlignHCenter
                            color:              "transparent"
                            radius:             4
                            border.width:       1
                            border.color:       _tealBorder

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width:          parent.width
                                height:         parent.height * (Math.min(_barMaximum, _yValue) / (_barMaximum - _barMinimum))
                                radius:         4
                                color:          _barColor(_yValue)
                                opacity:        0.8

                                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            }

                            Rectangle {
                                anchors.topMargin:      parent.height * (1.0 - ((_barBadValue - _barMinimum) / (_barMaximum - _barMinimum)))
                                anchors.top:            parent.top
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                width:                  parent.width
                                height:                 1
                                color:                  _errColor
                            }

                            Rectangle {
                                anchors.topMargin:      parent.height * (1.0 - ((_barMidValue - _barMinimum) / (_barMaximum - _barMinimum)))
                                anchors.top:            parent.top
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                width:                  parent.width
                                height:                 1
                                color:                  _warnColor
                            }
                        }

                        QGCLabel {
                            Layout.alignment:   Qt.AlignHCenter
                            text:               qsTr("Y (%1)").arg(_yValue.toFixed(0))
                            color:              _barColor(_yValue)
                            font.bold:          true
                        }
                    }

                    ColumnLayout {
                        Rectangle {
                            height:             _barHeight
                            width:              _barWidth
                            Layout.alignment:   Qt.AlignHCenter
                            color:              "transparent"
                            radius:             4
                            border.width:       1
                            border.color:       _tealBorder

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width:          parent.width
                                height:         parent.height * (Math.min(_barMaximum, _zValue) / (_barMaximum - _barMinimum))
                                radius:         4
                                color:          _barColor(_zValue)
                                opacity:        0.8

                                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            }

                            Rectangle {
                                anchors.topMargin:      parent.height * (1.0 - ((_barBadValue - _barMinimum) / (_barMaximum - _barMinimum)))
                                anchors.top:            parent.top
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                width:                  parent.width
                                height:                 1
                                color:                  _errColor
                            }

                            Rectangle {
                                anchors.topMargin:      parent.height * (1.0 - ((_barMidValue - _barMinimum) / (_barMaximum - _barMinimum)))
                                anchors.top:            parent.top
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                width:                  parent.width
                                height:                 1
                                color:                  _warnColor
                            }
                        }

                        QGCLabel {
                            Layout.alignment:   Qt.AlignHCenter
                            text:               qsTr("Z (%1)").arg(_zValue.toFixed(0))
                            color:              _barColor(_zValue)
                            font.bold:          true
                        }
                    }
                }

                // Clip counts card
                Rectangle {
                    anchors.left:       barRow.right
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2
                    anchors.top:        barRow.top
                    width:              clipCol.width + ScreenTools.defaultFontPixelWidth * 2
                    height:             clipCol.height + ScreenTools.defaultFontPixelWidth * 2
                    color:              Qt.rgba(1, 1, 1, 0.03)
                    radius:             4
                    border.width:       1
                    border.color:       Qt.rgba(1, 1, 1, 0.08)

                    Column {
                        id: clipCol
                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelHeight * 0.3

                        QGCLabel {
                            text:       qsTr("Clip count")
                            color:      _teal
                            font.bold:  true
                        }

                        QGCLabel {
                            text: qsTr("Accel 1: %1").arg(_activeVehicle.vibration.clipCount1.rawValue)
                            color: "#FFFFFF"
                        }

                        QGCLabel {
                            text: qsTr("Accel 2: %1").arg(_activeVehicle.vibration.clipCount2.rawValue)
                            color: "#FFFFFF"
                        }

                        QGCLabel {
                            text: qsTr("Accel 3: %1").arg(_activeVehicle.vibration.clipCount3.rawValue)
                            color: "#FFFFFF"
                        }
                    }
                }

                Rectangle {
                    anchors.fill:   barRow
                    color:          "#0D1117"
                    opacity:        0.75
                    radius:         4
                    visible:        !_available

                    QGCLabel {
                        anchors.fill:           parent
                        horizontalAlignment:    Text.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        text:                   qsTr("Not Available")
                        color:                  _dimTxt
                        font.pointSize:         ScreenTools.largeFontPointSize
                    }
                }
            }
        }
    }
}
