import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// Important Note: SubMenuButtons must manage their checked state manually in order to support
// view switch prevention. This means they can't be checkable or autoExclusive.

Button {
    id:             control
    text:           "Button"
    focusPolicy:    Qt.ClickFocus
    hoverEnabled:   !ScreenTools.isMobile
    implicitHeight: ScreenTools.defaultFontPixelHeight * 2.5

    property bool   setupComplete:  true
    property var    imageColor:     undefined
    property string imageResource:  "/qmlimages/subMenuButtonImage.png"
    property bool   largeSize:      false
    property bool   showHighlight:  control.pressed | control.checked

    property size   sourceSize:     Qt.size(ScreenTools.defaultFontPixelHeight * 2, ScreenTools.defaultFontPixelHeight * 2)

    property ButtonGroup buttonGroup:    null
    onButtonGroupChanged: {
        if (buttonGroup) {
            buttonGroup.addButton(control)
        }
    }

    onCheckedChanged: checkable = false

    readonly property color _teal:       "#00BFFF"
    readonly property color _tealDim:    Qt.rgba(0, 0.749, 1.0, 0.14)
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)

    background: Rectangle {
        id:     innerRect
        color:  showHighlight ? _tealDim : "transparent"
        radius: ScreenTools.defaultFontPixelHeight * 0.4
        border.width: showHighlight ? 1 : 0
        border.color: showHighlight ? _tealBorder : "transparent"

        implicitWidth: titleBar.x + titleBar.contentWidth + ScreenTools.defaultFontPixelWidth

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Left accent bar when selected
        Rectangle {
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin:    ScreenTools.defaultFontPixelHeight * 0.3
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.3
            width:          3
            radius:         1.5
            color:          _teal
            visible:        showHighlight
        }

        // Hover overlay
        Rectangle {
            anchors.fill:   parent
            radius:         parent.radius
            color:          Qt.rgba(0, 0.749, 1.0, 0.08)
            visible:        control.enabled && control.hovered && !showHighlight
        }

        QGCColoredImage {
            id:                     image
            anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 1.2
            anchors.left:           parent.left
            anchors.verticalCenter: parent.verticalCenter
            width:                  ScreenTools.defaultFontPixelHeight * 1.8
            height:                 ScreenTools.defaultFontPixelHeight * 1.8
            fillMode:               Image.PreserveAspectFit
            mipmap:                 true
            color:                  imageColor ? imageColor :
                                    (showHighlight ? _teal :
                                    (control.setupComplete ? Qt.rgba(1,1,1,0.60) : "#FF5252"))
            source:                 control.imageResource
            sourceSize:             control.sourceSize
        }

        QGCLabel {
            id:                     titleBar
            anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
            anchors.left:           image.right
            anchors.verticalCenter: parent.verticalCenter
            verticalAlignment:      TextEdit.AlignVCenter
            color:                  showHighlight ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.70)
            text:                   control.text
            font.bold:              showHighlight
        }
    }

    contentItem: Item {}
}
