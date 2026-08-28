package YawRateSensingUnitModel {

    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----

    value type AngularVelocityValue > Real {
        unit 'rad/s';
    }

    value type TemperatureValue > Real {
        unit 'degC';
    }

    value type VoltageValue > Real {
        unit 'V';
    }

    value type TimestampValue > Integer {
        unit 'ms';
    }

    value type QualityScoreValue > Real {
        unit '%';
        constraint { self >= 0.0 and self <= 100.0 }
    }

    value type OffsetValue > Real {
        unit 'rad/s';
    }

    value type ScaleFactorValue > Real {
        unit '1';
    }

    value type TemperatureCoefficientValue > Real {
        unit '1/degC';
    }

    // ---- Item definitions ----

    item def RawAnalogSignal {
        attribute voltage : VoltageValue;
        attribute noiseLevel : VoltageValue;
    }

    item def ConditionedAnalogSignal {
        attribute voltage : VoltageValue;
        attribute gain : Real;
    }

    item def DigitalSample {
        attribute rawValue : Real;
        attribute timestamp : TimestampValue;
        attribute temperature : TemperatureValue;
    }

    item def CalibratedData {
        attribute calibratedValue : AngularVelocityValue;
        attribute timestamp : TimestampValue;
        attribute temperature : TemperatureValue;
    }

    item def FilteredData {
        attribute filteredValue : AngularVelocityValue;
        attribute timestamp : TimestampValue;
        attribute temperature : TemperatureValue;
    }

    item def YawRateOutput {
        attribute yawRate : AngularVelocityValue;
        attribute qualityScore : QualityScoreValue;
        attribute isValid : Boolean;
        attribute timestamp : TimestampValue;
        attribute temperature : TemperatureValue;
    }

    item def CalibrationParameters {
        attribute offset : OffsetValue;
        attribute scaleFactor : ScaleFactorValue;
        attribute tempCoefficient : TemperatureCoefficientValue;
        attribute referenceTemperature : TemperatureValue;
    }

    item def StartMeasurementCommand;
    item def StopMeasurementCommand;
    item def ResetCommand;
    item def ErrorNotification {
        attribute errorCode : Integer;
        attribute description : String;
    }

    // ---- Port definitions ----

    port def PowerPort {
        attribute voltage : VoltageValue;
        in attribute suppliedVoltage : VoltageValue;
    }

    port def DataOutputPort {
        out item yawRateOutput : YawRateOutput;
    }

    port def CalibrationPort {
        in item calibrationParameters : CalibrationParameters;
        out attribute ack : Boolean;
    }

    port def CommandPort {
        in item startMeasurement : StartMeasurementCommand;
        in item stopMeasurement : StopMeasurementCommand;
        in item reset : ResetCommand;
    }

    port def DigitalStreamPort {
        out item digitalSample : DigitalSample;
    }

    port def AnalogSignalPort {
        out item rawAnalogSignal : RawAnalogSignal;
        out item conditionedAnalogSignal : ConditionedAnalogSignal;
    }

    // ---- Interfaces ----

    interface def PowerInterface {
        end supplier : PowerPort;
        end consumer : PowerPort;
        flow supplier.suppliedVoltage to consumer.suppliedVoltage;
    }

    interface def DigitalStreamInterface {
        end source : DigitalStreamPort;
        end destination : DigitalStreamPort;
        flow of source.digitalSample to destination.digitalSample;
    }

    interface def DataOutputInterface {
        end source : DataOutputPort;
        end destination : DataOutputPort;
        flow of source.yawRateOutput to destination.yawRateOutput;
    }

    interface def CalibrationInterface {
        end updater : CalibrationPort;
        end target : CalibrationPort;
        flow of updater.calibrationParameters to target.calibrationParameters;
        flow of target.ack to updater.ack;
    }

    // ---- Part definitions ----

    part def MEMSGyroscope {
        attribute sensitivity : Real = 0.01;
        port out analogOut : AnalogSignalPort;
        attribute detectedAngularVelocity : AngularVelocityValue;

        action def DetectRotation {
            in angularVelocity : AngularVelocityValue;
            out signal : RawAnalogSignal;
        }

        perform DetectRotation {
            in angularVelocity = detectedAngularVelocity;
            out signal = analogOut.rawAnalogSignal;
        }
    }

    part def SignalConditioner {
        attribute gain : Real = 100.0;
        attribute cutoffFrequency : Real = 500.0;
        port in analogIn : AnalogSignalPort;
        port out analogOut : AnalogSignalPort;

        action def AmplifyAndFilter {
            in rawSignal : RawAnalogSignal;
            out conditionedSignal : ConditionedAnalogSignal;
        }

        perform AmplifyAndFilter {
            in rawSignal = analogIn.rawAnalogSignal;
            out conditionedSignal = analogOut.conditionedAnalogSignal;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute samplingRate : Real = 1000.0;
        port in analogIn : AnalogSignalPort;
        port out digitalOut : DigitalStreamPort;

        action def Convert {
            in conditionedSignal : ConditionedAnalogSignal;
            in currentTemperature : TemperatureValue;
            out sample : DigitalSample;
        }

        perform Convert {
            in conditionedSignal = analogIn.conditionedAnalogSignal;
            in currentTemperature = currentTemperature;
            out sample = digitalOut.digitalSample;
        }

        attribute currentTemperature : TemperatureValue = 25.0 [degC];
    }

    part def YawRateSensor {
        part memsGyroscope : MEMSGyroscope;
        part signalConditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;

        port in sensorPower : PowerPort;
        port out digitalStream : DigitalStreamPort;

        connection analogLink1 connect memsGyroscope.analogOut to signalConditioner.analogIn;
        connection analogLink2 connect signalConditioner.analogOut to adc.analogIn;
        connection digitalLink connect adc.digitalOut to digitalStream;
        connection powerLink connect sensorPower to memsGyroscope::powerRef;
    }

    part def CalibrationMemory {
        attribute storedParameters : CalibrationParameters;
        port out parametersOut : CalibrationPort;

        action def LoadParameters {
            out parameters : CalibrationParameters;
        }

        perform LoadParameters {
            out parameters = storedParameters;
        }
    }

    part def CalibrationApplier {
        port in digitalIn : DigitalStreamPort;
        port in parametersIn : CalibrationPort;
        port out calibratedOut : DigitalStreamPort;

        action def ApplyCalibration {
            in sample : DigitalSample;
            in parameters : CalibrationParameters;
            out calibrated : CalibratedData;
        }

        perform ApplyCalibration {
            in sample = digitalIn.digitalSample;
            in parameters = parametersIn.calibrationParameters;
            out calibrated = calibratedOut.digitalSample;
        }
    }

    part def DigitalFilter {
        attribute filterOrder : Integer = 4;
        attribute cutoffFrequency : Real = 50.0;
        port in filterIn : DigitalStreamPort;
        port out filterOut : DigitalStreamPort;

        action def FilterData {
            in calibrated : CalibratedData;
            out filtered : FilteredData;
        }

        perform FilterData {
            in calibrated = filterIn.digitalSample;
            out filtered = filterOut.digitalSample;
        }
    }

    part def DataValidator {
        attribute maxValidYawRate : AngularVelocityValue = 300.0 [rad/s];
        attribute minQualityThreshold : QualityScoreValue = 50.0 [%];
        port in validateIn : DigitalStreamPort;
        port out validateOut : DataOutputPort;

        action def Validate {
            in filtered : FilteredData;
            out output : YawRateOutput;
        }

        perform Validate {
            in filtered = validateIn.digitalSample;
            out output = validateOut.yawRateOutput;
        }
    }

    part def DataProcessor {
        part calibrationMemory : CalibrationMemory;
        part calibrationApplier : CalibrationApplier;
        part digitalFilter : DigitalFilter;
        part dataValidator : DataValidator;

        port in processorPower : PowerPort;
        port in rawDigitalStream : DigitalStreamPort;
        port in calibrationUpdate : CalibrationPort;
        port out dataOutput : DataOutputPort;

        connection paramLink connect calibrationMemory.parametersOut to calibrationApplier.parametersIn;
        connection rawLink connect rawDigitalStream to calibrationApplier.digitalIn;
        connection calibratedLink connect calibrationApplier.calibratedOut to digitalFilter.filterIn;
        connection filteredLink connect digitalFilter.filterOut to dataValidator.validateIn;
        connection outputLink connect dataValidator.validateOut to dataOutput;
        connection calibUpdateLink connect calibrationUpdate to calibrationMemory::updatePort;
    }

    // ---- Main Yaw Rate Sensing Unit ----

    part def YawRateSensingUnit {
        part yawRateSensor : YawRateSensor;
        part dataProcessor : DataProcessor;

        port powerSupply : PowerPort;
        port dataOutput : DataOutputPort;
        port calibrationPort : CalibrationPort;
        port commandPort : CommandPort;

        connection powerToSensor connect powerSupply to yawRateSensor.sensorPower;
        connection powerToProcessor connect powerSupply to dataProcessor.processorPower;
        connection sensorToProcessor connect yawRateSensor.digitalStream to dataProcessor.rawDigitalStream;
        connection processorOutput connect dataProcessor.dataOutput to dataOutput;
        connection calibrationToProcessor connect calibrationPort to dataProcessor.calibrationUpdate;

        attribute selfTestResult : Boolean;
        attribute initializationComplete : Boolean;
        attribute currentYawRate : AngularVelocityValue;
        attribute lastOutput : YawRateOutput;

        // ---- State Machine ----

        state def UnitStateMachine {
            entry;
            exit;

            state initialization {
                entry {
                    selfTestResult = true;
                    initializationComplete = true;
                }
                do {
                    // Run self-test and load calibration settings
                    dataProcessor.calibrationMemory.LoadParameters();
                }
                transition to standby
                    when initializationComplete == true;
            }

            state standby {
                entry {
                    currentYawRate = 0.0 [rad/s];
                }
                transition to active
                    when commandPort.startMeasurement is received;
                transition to errorState
                    when selfTestResult == false;
            }

            state active {
                entry;
                do {
                    // Continuously acquire sensor data, process it, and output final yaw rate
                    yawRateSensor.memsGyroscope.DetectRotation();
                    yawRateSensor.signalConditioner.AmplifyAndFilter();
                    yawRateSensor.adc.Convert();
                    dataProcessor.calibrationApplier.ApplyCalibration();
                    dataProcessor.digitalFilter.FilterData();
                    dataProcessor.dataValidator.Validate();
                }
                transition to standby
                    when commandPort.stopMeasurement is received;
                transition to errorState
                    when dataProcessor.dataValidator.validateIn.digitalSample.rawValue > 300.0;
            }

            state errorState {
                entry {
                    // Emit error notification
                }
                transition to initialization
                    when commandPort.reset is received;
            }
        }

        perform UnitStateMachine;

        // ---- Requirements ----

        requirement def PowerRequirement {
            subject unit : YawRateSensingUnit;
            constraint { unit.powerSupply.suppliedVoltage >= 4.5 [V] and unit.powerSupply.suppliedVoltage <= 5.5 [V] }
        }

        requirement def MeasurementRangeRequirement {
            subject unit : YawRateSensingUnit;
            constraint { unit.currentYawRate >= -300.0 [rad/s] and unit.currentYawRate <= 300.0 [rad/s] }
        }

        requirement def OutputCompletenessRequirement {
            subject unit : YawRateSensingUnit;
            constraint {
                unit.lastOutput.yawRate is set and
                unit.lastOutput.qualityScore is set and
                unit.lastOutput.isValid is set and
                unit.lastOutput.timestamp is set and
                unit.lastOutput.temperature is set
            }
        }

        requirement def InitializationRequirement {
            subject unit : YawRateSensingUnit;
            constraint {
                unit.UnitStateMachine.initialization is entered and
                unit.UnitStateMachine.standby is entered after initialization
            }
        }

        requirement def CalibrationUpdateRequirement {
            subject unit : YawRateSensingUnit;
            constraint {
                unit.calibrationPort.calibrationParameters is received implies
                unit.dataProcessor.calibrationMemory.storedParameters is updated
            }
        }

        requirement def ErrorHandlingRequirement {
            subject unit : YawRateSensingUnit;
            constraint {
                unit.UnitStateMachine.errorState is entered implies
                unit.UnitStateMachine.initialization is entered after reset command
            }
        }

        satisfy PowerRequirement by powerSupply;
        satisfy MeasurementRangeRequirement by currentYawRate;
        satisfy OutputCompletenessRequirement by lastOutput;
        satisfy InitializationRequirement by UnitStateMachine;
        satisfy CalibrationUpdateRequirement by calibrationPort;
        satisfy ErrorHandlingRequirement by UnitStateMachine;
    }

    // ---- Top-level context ----

    part YawRateSensingUnitInstance : YawRateSensingUnit {
        // External power source interface
        port powerSupply : PowerPort {
            in suppliedVoltage = 5.0 [V];
        }

        // Calibration parameters example
        attribute defaultCalibration : CalibrationParameters {
            offset = 0.02 [rad/s];
            scaleFactor = 1.001;
            tempCoefficient = 0.0005 [1/degC];
            referenceTemperature = 25.0 [degC];
        }
    }

}
