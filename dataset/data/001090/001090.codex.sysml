package HydrophoneSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    /* Units and value types */

    attribute def PressurePa :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def VoltageV :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def CurrentA :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def FrequencyHz :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def Sensitivity_dBV_per_uPa {
        :>> unit = "dB re 1 V/uPa";
    }

    attribute def SignalToNoiseRatio_dB {
        :>> unit = "dB";
    }

    attribute def TemperatureC {
        :>> unit = "degC";
    }

    attribute def DepthM :> ISQ::length {
        unit = SI::metre;
    }

    attribute def BitRate_bps {
        :>> unit = "bit/s";
    }

    attribute def DigitalSample {
        attribute timestamp_s : Real;
        attribute sampleValue : Real;
        attribute sampleRate_Hz : FrequencyHz;
        attribute bitDepth : Integer;
    }

    attribute def AcousticPressureWave {
        attribute pressure : PressurePa;
        attribute frequency : FrequencyHz;
        attribute sourceBearing_deg : Real;
    }

    attribute def AnalogElectricalSignal {
        attribute voltage : VoltageV;
        attribute frequency : FrequencyHz;
        attribute noiseVoltage : VoltageV;
    }

    attribute def ConditionedAnalogSignal {
        attribute voltage : VoltageV;
        attribute gain_dB : Real;
        attribute bandwidth_Hz : FrequencyHz;
        attribute noiseVoltage : VoltageV;
    }

    attribute def DigitalAcousticStream {
        attribute sampleRate_Hz : FrequencyHz;
        attribute bitDepth : Integer;
        attribute dataRate : BitRate_bps;
    }

    attribute def DiagnosticStatus {
        attribute healthy : Boolean;
        attribute internalTemperature : TemperatureC;
        attribute supplyVoltage : VoltageV;
        attribute leakageDetected : Boolean;
        attribute saturationDetected : Boolean;
    }

    attribute def ElectricalPower {
        attribute voltage : VoltageV;
        attribute current : CurrentA;
    }

    /* Item definitions */

    item def AcousticWaveItem {
        attribute wave : AcousticPressureWave;
    }

    item def AnalogSignalItem {
        attribute signal : AnalogElectricalSignal;
    }

    item def ConditionedSignalItem {
        attribute signal : ConditionedAnalogSignal;
    }

    item def DigitalStreamItem {
        attribute stream : DigitalAcousticStream;
        attribute latestSample : DigitalSample;
    }

    item def DiagnosticItem {
        attribute status : DiagnosticStatus;
    }

    item def PowerItem {
        attribute power : ElectricalPower;
    }

    /* Port definitions */

    port def AcousticInputPort {
        in item incidentSound : AcousticWaveItem;
    }

    port def AnalogSignalPort {
        out item analogOut : AnalogSignalItem;
    }

    port def ConditionedSignalPort {
        out item conditionedOut : ConditionedSignalItem;
    }

    port def DigitalDataPort {
        out item acousticData : DigitalStreamItem;
    }

    port def DiagnosticPort {
        out item diagnostics : DiagnosticItem;
    }

    port def PowerInputPort {
        in item electricalPower : PowerItem;
    }

    port def GroundPort {
        inout item reference : PowerItem;
    }

    /* Actions */

    action def ConvertPressureToCharge {
        in item sound : AcousticWaveItem;
        out item analog : AnalogSignalItem;

        attribute transducerSensitivity : Sensitivity_dBV_per_uPa;
        attribute usableFrequencyMin : FrequencyHz;
        attribute usableFrequencyMax : FrequencyHz;
    }

    action def AmplifyAndFilter {
        in item rawSignal : AnalogSignalItem;
        out item conditionedSignal : ConditionedSignalItem;

        attribute preamplifierGain_dB : Real;
        attribute highPassCutoff : FrequencyHz;
        attribute lowPassCutoff : FrequencyHz;
    }

    action def DigitizeSignal {
        in item conditionedSignal : ConditionedSignalItem;
        out item digitalStream : DigitalStreamItem;

        attribute sampleRate : FrequencyHz;
        attribute bitDepth : Integer;
    }

    action def MonitorHealth {
        in item suppliedPower : PowerItem;
        out item diagnosticStatus : DiagnosticItem;

        attribute maximumInternalTemperature : TemperatureC;
        attribute minimumSupplyVoltage : VoltageV;
    }

    action def DetectAcousticEvent {
        in item digitalStream : DigitalStreamItem;
        out item eventStatus : DiagnosticItem;

        attribute eventThreshold_Pa : PressurePa;
        attribute saturationThreshold_V : VoltageV;
    }

    /* State machines */

    state def HydrophoneOperatingState {
        state Off;
        state PoweringUp;
        state SelfTest;
        state Listening;
        state Saturated;
        state Fault;

        transition first Off;

        transition Off_to_PoweringUp
            first Off
            then PoweringUp;

        transition PoweringUp_to_SelfTest
            first PoweringUp
            then SelfTest;

        transition SelfTest_to_Listening
            first SelfTest
            then Listening;

        transition Listening_to_Saturated
            first Listening
            then Saturated;

        transition Saturated_to_Listening
            first Saturated
            then Listening;

        transition Listening_to_Fault
            first Listening
            then Fault;

        transition Fault_to_Off
            first Fault
            then Off;
    }

    /* Part definitions */

    part def PiezoelectricSensingElement {
        port acousticIn : AcousticInputPort;
        port analogSignalOut : AnalogSignalPort;

        attribute elementMaterial : String = "PZT ceramic";
        attribute nominalSensitivity : Sensitivity_dBV_per_uPa = -180.0;
        attribute frequencyMin : FrequencyHz = 5.0;
        attribute frequencyMax : FrequencyHz = 80000.0;
        attribute maximumSafePressure : PressurePa = 1000000.0;

        perform action pressureConversion : ConvertPressureToCharge {
            in item sound = acousticIn.incidentSound;
            out item analog = analogSignalOut.analogOut;
        }
    }

    part def LowNoisePreamplifier {
        port analogIn : AnalogSignalPort;
        port conditionedOut : ConditionedSignalPort;
        port powerIn : PowerInputPort;
        port ground : GroundPort;

        attribute gain : Real = 24.0;
        attribute inputReferredNoise : VoltageV = 0.0000008;
        attribute supplyVoltageNominal : VoltageV = 5.0;
        attribute inputImpedance_ohm : Real = 10000000.0;

        perform action amplify : AmplifyAndFilter {
            in item rawSignal = analogIn.analogOut;
            out item conditionedSignal = conditionedOut.conditionedOut;
        }
    }

    part def AntiAliasFilter {
        port signalIn : ConditionedSignalPort;
        port signalOut : ConditionedSignalPort;

        attribute filterOrder : Integer = 4;
        attribute highPassCutoff : FrequencyHz = 10.0;
        attribute lowPassCutoff : FrequencyHz = 48000.0;
    }

    part def AnalogToDigitalConverter {
        port analogIn : ConditionedSignalPort;
        port digitalOut : DigitalDataPort;
        port powerIn : PowerInputPort;

        attribute sampleRate : FrequencyHz = 96000.0;
        attribute bitDepth : Integer = 24;
        attribute fullScaleInput : VoltageV = 2.5;
        attribute conversionLatency_s : Real = 0.001;

        perform action digitization : DigitizeSignal {
            in item conditionedSignal = analogIn.conditionedOut;
            out item digitalStream = digitalOut.acousticData;
        }
    }

    part def EnvironmentalHousing {
        port acousticWindow : AcousticInputPort;

        attribute material : String = "titanium alloy";
        attribute acousticWindowMaterial : String = "polyurethane";
        attribute ratedDepth : DepthM = 1000.0;
        attribute leakRateLimit_ml_per_day : Real = 0.01;
        attribute operatingTemperatureMin : TemperatureC = -5.0;
        attribute operatingTemperatureMax : TemperatureC = 45.0;
    }

    part def PowerRegulator {
        port externalPowerIn : PowerInputPort;
        port regulatedPowerOut : PowerInputPort;
        port ground : GroundPort;

        attribute inputVoltageMin : VoltageV = 9.0;
        attribute inputVoltageMax : VoltageV = 36.0;
        attribute regulatedVoltage : VoltageV = 5.0;
        attribute maximumOutputCurrent : CurrentA = 0.5;
    }

    part def HealthMonitor {
        port powerSense : PowerInputPort;
        port diagnosticOut : DiagnosticPort;

        attribute maximumAllowedTemperature : TemperatureC = 60.0;
        attribute minimumAllowedSupplyVoltage : VoltageV = 4.75;
        attribute leakageTripThreshold : Boolean = true;

        perform action monitor : MonitorHealth {
            in item suppliedPower = powerSense.electricalPower;
            out item diagnosticStatus = diagnosticOut.diagnostics;
        }
    }

    part def AcousticProcessor {
        port acousticDataIn : DigitalDataPort;
        port processedDataOut : DigitalDataPort;
        port diagnosticOut : DiagnosticPort;

        attribute eventDetectionThreshold : PressurePa = 0.02;
        attribute nominalOutputRate : BitRate_bps = 2304000.0;
        attribute calibrationOffset_dB : Real = 0.0;

        perform action eventDetection : DetectAcousticEvent {
            in item digitalStream = acousticDataIn.acousticData;
            out item eventStatus = diagnosticOut.diagnostics;
        }
    }

    part def Hydrophone {
        port acousticInput : AcousticInputPort;
        port powerInput : PowerInputPort;
        port dataOutput : DigitalDataPort;
        port healthOutput : DiagnosticPort;
        port chassisGround : GroundPort;

        attribute primaryFunction : String =
            "Detect underwater acoustic pressure waves and convert them into calibrated digital acoustic data for monitoring, recording, or analysis.";

        attribute nominalSensitivity : Sensitivity_dBV_per_uPa = -180.0;
        attribute usableFrequencyMin : FrequencyHz = 5.0;
        attribute usableFrequencyMax : FrequencyHz = 80000.0;
        attribute dynamicRange_dB : Real = 120.0;
        attribute selfNoiseLevel_dB_re_1uPa : Real = 35.0;
        attribute ratedDepth : DepthM = 1000.0;

        part housing : EnvironmentalHousing;
        part sensingElement : PiezoelectricSensingElement;
        part preamplifier : LowNoisePreamplifier;
        part antiAliasFilter : AntiAliasFilter;
        part adc : AnalogToDigitalConverter;
        part regulator : PowerRegulator;
        part processor : AcousticProcessor;
        part healthMonitor : HealthMonitor;

        exhibit stateMachine operatingState : HydrophoneOperatingState;

        connect acousticInput to housing.acousticWindow;
        connect housing.acousticWindow to sensingElement.acousticIn;
        connect sensingElement.analogSignalOut to preamplifier.analogIn;
        connect preamplifier.conditionedOut to antiAliasFilter.signalIn;
        connect antiAliasFilter.signalOut to adc.analogIn;
        connect adc.digitalOut to processor.acousticDataIn;
        connect processor.processedDataOut to dataOutput;

        connect powerInput to regulator.externalPowerIn;
        connect regulator.regulatedPowerOut to preamplifier.powerIn;
        connect regulator.regulatedPowerOut to adc.powerIn;
        connect regulator.regulatedPowerOut to healthMonitor.powerSense;
        connect chassisGround to regulator.ground;
        connect chassisGround to preamplifier.ground;

        connect processor.diagnosticOut to healthOutput;
        connect healthMonitor.diagnosticOut to healthOutput;
    }

    part def HydrophoneDeploymentSystem {
        port underwaterSoundField : AcousticInputPort;
        port externalPower : PowerInputPort;
        port acousticDataTelemetry : DigitalDataPort;
        port systemDiagnostics : DiagnosticPort;
        port groundReference : GroundPort;

        part hydrophone : Hydrophone;

        connect underwaterSoundField to hydrophone.acousticInput;
        connect externalPower to hydrophone.powerInput;
        connect hydrophone.dataOutput to acousticDataTelemetry;
        connect hydrophone.healthOutput to systemDiagnostics;
        connect groundReference to hydrophone.chassisGround;
    }

    /* Requirements */

    requirement def PrimaryFunctionRequirement {
        doc
        /* The hydrophone shall detect underwater acoustic pressure waves and convert them into digital acoustic data suitable for monitoring, recording, or analysis. */

        subject hydrophone : Hydrophone;

        require constraint {
            hydrophone.usableFrequencyMin <= 10.0 and
            hydrophone.usableFrequencyMax >= 48000.0
        }
    }

    requirement def SensitivityRequirement {
        doc
        /* The hydrophone shall provide nominal receive sensitivity adequate for low-level underwater acoustic signals. */

        subject hydrophone : Hydrophone;

        require constraint {
            hydrophone.nominalSensitivity <= -170.0 and
            hydrophone.nominalSensitivity >= -200.0
        }
    }

    requirement def DepthRatingRequirement {
        doc
        /* The hydrophone housing shall maintain acoustic and electrical integrity at the specified operating depth. */

        subject hydrophone : Hydrophone;

        require constraint {
            hydrophone.ratedDepth >= 1000.0
        }
    }

    requirement def SignalChainRequirement {
        doc
        /* The hydrophone shall condition and digitize the sensed analog signal before outputting acoustic data. */

        subject hydrophone : Hydrophone;

        require constraint {
            hydrophone.adc.bitDepth >= 24 and
            hydrophone.adc.sampleRate >= 96000.0
        }
    }

    requirement def HealthMonitoringRequirement {
        doc
        /* The hydrophone shall report diagnostic status including power health, temperature, leakage indication, and saturation indication. */

        subject hydrophone : Hydrophone;

        require constraint {
            hydrophone.healthMonitor.maximumAllowedTemperature <= 60.0 and
            hydrophone.healthMonitor.minimumAllowedSupplyVoltage >= 4.75
        }
    }

    requirement primaryFunctionReq : PrimaryFunctionRequirement {
        subject hydrophone = HydrophoneDeploymentSystem::hydrophone;
    }

    requirement sensitivityReq : SensitivityRequirement {
        subject hydrophone = HydrophoneDeploymentSystem::hydrophone;
    }

    requirement depthReq : DepthRatingRequirement {
        subject hydrophone = HydrophoneDeploymentSystem::hydrophone;
    }

    requirement signalChainReq : SignalChainRequirement {
        subject hydrophone = HydrophoneDeploymentSystem::hydrophone;
    }

    requirement healthReq : HealthMonitoringRequirement {
        subject hydrophone = HydrophoneDeploymentSystem::hydrophone;
    }

    satisfy primaryFunctionReq by HydrophoneDeploymentSystem::hydrophone;
    satisfy sensitivityReq by HydrophoneDeploymentSystem::hydrophone.sensingElement;
    satisfy depthReq by HydrophoneDeploymentSystem::hydrophone.housing;
    satisfy signalChainReq by HydrophoneDeploymentSystem::hydrophone.adc;
    satisfy healthReq by HydrophoneDeploymentSystem::hydrophone.healthMonitor;
}