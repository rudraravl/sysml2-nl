package BISMonitor {
    import ScalarValues::*;

    // ---- Value Types ----
    value def Voltage :> Real {
        doc "Electrical potential difference.";
        unit 'mV';
    }
    value def Impedance :> Real {
        doc "Electrical impedance measured at electrode-skin interface.";
        unit 'kOhm';
    }
    value def Frequency :> Real {
        doc "Frequency in Hertz.";
        unit 'Hz';
    }
    value def BISIndex :> Integer {
        doc "Bispectral Index score, 0 (no brain activity) to 100 (fully awake).";
        constraint { 0 <= self and self <= 100 }
    }
    value def Percent :> Real {
        doc "Percentage value.";
        unit '%';
    }
    value def Seconds :> Real {
        doc "Time duration in seconds.";
        unit 's';
    }
    value def BatteryLevel :> Real {
        doc "Remaining battery capacity as percentage.";
        unit '%';
    }
    value def DataSize :> Real {
        doc "Data storage size in megabytes.";
        unit 'MB';
    }

    // ---- Item Types ----
    item def EEGSignal {
        doc "Raw analog EEG signal from a single electrode.";
        attribute amplitude : Voltage;
        attribute sampleRate : Frequency;
        attribute electrodeId : String;
    }
    item def DigitalEEG {
        doc "Digitized, amplified, and filtered EEG signal ready for DSP.";
        attribute sampleRate : Frequency;
        attribute bitDepth : Integer;
        attribute channelCount : Integer;
    }
    item def BISData {
        doc "Processed output containing BIS index and auxiliary metrics.";
        attribute bisIndex : BISIndex;
        attribute signalQuality : Percent;
        attribute emgActivity : Percent;
        attribute suppressionRatio : Percent;
        attribute timestamp : Seconds;
    }
    item def AlarmEvent {
        doc "Alarm notification raised by the Alarm Management Unit.";
        enum AlarmType { highBIS, lowBIS, lowSignalQuality, lowBattery, powerFailure, electrodeImpedance }
        attribute type : AlarmType;
        attribute severity : Integer;
        attribute message : String;
        attribute timestamp : Seconds;
    }
    item def PowerStatus {
        doc "Current power source and battery level information.";
        enum Source { ac, battery }
        attribute source : Source;
        attribute batteryLevel : BatteryLevel;
        attribute acPowerLost : Boolean;
    }
    item def SessionRecord {
        doc "Complete recorded session of BIS data for a patient procedure.";
        attribute patientId : String;
        attribute sessionId : String;
        attribute startTime : Seconds;
        attribute duration : Seconds;
        attribute dataPoints : BISData[0..*];
    }

    // ---- Port Definitions ----
    port def EEGOutPort {
        out signal : EEGSignal;
        out impedance : Impedance;
    }
    port def DigitalEEGPort {
        out data : DigitalEEG;
    }
    port def BISDataPort {
        out data : BISData;
    }
    port def AlarmPort {
        out event : AlarmEvent;
    }
    port def PowerPort {
        out status : PowerStatus;
    }
    port def NetworkPort {
        out record : SessionRecord;
        in config : String;
    }

    // ---- Parts ----
    part def EEGElectrode {
        doc "Single EEG electrode placed on patient forehead or temple.";
        attribute electrodeId : String;
        attribute position : String;
        attribute impedanceThreshold : Impedance = 5;
        attribute currentImpedance : Impedance;
        port eegOut : EEGOutPort;

        action def AcquireSignal {
            doc "Continuously acquire raw EEG signal and measure skin impedance.";
            in patientSignal : Voltage;
            out raw : EEGSignal;
            out imp : Impedance;
        }
        perform AcquireSignal;
    }

    part def SignalAcquisitionModule {
        doc "Amplifies, filters, and digitizes raw EEG signals from all electrodes.";
        attribute gain : Real = 10000;
        attribute lowCutoff : Frequency = 0.5;
        attribute highCutoff : Frequency = 47;
        attribute notchFrequency : Frequency = 50;
        port eegIn : ~EEGOutPort[4];
        port digitalOut : DigitalEEGPort;

        action def ProcessSignal {
            doc "Amplify, filter, and digitize incoming analog EEG signals.";
            in raw : EEGSignal[4];
            out digital : DigitalEEG;
        }
        perform ProcessSignal;
    }

    part def DSP {
        doc "Digital Signal Processor: calculates BIS index, signal quality, EMG, and suppression ratio.";
        attribute processingInterval : Seconds = 1;
        attribute currentBIS : BISIndex;
        attribute currentSignalQuality : Percent;
        attribute currentEMG : Percent;
        attribute currentSuppression : Percent;
        port digitalIn : ~DigitalEEGPort;
        port bisOut : BISDataPort;

        action def CalculateBIS {
            doc "Perform bispectral analysis on digital EEG to compute BIS and metrics.";
            in digital : DigitalEEG;
            out bisData : BISData;
        }
        perform CalculateBIS;
    }

    part def AlarmManagementUnit {
        doc "Critical safety component: monitors BIS data and power status, triggers audible and visual alarms.";
        attribute highBISThreshold : BISIndex = 70;
        attribute lowBISThreshold : BISIndex = 30;
        attribute minSignalQuality : Percent = 50;
        attribute lowBatteryThreshold : BatteryLevel = 20;
        attribute criticalBatteryThreshold : BatteryLevel = 5;
        attribute currentBIS : BISIndex;
        attribute currentSQ : Percent;
        attribute currentBattery : BatteryLevel;
        attribute acPowerLost : Boolean = false;
        attribute alarmActive : Boolean = false;
        port bisIn : ~BISDataPort;
        port powerIn : ~PowerPort;
        port alarmOut : AlarmPort;

        state alarmBehavior {
            initial Normal;
            state HighBISAlarm {
                doc "Patient BIS too high - risk of awareness.";
            }
            state LowBISAlarm {
                doc "Patient BIS too low - risk of deep anesthesia.";
            }
            state LowSignalQualityAlarm {
                doc "EEG signal quality below acceptable threshold.";
            }
            state LowBatteryAlarm {
                doc "Battery level low - charge remaining limited.";
            }
            state PowerFailureAlarm {
                doc "AC power lost - operating on battery.";
            }

            transition Normal to HighBISAlarm
                when currentBIS > highBISThreshold;
            transition HighBISAlarm to Normal
                when currentBIS <= highBISThreshold;
            transition Normal to LowBISAlarm
                when currentBIS < lowBISThreshold;
            transition LowBISAlarm to Normal
                when currentBIS >= lowBISThreshold;
            transition Normal to LowSignalQualityAlarm
                when currentSQ < minSignalQuality;
            transition LowSignalQualityAlarm to Normal
                when currentSQ >= minSignalQuality;
            transition Normal to LowBatteryAlarm
                when currentBattery < lowBatteryThreshold;
            transition LowBatteryAlarm to Normal
                when currentBattery >= lowBatteryThreshold;
            transition Normal to PowerFailureAlarm
                when acPowerLost;
            transition PowerFailureAlarm to Normal
                when not acPowerLost;
        }
    }

    part def DisplayModule {
        doc "Screen showing current BIS value, trend graph, signal quality, EMG, and active alarms.";
        attribute refreshRate : Frequency = 1;
        attribute trendHistory : Seconds = 3600;
        port bisIn : ~BISDataPort;
        port alarmIn : ~AlarmPort;

        action def UpdateDisplay {
            doc "Refresh screen with current BIS value, trend graph, metrics, and alarm status.";
            in bisData : BISData;
            in alarm : AlarmEvent;
        }
        perform UpdateDisplay;
    }

    part def PowerManagementUnit {
        doc "Manages AC and battery power; seamlessly switches to battery on AC failure.";
        attribute batteryCapacity : Seconds = 14400;
        attribute batteryLevel : BatteryLevel = 100;
        attribute acPowerLost : Boolean = false;
        port powerOut : PowerPort;

        state powerBehavior {
            initial ACPower;
            state BatteryPower {
                doc "Operating on battery backup power.";
            }
            state BatteryLow {
                doc "Battery level below 20 percent - warning issued.";
            }
            state PowerOff {
                doc "Battery depleted - system shutdown.";
            }

            transition ACPower to BatteryPower
                when acPowerLost;
            transition BatteryPower to BatteryLow
                when batteryLevel < 20;
            transition BatteryLow to PowerOff
                when batteryLevel < 5;
            transition BatteryPower to ACPower
                when not acPowerLost;
            transition BatteryLow to ACPower
                when not acPowerLost;
        }
    }

    part def DataStorageModule {
        doc "Records all BIS data and metrics throughout the procedure for patient records and review.";
        attribute storageCapacity : DataSize = 512;
        attribute currentSession : SessionRecord;
        port bisIn : ~BISDataPort;
        port network : NetworkPort;

        action def RecordSession {
            doc "Continuously record BIS data points into the session record.";
            in bisData : BISData;
            out record : SessionRecord;
        }
        perform RecordSession;

        action def TransmitData {
            doc "Transmit recorded session data over network connection.";
            in record : SessionRecord;
        }
        perform TransmitData;
    }

    part def BISMonitorSystem {
        doc "Aspect Medical Systems BIS Monitor: measures patient depth of anesthesia via EEG processing.";
        attribute deviceId : String;
        attribute firmwareVersion : String;
        attribute targetBISLow : BISIndex = 40;
        attribute targetBISHigh : BISIndex = 60;

        part electrodes : EEGElectrode[4] {
            doc "Four EEG electrodes placed on patient forehead and temple.";
        }
        part acquisition : SignalAcquisitionModule;
        part dsp : DSP;
        part alarm : AlarmManagementUnit;
        part display : DisplayModule;
        part power : PowerManagementUnit;
        part storage : DataStorageModule;

        connection electrodeToAcquisition
            connect electrodes.eegOut to acquisition.eegIn;
        connection acquisitionToDSP
            connect acquisition.digitalOut to dsp.digitalIn;
        connection dspToAlarm
            connect dsp.bisOut to alarm.bisIn;
        connection dspToDisplay
            connect dsp.bisOut to display.bisIn;
        connection alarmToDisplay
            connect alarm.alarmOut to display.alarmIn;
        connection dspToStorage
            connect dsp.bisOut to storage.bisIn;
        connection powerToAlarm
            connect power.powerOut to alarm.powerIn;
    }

    // ---- Requirements ----
    req def BISRangeRequirement {
        doc "The BIS index shall range from 0 (no brain activity) to 100 (fully awake).";
        subject bisIndex : BISIndex;
        constraint { 0 <= bisIndex and bisIndex <= 100 }
    }

    req def TargetAnesthesiaRange {
        doc "The system shall support maintaining BIS in the 40 to 60 range for adequate surgical anesthesia.";
        subject targetBIS : BISIndex;
        constraint { 40 <= targetBIS and targetBIS <= 60 }
    }

    req def ProcessingLatencyRequirement {
        doc "The DSP shall update the BIS value at least once per second.";
        subject interval : Seconds;
        constraint { interval <= 1 }
    }

    req def BatteryBackupRequirement {
        doc "The system shall provide at least 4 hours of continuous monitoring on battery backup.";
        subject backupTime : Seconds;
        constraint { backupTime >= 14400 }
    }

    req def AlarmResponseRequirement {
        doc "Audible and visual alarms shall trigger within 2 seconds of a threshold breach.";
        subject responseTime : Seconds;
        constraint { responseTime <= 2 }
    }

    req def ElectrodeCountRequirement {
        doc "The system shall use four EEG electrodes placed on the patient forehead and temple.";
        subject electrodeCount : Integer;
        constraint { electrodeCount == 4 }
    }

    req def SignalQualityRequirement {
        doc "The system shall monitor EEG signal quality and alarm when quality drops below 50 percent.";
        subject quality : Percent;
        constraint { quality >= 50 }
    }

    req def DataStorageRequirement {
        doc "The system shall record all BIS data and related metrics throughout the procedure for post-operative review.";
        subject recorded : Boolean;
        constraint { recorded == true }
    }

    req def NetworkTransmissionRequirement {
        doc "The system shall support network transmission of session data and remote configuration.";
        subject networkEnabled : Boolean;
        constraint { networkEnabled == true }
    }

    req def ImpedanceMonitoringRequirement {
        doc "Each electrode shall continuously measure skin impedance and alarm when exceeding 5 kOhm.";
        subject impedance : Impedance;
        constraint { impedance <= 5 }
    }

    req def SeamlessPowerSwitchoverRequirement {
        doc "The system shall switch from AC to battery power without interruption of monitoring.";
        subject switchoverTime : Seconds;
        constraint { switchoverTime <= 0.1 }
    }

    // ---- Requirement Satisfaction ----
    requirement BISMonitorRequirements {
        doc "Top-level requirements package for the BIS Monitor system.";
        satisfy BISRangeRequirement by BISMonitorSystem;
        satisfy TargetAnesthesiaRange by BISMonitorSystem;
        satisfy ProcessingLatencyRequirement by dsp;
        satisfy BatteryBackupRequirement by power;
        satisfy AlarmResponseRequirement by alarm;
        satisfy ElectrodeCountRequirement by electrodes;
        satisfy SignalQualityRequirement by alarm;
        satisfy DataStorageRequirement by storage;
        satisfy NetworkTransmissionRequirement by storage;
        satisfy ImpedanceMonitoringRequirement by electrodes;
        satisfy SeamlessPowerSwitchoverRequirement by power;
    }
}
