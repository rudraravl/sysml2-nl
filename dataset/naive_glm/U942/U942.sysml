package DigitalWaterMeterSystem {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Value types with units ----
    value def Volume :> Real { unit 'L'; }
    value def FlowRate :> Real { unit 'L/min'; }
    value def Pressure :> Real { unit 'bar'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Duration :> Real { unit 's'; }
    value def TimeInstant :> Real { unit 's'; }
    value def Percent :> Real { unit '%'; }

    // ---- Item definitions ----
    item def Water;

    item def FlowRateReading {
        attribute value : FlowRate;
        attribute timestamp : TimeInstant;
        attribute valid : Boolean;
    }

    item def VolumeReading {
        attribute value : Volume;
        attribute timestamp : TimeInstant;
    }

    item def MeasurementRecord {
        attribute totalVolume : Volume;
        attribute flowRate : FlowRate;
        attribute timestamp : TimeInstant;
        attribute status : String;
    }

    item def FaultSignal {
        attribute code : String;
        attribute description : String;
        attribute timestamp : TimeInstant;
    }

    item def DisplayUpdate {
        attribute volume : Volume;
        attribute flowRate : FlowRate;
    }

    // ---- Port definitions ----
    port def WaterPort {
        in item water : Water;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    port def FlowRatePort {
        out reading : FlowRateReading;
    }

    port def VolumePort {
        out reading : VolumeReading;
    }

    port def RecordPort {
        out record : MeasurementRecord;
    }

    port def DisplayPort {
        in update : DisplayUpdate;
    }

    port def FaultPort {
        out fault : FaultSignal;
    }

    // ---- Flow sensor ----
    part def FlowSensor {
        port waterIn : WaterPort;
        port waterOut : WaterPort;
        port flowOut : FlowRatePort;

        attribute minFlowRate : FlowRate = 0.5;
        attribute maxFlowRate : FlowRate = 50.0;
        attribute accuracyTolerance : Percent = 2.0;
        attribute samplingPeriod : Duration = 0.1;

        attribute lastReading : FlowRateReading;

        action measureFlow {
            in waterFlow : Water;
            out reading : FlowRateReading;
        }

        action detectFault {
            out fault : Boolean;
        }
    }

    // ---- Volume integrator ----
    part def VolumeIntegrator {
        port flowIn : ~FlowRatePort;
        port volumeOut : VolumePort;

        attribute accumulatedVolume : Volume = 0.0;
        attribute lastTimestamp : TimeInstant = 0.0;

        action integrate {
            in currentReading : FlowRateReading;
            out totalVolume : VolumeReading;

            perform {
                if currentReading.valid {
                    attribute deltaT : Duration = currentReading.timestamp - lastTimestamp;
                    attribute deltaV : Volume = currentReading.value * deltaT / 60.0;
                    accumulatedVolume := accumulatedVolume + deltaV;
                    lastTimestamp := currentReading.timestamp;
                }
                totalVolume := VolumeReading { value = accumulatedVolume; timestamp = currentReading.timestamp; };
            }
        }
    }

    // ---- Display module ----
    part def DisplayModule {
        port displayIn : DisplayPort;

        attribute displayedVolume : Volume = 0.0;
        attribute displayedFlowRate : FlowRate = 0.0;
        attribute backlightEnabled : Boolean = false;

        action updateDisplay {
            in update : DisplayUpdate;

            perform {
                displayedVolume := update.volume;
                displayedFlowRate := update.flowRate;
                backlightEnabled := (update.flowRate > 0.0);
            }
        }

        action renderScreen {
            in volume : Volume;
            in flowRate : FlowRate;
        }
    }

    // ---- Data logger ----
    part def DataLogger {
        port recordIn : ~RecordPort;

        attribute logInterval : Duration = 60.0;
        attribute storageCapacity : Integer = 525600;
        attribute storedRecords : MeasurementRecord[0..*] := {};
        attribute lastLogTime : TimeInstant = 0.0;

        action logRecord {
            in record : MeasurementRecord;

            perform {
                storedRecords := storedRecords.append(record);
                lastLogTime := record.timestamp;
            }
        }

        action retrieveHistory {
            out records : MeasurementRecord[0..*];
        }
    }

    // ---- Real-time clock ----
    part def RealTimeClock {
        port timeOut : out TimeInstant;
        attribute currentTime : TimeInstant = 0.0;

        action tick {
            out t : TimeInstant;
        }
    }

    // ---- Meter controller ----
    part def MeterController {
        port flowIn : ~FlowRatePort;
        port volumeIn : ~VolumePort;
        port displayOut : ~DisplayPort;
        port recordOut : RecordPort;
        port faultOut : FaultPort;
        port timeIn : in TimeInstant;

        attribute faultDetected : Boolean = false;
        attribute faultResolved : Boolean = false;
        attribute lastRecordTime : TimeInstant = 0.0;
        attribute recordInterval : Duration = 60.0;

        state machine OperationalStates {
            state idle {
                entry action {
                    displayOut.update := DisplayUpdate { volume = volumeIn.reading.value; flowRate = 0.0; };
                }
            }

            state active {
                entry action {
                    displayOut.update := DisplayUpdate { volume = volumeIn.reading.value; flowRate = flowIn.reading.value; };
                }

                do action continuously {
                    if (timeIn - lastRecordTime) >= recordInterval {
                        recordOut.record := MeasurementRecord {
                            totalVolume = volumeIn.reading.value;
                            flowRate = flowIn.reading.value;
                            timestamp = timeIn;
                            status = "active";
                        };
                        lastRecordTime := timeIn;
                    }
                }
            }

            state error {
                entry action {
                    faultOut.fault := FaultSignal {
                        code = "E001";
                        description = "Flow sensor malfunction detected";
                        timestamp = timeIn;
                    };
                }
            }

            transition idle_to_active
                first idle
                when flowIn.reading.value > 0.0 and flowIn.reading.valid
                then active;

            transition active_to_idle
                first active
                when flowIn.reading.value == 0.0 and flowIn.reading.valid
                then idle;

            transition active_to_error
                first active
                when not flowIn.reading.valid
                then error;

            transition idle_to_error
                first idle
                when not flowIn.reading.valid
                then error;

            transition error_to_idle
                first error
                when faultResolved and flowIn.reading.valid and flowIn.reading.value == 0.0
                then idle;

            transition error_to_active
                first error
                when faultResolved and flowIn.reading.valid and flowIn.reading.value > 0.0
                then active;
        }
    }

    // ---- System ----
    part def DigitalWaterMeter {
        port waterInlet : WaterPort;
        port waterOutlet : WaterPort;

        attribute operatingPressure : Pressure;
        attribute operatingFlowRate : FlowRate;
        attribute operatingTemperature : Temperature;
        attribute measuredVolume : Volume;
        attribute actualVolume : Volume;

        part flowSensor : FlowSensor {
            port waterIn : WaterPort;
            port waterOut : WaterPort;
            port flowOut : FlowRatePort;
        }

        part integrator : VolumeIntegrator {
            port flowIn : ~FlowRatePort;
            port volumeOut : VolumePort;
        }

        part display : DisplayModule {
            port displayIn : DisplayPort;
        }

        part logger : DataLogger {
            port recordIn : ~RecordPort;
        }

        part clock : RealTimeClock {
            port timeOut : out TimeInstant;
        }

        part controller : MeterController {
            port flowIn : ~FlowRatePort;
            port volumeIn : ~VolumePort;
            port displayOut : ~DisplayPort;
            port recordOut : RecordPort;
            port faultOut : FaultPort;
            port timeIn : in TimeInstant;
        }

        connection waterThroughSensor connect waterInlet to flowSensor.waterIn;
        connection waterOutOfSensor connect flowSensor.waterOut to waterOutlet;
        connection flowToIntegrator connect flowSensor.flowOut to integrator.flowIn;
        connection flowToController connect flowSensor.flowOut to controller.flowIn;
        connection volumeToController connect integrator.volumeOut to controller.volumeIn;
        connection displayToModule connect controller.displayOut to display.displayIn;
        connection recordToLogger connect controller.recordOut to logger.recordIn;
        connection clockToController connect clock.timeOut to controller.timeIn;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracyRequirement {
        attribute accuracyTolerance : Percent = 2.0;
        subject meter : DigitalWaterMeter;
        require {
            |meter.measuredVolume - meter.actualVolume| / meter.actualVolume * 100.0 <= accuracyTolerance
        }
    }

    requirement def OperatingPressureRangeRequirement {
        attribute minPressure : Pressure = 0.5;
        attribute maxPressure : Pressure = 8.0;
        subject meter : DigitalWaterMeter;
        require {
            meter.operatingPressure >= minPressure and meter.operatingPressure <= maxPressure
        }
    }

    requirement def OperatingFlowRangeRequirement {
        attribute minFlow : FlowRate = 0.5;
        attribute maxFlow : FlowRate = 50.0;
        subject meter : DigitalWaterMeter;
        require {
            meter.operatingFlowRate >= minFlow and meter.operatingFlowRate <= maxFlow
        }
    }

    requirement def OperatingTemperatureRequirement {
        attribute minTemp : Temperature = 4.0;
        attribute maxTemp : Temperature = 40.0;
        subject meter : DigitalWaterMeter;
        require {
            meter.operatingTemperature >= minTemp and meter.operatingTemperature <= maxTemp
        }
    }

    requirement def DataLoggingRequirement {
        attribute maxLogInterval : Duration = 60.0;
        subject logger : DataLogger;
        require {
            logger.logInterval <= maxLogInterval
        }
    }

    requirement def StateBehaviorRequirement {
        subject meter : DigitalWaterMeter;
        require {
            meter.controller.OperationalStates.idle.occupied when meter.operatingFlowRate == 0.0
        }
        require {
            meter.controller.OperationalStates.active.occupied when meter.operatingFlowRate > 0.0
        }
        require {
            meter.controller.OperationalStates.error.occupied when meter.controller.faultDetected
        }
    }

    requirement def DisplayReadabilityRequirement {
        subject display : DisplayModule;
        require {
            display.displayedVolume >= 0.0
        }
        require {
            display.backlightEnabled when display.displayedFlowRate > 0.0
        }
    }

    // ---- Requirement satisfaction ----
    satisfaction satisfy MeasurementAccuracyRequirement by DigitalWaterMeter;
    satisfaction satisfy OperatingPressureRangeRequirement by DigitalWaterMeter;
    satisfaction satisfy OperatingFlowRangeRequirement by DigitalWaterMeter;
    satisfaction satisfy OperatingTemperatureRequirement by DigitalWaterMeter;
    satisfaction satisfy DataLoggingRequirement by DigitalWaterMeter.logger;
    satisfaction satisfy StateBehaviorRequirement by DigitalWaterMeter.controller;
    satisfaction satisfy DisplayReadabilityRequirement by DigitalWaterMeter.display;
}
