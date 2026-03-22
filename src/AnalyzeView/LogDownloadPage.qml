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
import QtQuick.Layouts
import Qt.labs.qmlmodels

import QGroundControl
import QGroundControl.Controls

AnalyzePage {
    id: logDownloadPage
    pageComponent: pageComponent
    pageDescription: qsTr("Log Download allows you to download binary log files from your vehicle. Click Refresh to get list of available logs.")

    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimTxt:     Qt.rgba(1, 1, 1, 0.50)

    Component {
        id: pageComponent

        RowLayout {
            width: availableWidth
            height: availableHeight
            spacing: ScreenTools.defaultFontPixelWidth * 1.5

            // ── Log table card ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color:          _cardBg
                radius:         ScreenTools.defaultFontPixelHeight * 0.5
                border.width:   1
                border.color:   _tealBorder

                QGCFlickable {
                    anchors.fill:       parent
                    anchors.margins:    ScreenTools.defaultFontPixelWidth
                    contentWidth:       gridLayout.width
                    contentHeight:      gridLayout.height
                    clip:               true

                    GridLayout {
                        id: gridLayout
                        rows: LogDownloadController.model.count + 1
                        columns: 5
                        flow: GridLayout.TopToBottom
                        columnSpacing: ScreenTools.defaultFontPixelWidth
                        rowSpacing: 0

                        QGCCheckBox {
                            id: headerCheckBox
                            enabled: false
                        }

                        Repeater {
                            model: LogDownloadController.model

                            QGCCheckBox {
                                Binding on checkState {
                                    value: object.selected ? Qt.Checked : Qt.Unchecked
                                }

                                onClicked: object.selected = checked
                            }
                        }

                        // Column headers with teal color
                        QGCLabel { text: qsTr("Id");     color: _teal; font.bold: true }

                        Repeater {
                            model: LogDownloadController.model
                            QGCLabel { text: object.id; color: "#FFFFFF" }
                        }

                        QGCLabel { text: qsTr("Date");   color: _teal; font.bold: true }

                        Repeater {
                            model: LogDownloadController.model

                            QGCLabel {
                                color: "#FFFFFF"
                                text: {
                                    if (!object.received) {
                                        return ""
                                    }
                                    if (object.time.getUTCFullYear() < 2010) {
                                        return qsTr("Date Unknown")
                                    }
                                    return object.time.toLocaleString(undefined)
                                }
                            }
                        }

                        QGCLabel { text: qsTr("Size");   color: _teal; font.bold: true }

                        Repeater {
                            model: LogDownloadController.model
                            QGCLabel { text: object.sizeStr; color: "#FFFFFF" }
                        }

                        QGCLabel { text: qsTr("Status"); color: _teal; font.bold: true }

                        Repeater {
                            model: LogDownloadController.model
                            QGCLabel { text: object.status; color: _dimTxt }
                        }
                    }
                }
            }

            // ── Action buttons ──
            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: false

                QGCButton {
                    Layout.fillWidth: true
                    enabled: !LogDownloadController.requestingList && !LogDownloadController.downloadingLogs
                    text: qsTr("Refresh")

                    onClicked: {
                        if (!QGroundControl.multiVehicleManager.activeVehicle || QGroundControl.multiVehicleManager.activeVehicle.isOfflineEditingVehicle) {
                            mainWindow.showMessageDialog(qsTr("Log Refresh"), qsTr("You must be connected to a vehicle in order to download logs."))
                            return
                        }
                        LogDownloadController.refresh()
                    }
                }

                QGCButton {
                    Layout.fillWidth: true
                    enabled: !LogDownloadController.requestingList && !LogDownloadController.downloadingLogs
                    text: qsTr("Download")

                    onClicked: {
                        var logsSelected = false
                        for (var i = 0; i < LogDownloadController.model.count; i++) {
                            if (LogDownloadController.model.get(i).selected) {
                                logsSelected = true
                                break
                            }
                        }
                        if (!logsSelected) {
                            mainWindow.showMessageDialog(qsTr("Log Download"), qsTr("You must select at least one log file to download."))
                            return
                        }
                        if (ScreenTools.isMobile) {
                            LogDownloadController.download()
                            return
                        }
                        fileDialog.title = qsTr("Select save directory")
                        fileDialog.folder = QGroundControl.settingsManager.appSettings.logSavePath
                        fileDialog.selectFolder = true
                        fileDialog.openForLoad()
                    }

                    QGCFileDialog {
                        id: fileDialog
                        onAcceptedForLoad: (file) => {
                            LogDownloadController.download(file)
                            close()
                        }
                    }
                }

                QGCButton {
                    Layout.fillWidth: true
                    enabled: !LogDownloadController.requestingList && !LogDownloadController.downloadingLogs && (LogDownloadController.model.count > 0)
                    text: qsTr("Erase All")
                    onClicked: mainWindow.showMessageDialog(
                        qsTr("Delete All Log Files"),
                        qsTr("All log files will be erased permanently. Is this really what you want?"),
                        Dialog.Yes | Dialog.No,
                        function() { LogDownloadController.eraseAll() }
                    )
                }

                QGCButton {
                    Layout.fillWidth: true
                    text: qsTr("Cancel")
                    enabled: LogDownloadController.requestingList || LogDownloadController.downloadingLogs
                    onClicked: LogDownloadController.cancel()
                }
            }
        }
    }
}
