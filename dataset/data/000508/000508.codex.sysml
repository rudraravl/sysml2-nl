package SurgicalDrapeModel {
    import ScalarValues::*;
    import SI::*;

    item def AirborneParticle {
        attribute diameter : Real;
    }

    item def LiquidContaminant {
        attribute volume : Real;
    }

    item def SterileInstrument {
        attribute sterilized : Boolean;
    }

    item def PatientContactPressure {
        attribute pressure_kPa : Real;
    }

    item def AdhesiveSealForce {
        attribute force_N : Real;
    }

    value def Area_m2 : Real;
    value def Length_mm : Real;
    value def Mass_g : Real;
    value def Absorbency_mL : Real;
    value def Permeability_mL_per_min : Real;
    value def Temperature_C : Real;

    enum def DrapeUsePhase {
        enum preparation;
        enum deployment;
        enum procedureProtection;
        enum removal;
        enum disposal;
    }

    enum def SterilityStatus {
        enum sterilePackaged;
        enum sterileFieldEstablished;
        enum compromised;
        enum disposed;
    }

    port def ContaminationPort {
        in item contaminant : LiquidContaminant;
        in item particle : AirborneParticle;
    }

    port def SterileFieldPort {
        out item sterileInstrument : SterileInstrument;
    }

    port def PatientInterfacePort {
        out item sealForce : AdhesiveSealForce;
        out item contactPressure : PatientContactPressure;
    }

    port def FluidCollectionPort {
        in item contaminant : LiquidContaminant;
    }

    port def DisposalPort {
        out item usedDrape : SurgicalDrape;
    }

    requirement def PrimaryFunctionRequirement {
        subject drape : SurgicalDrape;
        doc
        /*
         * The surgical drape shall establish and maintain a sterile physical barrier
         * around the operative site to reduce microbial, particulate, and liquid
         * contamination of the patient, surgical team, and sterile instruments during
         * a surgical procedure.
         */
        require constraint {
            drape.sterilityStatus == SterilityStatus::sterileFieldEstablished
        }
    }

    requirement def BarrierIntegrityRequirement {
        subject drape : SurgicalDrape;
        attribute minimumBarrierEfficiency : Real = 0.995;
        require constraint {
            drape.barrierLayer.microbialBarrierEfficiency >= minimumBarrierEfficiency
        }
    }

    requirement def FluidResistanceRequirement {
        subject drape : SurgicalDrape;
        require constraint {
            drape.barrierLayer.fluidPermeability <= 0.1
        }
    }

    requirement def OperativeAccessRequirement {
        subject drape : SurgicalDrape;
        require constraint {
            drape.fenestration.openingLength >= 80.0 and
            drape.fenestration.openingWidth >= 60.0
        }
    }

    requirement def AdhesiveRetentionRequirement {
        subject drape : SurgicalDrape;
        require constraint {
            drape.adhesiveBorder.peelStrength >= 1.5
        }
    }

    part def AbsorbentLayer {
        attribute material : String = "spunlace nonwoven absorbent layer";
        attribute area : Area_m2 = 1.80;
        attribute thickness : Length_mm = 0.45;
        attribute absorbency : Absorbency_mL = 650.0;
        attribute lintGenerationIndex : Real = 0.02;
        port fluidInlet : FluidCollectionPort;
    }

    part def BarrierLayer {
        attribute material : String = "polyethylene impermeable film";
        attribute area : Area_m2 = 1.85;
        attribute thickness : Length_mm = 0.035;
        attribute fluidPermeability : Permeability_mL_per_min = 0.02;
        attribute microbialBarrierEfficiency : Real = 0.999;
        attribute tensileStrength_N : Real = 42.0;
        port contaminationSide : ContaminationPort;
    }

    part def AdhesiveBorder {
        attribute material : String = "hypoallergenic pressure-sensitive adhesive";
        attribute width : Length_mm = 50.0;
        attribute peelStrength : Real = 2.1;
        attribute skinContactTemperatureLimit : Temperature_C = 41.0;
        port patientSeal : PatientInterfacePort;
    }

    part def Fenestration {
        attribute openingLength : Length_mm = 140.0;
        attribute openingWidth : Length_mm = 90.0;
        attribute reinforcedEdgeWidth : Length_mm = 20.0;
        attribute edgeMaterial : String = "reinforced absorbent adhesive surround";
        port patientOpening : PatientInterfacePort;
    }

    part def InstrumentZone {
        attribute usableArea : Area_m2 = 0.45;
        attribute maximumInstrumentMass : Mass_g = 3000.0;
        attribute slipResistanceCoefficient : Real = 0.72;
        port sterileSurface : SterileFieldPort;
    }

    part def FluidControlPouch {
        attribute capacity : Absorbency_mL = 1200.0;
        attribute drainPortDiameter : Length_mm = 8.0;
        attribute splashGuardHeight : Length_mm = 35.0;
        port pouchInlet : FluidCollectionPort;
    }

    part def Packaging {
        attribute packageMaterial : String = "sealed sterile medical pouch";
        attribute sterilizationMethod : String = "ethylene oxide";
        attribute packageIntegrity : Boolean = true;
        attribute shelfLifeMonths : Integer = 36;
    }

    action def VerifyPackageIntegrity {
        in package : Packaging;
        out valid : Boolean;
        action checkSeal;
        action checkSterilityIndicator;
        then checkSeal;
        then checkSterilityIndicator;
    }

    action def EstablishSterileField {
        inout drape : SurgicalDrape;
        action openPackage;
        action orientPatientSide;
        action unfoldWithoutContamination;
        action alignFenestration;
        action pressAdhesiveBorder;
        then openPackage;
        then orientPatientSide;
        then unfoldWithoutContamination;
        then alignFenestration;
        then pressAdhesiveBorder;
    }

    action def MaintainBarrier {
        inout drape : SurgicalDrape;
        in contaminant : LiquidContaminant;
        action repelFluidAtBarrierLayer;
        action absorbFluidAtTopLayer;
        action divertFluidToPouch;
        then repelFluidAtBarrierLayer;
        then absorbFluidAtTopLayer;
        then divertFluidToPouch;
    }

    action def RemoveAndDispose {
        inout drape : SurgicalDrape;
        action releaseAdhesiveFromSkin;
        action foldContaminatedSideInward;
        action transferToClinicalWaste;
        then releaseAdhesiveFromSkin;
        then foldContaminatedSideInward;
        then transferToClinicalWaste;
    }

    state def SurgicalDrapeLifecycle {
        entry action VerifyPackageIntegrity;

        state Packaged {
            entry;
        }

        state Deployed {
            entry action EstablishSterileField;
        }

        state ProtectingSterileField {
            entry action MaintainBarrier;
        }

        state Compromised {
            entry;
        }

        state Removed {
            entry action RemoveAndDispose;
        }

        state Disposed {
            entry;
        }

        transition first Packaged;
        transition Packaged_to_Deployed
            first Packaged
            then Deployed
            accept deployDrape;

        transition Deployed_to_Protecting
            first Deployed
            then ProtectingSterileField
            accept incisionPrepared;

        transition Protecting_to_Compromised
            first ProtectingSterileField
            then Compromised
            accept barrierBreachDetected;

        transition Protecting_to_Removed
            first ProtectingSterileField
            then Removed
            accept procedureComplete;

        transition Compromised_to_Removed
            first Compromised
            then Removed
            accept replaceDrape;

        transition Removed_to_Disposed
            first Removed
            then Disposed
            accept discardAsClinicalWaste;
    }

    part def SurgicalDrape {
        attribute identifier : String = "single-use fenestrated surgical drape";
        attribute totalLength : Length_mm = 2400.0;
        attribute totalWidth : Length_mm = 1800.0;
        attribute totalMass : Mass_g = 420.0;
        attribute usePhase : DrapeUsePhase = DrapeUsePhase::preparation;
        attribute sterilityStatus : SterilityStatus = SterilityStatus::sterilePackaged;

        part absorbentLayer : AbsorbentLayer;
        part barrierLayer : BarrierLayer;
        part adhesiveBorder : AdhesiveBorder;
        part fenestration : Fenestration;
        part instrumentZone : InstrumentZone;
        part fluidControlPouch : FluidControlPouch;
        part packaging : Packaging;

        port externalContamination : ContaminationPort;
        port sterileFieldOutput : SterileFieldPort;
        port patientInterface : PatientInterfacePort;
        port fluidDrainage : FluidCollectionPort;
        port disposalOutput : DisposalPort;

        connect externalContamination to barrierLayer.contaminationSide;
        connect absorbentLayer.fluidInlet to fluidControlPouch.pouchInlet;
        connect fluidDrainage to fluidControlPouch.pouchInlet;
        connect adhesiveBorder.patientSeal to patientInterface;
        connect fenestration.patientOpening to patientInterface;
        connect instrumentZone.sterileSurface to sterileFieldOutput;

        perform lifecycle : SurgicalDrapeLifecycle;
    }

    part def SurgicalDrapeSystem {
        attribute systemPurpose : String =
            "Provide a sterile barrier and controlled operative opening over a patient during surgery.";
        attribute intendedUse : String =
            "Single-use sterile surgical field isolation for invasive procedures.";

        part drape : SurgicalDrape;

        satisfy PrimaryFunctionRequirement by drape;
        satisfy BarrierIntegrityRequirement by drape;
        satisfy FluidResistanceRequirement by drape;
        satisfy OperativeAccessRequirement by drape;
        satisfy AdhesiveRetentionRequirement by drape;
    }
}