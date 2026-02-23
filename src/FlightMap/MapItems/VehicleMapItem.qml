/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Effects
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls

/// Marker for displaying a vehicle location on the map
MapQuickItem {
    id: _root

    property var    vehicle                                                         /// Vehicle object, undefined for ADSB vehicle
    property var    map
    property double altitude:       Number.NaN                                      ///< NAN to not show
    property string callsign:       ""                                              ///< Vehicle callsign
    property double heading:        vehicle ? vehicle.heading.value : Number.NaN    ///< Vehicle heading, NAN for none
    property real   size:           ScreenTools.defaultFontPixelHeight * 3          /// Default size for icon
    property bool   alert:          false                                           /// Collision alert

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool   _adsbVehicle:   vehicle ? false : true
    property var    _map:           map

    // ── HILM design tokens ─────────────────────────────────────────────────────
    readonly property color _teal:        "#00C8C8"
    readonly property color _tealDim:     Qt.rgba(0, 0.784, 0.784, 0.15)
    readonly property color _tealGlow:    Qt.rgba(0, 0.784, 0.784, 0.22)
    readonly property color _activeColor: Qt.rgba(0, 0.784, 0.784, 0.28)

    property real _circleSize: _root.size * 0.95

    anchorPoint.x: _adsbVehicle ? vehicleItem.width  / 2 : _circleSize / 2
    anchorPoint.y: _adsbVehicle ? vehicleItem.height / 2 : _circleSize / 2
    visible:       coordinate.isValid

    QGCPalette { id: qgcPal }

    sourceItem: Item {
        id:      vehicleItem
        width:   _adsbVehicle ? adsbIcon.width  : Math.max(_circleSize, labelCol.implicitWidth)
        height:  _adsbVehicle ? adsbIcon.height : _circleSize + (labelCol.visible ? labelCol.implicitHeight + 4 : 0)
        opacity: _adsbVehicle || vehicle === _activeVehicle ? 1.0 : 0.55

        // ══════════════════════════════════════════════════════════════════════
        //  ADSB VEHICLE — unchanged shadow + icon + label
        // ══════════════════════════════════════════════════════════════════════
        MultiEffect {
            source:                 adsbIcon
            shadowEnabled:          _adsbVehicle
            shadowColor:            Qt.rgba(0.94, 0.91, 0, 1.0)
            shadowVerticalOffset:   4
            shadowHorizontalOffset: 4
            shadowBlur:             1.0
            shadowOpacity:          0.5
            shadowScale:            1.3
            blurMax:                32
            blurMultiplier:         0.1
        }

        Image {
            id:                 adsbIcon
            source:             _adsbVehicle ? (alert ? "/qmlimages/AlertAircraft.svg" : "/qmlimages/AwarenessAircraft.svg") : ""
            mipmap:             true
            width:              _root.size
            sourceSize.width:   _root.size
            fillMode:           Image.PreserveAspectFit
            visible:            _adsbVehicle
        }

        QGCMapLabel {
            anchors.top:              adsbIcon.bottom
            anchors.horizontalCenter: adsbIcon.horizontalCenter
            map:                      _map
            text:                     !isNaN(altitude)
                                          ? (QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(altitude).toFixed(0)
                                             + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
                                             + "\n" + callsign)
                                          : ""
            font.pointSize:           ScreenTools.defaultFontPointSize
            visible:                  _adsbVehicle && !isNaN(altitude)
        }

        // ══════════════════════════════════════════════════════════════════════
        //  HILM VEHICLE — teal circle + rotating icon
        // ══════════════════════════════════════════════════════════════════════
        Item {
            id:      droneItem
            x:       (vehicleItem.width - _circleSize) / 2
            width:   _circleSize
            height:  _circleSize
            visible: !_adsbVehicle

            // Outer glow ring
            Rectangle {
                anchors.centerIn: parent
                width:            parent.width  + 10
                height:           parent.height + 10
                radius:           width / 2
                color:            "transparent"
                border.color:     _tealGlow
                border.width:     3
            }

            // Main circle — brighter border when active vehicle
            Rectangle {
                anchors.fill: parent
                radius:       width / 2
                color:        vehicle && vehicle === _activeVehicle ? _activeColor : _tealDim
                border.color: _teal
                border.width: vehicle && vehicle === _activeVehicle ? 2.5 : 1.5
            }

            // Vehicle icon — drone top-view, rotates with heading
            Image {
                id:               vehicleIcon
                anchors.centerIn: parent
                source:           "/qmlimages/droneTopView.svg"
                mipmap:           true
                width:            _circleSize * 0.72
                sourceSize.width: width
                fillMode:         Image.PreserveAspectFit
                transform: Rotation {
                    origin.x: vehicleIcon.width  / 2
                    origin.y: vehicleIcon.height / 2
                    angle:    isNaN(heading) ? 0 : heading
                }
            }

            // Gimbal direction indicator (preserved from original)
            Repeater {
                model: vehicle ? vehicle.gimbalController.gimbals : []

                Item {
                    id:               canvasItem
                    anchors.centerIn: droneItem
                    width:            droneItem.width  * 2
                    height:           droneItem.height * 2
                    property var gimbalYaw: object.absoluteYaw.rawValue
                    rotation:         gimbalYaw + 180
                    onGimbalYawChanged: canvas.requestPaint()
                    visible:          vehicle && !isNaN(gimbalYaw) && QGroundControl.settingsManager.gimbalControllerSettings.showAzimuthIndicatorOnMap.rawValue
                    opacity:          object === vehicle.gimbalController.activeGimbal ? 1.0 : 0.4

                    Canvas {
                        id:                          canvas
                        anchors.centerIn:             canvasItem
                        anchors.verticalCenterOffset: droneItem.width
                        width:                        droneItem.width
                        height:                       droneItem.height
                        onPaint:                      paintHeading()

                        function paintHeading() {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width  / 2
                            var cy = height / 2
                            var w  = width  * 0.6
                            ctx.save()
                            ctx.globalAlpha = 0.9
                            ctx.beginPath()
                            ctx.moveTo(cx,     cy + height * 0.2)
                            ctx.lineTo(cx - w, cy + height * 0.6)
                            ctx.lineTo(cx,     cy - height * 0.5)
                            ctx.lineTo(cx + w, cy + height * 0.6)
                            ctx.lineTo(cx,     cy + height * 0.2)
                            ctx.closePath()
                            const grad = ctx.createLinearGradient(cx, height, cx, 0)
                            grad.addColorStop(0.3, Qt.rgba(255, 255, 255, 0))
                            grad.addColorStop(0.5, Qt.rgba(255, 255, 255, 0.5))
                            grad.addColorStop(1.0, qgcPal.mapIndicator)
                            ctx.fillStyle = grad
                            ctx.fill()
                            ctx.restore()
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        //  STATUS LABELS — below the circle
        // ══════════════════════════════════════════════════════════════════════
        Column {
            id:                       labelCol
            anchors.top:              droneItem.bottom
            anchors.topMargin:        3
            anchors.horizontalCenter: droneItem.horizontalCenter
            visible:                  !_adsbVehicle && vehicle !== null
            spacing:                  2

            // "V{id} — ARMED / DISARMED / flightMode"
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                color:  Qt.rgba(0, 0, 0, 0.70)
                radius: 3
                width:  idLabel.implicitWidth + 12
                height: idLabel.implicitHeight + 6

                Text {
                    id:             idLabel
                    anchors.centerIn: parent
                    text:           vehicle
                                        ? ("V" + vehicle.id + "  \u2014  "
                                           + (vehicle.armed ? vehicle.flightMode : qsTr("DISARMED")))
                                        : ""
                    color:          _teal
                    font.bold:      true
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                    font.letterSpacing: 0.5
                }
            }

            // Altitude line — shown when altitude data is available
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                color:   Qt.rgba(0, 0, 0, 0.58)
                radius:  3
                width:   altLabel.implicitWidth + 12
                height:  altLabel.implicitHeight + 5
                visible: vehicle !== null && !isNaN(vehicle.altitudeRelative.value)

                Text {
                    id:             altLabel
                    anchors.centerIn: parent
                    text: {
                        if (!vehicle) return ""
                        var alt  = vehicle.altitudeRelative.value
                        var dist = vehicle.distanceToHome.value
                        if (isNaN(alt)) return ""
                        if (!isNaN(dist) && dist < 5)
                            return qsTr("%1 m  \u00B7  ALT %2 m").arg(dist.toFixed(0)).arg(alt.toFixed(1))
                        return qsTr("%1 m").arg(alt.toFixed(0))
                    }
                    color:          Qt.rgba(1, 1, 1, 0.82)
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.60
                }
            }
        }
    }
}
