/****************************************************************************
 *
 * HILM Ground Control — Media (Camera Roll)
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

    // HILM design tokens
    readonly property color _teal:     "#00BFFF"
    readonly property color _green:    "#4CAF50"
    readonly property color _orange:   "#FF9800"
    readonly property color _cardBg:   Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:  Qt.rgba(1, 1, 1, 0.50)
    readonly property real  _pad:      ScreenTools.defaultFontPixelWidth * 1.2
    // smaller to match the UI
    readonly property real  _fontSize: ScreenTools.defaultFontPixelHeight * 0.85

    // ── Data ────────────────────────────────────────────────
    property var    _info:       ({})
    property var    _allItems:   []
    property int    _typeFilter: 0          // 0=all, 1=videos, 2=photos
    property string _searchText: ""
    property bool   _gridMode:   true

    function _refresh() {
        _info     = QGroundControl.mediaInfo()
        _allItems = _info.items ? _info.items : []
    }

    function _formatGB(bytes) {
        if (!bytes || bytes <= 0) return "0.0"
        return (bytes / 1.0e9).toFixed(1)
    }
    function _formatSize(bytes) {
        if (!bytes || bytes <= 0) return "0 KB"
        if (bytes >= 1.0e9) return (bytes / 1.0e9).toFixed(1) + " GB"
        if (bytes >= 1.0e6) return (bytes / 1.0e6).toFixed(1) + " MB"
        return (bytes / 1.0e3).toFixed(0) + " KB"
    }

    // type + search filter
    property var _filtered: {
        var out = []
        var s = _searchText.toLowerCase()
        for (var i = 0; i < _allItems.length; i++) {
            var it = _allItems[i]
            if (_typeFilter === 1 && !it.isVideo) continue
            if (_typeFilter === 2 &&  it.isVideo) continue
            if (s.length > 0 && it.name.toLowerCase().indexOf(s) < 0) continue
            out.push(it)
        }
        return out
    }

    Component.onCompleted: _refresh()
    onVisibleChanged:      if (visible) _refresh()

    DeadMouseArea { anchors.fill: parent }

    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: _pad * 2
        spacing:         _pad * 1.5

        // ── HEADER: title + stats ───────────────────────────
        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: _pad * 0.3
                QGCLabel {
                    text: "Camera Roll"; color: "white"
                    font.pixelSize: _fontSize * 1.25; font.bold: true; font.letterSpacing: 0.5
                }
                QGCLabel {
                    text: "Mission recordings and aerial photography"
                    color: _dimText; font.pixelSize: _fontSize * 0.8
                }
            }

            // Spacer pushes the stats to the far-right edge
            Item { Layout.fillWidth: true }

            // Stat: VIDEOS / PHOTOS / STORAGE
            Row {
                spacing: _pad * 3

                Column {
                    QGCLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "" + (_info.videoCount ? _info.videoCount : 0)
                        color: _teal; font.pixelSize: _fontSize * 1.2; font.bold: true
                    }
                    QGCLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "VIDEOS"; color: _dimText
                        font.pixelSize: _fontSize * 0.65; font.letterSpacing: 1
                    }
                }
                Column {
                    QGCLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "" + (_info.photoCount ? _info.photoCount : 0)
                        color: _green; font.pixelSize: _fontSize * 1.2; font.bold: true
                    }
                    QGCLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "PHOTOS"; color: _dimText
                        font.pixelSize: _fontSize * 0.65; font.letterSpacing: 1
                    }
                }
                Column {
                    QGCLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: _formatGB(_info.diskUsedBytes) + " GB"
                        color: _orange; font.pixelSize: _fontSize * 1.2; font.bold: true
                    }
                    QGCLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: _info.diskTotalBytes
                                  ? ("STORAGE • " + _formatGB(_info.diskTotalBytes) + " GB " + (_info.diskRoot ? _info.diskRoot : ""))
                                  : "STORAGE"
                        color: _dimText; font.pixelSize: _fontSize * 0.65; font.letterSpacing: 1
                    }
                }
            }
        }

        // ── TOOLBAR: search + filters + drone + view toggle ─
        RowLayout {
            Layout.fillWidth: true
            spacing: _pad

            // Search
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: _fontSize * 2.8
                radius: _fontSize * 0.35
                color: _cardBg
                border.color: searchField.activeFocus ? _teal : Qt.rgba(1,1,1,0.12); border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: _pad; anchors.rightMargin: _pad
                    spacing: _pad * 0.5
                    QGCColoredImage {
                        width: _fontSize; height: width
                        source: "/InstrumentValueIcons/search.svg"
                        color: _dimText; fillMode: Image.PreserveAspectFit
                    }
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Search by location or drone..."
                        color: "white"
                        font.pixelSize: _fontSize * 0.85
                        background: Rectangle { color: "transparent" }
                        onTextChanged: _root._searchText = text
                    }
                }
            }

            // ALL / VIDEOS / PHOTOS
            Row {
                spacing: 1
                Repeater {
                    model: [ { t: "ALL", f: 0 }, { t: "VIDEOS", f: 1 }, { t: "PHOTOS", f: 2 } ]
                    Rectangle {
                        width: filterLabel.implicitWidth + _pad * 2.2
                        height: _fontSize * 2.8
                        radius: _fontSize * 0.35
                        color: _root._typeFilter === modelData.f ? _teal : _cardBg
                        border.color: _root._typeFilter === modelData.f ? _teal : Qt.rgba(1,1,1,0.12)
                        border.width: 1
                        QGCLabel {
                            id: filterLabel; anchors.centerIn: parent
                            text: modelData.t
                            color: _root._typeFilter === modelData.f ? "#000000" : _dimText
                            font.pixelSize: _fontSize * 0.7; font.bold: _root._typeFilter === modelData.f
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: _root._typeFilter = modelData.f
                        }
                    }
                }
            }

            // drone filter (placeholder)
            QGCComboBox {
                Layout.preferredWidth: _fontSize * 9
                model: [ "All Drones" ]
                currentIndex: 0
            }

            // Grid / list toggle
            Row {
                spacing: 1
                Repeater {
                    model: [ { g: true,  icon: "/InstrumentValueIcons/view-tile.svg" },
                             { g: false, icon: "/InstrumentValueIcons/list.svg" } ]
                    Rectangle {
                        width: _fontSize * 2.8; height: _fontSize * 2.8
                        radius: _fontSize * 0.35
                        color: _root._gridMode === modelData.g ? _teal : _cardBg
                        border.color: _root._gridMode === modelData.g ? _teal : Qt.rgba(1,1,1,0.12)
                        border.width: 1
                        QGCColoredImage {
                            anchors.centerIn: parent
                            width: _fontSize * 1.1; height: width
                            source: modelData.icon
                            color: _root._gridMode === modelData.g ? "#000000" : _dimText
                            fillMode: Image.PreserveAspectFit
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: _root._gridMode = modelData.g
                        }
                    }
                }
            }
        }

        // ── CONTENT ─────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                spacing: _pad
                visible: _filtered.length === 0

                QGCColoredImage {
                    Layout.alignment: Qt.AlignHCenter
                    width: _fontSize * 4; height: width
                    source: "/InstrumentValueIcons/folder.svg"
                    color: _orange; fillMode: Image.PreserveAspectFit
                }
                QGCLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No Media Found"; color: "white"
                    font.pixelSize: _fontSize * 1.2; font.bold: true
                }
                QGCLabel {
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    Layout.preferredWidth: _fontSize * 25
                    wrapMode: Text.WordWrap
                    text: "No recordings or photos available yet. Media captured during missions will appear here."
                    color: _dimText; font.pixelSize: _fontSize * 0.8
                }
            }

            // Grid view
            GridView {
                anchors.fill: parent
                visible: _filtered.length > 0 && _gridMode
                clip: true
                cellWidth:  _fontSize * 14
                cellHeight: _fontSize * 12
                model: _filtered

                delegate: Item {
                    width:  GridView.view.cellWidth
                    height: GridView.view.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: _pad * 0.5
                        radius: _fontSize * 0.4
                        color: _cardBg
                        border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            // Thumbnail / icon
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.rgba(0,0,0,0.35)
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    visible: !modelData.isVideo
                                    source: modelData.isVideo ? "" : modelData.url
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                }
                                QGCColoredImage {
                                    anchors.centerIn: parent
                                    visible: modelData.isVideo
                                    width: _fontSize * 2.5; height: width
                                    source: "/qmlimages/CameraIcon.svg"
                                    color: _teal; fillMode: Image.PreserveAspectFit
                                }

                                // Type badge
                                Rectangle {
                                    anchors.top: parent.top; anchors.left: parent.left
                                    anchors.margins: _pad * 0.4
                                    radius: _fontSize * 0.25
                                    width: badge.implicitWidth + _pad; height: _fontSize * 1.4
                                    color: modelData.isVideo ? Qt.rgba(0,0.749,1.0,0.85) : Qt.rgba(0.30,0.69,0.31,0.85)
                                    QGCLabel {
                                        id: badge; anchors.centerIn: parent
                                        text: modelData.isVideo ? "VIDEO" : "PHOTO"
                                        color: "white"; font.pixelSize: _fontSize * 0.6; font.bold: true
                                    }
                                }
                            }

                            // Caption
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.margins: _pad * 0.6
                                spacing: 1
                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: modelData.name; color: "white"
                                    font.pixelSize: _fontSize * 0.7; elide: Text.ElideRight
                                }
                                QGCLabel {
                                    text: _formatSize(modelData.sizeBytes) + "  •  " + modelData.modified
                                    color: _dimText; font.pixelSize: _fontSize * 0.6
                                }
                            }
                        }
                    }
                }
            }

            // List view
            ListView {
                anchors.fill: parent
                visible: _filtered.length > 0 && !_gridMode
                clip: true
                spacing: _pad * 0.5
                model: _filtered

                delegate: Rectangle {
                    width: ListView.view.width
                    height: _fontSize * 3.2
                    radius: _fontSize * 0.35
                    color: _cardBg
                    border.color: Qt.rgba(1,1,1,0.08); border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: _pad; anchors.rightMargin: _pad
                        spacing: _pad

                        QGCColoredImage {
                            width: _fontSize * 1.3; height: width
                            source: modelData.isVideo ? "/qmlimages/CameraIcon.svg" : "/InstrumentValueIcons/photo.svg"
                            color: modelData.isVideo ? _teal : _green
                            fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel {
                            Layout.fillWidth: true
                            text: modelData.name; color: "white"
                            font.pixelSize: _fontSize * 0.8; elide: Text.ElideRight
                        }
                        QGCLabel {
                            text: _formatSize(modelData.sizeBytes); color: _dimText
                            font.pixelSize: _fontSize * 0.75
                        }
                        QGCLabel {
                            text: modelData.modified; color: _dimText
                            font.pixelSize: _fontSize * 0.75
                        }
                    }
                }
            }
        }
    }
}
