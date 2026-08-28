package AtmosphericPressureMonitoringSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import Time::*;

    // ---------- Value Types with Units ----------
    public value type PressureValue :> Real {
        unit 'Pa';
    }
    public value type TemperatureValue :> Real {
        unit 'K';
    }
    public value type HumidityValue :> Real {
        unit '%';
    }
    public value type AltitudeValue :> Real {
        unit 'm';
    }
    public value type PressureRateValue :> Real {
        unit 'Pa/h';
    }
    public value type TimeIntervalValue :> Real {
        unit 'h';
    }
    public value type FrequencyValue :> Real {
        unit 'Hz';
    }

    // ---------- Enumerations ----------
    enum def PressureTrend {
        stable;
        rising;
        falling;
        rapidlyRising;
        rapidlyFalling;
    }

    enum def WeatherCondition {
        stableWeather;
        improvingWeather;
        deterioratingWeather;
        stormApproaching;
    }

    enum def SystemMode {
        off;
        initializing;
        monitoring;
        fault;
    }

    // ---------- Item Definitions ----------
    item def RawSensorData {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute timestamp : DateTime;
    }

    item def CorrectedPressureReading {
        attribute seaLevelPressure : PressureValue;
        attribute timestamp : DateTime;
    }

    item def PressureHistory {
        attribute readings : CorrectedPressureReading[0..*] ordered;
        attribute windowDuration : TimeIntervalValue = 24.0;
    }

    item def ForecastResult {
        attribute trend : PressureTrend;
        attribute rateOfChange : PressureRateValue;
        attribute forecast : WeatherCondition;
        attribute timestamp : DateTime;
    }

    item def DisplayContent {
        attribute currentPressure : PressureValue;
        attribute currentTemperature : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute forecast : WeatherCondition;
        attribute trend : PressureTrend;
        attribute rateOfChange : PressureRateValue;
        attribute timestamp : DateTime;
    }

    // ---------- Part Definitions ----------
    part def BarometricSensor {
        attribute samplingInterval : TimeIntervalValue = 0.0167;
        attribute operatingRangeMin : PressureValue = 30000.0;
        attribute operatingRangeMax : PressureValue = 110000.0;
        out port sensorDataOut : RawSensorData;
        in port powerIn : Boolean;

        action def takeMeasurement {
            in sensorEnabled : Boolean;
            out measurement : RawSensorData;
        }

        perform takeMeasurement every samplingInterval;
    }

    part def DataProcessor {
        attribute configuredAltitude : AltitudeValue = 250.0;
        attribute historyWindow : TimeIntervalValue = 24.0;
        attribute maxLogSize : Integer = 1440;
        attribute historyLog : CorrectedPressureReading[0..*] ordered;

        in port sensorDataIn : RawSensorData;
        in port altitudeConfigIn : AltitudeValue;
        out port correctedPressureOut : CorrectedPressureReading;
        out port historyOut : PressureHistory;

        action def correctForAltitude {
            in raw : RawSensorData;
            in altitude : AltitudeValue;
            out corrected : CorrectedPressureReading;

            // Sea-level pressure correction using barometric formula
            // P_sea = P_station * (1 - (L*h)/T) ^ (-g*M/(R*L))
            // Simplified: corrected.seaLevelPressure = raw.pressure * correctionFactor(altitude, temperature)
        }

        action def maintainHistory {
            in reading : CorrectedPressureReading;
            inout log : CorrectedPressureReading[0..*];

            // Append reading and prune entries older than 24 hours
        }

        action def publishHistory {
            in log : CorrectedPressureReading[0..*];
            out history : PressureHistory;
        }

        perform {
            accept sensorDataIn via sensorDataIn;
            then correctForAltitude;
            then maintainHistory;
            then publishHistory;
        }
    }

    part def ForecastEngine {
        attribute rapidChangeThreshold : PressureRateValue = 100.0;
        attribute moderateChangeThreshold : PressureRateValue = 30.0;
        attribute analysisWindow : TimeIntervalValue = 3.0;

        in port historyIn : PressureHistory;
        out port forecastOut : ForecastResult;

        action def analyzeTrend {
            in history : PressureHistory;
            out trend : PressureTrend;
            out rate : PressureRateValue;
        }

        action def generateForecast {
            in trend : PressureTrend;
            in rate : PressureRateValue;
            out result : ForecastResult;
        }

        perform {
            accept historyIn via historyIn;
            then analyzeTrend;
            then generateForecast;
        }
    }

    part def DisplayUnit {
        attribute refreshInterval : TimeIntervalValue = 0.0833;
        attribute backlightEnabled : Boolean = true;

        in port pressureIn : CorrectedPressureReading;
        in port forecastIn : ForecastResult;
        in port sensorDataIn : RawSensorData;
        out port displayContentOut : DisplayContent;

        action def renderDisplay {
            in pressure : CorrectedPressureReading;
            in forecast : ForecastResult;
            in sensor : RawSensorData;
            out content : DisplayContent;
        }

        perform renderDisplay every refreshInterval;
    }

    // ---------- Top-Level System ----------
    part def WeatherStation {
        attribute stationAltitude : AltitudeValue = 250.0;
        attribute systemMode : SystemMode = off;

        part sensor : BarometricSensor {
            redefines configuredAltitude = stationAltitude;
        }
        part processor : DataProcessor {
            redefines configuredAltitude = stationAltitude;
        }
        part forecastEngine : ForecastEngine;
        part display : DisplayUnit;

        connection sensorToProcessor connect sensor.sensorDataOut to processor.sensorDataIn;
        connection altitudeConfig connect stationAltitude to processor.altitudeConfigIn;
        connection processorToForecast connect processor.historyOut to forecastEngine.historyIn;
        connection processorToDisplay connect processor.correctedPressureOut to display.pressureIn;
        connection sensorToDisplay connect sensor.sensorDataOut to display.sensorDataIn;
        connection forecastToDisplay connect forecastEngine.forecastOut to display.forecastIn;

        state def OperatingStateMachine {
            entry action { systemMode = initializing; }
            state Initializing {
                entry action { systemMode = initializing; }
                transition to Monitoring when (sensor.sensorDataOut->notEmpty());
            }
            state Monitoring {
                entry action { systemMode = monitoring; }
                do { sensor.takeMeasurement; }
                transition to Fault when (sensor.sensorDataOut->isEmpty() and systemMode == monitoring);
            }
            state Fault {
                entry action { systemMode = fault; }
                transition to Initializing when (sensor.sensorDataOut->notEmpty());
            }
            transition first Initial to Initializing;
            initial state Initial;
        }

        exhibit OperatingStateMachine;

        requirement def PressureCorrectionRequirement {
            subject processor;
            objective {
                doc "The processor shall correct the measured station pressure to sea-level equivalent pressure using the measured temperature and the configured altitude."
            }
            assume { processor.configuredAltitude >= 0.0 }
        }

        requirement def HistoryLoggingRequirement {
            subject processor;
            objective {
                doc "The processor shall maintain a rolling 24-hour log of corrected pressure readings with timestamps."
            }
        }

        requirement def TrendAnalysisRequirement {
            subject forecastEngine;
            objective {
                doc "The forecast engine shall determine the pressure trend (stable, rising, falling) and the rate of change from the 24-hour pressure history."
            }
        }

        requirement def ForecastGenerationRequirement {
            subject forecastEngine;
            objective {
                doc "The forecast engine shall generate a weather forecast based on the pressure trend and rate of change, identifying stable weather, improving weather, deteriorating weather, or an approaching storm."
            }
        }

        requirement def DisplayRefreshRequirement {
            subject display;
            objective {
                doc "The display unit shall refresh the presented pressure data and forecast at regular intervals not exceeding 5 minutes."
            }
        }

        requirement def ContinuousOperationRequirement {
            subject WeatherStation;
            objective {
                doc "The system shall operate in a continuous cycle, performing measurement, correction, logging, trend analysis, forecasting, and display without operator intervention."
            }
        }

        satisfy PressureCorrectionRequirement by processor.correctForAltitude;
        satisfy HistoryLoggingRequirement by processor.maintainHistory;
        satisfy TrendAnalysisRequirement by forecastEngine.analyzeTrend;
        satisfy ForecastGenerationRequirement by forecastEngine.generateForecast;
        satisfy DisplayRefreshRequirement by display.renderDisplay;
        satisfy ContinuousOperationRequirement by WeatherStation.OperatingStateMachine;
    }
}
