#include "PatrolController.h"
#include "PlanMasterController.h"
#include "Vehicle.h"

#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QDateTime>
#include <QTime>

// File-local helper (not part of class API)
static QDateTime computeTriggerDateTime(const QDate& date,
                                        const QString& startTime)
{
    QTime time = QTime::fromString(startTime, "HH:mm");
    if (!time.isValid() || !date.isValid()) {
        return QDateTime();
    }

    return QDateTime(date, time);
}

PatrolController::PatrolController(PlanMasterController* master, QObject* parent)
    : PlanElementController(master, parent)
{
}

// ---------------------------
// NEW: injected drone list
// ---------------------------
void PatrolController::setAvailableDrones(const QStringList& drones)
{
    const QStringList normalizedDrones = drones;

    if (_availableDrones == normalizedDrones) {
        return;
    }

    _availableDrones = normalizedDrones;

            // If no drones → clear selection + cancel timer
    if (_availableDrones.isEmpty()) {
        if (!_config.droneUID.isEmpty()) {
            _config.droneUID.clear();
            emit droneUIDChanged(_config.droneUID);
        }
        _configurePatrolTimer();
        emit availableDronesChanged();
        return;
    }

            // If selected drone disappeared → reset
    if (!_config.droneUID.isEmpty() &&
        !_availableDrones.contains(_config.droneUID)) {

        _config.droneUID.clear();
        emit droneUIDChanged(_config.droneUID);
        _configurePatrolTimer();   // cancel timer
    }

    emit availableDronesChanged();
}

// ---------------------------
// State helpers
// ---------------------------
void PatrolController::setDirty(bool d)
{
    if (_dirty != d) {
        _dirty = d;
        emit dirtyChanged(d);
    }
}

bool PatrolController::isEmpty() const
{
    return !_config.enabled;
}

bool PatrolController::containsItems() const
{
    return _config.enabled;
}

// ---------------------------
// Lifecycle
// ---------------------------
void PatrolController::start(bool flyView)
{
    _flyView = flyView;
    loadFromINI();
}

// ---------------------------
// Drone UID
// ---------------------------
void PatrolController::setDroneUID(const QString& uid)
{
    if (_config.droneUID == uid)
        return;

    _config.droneUID = uid;
    setDirty(true);
    emit droneUIDChanged(uid);

    loadFromINI();          // load config for this drone
    _configurePatrolTimer(); // nsure correct scheduling
}

// ---------------------------
// JSON save/load (unchanged)
// ---------------------------
void PatrolController::save(QJsonObject& json)
{
    json["enabled"]    = _config.enabled;
    json["speed"]      = _config.speed_mps;
    json["loopMode"]   = static_cast<int>(_config.loopMode);
    json["loops"]      = _config.loopCount;
    json["duration"]   = _config.duration_min;
    json["startTime"]  = _config.startTime;
    json["startDate"]  = _config.startDate.toString(Qt::ISODate);
    json["droneUID"]   = _config.droneUID;

    setDirty(false);
}

bool PatrolController::load(const QJsonObject& json, QString&)
{
    _config.enabled      = json["enabled"].toBool();
    _config.speed_mps    = float(json["speed"].toDouble(5.0));
    _config.loopMode     = PatrolLoopMode(json["loopMode"].toInt(0));
    _config.loopCount    = json["loops"].toInt(3);
    _config.duration_min = json["duration"].toInt(20);
    _config.startTime    = json["startTime"].toString("22:00");

    _config.startDate =
        QDate::fromString(
            json["startDate"].toString(),
            Qt::ISODate);

    _config.droneUID     = json["droneUID"].toString();

    emit enabledChanged(_config.enabled);
    emit speedChanged(_config.speed_mps);
    emit loopsModeChanged(_config.loopMode);
    emit loopsChanged(_config.loopCount);
    emit durationChanged(_config.duration_min);
    emit startTimeChanged(_config.startTime);
    emit startDateChanged(_config.startDate);
    emit droneUIDChanged(_config.droneUID);

    _configurePatrolTimer();
    setDirty(false);
    return true;
}


void PatrolController::loadFromVehicle()
{
    setDirty(false);
}

// ---------------------------
// INI persistence (unchanged + DroneUID)
// ---------------------------
void PatrolController::saveToINI()
{
    if (_config.droneUID.isEmpty()) {
        return;
    }

    const QString iniPath =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
        + "/patrol.ini";

    QSettings settings(iniPath, QSettings::IniFormat);
    const QString groupName = QString("Patrol_%1").arg(_config.droneUID);

    settings.beginGroup(groupName);

    settings.setValue("Enabled",     _config.enabled);
    settings.setValue("LoopMode",    static_cast<int>(_config.loopMode));
    settings.setValue("SpeedMps",    _config.speed_mps);
    settings.setValue("LoopCount",   _config.loopCount);
    settings.setValue("DurationMin", _config.duration_min);

    settings.setValue("StartTime",   _config.startTime);             // HH:mm
    settings.setValue("StartDate",   _config.startDate.toString(Qt::ISODate)); // YYYY-MM-DD

    settings.setValue("LastUpdated",
                      QDateTime::currentDateTimeUtc().toString(Qt::ISODate));

    settings.endGroup();
    settings.sync();

    _configurePatrolTimer();
}

