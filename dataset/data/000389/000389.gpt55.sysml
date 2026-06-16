package AnalogRobotPrimaryTaskModel {
    import ScalarValues::*;

    attribute def Voltage :> Real {
        attribute unit : String = "V";
    }

    attribute def Current :> Real {
        attribute unit : String = "A";
    }

    attribute def Power :> Real {
        attribute unit : String = "W";
    }

    attribute def Resistance :> Real {
        attribute unit : String = "ohm";
    }

    attribute def Frequency :> Real {
        attribute unit : String = "Hz";
    }

    attribute def Length :> Real {
        attribute unit : String = "m";
    }

    attribute def Speed :> Real {
        attribute unit : String = "m/s";
    }

    attribute def AngularSpeed :> Real {
        attribute unit : String = "rad/s";
    }

    attribute def Mass :> Real {
        attribute unit : String = "kg";
    }

    attribute def Force :> Real {
        attribute unit : String = "N";
    }

    attribute def Time :> Real {
        attribute unit : String = "s";
    }

    attribute def Temperature :> Real {
        attribute unit : String = "degC";
    }

    attribute def Percent :> Real {
        attribute unit : String = "%";
    }

    attribute def Reflectance :> Real {
        attribute unit : String = "ratio";
    }

    attribute def PayloadIdentifier :> String;

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute availablePower : Power;
    }

    item def AnalogVoltageSignal {
        attribute amplitude : Voltage;
        attribute offset : Voltage;
        attribute frequency : Frequency;
        attribute sourceImpedance : Resistance;
    }

    item def MotorDriveSignal {
        attribute commandVoltage : Voltage;
        attribute currentLimit : Current;
        attribute polarity : Integer;
    }

    item def ReflectanceReading {
        attribute reflectance : Reflectance;
        attribute signalVoltage : Voltage;
    }

    item def RangeReading {
        attribute distance : Length;
        attribute signalVoltage : Voltage;
    }

    item def Payload {
        attribute id : PayloadIdentifier;
        attribute mass : Mass;
        attribute length : Length;
        attribute width : Length;
        attribute height : Length;
    }

    item def MissionCommand {
        attribute commandId : String;
        attribute pickupZone : String;
        attribute dropZone : String;
        attribute maximumPayloadMass : Mass;
        attribute requestedSpeed : Speed;
    }

    item def TaskReport {
        attribute commandId : String;
        attribute completed : Boolean;
        attribute payloadDelivered : Boolean;
        attribute elapsedTime : Time;
        attribute faultCode : String;
    }

    item def ContactState {
        attribute detected : Boolean;
        attribute contactForce : Force;
    }

    item def FaultSignal {
        attribute active : Boolean;
        attribute severity : Integer;
        attribute description : String;
    }

    port def PowerInputPort {
        in item power : ElectricalEnergy;
    }

    port def PowerOutputPort {
        out item power : ElectricalEnergy;
    }

    port def AnalogSignalInputPort {
        in item signal : AnalogVoltageSignal;
    }

    port def AnalogSignalOutputPort {
        out item signal : AnalogVoltageSignal;
    }

    port def MotorCommandInputPort {
        in item command : MotorDriveSignal;
    }

    port def MotorCommandOutputPort {
        out item command : MotorDriveSignal;
    }

    port def ReflectanceOutputPort {
        out item reading : ReflectanceReading;
    }

    port def RangeOutputPort {
        out item reading : RangeReading;
    }

    port def PayloadPort {
        inout item carriedPayload : Payload;
    }

    port def MissionCommandPort {
        in item command : MissionCommand;
    }

    port def TaskReportPort {
        out item report : TaskReport;
    }

    port def FaultOutputPort {
        out item fault : FaultSignal;
    }

    port def ContactOutputPort {
        out item contact : ContactState;
    }

    port def MechanicalWheelPort {
        out attribute wheelSpeed : AngularSpeed;
        out attribute tractionForce : Force;
    }

    port def MechanicalGripperPort {
        inout item handledPayload : Payload;
        out attribute grippingForce : Force;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage = 24.0;
        attribute capacity_Ah : Real = 18.0;
        attribute maximumContinuousCurrent : Current = 35.0;
        attribute mass : Mass = 6.5;
        port dcOut : PowerOutputPort;
    }

    part def Fuse {
        attribute currentRating : Current = 30.0;
        attribute tripTime : Time = 0.10;
        port powerIn : PowerInputPort;
        port powerOut : PowerOutputPort;
    }

    part def EmergencyStopSwitch {
        attribute normallyClosed : Boolean = true;
        attribute contactResistance : Resistance = 0.02;
        port powerIn : PowerInputPort;
        port powerOut : PowerOutputPort;
        port faultOut : FaultOutputPort;
    }

    part def PowerDistributionBoard {
        attribute busVoltage : Voltage = 24.0;
        attribute controllerRailVoltage : Voltage = 12.0;
        attribute sensorRailVoltage : Voltage = 5.0;
        attribute maximumOutputCurrent : Current = 25.0;
        port mainPowerIn : PowerInputPort;
        port leftMotorPowerOut : PowerOutputPort;
        port rightMotorPowerOut : PowerOutputPort;
        port gripperPowerOut : PowerOutputPort;
        port controllerPowerOut : PowerOutputPort;
        port sensorPowerOut : PowerOutputPort;
    }

    part def LineReflectanceSensor {
        attribute emitterWavelength_nm : Real = 940.0;
        attribute sampleFrequency : Frequency = 500.0;
        attribute outputVoltageDark : Voltage = 0.25;
        attribute outputVoltageBright : Voltage = 4.75;
        attribute mountingHeight : Length = 0.018;
        port powerIn : PowerInputPort;
        port reflectanceOut : ReflectanceOutputPort;
        port analogOut : AnalogSignalOutputPort;
    }

    part def AnalogRangeSensor {
        attribute minimumRange : Length = 0.05;
        attribute maximumRange : Length = 1.50;
        attribute outputAtMinimumRange : Voltage = 4.5;
        attribute outputAtMaximumRange : Voltage = 0.4;
        attribute sampleFrequency : Frequency = 100.0;
        port powerIn : PowerInputPort;
        port rangeOut : RangeOutputPort;
        port analogOut : AnalogSignalOutputPort;
    }

    part def ContactBumper {
        attribute triggerForce : Force = 8.0;
        attribute debounceTime : Time = 0.02;
        port contactOut : ContactOutputPort;
        port analogOut : AnalogSignalOutputPort;
    }

    part def AnalogErrorAmplifier {
        attribute gain : Real = 3.2;
        attribute inputOffset : Voltage = 0.0;
        attribute bandwidth : Frequency = 120.0;
        port leftSensorIn : AnalogSignalInputPort;
        port rightSensorIn : AnalogSignalInputPort;
        port errorOut : AnalogSignalOutputPort;
    }

    part def AnalogPIDNetwork {
        attribute proportionalGain : Real = 1.8;
        attribute integralTime : Time = 0.45;
        attribute derivativeTime : Time = 0.08;
        attribute filterCapacitance_uF : Real = 2.2;
        attribute filterResistance_kOhm : Real = 47.0;
        attribute bandwidth : Frequency = 80.0;
        port errorIn : AnalogSignalInputPort;
        port correctionOut : AnalogSignalOutputPort;
    }

    part def AnalogMotorMixer {
        attribute forwardBiasVoltage : Voltage = 2.5;
        attribute maximumCommandVoltage : Voltage = 5.0;
        attribute minimumCommandVoltage : Voltage = -5.0;
        port speedSetpointIn : AnalogSignalInputPort;
        port steeringCorrectionIn : AnalogSignalInputPort;
        port leftMotorCommandOut : MotorCommandOutputPort;
        port rightMotorCommandOut : MotorCommandOutputPort;
    }

    part def AnalogSafetyInterlock {
        attribute obstacleStopThreshold : Length = 0.25;
        attribute bumperStopThreshold : Force = 8.0;
        attribute inhibitVoltage : Voltage = 0.0;
        port rangeSignalIn : AnalogSignalInputPort;
        port bumperSignalIn : AnalogSignalInputPort;
        port controllerEnableIn : AnalogSignalInputPort;
        port safeEnableOut : AnalogSignalOutputPort;
        port faultOut : FaultOutputPort;
    }

    part def AnalogTaskSequencer {
        attribute pickupDwellTime : Time = 1.5;
        attribute dropDwellTime : Time = 1.2;
        attribute homingTimeout : Time = 45.0;
        attribute implementedWithRelaysAndComparators : Boolean = true;
        port missionIn : MissionCommandPort;
        port taskSpeedOut : AnalogSignalOutputPort;
        port gripperCommandOut : AnalogSignalOutputPort;
        port controllerEnableOut : AnalogSignalOutputPort;
        port reportOut : TaskReportPort;
    }

    part def AnalogController {
        attribute supplyVoltage : Voltage = 12.0;
        attribute idleCurrent : Current = 0.35;
        attribute analogOnlyControlPath : Boolean = true;
        part errorAmplifier : AnalogErrorAmplifier;
        part pidNetwork : AnalogPIDNetwork;
        part motorMixer : AnalogMotorMixer;
        part safetyInterlock : AnalogSafetyInterlock;
        part taskSequencer : AnalogTaskSequencer;
        port powerIn : PowerInputPort;
        port leftLineIn : AnalogSignalInputPort;
        port rightLineIn : AnalogSignalInputPort;
        port frontRangeIn : AnalogSignalInputPort;
        port bumperIn : AnalogSignalInputPort;
        port missionIn : MissionCommandPort;
        port leftMotorOut : MotorCommandOutputPort;
        port rightMotorOut : MotorCommandOutputPort;
        port gripperCommandOut : AnalogSignalOutputPort;
        port taskReportOut : TaskReportPort;
        port faultOut : FaultOutputPort;

        connect leftLineIn to errorAmplifier.leftSensorIn;
        connect rightLineIn to errorAmplifier.rightSensorIn;
        connect errorAmplifier.errorOut to pidNetwork.errorIn;
        connect pidNetwork.correctionOut to motorMixer.steeringCorrectionIn;
        connect taskSequencer.taskSpeedOut to motorMixer.speedSetpointIn;
        connect frontRangeIn to safetyInterlock.rangeSignalIn;
        connect bumperIn to safetyInterlock.bumperSignalIn;
        connect taskSequencer.controllerEnableOut to safetyInterlock.controllerEnableIn;
        connect motorMixer.leftMotorCommandOut to leftMotorOut;
        connect motorMixer.rightMotorCommandOut to rightMotorOut;
        connect taskSequencer.gripperCommandOut to gripperCommandOut;
        connect missionIn to taskSequencer.missionIn;
        connect taskSequencer.reportOut to taskReportOut;
        connect safetyInterlock.faultOut to faultOut;
    }

    part def DCMotor {
        attribute nominalVoltage : Voltage = 24.0;
        attribute stallCurrent : Current = 18.0;
        attribute noLoadSpeed : AngularSpeed = 314.0;
        attribute torqueConstant_NmPerA : Real = 0.085;
        attribute windingResistance : Resistance = 1.3;
        port powerIn : PowerInputPort;
        port commandIn : MotorCommandInputPort;
        port shaftOut : MechanicalWheelPort;
    }

    part def Gearbox {
        attribute ratio : Real = 24.0;
        attribute efficiency : Percent = 82.0;
        port inputShaft : MechanicalWheelPort;
        port outputShaft : MechanicalWheelPort;
    }

    part def DriveWheel {
        attribute radius : Length = 0.075;
        attribute width : Length = 0.032;
        attribute maximumTractionForce : Force = 85.0;
        port axleIn : MechanicalWheelPort;
        port groundContact : MechanicalWheelPort;
    }

    part def DifferentialDriveModule {
        attribute trackWidth : Length = 0.42;
        attribute maximumLinearSpeed : Speed = 1.20;
        part leftMotor : DCMotor;
        part rightMotor : DCMotor;
        part leftGearbox : Gearbox;
        part rightGearbox : Gearbox;
        part leftWheel : DriveWheel;
        part rightWheel : DriveWheel;
        port leftPowerIn : PowerInputPort;
        port rightPowerIn : PowerInputPort;
        port leftCommandIn : MotorCommandInputPort;
        port rightCommandIn : MotorCommandInputPort;
        port leftWheelGround : MechanicalWheelPort;
        port rightWheelGround : MechanicalWheelPort;

        connect leftPowerIn to leftMotor.powerIn;
        connect rightPowerIn to rightMotor.powerIn;
        connect leftCommandIn to leftMotor.commandIn;
        connect rightCommandIn to rightMotor.commandIn;
        connect leftMotor.shaftOut to leftGearbox.inputShaft;
        connect rightMotor.shaftOut to rightGearbox.inputShaft;
        connect leftGearbox.outputShaft to leftWheel.axleIn;
        connect rightGearbox.outputShaft to rightWheel.axleIn;
        connect leftWheel.groundContact to leftWheelGround;
        connect rightWheel.groundContact to rightWheelGround;
    }

    part def GripperActuator {
        attribute nominalVoltage : Voltage = 24.0;
        attribute maximumCurrent : Current = 4.5;
        attribute openTime : Time = 0.8;
        attribute closeTime : Time = 0.9;
        attribute maximumGripForce : Force = 55.0;
        port powerIn : PowerInputPort;
        port commandIn : AnalogSignalInputPort;
        port mechanicalOut : MechanicalGripperPort;
    }

    part def ParallelJawGripper {
        attribute jawStroke : Length = 0.09;
        attribute jawPadFrictionCoefficient : Real = 0.75;
        attribute payloadMassLimit : Mass = 5.0;
        part actuator : GripperActuator;
        port powerIn : PowerInputPort;
        port analogCommandIn : AnalogSignalInputPort;
        port payloadInterface : PayloadPort;
        port mechanicalInterface : MechanicalGripperPort;

        connect powerIn to actuator.powerIn;
        connect analogCommandIn to actuator.commandIn;
        connect actuator.mechanicalOut to mechanicalInterface;
    }

    part def AluminumChassis {
        attribute length : Length = 0.72;
        attribute width : Length = 0.48;
        attribute height : Length = 0.31;
        attribute mass : Mass = 8.2;
        attribute payloadDeckHeight : Length = 0.22;
    }

    part def TaskEnvironment {
        attribute lineWidth : Length = 0.035;
        attribute routeLength : Length = 28.0;
        attribute pickupZoneName : String = "PICKUP_A";
        attribute dropZoneName : String = "DROP_B";
        attribute nominalAmbientTemperature : Temperature = 25.0;
        item payload1 : Payload {
            attribute id = "crate-analog-001";
            attribute mass = 3.2;
            attribute length = 0.28;
            attribute width = 0.22;
            attribute height = 0.18;
        }
    }

    action def SenseLine {
        in item leftSignal : AnalogVoltageSignal;
        in item rightSignal : AnalogVoltageSignal;
        out item leftReading : ReflectanceReading;
        out item rightReading : ReflectanceReading;
    }

    action def ComputeAnalogSteeringCorrection {
        in item leftSignal : AnalogVoltageSignal;
        in item rightSignal : AnalogVoltageSignal;
        out item correction : AnalogVoltageSignal;
    }

    action def ApplyMotorCommands {
        in item leftCommand : MotorDriveSignal;
        in item rightCommand : MotorDriveSignal;
        out attribute forwardSpeed : Speed;
    }

    action def GripPayload {
        in item payloadToGrip : Payload;
        in item gripCommand : AnalogVoltageSignal;
        out item grippedPayload : Payload;
    }

    action def ReleasePayload {
        in item carriedPayload : Payload;
        in item releaseCommand : AnalogVoltageSignal;
        out item releasedPayload : Payload;
    }

    action def DetectObstacle {
        in item rangeSignal : AnalogVoltageSignal;
        in item contactSignal : AnalogVoltageSignal;
        out item fault : FaultSignal;
    }

    action def PerformPrimaryTransportTask {
        in item mission : MissionCommand;
        in item payloadAtPickup : Payload;
        out item report : TaskReport;

        action receiveMission;
        then action energizeAnalogController;
        then action approachPickupZone;
        then action closeGripper : GripPayload;
        then action followLineToDropZone;
        then action openGripper : ReleasePayload;
        then action returnToStandby;
        then action issueReport;
    }

    state def AnalogRobotOperationalStates {
        state poweredOff;
        state selfTest;
        state standby;
        state navigatingToPickup;
        state acquiringPayload;
        state transportingPayload;
        state releasingPayload;
        state returningHome;
        state completed;
        state safeStopped;
        state faulted;

        transition initial then poweredOff;
        transition poweredOff then selfTest accept PowerApplied;
        transition selfTest then standby accept SelfTestPassed;
        transition selfTest then faulted accept SelfTestFailed;
        transition standby then navigatingToPickup accept MissionReceived;
        transition navigatingToPickup then acquiringPayload accept PickupZoneDetected;
        transition acquiringPayload then transportingPayload accept PayloadSecured;
        transition transportingPayload then releasingPayload accept DropZoneDetected;
        transition releasingPayload then returningHome accept PayloadReleased;
        transition returningHome then completed accept HomeLineMarkerDetected;
        transition completed then standby accept ReportAcknowledged;
        transition navigatingToPickup then safeStopped accept ObstacleDetected;
        transition transportingPayload then safeStopped accept ObstacleDetected;
        transition returningHome then safeStopped accept ObstacleDetected;
        transition safeStopped then standby accept ObstacleCleared;
        transition safeStopped then faulted accept StopTimeoutExceeded;
        transition standby then poweredOff accept PowerRemoved;
    }

    part def AnalogRobot {
        attribute name : String = "Analog Primary Task Robot";
        attribute totalMassWithoutPayload : Mass = 22.4;
        attribute maximumPayloadMass : Mass = 5.0;
        attribute nominalTaskSpeed : Speed = 0.75;
        attribute maximumTaskSpeed : Speed = 1.20;
        attribute minimumLineReflectanceContrast : Reflectance = 0.35;
        attribute primaryTask : String = "Pick up a payload, follow an analog line-guided route, and deliver the payload to the drop zone";
        attribute usesAnalogRobotArchitecture : Boolean = true;

        part chassis : AluminumChassis;
        part battery : BatteryPack;
        part fuse : Fuse;
        part emergencyStop : EmergencyStopSwitch;
        part powerDistribution : PowerDistributionBoard;
        part leftLineSensor : LineReflectanceSensor;
        part rightLineSensor : LineReflectanceSensor;
        part frontRangeSensor : AnalogRangeSensor;
        part bumper : ContactBumper;
        part analogController : AnalogController;
        part drivetrain : DifferentialDriveModule;
        part gripper : ParallelJawGripper;

        port missionCommandIn : MissionCommandPort;
        port taskReportOut : TaskReportPort;
        port payloadInterface : PayloadPort;
        port externalFaultOut : FaultOutputPort;

        perform action primaryTransportTask : PerformPrimaryTransportTask;
        exhibit state operationalBehavior : AnalogRobotOperationalStates;

        connect battery.dcOut to fuse.powerIn;
        connect fuse.powerOut to emergencyStop.powerIn;
        connect emergencyStop.powerOut to powerDistribution.mainPowerIn;

        connect powerDistribution.controllerPowerOut to analogController.powerIn;
        connect powerDistribution.sensorPowerOut to leftLineSensor.powerIn;
        connect powerDistribution.sensorPowerOut to rightLineSensor.powerIn;
        connect powerDistribution.sensorPowerOut to frontRangeSensor.powerIn;
        connect powerDistribution.leftMotorPowerOut to drivetrain.leftPowerIn;
        connect powerDistribution.rightMotorPowerOut to drivetrain.rightPowerIn;
        connect powerDistribution.gripperPowerOut to gripper.powerIn;

        connect leftLineSensor.analogOut to analogController.leftLineIn;
        connect rightLineSensor.analogOut to analogController.rightLineIn;
        connect frontRangeSensor.analogOut to analogController.frontRangeIn;
        connect bumper.analogOut to analogController.bumperIn;

        connect missionCommandIn to analogController.missionIn;
        connect analogController.leftMotorOut to drivetrain.leftCommandIn;
        connect analogController.rightMotorOut to drivetrain.rightCommandIn;
        connect analogController.gripperCommandOut to gripper.analogCommandIn;
        connect analogController.taskReportOut to taskReportOut;
        connect analogController.faultOut to externalFaultOut;
        connect payloadInterface to gripper.payloadInterface;
    }

    requirement def ReqPrimaryTask {
        subject robot : AnalogRobot;
        require constraint {
            robot.usesAnalogRobotArchitecture == true
        }
    }

    requirement def ReqPayloadCapacity {
        subject robot : AnalogRobot;
        require constraint {
            robot.maximumPayloadMass >= 5.0
        }
    }

    requirement def ReqTaskSpeed {
        subject robot : AnalogRobot;
        require constraint {
            robot.maximumTaskSpeed >= 1.0 and robot.nominalTaskSpeed <= robot.maximumTaskSpeed
        }
    }

    requirement def ReqAnalogControlPath {
        subject robot : AnalogRobot;
        require constraint {
            robot.analogController.analogOnlyControlPath == true
        }
    }

    requirement def ReqBatteryVoltage {
        subject robot : AnalogRobot;
        require constraint {
            robot.battery.nominalVoltage == 24.0 and robot.powerDistribution.busVoltage == 24.0
        }
    }

    requirement def ReqSensorContrast {
        subject robot : AnalogRobot;
        require constraint {
            robot.minimumLineReflectanceContrast >= 0.30
        }
    }

    requirement def ReqObstacleSafety {
        subject robot : AnalogRobot;
        require constraint {
            robot.analogController.safetyInterlock.obstacleStopThreshold <= 0.30
        }
    }

    requirement def ReqGripPayload {
        subject robot : AnalogRobot;
        require constraint {
            robot.gripper.payloadMassLimit >= robot.maximumPayloadMass and robot.gripper.actuator.maximumGripForce >= 45.0
        }
    }

    requirement def ReqEmergencyStop {
        subject robot : AnalogRobot;
        require constraint {
            robot.emergencyStop.normallyClosed == true
        }
    }

    requirement def ReqRouteCompletion {
        subject environment : TaskEnvironment;
        require constraint {
            environment.routeLength <= 30.0
        }
    }

    part analogTransportCell {
        part robot : AnalogRobot;
        part environment : TaskEnvironment;

        item nominalMission : MissionCommand {
            attribute commandId = "mission-analog-delivery-001";
            attribute pickupZone = "PICKUP_A";
            attribute dropZone = "DROP_B";
            attribute maximumPayloadMass = 5.0;
            attribute requestedSpeed = 0.75;
        }

        requirement primaryTaskRequirement : ReqPrimaryTask {
            subject robot = robot;
        }

        requirement payloadCapacityRequirement : ReqPayloadCapacity {
            subject robot = robot;
        }

        requirement speedRequirement : ReqTaskSpeed {
            subject robot = robot;
        }

        requirement analogControlRequirement : ReqAnalogControlPath {
            subject robot = robot;
        }

        requirement batteryVoltageRequirement : ReqBatteryVoltage {
            subject robot = robot;
        }

        requirement sensorContrastRequirement : ReqSensorContrast {
            subject robot = robot;
        }

        requirement obstacleSafetyRequirement : ReqObstacleSafety {
            subject robot = robot;
        }

        requirement gripRequirement : ReqGripPayload {
            subject robot = robot;
        }

        requirement emergencyStopRequirement : ReqEmergencyStop {
            subject robot = robot;
        }

        requirement routeCompletionRequirement : ReqRouteCompletion {
            subject environment = environment;
        }
    }
}
