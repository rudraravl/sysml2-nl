package VariableReluctanceSensingUnitModel {

    enum def SensorTechnology {
        enum variableReluctance;
        enum hallEffect;
        enum optical;
        enum inductiveProximity;
    }

    enum def SignalPolarity {
        enum positiveGoing;
        enum negativeGoing;
        enum bipolar;
    }

    enum def MeasurementStatus {
        enum invalid;
        enum valid;
        enum initializing;
        enum lowSpeedBelowThreshold;
        enum airGapFault;
        enum openCoilFault;
        enum shortCoilFault;
        enum signalNoiseFault;
        enum supplyFault;
    }

    enum def UnitOperatingMode {
        enum unpowered;
        enum startupSelfTest;
        enum waitingForMotion;
        enum measuring;
        enum degraded;
        enum faulted;
    }

    attribute def Time :> Real {
        attribute unitSymbol : String = "s";
    }

    attribute def Frequency :> Real {
        attribute unitSymbol : String = "Hz";
    }

    attribute def Voltage :> Real {
        attribute unitSymbol : String = "V";
    }

    attribute def Current :> Real {
        attribute unitSymbol : String = "A";
    }

    attribute def Resistance :> Real {
        attribute unitSymbol : String = "ohm";
    }

    attribute def Inductance :> Real {
        attribute unitSymbol : String = "H";
    }

    attribute def MagneticFlux :> Real {
        attribute unitSymbol : String = "Wb";
    }

    attribute def MagneticFluxDensity :> Real {
        attribute unitSymbol : String = "T";
    }

    attribute def Length :> Real {
        attribute unitSymbol : String = "mm";
    }

    attribute def RotationalSpeed :> Real {
        attribute unitSymbol : String = "rpm";
    }

    attribute def Angle :> Real {
        attribute unitSymbol : String = "deg";
    }

    attribute def Temperature :> Real {
        attribute unitSymbol : String = "degC";
    }

    attribute def Percent :> Real {
        attribute unitSymbol : String = "%";
    }

    attribute def ToothCount :> Integer {
        attribute unitSymbol : String = "count";
    }

    attribute def Turns :> Integer {
        attribute unitSymbol : String = "turn";
    }

    attribute def DigitalLevel :> Integer {
        attribute unitSymbol : String = "logic";
    }

    attribute def Confidence :> Real {
        attribute unitSymbol : String = "0_to_1";
    }

    item def ShaftMotion {
        attribute angularSpeed : RotationalSpeed;
        attribute angularPosition : Angle;
        attribute acceleration : Real;
        attribute direction : Integer;
        attribute timestamp : Time;
    }

    item def ReluctorGeometry {
        attribute toothCount : ToothCount;
        attribute toothPitchAngle : Angle;
        attribute toothFaceWidth : Length;
        attribute valleyDepth : Length;
        attribute runout : Length;
    }

    item def AirGapCondition {
        attribute nominalGap : Length;
        attribute actualGap : Length;
        attribute maximumAllowedGap : Length;
        attribute minimumAllowedGap : Length;
        attribute gapWithinRange : Boolean;
    }

    item def MagneticFluxWaveform {
        attribute flux : MagneticFlux;
        attribute fluxDensity : MagneticFluxDensity;
        attribute fluxDerivative : Real;
        attribute toothPassFrequency : Frequency;
        attribute polarity : SignalPolarity;
        attribute timestamp : Time;
    }

    item def VrCoilWaveform {
        attribute instantaneousVoltage : Voltage;
        attribute peakToPeakVoltage : Voltage;
        attribute rmsVoltage : Voltage;
        attribute frequency : Frequency;
        attribute zeroCrossingPeriod : Time;
        attribute noiseRms : Voltage;
        attribute polarity : SignalPolarity;
        attribute timestamp : Time;
    }

    item def ConditionedPulseTrain {
        attribute highLevel : DigitalLevel;
        attribute lowLevel : DigitalLevel;
        attribute pulseFrequency : Frequency;
        attribute lastPeriod : Time;
        attribute dutyCycle : Percent;
        attribute missedToothDetected : Boolean;
        attribute timestamp : Time;
    }

    item def SpeedMeasurement {
        attribute measuredSpeed : RotationalSpeed;
        attribute measurementFrequency : Frequency;
        attribute updatePeriod : Time;
        attribute confidence : Confidence;
        attribute status : MeasurementStatus;
        attribute timestamp : Time;
    }

    item def ElectricalSupply {
        attribute voltage : Voltage;
        attribute currentLimit : Current;
        attribute ripple : Voltage;
        attribute enabled : Boolean;
    }

    item def DiagnosticMessage {
        attribute status : MeasurementStatus;
        attribute coilResistance : Resistance;
        attribute signalAmplitude : Voltage;
        attribute airGapEstimate : Length;
        attribute supplyVoltage : Voltage;
        attribute internalTemperature : Temperature;
        attribute timestamp : Time;
    }

    port def RotationalMeasurandPort {
        in item motion : ShaftMotion;
    }

    port def AirGapPort {
        out item gap : AirGapCondition;
    }

    port def MagneticFluxPort {
        out item fluxWaveform : MagneticFluxWaveform;
    }

    port def VrAnalogPort {
        inout item waveform : VrCoilWaveform;
    }

    port def ConditionedPulsePort {
        inout item pulseTrain : ConditionedPulseTrain;
    }

    port def SpeedOutputPort {
        out item measurement : SpeedMeasurement;
    }

    port def PowerInputPort {
        in item supply : ElectricalSupply;
    }

    port def DiagnosticPort {
        out item message : DiagnosticMessage;
    }

    port def ThermalPort {
        in item ambientTemperature : Temperature;
        out item internalTemperature : Temperature;
    }

    action def ModulateMagneticReluctance {
        in item shaftMotion : ShaftMotion;
        in item geometry : ReluctorGeometry;
        in item airGap : AirGapCondition;
        out item fluxWaveform : MagneticFluxWaveform;

        attribute passFrequency : Frequency;
        attribute magneticReluctanceVariation : Percent;
    }

    action def InduceVariableReluctanceVoltage {
        in item fluxWaveform : MagneticFluxWaveform;
        in attribute coilTurns : Turns;
        in attribute coilResistance : Resistance;
        in attribute coilInductance : Inductance;
        out item analogWaveform : VrCoilWaveform;

        attribute inducedVoltageRelation : String = "v = -N * dPhi/dt";
    }

    action def ProtectAndLimitVrInput {
        in item rawWaveform : VrCoilWaveform;
        out item protectedWaveform : VrCoilWaveform;

        attribute positiveClamp : Voltage = 28.0;
        attribute negativeClamp : Voltage = -28.0;
        attribute inputImpedance : Resistance = 100000.0;
    }

    action def FilterVrWaveform {
        in item protectedWaveform : VrCoilWaveform;
        out item filteredWaveform : VrCoilWaveform;

        attribute highPassCorner : Frequency = 5.0;
        attribute lowPassCorner : Frequency = 8000.0;
        attribute minimumAcceptedAmplitude : Voltage = 0.05;
    }

    action def DetectZeroCrossings {
        in item filteredWaveform : VrCoilWaveform;
        out item pulseTrain : ConditionedPulseTrain;

        attribute adaptiveThreshold : Voltage;
        attribute hysteresis : Voltage = 0.020;
        attribute blankingTime : Time = 0.000050;
    }

    action def EstimateRotationalSpeed {
        in item pulseTrain : ConditionedPulseTrain;
        in attribute toothCount : ToothCount;
        out item measurement : SpeedMeasurement;

        attribute speedComputation : String = "rpm = 60 * pulseFrequency / toothCount";
        attribute updatePeriod : Time = 0.010;
    }

    action def DiagnoseVariableReluctanceSensor {
        in item analogWaveform : VrCoilWaveform;
        in attribute coilResistance : Resistance;
        in item supply : ElectricalSupply;
        in item airGap : AirGapCondition;
        out item diagnostic : DiagnosticMessage;

        attribute openCircuitResistanceLimit : Resistance = 5000.0;
        attribute shortCircuitResistanceLimit : Resistance = 50.0;
        attribute minimumSignalAmplitudeAtReferenceSpeed : Voltage = 0.150;
    }

    action def AcquireShaftSpeedUsingVariableReluctanceSensor {
        in item shaftMotion : ShaftMotion;
        in item geometry : ReluctorGeometry;
        in item airGap : AirGapCondition;
        in attribute coilTurns : Turns;
        in attribute coilResistance : Resistance;
        in attribute coilInductance : Inductance;
        in attribute toothCount : ToothCount;
        out item measurement : SpeedMeasurement;
        out item diagnostic : DiagnosticMessage;

        action modulate : ModulateMagneticReluctance;
        action induce : InduceVariableReluctanceVoltage;
        action protect : ProtectAndLimitVrInput;
        action filter : FilterVrWaveform;
        action zeroCross : DetectZeroCrossings;
        action estimate : EstimateRotationalSpeed;
        action diagnose : DiagnoseVariableReluctanceSensor;

        flow shaftMotion to modulate.shaftMotion;
        flow geometry to modulate.geometry;
        flow airGap to modulate.airGap;
        flow modulate.fluxWaveform to induce.fluxWaveform;
        flow coilTurns to induce.coilTurns;
        flow coilResistance to induce.coilResistance;
        flow coilInductance to induce.coilInductance;
        flow induce.analogWaveform to protect.rawWaveform;
        flow protect.protectedWaveform to filter.protectedWaveform;
        flow filter.filteredWaveform to zeroCross.filteredWaveform;
        flow zeroCross.pulseTrain to estimate.pulseTrain;
        flow toothCount to estimate.toothCount;
        flow estimate.measurement to measurement;
        flow induce.analogWaveform to diagnose.analogWaveform;
        flow coilResistance to diagnose.coilResistance;
        flow airGap to diagnose.airGap;
        flow diagnose.diagnostic to diagnostic;
    }

    state def SensingUnitStateMachine {
        attribute mode : UnitOperatingMode;

        entry state initial;
        state unpowered;
        state startupSelfTest;
        state waitingForMotion;
        state measuring;
        state degraded;
        state faulted;

        transition initial then unpowered;

        transition unpowered then startupSelfTest
            accept ElectricalSupply
            if supply.enabled == true;

        transition startupSelfTest then waitingForMotion
            if supply.voltage >= 4.75 and supply.voltage <= 5.25;

        transition startupSelfTest then faulted
            if supply.voltage < 4.75 or supply.voltage > 5.25;

        transition waitingForMotion then measuring
            accept VrCoilWaveform
            if waveform.peakToPeakVoltage >= 0.050;

        transition measuring then waitingForMotion
            accept VrCoilWaveform
            if waveform.peakToPeakVoltage < 0.050;

        transition measuring then degraded
            accept DiagnosticMessage
            if message.status == MeasurementStatus::signalNoiseFault or message.status == MeasurementStatus::airGapFault;

        transition degraded then measuring
            accept DiagnosticMessage
            if message.status == MeasurementStatus::valid;

        transition measuring then faulted
            accept DiagnosticMessage
            if message.status == MeasurementStatus::openCoilFault or message.status == MeasurementStatus::shortCoilFault or message.status == MeasurementStatus::supplyFault;

        transition faulted then startupSelfTest
            accept ElectricalSupply
            if supply.enabled == true and supply.voltage >= 4.75 and supply.voltage <= 5.25;
    }

    constraint def ToothPassFrequencyConstraint {
        in speed : RotationalSpeed;
        in toothCount : ToothCount;
        in frequency : Frequency;

        speed >= 0.0 and frequency == speed * toothCount / 60.0;
    }

    constraint def VrVoltageGenerationConstraint {
        in inducedVoltage : Voltage;
        in coilTurns : Turns;
        in fluxDerivative : Real;

        inducedVoltage == -1.0 * coilTurns * fluxDerivative;
    }

    constraint def SpeedAccuracyConstraint {
        in actualSpeed : RotationalSpeed;
        in measuredSpeed : RotationalSpeed;
        in maximumError : Percent;

        actualSpeed >= 60.0 implies abs(measuredSpeed - actualSpeed) <= actualSpeed * maximumError / 100.0;
    }

    constraint def AirGapValidityConstraint {
        in actualGap : Length;
        in minimumGap : Length;
        in maximumGap : Length;
        in gapWithinRange : Boolean;

        gapWithinRange == (actualGap >= minimumGap and actualGap <= maximumGap);
    }

    part def FerromagneticReluctorWheel {
        port shaftInput : RotationalMeasurandPort;
        port gapOutput : AirGapPort;
        port fluxOutput : MagneticFluxPort;

        attribute geometry : ReluctorGeometry;
        attribute toothCount : ToothCount = 60;
        attribute toothPitchAngle : Angle = 6.0;
        attribute toothFaceWidth : Length = 2.5;
        attribute valleyDepth : Length = 1.2;
        attribute runout : Length = 0.05;
        attribute materialRelativePermeability : Real = 850.0;
        attribute maximumContinuousSpeed : RotationalSpeed = 12000.0;

        action reluctanceModulation : ModulateMagneticReluctance;

        constraint toothPitchDefinition {
            toothPitchAngle == 360.0 / toothCount;
        }
    }

    part def PermanentMagnet {
        attribute remanentFluxDensity : MagneticFluxDensity = 1.20;
        attribute coercivity : Real = 900000.0;
        attribute operatingTemperatureMinimum : Temperature = -40.0;
        attribute operatingTemperatureMaximum : Temperature = 150.0;
        attribute length : Length = 12.0;
        attribute diameter : Length = 5.0;
    }

    part def PolePiece {
        attribute tipDiameter : Length = 2.0;
        attribute length : Length = 18.0;
        attribute relativePermeability : Real = 1200.0;
        attribute saturationFluxDensity : MagneticFluxDensity = 1.60;
    }

    part def SensingCoil {
        port coilTerminals : VrAnalogPort;

        attribute turns : Turns = 1800;
        attribute resistanceAt20C : Resistance = 850.0;
        attribute inductance : Inductance = 0.320;
        attribute wireDiameter : Length = 0.071;
        attribute maximumInsulationTemperature : Temperature = 180.0;
        attribute openCircuitResistanceLimit : Resistance = 5000.0;
        attribute shortCircuitResistanceLimit : Resistance = 50.0;
    }

    part def VariableReluctancePickup {
        port magneticInput : MagneticFluxPort;
        port airGapInput : AirGapPort;
        port analogOutput : VrAnalogPort;
        port thermal : ThermalPort;

        part magnet : PermanentMagnet;
        part polePiece : PolePiece;
        part coil : SensingCoil;

        attribute technology : SensorTechnology = SensorTechnology::variableReluctance;
        attribute nominalAirGap : Length = 0.50;
        attribute minimumAirGap : Length = 0.25;
        attribute maximumAirGap : Length = 1.50;
        attribute referenceSpeed : RotationalSpeed = 1000.0;
        attribute minimumUsableSpeed : RotationalSpeed = 60.0;
        attribute outputAtReferenceSpeed : Voltage = 2.50;
        attribute selfPoweredTransducer : Boolean = true;
        attribute requiresBiasMagnet : Boolean = true;

        action electromagneticInduction : InduceVariableReluctanceVoltage;

        constraint airGapAllowed : AirGapValidityConstraint {
            in actualGap = nominalAirGap;
            in minimumGap = minimumAirGap;
            in maximumGap = maximumAirGap;
        }

        connect coil.coilTerminals to analogOutput;
    }

    part def InputProtectionNetwork {
        port rawInput : VrAnalogPort;
        port protectedOutput : VrAnalogPort;

        attribute seriesResistance : Resistance = 1000.0;
        attribute positiveClampVoltage : Voltage = 28.0;
        attribute negativeClampVoltage : Voltage = -28.0;
        attribute electrostaticDischargeWithstand : Voltage = 8000.0;

        action protect : ProtectAndLimitVrInput;
    }

    part def AnalogFilter {
        port analogInput : VrAnalogPort;
        port analogOutput : VrAnalogPort;

        attribute highPassCorner : Frequency = 5.0;
        attribute lowPassCorner : Frequency = 8000.0;
        attribute gain : Real = 2.0;
        attribute inputNoiseDensity : Real = 0.000000025;

        action filter : FilterVrWaveform;
    }

    part def AdaptiveZeroCrossingComparator {
        port analogInput : VrAnalogPort;
        port pulseOutput : ConditionedPulsePort;

        attribute hysteresis : Voltage = 0.020;
        attribute minimumRecognizedPeakToPeak : Voltage = 0.050;
        attribute propagationDelay : Time = 0.000005;
        attribute blankingTime : Time = 0.000050;
        attribute outputHighLevel : DigitalLevel = 1;
        attribute outputLowLevel : DigitalLevel = 0;

        action zeroCrossingDetection : DetectZeroCrossings;
    }

    part def VariableReluctanceSignalConditioner {
        port rawVrInput : VrAnalogPort;
        port conditionedPulseOutput : ConditionedPulsePort;
        port power : PowerInputPort;
        port thermal : ThermalPort;

        part inputProtection : InputProtectionNetwork;
        part bandPassFilter : AnalogFilter;
        part comparator : AdaptiveZeroCrossingComparator;

        attribute minimumSupplyVoltage : Voltage = 4.75;
        attribute nominalSupplyVoltage : Voltage = 5.0;
        attribute maximumSupplyVoltage : Voltage = 5.25;
        attribute operatingCurrent : Current = 0.015;
        attribute inputCommonModeRange : Voltage = 24.0;

        connect rawVrInput to inputProtection.rawInput;
        connect inputProtection.protectedOutput to bandPassFilter.analogInput;
        connect bandPassFilter.analogOutput to comparator.analogInput;
        connect comparator.pulseOutput to conditionedPulseOutput;
    }

    part def PeriodTimer {
        port pulseInput : ConditionedPulsePort;

        attribute clockFrequency : Frequency = 1000000.0;
        attribute periodResolution : Time = 0.000001;
        attribute timeoutPeriod : Time = 0.250;
        attribute lastMeasuredPeriod : Time;
    }

    part def SpeedEstimator {
        port pulseInput : ConditionedPulsePort;
        port speedOutput : SpeedOutputPort;

        attribute configuredToothCount : ToothCount = 60;
        attribute updatePeriod : Time = 0.010;
        attribute averagingWindowPulses : Integer = 4;
        attribute minimumReportedSpeed : RotationalSpeed = 60.0;
        attribute maximumReportedSpeed : RotationalSpeed = 12000.0;
        attribute accuracyAboveMinimumSpeed : Percent = 1.0;

        part timer : PeriodTimer;

        action estimateSpeed : EstimateRotationalSpeed;

        constraint frequencyToSpeed : ToothPassFrequencyConstraint {
            in toothCount = configuredToothCount;
        }

        connect pulseInput to timer.pulseInput;
    }

    part def SensorDiagnostics {
        port analogInput : VrAnalogPort;
        port pulseInput : ConditionedPulsePort;
        port power : PowerInputPort;
        port diagnosticOutput : DiagnosticPort;

        attribute coilResistanceMeasured : Resistance = 850.0;
        attribute minimumExpectedAmplitudeAt60rpm : Voltage = 0.050;
        attribute minimumExpectedAmplitudeAt1000rpm : Voltage = 0.800;
        attribute noiseFaultThreshold : Voltage = 0.100;
        attribute maximumMissingPulses : Integer = 2;
        attribute internalTemperature : Temperature = 35.0;

        action diagnose : DiagnoseVariableReluctanceSensor;
    }

    part def VariableReluctanceSensingUnit {
        port shaftInput : RotationalMeasurandPort;
        port powerInput : PowerInputPort;
        port speedOutput : SpeedOutputPort;
        port diagnosticOutput : DiagnosticPort;
        port thermal : ThermalPort;

        part targetWheel : FerromagneticReluctorWheel;
        part pickup : VariableReluctancePickup;
        part conditioner : VariableReluctanceSignalConditioner;
        part estimator : SpeedEstimator;
        part diagnostics : SensorDiagnostics;

        attribute measuredQuantityName : String = "shaft rotational speed";
        attribute operatingMode : UnitOperatingMode = UnitOperatingMode::unpowered;
        attribute nominalToothCount : ToothCount = 60;
        attribute minimumMeasurementSpeed : RotationalSpeed = 60.0;
        attribute maximumMeasurementSpeed : RotationalSpeed = 12000.0;
        attribute requiredAccuracy : Percent = 1.0;
        attribute nominalUpdatePeriod : Time = 0.010;
        attribute enclosureIngressProtection : String = "IP67";
        attribute operatingTemperatureMinimum : Temperature = -40.0;
        attribute operatingTemperatureMaximum : Temperature = 125.0;

        state operatingStates : SensingUnitStateMachine;

        action acquireSpeed : AcquireShaftSpeedUsingVariableReluctanceSensor;

        connect shaftInput to targetWheel.shaftInput;
        connect targetWheel.fluxOutput to pickup.magneticInput;
        connect targetWheel.gapOutput to pickup.airGapInput;
        connect pickup.analogOutput to conditioner.rawVrInput;
        connect conditioner.conditionedPulseOutput to estimator.pulseInput;
        connect estimator.speedOutput to speedOutput;
        connect pickup.analogOutput to diagnostics.analogInput;
        connect conditioner.conditionedPulseOutput to diagnostics.pulseInput;
        connect diagnostics.diagnosticOutput to diagnosticOutput;
        connect powerInput to conditioner.power;
        connect powerInput to diagnostics.power;
        connect thermal to pickup.thermal;
        connect thermal to conditioner.thermal;

        constraint requiredSpeedAccuracy : SpeedAccuracyConstraint {
            in maximumError = requiredAccuracy;
        }

        requirement useVariableReluctanceSensor {
            subject unit : VariableReluctanceSensingUnit = this;
            require constraint { unit.pickup.technology == SensorTechnology::variableReluctance }
        }

        requirement measureRotationalSpeed {
            subject unit : VariableReluctanceSensingUnit = this;
            require constraint { unit.measuredQuantityName == "shaft rotational speed" }
            require constraint { unit.minimumMeasurementSpeed == 60.0 }
            require constraint { unit.maximumMeasurementSpeed == 12000.0 }
        }

        requirement passivePickupRequirement {
            subject unit : VariableReluctanceSensingUnit = this;
            require constraint { unit.pickup.selfPoweredTransducer == true }
            require constraint { unit.pickup.requiresBiasMagnet == true }
        }

        requirement conditionedOutputRequirement {
            subject unit : VariableReluctanceSensingUnit = this;
            require constraint { unit.conditioner.comparator.minimumRecognizedPeakToPeak <= 0.050 }
            require constraint { unit.estimator.configuredToothCount == unit.nominalToothCount }
        }

        requirement environmentalRequirement {
            subject unit : VariableReluctanceSensingUnit = this;
            require constraint { unit.operatingTemperatureMinimum <= -40.0 }
            require constraint { unit.operatingTemperatureMaximum >= 125.0 }
            require constraint { unit.enclosureIngressProtection == "IP67" }
        }
    }

    part def RotatingMachineShaft {
        port motionOutput : RotationalMeasurandPort;

        attribute actualSpeed : RotationalSpeed = 1800.0;
        attribute actualPosition : Angle = 0.0;
        attribute direction : Integer = 1;
        attribute maximumSpeed : RotationalSpeed = 10000.0;
    }

    part def FiveVoltControllerSupply {
        port supplyOutput : PowerInputPort;

        attribute voltage : Voltage = 5.0;
        attribute currentLimit : Current = 0.100;
        attribute ripple : Voltage = 0.020;
        attribute enabled : Boolean = true;
    }

    part def EngineSpeedSensingApplication {
        part shaft : RotatingMachineShaft;
        part supply : FiveVoltControllerSupply;
        part sensingUnit : VariableReluctanceSensingUnit;

        port speedMeasurementOutput : SpeedOutputPort;
        port diagnosticOutput : DiagnosticPort;

        connect shaft.motionOutput to sensingUnit.shaftInput;
        connect supply.supplyOutput to sensingUnit.powerInput;
        connect sensingUnit.speedOutput to speedMeasurementOutput;
        connect sensingUnit.diagnosticOutput to diagnosticOutput;

        requirement applicationMeasurementRequirement {
            subject application : EngineSpeedSensingApplication = this;
            require constraint { application.sensingUnit.pickup.technology == SensorTechnology::variableReluctance }
            require constraint { application.sensingUnit.targetWheel.toothCount == 60 }
            require constraint { application.sensingUnit.estimator.maximumReportedSpeed >= 12000.0 }
            require constraint { application.sensingUnit.requiredAccuracy <= 1.0 }
        }
    }

    part engineSpeedSensingApplication : EngineSpeedSensingApplication;

}
