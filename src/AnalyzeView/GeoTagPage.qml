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
import QGroundControl.Controls

AnalyzePage {
    pageComponent: pageComponent
    pageDescription: qsTr("Used to tag a set of images from a survey mission with gps coordinates. You must provide the binary log from the flight as well as the directory which contains the images to tag.")

    readonly property real  _margin:     ScreenTools.defaultFontPixelWidth * 2
    readonly property real  _minWidth:   ScreenTools.defaultFontPixelWidth * 20
    readonly property real  _maxWidth:   ScreenTools.defaultFontPixelWidth * 30
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimTxt:     Qt.rgba(1, 1, 1, 0.50)

    Component {
        id: pageComponent

        Rectangle {
            width:  availableWidth
            height: geoGrid.height + _margin * 2
            color:  _cardBg
            radius: ScreenTools.defaultFontPixelHeight * 0.5
            border.width: 1
            border.color: _tealBorder

            GridLayout {
                id:             geoGrid
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.top:    parent.top
                anchors.margins: _margin
                columns:        2
                columnSpacing:  _margin
                rowSpacing:     ScreenTools.defaultFontPixelWidth * 2

                BusyIndicator {
                    running: (geoController.progress > 0) && (geoController.progress < 100) && !geoController.errorMessage
                    width: progressBar.height
                    height: progressBar.height
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                }

                ProgressBar {
                    id: progressBar
                    to: 100
                    value: geoController.progress
                    opacity: (geoController.progress > 0) ? 1 : 0.25
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                QGCLabel {
                    text: geoController.errorMessage
                    color: "#FF5252"
                    font.bold: true
                    font.pointSize: ScreenTools.mediumFontPointSize
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                    Layout.columnSpan: 2
                }

                QGCButton {
                    text: qsTr("Select log file")
                    Layout.minimumWidth: _minWidth
                    Layout.maximumWidth: _maxWidth
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: openLogFile.openForLoad()

                    QGCFileDialog {
                        id: openLogFile
                        title: qsTr("Select log file")
                        nameFilters: [qsTr("ULog file (*.ulg)"), qsTr("PX4 log file (*.px4log)"), qsTr("All Files (*)")]
                        defaultSuffix: "ulg"
                        onAcceptedForLoad: (file) => {
                            geoController.logFile = file
                            close()
                        }
                    }
                }

                QGCLabel {
                    text: geoController.logFile
                    elide: Text.ElideLeft
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    color: "#FFFFFF"
                }

                QGCButton {
                    text: qsTr("Select image directory")
                    Layout.minimumWidth: _minWidth
                    Layout.maximumWidth: _maxWidth
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: selectImageDir.openForLoad()

                    QGCFileDialog {
                        id: selectImageDir
                        title: qsTr("Select image directory")
                        selectFolder: true
                        onAcceptedForLoad: (file) => {
                            geoController.imageDirectory = file
                            close()
                        }
                    }
                }

                QGCLabel {
                    text: geoController.imageDirectory
                    elide: Text.ElideLeft
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    color: "#FFFFFF"
                }

                QGCButton {
                    text: qsTr("(Optionally) Select save directory")
                    Layout.minimumWidth: _minWidth
                    Layout.maximumWidth: _maxWidth
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: selectDestDir.openForLoad()

                    QGCFileDialog {
                        id: selectDestDir
                        title: qsTr("Select save directory")
                        selectFolder: true
                        onAcceptedForLoad: (file) => {
                            geoController.saveDirectory = file
                            close()
                        }
                    }
                }

                QGCLabel {
                    text: {
                        if (geoController.saveDirectory) {
                            return geoController.saveDirectory;
                        } else if (geoController.imageDirectory) {
                            return geoController.imageDirectory + qsTr("/TAGGED");
                        } else {
                            return qsTr("/TAGGED folder in your image folder");
                        }
                    }
                    elide: Text.ElideLeft
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    color: _dimTxt
                }

                QGCButton {
                    text: geoController.inProgress ? qsTr("Cancel Tagging") : qsTr("Start Tagging")
                    enabled: (geoController.imageDirectory && geoController.logFile) || geoController.inProgress
                    Layout.minimumWidth: _minWidth
                    Layout.maximumWidth: _maxWidth
                    Layout.alignment: Qt.AlignHCenter
                    Layout.columnSpan: 2
                }
            }
        }
    }
}
