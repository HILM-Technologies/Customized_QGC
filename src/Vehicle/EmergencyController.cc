#include "EmergencyController.h"
#include "Vehicle.h"
#include "FirmwarePlugin.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QtMath>

QGC_LOGGING_CATEGORY(EmergencyControllerLog, "qgc.vehicle.emergency")

EmergencyController::EmergencyController(Vehicle* vehicle, QObject* parent)
    : QObject(parent)
    , _vehicle(vehicle)
{}

EmergencyController::~EmergencyController()
{}

// UI: "Select Emergency Location"
void EmergencyController::startEmergencySelect()
{
    if (!_vehicle)
        return;

    _selectingTarget = true;
    emit selectingTargetChanged();
}

// Map click
void EmergencyController::setEmergencyTarget(const QGeoCoordinate& coord)
{
    _emergencyCoord = coord;
    _selectingTarget = false;
    _targetSelected = true;

    emit selectingTargetChanged();
    emit targetSelectedChanged();
    emit emergencyCoordinateChanged();
}


// UI: "Deploy Emergency"
void EmergencyController::deployEmergency()
{
    if (!_vehicle || !_targetSelected)
        return;

    FirmwarePlugin* fw = _vehicle->firmwarePlugin();
    if (!fw)
        return;

    qCWarning(EmergencyControllerLog) << "EMERGENCY DEPLOYMENT STARTED, hover alt =" << _emergencyAltitude;

    const bool wasFlying = _vehicle->armed();

            // 1. Switch to guided
    fw->setGuidedMode(_vehicle, true);

            // 2. Arm + takeoff to the requested altitude if on the ground
    if (!wasFlying) {
        fw->guidedModeTakeoff(_vehicle, _emergencyAltitude);
    }

            // 3. Go to emergency coordinate (holds the vehicle's CURRENT altitude)
    fw->guidedModeGotoLocation(_vehicle, _emergencyCoord, 0);

            // 4. If already airborne, goto kept the old altitude — nudge to target.
    if (wasFlying) {
        _applyHoverAltitude();
    }

    _emergencyActive = true;
    emit emergencyActiveChanged();
}

// Command the requested hover altitude via a relative-delta change (PX4/APM
// guidedModeChangeAltitude takes a delta, not an absolute altitude).
void EmergencyController::_applyHoverAltitude()
{
    if (!_vehicle)
        return;

    const double currentRel = _vehicle->altitudeRelative()->rawValue().toDouble();
    if (qIsNaN(currentRel))
        return;

    const double delta = _emergencyAltitude - currentRel;
    if (qFabs(delta) < 0.5)      // already within tolerance
        return;

    _vehicle->firmwarePlugin()->guidedModeChangeAltitude(_vehicle, delta, false);
}

// UI: hover-altitude stepper. Persists the target and, if already hovering,
// adjusts the vehicle live.
void EmergencyController::setEmergencyAltitude(double altitudeRel)
{
    altitudeRel = qBound(2.0, altitudeRel, 500.0);
    if (qFuzzyCompare(altitudeRel, _emergencyAltitude))
        return;

    _emergencyAltitude = altitudeRel;
    emit emergencyAltitudeChanged();

    if (_emergencyActive) {
        _applyHoverAltitude();
    }
}

// UI: "Land Here" — land at the current (target) position.
void EmergencyController::landAtLocation()
{
    if (!_vehicle)
        return;

    qCWarning(EmergencyControllerLog) << "Emergency land at current location";

    _vehicle->firmwarePlugin()->guidedModeLand(_vehicle);

    _emergencyActive = false;
    _targetSelected  = false;

    emit emergencyActiveChanged();
    emit targetSelectedChanged();
}

// UI: "Return Home"
void EmergencyController::returnToHome()
{
    if (!_vehicle)
        return;

    qCWarning(EmergencyControllerLog) << "Emergency return to home";

    _vehicle->firmwarePlugin()->guidedModeRTL(_vehicle, false);

    _emergencyActive = false;
    _targetSelected  = false;

    emit emergencyActiveChanged();
    emit targetSelectedChanged();
}

// UI: "Cancel"
void EmergencyController::cancelEmergency()
{
    // Stop any emergency activity
    _emergencyActive = false;
    _selectingTarget = false;
    _targetSelected  = false;
    _emergencyCoord  = QGeoCoordinate();

    emit emergencyActiveChanged();
    emit selectingTargetChanged();
    emit targetSelectedChanged();
    emit emergencyCoordinateChanged();
}
