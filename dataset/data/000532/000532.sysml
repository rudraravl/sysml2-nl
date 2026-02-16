package AspectMedicalBISMonitorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;
    private import ModelingMetadata::*;

    metadata def MedicalDevice;
    metadata def SafetyCritical;
    metadata def FDARegulated;

    attribute def BISValue :> Real {
        doc /* Bispectral Index value ranging from 0 (no brain activity) to 100 (fully awake). */
        assert constraint { that >= 0.0 and that <= 100.0 }
    }

    attribute def SignalQualityIndex :> Real {
        doc /* Signal quality indicator from 0 (poor) to 100 (excellent). */
        assert constraint { that >= 0.0 and that <= 100.0 }
    }

    attribute def ElectrodeImpedance :> ISQ::electricResistance;

    attribute def EMGLevel :> Real {
        doc /* Electromyographic activity level in dB. */
    }

    attribute def SuppressionRatio :> Real {
        doc /* Percentage of time EEG is suppressed. */
        assert constraint { that >= 0.0 and that <= 100.0 }
    }

    item def EEGWaveform {
        attribute amplitude : ISQ::electricPotential;
        attribute frequency : ISQ::frequency;
        attribute timestamp : ISQ::time;
        attribute channelId : String;
    }

    item def ProcessedBISData {
        attribute bisIndex : BISValue;
        attribute signalQuality : SignalQualityIndex;
        attribute emgActivity : EMGLevel;
        attribute suppressionRatio : SuppressionRatio;
        attribute timestamp : ISQ::time;
    }

    item def AlarmEvent {
        attribute alarmType : String;
        attribute severity : String;
        attribute alarmMessage : String;
        attribute timestamp : ISQ::time;
    }

    port def EEGElectrodePort {
        out rawSignal : EEGWaveform;
        in impedanceTest : ElectrodeImpedance;
    }

    port def DataOutputPort {
        out bisData : ProcessedBISData;
        out alarmSignal : AlarmEvent[0..*];
    }

    port def DisplayInputPort {
        in bisData : ProcessedBISData;
        in alarmSignal : AlarmEvent[0..*];
    }

    port def PowerInputPort {
        in voltage : ISQ::electricPotential;
        in current : ISQ::electricCurrent;
    }

    port def NetworkPort {
        out patientData : ProcessedBISData;
        in configurationData : String;
    }

    part def EEGElectrode {
        @SafetyCritical
        attribute electrodePosition : String;
        attribute impedanceThreshold : ElectrodeImpedance;
        port output : EEGElectrodePort;
    }

    part def SignalAcquisitionModule {
        @SafetyCritical
        attribute samplingRate : ISQ::frequency;
        attribute inputRange : ISQ::electricPotential;
        attribute resolution : Integer;
        
        port electrodeInput1 : ~EEGElectrodePort;
        port electrodeInput2 : ~EEGElectrodePort;
        port electrodeInput3 : ~EEGElectrodePort;
        port electrodeInput4 : ~EEGElectrodePort;
        port dataOutput : DataOutputPort;

        action def AcquireSignals {
            in rawSignal1 : EEGWaveform;
            in rawSignal2 : EEGWaveform;
            in rawSignal3 : EEGWaveform;
            in rawSignal4 : EEGWaveform;
            out digitalSignal : EEGWaveform[4];

            first start;
            then action amplifySignals {
                in signals = (rawSignal1, rawSignal2, rawSignal3, rawSignal4);
                out amplified : EEGWaveform[4];
            }
            then action filterNoise {
                in signals = amplifySignals.amplified;
                out filtered : EEGWaveform[4];
            }
            then action digitizeSignals {
                in signals = filterNoise.filtered;
                out digital = digitalSignal;
            }
            then done;
        }
    }

    part def DigitalSignalProcessor {
        @SafetyCritical
        attribute processingDelay : ISQ::time;
        attribute updateRate : ISQ::frequency;
        
        port signalInput : ~DataOutputPort;
        port processedOutput : DataOutputPort;

        action def ComputeBIS {
            in eegSignals : EEGWaveform[4];
            out bisData : ProcessedBISData;

            first start;
            then action performFFT {
                in signals = eegSignals;
                out frequencyDomain : Real[*];
            }
            then action extractBispectrum {
                in freqData = performFFT.frequencyDomain;
                out bispectralData : Real[*];
            }
            then action calculateBISIndex {
                in bispecData = extractBispectrum.bispectralData;
                out bisValue : BISValue;
            }
            then action assessSignalQuality {
                in signals = eegSignals;
                out quality : SignalQualityIndex;
            }
            then action detectEMG {
                in signals = eegSignals;
                out emgLevel : EMGLevel;
            }
            then action calculateSuppression {
                in signals = eegSignals;
                out suppression : SuppressionRatio;
            }
            then action assembleBISData {
                in bis = calculateBISIndex.bisValue;
                in sq = assessSignalQuality.quality;
                in emg = detectEMG.emgLevel;
                in sr = calculateSuppression.suppression;
                out data = bisData;
            }
            then done;
        }

        state def ProcessingStateMachine {
            entry action initializeProcessor;
            do action continuousProcessing : ComputeBIS;

            state idle {
                entry action enterIdle;
            }
            state acquiring {
                entry action startAcquisition;
                do action collectData;
            }
            state processing {
                entry action beginProcessing;
                do action computeBIS : ComputeBIS;
            }
            state validating {
                entry action validateResults;
            }
            state outputting {
                entry action sendResults;
            }

            transition idleToAcquiring first idle accept StartMonitoringEvent then acquiring;
            transition acquiringToProcessing first acquiring if signalQualityAdequate then processing;
            transition processingToValidating first processing then validating;
            transition validatingToOutputting first validating if resultsValid then outputting;
            transition outputtingToAcquiring first outputting then acquiring;
            transition anyToIdle first acquiring accept StopMonitoringEvent then idle;
        }
    }

    part def AlarmManagementUnit {
        @SafetyCritical
        attribute lowBISThreshold : BISValue;
        attribute highBISThreshold : BISValue;
        attribute lowSQIThreshold : SignalQualityIndex;
        attribute highImpedanceThreshold : ElectrodeImpedance;

        port bisInput : ~DataOutputPort;
        port alarmOutput : DataOutputPort;

        action def MonitorAlarmConditions {
            in bisData : ProcessedBISData;
            in impedance : ElectrodeImpedance[4];
            out alarms : AlarmEvent[0..*];

            first start;
            then merge checkConditions;
            then decide alarmCheck;
                if bisData.bisIndex < lowBISThreshold then action generateLowBISAlarm {
                    out alarm : AlarmEvent;
                }
                if bisData.bisIndex > highBISThreshold then action generateHighBISAlarm {
                    out alarm : AlarmEvent;
                }
                if bisData.signalQuality < lowSQIThreshold then action generateSQIAlarm {
                    out alarm : AlarmEvent;
                }
                if bisData.bisIndex >= lowBISThreshold and 
                   bisData.bisIndex <= highBISThreshold and
                   bisData.signalQuality >= lowSQIThreshold
                then action noAlarm;
            then checkConditions;
        }
    }

    part def DisplayModule {
        attribute screenSize : ISQ::length;
        attribute refreshRate : ISQ::frequency;
        attribute brightness : Real;

        port dataInput : DisplayInputPort;
        port powerInput : PowerInputPort;

        action def UpdateDisplay {
            in bisData : ProcessedBISData;
            in alarms : AlarmEvent[0..*];

            first start;
            then action renderBISValue {
                in data = bisData;
            }
            then action renderTrendGraph {
                in data = bisData;
            }
            then action renderSignalQuality {
                in sq = bisData.signalQuality;
            }
            then action renderEMGBar {
                in emg = bisData.emgActivity;
            }
            then action renderSuppressionRatio {
                in sr = bisData.suppressionRatio;
            }
            then decide alarmDisplay;
                if alarms != null then action displayAlarms {
                    in alarmList = alarms;
                }
                else action clearAlarms;
            then action refreshScreen;
            then done;
        }
    }

    part def PowerManagementUnit {
        attribute acInputVoltage : ISQ::electricPotential;
        attribute dcOutputVoltage : ISQ::electricPotential;
        attribute batteryCapacity : Real;
        attribute batteryVoltage : ISQ::electricPotential;
        attribute currentBatteryLevel : Real;

        port acInput : PowerInputPort;
        port dcOutput : ~PowerInputPort;

        state def PowerStateMachine {
            state acPowered {
                entry action switchToAC;
                do action chargeBattery;
            }
            state batteryPowered {
                entry action switchToBattery;
                do action monitorBatteryLevel;
            }
            state lowBattery {
                entry action activateLowBatteryWarning;
            }
            state criticalBattery {
                entry action activateCriticalBatteryAlarm;
            }
            state shutdown {
                entry action performSafeShutdown;
            }

            transition acToBattery first acPowered accept ACPowerLossEvent then batteryPowered;
            transition batteryToAC first batteryPowered accept ACPowerRestoredEvent then acPowered;
            transition batteryToLow first batteryPowered if currentBatteryLevel < 30.0 then lowBattery;
            transition lowToCritical first lowBattery if currentBatteryLevel < 10.0 then criticalBattery;
            transition criticalToShutdown first criticalBattery if currentBatteryLevel < 5.0 then shutdown;
        }
    }

    part def DataStorageModule {
        attribute storageCapacity : Real;
        attribute recordingDuration : ISQ::time;
        
        port dataInput : ~DataOutputPort;
        port networkOutput : NetworkPort;

        action def RecordPatientData {
            in bisData : ProcessedBISData;
            
            first start;
            then action timestampData {
                in data = bisData;
                out stamped : ProcessedBISData;
            }
            then action storeToMemory {
                in data = timestampData.stamped;
            }
            then action checkStorageCapacity;
            then decide storageCheck;
                if storageCapacity > 90.0 then action archiveOldData;
                else action continueRecording;
            then done;
        }
    }

    @MedicalDevice
    @SafetyCritical
    @FDARegulated
    part def BISMonitor {
        doc /* 
         * Aspect Medical Systems BIS Monitor - A medical device that measures 
         * the depth of anesthesia by processing electroencephalogram (EEG) signals 
         * to compute the Bispectral Index, providing real-time assessment of 
         * patient consciousness level during surgical procedures.
         */
        
        attribute deviceSerialNumber : String;
        attribute softwareVersion : String;
        attribute calibrationDate : String;
        attribute lastMaintenanceDate : String;

        part frontalElectrode : EEGElectrode[1];
        part frontalReferenceElectrode : EEGElectrode[1];
        part temporalElectrode : EEGElectrode[1];
        part groundElectrode : EEGElectrode[1];

        part acquisitionModule : SignalAcquisitionModule[1];
        part dspModule : DigitalSignalProcessor[1];
        part alarmUnit : AlarmManagementUnit[1];
        part display : DisplayModule[1];
        part powerUnit : PowerManagementUnit[1];
        part storage : DataStorageModule[1];

        connection electrode1Connection connect 
            frontalElectrode.output to acquisitionModule.electrodeInput1;
        connection electrode2Connection connect 
            frontalReferenceElectrode.output to acquisitionModule.electrodeInput2;
        connection electrode3Connection connect 
            temporalElectrode.output to acquisitionModule.electrodeInput3;
        connection electrode4Connection connect 
            groundElectrode.output to acquisitionModule.electrodeInput4;

        connection acquisitionToDSP connect 
            acquisitionModule.dataOutput to dspModule.signalInput;
        connection dspToAlarm connect 
            dspModule.processedOutput to alarmUnit.bisInput;
        connection alarmToDisplay connect 
            alarmUnit.alarmOutput to display.dataInput;
        connection dspToStorage connect 
            dspModule.processedOutput to storage.dataInput;

        connection powerToDisplay connect 
            powerUnit.dcOutput to display.powerInput;
    }

    requirement <'REQ-BIS-001'> primaryMonitoringFunction {
        doc /* 
         * The BIS Monitor shall continuously acquire EEG signals from the patient, 
         * process these signals using bispectral analysis algorithms, and compute 
         * a real-time Bispectral Index value (0-100) that correlates with the 
         * patient's level of consciousness and depth of anesthesia during surgical 
         * procedures under general anesthesia.
         */
        subject monitor : BISMonitor;

        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = medium;
                costRisk = medium;
            }
            originator = "Clinical Engineering Department";
            owner = "Medical Device Safety Board";
        }
    }

    requirement <'REQ-BIS-002'> bisComputationAccuracy {
        doc /* 
         * The system shall compute BIS values with an accuracy of ±5 index units 
         * compared to reference standards across the full range of 0-100.
         */
        subject dsp :>> BISMonitor::dspModule;

        assert constraint {
            dsp.processingDelay <= 5.0 [s]
        }
    }

    requirement <'REQ-BIS-003'> signalAcquisitionRate {
        doc /* 
         * The signal acquisition module shall sample EEG signals at a minimum 
         * rate of 128 Hz with 16-bit resolution.
         */
        subject acq :>> BISMonitor::acquisitionModule;

        assert constraint {
            acq.samplingRate >= 128.0 [Hz] and acq.resolution >= 16
        }
    }

    requirement <'REQ-BIS-004'> alarmResponseTime {
        doc /* 
         * The system shall generate alarms within 5 seconds of detecting 
         * BIS values outside the target range or signal quality degradation.
         */
        subject alarmUnit :>> BISMonitor::alarmUnit;
    }

    requirement <'REQ-BIS-005'> displayUpdateRate {
        doc /* 
         * The display shall update BIS values and trend information at least 
         * once per second during active monitoring.
         */
        subject display :>> BISMonitor::display;

        assert constraint {
            display.refreshRate >= 1.0 [Hz]
        }
    }

    requirement <'REQ-BIS-006'> powerBackupDuration {
        doc /* 
         * The system shall provide battery backup power for a minimum of 
         * 2 hours of continuous operation in the event of AC power loss.
         */
        subject power :>> BISMonitor::powerUnit;

        assert constraint {
            power.batteryCapacity >= 4000.0
        }
    }

    requirement <'REQ-BIS-007'> dataRecordingCapacity {
        doc /* 
         * The system shall record and store patient BIS data for a minimum 
         * of 24 hours of continuous monitoring.
         */
        subject storage :>> BISMonitor::storage;

        assert constraint {
            storage.recordingDuration >= 24.0 [h]
        }
    }

    part bisMonitorInstance : BISMonitor {
        attribute :>> deviceSerialNumber = "BIS-A2000-2024-0042";
        attribute :>> softwareVersion = "4.2.1";
        attribute :>> calibrationDate = "2024-01-15";
        attribute :>> lastMaintenanceDate = "2024-06-20";
        
        part :>> frontalElectrode {
            attribute :>> electrodePosition = "Fp1";
            attribute :>> impedanceThreshold = 5000.0 [SI::Ω];
        }
        part :>> frontalReferenceElectrode {
            attribute :>> electrodePosition = "Fp2";
            attribute :>> impedanceThreshold = 5000.0 [SI::Ω];
        }
        part :>> temporalElectrode {
            attribute :>> electrodePosition = "T3";
            attribute :>> impedanceThreshold = 5000.0 [SI::Ω];
        }
        part :>> groundElectrode {
            attribute :>> electrodePosition = "Fpz";
            attribute :>> impedanceThreshold = 5000.0 [SI::Ω];
        }
        
        part :>> acquisitionModule {
            attribute :>> samplingRate = 256.0 [Hz];
            attribute :>> inputRange = 0.5 [V];
            attribute :>> resolution = 16;
        }
        
        part :>> dspModule {
            attribute :>> processingDelay = 2.0 [s];
            attribute :>> updateRate = 1.0 [Hz];
        }
        
        part :>> alarmUnit {
            attribute :>> lowBISThreshold = 40.0;
            attribute :>> highBISThreshold = 60.0;
            attribute :>> lowSQIThreshold = 30.0;
            attribute :>> highImpedanceThreshold = 5000.0 [SI::Ω];
        }
        
        part :>> display {
            attribute :>> screenSize = 10.4 [inch];
            attribute :>> refreshRate = 2.0 [Hz];
        }
        
        part :>> powerUnit {
            attribute :>> acInputVoltage = 120.0 [V];
            attribute :>> dcOutputVoltage = 12.0 [V];
            attribute :>> batteryCapacity = 4000.0;
            attribute :>> batteryVoltage = 14.4 [V];
        }
        
        part :>> storage {
            attribute :>> storageCapacity = 1000.0;
            attribute :>> recordingDuration = 24.0 [h];
        }
    }

    satisfy primaryMonitoringFunction by bisMonitorInstance;
    satisfy bisComputationAccuracy by bisMonitorInstance.dspModule;
    satisfy signalAcquisitionRate by bisMonitorInstance.acquisitionModule;
    satisfy alarmResponseTime by bisMonitorInstance.alarmUnit;
    satisfy displayUpdateRate by bisMonitorInstance.display;
    satisfy powerBackupDuration by bisMonitorInstance.powerUnit;
    satisfy dataRecordingCapacity by bisMonitorInstance.storage;

    action def ClinicalWorkflow {
        doc /* 
         * Complete clinical workflow for using the BIS Monitor during 
         * a surgical procedure requiring general anesthesia.
         */

        first start;
        then action preparePatient {
            doc /* Clean and prepare electrode application sites on patient forehead. */
        }
        then action applyElectrodes {
            doc /* Apply four EEG electrodes according to manufacturer guidelines. */
        }
        then action powerOnMonitor {
            doc /* Power on BIS Monitor and perform self-test. */
        }
        then action checkImpedance {
            doc /* Verify electrode impedance is below 5 kOhm on all channels. */
        }
        then decide impedanceCheck;
            if impedanceAcceptable then action beginMonitoring;
            else action adjustElectrodes then checkImpedance;
        
        action beginMonitoring {
            doc /* Start continuous BIS monitoring and establish baseline. */
        }
        then action inductionPhase {
            doc /* Monitor BIS during anesthesia induction, target BIS 40-60. */
        }
        then merge maintenanceLoop;
        then action assessCurrentBIS {
            out currentBIS : BISValue;
            out currentSQI : SignalQualityIndex;
        }
        then decide anesthesiaDepthCheck;
            if assessCurrentBIS.currentBIS < 40.0 then action reducedAnesthetic {
                doc /* BIS too low - reduce anesthetic agent delivery. */
            }
            if assessCurrentBIS.currentBIS > 60.0 then action increasedAnesthetic {
                doc /* BIS too high - increase anesthetic agent delivery. */
            }
            if assessCurrentBIS.currentBIS >= 40.0 and assessCurrentBIS.currentBIS <= 60.0 
            then action maintainAnesthetic {
                doc /* BIS in target range - maintain current anesthetic depth. */
            }
        then decide signalQualityCheck;
            if assessCurrentBIS.currentSQI < 30.0 then action troubleshootSignal {
                doc /* Poor signal quality - check electrode connections. */
            }
            else action continueMonitoring;
        then maintenanceLoop;
        
        accept SurgeryCompleteEvent;
        then action emergencePhase {
            doc /* Monitor BIS during emergence from anesthesia. */
        }
        then action removeElectrodes {
            doc /* Remove electrodes after patient is fully awake. */
        }
        then action downloadData {
            doc /* Download and archive patient monitoring data. */
        }
        then done;
    }
}
