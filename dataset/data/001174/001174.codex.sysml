package PassiveInfraredSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Angle :> ISQ::planeAngle {
        unit = SI::degree;
    }

    attribute def Distance :> ISQ::length {
        unit = SI::meter;
    }

    attribute def Time :> ISQ::time {
        unit = SI::second;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def Irradiance :> ISQ::powerDensity {
        unit = SI::watt / SI::meter ^ 2;
    }

    attribute def DigitalCount :> ScalarValues::Integer;

    attribute def Probability :> ScalarValues::Real {
        range = "0.0..1.0";
    }

    attribute def MotionStateKind :> ScalarValues::String;

    item def InfraredRadiation {
        attribute wavelengthBandLow : Distance = 7.0e-6 [SI::meter];
        attribute wavelengthBandHigh : Distance = 14.0e-6 [SI::meter];
        attribute radiantIrradiance : Irradiance;
        attribute apparentSourceTemperature : Temperature;
        attribute modulationFrequency : Frequency;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute availablePower : Power;
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
        attribute bandwidth : Frequency;
        attribute noiseRms : Voltage;
    }

    item def DigitalSample {
        attribute rawCount : DigitalCount;
        attribute sampledVoltage : Voltage;
        attribute sampleTime : Time;
    }

    item def MotionEvent {
        attribute detected : Boolean;
        attribute confidence : Probability;
        attribute detectionRange : Distance;
        attribute azimuth : Angle;
        attribute eventAge : Time;
    }

    item def DiagnosticStatus {
        attribute supplyHealthy : Boolean;
        attribute sensorHealthy : Boolean;
        attribute amplifierHealthy : Boolean;
        attribute processorHealthy : Boolean;
        attribute faultCode : ScalarValues::String;
    }

    port def InfraredInputPort {
        in item incidentRadiation : InfraredRadiation;
    }

    port def PowerInputPort {
        in item supply : ElectricalPower;
    }

    port def AnalogSignalPort {
        out item analogOut : AnalogSignal;
    }

    port def DigitalSignalPort {
        out item sampleOut : DigitalSample;
    }

    port def MotionEventPort {
        out item motionOut : MotionEvent;
    }

    port def DiagnosticPort {
        out item statusOut : DiagnosticStatus;
    }

    port def ControlPort {
        in attribute enable : Boolean;
        in attribute sensitivitySetting : ScalarValues::Integer;
        in attribute resetFaults : Boolean;
    }

    action def CollectInfraredEnergy {
        in item incidentRadiation : InfraredRadiation;
        out item focusedRadiation : InfraredRadiation;
        attribute opticalTransmission : Probability = 0.82;
        attribute fieldOfViewHorizontal : Angle = 110 [SI::degree];
        attribute fieldOfViewVertical : Angle = 70 [SI::degree];
    }

    action def GeneratePyroelectricCharge {
        in item focusedRadiation : InfraredRadiation;
        out item pyroelectricSignal : AnalogSignal;
        attribute elementResponsivity : Voltage = 4.2e3 [SI::volt];
        attribute thermalTimeConstant : Time = 0.35 [SI::second];
    }

    action def FilterAndAmplifySignal {
        in item pyroelectricSignal : AnalogSignal;
        out item conditionedSignal : AnalogSignal;
        attribute lowCutFrequency : Frequency = 0.15 [SI::hertz];
        attribute highCutFrequency : Frequency = 8.0 [SI::hertz];
        attribute voltageGain : ScalarValues::Real = 68.0;
    }

    action def ConvertAnalogToDigital {
        in item conditionedSignal : AnalogSignal;
        out item digitalSample : DigitalSample;
        attribute adcResolutionBits : ScalarValues::Integer = 12;
        attribute adcReferenceVoltage : Voltage = 3.3 [SI::volt];
        attribute sampleRate : Frequency = 50 [SI::hertz];
    }

    action def EstimateMotion {
        in item digitalSample : DigitalSample;
        out item motionEvent : MotionEvent;
        attribute adaptiveThreshold : DigitalCount = 96;
        attribute minimumPulseWidth : Time = 0.12 [SI::second];
        attribute holdTime : Time = 2.5 [SI::second];
    }

    action def ReportDiagnostics {
        in attribute supplyVoltage : Voltage;
        in attribute processorAlive : Boolean;
        out item diagnosticStatus : DiagnosticStatus;
    }

    state def SensingUnitOperatingState {
        entry;
        state Off;
        state Starting;
        state Stabilizing;
        state Monitoring;
        state MotionDetected;
        state Faulted;

        transition first Off;

        transition powerApplied
            first Off
            then Starting
            accept ElectricalPower;

        transition startupComplete
            first Starting
            then Stabilizing
            after 1.0 [SI::second];

        transition warmupComplete
            first Stabilizing
            then Monitoring
            after 30.0 [SI::second];

        transition motionConfirmed
            first Monitoring
            then MotionDetected
            accept MotionEvent
            if motionOut.detected == true;

        transition holdExpired
            first MotionDetected
            then Monitoring
            after 2.5 [SI::second];

        transition faultDetectedFromStarting
            first Starting
            then Faulted
            if supplyHealthy == false;

        transition faultDetectedFromStabilizing
            first Stabilizing
            then Faulted
            if sensorHealthy == false;

        transition faultDetectedFromMonitoring
            first Monitoring
            then Faulted
            if processorHealthy == false;

        transition reset
            first Faulted
            then Starting
            accept ControlPort::resetFaults
            if resetFaults == true;
    }

    part def FresnelLensArray {
        port irIn : InfraredInputPort;
        port irOut : InfraredInputPort;

        attribute materialTransmission : Probability = 0.82;
        attribute segmentCount : ScalarValues::Integer = 24;
        attribute horizontalFieldOfView : Angle = 110 [SI::degree];
        attribute verticalFieldOfView : Angle = 70 [SI::degree];
        attribute nominalDetectionRange : Distance = 8.0 [SI::meter];

        perform action collect : CollectInfraredEnergy {
            in incidentRadiation = irIn.incidentRadiation;
            out focusedRadiation = irOut.incidentRadiation;
        }
    }

    part def PassiveInfraredSensorElement {
        port opticalInput : InfraredInputPort;
        port signalOutput : AnalogSignalPort;

        attribute sensingPrinciple : ScalarValues::String = "passive pyroelectric response to time-varying long-wave infrared radiation";
        attribute elementCount : ScalarValues::Integer = 2;
        attribute spectralBandLow : Distance = 7.0e-6 [SI::meter];
        attribute spectralBandHigh : Distance = 14.0e-6 [SI::meter];
        attribute responsivityAtOneHz : Voltage = 4200 [SI::volt];
        attribute noiseEquivalentPower : Power = 1.5e-9 [SI::watt];
        attribute operatingTemperatureMin : Temperature = 253.15 [SI::kelvin];
        attribute operatingTemperatureMax : Temperature = 333.15 [SI::kelvin];

        perform action transduce : GeneratePyroelectricCharge {
            in focusedRadiation = opticalInput.incidentRadiation;
            out pyroelectricSignal = signalOutput.analogOut;
        }
    }

    part def AnalogFrontEnd {
        port signalInput : AnalogSignalPort;
        port signalOutput : AnalogSignalPort;
        port powerInput : PowerInputPort;

        attribute inputImpedance : ScalarValues::Real = 1.0e9;
        attribute gain : ScalarValues::Real = 68.0;
        attribute lowCutFrequency : Frequency = 0.15 [SI::hertz];
        attribute highCutFrequency : Frequency = 8.0 [SI::hertz];
        attribute outputNoiseRms : Voltage = 0.002 [SI::volt];
        attribute supplyVoltageNominal : Voltage = 3.3 [SI::volt];
        attribute supplyCurrentNominal : Current = 0.00045 [SI::ampere];

        perform action condition : FilterAndAmplifySignal {
            in pyroelectricSignal = signalInput.analogOut;
            out conditionedSignal = signalOutput.analogOut;
        }
    }

    part def Microcontroller {
        port analogInput : AnalogSignalPort;
        port sampleOutput : DigitalSignalPort;
        port motionOutput : MotionEventPort;
        port diagnosticOutput : DiagnosticPort;
        port controlInput : ControlPort;
        port powerInput : PowerInputPort;

        attribute adcResolutionBits : ScalarValues::Integer = 12;
        attribute adcReferenceVoltage : Voltage = 3.3 [SI::volt];
        attribute sampleRate : Frequency = 50 [SI::hertz];
        attribute detectionThresholdLowSensitivity : DigitalCount = 160;
        attribute detectionThresholdMediumSensitivity : DigitalCount = 96;
        attribute detectionThresholdHighSensitivity : DigitalCount = 52;
        attribute firmwareCycleTime : Time = 0.02 [SI::second];
        attribute supplyCurrentNominal : Current = 0.0032 [SI::ampere];

        perform action sample : ConvertAnalogToDigital {
            in conditionedSignal = analogInput.analogOut;
            out digitalSample = sampleOutput.sampleOut;
        }

        perform action detect : EstimateMotion {
            in digitalSample = sampleOutput.sampleOut;
            out motionEvent = motionOutput.motionOut;
        }

        perform action diagnose : ReportDiagnostics {
            in supplyVoltage = powerInput.supply.voltage;
            in processorAlive = true;
            out diagnosticStatus = diagnosticOutput.statusOut;
        }

        exhibit state behavior : SensingUnitOperatingState;
    }

    part def RegulatedPowerSupply {
        port powerIn : PowerInputPort;
        port powerOut : PowerInputPort;
        port diagnosticOut : DiagnosticPort;

        attribute inputVoltageMin : Voltage = 4.5 [SI::volt];
        attribute inputVoltageMax : Voltage = 28.0 [SI::volt];
        attribute outputVoltageNominal : Voltage = 3.3 [SI::volt];
        attribute outputVoltageTolerance : Voltage = 0.10 [SI::volt];
        attribute maximumOutputCurrent : Current = 0.020 [SI::ampere];
        attribute quiescentCurrent : Current = 0.00018 [SI::ampere];
        attribute conversionEfficiency : Probability = 0.84;
    }

    part def MotionIndicatorOutput {
        port motionInput : MotionEventPort;
        port diagnosticInput : DiagnosticPort;

        attribute activeHighLogicVoltage : Voltage = 3.3 [SI::volt];
        attribute inactiveLogicVoltage : Voltage = 0.0 [SI::volt];
        attribute outputHoldTime : Time = 2.5 [SI::second];
        attribute maximumSinkCurrent : Current = 0.010 [SI::ampere];
    }

    part def PassiveInfraredSensingUnit {
        port environmentInput : InfraredInputPort;
        port supplyInput : PowerInputPort;
        port control : ControlPort;
        port motionEventOutput : MotionEventPort;
        port diagnosticOutput : DiagnosticPort;

        part lens : FresnelLensArray;
        part pirElement : PassiveInfraredSensorElement;
        part analogFrontEnd : AnalogFrontEnd;
        part processor : Microcontroller;
        part powerRegulator : RegulatedPowerSupply;
        part outputDriver : MotionIndicatorOutput;

        attribute measuredQuantity : ScalarValues::String = "time-varying long-wave infrared radiation caused by motion of warm bodies";
        attribute nominalSupplyVoltage : Voltage = 12.0 [SI::volt];
        attribute regulatedVoltage : Voltage = 3.3 [SI::volt];
        attribute nominalCurrent : Current = 0.0045 [SI::ampere];
        attribute nominalPower : Power = 0.054 [SI::watt];
        attribute detectionRange : Distance = 8.0 [SI::meter];
        attribute horizontalCoverage : Angle = 110 [SI::degree];
        attribute verticalCoverage : Angle = 70 [SI::degree];
        attribute warmupTime : Time = 30.0 [SI::second];
        attribute outputHoldTime : Time = 2.5 [SI::second];
        attribute responseTime : Time = 0.25 [SI::second];

        connect environmentInput to lens.irIn;
        connect lens.irOut to pirElement.opticalInput;
        connect pirElement.signalOutput to analogFrontEnd.signalInput;
        connect analogFrontEnd.signalOutput to processor.analogInput;
        connect processor.motionOutput to motionEventOutput;
        connect processor.motionOutput to outputDriver.motionInput;
        connect processor.diagnosticOutput to diagnosticOutput;
        connect processor.diagnosticOutput to outputDriver.diagnosticInput;
        connect supplyInput to powerRegulator.powerIn;
        connect powerRegulator.powerOut to analogFrontEnd.powerInput;
        connect powerRegulator.powerOut to processor.powerInput;
        connect control to processor.controlInput;
    }

    requirement def MeasureInfraredMotionRequirement {
        doc /* The sensing unit shall measure passive infrared radiation variation in the 7 um to 14 um wavelength band and infer motion of warm bodies without emitting sensing energy. */
        subject unit : PassiveInfraredSensingUnit;
        require constraint {
            unit.pirElement.spectralBandLow <= 7.0e-6 [SI::meter] and
            unit.pirElement.spectralBandHigh >= 14.0e-6 [SI::meter]
        }
    }

    requirement def PassiveOperationRequirement {
        doc /* The sensing unit shall operate as a passive infrared detector and shall not include an active illumination emitter for measurement. */
        subject unit : PassiveInfraredSensingUnit;
        require constraint {
            unit.measuredQuantity == "time-varying long-wave infrared radiation caused by motion of warm bodies"
        }
    }

    requirement def DetectionRangeRequirement {
        doc /* The sensing unit shall detect human-scale motion within 8 meters over the nominal field of view. */
        subject unit : PassiveInfraredSensingUnit;
        require constraint {
            unit.detectionRange >= 8.0 [SI::meter] and
            unit.horizontalCoverage >= 110 [SI::degree] and
            unit.verticalCoverage >= 70 [SI::degree]
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The sensing unit shall produce a motion event within 250 ms after the conditioned signal exceeds the configured detection threshold. */
        subject unit : PassiveInfraredSensingUnit;
        require constraint {
            unit.responseTime <= 0.25 [SI::second]
        }
    }

    requirement def PowerRequirement {
        doc /* The sensing unit shall operate from a 4.5 V to 28 V external supply and shall regulate internal electronics to 3.3 V. */
        subject unit : PassiveInfraredSensingUnit;
        require constraint {
            unit.powerRegulator.inputVoltageMin <= 4.5 [SI::volt] and
            unit.powerRegulator.inputVoltageMax >= 28.0 [SI::volt] and
            unit.powerRegulator.outputVoltageNominal == 3.3 [SI::volt]
        }
    }

    requirement def WarmupRequirement {
        doc /* The sensing unit shall enter monitoring mode no later than 30 seconds after valid supply power is applied. */
        subject unit : PassiveInfraredSensingUnit;
        require constraint {
            unit.warmupTime <= 30.0 [SI::second]
        }
    }

    requirement def DiagnosticRequirement {
        doc /* The sensing unit shall report supply, sensor, amplifier, and processor health through a diagnostic output. */
        subject unit : PassiveInfraredSensingUnit;
        require constraint {
            unit.processor.diagnosticOutput.statusOut.supplyHealthy == true implies
            unit.processor.diagnosticOutput.statusOut.processorHealthy == true
        }
    }

    satisfy MeasureInfraredMotionRequirement by PassiveInfraredSensingUnit::pirElement;
    satisfy PassiveOperationRequirement by PassiveInfraredSensingUnit::pirElement;
    satisfy DetectionRangeRequirement by PassiveInfraredSensingUnit::lens;
    satisfy ResponseTimeRequirement by PassiveInfraredSensingUnit::processor;
    satisfy PowerRequirement by PassiveInfraredSensingUnit::powerRegulator;
    satisfy WarmupRequirement by PassiveInfraredSensingUnit::processor;
    satisfy DiagnosticRequirement by PassiveInfraredSensingUnit::processor;

    part sensingUnit : PassiveInfraredSensingUnit {
        attribute nominalSupplyVoltage = 12.0 [SI::volt];
        attribute detectionRange = 8.0 [SI::meter];
        attribute horizontalCoverage = 110 [SI::degree];
        attribute verticalCoverage = 70 [SI::degree];
    }
}