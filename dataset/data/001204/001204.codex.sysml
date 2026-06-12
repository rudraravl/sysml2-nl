package PressureSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MeasurementTimestamp : ScalarValues::Real;
    attribute def ConfidenceRatio : ScalarValues::Real;
    attribute def SampleCount : ScalarValues::Integer;

    value def PressureValue :> ISQ::pressure {
        unit = SI::pascal;
    }

    value def TemperatureValue :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    value def VoltageValue :> ISQ::electricPotential {
        unit = SI::volt;
    }

    value def CurrentValue :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    value def FrequencyValue :> ISQ::frequency {
        unit = SI::hertz;
    }

    value def TimeValue :> ISQ::time {
        unit = SI::second;
    }

    value def DataRateValue :> ISQ::frequency {
        unit = SI::hertz;
    }

    item def PressureMedium {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute mediumName : ScalarValues::String;
    }

    item def RawPressureSignal {
        attribute bridgeVoltage : VoltageValue;
        attribute excitationVoltage : VoltageValue;
        attribute sensedPressure : PressureValue;
        attribute signalTimestamp : MeasurementTimestamp;
    }

    item def ConditionedPressureSignal {
        attribute analogVoltage : VoltageValue;
        attribute compensatedPressure : PressureValue;
        attribute signalTimestamp : MeasurementTimestamp;
    }

    item def DigitalPressureSample {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute timestamp : MeasurementTimestamp;
        attribute confidence : ConfidenceRatio;
        attribute valid : ScalarValues::Boolean;
    }

    item def PressureMeasurementMessage {
        attribute measuredPressure : PressureValue;
        attribute measuredTemperature : TemperatureValue;
        attribute timestamp : MeasurementTimestamp;
        attribute sampleSequence : SampleCount;
        attribute diagnosticStatus : ScalarValues::String;
        attribute confidence : ConfidenceRatio;
    }

    item def ElectricalPower {
        attribute supplyVoltage : VoltageValue;
        attribute supplyCurrent : CurrentValue;
    }

    port def PressureProcessPort {
        in item medium : PressureMedium;
    }

    port def AnalogSignalPort {
        out item rawSignal : RawPressureSignal;
    }

    port def ConditionedSignalPort {
        out item conditionedSignal : ConditionedPressureSignal;
    }

    port def DigitalSamplePort {
        out item sample : DigitalPressureSample;
    }

    port def MeasurementDataPort {
        out item message : PressureMeasurementMessage;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def DiagnosticPort {
        out item status : PressureMeasurementMessage;
    }

    part def PressureSensor {
        attribute measurementRangeMin : PressureValue = 0 [SI::pascal];
        attribute measurementRangeMax : PressureValue = 1000000 [SI::pascal];
        attribute overloadLimit : PressureValue = 2000000 [SI::pascal];
        attribute responseTime : TimeValue = 0.005 [SI::second];
        attribute sensitivity : ScalarValues::Real = 0.000004;
        attribute fullScaleAccuracy : ConfidenceRatio = 0.995;

        port processPort : PressureProcessPort;
        port rawOutput : AnalogSignalPort;
        port powerInput : PowerInputPort;

        action transducePressure {
            in item sensedMedium : PressureMedium;
            in item sensorPower : ElectricalPower;
            out item rawSignal : RawPressureSignal;

            first start;
            then validateSupply;
            then measureDeflection;
            then generateBridgeSignal;
            then done;

            action validateSupply {
                in item sensorPower : ElectricalPower;
                out attribute supplyAcceptable : ScalarValues::Boolean;
            }

            action measureDeflection {
                in item sensedMedium : PressureMedium;
                out attribute diaphragmDeflection : ScalarValues::Real;
            }

            action generateBridgeSignal {
                in attribute diaphragmDeflection : ScalarValues::Real;
                out item rawSignal : RawPressureSignal;
            }

            flow sensedMedium from processPort.medium to transducePressure.sensedMedium;
            flow sensorPower from powerInput.power to transducePressure.sensorPower;
            flow rawSignal from transducePressure.rawSignal to rawOutput.rawSignal;
        }
    }

    part def SignalConditioner {
        attribute gain : ScalarValues::Real = 125.0;
        attribute offsetVoltage : VoltageValue = 0.5 [SI::volt];
        attribute lowPassCutoff : FrequencyValue = 250 [SI::hertz];

        port rawInput : AnalogSignalPort;
        port conditionedOutput : ConditionedSignalPort;
        port powerInput : PowerInputPort;

        action conditionPressureSignal {
            in item rawSignal : RawPressureSignal;
            out item conditionedSignal : ConditionedPressureSignal;

            first start;
            then amplify;
            then filterNoise;
            then compensateOffset;
            then done;

            action amplify {
                in item rawSignal : RawPressureSignal;
                out attribute amplifiedVoltage : VoltageValue;
            }

            action filterNoise {
                in attribute amplifiedVoltage : VoltageValue;
                out attribute filteredVoltage : VoltageValue;
            }

            action compensateOffset {
                in attribute filteredVoltage : VoltageValue;
                in item rawSignal : RawPressureSignal;
                out item conditionedSignal : ConditionedPressureSignal;
            }

            flow rawSignal from rawInput.rawSignal to conditionPressureSignal.rawSignal;
            flow conditionedSignal from conditionPressureSignal.conditionedSignal to conditionedOutput.conditionedSignal;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : ScalarValues::Integer = 16;
        attribute referenceVoltage : VoltageValue = 3.3 [SI::volt];
        attribute samplingRate : DataRateValue = 100 [SI::hertz];
        attribute conversionTime : TimeValue = 0.0001 [SI::second];

        port analogInput : ConditionedSignalPort;
        port digitalOutput : DigitalSamplePort;
        port powerInput : PowerInputPort;

        action digitizePressure {
            in item conditionedSignal : ConditionedPressureSignal;
            out item sample : DigitalPressureSample;

            first start;
            then sampleAndHold;
            then quantize;
            then computePressure;
            then validateSample;
            then done;

            action sampleAndHold {
                in item conditionedSignal : ConditionedPressureSignal;
                out attribute heldVoltage : VoltageValue;
            }

            action quantize {
                in attribute heldVoltage : VoltageValue;
                out attribute adcCode : ScalarValues::Integer;
            }

            action computePressure {
                in attribute adcCode : ScalarValues::Integer;
                in item conditionedSignal : ConditionedPressureSignal;
                out item preliminarySample : DigitalPressureSample;
            }

            action validateSample {
                in item preliminarySample : DigitalPressureSample;
                out item sample : DigitalPressureSample;
            }

            flow conditionedSignal from analogInput.conditionedSignal to digitizePressure.conditionedSignal;
            flow sample from digitizePressure.sample to digitalOutput.sample;
        }
    }

    part def TemperatureCompensator {
        attribute compensationEnabled : ScalarValues::Boolean = true;
        attribute referenceTemperature : TemperatureValue = 298.15 [SI::kelvin];
        attribute pressureTemperatureCoefficient : ScalarValues::Real = 0.0002;

        port sampleInput : DigitalSamplePort;
        port compensatedOutput : DigitalSamplePort;

        action compensateTemperature {
            in item uncompensatedSample : DigitalPressureSample;
            out item compensatedSample : DigitalPressureSample;

            first start;
            then estimateThermalError;
            then correctPressure;
            then assignConfidence;
            then done;

            action estimateThermalError {
                in item uncompensatedSample : DigitalPressureSample;
                out attribute thermalPressureError : PressureValue;
            }

            action correctPressure {
                in item uncompensatedSample : DigitalPressureSample;
                in attribute thermalPressureError : PressureValue;
                out item correctedSample : DigitalPressureSample;
            }

            action assignConfidence {
                in item correctedSample : DigitalPressureSample;
                out item compensatedSample : DigitalPressureSample;
            }

            flow uncompensatedSample from sampleInput.sample to compensateTemperature.uncompensatedSample;
            flow compensatedSample from compensateTemperature.compensatedSample to compensatedOutput.sample;
        }
    }

    part def MeasurementController {
        attribute samplePeriod : TimeValue = 0.01 [SI::second];
        attribute startupDelay : TimeValue = 0.1 [SI::second];
        attribute faultRecoveryDelay : TimeValue = 1.0 [SI::second];
        attribute sequenceCounter : SampleCount = 0;

        port sampleInput : DigitalSamplePort;
        port measurementOutput : MeasurementDataPort;
        port diagnosticOutput : DiagnosticPort;

        action publishMeasurement {
            in item sample : DigitalPressureSample;
            out item message : PressureMeasurementMessage;

            first start;
            then incrementSequence;
            then encodeMessage;
            then done;

            action incrementSequence {
                out attribute nextSequence : SampleCount;
            }

            action encodeMessage {
                in item sample : DigitalPressureSample;
                in attribute nextSequence : SampleCount;
                out item message : PressureMeasurementMessage;
            }

            flow sample from sampleInput.sample to publishMeasurement.sample;
            flow message from publishMeasurement.message to measurementOutput.message;
        }

        state machine measurementLifecycle {
            state Off;
            state Initializing;
            state Measuring;
            state Degraded;
            state Faulted;

            initial then Off;

            transition powerApplied
                first Off
                accept PowerApplied
                then Initializing;

            transition initializationComplete
                first Initializing
                accept InitializationComplete
                if sensorSelfTestPassed
                then Measuring;

            transition initializationFailed
                first Initializing
                accept InitializationComplete
                if not sensorSelfTestPassed
                then Faulted;

            transition sampleValid
                first Measuring
                accept SampleEvaluated
                if latestSampleValid
                then Measuring;

            transition sampleInvalid
                first Measuring
                accept SampleEvaluated
                if not latestSampleValid
                then Degraded;

            transition degradedRecovered
                first Degraded
                accept SampleEvaluated
                if latestSampleValid
                then Measuring;

            transition persistentFault
                first Degraded
                accept FaultLimitExceeded
                then Faulted;

            transition resetFault
                first Faulted
                accept ResetCommand
                then Initializing;

            attribute sensorSelfTestPassed : ScalarValues::Boolean;
            attribute latestSampleValid : ScalarValues::Boolean;
        }
    }

    part def RegulatedPowerSupply {
        attribute nominalInputVoltage : VoltageValue = 24 [SI::volt];
        attribute regulatedVoltage : VoltageValue = 3.3 [SI::volt];
        attribute maximumOutputCurrent : CurrentValue = 0.05 [SI::ampere];

        port externalPowerInput : PowerInputPort;
        port sensorPowerOutput : PowerInputPort;
        port electronicsPowerOutput : PowerInputPort;

        action regulatePower {
            in item inputPower : ElectricalPower;
            out item sensorPower : ElectricalPower;
            out item electronicsPower : ElectricalPower;

            first start;
            then verifyInputRange;
            then convertVoltage;
            then limitCurrent;
            then done;

            action verifyInputRange {
                in item inputPower : ElectricalPower;
                out attribute inputValid : ScalarValues::Boolean;
            }

            action convertVoltage {
                in item inputPower : ElectricalPower;
                out item convertedPower : ElectricalPower;
            }

            action limitCurrent {
                in item convertedPower : ElectricalPower;
                out item sensorPower : ElectricalPower;
                out item electronicsPower : ElectricalPower;
            }
        }
    }

    part def PressureSensingUnit {
        attribute unitIdentifier : ScalarValues::String = "PSU-001";
        attribute operatingPressureMin : PressureValue = 0 [SI::pascal];
        attribute operatingPressureMax : PressureValue = 1000000 [SI::pascal];
        attribute measurementAccuracy : ConfidenceRatio = 0.99;
        attribute nominalSampleRate : DataRateValue = 100 [SI::hertz];
        attribute startupTime : TimeValue = 0.25 [SI::second];

        port processInput : PressureProcessPort;
        port powerInput : PowerInputPort;
        port measurementOutput : MeasurementDataPort;
        port diagnosticOutput : DiagnosticPort;

        part sensor : PressureSensor;
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part compensator : TemperatureCompensator;
        part controller : MeasurementController;
        part powerSupply : RegulatedPowerSupply;

        connection processToSensor connect processInput to sensor.processPort;
        connection powerToSupply connect powerInput to powerSupply.externalPowerInput;
        connection supplyToSensor connect powerSupply.sensorPowerOutput to sensor.powerInput;
        connection supplyToConditioner connect powerSupply.electronicsPowerOutput to conditioner.powerInput;
        connection supplyToAdc connect powerSupply.electronicsPowerOutput to adc.powerInput;
        connection sensorToConditioner connect sensor.rawOutput to conditioner.rawInput;
        connection conditionerToAdc connect conditioner.conditionedOutput to adc.analogInput;
        connection adcToCompensator connect adc.digitalOutput to compensator.sampleInput;
        connection compensatorToController connect compensator.compensatedOutput to controller.sampleInput;
        connection controllerToMeasurementOutput connect controller.measurementOutput to measurementOutput;
        connection controllerToDiagnosticOutput connect controller.diagnosticOutput to diagnosticOutput;

        action measurePressure {
            in item medium : PressureMedium;
            in item suppliedPower : ElectricalPower;
            out item pressureMessage : PressureMeasurementMessage;

            first receiveMediumAndPower;
            then powerSupply.regulatePower;
            then sensor.transducePressure;
            then conditioner.conditionPressureSignal;
            then adc.digitizePressure;
            then compensator.compensateTemperature;
            then controller.publishMeasurement;
            then done;

            action receiveMediumAndPower {
                in item medium : PressureMedium;
                in item suppliedPower : ElectricalPower;
                out item acceptedMedium : PressureMedium;
                out item acceptedPower : ElectricalPower;
            }

            flow medium from processInput.medium to measurePressure.medium;
            flow suppliedPower from powerInput.power to measurePressure.suppliedPower;
            flow pressureMessage from controller.publishMeasurement.message to measurementOutput.message;
        }
    }

    requirement def MeasurePressureRequirement {
        subject sensingUnit : PressureSensingUnit;

        require constraint {
            sensingUnit.operatingPressureMin == 0 [SI::pascal]
        }

        require constraint {
            sensingUnit.operatingPressureMax >= 1000000 [SI::pascal]
        }

        doc /* The pressure sensing unit shall measure pressure using a pressure sensor and provide a digital pressure measurement message. */
    }

    requirement def AccuracyRequirement {
        subject sensingUnit : PressureSensingUnit;

        require constraint {
            sensingUnit.measurementAccuracy >= 0.99
        }

        doc /* The pressure sensing unit shall report pressure with at least 99 percent confidence over the operating pressure range. */
    }

    requirement def SampleRateRequirement {
        subject sensingUnit : PressureSensingUnit;

        require constraint {
            sensingUnit.nominalSampleRate >= 100 [SI::hertz]
        }

        doc /* The pressure sensing unit shall produce pressure measurements at no less than 100 samples per second during normal operation. */
    }

    requirement def StartupRequirement {
        subject sensingUnit : PressureSensingUnit;

        require constraint {
            sensingUnit.startupTime <= 0.25 [SI::second]
        }

        doc /* The pressure sensing unit shall become ready to measure within 250 milliseconds after valid power is applied. */
    }

    requirement def DiagnosticRequirement {
        subject sensingUnit : PressureSensingUnit;

        require constraint {
            sensingUnit.controller.faultRecoveryDelay <= 1.0 [SI::second]
        }

        doc /* The pressure sensing unit shall detect invalid pressure samples and publish diagnostic status when degraded or faulted. */
    }

    requirement def SensorRangeRequirement {
        subject pressureSensor : PressureSensor;

        require constraint {
            pressureSensor.measurementRangeMin <= 0 [SI::pascal]
        }

        require constraint {
            pressureSensor.measurementRangeMax >= 1000000 [SI::pascal]
        }

        require constraint {
            pressureSensor.overloadLimit >= 2 * pressureSensor.measurementRangeMax
        }

        doc /* The pressure sensor shall cover the full sensing unit pressure range and tolerate twice full-scale pressure without damage. */
    }

    satisfy MeasurePressureRequirement by PressureSensingUnit;
    satisfy AccuracyRequirement by PressureSensingUnit;
    satisfy SampleRateRequirement by PressureSensingUnit;
    satisfy StartupRequirement by PressureSensingUnit;
    satisfy DiagnosticRequirement by PressureSensingUnit;
    satisfy SensorRangeRequirement by PressureSensor;

    part pressureSensingUnit_1 : PressureSensingUnit {
        attribute unitIdentifier = "PSU-PRESSURE-1000KPA";
        attribute operatingPressureMin = 0 [SI::pascal];
        attribute operatingPressureMax = 1000000 [SI::pascal];
        attribute measurementAccuracy = 0.99;
        attribute nominalSampleRate = 100 [SI::hertz];
        attribute startupTime = 0.25 [SI::second];

        part redefines sensor {
            attribute measurementRangeMin = 0 [SI::pascal];
            attribute measurementRangeMax = 1000000 [SI::pascal];
            attribute overloadLimit = 2000000 [SI::pascal];
            attribute responseTime = 0.005 [SI::second];
        }

        part redefines conditioner {
            attribute gain = 125.0;
            attribute offsetVoltage = 0.5 [SI::volt];
            attribute lowPassCutoff = 250 [SI::hertz];
        }

        part redefines adc {
            attribute resolutionBits = 16;
            attribute referenceVoltage = 3.3 [SI::volt];
            attribute samplingRate = 100 [SI::hertz];
        }

        part redefines controller {
            attribute samplePeriod = 0.01 [SI::second];
            attribute startupDelay = 0.1 [SI::second];
            attribute faultRecoveryDelay = 1.0 [SI::second];
        }
    }
}