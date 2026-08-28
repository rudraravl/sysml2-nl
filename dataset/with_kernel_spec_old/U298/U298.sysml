package 'Medical Gas Supply System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def FlowRateValue :> Real;
    attribute def PurityLevel :> Real;
    attribute def GasLevel :> Real;
    
    item def MedicalGas;
    item def Oxygen :> MedicalGas;
    item def MedicalAir :> MedicalGas;
    item def NitrousOxide :> MedicalGas;
    
    port def GasSourcePort {
        attribute sourcePressure : PressureValue;
        attribute remainingLevel : GasLevel;
        out item gasSupply : MedicalGas;
    }
    
    port def GasIntakePort {
        attribute inletPressure : PressureValue;
        in item gasSupply : MedicalGas;
    }
    
    port def RegulatedGasPort {
        attribute outletPressure : PressureValue;
        attribute outletFlow : FlowRateValue;
        out item regulatedGas : MedicalGas;
    }
    
    port def GasDeliveryPort {
        attribute deliveryPressure : PressureValue;
        attribute purity : PurityLevel;
        in item regulatedGas : MedicalGas;
    }
    
    port def AlarmPort {
        attribute alarmActive : Boolean;
        out item alarmSignal : String;
    }
    
    part def GasCylinderBank {
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : GasLevel;
        attribute bankPressure : PressureValue;
        port sourceOutput : GasSourcePort;
    }
    
    part def SourceManifold {
        attribute activeSource : String;
        port primaryInput : GasIntakePort;
        port reserveInput : GasIntakePort;
        port manifoldOutput : GasSourcePort;
        port alarmOutput : AlarmPort;
    }
    
    part def PressureRegulator {
        attribute setPoint : PressureValue;
        attribute regulationTolerance : PressureValue;
        port regulatorInput : GasIntakePort;
        port regulatorOutput : RegulatedGasPort;
    }
    
    part def QualityMonitor {
        attribute purityThreshold : PurityLevel;
        attribute measuredPurity : PurityLevel;
        port monitorInput : GasDeliveryPort;
        port monitorOutput : RegulatedGasPort;
        port qualityAlarm : AlarmPort;
    }
    
    part def DistributionPipeline {
        attribute linePressure : PressureValue;
        port pipelineInput : GasDeliveryPort;
        port zone1Output : RegulatedGasPort;
        port zone2Output : RegulatedGasPort;
        port zone3Output : RegulatedGasPort;
    }
    
    part def ZoneValveBox {
        attribute valvePosition : Boolean;
        port zoneInput : GasDeliveryPort;
        port zoneOutput : RegulatedGasPort;
    }
    
    part def ClinicalOutlet {
        attribute outletIdentifier : String;
        attribute flowDemand : FlowRateValue;
        port outletInput : GasDeliveryPort;
    }
    
    part def CentralAlarmPanel {
        attribute highPressureLimit : PressureValue;
        attribute lowPressureLimit : PressureValue;
        attribute lowLevelLimit : GasLevel;
        port masterAlarm : AlarmPort;
    }
    
    action def MonitorSourceStatus {
        in primaryLevel : GasLevel;
        in reserveLevel : GasLevel;
        in primaryPressure : PressureValue;
        out usePrimary : Boolean;
        out sourceAvailable : Boolean;
    }
    
    action def SwitchGasSource {
        in targetSource : String;
        out switchComplete : Boolean;
    }
    
    action def RegulateSupplyPressure {
        in rawPressure : PressureValue;
        in targetPressure : PressureValue;
        out controlledPressure : PressureValue;
    }
    
    action def VerifyGasQuality {
        in gasPurity : PurityLevel;
        in purityThreshold : PurityLevel;
        out qualityAcceptable : Boolean;
    }
    
    action def DistributeToZones {
        in supplyPressure : PressureValue;
        in zone1Demand : FlowRateValue;
        in zone2Demand : FlowRateValue;
        in zone3Demand : FlowRateValue;
        out totalFlow : FlowRateValue;
    }
    
    action def TriggerAlarm {
        in alarmType : String;
        in alarmLevel : String;
    }
    
    state def MedicalGasSystemState {
        entry; then normalOperation;
        
        state normalOperation;
        state switching;
        state reserveOperation;
        state criticalAlarm;
        
        transition normalToSwitching
            first normalOperation
            do action SwitchGasSource
            then switching;
            
        transition switchingToReserve
            first switching
            do action TriggerAlarm
            then reserveOperation;
            
        transition reserveToCritical
            first reserveOperation
            do action TriggerAlarm
            then criticalAlarm;
            
        transition criticalToNormal
            first criticalAlarm
            then normalOperation;
    }
    
    action def ManageMedicalGasSupply {
        in primaryLevel : GasLevel;
        in reserveLevel : GasLevel;
        in primaryPressure : PressureValue;
        in targetPressure : PressureValue;
        in purityThreshold : PurityLevel;
        out deliveredPressure : PressureValue;
        
        first start;
        then merge continuousMonitoring;
        
        action checkSource : MonitorSourceStatus {
            in primaryLevel = primaryLevel;
            in reserveLevel = reserveLevel;
            in primaryPressure = primaryPressure;
            out usePrimary;
            out sourceAvailable;
        }
        
        then decide;
            if not checkSource.sourceAvailable then noSourceAlarm;
            if checkSource.sourceAvailable and not checkSource.usePrimary then switchToReserve;
            if checkSource.sourceAvailable and checkSource.usePrimary then regulatePressure;
            
        action switchToReserve : SwitchGasSource {
            in targetSource = "reserve";
            out switchComplete;
        }
        then action announceSwitch : TriggerAlarm {
            in alarmType = "source_switchover";
            in alarmLevel = "warning";
        }
        then regulatePressure;
        
        action regulatePressure : RegulateSupplyPressure {
            in rawPressure = primaryPressure;
            in targetPressure = targetPressure;
            out controlledPressure = deliveredPressure;
        }
        then continuousMonitoring;
        
        action noSourceAlarm : TriggerAlarm {
            in alarmType = "no_gas_source";
            in alarmLevel = "critical";
        }
        then done;
    }
    
    requirement def SystemCapabilityRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    
    requirement <'MGS-REQ-001'> continuousGasDelivery : SystemCapabilityRequirement {
        doc /* The medical gas supply system shall maintain continuous delivery of medical grade gas from available sources to patient care areas. */
    }
    
    requirement <'MGS-REQ-002'> pressureRegulation : PerformanceRequirement {
        doc /* The system shall regulate outlet pressure to remain within specified limits for safe equipment operation. */
    }
    
    requirement <'MGS-REQ-003'> automaticSourceSwitchover : SafetyRequirement {
        doc /* The system shall automatically switch from primary to reserve source when primary source falls below minimum operating level. */
    }
    
    requirement <'MGS-REQ-004'> gasPurityVerification : SafetyRequirement {
        doc /* Medical oxygen purity shall be verified at minimum 99.5 percent before distribution. */
    }
    
    requirement <'MGS-REQ-005'> alarmAnnunciation : SafetyRequirement {
        doc /* The system shall activate alarms for low source level, abnormal pressure, or insufficient gas purity. */
    }
    
    part medicalGasSystem {
        doc /* Primary function: Continuously deliver medical-grade gas from cylinder banks through regulated pressure control and quality monitoring to clinical outlets in patient care zones. */
        
        part primaryBank : GasCylinderBank {
            port :>> sourceOutput {
                out item oxygenPrimary : Oxygen;
            }
        }
        
        part reserveBank : GasCylinderBank {
            port :>> sourceOutput {
                out item oxygenReserve : Oxygen;
            }
        }
        
        part sourceSelector : SourceManifold {
            perform action manage : ManageMedicalGasSupply;
        }
        
        part regulator : PressureRegulator;
        
        part qualityMonitor : QualityMonitor;
        
        part mainPipeline : DistributionPipeline;
        
        part icuZoneValve : ZoneValveBox;
        part orZoneValve : ZoneValveBox;
        part wardZoneValve : ZoneValveBox;
        
        part icuOutlet1 : ClinicalOutlet;
        part icuOutlet2 : ClinicalOutlet;
        part orOutlet1 : ClinicalOutlet;
        part orOutlet2 : ClinicalOutlet;
        part wardOutlet1 : ClinicalOutlet;
        part wardOutlet2 : ClinicalOutlet;
        
        part alarmPanel : CentralAlarmPanel;
        
        connection primarySource connect 
            primaryBank.sourceOutput to sourceSelector.primaryInput;
            
        connection reserveSource connect
            reserveBank.sourceOutput to sourceSelector.reserveInput;
            
        connection manifoldToRegulator connect
            sourceSelector.manifoldOutput to regulator.regulatorInput;
            
        connection regulatorToQuality connect
            regulator.regulatorOutput to qualityMonitor.monitorInput;
            
        connection qualityToPipeline connect
            qualityMonitor.monitorOutput to mainPipeline.pipelineInput;
            
        connection pipelineToIcu connect
            mainPipeline.zone1Output to icuZoneValve.zoneInput;
            
        connection pipelineToOr connect
            mainPipeline.zone2Output to orZoneValve.zoneInput;
            
        connection pipelineToWard connect
            mainPipeline.zone3Output to wardZoneValve.zoneInput;
            
        connection icuToOutlet1 connect
            icuZoneValve.zoneOutput to icuOutlet1.outletInput;
            
        connection icuToOutlet2 connect
            icuZoneValve.zoneOutput to icuOutlet2.outletInput;
            
        connection orToOutlet1 connect
            orZoneValve.zoneOutput to orOutlet1.outletInput;
            
        connection orToOutlet2 connect
            orZoneValve.zoneOutput to orOutlet2.outletInput;
            
        connection wardToOutlet1 connect
            wardZoneValve.zoneOutput to wardOutlet1.outletInput;
            
        connection wardToOutlet2 connect
            wardZoneValve.zoneOutput to wardOutlet2.outletInput;
            
        connection manifoldAlarmLink connect
            sourceSelector.alarmOutput to alarmPanel.masterAlarm;
            
        connection qualityAlarmLink connect
            qualityMonitor.qualityAlarm to alarmPanel.masterAlarm;
            
        exhibit state operationalState : MedicalGasSystemState;
    }
}
