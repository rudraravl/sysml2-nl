package YawRateSensingUnitModel {
    private import ScalarValues::*;
    import Definitions::*;

    package Definitions {
        attribute def AngularVelocityValue :> ScalarValues::Real;
        attribute def TemperatureValue :> ScalarValues::Real;
        attribute def VoltageValue :> ScalarValues::Real;
        attribute def CurrentValue :> ScalarValues::Real;
        attribute def FrequencyValue :> ScalarValues::Real;
        attribute def QualityScoreValue :> ScalarValues::Real;

        attribute def StartMeasurementCmd;
        attribute def StopMeasurementCmd;
        attribute def ResetCmd;
        attribute def ErrorDetected;
        attribute def CalibrationUpdate;

        attribute def RawAnalogSignal {
            attribute amplitude : ScalarValues::Real;
        }
        attribute def ConditionedAnalogSignal {
            attribute amplitude : ScalarValues::Real;
        }
        attribute def RawDigitalSample {
            attribute value : ScalarValues::Real;
            attribute timestamp : ScalarValues::Real;
            attribute temperature : TemperatureValue;
        }
        attribute def CalibratedSample {
            attribute value : ScalarValues::Real;
            attribute timestamp : ScalarValues::Real;
            attribute temperature : TemperatureValue;
        }
        attribute def FilteredSample {
            attribute value : ScalarValues::Real;
            attribute timestamp : ScalarValues::Real;
            attribute temperature : TemperatureValue;
        }
        attribute def YawRateOutput {
            attribute yawRate : AngularVelocityValue;
            attribute qualityScore : QualityScoreValue;
            attribute isValid : ScalarValues::Boolean;
            attribute timestamp : ScalarValues::Real;
        }
        attribute def CalibrationParameters {
            attribute offset : ScalarValues::Real;
            attribute scaleFactor : ScalarValues::Real;
            attribute tempCoeffA : ScalarValues::Real;
            attribute tempCoeffB : ScalarValues::Real;
        }

        port def PowerPort {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
        }
        port def DataOutputPort {
            attribute data : YawRateOutput;
        }
        port def CalibrationPort {
            attribute params : CalibrationParameters;
        }
        port def AnalogSignalPort {
            attribute signal : RawAnalogSignal;
        }
        port def ConditionedSignalPort {
            attribute signal : ConditionedAnalogSignal;
        }
        port def DigitalSamplePort {
            attribute sample : RawDigitalSample;
        }

        action def DetectRotationalMotion {
            out motion : RawAnalogSignal;
        }
        action def AmplifyAndFilter {
            in input : RawAnalogSignal;
            out output : ConditionedAnalogSignal;
        }
        action def ConvertAnalogToDigital {
            in input : ConditionedAnalogSignal;
            out output : RawDigitalSample;
        }
        action def AcquireSensorData {
            out sample : RawDigitalSample;
        }
        action def ApplyCalibration {
            in sample : RawDigitalSample;
            in params : CalibrationParameters;
            out calibrated : CalibratedSample;
        }
        action def DigitalFilterAction {
            in input : CalibratedSample;
            out output : FilteredSample;
        }
        action def ValidateResult {
            in input : FilteredSample;
            out yawRate : AngularVelocityValue;
            out qualityScore : QualityScoreValue;
            out isValid : ScalarValues::Boolean;
        }
        action def PackageOutput {
            in yawRate : AngularVelocityValue;
            in qualityScore : QualityScoreValue;
            in isValid : ScalarValues::Boolean;
            out output : YawRateOutput;
        }
        action def RunSelfTest {
            out passed : ScalarValues::Boolean;
        }
        action def LoadCalibrationSettings {
            out params : CalibrationParameters;
        }
        action def AcquireAndProcessPipeline {
            out output : YawRateOutput;
        }

        state def YawRateSensingUnitStates;

        part def MemsGyroscopicElement {
            attribute sensitivity : ScalarValues::Real;
            attribute noiseFloor : ScalarValues::Real;
            port rawOut : AnalogSignalPort;
            perform action detectMotion : DetectRotationalMotion;
        }

        part def SignalConditioner {
            attribute gain : ScalarValues::Real;
            attribute cutoffFrequency : FrequencyValue;
            port analogIn : AnalogSignalPort;
            port conditionedOut : ConditionedSignalPort;
            perform action amplifyAndFilter : AmplifyAndFilter;
        }

        part def AnalogToDigitalConverter {
            attribute resolutionBits : ScalarValues::Integer;
            attribute samplingRate : FrequencyValue;
            port conditionedIn : ConditionedSignalPort;
            port digitalOut : DigitalSamplePort;
            perform action convertAnalogToDigital : ConvertAnalogToDigital;
        }

        part def YawRateSensor {
            attribute sampleRate : FrequencyValue;
            port powerIn : PowerPort;
            port digitalOut : DigitalSamplePort;
            part memsGyro : MemsGyroscopicElement;
            part signalConditioner : SignalConditioner;
            part adc : AnalogToDigitalConverter;
            connect memsGyro.rawOut to signalConditioner.analogIn;
            connect signalConditioner.conditionedOut to adc.conditionedIn;
            connect adc.digitalOut to digitalOut;
        }

        part def CalibrationMemory {
            attribute storedParams : CalibrationParameters;
        }

        part def DigitalFilterUnit {
            attribute filterOrder : ScalarValues::Integer;
        }

        part def Validator {
            attribute thresholdMin : AngularVelocityValue;
            attribute thresholdMax : AngularVelocityValue;
        }

        part def OutputPackager {
        }

        part def DataProcessor {
            attribute internalMemory : CalibrationParameters;
            port powerIn : PowerPort;
            port rawDigitalIn : DigitalSamplePort;
            port calibIn : CalibrationPort;
            port processedOut : DataOutputPort;
            part calibrationMemory : CalibrationMemory;
            part digitalFilter : DigitalFilterUnit;
            part validator : Validator;
            part packager : OutputPackager;
            perform action applyCalibration : ApplyCalibration;
            perform action digitalFilterAction : DigitalFilterAction;
            perform action validateResult : ValidateResult;
            perform action packageOutput : PackageOutput;
        }

        part def YawRateSensingUnit {
            attribute deviceTemperature : TemperatureValue;
            attribute nominalVoltage : VoltageValue;
            attribute maxOperatingTemp : TemperatureValue;
            port powerPort : PowerPort;
            port dataOutputPort : DataOutputPort;
            port calibrationPort : CalibrationPort;
            part sensor : YawRateSensor;
            part processor : DataProcessor;
            connect sensor.digitalOut to processor.rawDigitalIn;
            connect processor.processedOut to dataOutputPort;
            connect calibrationPort to processor.calibIn;
            connect powerPort to sensor.powerIn;
            connect powerPort to processor.powerIn;
            perform action acquireSensorData : AcquireSensorData;
            perform action runSelfTest : RunSelfTest;
            perform action loadCalibration : LoadCalibrationSettings;
            exhibit state unitStates : YawRateSensingUnitStates;
        }

        requirement def YawRateAccuracyRequirement {
            doc
            /* The sensing unit shall report yaw rate within specified accuracy. */
            attribute maxError : AngularVelocityValue;
        }
        requirement def OutputCompletenessRequirement {
            doc
            /* The output shall include yaw rate, quality score, and validity flag. */
        }
        requirement def TemperatureCompensationRequirement {
            doc
            /* Calibration shall compensate for temperature-induced drift. */
        }
        requirement def PowerOnSequenceRequirement {
            doc
            /* On power-up, the unit shall self-test and load calibration before standby. */
        }
        requirement def ErrorHandlingRequirement {
            doc
            /* On error detection, the unit shall enter an error state and allow reset. */
        }
        requirement def CalibrationUpdateRequirement {
            doc
            /* The unit shall support calibration parameter updates via a dedicated port. */
        }
    }

    package Usages {
        private import Definitions::*;

        action acquireSensorData : AcquireSensorData;
        action runSelfTest : RunSelfTest;
        action loadCalibration : LoadCalibrationSettings;
        action acquireAndProcess : AcquireAndProcessPipeline;

        requirement yawAccuracy : YawRateAccuracyRequirement {
            attribute maxError = 0.1;
        }
        requirement outputComplete : OutputCompletenessRequirement;
        requirement tempCompensation : TemperatureCompensationRequirement;
        requirement powerOnSequence : PowerOnSequenceRequirement;
        requirement errorHandling : ErrorHandlingRequirement;
        requirement calibrationUpdate : CalibrationUpdateRequirement;

        part yawRateUnit : YawRateSensingUnit {
            attribute nominalVoltage = 12.0;
            attribute maxOperatingTemp = 85.0;
            attribute deviceTemperature = 25.0;

            part sensor : YawRateSensor {
                attribute sampleRate = 1000.0;
                part memsGyro : MemsGyroscopicElement {
                    attribute sensitivity = 0.001;
                    attribute noiseFloor = 0.0001;
                }
                part signalConditioner : SignalConditioner {
                    attribute gain = 1000.0;
                    attribute cutoffFrequency = 500.0;
                }
                part adc : AnalogToDigitalConverter {
                    attribute resolutionBits = 16;
                    attribute samplingRate = 1000.0;
                }
            }

            part processor : DataProcessor {
                attribute internalMemory : CalibrationParameters;
                part digitalFilter : DigitalFilterUnit {
                    attribute filterOrder = 4;
                }
                part validator : Validator {
                    attribute thresholdMin = -10.0;
                    attribute thresholdMax = 10.0;
                }
                part packager : OutputPackager;
            }

            satisfy yawAccuracy;
            satisfy outputComplete;
            satisfy tempCompensation;
            satisfy powerOnSequence;
            satisfy errorHandling;
            satisfy calibrationUpdate;
        }

        state unitStates : YawRateSensingUnitStates {
            entry; then initializing;
            state initializing {
                entry runSelfTest;
                do loadCalibration;
            }
            transition init_to_standby
                first initializing
                accept when runSelfTest.passed
                then standby;
            transition init_to_error
                first initializing
                accept when not runSelfTest.passed
                then error;
            state standby;
            transition standby_calib
                first standby
                accept CalibrationUpdate
                then standby;
            transition standby_to_active
                first standby
                accept StartMeasurementCmd
                then active;
            state active {
                do acquireAndProcess;
            }
            transition active_to_standby
                first active
                accept StopMeasurementCmd
                then standby;
            transition active_to_error
                first active
                accept ErrorDetected
                then error;
            state error;
            transition error_to_init
                first error
                accept ResetCmd
                then initializing;
        }
    }
}
