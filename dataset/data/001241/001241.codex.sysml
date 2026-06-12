package SensingUnitModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def RealValue :> ScalarValues::Real;

    item def ElectricalPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
    }

    item def SensorExcitation {
        attribute supplyVoltage : ElectricPotential;
        attribute biasCurrent : ElectricCurrent;
    }

    item def RawSample {
        attribute channelId : Integer;
        attribute sampleTime : Time;
        attribute adcCode : Integer;
        attribute inputVoltage : ElectricPotential;
    }

    item def CalibratedMeasurement {
        attribute channelId : Integer;
        attribute sampleTime : Time;
        attribute measuredQuantity : RealValue;
        attribute standardUncertainty : RealValue;
        attribute quality : MeasurementQuality;
    }

    item def MeasurementFrame {
        attribute frameTime : Time;
        attribute fusedQuantity : RealValue;
        attribute expandedUncertainty : RealValue;
        attribute activeSensorCount : Integer;
        attribute status : UnitStatus;
    }

    enum def MeasurementQuality {
        enum nominal;
        enum saturated;
        enum noisy;
        enum failed;
        enum invalid;
    }

    enum def UnitStatus {
        enum initializing;
        enum ready;
        enum measuring;
        enum degraded;
        enum faulted;
        enum calibrating;
        enum poweredOff;
    }

    enum def SensorHealth {
        enum healthy;
        enum drifting;
        enum disconnected;
        enum shorted;
        enum outOfRange;
    }

    value def SampleRate :> RealValue {
        unit = Hz;
    }

    value def ResolutionBits :> Integer;

    value def TemperatureCelsius :> RealValue {
        unit = degC;
    }

    value def NoiseDensity :> RealValue;

    value def RelevantQuantity :> RealValue {
        doc /* Quantity of interest measured by the sensing unit. */
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def ExcitationPort {
        out item excitation : SensorExcitation;
    }

    port def AnalogSignalPort {
        in item sample : RawSample;
        out item excitation : SensorExcitation;
    }

    port def DigitalSamplePort {
        out item sample : RawSample;
    }

    port def MeasurementOutputPort {
        out item frame : MeasurementFrame;
    }

    port def CommandPort {
        in item command : Command;
    }

    port def StatusPort {
        out item status : UnitStatus;
    }

    item def Command {
        attribute requestedMode : UnitStatus;
        attribute requestedSampleRate : SampleRate;
    }

    part def SensorElement {
        attribute channelId : Integer;
        attribute sensitivity : RealValue;
        attribute offset : RealValue;
        attribute noiseDensity : NoiseDensity;
        attribute fullScaleQuantity : RelevantQuantity;
        attribute health : SensorHealth = SensorHealth::healthy;
        attribute operatingTemperature : TemperatureCelsius;

        port excitationPort : ExcitationPort;
        port analogPort : AnalogSignalPort;

        action sense {
            in quantity : RelevantQuantity;
            in excitation : SensorExcitation;
            out raw : RawSample;

            first start;
            then convertQuantity;
            then applySensitivity;
            then addOffsetAndNoise;
            then emitRawSample;
        }

        state machine healthMonitor {
            state healthy;
            state drifting;
            state disconnected;
            state shorted;
            state outOfRange;

            entry state healthy;

            transition healthy_to_drifting
                first healthy
                accept when offset > 0.05
                then drifting;

            transition healthy_to_outOfRange
                first healthy
                accept when operatingTemperature > 85.0
                then outOfRange;

            transition drifting_to_healthy
                first drifting
                accept when offset <= 0.02
                then healthy;

            transition any_to_disconnected
                first healthy
                accept when sensitivity == 0.0
                then disconnected;

            transition any_to_shorted
                first healthy
                accept when noiseDensity > 10.0
                then shorted;
        }
    }

    part def SensorArray {
        attribute elementCount : Integer = 8;
        attribute activeElementCount : Integer;
        attribute arraySampleRate : SampleRate = 1000.0;
        attribute arrayHealth : UnitStatus;

        port excitationIn : ExcitationPort;
        port samplesOut : DigitalSamplePort;

        part sensor[8] : SensorElement {
            attribute fullScaleQuantity = 100.0;
        }

        action acquireArraySamples {
            in measuredQuantity : RelevantQuantity;
            out samples[8] : RawSample;

            first distributeExcitation;
            then sampleAllElements;
            then rejectFailedElements;
            then publishRawSamples;
        }
    }

    part def AnalogFrontEnd {
        attribute gain : RealValue = 16.0;
        attribute antiAliasCutoff : Frequency = 400.0 [Hz];
        attribute inputImpedance : Resistance = 1000000.0 [Ohm];
        attribute noiseFloor : NoiseDensity = 0.001;

        port analogIn : AnalogSignalPort;
        port conditionedOut : DigitalSamplePort;

        action conditionSignal {
            in raw : RawSample;
            out conditioned : RawSample;

            first receiveAnalogSignal;
            then filterAntiAlias;
            then amplify;
            then clampToAdcRange;
            then outputConditionedSample;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolution : ResolutionBits = 16;
        attribute referenceVoltage : ElectricPotential = 3.3 [V];
        attribute conversionRate : SampleRate = 1000.0;
        attribute integralNonlinearity : RealValue = 0.5;

        port conditionedIn : DigitalSamplePort;
        port digitalOut : DigitalSamplePort;

        action digitize {
            in conditioned : RawSample;
            out digital : RawSample;

            first sampleAndHold;
            then quantize;
            then timestamp;
            then publishDigitalSample;
        }
    }

    part def CalibrationProcessor {
        attribute calibrationTemperature : TemperatureCelsius = 25.0;
        attribute gainCoefficients[8] : RealValue;
        attribute offsetCoefficients[8] : RealValue;
        attribute maxAllowedResidual : RealValue = 0.02;

        port rawIn : DigitalSamplePort;
        port calibratedOut : MeasurementOutputPort;

        action calibrateSample {
            in raw : RawSample;
            out calibrated : CalibratedMeasurement;

            first selectChannelCoefficients;
            then subtractOffset;
            then applyGain;
            then compensateTemperature;
            then estimateUncertainty;
            then classifyQuality;
        }
    }

    part def FusionProcessor {
        attribute minimumValidSensors : Integer = 5;
        attribute outlierThreshold : RealValue = 3.0;
        attribute fusionLatency : Time = 0.010 [s];

        port calibratedIn : MeasurementOutputPort;
        port frameOut : MeasurementOutputPort;

        action fuseMeasurements {
            in calibrated[8] : CalibratedMeasurement;
            out frame : MeasurementFrame;

            first collectCalibratedMeasurements;
            then removeInvalidMeasurements;
            then rejectOutliers;
            then computeWeightedAverage;
            then computeExpandedUncertainty;
            then publishMeasurementFrame;
        }
    }

    part def PowerConditioner {
        attribute inputVoltageMin : ElectricPotential = 9.0 [V];
        attribute inputVoltageMax : ElectricPotential = 36.0 [V];
        attribute regulatedVoltage : ElectricPotential = 3.3 [V];
        attribute maximumCurrent : ElectricCurrent = 0.25 [A];

        port powerIn : PowerInputPort;
        port excitationOut : ExcitationPort;

        action regulatePower {
            in supply : ElectricalPower;
            out excitation : SensorExcitation;

            first validateInputRange;
            then regulateVoltage;
            then limitCurrent;
            then distributeExcitation;
        }
    }

    part def DiagnosticManager {
        attribute selfTestInterval : Time = 10.0 [s];
        attribute lastFaultCode : Integer = 0;
        attribute currentStatus : UnitStatus = UnitStatus::initializing;

        port sampleIn : DigitalSamplePort;
        port statusOut : StatusPort;

        action runSelfTest {
            first checkPowerRails;
            then checkSensorContinuity;
            then checkNoiseLevel;
            then checkSampleTiming;
            then updateStatus;
        }

        state machine unitStatusMachine {
            state poweredOff;
            state initializing;
            state ready;
            state measuring;
            state degraded;
            state faulted;
            state calibrating;

            entry state poweredOff;

            transition power_on
                first poweredOff
                accept UnitStatus::initializing
                then initializing;

            transition initialization_complete
                first initializing
                accept when lastFaultCode == 0
                then ready;

            transition begin_measurement
                first ready
                accept UnitStatus::measuring
                then measuring;

            transition measurement_degraded
                first measuring
                accept when currentStatus == UnitStatus::degraded
                then degraded;

            transition degraded_recovered
                first degraded
                accept when currentStatus == UnitStatus::ready
                then measuring;

            transition enter_calibration
                first ready
                accept UnitStatus::calibrating
                then calibrating;

            transition calibration_complete
                first calibrating
                accept UnitStatus::ready
                then ready;

            transition fault_detected
                first measuring
                accept when lastFaultCode != 0
                then faulted;

            transition shutdown
                first ready
                accept UnitStatus::poweredOff
                then poweredOff;
        }
    }

    part def SensingUnit {
        attribute requiredSampleRate : SampleRate = 1000.0;
        attribute measurementRangeMin : RelevantQuantity = 0.0;
        attribute measurementRangeMax : RelevantQuantity = 100.0;
        attribute maximumExpandedUncertainty : RealValue = 0.5;
        attribute responseTime : Time = 0.050 [s];
        attribute status : UnitStatus = UnitStatus::initializing;

        port powerInput : PowerInputPort;
        port commandInput : CommandPort;
        port measurementOutput : MeasurementOutputPort;
        port statusOutput : StatusPort;

        part powerConditioner : PowerConditioner;
        part sensorArray : SensorArray;
        part analogFrontEnd : AnalogFrontEnd;
        part adc : AnalogToDigitalConverter;
        part calibrationProcessor : CalibrationProcessor;
        part fusionProcessor : FusionProcessor;
        part diagnostics : DiagnosticManager;

        connect powerInput to powerConditioner.powerIn;
        connect powerConditioner.excitationOut to sensorArray.excitationIn;
        connect sensorArray.samplesOut to analogFrontEnd.analogIn;
        connect analogFrontEnd.conditionedOut to adc.conditionedIn;
        connect adc.digitalOut to calibrationProcessor.rawIn;
        connect calibrationProcessor.calibratedOut to fusionProcessor.calibratedIn;
        connect fusionProcessor.frameOut to measurementOutput;
        connect adc.digitalOut to diagnostics.sampleIn;
        connect diagnostics.statusOut to statusOutput;

        action measureRelevantQuantity {
            in physicalQuantity : RelevantQuantity;
            out reportedMeasurement : MeasurementFrame;

            first powerSensorArray;
            then acquireRawSamples;
            then conditionAnalogSignals;
            then convertToDigitalSamples;
            then calibrateChannelMeasurements;
            then fuseChannelMeasurements;
            then reportMeasurement;
        }

        state machine operatingBehavior {
            state off;
            state initializing;
            state standby;
            state measuring;
            state calibrating;
            state degraded;
            state faulted;

            entry state off;

            transition off_to_initializing
                first off
                accept UnitStatus::initializing
                then initializing;

            transition initializing_to_standby
                first initializing
                accept when diagnostics.lastFaultCode == 0
                then standby;

            transition standby_to_measuring
                first standby
                accept UnitStatus::measuring
                then measuring;

            transition measuring_to_degraded
                first measuring
                accept when sensorArray.activeElementCount < sensorArray.elementCount and sensorArray.activeElementCount >= fusionProcessor.minimumValidSensors
                then degraded;

            transition degraded_to_measuring
                first degraded
                accept when sensorArray.activeElementCount == sensorArray.elementCount
                then measuring;

            transition measuring_to_faulted
                first measuring
                accept when sensorArray.activeElementCount < fusionProcessor.minimumValidSensors
                then faulted;

            transition standby_to_calibrating
                first standby
                accept UnitStatus::calibrating
                then calibrating;

            transition calibrating_to_standby
                first calibrating
                accept UnitStatus::ready
                then standby;

            transition any_to_off
                first standby
                accept UnitStatus::poweredOff
                then off;
        }
    }

    requirement def MeasureRelevantQuantityRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.measurementRangeMin <= sensingUnit.measurementRangeMax
        }

        require constraint {
            sensingUnit.requiredSampleRate >= 100.0
        }

        require constraint {
            sensingUnit.sensorArray.elementCount >= sensingUnit.fusionProcessor.minimumValidSensors
        }
    }

    requirement def AccuracyRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.maximumExpandedUncertainty <= 0.5
        }
    }

    requirement def ResponseTimeRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.responseTime <= 0.050 [s]
        }
    }

    requirement def SensorArrayRedundancyRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.sensorArray.elementCount == 8
        }

        require constraint {
            sensingUnit.fusionProcessor.minimumValidSensors <= 5
        }
    }

    requirement def PowerInputRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.powerConditioner.inputVoltageMin >= 9.0 [V]
        }

        require constraint {
            sensingUnit.powerConditioner.inputVoltageMax <= 36.0 [V]
        }
    }

    part sensingUnit : SensingUnit;

    satisfy MeasureRelevantQuantityRequirement by sensingUnit;
    satisfy AccuracyRequirement by sensingUnit;
    satisfy ResponseTimeRequirement by sensingUnit;
    satisfy SensorArrayRedundancyRequirement by sensingUnit;
    satisfy PowerInputRequirement by sensingUnit;
}