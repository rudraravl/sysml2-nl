package TerabotS {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // ===== Value Types =====
    value type SpeedValue :> Real { attribute unit : String = "m/s"; }
    value type MassValue :> Real { attribute unit : String = "kg"; }
    value type LengthValue :> Real { attribute unit : String = "m"; }
    value type VoltageValue :> Real { attribute unit : String = "V"; }
    value type DistanceValue :> Real { attribute unit : String = "m"; }
    value type BatteryPercentage :> Real { attribute unit : String = "%"; }
    value type AngularPositionValue :> Real { attribute unit : String = "rad"; }
    value type TorqueValue :> Real { attribute unit : String = "N*m"; }
    value type FrequencyValue :> Real { attribute unit : String = "Hz"; }
    value type CurrentValue :> Real { attribute unit : String = "A"; }
    value type DurationValue :> Real { attribute unit : String = "s"; }

    // ===== Enumerations =====
    enum def OperationalMode {
        AUTONOMOUS;
        TELEOPERATION;
        CHARGING;
        IDLE;
    }

    enum def SystemHealth {
        HEALTHY;
        DEGRADED;
        FAULT;
    }

    enum def GripperState {
        OPEN;
        CLOSED;
    }

    enum def TaskType {
        INSPECTION;
        MATERIAL_HANDLING;
        REMOTE_OPERATION;
        NAVIGATION;
        CHARGING_TASK;
    }

    // ===== Item Definitions =====
    item def PointCloud {
        attribute pointCount : Integer;
        attribute resolution : DistanceValue;
        attribute maxRange : DistanceValue;
    }

    item def ImageData {
        attribute width : Integer;
        attribute height : Integer;
        attribute frameRate : FrequencyValue;
        attribute encoding : String;
    }

    item def FusedMap {
        attribute resolution : DistanceValue;
        attribute coverageArea : Real;
        attribute obstacleCount : Integer;
        attribute timestamp : Real;
    }

    item def PathPlan {
        attribute waypointCount : Integer;
        attribute estimatedDuration : DurationValue;
        attribute totalDistance : LengthValue;
        attribute safeCorridorWidth : LengthValue;
    }

    item def MotionCommand {
        attribute linearVelocity : SpeedValue;
        attribute angularVelocity : Real;
        attribute direction : String;
    }

    item def ArmCommand {
        attribute jointPositions : List[6] of AngularPositionValue;
        attribute gripperAction : GripperState;
        attribute payloadEstimate : MassValue;
    }

    item def MissionPlan {
        attribute taskSequence : List of TaskType;
        attribute priority : Integer;
        attribute estimatedDuration : DurationValue;
        attribute waypoints : List of String;
    }

    item def StatusReport {
        attribute batteryLevel : BatteryPercentage;
        attribute currentMode : OperationalMode;
        attribute currentSpeed : SpeedValue;
        attribute armStatus : String;
        attribute systemHealth : SystemHealth;
        attribute timestamp : Real;
    }

    item def PowerFlow {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def TeleopCommand {
        attribute linearVelocity : SpeedValue;
        attribute angularVelocity : Real;
        attribute armJointCommands : List[6] of AngularPositionValue;
        attribute gripperCommand : GripperState;
    }

    item def NavigationCommand {
        attribute destination : String;
        attribute speedLimit : SpeedValue;
        attribute avoidObstacles : Boolean;
    }

    item def ObstacleList {
        attribute count : Integer;
        attribute nearestDistance : DistanceValue;
        attribute directions : List of Real;
    }

    // ===== Port Definitions =====
    port def PowerOutPort {
        out power : PowerFlow;
    }

    port def PowerInPort {
        in power : PowerFlow;
    }

    port def ChargingInPort {
        in chargePower : PowerFlow;
    }

    port def LidarDataOutPort {
        out pointCloud : PointCloud;
    }

    port def LidarDataInPort {
        in pointCloud : PointCloud;
    }

    port def VisionDataOutPort {
        out image : ImageData;
    }

    port def VisionDataInPort {
        in image : ImageData;
    }

    port def FusedDataOutPort {
        out fusedMap : FusedMap;
    }

    port def FusedDataInPort {
        in fusedMap : FusedMap;
    }

    port def MotionCommandOutPort {
        out motionCmd : MotionCommand;
    }

    port def MotionCommandInPort {
        in motionCmd : MotionCommand;
    }

    port def ArmCommandOutPort {
        out armCmd : ArmCommand;
    }

    port def ArmCommandInPort {
        in armCmd : ArmCommand;
    }

    port def StatusOutPort {
        out status : StatusReport;
    }

    port def StatusInPort {
        in status : StatusReport;
    }

    port def MissionInPort {
        in mission : MissionPlan;
    }

    port def MissionOutPort {
        out mission : MissionPlan;
    }

    port def TeleopCommandOutPort {
        out teleopCmd : TeleopCommand;
    }

    port def TeleopCommandInPort {
        in teleopCmd : TeleopCommand;
    }

    port def NavCommandOutPort {
        out navCommand : NavigationCommand;
    }

    port def NavCommandInPort {
        in navCommand : NavigationCommand;
    }

    port def PathOutPort {
        out path : PathPlan;
    }

    port def PathInPort {
        in path : PathPlan;
    }

    port def ObstacleOutPort {
        out obstacles : ObstacleList;
    }

    // ===== Requirements =====
    requirement def TerabotSRequirements {
        doc /* Top-level requirements for the Terabot-S autonomous mobile robot. */
        subject robot : TerabotS;
    }

    requirement MaxSpeedRequirement :> TerabotSRequirements {
        doc /* The robot shall travel at speeds up to 3.5 m/s. */
        constraint { robot.mobilePlatform.maxSpeed <= 3.5 }
    }

    requirement ArmPayloadRequirement :> TerabotSRequirements {
        doc /* The manipulator arm shall lift payloads up to 8 kg. */
        constraint { robot.manipulatorArm.maxPayload <= 8.0 }
    }

    requirement ArmReachRequirement :> TerabotSRequirements {
        doc /* The manipulator arm shall have a reach of 1 m. */
        constraint { robot.manipulatorArm.maxReach <= 1.0 }
    }

    requirement ArmJointsRequirement :> TerabotSRequirements {
        doc /* The manipulator arm shall have six joints for dexterity. */
        constraint { robot.manipulatorArm.jointCount == 6 }
    }

    requirement LidarRangeRequirement :> TerabotSRequirements {
        doc /* The lidar sensor shall detect obstacles up to 50 m away. */
        constraint { robot.lidarSensor.maxRange >= 50.0 }
    }

    requirement LidarMappingRequirement :> TerabotSRequirements {
        doc /* The lidar sensor shall create a 3D map for navigation. */
    }

    requirement VisionSystemRequirement :> TerabotSRequirements {
        doc /* The vision system shall provide high-definition visual information for object identification and terrain understanding. */
    }

    requirement BatteryVoltageRequirement :> TerabotSRequirements {
        doc /* The battery pack shall be a rechargeable 48 V system. */
        constraint { robot.batteryPack.nominalVoltage == 48.0 }
    }

    requirement AutonomousModeRequirement :> TerabotSRequirements {
        doc /* The robot shall operate in autonomous mode, following a mission plan by continuously sensing, planning, and executing motion and manipulation tasks. */
    }

    requirement TeleoperationModeRequirement :> TerabotSRequirements {
        doc /* The robot shall support direct human teleoperation. */
    }

    requirement AutoRechargeRequirement :> TerabotSRequirements {
        doc /* The robot shall automatically return to a charging station when battery level is low and resume tasks after charging. */
    }

    requirement ObstacleAvoidanceRequirement :> TerabotSRequirements {
        doc /* The robot shall avoid obstacles using fused lidar and vision data. */
    }

    requirement StatusReportingRequirement :> TerabotSRequirements {
        doc /* The robot shall report its status back to an operator. */
    }

    requirement NavigationPlanningRequirement :> TerabotSRequirements {
        doc /* The navigation unit shall plan safe and efficient paths using fused sensor data. */
    }

    // ===== Part Definitions =====

    part def Wheel {
        attribute diameter : LengthValue = 0.3;
        attribute maxRPM : Real = 300.0;
        attribute currentRPM : Real;
        attribute material : String = "Rubber";
    }

    part def DriveController {
        attribute currentSpeed : SpeedValue;
        attribute currentHeading : Real;
        attribute tractionControlEnabled : Boolean = true;

        action applyMotionCommand {
            in cmd : MotionCommand;
            out wheelSpeeds : List[4] of Real;
        }

        action regulateSpeed {
            in targetSpeed : SpeedValue;
            out actualSpeed : SpeedValue;
        }
    }

    part def MobilePlatform {
        attribute maxSpeed : SpeedValue = 3.5;
        attribute wheelbase : LengthValue = 0.6;
        attribute mass : MassValue = 35.0;
        attribute groundClearance : LengthValue = 0.15;
        attribute driveType : String = "Four-wheel differential";

        port powerIn : PowerInPort;
        port motionCommandIn : MotionCommandInPort;
        port statusOut : StatusOutPort;

        part frontLeftWheel : Wheel { attribute diameter = 0.3; }
        part frontRightWheel : Wheel { attribute diameter = 0.3; }
        part rearLeftWheel : Wheel { attribute diameter = 0.3; }
        part rearRightWheel : Wheel { attribute diameter = 0.3; }

        part driveController : DriveController;

        action move {
            in cmd : MotionCommand;
            out actualSpeed : SpeedValue;
            out actualHeading : Real;
        }

        action brake {
            out deceleration : Real;
        }

        action estimateOdometry {
            out position : String;
            out heading : Real;
        }
    }

    part def Joint {
        attribute jointId : Integer;
        attribute position : AngularPositionValue;
        attribute torque : TorqueValue;
        attribute maxTorque : TorqueValue = 45.0;
        attribute minAngle : AngularPositionValue;
        attribute maxAngle : AngularPositionValue;
        attribute velocity : Real;

        action actuate {
            in targetPosition : AngularPositionValue;
            out currentPosition : AngularPositionValue;
        }

        action holdPosition {
            in currentPosition : AngularPositionValue;
        }
    }

    part def Gripper {
        attribute state : GripperState = GripperState::OPEN;
        attribute maxGripForce : Real = 50.0;
        attribute currentGripForce : Real;
        attribute payloadCapacity : MassValue = 8.0;

        action open {
            out state : GripperState;
        }

        action close {
            in force : Real;
            out state : GripperState;
        }

        action senseGrip {
            out gripForce : Real;
            out objectDetected : Boolean;
        }
    }

    part def ArmController {
        attribute kinematicsModel : String = "6-DOF inverse kinematics";
        attribute controlRate : FrequencyValue = 100.0;

        action solveInverseKinematics {
            in targetPose : String;
            out jointAngles : List[6] of AngularPositionValue;
        }

        action executeArmCommand {
            in cmd : ArmCommand;
            out jointPositions : List[6] of AngularPositionValue;
            out gripperState : GripperState;
        }

        action computePayload {
            in jointAngles : List[6] of AngularPositionValue;
            out payloadEstimate : MassValue;
        }
    }

    part def ManipulatorArm {
        attribute maxPayload : MassValue = 8.0;
        attribute maxReach : LengthValue = 1.0;
        attribute jointCount : Integer = 6;
        attribute currentPayload : MassValue;
        attribute mountingPosition : String = "Top-center of mobile platform";

        port powerIn : PowerInPort;
        port armCommandIn : ArmCommandInPort;
        port statusOut : StatusOutPort;

        part joints : Joint[6] {
            attribute jointId = 1;
        }

        part gripper : Gripper;

        part armController : ArmController;

        action pickAndPlace {
            in targetObject : String;
            in destination : String;
            out success : Boolean;
        }

        action inspectObject {
            in targetObject : String;
            out inspectionResult : String;
        }

        action homePosition {
            out jointPositions : List[6] of AngularPositionValue;
        }
    }

    part def LidarSensor {
        attribute maxRange : DistanceValue = 50.0;
        attribute scanRate : FrequencyValue = 10.0;
        attribute angularResolution : Real = 0.5;
        attribute fieldOfView : Real = 360.0;
        attribute laserClass : String = "Class 1";

        port powerIn : PowerInPort;
        port dataOut : LidarDataOutPort;
        port obstacleOut : ObstacleOutPort;

        action scanEnvironment {
            out pointCloud : PointCloud;
        }

        action detectObstacles {
            in cloud : PointCloud;
            out obstacleList : ObstacleList;
        }

        action buildLocalMap {
            in cloud : PointCloud;
            out localMap : FusedMap;
        }
    }

    part def VisionSystem {
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute frameRate : FrequencyValue = 30.0;
        attribute fieldOfView : Real = 90.0;
        attribute encoding : String = "RGB";
        attribute lensType : String = "Wide-angle";

        port powerIn : PowerInPort;
        port dataOut : VisionDataOutPort;

        action captureImage {
            out image : ImageData;
        }

        action identifyObjects {
            in image : ImageData;
            out objectList : List of String;
        }

        action analyzeTerrain {
            in image : ImageData;
            out terrainType : String;
            out traversable : Boolean;
        }

        action trackObject {
            in image : ImageData;
            in targetObject : String;
            out position : String;
        }
    }

    part def ProcessingUnit {
        attribute clockSpeed : FrequencyValue = 2.0;
        attribute memoryGB : Real = 16.0;
        attribute currentMode : OperationalMode = OperationalMode::IDLE;
        attribute aiModel : String = "Deep reinforcement learning";
        attribute decisionRate : FrequencyValue = 20.0;

        port powerIn : PowerInPort;
        port lidarDataIn : LidarDataInPort;
        port visionDataIn : VisionDataInPort;
        port missionIn : MissionInPort;
        port teleopIn : TeleopCommandInPort;
        port navCommandOut : NavCommandOutPort;
        port armCommandOut : ArmCommandOutPort;
        port motionCommandOut : MotionCommandOutPort;
        port statusOut : StatusOutPort;

        action processMission {
            in mission : MissionPlan;
            out taskCommands : List of String;
        }

        action makeDecisions {
            in pointCloud : PointCloud;
            in image : ImageData;
            in mission : MissionPlan;
            out navCommand : NavigationCommand;
            out armCommand : ArmCommand;
            out motionCommand : MotionCommand;
        }

        action generateStatusReport {
            in batteryLevel : BatteryPercentage;
            in mode : OperationalMode;
            in speed : SpeedValue;
            in armStatus : String;
            out status : StatusReport;
        }

        action coordinateActions {
            in navCommand : NavigationCommand;
            in armCommand : ArmCommand;
            in motionCommand : MotionCommand;
            out coordinatedPlan : String;
        }

        action processTeleop {
            in cmd : TeleopCommand;
            out motionCommand : MotionCommand;
            out armCommand : ArmCommand;
        }

        action evaluateBatteryStatus {
            in batteryLevel : BatteryPercentage;
            out returnToCharge : Boolean;
        }
    }

    part def NavigationUnit {
        attribute pathPlanningAlgorithm : String = "A* with DWA";
        attribute mapResolution : DistanceValue = 0.05;
        attribute updateRate : FrequencyValue = 5.0;
        attribute localizationMethod : String = "AMCL";

        port powerIn : PowerInPort;
        port lidarDataIn : LidarDataInPort;
        port visionDataIn : VisionDataInPort;
        port commandIn : NavCommandInPort;
        port fusedDataOut : FusedDataOutPort;
        port pathOut : PathOutPort;
        port motionOut : MotionCommandOutPort;

        action fuseSensorData {
            in pointCloud : PointCloud;
            in image : ImageData;
            out fusedMap : FusedMap;
        }

        action planPath {
            in fusedMap : FusedMap;
            in destination : String;
            out path : PathPlan;
        }

        action generateMotionCommands {
            in path : PathPlan;
            out motionCmd : MotionCommand;
        }

        action avoidObstacles {
            in fusedMap : FusedMap;
            in currentPath : PathPlan;
            out revisedPath : PathPlan;
        }

        action localize {
            in fusedMap : FusedMap;
            out estimatedPosition : String;
            out confidence : Real;
        }

        action planPathToChargingStation {
            in fusedMap : FusedMap;
            in stationLocation : String;
            out path : PathPlan;
        }
    }

    part def BatteryPack {
        attribute nominalVoltage : VoltageValue = 48.0;
        attribute capacityAh : Real = 40.0;
        attribute currentLevel : BatteryPercentage = 100.0;
        attribute lowThreshold : BatteryPercentage = 20.0;
        attribute criticalThreshold : BatteryPercentage = 10.0;
        attribute isCharging : Boolean = false;
        attribute cellCount : Integer = 13;
        attribute chemistry : String = "LiFePO4";

        port powerOut : PowerOutPort;
        port chargingIn : ChargingInPort;
        port statusOut : StatusOutPort;

        action monitorLevel {
            out level : BatteryPercentage;
            out isLow : Boolean;
            out isCritical : Boolean;
        }

        action discharge {
            out power : PowerFlow;
            out remainingLevel : BatteryPercentage;
        }

        action charge {
            in externalPower : PowerFlow;
            out currentLevel : BatteryPercentage;
            out chargeComplete : Boolean;
        }

        action estimateTimeRemaining {
            out timeRemaining : DurationValue;
        }

        action balanceCells {
            out balanced : Boolean;
        }
    }

    part def ChargingStation {
        attribute outputVoltage : VoltageValue = 48.0;
        attribute maxChargeCurrent : CurrentValue = 10.0;
        attribute location : String = "Base station";
        attribute dockingMethod : String = "Automatic contact pad";

        port powerOut : PowerOutPort;

        action providePower {
            out power : PowerFlow;
        }

        action dockRobot {
            in robotId : String;
            out docked : Boolean;
        }

        action undockRobot {
            out undocked : Boolean;
        }
    }

    part def OperatorInterface {
        attribute displayType : String = "GUI dashboard";
        attribute connectionType : String = "Wireless 802.11";
        attribute maxRange : DistanceValue = 100.0;

        port missionOut : MissionOutPort;
        port statusIn : StatusInPort;
        port teleopCommandOut : TeleopCommandOutPort;

        action sendMission {
            out mission : MissionPlan;
        }

        action sendTeleopCommand {
            out cmd : TeleopCommand;
        }

        action displayStatus {
            in status : StatusReport;
        }

        action alertOperator {
            in alertType : String;
            in message : String;
        }

        action logTelemetry {
            in status : StatusReport;
        }
    }

    // ===== Action Definitions =====
    action def DoInitialize {
        out initialized : Boolean;
    }

    action def SetMode {
        in mode : OperationalMode;
    }

    action def SenseEnvironment {
        out pointCloud : PointCloud;
        out image : ImageData;
        out fusedMap : FusedMap;
    }

    action def PlanNextMove {
        in pointCloud : PointCloud;
        in image : ImageData;
        in fusedMap : FusedMap;
        in mission : MissionPlan;
        out path : PathPlan;
        out armCmd : ArmCommand;
        out motionCmd : MotionCommand;
    }

    action def ExecuteTasks {
        in path : PathPlan;
        in armCmd : ArmCommand;
        in motionCmd : MotionCommand;
        out completed : Boolean;
    }

    action def NavigateToChargingStation {
        in fusedMap : FusedMap;
        in stationLocation : String;
        out path : PathPlan;
        out arrived : Boolean;
    }

    action def DockAndCharge {
        in power : PowerFlow;
        out chargeComplete : Boolean;
    }

    action def ResumeMission {
        in mission : MissionPlan;
        out resumed : Boolean;
    }

    action def HandleFault {
        in faultType : String;
        out handled : Boolean;
        out requiresOperator : Boolean;
    }

    action def ProcessTeleopCommands {
        in cmd : TeleopCommand;
        out motionCmd : MotionCommand;
        out armCmd : ArmCommand;
    }

    action def CheckBatteryLevel {
        out level : BatteryPercentage;
        out returnToCharge : Boolean;
    }

    action def ReportStatus {
        in status : StatusReport;
    }

    // ===== State Machine Definition =====
    state def TerabotSStateMachine {
        entry; then Initializing;

        state Initializing {
            entry action doInitialize;
            transition initComplete
                first Initializing
                accept InitComplete
                then Idle;
        }

        state Idle {
            entry action setModeIdle;
            do action monitorBattery;

            transition missionReceived
                first Idle
                accept MissionReceived
                then AutonomousMode;

            transition teleopRequested
                first Idle
                accept TeleopRequested
                then TeleoperationMode;

            transition batteryLowIdle
                first Idle
                accept BatteryLow
                then ReturnToCharge;

            transition faultDetectedIdle
                first Idle
                accept FaultDetected
                then FaultState;
        }

        state AutonomousMode {
            entry action setModeAutonomous;

            state Sensing {
                entry action senseEnvironment;
            }

            state Planning {
                entry action planNextMove;
            }

            state Executing {
                entry action executeTasks;
            }

            transition startSensing
                first AutonomousMode
                accept MissionStarted
                then Sensing;

            transition senseToPlan
                first Sensing
                accept SensingComplete
                then Planning;

            transition planToExecute
                first Planning
                accept PlanningComplete
                then Executing;

            transition executeToSense
                first Executing
                accept ExecutionStepComplete
                then Sensing;

            transition batteryLowAuto
                first AutonomousMode
                accept BatteryLow
                then ReturnToCharge;

            transition missionComplete
                first AutonomousMode
                accept MissionComplete
                then Idle;

            transition teleopRequestedAuto
                first AutonomousMode
                accept TeleopRequested
                then TeleoperationMode;

            transition faultDetectedAuto
                first AutonomousMode
                accept FaultDetected
                then FaultState;
        }

        state TeleoperationMode {
            entry action setModeTeleoperation;
            do action processTeleopCommands;

            transition batteryLowTeleop
                first TeleoperationMode
                accept BatteryLow
                then ReturnToCharge;

            transition sessionEnded
                first TeleoperationMode
                accept SessionEnded
                then Idle;

            transition faultDetectedTeleop
                first TeleoperationMode
                accept FaultDetected
                then FaultState;
        }

        state ReturnToCharge {
            entry action setModeCharging;

            state NavigatingToStation {
                entry action navigateToChargingStation;
                do action monitorProgress;
            }

            state Docking {
                entry action dockRobot;
            }

            state Charging {
                entry action dockAndCharge;
                do action monitorCharging;
            }

            state Resuming {
                entry action resumeMission;
            }

            transition arrivedAtStation
                first NavigatingToStation
                accept ArrivedAtStation
                then Docking;

            transition docked
                first Docking
                accept Docked
                then Charging;

            transition chargeComplete
                first Charging
                accept ChargeComplete
                then Resuming;

            transition resumeComplete
                first Resuming
                accept ResumeComplete
                then AutonomousMode;

            transition resumeToIdle
                first Resuming
                accept NoMissionPending
                then Idle;
        }

        state FaultState {
            entry action handleFault;
            do action waitForRecovery;

            transition faultCleared
                first FaultState
                accept FaultCleared
                then Idle;

            transition faultCritical
                first FaultState
                accept FaultCritical
                then Shutdown;
        }

        state Shutdown {
            entry action safeShutdown;
        }
    }

    // ===== Main Robot Definition =====
    part def TerabotS {
        attribute name : String = "Terabot-S";
        attribute serialNumber : String;
        attribute currentMode : OperationalMode = OperationalMode::IDLE;
        attribute systemHealth : SystemHealth = SystemHealth::HEALTHY;
        attribute firmwareVersion : String = "2.1.0";

        port missionPort : MissionInPort;
        port statusPort : StatusOutPort;
        port teleopPort : TeleopCommandInPort;

        part mobilePlatform : MobilePlatform {
            attribute maxSpeed = 3.5;
        }

        part manipulatorArm : ManipulatorArm {
            attribute maxPayload = 8.0;
            attribute maxReach = 1.0;
            attribute jointCount = 6;
        }

        part lidarSensor : LidarSensor {
            attribute maxRange = 50.0;
        }

        part visionSystem : VisionSystem;

        part processingUnit : ProcessingUnit;

        part navigationUnit : NavigationUnit;

        part batteryPack : BatteryPack {
            attribute nominalVoltage = 48.0;
        }

        part chargingStation : ChargingStation;

        part operatorInterface : OperatorInterface;

        // Power distribution connections
        connection powerToPlatform connect batteryPack.powerOut to mobilePlatform.powerIn;
        connection powerToArm connect batteryPack.powerOut to manipulatorArm.powerIn;
        connection powerToLidar connect batteryPack.powerOut to lidarSensor.powerIn;
        connection powerToVision connect batteryPack.powerOut to visionSystem.powerIn;
        connection powerToProcessor connect batteryPack.powerOut to processingUnit.powerIn;
        connection powerToNav connect batteryPack.powerOut to navigationUnit.powerIn;

        // Sensor data connections to Processing Unit
        connection lidarToProcessor connect lidarSensor.dataOut to processingUnit.lidarDataIn;
        connection visionToProcessor connect visionSystem.dataOut to processingUnit.visionDataIn;

        // Sensor data connections to Navigation Unit
        connection lidarToNav connect lidarSensor.dataOut to navigationUnit.lidarDataIn;
        connection visionToNav connect visionSystem.dataOut to navigationUnit.visionDataIn;

        // Command connections from Processing Unit
        connection processorToNav connect processingUnit.navCommandOut to navigationUnit.commandIn;
        connection navMotionToPlatform connect navigationUnit.motionOut to mobilePlatform.motionCommandIn;
        connection processorMotionToPlatform connect processingUnit.motionCommandOut to mobilePlatform.motionCommandIn;
        connection processorToArm connect processingUnit.armCommandOut to manipulatorArm.armCommandIn;

        // Operator interface connections
        connection missionToProcessor connect operatorInterface.missionOut to processingUnit.missionIn;
        connection teleopToProcessor connect operatorInterface.teleopCommandOut to processingUnit.teleopIn;
        connection statusToOperator connect processingUnit.statusOut to operatorInterface.statusIn;
        connection platformStatusToProcessor connect mobilePlatform.statusOut to processingUnit.statusIn;

        // External connections
        connection missionExternal connect missionPort to processingUnit.missionIn;
        connection teleopExternal connect teleopPort to processingUnit.teleopIn;
        connection statusExternal connect processingUnit.statusOut to statusPort;

        // Charging station connection
        connection stationToBattery connect chargingStation.powerOut to batteryPack.chargingIn;

        // Battery status to Processing Unit
        connection batteryStatusToProcessor connect batteryPack.statusOut to processingUnit.statusIn;

        // Action usages
        action doInitialize : DoInitialize;
        action setModeIdle : SetMode { in mode = OperationalMode::IDLE; }
        action setModeAutonomous : SetMode { in mode = OperationalMode::AUTONOMOUS; }
        action setModeTeleoperation : SetMode { in mode = OperationalMode::TELEOPERATION; }
        action setModeCharging : SetMode { in mode = OperationalMode::CHARGING; }
        action senseEnvironment : SenseEnvironment;
        action planNextMove : PlanNextMove;
        action executeTasks : ExecuteTasks;
        action navigateToChargingStation : NavigateToChargingStation;
        action dockAndCharge : DockAndCharge;
        action resumeMission : ResumeMission;
        action handleFault : HandleFault;
        action processTeleopCommands : ProcessTeleopCommands;
        action monitorBattery : CheckBatteryLevel;
        action monitorProgress : PlanNextMove;
        action monitorCharging : CheckBatteryLevel;
        action waitForRecovery : DoInitialize;
        action safeShutdown : DoInitialize;
        action dockRobot : DoInitialize;
        action reportStatus : ReportStatus;

        // State machine
        exhibit TerabotSStateMachine;
    }
}
