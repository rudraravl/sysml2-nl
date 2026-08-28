package HygrometerSystem {
    import ScalarValues::*;
    import SI::*;
    import Time::*;

    // ---- Value Types ----
    value def Humidity :> Real {
        unit 'percent' {
            dimension = 1;
        }
    }

    value def TemperatureValue :> Real {
        unit 'K';
    }

    value def Voltage :> Real {
        unit 'V';
    }

    value def Frequency :> Real {
        unit 'Hz';
    }

    value def Power :> Real {
        unit 'W';
    }

    value def TimeInterval :> Real {
        unit 's';
    }

    // ---- Enumerations ----
    enum def DisplayMode {
        HUMIDITY_ONLY;
        TEMPERATURE_ONLY;
        COMBINED;
        TREND_GRAPH;
    }

    enum def SensorStatus {
        NORMAL;
        DEGRADED;
        FAULT;
    }

    enum def SystemState {
        POWERED_OFF;
        INITIALIZING;
        READY;
        MEASURING;
        CALIBRATING;
        ERROR;
        SHUTTING_DOWN;
    }

    // ---- Item Definitions ----
    item def RawHumiditySignal {
        attribute voltage : Voltage;
        attribute timestamp : DateTime;
    }

    item def RawTemperatureSignal {
        attribute temperature : TemperatureValue;
        attribute timestamp : DateTime;
    }

    item def CalibrationData {
        attribute humidityOffset : Humidity;
        attribute humidityScaleFactor : Real;
        attribute temperatureOffset : TemperatureValue;
        attribute temperatureScaleFactor : Real;
        attribute lastCalibrationDate : DateTime;
    }

    item def ProcessedReading {
        attribute humidity : Humidity;
        attribute temperature : TemperatureValue;
        attribute timestamp : DateTime;
        attribute status : SensorStatus;
    }

    item def DisplayCommand {
        attribute mode : DisplayMode;
    }

    item def LogEntry {
        attribute reading : ProcessedReading;
        attribute sequenceNumber : Integer;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Real;
        attribute power : Power;
    }

    // ---- Port Definitions ----
    port def AnalogOutputPort {
        out item rawSignal : RawHumiditySignal;
    }

    port def DigitalTempPort {
        out item tempSignal : RawTemperatureSignal;
    }

    port def ProcessedReadingOutPort {
        out item reading : ProcessedReading;
    }

    port def ProcessedReadingInPort {
        in item reading : ProcessedReading;
    }

    port def DisplayCommandPort {
        in item command : DisplayCommand;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def AmbientExposurePort {
        attribute exposed : Boolean;
    }

    // ---- Actions ----
    action def ConvertAnalogToDigital {
        in item rawSignal : RawHumiditySignal;
        out item digitalValue : Real;
    }

    action def CompensateHumidity {
        in item digitalValue : Real;
        in item temperature : TemperatureValue;
        in item calibration : CalibrationData;
        out item compensatedHumidity : Humidity;
    }

    action def ApplyCalibration {
        in item rawHumidity : Humidity;
        in item rawTemperature : TemperatureValue;
        in item calibration : CalibrationData;
        out item calibratedHumidity : Humidity;
        out item calibratedTemperature : TemperatureValue;
    }

    action def AssembleReading {
        in item humidity : Humidity;
        in item temperature : TemperatureValue;
        in item timestamp : DateTime;
        in item status : SensorStatus;
        out item reading : ProcessedReading;
    }

    action def RenderDisplay {
        in item reading : ProcessedReading;
        in item mode : DisplayMode;
    }

    action def StoreLogEntry {
        in item reading : ProcessedReading;
        out item entry : LogEntry;
    }

    // ---- Parts ----
    part def HumiditySensor {
        port ambientPort : AmbientExposurePort;
        port analogOut : AnalogOutputPort;
        port powerIn : PowerInputPort;

        attribute nominalSensitivity : Real = 0.0315; // V per %RH
        attribute operatingRangeMin : Humidity = 0.0;
        attribute operatingRangeMax : Humidity = 100.0;

        action sense : ConvertAnalogToDigital {
            in item rawSignal : RawHumiditySignal;
            out item digitalValue : Real;
        }
    }

    part def TemperatureSensor {
        port ambientPort : AmbientExposurePort;
        port digitalOut : DigitalTempPort;
        port powerIn : PowerInputPort;

        attribute accuracy : TemperatureValue = 0.5;
        attribute operatingRangeMin : TemperatureValue = 273.15;
        attribute operatingRangeMax : TemperatureValue = 358.15;

        action readTemperature {
            out item tempSignal : RawTemperatureSignal;
        }
    }

    part def SignalProcessor {
        port humidityIn : AnalogOutputPort;
        port tempIn : DigitalTempPort;
        port readingOut : ProcessedReadingOutPort;
        port powerIn : PowerInputPort;

        attribute calibration : CalibrationData;
        attribute processingInterval : TimeInterval = 1.0;

        action processReading {
            in item rawHumidity : RawHumiditySignal;
            in item rawTemp : RawTemperatureSignal;
            out item reading : ProcessedReading;

            action convert : ConvertAnalogToDigital {
                in item rawSignal = rawHumidity;
                out item digitalValue;
            }

            action compensate : CompensateHumidity {
                in item digitalValue = convert.digitalValue;
                in item temperature = rawTemp.temperature;
                in item calibration = SignalProcessor::calibration;
                out item compensatedHumidity;
            }

            action calibrate : ApplyCalibration {
                in item rawHumidity = compensate.compensatedHumidity;
                in item rawTemperature = rawTemp.temperature;
                in item calibration = SignalProcessor::calibration;
                out item calibratedHumidity;
                out item calibratedTemperature;
            }

            action assemble : AssembleReading {
                in item humidity = calibrate.calibratedHumidity;
                in item temperature = calibrate.calibratedTemperature;
                in item timestamp = rawTemp.timestamp;
                in item status = SensorStatus::NORMAL;
                out item reading;
            }
        }
    }

    part def DisplayUnit {
        port readingIn : ProcessedReadingInPort;
        port commandIn : DisplayCommandPort;
        port powerIn : PowerInputPort;

        attribute currentMode : DisplayMode = DisplayMode::COMBINED;
        attribute trendBuffer : ProcessedReading[0..100];

        action render : RenderDisplay {
            in item reading : ProcessedReading;
            in item mode : DisplayMode;
        }

        action updateTrend {
            in item reading : ProcessedReading;
        }
    }

    part def DataLogger {
        port readingIn : ProcessedReadingInPort;
        port powerIn : PowerInputPort;

        attribute logInterval : TimeInterval = 60.0;
        attribute storageCapacity : Integer = 100000;
        attribute entryCount : Integer = 0;
        attribute logStorage : LogEntry[0..100000];

        action log : StoreLogEntry {
            in item reading : ProcessedReading;
            out item entry : LogEntry;
        }

        action flushStorage {
            attribute flushed : Boolean;
        }
    }

    part def PowerSupply {
        port powerOut : PowerOutputPort[5];

        attribute inputVoltage : Voltage = 12.0;
        attribute outputVoltage : Voltage = 3.3;
        attribute maxOutputPower : Power = 15.0;
        attribute efficiency : Real = 0.85;

        action regulate {
            in item inputPower : ElectricalPower;
            out item outputPower : ElectricalPower;
        }
    }

    // ---- System ----
    part def Hygrometer {
        port ambientHumidityPort : AmbientExposurePort;
        port ambientTemperaturePort : AmbientExposurePort;
        port displayCommandPort : DisplayCommandPort;
        port externalPowerPort : PowerInputPort;

        part humiditySensor : HumiditySensor {
            port ambientPort = ambientHumidityPort;
        }

        part temperatureSensor : TemperatureSensor {
            port ambientPort = ambientTemperaturePort;
        }

        part processor : SignalProcessor;

        part display : DisplayUnit;

        part logger : DataLogger;

        part powerSupply : PowerSupply {
            port powerOut[1] -> humiditySensor.powerIn;
            port powerOut[2] -> temperatureSensor.powerIn;
            port powerOut[3] -> processor.powerIn;
            port powerOut[4] -> display.powerIn;
            port powerOut[5] -> logger.powerIn;
        }

        // Connections
        connection humiditySignalFlow from humiditySensor.analogOut to processor.humidityIn;
        connection temperatureSignalFlow from temperatureSensor.digitalOut to processor.tempIn;
        connection readingToDisplay from processor.readingOut to display.readingIn;
        connection readingToLogger from processor.readingOut to logger.readingIn;
        connection externalPower from externalPowerPort to powerSupply.powerOut;

        // State Machine
        state machine HygrometerLifecycle {
            entry action { /* system startup */ }

            state POWERED_OFF {
                entry action { /* all components unpowered */ }
            }

            state INITIALIZING {
                entry action {
                    /* load calibration data */
                    /* self-test sensors */
                    /* initialize display */
                }
            }

            state READY {
                entry action { /* await user command */ }

                transition to MEASURING when /* user requests measurement */ true;
                transition to CALIBRATING when /* calibration requested */ true;
                transition to SHUTTING_DOWN when /* shutdown requested */ true;
            }

            state MEASURING {
                do action {
                    /* continuously process readings */
                    /* update display */
                    /* log data at intervals */
                }

                transition to READY when /* measurement stopped */ true;
                transition to ERROR when /* sensor fault detected */ true;
            }

            state CALIBRATING {
                entry action {
                    /* apply known reference */
                    /* update calibration data */
                }

                transition to READY when /* calibration complete */ true;
                transition to ERROR when /* calibration failed */ true;
            }

            state ERROR {
                entry action {
                    /* log error */
                    /* display error message */
                }

                transition to INITIALIZING when /* retry requested */ true;
                transition to SHUTTING_DOWN when /* shutdown requested */ true;
            }

            state SHUTTING_DOWN {
                entry action {
                    /* flush logger storage */
                    /* save calibration */
                    /* power down components */
                }

                transition to POWERED_OFF when /* shutdown complete */ true;
            }

            transition initial to POWERED_OFF;
            transition POWERED_OFF to INITIALIZING when /* power applied */ true;
            transition INITIALIZING to READY when /* initialization complete */ true;
            transition INITIALIZING to ERROR when /* initialization failed */ true;
        }

        attribute currentState : SystemState = SystemState::POWERED_OFF;
    }

    // ---- Requirements ----
    requirement def MeasurementRequirement {
        subject hygrometer : Hygrometer;
        objective {
            doc "The hygrometer shall continuously measure relative humidity and temperature."
        }
    }

    requirement HumidityAccuracyRequirement : MeasurementRequirement {
        subject hygrometer : Hygrometer;
        requirement {
            doc "The system shall measure relative humidity with an accuracy of ±2% RH after temperature compensation."
        }
    }

    requirement TemperatureAccuracyRequirement : MeasurementRequirement {
        subject hygrometer : Hygrometer;
        requirement {
            doc "The system shall measure temperature with an accuracy of ±0.5 K."
        }
    }

    requirement CompensationRequirement : MeasurementRequirement {
        subject hygrometer : Hygrometer;
        requirement {
            doc "The signal processor shall compensate humidity readings using the temperature sensor data and stored calibration factors."
        }
    }

    requirement DisplayRequirement {
        subject display : DisplayUnit;
        requirement {
            doc "The display shall support at least four modes: humidity only, temperature only, combined, and trend graph."
        }
    }

    requirement LoggingRequirement {
        subject logger : DataLogger;
        requirement {
            doc "The data logger shall store processed readings at regular configurable intervals with timestamp and sensor status."
        }
    }

    requirement PowerRequirement {
        subject power : PowerSupply;
        requirement {
            doc "The power supply shall provide regulated electrical power to all components including sensors, processor, display, and logger."
        }
    }

    requirement LifecycleRequirement {
        subject hygrometer : Hygrometer;
        requirement {
            doc "The system shall follow a defined lifecycle: powered-off, initializing, ready, measuring, calibrating, error, and shutting down."
        }
    }

    requirement ErrorHandlingRequirement {
        subject hygrometer : Hygrometer;
        requirement {
            doc "The system shall enter an error state upon detecting sensor or system malfunctions and allow recovery through re-initialization."
        }
    }

    // ---- Satisfaction ----
    satisfaction satisfyHumidityAccuracy by Hygrometer::processor.processReading.compensate satisfies HumidityAccuracyRequirement;
    satisfaction satisfyTemperatureAccuracy by Hygrometer::temperatureSensor satisfies TemperatureAccuracyRequirement;
    satisfaction satisfyCompensation by Hygrometer::processor.processReading.compensate satisfies CompensationRequirement;
    satisfaction satisfyDisplay by Hygrometer::display satisfies DisplayRequirement;
    satisfaction satisfyLogging by Hygrometer::logger satisfies LoggingRequirement;
    satisfaction satisfyPower by Hygrometer::powerSupply satisfies PowerRequirement;
    satisfaction satisfyLifecycle by Hygrometer::HygrometerLifecycle satisfies LifecycleRequirement;
    satisfaction satisfyErrorHandling by Hygrometer::HygrometerLifecycle.ERROR satisfies ErrorHandlingRequirement;
}
