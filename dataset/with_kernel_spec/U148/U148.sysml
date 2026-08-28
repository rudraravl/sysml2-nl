package BIS_Monitor_Model {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    package ValueTypes {
        attribute def BISValue :> Real {
            doc /* Bispectral Index value, 0 to 100 */
            assert constraint { that >= 0 and that <= 100 }
        }
        attribute def SignalQualityValue :> Real {
            assert constraint { that >= 0 and that <= 100 }
        }
        attribute def EMGValue :> Real {
            assert constraint { that >= 0 and that <= 100 }
        }
        attribute def SuppressionRateValue :> Real {
            assert constraint { that >= 0 and that <= 100 }
        }
        attribute def ImpedanceValue :> Real {
            doc /* Skin contact impedance in ohms */
        }
        attribute def BatteryLevelValue :> Real {
            assert constraint { that >= 0 and that <= 100 }
        }
        attribute def VoltageValue :> Real {
            doc /* EEG signal amplitude in microvolts */
        }
        attribute def FrequencyValue :> Real {
            doc /* EEG signal frequency in Hz */
        }
    }

    package ItemDefinitions {
        item def EEGSignal {
            attribute amplitude : VoltageValue;
            attribute frequency : FrequencyValue;
        }
        item def DigitalEEGData;
        item def ProcessedBISData {
            attribute bis : BISValue;
            attribute quality : SignalQualityValue;
            attribute emg : EMGValue;
            attribute suppression : SuppressionRateValue;
        }
        item def AlarmEvent {
            attribute alarmType : String;
            attribute severity : String;
        }
        item def DisplayData;
    }

    package SignalDefinitions {
        attribute def EEGDataReady;
        attribute def BISDataReady;
        attribute def BISHighAlarm;
        attribute def BISLowAlarm;
        attribute def PoorSignalAlarm;
        attribute def PowerFailure;
        attribute def PowerRestored;
        attribute def BatteryLow;
        attribute def AlarmReset;
        attribute def StartMonitoring;
        attribute def StopMonitoring;
    }

    package PortDefinitions {
        port def EEGSignalPort;
        port def DigitalDataPort;
        port def BISDataPort;
        port def AlarmPort;
        port def PowerPort;
        port def NetworkPort;
    }

    package ActionDefinitions {
        action def AcquireEEG;
        action def AmplifySignal;
        action def NoiseFilter;
        action def ConvertAnalogToDigital;
        action def ProcessEEGData;
        action def CalculateBIS;
        action def EvaluateThresholds;
        action def RenderDisplay;
        action def StoreData;
        action def TransmitData;
        action def CheckImpedance;
    }

    package StateDefinitions {
        state def DSPStates;
        state def AlarmStates;
        state def PowerStates;
        state def ElectrodeStates;
    }

    package PartDefinitions {
        part def Patient;
        part def Anesthesiologist;

        part def EEGElectrode {
            attribute impedance : ImpedanceValue;
            attribute contactQuality : SignalQualityValue;
            port eegOut : EEGSignalPort;
            perform action checkImpedance : CheckImpedance;
        }

        part def SignalAcquisitionModule {
            port analogIn : EEGSignalPort;
            port digitalOut : DigitalDataPort;
            port powerIn : PowerPort;
            perform action acquireEEG : AcquireEEG;
            perform action amplify : AmplifySignal;
            perform action noiseFilter : NoiseFilter;
            perform action convert : ConvertAnalogToDigital;
        }

        part def DigitalSignalProcessor {
            port digitalIn : DigitalDataPort;
            port bisOut : BISDataPort;
            port powerIn : PowerPort;
            attribute bisValue : BISValue;
            attribute signalQuality : SignalQualityValue;
            attribute emgLevel : EMGValue;
            attribute suppressionRate : SuppressionRateValue;
            perform action processEEG : ProcessEEGData;
            perform action calculateBIS : CalculateBIS;
        }

        part def AlarmManagementUnit {
            port dataIn : BISDataPort;
            port alarmOut : AlarmPort;
            port powerIn : PowerPort;
            attribute highThreshold : BISValue = 70;
            attribute lowThreshold : BISValue = 30;
            attribute qualityThreshold : SignalQualityValue = 50;
            perform action evaluateThresholds : EvaluateThresholds;
        }

        part def DisplayModule {
            port dataIn : BISDataPort;
            port alarmIn : AlarmPort;
            port powerIn : PowerPort;
            perform action renderDisplay : RenderDisplay;
        }

        part def PowerManagementUnit {
            port powerOut : PowerPort;
            attribute batteryLevel : BatteryLevelValue = 100;
            attribute powerSource : String = "AC";
        }

        part def DataStorageModule {
            port storageIn : BISDataPort;
            port networkOut : NetworkPort;
            port powerIn : PowerPort;
            perform action storeData : StoreData;
            perform action transmitData : TransmitData;
        }

        part def BISMonitor {
            attribute serialNumber : String;
            attribute model : String = "Aspect BIS";
        }
    }

    package RequirementDefinitions {
        requirement def BISAccuracyRequirement {
            doc /* The BIS monitor shall measure depth of anesthesia with BIS value 0-100 */
            subject monitor : DigitalSignalProcessor;
            assert constraint { monitor.bisValue >= 0 and monitor.bisValue <= 100 }
        }
        requirement def SafeAnesthesiaRangeRequirement {
            doc /* Target BIS range for surgical anesthesia is 40-60 */
            subject monitor : DigitalSignalProcessor;
            assert constraint { monitor.bisValue >= 40 and monitor.bisValue <= 60 }
        }
        requirement def AlarmThresholdRequirement {
            doc /* Alarms shall trigger when BIS exceeds 70 or drops below 30, or signal quality < 50 */
            subject alarmUnit : AlarmManagementUnit;
            assert constraint {
                alarmUnit.highThreshold == 70 and
                alarmUnit.lowThreshold == 30 and
                alarmUnit.qualityThreshold == 50
            }
        }
        requirement def PowerBackupRequirement {
            doc /* The monitor shall provide backup battery power for continuous monitoring */
            subject powerUnit : PowerManagementUnit;
            assert constraint { powerUnit.batteryLevel >= 0 and powerUnit.batteryLevel <= 100 }
        }
    }

    package Usages {
        private import ValueTypes::*;
        private import ItemDefinitions::*;
        private import SignalDefinitions::*;
        private import PortDefinitions::*;
        private import ActionDefinitions::*;
        private import StateDefinitions::*;
        private import PartDefinitions::*;
        private import RequirementDefinitions::*;

        part bisMonitor : BISMonitor {
            doc /* Aspect Medical Systems BIS Monitor */

            part electrode1 : EEGElectrode {
                perform action checkImpedance : CheckImpedance;
                exhibit state electrodeStates : ElectrodeStates {
                    state good;
                    accept PoorSignalAlarm
                        then poor;
                    state poor;
                    accept AlarmReset
                        then good;
                }
            }
            part electrode2 : EEGElectrode {
                perform action checkImpedance : CheckImpedance;
            }
            part electrode3 : EEGElectrode {
                perform action checkImpedance : CheckImpedance;
            }
            part electrode4 : EEGElectrode {
                perform action checkImpedance : CheckImpedance;
            }

            part acquisitionModule : SignalAcquisitionModule {
                perform action acquireEEG : AcquireEEG;
                perform action amplify : AmplifySignal;
                perform action noiseFilter : NoiseFilter;
                perform action convert : ConvertAnalogToDigital;
            }

            part dsp : DigitalSignalProcessor {
                attribute redefines bisValue = 50;
                attribute redefines signalQuality = 95;
                attribute redefines emgLevel = 10;
                attribute redefines suppressionRate = 5;
                perform action processEEG : ProcessEEGData;
                perform action calculateBIS : CalculateBIS;
                exhibit state dspStates : DSPStates {
                    state idle;
                    accept EEGDataReady
                        then processing;
                    state processing {
                        do processEEG;
                        do calculateBIS;
                        do send new BISDataReady() to alarmUnit;
                    }
                    accept StopMonitoring
                        then idle;
                }
            }

            part alarmUnit : AlarmManagementUnit {
                attribute redefines highThreshold = 70;
                attribute redefines lowThreshold = 30;
                attribute redefines qualityThreshold = 50;
                perform action evaluateThresholds : EvaluateThresholds;
                exhibit state alarmStates : AlarmStates {
                    state monitoring;
                    accept BISDataReady
                        if bisMonitor.dsp.bisValue > highThreshold
                        do send new BISHighAlarm() to display
                        then alerting;
                    accept BISDataReady
                        if bisMonitor.dsp.bisValue < lowThreshold
                        do send new BISLowAlarm() to display
                        then alerting;
                    accept BISDataReady
                        if bisMonitor.dsp.signalQuality < qualityThreshold
                        do send new PoorSignalAlarm() to display
                        then alerting;
                    state alerting;
                    accept AlarmReset
                        then monitoring;
                }
            }

            part display : DisplayModule {
                perform action renderDisplay : RenderDisplay;
            }

            part powerUnit : PowerManagementUnit {
                attribute redefines batteryLevel = 100;
                attribute redefines powerSource = "AC";
                exhibit state powerStates : PowerStates {
                    state acPower;
                    accept PowerFailure
                        then batteryPower;
                    state batteryPower;
                    accept PowerRestored
                        then acPower;
                    accept BatteryLow
                        then lowBattery;
                    state lowBattery;
                    accept PowerRestored
                        then acPower;
                }
            }

            part storage : DataStorageModule {
                perform action storeData : StoreData;
                perform action transmitData : TransmitData;
            }

            connect electrode1.eegOut to acquisitionModule.analogIn;
            connect electrode2.eegOut to acquisitionModule.analogIn;
            connect electrode3.eegOut to acquisitionModule.analogIn;
            connect electrode4.eegOut to acquisitionModule.analogIn;
            connect acquisitionModule.digitalOut to dsp.digitalIn;
            connect dsp.bisOut to alarmUnit.dataIn;
            connect dsp.bisOut to display.dataIn;
            connect alarmUnit.alarmOut to display.alarmIn;
            connect dsp.bisOut to storage.storageIn;
            connect powerUnit.powerOut to acquisitionModule.powerIn;
            connect powerUnit.powerOut to dsp.powerIn;
            connect powerUnit.powerOut to alarmUnit.powerIn;
            connect powerUnit.powerOut to display.powerIn;
            connect powerUnit.powerOut to storage.powerIn;
        }

        part patient : Patient;
        part anesthesiologist : Anesthesiologist;

        requirement bisAccuracy : BISAccuracyRequirement {
            subject monitor = bisMonitor.dsp;
        }
        requirement safeRange : SafeAnesthesiaRangeRequirement {
            subject monitor = bisMonitor.dsp;
        }
        requirement alarmThreshold : AlarmThresholdRequirement {
            subject alarmUnit = bisMonitor.alarmUnit;
        }
        requirement powerBackup : PowerBackupRequirement {
            subject powerUnit = bisMonitor.powerUnit;
        }
    }
}
