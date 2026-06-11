package Segs4VetsMobilitySystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Mass :> ISQ::mass {
        unit = SI::kg;
    }

    attribute def Length :> ISQ::length {
        unit = SI::m;
    }

    attribute def Speed :> ISQ::speed {
        unit = SI::m / SI::s;
    }

    attribute def Acceleration :> ISQ::acceleration {
        unit = SI::m / SI::s^2;
    }

    attribute def Time :> ISQ::time {
        unit = SI::s;
    }

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = SI::V;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = SI::A;
    }

    attribute def Energy :> ISQ::energy {
        unit = SI::J;
    }

    attribute def Power :> ISQ::power {
        unit = SI::W;
    }

    attribute def Angle :> ISQ::planeAngle {
        unit = SI::rad;
    }

    attribute def Percent :> ScalarValues::Real;

    attribute def BooleanStatus :> ScalarValues::Boolean;

    enum def TerrainKind {
        enum smoothIndoor;
        enum sidewalk;
        enum ramp;
        enum grass;
        enum gravel;
        enum curbApproach;
    }

    enum def MobilityMode {
        enum poweredOff;
        enum standby;
        enum assistedBalance;
        enum userControlledTravel;
        enum controlledStop;
        enum emergencyStop;
        enum maintenanceLockout;
        enum charging;
    }

    enum def AlertSeverity {
        enum advisory;
        enum caution;
        enum warning;
        enum critical;
    }

    item def ElectricalEnergy {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute storedEnergy : Energy;
        attribute stateOfCharge : Percent;
    }

    item def MotionCommand {
        attribute requestedSpeed : Speed;
        attribute requestedYawRate : Angle;
        attribute forwardLean : Angle;
        attribute lateralLean : Angle;
        attribute brakeRequested : BooleanStatus;
    }

    item def RiderSupportLoad {
        attribute riderMass : Mass;
        attribute supportForce : ISQ::force;
        attribute centerOfMassOffset : Length;
    }

    item def StabilityTelemetry {
        attribute pitchAngle : Angle;
        attribute rollAngle : Angle;
        attribute yawRate : Angle;
        attribute wheelSpeedLeft : Speed;
        attribute wheelSpeedRight : Speed;
        attribute platformAcceleration : Acceleration;
        attribute stable : BooleanStatus;
    }

    item def NavigationContext {
        attribute terrain : TerrainKind;
        attribute slopeAngle : Angle;
        attribute obstacleDistance : Length;
        attribute ambientLightLevel : ScalarValues::Real;
    }

    item def UserAlert {
        attribute severity : AlertSeverity;
        attribute messageCode : ScalarValues::String;
        attribute audible : BooleanStatus;
        attribute haptic : BooleanStatus;
        attribute visual : BooleanStatus;
    }

    port def PowerInputPort {
        in item suppliedEnergy : ElectricalEnergy;
    }

    port def PowerOutputPort {
        out item deliveredEnergy : ElectricalEnergy;
    }

    port def CommandInputPort {
        in item command : MotionCommand;
    }

    port def TelemetryOutputPort {
        out item telemetry : StabilityTelemetry;
    }

    port def RiderInterfacePort {
        in item riderLoad : RiderSupportLoad;
        out item alert : UserAlert;
    }

    port def EnvironmentSensingPort {
        in item context : NavigationContext;
    }

    port def DrivePort {
        in item driveEnergy : ElectricalEnergy;
        in item driveCommand : MotionCommand;
        out item wheelTelemetry : StabilityTelemetry;
    }

    part def BatteryPack {
        attribute nominalVoltage : ElectricPotential = 72 [SI::V];
        attribute usableEnergy : Energy = 1800000 [SI::J];
        attribute maximumDischargePower : Power = 2500 [SI::W];
        attribute maximumChargeCurrent : ElectricCurrent = 8 [SI::A];
        attribute stateOfCharge : Percent;
        attribute temperatureCelsius : ScalarValues::Real;
        attribute healthy : BooleanStatus;

        port powerOut : PowerOutputPort;
        port chargeIn : PowerInputPort;
    }

    part def Charger {
        attribute inputVoltage : ElectricPotential = 120 [SI::V];
        attribute outputVoltage : ElectricPotential = 72 [SI::V];
        attribute outputCurrentLimit : ElectricCurrent = 8 [SI::A];

        port gridInput : PowerInputPort;
        port chargeOutput : PowerOutputPort;
    }

    part def WheelMotor {
        attribute ratedPower : Power = 1200 [SI::W];
        attribute peakPower : Power = 2000 [SI::W];
        attribute maximumWheelSpeed : Speed = 5.4 [SI::m / SI::s];
        attribute motorTemperatureCelsius : ScalarValues::Real;

        port drive : DrivePort;
    }

    part def InertialMeasurementUnit {
        attribute pitchAccuracy : Angle = 0.01 [SI::rad];
        attribute rollAccuracy : Angle = 0.01 [SI::rad];
        attribute yawRateAccuracy : Angle = 0.02 [SI::rad];

        port telemetryOut : TelemetryOutputPort;
    }

    part def ObstacleSensorSet {
        attribute minimumDetectionDistance : Length = 0.15 [SI::m];
        attribute maximumDetectionDistance : Length = 6.0 [SI::m];

        port environmentIn : EnvironmentSensingPort;
    }

    part def BalanceController {
        attribute controlLoopPeriod : Time = 0.01 [SI::s];
        attribute maximumAllowedPitch : Angle = 0.35 [SI::rad];
        attribute maximumAllowedRoll : Angle = 0.25 [SI::rad];
        attribute commandedSpeedLimit : Speed = 4.5 [SI::m / SI::s];
        attribute emergencyStopDeceleration : Acceleration = 2.5 [SI::m / SI::s^2];

        port riderCommandIn : CommandInputPort;
        port imuTelemetryIn : TelemetryOutputPort;
        port environmentIn : EnvironmentSensingPort;
        port motorCommandOutLeft : CommandInputPort;
        port motorCommandOutRight : CommandInputPort;
        port alertOut : RiderInterfacePort;
    }

    part def RiderSupportAssembly {
        attribute supportedRiderMassMinimum : Mass = 45 [SI::kg];
        attribute supportedRiderMassMaximum : Mass = 125 [SI::kg];
        attribute handlebarHeightMinimum : Length = 0.9 [SI::m];
        attribute handlebarHeightMaximum : Length = 1.25 [SI::m];
        attribute platformWidth : Length = 0.62 [SI::m];
        attribute platformLength : Length = 0.54 [SI::m];

        port riderInterface : RiderInterfacePort;
        port commandOut : CommandInputPort;
    }

    part def UserDisplayAndAlertUnit {
        attribute visualDisplayActive : BooleanStatus;
        attribute audibleAlarmLevel : ScalarValues::Real;
        attribute hapticMotorEnabled : BooleanStatus;

        port riderInterface : RiderInterfacePort;
    }

    part def TransportFrame {
        attribute frameMass : Mass = 22 [SI::kg];
        attribute totalSystemMass : Mass = 55 [SI::kg];
        attribute wheelTrackWidth : Length = 0.64 [SI::m];
        attribute groundClearance : Length = 0.08 [SI::m];
        attribute maximumStaticLoad : Mass = 140 [SI::kg];
    }

    action def PowerUp {
        in item batteryEnergy : ElectricalEnergy;
        out mode : MobilityMode;
        first start;
        then verifyBattery;
        then verifySensors;
        then enableBalanceController;
        then done;

        action verifyBattery;
        action verifySensors;
        action enableBalanceController;
    }

    action def InterpretRiderIntent {
        in item riderLoad : RiderSupportLoad;
        out item command : MotionCommand;
        first measureLean;
        then calculateRequestedMotion;
        then limitUnsafeCommand;
        then done;

        action measureLean;
        action calculateRequestedMotion;
        action limitUnsafeCommand;
    }

    action def MaintainDynamicBalance {
        in item command : MotionCommand;
        in item telemetry : StabilityTelemetry;
        in item context : NavigationContext;
        out item correctedCommand : MotionCommand;
        first estimatePose;
        then computeBalanceCorrection;
        then compensateForTerrain;
        then commandDriveMotors;
        then done;

        action estimatePose;
        action computeBalanceCorrection;
        action compensateForTerrain;
        action commandDriveMotors;
    }

    action def ControlledEmergencyStop {
        in item telemetry : StabilityTelemetry;
        out item alert : UserAlert;
        first reduceMotorTorque;
        then holdUprightUntilStopped;
        then notifyRider;
        then done;

        action reduceMotorTorque;
        action holdUprightUntilStopped;
        action notifyRider;
    }

    state def MobilityOperatingStateMachine {
        attribute mode : MobilityMode;

        state off;
        state standby;
        state balancing;
        state traveling;
        state stopping;
        state emergency;
        state charging;
        state lockout;

        transition initial then off;

        transition powerButtonPressed
            first off
            accept;
            then standby;

        transition chargerConnected
            first off
            accept;
            then charging;

        transition selfTestPassed
            first standby
            accept;
            then balancing;

        transition riderCommandDetected
            first balancing
            accept;
            then traveling;

        transition riderCommandNeutral
            first traveling
            accept;
            then balancing;

        transition normalStopRequested
            first traveling
            accept;
            then stopping;

        transition stoppedAndStable
            first stopping
            accept;
            then balancing;

        transition unsafePitchOrRoll
            first balancing
            accept;
            then emergency;

        transition unsafePitchOrRollDuringTravel
            first traveling
            accept;
            then emergency;

        transition lowBatteryCritical
            first traveling
            accept;
            then emergency;

        transition maintenanceFault
            first standby
            accept;
            then lockout;

        transition maintenanceReset
            first lockout
            accept;
            then standby;

        transition powerButtonHeld
            first standby
            accept;
            then off;
    }

    part def Segs4VetsPersonalMobilityDevice {
        attribute primaryFunction : ScalarValues::String =
            "Provide upright, self-balancing, electrically powered personal mobility assistance for an injured veteran, enabling controlled travel across accessible indoor and outdoor surfaces with continuous stabilization and rider safety monitoring.";

        attribute maximumUserMass : Mass = 125 [SI::kg];
        attribute maximumSpeed : Speed = 4.5 [SI::m / SI::s];
        attribute minimumTurningRadius : Length = 0.0 [SI::m];
        attribute maximumClimbSlope : Angle = 0.17 [SI::rad];
        attribute operatingRangeEnergyBasis : Energy = 1800000 [SI::J];
        attribute allowableOperatingTemperatureLow : ScalarValues::Real = -10;
        attribute allowableOperatingTemperatureHigh : ScalarValues::Real = 40;

        part frame : TransportFrame;
        part battery : BatteryPack;
        part charger : Charger;
        part leftMotor : WheelMotor;
        part rightMotor : WheelMotor;
        part imu : InertialMeasurementUnit;
        part obstacleSensors : ObstacleSensorSet;
        part controller : BalanceController;
        part riderSupport : RiderSupportAssembly;
        part alerts : UserDisplayAndAlertUnit;

        port riderPort : RiderInterfacePort;
        port environmentPort : EnvironmentSensingPort;
        port externalChargePort : PowerInputPort;
        port telemetryPort : TelemetryOutputPort;

        perform action powerUp : PowerUp;
        perform action interpretIntent : InterpretRiderIntent;
        perform action maintainBalance : MaintainDynamicBalance;
        perform action emergencyStop : ControlledEmergencyStop;

        exhibit state machine operatingState : MobilityOperatingStateMachine;

        connect externalChargePort to charger.gridInput;
        connect charger.chargeOutput to battery.chargeIn;
        connect battery.powerOut to leftMotor.drive;
        connect battery.powerOut to rightMotor.drive;

        connect riderPort to riderSupport.riderInterface;
        connect riderSupport.commandOut to controller.riderCommandIn;
        connect controller.motorCommandOutLeft to leftMotor.drive;
        connect controller.motorCommandOutRight to rightMotor.drive;

        connect imu.telemetryOut to controller.imuTelemetryIn;
        connect imu.telemetryOut to telemetryPort;
        connect obstacleSensors.environmentIn to environmentPort;
        connect environmentPort to controller.environmentIn;

        connect controller.alertOut to alerts.riderInterface;
        connect alerts.riderInterface to riderPort;
    }

    requirement def HighLevelMobilityFunction {
        doc /* The system shall provide self-balancing powered mobility assistance for a veteran with impaired walking capability. */
        subject device : Segs4VetsPersonalMobilityDevice;

        require constraint {
            device.maximumSpeed <= 4.5 [SI::m / SI::s]
        }

        require constraint {
            device.maximumUserMass >= 125 [SI::kg]
        }
    }

    requirement def DynamicStabilityRequirement {
        doc /* The system shall maintain dynamic upright stability during commanded travel, standby balancing, and controlled stopping. */
        subject device : Segs4VetsPersonalMobilityDevice;

        require constraint {
            device.controller.maximumAllowedPitch <= 0.35 [SI::rad]
        }

        require constraint {
            device.controller.maximumAllowedRoll <= 0.25 [SI::rad]
        }

        require constraint {
            device.controller.controlLoopPeriod <= 0.01 [SI::s]
        }
    }

    requirement def RiderSupportRequirement {
        doc /* The system shall support the rider within the specified mass range using an adjustable standing support assembly. */
        subject support : RiderSupportAssembly;

        require constraint {
            support.supportedRiderMassMinimum <= 45 [SI::kg]
        }

        require constraint {
            support.supportedRiderMassMaximum >= 125 [SI::kg]
        }

        require constraint {
            support.handlebarHeightMinimum <= 0.9 [SI::m]
        }

        require constraint {
            support.handlebarHeightMaximum >= 1.25 [SI::m]
        }
    }

    requirement def ControlledStopRequirement {
        doc /* The system shall enter controlled stop or emergency stop when instability, critical low battery, or unsafe obstacle conditions are detected. */
        subject controller : BalanceController;

        require constraint {
            controller.emergencyStopDeceleration <= 2.5 [SI::m / SI::s^2]
        }
    }

    requirement def EnergyAvailabilityRequirement {
        doc /* The system shall carry sufficient stored electrical energy for routine mobility trips between charging events. */
        subject battery : BatteryPack;

        require constraint {
            battery.usableEnergy >= 1800000 [SI::J]
        }

        require constraint {
            battery.nominalVoltage == 72 [SI::V]
        }
    }

    requirement def UserAlertRequirement {
        doc /* The system shall provide visual, audible, or haptic alerts for low battery, unsafe posture, sensor fault, charging status, and emergency stop events. */
        subject alertUnit : UserDisplayAndAlertUnit;

        require constraint {
            alertUnit.visualDisplayActive == true
        }
    }

    requirement def EnvironmentalAwarenessRequirement {
        doc /* The system shall sense nearby obstacles and terrain context to limit commands that could compromise rider safety. */
        subject sensors : ObstacleSensorSet;

        require constraint {
            sensors.minimumDetectionDistance <= 0.15 [SI::m]
        }

        require constraint {
            sensors.maximumDetectionDistance >= 6.0 [SI::m]
        }
    }

    satisfy HighLevelMobilityFunction by Segs4VetsPersonalMobilityDevice;
    satisfy DynamicStabilityRequirement by Segs4VetsPersonalMobilityDevice::controller;
    satisfy RiderSupportRequirement by Segs4VetsPersonalMobilityDevice::riderSupport;
    satisfy ControlledStopRequirement by Segs4VetsPersonalMobilityDevice::controller;
    satisfy EnergyAvailabilityRequirement by Segs4VetsPersonalMobilityDevice::battery;
    satisfy UserAlertRequirement by Segs4VetsPersonalMobilityDevice::alerts;
    satisfy EnvironmentalAwarenessRequirement by Segs4VetsPersonalMobilityDevice::obstacleSensors;

}