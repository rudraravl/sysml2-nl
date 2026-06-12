package IntelligentSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Temperature :> ScalarValues::Real {
        unit = "K";
    }

    attribute def CelsiusTemperature :> ScalarValues::Real {
        unit = "degC";
    }

    attribute def Voltage :> ScalarValues::Real {
        unit = "V";
    }

    attribute def Current :> ScalarValues::Real {
        unit = "A";
    }

    attribute def Power :> ScalarValues::Real {
        unit = "W";
    }

    attribute def Frequency :> ScalarValues::Real {
        unit = "Hz";
    }

    attribute def TimeDuration :> ScalarValues::Real {
        unit = "s";
    }

    attribute def DataRate :> ScalarValues::Real {
        unit = "bit/s";
    }

    attribute def Percent :> ScalarValues::Real {
        unit = "%";
    }

    attribute def MeasurementUncertainty :> ScalarValues::Real {
        unit = "degC";
    }

    attribute def DigitalCount :> ScalarValues::Integer;

    enum def SensorHealthKind {
        enum ok;
        enum degraded;
        enum failed;
        enum uncalibrated;
    }

    enum def MeasurementStatusKind {
        enum valid;
        enum suspect;
        enum invalid;
        enum saturated;
        enum stale;
    }

    item def ThermalQuantity {
        attribute temperature : CelsiusTemperature;
        attribute gradient : CelsiusTemperature;
        attribute acquisitionTime : TimeDuration;
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
        attribute sourceImpedance : ScalarValues::Real;
        attribute bandwidth : Frequency;
    }

    item def SampledSignal {
        attribute rawCount : DigitalCount;
        attribute samplePeriod : TimeDuration;
        attribute referenceVoltage : Voltage;
    }

    item def MeasurementEstimate {
        attribute value : CelsiusTemperature;
        attribute uncertainty : MeasurementUncertainty;
        attribute status : MeasurementStatusKind;
        attribute timestamp : TimeDuration;
    }

    item def SensorDiagnostic {
        attribute health : SensorHealthKind;
        attribute selfTestPassed : Boolean;
        attribute driftEstimate : MeasurementUncertainty;
        attribute supplyVoltage : Voltage;
        attribute internalTemperature : CelsiusTemperature;
    }

    item def PowerSupply {
        attribute voltage : Voltage;
        attribute currentLimit : Current;
        attribute ripple : Voltage;
    }

    item def ConfigurationCommand {
        attribute requestedSampleRate : Frequency;
        attribute filterTimeConstant : TimeDuration;
        attribute enableSelfTest : Boolean;
        attribute calibrationOffset : MeasurementUncertainty;
    }

    item def MeasurementMessage {
        attribute measuredTemperature : CelsiusTemperature;
        attribute uncertainty : MeasurementUncertainty;
        attribute status : MeasurementStatusKind;
        attribute health : SensorHealthKind;
        attribute sequenceNumber : DigitalCount;
        attribute messageTimestamp : TimeDuration;
    }

    port def ThermalInterface {
        in item sensedThermalQuantity : ThermalQuantity;
    }

    port def AnalogOutputPort {
        out item analogSignal : AnalogSignal;
    }

    port def AnalogInputPort {
        in item analogSignal : AnalogSignal;
    }

    port def SamplePort {
        out item sampledSignal : SampledSignal;
    }

    port def SampleInputPort {
        in item sampledSignal : SampledSignal;
    }

    port def EstimatePort {
        out item estimate : MeasurementEstimate;
    }

    port def EstimateInputPort {
        in item estimate : MeasurementEstimate;
    }

    port def DiagnosticPort {
        out item diagnostic : SensorDiagnostic;
    }

    port def DigitalCommunicationPort {
        out item measurementMessage : MeasurementMessage;
        in item configurationCommand : ConfigurationCommand;
    }

    port def PowerInputPort {
        in item power : PowerSupply;
    }

    part def SensingElement {
        attribute sensitivity : Voltage;
        attribute nominalResistance : ScalarValues::Real;
        attribute thermalResponseTime : TimeDuration;
        attribute operatingMin : CelsiusTemperature;
        attribute operatingMax : CelsiusTemperature;

        port environment : ThermalInterface;
        port signalOut : AnalogOutputPort;

        action convertThermalQuantityToVoltage {
            in item thermalInput : ThermalQuantity;
            out item analogOutput : AnalogSignal;

            first start;
            then computeSensorVoltage;
            then emitAnalogSignal;
            then done;

            action computeSensorVoltage {
                in item t : ThermalQuantity;
                out item v : AnalogSignal;
            }
        }
    }

    part def SignalConditioner {
        attribute gain : ScalarValues::Real;
        attribute offset : Voltage;
        attribute lowPassCutoff : Frequency;
        attribute noiseRms : Voltage;

        port analogIn : AnalogInputPort;
        port analogOut : AnalogOutputPort;

        action conditionSignal {
            in item unconditioned : AnalogSignal;
            out item conditioned : AnalogSignal;

            first receiveInput;
            then applyGainAndOffset;
            then attenuateOutOfBandNoise;
            then provideConditionedSignal;
            then done;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : ScalarValues::Integer;
        attribute referenceVoltage : Voltage;
        attribute sampleRate : Frequency;
        attribute conversionTime : TimeDuration;

        port analogIn : AnalogInputPort;
        port sampleOut : SamplePort;

        action sampleAndQuantize {
            in item conditionedAnalog : AnalogSignal;
            out item sampled : SampledSignal;

            first waitForSampleClock;
            then acquireVoltage;
            then quantizeVoltage;
            then publishRawCount;
            then done;
        }
    }

    part def IntelligentProcessor {
        attribute calibrationOffset : MeasurementUncertainty;
        attribute calibrationGain : ScalarValues::Real;
        attribute filterTimeConstant : TimeDuration;
        attribute maximumAllowedDrift : MeasurementUncertainty;
        attribute staleDataTimeout : TimeDuration;
        attribute health : SensorHealthKind;
        attribute sequenceCounter : DigitalCount;

        port sampleIn : SampleInputPort;
        port estimateOut : EstimatePort;
        port diagnosticOut : DiagnosticPort;
        port comms : DigitalCommunicationPort;

        state def ProcessorStateMachine {
            state powerOff;
            state initializing;
            state selfTesting;
            state calibrating;
            state measuring;
            state degradedOperation;
            state faulted;

            entry action initializeMemory;
            entry action loadCalibrationData;
            entry action resetSequenceCounter;

            transition first powerOff then initializing;
            transition initializing then selfTesting
                accept after 0.25 [s];

            transition selfTesting then calibrating
                if selfTestResult == true;

            transition selfTesting then faulted
                if selfTestResult == false;

            transition calibrating then measuring
                accept after 1.0 [s];

            transition measuring then degradedOperation
                if estimatedDrift > maximumAllowedDrift;

            transition degradedOperation then measuring
                if estimatedDrift <= maximumAllowedDrift;

            transition measuring then faulted
                if missingSamplesDuration > staleDataTimeout;

            transition degradedOperation then faulted
                if missingSamplesDuration > staleDataTimeout;

            transition faulted then initializing
                accept configurationCommand
                if configurationCommand.enableSelfTest == true;
        }

        action estimateMeasuredQuantity {
            in item sampled : SampledSignal;
            out item estimate : MeasurementEstimate;

            first validateSample;
            then convertCountsToVoltage;
            then applyCalibration;
            then applyDigitalFilter;
            then computeUncertainty;
            then classifyMeasurementStatus;
            then publishEstimate;
            then done;
        }

        action performSelfTest {
            out item diagnostic : SensorDiagnostic;

            first verifyProgramMemory;
            then verifyAdcReference;
            then verifySignalPathStimulus;
            then estimateSensorDrift;
            then publishDiagnostic;
            then done;
        }

        action processConfiguration {
            in item command : ConfigurationCommand;

            first receiveCommand;
            then validateConfigurationRange;
            then updateSampleRate;
            then updateFilterConstant;
            then updateCalibrationOffset;
            then done;
        }
    }

    part def CommunicationInterface {
        attribute protocolName : String = "I2C";
        attribute busAddress : ScalarValues::Integer = 72;
        attribute dataRate : DataRate;
        attribute maximumLatency : TimeDuration;

        port estimateIn : EstimateInputPort;
        port diagnosticIn : DiagnosticPort;
        port externalBus : DigitalCommunicationPort;

        action encodeMeasurementMessage {
            in item estimate : MeasurementEstimate;
            in item diagnostic : SensorDiagnostic;
            out item message : MeasurementMessage;

            first collectLatestEstimate;
            then collectLatestDiagnostic;
            then assignSequenceNumber;
            then encodePayload;
            then transmitMessage;
            then done;
        }
    }

    part def PowerRegulator {
        attribute inputVoltageMin : Voltage;
        attribute inputVoltageMax : Voltage;
        attribute regulatedVoltage : Voltage;
        attribute efficiency : Percent;
        attribute outputNoise : Voltage;

        port powerIn : PowerInputPort;
        port regulatedPowerOut : PowerInputPort;
    }

    part def IntelligentTemperatureSensingUnit {
        attribute measuringRangeMin : CelsiusTemperature = -40.0;
        attribute measuringRangeMax : CelsiusTemperature = 125.0;
        attribute accuracyAt25C : MeasurementUncertainty = 0.2;
        attribute maximumSampleRate : Frequency = 100.0;
        attribute nominalSupplyVoltage : Voltage = 3.3;
        attribute nominalPower : Power = 0.045;

        port sensedEnvironment : ThermalInterface;
        port electricalPower : PowerInputPort;
        port digitalInterface : DigitalCommunicationPort;

        part sensingElement : SensingElement {
            attribute sensitivity = 0.010;
            attribute nominalResistance = 10000.0;
            attribute thermalResponseTime = 0.50;
            attribute operatingMin = -55.0;
            attribute operatingMax = 150.0;
        }

        part conditioner : SignalConditioner {
            attribute gain = 8.0;
            attribute offset = 1.25;
            attribute lowPassCutoff = 50.0;
            attribute noiseRms = 0.0005;
        }

        part adc : AnalogToDigitalConverter {
            attribute resolutionBits = 16;
            attribute referenceVoltage = 2.5;
            attribute sampleRate = 20.0;
            attribute conversionTime = 0.002;
        }

        part processor : IntelligentProcessor {
            attribute calibrationOffset = 0.0;
            attribute calibrationGain = 1.0;
            attribute filterTimeConstant = 0.25;
            attribute maximumAllowedDrift = 0.5;
            attribute staleDataTimeout = 2.0;
            attribute health = SensorHealthKind::ok;
            attribute sequenceCounter = 0;
        }

        part communicationInterface : CommunicationInterface {
            attribute dataRate = 400000.0;
            attribute maximumLatency = 0.050;
        }

        part regulator : PowerRegulator {
            attribute inputVoltageMin = 3.0;
            attribute inputVoltageMax = 5.5;
            attribute regulatedVoltage = 3.3;
            attribute efficiency = 88.0;
            attribute outputNoise = 0.010;
        }

        connect sensedEnvironment to sensingElement.environment;
        connect sensingElement.signalOut to conditioner.analogIn;
        connect conditioner.analogOut to adc.analogIn;
        connect adc.sampleOut to processor.sampleIn;
        connect processor.estimateOut to communicationInterface.estimateIn;
        connect processor.diagnosticOut to communicationInterface.diagnosticIn;
        connect communicationInterface.externalBus to digitalInterface;
        connect electricalPower to regulator.powerIn;

        perform action sensingCycle {
            first acquireThermalQuantity;
            then convertToAnalogSignal;
            then conditionAnalogSignal;
            then digitizeSignal;
            then estimateTemperature;
            then runHealthAssessment;
            then transmitMeasurement;
            then done;
        }

        state def UnitStateMachine {
            state unpowered;
            state booting;
            state ready;
            state activeMeasurement;
            state standby;
            state maintenance;
            state failed;

            transition first unpowered then booting
                if electricalPower.power.voltage >= 3.0;

            transition booting then ready
                accept after 1.5 [s];

            transition ready then activeMeasurement
                accept configurationCommand
                if configurationCommand.requestedSampleRate > 0.0;

            transition activeMeasurement then standby
                accept configurationCommand
                if configurationCommand.requestedSampleRate == 0.0;

            transition standby then activeMeasurement
                accept configurationCommand
                if configurationCommand.requestedSampleRate > 0.0;

            transition activeMeasurement then maintenance
                accept configurationCommand
                if configurationCommand.enableSelfTest == true;

            transition maintenance then ready
                accept after 2.0 [s];

            transition ready then failed
                if processor.health == SensorHealthKind::failed;

            transition activeMeasurement then failed
                if processor.health == SensorHealthKind::failed;

            transition failed then booting
                accept configurationCommand
                if configurationCommand.enableSelfTest == true;
        }
    }

    requirement def MeasurementRangeRequirement {
        subject sensingUnit : IntelligentTemperatureSensingUnit;

        doc /* The sensing unit shall measure temperature from -40 degC to 125 degC. */

        require constraint {
            sensingUnit.measuringRangeMin <= -40.0 and
            sensingUnit.measuringRangeMax >= 125.0
        }
    }

    requirement def AccuracyRequirement {
        subject sensingUnit : IntelligentTemperatureSensingUnit;

        doc /* The sensing unit shall report measured temperature with uncertainty no greater than 0.5 degC over the specified operating range after calibration. */

        require constraint {
            sensingUnit.accuracyAt25C <= 0.5
        }
    }

    requirement def IntelligentSensorRequirement {
        subject sensingUnit : IntelligentTemperatureSensingUnit;

        doc /* The intelligent sensor shall perform local calibration compensation, filtering, status classification, self-test, and diagnostic reporting without requiring an external processor for basic measurement validity. */

        require constraint {
            sensingUnit.processor.maximumAllowedDrift <= 0.5 and
            sensingUnit.processor.staleDataTimeout <= 2.0
        }
    }

    requirement def DigitalReportingRequirement {
        subject sensingUnit : IntelligentTemperatureSensingUnit;

        doc /* The sensing unit shall provide each measurement as a digital message containing value, uncertainty, status, health, sequence number, and timestamp. */

        require constraint {
            sensingUnit.communicationInterface.maximumLatency <= 0.050 and
            sensingUnit.communicationInterface.dataRate >= 100000.0
        }
    }

    requirement def SampleRateRequirement {
        subject sensingUnit : IntelligentTemperatureSensingUnit;

        doc /* The sensing unit shall support configurable measurement sampling up to at least 20 samples per second. */

        require constraint {
            sensingUnit.maximumSampleRate >= 20.0 and
            sensingUnit.adc.sampleRate >= 20.0
        }
    }

    requirement def PowerRequirement {
        subject sensingUnit : IntelligentTemperatureSensingUnit;

        doc /* The sensing unit shall operate from a nominal 3.3 V regulated supply and consume no more than 75 mW during active measurement. */

        require constraint {
            sensingUnit.nominalSupplyVoltage == 3.3 and
            sensingUnit.nominalPower <= 0.075
        }
    }

    requirement def FaultDetectionRequirement {
        subject sensingUnit : IntelligentTemperatureSensingUnit;

        doc /* The sensing unit shall enter a failed state if samples are stale longer than the configured stale-data timeout or self-test fails. */

        require constraint {
            sensingUnit.processor.staleDataTimeout <= 2.0
        }
    }

    satisfy MeasurementRangeRequirement by IntelligentTemperatureSensingUnit;
    satisfy AccuracyRequirement by IntelligentTemperatureSensingUnit;
    satisfy IntelligentSensorRequirement by IntelligentTemperatureSensingUnit;
    satisfy DigitalReportingRequirement by IntelligentTemperatureSensingUnit;
    satisfy SampleRateRequirement by IntelligentTemperatureSensingUnit;
    satisfy PowerRequirement by IntelligentTemperatureSensingUnit;
    satisfy FaultDetectionRequirement by IntelligentTemperatureSensingUnit;
}