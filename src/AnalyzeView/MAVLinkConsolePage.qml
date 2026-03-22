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

AnalyzePage {
    id: root
    pageComponent: pageComponent
    pageDescription: qsTr("Provides a connection to the vehicle's system shell.")
    allowPopout: true

    property bool isLoaded: false

    readonly property bool  _separateCommandInput: ScreenTools.isMobile
    readonly property color _teal:       "#00BFFF"
    readonly property color _tealBorder: Qt.rgba(0, 0.749, 1.0, 0.32)
    readonly property color _cardBg:     Qt.rgba(1, 1, 1, 0.04)

    MAVLinkConsoleController { id: conController }

    Component {
        id: pageComponent

        ColumnLayout {
            height: availableHeight
            width: availableWidth
            property int _consoleOutputLen: 0

            function scrollToBottom() {
                if (flickable.contentHeight > flickable.height) {
                    flickable.contentY = flickable.contentHeight - flickable.height
                }
            }

            function getCommand() { return textConsole.getText(_consoleOutputLen, textConsole.length) }

            function getCommandAndClear() {
                const command = getCommand()
                textConsole.remove(_consoleOutputLen, textConsole.length)
                return command
            }

            function pasteFromClipboard() {
                const cursor = textConsole.cursorPosition - _consoleOutputLen
                var command = getCommandAndClear()
                var command_pre = ""
                var command_post = command
                if (cursor > 0) {
                    command_pre = command.substr(0, cursor)
                    command_post = command.substr(cursor)
                }
                var command_leftover = conController.handleClipboard(command_pre) + command_post
                textConsole.insert(textConsole.length, command_leftover)
                textConsole.cursorPosition = textConsole.length - command_post.length
            }

            Connections {
                target: conController
                function onDataChanged(topLeft, bottomRight, roles) {
                    if (isLoaded) {
                        updateTimer.start();
                    }
                }
            }

            Timer {
                id: updateTimer
                interval: 30
                running: false
                repeat: false
                onTriggered: {
                    if (flickable.atYEnd) {
                        const command = getCommand()
                        const cursor = textConsole.cursorPosition - _consoleOutputLen
                        textConsole.text = conController.text
                        _consoleOutputLen = textConsole.length
                        textConsole.insert(textConsole.length, command)
                        textConsole.cursorPosition = textConsole.length
                        scrollToBottom()
                        if (cursor >= 0) {
                            textConsole.cursorPosition = _consoleOutputLen + cursor
                        }
                    } else {
                        updateTimer.start();
                    }
                }
            }

            // ── Console card ──
            Rectangle {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                color:             _cardBg
                radius:            ScreenTools.defaultFontPixelHeight * 0.5
                border.width:      1
                border.color:      _tealBorder
                clip:              true

                QGCFlickable {
                    id: flickable
                    anchors.fill:       parent
                    anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.8
                    contentWidth:       textConsole.width
                    contentHeight:      textConsole.height

                    TextArea.flickable: TextArea {
                        id: textConsole
                        width: availableWidth - ScreenTools.defaultFontPixelWidth * 1.6
                        wrapMode: Text.WordWrap
                        readOnly: _separateCommandInput
                        textFormat: TextEdit.RichText
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhMultiLine
                        text: "> "
                        focus: true
                        color: "#00E04B"
                        selectedTextColor: "#0D1117"
                        selectionColor: _teal
                        font.pointSize: ScreenTools.defaultFontPointSize
                        font.family: ScreenTools.fixedFontFamily

                        Component.onCompleted: {
                            root.isLoaded = true
                            _consoleOutputLen = textConsole.length
                            textConsole.cursorPosition = _consoleOutputLen
                            if (!_separateCommandInput) {
                                textConsole.forceActiveFocus()
                            }
                        }

                        background: Rectangle { color: "transparent" }

                        Keys.onPressed: (event) => {
                            if (event.key == Qt.Key_Tab) {
                                event.accepted = true
                            }
                            if (event.matches(StandardKey.Cut)) {
                                event.accepted = true
                            }
                            if (!event.matches(StandardKey.Copy) &&
                                event.key != Qt.Key_Escape &&
                                event.key != Qt.Key_Insert &&
                                event.key != Qt.Key_Pause &&
                                event.key != Qt.Key_Print &&
                                event.key != Qt.Key_SysReq &&
                                event.key != Qt.Key_Clear &&
                                event.key != Qt.Key_Home &&
                                event.key != Qt.Key_End &&
                                event.key != Qt.Key_Left &&
                                event.key != Qt.Key_Up &&
                                event.key != Qt.Key_Right &&
                                event.key != Qt.Key_Down &&
                                event.key != Qt.Key_PageUp &&
                                event.key != Qt.Key_PageDown &&
                                event.key != Qt.Key_Shift &&
                                event.key != Qt.Key_Control &&
                                event.key != Qt.Key_Meta &&
                                event.key != Qt.Key_Alt &&
                                event.key != Qt.Key_AltGr &&
                                event.key != Qt.Key_CapsLock &&
                                event.key != Qt.Key_NumLock &&
                                event.key != Qt.Key_ScrollLock &&
                                event.key != Qt.Key_Super_L &&
                                event.key != Qt.Key_Super_R &&
                                event.key != Qt.Key_Menu &&
                                event.key != Qt.Key_Hyper_L &&
                                event.key != Qt.Key_Hyper_R &&
                                event.key != Qt.Key_Direction_L &&
                                event.key != Qt.Key_Direction_R) {
                                scrollToBottom()
                                if (textConsole.selectionStart < _consoleOutputLen) {
                                    textConsole.select(_consoleOutputLen, textConsole.selectionEnd)
                                }
                                if (textConsole.cursorPosition < _consoleOutputLen) {
                                    textConsole.cursorPosition = textConsole.length
                                }
                            }
                            switch (event.key) {
                            case Qt.Key_Left:
                                if (textConsole.cursorPosition == _consoleOutputLen) {
                                    event.accepted = true
                                }
                                break;
                            case Qt.Key_Backspace:
                                if (textConsole.cursorPosition <= _consoleOutputLen) {
                                    event.accepted = true
                                }
                                break;
                            case Qt.Key_Enter:
                            case Qt.Key_Return:
                                conController.sendCommand(getCommandAndClear())
                                event.accepted = true
                                break;
                            default:
                                break;
                            }
                            if (event.matches(StandardKey.Paste)) {
                                pasteFromClipboard()
                                event.accepted = true
                            }
                            if (event.key == Qt.Key_Up) {
                                const command = conController.historyUp(getCommandAndClear())
                                textConsole.insert(textConsole.length, command)
                                textConsole.cursorPosition = textConsole.length
                                event.accepted = true
                            } else if (event.key == Qt.Key_Down) {
                                const command = conController.historyDown(getCommandAndClear())
                                textConsole.insert(textConsole.length, command)
                                textConsole.cursorPosition = textConsole.length
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            // ── Mobile command input ──
            RowLayout {
                Layout.fillWidth: true
                visible: _separateCommandInput

                QGCTextField {
                    id: commandInput
                    Layout.fillWidth: true
                    placeholderText:  qsTr("Enter Commands here...")
                    inputMethodHints: Qt.ImhNoAutoUppercase
                    onAccepted: sendCommand()

                    function sendCommand() {
                        conController.sendCommand(text)
                        text = ""
                        scrollToBottom()
                    }
                }

                QGCButton {
                    text: qsTr("Send")
                    onClicked: commandInput.sendCommand()
                }
            }
        }
    }
}
