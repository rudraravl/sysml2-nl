package AutonomousRoboticPrimaryTaskModel {

    import ScalarValues::*;
    import NumericalFunctions::*;

    enum def RobotMode {
        enum poweredOff;
        enum booting;
        enum idle;
        enum missionPlanning;
        enum navigatingToPickup;
        enum acquiringPayload;
        enum transportingPayload;
        enum deliveringPayload;
        enum returningToDock;
        enum charging;
        enum fault;
        enum emergencyStop;
    }

    enum def MissionPhase {
        enum received;
        enum validated;
        enum planned;
        enum executing;
        enum completed;
        enum aborted;
    }

    enum def FaultSeverity {
        enum advisory;
        enum degraded;
        enum critical;
        enum unrecoverable;
    }

    enum def GripperState {
        enum open;
        enum closing;
        enum closed;
        enum holding;
        enum releasing;
    }

    attribute def Meter {
        attribute value : Real;
        attribute unit : String = "m";
    }

    attribute def SquareMeter {
        attribute value : Real;
        attribute unit : String = "m^2";
    }

    attribute def MeterPerSecond {
        attribute value : Real;
        attribute unit : String = "m/s";
    }

    attribute def MeterPerSecondSquared {
        attribute value : Real;
        attribute unit : String = "m/s^2";
    }

    attribute def Degree {
        attribute value : Real;
        attribute unit : String = "deg";
    }

    attribute def Second {
        attribute value : Real;
        attribute unit : String = "s";
    }

    attribute def Kilogram {
        attribute value : Real;
        attribute unit : String = "kg";
    }

    attribute def Newton {
        attribute value : Real;
        attribute unit : String = "N";
    }

    attribute def Volt {
        attribute value : Real;
        attribute unit : String = "V";
    }

    attribute def Ampere {
        attribute value : Real;
        attribute unit : String = "A";
    }

    attribute def Watt {
        attribute value : Real;
        attribute unit : String = "W";
    }

    attribute def WattHour {
        attribute value : Real;
        attribute unit : String = "Wh";
    }

    attribute def Percent {
        attribute value : Real;
        attribute unit : String = "%";
    }

    attribute def Hertz {
        attribute value : Real;
        attribute unit : "Hz";
    }

    attribute def Millisecond {
        attribute value : Real;
        attribute unit : String = "ms";
    }

    attribute def Pose2D {
        attribute x : Meter;
        attribute y : Meter;
        attribute heading : Degree;
    }

    attribute def Velocity2D {
        attribute linear : MeterPerSecond;
        attribute angular : Degree;
    }

    attribute def AccelerationLimit {
        attribute maxLinearAcceleration : MeterPerSecondSquared;
        attribute maxAngularAcceleration : Degree;
    }

    attribute def Geofence {
        attribute minX : Meter;
        attribute maxX : Meter;
        attribute minY : Meter;
        attribute maxY : Meter;
        attribute permittedArea : SquareMeter;
    }

    item def MissionPlan {
        attribute missionId : String;
        attribute phase : MissionPhase;
        attribute pickupPose : Pose2D;
        attribute deliveryPose : Pose2D;
        attribute geofence : Geofence;
        attribute maximumMissionTime : Second;
        attribute requiredPayloadMass : Kilogram;
        attribute requiredDeliveryAccuracy : Meter;
    }

    item def Waypoint {
        attribute sequenceNumber : Integer;
        attribute targetPose : Pose2D;
        attribute maximumSpeed : MeterPerSecond;
        attribute stopRequired : Boolean;
    }

    item def PathPlan {
        attribute planId : String;
        attribute estimatedTravelDistance : Meter;
        attribute estimatedTravelTime : Second;
        attribute clearanceMargin : Meter;
        item waypoint[1..*] : Waypoint;
    }

    item def VelocityCommand {
        attribute desiredLinearVelocity : MeterPerSecond;
        attribute desiredAngularVelocity : Degree;
        attribute commandAge : Millisecond;
    }

    item def WheelTorqueCommand {
        attribute leftWheelTorque : Newton;
        attribute rightWheelTorque : Newton;
    }

    item def SensorFrame {
        attribute frameId : String;
        attribute timeSinceCapture : Millisecond;
        attribute fieldOfView : Degree;
        attribute rangeMinimum : Meter;
        attribute rangeMaximum : Meter;
    }

    item def ObstacleDetection {
        attribute obstacleId : String;
        attribute obstaclePose : Pose2D;
        attribute obstacleRadius : Meter;
        attribute relativeSpeed : MeterPerSecond;
        attribute confidence : Percent;
    }

    item def LocalMap {
        attribute mapId : String;
        attribute resolution : Meter;
        attribute occupiedCellCount : Integer;
        attribute updateRate : Hertz;
        item obstacle[0..*] : ObstacleDetection;
    }

    item def RobotStatus {
        attribute robotId : String;
        attribute mode : RobotMode;
        attribute currentPose : Pose2D;
        attribute batteryStateOfCharge : Percent;
        attribute payloadSecured : Boolean;
        attribute activeFaultCount : Integer;
        attribute autonomyAvailable : Boolean;
    }

    item def FaultReport {
        attribute faultCode : String;
        attribute severity : FaultSeverity;
        attribute description : String;
        attribute detectedAtPose : Pose2D;
        attribute recoveryAttempted : Boolean;
    }

    item def EmergencyStopSignal {
        attribute asserted : Boolean;
        attribute source : String;
        attribute latency : Millisecond;
    }

    item def Payload {
        attribute payloadId : String;
        attribute mass : Kilogram;
        attribute length : Meter;
        attribute width : Meter;
        attribute height : Meter;
        attribute fragile : Boolean;
    }

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute power : Watt;
    }

    item def BatteryEnergy {
        attribute capacity : WattHour;
        attribute remainingEnergy : WattHour;
        attribute stateOfCharge : Percent;
        attribute temperature : Degree;
    }

    item def ChargingPower {
        attribute dockVoltage : Volt;
        attribute dockCurrent : Ampere;
        attribute chargePower : Watt;
    }

    port def MissionCommandPort {
        in item mission : MissionPlan;
        in item emergencyStop : EmergencyStopSignal;
        out item status : RobotStatus;
        out item fault : FaultReport;
    }

    port def TelemetryPort {
        out item status : RobotStatus;
        out item map : LocalMap;
        out item fault : FaultReport;
    }

    port def SensorDataPort {
        out item frame : SensorFrame;
        out item detection : ObstacleDetection;
    }

    port def MapPort {
        in item detection : ObstacleDetection;
        out item localMap : LocalMap;
    }

    port def NavigationPort {
        in item mission : MissionPlan;
        in item localMap : LocalMap;
        out item path : PathPlan;
        out item velocityCommand : VelocityCommand;
    }

    port def MotionCommandPort {
        in item velocityCommand : VelocityCommand;
        out item wheelTorqueCommand : WheelTorqueCommand;
    }

    port def DrivePowerPort {
        in item electricalPower : ElectricalPower;
        in item wheelTorqueCommand : WheelTorqueCommand;
    }

    port def PayloadInterfacePort {
        inout item payload : Payload;
    }

    port def GripperControlPort {
        in item payload : Payload;
        out item payloadSecuredStatus : RobotStatus;
    }

    port def BatteryPowerPort {
        out item electricalPower : ElectricalPower;
        out item batteryEnergy : BatteryEnergy;
    }

    port def ChargingPort {
        in item chargingPower : ChargingPower;
        out item batteryEnergy : BatteryEnergy;
    }

    port def SafetyPort {
        in item emergencyStop : EmergencyStopSignal;
        in item localMap : LocalMap;
        in item status : RobotStatus;
        out item safeVelocityCommand : VelocityCommand;
        out item fault : FaultReport;
    }

    port def DockingPort {
        in item status : RobotStatus;
        out item chargingPower : ChargingPower;
    }

    action def ValidateMission {
        in item mission : MissionPlan;
        out valid : Boolean;
        out item rejectedFault : FaultReport;
    }

    action def BuildLocalMap {
        in item frame : SensorFrame;
        in item detection : ObstacleDetection;
        out item localMap : LocalMap;
    }

    action def PlanCollisionFreePath {
        in item mission : MissionPlan;
        in item localMap : LocalMap;
        out item path : PathPlan;
    }

    action def NavigateAlongPath {
        in item path : PathPlan;
        in item localMap : LocalMap;
        out item velocityCommand : VelocityCommand;
    }

    action def EnforceSafetyLimits {
        in item commandedVelocity : VelocityCommand;
        in item localMap : LocalMap;
        in item emergencyStop : EmergencyStopSignal;
        out item safeVelocity : VelocityCommand;
        out item fault : FaultReport;
    }

    action def DriveRobot {
        in item safeVelocity : VelocityCommand;
        out item wheelTorque : WheelTorqueCommand;
    }

    action def AcquirePayload {
        in item payload : Payload;
        in item pickupPose : Pose2D;
        out secured : Boolean;
    }

    action def DeliverPayload {
        in item payload : Payload;
        in item deliveryPose : Pose2D;
        out delivered : Boolean;
    }

    action def ReturnToChargingDock {
        in item currentStatus : RobotStatus;
        out docked : Boolean;
    }

    action def ChargeBattery {
        in item chargingPower : ChargingPower;
        out item batteryEnergy : BatteryEnergy;
    }

    action def ExecuteAutonomousPrimaryTask {
        in item mission : MissionPlan;
        in item payload : Payload;
        in item emergencyStop : EmergencyStopSignal;
        out item finalStatus : RobotStatus;
        out completed : Boolean;

        action validate : ValidateMission {
            in mission = mission;
        }

        action mapWorld : BuildLocalMap;

        action planPathToPickup : PlanCollisionFreePath {
            in mission = mission;
        }

        action navigateToPickup : NavigateAlongPath;

        action acquire : AcquirePayload {
            in payload = payload;
            in pickupPose = mission.pickupPose;
        }

        action planPathToDelivery : PlanCollisionFreePath {
            in mission = mission;
        }

        action navigateToDelivery : NavigateAlongPath;

        action deliver : DeliverPayload {
            in payload = payload;
            in deliveryPose = mission.deliveryPose;
        }

        action returnToDock : ReturnToChargingDock;
    }

    state def AutonomousRobotOperatingStates {
        attribute mode : RobotMode;

        state poweredOff;
        state booting;
        state idle;
        state missionPlanning;
        state navigatingToPickup;
        state acquiringPayload;
        state transportingPayload;
        state deliveringPayload;
        state returningToDock;
        state charging;
        state fault;
        state emergencyStop;

        transition powerOn first poweredOff then booting;
        transition bootComplete first booting then idle;

        transition missionAccepted first idle then missionPlanning;
        transition planReady first missionPlanning then navigatingToPickup;
        transition arrivedAtPickup first navigatingToPickup then acquiringPayload;
        transition payloadSecured first acquiringPayload then transportingPayload;
        transition arrivedAtDelivery first transportingPayload then deliveringPayload;
        transition payloadReleased first deliveringPayload then returningToDock;
        transition dockReached first returningToDock then charging;
        transition sufficientlyCharged first charging then idle;

        transition recoverableFaultFromPlanning first missionPlanning then fault;
        transition recoverableFaultFromNavigation first navigatingToPickup then fault;
        transition recoverableFaultFromTransport first transportingPayload then fault;
        transition faultCleared first fault then idle;

        transition emergencyFromIdle first idle then emergencyStop;
        transition emergencyFromPlanning first missionPlanning then emergencyStop;
        transition emergencyFromPickupNavigation first navigatingToPickup then emergencyStop;
        transition emergencyFromAcquisition first acquiringPayload then emergencyStop;
        transition emergencyFromTransport first transportingPayload then emergencyStop;
        transition emergencyFromDelivery first deliveringPayload then emergencyStop;
        transition emergencyReset first emergencyStop then idle;
    }

    part def LidarSensor {
        attribute horizontalFieldOfView : Degree = 270.0 [unit = "deg"];
        attribute maximumRange : Meter = 30.0 [unit = "m"];
        attribute minimumRange : Meter = 0.15 [unit = "m"];
        attribute scanRate : Hertz = 20.0 [unit = "Hz"];
        port dataOut : SensorDataPort;
    }

    part def StereoCamera {
        attribute horizontalFieldOfView : Degree = 90.0 [unit = "deg"];
        attribute maximumRange : Meter = 12.0 [unit = "m"];
        attribute frameRate : Hertz = 30.0 [unit = "Hz"];
        port dataOut : SensorDataPort;
    }

    part def UltrasonicRing {
        attribute sensorCount : Integer = 12;
        attribute maximumRange : Meter = 4.0 [unit = "m"];
        attribute updateRate : Hertz = 25.0 [unit = "Hz"];
        port dataOut : SensorDataPort;
    }

    part def PerceptionSubsystem {
        part lidar : LidarSensor;
        part stereoCamera : StereoCamera;
        part ultrasonicRing : UltrasonicRing;
        port mapPort : MapPort;

        perform action buildMap : BuildLocalMap;

        connection lidarToMap connect lidar.dataOut to mapPort;
        connection cameraToMap connect stereoCamera.dataOut to mapPort;
        connection ultrasonicToMap connect ultrasonicRing.dataOut to mapPort;
    }

    part def NavigationComputer {
        attribute localizationAccuracy : Meter = 0.05 [unit = "m"];
        attribute replanningPeriod : Second = 0.25 [unit = "s"];
        attribute maximumPlannedSpeed : MeterPerSecond = 1.5 [unit = "m/s"];
        attribute minimumObstacleClearance : Meter = 0.50 [unit = "m"];
        port navigationPort : NavigationPort;

        perform action planPath : PlanCollisionFreePath;
        perform action navigate : NavigateAlongPath;
    }

    part def SafetyController {
        attribute maximumSafeSpeed : MeterPerSecond = 1.2 [unit = "m/s"];
        attribute emergencyStopLatency : Millisecond = 100.0 [unit = "ms"];
        attribute minimumStoppingDistance : Meter = 0.35 [unit = "m"];
        attribute obstacleHardStopDistance : Meter = 0.30 [unit = "m"];
        port safetyPort : SafetyPort;

        perform action enforceSafety : EnforceSafetyLimits;
    }

    part def MotionController {
        attribute controlLoopRate : Hertz = 100.0 [unit = "Hz"];
        attribute maximumLinearAcceleration : MeterPerSecondSquared = 0.8 [unit = "m/s^2"];
        attribute maximumAngularRate : Degree = 90.0 [unit = "deg/s"];
        port commandIn : MotionCommandPort;

        perform action drive : DriveRobot;
    }

    part def DifferentialDriveBase {
        attribute wheelRadius : Meter = 0.125 [unit = "m"];
        attribute trackWidth : Meter = 0.52 [unit = "m"];
        attribute maximumSpeed : MeterPerSecond = 1.5 [unit = "m/s"];
        attribute maximumClimbGrade : Degree = 8.0 [unit = "deg"];
        port drivePower : DrivePowerPort;
    }

    part def ManipulatorArm {
        attribute reach : Meter = 0.65 [unit = "m"];
        attribute liftCapacity : Kilogram = 5.0 [unit = "kg"];
        attribute positioningAccuracy : Meter = 0.02 [unit = "m"];
        port payloadInterface : PayloadInterfacePort;
    }

    part def Gripper {
        attribute maximumGripForce : Newton = 120.0 [unit = "N"];
        attribute jawOpening : Meter = 0.18 [unit = "m"];
        attribute state : GripperState = GripperState::open;
        port control : GripperControlPort;
        port payloadInterface : PayloadInterfacePort;
    }

    part def PayloadHandlingSubsystem {
        part manipulator : ManipulatorArm;
        part gripper : Gripper;
        port payloadInterface : PayloadInterfacePort;
        port gripperControl : GripperControlPort;

        perform action acquirePayload : AcquirePayload;
        perform action deliverPayload : DeliverPayload;

        connection manipulatorToPayload connect manipulator.payloadInterface to payloadInterface;
        connection gripperToPayload connect gripper.payloadInterface to payloadInterface;
        connection gripperControlLink connect gripper.control to gripperControl;
    }

    part def BatteryPack {
        attribute nominalVoltage : Volt = 48.0 [unit = "V"];
        attribute capacity : WattHour = 1200.0 [unit = "Wh"];
        attribute minimumOperatingStateOfCharge : Percent = 15.0 [unit = "%"];
        attribute stateOfCharge : Percent = 80.0 [unit = "%"];
        port powerOut : BatteryPowerPort;
        port chargingIn : ChargingPort;
    }

    part def PowerDistributionUnit {
        attribute maximumContinuousPower : Watt = 900.0 [unit = "W"];
        attribute peakPower : Watt = 1500.0 [unit = "W"];
        port batteryIn : BatteryPowerPort;
        port drivePowerOut : DrivePowerPort;
    }

    part def PowerSubsystem {
        part battery : BatteryPack;
        part pdu : PowerDistributionUnit;
        port powerOut : BatteryPowerPort;
        port chargingPort : ChargingPort;
        port drivePowerOut : DrivePowerPort;

        connection batteryToPdu connect battery.powerOut to pdu.batteryIn;
        connection pduToDrive connect pdu.drivePowerOut to drivePowerOut;
        connection externalCharging connect chargingPort to battery.chargingIn;
        connection systemPower connect battery.powerOut to powerOut;
    }

    part def CommunicationModule {
        attribute telemetryRate : Hertz = 5.0 [unit = "Hz"];
        attribute maximumCommandLatency : Millisecond = 250.0 [unit = "ms"];
        attribute commandRange : Meter = 100.0 [unit = "m"];
        port missionPort : MissionCommandPort;
        port telemetryPort : TelemetryPort;
    }

    part def AutonomousRobot {
        attribute robotId : String = "AR-PRIMARY-001";
        attribute nominalMass : Kilogram = 72.0 [unit = "kg"];
        attribute maximumPayloadMass : Kilogram = 5.0 [unit = "kg"];
        attribute maximumSpeed : MeterPerSecond = 1.5 [unit = "m/s"];
        attribute operatingEndurance : Second = 14400.0 [unit = "s"];
        attribute currentMode : RobotMode = RobotMode::poweredOff;
        attribute autonomyLevel : Integer = 4;

        part perception : PerceptionSubsystem;
        part navigationComputer : NavigationComputer;
        part safetyController : SafetyController;
        part motionController : MotionController;
        part driveBase : DifferentialDriveBase;
        part payloadHandling : PayloadHandlingSubsystem;
        part powerSubsystem : PowerSubsystem;
        part communication : CommunicationModule;

        port commandIn : MissionCommandPort;
        port telemetryOut : TelemetryPort;
        port payloadPort : PayloadInterfacePort;
        port chargingPort : ChargingPort;

        perform action primaryTask : ExecuteAutonomousPrimaryTask;
        exhibit state lifecycle : AutonomousRobotOperatingStates;

        connection externalCommandToCommunication connect commandIn to communication.missionPort;
        connection telemetryToExternal connect communication.telemetryPort to telemetryOut;
        connection perceptionMapToNavigation connect perception.mapPort to navigationComputer.navigationPort;
        connection navigationToSafety connect navigationComputer.navigationPort to safetyController.safetyPort;
        connection commandToSafety connect communication.missionPort to safetyController.safetyPort;
        connection safetyToMotion connect safetyController.safetyPort to motionController.commandIn;
        connection motionToDrive connect motionController.commandIn to driveBase.drivePower;
        connection powerToDrive connect powerSubsystem.drivePowerOut to driveBase.drivePower;
        connection payloadExternalInterface connect payloadPort to payloadHandling.payloadInterface;
        connection payloadHandlingStatusToSafety connect payloadHandling.gripperControl to safetyController.safetyPort;
        connection chargingInterface connect chargingPort to powerSubsystem.chargingPort;
    }

    part def MissionControlStation {
        attribute operatorOverrideAvailable : Boolean = true;
        attribute missionUploadLatency : Millisecond = 200.0 [unit = "ms"];
        attribute requiredTelemetryRefresh : Hertz = 2.0 [unit = "Hz"];
        port commandOut : MissionCommandPort;
        port telemetryIn : TelemetryPort;
    }

    part def ChargingDock {
        attribute dockingTolerance : Meter = 0.05 [unit = "m"];
        attribute outputVoltage : Volt = 48.0 [unit = "V"];
        attribute maximumChargeCurrent : Ampere = 20.0 [unit = "A"];
        attribute maximumChargePower : Watt = 960.0 [unit = "W"];
        port dockPort : DockingPort;
        port chargingOut : ChargingPort;
    }

    part def TaskEnvironment {
        attribute operatingArea : SquareMeter = 600.0 [unit = "m^2"];
        attribute maximumFloorSlope : Degree = 5.0 [unit = "deg"];
        attribute minimumAisleWidth : Meter = 1.2 [unit = "m"];
        attribute nominalObstacleDensity : Integer = 20;
        item availablePayload[1..*] : Payload;
    }

    part def AutonomousRoboticSystem {
        attribute systemName : String = "Autonomous Payload Transport Robotic System";
        attribute primaryTaskDescription : String = "Autonomously pick up a payload at a specified location, transport it through a mapped environment while avoiding obstacles, deliver it to a destination, and return to a charging dock.";

        part autonomousRobot : AutonomousRobot;
        part missionControl : MissionControlStation;
        part chargingDock : ChargingDock;
        part environment : TaskEnvironment;

        item activeMission : MissionPlan {
            attribute missionId = "MISSION-TRANSPORT-001";
            attribute phase = MissionPhase::received;
            attribute maximumMissionTime : Second = 900.0 [unit = "s"];
            attribute requiredPayloadMass : Kilogram = 3.0 [unit = "kg"];
            attribute requiredDeliveryAccuracy : Meter = 0.10 [unit = "m"];
        }

        item taskPayload : Payload {
            attribute payloadId = "PAYLOAD-A17";
            attribute mass : Kilogram = 3.0 [unit = "kg"];
            attribute length : Meter = 0.30 [unit = "m"];
            attribute width : Meter = 0.22 [unit = "m"];
            attribute height : Meter = 0.16 [unit = "m"];
            attribute fragile = false;
        }

        connection missionCommandLink connect missionControl.commandOut to autonomousRobot.commandIn;
        connection telemetryLink connect autonomousRobot.telemetryOut to missionControl.telemetryIn;
        connection robotPayloadInterface connect autonomousRobot.payloadPort to environment.availablePayload;
        connection dockingTelemetryLink connect autonomousRobot.telemetryOut to chargingDock.dockPort;
        connection chargingPowerLink connect chargingDock.chargingOut to autonomousRobot.chargingPort;
    }

    requirement def PrimaryTaskAutonomyRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-AUTO-001";
        attribute text : String = "The robotic system shall perform the primary payload transport task using the autonomous robot without requiring continuous human control.";
        require constraint autonomyLevelConstraint {
            robot.autonomyLevel >= 4
        }
    }

    requirement def MissionCompletionRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-AUTO-002";
        attribute text : String = "The autonomous robot shall complete a validated pickup, transport, delivery, and return-to-dock mission within the maximum mission time.";
        require constraint missionTimeConstraint {
            robot.operatingEndurance.value >= 900.0
        }
    }

    requirement def PayloadCapacityRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-AUTO-003";
        attribute text : String = "The autonomous robot shall acquire, secure, transport, and release payloads with mass up to 5 kg.";
        require constraint payloadMassConstraint {
            robot.maximumPayloadMass.value >= 5.0
        }
    }

    requirement def CollisionAvoidanceRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-SAFE-001";
        attribute text : String = "The autonomous robot shall maintain at least 0.50 m planned clearance from detected obstacles and shall stop when an obstacle is within 0.30 m.";
        require constraint plannedClearanceConstraint {
            robot.navigationComputer.minimumObstacleClearance.value >= 0.50
        }
        require constraint hardStopConstraint {
            robot.safetyController.obstacleHardStopDistance.value <= 0.30
        }
    }

    requirement def EmergencyStopRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-SAFE-002";
        attribute text : String = "The autonomous robot shall enter the emergency stop state within 100 ms of receiving an asserted emergency stop signal.";
        require constraint emergencyStopLatencyConstraint {
            robot.safetyController.emergencyStopLatency.value <= 100.0
        }
    }

    requirement def SpeedLimitRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-SAFE-003";
        attribute text : String = "The autonomous robot shall limit autonomous motion speed to no more than 1.5 m/s and safety-limited speed to no more than 1.2 m/s.";
        require constraint maximumSpeedConstraint {
            robot.maximumSpeed.value <= 1.5
        }
        require constraint safeSpeedConstraint {
            robot.safetyController.maximumSafeSpeed.value <= 1.2
        }
    }

    requirement def LocalizationAccuracyRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-NAV-001";
        attribute text : String = "The navigation computer shall localize the robot to within 0.05 m during autonomous operation.";
        require constraint localizationConstraint {
            robot.navigationComputer.localizationAccuracy.value <= 0.05
        }
    }

    requirement def ReplanningRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-NAV-002";
        attribute text : String = "The autonomous robot shall update its local map and replan around obstacles at least every 0.25 s.";
        require constraint replanningConstraint {
            robot.navigationComputer.replanningPeriod.value <= 0.25
        }
    }

    requirement def BatteryEnduranceRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-PWR-001";
        attribute text : String = "The autonomous robot shall have sufficient stored energy to operate for at least 4 hours under nominal autonomous task execution.";
        require constraint enduranceConstraint {
            robot.operatingEndurance.value >= 14400.0
        }
    }

    requirement def ChargingRequirement {
        subject dock : ChargingDock;
        attribute id : String = "REQ-PWR-002";
        attribute text : String = "The charging dock shall provide up to 960 W of charging power at 48 V nominal to recharge the autonomous robot.";
        require constraint chargePowerConstraint {
            dock.maximumChargePower.value >= 960.0
        }
        require constraint voltageConstraint {
            dock.outputVoltage.value == 48.0
        }
    }

    requirement def TelemetryRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-COM-001";
        attribute text : String = "The autonomous robot shall transmit status telemetry at no less than 5 Hz during mission execution.";
        require constraint telemetryRateConstraint {
            robot.communication.telemetryRate.value >= 5.0
        }
    }

    requirement def CommandLatencyRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-COM-002";
        attribute text : String = "The autonomous robot shall accept mission commands and emergency stop commands with communication latency not greater than 250 ms.";
        require constraint commandLatencyConstraint {
            robot.communication.maximumCommandLatency.value <= 250.0
        }
    }

    requirement def DeliveryAccuracyRequirement {
        subject robot : AutonomousRobot;
        attribute id : String = "REQ-TASK-001";
        attribute text : String = "The autonomous robot shall place the payload at the delivery pose with position error no greater than 0.10 m.";
        require constraint manipulatorAccuracyConstraint {
            robot.payloadHandling.manipulator.positioningAccuracy.value <= 0.02
        }
    }

    requirement def GeofenceRequirement {
        subject system : AutonomousRoboticSystem;
        attribute id : String = "REQ-SAFE-004";
        attribute text : String = "The robotic system shall keep the autonomous robot within the mission-defined geofence during autonomous operation.";
        require constraint operatingAreaConstraint {
            system.environment.operatingArea.value >= 600.0
        }
    }

    satisfy PrimaryTaskAutonomyRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy MissionCompletionRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy PayloadCapacityRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy CollisionAvoidanceRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy EmergencyStopRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy SpeedLimitRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy LocalizationAccuracyRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy ReplanningRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy BatteryEnduranceRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy ChargingRequirement by AutonomousRoboticSystem::chargingDock;
    satisfy TelemetryRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy CommandLatencyRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy DeliveryAccuracyRequirement by AutonomousRoboticSystem::autonomousRobot;
    satisfy GeofenceRequirement by AutonomousRoboticSystem;

}
