package HomeEnergyMonitor {
    import ScalarValues::*;
    import Collections::*;

    // ---- Units ----
    unit V;
    unit A;
    unit W;
    unit kWh;
    unit USD;
    unit s;
    unit Hz;
    unit inch;

    // ---- Value types ----
    value def VoltageValue :> Real { unit = V; }
    value def CurrentValue :> Real { unit = A; }
    value def PowerValue   :> Real { unit = W; }
    value def EnergyValue  :> Real { unit = kWh; }
    value def CostValue    :> Real { unit = USD; }
    value def TimeValue    :> Real { unit = s; }
    value def FrequencyValue :> Real { unit = Hz; }
    value def ScreenSizeValue :> Real { unit = inch; }

    // ---- Item definitions ----
    item def VoltageReading {
        attribute value : VoltageValue;
        attribute timestamp : TimeValue;
    }
    item def CurrentReading {
        attribute value : CurrentValue;
        attribute timestamp : TimeValue;
    }
    item def PowerSample {
        attribute power : PowerValue;
        attribute timestamp : TimeValue;
    }
    item def EnergyMetrics {
        attribute totalEnergy : EnergyValue;
        attribute averagePower : PowerValue;
        attribute peakPower : PowerValue;
        attribute estimatedCost : CostValue;
        attribute timestamp : TimeValue;
    }
    item def DisplayData {
        attribute instantaneousPower : PowerValue;
        attribute totalEnergy : EnergyValue;
        attribute averagePower : PowerValue;
        attribute peakPower : PowerValue;
        attribute estimatedCost : CostValue;
        attribute timestamp : TimeValue;
    }
    item def AlertSignal {
        attribute reason : String;
        attribute measuredValue : Real;
        attribute threshold : Real;
        attribute timestamp : TimeValue;
    }

    // ---- Port definitions ----
    port def VoltageOutPort { out item voltage : VoltageReading; }
    port def CurrentOutPort { out item current : CurrentReading; }
    port def VoltageInPort  { in item voltage : VoltageReading; }
    port def CurrentInPort  { in item current : CurrentReading; }
    port def MetricsOutPort { out item metrics : EnergyMetrics; }
    port def MetricsInPort  { in item metrics : EnergyMetrics; }
    port def DisplayOutPort { out item data : DisplayData; }
    port def DisplayInPort  { in item data : DisplayData; }
    port def AlertOutPort   { out item alert : AlertSignal; }
    port def AlertInPort   { in item alert : AlertSignal; }

    // ---- Voltage sensor ----
    part def VoltageSensor {
        port voltageOut : VoltageOutPort;
        attribute samplingRate : FrequencyValue = 1.0;

        action def measureVoltage {
            out v : VoltageReading;
        }

        exhibit VoltageSensorBehavior;

        state def VoltageSensorBehavior {
            entry; then Sampling;
            state Sampling {
                entry { perform measureVoltage; }
                do { send voltageOut.voltage; }
                transition Sampling -> Sampling when true;
            }
        }
    }

    // ---- Current sensor ----
    part def CurrentSensor {
        port currentOut : CurrentOutPort;
        attribute samplingRate : FrequencyValue = 1.0;

        action def measureCurrent {
            out i : CurrentReading;
        }

        exhibit CurrentSensorBehavior;

        state def CurrentSensorBehavior {
            entry; then Sampling;
            state Sampling {
                entry { perform measureCurrent; }
                do { send currentOut.current; }
                transition Sampling -> Sampling when true;
            }
        }
    }

    // ---- Processing unit ----
    part def ProcessingUnit {
        port voltageIn : VoltageInPort;
        port currentIn : CurrentInPort;
        port metricsOut : MetricsOutPort;
        port displayOut : DisplayOutPort;
        port alertOut : AlertOutPort;

        attribute maxPowerThreshold : PowerValue = 5000;
        attribute dailyCostThreshold : CostValue = 5.0;
        attribute tariffRate : CostValue = 0.15; // USD per kWh

        attribute instantaneousPower : PowerValue = 0;
        attribute totalEnergy : EnergyValue = 0;
        attribute averagePower : PowerValue = 0;
        attribute peakPower : PowerValue = 0;
        attribute estimatedCost : CostValue = 0;
        attribute sampleCount : Integer = 0;
        attribute lastTimestamp : TimeValue = 0;

        action def computePower {
            in v : VoltageReading;
            in i : CurrentReading;
            return p : PowerValue;
        }
        action def aggregateEnergy {
            in p : PowerValue;
            in dt : TimeValue;
        }
        action def checkThresholds;
        action def emitDisplayData;
        action def emitMetrics;

        exhibit ProcessingStates;

        state def ProcessingStates {
            entry; then Monitoring;

            state Monitoring {
                entry { /* await next sensor sample */ }
                do {
                    computePower();
                }
                transition Monitoring -> Computing when true;
            }

            state Computing {
                entry {
                    aggregateEnergy();
                    checkThresholds();
                    emitDisplayData();
                    emitMetrics();
                }
                transition Computing -> Monitoring when peakPower <= maxPowerThreshold;
                transition Computing -> Alerting when peakPower > maxPowerThreshold;
                transition Computing -> Alerting when estimatedCost > dailyCostThreshold;
            }

            state Alerting {
                entry {
                    send alertOut.alert;
                }
                transition Alerting -> Monitoring when true;
            }
        }
    }

    // ---- User display ----
    part def UserDisplay {
        port displayIn : DisplayInPort;
        attribute screenSize : ScreenSizeValue = 7.0;
        attribute resolution : String = "1024x600";
        attribute backlightOn : Boolean = true;

        action def render {
            in data : DisplayData;
        }

        exhibit DisplayBehavior;

        state def DisplayBehavior {
            entry; then Idle;
            state Idle {
                transition Idle -> Refreshing when displayIn.data is received;
            }
            state Refreshing {
                entry { perform render; }
                transition Refreshing -> Idle when true;
            }
        }
    }

    // ---- Notification module ----
    part def NotificationModule {
        port alertIn : AlertInPort;
        attribute audioEnabled : Boolean = true;
        attribute visualEnabled : Boolean = true;
        attribute alarmDuration : TimeValue = 10.0;

        action def triggerAudio;
        action def triggerVisual;
        action def soundAlarm;

        exhibit NotificationStates;

        state def NotificationStates {
            entry; then Idle;

            state Idle {
                transition Idle -> Alerting when alertIn.alert is received;
            }

            state Alerting {
                entry {
                    triggerAudio();
                    triggerVisual();
                }
                do { soundAlarm(); }
                transition Alerting -> Idle when alarmDuration <= 0;
            }
        }
    }

    // ---- Top-level system ----
    part def HomeEnergyMonitor {
        part voltageSensor : VoltageSensor;
        part currentSensor : CurrentSensor;
        part processingUnit : ProcessingUnit;
        part userDisplay : UserDisplay;
        part notificationModule : NotificationModule;

        connection voltageSensor.voltageOut to processingUnit.voltageIn;
        connection currentSensor.currentOut to processingUnit.currentIn;
        connection processingUnit.metricsOut to userDisplay.displayIn;
        connection processingUnit.displayOut to userDisplay.displayIn;
        connection processingUnit.alertOut to notificationModule.alertIn;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracy {
        subject monitor : HomeEnergyMonitor;
        requirement voltageAccuracy : VoltageValue = 1.0;
        requirement currentAccuracy : CurrentValue = 0.1;
        requirement samplingInterval : TimeValue <= 1.0;
    }

    requirement def RealTimeMonitoring {
        subject monitor : HomeEnergyMonitor;
        requirement displayUpdateInterval : TimeValue <= 2.0;
        requirement continuousMeasurement : Boolean = true;
    }

    requirement def EnergyComputation {
        subject monitor : HomeEnergyMonitor;
        requirement computeTotalEnergy : EnergyValue;
        requirement computeAveragePower : PowerValue;
        requirement computePeakPower : PowerValue;
        requirement computeEstimatedCost : CostValue;
    }

    requirement def AlertingCapability {
        subject monitor : HomeEnergyMonitor;
        requirement powerThresholdAlert : PowerValue;
        requirement costThresholdAlert : CostValue;
        requirement audioAlert : Boolean = true;
        requirement visualAlert : Boolean = true;
    }

    requirement def UserFeedback {
        subject monitor : HomeEnergyMonitor;
        requirement displayScreenSize : ScreenSizeValue >= 7.0;
        requirement readableFormat : Boolean = true;
    }

    requirement measurementAccuracy : MeasurementAccuracy {
        subject :>> monitor = HomeEnergyMonitor;
    }
    requirement realTimeMonitoring : RealTimeMonitoring {
        subject :>> monitor = HomeEnergyMonitor;
    }
    requirement energyComputation : EnergyComputation {
        subject :>> monitor = HomeEnergyMonitor;
    }
    requirement alertingCapability : AlertingCapability {
        subject :>> monitor = HomeEnergyMonitor;
    }
    requirement userFeedback : UserFeedback {
        subject :>> monitor = HomeEnergyMonitor;
    }

    // ---- Satisfactions ----
    satisfaction measurementAccuracy by HomeEnergyMonitor::voltageSensor;
    satisfaction measurementAccuracy by HomeEnergyMonitor::currentSensor;
    satisfaction realTimeMonitoring by HomeEnergyMonitor::processingUnit;
    satisfaction energyComputation by HomeEnergyMonitor::processingUnit;
    satisfaction alertingCapability by HomeEnergyMonitor::notificationModule;
    satisfaction userFeedback by HomeEnergyMonitor::userDisplay;
}
