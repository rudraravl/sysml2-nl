package ProbePositioningSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def LengthValue :> Real {
        unit = "m";
    }

    attribute def VelocityValue :> Real {
        unit = "m/s";
    }

    attribute def AccelerationValue :> Real {
        unit = "m/s^2";
    }

    attribute def ForceValue :> Real {
        unit = "N";
    }

    attribute def VoltageValue :> Real {
        unit = "V";
    }

    attribute def CurrentValue :> Real {
        unit = "A";
    }

    attribute def TemperatureValue :> Real {
        unit = "degC";
    }

    attribute def TimeValue :> Real {
        unit = "s";
    }

    attribute def BooleanStatus :> Boolean;

    item def PositionCommand {
        attribute targetX : LengthValue;
        attribute targetY : LengthValue;
        attribute targetZ : LengthValue;
        attribute maxVelocity : VelocityValue;
        attribute maxAcceleration : AccelerationValue;
    }

    item def ProbePose {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute vx : VelocityValue;
        attribute vy : VelocityValue;
        attribute vz : VelocityValue;
    }

    item def ProbeContactSample {
        attribute contactDetected : BooleanStatus;
        attribute contactForce : ForceValue;
        attribute probeDeflection : LengthValue;
        attribute sampleTime : TimeValue;
    }

    item def MotionStatus {
        attribute enabled : BooleanStatus;
        attribute homed : BooleanStatus;
        attribute moving : BooleanStatus;
        attribute inPosition : BooleanStatus;
        attribute faulted : BooleanStatus;
        attribute faultCode : Integer;
    }

    item def PowerDC {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def ThermalStatus {
        attribute controllerTemperature : TemperatureValue;
        attribute actuatorTemperature : TemperatureValue;
        attribute probeTemperature : TemperatureValue;
    }

    port def CommandPort {
        in item command : PositionCommand;
        out item status : MotionStatus;
    }

    port def PosePort {
        out item pose : ProbePose;
    }

    port def ContactPort {
        out item contact : ProbeContactSample;
    }

    port def PowerPort {
        in item power : PowerDC;
    }

    port def MotorDrivePort {
        out item commandedCurrent : CurrentValue;
        in item measuredPosition : LengthValue;
        in item measuredVelocity : VelocityValue;
    }

    port def SensorPort {
        out item measuredPose : ProbePose;
        out item thermal : ThermalStatus;
    }

    port def ProbeInterfacePort {
        out item commandedPose : ProbePose;
        in item contactSample : ProbeContactSample;
    }

    part def LinearAxis {
        attribute travelRange : LengthValue;
        attribute positionResolution : LengthValue;
        attribute maximumVelocity : VelocityValue;
        attribute maximumAcceleration : AccelerationValue;
        attribute maximumDriveForce : ForceValue;
        attribute currentPosition : LengthValue;
        attribute currentVelocity : VelocityValue;

        port powerInput : PowerPort;
        port driveInterface : MotorDrivePort;
    }

    part def ProbeAssembly {
        attribute tipDiameter : LengthValue;
        attribute maximumContactForce : ForceValue;
        attribute nominalPreload : ForceValue;
        attribute deflectionLimit : LengthValue;
        attribute calibrated : BooleanStatus;

        port probeInterface : ProbeInterfacePort;
        port contactOutput : ContactPort;
    }

    part def PositionController {
        attribute controlPeriod : TimeValue;
        attribute followingErrorLimit : LengthValue;
        attribute commandQueueDepth : Integer;
        attribute motionEnabled : BooleanStatus;
        attribute emergencyStopActive : BooleanStatus;

        port commandInterface : CommandPort;
        port poseFeedback : SensorPort;
        port xDrive : MotorDrivePort;
        port yDrive : MotorDrivePort;
        port zDrive : MotorDrivePort;
        port probeInterface : ProbeInterfacePort;
    }

    part def MetrologyFrame {
        attribute baseFlatness : LengthValue;
        attribute orthogonalityErrorXY : Real;
        attribute orthogonalityErrorXZ : Real;
        attribute thermalExpansionCoefficient : Real;
    }

    part def PositionSensorSet {
        attribute linearScaleResolution : LengthValue;
        attribute probeDeflectionResolution : LengthValue;
        attribute samplePeriod : TimeValue;

        port sensorOutput : SensorPort;
    }

    part def SafetyMonitor {
        attribute maximumAllowedForce : ForceValue;
        attribute maximumAllowedTemperature : TemperatureValue;
        attribute limitSwitchActive : BooleanStatus;
        attribute enclosureClosed : BooleanStatus;
        attribute safeToMove : BooleanStatus;

        in item motionStatus : MotionStatus;
        in item contactSample : ProbeContactSample;
        in item thermalStatus : ThermalStatus;
        out item motionPermit : BooleanStatus;
    }

    part def ProbePositioningSystem {
        attribute workspaceX : LengthValue = 0.300;
        attribute workspaceY : LengthValue = 0.200;
        attribute workspaceZ : LengthValue = 0.120;
        attribute positioningAccuracy : LengthValue = 0.000005;
        attribute repeatability : LengthValue = 0.000002;
        attribute maximumProbeForce : ForceValue = 1.5;

        port commandPort : CommandPort;
        port posePort : PosePort;
        port contactPort : ContactPort;
        port powerPort : PowerPort;

        part frame : MetrologyFrame {
            attribute baseFlatness = 0.000003;
            attribute orthogonalityErrorXY = 0.00002;
            attribute orthogonalityErrorXZ = 0.00003;
            attribute thermalExpansionCoefficient = 0.000011;
        }

        part xAxis : LinearAxis {
            attribute travelRange = 0.300;
            attribute positionResolution = 0.0000005;
            attribute maximumVelocity = 0.250;
            attribute maximumAcceleration = 1.200;
            attribute maximumDriveForce = 80.0;
        }

        part yAxis : LinearAxis {
            attribute travelRange = 0.200;
            attribute positionResolution = 0.0000005;
            attribute maximumVelocity = 0.250;
            attribute maximumAcceleration = 1.200;
            attribute maximumDriveForce = 70.0;
        }

        part zAxis : LinearAxis {
            attribute travelRange = 0.120;
            attribute positionResolution = 0.0000002;
            attribute maximumVelocity = 0.120;
            attribute maximumAcceleration = 0.800;
            attribute maximumDriveForce = 50.0;
        }

        part probe : ProbeAssembly {
            attribute tipDiameter = 0.001;
            attribute maximumContactForce = 1.5;
            attribute nominalPreload = 0.15;
            attribute deflectionLimit = 0.002;
            attribute calibrated = true;
        }

        part sensors : PositionSensorSet {
            attribute linearScaleResolution = 0.0000005;
            attribute probeDeflectionResolution = 0.0000001;
            attribute samplePeriod = 0.001;
        }

        part controller : PositionController {
            attribute controlPeriod = 0.001;
            attribute followingErrorLimit = 0.000010;
            attribute commandQueueDepth = 32;
            attribute motionEnabled = false;
            attribute emergencyStopActive = false;
        }

        part safety : SafetyMonitor {
            attribute maximumAllowedForce = 1.5;
            attribute maximumAllowedTemperature = 55.0;
            attribute limitSwitchActive = false;
            attribute enclosureClosed = true;
            attribute safeToMove = true;
        }

        connect commandPort to controller.commandInterface;
        connect powerPort to xAxis.powerInput;
        connect powerPort to yAxis.powerInput;
        connect powerPort to zAxis.powerInput;
        connect controller.xDrive to xAxis.driveInterface;
        connect controller.yDrive to yAxis.driveInterface;
        connect controller.zDrive to zAxis.driveInterface;
        connect sensors.sensorOutput to controller.poseFeedback;
        connect controller.probeInterface to probe.probeInterface;
        connect probe.contactOutput to contactPort;
        connect sensors.sensorOutput.measuredPose to posePort.pose;
        connect probe.contactOutput.contact to safety.contactSample;
        connect sensors.sensorOutput.thermal to safety.thermalStatus;
        connect controller.commandInterface.status to safety.motionStatus;
    }

    action def HomeAxes {
        in item permit : BooleanStatus;
        out item homedStatus : MotionStatus;

        first start;
        then verifyPermit;
        then moveXToReference;
        then moveYToReference;
        then moveZToReference;
        then setMachineZero;
        then complete;

        action verifyPermit;
        action moveXToReference;
        action moveYToReference;
        action moveZToReference;
        action setMachineZero;
        action complete;
    }

    action def ExecuteProbeMove {
        in item command : PositionCommand;
        in item currentPose : ProbePose;
        out item finalPose : ProbePose;
        out item status : MotionStatus;

        first receiveCommand;
        then validateWorkspaceLimits;
        then generateTrajectory;
        then servoX;
        then servoY;
        then servoZ;
        then monitorContact;
        then settleAtTarget;
        then reportStatus;

        action receiveCommand;
        action validateWorkspaceLimits;
        action generateTrajectory;
        action servoX;
        action servoY;
        action servoZ;
        action monitorContact;
        action settleAtTarget;
        action reportStatus;
    }

    action def ProbeSurface {
        in item approachCommand : PositionCommand;
        out item measuredContact : ProbeContactSample;
        out item contactPose : ProbePose;

        first approachSurface;
        then reduceVelocity;
        then detectDeflection;
        then captureContactPose;
        then retractProbe;
        then publishMeasurement;

        action approachSurface;
        action reduceVelocity;
        action detectDeflection;
        action captureContactPose;
        action retractProbe;
        action publishMeasurement;
    }

    state def PositioningLifecycle {
        entry action initializeElectronics;
        state Off;
        state Initializing;
        state Ready;
        state Homing;
        state Idle;
        state Moving;
        state Probing;
        state HoldingPosition;
        state Fault;
        state EmergencyStopped;

        transition first Off then Initializing;
        transition Initializing then Ready;
        transition Ready then Homing;
        transition Homing then Idle;
        transition Idle then Moving;
        transition Moving then HoldingPosition;
        transition HoldingPosition then Idle;
        transition Idle then Probing;
        transition Probing then Idle;
        transition Moving then Fault;
        transition Probing then Fault;
        transition Fault then Idle;
        transition Idle then EmergencyStopped;
        transition Moving then EmergencyStopped;
        transition Probing then EmergencyStopped;
        transition EmergencyStopped then Initializing;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The probe positioning system shall precisely position a measurement probe within a three-axis workspace so that the probe tip reaches commanded coordinates, maintains controlled motion, detects contact with a target surface, and reports probe pose and contact status to an external measurement controller. */
    }

    requirement def WorkspaceRequirement {
        attribute requiredXTravel : LengthValue = 0.300;
        attribute requiredYTravel : LengthValue = 0.200;
        attribute requiredZTravel : LengthValue = 0.120;

        require constraint {
            requiredXTravel <= 0.300 and
            requiredYTravel <= 0.200 and
            requiredZTravel <= 0.120
        }
    }

    requirement def AccuracyRequirement {
        attribute maximumPositionError : LengthValue = 0.000005;
        attribute maximumRepeatabilityError : LengthValue = 0.000002;

        require constraint {
            maximumPositionError <= 0.000005 and
            maximumRepeatabilityError <= 0.000002
        }
    }

    requirement def ForceLimitingRequirement {
        attribute allowedContactForce : ForceValue = 1.5;

        require constraint {
            allowedContactForce <= 1.5
        }
    }

    requirement def SafetyRequirement {
        attribute allowedTemperature : TemperatureValue = 55.0;
        attribute emergencyStopResponseTime : TimeValue = 0.050;

        require constraint {
            allowedTemperature <= 55.0 and
            emergencyStopResponseTime <= 0.050
        }
    }

    requirement def StatusReportingRequirement {
        doc /* The system shall continuously report motion enabled state, homed state, moving state, in-position state, fault state, current pose, and probe contact samples during operation. */
    }

    satisfy PrimaryFunctionRequirement by ProbePositioningSystem;
    satisfy WorkspaceRequirement by ProbePositioningSystem;
    satisfy AccuracyRequirement by ProbePositioningSystem;
    satisfy ForceLimitingRequirement by ProbePositioningSystem.probe;
    satisfy SafetyRequirement by ProbePositioningSystem.safety;
    satisfy StatusReportingRequirement by ProbePositioningSystem.controller;

    perform action HomeAxes by ProbePositioningSystem.controller;
    perform action ExecuteProbeMove by ProbePositioningSystem.controller;
    perform action ProbeSurface by ProbePositioningSystem.probe;
    exhibit state PositioningLifecycle by ProbePositioningSystem;
}