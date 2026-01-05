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
    Q_PROPERTY(QString        droneUID        READ droneUID        WRITE setDroneUID        NOTIFY droneUIDChanged)
    Q_PROPERTY(bool           enabled         READ enabled         WRITE setEnabled         NOTIFY enabledChanged)
    Q_PROPERTY(float          speed           READ speed           WRITE setSpeed           NOTIFY speedChanged)
    Q_PROPERTY(int            loops           READ loops           WRITE setLoops           NOTIFY loopsChanged)
    Q_PROPERTY(PatrolLoopMode loopsMode       READ loopsMode       WRITE setLoopsMode       NOTIFY loopsModeChanged)
    Q_PROPERTY(int            duration        READ duration        WRITE setDuration        NOTIFY durationChanged)
    Q_PROPERTY(QString        startTime       READ startTime       WRITE setStartTime       NOTIFY startTimeChanged)
    Q_PROPERTY(QDate          startDate       READ startDate       WRITE setStartDate       NOTIFY startDateChanged)
    Q_PROPERTY(QStringList    availableDrones READ availableDrones                          NOTIFY availableDronesChanged)

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
        int             loopCount      = -1; // loopCount used only when loopMode == NTimes, otherwise -1
        int             duration_min   = -1; // duration_min used only when loopMode == Duration, otherwise -1
        QString         startTime;     // HH:MM
        QDate           startDate;     // YYYY-MM-DD
        QString         droneUID;
    };

    Q_ENUM(PatrolLoopMode)

    explicit PatrolController(PlanMasterController* master,
                              QObject* parent = nullptr);

    Q_INVOKABLE void saveToINI();
    Q_INVOKABLE void reset();


            // ---------------------------
            // Accessors
            // ---------------------------
    bool            enabled         () const { return _config.enabled;      }
    float           speed           () const { return _config.speed_mps;    }
    int             loops           () const { return _config.loopCount;    }
    PatrolLoopMode  loopsMode       () const { return _config.loopMode;     }
    int             duration        () const { return _config.duration_min; }
    QString         startTime       () const { return _config.startTime;    }
    QDate           startDate       () const { return _config.startDate;    }
    QString         droneUID        () const { return _config.droneUID;     }
    QStringList     availableDrones () const { return _availableDrones; }

            // ---------------------------
            // Mutators
            // ---------------------------
    void setEnabled         (bool v);
    void setSpeed           (float v);
    void setLoops           (int v);
    void setLoopsMode       (PatrolLoopMode m);
    void setDuration        (int d);
    void setStartTime       (const QString& t);
    void setStartDate       (const QDate& d);
    void setDroneUID        (const QString& uid);
    void setAvailableDrones (const QStringList& drones);


            // ---------------------------
            // PlanElementController
            // ---------------------------
    bool isEmpty                () const;
    void start                  (bool flyView) override;
    void save                   (QJsonObject& json) override;
    bool load                   (const QJsonObject& json, QString& errorString) override;
    void loadFromINI                ();
    void loadFromVehicle            () override;
    void sendToVehicle              () override;
    void removeAll                  () override;
    void removeAllFromVehicle       () override;
    bool containsItems              () const override;
    void setDirty                   (bool d) override;
    bool supported                  () const override { return true;  }
    bool syncInProgress             () const override { return false; }
    bool dirty                      () const override { return _dirty; }
    bool showPlanFromManagerVehicle () override { return true; }

   signals:
    void enabledChanged         (bool);
    void speedChanged           (float);
    void loopsChanged           (int);
    void loopsModeChanged       (PatrolLoopMode);
    void durationChanged        (int);
    void startTimeChanged       (QString);
    void dirtyChanged           (bool);
    void droneUIDChanged        (QString);
    void startDateChanged       (QDate);
    void patrolConfigChanged    (const QString& droneUID);


    void availableDronesChanged ();

   private:
    PatrolConfig    _config;
    QStringList     _availableDrones;
    bool            _dirty = false;
};
