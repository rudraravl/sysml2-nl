package WarehouseFulfillmentSystem {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQMass::*;
    import ISQTime::*;
    import ISQElectricity::*;

    // ---- Value Types ----

    value def BatteryLevel :> Real {
        unit %;
    }

    value def PodWeight :> Mass {
    }

    value def RobotSpeed :> Speed {
    }

    value def OrderCount :> Integer {
    }

    value def TaskPriority :> Integer {
    }

    value def ChargeRate :> Power {
    }

    value def Throughput :> Real {
        ref unit orders_per_hour = 1/[h];
    }

    value def Distance :> Length {
    }

    value def PayloadCapacity :> Mass {
    }

    // ---- Enumerations ----

    enum def RobotStatus {
        idle;
        navigatingToPod;
        liftingPod;
        transportingPod;
        atWorkstation;
        returningPod;
        navigatingToCharger;
        charging;
        faulted;
    }

    enum def PodStatus {
        inStorage;
        beingTransported;
        atWorkstation;
        beingReturned;
    }

    enum def OrderStatus {
        received;
        assigned;
        inProgress;
        picking;
        fulfilled;
        cancelled;
    }

    enum def TaskType {
        fetchPod;
        returnPod;
        chargeBattery;
    }

    enum def ChargeState {
        notCharging;
        charging;
        fullyCharged;
    }

    // ---- Item Types ----

    item def Product {
        attribute productId : String;
        attribute name : String;
        attribute weight : Mass;
        attribute quantityInPod : Integer;
    }

    item def OrderLine {
        attribute product : Product;
        attribute quantity : Integer;
    }

    item def CustomerOrder {
        attribute orderId : String;
        attribute lines : OrderLine[0..*];
        attribute status : OrderStatus;
        attribute receivedTime : DateTime;
    }

    item def TaskAssignment {
        attribute taskId : String;
        attribute taskType : TaskType;
        attribute priority : TaskPriority;
        attribute targetPodId : String;
        attribute destinationId : String;
        attribute assignedRobotId : String;
    }

    item def NavigationPath {
        attribute pathId : String;
        attribute waypoints : Position[0..*];
        attribute estimatedDistance : Distance;
        attribute estimatedDuration : Duration;
    }

    item def Position {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }

    item def ObstacleDetection {
        attribute detected : Boolean;
        attribute distance : Length;
        attribute direction : Real;
    }

    // ---- Port Definitions ----

    port def CommandPort {
        in task : TaskAssignment;
        in path : NavigationPath;
        out status : RobotStatus;
        out position : Position;
    }

    port def PodInterfacePort {
        out liftCommand : Boolean;
        in podPresent : Boolean;
        in podWeight : PodWeight;
    }

    port def WorkstationPort {
        in podArrived : Boolean;
        out pickComplete : Boolean;
        in order : CustomerOrder;
    }

    port def ChargingPort {
        in docked : Boolean;
        out chargeLevel : BatteryLevel;
        in chargeCurrent : ElectricCurrent;
    }

    port def PerceptionPort {
        out obstacle : ObstacleDetection;
        out qrCode : String;
        out visionData : String;
    }

    port def NetworkPort {
        in telemetry : String;
        out command : String;
    }

    // ---- Interfaces ----

    interface def RobotToPodInterface {
        end robotPort : PodInterfacePort;
        end podPort : PodInterfacePort;
    }

    interface def ControlToRobotInterface {
        end controlPort : CommandPort;
        end robotPort : CommandPort;
    }

    interface def RobotToChargerInterface {
        end robotPort : ChargingPort;
        end chargerPort : ChargingPort;
    }

    interface def RobotToWorkstationInterface {
        end robotPort : WorkstationPort;
        end stationPort : WorkstationPort;
    }

    // ---- Sub-components of Mobile Drive Unit ----

    part def DriveSystem {
        attribute maxSpeed : RobotSpeed = 1.5 [m/s];
        attribute currentSpeed : RobotSpeed;
        port driveControlIn : CommandPort;
        action def moveTo(in target : Position, in path : NavigationPath);
        action def stop();
        action def rotate(in angle : Real);
    }

    part def BatteryPack {
        attribute capacity : ElectricCharge = 50 [A*h];
        attribute currentLevel : BatteryLevel = 100 [%];
        attribute voltage : ElectricPotential = 48 [V];
        attribute lowThreshold : BatteryLevel = 20 [%];
        port powerOut : ChargingPort;
        action def discharge(in rate : Power);
        action def charge(in current : ElectricCurrent);
    }

    part def LiftingMechanism {
        attribute maxPayload : PayloadCapacity = 750 [kg];
        attribute liftHeight : Length = 0.1 [m];
        attribute isEngaged : Boolean = false;
        port liftPort : PodInterfacePort;
        action def liftPod(in weight : PodWeight);
        action def lowerPod();
        action def engage();
        action def disengage();
    }

    part def LiDAR {
        attribute range : Distance = 30 [m];
        attribute resolution : Real = 0.5;
        port sensorOut : PerceptionPort;
        action def scan() : ObstacleDetection;
    }

    part def VisionCamera {
        attribute fieldOfView : Real = 120;
        attribute resolution : String = "1920x1080";
        port sensorOut : PerceptionPort;
        action def capture() : String;
    }

    part def QRCodeScanner {
        attribute scanRate : Real = 10;
        port sensorOut : PerceptionPort;
        action def readCode() : String;
    }

    part def PerceptionSystem {
        part lidar : LiDAR;
        part camera : VisionCamera;
        part qrScanner : QRCodeScanner;
        port perceptionOut : PerceptionPort;
        action def perceiveEnvironment() : ObstacleDetection;
        action def detectObstacles() : ObstacleDetection;
        action def readFloorMarkers() : String;
        action def fuseSensorData() : String;
    }

    // ---- Inventory Pod ----

    part def InventoryPod {
        attribute podId : String;
        attribute podWeight : PodWeight;
        attribute maxLoad : PayloadCapacity = 500 [kg];
        attribute currentLoad : PodWeight;
        attribute status : PodStatus;
        attribute storageLocation : Position;
        attribute shelves : Product[0..*];
        port podInterface : PodInterfacePort;
        action def receiveLift();
        action def releaseLift();
    }

    // ---- Workstation ----

    part def Workstation {
        attribute stationId : String;
        attribute location : Position;
        attribute operatorPresent : Boolean = true;
        port stationPort : WorkstationPort;
        action def pickItems(in order : CustomerOrder, in pod : InventoryPod);
        action def completePick(out order : CustomerOrder);
    }

    // ---- Charging Dock ----

    part def ChargingDock {
        attribute dockId : String;
        attribute location : Position;
        attribute outputVoltage : ElectricPotential = 48 [V];
        attribute maxChargeCurrent : ElectricCurrent = 30 [A];
        attribute chargeRate : ChargeRate;
        port chargerPort : ChargingPort;
        action def dockRobot();
        action def supplyPower(out current : ElectricCurrent);
        action def undockRobot();
    }

    // ---- Warehouse Control System ----

    part def WarehouseControlSystem {
        attribute systemId : String;
        attribute maxThroughput : Throughput = 600 [orders_per_hour];
        attribute taskQueue : TaskAssignment[0..*];
        attribute activeOrders : CustomerOrder[0..*];
        attribute podRegistry : InventoryPod[0..*];
        attribute robotRegistry : MobileDriveUnit[0..*];
        port controlPort : CommandPort[0..*];
        port networkPort : NetworkPort;
        action def receiveOrder(in order : CustomerOrder);
        action def locatePods(in order : CustomerOrder) : InventoryPod[0..*];
        action def selectNearestRobot(in pod : InventoryPod) : MobileDriveUnit;
        action def createTask(in pod : InventoryPod, in destination : Position) : TaskAssignment;
        action def dispatchTask(in task : TaskAssignment, in robot : MobileDriveUnit);
        action def optimizePaths(in robots : MobileDriveUnit[0..*]) : NavigationPath[0..*];
        action def preventCollisions(in paths : NavigationPath[0..*]);
        action def trackInventory();
        action def manageTaskQueue();
        action def monitorFleet();
        action def assignReturnTask(in pod : InventoryPod, in robot : MobileDriveUnit);
    }

    // ---- Mobile Drive Unit ----

    part def MobileDriveUnit {
        attribute robotId : String;
        attribute status : RobotStatus;
        attribute currentPosition : Position;
        attribute maxPayload : PayloadCapacity = 750 [kg];
        attribute currentPod : InventoryPort[0..1];

        part driveSystem : DriveSystem;
        part battery : BatteryPack;
        part liftingMechanism : LiftingMechanism;
        part perception : PerceptionSystem;

        port commandPort : CommandPort;
        port podPort : PodInterfacePort;
        port chargerPort : ChargingPort;
        port workstationPort : WorkstationPort;

        // State machine for robot behavior
        state def RobotStateMachine {
            entry; then idle;

            state idle {
                entry action sendStatusIdle();
                do action waitForTask();
            }

            state navigatingToPod {
                entry action planPathToPod();
                do action navigateToPod();
            }

            state liftingPod {
                entry action engageLift();
                do action liftPod();
            }

            state transportingPod {
                entry action planPathToWorkstation();
                do action transportPod();
            }

            state atWorkstation {
                entry action notifyWorkstation();
                do action waitForPickComplete();
            }

            state returningPod {
                entry action planPathToStorage();
                do action returnPodToStorage();
            }

            state navigatingToCharger {
                entry action planPathToCharger();
                do action navigateToCharger();
            }

            state charging {
                entry action connectToCharger();
                do action chargeBattery();
            }

            state faulted {
                entry action reportFault();
                do action awaitMaintenance();
            }

            transition idle_navigatingToPod
                first idle
                accept TaskAssignment
                then navigatingToPod;

            transition navigatingToPod_liftingPod
                first navigatingToPod
                when perception.readFloorMarkers() == currentPod.podId
                then liftingPod;

            transition liftingPod_transportingPod
                first liftingPod
                when liftingMechanism.isEngaged == true
                then transportingPod;

            transition transportingPod_atWorkstation
                first transportingPod
                when currentPosition == workstation.location
                then atWorkstation;

            transition atWorkstation_returningPod
                first atWorkstation
                accept pickComplete
                then returningPod;

            transition returningPod_idle
                first returningPod
                when podPort.podPresent == false
                then idle;

            transition idle_navigatingToCharger
                first idle
                when battery.currentLevel <= battery.lowThreshold
                then navigatingToCharger;

            transition navigatingToCharger_charging
                first navigatingToCharger
                when currentPosition == chargingDock.location
                then charging;

            transition charging_idle
                first charging
                when battery.currentLevel >= 95 [%]
                then idle;

            transition any_faulted
                first idle, navigatingToPod, liftingPod, transportingPod, atWorkstation, returningPod, navigatingToCharger, charging
                accept Fault
                then faulted;

            transition faulted_idle
                first faulted
                accept MaintenanceComplete
                then idle;
        }

        state machine : RobotStateMachine;

        action def sendStatusIdle();
        action def waitForTask();
        action def planPathToPod();
        action def navigateToPod();
        action def engageLift();
        action def liftPod();
        action def planPathToWorkstation();
        action def transportPod();
        action def notifyWorkstation();
        action def waitForPickComplete();
        action def planPathToStorage();
        action def returnPodToStorage();
        action def planPathToCharger();
        action def navigateToCharger();
        action def connectToCharger();
        action def chargeBattery();
        action def reportFault();
        action def awaitMaintenance();

        action def executeTask(in task : TaskAssignment) {
            // Navigate to pod
            send driveSystem.moveToToPod(task.targetPodId);
            // Lift pod
            send liftingMechanism.engage();
            // Transport to destination
            send driveSystem.moveTo(task.destinationId);
            // Wait for picking
            receive workstationPort.pickComplete;
            // Return pod
            send driveSystem.moveToStorage();
            send liftingMechanism.disengage();
        }
    }

    // ---- Warehouse System (Top-level) ----

    part def WarehouseFulfillmentSystem {
        attribute systemName : String = "AutomatedWarehouseFulfillmentSystem";
        attribute maxPodWeight : PayloadCapacity = 750 [kg];
        attribute targetThroughput : Throughput = 600 [orders_per_hour];

        part controlSystem : WarehouseControlSystem;
        part robots : MobileDriveUnit[0..*];
        part pods : InventoryPod[0..*];
        part workstations : Workstation[0..*];
        part chargingDocks : ChargingDock[0..*];

        // Connections between control system and robots
        connection controlToRobots : ControlToRobotInterface connect controlSystem.controlPort to robots.commandPort;

        // Connections between robots and pods
        connection robotToPod : RobotToPodInterface connect robots.podPort to pods.podInterface;

        // Connections between robots and workstations
        connection robotToWorkstation : RobotToWorkstationInterface connect robots.workstationPort to workstations.stationPort;

        // Connections between robots and charging docks
        connection robotToCharger : RobotToChargerInterface connect robots.chargerPort to chargingDocks.chargerPort;

        // Internal power connections
        connection batteryToDrive : ChargingPort connect robots.battery.powerOut to robots.driveSystem.driveControlIn;

        // Perception connections
        connection perceptionToDrive : PerceptionPort connect robots.perception.perceptionOut to robots.driveSystem.driveControlIn;

        // Lift mechanism connections
        connection liftToPod : PodInterfacePort connect robots.liftingMechanism.liftPort to robots.podPort;

        action def processOrder(in order : CustomerOrder) {
            // WCS receives order
            controlSystem.receiveOrder(order);
            // Locate pods containing required items
            var requiredPods : InventoryPod[0..*] = controlSystem.locatePods(order);
            // For each pod, select nearest robot and dispatch
            for pod in requiredPods {
                var robot : MobileDriveUnit = controlSystem.selectNearestRobot(pod);
                var task : TaskAssignment = controlSystem.createTask(pod, workstations[1].location);
                controlSystem.dispatchTask(task, robot);
            }
        }

        action def optimizeFleet() {
            var paths : NavigationPath[0..*] = controlSystem.optimizePaths(robots);
            controlSystem.preventCollisions(paths);
        }

        action def manageCharging() {
            for robot in robots {
                if robot.battery.currentLevel <= robot.battery.lowThreshold {
                    var dock : ChargingDock = chargingDocks[1];
                    var chargeTask : TaskAssignment = TaskAssignment{
                        taskId = "CHARGE_" + robot.robotId;
                        taskType = TaskType::chargeBattery;
                        priority = 10;
                        targetPodId = "";
                        destinationId = dock.dockId;
                        assignedRobotId = robot.robotId;
                    };
                    controlSystem.dispatchTask(chargeTask, robot);
                }
            }
        }
    }

    // ---- Requirements ----

    requirement def GoodsToPersonRequirement {
        doc /* The system shall implement a goods-to-person fulfillment model where robots transport inventory pods to stationary workstations. */
        subject : WarehouseFulfillmentSystem;
        requirement goodsToPersonOperation {
            doc /* Robots shall bring inventory pods to human operators at workstations. */
        }
    }

    requirement def PayloadRequirement {
        doc /* Each mobile drive unit shall be capable of lifting and transporting inventory pods weighing up to 750 kg. */
        subject : MobileDriveUnit;
        attribute requiredPayload : PayloadCapacity = 750 [kg];
        requirement maxPayload {
            doc /* The lifting mechanism shall support a maximum payload of 750 kg. */
            subject : LiftingMechanism;
            constraint { maxPayload >= 750 [kg] }
        }
    }

    requirement def ThroughputRequirement {
        doc /* The system shall process hundreds of orders per hour in high-throughput environments. */
        subject : WarehouseFulfillmentSystem;
        attribute minThroughput : Throughput = 300 [orders_per_hour];
        attribute targetThroughput : Throughput = 600 [orders_per_hour];
        constraint { targetThroughput >= 300 [orders_per_hour] }
    }

    requirement def NavigationSafetyRequirement {
        doc /* Each robot shall use LiDAR, vision cameras, and QR code scanners for navigation, obstacle avoidance, and path following. */
        subject : MobileDriveUnit;
        requirement perceptionComponents {
            doc /* The perception system shall include LiDAR, vision cameras, and QR code scanners. */
            subject : PerceptionSystem;
            constraint { lidar != null && camera != null && qrScanner != null }
        }
        requirement obstacleAvoidance {
            doc /* The robot shall detect and avoid obstacles in its path. */
            subject : PerceptionSystem;
        }
    }

    requirement def BatteryManagementRequirement {
        doc /* Robots shall autonomously navigate to charging docks when battery level falls below a threshold. */
        subject : MobileDriveUnit;
        attribute lowBatteryThreshold : BatteryLevel = 20 [%];
        requirement autoCharging {
            doc /* When battery level is at or below 20%, the robot shall proceed to a charging dock. */
            constraint { battery.lowThreshold <= 20 [%] }
        }
        requirement continuousOperation {
            doc /* The system shall ensure continuous operation through fleet charging management. */
            subject : WarehouseControlSystem;
        }
    }

    requirement def ControlSystemRequirement {
        doc /* The Warehouse Control System shall orchestrate the fleet, optimize paths, manage the task queue, and track inventory and orders. */
        subject : WarehouseControlSystem;
        requirement fleetOrchestration {
            doc /* The WCS shall dispatch tasks to the nearest available robot. */
        }
        requirement pathOptimization {
            doc /* The WCS shall optimize robot paths to prevent collisions. */
        }
        requirement taskQueueManagement {
            doc /* The WCS shall maintain and prioritize a task queue. */
        }
        requirement inventoryTracking {
            doc /* The WCS shall track all inventory pods and their storage locations. */
        }
    }

    requirement def PodReturnRequirement {
        doc /* After picking is complete, the robot shall return the inventory pod to an open storage location. */
        subject : MobileDriveUnit;
        requirement podReturn {
            doc /* The robot shall transport the pod back to storage and disengage the lift mechanism. */
        }
    }

    requirement def WorkstationRequirement {
        doc /* Workstations shall provide a stationary picking location where human operators pick items from pods. */
        subject : Workstation;
        requirement pickingOperation {
            doc /* The workstation shall signal pick completion to the robot upon order fulfillment. */
        }
    }

    // ---- Verification Actions ----

    action def verifyPayloadCapacity(in robot : MobileDriveUnit) : Boolean {
        return robot.liftingMechanism.maxPayload >= 750 [kg];
    }

    action def verifyThroughput(in system : WarehouseFulfillmentSystem) : Boolean {
        return system.targetThroughput >= 300 [orders_per_hour];
    }

    action def verifyPerceptionSystem(in robot : MobileDriveUnit) : Boolean {
        return robot.perception.lidar != null && robot.perception.camera != null && robot.perception.qrScanner != null;
    }

    action def verifyBatteryThreshold(in robot : MobileDriveUnit) : Boolean {
        return robot.battery.lowThreshold <= 20 [%];
    }

    // ---- Satisfaction ----

    satisfaction payloadSatisfaction : PayloadRequirement satisfy robots.maxPayload;
    satisfaction throughputSatisfaction : ThroughputRequirement satisfy WarehouseFulfillmentSystem.targetThroughput;
    satisfaction navigationSatisfaction : NavigationSafetyRequirement satisfy robots.perception;
    satisfaction batterySatisfaction : BatteryManagementRequirement satisfy robots.battery;
    satisfaction controlSatisfaction : ControlSystemRequirement satisfy controlSystem;

}
