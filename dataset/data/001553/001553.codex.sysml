package RoboticFinSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Angle {
        :> scalarValues::Real;
        unit = "deg";
    }

    attribute def AngularVelocity {
        :> scalarValues::Real;
        unit = "deg/s";
    }

    attribute def Frequency {
        :> scalarValues::Real;
        unit = "Hz";
    }

    attribute def Force {
        :> scalarValues::Real;
        unit = "N";
    }

    attribute def Torque {
        :> scalarValues::Real;
        unit = "N*m";
    }

    attribute def Voltage {
        :> scalarValues::Real;
        unit = "V";
    }

    attribute def Current {
        :> scalarValues::Real;
        unit = "A";
    }

    attribute def Power {
        :> scalarValues::Real;
        unit = "W";
    }

    attribute def Temperature {
        :> scalarValues::Real;
        unit = "degC";
    }

    attribute def Pressure {
        :> scalarValues::Real;
        unit = "kPa";
    }

    attribute def Length {
        :> scalarValues::Real;
        unit = "mm";
    }

    attribute def Velocity {
        :> scalarValues::Real;
        unit = "m/s";
    }

    attribute def Percent {
        :> scalarValues::Real;
        unit = "%";
    }

    enum def FinOperatingMode {
        enum idle;
        enum calibrating;
        enum swimming;
        enum maneuvering;
        enum holding;
        enum faulted;
    }

    enum def FinFaultCode {
        enum none;
        enum overCurrent;
        enum overTemperature;
        enum encoderLoss;
        enum leakDetected;
        enum actuatorStall;
        enum commandTimeout;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute availablePower : Power;
    }

    item def ControlCommand {
        attribute desiredMode : FinOperatingMode;
        attribute targetSweepAngle : Angle;
        attribute targetFlapFrequency : Frequency;
        attribute targetBiasAngle : Angle;
        attribute targetThrust : Force;
    }

    item def FinStatus {
        attribute actualMode : FinOperatingMode;
        attribute actualSweepAngle : Angle;
        attribute actualFlapFrequency : Frequency;
        attribute estimatedThrust : Force;
        attribute healthPercent : Percent;
        attribute activeFault : FinFaultCode;
    }

    item def MotorDriveSignal {
        attribute phaseCurrentA : Current;
        attribute phaseCurrentB : Current;
        attribute phaseCurrentC : Current;
        attribute commandedTorque : Torque;
    }

    item def JointFeedback {
        attribute jointAngle : Angle;
        attribute jointVelocity : AngularVelocity;
        attribute motorTemperature : Temperature;
        attribute driveCurrent : Current;
    }

    item def HydrodynamicLoad {
        attribute liftForce : Force;
        attribute dragForce : Force;
        attribute bendingMoment : Torque;
        attribute waterSpeed : Velocity;
    }

    item def LeakSignal {
        attribute internalPressure : Pressure;
        attribute leakDetected : Boolean;
    }

    port def PowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def CommandInputPort {
        in item commandIn : ControlCommand;
    }

    port def StatusOutputPort {
        out item statusOut : FinStatus;
    }

    port def MotorDrivePort {
        out item driveOut : MotorDriveSignal;
    }

    port def FeedbackPort {
        in item feedbackIn : JointFeedback;
    }

    port def LoadPort {
        in item loadIn : HydrodynamicLoad;
    }

    port def LeakPort {
        in item leakIn : LeakSignal;
    }

    port def MechanicalJointPort {
        out item loadOut : HydrodynamicLoad;
    }

    action def InterpretCommand {
        in item command : ControlCommand;
        out attribute modeRequest : FinOperatingMode;
        out attribute sweepAmplitude : Angle;
        out attribute flapFrequency : Frequency;
        out attribute biasAngle : Angle;
    }

    action def GenerateFinTrajectory {
        in attribute sweepAmplitude : Angle;
        in attribute flapFrequency : Frequency;
        in attribute biasAngle : Angle;
        in attribute timeStep : Real;
        out attribute targetAngle : Angle;
        out attribute targetVelocity : AngularVelocity;
    }

    action def ControlJointTorque {
        in attribute targetAngle : Angle;
        in attribute targetVelocity : AngularVelocity;
        in item feedback : JointFeedback;
        out attribute requiredTorque : Torque;
    }

    action def EstimateHydrodynamicThrust {
        in item load : HydrodynamicLoad;
        in item feedback : JointFeedback;
        out attribute thrustEstimate : Force;
    }

    action def DetectFinFaults {
        in item feedback : JointFeedback;
        in item leak : LeakSignal;
        in item command : ControlCommand;
        out attribute faultDetected : Boolean;
        out attribute faultCode : FinFaultCode;
    }

    action def RoboticFinControlLoop {
        in item command : ControlCommand;
        in item feedback : JointFeedback;
        in item load : HydrodynamicLoad;
        in item leak : LeakSignal;
        out item drive : MotorDriveSignal;
        out item status : FinStatus;

        action interpret : InterpretCommand {
            in item command = command;
        }

        action trajectory : GenerateFinTrajectory {
            in attribute sweepAmplitude = interpret.sweepAmplitude;
            in attribute flapFrequency = interpret.flapFrequency;
            in attribute biasAngle = interpret.biasAngle;
            in attribute timeStep = 0.01;
        }

        action torqueControl : ControlJointTorque {
            in attribute targetAngle = trajectory.targetAngle;
            in attribute targetVelocity = trajectory.targetVelocity;
            in item feedback = feedback;
        }

        action thrustEstimator : EstimateHydrodynamicThrust {
            in item load = load;
            in item feedback = feedback;
        }

        action faultMonitor : DetectFinFaults {
            in item feedback = feedback;
            in item leak = leak;
            in item command = command;
        }

        bind drive.commandedTorque = torqueControl.requiredTorque;
        bind status.estimatedThrust = thrustEstimator.thrustEstimate;
        bind status.activeFault = faultMonitor.faultCode;
    }

    state def FinControllerStateMachine {
        in item command : ControlCommand;
        in item feedback : JointFeedback;
        in item leak : LeakSignal;

        state initialOff;
        state idle;
        state calibrating;
        state swimming;
        state maneuvering;
        state holdingPosition;
        state faulted;

        transition first initialOff then idle;

        transition idleToCalibrating
            first idle
            accept command
            if command.desiredMode == FinOperatingMode::calibrating
            then calibrating;

        transition calibrationComplete
            first calibrating
            if feedback.jointAngle >= -2.0 and feedback.jointAngle <= 2.0
            then idle;

        transition idleToSwimming
            first idle
            accept command
            if command.desiredMode == FinOperatingMode::swimming
            then swimming;

        transition swimmingToManeuvering
            first swimming
            accept command
            if command.desiredMode == FinOperatingMode::maneuvering
            then maneuvering;

        transition maneuveringToSwimming
            first maneuvering
            accept command
            if command.desiredMode == FinOperatingMode::swimming
            then swimming;

        transition activeToHolding
            first swimming
            accept command
            if command.desiredMode == FinOperatingMode::holding
            then holdingPosition;

        transition holdingToSwimming
            first holdingPosition
            accept command
            if command.desiredMode == FinOperatingMode::swimming
            then swimming;

        transition anyFaultFromIdle
            first idle
            if leak.leakDetected or feedback.motorTemperature > 85.0
            then faulted;

        transition anyFaultFromSwimming
            first swimming
            if leak.leakDetected or feedback.motorTemperature > 85.0 or feedback.driveCurrent > 12.0
            then faulted;

        transition anyFaultFromManeuvering
            first maneuvering
            if leak.leakDetected or feedback.motorTemperature > 85.0 or feedback.driveCurrent > 15.0
            then faulted;

        transition anyFaultFromHolding
            first holdingPosition
            if leak.leakDetected or feedback.motorTemperature > 85.0
            then faulted;

        transition resetFault
            first faulted
            accept command
            if command.desiredMode == FinOperatingMode::idle and not leak.leakDetected and feedback.motorTemperature < 60.0
            then idle;
    }

    part def MotorDriver {
        port powerPort : PowerInputPort;
        port commandPort : MotorDrivePort;
        port feedbackPort : FeedbackPort;

        attribute supplyVoltage : Voltage = 24.0;
        attribute peakCurrentLimit : Current = 15.0;
        attribute continuousCurrentLimit : Current = 8.0;
        attribute switchingFrequency : Frequency = 20000.0;
    }

    part def BrushlessServoMotor {
        port drivePort : MotorDrivePort;
        port shaftFeedbackPort : FeedbackPort;

        attribute ratedTorque : Torque = 1.8;
        attribute peakTorque : Torque = 4.0;
        attribute noLoadSpeed : AngularVelocity = 900.0;
        attribute windingTemperature : Temperature;
    }

    part def ReductionGearbox {
        attribute gearRatio : Real = 12.0;
        attribute backlash : Angle = 0.35;
        attribute efficiency : Percent = 88.0;
    }

    part def FinRootJoint {
        port feedbackPort : FeedbackPort;
        port loadPort : LoadPort;

        attribute commandedAngle : Angle;
        attribute actualAngle : Angle;
        attribute angularRate : AngularVelocity;
        attribute maximumSweepAngle : Angle = 38.0;
        attribute mechanicalStopAngle : Angle = 45.0;
    }

    part def FlexibleFinSurface {
        port hydrodynamicPort : MechanicalJointPort;

        attribute span : Length = 220.0;
        attribute chord : Length = 90.0;
        attribute thickness : Length = 4.0;
        attribute passiveFlexibility : Real = 0.62;
        attribute nominalThrustAtOneHz : Force = 5.5;
        attribute maximumBendingMoment : Torque = 6.0;
    }

    part def JointEncoder {
        port feedbackPort : FeedbackPort;

        attribute resolution : Angle = 0.05;
        attribute measuredAngle : Angle;
        attribute measuredVelocity : AngularVelocity;
    }

    part def LoadSensor {
        port loadPort : LoadPort;

        attribute liftRange : Force = 25.0;
        attribute dragRange : Force = 20.0;
        attribute momentRange : Torque = 8.0;
    }

    part def LeakAndPressureSensor {
        port leakPort : LeakPort;

        attribute nominalInternalPressure : Pressure = 101.0;
        attribute leakThresholdPressureDrop : Pressure = 8.0;
    }

    part def EmbeddedFinController {
        port commandPort : CommandInputPort;
        port statusPort : StatusOutputPort;
        port feedbackPort : FeedbackPort;
        port loadPort : LoadPort;
        port leakPort : LeakPort;
        port driveCommandPort : MotorDrivePort;

        attribute controlLoopRate : Frequency = 100.0;
        attribute currentMode : FinOperatingMode = FinOperatingMode::idle;
        attribute activeFault : FinFaultCode = FinFaultCode::none;

        perform controlLoop : RoboticFinControlLoop;
        exhibit stateMachine : FinControllerStateMachine;
    }

    part def RoboticFinAssembly {
        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
        port statusOut : StatusOutputPort;
        port waterLoadIn : LoadPort;

        part controller : EmbeddedFinController;
        part motorDriver : MotorDriver;
        part motor : BrushlessServoMotor;
        part gearbox : ReductionGearbox;
        part rootJoint : FinRootJoint;
        part finSurface : FlexibleFinSurface;
        part encoder : JointEncoder;
        part loadSensor : LoadSensor;
        part leakSensor : LeakAndPressureSensor;

        attribute maximumThrust : Force = 12.0;
        attribute nominalCruiseThrust : Force = 4.0;
        attribute maximumSweepAmplitude : Angle = 35.0;
        attribute nominalFlapFrequency : Frequency = 1.2;
        attribute maximumFlapFrequency : Frequency = 3.0;
        attribute operatingVoltage : Voltage = 24.0;
        attribute dryMass : Real = 1.4;
        attribute primaryFunction : String = "Convert electrical command energy into controlled oscillatory fin motion that produces hydrodynamic thrust and directional maneuvering force for an underwater vehicle.";

        connect powerIn.powerIn to motorDriver.powerPort.powerIn;
        connect commandIn.commandIn to controller.commandPort.commandIn;
        connect controller.statusPort.statusOut to statusOut.statusOut;
        connect controller.driveCommandPort.driveOut to motorDriver.commandPort.driveOut;
        connect motorDriver.commandPort.driveOut to motor.drivePort.driveOut;
        connect motor.shaftFeedbackPort.feedbackIn to encoder.feedbackPort.feedbackIn;
        connect encoder.feedbackPort.feedbackIn to controller.feedbackPort.feedbackIn;
        connect rootJoint.feedbackPort.feedbackIn to controller.feedbackPort.feedbackIn;
        connect waterLoadIn.loadIn to loadSensor.loadPort.loadIn;
        connect loadSensor.loadPort.loadIn to controller.loadPort.loadIn;
        connect loadSensor.loadPort.loadIn to rootJoint.loadPort.loadIn;
        connect leakSensor.leakPort.leakIn to controller.leakPort.leakIn;
        connect rootJoint.loadPort.loadIn to finSurface.hydrodynamicPort.loadOut;
    }

    part def UnderwaterVehicleWithRoboticFin {
        part roboticFin : RoboticFinAssembly;

        port vehiclePower : PowerInputPort;
        port vehicleCommand : CommandInputPort;
        port vehicleFinStatus : StatusOutputPort;
        port externalWaterLoad : LoadPort;

        connect vehiclePower.powerIn to roboticFin.powerIn.powerIn;
        connect vehicleCommand.commandIn to roboticFin.commandIn.commandIn;
        connect roboticFin.statusOut.statusOut to vehicleFinStatus.statusOut;
        connect externalWaterLoad.loadIn to roboticFin.waterLoadIn.loadIn;
    }

    requirement def PrimaryFunctionRequirement {
        subject fin : RoboticFinAssembly;
        doc /* The robotic fin shall generate controlled oscillatory motion to produce hydrodynamic thrust and maneuvering force for an underwater vehicle. */
        require constraint {
            fin.maximumThrust >= 10.0 and
            fin.maximumSweepAmplitude >= 30.0 and
            fin.maximumFlapFrequency >= 2.5
        }
    }

    requirement def SweepControlRequirement {
        subject fin : RoboticFinAssembly;
        doc /* The robotic fin shall track commanded sweep angle during swimming and maneuvering operation. */
        require constraint {
            fin.maximumSweepAmplitude <= 35.0
        }
    }

    requirement def SafeCurrentRequirement {
        subject fin : RoboticFinAssembly;
        doc /* The robotic fin drive shall limit continuous motor current during normal swimming operation. */
        require constraint {
            fin.motorDriver.continuousCurrentLimit <= 8.0 and
            fin.motorDriver.peakCurrentLimit <= 15.0
        }
    }

    requirement def LeakProtectionRequirement {
        subject fin : RoboticFinAssembly;
        doc /* The robotic fin shall transition to faulted mode when an internal leak is detected. */
        require constraint {
            fin.controller.activeFault == FinFaultCode::leakDetected implies
            fin.controller.currentMode == FinOperatingMode::faulted
        }
    }

    requirement def ThermalProtectionRequirement {
        subject fin : RoboticFinAssembly;
        doc /* The robotic fin shall stop active thrust generation before actuator temperature exceeds the safe operating limit. */
        require constraint {
            fin.motor.windingTemperature <= 85.0
        }
    }

    requirement def StatusReportingRequirement {
        subject fin : RoboticFinAssembly;
        doc /* The robotic fin shall report operating mode, joint motion, thrust estimate, health, and active fault status to the host vehicle controller. */
        require constraint {
            fin.controller.controlLoopRate >= 50.0
        }
    }

    satisfy PrimaryFunctionRequirement by RoboticFinAssembly;
    satisfy SweepControlRequirement by RoboticFinAssembly;
    satisfy SafeCurrentRequirement by RoboticFinAssembly;
    satisfy LeakProtectionRequirement by RoboticFinAssembly;
    satisfy ThermalProtectionRequirement by RoboticFinAssembly;
    satisfy StatusReportingRequirement by RoboticFinAssembly;

    part roboticFinSystem : UnderwaterVehicleWithRoboticFin;

}