void PatrolController::loadFromINI()
{
    if (_config.droneUID.isEmpty()) {
        return;
    }

    const QString iniPath =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
        + "/patrol.ini";

    QSettings settings(iniPath, QSettings::IniFormat);
    const QString groupName = QString("Patrol_%1").arg(_config.droneUID);

    if (!settings.childGroups().contains(groupName)) {
        return;
    }

    settings.beginGroup(groupName);

    setEnabled(settings.value("Enabled", false).toBool());
    setLoopsMode(static_cast<PatrolLoopMode>(
        settings.value("LoopMode", 0).toInt()));
    setSpeed(settings.value("SpeedMps", 5.0f).toFloat());
    setLoops(settings.value("LoopCount", 3).toInt());
    setDuration(settings.value("DurationMin", 20).toInt());

    _config.startTime =
        settings.value("StartTime", "").toString();

    _config.startDate =
        QDate::fromString(
            settings.value("StartDate", "").toString(),
            Qt::ISODate);

    settings.endGroup();

    _configurePatrolTimer();
}

void PatrolController::_configurePatrolTimer()
{
    if (_patrolTimer) {
        _patrolTimer->stop();
        _patrolTimer->deleteLater();
        _patrolTimer = nullptr;
    }

    if (!_config.enabled ||
        _config.startTime.isEmpty() ||
        !_config.startDate.isValid()) {
        return;
    }

    QDateTime triggerTime =
        computeTriggerDateTime(_config.startDate, _config.startTime);

    if (!triggerTime.isValid()) {
        qWarning() << "Invalid patrol date/time for drone:"
                   << _config.droneUID;
        return;
    }

    QDateTime now = QDateTime::currentDateTime();

            // 🔒 EXPIRED → DO NOT SCHEDULE
    if (triggerTime <= now) {
        qInfo() << "Patrol already expired for drone:"
                << _config.droneUID
                << "trigger was:" << triggerTime;
        return;
    }

    qint64 msecsToTrigger = now.msecsTo(triggerTime);

    _patrolTimer = new QTimer(this);
    _patrolTimer->setSingleShot(true);

    connect(_patrolTimer, &QTimer::timeout, this, [this, triggerTime]() {
        qInfo() << "Patrol timer triggered for drone:"
                << _config.droneUID
                << "at" << triggerTime.toString(Qt::ISODate);

                // emit patrolTriggered(_config.droneUID);

        if (_patrolTimer) {
            _patrolTimer->deleteLater();
            _patrolTimer = nullptr;
        }
    });

    _patrolTimer->start(static_cast<int>(msecsToTrigger));

    qInfo() << "Patrol scheduled for drone:"
            << _config.droneUID
            << "at" << triggerTime.toString(Qt::ISODate);
}

// ---------------------------
// Vehicle interaction (unchanged)
// ---------------------------
void PatrolController::sendToVehicle()
{
    qDebug() << "Sending Patrol Config:"
             << "enabled=" << _config.enabled
             << "speed=" << _config.speed_mps
             << "loopMode=" << int(_config.loopMode)
             << "loops=" << _config.loopCount
             << "duration=" << _config.duration_min
             << "startTime=" << _config.startTime
             << "droneUID=" << _config.droneUID;

    emit sendComplete();
}

void PatrolController::removeAll()
{
    _config = PatrolConfig{};

    emit enabledChanged(false);
    emit speedChanged(_config.speed_mps);
    emit loopsModeChanged(_config.loopMode);
    emit loopsChanged(_config.loopCount);
    emit durationChanged(_config.duration_min);
    emit startTimeChanged(_config.startTime);
    emit startDateChanged(_config.startDate);
    emit droneUIDChanged(_config.droneUID);

    _configurePatrolTimer(); // cancel timer
    setDirty(true);
}


void PatrolController::removeAllFromVehicle()
{
    emit removeAllComplete();
}

// ---------------------------
// Property setters
// ---------------------------
void PatrolController::setEnabled(bool v)
{
    if (_config.enabled != v) {
        _config.enabled = v;
        emit enabledChanged(v);
        setDirty(true);
        _configurePatrolTimer();
    }
}


void PatrolController::setSpeed(float v)
{
    if (!qFuzzyCompare(_config.speed_mps, v)) {
        _config.speed_mps = v;
        emit speedChanged(v);
        setDirty(true);
    }
}

void PatrolController::setLoops(int v)
{
    if (_config.loopCount != v) {
        _config.loopCount = v;
        emit loopsChanged(v);
        setDirty(true);
    }
}

void PatrolController::setLoopsMode(PatrolLoopMode m)
{
    if (_config.loopMode != m) {
        _config.loopMode = m;
        emit loopsModeChanged(m);
        setDirty(true);
    }
}

void PatrolController::setDuration(int d)
{
    if (_config.duration_min != d) {
        _config.duration_min = d;
        emit durationChanged(d);
        setDirty(true);
    }
}

void PatrolController::setStartTime(const QString& t)
{
    if (_config.startTime != t) {
        _config.startTime = t;
        emit startTimeChanged(t);
        setDirty(true);
        _configurePatrolTimer();
    }
}

void PatrolController::setStartDate(const QDate& d)
{
    if (_config.startDate != d) {
        _config.startDate = d;
        emit startDateChanged(d);
        setDirty(true);
        _configurePatrolTimer();
    }
}


