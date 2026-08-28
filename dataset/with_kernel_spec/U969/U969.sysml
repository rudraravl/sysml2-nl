package WarehouseFulfillmentSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def Product {
        attribute sku : String;
        attribute name : String;
        attribute quantity : Integer;
    }

    enum def OrderStatus {
        RECEIVED;
        PROCESSING;
        FULFILLED;
    }

    item def Order {
        attribute orderId : String;
        item orderItems : Product[0..*];
        attribute status : OrderStatus;
    }

    item def TaskAssignment {
        attribute taskId : String;
        attribute targetPodId : String;
        attribute destinationStationId : String;
        attribute returnLocationId : String;
        attribute priority : Integer;
    }

    item def RobotStatus {
        attribute robotId : String;
        attribute positionX : Real;
        attribute positionY : Real;
        attribute batteryLevel : Real;
        attribute currentState : String;
    }

    item def SensorData {
        attribute obstacleDetected : Boolean;
        attribute qrCodeId : String;
        attribute distanceToObstacle : Real;
    }

    item def LiftCommand {
        attribute lift : Boolean;
        attribute lower : Boolean;
    }

    item def PickConfirmation {
        attribute orderId : String;
        attribute itemsPicked : Integer;
    }

    attribute def SigTaskAssigned;
    attribute def SigPodReached;
    attribute def SigPodLifted;
    attribute def SigWorkstationReached;
    attribute def SigPickingComplete;
    attribute def SigPodReturned;
    attribute def SigBatteryLow;
    attribute def SigChargerReached;
    attribute def SigChargeComplete;
    attribute def SigOrderReceived;

    part def DriveSystem {
        attribute wheelDiameter : LengthValue = 0.15 [m];
        attribute maxSpeed : SpeedValue = 1.5 [m/s];
        attribute currentSpeed : SpeedValue;
        attribute isMoving : Boolean;
    }

    part def BatteryPack {
        attribute capacity : EnergyValue = 360000 [J];
        attribute currentCharge : Real;
        attribute lowThreshold : Real = 20.0;
        port batteryPort {
            out batteryLevel : Real;
            in chargePower : Real;
        }
        perform action monitorCharge {
            out level : Real;
            first start;
            then action readCharge;
            then action checkThreshold;
            then done;
        }
    }

    part def LiftingMechanism {
        attribute maxLiftHeight : LengthValue = 0.1 [m];
        attribute liftCapacity : MassValue = 750 [kg];
        attribute isEngaged : Boolean;
        attribute isLifted : Boolean;
        port podCommandPort {
            out liftCommand : LiftCommand;
        }
        perform action liftPod {
            in podWeight : MassValue;
            first start;
            then action engageMechanism;
            then action raisePod;
            then done;
        }
        perform action lowerPod {
            first start;
            then action lowerMechanism;
            then action disengageMechanism;
            then done;
        }
    }

    part def LiDAR {
        attribute range : LengthValue = 10 [m];
        attribute scanRate : FrequencyValue = 10 [Hz];
        port perceptionOut {
            out sensorData : SensorData;
        }
    }

    part def VisionCamera {
        attribute resolution : String;
        attribute fieldOfView : Real = 120.0;
        port perceptionOut {
            out sensorData : SensorData;
        }
    }

    part def QRScanner {
        attribute scanRate : FrequencyValue = 5 [Hz];
        port perceptionOut {
            out sensorData : SensorData;
        }
    }

    part def PerceptionSystem {
        part lidar : LiDAR;
        part visionCamera : VisionCamera;
        part qrScanner : QRScanner;
        attribute obstacleDetected : Boolean;
        attribute currentPath : String;
        port perceptionOut {
            out sensorData : SensorData;
        }
        perform action perceiveEnvironment {
            out obstacle : Boolean;
            out path : String;
            first start;
            then action scanLiDAR;
            then action scanCamera;
            then action scanQR;
            then action fuseData;
            then done;
        }
    }

    enum def RobotState {
        IDLE;
        NAVIGATING_TO_POD;
        LIFTING_POD;
        TRANSPORTING_POD;
        AT_WORKSTATION;
        RETURNING_POD;
        NAVIGATING_TO_CHARGER;
        CHARGING;
    }

    part def MobileDriveUnit {
        attribute robotId : String;
        attribute maxPayload : MassValue = 750 [kg];
        attribute currentSpeed : SpeedValue;
        attribute status : RobotState;

        port taskPort {
            in task : TaskAssignment;
            out taskComplete : TaskAssignment;
        }
        port statusPort {
            out status : RobotStatus;
        }
        port batteryPort {
            out batteryLevel : Real;
            in chargePower : Real;
        }
        port perceptionPort {
            out sensorData : SensorData;
        }

        part driveSystem : DriveSystem;
        part batteryPack : BatteryPack;
        part liftingMechanism : LiftingMechanism;
        part perceptionSystem : PerceptionSystem;

        bind batteryPort = batteryPack.batteryPort;
        bind perceptionPort = perceptionSystem.perceptionOut;

        state robotStateMachine {
            entry; then idle;
            state idle;
            accept SigTaskAssigned then navigatingToPod;
            state navigatingToPod;
            accept SigPodReached then liftingPod;
            state liftingPod;
            accept SigPodLifted then transportingPod;
            state transportingPod;
            accept SigWorkstationReached then atWorkstation;
            state atWorkstation;
            accept SigPickingComplete then returningPod;
            state returningPod;
            accept SigPodReturned then idle;
            transition idle_lowBattery
                first idle
                accept SigBatteryLow
                then navigatingToCharger;
            transition navigatingToPod_lowBattery
                first navigatingToPod
                accept SigBatteryLow
                then navigatingToCharger;
            transition transportingPod_lowBattery
                first transportingPod
                accept SigBatteryLow
                then navigatingToCharger;
            transition returningPod_lowBattery
                first returningPod
                accept SigBatteryLow
                then navigatingToCharger;
            state navigatingToCharger;
            accept SigChargerReached then charging;
            state charging;
            accept SigChargeComplete then idle;
        }
    }

    part def InventoryPod {
        attribute podId : String;
        attribute weight : MassValue;
        attribute maxWeight : MassValue = 750 [kg];
        attribute locationId : String;
        item products : Product[0..*];
        attribute isLifted : Boolean;
        port podCommandPort {
            in liftCommand : LiftCommand;
        }
    }

    part def HumanOperator {
        attribute operatorId : String;
        attribute name : String;
    }

    part def Workstation {
        attribute stationId : String;
        attribute operatorPresent : Boolean;
        port pickPort {
            in podArrival : InventoryPod;
            out pickConfirmation : PickConfirmation;
        }
        part operator : HumanOperator;
        perform action pickItems {
            in pod : InventoryPod;
            in order : Order;
            out pickedItems : Product[0..*];
            first start;
            then action receivePod;
            then action scanOrder;
            then action pickProducts;
            then action confirmPicking;
            then done;
        }
    }

    part def ChargingDock {
        attribute dockId : String;
        attribute isOccupied : Boolean;
        attribute chargingPower : PowerValue = 500 [W];
        port batteryPort {
            in batteryLevel : Real;
            out chargePower : Real;
        }
        perform action chargeRobot {
            in robotId : String;
            first start;
            then action connectRobot;
            then action chargeBattery;
            then action disconnectRobot;
            then done;
        }
    }

    part def FleetManager {
        attribute totalRobots : Integer;
        attribute activeRobots : Integer;
        attribute availableRobots : Integer;
        port statusInPort {
            in status : RobotStatus;
        }
        port taskOutPort {
            out task : TaskAssignment;
            in taskComplete : TaskAssignment;
        }
        perform action assignTask {
            in task : TaskAssignment;
            out robotId : String;
            first start;
            then action findAvailableRobot;
            then action dispatchTask;
            then done;
        }
    }

    part def PathOptimizer {
        attribute collisionAvoidanceEnabled : Boolean = true;
        attribute activePaths : Integer;
        perform action optimizePath {
            in startLocation : String;
            in endLocation : String;
            out optimizedPath : String;
            first start;
            then action calculateRoute;
            then action checkCollisions;
            then action adjustRoute;
            then done;
        }
    }

    part def InventoryTracker {
        attribute podLocations : String[0..*];
        attribute productToPodMap : String[0..*];
        perform action locatePod {
            in productSku : String;
            out podId : String;
            first start;
            then action lookupProduct;
            then action findPod;
            then done;
        }
    }

    part def OrderManager {
        item pendingOrders : Order[0..*];
        item completedOrders : Order[0..*];
        port orderPort {
            in order : Order;
            out orderStatus : OrderStatus;
        }
        perform action processOrder {
            in order : Order;
            out task : TaskAssignment;
            first start;
            then action receiveOrder;
            then action validateOrder;
            then action locatePods;
            then action createTask;
            then done;
        }
    }

    part def WarehouseControlSystem {
        attribute systemId : String;
        item taskQueue : TaskAssignment[0..*];
        attribute throughput : Integer;
        attribute maxThroughput : Integer = 500;

        port orderPort {
            in order : Order;
            out orderStatus : OrderStatus;
        }
        port taskDispatchPort {
            out task : TaskAssignment;
            in taskComplete : TaskAssignment;
        }
        port statusMonitorPort {
            in status : RobotStatus;
        }

        part fleetManager : FleetManager;
        part pathOptimizer : PathOptimizer;
        part inventoryTracker : InventoryTracker;
        part orderManager : OrderManager;

        bind orderPort = orderManager.orderPort;
        bind taskDispatchPort = fleetManager.taskOutPort;
        bind statusMonitorPort = fleetManager.statusInPort;

        state controlState {
            entry; then idle;
            state idle;
            accept SigOrderReceived then processingOrder;
            state processingOrder;
            accept SigPickingComplete then idle;
        }
    }

    part def WarehouseSystem {
        part controlSystem : WarehouseControlSystem;
        part robots : MobileDriveUnit[1..*];
        part pods : InventoryPod[1..*];
        part workstations : Workstation[1..*];
        part chargingDocks : ChargingDock[1..*];

        interface taskDispatchInterface connect controlSystem.taskDispatchPort to robots.taskPort {
            flow taskFlow of TaskAssignment
                from controlSystem.taskDispatchPort.task to robots.taskPort.task;
            flow taskCompleteFlow of TaskAssignment
                from robots.taskPort.taskComplete to controlSystem.taskDispatchPort.taskComplete;
        }

        interface statusMonitoringInterface connect robots.statusPort to controlSystem.statusMonitorPort {
            flow statusFlow of RobotStatus
                from robots.statusPort.status to controlSystem.statusMonitorPort.status;
        }

        interface batteryMonitoringInterface connect robots.batteryPort to chargingDocks.batteryPort {
            flow batteryLevelFlow of Real
                from robots.batteryPort.batteryLevel to chargingDocks.batteryPort.batteryLevel;
            flow chargePowerFlow of Real
                from chargingDocks.batteryPort.chargePower to robots.batteryPort.chargePower;
        }

        interface podLiftInterface connect robots.liftingMechanism.podCommandPort to pods.podCommandPort {
            flow liftCommandFlow of LiftCommand
                from robots.liftingMechanism.podCommandPort.liftCommand to pods.podCommandPort.liftCommand;
        }

        perform action fulfillOrder {
            in order : Order;
            first start;
            then action receiveOrder;
            then action locatePod;
            then action dispatchRobot;
            then action navigateToPod;
            then action liftPod;
            then action transportToWorkstation;
            then action pickItems;
            then action returnPodToStorage;
            then action releaseRobot;
            then done;
        }
    }

    requirement def PayloadRequirement {
        doc /* The mobile drive unit shall be capable of lifting and transporting inventory pods weighing up to 750 kg. */
        subject robot : MobileDriveUnit;
        attribute maxPayload : MassValue;
        require constraint { maxPayload >= 750 [kg] }
    }

    requirement def ThroughputRequirement {
        doc /* The warehouse fulfillment system shall process hundreds of orders per hour to support high-throughput environments. */
        subject system : WarehouseSystem;
        attribute ordersPerHour : Integer;
        require constraint { ordersPerHour >= 100 }
    }

    requirement def BatteryAutonomyRequirement {
        doc /* The mobile drive unit shall autonomously navigate to a charging dock when battery level falls below 20 percent. */
        subject robot : MobileDriveUnit;
        attribute lowBatteryThreshold : Real;
        require constraint { lowBatteryThreshold <= 20.0 }
    }

    requirement def CollisionAvoidanceRequirement {
        doc /* The warehouse control system shall optimize robot paths to prevent collisions between mobile drive units. */
        subject controlSystem : WarehouseControlSystem;
        attribute collisionAvoidanceEnabled : Boolean;
        require constraint { collisionAvoidanceEnabled == true }
    }

    requirement def PodWeightRequirement {
        doc /* Each inventory pod shall support a maximum weight of 750 kg. */
        subject pod : InventoryPod;
        attribute maxWeight : MassValue;
        require constraint { maxWeight >= 750 [kg] }
    }

    requirement <REQ01> payloadReq : PayloadRequirement {
        subject robot : MobileDriveUnit;
        attribute :>> maxPayload = robot.maxPayload;
    }

    requirement <REQ02> throughputReq : ThroughputRequirement {
        subject system : WarehouseSystem;
        attribute :>> ordersPerHour = system.controlSystem.throughput;
    }

    requirement <REQ03> batteryReq : BatteryAutonomyRequirement {
        subject robot : MobileDriveUnit;
        attribute :>> lowBatteryThreshold = 20.0;
    }

    requirement <REQ04> collisionReq : CollisionAvoidanceRequirement {
        subject controlSystem : WarehouseControlSystem;
        attribute :>> collisionAvoidanceEnabled = controlSystem.pathOptimizer.collisionAvoidanceEnabled;
    }

    requirement <REQ05> podWeightReq : PodWeightRequirement {
        subject pod : InventoryPod;
        attribute :>> maxWeight = pod.maxWeight;
    }
}
