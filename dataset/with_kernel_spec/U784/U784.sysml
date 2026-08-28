package NeutronDetectionSystemModel {
    private import ScalarValues::*;
    private import ISQ::*;
    public import Definitions::*;
    
    package Definitions {
        private import ScalarValues::*;
        private import ISQ::*;
        
        item def NeutronCount;
        attribute def RawPulse;
        attribute def CountRateValue :> Real;
        attribute def TotalCountsValue :> Integer;
        
        enum def AlarmLevel {
            normal;
            caution;
            warning;
            critical;
        }
        
        attribute def HighVoltage;
        attribute def LowVoltage;
        attribute def CriticalAlarm;
        attribute def StartMonitoring;
        attribute def Calibrate;
        attribute def AcknowledgeAlarm;
        attribute def CalibrationComplete;
        
        port def RawPulseOutPort { out rawPulse : RawPulse; }
        port def RawPulseInPort { in rawPulse : RawPulse; }
        port def NeutronCountOutPort { out count : NeutronCount; }
        port def NeutronCountInPort { in count : NeutronCount; }
        port def CountRateOutPort { out rate : CountRateValue; out total : TotalCountsValue; }
        port def CountRateInPort { in rate : CountRateValue; in total : TotalCountsValue; }
        port def AlarmStatusOutPort { out status : AlarmLevel; }
        port def AlarmStatusInPort { in status : AlarmLevel; }
        port def HVPowerInPort { in hv : HighVoltage; }
        port def HVPowerOutPort { out hv : HighVoltage; }
        port def LVPowerInPort { in lv : LowVoltage; }
        port def LVPowerOutPort { out lv : LowVoltage; }
        
        action def DetectNeutron { out rawPulse : RawPulse; }
        action def ProcessSignal { in rawPulse : RawPulse; out count : NeutronCount; }
        action def CalculateRate { in count : NeutronCount; out rate : CountRateValue; out total : TotalCountsValue; }
        action def CompareThresholds { in rate : CountRateValue; out status : AlarmLevel; }
        action def UpdateDisplay { in rate : CountRateValue; in total : TotalCountsValue; in status : AlarmLevel; }
        action def PerformCalibration;
        action def PerformMonitoring {
            do calculateRate;
            do compareThresholds;
            do updateDisplay;
        }
        
        state def SystemStates;
        
        part def DetectorTube {
            port rawPulseOut : RawPulseOutPort;
            port hvIn : HVPowerInPort;
            perform action detectNeutron : DetectNeutron;
        }
        
        part def SignalProcessor {
            port rawPulseIn : RawPulseInPort;
            port countOut : NeutronCountOutPort;
            port lvIn : LVPowerInPort;
            perform action processSignal : ProcessSignal;
        }
        
        part def CountRateMonitor {
            port countIn : NeutronCountInPort;
            port rateOut : CountRateOutPort;
            port lvIn : LVPowerInPort;
            perform action calculateRate : CalculateRate;
        }
        
        part def AlarmController {
            port rateIn : CountRateInPort;
            port alarmOut : AlarmStatusOutPort;
            port lvIn : LVPowerInPort;
            attribute cautionThreshold : CountRateValue;
            attribute warningThreshold : CountRateValue;
            attribute criticalThreshold : CountRateValue;
            perform action compareThresholds : CompareThresholds;
        }
        
        part def DisplayUnit {
            port rateIn : CountRateInPort;
            port alarmIn : AlarmStatusInPort;
            port lvIn : LVPowerInPort;
            perform action updateDisplay : UpdateDisplay;
        }
        
        part def PowerSupply {
            port hvOut : HVPowerOutPort;
            port lvOut : LVPowerOutPort;
        }
        
        part def NeutronDetectionSystem {
            exhibit state systemStates : SystemStates;
        }
        
        requirement def DetectNeutronsRequirement {
            doc /* The system shall detect neutrons using a gas-filled proportional counter. */
        }
        
        requirement def MeasureRateRequirement {
            doc /* The system shall calculate the neutron count rate and track total counts over time. */
        }
        
        requirement def AlertThresholdsRequirement {
            doc /* The system shall raise alarms when count rates exceed caution, warning, or critical thresholds. */
        }
        
        requirement def DisplayDataRequirement {
            doc /* The system shall display real-time count rate, total counts, and alarm status. */
        }
        
        requirement def PowerSupplyRequirement {
            doc /* The system shall provide stable high voltage for the detector and low voltage for electronics. */
        }
        
        requirement def CalibrationRequirement {
            doc /* The system shall support calibration mode for maintenance and setup. */
        }
    }
    
    package Usages {
        private import Definitions::*;
        private import ScalarValues::*;
        private import ISQ::*;
        
        action detectNeutron : DetectNeutron;
        action processSignal : ProcessSignal;
        action calculateRate : CalculateRate;
        action compareThresholds : CompareThresholds;
        action updateDisplay : UpdateDisplay;
        action performCalibration : PerformCalibration;
        action performMonitoring : PerformMonitoring;
        
        part neutronDetectionSystem : NeutronDetectionSystem {
            part detectorTube : DetectorTube;
            part signalProcessor : SignalProcessor;
            part countRateMonitor : CountRateMonitor;
            part alarmController : AlarmController;
            part displayUnit : DisplayUnit;
            part powerSupply : PowerSupply;
            
            connect powerSupply.hvOut to detectorTube.hvIn;
            connect powerSupply.lvOut to signalProcessor.lvIn;
            connect powerSupply.lvOut to countRateMonitor.lvIn;
            connect powerSupply.lvOut to alarmController.lvIn;
            connect powerSupply.lvOut to displayUnit.lvIn;
            
            connect detectorTube.rawPulseOut to signalProcessor.rawPulseIn;
            connect signalProcessor.countOut to countRateMonitor.countIn;
            connect countRateMonitor.rateOut to alarmController.rateIn;
            connect countRateMonitor.rateOut to displayUnit.rateIn;
            connect alarmController.alarmOut to displayUnit.alarmIn;
        }
        
        state systemStates : SystemStates {
            entry; then idle;
            state idle;
            accept StartMonitoring
                then monitoring;
            state monitoring {
                do performMonitoring;
            }
            accept Calibrate
                then calibrating;
            accept when calculateRate.rate > neutronDetectionSystem.alarmController.criticalThreshold
                then alarming;
            state alarming {
                entry send new CriticalAlarm() to neutronDetectionSystem;
            }
            accept AcknowledgeAlarm
                then monitoring;
            state calibrating {
                entry performCalibration;
            }
            accept CalibrationComplete
                then idle;
        }
        
        requirement detectNeutrons : DetectNeutronsRequirement;
        requirement measureRate : MeasureRateRequirement;
        requirement alertThresholds : AlertThresholdsRequirement;
        requirement displayData : DisplayDataRequirement;
        requirement powerSupplyReq : PowerSupplyRequirement;
        requirement calibration : CalibrationRequirement;
    }
}
