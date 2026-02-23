#include "EmergencyController.h"
#include "Vehicle.h"
#include "FirmwarePlugin.h"
#include "QGCLoggingCategory.h"

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

    qCWarning(EmergencyControllerLog) << "EMERGENCY DEPLOYMENT STARTED";

            // 1. Switch to guided
    fw->setGuidedMode(_vehicle, true);

            // 2. Arm + takeoff if not yet airborne
    //    If already armed and flying skip takeoff — just navigate
    if (!_vehicle->armed()) {
        fw->guidedModeTakeoff(_vehicle, 10.0);   // arm, then rise to 10 m
    }

            // 3. Go to emergency coordinate at current/safe altitude
    //    Use the vehicle's current relative altitude (min 10 m for safety)
    double safeAlt = 10.0;
    if (_vehicle->altitudeRelative()) {
        double curAlt = _vehicle->altitudeRelative()->rawValue().toDouble();
        if (curAlt > safeAlt)
            safeAlt = curAlt;
    }
    fw->guidedModeGotoLocation(_vehicle, _emergencyCoord, safeAlt);

    _emergencyActive = true;
    emit emergencyActiveChanged();
}

// UI: "Return Home"
void EmergencyController::returnToHome()
{
    if (!_vehicle)
        return;

    FirmwarePlugin* fw = _vehicle->firmwarePlugin();
    if (!fw)
        return;

    qCWarning(EmergencyControllerLog) << "Emergency return to home";

    fw->guidedModeRTL(_vehicle, false);

    _emergencyActive = false;
    _targetSelected  = false;

    emit emergencyActiveChanged();
    emit targetSelectedChanged();
}

// UI: "Cancel"
void EmergencyController::cancelEmergency()
{
    // If the drone was actively heading to the emergency location, pause it
    if (_emergencyActive && _vehicle) {
        if (_vehicle->pauseVehicleSupported()) {
            _vehicle->pauseVehicle();
        }
    }

    _emergencyActive = false;
    _selectingTarget = false;
    _targetSelected  = false;
    _emergencyCoord  = QGeoCoordinate();

    emit emergencyActiveChanged();
    emit selectingTargetChanged();
    emit targetSelectedChanged();
    emit emergencyCoordinateChanged();
}
