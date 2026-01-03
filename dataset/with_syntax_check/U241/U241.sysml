package 'Hindustan Syringes Medical System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SterilityLevel;
    attribute def SafetyStatus;
    attribute def DosageAccuracy;
    
    item def Medication {
        attribute volume : ISQ::VolumeValue;
        attribute concentration : Real;
        attribute name : String;
    }
    
    item def SyringeBarrel {
        attribute capacity : ISQ::VolumeValue;
        attribute material : String;
        attribute isSterile : Boolean;
    }
    
    item def Plunger {
        attribute position : ISQ::LengthValue;
        attribute sealIntegrity : Boolean;
    }
    
    item def Needle {
        attribute gauge : Real;
        attribute length : ISQ::LengthValue;
        attribute isSharp : Boolean;
    }
    
    item def AssembledSyringe {
        attribute totalCapacity : ISQ::VolumeValue;
        attribute currentVolume : ISQ::VolumeValue;
        attribute isSterile : Boolean;
    }
    
    item def AutoDisableSyringe :> AssembledSyringe {
        attribute isUsed : Boolean;
        attribute lockEngaged : Boolean;
        attribute canReuse : Boolean;
    }
    
    item def PackagedSyringe {
        attribute packageIntegrity : Boolean;
        attribute expirationDate : String;
    }
    
    port def MedicationInputPort {
        in item medication : Medication;
    }
    
    port def MedicationOutputPort {
        out item deliveredMedication : Medication;
    }
    
    port def ComponentInputPort {
        in item component : SyringeBarrel;
    }
    
    port def SyringeOutputPort {
        out item syringe : AssembledSyringe;
    }
    
    part def MoldingStation {
        attribute moldTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute cycleTime : ISQ::TimeValue;
        out item barrelOutput : SyringeBarrel[*];
        out item plungerOutput : Plunger[*];
    }
    
    part def AssemblyStation {
        in item barrelInput : SyringeBarrel[*];
        in item plungerInput : Plunger[*];
        in item needleInput : Needle[*];
        out item assembledOutput : AssembledSyringe[*];
        port assemblyPort : SyringeOutputPort;
    }
    
    part def SterilizationChamber {
        attribute method : String;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute duration : ISQ::TimeValue;
        attribute validationStatus : Boolean;
        in item unsterilizedInput : AssembledSyringe[*];
        out item sterilizedOutput : AssembledSyringe[*];
    }
    
    part def PackagingStation {
        attribute sealingPressure : ISQ::PressureValue;
        attribute packagingMaterial : String;
        in item sterilizedInput : AssembledSyringe[*];
        out item packagedOutput : PackagedSyringe[*];
    }
    
    part def QualityInspectionUnit {
        attribute inspectionCriteria : String[*];
        attribute rejectionRate : Real;
        in item inspectionInput : PackagedSyringe[*];
        out item approvedOutput : PackagedSyringe[*];
        out item rejectedOutput : PackagedSyringe[*];
    }
    
    part def AutoDisableMechanism {
        attribute lockingForce : ISQ::ForceValue;
        attribute activationThreshold : ISQ::VolumeValue;
        attribute isEngaged : Boolean;
    }
    
    action def MoldComponents {
        in moldTemp : ISQ::ThermodynamicTemperatureValue;
        in cycleTime : ISQ::TimeValue;
        out barrel : SyringeBarrel;
        out plunger : Plunger;
    }
    
    action def AssembleSyringe {
        in barrel : SyringeBarrel;
        in plunger : Plunger;
        in needle : Needle;
        out assembled : AssembledSyringe;
    }
    
    action def SterilizeProduct {
        in unsterilized : AssembledSyringe;
        in temperature : ISQ::ThermodynamicTemperatureValue;
        in duration : ISQ::TimeValue;
        out sterilized : AssembledSyringe;
    }
    
    action def PackageProduct {
        in sterilized : AssembledSyringe;
        in sealPressure : ISQ::PressureValue;
        out packaged : PackagedSyringe;
    }
    
    action def InspectQuality {
        in product : PackagedSyringe;
        out approved : PackagedSyringe;
        out isAccepted : Boolean;
    }
    
    action def LoadMedication {
        in syringe : AutoDisableSyringe;
        in medication : Medication;
        in targetVolume : ISQ::VolumeValue;
        out loadedSyringe : AutoDisableSyringe;
    }
    
    action def DeliverDose {
        in loadedSyringe : AutoDisableSyringe;
        in targetDosage : ISQ::VolumeValue;
        in deliveryRate : Real;
        out administeredMedication : Medication;
        out usedSyringe : AutoDisableSyringe;
    }
    
    action def EngageAutoDisable {
        in syringe : AutoDisableSyringe;
        out lockedSyringe : AutoDisableSyringe;
    }
    
    action def ManufactureSyringes {
        in batchSize : Integer;
        in moldingTemp : ISQ::ThermodynamicTemperatureValue;
        in sterilizationTemp : ISQ::ThermodynamicTemperatureValue;
        in sterilizationTime : ISQ::TimeValue;
        out finishedProducts : PackagedSyringe[*];
        
        first start;
        then merge beginProduction;
        
        then action moldingPhase : MoldComponents {
            in moldTemp = moldingTemp;
            in cycleTime;
            out barrel;
            out plunger;
        }
        
        then action assemblyPhase : AssembleSyringe {
            in barrel = moldingPhase.barrel;
            in plunger = moldingPhase.plunger;
            in needle;
            out assembled;
        }
        
        then action sterilizationPhase : SterilizeProduct {
            in unsterilized = assemblyPhase.assembled;
            in temperature = sterilizationTemp;
            in duration = sterilizationTime;
            out sterilized;
        }
        
        then action packagingPhase : PackageProduct {
            in sterilized = sterilizationPhase.sterilized;
            in sealPressure;
            out packaged;
        }
        
        then action inspectionPhase : InspectQuality {
            in product = packagingPhase.packaged;
            out approved;
            out isAccepted;
        }
        
        then decide;
            if inspectionPhase.isAccepted == true then acceptProduct;
            if inspectionPhase.isAccepted == false then rejectProduct;
        
        action acceptProduct;
        then beginProduction;
        
        action rejectProduct;
        then beginProduction;
    }
    
    action def SafeMedicationAdministration {
        in medication : Medication;
        in prescribedDosage : ISQ::VolumeValue;
        in syringe : AutoDisableSyringe;
        out deliveryComplete : Boolean;
        out finalSyringe : AutoDisableSyringe;
        
        first start;
        then merge prepareDelivery;
        
        then action verifyIntegrity {
            out integrityCheck : Boolean;
        }
        
        then decide;
            if verifyIntegrity.integrityCheck == true then proceedWithLoading;
            if verifyIntegrity.integrityCheck == false then abortProcedure;
        
        action proceedWithLoading;
        then action loadMed : LoadMedication {
            in syringe = SafeMedicationAdministration::syringe;
            in medication = SafeMedicationAdministration::medication;
            in targetVolume = SafeMedicationAdministration::prescribedDosage;
            out loadedSyringe;
        }
        
        then action deliverMed : DeliverDose {
            in loadedSyringe = loadMed.loadedSyringe;
            in targetDosage = SafeMedicationAdministration::prescribedDosage;
            in deliveryRate;
            out administeredMedication;
            out usedSyringe;
        }
        
        then action lockSyringe : EngageAutoDisable {
            in syringe = deliverMed.usedSyringe;
            out lockedSyringe;
        }
        
        then assign finalSyringe := lockSyringe.lockedSyringe;
        then assign deliveryComplete := true;
        then done;
        
        action abortProcedure {
            then assign deliveryComplete := false;
        }
        then done;
    }
    
    attribute def PackagingCompleteEvent;
    attribute def QualityApprovedEvent;
    attribute def MedicationLoadedEvent;
    attribute def DeliveryStartedEvent;
    attribute def DeliveryCompleteEvent;
    attribute def DisposalEvent;
    
    state def SyringeLifecycleStates {
        in attribute syringeRef : AutoDisableSyringe;
        
        entry; then manufactured;
        
        state manufactured;
        transition manufactured_to_packaged
            first manufactured
            accept PackagingCompleteEvent
            then packaged;
        
        state packaged;
        transition packaged_to_ready
            first packaged
            accept QualityApprovedEvent
            then readyForUse;
        
        state readyForUse;
        transition ready_to_loaded
            first readyForUse
            accept MedicationLoadedEvent
            then loaded;
        
        state loaded;
        transition loaded_to_delivering
            first loaded
            accept DeliveryStartedEvent
            then delivering;
        
        state delivering {
            do action deliverDose : DeliverDose;
        }
        transition delivering_to_used
            first delivering
            accept DeliveryCompleteEvent
            then used;
        
        state used;
        transition used_to_disposed
            first used
            accept DisposalEvent
            then disposed;
        
        state disposed;
    }
    
    requirement def <'REQ-HSMD-001'> PrimaryFunctionRequirement {
        doc /* The Hindustan Syringes system shall manufacture sterile, single-use auto-disable syringes 
               that safely deliver precise medication dosages while preventing reuse and cross-contamination. */
    }
    
    requirement def <'REQ-HSMD-002'> SterilityRequirement {
        doc /* All manufactured syringes shall achieve and maintain sterility assurance level (SAL) of 10^-6 
               through validated sterilization processes. */
        
        subject sterilizationChamber : SterilizationChamber;
        
        require constraint {
            sterilizationChamber.validationStatus == true
        }
    }
    
    requirement def <'REQ-HSMD-003'> DosageAccuracyRequirement {
        doc /* Medication delivery shall be accurate within ±5% of the prescribed dosage volume. */
    }
    
    requirement def <'REQ-HSMD-004'> AutoDisableRequirement {
        doc /* The auto-disable mechanism shall engage immediately after single use to prevent reuse 
               and ensure patient safety. */
    }
    
    requirement def <'REQ-HSMD-005'> PackageIntegrityRequirement {
        doc /* Packaged syringes shall maintain sterile barrier integrity until point of use. */
    }
    
    requirement <'SYS-HSMD-001'> systemMissionRequirement : PrimaryFunctionRequirement {
        doc /* The Hindustan Syringes & Medical Devices system shall provide safe, sterile, 
               and reliable single-use syringes for global healthcare delivery. */
        
        require sterilityReq : SterilityRequirement;
        require accuracyReq : DosageAccuracyRequirement;
        require autoDisableReq : AutoDisableRequirement;
        require packageReq : PackageIntegrityRequirement;
    }
    
    part hindustandSyringesManufacturingSystem {
        doc /* Complete manufacturing system for producing auto-disable syringes with integrated 
               quality control and sterilization processes. */
        
        part moldingUnit : MoldingStation {
            attribute moldTemperature = 200.0;
            attribute cycleTime = 30.0;
        }
        
        part assemblyUnit : AssemblyStation;
        
        part sterilizationUnit : SterilizationChamber {
            attribute method = "EthyleneOxide";
            attribute temperature = 55.0;
            attribute duration = 720.0;
            attribute validationStatus = true;
        }
        
        part packagingUnit : PackagingStation {
            attribute sealingPressure = 200.0;
            attribute packagingMaterial = "MedicalGradePlastic";
        }
        
        part qualityUnit : QualityInspectionUnit {
            attribute inspectionCriteria = ("SterilityCheck", "DimensionalAccuracy", "PackageIntegrity");
            attribute rejectionRate = 0.02;
        }
        
        part autoDisableDevice : AutoDisableMechanism {
            attribute lockingForce = 50.0;
            attribute activationThreshold = 0.1;
            attribute isEngaged = false;
        }
        
        item flow barrels from moldingUnit.barrelOutput to assemblyUnit.barrelInput;
        item flow plungers from moldingUnit.plungerOutput to assemblyUnit.plungerInput;
        item flow assembled from assemblyUnit.assembledOutput to sterilizationUnit.unsterilizedInput;
        item flow sterilized from sterilizationUnit.sterilizedOutput to packagingUnit.sterilizedInput;
        item flow packaged from packagingUnit.packagedOutput to qualityUnit.inspectionInput;
        
        perform action production[*] ordered references ManufactureSyringes;
        
        satisfy systemMissionRequirement;
    }
    
    part autoDisableSyringeProduct : AutoDisableSyringe {
        attribute totalCapacity = 5.0;
        attribute currentVolume = 0.0;
        attribute isSterile = true;
        attribute isUsed = false;
        attribute lockEngaged = false;
        attribute canReuse = false;
        
        part syringeBarrel : SyringeBarrel {
            attribute capacity = 5.0;
            attribute material = "MedicalGradePolypropylene";
            attribute isSterile = true;
        }
        
        part syringePlunger : Plunger {
            attribute position = 0.0;
            attribute sealIntegrity = true;
        }
        
        part syringeNeedle : Needle {
            attribute gauge = 23.0;
            attribute length = 25.0;
            attribute isSharp = true;
        }
        
        part lockingMechanism : AutoDisableMechanism {
            attribute lockingForce = 50.0;
            attribute activationThreshold = 0.1;
            attribute isEngaged = false;
        }
        
        port medicationInput : MedicationInputPort;
        port deliveryOutput : MedicationOutputPort;
        
        connection barrelToPlunger connect syringeBarrel to syringePlunger;
        connection barrelToNeedle connect syringeBarrel to syringeNeedle;
        
        perform action administrationProcess : SafeMedicationAdministration {
            in medication;
            in prescribedDosage;
            in syringe;
            out deliveryComplete;
            out finalSyringe;
        }
        
        exhibit state lifecycle : SyringeLifecycleStates {
            in syringeRef = autoDisableSyringeProduct;
        }
        
        satisfy systemMissionRequirement;
    }
}
