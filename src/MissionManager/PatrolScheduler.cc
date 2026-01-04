#include "PatrolScheduler.h"
#include "Vehicle.h"
#include "MultiVehicleManager.h"

#include <QSettings>
#include <QStandardPaths>
#include <QDateTime>
#include <QDebug>

PatrolScheduler::PatrolScheduler(QObject* parent)
    : QObject(parent)
{
}

void PatrolScheduler::updatePatrol(const QString& droneUID)
{
    bool ok = false;
    const int vehicleId = droneUID.toInt(&ok);
    if (!ok) {
        qWarning() << "PatrolScheduler: invalid droneUID" << droneUID;
        return;
    }

            // Stop & clear old timer (if any)
    auto& runtime = _runtimes[vehicleId];
    if (runtime.timer) {
        runtime.timer->stop();
        runtime.timer->deleteLater();
        runtime.timer = nullptr;
    }

            // Load patrol config from INI
    const QString iniPath =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
        + "/patrol.ini";

    QSettings settings(iniPath, QSettings::IniFormat);
    const QString group = QString("Patrol_%1").arg(vehicleId);

    if (!settings.childGroups().contains(group)) {
        qInfo() << "PatrolScheduler: no patrol config for vehicle"
                << vehicleId;
        return;
    }

    settings.beginGroup(group);

    const bool enabled = settings.value("Enabled", false).toBool();
    const QString startTimeStr = settings.value("StartTime").toString();
    const QDate startDate =
        QDate::fromString(settings.value("StartDate").toString(),
                          Qt::ISODate);

    settings.endGroup();

    if (!enabled) {
        qInfo() << "PatrolScheduler: patrol disabled for vehicle"
                << vehicleId;
        return;
    }

    if (!startDate.isValid()) {
        qWarning() << "PatrolScheduler: invalid StartDate for vehicle"
                   << vehicleId;
        return;
    }

    const QTime startTime = QTime::fromString(startTimeStr, "HH:mm");
    if (!startTime.isValid()) {
        qWarning() << "PatrolScheduler: invalid StartTime for vehicle"
                   << vehicleId << startTimeStr;
        return;
    }

    const QDateTime trigger(startDate, startTime);
    const QDateTime now = QDateTime::currentDateTime();

    if (trigger <= now) {
        qInfo() << "PatrolScheduler: patrol already expired for vehicle"
                << vehicleId << "trigger was" << trigger;
        return;
    }
    qDebug() << "Patrol Configuring for -->" << vehicleId;

    const qint64 msecsToTrigger = now.msecsTo(trigger);

    runtime.timer = new QTimer(this);
    runtime.timer->setSingleShot(true);

    connect(runtime.timer, &QTimer::timeout, this,
            [this, vehicleId]() {

                qDebug() << "Patrol timer hit for -->" << vehicleId;

                MultiVehicleManager* mvm = MultiVehicleManager::instance();
                if (!mvm) {
                    qWarning() << "PatrolScheduler: MVM not available at trigger";
                    return;
                }

                Vehicle* vehicle = mvm->getVehicleById(vehicleId);
                if (!vehicle) {
                    qWarning() << "PatrolScheduler: vehicle missing at trigger"
                               << vehicleId;
                    return;
                }

                        // Load FULL patrol config at trigger time
                QSettings settings(
                    QStandardPaths::writableLocation(
                        QStandardPaths::AppDataLocation)
                        + "/patrol.ini",
                    QSettings::IniFormat);

                const QString group = QString("Patrol_%1").arg(vehicleId);
                settings.beginGroup(group);

                const int loopMode    = settings.value("LoopMode", 0).toInt();
                const int loopCount   = settings.value("LoopCount", 0).toInt();
                const int durationMin= settings.value("DurationMin", 0).toInt();
                const float speedMps =
                    settings.value("SpeedMps", 5.0).toFloat();

                settings.endGroup();

                _sendPatrolCommand(vehicle,
                                   loopMode,
                                   loopCount,
                                   durationMin,
                                   speedMps);
            });

    runtime.timer->start(static_cast<int>(msecsToTrigger));

    qInfo() << "PatrolScheduler: patrol scheduled for vehicle"
            << vehicleId
            << "at" << trigger.toString(Qt::ISODate);
}

void PatrolScheduler::_sendPatrolCommand(
    Vehicle* vehicle,
    int loopMode,
    int loopCount,
    int durationMin,
    float speedMps)
{
    if (!vehicle)
        return;

    qInfo() << "Sending EXECUTE PATROL command to vehicle"
            << vehicle->id()
            << "loopMode=" << loopMode
            << "loopCount=" << loopCount
            << "durationMin=" << durationMin
            << "speedMps=" << speedMps;

    vehicle->sendMavCommand(
        vehicle->defaultComponentId(),
        MAV_CMD_USER_1,   // EXECUTE_PATROL_NOW
        true,
        float(loopMode),      // param1
        float(loopCount),     // param2
        float(durationMin),   // param3
        speedMps,             // param4
        0.0f,
        0.0f,
        0.0f
        );
}

void PatrolScheduler::vehicleRemoved(Vehicle* vehicle)
{
    if (!vehicle)
        return;

    const int vehicleId = vehicle->id();

    if (!_runtimes.contains(vehicleId))
        return;

    qInfo() << "PatrolScheduler: vehicle removed, cleaning patrol for"
            << vehicleId;

    auto& runtime = _runtimes[vehicleId];
    if (runtime.timer) {
        runtime.timer->stop();
        runtime.timer->deleteLater();
        runtime.timer = nullptr;
    }

    _runtimes.remove(vehicleId);
}
