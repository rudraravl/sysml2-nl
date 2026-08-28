package FishCountingSystem {
    import ScalarValues::*;
    import SI::*;
    import Time::*;

    attribute def LengthCm :> Real {
        doc /* Length in centimeters. */
        unit cm;
    }
    attribute def CountValue :> Integer {
        unit fish;
    }
    attribute def RatePerMinute :> Real {
        unit "fish/min";
    }
    attribute def TemperatureC :> Real {
        unit "degC";
    }
    attribute def VoltageDC :> Real {
        unit V;
    }
    attribute def StorageGB :> Real {
        unit GB;
    }
    attribute def Confidence :> Real {
        unit "ratio";
    }

    enum def Direction {
        upstream;
        downstream;
        unknown;
    }

    item def RawDetectionSignal {
        attribute detectedSize : LengthCm;
        attribute signalStrength : Real;
        attribute duration : Duration;
        attribute timestamp : DateTime;
    }

    item def ValidatedFishEvent {
        attribute estimatedSize : LengthCm;
        attribute direction : Direction;
        attribute confidence : Confidence;
        attribute timestamp : DateTime;
    }

    item def CountRecord {
        attribute upstreamCount : CountValue;
        attribute downstreamCount : CountValue;
        attribute netCount : CountValue;
        attribute timestamp : DateTime;
    }

    item def DCPower {
        attribute voltage : VoltageDC;
        attribute current : Real;
    }

    port def RawSignalPort {
        out item : RawDetectionSignal;
    }
    port def FishEventPort {
        out item : ValidatedFishEvent;
    }
    port def CountRecordPort {
        out item : CountRecord;
    }
    port def DisplayPort {
        out item : CountRecord;
    }
    port def LogPort {
        out item : CountRecord;
    }
    port def DCPowerPort {
        in item : DCPower;
    }

    requirement def DetectsSmallFish {
        doc /* The optical sensor shall detect objects as small as 5 cm. */
        attribute minDetectableSize : LengthCm = 5.0;
        subject sensor : OpticalSensor;
        require sensor.minDetectableSize <= minDetectableSize;
    }

    requirement def DeterminesDirection {
        doc /* The sensor shall determine direction of travel. */
        subject sensor : OpticalSensor;
        require sensor.directionCapability == true;
    }

    requirement def FiltersNonFish {
        doc /* The signal processor shall distinguish fish from debris and turbulence. */
        subject processor : SignalProcessor;
        require processor.filteringEnabled == true;
    }

    requirement def SupportsHighThroughput {
        doc /* The counting module shall process up to 300 fish per minute. */
        attribute maxThroughput : RatePerMinute = 300.0;
        subject counter : CountingModule;
        require counter.maxThroughput >= maxThroughput;
    }

    requirement def MaintainsSeparateCounts {
        doc /* The counting module shall maintain upstream, downstream, and net counts. */
        subject counter : CountingModule;
        require counter.upstreamCountSupported == true and
                counter.downstreamCountSupported == true and
                counter.netCountSupported == true;
    }

    requirement def LogsOverOneYear {
        doc /* The data logger shall hold over one year of data. */
        attribute minCapacity : StorageGB = 32.0;
        subject logger : DataLogger;
        require logger.storageCapacity >= minCapacity;
    }

    requirement def OperatesOverWideTemperature {
        doc /* The system shall operate reliably across a wide outdoor temperature range. */
        attribute minTemp : TemperatureC = -20.0;
        attribute maxTemp : TemperatureC = 60.0;
        subject system : FishCountingSystem;
        require system.operatingTempMin <= minTemp and
                system.operatingTempMax >= maxTemp;
    }

    requirement def WaterproofSensor {
        doc /* The sensor components shall be waterproof. */
        subject sensor : OpticalSensor;
        require sensor.ingressProtection == "IP68";
    }

    requirement def ConvertsToLowVoltageDC {
        doc /* The power supply shall convert standard input to low-voltage DC. */
        attribute outputVoltage : VoltageDC = 12.0;
        subject supply : PowerSupply;
        require supply.outputVoltage == outputVoltage;
    }

    part def OpticalSensor {
        attribute minDetectableSize : LengthCm = 5.0;
        attribute directionCapability : Boolean = true;
        attribute ingressProtection : String = "IP68";
        attribute operatingTempMin : TemperatureC = -20.0;
        attribute operatingTempMax : TemperatureC = 60.0;

        port rawOut : RawSignalPort;
        port powerIn : DCPowerPort;

        attribute detectionActive : Boolean = false;

        state def OpticalSensorBehavior {
            entry action { detectionActive := true; }
            exit action { detectionActive := false; }
            state Idle {
                transition to Detecting
                    when detectionActive
                    accept item trigger : Real;
            }
            state Detecting {
                entry action {
                    send RawDetectionSignal {
                        detectedSize := 5.0,
                        signalStrength := 0.8,
                        duration := 0.2,
                        timestamp := now
                    } to rawOut;
                }
                transition to Idle
                    accept item standby : Boolean;
            }
        }
        behavior : OpticalSensorBehavior;
    }

    part def SignalProcessor {
        attribute filteringEnabled : Boolean = true;
        attribute confidenceThreshold : Confidence = 0.7;

        port rawIn : RawSignalPort;
        port eventOut : FishEventPort;
        port powerIn : DCPowerPort;

        state def ProcessorBehavior {
            state Listening {
                transition to Analyzing
                    accept item signal : RawDetectionSignal via rawIn;
            }
            state Analyzing {
                entry action {
                    if signal.signalStrength > 0.5 then {
                        send ValidatedFishEvent {
                            estimatedSize := signal.detectedSize,
                            direction := Direction::upstream,
                            confidence := 0.85,
                            timestamp := signal.timestamp
                        } to eventOut;
                    }
                }
                transition to Listening;
            }
        }
        behavior : ProcessorBehavior;
    }

    part def CountingModule {
        attribute maxThroughput : RatePerMinute = 300.0;
        attribute upstreamCountSupported : Boolean = true;
        attribute downstreamCountSupported : Boolean = true;
        attribute netCountSupported : Boolean = true;

        attribute upstreamTotal : CountValue = 0;
        attribute downstreamTotal : CountValue = 0;
        attribute netTotal : CountValue = 0;

        port eventIn : FishEventPort;
        port countOut : CountRecordPort;
        port powerIn : DCPowerPort;

        state def CountingBehavior {
            state Counting {
                transition to Counting
                    accept item event : ValidatedFishEvent via eventIn {
                        if event.direction == Direction::upstream then {
                            upstreamTotal := upstreamTotal + 1;
                        } else if event.direction == Direction::downstream then {
                            downstreamTotal := downstreamTotal + 1;
                        }
                        netTotal := upstreamTotal - downstreamTotal;
                        send CountRecord {
                            upstreamCount := upstreamTotal,
                            downstreamCount := downstreamTotal,
                            netCount := netTotal,
                            timestamp := event.timestamp
                        } to countOut;
                    }
            }
        }
        behavior : CountingBehavior;
    }

    part def DisplayController {
        attribute displayRefreshHz : Real = 2.0;

        port countIn : CountRecordPort;
        port displayOut : DisplayPort;
        port powerIn : DCPowerPort;

        state def DisplayBehavior {
            state Showing {
                transition to Showing
                    accept item record : CountRecord via countIn {
                        send record to displayOut;
                    }
            }
        }
        behavior : DisplayBehavior;
    }

    part def DataLogger {
        attribute storageCapacity : StorageGB = 64.0;
        attribute recordsStored : Integer = 0;

        port logIn : LogPort;
        port powerIn : DCPowerPort;

        state def LoggingBehavior {
            state Recording {
                transition to Recording
                    accept item record : CountRecord via logIn {
                        recordsStored := recordsStored + 1;
                    }
            }
        }
        behavior : LoggingBehavior;
    }

    part def PowerSupply {
        attribute inputVoltage : VoltageDC = 230.0;
        attribute outputVoltage : VoltageDC = 12.0;
        attribute outputCurrent : Real = 5.0;

        port dcOut : DCPowerPort;

        state def PowerBehavior {
            state On {
                entry action {
                    send DCPower {
                        voltage := outputVoltage,
                        current := outputCurrent
                    } to dcOut;
                }
            }
        }
        behavior : PowerBehavior;
    }

    part def FishCountingSystem {
        attribute operatingTempMin : TemperatureC = -20.0;
        attribute operatingTempMax : TemperatureC = 60.0;

        part opticalSensor : OpticalSensor;
        part signalProcessor : SignalProcessor;
        part countingModule : CountingModule;
        part displayController : DisplayController;
        part dataLogger : DataLogger;
        part powerSupply : PowerSupply;

        connection rawLink connect opticalSensor.rawOut to signalProcessor.rawIn;
        connection eventLink connect signalProcessor.eventOut to countingModule.eventIn;
        connection countLink connect countingModule.countOut to displayController.countIn;
        connection displayLink connect countingModule.countOut to displayController.displayOut;
        connection logLink connect countingModule.countOut to dataLogger.logIn;

        connection powerToSensor connect powerSupply.dcOut to opticalSensor.powerIn;
        connection powerToProcessor connect powerSupply.dcOut to signalProcessor.powerIn;
        connection powerToCounter connect powerSupply.dcOut to countingModule.powerIn;
        connection powerToDisplay connect powerSupply.dcOut to displayController.powerIn;
        connection powerToLogger connect powerSupply.dcOut to dataLogger.powerIn;

        satisfy DetectsSmallFish by opticalSensor;
        satisfy DeterminesDirection by opticalSensor;
        satisfy FiltersNonFish by signalProcessor;
        satisfy SupportsHighThroughput by countingModule;
        satisfy MaintainsSeparateCounts by countingModule;
        satisfy LogsOverOneYear by dataLogger;
        satisfy OperatesOverWideTemperature by FishCountingSystem;
        satisfy WaterproofSensor by opticalSensor;
        satisfy ConvertsToLowVoltageDC by powerSupply;
    }
}
