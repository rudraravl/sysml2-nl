package WarehouseRobot {

    import ScalarValues::*;

    // ===== Value Types =====
    value def MassKg :> Real;
    value def LengthM :> Real;
    value def SpeedMps :> Real;
    value def VoltageV :> Real;
    value def CurrentA :> Real;
    value def EnergyWh :> Real;
    value def AngleDeg :> Real;
    value def BatteryLevel :> Real;
    value def TimeS :> Real;
    value def PowerW :> Real;

    // ===== Item Definitions =====
    item def Package {
        attribute packageId : String;
        attribute weight : MassKg;
        attribute destinationId : String;
    }

    item def Pose {
        attribute x : LengthM;
        attribute y : LengthM;
        attribute heading : AngleDeg;
    }

    item def Obstacle {
        attribute distance : LengthM;
        attribute bearing : AngleDeg;
        attribute isDynamic : Boolean;
    }

    item def ObstacleScan {
        attribute obstacles : Obstacle[0..*];
        attribute timestamp : TimeS;
    }

    item def EncoderData {
        attribute leftWheelTicks : Integer;
        attribute rightWheelTicks : Integer;
        attribute timestamp : TimeS;
    }

    item def OdometryData {
        attribute pose : Pose;
        attribute linearVelocity : SpeedMps;
        attribute angularVelocity : AngleDeg;
        attribute timestamp : TimeS;
    }

    item def Path {
        attribute waypoints : Pose[0..*];
        attribute totalLength : LengthM;
        attribute estimatedTime : TimeS;
    }

    item def PathRequest {
        attribute start : Pose;
        attribute goal : Pose;
    }

    item def MissionCommand {
        attribute commandId : String;
        attribute pickupPose : Pose;
        attribute deliveryPose : Pose;
        attribute packageRef : Package;
    }

    item def DriveCommand {
        attribute linearVelocity : SpeedMps;
        attribute angularVelocity : AngleDeg;
    }

    item def LiftCommand {
        attribute targetHeight : LengthM;
        attribute action : String;
    }

    item def BatteryStatus {
        attribute level : BatteryLevel;
        attribute voltage : VoltageV;
        attribute current : CurrentA;
        attribute remainingEnergy : EnergyWh;
        attribute isCharging : Boolean;
    }

    item def WarehouseMap {
        attribute resolution : LengthM;
        attribute knownObstacles : Obstacle[0..*];
        attribute chargingStationPose : Pose;
    }

    // ===== Port Definitions =====
    port def PowerOutPort {
        out batteryStatus : BatteryStatus;
    }

    port def PowerInPort {
        in batteryStatus : BatteryStatus;
    }

    port def ChargingOutPort {
        out voltage : VoltageV;
        out current : CurrentA;
    }

    port def ChargingInPort {
        in voltage : VoltageV;
        in current : CurrentA;
    }

    port def ScanOutPort {
        out scanData : ObstacleScan;
    }

    port def ScanInPort {
        in scanData : ObstacleScan;
    }

    port def OdomOutPort {
        out odomData : OdometryData;
    }

    port def OdomInPort {
        in odomData : OdometryData;
    }

    port def EncoderOutPort {
        out encoderData : EncoderData;
    }

    port def EncoderInPort {
        in encoderData : EncoderData;
    }

    port def PathOutPort {
        out pathData : Path;
    }

    port def PathInPort {
        in pathData : Path;
    }

    port def PathReqOutPort {
        out request : PathRequest;
    }

    port def PathReqInPort {
        in request : PathRequest;
    }

    port def DriveCmdOutPort {
        out cmd : DriveCommand;
    }

    port def DriveCmdInPort {
        in cmd : DriveCommand;
    }

    port def LiftCmdOutPort {
        out cmd : LiftCommand;
    }

    port def LiftCmdInPort {
        in cmd : LiftCommand;
    }

    port def MissionCmdInPort {
        in command : MissionCommand;
    }

    // ===== Action Definitions =====
    action def DischargeAction {
        in consumption : PowerW;
        out updatedStatus : BatteryStatus;
    }

    action def ChargeAction {
        in supplyVoltage : VoltageV;
        in supplyCurrent : CurrentA;
        out updatedStatus : BatteryStatus;
    }

    action def DriveAction {
        in cmd : DriveCommand;
        out encoderData : EncoderData;
    }

    action def ScanAction {
        out scanData : ObstacleScan;
    }

    action def ComputeOdometryAction {
        in encoderData : EncoderData;
        in previousPose : Pose;
        out odomData : OdometryData;
    }

    action def PlanPathAction {
        in request : PathRequest;
        in scanData : ObstacleScan;
        in currentMap : WarehouseMap;
        out pathData : Path;
    }

    action def RaiseLiftAction {
        in targetHeight : LengthM;
    }

    action def LowerLiftAction {
        in targetHeight : LengthM;
    }

    action def PickUpPackageAction {
        in pkg : Package;
        out success : Boolean;
    }

    action def DropOffPackageAction {
        out pkg : Package;
    }

    // ===== Part Definitions =====

    part def BatteryPack {
        port powerOut : PowerOutPort;
        port chargingIn : ChargingInPort;

        attribute capacity : EnergyWh = 480.0;
        attribute nominalVoltage : VoltageV = 24.0;
        attribute maxChargeCurrent : CurrentA = 10.0;
        attribute lowThreshold : BatteryLevel = 20.0;
        attribute fullThreshold : BatteryLevel = 95.0;
        attribute criticalThreshold : BatteryLevel = 10.0;
        attribute currentLevel : BatteryLevel = 100.0;
        attribute currentVoltage : VoltageV = 24.0;
        attribute currentDraw : CurrentA = 0.0;
        attribute isCharging : Boolean = false;

        action discharge : DischargeAction;
        action charge : ChargeAction;

        action def monitorBatteryLevel {
            in consumption : PowerW;
            out status : BatteryStatus;
            /* Calculate currentLevel based on consumption over time.
               If level drops below lowThreshold, signal batteryLow.
               If level drops below criticalThreshold, force emergency stop. */
        }
    }

    part def DriveSystem {
        port driveCmdIn : DriveCmdInPort;
        port encoderOut : EncoderOutPort;
        port powerIn : PowerInPort;

        attribute maxSpeed : SpeedMps = 1.5;
        attribute maxAngularSpeed : AngleDeg = 90.0;
        attribute wheelDiameter : LengthM = 0.15;
        attribute wheelbase : LengthM = 0.4;
        attribute encoderResolution : Integer = 2048;

        action drive : DriveAction;

        action def readEncoders {
            out encoderData : EncoderData;
            /* Read wheel encoder tick counts from both drive motors */
        }
    }

    part def LiftMechanism {
        port liftCmdIn : LiftCmdInPort;
        port powerIn : PowerInPort;

        attribute maxHeight : LengthM = 1.5;
        attribute minHeight : LengthM = 0.05;
        attribute maxPayload : MassKg = 50.0;
        attribute liftSpeed : SpeedMps = 0.1;
        attribute currentHeight : LengthM = 0.05;
        attribute isLoaded : Boolean = false;
        attribute loadedPackage : Package;

        action raise : RaiseLiftAction;
        action lower : LowerLiftAction;
        action pickUp : PickUpPackageAction;
        action dropOff : DropOffPackageAction;

        action def executeLiftCommand {
            in cmd : LiftCommand;
            /* If cmd.action == "raise", invoke raise action.
               If cmd.action == "lower", invoke lower action.
               If cmd.action == "pickup", invoke pickUp action.
               If cmd.action == "dropoff", invoke dropOff action. */
        }
    }

    part def Lidar {
        port scanOut : ScanOutPort;
        port powerIn : PowerInPort;

        attribute maxRange : LengthM = 10.0;
        attribute minRange : LengthM = 0.1;
        attribute angularResolution : AngleDeg = 1.0;
        attribute scanRateHz : Real = 10.0;
        attribute scanPeriod : TimeS = 0.1;
        attribute numBeams : Integer = 360;

        action scan : ScanAction;

        action def continuousScan {
            out scanData : ObstacleScan;
            /* Continuously rotate laser and measure distances.
               Package results into ObstacleScan at 10 Hz. */
        }
    }

    part def OdometrySystem {
        port encoderIn : EncoderInPort;
        port odomOut : OdomOutPort;
        port powerIn : PowerInPort;

        attribute wheelDiameter : LengthM = 0.15;
        attribute countsPerRevolution : Integer = 2048;
        attribute currentPose : Pose;

        action computeOdometry : ComputeOdometryAction;

        action def updatePose {
            in encoderData : EncoderData;
            /* Calculate distance traveled from encoder ticks.
               Update currentPose based on differential drive kinematics.
               Output OdometryData with pose, velocity, and timestamp. */
        }
    }

    part def PathPlanner {
        port scanIn : ScanInPort;
        port odomIn : OdomInPort;
        port pathReqIn : PathReqInPort;
        port pathOut : PathOutPort;
        port powerIn : PowerInPort;

        attribute warehouseMap : WarehouseMap;
        attribute mapResolution : LengthM = 0.05;
        attribute pathOptimizationWeight : Real = 1.0;
        attribute safetyMargin : LengthM = 0.3;

        action planPath : PlanPathAction;

        action def updateMap {
            in scanData : ObstacleScan;
            /* Integrate new obstacle detections into the warehouse map.
               Mark dynamic obstacles with timestamps for decay. */
        }

        action def evaluatePathSafety {
            in pathData : Path;
            in scanData : ObstacleScan;
            out isSafe : Boolean;
            /* Check if any obstacle on the current scan conflicts
               with the planned path within safetyMargin. */
        }
    }

    // ===== State Machine Definition =====
    state def MissionStateMachine {
        attribute missionReceived : Boolean = false;
        attribute pathCalculated : Boolean = false;
        attribute reachedPickup : Boolean = false;
        attribute packagePickedUp : Boolean = false;
        attribute reachedDelivery : Boolean = false;
        attribute packageDelivered : Boolean = false;
        attribute batteryLow : Boolean = false;
        attribute reachedCharger : Boolean = false;
        attribute batteryCharged : Boolean = false;
        attribute obstacleDetected : Boolean = false;
        attribute obstacleCleared : Boolean = true;
        attribute missionInterrupted : Boolean = false;

        state idle {
            entry {
                /* Reset all mission flags.
                   Await incoming mission command from external system. */
            }
            do {
                /* Continuously monitor battery level.
                   If batteryLow becomes true, transition to emergencyCharging. */
            }
        }

        state planning {
            entry {
                /* Construct PathRequest with current pose as start
                   and mission pickupPose as goal.
                   Send PathRequest to PathPlanner via pathReqOut port. */
            }
            do {
                /* Wait for path data from PathPlanner. */
            }
        }

        state navigating {
            entry {
                /* Begin following the calculated path waypoints.
                   Send DriveCommands to DriveSystem. */
            }

            state pathFollowing {
                do {
                    /* Issue sequential DriveCommands to follow each waypoint.
                       Monitor odometry for arrival at target location. */
                }
            }

            state obstacleAvoidance {
                entry {
                    /* Stop robot immediately.
                     Request replanned path from PathPlanner avoiding new obstacles. */
                }
                do {
                    /* Wait for replanned path, then resume navigation. */
                }
            }

            transition from pathFollowing to obstacleAvoidance
                when obstacleDetected;

            transition from obstacleAvoidance to pathFollowing
                when obstacleCleared;
        }

        state loading {
            entry {
                /* Position robot precisely at pickup location.
                   Send LiftCommand to lower lift to minHeight. */
            }
            do {
                /* Send LiftCommand to pick up package.
                   Send LiftCommand to raise lift to transport height. */
            }
            exit {
                /* Set packagePickedUp flag to true. */
            }
        }

        state unloading {
            entry {
                /* Position robot precisely at delivery location.
                   Send LiftCommand to lower lift to delivery height. */
            }
            do {
                /* Send LiftCommand to drop off package.
                   Send LiftCommand to raise lift to minHeight. */
            }
            exit {
                /* Set packageDelivered flag to true.
                   Clear loadedPackage from LiftMechanism. */
            }
        }

        state emergencyCharging {
            entry {
                /* Set missionInterrupted to true.
                   Construct PathRequest with current pose as start
                   and chargingStationPose as goal.
                   Send PathRequest to PathPlanner. */
            }
            do {
                /* Navigate to charging station using drive commands.
                   Monitor odometry for arrival at charging station. */
            }
        }

        state charging {
            entry {
                /* Dock with charging station.
                   Enable charging on BatteryPack via chargingIn port. */
            }
            do {
                /* Monitor battery level until fullThreshold is reached. */
            }
            exit {
                /* Disconnect from charging station.
                   Clear missionInterrupted if mission was in progress. */
            }
        }

        // Normal mission flow
        transition from idle to planning
            when missionReceived;

        transition from planning to navigating
            when pathCalculated;

        transition from navigating to loading
            when reachedPickup;

        transition from loading to navigating
            when packagePickedUp;

        transition from navigating to unloading
            when reachedDelivery;

        transition from unloading to idle
            when packageDelivered;

        // Low battery interrupt transitions
        transition from idle to emergencyCharging
            when batteryLow;

        transition from planning to emergencyCharging
            when batteryLow;

        transition from navigating to emergencyCharging
            when batteryLow;

        transition from loading to emergencyCharging
            when batteryLow;

        transition from unloading to emergencyCharging
            when batteryLow;

        // Charging flow
        transition from emergencyCharging to charging
            when reachedCharger;

        transition from charging to idle
            when batteryCharged;
    }

    part def MissionController {
        port missionCmdIn : MissionCmdInPort;
        port scanIn : ScanInPort;
        port odomIn : OdomInPort;
        port pathIn : PathInPort;
        port pathReqOut : PathReqOutPort;
        port driveCmdOut : DriveCmdOutPort;
        port liftCmdOut : LiftCmdOutPort;
        port powerIn : PowerInPort;

        attribute currentMission : MissionCommand;
        attribute currentPath : Path;
        attribute chargingStationPose : Pose;
        attribute batteryLowThreshold : BatteryLevel = 20.0;
        attribute batteryFullThreshold : BatteryLevel = 95.0;
        attribute obstacleStopDistance : LengthM = 0.5;
        attribute arrivalTolerance : LengthM = 0.1;

        state missionState : MissionStateMachine;

        action def executeMission {
            in command : MissionCommand;
            /* Set currentMission from command.
               Set missionReceived flag to trigger state transition. */
        }

        action def monitorBattery {
            in status : BatteryStatus;
            /* If status.level < batteryLowThreshold, set batteryLow flag.
               If status.level >= batteryFullThreshold and in charging state,
               set batteryCharged flag. */
        }

        action def checkArrival {
            in odomData : OdometryData;
            in targetPose : Pose;
            out arrived : Boolean;
            /* Compare current pose from odometry with target pose.
               Return true if within arrivalTolerance. */
        }

        action def processScan {
            in scanData : ObstacleScan;
            /* Check each obstacle in scan.
               If any obstacle distance < obstacleStopDistance,
               set obstacleDetected flag.
               Otherwise set obstacleCleared flag. */
        }

        action def generateDriveCommand {
            in currentPose : Pose;
            in targetWaypoint : Pose;
            out cmd : DriveCommand;
            /* Compute linear and angular velocity to move from
               currentPose toward targetWaypoint. */
        }
    }

    part def ChargingStation {
        port chargeOut : ChargingOutPort;
        attribute stationPose : Pose;
        attribute outputVoltage : VoltageV = 24.0;
        attribute maxChargeCurrent : CurrentA = 10.0;
        attribute isAvailable : Boolean = true;
    }

    // ===== Main System Part =====
    part def WarehouseRobotSystem {
        attribute systemName : String = "WarehouseAMR-01";
        attribute maxPayload : MassKg = 50.0;
        attribute maxLiftHeight : LengthM = 1.5;
        attribute maxSpeed : SpeedMps = 1.5;
        attribute operatingTempMin : Real = 0.0;
        attribute operatingTempMax : Real = 40.0;
        attribute robotWidth : LengthM = 0.6;
        attribute robotLength : LengthM = 0.8;

        part battery : BatteryPack;
        part drive : DriveSystem;
        part lift : LiftMechanism;
        part lidar : Lidar;
        part odometry : OdometrySystem;
        part planner : PathPlanner;
        part controller : MissionController;

        // Environment
        part chargingStation : ChargingStation;

        // Power distribution connections
        connection powerToDrive connect battery.powerOut to drive.powerIn;
        connection powerToLift connect battery.powerOut to lift.powerIn;
        connection powerToLidar connect battery.powerOut to lidar.powerIn;
        connection powerToOdom connect battery.powerOut to odometry.powerIn;
        connection powerToPlanner connect battery.powerOut to planner.powerIn;
        connection powerToController connect battery.powerOut to controller.powerIn;

        // Charging connection
        connection chargeToBattery connect chargingStation.chargeOut to battery.chargingIn;

        // Sensor data connections
        connection lidarToController connect lidar.scanOut to controller.scanIn;
        connection lidarToPlanner connect lidar.scanOut to planner.scanIn;

        // Odometry data connections
        connection odomToController connect odometry.odomOut to controller.odomIn;
        connection odomToPlanner connect odometry.odomOut to planner.odomIn;

        // Encoder data connection
        connection encoderToOdom connect drive.encoderOut to odometry.encoderIn;

        // Path planning connections
        connection pathReqToPlanner connect controller.pathReqOut to planner.pathReqIn;
        connection pathToController connect planner.pathOut to controller.pathIn;

        // Command connections
        connection driveCmdToDrive connect controller.driveCmdOut to drive.driveCmdIn;
        connection liftCmdToLift connect controller.liftCmdOut to lift.liftCmdIn;
    }

    // ===== Requirements =====
    requirement def TransportPackagesRequirement {
        subject robot : WarehouseRobotSystem;
        doc /* The robot shall transport packages from pickup locations such as storage shelves to delivery destinations such as packing stations without direct human intervention. */;
    }

    requirement def AutonomousNavigationRequirement {
        subject robot : WarehouseRobotSystem;

        requirement autonomousPathPlanning {
            subject robot;
            doc /* The PathPlanner shall calculate the most efficient and safest routes between points, taking into account known obstacles from sensors. */;
        }

        requirement obstacleAvoidance {
            subject robot;
            doc /* The robot shall detect and avoid obstacles using Lidar scan data, ensuring safe operation at all times. */;
        }

        requirement positionTracking {
            subject robot;
            doc /* The robot shall continuously track its position using the Odometry system, which calculates location based on wheel rotations. */;
        }

        requirement missionControl {
            subject robot;
            doc /* The MissionController shall act as the central brain, directing the robot's actions based on assigned tasks. */;
        }
    }

    requirement def PayloadHandlingRequirement {
        subject robot : WarehouseRobotSystem;

        requirement maxPayloadCapacity {
            subject robot;
            doc /* The Lift Mechanism shall handle packages up to 50 kg. */;
        }

        requirement maxLiftHeightCapability {
            subject robot;
            doc /* The Lift Mechanism shall raise and lower a platform to a maximum height of 1.5 m to pick up and drop off payloads. */;
        }

        requirement liftPickupAndDropoff {
            subject robot;
            doc /* The Lift Mechanism shall raise the platform to acquire a package at a pickup location and lower the platform to release a package at a delivery destination. */;
        }
    }

    requirement def BatterySelfSufficiencyRequirement {
        subject robot : WarehouseRobotSystem;

        requirement batteryMonitoring {
            subject robot;
            doc /* The robot shall continuously monitor its battery level. */;
        }

        requirement lowBatteryInterrupt {
            subject robot;
            doc /* The robot shall automatically interrupt its current work and navigate to a charging station when the battery level falls below 20 percent. */;
        }

        requirement resumeAfterCharge {
            subject robot;
            doc /* The robot shall resume idle operation after charging when the battery level reaches 95 percent. */;
        }

        requirement continuousOperation {
            subject robot;
            doc /* The system shall ensure continuous operation by self-managing power state without human intervention. */;
        }
    }

    requirement def OperationalModesRequirement {
        subject robot : WarehouseRobotSystem;

        requirement idleMode {
            subject robot;
            doc /* The robot shall enter idle mode while waiting for tasks. */;
        }

        requirement navigatingMode {
            subject robot;
            doc /* The robot shall enter navigating mode when driving to a destination. */;
        }

        requirement loadingMode {
            subject robot;
            doc /* The robot shall enter loading mode when acquiring a package at a pickup location. */;
        }

        requirement unloadingMode {
            subject robot;
            doc /* The robot shall enter unloading mode when releasing a package at a delivery destination. */;
        }

        requirement chargingMode {
            subject robot;
            doc /* The robot shall enter charging mode when its battery is low and it has reached a charging station. */;
        }
    }

    requirement def MissionExecutionRequirement {
        subject robot : WarehouseRobotSystem;
        doc /* A typical mission shall involve receiving a command, planning a path, driving to the pickup location, using the lift to acquire the package, navigating to the delivery destination, and finally unloading the package. */;
    }

    requirement def SafetyRequirement {
        subject robot : WarehouseRobotSystem;

        requirement continuousScanning {
            subject robot;
            doc /* The Lidar shall constantly scan the surroundings to detect obstacles. */;
        }

        requirement obstacleStopDistance {
            subject robot;
            doc /* The robot shall stop or reroute when an obstacle is detected within 0.5 m. */;
        }

        requirement safeOperationSpeed {
            subject robot;
            doc /* The robot shall not exceed 1.5 m/s maximum speed during autonomous navigation. */;
        }
    }

    requirement def DriveSystemRequirement {
        subject robot : WarehouseRobotSystem;
        doc /* The robot shall be built on a mobile platform equipped with a Drive System for movement. */;
    }

    requirement def PowerSupplyRequirement {
        subject robot : WarehouseRobotSystem;
        doc /* A rechargeable Battery Pack shall supply energy to all robot components including the Drive System, Lift Mechanism, Lidar, Odometry System, Path Planner, and Mission Controller. */;
    }

}
