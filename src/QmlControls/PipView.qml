/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Window

import QGroundControl
import QGroundControl.Controls

Item {
    id:         _root
    width:      _pipSize
    height:     _pipSize * (9/16)
    visible:    item2 && item2.pipState !== item2.pipState.window && show

    property var    item1:                  null    // Required
    property var    item2:                  null    // Optional, may come and go
    property string item1IsFullSettingsKey          // Settings key to save whether item1 was saved in full mode
    property bool   show:                   true

    readonly property string _pipExpandedSettingsKey: "IsPIPVisible"

    property var    _fullItem
    property var    _pipOrWindowItem
    property alias  _windowContentItem: window.contentItem
    property alias  _pipContentItem:    pipContent
    property bool   _isExpanded:        true
    property real   _pipSize:           parent.width * 0.2
    property real   _maxSize:           0.75
    property real   _minSize:           0.10
    property bool   _componentComplete: false

    // ── HILM design tokens ────────────────────────────────────────────────────
    readonly property color _teal:       "#00C8C8"
    readonly property color _tealBorder: Qt.rgba(0, 0.784, 0.784, 0.55)
    readonly property color _tealDim:    Qt.rgba(0, 0.784, 0.784, 0.12)
    readonly property color _headerBg:   Qt.rgba(0.03, 0.05, 0.05, 0.90)

    Component.onCompleted: {
        _initForItems()
        _componentComplete = true
    }

    onItem2Changed: _initForItems()

    function showWindow() {
        window.width  = _root.width
        window.height = _root.height
        window.show()
    }

    function _initForItems() {
        var item1IsFull = QGroundControl.loadBoolGlobalSetting(item1IsFullSettingsKey, true)
        if (item1 && item2) {
            item1.pipState.state = item1IsFull ? item1.pipState.fullState : item1.pipState.pipState
            item2.pipState.state = item1IsFull ? item2.pipState.pipState : item2.pipState.fullState
            _fullItem        = item1IsFull ? item1 : item2
            _pipOrWindowItem = item1IsFull ? item2 : item1
        } else {
            item1.pipState.state = item1.pipState.fullState
            _fullItem        = item1
            _pipOrWindowItem = null
        }
        _setPipIsExpanded(QGroundControl.loadBoolGlobalSetting(_pipExpandedSettingsKey, true))
    }

    function _swapPip() {
        var item1IsFull = false
        if (item1.pipState.state === item1.pipState.fullState) {
            item1.pipState.state = item1.pipState.pipState
            item2.pipState.state = item2.pipState.fullState
            _fullItem        = item2
            _pipOrWindowItem = item1
            item1IsFull      = false
        } else {
            item1.pipState.state = item1.pipState.fullState
            item2.pipState.state = item2.pipState.pipState
            _fullItem        = item1
            _pipOrWindowItem = item2
            item1IsFull      = true
        }
        QGroundControl.saveBoolGlobalSetting(item1IsFullSettingsKey, item1IsFull)
    }

    function _setPipIsExpanded(isExpanded) {
        QGroundControl.saveBoolGlobalSetting(_pipExpandedSettingsKey, isExpanded)
        _isExpanded = isExpanded
    }

    // ── Detached window (pop-out) ─────────────────────────────────────────────
    Window {
        id:      window
        title:   qsTr("Video Feed")
        visible: false
        onClosing: {
            var item = contentItem.children[0]
            if (item) {
                item.pipState.windowAboutToClose()
                item.pipState.state = item.pipState.pipState
            }
        }
    }

    // ── Video content area ────────────────────────────────────────────────────
    Item {
        id:             pipContent
        anchors.fill:   parent
        visible:        _isExpanded
        clip:           true
    }

    // ── Teal border frame ─────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:        "transparent"
        radius:       4
        visible:      _isExpanded
        border.color: pipMouseArea.containsMouse
                          ? _tealBorder
                          : Qt.rgba(0, 0.784, 0.784, 0.22)
        border.width: pipMouseArea.containsMouse ? 2 : 1
        Behavior on border.color { ColorAnimation  { duration: 160 } }
        Behavior on border.width { NumberAnimation { duration: 160 } }
    }

    // ── Full-area swap click handler ──────────────────────────────────────────
    MouseArea {
        id:              pipMouseArea
        anchors.fill:    parent
        enabled:         _isExpanded
        preventStealing: true
        hoverEnabled:    true
        onClicked:       _swapPip()
    }

    // ── Header bar (visible on hover) ─────────────────────────────────────────
    Rectangle {
        id:           pipHeader
        anchors.top:  parent.top
        anchors.left: parent.left; anchors.right: parent.right
        height:       ScreenTools.defaultFontPixelHeight * 1.80
        radius:       4
        color:        _headerBg
        visible:      _isExpanded && (ScreenTools.isMobile || pipMouseArea.containsMouse)
        opacity:      pipMouseArea.containsMouse ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        // Bottom separator line
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left:   parent.left; anchors.right: parent.right
            height: 1; color: Qt.rgba(0, 0.784, 0.784, 0.28)
        }

        // Left: pulsing dot + VIDEO label
        Row {
            anchors.left:           parent.left
            anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 0.85
            anchors.verticalCenter: parent.verticalCenter
            spacing:                ScreenTools.defaultFontPixelWidth * 0.55

            Rectangle {
                width: 5; height: 5; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: _teal
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 850 }
                    NumberAnimation { to: 1.00; duration: 850 }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:           qsTr("VIDEO")
                color:          _teal
                font.bold:      true
                font.letterSpacing: 1.8
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.62
            }
        }

        // Right: pop-out + hide buttons
        Row {
            anchors.right:          parent.right
            anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 0.5
            anchors.verticalCenter: parent.verticalCenter
            spacing:                ScreenTools.defaultFontPixelWidth * 0.4

            // Pop-out to window button
            Rectangle {
                width:   ScreenTools.defaultFontPixelHeight * 1.40
                height:  width
                radius:  3
                visible: !ScreenTools.isMobile
                color:   popoutHover.containsMouse
                             ? Qt.rgba(0, 0.784, 0.784, 0.26)
                             : Qt.rgba(0, 0.784, 0.784, 0.10)
                border.color: Qt.rgba(0, 0.784, 0.784,
                                      popoutHover.containsMouse ? 0.72 : 0.35)
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 110 } }
                Behavior on border.color { ColorAnimation { duration: 110 } }

                Text {
                    anchors.centerIn: parent
                    text:  "\u2197"       // ↗ north-east arrow
                    color: _teal
                    font.pixelSize: parent.height * 0.54
                }

                MouseArea {
                    id:           popoutHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    _pipOrWindowItem.pipState.state = _pipOrWindowItem.pipState.windowState
                }
            }

            // Hide / minimise button
            Rectangle {
                width:   ScreenTools.defaultFontPixelHeight * 1.40
                height:  width
                radius:  3
                color:   hideHover.containsMouse
                             ? Qt.rgba(1, 0.18, 0.18, 0.24)
                             : Qt.rgba(1, 1, 1, 0.07)
                border.color: hideHover.containsMouse
                                  ? Qt.rgba(1, 0.28, 0.28, 0.62)
                                  : Qt.rgba(1, 1, 1, 0.18)
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 110 } }
                Behavior on border.color { ColorAnimation { duration: 110 } }

                Text {
                    anchors.centerIn: parent
                    text:  "\u2715"       // ✕
                    color: hideHover.containsMouse ? "#FF6666" : Qt.rgba(1, 1, 1, 0.60)
                    font.pixelSize: parent.height * 0.48
                    Behavior on color { ColorAnimation { duration: 110 } }
                }

                MouseArea {
                    id:           hideHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    _root._setPipIsExpanded(false)
                }
            }
        }
    }

    // ── Resize corner indicator (bottom-right, shown on hover) ───────────────
    Item {
        id:             pipResizeHandle
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        width:          ScreenTools.defaultFontPixelHeight * 2.5
        height:         ScreenTools.defaultFontPixelHeight * 2.5
        visible:        _isExpanded && (ScreenTools.isMobile || pipMouseArea.containsMouse)

        // L-bracket corner marks
        Rectangle {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.rightMargin: 3; anchors.bottomMargin: 3
            width: parent.width * 0.52; height: 2; radius: 1
            color: Qt.rgba(0, 0.784, 0.784, 0.65)
        }
        Rectangle {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.rightMargin: 3; anchors.bottomMargin: 3
            width: 2; height: parent.height * 0.52; radius: 1
            color: Qt.rgba(0, 0.784, 0.784, 0.65)
        }
    }

    // Resize drag — same logic as original, now references pipResizeHandle
    MouseArea {
        id:                 pipResize
        anchors.fill:       pipResizeHandle
        preventStealing:    true
        cursorShape:        Qt.SizeFDiagCursor

        property real initialX:     0
        property real initialWidth: 0

        onPressed: (mouse) => {
            pipResize.anchors.fill = undefined
            pipResize.initialX     = mouse.x
            pipResize.initialWidth = _root.width
        }

        onReleased: pipResize.anchors.fill = pipResizeHandle

        onPositionChanged: (mouse) => {
            if (pipResize.pressed) {
                var parentWidth = _root.parent.width
                var newWidth    = pipResize.initialWidth + mouse.x - pipResize.initialX
                if (newWidth < parentWidth * _maxSize && newWidth > parentWidth * _minSize) {
                    _pipSize = newWidth
                }
            }
        }
    }

    // ── Collapsed-state restore button ────────────────────────────────────────
    Rectangle {
        id:             showPip
        anchors.left:   parent.left
        anchors.bottom: parent.bottom
        width:          ScreenTools.defaultFontPixelHeight * 2.2
        height:         ScreenTools.defaultFontPixelHeight * 2.2
        radius:         4
        visible:        !_isExpanded
        color:          showPipHover.containsMouse
                            ? Qt.rgba(0, 0.784, 0.784, 0.26)
                            : Qt.rgba(0.03, 0.05, 0.05, 0.88)
        border.color:   Qt.rgba(0, 0.784, 0.784,
                                showPipHover.containsMouse ? 0.78 : 0.40)
        border.width:   1
        Behavior on color        { ColorAnimation { duration: 130 } }
        Behavior on border.color { ColorAnimation { duration: 130 } }

        Text {
            anchors.centerIn: parent
            text:  "\u25B6"       // ▶
            color: _teal
            font.pixelSize: parent.height * 0.42
        }

        MouseArea {
            id:           showPipHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    _root._setPipIsExpanded(true)
        }
    }

    // ── Parent-resize constraint ──────────────────────────────────────────────
    Connections {
        target: _root.parent

        function onWidthChanged() {
            if (!_componentComplete) return
            var parentWidth = _root.parent.width
            if (_root.width > parentWidth * _maxSize) {
                _pipSize = parentWidth * _maxSize
            } else if (_root.width < parentWidth * _minSize) {
                _pipSize = parentWidth * _minSize
            }
        }
    }
}
