package AutoDisableSyringeEcosystem {

    // =========================================================================
    // Value Types
    // =========================================================================
    value type Temperature :> Real;
    value type Pressure :> Real;
    value type Volume :> Real;
    value type Force :> Real;
    value type Mass :> Real;
    value type Length :> Real;
    value type Duration :> Real;
    value type Dose :> Real;
    value type Concentration :> Real;
    value type FlowRate :> Real;
    value type Diameter :> Real;
    value type CycleCount :> Integer;
    value type StrokesPerMinute :> Real;
    value type Percent :> Real;
    value type HumidityLevel :> Real;

    // =========================================================================
    // Enumerations
    // =========================================================================
    enum SyringeOperationalState {
        empty,
        filled,
        primed,
        dispensing,
        autoDisabled,
        disposed
    }

    enum SterilityState {
        contaminated,
        sterile,
        breached
    }

    enum QualityState {
        pending,
        pass,
        fail,
        rejected
    }

    enum ProductionStatus {
        idle,
        running,
        maintenance,
        faulted
    }

    enum DisposalMethod {
        biohazardSharpsContainer,
        medicalWaste,
        incineration
    }

    // =========================================================================
    // Item Definitions
    // =========================================================================
    item def PolypropylenePellets {
        attribute mass : Mass;
        attribute meltTemperature : Temperature;
        attribute materialGrade : String;
        attribute color : String;
    }

    item def SterileNeedleStock {
        attribute length : Length;
        attribute gauge : Integer;
        attribute material : String;
        attribute bevelAngle : Real;
        attribute sterile : Boolean;
    }

    item def EthyleneOxideGas {
        attribute concentration : Concentration;
        attribute exposureTemperature : Temperature;
        attribute exposureDuration : Duration;
        attribute humidityRequired : HumidityLevel;
    }

    item def PackagingMaterial {
        attribute materialType : String;
        attribute isSterileBarrier : Boolean;
        attribute hasTamperSeal : Boolean;
        attribute shelfLifeMonths : Integer;
    }

    item def Medication {
        attribute name : String;
        attribute volume : Dose;
        attribute viscosity : Real;
    }

    item def BiohazardWaste {
        attribute disposalMethod : DisposalMethod;
        attribute containsSharps : Boolean;
    }

    item def MoldedBarrel {
        attribute volumeCapacity : Volume;
        attribute innerDiameter : Diameter;
        attribute barrelLength : Length;
        attribute material : String;
        attribute isSterile : Boolean;
    }

    item def MoldedPlunger {
        attribute length : Length;
        attribute diameter : Diameter;
        attribute material : String;
        attribute strokeDistance : Length;
    }

    item def AssembledSyringe {
        attribute isComplete : Boolean;
        attribute isSterile : Boolean;
        attribute hasNeedleCover : Boolean;
    }

    item def PackagedSyringe {
        attribute hasSterileSeal : Boolean;
        attribute isDefective : Boolean;
        attribute lotNumber : String;
        attribute expirationDate : String;
    }

    item def RejectedProduct {
        attribute rejectionReason : String;
        attribute originalLot : String;
    }

    // =========================================================================
    // Port Definitions
    // =========================================================================
    port def PelletsFlow {
        in item pellets : PolypropylenePellets;
    }

    port def MoldingOutputFlow {
        out item moldedBarrel : MoldedBarrel;
        out item moldedPlunger : MoldedPlunger;
    }

    port def AssemblyInputFlow {
        in item moldedBarrel : MoldedBarrel;
        in item moldedPlunger : MoldedPlunger;
        in item needleStock : SterileNeedleStock;
    }

    port def AssemblyOutputFlow {
        out item assembledSyringe : AssembledSyringe;
    }

    port def SterilizationInputFlow {
        in item assembledSyringe : AssembledSyringe;
        in item eoGas : EthyleneOxideGas;
    }

    port def SterilizationOutputFlow {
        out item sterileSyringe : AssembledSyringe;
    }

    port def PackagingInputFlow {
        in item sterileSyringe : AssembledSyringe;
        in item packagingMaterial : PackagingMaterial;
    }

    port def PackagingOutputFlow {
        out item packagedSyringe : PackagedSyringe;
    }

    port def InspectionInputFlow {
        in item packagedSyringe : PackagedSyringe;
    }

    port def InspectionAcceptedOutputFlow {
        out item acceptedProduct : PackagedSyringe;
    }

    port def InspectionRejectedOutputFlow {
        out item rejectedProduct : RejectedProduct;
    }

    port def MedicationFlow {
        in item medication : Medication;
    }

    port def DispensedFlow {
        out item dispensed : Medication;
    }

    port def WasteFlow {
        out item waste : BiohazardWaste;
    }

    // =========================================================================
    // Syringe Component Part Definitions
    // =========================================================================
    part def Barrel {
        attribute volumeCapacity : Volume;
        attribute innerDiameter : Diameter;
        attribute barrelLength : Length;
        attribute material : String;
        attribute isSterile : Boolean;
        attribute wallThickness : Length;

        port in medicationIn : MedicationFlow;
        port out medicationOut : DispensedFlow;
    }

    part def Plunger {
        attribute length : Length;
        attribute diameter : Diameter;
        attribute material : String;
        attribute position : Real;
        attribute isLocked : Boolean;
        attribute strokeDistance : Length;
        attribute sealIntegrity : Boolean;
    }

    part def Needle {
        attribute length : Length;
        attribute gauge : Integer;
        attribute bevelAngle : Real;
        attribute sterile : Boolean;
        attribute isAttached : Boolean;
        attribute hasSafetyCover : Boolean;
    }

    part def AutoDisableMechanism {
        attribute isEngaged : Boolean;
        attribute activationForce : Force;
        attribute lockPosition : Real;
        attribute singleUseCount : CycleCount;
        attribute mechanismType : String;

        action engage {
            doc /* Permanently lock the plunger after a single full-dose dispense, making the syringe physically impossible to reuse. */;
            in currentStroke : Real;
            out lockEngaged : Boolean;
        }

        state machine AutoDisableStates {
            state Ready;
            state Monitoring;
            state Engaged;
            state PermanentlyLocked;

            initial;
            transition initial to Ready;

            transition Ready to Monitoring
                when plungerStrokeStarts;

            transition Monitoring to Engaged
                when currentStroke >= fullStrokeDistance;

            transition Engaged to PermanentlyLocked;

            transition PermanentlyLocked to PermanentlyLocked;
        }
    }

    // =========================================================================
    // AutoDisableSyringe Part Definition
    // =========================================================================
    part def AutoDisableSyringe {
        attribute state : SyringeOperationalState;
        attribute sterility : SterilityState;
        attribute quality : QualityState;
        attribute hasBeenUsed : Boolean;
        attribute doseVolume : Dose;
        attribute maximumDose : Dose;
        attribute lotNumber : String;

        part barrel : Barrel;
        part plunger : Plunger;
        part needle : Needle;
        part autoDisable : AutoDisableMechanism;

        port in medicationIn : MedicationFlow;
        port out medicationOut : DispensedFlow;
        port out wasteOut : WasteFlow;

        state machine SyringeLifecycle {
            state Empty;
            state Filled;
            state Primed;
            state Dispensing;
            state AutoDisabled;
            state Disposed;

            initial;
            transition initial to Empty;

            transition Empty to Filled
                when medicationReceived;

            transition Filled to Primed
                when needleAttachedAndAirPurged;

            transition Primed to Dispensing
                when actuationApplied;

            transition Dispensing to AutoDisabled
                when autoDisable.isEngaged == true;

            transition AutoDisabled to Disposed
                when placedInBiohazardContainer;
        }

        action fillSyringe {
            in medication : Medication;
            doc /* Draw medication into the barrel up to the maximum dose volume. */;
        }

        action dispenseDose {
            in dose : Medication;
            out dispensed : Medication;
            doc /* Dispense the full dose of medication through the needle, then engage the auto-disable mechanism. */;
        }

        action disposeSyringe {
            out waste : BiohazardWaste;
            doc /* Place the auto-disabled syringe in a biohazard sharps container. */;
        }
    }

    // =========================================================================
    // Manufacturing Station Definitions
    // =========================================================================
    part def MoldingStation {
        attribute stationStatus : ProductionStatus;
        attribute barrelMoldTemperature : Temperature;
        attribute plungerMoldTemperature : Temperature;
        attribute injectionPressure : Pressure;
        attribute cycleTime : Duration;
        attribute throughputRate : StrokesPerMinute;
        attribute moldCavityCount : Integer;

        port in rawMaterial : PelletsFlow;
        port out moldedComponents : MoldingOutputFlow;

        action moldComponents {
            in pellets : PolypropylenePellets;
            out barrel : MoldedBarrel;
            out plunger : MoldedPlunger;
            doc /* Injection mold the syringe barrel and plunger from medical-grade polypropylene at high temperature. */;
        }

        state machine MoldingStates {
            state Idle;
            state Preheating;
            state Injecting;
            state Cooling;
            state Ejecting;
            state QualityCheck;

            initial;
            transition initial to Idle;

            transition Idle to Preheating
                when rawMaterial is received;

            transition Preheating to Injecting
                [barrelMoldTemperature >= meltTemperature];

            transition Injecting to Cooling
                when injectionPressureReached;

            transition Cooling to Ejecting
                when coolingCycleComplete;

            transition Ejecting to QualityCheck;

            transition QualityCheck to Idle;
        }
    }

    part def AssemblyStation {
        attribute stationStatus : ProductionStatus;
        attribute assemblyCycleTime : Duration;
        attribute throughputRate : StrokesPerMinute;
        attribute needleAttachmentForce : Force;

        port in components : AssemblyInputFlow;
        port out assembledSyringes : AssemblyOutputFlow;

        action assembleSyringe {
            in barrel : MoldedBarrel;
            in plunger : MoldedPlunger;
            in needle : SterileNeedleStock;
            out assembledSyringe : AssembledSyringe;
            doc /* Combine the molded barrel and plunger with a sterile needle to form a complete, functional syringe. */;
        }

        state machine AssemblyStates {
            state Idle;
            state Loading;
            state InsertingPlunger;
            state AttachingNeedle;
            state ApplyingNeedleCover;
            state Ejecting;

            initial;
            transition initial to Idle;

            transition Idle to Loading
                when components is received;

            transition Loading to InsertingPlunger;
            transition InsertingPlunger to AttachingNeedle;
            transition AttachingNeedle to ApplyingNeedleCover;
            transition ApplyingNeedleCover to Ejecting;
            transition Ejecting to Idle;
        }
    }

    part def SterilizationChamber {
        attribute stationStatus : ProductionStatus;
        attribute chamberTemperature : Temperature;
        attribute gasConcentration : Concentration;
        attribute exposureDuration : Duration;
        attribute humidity : HumidityLevel;
        attribute aerationDuration : Duration;
        attribute vacuumLevel : Pressure;
        attribute batchSize : Integer;

        port in assembledSyringes : SterilizationInputFlow;
        port out sterileSyringes : SterilizationOutputFlow;

        action sterilize {
            in assembledSyringe : AssembledSyringe;
            in gas : EthyleneOxideGas;
            out sterileSyringe : AssembledSyringe;
            doc /* Expose assembled syringes to Ethylene Oxide gas at controlled temperature and humidity for the specified exposure duration to eliminate all microorganisms. */;
        }

        state machine SterilizationStates {
            state Idle;
            state Loading;
            state VacuumPurge;
            state GasInjection;
            state Exposure;
            state FlushPurge;
            state Aeration;
            state Unloading;

            initial;
            transition initial to Idle;

            transition Idle to Loading
                when assembledSyringes is received;

            transition Loading to VacuumPurge;
            transition VacuumPurge to GasInjection
                [vacuumLevel <= targetVacuum];

            transition GasInjection to Exposure
                [gasConcentration >= targetConcentration];

            transition Exposure to FlushPurge
                when exposureDuration is complete;

            transition FlushPurge to Aeration;
            transition Aeration to Unloading
                when aerationDuration is complete;

            transition Unloading to Idle;
        }
    }

    part def PackagingStation {
        attribute stationStatus : ProductionStatus;
        attribute packagingCycleTime : Duration;
        attribute throughputRate : StrokesPerMinute;
        attribute sealTemperature : Temperature;
        attribute sealPressure : Pressure;

        port in sterileProducts : PackagingInputFlow;
        port out packagedProducts : PackagingOutputFlow;

        action packageSyringe {
            in sterileSyringe : AssembledSyringe;
            in packagingMaterial : PackagingMaterial;
            out packagedSyringe : PackagedSyringe;
            doc /* Individually seal each sterile syringe in protective medical-grade packaging that maintains sterility until opened by a healthcare professional. */;
        }

        state machine PackagingStates {
            state Idle;
            state Loading;
            state InsertingSyringe;
            state Sealing;
            state Labeling;
            state Ejecting;

            initial;
            transition initial to Idle;

            transition Idle to Loading
                when sterileProducts is received;

            transition Loading to InsertingSyringe;
            transition InsertingSyringe to Sealing
                [sealTemperature >= targetSealTemperature];

            transition Sealing to Labeling
                when sealComplete;

            transition Labeling to Ejecting;
            transition Ejecting to Idle;
        }
    }

    part def QualityInspectionUnit {
        attribute stationStatus : ProductionStatus;
        attribute inspectionCycleTime : Duration;
        attribute dimensionalTolerance : Length;
        attribute sterilityTestPassRate : Percent;
        attribute packageIntegrityTestRequired : Boolean;
        attribute visualDefectThreshold : Integer;
        attribute totalInspected : CycleCount;
        attribute totalAccepted : CycleCount;
        attribute totalRejected : CycleCount;

        port in incomingProducts : InspectionInputFlow;
        port out accepted : InspectionAcceptedOutputFlow;
        port out rejected : InspectionRejectedOutputFlow;

        action inspectProduct {
            in packagedSyringe : PackagedSyringe;
            out acceptedProduct : PackagedSyringe;
            out rejectedProduct : RejectedProduct;
            doc /* Rigorously inspect each packaged syringe for dimensional accuracy, sterility assurance, and package integrity. Reject products that fail any criterion. */;
        }

        action dimensionalInspection {
            in syringe : PackagedSyringe;
            out pass : Boolean;
            doc /* Verify barrel inner diameter, plunger dimensions, and needle gauge are within tolerance. */;
        }

        action sterilityVerification {
            in syringe : PackagedSyringe;
            out pass : Boolean;
            doc /* Verify sterility seal integrity and biological indicator test results. */;
        }

        action packageIntegrityInspection {
            in syringe : PackagedSyringe;
            out pass : Boolean;
            doc /* Verify package seal integrity, tamper-evidence, and absence of visual defects. */;
        }

        state machine InspectionStates {
            state Idle;
            state Weighing;
            state DimensionalInspection;
            state SterilityVerification;
            state PackageIntegrityTest;
            state Decision;
            state Pass;
            state Fail;

            initial;
            transition initial to Idle;

            transition Idle to Weighing
                when incomingProducts is received;

            transition Weighing to DimensionalInspection;
            transition DimensionalInspection to SterilityVerification;
            transition SterilityVerification to PackageIntegrityTest;
            transition PackageIntegrityTest to Decision;

            transition Decision to Pass
                [dimensionalPass == true && sterilityPass == true && packagePass == true];

            transition Decision to Fail;

            transition Pass to Idle;
            transition Fail to Idle;
        }
    }

    // =========================================================================
    // Manufacturing Line Part Definition
    // =========================================================================
    part def ManufacturingLine {
        attribute lineStatus : ProductionStatus;
        attribute throughputTarget : StrokesPerMinute;
        attribute totalProduced : CycleCount;
        attribute totalRejected : CycleCount;
        attribute yieldRate : Percent;
        attribute operatingHours : Duration;
        attribute maintenanceInterval : Duration;

        part molding : MoldingStation;
        part assembly : AssemblyStation;
        part sterilization : SterilizationChamber;
        part packaging : PackagingStation;
        part inspection : QualityInspectionUnit;

        port in polypropyleneSupply : PelletsFlow;
        port in needleSupply : SterileNeedleStock;
        port in eoGasSupply : EthyleneOxideGas;
        port in packagingSupply : PackagingMaterial;
        port out finishedGoods : InspectionAcceptedOutputFlow;
        port out rejectedGoods : InspectionRejectedOutputFlow;

        connection molding.moldedComponents to assembly.components;
        connection assembly.assembledSyringes to sterilization.assembledSyringes;
        connection sterilization.sterileSyringes to packaging.sterileProducts;
        connection packaging.packagedProducts to inspection.incomingProducts;
        connection inspection.accepted to finishedGoods;
        connection inspection.rejected to rejectedGoods;
        connection polypropyleneSupply to molding.rawMaterial;
        connection needleSupply to assembly.components.needleStock;
        connection eoGasSupply to sterilization.assembledSyringes.eoGas;
        connection packagingSupply to packaging.sterileProducts.packagingMaterial;

        state machine LineOperation {
            state Idle;
            state Startup;
            state Running;
            state Faulted;
            state Maintenance;
            state Shutdown;
            state Cleaning;

            initial;
            transition initial to Idle;

            transition Idle to Startup
                when startCommand;

            transition Startup to Running
                [allStationsOperational == true];

            transition Running to Faulted
                when stationFaultDetected;

            transition Running to Maintenance
                when maintenanceScheduled;

            transition Running to Shutdown
                when stopCommand;

            transition Faulted to Idle
                when faultCleared;

            transition Maintenance to Idle
                when maintenanceComplete;

            transition Shutdown to Cleaning;
            transition Cleaning to Idle;
        }

        action produceBatch {
            in batchSize : Integer;
            in pellets : PolypropylenePellets;
            in needleStock : SterileNeedleStock;
            in eoGas : EthyleneOxideGas;
            in packagingMaterial : PackagingMaterial;
            out acceptedProducts : PackagedSyringe;
            out rejectedProducts : RejectedProduct;
            doc /* Execute the full production cycle: mold components, assemble syringes, sterilize with EO gas, package in sterile barriers, and inspect for quality. */;
        }

        action calculateYield {
            in accepted : CycleCount;
            in rejected : CycleCount;
            out yield : Percent;
            doc /* Compute yield rate as accepted divided by total produced. */;
        }
    }

    // =========================================================================
    // Requirements
    // =========================================================================
    requirement def AutoDisableRequirement {
        doc /* The syringe shall automatically disable after a single, full-dose delivery of medication by permanently locking the plunger, making it physically impossible to use the syringe a second time. */;
        subject syringe : AutoDisableSyringe;
        attribute maxUses : Integer = 1;
        attribute lockIsPermanent : Boolean = true;
    }

    requirement def SingleUseRequirement {
        doc /* The syringe shall be designed for single use only. After the auto-disable mechanism engages, the plunger shall remain permanently locked and the syringe shall not be reusable under any circumstances. */;
        subject syringe : AutoDisableSyringe;
        attribute isReusable : Boolean = false;
    }

    requirement def SterilityRequirement {
        doc /* The syringe shall be completely free of microorganisms before use, achieved through Ethylene Oxide sterilization, and shall maintain sterility through individually sealed medical-grade packaging until opened by a healthcare professional. */;
        subject syringe : AutoDisableSyringe;
        attribute sterilizationMethod : String = "EthyleneOxide";
        attribute packagingIsSterileBarrier : Boolean = true;
    }

    requirement def QualityInspectionRequirement {
        doc /* All packaged syringes shall be rigorously inspected for dimensional accuracy, sterility assurance, and package integrity. Products that fail any inspection criterion shall be rejected and not shipped. */;
        subject inspection : QualityInspectionUnit;
        attribute dimensionalAccuracyChecked : Boolean = true;
        attribute sterilityVerified : Boolean = true;
        attribute packageIntegrityChecked : Boolean = true;
        attribute rejectedProductsRemoved : Boolean = true;
    }

    requirement def ManufacturingThroughputRequirement {
        doc /* The manufacturing line shall produce auto-disable syringes at the specified throughput target while maintaining a minimum acceptable yield rate. */;
        subject line : ManufacturingLine;
        attribute throughputTarget : StrokesPerMinute = 60.0;
        attribute minimumYield : Percent = 98.0;
    }

    requirement def MaterialCompositionRequirement {
        doc /* The syringe barrel and plunger shall be manufactured from medical-grade polypropylene suitable for medical device applications and injection molding at high temperature. */;
        subject barrel : Barrel;
        subject plunger : Plunger;
        attribute material : String = "MedicalGradePolypropylene";
    }

    requirement def DisposalRequirement {
        doc /* After its single use is fulfilled and the auto-disable mechanism has engaged, the syringe shall be disposed of in a biohazard sharps container. The syringe shall not be sterilized or reprocessed for reuse. */;
        subject syringe : AutoDisableSyringe;
        attribute disposalMethod : DisposalMethod = DisposalMethod::biohazardSharpsContainer;
        attribute reprocessingProhibited : Boolean = true;
    }

    requirement def NeedleSafetyRequirement {
        doc /* The syringe needle shall be sharp, sterile, and shall have a safety cover that is intact until the syringe is used by a healthcare professional. */;
        subject needle : Needle;
        attribute sharp : Boolean = true;
        attribute sterile : Boolean = true;
        attribute hasSafetyCover : Boolean = true;
    }

    requirement def DoseAccuracyRequirement {
        doc /* The syringe shall be capable of delivering a single full dose of medication with the specified dose volume accuracy. */;
        subject syringe : AutoDisableSyringe;
        attribute maximumDose : Dose = 5.0;
        attribute doseAccuracyTolerance : Percent = 2.0;
    }

    // Requirement usages
    requirement autoDisableReq : AutoDisableRequirement;
    requirement singleUseReq : SingleUseRequirement;
    requirement sterilityReq : SterilityRequirement;
    requirement qualityInspectionReq : QualityInspectionRequirement;
    requirement throughputReq : ManufacturingThroughputRequirement;
    requirement materialReq : MaterialCompositionRequirement;
    requirement disposalReq : DisposalRequirement;
    requirement needleSafetyReq : NeedleSafetyRequirement;
    requirement doseAccuracyReq : DoseAccuracyRequirement;

    // =========================================================================
    // Top-Level System Usages
    // =========================================================================
    part autoDisableSyringe : AutoDisableSyringe {
        attribute maximumDose : Dose = 5.0;
        attribute doseVolume : Dose = 5.0;
        attribute state : SyringeOperationalState = SyringeOperationalState::empty;
        attribute sterility : SterilityState = SterilityState::contaminated;
        attribute quality : QualityState = QualityState::pending;
        attribute hasBeenUsed : Boolean = false;

        part barrel : Barrel {
            attribute volumeCapacity : Volume = 5.0;
            attribute innerDiameter : Diameter = 12.0;
            attribute barrelLength : Length = 60.0;
            attribute material : String = "MedicalGradePolypropylene";
            attribute isSterile : Boolean = false;
            attribute wallThickness : Length = 1.5;
        }

        part plunger : Plunger {
            attribute length : Length = 70.0;
            attribute diameter : Diameter = 11.5;
            attribute material : String = "MedicalGradePolypropylene";
            attribute position : Real = 0.0;
            attribute isLocked : Boolean = false;
            attribute strokeDistance : Length = 55.0;
            attribute sealIntegrity : Boolean = true;
        }

        part needle : Needle {
            attribute length : Length = 25.0;
            attribute gauge : Integer = 23;
            attribute bevelAngle : Real = 30.0;
            attribute sterile : Boolean = false;
            attribute isAttached : Boolean = false;
            attribute hasSafetyCover : Boolean = true;
        }

        part autoDisable : AutoDisableMechanism {
            attribute isEngaged : Boolean = false;
            attribute activationForce : Force = 15.0;
            attribute lockPosition : Real = 55.0;
            attribute singleUseCount : CycleCount = 0;
            attribute mechanismType : String = "SnapLock";
        }
    }

    part manufacturingLine : ManufacturingLine {
        attribute throughputTarget : StrokesPerMinute = 60.0;
        attribute yieldRate : Percent = 98.5;
        attribute lineStatus : ProductionStatus = ProductionStatus::idle;
        attribute totalProduced : CycleCount = 0;
        attribute totalRejected : CycleCount = 0;
        attribute operatingHours : Duration = 480.0;
        attribute maintenanceInterval : Duration = 120.0;

        part molding : MoldingStation {
            attribute stationStatus : ProductionStatus = ProductionStatus::idle;
            attribute barrelMoldTemperature : Temperature = 220.0;
            attribute plungerMoldTemperature : Temperature = 210.0;
            attribute injectionPressure : Pressure = 120.0;
            attribute cycleTime : Duration = 0.5;
            attribute throughputRate : StrokesPerMinute = 120.0;
            attribute moldCavityCount : Integer = 16;
        }

        part assembly : AssemblyStation {
            attribute stationStatus : ProductionStatus = ProductionStatus::idle;
            attribute assemblyCycleTime : Duration = 0.3;
            attribute throughputRate : StrokesPerMinute = 200.0;
            attribute needleAttachmentForce : Force = 5.0;
        }

        part sterilization : SterilizationChamber {
            attribute stationStatus : ProductionStatus = ProductionStatus::idle;
            attribute chamberTemperature : Temperature = 55.0;
            attribute gasConcentration : Concentration = 600.0;
            attribute exposureDuration : Duration = 240.0;
            attribute humidity : HumidityLevel = 60.0;
            attribute aerationDuration : Duration = 720.0;
            attribute vacuumLevel : Pressure = 0.05;
            attribute batchSize : Integer = 5000;
        }

        part packaging : PackagingStation {
            attribute stationStatus : ProductionStatus = ProductionStatus::idle;
            attribute packagingCycleTime : Duration = 0.25;
            attribute throughputRate : StrokesPerMinute = 240.0;
            attribute sealTemperature : Temperature = 180.0;
            attribute sealPressure : Pressure = 0.3;
        }

        part inspection : QualityInspectionUnit {
            attribute stationStatus : ProductionStatus = ProductionStatus::idle;
            attribute inspectionCycleTime : Duration = 0.15;
            attribute dimensionalTolerance : Length = 0.1;
            attribute sterilityTestPassRate : Percent = 99.0;
            attribute packageIntegrityTestRequired : Boolean = true;
            attribute visualDefectThreshold : Integer = 0;
            attribute totalInspected : CycleCount = 0;
            attribute totalAccepted : CycleCount = 0;
            attribute totalRejected : CycleCount = 0;
        }
    }

    part qualityInspectionUnit : QualityInspectionUnit {
        attribute inspectionCycleTime : Duration = 0.15;
        attribute dimensionalTolerance : Length = 0.1;
        attribute sterilityTestPassRate : Percent = 99.0;
        attribute packageIntegrityTestRequired : Boolean = true;
    }

    // =========================================================================
    // Action Definitions for End-to-End Processes
    // =========================================================================
    action def HealthcareWorkerUse {
        in packagedSyringe : PackagedSyringe;
        in medication : Medication;
        out waste : BiohazardWaste;
        doc /* A healthcare professional opens the sterile package, draws medication into the syringe, primes the needle, administers the full dose to the patient, the auto-disable mechanism engages permanently, and the disabled syringe is placed in a biohazard sharps container for disposal. */;

        action openSterilePackage {
            in packaged : PackagedSyringe;
            out sterileSyringe : AssembledSyringe;
        }

        action drawMedication {
            in sterileSyringe : AssembledSyringe;
            in med : Medication;
            out filledSyringe : AutoDisableSyringe;
        }

        action primeNeedle {
            in filledSyringe : AutoDisableSyringe;
            out primedSyringe : AutoDisableSyringe;
        }

        action administerDose {
            in primedSyringe : AutoDisableSyringe;
            out disabledSyringe : AutoDisableSyringe;
        }

        action disposeInSharpsContainer {
            in disabledSyringe : AutoDisableSyringe;
            out biohazardWaste : BiohazardWaste;
        }

        flow from openSterilePackage.sterileSyringe to drawMedication.sterileSyringe;
        flow from drawMedication.filledSyringe to primeNeedle.filledSyringe;
        flow from primeNeedle.primedSyringe to administerDose.primedSyringe;
        flow from administerDose.disabledSyringe to disposeInSharpsContainer.disabledSyringe;
    }

    action def ManufacturingProcess {
        in rawPolypropylene : PolypropylenePellets;
        in needleStock : SterileNeedleStock;
        in eoGas : EthyleneOxideGas;
        in packagingMaterial : PackagingMaterial;
        out acceptedProducts : PackagedSyringe;
        out rejectedProducts : RejectedProduct;
        doc /* The complete manufacturing process from raw polypropylene pellets and needle stock to quality-assured, sterile, individually packaged auto-disable syringes ready for shipment to healthcare facilities. */;

        action moldingPhase {
            in pellets : PolypropylenePellets;
            out barrels : MoldedBarrel;
            out plungers : MoldedPlunger;
        }

        action assemblyPhase {
            in barrels : MoldedBarrel;
            in plungers : MoldedPlunger;
            in needles : SterileNeedleStock;
            out assembled : AssembledSyringe;
        }

        action sterilizationPhase {
            in assembled : AssembledSyringe;
            in gas : EthyleneOxideGas;
            out sterile : AssembledSyringe;
        }

        action packagingPhase {
            in sterile : AssembledSyringe;
            in material : PackagingMaterial;
            out packaged : PackagedSyringe;
        }

        action inspectionPhase {
            in packaged : PackagedSyringe;
            out accepted : PackagedSyringe;
            out rejected : RejectedProduct;
        }

        flow from moldingPhase.barrels to assemblyPhase.barrels;
        flow from moldingPhase.plungers to assemblyPhase.plungers;
        flow from assemblyPhase.assembled to sterilizationPhase.assembled;
        flow from sterilizationPhase.sterile to packagingPhase.sterile;
        flow from packagingPhase.packaged to inspectionPhase.packaged;
        flow from inspectionPhase.accepted to acceptedProducts;
        flow from inspectionPhase.rejected to rejectedProducts;
    }

    action def EndOfLifeDisposal {
        in disabledSyringe : AutoDisableSyringe;
        out biohazardWaste : BiohazardWaste;
        doc /* After the auto-disable mechanism has engaged and the single-use purpose is fulfilled, the syringe is disposed of in a biohazard sharps container for safe medical waste handling. */;
    }

}
