/****************************************************************************
 *
 * HILM Ground Control — Network (Streaming server connectivity)
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

    // design tokens (match Setup tab)
    readonly property color _teal:        "#00BFFF"
    readonly property color _green:       "#4CAF50"
    readonly property color _orange:      "#FF9800"
    readonly property color _err:         "#FF5252"
    readonly property color _cardBg:      Qt.rgba(1, 1, 1, 0.04)
    readonly property color _dimText:     Qt.rgba(1, 1, 1, 0.50)
    readonly property color _tealDim:     Qt.rgba(0, 0.749, 1.0, 0.10)
    readonly property color _tealBorder:  Qt.rgba(0, 0.749, 1.0, 0.45)
    readonly property color _greenDim:    Qt.rgba(0.30, 0.69, 0.31, 0.10)
    readonly property color _greenBorder: Qt.rgba(0.30, 0.69, 0.31, 0.45)

    readonly property real  _pad:             ScreenTools.defaultFontPixelWidth * 1.2
    readonly property real  _fontSize:        ScreenTools.defaultFontPixelHeight * 0.9
    readonly property real  _maxContentWidth: ScreenTools.defaultFontPixelWidth * 175

    // ── Data ────────────────────────────────────────────────
    property var _vehicleModel: QGroundControl.multiVehicleManager.vehicles
    property int _droneCount:   _vehicleModel ? _vehicleModel.count : 0
    property int _serverChoice: 0   // 0=hardware, 1=cloud (hardcoded)

    // plans (hardcoded)
    readonly property var _plans: [
        { icon: "plan-starter.svg",    name: "Starter",    spec: "Raspberry Pi 4 (4GB) · Up to 5 drones",                 later: "Free forever",  cost: "~$80 one-time",    max: 5 },
        { icon: "plan-standard.svg",   name: "Standard",   spec: "Mini PC (i5 / 16GB) · Up to 15 drones",                 later: "$79 / mo",      cost: "~$400 one-time",   max: 15 },
        { icon: "plan-pro.svg",        name: "Pro",        spec: "Dedicated server (8c / 16GB) · Up to 50 drones",        later: "$299 / mo",     cost: "~$1,500 one-time", max: 50 },
        { icon: "plan-enterprise.svg", name: "Enterprise", spec: "Server cluster (16c+ / 32GB+ / 10 Gbps) · 100+ drones", later: "Contact sales", cost: "Custom",           max: 1000000 }
    ]
    // plan that fits the fleet
    property int _planIndex: {
        for (var i = 0; i < _plans.length; i++) {
            if (_droneCount <= _plans[i].max) return i
        }
        return _plans.length - 1
    }

    DeadMouseArea { anchors.fill: parent }

    QGCFlickable {
        anchors.fill:  parent
        contentHeight: _col.implicitHeight + _pad * 4
        clip:          true

        ColumnLayout {
            id: _col
            anchors.top:              parent.top
            anchors.topMargin:        _pad * 2
            anchors.horizontalCenter: parent.horizontalCenter
            width:                    Math.min(_root.width - _pad * 4, _maxContentWidth)
            spacing:                  _pad * 1.5

            // ── HEADER ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: _pad * 0.3
                    QGCLabel { text: "Network"; color: "white"; font.pixelSize: _fontSize * 1.4; font.bold: true; font.letterSpacing: 0.5 }
                    QGCLabel { text: "Streaming server connectivity"; color: _dimText; font.pixelSize: _fontSize * 0.8 }
                }

                Item { Layout.fillWidth: true }

                // RE-CHECK button
                Rectangle {
                    Layout.preferredWidth:  _recheckRow.implicitWidth + _pad * 3
                    Layout.preferredHeight: _fontSize * 2.8
                    radius: _fontSize * 0.4
                    color:  recheckArea.containsMouse ? _tealDim : "transparent"
                    border.color: _tealBorder; border.width: 1

                    RowLayout {
                        id: _recheckRow
                        anchors.centerIn: parent
                        spacing: _pad * 0.5
                        QGCColoredImage {
                            width: _fontSize; height: width
                            source: "/InstrumentValueIcons/refresh.svg"
                            color: _teal; fillMode: Image.PreserveAspectFit
                        }
                        QGCLabel { text: "RE-CHECK"; color: _teal; font.pixelSize: _fontSize * 0.72; font.bold: true; font.letterSpacing: 0.8 }
                    }
                    MouseArea { id: recheckArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                }
            }

            // ── BETA banner ─────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: _betaRow.implicitHeight + _pad * 2.5
                radius: _fontSize * 0.5
                color: _greenDim
                border.color: _greenBorder; border.width: 1

                RowLayout {
                    id: _betaRow
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: _pad * 1.5; rightMargin: _pad * 1.5 }
                    spacing: _pad

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignTop
                        width: _fontSize * 2.2; height: width
                        source: "/InstrumentValueIcons/cloud.svg"
                        color: _green; fillMode: Image.PreserveAspectFit
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.4
                        RowLayout {
                            spacing: _pad * 0.6
                            Rectangle {
                                radius: _fontSize * 0.25; color: _green
                                Layout.preferredWidth: _betaPill.implicitWidth + _pad * 1.2; Layout.preferredHeight: _fontSize * 1.5
                                QGCLabel { id: _betaPill; anchors.centerIn: parent; text: "BETA"; color: "#06210B"; font.pixelSize: _fontSize * 0.62; font.bold: true; font.letterSpacing: 0.5 }
                            }
                            QGCLabel { text: "Everything is free during beta"; color: "white"; font.pixelSize: _fontSize * 0.95; font.bold: true }
                        }
                        QGCLabel {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "All tiers, recording, cloud hosting — unlocked for early users until Q3 2026. Prices below show what plans will cost once we go live."
                            color: _dimText; font.pixelSize: _fontSize * 0.78
                        }
                    }
                }
            }

            // ── WHERE'S YOUR STREAMING SERVER? ──────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: _serverCol.implicitHeight + _pad * 3
                radius: _fontSize * 0.5
                color: _cardBg
                border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                ColumnLayout {
                    id: _serverCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad * 1.8 }
                    spacing: _pad * 1.2

                    QGCLabel { text: "WHERE'S YOUR STREAMING SERVER?"; color: _dimText; font.pixelSize: _fontSize * 0.72; font.bold: true; font.letterSpacing: 1 }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 1.2

                        // ON YOUR HARDWARE
                        ServerChoiceCard {
                            choice:    0
                            icon:      "/InstrumentValueIcons/home.svg"
                            title:     "ON YOUR HARDWARE"
                            subtitle:  "RASPBERRY PI 4 (4GB)"
                            priceNow:  "FREE"
                            priceWas:  "FREE FOREVER"
                            note:      "ONE-TIME HARDWARE COST, LOWER MONTHLY"
                        }

                        // HILM CLOUD
                        ServerChoiceCard {
                            choice:    1
                            icon:      "/InstrumentValueIcons/cloud.svg"
                            title:     "HILM CLOUD"
                            subtitle:  "WE HOST IT FOR YOU"
                            priceNow:  "FREE"
                            priceWas:  "$29 / MO"
                            note:      "ZERO SETUP, HIGHER MONTHLY"
                            badge:     "EASIEST"
                        }
                    }
                }
            }

            // ── Suggestion (hardcoded, uses drone count) ──
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: _sugRow.implicitHeight + _pad * 2.5
                radius: _fontSize * 0.5
                color: _greenDim
                border.color: _greenBorder; border.width: 1

                RowLayout {
                    id: _sugRow
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: _pad * 1.5; rightMargin: _pad * 1.5 }
                    spacing: _pad

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignTop
                        width: _fontSize * 2.2; height: width
                        source: "/InstrumentValueIcons/checkmark.svg"
                        color: _green; fillMode: Image.PreserveAspectFit
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: _pad * 0.3
                        QGCLabel { text: "RIGHT-SIZED FOR YOUR FLEET"; color: _dimText; font.pixelSize: _fontSize * 0.65; font.bold: true; font.letterSpacing: 1 }
                        QGCLabel {
                            text: "You have " + _droneCount + " drone" + (_droneCount === 1 ? "" : "s") + " — " +
                                  (_droneCount <= 5 ? "you don't need a server" : "a " + _plans[_planIndex].name.toLowerCase() + " server is recommended")
                            color: "white"; font.pixelSize: _fontSize * 1.1; font.bold: true
                        }
                        QGCLabel {
                            text: "A " + _plans[_planIndex].spec.split(" · ")[0] + " is enough. " + _plans[_planIndex].cost + "."
                            color: _dimText; font.pixelSize: _fontSize * 0.8
                        }
                    }
                }
            }

            // ── STATUS: Raspberry Pi + Recording (side by side) ─
            RowLayout {
                Layout.fillWidth: true
                spacing: _pad * 1.2

                // Raspberry Pi (connected)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: _piCol.implicitHeight + _pad * 3
                    radius: _fontSize * 0.5
                    color: _greenDim
                    border.color: _greenBorder; border.width: 1

                    ColumnLayout {
                        id: _piCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad * 1.6 }
                        spacing: _pad

                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                width: _fontSize * 2.4; height: width; radius: _fontSize * 0.4; color: Qt.rgba(0.30,0.69,0.31,0.18)
                                QGCColoredImage { anchors.centerIn: parent; width: _fontSize * 1.3; height: width; source: "/InstrumentValueIcons/servers.svg"; color: _green; fillMode: Image.PreserveAspectFit }
                            }
                            Item { Layout.fillWidth: true }
                            QGCColoredImage { width: _fontSize * 1.3; height: width; source: "/InstrumentValueIcons/checkmark.svg"; color: _green; fillMode: Image.PreserveAspectFit }
                        }
                        QGCLabel { text: "Raspberry Pi 4 (4GB)"; color: "white"; font.pixelSize: _fontSize * 1.0; font.bold: true }
                        QGCLabel { text: "192.168.1.50:8554"; color: _dimText; font.pixelSize: _fontSize * 0.8; font.family: "monospace" }
                        RowLayout {
                            Layout.fillWidth: true; Layout.topMargin: _pad * 0.4
                            QGCLabel { text: "CONNECTED"; color: _green; font.pixelSize: _fontSize * 0.8; font.bold: true; font.letterSpacing: 0.5 }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                radius: _fontSize * 0.25; color: _tealDim; border.color: _tealBorder; border.width: 1
                                Layout.preferredWidth: _starterPill.implicitWidth + _pad * 1.2; Layout.preferredHeight: _fontSize * 1.5
                                QGCLabel { id: _starterPill; anchors.centerIn: parent; text: "STARTER"; color: _teal; font.pixelSize: _fontSize * 0.6; font.bold: true }
                            }
                            QGCLabel { text: "23 ms"; color: _dimText; font.pixelSize: _fontSize * 0.75 }
                        }
                    }
                }

                // Recording (disabled)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: _recCol.implicitHeight + _pad * 3
                    radius: _fontSize * 0.5
                    color: _cardBg
                    border.color: Qt.rgba(1,1,1,0.08); border.width: 1

                    ColumnLayout {
                        id: _recCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad * 1.6 }
                        spacing: _pad

                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                width: _fontSize * 2.4; height: width; radius: _fontSize * 0.4; color: Qt.rgba(1,1,1,0.06)
                                QGCColoredImage { anchors.centerIn: parent; width: _fontSize * 1.3; height: width; source: "/InstrumentValueIcons/hard-drive.svg"; color: _dimText; fillMode: Image.PreserveAspectFit }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: _fontSize * 1.4; height: width; radius: width/2; color: "transparent"; border.color: _err; border.width: 1.5
                                QGCLabel { anchors.centerIn: parent; text: "✕"; color: _err; font.pixelSize: _fontSize * 0.8; font.bold: true }
                            }
                        }
                        QGCLabel { text: "Recording"; color: "white"; font.pixelSize: _fontSize * 1.0; font.bold: true }
                        QGCLabel { text: "Recording off"; color: _dimText; font.pixelSize: _fontSize * 0.8 }
                        QGCLabel { Layout.topMargin: _pad * 0.4; text: "DISABLED"; color: _dimText; font.pixelSize: _fontSize * 0.8; font.bold: true; font.letterSpacing: 0.5 }
                    }
                }
            }

            // ── DRONE STREAMS ───────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: _streamCol.implicitHeight + _pad * 3
                radius: _fontSize * 0.5
                color: _cardBg
                border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                ColumnLayout {
                    id: _streamCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad * 1.8 }
                    spacing: _pad

                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel { text: "DRONE STREAMS"; color: _teal; font.pixelSize: _fontSize * 0.85; font.bold: true; font.letterSpacing: 1 }
                        Item { Layout.fillWidth: true }
                        QGCLabel {
                            text: _droneCount + " / " + _droneCount + " streaming · 16 Mbps"
                            color: _dimText; font.pixelSize: _fontSize * 0.78
                        }
                    }

                    // Connected drones
                    Repeater {
                        model: _vehicleModel
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: _fontSize * 2.6
                            radius: _fontSize * 0.3
                            color: Qt.rgba(1,1,1,0.03)
                            RowLayout {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: _pad; rightMargin: _pad }
                                spacing: _pad * 0.6
                                Rectangle { width: _fontSize * 0.6; height: width; radius: width/2; color: _green }
                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: object ? (qsTr("Vehicle") + " " + object.id) : ""
                                    color: "white"; font.pixelSize: _fontSize * 0.85; elide: Text.ElideRight
                                }
                                QGCLabel { text: "Streaming"; color: _green; font.pixelSize: _fontSize * 0.8; font.bold: true }
                            }
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: _droneCount === 0
                        text: "No drones connected"
                        color: _dimText; font.pixelSize: _fontSize * 0.8
                    }
                }
            }

            // ── PLANS (POST-BETA PRICING) ───────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: _plansCol.implicitHeight + _pad * 3
                radius: _fontSize * 0.5
                color: _cardBg
                border.color: Qt.rgba(1,1,1,0.06); border.width: 1

                ColumnLayout {
                    id: _plansCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad * 1.8 }
                    spacing: _pad

                    QGCLabel { text: "PLANS (POST-BETA PRICING)"; color: _teal; font.pixelSize: _fontSize * 0.85; font.bold: true; font.letterSpacing: 1 }
                    QGCLabel {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        text: "All plans are free until Q3 2026. Prices below are what we'll charge later."
                        color: _dimText; font.pixelSize: _fontSize * 0.78
                    }

                    Repeater {
                        model: _plans
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: _pad * 0.3
                            implicitHeight: _planRow.implicitHeight + _pad * 1.8
                            radius: _fontSize * 0.4
                            color: index === _planIndex ? _greenDim : Qt.rgba(1,1,1,0.03)
                            border.color: index === _planIndex ? _greenBorder : Qt.rgba(1,1,1,0.06); border.width: 1

                            RowLayout {
                                id: _planRow
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: _pad * 1.2; rightMargin: _pad * 1.2 }
                                spacing: _pad

                                Rectangle {
                                    Layout.preferredWidth:  _fontSize * 2.4
                                    Layout.preferredHeight: _fontSize * 2.4
                                    Layout.alignment:       Qt.AlignVCenter
                                    radius: _fontSize * 0.4; color: Qt.rgba(1,1,1,0.06)
                                    Image {
                                        anchors.centerIn: parent
                                        width: _fontSize * 1.7; height: width
                                        source: "/InstrumentValueIcons/" + modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize.width:  width * 2
                                        sourceSize.height: height * 2
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: _pad * 0.2
                                    RowLayout {
                                        spacing: _pad * 0.6
                                        QGCLabel { text: modelData.name; color: "white"; font.pixelSize: _fontSize * 0.95; font.bold: true }
                                        Rectangle {
                                            visible: index === _planIndex
                                            radius: _fontSize * 0.25; color: _orange
                                            Layout.preferredWidth: _fleetPill.implicitWidth + _pad; Layout.preferredHeight: _fontSize * 1.4
                                            QGCLabel { id: _fleetPill; anchors.centerIn: parent; text: "YOUR FLEET"; color: "#1A1206"; font.pixelSize: _fontSize * 0.58; font.bold: true }
                                        }
                                    }
                                    QGCLabel { text: modelData.spec; color: _dimText; font.pixelSize: _fontSize * 0.75 }
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignRight
                                    spacing: 1
                                    QGCLabel { Layout.alignment: Qt.AlignRight; text: "Free"; color: _green; font.pixelSize: _fontSize * 0.95; font.bold: true }
                                    QGCLabel { Layout.alignment: Qt.AlignRight; text: "later: " + modelData.later; color: _dimText; font.pixelSize: _fontSize * 0.7 }
                                    QGCLabel { Layout.alignment: Qt.AlignRight; text: modelData.cost; color: _dimText; font.pixelSize: _fontSize * 0.7 }
                                }
                            }
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth: true; Layout.topMargin: _pad * 0.4
                        horizontalAlignment: Text.AlignHCenter
                        text: "You'll get a heads-up before billing starts · No card needed during beta"
                        color: _teal; font.pixelSize: _fontSize * 0.72
                    }
                }
            }

            Item { Layout.preferredHeight: _pad * 2 }
        }
    }

    // ── Selectable server-choice card ───────────────────────
    component ServerChoiceCard: Rectangle {
        required property int    choice
        required property string icon
        required property string title
        required property string subtitle
        required property string priceNow
        required property string priceWas
        required property string note
        property string badge: ""

        readonly property bool _selected: _root._serverChoice === choice

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: _scCol.implicitHeight + _pad * 3
        radius: _fontSize * 0.5
        color: _selected ? _tealDim : Qt.rgba(1,1,1,0.02)
        border.color: _selected ? _tealBorder : Qt.rgba(1,1,1,0.10)
        border.width: _selected ? 1.5 : 1

        // EASIEST badge
        Rectangle {
            visible: badge !== ""
            anchors { top: parent.top; right: parent.right; margins: _pad }
            radius: _fontSize * 0.25; color: _orange
            width: _badgeLabel.implicitWidth + _pad; height: _fontSize * 1.4
            QGCLabel { id: _badgeLabel; anchors.centerIn: parent; text: badge; color: "#1A1206"; font.pixelSize: _fontSize * 0.58; font.bold: true }
        }

        ColumnLayout {
            id: _scCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: _pad * 1.6 }
            spacing: _pad * 0.6

            RowLayout {
                Layout.fillWidth: true
                QGCColoredImage { width: _fontSize * 1.5; height: width; source: icon; color: _teal; fillMode: Image.PreserveAspectFit }
                QGCLabel { text: title; color: "white"; font.pixelSize: _fontSize * 0.95; font.bold: true; font.letterSpacing: 0.5 }
                Item { Layout.fillWidth: true }
                QGCColoredImage {
                    visible: _selected
                    width: _fontSize * 1.4; height: width
                    source: "/InstrumentValueIcons/checkmark.svg"; color: _teal; fillMode: Image.PreserveAspectFit
                }
            }
            QGCLabel { text: subtitle; color: _dimText; font.pixelSize: _fontSize * 0.72; font.letterSpacing: 0.5 }
            RowLayout {
                Layout.topMargin: _pad * 0.4
                spacing: _pad * 0.5
                QGCLabel { text: priceNow; color: _green; font.pixelSize: _fontSize * 1.1; font.bold: true }
                QGCLabel { text: priceWas; color: _dimText; font.pixelSize: _fontSize * 0.78; font.strikeout: true }
                QGCLabel { text: "LATER"; color: _dimText; font.pixelSize: _fontSize * 0.7 }
            }
            QGCLabel { text: note; color: _dimText; font.pixelSize: _fontSize * 0.7; font.letterSpacing: 0.3 }
        }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: _root._serverChoice = choice
        }
    }
}
