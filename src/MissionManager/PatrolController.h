#pragma once

#include <QObject>
#include <QJsonObject>
#include <QtQmlIntegration/QtQmlIntegration>

#include "PlanElementController.h"

class PlanMasterController;

class PatrolController : public PlanElementController
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")

            // ---------------------------
            // QML Properties
            // ---------------------------
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(float speed READ speed WRITE setSpeed NOTIFY speedChanged)
    Q_PROPERTY(int loops READ loops WRITE setLoops NOTIFY loopsChanged)
    Q_PROPERTY(PatrolLoopMode loopsMode READ loopsMode WRITE setLoopsMode NOTIFY loopsModeChanged)
    Q_PROPERTY(int duration READ duration WRITE setDuration NOTIFY durationChanged)
    Q_PROPERTY(QString startTime READ startTime WRITE setStartTime NOTIFY startTimeChanged)

   public:

    enum PatrolLoopMode : uint8_t {
        Forever  = 0,
        NTimes   = 1,
        Duration = 2
    };

    struct PatrolConfig {
        bool            enabled       = false;
        PatrolLoopMode  loopMode       = Forever;
        float           speed_mps      = 5.0f;
        int             loopCount      = 3;
        int             duration_min   = 20;
        QString         startTime      = "22:00";
    };

    Q_ENUM(PatrolLoopMode)
    PatrolController(PlanMasterController* master, QObject* parent = nullptr);

    Q_INVOKABLE void saveToINI();
          // ---------------------------
          // Accessors
          // ---------------------------
    bool enabled() const { return _config.enabled; }
    float speed() const { return _config.speed_mps; }
    int loops() const { return _config.loopCount; }
    PatrolLoopMode loopsMode() const { return _config.loopMode; }
    int duration() const { return _config.duration_min; }
    QString startTime() const { return _config.startTime; }

            // ---------------------------
            // Mutators
            // ---------------------------
    void setEnabled(bool v);
    void setSpeed(float v);
    void setLoops(int v);
    void setLoopsMode(PatrolLoopMode m);
    void setDuration(int d);
    void setStartTime(const QString& t);

            // ---------------------------
            // PlanElementController
            // ---------------------------
    bool isEmpty() const ;
    void start(bool flyView) override;
    void save(QJsonObject& json) override;
    bool load(const QJsonObject& json, QString& errorString) override;
    void loadFromINI();
    void loadFromVehicle() override;
    void sendToVehicle() override;
    void removeAll() override;
    void removeAllFromVehicle() override;

    bool supported() const override { return true; }
    bool containsItems() const override;
    bool syncInProgress() const override { return false; }

    bool dirty() const override { return _dirty; }
    void setDirty(bool d) override;

    bool showPlanFromManagerVehicle() override { return true; }

   signals:
    void enabledChanged(bool);
    void speedChanged(float);
    void loopsChanged(int);
    void loopsModeChanged(PatrolLoopMode);
    void durationChanged(int);
    void startTimeChanged(QString);
    void dirtyChanged(bool);

   private:
    PatrolConfig _config;
    bool _dirty = false;
};
