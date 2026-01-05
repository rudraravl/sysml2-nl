package 'Sewage Treatment System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WaterQualityMetric;
    attribute def TreatmentStageIndicator;
    attribute def OperationalCommand;
    
    attribute def StartupCommand;
    attribute def SystemsReady;
    attribute def MaintenanceRequired;
    attribute def MaintenanceComplete;
    attribute def ShutdownCommand;
    attribute def ShutdownComplete;
    
    value def WaterQuality {
        attribute biochemicalOxygenDemand : Real;
        attribute totalSuspendedSolids : Real;
        attribute nitrogenContent : Real;
        attribute phosphorusContent : Real;
        attribute pathogenLevel : Real;
        attribute pH : Real;
    }
    
    item def RawSewage {
        attribute volumeFlowRate : VolumeFlowRateValue;
        attribute quality : WaterQuality;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    item def PrimaryEffluent {
        attribute volumeFlowRate : VolumeFlowRateValue;
        attribute quality : WaterQuality;
    }
    
    item def SecondaryEffluent {
        attribute volumeFlowRate : VolumeFlowRateValue;
        attribute quality : WaterQuality;
    }
    
    item def TreatedEffluent {
        attribute volumeFlowRate : VolumeFlowRateValue;
        attribute quality : WaterQuality;
        attribute dischargeCompliant : Boolean;
    }
    
    item def PrimarySludge {
        attribute mass : MassValue;
        attribute solidsContent : Real;
    }
    
    item def ActivatedSludge {
        attribute mass : MassValue;
        attribute solidsContent : Real;
        attribute microorganismConcentration : Real;
    }
    
    item def DigestedSludge {
        attribute mass : MassValue;
        attribute solidsContent : Real;
        attribute stabilized : Boolean;
    }
    
    port def SewageInletPort {
        in item influent : RawSewage;
    }
    
    port def SewageTransferPort {
        out item effluent : RawSewage;
    }
    
    port def PrimaryEffluentPort {
        out item effluent : PrimaryEffluent;
    }
    
    port def SecondaryEffluentPort {
        out item effluent : SecondaryEffluent;
    }
    
    port def TreatedWaterPort {
        out item effluent : TreatedEffluent;
    }
    
    port def SludgePort {
        out item sludge : PrimarySludge;
    }
    
    port def ActivatedSludgePort {
        in item returnSludge : ActivatedSludge;
        out item wasteSludge : ActivatedSludge;
    }
    
    action def PerformScreening {
        in rawInfluent : RawSewage;
        out screenedSewage : RawSewage;
    }
    
    action def PerformGritRemoval {
        in screenedSewage : RawSewage;
        out degrittedSewage : RawSewage;
    }
    
    action def PerformPrimarySettling {
        in degrittedSewage : RawSewage;
        out primaryEffluent : PrimaryEffluent;
        out primarySludge : PrimarySludge;
    }
    
    action def PerformBiologicalTreatment {
        in primaryEffluent : PrimaryEffluent;
        in returnSludge : ActivatedSludge;
        out biologicallyTreated : SecondaryEffluent;
    }
    
    action def PerformSecondarySettling {
        in biologicallyTreated : SecondaryEffluent;
        out clarifiedEffluent : SecondaryEffluent;
        out wasteSludge : ActivatedSludge;
        out returnSludge : ActivatedSludge;
    }
    
    action def PerformDisinfection {
        in clarifiedEffluent : SecondaryEffluent;
        out disinfectedEffluent : TreatedEffluent;
    }
    
    action def PerformSludgeDigestion {
        in primarySludge : PrimarySludge;
        in wasteSludge : ActivatedSludge;
        out digestedSludge : DigestedSludge;
    }
    
    action def TreatWastewater {
        in rawSewageInput : RawSewage;
        out treatedWaterOutput : TreatedEffluent;
        out processedSludgeOutput : DigestedSludge;
        
        first start;
        then action screening : PerformScreening {
            in rawInfluent = rawSewageInput;
            out screenedSewage;
        }
        then action gritRemoval : PerformGritRemoval {
            in screenedSewage = screening.screenedSewage;
            out degrittedSewage;
        }
        then action primarySettling : PerformPrimarySettling {
            in degrittedSewage = gritRemoval.degrittedSewage;
            out primaryEffluent;
            out primarySludge;
        }
        then action biologicalTreatment : PerformBiologicalTreatment {
            in primaryEffluent = primarySettling.primaryEffluent;
            in returnSludge;
            out biologicallyTreated;
        }
        then action secondarySettling : PerformSecondarySettling {
            in biologicallyTreated = biologicalTreatment.biologicallyTreated;
            out clarifiedEffluent;
            out wasteSludge;
            out returnSludge;
        }
        flow secondarySettling.returnSludge to biologicalTreatment.returnSludge;
        then action disinfection : PerformDisinfection {
            in clarifiedEffluent = secondarySettling.clarifiedEffluent;
            out disinfectedEffluent;
        }
        then merge treatmentComplete;
        
        action sludgeDigestion : PerformSludgeDigestion {
            in primarySludge = primarySettling.primarySludge;
            in wasteSludge = secondarySettling.wasteSludge;
            out digestedSludge;
        }
        then treatmentComplete;
        
        then assign treatedWaterOutput := disinfection.disinfectedEffluent;
        then assign processedSludgeOutput := sludgeDigestion.digestedSludge;
        then done;
    }
    
    state def TreatmentPlantOperationalState {
        entry; then offline;
        
        state offline;
        transition offline_to_startup
            first offline
            accept StartupCommand
            then startup;
            
        state startup {
            entry; then initializingSystems;
            state initializingSystems;
            transition initializing_to_warmup
                first initializingSystems
                then warmup;
            state warmup;
        }
        
        transition startup_to_operational
            first startup
            accept SystemsReady
            then operational;
            
        state operational {
            entry; then normalOperation;
            
            state normalOperation {
                entry; then receiving;
                state receiving;
                transition receiving_to_primaryTreatment
                    first receiving
                    then primaryTreatment;
                state primaryTreatment;
                transition primary_to_secondaryTreatment
                    first primaryTreatment
                    then secondaryTreatment;
                state secondaryTreatment;
                transition secondary_to_finalDisinfection
                    first secondaryTreatment
                    then finalDisinfection;
                state finalDisinfection;
                transition final_to_discharge
                    first finalDisinfection
                    then discharging;
                state discharging;
                transition discharge_to_receiving
                    first discharging
                    then receiving;
            }
            
            state maintenance;
            transition normal_to_maintenance
                first normalOperation
                accept MaintenanceRequired
                then maintenance;
            transition maintenance_to_normal
                first maintenance
                accept MaintenanceComplete
                then normalOperation;
        }
        
        transition operational_to_shutdown
            first operational
            accept ShutdownCommand
            then shutdown;
            
        state shutdown;
        transition shutdown_to_offline
            first shutdown
            accept ShutdownComplete
            then offline;
    }
    
    part def ScreeningUnit {
        port inlet : SewageInletPort;
        port outlet : SewageTransferPort;
        attribute barSpacing : LengthValue;
        
        perform action screeningOperation : PerformScreening;
    }
    
    part def GritChamber {
        port inlet : SewageInletPort;
        port outlet : SewageTransferPort;
        attribute retentionTime : TimeValue;
        
        perform action gritRemovalOperation : PerformGritRemoval;
    }
    
    part def PrimaryClarifier {
        port inlet : SewageInletPort;
        port effluentOutlet : PrimaryEffluentPort;
        port sludgeOutlet : SludgePort;
        attribute surfaceArea : AreaValue;
        attribute depth : LengthValue;
        
        perform action primarySettlingOperation : PerformPrimarySettling;
    }
    
    part def AerationBasin {
        port inlet : PrimaryEffluentPort;
        port sludgeReturn : ActivatedSludgePort;
        port outlet : SecondaryEffluentPort;
        attribute volume : VolumeValue;
        attribute airFlowRate : VolumeFlowRateValue;
        attribute dissolvedOxygenSetpoint : Real;
        
        perform action biologicalTreatmentOperation : PerformBiologicalTreatment;
    }
    
    part def SecondaryClarifier {
        port inlet : SecondaryEffluentPort;
        port effluentOutlet : SecondaryEffluentPort;
        port sludgeReturn : ActivatedSludgePort;
        port sludgeWaste : ActivatedSludgePort;
        attribute surfaceArea : AreaValue;
        
        perform action secondarySettlingOperation : PerformSecondarySettling;
    }
    
    part def DisinfectionChamber {
        port inlet : SecondaryEffluentPort;
        port outlet : TreatedWaterPort;
        attribute contactTime : TimeValue;
        attribute chlorineDosage : MassValue;
        
        perform action disinfectionOperation : PerformDisinfection;
    }
    
    part def AnaerobicDigester {
        port primarySludgeInlet : SludgePort;
        port wasteSludgeInlet : ActivatedSludgePort;
        port digestedSludgeOutlet : SludgePort;
        attribute volume : VolumeValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute retentionTime : TimeValue;
        
        perform action digestionOperation : PerformSludgeDigestion;
    }
    
    part def SewageTreatmentPlant {
        attribute designCapacity : VolumeFlowRateValue;
        attribute currentFlowRate : VolumeFlowRateValue;
        attribute operationalEfficiency : Real;
        
        port plantInlet : SewageInletPort;
        port treatedWaterDischarge : TreatedWaterPort;
        port sludgeDisposal : SludgePort;
        
        part screeningUnit : ScreeningUnit {
            perform treatmentProcess.screening;
        }
        
        part gritChamber : GritChamber {
            perform treatmentProcess.gritRemoval;
        }
        
        part primaryClarifier : PrimaryClarifier {
            perform treatmentProcess.primarySettling;
        }
        
        part aerationBasin : AerationBasin {
            perform treatmentProcess.biologicalTreatment;
        }
        
        part secondaryClarifier : SecondaryClarifier {
            perform treatmentProcess.secondarySettling;
        }
        
        part disinfectionChamber : DisinfectionChamber {
            perform treatmentProcess.disinfection;
        }
        
        part anaerobicDigester : AnaerobicDigester {
            perform treatmentProcess.sludgeDigestion;
        }
        
        connect plantInlet to screeningUnit.inlet;
        connect screeningUnit.outlet to gritChamber.inlet;
        connect gritChamber.outlet to primaryClarifier.inlet;
        connect primaryClarifier.effluentOutlet to aerationBasin.inlet;
        connect aerationBasin.outlet to secondaryClarifier.inlet;
        connect secondaryClarifier.effluentOutlet to disinfectionChamber.inlet;
        connect disinfectionChamber.outlet to treatedWaterDischarge;
        connect primaryClarifier.sludgeOutlet to anaerobicDigester.primarySludgeInlet;
        connect secondaryClarifier.sludgeWaste to anaerobicDigester.wasteSludgeInlet;
        connect secondaryClarifier.sludgeReturn to aerationBasin.sludgeReturn;
        connect anaerobicDigester.digestedSludgeOutlet to sludgeDisposal;
        
        perform action treatmentProcess : TreatWastewater;
        
        exhibit state plantState : TreatmentPlantOperationalState;
    }
    
    requirement def EffluentQualityStandard {
        doc /* Treated effluent must meet regulatory discharge standards for water quality parameters. */
        
        subject treatedWater : TreatedEffluent;
        
        require constraint bodLimit {
            treatedWater.quality.biochemicalOxygenDemand <= 30.0
        }
        
        require constraint tssLimit {
            treatedWater.quality.totalSuspendedSolids <= 30.0
        }
        
        require constraint nitrogenLimit {
            treatedWater.quality.nitrogenContent <= 15.0
        }
        
        require constraint phosphorusLimit {
            treatedWater.quality.phosphorusContent <= 2.0
        }
        
        require constraint pathogenLimit {
            treatedWater.quality.pathogenLevel <= 1000.0
        }
        
        require constraint pHRange {
            treatedWater.quality.pH >= 6.0 and treatedWater.quality.pH <= 9.0
        }
    }
    
    requirement def HydraulicCapacityRequirement {
        doc /* The treatment plant must process wastewater at or above design capacity under normal conditions. */
        
        subject plant : SewageTreatmentPlant;
        
        require constraint capacityMaintenance {
            plant.currentFlowRate >= plant.designCapacity * 0.95
        }
    }
    
    requirement def SludgeStabilizationRequirement {
        doc /* Digested sludge must be stabilized to reduce pathogens and odors before disposal. */
        
        subject sludge : DigestedSludge;
        
        require constraint stabilizationAchieved {
            sludge.stabilized == true
        }
        
        require constraint solidsReduction {
            sludge.solidsContent >= 0.20
        }
    }
    
    requirement def OperationalReliabilityRequirement {
        doc /* The treatment plant must maintain high operational reliability to ensure continuous service. */
        
        subject plant : SewageTreatmentPlant;
        
        require constraint efficiencyTarget {
            plant.operationalEfficiency >= 0.95
        }
    }
    
    requirement primarySystemRequirement {
        doc /* The sewage treatment system shall remove contaminants from wastewater to protect public health and environmental water quality through multi-stage treatment processes. */
        
        subject system : SewageTreatmentPlant;
        
        require requirement effluentQualityReq : EffluentQualityStandard;
        require requirement hydraulicCapacityReq : HydraulicCapacityRequirement;
        require requirement sludgeStabilizationReq : SludgeStabilizationRequirement;
        require requirement operationalReliabilityReq : OperationalReliabilityRequirement;
    }
}
