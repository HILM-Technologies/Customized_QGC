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
import QGroundControl.UTMSP

Item {
    id:         control
    width:      mainLayout.width + _hilmFramePad * 2
    visible:    _utmspEnabled === true ? utmspSliderTrigger: false

    property var    guidedController
    property var    guidedValueSlider
    property var    messageDisplay
    property string title
    property string message
    property int    action
    property var    actionData
    property bool   hideTrigger:        false
    property var    mapIndicator
    property alias  optionText:         optionCheckBox.text
    property alias  optionChecked:      optionCheckBox.checked

    property real _margins:         2
    property bool _emergencyAction: action === guidedController.actionEmergencyStop

    // HILM theme tokens
    readonly property color _hilmTeal:     "#00BFFF"
    readonly property color _hilmAccent:   _emergencyAction ? "#FF5252" : _hilmTeal
    readonly property color _hilmBg:       Qt.rgba(0, 0, 0, 0.82)
    readonly property color _hilmBorder:   Qt.rgba(_hilmAccent.r, _hilmAccent.g, _hilmAccent.b, 0.55)
    readonly property real  _hilmFramePad: ScreenTools.defaultFontPixelWidth * 0.8

    // Properties of UTM adapter
    property bool   utmspSliderTrigger
    property bool   _utmspEnabled:                       QGroundControl.utmspSupported

    Component.onCompleted: guidedController.confirmDialog = this

    onHideTriggerChanged: {
        if (hideTrigger) {
            confirmCancelled()
        }
    }

    function show(immediate) {
        if (immediate) {
            _reallyShow()
        } else {
            // We delay showing the confirmation for a small amount in order for any other state
            // changes to propogate through the system. This way only the final state shows up.
            visibleTimer.restart()
        }
    }

    function confirmCancelled() {
        guidedValueSlider.visible = false
        visible = false
        hideTrigger = false
        visibleTimer.stop()
        messageDisplay.opacity = 1.0
        messageFadeTimer.stop()
        messageOpacityAnimation.stop()
        if (mapIndicator) {
            mapIndicator.actionCancelled()
            mapIndicator = undefined
        }
    }

    function _reallyShow() {
        visible = true
        messageDisplay.opacity = 1.0
        messageFadeTimer.start()
    }

    Timer {
        id:             visibleTimer
        interval:       1000
        repeat:         false
        onTriggered:    _reallyShow()
    }

    Timer {
        id:             messageFadeTimer
        interval:       5000
        repeat:         false
        onTriggered:    messageOpacityAnimation.start()
    }

    NumberAnimation {
        id:         messageOpacityAnimation
        target:     messageDisplay
        property:   "opacity"
        from:       1.0
        to:         0.0
        duration:   2000
    }

    QGCPalette { id: qgcPal }

    Rectangle {
        anchors.fill:    mainLayout
        anchors.margins: -_hilmFramePad
        radius:          ScreenTools.defaultFontPixelHeight * 0.45
        color:           _hilmBg
        border.width:    1
        border.color:    _hilmBorder
    }

    RowLayout {
        id:         mainLayout
        x:          _hilmFramePad
        y:          2 + _hilmFramePad
        height:     parent.height - 4 - (_hilmFramePad * 2)
        spacing:    ScreenTools.defaultFontPixelWidth

        QGCDelayButton {
            text:               control.title
            enabled:            _utmspEnabled === true? utmspSliderTrigger : true
            opacity:            if(_utmspEnabled){utmspSliderTrigger === true ? 1 : 0.5} else{1}
            backgroundColor:    Qt.rgba(_hilmAccent.r, _hilmAccent.g, _hilmAccent.b, 0.18)
            textColor:          "white"
            fontWeight:         Font.DemiBold

            onActivated: {
                control.visible = false
                var sliderOutputValue = 0
                if (guidedValueSlider.visible) {
                    sliderOutputValue = guidedValueSlider.getOutputValue()
                    guidedValueSlider.visible = false
                }
                hideTrigger = false
                guidedController.executeAction(control.action, control.actionData, sliderOutputValue, control.optionChecked)
                if (mapIndicator) {
                    mapIndicator.actionConfirmed()
                    mapIndicator = undefined
                }

                UTMSPStateStorage.indicatorOnMissionStatus = true
                UTMSPStateStorage.currentNotificationIndex = 7
                UTMSPStateStorage.currentStateIndex = 3
            }
        }

        QGCCheckBox {
            id:                 optionCheckBox
            visible:            text !== ""
        }

        QGCColoredImage {
            id:                 closeButton
            Layout.alignment:   Qt.AlignTop
            width:              height
            height:             ScreenTools.defaultFontPixelHeight * 0.5
            source:             "/res/XDelete.svg"
            fillMode:           Image.PreserveAspectFit
            color:              qgcPal.text

            QGCMouseArea {
                fillItem:   parent
                onClicked:  confirmCancelled()
            }
        }
    }
}
