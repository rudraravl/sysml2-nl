package 'Matter Based System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ContaminantLevel :> Real;
    attribute def FlowRate :> Real;
    attribute def ProcessingEfficiency :> Real;
    
    item def RawMatter {
        attribute mass : MassValue;
        attribute volume : VolumeValue;
        attribute contaminantLevel : ContaminantLevel;
        attribute temperature : TemperatureValue;
    }
    
    item def ProcessedMatter :> RawMatter {
        attribute purityLevel : Real;
        attribute processingTimestamp : String;
    }
    
    port def MatterFlowPort {
        in item matterIn : RawMatter;
        out item matterOut : ProcessedMatter;
        attribute flowRate : FlowRate;
    }
    
    port def ControlPort {
        in attribute setPoint : Real;
        out attribute actualValue : Real;
    }
    
    action def InspectMatter {
        in rawMatter : RawMatter;
        out contaminantReading : ContaminantLevel;
        out massReading : MassValue;
    }
    
    action def SeparateContaminants {
        in contaminated : RawMatter;
        in separationEfficiency : ProcessingEfficiency;
        out separated : ProcessedMatter;
        out removedContaminants : MassValue;
    }
    
    action def ConsolidateMatter {
        in purified : ProcessedMatter;
        out consolidated : ProcessedMatter;
    }
    
    action def PurifyMatter {
        in inputMatter : RawMatter;
        in targetPurity : Real;
        out outputMatter : ProcessedMatter;
        
        first start;
        then merge checkCycle;
        
        then action inspect : InspectMatter {
            in rawMatter = inputMatter;
            out contaminantReading;
            out massReading;
        }
        
        then decide;
            if inspect.contaminantReading > targetPurity then separate;
            if inspect.contaminantReading <= targetPurity then consolidate;
        
        action separate : SeparateContaminants {
            in contaminated = inputMatter;
            in separationEfficiency = 0.95;
            out separated;
            out removedContaminants;
        }
        then checkCycle;
        
        action consolidate : ConsolidateMatter {
            in purified = inputMatter;
            out consolidated;
        }
        then assign outputMatter := consolidate.consolidated;
        then done;
    }
    
    part def InspectionUnit {
        port matterInput : MatterFlowPort;
        port controlInterface : ControlPort;
        
        attribute inspectionAccuracy : Real := 0.99;
        
        action performInspection : InspectMatter;
    }
    
    part def SeparationUnit {
        port matterInput : MatterFlowPort;
        port matterOutput : MatterFlowPort;
        port controlInterface : ControlPort;
        
        attribute separationCapacity : MassValue;
        attribute efficiency : ProcessingEfficiency := 0.95;
        
        action performSeparation : SeparateContaminants;
    }
    
    part def ConsolidationUnit {
        port matterInput : MatterFlowPort;
        port matterOutput : MatterFlowPort;
        
        attribute consolidationRate : FlowRate;
        
        action performConsolidation : ConsolidateMatter;
    }
    
    part def StorageVessel {
        port matterInterface : MatterFlowPort;
        
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        
        part storedMatter : ProcessedMatter[0..1];
    }
    
    part def ControlSystem {
        port systemControl : ControlPort;
        
        attribute targetPurityLevel : Real := 95.0;
        attribute operatingMode : String;
        
        action monitorAndControl {
            in sensorData : ContaminantLevel;
            in targetLevel : Real;
            out adjustmentCommand : Real;
        }
    }
    
    part def MatterPurificationSystem {
        doc /* 
            The Matter Purification System processes raw matter containing 
            contaminants to produce purified matter suitable for downstream use.
            Its primary function is to receive raw matter, inspect it for 
            contaminant levels, separate unwanted materials through controlled 
            processing, and consolidate the purified matter for storage and 
            distribution. The system operates continuously, monitoring matter 
            quality and adjusting processing parameters to maintain target 
            purity levels while maximizing throughput efficiency.
        */
        
        attribute systemIdentifier : String;
        attribute nominalThroughput : FlowRate;
        attribute targetPurityLevel : Real := 95.0;
        
        port rawMatterInlet : MatterFlowPort;
        port purifiedMatterOutlet : MatterFlowPort;
        port systemControlInterface : ControlPort;
        
        part inputStorage : StorageVessel {
            attribute capacity = 1000.0 [SI::L];
        }
        
        part inspector : InspectionUnit {
            perform inspectionActivity;
        }
        
        part separator : SeparationUnit {
            attribute separationCapacity = 500.0 [SI::kg];
            perform separationActivity;
        }
        
        part consolidator : ConsolidationUnit {
            attribute consolidationRate = 100.0;
            perform consolidationActivity;
        }
        
        part outputStorage : StorageVessel {
            attribute capacity = 1000.0 [SI::L];
        }
        
        part controller : ControlSystem {
            port redefines systemControl = systemControlInterface;
            perform controlActivity;
        }
        
        connection inputFlow connect rawMatterInlet to inputStorage.matterInterface;
        connection inspectionFlow connect inputStorage.matterInterface to inspector.matterInput;
        connection separationInputFlow connect inspector.matterInput to separator.matterInput;
        connection separationOutputFlow connect separator.matterOutput to consolidator.matterInput;
        connection consolidationFlow connect consolidator.matterOutput to outputStorage.matterInterface;
        connection outputFlow connect outputStorage.matterInterface to purifiedMatterOutlet;
        
        connection inspectorControl connect controller.systemControl to inspector.controlInterface;
        connection separatorControl connect controller.systemControl to separator.controlInterface;
        
        perform action primaryPurificationProcess[*] ordered : PurifyMatter {
            in inputMatter;
            in targetPurity = targetPurityLevel;
            out outputMatter;
            
            perform inspect by inspector;
            perform separate by separator;
            perform consolidate by consolidator;
        }
        
        action inspectionActivity {
            loop {
                action checkMatter;
                then action reportStatus;
            }
        }
        
        action separationActivity {
            first start;
            then loop {
                accept matterBatch;
                then action processBatch;
                then action dischargePurified;
            }
        }
        
        action consolidationActivity {
            loop {
                action collectPurified;
                then action compress;
                then action transfer;
            }
        }
        
        action controlActivity {
            first start;
            then loop {
                action readSensors;
                then action evaluatePerformance;
                then decide;
                    if needsAdjustment then adjust;
                    if optimal then maintain;
                action adjust;
                then merge continue;
                action maintain;
                then continue;
            }
        }
    }
    
    requirement def PurityRequirement {
        doc /* The system shall produce matter with purity level at or above the specified target. */
        
        subject system : MatterPurificationSystem;
        
        require constraint purityConstraint {
            system.primaryPurificationProcess.outputMatter.purityLevel >= 
                system.targetPurityLevel
        }
    }
    
    requirement def ThroughputRequirement {
        doc /* The system shall maintain nominal throughput during continuous operation. */
        
        subject system : MatterPurificationSystem;
        
        require constraint throughputConstraint {
            system.rawMatterInlet.flowRate >= system.nominalThroughput * 0.9
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall operate within safe capacity limits for all vessels and processing units. */
        
        subject system : MatterPurificationSystem;
        
        require constraint storageConstraint {
            system.inputStorage.currentLevel <= system.inputStorage.capacity
        }
        
        require constraint separationConstraint {
            system.separator.separationCapacity > 0.0 [SI::kg]
        }
    }
    
    requirement systemRequirements {
        doc /* Complete set of requirements for the Matter Purification System. */
        
        subject purificationSystem : MatterPurificationSystem;
        
        require purityReq : PurityRequirement {
            subject system = purificationSystem;
        }
        
        require throughputReq : ThroughputRequirement {
            subject system = purificationSystem;
        }
        
        require safetyReq : SafetyRequirement {
            subject system = purificationSystem;
        }
    }
    
    part matterPurificationPlant : MatterPurificationSystem {
        attribute systemIdentifier = "MPP-001";
        attribute nominalThroughput = 150.0;
        attribute targetPurityLevel = 97.5;
    }
}
