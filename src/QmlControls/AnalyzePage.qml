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

import QGroundControl
import QGroundControl.Controls

/// Base view control for all Analyze pages
Item {
    anchors.fill:               parent
    anchors.margins:            ScreenTools.defaultFontPixelWidth

    property alias  pageComponent:      pageLoader.sourceComponent
    property alias  pageName:           pageNameLabel.text
    property alias  pageDescription:    pageDescriptionLabel.text
    property alias  headerComponent:    headerLoader.sourceComponent
    property real   availableWidth:     width  - pageLoader.x
    property real   availableHeight:    height - mainContent.y
    property bool   allowPopout:        false
    property bool   popped:             false
    property real   _margins:           ScreenTools.defaultFontPixelHeight * 0.5

    // HILM tokens
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _dimText:    Qt.rgba(1, 1, 1, 0.50)

    signal popout()

    Loader {
        id:                     headerLoader
        anchors.topMargin:      _margins
        anchors.top:            parent.top
        anchors.left:           parent.left
        anchors.rightMargin:    _margins
        anchors.right:          floatIcon.left
        visible:                !ScreenTools.isShortScreen && headerLoader.sourceComponent !== null
    }

    Column {
        id:                     headingColumn
        anchors.topMargin:      _margins
        anchors.top:            parent.top
        anchors.left:           parent.left
        anchors.rightMargin:    _margins
        anchors.right:          floatIcon.visible ? floatIcon.left : parent.right
        spacing:                _margins
        visible:                !ScreenTools.isShortScreen && headerLoader.sourceComponent === null
        QGCLabel {
            id:                 pageNameLabel
            font.pointSize:     ScreenTools.largeFontPointSize
            color:              _teal
            font.bold:          true
            visible:            !popped
        }
        QGCLabel {
            id:                 pageDescriptionLabel
            anchors.left:       parent.left
            anchors.right:      parent.right
            wrapMode:           Text.WordWrap
            color:              _dimText
        }
    }

    Item {
        id:                     mainContent
        anchors.topMargin:      ScreenTools.defaultFontPixelHeight
        anchors.top:            headerLoader.sourceComponent === null ? (headingColumn.visible ? headingColumn.bottom : parent.top) : headerLoader.bottom
        anchors.bottom:         parent.bottom
        anchors.left:           parent.left
        anchors.right:          parent.right
        clip:                   true
        Loader {
            id:                 pageLoader
        }
    }

    // Popout button — teal icon with hover glow
    Rectangle {
        id:                     floatIcon
        anchors.verticalCenter: headerLoader.visible ? headerLoader.verticalCenter : headingColumn.verticalCenter
        anchors.right:          parent.right
        width:                  ScreenTools.defaultFontPixelHeight * 2.2
        height:                 width
        radius:                 ScreenTools.defaultFontPixelHeight * 0.4
        color:                  floatMa.containsMouse ? Qt.rgba(0, 0.749, 1.0, 0.12) : "transparent"
        border.width:           floatMa.containsMouse ? 1 : 0
        border.color:           _tealBorder
        visible:                allowPopout && !popped && !ScreenTools.isMobile

        Behavior on color { ColorAnimation { duration: 150 } }

        QGCColoredImage {
            anchors.centerIn:   parent
            width:              ScreenTools.defaultFontPixelHeight * 1.6
            height:             width
            sourceSize.width:   width
            source:             "/qmlimages/FloatingWindow.svg"
            fillMode:           Image.PreserveAspectFit
            color:              floatMa.containsMouse ? _teal : Qt.rgba(1,1,1,0.60)
        }

        MouseArea {
            id:             floatMa
            anchors.fill:   parent
            hoverEnabled:   true
            cursorShape:    Qt.PointingHandCursor
            onClicked:      popout()
        }
    }
}
