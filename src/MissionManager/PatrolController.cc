#include "PatrolController.h"
#include "PlanMasterController.h"
#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>

PatrolController::PatrolController(PlanMasterController* master, QObject* parent)
    : PlanElementController(master, parent)
{
}

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

void PatrolController::start(bool flyView)
{
    _flyView = flyView;
    loadFromINI();
}

void PatrolController::save(QJsonObject& json)
{
    json["enabled"]    = _config.enabled;
    json["speed"]      = _config.speed_mps;
    json["loopMode"]   = static_cast<int>(_config.loopMode);
    json["loops"]      = _config.loopCount;
    json["duration"]   = _config.duration_min;
    json["startTime"]  = _config.startTime;
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

    emit enabledChanged(_config.enabled);
    emit speedChanged(_config.speed_mps);
    emit loopsModeChanged(_config.loopMode);
    emit loopsChanged(_config.loopCount);
    emit durationChanged(_config.duration_min);
    emit startTimeChanged(_config.startTime);

    setDirty(false);
    return true;
}

void PatrolController::loadFromVehicle()
{
    setDirty(false);
}

void PatrolController::saveToINI()
{
    // Resolve app data directory
    const QString appDataPath =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);

    QDir().mkpath(appDataPath);

    const QString iniPath = appDataPath + "/patrol.ini";

    QSettings settings(iniPath, QSettings::IniFormat);

    settings.beginGroup("Patrol");
    settings.setValue("Enabled",     _config.enabled);
    settings.setValue("LoopMode",    static_cast<int>(_config.loopMode));
    settings.setValue("SpeedMps",    _config.speed_mps);
    settings.setValue("LoopCount",   _config.loopCount);
    settings.setValue("DurationMin", _config.duration_min);
    settings.setValue("StartTime",   _config.startTime);
    settings.endGroup();

    settings.sync();

    // qCDebug(QGCLoggingCategory("PatrolController"))
    //     << "Patrol config saved to INI:" << iniPath;
}

void PatrolController::loadFromINI()
{
    const QString iniPath =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
        + "/patrol.ini";

    QSettings settings(iniPath, QSettings::IniFormat);

    settings.beginGroup("Patrol");

    setEnabled(settings.value("Enabled", false).toBool());
    setLoopsMode(static_cast<PatrolLoopMode>(
        settings.value("LoopMode", 0).toInt()));
    setSpeed(settings.value("SpeedMps", 5.0f).toFloat());
    setLoops(settings.value("LoopCount", 3).toInt());
    setDuration(settings.value("DurationMin", 20).toInt());
    setStartTime(settings.value("StartTime", "22:00").toString());

    settings.endGroup();

    setDirty(false);

    // qCDebug(QGCLoggingCategory("PatrolController"))
    //     << "Patrol config loaded from INI";
}

void PatrolController::sendToVehicle()
{
    qDebug() << "Sending Patrol Config:"
             << "enabled=" << _config.enabled
             << "speed=" << _config.speed_mps
             << "loopMode=" << int(_config.loopMode)
             << "loops=" << _config.loopCount
             << "duration=" << _config.duration_min
             << "startTime=" << _config.startTime;

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
    }
}
