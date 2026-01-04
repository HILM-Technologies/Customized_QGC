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

   public slots:
    void updatePatrol(const QString& droneUID);
    void vehicleRemoved(Vehicle* vehicle);

   private:
    struct Runtime {
        QTimer* timer = nullptr;
    };

    QMap<int, Runtime> _runtimes; // key = vehicleId

    void _sendPatrolCommand(Vehicle* vehicle, int loopMode, int loopCount, int durationMin, float speedMps);
};
