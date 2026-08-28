package HookGaugeEvaporimeter {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceVolume::*;
    import ISQTime::*;
    import ISQThermodynamics::*;

    // ---- Value Types with Units ----
    value type Length :> Real {
        unit millimetre :> ISQ::millimetre;
        unit metre :> ISQ::metre;
    }
    value type Duration :> Real {
        unit hour :> ISQ::hour;
        unit second :> ISQ::second;
    }
    value type EvaporationRate :> Real {
        unit mmPerDay = millimetre / (hour * 24);
    }
    value type Temperature :> Real {
        unit degC :> ISQ::degreeCelsius;
    }
    value type RelativeHumidity :> Real {
        unit percent;
    }
    value type WindSpeed :> Real {
        unit metrePerSecond = metre / second;
    }
    value type Area :> Real {
        unit squareMetre = metre * metre;
    }
    value type Volume :> Real {
        unit litre = (millimetre * metre * metre) / 1000;
    }

    // ---- Item Definitions ----
    item def Water;

    item def DepthReading {
        attribute depth : Length;
        attribute timestamp : String;
        attribute sequenceId : Integer;
    }

    item def WeatherSample {
        attribute airTemperature : Temperature;
        attribute relativeHumidity : RelativeHumidity;
        attribute windSpeed : WindSpeed;
        attribute timestamp : String;
    }

    item def EvaporationReport {
        attribute initialDepth : Length;
        attribute finalDepth : Length;
        attribute interval : Duration;
        attribute evaporationRate : EvaporationRate;
        attribute meanTemperature : Temperature;
        attribute meanHumidity : RelativeHumidity;
        attribute meanWindSpeed : WindSpeed;
        attribute timestamp : String;
    }

    // ---- Port Definitions ----
    port def HydraulicConnection {
        out item water : Water;
    }

    port def DepthReadingOut {
        out item reading : DepthReading;
    }

    port def WeatherSampleOut {
        out item sample : WeatherSample;
    }

    port def LoggerDataIn {
        in item depthReading : DepthReading;
        in item weatherSample : WeatherSample;
    }

    port def ReportOut {
        out item report : EvaporationReport;
    }

    // ---- Part Definitions ----
    part def EvaporationPan {
        attribute panDiameter : Length = 1219 [millimetre];
        attribute panDepth : Length :> 254 [millimetre];
        attribute surfaceArea : Area = 1.154 [squareMetre];
        attribute material : String = "stainless steel";
        port waterSurfacePort : HydraulicConnection;
    }

    part def StillingWell {
        attribute wellDiameter : Length = 100 [millimetre];
        attribute wellHeight : Length = 300 [millimetre];
        attribute dampingRatio : Real = 0.85;
        port wellWaterPort : HydraulicConnection;
    }

    part def HookGauge {
        attribute resolution : Length = 0.1 [millimetre];
        attribute maxTravel : Length = 100 [millimetre];
        attribute hookType : String = "pointed";
        port depthOut : DepthReadingOut;

        action def TakeDepthMeasurement {
            in targetWell : StillingWell;
            out reading : DepthReading;
        }

        perform action takeMeasurement : TakeDepthMeasurement;
    }

    part def WeatherStation {
        attribute tempRangeMin : Temperature = -40 [degC];
        attribute tempRangeMax : Temperature = 60 [degC];
        attribute humidityRangeMin : RelativeHumidity = 0 [percent];
        attribute humidityRangeMax : RelativeHumidity = 100 [percent];
        attribute windRangeMin : WindSpeed = 0 [metrePerSecond];
        attribute windRangeMax : WindSpeed = 60 [metrePerSecond];
        port weatherOut : WeatherSampleOut;

        action def SampleEnvironment {
            out sample : WeatherSample;
        }

        perform action sampleEnvironment : SampleEnvironment;
    }

    part def DataLogger {
        attribute storageCapacity : Integer = 10000;
        attribute recordedDepths : DepthReading[0..*];
        attribute recordedWeather : WeatherSample[0..*];
        attribute computedReports : EvaporationReport[0..*];
        port dataIn : LoggerDataIn;
        port reportOut : ReportOut;

        action def RecordDepth {
            in reading : DepthReading;
        }

        action def RecordWeather {
            in sample : WeatherSample;
        }

        action def ComputeRate {
            in initialReading : DepthReading;
            in finalReading : DepthReading;
            in interval : Duration;
            in weatherSamples : WeatherSample[0..*];
            out report : EvaporationReport;
        }

        perform action recordDepth : RecordDepth;
        perform action recordWeather : RecordWeather;
        perform action computeRate : ComputeRate;
    }

    // ---- System ----
    part def HookGaugeEvaporimeterSystem {
        attribute systemName : String = "Hook Gauge Evaporimeter";
        attribute measurementInterval : Duration = 24 [hour];
        attribute stabilizationTime : Duration = 1 [hour];

        part pan : EvaporationPan;
        part stillingWell : StillingWell;
        part hookGauge : HookGauge;
        part weatherStation : WeatherStation;
        part dataLogger : DataLogger;

        connection panToWell connect pan.waterSurfacePort to stillingWell.wellWaterPort;
        connection gaugeToLogger connect hookGauge.depthOut to dataLogger.dataIn;
        connection weatherToLogger connect weatherStation.weatherOut to dataLogger.dataIn;

        // ---- State Machine ----
        state def MeasurementLifecycle {
            entry action initializeSystem {
                // Reset readings and verify pan water level
            }

            state idle {
                entry action awaitStart {
                    // System ready, waiting for measurement cycle trigger
                }
            }

            state measuring {
                entry action takeInitialReading {
                    // Lower hook until point just touches water surface
                    // Record initial depth and timestamp
                }
                do action monitorInitialContact;
                exit action storeInitialReading;
            }

            state stabilizing {
                entry action beginStabilization {
                    // Allow water surface to settle after measurement disturbance
                }
                do action waitForInterval {
                    // Wait measurementInterval (typically 24 h)
                }
                exit action takeFinalReading {
                    // Perform second hook gauge measurement
                }
            }

            state recording {
                entry action logDepthReadings {
                    // Send both depth readings to data logger
                }
                do action logWeatherData {
                    // Record environmental samples
                }
                exit action confirmStorage;
            }

            state computing {
                entry action calculateEvaporation {
                    // Compute rate = (initialDepth - finalDepth) / interval
                }
                do action generateReport;
                exit action archiveReport;
            }

            transition idle -> measuring
                when true;

            transition measuring -> stabilizing
                when hookGauge.takeMeasurement.done;

            transition stabilizing -> recording
                when stabilizationTime.elapsed;

            transition recording -> computing
                when dataLogger.recordDepth.done and dataLogger.recordWeather.done;

            transition computing -> idle
                when dataLogger.computeRate.done;
        }

        exhibit state measurementLifecycle : MeasurementLifecycle;
    }

    // ---- Requirements ----
    requirement def EvaporationAccuracyRequirement {
        subject evaporimeter : HookGaugeEvaporimeterSystem;
        requirement {
            attribute depthResolution : Length = 0.1 [millimetre];
            attribute maxMeasurementError : Length = 0.2 [millimetre];
        }
    }

    requirement def PanSpecificationRequirement {
        subject pan : EvaporationPan;
        requirement {
            attribute requiredDiameter : Length = 1219 [millimetre];
            attribute requiredDepth : Length = 254 [millimetre];
            attribute materialSpec : String = "corrosion-resistant stainless steel";
        }
    }

    requirement def StillingWellDampingRequirement {
        subject well : StillingWell;
        requirement {
            attribute minDampingRatio : Real = 0.80;
            attribute maxWellDiameter : Length = 120 [millimetre];
        }
    }

    requirement def WeatherMonitoringRequirement {
        subject station : WeatherStation;
        requirement {
            attribute tempAccuracy : Temperature = 0.5 [degC];
            attribute humidityAccuracy : RelativeHumidity = 2 [percent];
            attribute windSpeedAccuracy : WindSpeed = 0.5 [metrePerSecond];
        }
    }

    requirement def DataLoggingRequirement {
        subject logger : DataLogger;
        requirement {
            attribute minStorageRecords : Integer = 10000;
            attribute timestampResolution : Duration = 1 [second];
            attribute dataRetentionDays : Integer = 365;
        }
    }

    requirement def MeasurementCycleRequirement {
        subject system : HookGaugeEvaporimeterSystem;
        requirement {
            attribute standardInterval : Duration = 24 [hour];
            attribute stabilizationPeriod : Duration = 1 [hour];
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction satisfy EvaporationAccuracyRequirement by hookGauge;
    satisfaction satisfy PanSpecificationRequirement by pan;
    satisfaction satisfy StillingWellDampingRequirement by stillingWell;
    satisfaction satisfy WeatherMonitoringRequirement by weatherStation;
    satisfaction satisfy DataLoggingRequirement by dataLogger;
    satisfaction satisfy MeasurementCycleRequirement by HookGaugeEvaporimeterSystem;
}
