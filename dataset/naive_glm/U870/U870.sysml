package EnvironmentalSensingUnit {
    import ScalarValues::*;
    import ISQ::*;
    import Quantities::*;

    // ---- Value types with units ----
    value def TemperatureValue :> Real {
        unit :> Kelvin;
    }
    value def PressureValue :> Real {
        unit :> Pascal;
    }
    value def CalibrationFactor :> Real;
    value def QualityScore :> Real;
    value def Timestamp :> Integer;

    // ---- Item definitions ----
    item def RawSensorData {
        attribute sensorId : String;
        attribute rawValue : Real;
        attribute timestamp : Timestamp;
    }

    item def ProcessedMeasurement {
        attribute sensorId : String;
        attribute value : Real;
        attribute unit : String;
        attribute timestamp : Timestamp;
        attribute quality : QualityScore;
    }

    item def LogEntry {
        attribute entryId : Integer;
        attribute measurement : ProcessedMeasurement;
    }

    item def SensorCommand {
        attribute commandType : String;
        attribute targetSensorId : String;
    }

    item def ErrorReport {
        attribute errorCode : Integer;
        attribute description : String;
        attribute timestamp : Timestamp;
    }

    // ---- Port definitions ----
    port def RawDataOut {
        out raw : RawSensorData;
    }

    port def RawDataIn {
        in raw : RawSensorData;
    }

    port def ProcessedDataOut {
        out measurement : ProcessedMeasurement;
    }

    port def ProcessedDataIn {
        in measurement : ProcessedMeasurement;
    }

    port def CommandPort {
        in command : SensorCommand;
    }

    port def ErrorPort {
        out error : ErrorReport;
    }

    // ---- Sensor abstraction ----
    part def Sensor {
        attribute sensorId : String;
        attribute calibrationFactor : CalibrationFactor;
        port rawOut : RawDataOut;
        port cmdIn : CommandPort;
        port errOut : ErrorPort;

        attribute operatingRangeMin : Real;
        attribute operatingRangeMax : Real;

        action def takeMeasurement :> Action {
            in physicalPhenomenon : Real;
            out raw : RawSensorData;
        }

        state def SensorBehavior {
            entry; then Idle;
            state Idle;
            transition Idle -> Measuring
                when cmdIn.command.commandType == "measure";
            state Measuring {
                // capture raw reading
            }
            transition Measuring -> Idle
                when rawOut.raw.transmit();
            transition Measuring -> Error
                when rawOut.raw.rawValue < operatingRangeMin
                    or rawOut.raw.rawValue > operatingRangeMax;
            state Error {
                entry { send errOut.error; }
            }
            transition Error -> Idle
                when cmdIn.command.commandType == "reset";
        }
    }

    // ---- Temperature sensor ----
    part def TemperatureSensor :> Sensor {
        attribute operatingRangeMin = 223.15; // Kelvin
        attribute operatingRangeMax = 373.15; // Kelvin
        attribute calibrationFactor = 1.02;
    }

    // ---- Pressure sensor ----
    part def PressureSensor :> Sensor {
        attribute operatingRangeMin = 50000.0; // Pascals
        attribute operatingRangeMax = 150000.0; // Pascals
        attribute calibrationFactor = 0.98;
    }

    // ---- Signal processor ----
    part def SignalProcessor {
        port rawIn : RawDataIn;
        port procOut : ProcessedDataOut;
        port errOut : ErrorPort;

        attribute filterWindow : Integer = 5;

        action def filterRaw :> Action {
            in raw : RawSensorData;
            in calibration : CalibrationFactor;
            out processed : ProcessedMeasurement;
        }

        action def computeQuality :> Action {
            in raw : RawSensorData;
            out quality : QualityScore;
        }

        state def ProcessorBehavior {
            entry; then Idle;
            state Idle;
            transition Idle -> Filtering
                when rawIn.raw.receive();
            state Filtering {
                do filterRaw;
            }
            transition Filtering -> Idle
                when procOut.measurement.transmit();
            transition Filtering -> Error
                when rawIn.raw.rawValue == 0;
            state Error {
                entry { send errOut.error; }
            }
        }
    }

    // ---- Data logger ----
    part def DataLogger {
        port procIn : ProcessedDataIn;
        port errOut : ErrorPort;

        attribute bufferCapacity : Integer = 1000;
        attribute buffer : LogEntry[0..*] := ();
        attribute nextEntryId : Integer = 0;

        action def storeEntry :> Action {
            in measurement : ProcessedMeasurement;
            out entry : LogEntry;
        }

        action def retrieveEntries :> Action {
            out entries : LogEntry[0..*];
        }

        state def LoggerBehavior {
            entry; then Idle;
            state Idle;
            transition Idle -> Logging
                when procIn.measurement.receive();
            state Logging {
                do storeEntry;
            }
            transition Logging -> Idle
                when buffer.size > 0;
            transition Logging -> Error
                when buffer.size >= bufferCapacity;
            state Error {
                entry { send errOut.error; }
            }
        }
    }

    // ---- Environmental sensing unit ----
    part def EnvironmentalSensingUnit {
        port cmdIn : CommandPort;
        port errOut : ErrorPort;

        part tempSensor : TemperatureSensor {
            attribute sensorId = "TEMP-001";
        }
        part pressureSensor : PressureSensor {
            attribute sensorId = "PRES-001";
        }
        part processor : SignalProcessor;
        part logger : DataLogger;

        connection rawTempToProcessor connect tempSensor.rawOut to processor.rawIn;
        connection rawPressureToProcessor connect pressureSensor.rawOut to processor.rawIn;
        connection processedToLogger connect processor.procOut to logger.procIn;

        connection tempCmd connect cmdIn.command to tempSensor.cmdIn.command
            when cmdIn.command.targetSensorId == "TEMP-001";
        connection pressureCmd connect cmdIn.command to pressureSensor.cmdIn.command
            when cmdIn.command.targetSensorId == "PRES-001";

        connection tempErr connect tempSensor.errOut.error to errOut.error;
        connection pressureErr connect pressureSensor.errOut.error to errOut.error;
        connection processorErr connect processor.errOut.error to errOut.error;
        connection loggerErr connect logger.errOut.error to errOut.error;

        state def UnitLifecycle {
            entry; then Idle;
            state Idle {
                entry { /* waiting for command */ }
            }
            transition Idle -> Measuring
                when cmdIn.command.commandType == "measure";
            state Measuring {
                // sensors capture physical phenomena
            }
            transition Measuring -> Processing
                when processor.rawIn.raw.receive();
            state Processing {
                // signal processor filters raw data
            }
            transition Processing -> Logging
                when logger.procIn.measurement.receive();
            state Logging {
                // data logger stores processed measurement
            }
            transition Logging -> Idle
                when logger.buffer.size > 0;
            transition Measuring -> Error
                when errOut.error.receive();
            transition Processing -> Error
                when errOut.error.receive();
            transition Logging -> Error
                when errOut.error.receive();
            state Error {
                entry { /* report fault */ }
            }
            transition Error -> Idle
                when cmdIn.command.commandType == "reset";
        }
    }

    // ---- Requirements ----
    requirement def MeasurementRequirement {
        subject sensingUnit : EnvironmentalSensingUnit;
        objective {
            doc "The sensing unit shall measure physical conditions using one or more sensors."
        }
    }

    requirement def ProcessingRequirement {
        subject processor : SignalProcessor;
        objective {
            doc "The signal processor shall filter raw sensor data to produce a processed measurement."
        }
    }

    requirement def LoggingRequirement {
        subject logger : DataLogger;
        objective {
            doc "The data logger shall store processed measurements in an internal buffer for later retrieval."
        }
    }

    requirement def LifecycleRequirement {
        subject unit : EnvironmentalSensingUnit;
        objective {
            doc "The unit shall operate through idle, measuring, processing, logging, and error states."
        }
    }

    requirement def CalibrationRequirement {
        subject sensor : Sensor;
        objective {
            doc "Each sensor shall apply a unique calibration factor to ensure measurement accuracy."
        }
    }

    requirement def DataPacketRequirement {
        subject measurement : ProcessedMeasurement;
        objective {
            doc "Processed measurements shall include numeric value, unit, timestamp, and quality score."
        }
    }

    requirement def ErrorHandlingRequirement {
        subject unit : EnvironmentalSensingUnit;
        objective {
            doc "The unit shall enter a dedicated error state upon faults during the measurement phase."
        }
    }

    satisfaction satisfyMeasurementRequirement : MeasurementRequirement {
        subject sensingUnit : EnvironmentalSensingUnit;
    }

    satisfaction satisfyProcessingRequirement : ProcessingRequirement {
        subject processor : SignalProcessor;
    }

    satisfaction satisfyLoggingRequirement : LoggingRequirement {
        subject logger : DataLogger;
    }

    satisfaction satisfyLifecycleRequirement : LifecycleRequirement {
        subject unit : EnvironmentalSensingUnit;
    }

    satisfaction satisfyCalibrationRequirement : CalibrationRequirement {
        subject sensor : Sensor;
    }

    satisfaction satisfyDataPacketRequirement : DataPacketRequirement {
        subject measurement : ProcessedMeasurement;
    }

    satisfaction satisfyErrorHandlingRequirement : ErrorHandlingRequirement {
        subject unit : EnvironmentalSensingUnit;
    }
}
