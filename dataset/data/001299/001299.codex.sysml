package TurnCoordinatorSystemModel {

    import ScalarValues::*;
    import SI::*;

    /* Value and item definitions */

    attribute def Angle {
        :>> unit = rad;
    }

    attribute def AngularRate {
        :>> unit = rad / s;
    }

    attribute def Acceleration {
        :>> unit = m / s^2;
    }

    attribute def Voltage {
        :>> unit = V;
    }

    attribute def Current {
        :>> unit = A;
    }

    attribute def Luminance {
        :>> unit = cd / m^2;
    }

    attribute def TimeDuration {
        :>> unit = s;
    }

    attribute def ValidityCode {
        attribute isValid : Boolean;
        attribute faultCode : String;
    }

    item def AircraftMotionSignal {
        attribute rollRate : AngularRate;
        attribute yawRate : AngularRate;
        attribute lateralAcceleration : Acceleration;
        attribute timestamp : TimeDuration;
        attribute validity : ValidityCode;
    }

    item def ElectricalPower {
        attribute supplyVoltage : Voltage;
        attribute supplyCurrent : Current;
        attribute powerAvailable : Boolean;
    }

    item def LightingCommand {
        attribute dimmingLevel : Real;
    }

    item def TurnIndication {
        attribute indicatedTurnRate : AngularRate;
        attribute bankTrendAngle : Angle;
        attribute leftStandardRateReached : Boolean;
        attribute rightStandardRateReached : Boolean;
        attribute indicationValid : Boolean;
    }

    item def SlipSkidIndication {
        attribute lateralDeflection : Angle;
        attribute centered : Boolean;
        attribute indicationValid : Boolean;
    }

    item def PilotVisualCue {
        attribute symbolicAircraftAngle : Angle;
        attribute slipSkidBallOffset : Angle;
        attribute standardRateMarkerLeftActive : Boolean;
        attribute standardRateMarkerRightActive : Boolean;
        attribute brightness : Luminance;
        attribute cautionFlagVisible : Boolean;
    }

    item def MaintenanceStatus {
        attribute builtInTestPassed : Boolean;
        attribute sensorFault : Boolean;
        attribute displayFault : Boolean;
        attribute powerFault : Boolean;
        attribute calibrationDue : Boolean;
    }

    /* Ports */

    port def AircraftMotionInputPort {
        in item motion : AircraftMotionSignal;
    }

    port def ElectricalPowerInputPort {
        in item power : ElectricalPower;
    }

    port def LightingInputPort {
        in item command : LightingCommand;
    }

    port def TurnIndicationPort {
        out item turn : TurnIndication;
    }

    port def SlipSkidIndicationPort {
        out item slipSkid : SlipSkidIndication;
    }

    port def PilotDisplayPort {
        out item cue : PilotVisualCue;
    }

    port def MaintenanceOutputPort {
        out item status : MaintenanceStatus;
    }

    /* Primary action behavior */

    action def CoordinateTurnIndication {
        in item sensedMotion : AircraftMotionSignal;
        in item powerInput : ElectricalPower;
        in item lightingInput : LightingCommand;
        out item turnOutput : TurnIndication;
        out item slipSkidOutput : SlipSkidIndication;
        out item visualOutput : PilotVisualCue;
        out item maintenanceOutput : MaintenanceStatus;

        attribute standardRate : AngularRate = 0.05236 [rad / s];
        attribute maximumDisplayAngle : Angle = 0.6109 [rad];
        attribute lateralCenterTolerance : Angle = 0.01745 [rad];

        action validateInputs {
            in item motionIn : AircraftMotionSignal = sensedMotion;
            in item powerIn : ElectricalPower = powerInput;
            out validForIndication : Boolean;
            out powerFaultDetected : Boolean;
        }

        action computeTurnRate {
            in item motionIn : AircraftMotionSignal = sensedMotion;
            out rate : AngularRate;
            out bankTrend : Angle;
        }

        action computeSlipSkid {
            in item motionIn : AircraftMotionSignal = sensedMotion;
            out deflection : Angle;
            out isCentered : Boolean;
        }

        action generateDisplayCue {
            in rate : AngularRate;
            in bankTrend : Angle;
            in deflection : Angle;
            in isCentered : Boolean;
            in validForIndication : Boolean;
            in item lightingIn : LightingCommand = lightingInput;
            out item cue : PilotVisualCue;
        }

        bind turnOutput.indicatedTurnRate = computeTurnRate.rate;
        bind turnOutput.bankTrendAngle = computeTurnRate.bankTrend;
        bind turnOutput.leftStandardRateReached = computeTurnRate.rate <= -standardRate;
        bind turnOutput.rightStandardRateReached = computeTurnRate.rate >= standardRate;
        bind turnOutput.indicationValid = validateInputs.validForIndication;

        bind slipSkidOutput.lateralDeflection = computeSlipSkid.deflection;
        bind slipSkidOutput.centered = computeSlipSkid.isCentered;
        bind slipSkidOutput.indicationValid = validateInputs.validForIndication;

        bind visualOutput = generateDisplayCue.cue;

        bind maintenanceOutput.powerFault = validateInputs.powerFaultDetected;
        bind maintenanceOutput.sensorFault = not sensedMotion.validity.isValid;
        bind maintenanceOutput.displayFault = false;
        bind maintenanceOutput.builtInTestPassed =
            validateInputs.validForIndication and not maintenanceOutput.displayFault;
        bind maintenanceOutput.calibrationDue = false;
    }

    /* State machine behavior */

    state def TurnCoordinatorOperationalStates {
        in item power : ElectricalPower;
        in item motion : AircraftMotionSignal;
        out item status : MaintenanceStatus;

        state off;
        state initializing;
        state selfTest;
        state indicating;
        state degraded;
        state failed;

        initial then off;

        transition off_to_initializing
            first off
            accept when power.powerAvailable
            then initializing;

        transition initializing_to_selfTest
            first initializing
            accept after 2 [s]
            then selfTest;

        transition selfTest_to_indicating
            first selfTest
            accept when power.powerAvailable and motion.validity.isValid
            then indicating;

        transition indicating_to_degraded
            first indicating
            accept when power.powerAvailable and not motion.validity.isValid
            then degraded;

        transition degraded_to_indicating
            first degraded
            accept when power.powerAvailable and motion.validity.isValid
            then indicating;

        transition any_power_loss_to_off
            first indicating
            accept when not power.powerAvailable
            then off;

        transition degraded_power_loss_to_off
            first degraded
            accept when not power.powerAvailable
            then off;

        transition selfTest_failure_to_failed
            first selfTest
            accept when power.powerAvailable and not motion.validity.isValid
            then failed;

        transition failed_power_cycle_to_off
            first failed
            accept when not power.powerAvailable
            then off;
    }

    /* Part definitions */

    part def RateSensingAssembly {
        port motionIn : AircraftMotionInputPort;
        port sensedRateOut : TurnIndicationPort;

        attribute rollRateMeasurementRange : AngularRate = 1.745 [rad / s];
        attribute yawRateMeasurementRange : AngularRate = 1.745 [rad / s];
        attribute measurementLatency : TimeDuration = 0.080 [s];
        attribute rateAccuracy : AngularRate = 0.00349 [rad / s];
    }

    part def SlipSkidSensor {
        port motionIn : AircraftMotionInputPort;
        port slipSkidOut : SlipSkidIndicationPort;

        attribute lateralAccelerationRange : Acceleration = 9.81 [m / s^2];
        attribute centeredTolerance : Angle = 0.01745 [rad];
        attribute dampingTimeConstant : TimeDuration = 0.450 [s];
    }

    part def SignalProcessor {
        port sensedMotionIn : AircraftMotionInputPort;
        port powerIn : ElectricalPowerInputPort;
        port turnOut : TurnIndicationPort;
        port slipSkidOut : SlipSkidIndicationPort;
        port statusOut : MaintenanceOutputPort;

        attribute standardTurnRate : AngularRate = 0.05236 [rad / s];
        attribute updatePeriod : TimeDuration = 0.050 [s];
        attribute maximumPermittedLatency : TimeDuration = 0.250 [s];

        perform action coordinate : CoordinateTurnIndication;
    }

    part def DisplayAssembly {
        port turnIn : TurnIndicationPort;
        port slipSkidIn : SlipSkidIndicationPort;
        port lightingIn : LightingInputPort;
        port pilotCueOut : PilotDisplayPort;

        attribute minimumBrightness : Luminance = 5 [cd / m^2];
        attribute maximumBrightness : Luminance = 450 [cd / m^2];
        attribute symbolicAircraftMaximumDeflection : Angle = 0.6109 [rad];
        attribute slipSkidBallMaximumDeflection : Angle = 0.3491 [rad];
    }

    part def PowerConditioner {
        port aircraftPowerIn : ElectricalPowerInputPort;
        port conditionedPowerOut : ElectricalPowerInputPort;

        attribute nominalInputVoltage : Voltage = 14 [V];
        attribute minimumOperatingVoltage : Voltage = 10 [V];
        attribute maximumOperatingVoltage : Voltage = 32 [V];
        attribute maximumCurrentDraw : Current = 0.750 [A];
    }

    part def BuiltInTestController {
        port powerIn : ElectricalPowerInputPort;
        port statusIn : MaintenanceOutputPort;
        port maintenanceOut : MaintenanceOutputPort;

        attribute startupTestDuration : TimeDuration = 2 [s];
        attribute periodicTestInterval : TimeDuration = 60 [s];
    }

    part def TurnCoordinator {
        port aircraftMotionInput : AircraftMotionInputPort;
        port aircraftPowerInput : ElectricalPowerInputPort;
        port cockpitLightingInput : LightingInputPort;
        port pilotDisplayOutput : PilotDisplayPort;
        port maintenanceOutput : MaintenanceOutputPort;

        attribute primaryFunction : String =
            "Sense aircraft roll and yaw rate, combine them into a coordinated turn indication, and present the pilot with standard-rate turn and slip-skid cues for maintaining coordinated flight.";
        attribute standardRateTurn : AngularRate = 0.05236 [rad / s];
        attribute requiredStartupTime : TimeDuration = 5 [s];
        attribute maximumIndicationLatency : TimeDuration = 0.250 [s];
        attribute operatingVoltageLow : Voltage = 10 [V];
        attribute operatingVoltageHigh : Voltage = 32 [V];

        part powerConditioner : PowerConditioner;
        part rateSensingAssembly : RateSensingAssembly;
        part slipSkidSensor : SlipSkidSensor;
        part signalProcessor : SignalProcessor;
        part displayAssembly : DisplayAssembly;
        part builtInTestController : BuiltInTestController;

        perform state operationalState : TurnCoordinatorOperationalStates;

        connect aircraftPowerInput to powerConditioner.aircraftPowerIn;
        connect powerConditioner.conditionedPowerOut to signalProcessor.powerIn;
        connect powerConditioner.conditionedPowerOut to builtInTestController.powerIn;

        connect aircraftMotionInput to rateSensingAssembly.motionIn;
        connect aircraftMotionInput to slipSkidSensor.motionIn;
        connect aircraftMotionInput to signalProcessor.sensedMotionIn;

        connect signalProcessor.turnOut to displayAssembly.turnIn;
        connect signalProcessor.slipSkidOut to displayAssembly.slipSkidIn;
        connect cockpitLightingInput to displayAssembly.lightingIn;

        connect displayAssembly.pilotCueOut to pilotDisplayOutput;
        connect signalProcessor.statusOut to builtInTestController.statusIn;
        connect builtInTestController.maintenanceOut to maintenanceOutput;
    }

    /* System context */

    part def AircraftElectricalBus {
        port powerOut : ElectricalPowerInputPort;
        attribute nominalBusVoltage : Voltage = 14 [V];
    }

    part def AircraftMotionEnvironment {
        port motionOut : AircraftMotionInputPort;
        attribute maximumExpectedRollRate : AngularRate = 1.047 [rad / s];
        attribute maximumExpectedYawRate : AngularRate = 0.524 [rad / s];
    }

    part def CockpitLightingController {
        port lightingOut : LightingInputPort;
        attribute normalDimmingLevel : Real = 0.70;
    }

    part def Pilot {
        port visualInput : PilotDisplayPort;
    }

    part def TurnCoordinatorInstallation {
        part aircraftMotion : AircraftMotionEnvironment;
        part electricalBus : AircraftElectricalBus;
        part lightingController : CockpitLightingController;
        part turnCoordinator : TurnCoordinator;
        part pilot : Pilot;

        connect aircraftMotion.motionOut to turnCoordinator.aircraftMotionInput;
        connect electricalBus.powerOut to turnCoordinator.aircraftPowerInput;
        connect lightingController.lightingOut to turnCoordinator.cockpitLightingInput;
        connect turnCoordinator.pilotDisplayOutput to pilot.visualInput;
    }

    /* Requirements */

    requirement def PrimaryFunctionRequirement {
        subject system : TurnCoordinator;

        doc
            /*
             * The turn coordinator shall provide a high-level pilot indication of aircraft turning motion
             * by sensing roll and yaw rate and displaying the direction and approximate rate of turn.
             */

        require constraint {
            system.standardRateTurn == 0.05236 [rad / s]
        }
    }

    requirement def CoordinatedFlightCueRequirement {
        subject system : TurnCoordinator;

        doc
            /*
             * The turn coordinator shall provide a slip-skid cue that enables the pilot to determine
             * whether lateral acceleration is centered during a turn.
             */

        require constraint {
            system.slipSkidSensor.centeredTolerance <= 0.01745 [rad]
        }
    }

    requirement def StandardRateMarkerRequirement {
        subject cue : PilotVisualCue;

        doc
            /*
             * The displayed cue shall identify left and right standard-rate turn conditions.
             */

        require constraint {
            cue.standardRateMarkerLeftActive or cue.standardRateMarkerRightActive or not cue.cautionFlagVisible
        }
    }

    requirement def LatencyRequirement {
        subject system : TurnCoordinator;

        doc
            /*
             * The elapsed time from aircraft motion input to updated pilot visual cue shall not exceed
             * the maximum allowable indication latency during normal operation.
             */

        require constraint {
            system.maximumIndicationLatency <= 0.250 [s]
        }
    }

    requirement def StartupRequirement {
        subject system : TurnCoordinator;

        doc
            /*
             * The turn coordinator shall complete initialization and built-in test within the specified
             * startup time after valid electrical power is applied.
             */

        require constraint {
            system.requiredStartupTime <= 5 [s]
        }
    }

    requirement def PowerCompatibilityRequirement {
        subject system : TurnCoordinator;

        doc
            /*
             * The turn coordinator shall operate from the aircraft electrical bus over the specified
             * voltage range.
             */

        require constraint {
            system.operatingVoltageLow <= 10 [V] and system.operatingVoltageHigh >= 32 [V]
        }
    }

    requirement def FailureIndicationRequirement {
        subject cue : PilotVisualCue;

        doc
            /*
             * The display shall show a caution flag when input data or internal status is invalid.
             */

        require constraint {
            cue.cautionFlagVisible implies not cue.standardRateMarkerLeftActive and not cue.standardRateMarkerRightActive
        }
    }

    requirement def MaintenanceStatusRequirement {
        subject status : MaintenanceStatus;

        doc
            /*
             * The system shall report maintenance status sufficient to distinguish sensor, display,
             * power, calibration, and built-in-test conditions.
             */

        require constraint {
            status.builtInTestPassed or status.sensorFault or status.displayFault or status.powerFault or status.calibrationDue
        }
    }

    satisfy PrimaryFunctionRequirement by TurnCoordinator;
    satisfy CoordinatedFlightCueRequirement by TurnCoordinator;
    satisfy LatencyRequirement by TurnCoordinator;
    satisfy StartupRequirement by TurnCoordinator;
    satisfy PowerCompatibilityRequirement by TurnCoordinator;
}