package RoboticsPrimaryFunctionModel {

    import ScalarValues::*;
    import Occurrences::*;
    import Actions::*;
    import States::*;
    import Requirements::*;

    attribute def Length_m :> Real {
        doc /* Linear distance measured in meters. */
    }

    attribute def Angle_rad :> Real {
        doc /* Plane angle measured in radians. */
    }

    attribute def Time_s :> Real {
        doc /* Duration measured in seconds. */
    }

    attribute def Mass_kg :> Real {
        doc /* Mass measured in kilograms. */
    }

    attribute def Speed_mps :> Real {
        doc /* Translational speed measured in meters per second. */
    }

    attribute def AngularSpeed_radps :> Real {
        doc /* Angular speed measured in radians per second. */
    }

    attribute def Acceleration_mps2 :> Real {
        doc /* Translational acceleration measured in meters per second squared. */
    }

    attribute def Force_N :> Real {
        doc /* Force measured in newtons. */
    }

    attribute def Voltage_V :> Real {
        doc /* Electrical potential measured in volts. */
    }

    attribute def Current_A :> Real {
        doc /* Electrical current measured in amperes. */
    }

    attribute def Power_W :> Real {
        doc /* Power measured in watts. */
    }

    attribute def Energy_Wh :> Real {
        doc /* Stored electrical energy measured in watt-hours. */
    }

    attribute def DataRate_Mbps :> Real {
        doc /* Communication data rate measured in megabits per second. */
    }

    attribute def Probability_1 :> Real {
        doc /* Unitless probability value in the closed interval [0,1]. */
    }

    enum def RobotMode {
        enum idle;
        enum acceptingTask;
        enum perceiving;
        enum planning;
        enum navigating;
        enum manipulating;
        enum delivering;
        enum charging;
        enum safeStop;
        enum fault;
    }

    enum def TaskOutcome {
        enum accepted;
        enum rejected;
        enum inProgress;
        enum completed;
        enum failed;
        enum canceled;
    }

    enum def ObjectCategory {
        enum parcel;
        enum tray;
        enum tool;
        enum bottle;
        enum unknown;
    }

    enum def ObstacleClass {
        enum staticFurniture;
        enum human;
        enum pet;
        enum mobileRobot;
        enum unknownObstacle;
    }

    enum def HealthLevel {
        enum nominal;
        enum degraded;
        enum critical;
    }

    item def Pose2D {
        attribute x : Length_m;
        attribute y : Length_m;
        attribute heading : Angle_rad;
        attribute covariancePosition : Length_m;
        attribute covarianceHeading : Angle_rad;
    }

    item def Velocity2D {
        attribute linear : Speed_mps;
        attribute lateral : Speed_mps;
        attribute angular : AngularSpeed_radps;
    }

    item def NavigationGoal {
        attribute targetPose : Pose2D;
        attribute allowedPositionError : Length_m = 0.05;
        attribute allowedHeadingError : Angle_rad = 0.0872665;
        attribute maximumArrivalTime : Time_s;
    }

    item def ObjectDescriptor {
        attribute category : ObjectCategory;
        attribute estimatedMass : Mass_kg;
        attribute graspWidth : Length_m;
        attribute confidence : Probability_1;
        attribute objectPose : Pose2D;
    }

    item def ObstacleDescriptor {
        attribute obstacleClass : ObstacleClass;
        attribute obstaclePose : Pose2D;
        attribute radius : Length_m;
        attribute velocity : Velocity2D;
        attribute confidence : Probability_1;
    }

    item def SensorFrame {
        attribute timestamp : Time_s;
        attribute robotPoseEstimate : Pose2D;
        attribute detectionConfidence : Probability_1;
    }

    item def LocalMap {
        attribute mapTimestamp : Time_s;
        attribute origin : Pose2D;
        attribute width : Length_m;
        attribute height : Length_m;
        attribute resolution : Length_m;
        attribute obstacleCount : Integer;
    }

    item def TaskCommand {
        attribute commandId : String;
        attribute pickupLocation : Pose2D;
        attribute deliveryLocation : Pose2D;
        attribute requestedObject : ObjectCategory;
        attribute maximumPayloadMass : Mass_kg;
        attribute priority : Integer;
    }

    item def TaskStatus {
        attribute commandId : String;
        attribute outcome : TaskOutcome;
        attribute currentMode : RobotMode;
        attribute progressFraction : Probability_1;
        attribute message : String;
    }

    item def GraspPlan {
        attribute object : ObjectDescriptor;
        attribute approachPose : Pose2D;
        attribute gripperOpening : Length_m;
        attribute expectedGripForce : Force_N;
        attribute planConfidence : Probability_1;
    }

    item def MotionPlan {
        attribute startPose : Pose2D;
        attribute goalPose : Pose2D;
        attribute pathLength : Length_m;
        attribute nominalSpeed : Speed_mps;
        attribute expectedDuration : Time_s;
        attribute clearanceToObstacles : Length_m;
    }

    item def WheelCommand {
        attribute leftWheelSpeed : AngularSpeed_radps;
        attribute rightWheelSpeed : AngularSpeed_radps;
    }

    item def ArmJointCommand {
        attribute shoulderAngle : Angle_rad;
        attribute elbowAngle : Angle_rad;
        attribute wristAngle : Angle_rad;
        attribute gripperOpening : Length_m;
        attribute gripperForce : Force_N;
    }

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute current : Current_A;
        attribute power : Power_W;
    }

    item def BatteryState {
        attribute storedEnergy : Energy_Wh;
        attribute stateOfCharge : Probability_1;
        attribute busVoltage : Voltage_V;
        attribute dischargeCurrent : Current_A;
        attribute estimatedRuntime : Time_s;
    }

    item def HealthReport {
        attribute health : HealthLevel;
        attribute activeFaultCount : Integer;
        attribute batteryState : BatteryState;
        attribute localizationConfidence : Probability_1;
        attribute message : String;
    }

    item def WirelessMessage {
        attribute sourceId : String;
        attribute destinationId : String;
        attribute payloadBytes : Integer;
        attribute dataRate : DataRate_Mbps;
    }

    port def TaskCommandPort {
        in item command : TaskCommand;
        out item status : TaskStatus;
    }

    port def WirelessServicePort {
        in item inboundMessage : WirelessMessage;
        out item outboundMessage : WirelessMessage;
    }

    port def SensorDataPort {
        out item frame : SensorFrame;
        out item obstacle : ObstacleDescriptor;
        out item object : ObjectDescriptor;
    }

    port def MapPort {
        in item sensorFrame : SensorFrame;
        in item obstacle : ObstacleDescriptor;
        out item map : LocalMap;
        out item pose : Pose2D;
    }

    port def PlanningPort {
        in item task : TaskCommand;
        in item map : LocalMap;
        in item pose : Pose2D;
        out item navigationGoal : NavigationGoal;
        out item motionPlan : MotionPlan;
        out item graspPlan : GraspPlan;
    }

    port def DriveControlPort {
        in item wheelCommand : WheelCommand;
        out item odometryPose : Pose2D;
        out item odometryVelocity : Velocity2D;
    }

    port def ManipulatorControlPort {
        in item armCommand : ArmJointCommand;
        out item sensedObject : ObjectDescriptor;
        out item graspState : GraspPlan;
    }

    port def PowerOutputPort {
        out item electricalPower : ElectricalPower;
        out item batteryState : BatteryState;
    }

    port def PowerInputPort {
        in item electricalPower : ElectricalPower;
    }

    port def HealthPort {
        in item batteryState : BatteryState;
        in item pose : Pose2D;
        out item healthReport : HealthReport;
    }

    port def HumanInterfacePort {
        in item command : TaskCommand;
        out item status : TaskStatus;
        out item healthReport : HealthReport;
    }

    action def AcquireTask {
        in item operatorCommand : TaskCommand;
        out item acceptedTask : TaskCommand;
        out item taskStatus : TaskStatus;
    }

    action def PerceiveEnvironment {
        in item rawFrame : SensorFrame;
        out item detectedObstacle : ObstacleDescriptor;
        out item detectedObject : ObjectDescriptor;
    }

    action def BuildLocalMap {
        in item frame : SensorFrame;
        in item obstacle : ObstacleDescriptor;
        out item map : LocalMap;
        out item estimatedPose : Pose2D;
    }

    action def PlanTask {
        in item task : TaskCommand;
        in item map : LocalMap;
        in item pose : Pose2D;
        out item goal : NavigationGoal;
        out item motionPlan : MotionPlan;
        out item graspPlan : GraspPlan;
    }

    action def NavigateToGoal {
        in item motionPlan : MotionPlan;
        in item currentPose : Pose2D;
        out item wheelCommand : WheelCommand;
        out item navigationStatus : TaskStatus;

        attribute maximumSpeed : Speed_mps = 1.2;
        attribute maximumAcceleration : Acceleration_mps2 = 0.8;
        attribute minimumObstacleClearance : Length_m = 0.30;
    }

    action def ExecuteGrasp {
        in item graspPlan : GraspPlan;
        out item armCommand : ArmJointCommand;
        out item graspStatus : TaskStatus;

        attribute maximumPayload : Mass_kg = 5.0;
        attribute nominalGripForce : Force_N = 35.0;
    }

    action def DeliverObject {
        in item task : TaskCommand;
        in item currentPose : Pose2D;
        out item deliveryStatus : TaskStatus;
    }

    action def MonitorRobotHealth {
        in item batteryState : BatteryState;
        in item pose : Pose2D;
        out item healthReport : HealthReport;
    }

    state def AutonomousServiceRobotStates {
        entry action initializeRobot;

        state initial;
        state Idle;
        state TaskAcceptance;
        state EnvironmentPerception;
        state TaskPlanning;
        state NavigationToPickup;
        state ObjectManipulation;
        state NavigationToDelivery;
        state DeliveryCompletion;
        state ReturnToCharge;
        state SafeStop;
        state FaultManagement;
        state final;

        transition initial then Idle;

        transition Idle then TaskAcceptance
            accept TaskCommand
            if true;

        transition TaskAcceptance then EnvironmentPerception
            if true;

        transition EnvironmentPerception then TaskPlanning
            if true;

        transition TaskPlanning then NavigationToPickup
            if true;

        transition NavigationToPickup then ObjectManipulation
            if true;

        transition ObjectManipulation then NavigationToDelivery
            if true;

        transition NavigationToDelivery then DeliveryCompletion
            if true;

        transition DeliveryCompletion then Idle
            if true;

        transition Idle then ReturnToCharge
            if true;

        transition ReturnToCharge then Idle
            if true;

        transition Idle then SafeStop
            accept HealthReport
            if true;

        transition TaskAcceptance then SafeStop
            accept HealthReport
            if true;

        transition EnvironmentPerception then SafeStop
            accept HealthReport
            if true;

        transition TaskPlanning then SafeStop
            accept HealthReport
            if true;

        transition NavigationToPickup then SafeStop
            accept HealthReport
            if true;

        transition ObjectManipulation then SafeStop
            accept HealthReport
            if true;

        transition NavigationToDelivery then SafeStop
            accept HealthReport
            if true;

        transition SafeStop then FaultManagement
            if true;

        transition FaultManagement then Idle
            if true;

        transition FaultManagement then final
            if true;
    }

    part def RGBDCamera {
        attribute horizontalFieldOfView : Angle_rad = 1.5708;
        attribute rangeMinimum : Length_m = 0.20;
        attribute rangeMaximum : Length_m = 8.00;
        attribute frameRate : Real = 30.0;

        port sensorOut : SensorDataPort;
        port powerIn : PowerInputPort;
    }

    part def LidarScanner {
        attribute scanAngle : Angle_rad = 6.28318;
        attribute rangeMinimum : Length_m = 0.05;
        attribute rangeMaximum : Length_m = 20.0;
        attribute scanRate : Real = 10.0;

        port sensorOut : SensorDataPort;
        port powerIn : PowerInputPort;
    }

    part def InertialMeasurementUnit {
        attribute updateRate : Real = 200.0;
        attribute headingNoise : Angle_rad = 0.01;

        port sensorOut : SensorDataPort;
        port powerIn : PowerInputPort;
    }

    part def PerceptionSubsystem {
        part camera : RGBDCamera;
        part lidar : LidarScanner;
        part imu : InertialMeasurementUnit;

        port perceptionOut : SensorDataPort;
        port powerIn : PowerInputPort;

        action perceive : PerceiveEnvironment;

        bind camera.sensorOut.frame = perceptionOut.frame;
        bind lidar.sensorOut.obstacle = perceptionOut.obstacle;
        bind camera.sensorOut.object = perceptionOut.object;
    }

    part def LocalizationAndMappingSubsystem {
        attribute nominalMapResolution : Length_m = 0.05;
        attribute maximumMapWidth : Length_m = 50.0;
        attribute maximumMapHeight : Length_m = 50.0;
        attribute minimumLocalizationConfidence : Probability_1 = 0.85;

        port mapPort : MapPort;
        port powerIn : PowerInputPort;

        action buildMap : BuildLocalMap;
    }

    part def TaskPlannerSubsystem {
        attribute nominalPlanningHorizon : Time_s = 20.0;
        attribute minimumObstacleClearance : Length_m = 0.30;
        attribute maximumPathLength : Length_m = 200.0;

        port planningPort : PlanningPort;
        port powerIn : PowerInputPort;

        action plan : PlanTask;
    }

    part def DifferentialDriveBase {
        attribute trackWidth : Length_m = 0.52;
        attribute wheelRadius : Length_m = 0.10;
        attribute maximumLinearSpeed : Speed_mps = 1.2;
        attribute maximumAngularSpeed : AngularSpeed_radps = 2.0;
        attribute maximumAcceleration : Acceleration_mps2 = 0.8;

        port drivePort : DriveControlPort;
        port powerIn : PowerInputPort;
    }

    part def ManipulatorArm {
        attribute degreesOfFreedom : Integer = 4;
        attribute reach : Length_m = 0.75;
        attribute payloadCapacity : Mass_kg = 5.0;
        attribute maximumGripForce : Force_N = 60.0;
        attribute minimumGripperOpening : Length_m = 0.00;
        attribute maximumGripperOpening : Length_m = 0.12;

        port manipulatorPort : ManipulatorControlPort;
        port powerIn : PowerInputPort;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage_V = 48.0;
        attribute capacity : Energy_Wh = 1200.0;
        attribute maximumContinuousPower : Power_W = 900.0;
        attribute lowChargeThreshold : Probability_1 = 0.20;
        attribute criticalChargeThreshold : Probability_1 = 0.08;

        port powerOut : PowerOutputPort;
    }

    part def PowerDistributionUnit {
        attribute busVoltage : Voltage_V = 48.0;
        attribute maximumOutputPower : Power_W = 850.0;
        attribute conversionEfficiency : Probability_1 = 0.94;

        port batteryInput : PowerInputPort;
        port sensorsOutput : PowerOutputPort;
        port computeOutput : PowerOutputPort;
        port driveOutput : PowerOutputPort;
        port manipulatorOutput : PowerOutputPort;
    }

    part def RobotControllerComputer {
        attribute processorPower : Power_W = 65.0;
        attribute controlLoopPeriod : Time_s = 0.02;
        attribute wirelessDataRate : DataRate_Mbps = 50.0;

        port taskPort : TaskCommandPort;
        port wirelessPort : WirelessServicePort;
        port healthPort : HealthPort;
        port powerIn : PowerInputPort;
    }

    part def OperatorInterface {
        attribute displayRefreshPeriod : Time_s = 0.10;
        attribute maximumCommandLatency : Time_s = 0.50;

        port userPort : HumanInterfacePort;
        port wirelessPort : WirelessServicePort;
    }

    part def HealthManagementSubsystem {
        attribute minimumBatteryStateOfCharge : Probability_1 = 0.20;
        attribute minimumLocalizationConfidence : Probability_1 = 0.85;
        attribute maximumAllowedFaults : Integer = 0;

        port healthPort : HealthPort;
        port powerIn : PowerInputPort;

        action monitor : MonitorRobotHealth;
    }

    part def AutonomousServiceRobot {
        doc /* Primary high-level function: autonomously receive a service task, perceive an indoor environment, plan a safe route, navigate to an object, grasp it, transport it, deliver it to the requested destination, and report task status to a human operator. */

        attribute robotIdentifier : String = "ASR-01";
        attribute nominalRobotMass : Mass_kg = 72.0;
        attribute maximumPayloadMass : Mass_kg = 5.0;
        attribute maximumOperatingSpeed : Speed_mps = 1.2;
        attribute minimumObstacleClearance : Length_m = 0.30;
        attribute nominalRuntime : Time_s = 14400.0;
        attribute currentMode : RobotMode = RobotMode::idle;

        part perception : PerceptionSubsystem;
        part mapping : LocalizationAndMappingSubsystem;
        part planner : TaskPlannerSubsystem;
        part driveBase : DifferentialDriveBase;
        part manipulator : ManipulatorArm;
        part battery : BatteryPack;
        part powerDistribution : PowerDistributionUnit;
        part controller : RobotControllerComputer;
        part healthManager : HealthManagementSubsystem;

        port taskInterface : TaskCommandPort;
        port operatorInterface : WirelessServicePort;
        port healthInterface : HealthPort;

        action acquireTask : AcquireTask;
        action perceiveEnvironment : PerceiveEnvironment;
        action buildLocalMap : BuildLocalMap;
        action planTask : PlanTask;
        action navigateToPickup : NavigateToGoal;
        action graspObject : ExecuteGrasp;
        action navigateToDelivery : NavigateToGoal;
        action deliverObject : DeliverObject;
        action monitorHealth : MonitorRobotHealth;

        state machine operationalStates : AutonomousServiceRobotStates;

        connection commandConnection
            connect taskInterface to controller.taskPort;

        connection operatorWirelessConnection
            connect operatorInterface to controller.wirelessPort;

        connection perceptionToMapping
            connect perception.perceptionOut to mapping.mapPort;

        connection mappingToPlanner
            connect mapping.mapPort to planner.planningPort;

        connection controllerToPlanner
            connect controller.taskPort to planner.planningPort;

        connection plannerToDrive
            connect planner.planningPort to driveBase.drivePort;

        connection plannerToManipulator
            connect planner.planningPort to manipulator.manipulatorPort;

        connection driveOdometryToMapping
            connect driveBase.drivePort to mapping.mapPort;

        connection batteryToPowerDistribution
            connect battery.powerOut to powerDistribution.batteryInput;

        connection powerToPerception
            connect powerDistribution.sensorsOutput to perception.powerIn;

        connection powerToMapping
            connect powerDistribution.computeOutput to mapping.powerIn;

        connection powerToPlanner
            connect powerDistribution.computeOutput to planner.powerIn;

        connection powerToController
            connect powerDistribution.computeOutput to controller.powerIn;

        connection powerToDriveBase
            connect powerDistribution.driveOutput to driveBase.powerIn;

        connection powerToManipulator
            connect powerDistribution.manipulatorOutput to manipulator.powerIn;

        connection powerToHealthManager
            connect powerDistribution.computeOutput to healthManager.powerIn;

        connection batteryStateToHealth
            connect battery.powerOut to healthManager.healthPort;

        connection localizationHealth
            connect mapping.mapPort to healthManager.healthPort;

        connection robotHealthExternal
            connect healthManager.healthPort to healthInterface;

        connection controllerHealth
            connect healthManager.healthPort to controller.healthPort;
    }

    part def RoboticsServiceSystem {
        doc /* System context for one autonomous service robot and its operator interface. */

        part robot : AutonomousServiceRobot;
        part operatorConsole : OperatorInterface;

        connection operatorCommandLink
            connect operatorConsole.wirelessPort to robot.operatorInterface;

        connection directTaskLink
            connect operatorConsole.userPort to robot.taskInterface;

        connection robotHealthLink
            connect operatorConsole.userPort to robot.healthInterface;
    }

    requirement def PrimaryFunctionRequirement {
        subject robot : AutonomousServiceRobot;

        require constraint {
            robot.maximumPayloadMass >= 5.0 and
            robot.maximumOperatingSpeed <= 1.2 and
            robot.minimumObstacleClearance >= 0.30
        }

        doc /* The robot shall autonomously perform indoor pickup-and-delivery tasks by accepting a task command, perceiving the environment, planning motion, navigating safely, manipulating the requested object, delivering it, and reporting completion status. */
    }

    requirement def SafeNavigationRequirement {
        subject robot : AutonomousServiceRobot;

        require constraint {
            robot.minimumObstacleClearance >= 0.30 and
            robot.maximumOperatingSpeed <= 1.2
        }

        doc /* The robot shall maintain at least 0.30 m clearance from detected obstacles during nominal navigation and shall limit indoor operating speed to 1.2 m/s or less. */
    }

    requirement def PayloadRequirement {
        subject robot : AutonomousServiceRobot;

        require constraint {
            robot.maximumPayloadMass >= 5.0
        }

        doc /* The manipulator and mobile base shall support transport and delivery of objects with mass up to 5 kg. */
    }

    requirement def RuntimeRequirement {
        subject robot : AutonomousServiceRobot;

        require constraint {
            robot.nominalRuntime >= 14400.0
        }

        doc /* The robot shall support at least 4 hours of nominal autonomous service operation on one battery charge. */
    }

    requirement def HealthReportingRequirement {
        subject robot : AutonomousServiceRobot;

        require constraint {
            robot.currentMode != RobotMode::fault
        }

        doc /* The robot shall monitor battery, localization confidence, and active faults and shall report health status to the operator interface during operation. */
    }

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject robot = RoboticsServiceSystem::robot;
    }

    requirement safeNavigation : SafeNavigationRequirement {
        subject robot = RoboticsServiceSystem::robot;
    }

    requirement payloadCapability : PayloadRequirement {
        subject robot = RoboticsServiceSystem::robot;
    }

    requirement runtimeCapability : RuntimeRequirement {
        subject robot = RoboticsServiceSystem::robot;
    }

    requirement healthReporting : HealthReportingRequirement {
        subject robot = RoboticsServiceSystem::robot;
    }

}
