package CapacitiveLeafMoistureSensingUnit {

    import ScalarValues::*;

    // ====== VALUE TYPES WITH UNITS ======
    value type CapacitanceValue :> Real {
        doc /* Capacitance measured in picofarads (pF) */
    }

    value type TemperatureValue :> Real {
        doc /* Temperature in degrees Celsius (degC) */
    }

    value type MoistureValue :> Real {
        doc /* Leaf moisture content as a percentage (0..100) */
    }

    value type VoltageValue :> Real {
        doc /* Supply voltage in volts (V) */
    }

    value type TimeMs :> Real {
        doc /* Elapsed time in milliseconds (ms) */
    }

    value type TimeS :> Real {
        doc /* Elapsed time in seconds (s) */
    }

    // ====== ITEM DEFINITIONS ======
    item def RawSensorReading {
        attribute capacitance : CapacitanceValue;
        attribute temperature : TemperatureValue;
        attribute timestamp : TimeS;
        attribute sequenceId : Integer;
    }

    item def ConditionedSignal {
        attribute capacitance : CapacitanceValue;
        attribute compensatedTemperature : TemperatureValue;
        attribute timestamp : TimeS;
        attribute noiseFloor : Real;
        attribute gain : Real;
        attribute sequenceId : Integer;
    }

    item def ProcessedMeasurement {
        attribute moisturePercent : MoistureValue;
        attribute quality : String;
        attribute valid : Boolean;
        attribute timestamp : TimeS;
        attribute sequenceId : Integer;
    }

    item def CalibrationParameters {
        attribute dryReferenceCapacitance : CapacitanceValue;
        attribute wetReferenceCapacitance : CapacitanceValue;
        attribute lastCalibrationTime : TimeS;
        attribute validForDays : Integer;
    }

    item def RecalibrationRequest {
        attribute trigger : Boolean;
        attribute requestId : Integer;
        attribute force : Boolean;
    }

    item def OutputMessage {
        attribute payload : String;
        attribute format : String;
        attribute timestamp : TimeS;
        attribute sequenceId : Integer;
    }

    // ====== PORT DEFINITIONS ======
    port def RawReadingOut {
        out reading : RawSensorReading [0..*];
    }

    port def RawReadingIn {
        in reading : RawSensorReading [0..*];
    }

    port def ConditionedOut {
        out signal : ConditionedSignal [0..*];
    }

    port def ConditionedIn {
        in signal : ConditionedSignal [0..*];
    }

    port def ProcessedOut {
        out measurement : ProcessedMeasurement [0..*];
    }

    port def ProcessedIn {
        in measurement : ProcessedMeasurement [0..*];
    }

    port def CalibrationExchange {
        in request : RecalibrationRequest [0..*];
        out parameters : CalibrationParameters [0..*];
    }

    port def DataOutput {
        out message : OutputMessage [0..*];
    }

    port def PowerInput {
        in supplyVoltage : VoltageValue;
    }

    // ====== PART DEFINITIONS ======

    part def LeafSensor {
        doc /* Capacitive leaf moisture sensor head: measures raw capacitance and ambient temperature directly on the leaf surface */

        port rawOut : RawReadingOut;
        port powerIn : PowerInput;

        attribute minOperatingTemp : TemperatureValue = -20;
        attribute maxOperatingTemp : TemperatureValue = 85;
        attribute samplingInterval : TimeMs = 100;
        attribute sequenceCounter : Integer = 0;
        attribute lastReading : RawSensorReading;

        action def takeRawReading {
            in measuredCapacitance : CapacitanceValue;
            in ambientTemp : TemperatureValue;
            return reading : RawSensorReading;
        }

        action def acquireSample {
            doc /* Performs one capacitive and temperature acquisition on the leaf */
            out reading : RawSensorReading;
        }

        action acquire : acquireSample;

        state def SensorState {
            state idle;
            state sampling;
            transition idle -> sampling when startSample;
            transition sampling -> idle when sampleComplete;
        }

        state sensorState : SensorState;
    }

    part def SignalConditioner {
        doc /* Filters noise, amplifies the signal, and compensates for temperature-dependent drift */

        port rawIn : RawReadingIn;
        port conditionedOut : ConditionedOut;
        port powerIn : PowerInput;

        attribute noiseFloor : Real = 0.0;
        attribute gain : Real = 1.0;
        attribute referenceTemperature : TemperatureValue = 25;
        attribute temperatureCompensationCoefficient : Real = 0.05;
        attribute filterCutoffHz : Real = 10;

        action def filterNoise {
            in raw : RawSensorReading;
            return filteredCapacitance : CapacitanceValue;
        }

        action def amplifySignal {
            in filtered : CapacitanceValue;
            return amplified : CapacitanceValue;
        }

        action def compensateTemperature {
            in capacitance : CapacitanceValue;
            in temperature : TemperatureValue;
            return compensated : CapacitanceValue;
        }

        action def conditionSignal {
            in raw : RawSensorReading;
            return conditioned : ConditionedSignal;
        }

        action condition : conditionSignal;
    }

    part def DataProcessor {
        doc /* Converts conditioned capacitance into a moisture percentage using stored calibration; assesses quality */

        port conditionedIn : ConditionedIn;
        port processedOut : ProcessedOut;
        port calibration : CalibrationExchange;
        port powerIn : PowerInput;

        attribute currentCalibration : CalibrationParameters;
        attribute qualityThreshold : Real = 0.5;
        attribute lastMeasurement : ProcessedMeasurement;

        action def computeMoisture {
            in capacitance : CapacitanceValue;
            in dryRef : CapacitanceValue;
            in wetRef : CapacitanceValue;
            return moisture : MoistureValue;
        }

        action def assessQuality {
            in noiseFloor : Real;
            in moisture : MoistureValue;
            return quality : String;
        }

        action def processSignal {
            in signal : ConditionedSignal;
            in calibration : CalibrationParameters;
            return measurement : ProcessedMeasurement;
        }

        action process : processSignal;
    }

    part def CalibrationManager {
        doc /* Stores dry/wet calibration references, validates retention, and orchestrates in-field recalibration */

        port calibration : CalibrationExchange;
        port rawIn : RawReadingIn;
        port powerIn : PowerInput;

        attribute storedCalibration : CalibrationParameters;
        attribute retentionDurationDays : Integer = 30;
        attribute recalibrationInProgress : Boolean = false;
        attribute drySampleCount : Integer = 0;
        attribute wetSampleCount : Integer = 0;

        action def performRecalibration {
            in request : RecalibrationRequest;
            return params : CalibrationParameters;
        }

        action def verifyCalibrationValidity {
            return isValid : Boolean;
        }

        action def captureDryReference {
            in rawReadings : RawSensorReading [0..*];
            return dryRef : CapacitanceValue;
        }

        action def captureWetReference {
            in rawReadings : RawSensorReading [0..*];
            return wetRef : CapacitanceValue;
        }

        action def persistCalibration {
            in params : CalibrationParameters;
        }

        state def CalibrationState {
            state idle;
            state capturingDry;
            state capturingWet;
            state computing;
            state stored;
            transition idle -> capturingDry when startRecalibration;
            transition capturingDry -> capturingWet when dryCaptureComplete;
            transition capturingWet -> computing when wetCaptureComplete;
            transition computing -> stored when referencesComputed;
            transition stored -> idle when calibrationConfirmed;
        }

        state calibrationState : CalibrationState;
    }

    part def OutputInterface {
        doc /* Formats the processed measurement into a standard JSON payload and transmits it to the external monitoring system */

        port processedIn : ProcessedIn;
        port dataOut : DataOutput;
        port powerIn : PowerInput;

        attribute outputFormat : String = "JSON";
        attribute baudRate : Integer = 115200;
        attribute sequenceCounter : Integer = 0;

        action def formatAsJSON {
            in measurement : ProcessedMeasurement;
            return payload : String;
        }

        action def transmit {
            in message : OutputMessage;
        }

        action def publishMeasurement {
            in measurement : ProcessedMeasurement;
            out message : OutputMessage;
        }

        action publish : publishMeasurement;
    }

    // ====== TOP-LEVEL SYSTEM ASSEMBLY ======
    part def MoistureSensingSystem {
        doc /* Capacitive leaf moisture sensing unit for plant health monitoring in agriculture and environmental science */

        port externalOutput : DataOutput;
        port externalPower : PowerInput;
        port externalCalibration : CalibrationExchange;

        attribute minSupplyVoltage : VoltageValue = 3.3;
        attribute maxSupplyVoltage : VoltageValue = 5.0;
        attribute minOperatingTemp : TemperatureValue = -20;
        attribute maxOperatingTemp : TemperatureValue = 85;
        attribute maxResponseTime : TimeMs = 500;
        attribute accuracyMargin : MoistureValue = 2.0;
        attribute powerUpInitialized : Boolean = false;

        part leafSensor : LeafSensor;
        part signalConditioner : SignalConditioner;
        part dataProcessor : DataProcessor;
        part calibrationManager : CalibrationManager;
        part outputInterface : OutputInterface;

        // Power distribution from external supply to each module
        connect externalPower to leafSensor.powerIn;
        connect externalPower to signalConditioner.powerIn;
        connect externalPower to dataProcessor.powerIn;
        connect externalPower to calibrationManager.powerIn;
        connect externalPower to outputInterface.powerIn;

        // Primary measurement data flow
        connect leafSensor.rawOut to signalConditioner.rawIn;
        connect signalConditioner.conditionedOut to dataProcessor.conditionedIn;
        connect dataProcessor.processedOut to outputInterface.processedIn;
        connect outputInterface.dataOut to externalOutput;

        // Calibration management flows
        connect dataProcessor.calibration to calibrationManager.calibration;
        connect leafSensor.rawOut to calibrationManager.rawIn;
        connect externalCalibration to calibrationManager.calibration;

        // System-level operating state machine
        state def SystemStates {
            state initialization {
                entry {
                    // Power-up self-test; load stored calibration from CalibrationManager
                }
                exit {
                    // Confirm all subsystems report healthy and ready
                }
            }
            state ready {
                entry {
                    // Idle, awaiting measurement or recalibration request
                }
            }
            state activeMeasuring {
                entry {
                    // Trigger leafSensor sampling; begin conditioning/processing pipeline
                }
                do {
                    // Continuously produce and transmit moisture measurements
                }
                exit {
                    // Finalize the current measurement cycle
                }
            }
            state calibrationMode {
                entry {
                    // Begin recalibration sequence in CalibrationManager
                }
            }
            state error {
                entry {
                    // Log fault and emit fault notification via externalOutput
                }
            }

            transition initial -> initialization;
            transition initialization -> ready when initializationComplete;
            transition ready -> activeMeasuring when measurementRequested;
            transition activeMeasuring -> ready when measurementComplete;
            transition ready -> calibrationMode when recalibrationRequested;
            transition calibrationMode -> ready when calibrationComplete;
            transition ready -> error when faultDetected;
            transition activeMeasuring -> error when faultDetected;
            transition calibrationMode -> error when faultDetected;
            transition error -> initialization when faultCleared;
        }

        state systemState : SystemStates;
    }

    // ====== REQUIREMENTS ======

    requirement def MeasurementAccuracyRequirement {
        doc /* The system shall measure leaf moisture content with an accuracy within +/-2% */
        subject sensingUnit : MoistureSensingSystem;
        attribute accuracyMargin : MoistureValue = 2.0;
    }

    requirement def ResponseTimeRequirement {
        doc /* The system shall complete a single measurement cycle in under 500 ms */
        subject sensingUnit : MoistureSensingSystem;
        attribute maxResponseTime : TimeMs = 500;
    }

    requirement def OperatingTemperatureRangeRequirement {
        doc /* The system shall operate reliably across a temperature range of -20 degC to +85 degC */
        subject sensingUnit : MoistureSensingSystem;
        attribute minTemp : TemperatureValue = -20;
        attribute maxTemp : TemperatureValue = 85;
    }

    requirement def PowerSupplyRequirement {
        doc /* The system shall operate from a DC supply between 3.3 V and 5.0 V */
        subject sensingUnit : MoistureSensingSystem;
        attribute minVoltage : VoltageValue = 3.3;
        attribute maxVoltage : VoltageValue = 5.0;
    }

    requirement def CalibrationRetentionRequirement {
        doc /* The system shall retain calibration for at least 30 days and support in-field recalibration */
        subject sensingUnit : MoistureSensingSystem;
        attribute retentionDays : Integer = 30;
        attribute supportsFieldRecalibration : Boolean = true;
    }

    requirement def OutputFormatRequirement {
        doc /* The system shall emit measurements in a standard format (JSON) to an external monitoring system */
        subject sensingUnit : MoistureSensingSystem;
        attribute outputFormat : String = "JSON";
    }

    // ====== SATISFACTIONS ======
    satisfy accReq : MeasurementAccuracyRequirement by MoistureSensingSystem;
    satisfy rtReq : ResponseTimeRequirement by MoistureSensingSystem;
    satisfy tempReq : OperatingTemperatureRangeRequirement by MoistureSensingSystem;
    satisfy powerReq : PowerSupplyRequirement by MoistureSensingSystem;
    satisfy calReq : CalibrationRetentionRequirement by MoistureSensingSystem.calibrationManager;
    satisfy outReq : OutputFormatRequirement by MoistureSensingSystem.outputInterface;
}
