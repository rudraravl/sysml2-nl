package AnalogRobotPrimaryTaskModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent : Real {
        doc /* Percentage from 0 to 100. */
    }

    attribute def Volt : Real {
        doc /* Electrical potential in volts. */
    }

    attribute def Ampere : Real {
        doc /* Electrical current in amperes. */
    }

    attribute def NewtonMeter : Real {
        doc /* Rotational torque in newton-meters. */
    }

    attribute def RadianPerSecond : Real {
        doc /* Angular velocity in radians per second. */
    }

    attribute def MeterPerSecond : Real {
        doc /* Linear velocity in meters per second. */
    }

    attribute def Meter : Real {
        doc /* Length in meters. */
    }

    attribute def Kilogram : Real {
        doc /* Mass in kilograms. */
    }

    attribute def Second : Real {
        doc /* Duration in seconds. */
    }

    attribute def Celsius : Real {
        doc /* Temperature in degrees Celsius. */
    }

    attribute def Ohm : Real {
        doc /* Electrical resistance in ohms. */
    }

    attribute def AnalogSignalVoltage : Volt {
        doc /* Continuous analog signal voltage. */
        range : Real[2] = [0.0, 5.0];
    }

    attribute def BatteryVoltage : Volt {
        range : Real[2] = [18.0, 29.4];
    }

    attribute def DutyCycle : Percent {
        range : Real[2] = [0.0, 100.0];
    }

    attribute def PayloadMass : Kilogram {
        range : Real[2] = [0.0, 2.5];
    }

    attribute def Position2D {
        x : Meter;
        y : Meter;
    }

    attribute def Pose2D {
        position : Position2D;
        heading : Real;
    }

    item def ElectricalPower {
        voltage : Volt;
        current : Ampere;
    }

    item def AnalogControlSignal {
        signalVoltage : AnalogSignalVoltage;
        impedance : Ohm;
        noisePeakToPeak : Volt;
    }

    item def MotorDriveSignal {
        pwmDuty : DutyCycle;
        directionCommand : Integer;
        enable : Boolean;
    }

    item def WheelMotion {
        angularVelocity : RadianPerSecond;
        torque : NewtonMeter;
    }

    item def EncoderPulseTrain {
        leftPulseRate : Real;
        rightPulseRate : Real;
    }

    item def RangeVoltage {
        frontRangeVoltage : AnalogSignalVoltage;
        leftRangeVoltage : AnalogSignalVoltage;
        rightRangeVoltage : AnalogSignalVoltage;
    }

    item def PayloadItem {
        mass : PayloadMass;
        fragile : Boolean;
        secured : Boolean;
    }

    item def TaskCommand {
        start : Boolean;
        targetPose : Pose2D;
        requestedPayloadMass : PayloadMass;
    }

    item def TaskStatus {
        active : Boolean;
        completed : Boolean;
        faulted : Boolean;
        messageCode : Integer;
    }

    port def PowerInputPort {
        in power : ElectricalPower;
    }

    port def PowerOutputPort {
        out power : ElectricalPower;
    }

    port def AnalogInputPort {
        in signal : AnalogControlSignal;
    }

    port def AnalogOutputPort {
        out signal : AnalogControlSignal;
    }

    port def MotorCommandPort {
        in command : MotorDriveSignal;
    }

    port def WheelMotionPort {
        out motion : WheelMotion;
    }

    port def EncoderPort {
        out pulses : EncoderPulseTrain;
    }

    port def RangeSensorPort {
        out ranges : RangeVoltage;
    }

    port def PayloadPort {
        inout payload : PayloadItem;
    }

    port def TaskCommandPort {
        in command : TaskCommand;
    }

    port def TaskStatusPort {
        out status : TaskStatus;
    }

    port def GroundContactPort {
        out tractionForce : Real;
    }

    action def ConvertAnalogJoystickToMotorCommands {
        in leftAxis : AnalogControlSignal;
        in rightAxis : AnalogControlSignal;
        out leftMotor : MotorDriveSignal;
        out rightMotor : MotorDriveSignal;

        first start;
        then sampleAnalogInputs;
        then filterNoise;
        then mapVoltageToDutyCycle;
        then limitAcceleration;
        then emitMotorCommands;
        then done;

        flow from start to sampleAnalogInputs;
        flow from sampleAnalogInputs to filterNoise;
        flow from filterNoise to mapVoltageToDutyCycle;
        flow from mapVoltageToDutyCycle to limitAcceleration;
        flow from limitAcceleration to emitMotorCommands;
        flow from emitMotorCommands to done;
    }

    action def NavigateToTargetPose {
        in targetPose : Pose2D;
        in frontRange : RangeVoltage;
        in encoderFeedback : EncoderPulseTrain;
        out leftCommand : MotorDriveSignal;
        out rightCommand : MotorDriveSignal;
        out arrived : Boolean;

        first initializeNavigation;
        then estimatePose;
        then evaluateObstacleClearance;
        then computeAnalogEquivalentSteering;
        then commandDifferentialDrive;
        then checkArrival;
        then finish;

        flow from initializeNavigation to estimatePose;
        flow from estimatePose to evaluateObstacleClearance;
        flow from evaluateObstacleClearance to computeAnalogEquivalentSteering;
        flow from computeAnalogEquivalentSteering to commandDifferentialDrive;
        flow from commandDifferentialDrive to checkArrival;
        flow from checkArrival to finish;
    }

    action def PerformAnalogRobotPrimaryTask {
        in task : TaskCommand;
        out status : TaskStatus;

        first waitForStart;
        then validatePayload;
        then acquirePayload;
        then navigateWithAnalogControlLoop;
        then placePayload;
        then confirmCompletion;
        then publishStatus;

        flow from waitForStart to validatePayload;
        flow from validatePayload to acquirePayload;
        flow from acquirePayload to navigateWithAnalogControlLoop;
        flow from navigateWithAnalogControlLoop to placePayload;
        flow from placePayload to confirmCompletion;
        flow from confirmCompletion to publishStatus;
    }

    state def AnalogRobotOperatingState {
        entry action initializeElectronics;
        exit action disableMotorDrivers;

        state powerOff;
        state selfTest;
        state idle;
        state acceptingAnalogCommand;
        state executingPrimaryTask;
        state obstacleAvoidance;
        state payloadHandling;
        state completed;
        state fault;

        transition initial then powerOff;
        transition powerOff then selfTest
            accept PowerApplied;

        transition selfTest then idle
            if electronicsNominal and batteryVoltageOk and analogInputsCalibrated;

        transition selfTest then fault
            if not electronicsNominal or not batteryVoltageOk;

        transition idle then acceptingAnalogCommand
            accept OperatorAnalogSignalDetected;

        transition acceptingAnalogCommand then executingPrimaryTask
            accept ValidTaskCommand;

        transition executingPrimaryTask then obstacleAvoidance
            if frontClearanceLessThan0_35m;

        transition obstacleAvoidance then executingPrimaryTask
            if frontClearanceGreaterThan0_50m;

        transition executingPrimaryTask then payloadHandling
            if targetPoseReached;

        transition payloadHandling then completed
            if payloadPlacedAndReleased;

        transition completed then idle
            accept ResetTask;

        transition idle then fault
            if batteryVoltageBelow18V;

        transition acceptingAnalogCommand then fault
            if analogSignalOutOfRange;

        transition executingPrimaryTask then fault
            if motorOverTemperature or encoderFeedbackLost;

        transition fault then powerOff
            accept PowerRemoved;
    }

    part def AnalogJoystickController {
        attribute supplyVoltage : Volt = 5.0;
        attribute neutralVoltage : Volt = 2.5;
        attribute maxSignalNoise : Volt = 0.05;

        port leftAxisOut : AnalogOutputPort;
        port rightAxisOut : AnalogOutputPort;
        port taskCommandOut : TaskCommandPort;
        port statusIn : TaskStatusPort;
    }

    part def AnalogSignalConditioner {
        attribute inputImpedance : Ohm = 100000.0;
        attribute cutoffFrequencyHz : Real = 25.0;
        attribute outputMin : Volt = 0.0;
        attribute outputMax : Volt = 5.0;

        port rawLeftIn : AnalogInputPort;
        port rawRightIn : AnalogInputPort;
        port filteredLeftOut : AnalogOutputPort;
        port filteredRightOut : AnalogOutputPort;
    }

    part def AnalogControlComputer {
        attribute controlLoopPeriod : Second = 0.02;
        attribute maxCommandSlewRate : Percent = 40.0;

        port leftAnalogIn : AnalogInputPort;
        port rightAnalogIn : AnalogInputPort;
        port rangeIn : RangeSensorPort;
        port encoderIn : EncoderPort;
        port taskIn : TaskCommandPort;
        port leftMotorOut : MotorCommandPort;
        port rightMotorOut : MotorCommandPort;
        port statusOut : TaskStatusPort;

        perform analogMapping : ConvertAnalogJoystickToMotorCommands;
        perform primaryTask : PerformAnalogRobotPrimaryTask;
        perform navigation : NavigateToTargetPose;
    }

    part def BatteryPack {
        attribute nominalVoltage : BatteryVoltage = 24.0;
        attribute capacityAmpereHour : Real = 12.0;
        attribute maxContinuousCurrent : Ampere = 30.0;
        attribute stateOfCharge : Percent;
        attribute packTemperature : Celsius;

        port powerOut : PowerOutputPort;
    }

    part def PowerDistributionUnit {
        attribute logicRailVoltage : Volt = 5.0;
        attribute motorRailVoltage : Volt = 24.0;
        attribute fuseCurrentLimit : Ampere = 35.0;

        port batteryIn : PowerInputPort;
        port logicPowerOut : PowerOutputPort;
        port motorPowerOut : PowerOutputPort;
    }

    part def MotorDriver {
        attribute maxCurrent : Ampere = 15.0;
        attribute pwmFrequencyHz : Real = 20000.0;
        attribute overTemperatureLimit : Celsius = 85.0;

        port powerIn : PowerInputPort;
        port commandIn : MotorCommandPort;
        port motorPowerOut : PowerOutputPort;
    }

    part def DCMotor {
        attribute ratedVoltage : Volt = 24.0;
        attribute stallTorque : NewtonMeter = 3.2;
        attribute noLoadSpeed : RadianPerSecond = 42.0;
        attribute windingResistance : Ohm = 1.8;

        port electricalIn : PowerInputPort;
        port shaftOut : WheelMotionPort;
    }

    part def WheelAssembly {
        attribute wheelRadius : Meter = 0.075;
        attribute wheelWidth : Meter = 0.035;
        attribute maxGroundSpeed : MeterPerSecond = 1.2;

        port shaftIn : WheelMotionPort;
        port groundOut : GroundContactPort;
    }

    part def DifferentialDriveModule {
        attribute trackWidth : Meter = 0.42;
        attribute maxLinearSpeed : MeterPerSecond = 1.2;
        attribute maxAngularSpeed : RadianPerSecond = 2.4;

        port powerIn : PowerInputPort;
        port leftCommandIn : MotorCommandPort;
        port rightCommandIn : MotorCommandPort;
        port encoderOut : EncoderPort;
        port leftGroundOut : GroundContactPort;
        port rightGroundOut : GroundContactPort;

        part leftDriver : MotorDriver;
        part rightDriver : MotorDriver;
        part leftMotor : DCMotor;
        part rightMotor : DCMotor;
        part leftWheel : WheelAssembly;
        part rightWheel : WheelAssembly;

        connect powerIn.power to leftDriver.powerIn.power;
        connect powerIn.power to rightDriver.powerIn.power;
        connect leftCommandIn.command to leftDriver.commandIn.command;
        connect rightCommandIn.command to rightDriver.commandIn.command;
        connect leftDriver.motorPowerOut.power to leftMotor.electricalIn.power;
        connect rightDriver.motorPowerOut.power to rightMotor.electricalIn.power;
        connect leftMotor.shaftOut.motion to leftWheel.shaftIn.motion;
        connect rightMotor.shaftOut.motion to rightWheel.shaftIn.motion;
        connect leftWheel.groundOut.tractionForce to leftGroundOut.tractionForce;
        connect rightWheel.groundOut.tractionForce to rightGroundOut.tractionForce;
    }

    part def AnalogRangeSensorArray {
        attribute minimumRange : Meter = 0.08;
        attribute maximumRange : Meter = 1.5;
        attribute outputVoltageNear : Volt = 4.5;
        attribute outputVoltageFar : Volt = 0.4;

        port powerIn : PowerInputPort;
        port rangeOut : RangeSensorPort;
    }

    part def PayloadManipulator {
        attribute maxPayloadMass : PayloadMass = 2.5;
        attribute gripperOpenWidth : Meter = 0.12;
        attribute gripForceNewtons : Real = 35.0;
        attribute liftHeight : Meter = 0.18;

        port powerIn : PowerInputPort;
        port commandIn : MotorCommandPort;
        port payloadInterface : PayloadPort;
    }

    part def AnalogRobot {
        attribute massWithoutPayload : Kilogram = 18.0;
        attribute maximumPayload : PayloadMass = 2.5;
        attribute nominalTaskSpeed : MeterPerSecond = 0.65;
        attribute stoppingDistanceAtNominalSpeed : Meter = 0.28;
        attribute batteryVoltage : BatteryVoltage;
        attribute currentPose : Pose2D;
        attribute operatingState : AnalogRobotOperatingState;

        port operatorLeftAnalog : AnalogInputPort;
        port operatorRightAnalog : AnalogInputPort;
        port taskCommandIn : TaskCommandPort;
        port taskStatusOut : TaskStatusPort;
        port payloadPort : PayloadPort;

        part joystick : AnalogJoystickController;
        part conditioner : AnalogSignalConditioner;
        part controller : AnalogControlComputer;
        part battery : BatteryPack;
        part powerDistribution : PowerDistributionUnit;
        part drive : DifferentialDriveModule;
        part rangeSensors : AnalogRangeSensorArray;
        part manipulator : PayloadManipulator;

        connect joystick.leftAxisOut.signal to conditioner.rawLeftIn.signal;
        connect joystick.rightAxisOut.signal to conditioner.rawRightIn.signal;
        connect conditioner.filteredLeftOut.signal to controller.leftAnalogIn.signal;
        connect conditioner.filteredRightOut.signal to controller.rightAnalogIn.signal;

        connect joystick.taskCommandOut.command to controller.taskIn.command;
        connect controller.statusOut.status to joystick.statusIn.status;

        connect battery.powerOut.power to powerDistribution.batteryIn.power;
        connect powerDistribution.logicPowerOut.power to rangeSensors.powerIn.power;
        connect powerDistribution.logicPowerOut.power to controller.taskIn.command;
        connect powerDistribution.motorPowerOut.power to drive.powerIn.power;
        connect powerDistribution.motorPowerOut.power to manipulator.powerIn.power;

        connect rangeSensors.rangeOut.ranges to controller.rangeIn.ranges;
        connect drive.encoderOut.pulses to controller.encoderIn.pulses;
        connect controller.leftMotorOut.command to drive.leftCommandIn.command;
        connect controller.rightMotorOut.command to drive.rightCommandIn.command;
        connect controller.leftMotorOut.command to manipulator.commandIn.command;

        connect taskCommandIn.command to controller.taskIn.command;
        connect controller.statusOut.status to taskStatusOut.status;
        connect payloadPort.payload to manipulator.payloadInterface.payload;
    }

    part def PrimaryTaskWorkcell {
        attribute loadingPose : Pose2D;
        attribute deliveryPose : Pose2D;
        attribute minimumObstacleClearance : Meter = 0.35;
        attribute maximumTaskDuration : Second = 180.0;

        part robot : AnalogRobot;
        part commandedPayload : PayloadItem;

        port externalTaskCommand : TaskCommandPort;
        port externalTaskStatus : TaskStatusPort;

        connect externalTaskCommand.command to robot.taskCommandIn.command;
        connect robot.taskStatusOut.status to externalTaskStatus.status;
    }

    requirement def AnalogRobotPrimaryTaskRequirement {
        subject robot : AnalogRobot;

        require constraint {
            robot.maximumPayload >= 2.5
        }

        require constraint {
            robot.nominalTaskSpeed <= 0.8
        }

        require constraint {
            robot.stoppingDistanceAtNominalSpeed <= 0.30
        }
    }

    requirement def AnalogSignalRequirement {
        subject conditioner : AnalogSignalConditioner;

        require constraint {
            conditioner.outputMin == 0.0 and conditioner.outputMax == 5.0
        }

        require constraint {
            conditioner.cutoffFrequencyHz >= 10.0 and conditioner.cutoffFrequencyHz <= 50.0
        }
    }

    requirement def PowerRequirement {
        subject battery : BatteryPack;

        require constraint {
            battery.nominalVoltage >= 24.0
        }

        require constraint {
            battery.maxContinuousCurrent >= 30.0
        }
    }

    requirement def NavigationSafetyRequirement {
        subject cell : PrimaryTaskWorkcell;

        require constraint {
            cell.minimumObstacleClearance >= 0.35
        }

        require constraint {
            cell.maximumTaskDuration <= 180.0
        }
    }

    requirement def PayloadHandlingRequirement {
        subject manipulator : PayloadManipulator;

        require constraint {
            manipulator.maxPayloadMass >= 2.5
        }

        require constraint {
            manipulator.gripForceNewtons >= 30.0
        }
    }

    satisfy AnalogRobotPrimaryTaskRequirement by AnalogRobot;
    satisfy AnalogSignalRequirement by AnalogSignalConditioner;
    satisfy PowerRequirement by BatteryPack;
    satisfy NavigationSafetyRequirement by PrimaryTaskWorkcell;
    satisfy PayloadHandlingRequirement by PayloadManipulator;

    part analogRobotWorkcell : PrimaryTaskWorkcell {
        attribute loadingPose = (position = (x = 0.0, y = 0.0), heading = 0.0);
        attribute deliveryPose = (position = (x = 4.0, y = 2.0), heading = 1.5708);

        part robot : AnalogRobot {
            attribute massWithoutPayload = 18.0;
            attribute maximumPayload = 2.5;
            attribute nominalTaskSpeed = 0.65;
            attribute stoppingDistanceAtNominalSpeed = 0.28;
        }

        part commandedPayload : PayloadItem {
            attribute mass = 1.8;
            attribute fragile = true;
            attribute secured = false;
        }
    }
}