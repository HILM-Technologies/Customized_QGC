#pragma once

#include <QObject>
#include <QGeoCoordinate>

class Vehicle;

/*
 * EmergencyController
 *
 * Owns all emergency-deployment logic.
 * UI must never talk MAVLink directly.
 * This controller only talks to Vehicle/FirmwarePlugin.
 */
class EmergencyController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool emergencyActive READ emergencyActive NOTIFY emergencyActiveChanged)
    Q_PROPERTY(bool selectingTarget READ selectingTarget NOTIFY selectingTargetChanged)
    Q_PROPERTY(bool targetSelected  READ targetSelected  NOTIFY targetSelectedChanged)
    Q_PROPERTY(QGeoCoordinate emergencyCoordinate READ emergencyCoordinate NOTIFY emergencyCoordinateChanged)
    Q_PROPERTY(double emergencyAltitude READ emergencyAltitude WRITE setEmergencyAltitude NOTIFY emergencyAltitudeChanged)


   public:
    explicit EmergencyController(Vehicle* vehicle, QObject* parent = nullptr);
    virtual ~EmergencyController();

    bool emergencyActive() const { return _emergencyActive; }
    bool selectingTarget() const { return _selectingTarget; }
    bool targetSelected()  const { return _targetSelected; }
    QGeoCoordinate emergencyCoordinate() const { return _emergencyCoord; }
    double emergencyAltitude() const { return _emergencyAltitude; }


            // Called from QML
    Q_INVOKABLE void startEmergencySelect();
    Q_INVOKABLE void setEmergencyTarget(const QGeoCoordinate& coord);
    Q_INVOKABLE void deployEmergency();
    Q_INVOKABLE void returnToHome();
    Q_INVOKABLE void landAtLocation();
    Q_INVOKABLE void cancelEmergency();
    Q_INVOKABLE void setEmergencyAltitude(double altitudeRel);


   signals:
    void emergencyActiveChanged();
    void selectingTargetChanged();
    void targetSelectedChanged();
    void emergencyCoordinateChanged();
    void emergencyAltitudeChanged();

   private:
    // Command the vehicle to the requested hover altitude (relative), using the
    // delta from its current altitude. No-op if already within tolerance.
    void _applyHoverAltitude();

    Vehicle*        _vehicle = nullptr;

    bool            _emergencyActive = false;
    bool            _selectingTarget = false;
    bool            _targetSelected  = false;

    double          _emergencyAltitude = 10.0;   // metres, relative to launch

    QGeoCoordinate  _emergencyCoord;
};
