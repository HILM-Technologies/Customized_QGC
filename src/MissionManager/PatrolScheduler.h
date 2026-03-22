#pragma once

#include <QObject>
#include <QTimer>
#include <QMap>
#include <QString>

class Vehicle;

class PatrolScheduler : public QObject
{
    Q_OBJECT
   public:
    explicit PatrolScheduler(QObject* parent = nullptr);

   signals:
    void patrolTriggered(int vehicleId);          ///< Patrol timer fired, command sent
    void patrolScheduled(int vehicleId, const QString& dateTime);  ///< Timer armed
    void patrolFailed(int vehicleId, const QString& reason);       ///< Vehicle not found etc.

   public slots:
    void updatePatrol(const QString& droneUID);
    void vehicleRemoved(Vehicle* vehicle);

    /// On app startup: scan patrol.ini for all drones with valid future schedules
    /// and re-arm timers for each.
    void checkAllPendingSchedules();

   private:
    struct Runtime {
        QTimer* timer = nullptr;
    };

    QMap<int, Runtime> _runtimes; // key = vehicleId

    void _sendPatrolCommand(Vehicle* vehicle, float speedMps, int loopMode, int loopCount, int durationMin);
};
