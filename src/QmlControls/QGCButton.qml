import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Standard push button control:
///     If there is both an icon and text the icon will be to the left of the text
///     If icon only, icon will be centered
Button {
    property bool primary: false
    property bool showBorder: qgcPal.globalTheme === QGCPalette.Light
    property real backRadius: ScreenTools.defaultBorderRadius
    property real heightFactor: 0.5
    property string iconSource: ""
    property real fontWeight: Font.Normal // default for qml Text
    property real pointSize: ScreenTools.defaultFontPointSize

    property alias wrapMode: text.wrapMode
    property alias horizontalAlignment: text.horizontalAlignment
    property alias backgroundColor: backRect.color
    property alias textColor: text.color

    id: control
    hoverEnabled: !ScreenTools.isMobile
    topPadding: _verticalPadding
    bottomPadding: _verticalPadding
    leftPadding: _horizontalPadding
    rightPadding: _horizontalPadding
    focusPolicy: Qt.ClickFocus
    font.family: ScreenTools.normalFontFamily
    text: ""

    // ── HILM design tokens ───────────────────────────────────────
    readonly property color _teal:      "#00C8C8"
    readonly property color _tealDim:   Qt.rgba(0, 0.784, 0.784, 0.18)
    readonly property color _tealBorder:Qt.rgba(0, 0.784, 0.784, 0.45)

    property bool _showHighlight: enabled && (pressed | checked)
    property int _horizontalPadding: ScreenTools.defaultFontPixelWidth * 2
    property int _verticalPadding: Math.round(ScreenTools.defaultFontPixelHeight * heightFactor) - (iconSource === "" ? 0 : (_iconHeight - ScreenTools.defaultFontPixelHeight)  / 2)
    property real _iconHeight: text.height * 1.5

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    background: Rectangle {
        id: backRect
        radius: backRadius
        implicitWidth: ScreenTools.implicitButtonWidth
        implicitHeight: ScreenTools.implicitButtonHeight
        // Primary and pressed/checked → solid teal; hover → dim teal; normal → palette button
        color: (control._showHighlight || control.primary)
                   ? (control.pressed ? Qt.darker(control._teal, 1.20) : control._teal)
                   : qgcPal.button
        border.width: (!control._showHighlight && !control.primary && control.enabled && control.hovered) ? 1 : (showBorder ? 1 : 0)
        border.color: (!control._showHighlight && !control.primary && control.enabled && control.hovered)
                          ? control._tealBorder : qgcPal.buttonBorder

        // Hover glow on normal (non-primary, non-pressed) buttons
        Rectangle {
            anchors.fill: parent
            color:        control._tealDim
            opacity:      (!control._showHighlight && !control.primary && control.enabled && control.hovered) ? 1 : 0
            radius:       parent.radius
        }

        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    contentItem: RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth

        QGCColoredImage {
            id: icon
            Layout.alignment: Qt.AlignHCenter
            source: control.iconSource
            height: _iconHeight
            width: height
            color: text.color
            fillMode: Image.PreserveAspectFit
            sourceSize.height: height
            visible: control.iconSource !== ""
        }

        QGCLabel {
            id: text
            Layout.alignment: Qt.AlignHCenter
            text: control.text
            font.pointSize: control.pointSize
            font.family: control.font.family
            font.weight: fontWeight
            // Dark text on teal (pressed/primary), normal text otherwise
            color: (control._showHighlight || control.primary) ? "#001a1a" : qgcPal.buttonText
            visible: control.text !== ""

            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }
}
