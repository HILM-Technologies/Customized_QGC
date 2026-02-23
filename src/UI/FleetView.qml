/****************************************************************************
 *
 * HILM Ground Control — Fleet View (Placeholder)
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl.Controls

Rectangle {
    id:    _root
    color: "#0D1117"

    readonly property color _teal:    "#00BFFF"
    readonly property color _dimText: Qt.rgba(1, 1, 1, 0.50)

    ColumnLayout {
        anchors.centerIn: parent
        spacing:          ScreenTools.defaultFontPixelHeight

        QGCColoredImage {
            Layout.alignment:       Qt.AlignHCenter
            width:                  ScreenTools.defaultFontPixelHeight * 4
            height:                 width
            source:                 "/qmlimages/Quad.svg"
            color:                  _teal
            fillMode:               Image.PreserveAspectFit
        }

        QGCLabel {
            Layout.alignment:   Qt.AlignHCenter
            text:               "FLEET MANAGEMENT"
            color:              "white"
            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 1.5
            font.bold:          true
            font.letterSpacing: 2
        }

        QGCLabel {
            Layout.alignment:   Qt.AlignHCenter
            text:               "Fleet management view coming soon"
            color:              _dimText
            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.9
        }
    }
}
