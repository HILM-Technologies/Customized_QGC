import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts

import QGroundControl
import QGroundControl.Controls

ChartView {
    id:                 chartView
    theme:              ChartView.ChartThemeDark
    antialiasing:       true
    animationOptions:   ChartView.NoAnimation
    legend.visible:     false
    backgroundColor:    Qt.rgba(1, 1, 1, 0.04)
    backgroundRoundness: ScreenTools.defaultFontPixelHeight * 0.5
    margins.bottom:     ScreenTools.defaultFontPixelHeight * 1.5
    margins.top:        chartHeader.height + (ScreenTools.defaultFontPixelHeight * 2)
    visible:            chartController.chartFields.length > 0

    required property var inspectorController
    required property int chartIndex

    readonly property color _teal:       "#00BFFF"
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _dimTxt:     Qt.rgba(1, 1, 1, 0.50)

    property var _seriesColors: ["#00BFFF","#4CAF50","#FF9800","#FF5252","#536DFF","#EECC44"]

    // Teal border around chart
    Rectangle {
        anchors.fill: parent
        color:        "transparent"
        radius:       ScreenTools.defaultFontPixelHeight * 0.5
        border.width: 1
        border.color: _tealBorder
        z:            -1
    }

    function addDimension(field) {
        var color   = _seriesColors[chartView.count]
        var serie   = createSeries(ChartView.SeriesTypeLine, field.label)
        serie.axisX = axisX
        serie.axisY = axisY
        serie.useOpenGL = QGroundControl.videoManager.gstreamerEnabled
        serie.color = color
        serie.width = 1
        chartController.addSeries(field, serie)
    }

    function delDimension(field) {
        if(chartController) {
            chartView.removeSeries(field.series)
            chartController.delSeries(field)
        }
    }

    function roomForNewDimension() {
        return chartController.chartFields.length < _seriesColors.length
    }

    MAVLinkChartController {
        id:                     chartController
        inspectorController:    chartView.inspectorController
        chartIndex:             chartView.chartIndex
    }

    DateTimeAxis {
        id:                         axisX
        min:                        chartController ? chartController.rangeXMin : new Date()
        max:                        chartController ? chartController.rangeXMax : new Date()
        visible:                    chartController !== null
        format:                     "<br/>mm:ss.zzz"
        tickCount:                  5
        gridVisible:                true
        gridLineColor:              Qt.rgba(1, 1, 1, 0.08)
        labelsFont.family:          ScreenTools.fixedFontFamily
        labelsFont.pointSize:       ScreenTools.smallFontPointSize
        labelsColor:                _dimTxt
        color:                      _tealBorder
    }

    ValueAxis {
        id:                         axisY
        min:                        chartController ? chartController.rangeYMin : 0
        max:                        chartController ? chartController.rangeYMax : 0
        visible:                    chartController !== null
        lineVisible:                false
        gridLineColor:              Qt.rgba(1, 1, 1, 0.08)
        labelsFont.family:          ScreenTools.fixedFontFamily
        labelsFont.pointSize:       ScreenTools.smallFontPointSize
        labelsColor:                _dimTxt
        color:                      _tealBorder
    }

    Row {
        id:                         chartHeader
        anchors.left:               parent.left
        anchors.leftMargin:         ScreenTools.defaultFontPixelWidth  * 4
        anchors.right:              parent.right
        anchors.rightMargin:        ScreenTools.defaultFontPixelWidth  * 4
        anchors.top:                parent.top
        anchors.topMargin:          ScreenTools.defaultFontPixelHeight * 1.5
        spacing:                    ScreenTools.defaultFontPixelWidth  * 2
        visible:                    chartController !== null
        GridLayout {
            columns:                2
            columnSpacing:          ScreenTools.defaultFontPixelWidth
            rowSpacing:             ScreenTools.defaultFontPixelHeight * 0.25
            anchors.verticalCenter: parent.verticalCenter
            QGCLabel {
                text:               qsTr("Scale:");
                color:              _dimTxt
                Layout.alignment:   Qt.AlignVCenter
            }
            QGCComboBox {
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
                Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 10
                height:             ScreenTools.defaultFontPixelHeight
                model:              controller.timeScales
                currentIndex:       chartController ? chartController.rangeXIndex : 0
                onActivated: (index) => { if(chartController) chartController.rangeXIndex = index; }
                Layout.alignment:   Qt.AlignVCenter
            }
            QGCLabel {
                text:               qsTr("Range:");
                color:              _dimTxt
                Layout.alignment:   Qt.AlignVCenter
            }
            QGCComboBox {
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
                Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 10
                height:             ScreenTools.defaultFontPixelHeight
                model:              controller.rangeList
                currentIndex:       chartController ? chartController.rangeYIndex : 0
                onActivated: (index) => { if(chartController) chartController.rangeYIndex = index; }
                Layout.alignment:   Qt.AlignVCenter
            }
        }
        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model:              chartController ? chartController.chartFields : []
                QGCLabel {
                    text:           modelData.label
                    color:          chartView.series(index).color
                    font.pointSize: ScreenTools.smallFontPointSize
                    font.bold:      true
                }
            }
        }
    }
}
