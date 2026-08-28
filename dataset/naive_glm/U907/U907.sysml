package TemperatureGaugeSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQTemperature::*;
    import ISQDateTime::*;
    import ISQDuration::*;

    // ---------- Value Types ----------
    value def TemperatureValue :> Real {
        unit degC;
    }

    value def AccuracyValue :> Real {
        unit degC;
    }

    value def TimestampValue :> DateTime;
    
    value def IntervalValue :> Real {
        unit s;
    }

    value def ThresholdValue :> Real {
        unit degC;
    }

    // ---------- Enumerations ----------
    enum def QualityMetric {
        good;
        questionable;
        bad;
    }

    enum def AlertStatus {
        normal;
        warning;
        critical;
    }

    enum def GaugeMode {
        standby;
        active;
        calibration;
    }

    // ---------- Item Definitions ----------
    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : TimestampValue;
        attribute quality : QualityMetric;
    }

    item def ProcessedReading {
        attribute calibratedValue : TemperatureValue;
        attribute timestamp : TimestampValue;
        attribute alertStatus : AlertStatus;
    }

    item def DisplayMessage {
        attribute displayValue : TemperatureValue;
        attribute alertStatus : AlertStatus;
        attribute mode : GaugeMode;
    }

    // ---------- Port Definitions ----------
    port def SensorOutPort {
        out reading : TemperatureReading;
    }

    port def ProcessorInPort {
        in reading : TemperatureReading;
    }

    port def ProcessorOutPort {
        out processed : ProcessedReading;
    }

    port def DisplayInPort {
        in message : ProcessedReading;
    }

    // ---------- Interfaces ----------
    interface def SensorToProcessorInterface {
        end supplier : SensorOutPort;
        end consumer : ProcessorInPort;
    }

    interface def ProcessorToDisplayInterface {
        end supplier : ProcessorOutPort;
        end consumer : DisplayInPort;
    }

    // ---------- Requirements ----------
    requirement def MeasurementRangeRequirement {
        doc /* The sensor shall measure temperature within -40°C to 150°C. */
        attribute minRange : TemperatureValue = -40 [degC];
        attribute maxRange : TemperatureValue = 150 [degC];
        subject sensor : TemperatureSensor;
        require constraint { sensor.measuredValue >= minRange and sensor.measuredValue <= maxRange }
    }

    requirement def AccuracyRequirement {
        doc /* The sensor shall be accurate to within 0.5°C. */
        attribute maxError : AccuracyValue = 0.5 [degC];
        subject sensor : TemperatureSensor;
        require constraint { sensor.accuracyError <= maxError }
    }

    requirement def SamplingIntervalRequirement {
        doc /* The processor shall receive data at a 1-second interval. */
        attribute interval : IntervalValue = 1 [s];
        subject processor : CentralProcessor;
        require constraint { processor.samplingInterval == interval }
    }

    requirement def ThresholdRequirement {
        doc /* The processor shall evaluate warning at 80°C and critical at 100°C. */
        attribute warningThreshold : ThresholdValue = 80 [degC];
        attribute criticalThreshold : ThresholdValue = 100 [degC];
        subject processor : CentralProcessor;
        require constraint { processor.warningLimit == warningThreshold and processor.criticalLimit == criticalThreshold }
    }

    requirement def DisplayRequirement {
        doc /* The display shall show numerical temperature and alert status. */
        subject display : DigitalDisplay;
        require constraint { display.showsTemperature == true and display.showsAlertStatus == true }
    }

    requirement def ModeRequirement {
        doc /* The gauge shall operate in standby, active, or calibration modes. */
        subject gauge : TemperatureGauge;
        require constraint { gauge.currentMode in GaugeMode::standby::active::calibration }
    }

    // ---------- Parts ----------
    part def TemperatureSensor {
        attribute minRange : TemperatureValue = -40 [degC];
        attribute maxRange : TemperatureValue = 150 [degC];
        attribute accuracyError : AccuracyValue = 0.5 [degC];
        attribute measuredValue : TemperatureValue;
        attribute lastTimestamp : TimestampValue;
        attribute lastQuality : QualityMetric = QualityMetric::good;

        port sensorOut : SensorOutPort;

        attribute samplingInterval : IntervalValue = 1 [s];

        state sensorStateMachine {
            entry; then measuring;

            state measuring {
                entry action {
                    measuredValue = readTemperature();
                    lastTimestamp = currentTime();
                    lastQuality = assessQuality();
                    sensorOut.reading = TemperatureReading {
                        value = measuredValue,
                        timestamp = lastTimestamp,
                        quality = lastQuality
                    };
                }
            }

            transition measuring -> measuring
                when samplingIntervalElapsed() {
                }
            }

        action def readTemperature :> Real {
            return measuredValue;
        }

        action def currentTime :> DateTime {
            return lastTimestamp;
        }

        action def assessQuality :> QualityMetric {
            return lastQuality;
        }

        action def samplingIntervalElapsed :> Boolean;

        satisfy MeasurementRangeRequirement by sensor;
        satisfy AccuracyRequirement by sensor;
    }

    part def CentralProcessor {
        attribute samplingInterval : IntervalValue = 1 [s];
        attribute warningLimit : ThresholdValue = 80 [degC];
        attribute criticalLimit : ThresholdValue = 100 [degC];
        attribute calibrationOffset : TemperatureValue = 0 [degC];

        attribute currentAlertStatus : AlertStatus = AlertStatus::normal;
        attribute currentMode : GaugeMode = GaugeMode::standby;

        port processorIn : ProcessorInPort;
        port processorOut : ProcessorOutPort;

        state processorStateMachine {
            entry; then standby;

            state standby {
                entry action {
                    currentMode = GaugeMode::standby;
                }
                transition standby -> active
                    when activateSignalReceived();
            }

            state active {
                entry action {
                    currentMode = GaugeMode::active;
                }

                state normalState {
                    entry action {
                        currentAlertStatus = AlertStatus::normal;
                    }
                    transition normalState -> warningState
                        when processorIn.reading.calibratedValue >= warningLimit;
                    transition normalState -> criticalState
                        when processorIn.reading.calibratedValue >= criticalLimit;
                }

                state warningState {
                    entry action {
                        currentAlertStatus = AlertStatus::warning;
                    }
                    transition warningState -> criticalState
                        when processorIn.reading.calibratedValue >= criticalLimit;
                    transition warningState -> normalState
                        when processorIn.reading.calibratedValue < warningLimit;
                }

                state criticalState {
                    entry action {
                        currentAlertStatus = AlertStatus::critical;
                    }
                    transition criticalState -> warningState
                        when processorIn.reading.calibratedValue < criticalLimit and processorIn.reading.calibratedValue >= warningLimit;
                    transition criticalState -> normalState
                        when processorIn.reading.calibratedValue < warningLimit;
                }

                transition active -> calibration
                    when calibrationSignalReceived();
                transition active -> standby
                    when deactivateSignalReceived();
            }

            state calibration {
                entry action {
                    currentMode = GaugeMode::calibration;
                }
                transition calibration -> active
                    when calibrationComplete();
            }
        }

        action def processReading(in rawReading : TemperatureReading) : ProcessedReading {
            calibratedValue : TemperatureValue = rawReading.value + calibrationOffset;
            alertStatus : AlertStatus = evaluateThresholds(calibratedValue);
            return ProcessedReading {
                calibratedValue = calibratedValue,
                timestamp = rawReading.timestamp,
                alertStatus = alertStatus
            };
        }

        action def evaluateThresholds(in value : TemperatureValue) : AlertStatus {
            if value >= criticalLimit then return AlertStatus::critical;
            else if value >= warningLimit then return AlertStatus::warning;
            else return AlertStatus::normal;
        }

        action def activateSignalReceived :> Boolean;
        action def deactivateSignalReceived :> Boolean;
        action def calibrationSignalReceived :> Boolean;
        action def calibrationComplete :> Boolean;

        satisfy SamplingIntervalRequirement by processor;
        satisfy ThresholdRequirement by processor;
    }

    part def DigitalDisplay {
        attribute showsTemperature : Boolean = true;
        attribute showsAlertStatus : Boolean = true;
        attribute displayedValue : TemperatureValue;
        attribute displayedAlert : AlertStatus = AlertStatus::normal;
        attribute displayedMode : GaugeMode = GaugeMode::standby;

        port displayIn : DisplayInPort;

        state displayStateMachine {
            entry; then idle;

            state idle {
                entry action {
                    showsTemperature = false;
                }
                transition idle -> displaying
                    when displayIn.message.received();
            }

            state displaying {
                entry action {
                    displayedValue = displayIn.message.calibratedValue;
                    displayedAlert = displayIn.message.alertStatus;
                    showsTemperature = true;
                    showsAlertStatus = true;
                }
                do action {
                    renderDisplay(displayedValue, displayedAlert);
                }
                transition displaying -> idle
                    when powerOffSignalReceived();
            }
        }

        action def renderDisplay(in value : TemperatureValue, in alert : AlertStatus) {
            displayedValue = value;
            displayedAlert = alert;
        }

        action def powerOffSignalReceived :> Boolean;

        satisfy DisplayRequirement by display;
    }

    // ---------- Top-level Gauge ----------
    part def TemperatureGauge {
        attribute currentMode : GaugeMode = GaugeMode::standby;

        part sensor : TemperatureSensor {
            redefines samplingInterval = 1 [s];
        }

        part processor : CentralProcessor {
            redefines samplingInterval = 1 [s];
            redefines warningLimit = 80 [degC];
            redefines criticalLimit = 100 [degC];
        }

        part display : DigitalDisplay;

        interface sensorToProcessor : SensorToProcessorInterface connect
            sensor::sensorOut to processor::processorIn;

        interface processorToDisplay : ProcessorToDisplayInterface connect
            processor::processorOut to display::displayIn;

        state gaugeModeStateMachine {
            entry; then standbyMode;

            state standbyMode {
                entry action {
                    currentMode = GaugeMode::standby;
                }
                transition standbyMode -> activeMode
                    when powerOnSignal();
            }

            state activeMode {
                entry action {
                    currentMode = GaugeMode::active;
                }
                transition activeMode -> calibrationMode
                    when maintenanceRequested();
                transition activeMode -> standbyMode
                    when powerOffSignal();
            }

            state calibrationMode {
                entry action {
                    currentMode = GaugeMode::calibration;
                }
                transition calibrationMode -> activeMode
                    when maintenanceComplete();
            }
        }

        action def powerOnSignal :> Boolean;
        action def powerOffSignal :> Boolean;
        action def maintenanceRequested :> Boolean;
        action def maintenanceComplete :> Boolean;

        satisfy ModeRequirement by gauge;
    }
}
