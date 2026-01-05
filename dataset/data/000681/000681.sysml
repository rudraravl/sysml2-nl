package MedicalGasSupplySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    attribute def PurityPercentage :> Real;
    
    item def MedicalGas {
        attribute gasType : String;
        attribute purity : PurityPercentage;
        attribute pressure : PressureValue;
    }
    
    item def MedicalOxygen :> MedicalGas {
        attribute :>> gasType = "O2";
        attribute :>> purity = 99.5;
    }
    
    item def MedicalAir :> MedicalGas {
        attribute :>> gasType = "Air";
        attribute oxygenContent : PurityPercentage = 21.0;
    }
    
    port def GasSupplyPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        out item gasSupply : MedicalGas;
    }
    
    port def GasDeliveryPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        in item gasSupply : MedicalGas;
    }
    
    port def MonitoringPort {
        out attribute currentPressure : PressureValue;
        out attribute alarmActive : Boolean;
    }
    
    enum def SupplyMode {
        primary;
        secondary;
        emergency;
    }
    
    enum def AlarmLevel {
        normal;
        warning;
        critical;
    }
    
    part def GasCylinderBank {
        attribute bankCapacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute storagePressure : PressureValue;
        attribute minimumPressure : PressureValue;
        
        port outlet : GasSupplyPort;
        port monitor : MonitoringPort;
    }
    
    part def PressureRegulator {
        attribute targetPressure : PressureValue;
        attribute inputPressure : PressureValue;
        attribute outputPressure : PressureValue;
        
        port inlet : GasDeliveryPort;
        port outlet : GasSupplyPort;
    }
    
    part def ManifoldController {
        attribute activeMode : SupplyMode;
        attribute switchoverThreshold : PressureValue;
        attribute alarmThreshold : PressureValue;
        attribute alarmActive : Boolean;
        
        port primaryInput : GasDeliveryPort;
        port secondaryInput : GasDeliveryPort;
        port regulatedOutput : GasSupplyPort;
        port primaryMonitor : MonitoringPort;
        port secondaryMonitor : MonitoringPort;
        port alarmSignal : MonitoringPort;
        
        state controlLogic {
            entry action initialize;
            
            state NormalOperation {
                entry assign activeMode := SupplyMode::primary;
                entry assign alarmActive := false;
            }
            
            state SwitchingToSecondary {
                entry action switchValves;
                entry assign activeMode := SupplyMode::secondary;
            }
            
            state SecondaryOperation {
                entry assign alarmActive := false;
            }
            
            state CriticalAlarm {
                entry assign alarmActive := true;
                entry assign activeMode := SupplyMode::emergency;
            }
            
            transition first NormalOperation;
            
            transition primaryDepleted
                first NormalOperation
                accept at when primaryMonitor.currentPressure < switchoverThreshold
                then SwitchingToSecondary;
            
            transition switchComplete
                first SwitchingToSecondary
                accept at when activeMode == SupplyMode::secondary
                then SecondaryOperation;
            
            transition secondaryDepleted
                first SecondaryOperation
                accept at when secondaryMonitor.currentPressure < switchoverThreshold
                then CriticalAlarm;
            
            transition primaryRestored
                first SecondaryOperation
                accept at when primaryMonitor.currentPressure >= switchoverThreshold
                then NormalOperation;
        }
    }
    
    part def DistributionPipeline {
        attribute pipelinePressure : PressureValue;
        attribute pipelineLength : ISQ::LengthValue;
        
        port mainInlet : GasDeliveryPort;
        port outlets : GasSupplyPort[*];
    }
    
    part def OutletTerminal {
        attribute terminalID : String;
        attribute maxFlowRate : FlowRateValue;
        attribute nominalPressure : PressureValue;
        
        port gasInlet : GasDeliveryPort;
    }
    
    part def AlarmPanel {
        attribute alarmStatus : AlarmLevel;
        
        port primaryAlarmInput : MonitoringPort;
        port secondaryAlarmInput : MonitoringPort;
        port lineAlarmInput : MonitoringPort;
        
        perform action monitorAlarms;
        perform action notifyStaff;
    }
    
    action def MonitorPressure {
        in measuredPressure : PressureValue;
        in threshold : PressureValue;
        out belowThreshold : Boolean;
    }
    
    action def RegulatePressure {
        in targetPressure : PressureValue;
        in sourcePressure : PressureValue;
        out regulatedPressure : PressureValue;
    }
    
    action def DistributeGas {
        in inletPressure : PressureValue;
        in demandFlow : FlowRateValue;
        out deliveryPressure : PressureValue;
    }
    
    action def SupplyMedicalGas {
        in attribute nominalPressure : PressureValue;
        in attribute lowPressureThreshold : PressureValue;
        
        first start;
        then merge continuousSupply;
        
        then action checkPrimary : MonitorPressure {
            in measuredPressure;
            in threshold = lowPressureThreshold;
            out belowThreshold;
        }
        
        then decide;
            if checkPrimary.belowThreshold then switchSource;
            if not checkPrimary.belowThreshold then regulate;
        
        action switchSource {
            then action checkSecondary : MonitorPressure {
                in measuredPressure;
                in threshold = lowPressureThreshold;
                out belowThreshold;
            }
            then decide;
                if checkSecondary.belowThreshold then alarm;
                if not checkSecondary.belowThreshold then regulate;
        }
        
        action regulate : RegulatePressure {
            in targetPressure = nominalPressure;
            in sourcePressure;
            out regulatedPressure;
        }
        
        then action distribute : DistributeGas {
            in inletPressure = regulate.regulatedPressure;
            in demandFlow;
            out deliveryPressure;
        }
        
        then continuousSupply;
        
        action alarm {
            then done;
        }
    }
    
    requirement def SystemGoal;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    requirement def ReliabilityRequirement;
    
    requirement <'SYS-001'> primaryFunction : SystemGoal {
        doc /* The Medical Gas Supply System shall provide continuous, reliable delivery 
             of medical-grade gases at regulated pressure to patient care areas throughout 
             the healthcare facility. */
        
        require performanceReq pressureRegulation;
        require safetyReq automaticSwitchover;
        require safetyReq alarmNotification;
        require reliabilityReq redundantSupply;
    }
    
    requirement <'PERF-001'> pressureRegulation : PerformanceRequirement {
        doc /* The system shall maintain outlet pressure at 345 kPa ± 35 kPa 
             at all terminal units under normal operating conditions. */
        
        subject system : MedicalGasDeliverySystem;
    }
    
    requirement <'SAFE-001'> automaticSwitchover : SafetyRequirement {
        doc /* The system shall automatically switch from primary to secondary gas source 
             when primary source pressure falls below 350 kPa without interruption 
             of gas delivery. */
        
        subject controller : ManifoldController;
    }
    
    requirement <'SAFE-002'> alarmNotification : SafetyRequirement {
        doc /* The system shall activate visual and audible alarms when source pressure 
             falls below critical threshold or when automatic switchover occurs. */
        
        subject alarms : AlarmPanel;
    }
    
    requirement <'REL-001'> redundantSupply : ReliabilityRequirement {
        doc /* The system shall provide redundant gas sources with automatic failover 
             to ensure uninterrupted supply during source depletion or maintenance. */
        
        subject system : MedicalGasDeliverySystem;
    }
    
    part def MedicalGasDeliverySystem;
    
    part medicalGasDeliverySystem : MedicalGasDeliverySystem {
        part primaryOxygenBank : GasCylinderBank {
            attribute :>> bankCapacity = 27200.0 [L];
            attribute :>> currentVolume = 27200.0 [L];
            attribute :>> storagePressure = 13700000.0 [Pa];
            attribute :>> minimumPressure = 350000.0 [Pa];
        }
        
        part secondaryOxygenBank : GasCylinderBank {
            attribute :>> bankCapacity = 27200.0 [L];
            attribute :>> currentVolume = 27200.0 [L];
            attribute :>> storagePressure = 13700000.0 [Pa];
            attribute :>> minimumPressure = 350000.0 [Pa];
        }
        
        part manifoldControl : ManifoldController {
            attribute :>> activeMode = SupplyMode::primary;
            attribute :>> switchoverThreshold = 350000.0 [Pa];
            attribute :>> alarmThreshold = 300000.0 [Pa];
        }
        
        part lineRegulator : PressureRegulator {
            attribute :>> targetPressure = 345000.0 [Pa];
        }
        
        part distributionNetwork : DistributionPipeline {
            attribute :>> pipelinePressure = 345000.0 [Pa];
            attribute :>> pipelineLength = 500.0 [m];
        }
        
        part operatingRoomOutlets : OutletTerminal[8] {
            attribute :>> maxFlowRate = 100.0 [L/min];
            attribute :>> nominalPressure = 345000.0 [Pa];
        }
        
        part icuOutlets : OutletTerminal[12] {
            attribute :>> maxFlowRate = 80.0 [L/min];
            attribute :>> nominalPressure = 345000.0 [Pa];
        }
        
        part emergencyRoomOutlets : OutletTerminal[6] {
            attribute :>> maxFlowRate = 100.0 [L/min];
            attribute :>> nominalPressure = 345000.0 [Pa];
        }
        
        part masterAlarmPanel : AlarmPanel {
            attribute :>> alarmStatus = AlarmLevel::normal;
        }
        
        connect primaryOxygenBank.outlet to manifoldControl.primaryInput;
        connect secondaryOxygenBank.outlet to manifoldControl.secondaryInput;
        connect manifoldControl.regulatedOutput to lineRegulator.inlet;
        connect lineRegulator.outlet to distributionNetwork.mainInlet;
        
        connect distributionNetwork.outlets to operatingRoomOutlets.gasInlet;
        connect distributionNetwork.outlets to icuOutlets.gasInlet;
        connect distributionNetwork.outlets to emergencyRoomOutlets.gasInlet;
        
        connect primaryOxygenBank.monitor to manifoldControl.primaryMonitor;
        connect secondaryOxygenBank.monitor to manifoldControl.secondaryMonitor;
        connect manifoldControl.alarmSignal to masterAlarmPanel.primaryAlarmInput;
        
        perform action continuousGasSupply : SupplyMedicalGas[*] ordered {
            in nominalPressure = 345000.0 [Pa];
            in lowPressureThreshold = 350000.0 [Pa];
        }
        
        satisfy primaryFunction;
        satisfy pressureRegulation;
        satisfy automaticSwitchover;
        satisfy alarmNotification;
        satisfy redundantSupply;
    }
}
