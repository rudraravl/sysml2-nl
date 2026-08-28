package NeutronDetectionSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value def Voltage :> Real { unit 'V'; }
    value def HighVoltage :> Voltage;
    value def LowVoltage :> Voltage;
    value def CountRate :> Real { unit 'cps'; }   // counts per second
    value def Counts :> Integer;
    value def TimeSeconds :> Real { unit 's'; }
    value def PulseAmplitude :> Real { unit 'mV'; }
    value def ThresholdLevel :> CountRate;

    // ---- Item types ----
    item def Neutron;
    item def RawPulse {
        attribute amplitude : PulseAmplitude;
        attribute timestamp : TimeSeconds;
    }
    item def ValidCount {
        attribute timestamp : TimeSeconds;
    }
    item def CountRateData {
        attribute rate : CountRate;
        attribute total : Counts;
        attribute timestamp : TimeSeconds;
    }
    item def AlarmStatus {
        attribute level : AlarmLevel;
        attribute active : Boolean;
    }
    enum def AlarmLevel {
        normal = 0;
        caution = 1;
        warning = 2;
        critical = 3;
    }

    // ---- Port definitions ----
    port def NeutronFluxPort { in item neutrons : Neutron; }
    port def RawPulseOutPort { out item pulse : RawPulse; }
    port def RawPulseInPort { in item pulse : RawPulse; }
    port def ValidCountOutPort { out item count : ValidCount; }
    port def ValidCountInPort { in item count : ValidCount; }
    port def CountRateOutPort { out item data : CountRateData; }
    port def CountRateInPort { in item data : CountRateData; }
    port def AlarmOutPort { out item status : AlarmStatus; }
    port def AlarmInPort { in item status : AlarmStatus; }
    port def HVPort { out voltage : HighVoltage; }
    port def LVPort { out voltage : LowVoltage; }
    port def HVInPort { in voltage : HighVoltage; }
    port def LVInPort { in voltage : LowVoltage; }

    // ---- Requirements ----
    requirement def DetectNeutronsRequirement {
        doc << "The system shall detect incident neutrons and produce a measurable electrical pulse for each valid neutron interaction.">>
        attribute minSensitivity : CountRate = 0.01 [cps];
    }

    requirement def MeasureCountRateRequirement {
        doc << "The system shall measure the neutron count rate in counts per second and maintain a running total of detected neutrons.">>
        attribute rateAccuracy : Real = 0.05; // +/- 5%
        attribute maxRate : CountRate = 10000 [cps];
    }

    requirement def AlertOperatorsRequirement {
        doc << "The system shall alert operators when neutron radiation levels exceed caution, warning, or critical thresholds.">>
        attribute cautionThreshold : ThresholdLevel = 10 [cps];
        attribute warningThreshold : ThresholdLevel = 100 [cps];
        attribute criticalThreshold : ThresholdLevel = 1000 [cps];
        attribute maxResponseTime : TimeSeconds = 1 [s];
    }

    requirement def PowerStabilityRequirement {
        doc << "The system power supply shall provide stable high voltage for the detector tube and stable low voltage for electronics.">>
        attribute hvNominal : HighVoltage = 900 [V];
        attribute hvTolerance : Real = 0.01;
        attribute lvNominal : LowVoltage = 12 [V];
        attribute lvTolerance : Real = 0.02;
    }

    requirement def DisplayRequirement {
        doc << "The display unit shall show current count rate, total counts, and alarm status in real time.">>
        attribute refreshInterval : TimeSeconds = 0.5 [s];
    }

    // ---- Part definitions ----
    part def DetectorTube {
        doc << "Gas-filled proportional counter serving as the primary neutron sensor.">>
        attribute gasType : String = "He-3";
        attribute operatingVoltage : HighVoltage = 900 [V];
        port neutronIn : NeutronFluxPort;
        port pulseOut : RawPulseOutPort;
        port hvIn : HVInPort;

        action def GeneratePulse {
            in neutron : Neutron;
            out pulse : RawPulse;
        }
    }

    part def SignalProcessor {
        doc << "Cleans, amplifies, and discriminates raw pulses to produce valid neutron counts.">>
        attribute gain : Real = 100;
        attribute noiseFloor : PulseAmplitude = 5 [mV];
        port pulseIn : RawPulseInPort;
        port countOut : ValidCountOutPort;
        port lvIn : LVInPort;

        action def ProcessPulse {
            in raw : RawPulse;
            out valid : ValidCount;
        }
    }

    part def CountRateMonitor {
        doc << "Calculates current count rate and accumulates total neutron counts.">>
        attribute windowSize : TimeSeconds = 1 [s];
        attribute currentRate : CountRate;
        attribute totalCount : Counts;
        port countIn : ValidCountInPort;
        port rateOut : CountRateOutPort;
        port lvIn : LVInPort;

        action def UpdateRate {
            in count : ValidCount;
            out data : CountRateData;
        }
    }

    part def AlarmController {
        doc << "Compares count rate against caution, warning, and critical thresholds and raises alarms.">>
        attribute cautionThreshold : ThresholdLevel = 10 [cps];
        attribute warningThreshold : ThresholdLevel = 100 [cps];
        attribute criticalThreshold : ThresholdLevel = 1000 [cps];
        attribute currentLevel : AlarmLevel = AlarmLevel::normal;
        port rateIn : CountRateInPort;
        port alarmOut : AlarmOutPort;
        port lvIn : LVInPort;

        action def EvaluateThresholds {
            in data : CountRateData;
            out status : AlarmStatus;
        }
    }

    part def DisplayUnit {
        doc << "Provides real-time display of count rate, total counts, and alarm status.">>
        attribute refreshInterval : TimeSeconds = 0.5 [s];
        port rateIn : CountRateInPort;
        port alarmIn : AlarmInPort;
        port lvIn : LVInPort;

        action def RefreshDisplay {
            in rateData : CountRateData;
            in alarmData : AlarmStatus;
        }
    }

    part def PowerSupply {
        doc << "Provides stable high voltage for the detector tube and low voltage for electronics.">>
        attribute hvOutput : HighVoltage = 900 [V];
        attribute lvOutput : LowVoltage = 12 [V];
        port hvOut : HVPort;
        port lvOut : LVPort;
    }

    // ---- System-level state machine ----
    state def SystemStates {
        entry; exit;
        idle {
            doc << "Powered on but not actively measuring.">>
            entry action { send PowerOnSignal(); }
            transition idle_to_monitoring first idle to monitoring
                when TriggerStartMonitoring;
        }
        monitoring {
            doc << "Normal operation: actively detecting and measuring neutrons.">>
            transition monitoring_to_alarming to alarming
                when ThresholdExceeded;
            transition monitoring_to_idle to idle
                when TriggerStopMonitoring;
            transition monitoring_to_calibrating to calibrating
                when TriggerCalibration;
        }
        alarming {
            doc << "Safety threshold breached; alarm active.">>
            entry action { send RaiseAlarm(); }
            transition alarming_to_monitoring to monitoring
                when ThresholdCleared;
        }
        calibrating {
            doc << "Maintenance and setup mode.">>
            entry action { send StartCalibration(); }
            transition calibrating_to_monitoring to monitoring
                when CalibrationComplete;
        }
    }

    // ---- Top-level system ----
    part neutronDetectionSystem :> NeutronDetectionSystem {
        doc << "Continuous safety monitoring system for neutron radiation.">>

        satisfy DetectNeutronsRequirement;
        satisfy MeasureCountRateRequirement;
        satisfy AlertOperatorsRequirement;
        satisfy PowerStabilityRequirement;
        satisfy DisplayRequirement;

        attribute systemState : SystemStates;

        part detectorTube : DetectorTube;
        part signalProcessor : SignalProcessor;
        part countRateMonitor : CountRateMonitor;
        part alarmController : AlarmController;
        part displayUnit : DisplayUnit;
        part powerSupply : PowerSupply;

        // Connections
        connection detectorToProcessor : RawPulse
            from detectorTube.pulseOut to signalProcessor.pulseIn;
        connection processorToMonitor : ValidCount
            from signalProcessor.countOut to countRateMonitor.countIn;
        connection monitorToAlarm : CountRateData
            from countRateMonitor.rateOut to alarmController.rateIn;
        connection monitorToDisplay : CountRateData
            from countRateMonitor.rateOut to displayUnit.rateIn;
        connection alarmToDisplay : AlarmStatus
            from alarmController.alarmOut to displayUnit.alarmIn;

        // Power distribution
        connection hvToDetector : HighVoltage
            from powerSupply.hvOut to detectorTube.hvIn;
        connection lvToProcessor : LowVoltage
            from powerSupply.lvOut to signalProcessor.lvIn;
        connection lvToMonitor : LowVoltage
            from powerSupply.lvOut to countRateMonitor.lvIn;
        connection lvToAlarm : LowVoltage
            from powerSupply.lvOut to alarmController.lvIn;
        connection lvToDisplay : LowVoltage
            from powerSupply.lvOut to displayUnit.lvIn;

        exhibit state behavior : SystemStates;
    }
}
