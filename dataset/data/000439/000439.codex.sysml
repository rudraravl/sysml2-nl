package DapivirineRingSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Concentration {
    :> ScalarValues::Real;
    unit = "mg/mL";
  }

  attribute def MassDose {
    :> ScalarValues::Real;
    unit = "mg";
  }

  attribute def TimeDuration {
    :> ScalarValues::Real;
    unit = "day";
  }

  attribute def ReleaseRate {
    :> ScalarValues::Real;
    unit = "mg/day";
  }

  attribute def Diameter {
    :> ScalarValues::Real;
    unit = "mm";
  }

  attribute def Temperature {
    :> ScalarValues::Real;
    unit = "degC";
  }

  attribute def pH {
    :> ScalarValues::Real;
  }

  item def DapivirineMolecule {
    attribute molecularRole : String = "non-nucleoside reverse transcriptase inhibitor";
    attribute targetPathogen : String = "HIV-1";
  }

  item def VaginalFluid {
    attribute localPH : pH;
    attribute temperature : Temperature;
  }

  item def UserInstruction {
    attribute instructionText : String;
  }

  item def ProtectionStatus {
    attribute active : Boolean;
    attribute residualDrugMass : MassDose;
    attribute estimatedRemainingDuration : TimeDuration;
  }

  port def DrugReleasePort {
    out item releasedDrug : DapivirineMolecule;
    in item hydrationFluid : VaginalFluid;
  }

  port def UserInterfacePort {
    in item insertionInstruction : UserInstruction;
    out item protectionStatus : ProtectionStatus;
  }

  port def TissueInterfacePort {
    out item localDrugExposure : DapivirineMolecule;
    in item physiologicalFluid : VaginalFluid;
  }

  part def DapivirineRingSystem {

    attribute primaryFunction : String =
      "Provide sustained local release of dapivirine in the vagina to reduce the risk of HIV-1 acquisition during sexual exposure.";

    attribute intendedUseDuration : TimeDuration = 28.0;
    attribute nominalDapivirineLoad : MassDose = 25.0;
    attribute nominalReleaseRate : ReleaseRate = 0.14;
    attribute outerDiameter : Diameter = 56.0;
    attribute crossSectionDiameter : Diameter = 7.7;
    attribute storageTemperatureMaximum : Temperature = 30.0;

    port userPort : UserInterfacePort;
    port releasePort : DrugReleasePort;
    port tissuePort : TissueInterfacePort;

    part ringBody : SiliconeElastomerMatrix;
    part drugReservoir : DapivirineReservoir;
    part diffusionPath : ControlledDiffusionLayer;
    part vaginalEnvironment : VaginalLocalEnvironment;
    part adherenceMonitor : UseDurationMonitor;

    connection drugToDiffusion
      connect drugReservoir.reservoirOutlet to diffusionPath.diffusionInlet;

    connection diffusionToRelease
      connect diffusionPath.diffusionOutlet to releasePort;

    connection releaseToTissue
      connect releasePort to tissuePort;

    connection environmentHydration
      connect vaginalEnvironment.fluidPort to releasePort;

    connection useStatus
      connect adherenceMonitor.statusPort to userPort;

    action def InsertRing {
      in item instruction : UserInstruction;
      out item status : ProtectionStatus;
      first start;
      then verifyUserHandling;
      then placeFlexibleRing;
      then confirmPlacement;
      then status.active = true;
    }

    action def ReleaseDapivirine {
      in item fluid : VaginalFluid;
      out item drug : DapivirineMolecule;
      first hydrateSurface;
      then dissolveDapivirineAtMatrixInterface;
      then diffuseThroughElastomer;
      then deliverToLocalFluid;
    }

    action def RemoveRing {
      out item status : ProtectionStatus;
      first graspRing;
      then withdrawRing;
      then status.active = false;
    }

    state def RingLifecycle {
      state Stored;
      state Inserted;
      state ReleasingDrug;
      state EndOfUse;
      state Removed;

      transition initial then Stored;

      transition Stored_to_Inserted
        first Stored
        accept InsertRing
        then Inserted;

      transition Inserted_to_ReleasingDrug
        first Inserted
        if vaginalEnvironment.hydrated == true
        then ReleasingDrug;

      transition ReleasingDrug_to_EndOfUse
        first ReleasingDrug
        if adherenceMonitor.elapsedUseTime >= intendedUseDuration
        then EndOfUse;

      transition EndOfUse_to_Removed
        first EndOfUse
        accept RemoveRing
        then Removed;

      transition Inserted_to_Removed
        first Inserted
        accept RemoveRing
        then Removed;

      transition ReleasingDrug_to_Removed
        first ReleasingDrug
        accept RemoveRing
        then Removed;
    }

    exhibit state ringLifecycle : RingLifecycle;
    perform action insertion : InsertRing;
    perform action sustainedRelease : ReleaseDapivirine;
    perform action removal : RemoveRing;
  }

  part def SiliconeElastomerMatrix {
    attribute materialName : String = "medical-grade silicone elastomer";
    attribute flexible : Boolean = true;
    attribute biocompatible : Boolean = true;
    attribute structuralRole : String = "retain annular shape while permitting user insertion and removal";
  }

  part def DapivirineReservoir {
    attribute initialDrugMass : MassDose = 25.0;
    attribute remainingDrugMass : MassDose;
    attribute drugUniformlyDispersed : Boolean = true;

    port reservoirOutlet : DrugReleasePort;

    item storedDrug : DapivirineMolecule;

    constraint massBalance {
      remainingDrugMass >= 0.0;
      remainingDrugMass <= initialDrugMass;
    }
  }

  part def ControlledDiffusionLayer {
    attribute releaseMechanism : String = "passive diffusion from silicone matrix into vaginal fluid";
    attribute targetReleaseRate : ReleaseRate = 0.14;

    port diffusionInlet : DrugReleasePort;
    port diffusionOutlet : DrugReleasePort;

    constraint controlledRelease {
      targetReleaseRate > 0.0;
    }
  }

  part def VaginalLocalEnvironment {
    attribute hydrated : Boolean;
    attribute nominalTemperature : Temperature = 37.0;
    attribute expectedPHMinimum : pH = 3.5;
    attribute expectedPHMaximum : pH = 5.0;

    port fluidPort : DrugReleasePort;

    item localFluid : VaginalFluid;
  }

  part def UseDurationMonitor {
    attribute elapsedUseTime : TimeDuration = 0.0;
    attribute replacementDue : Boolean;

    port statusPort : UserInterfacePort;

    action def UpdateUseStatus {
      out item status : ProtectionStatus;
      first readElapsedUseTime;
      then estimateResidualDrug;
      then setReplacementDueFlag;
    }

    constraint replacementRule {
      replacementDue == (elapsedUseTime >= 28.0);
    }
  }

  requirement def SustainedLocalDeliveryRequirement {
    subject ring : DapivirineRingSystem;
    doc
      /* The system shall provide sustained local release of dapivirine over the intended use duration. */
    require constraint {
      ring.nominalReleaseRate > 0.0;
      ring.intendedUseDuration == 28.0;
    }
  }

  requirement def HIVRiskReductionFunctionRequirement {
    subject ring : DapivirineRingSystem;
    doc
      /* The system shall reduce risk of HIV-1 acquisition by maintaining local dapivirine exposure at the vaginal tissue interface. */
    require constraint {
      ring.primaryFunction ==
      "Provide sustained local release of dapivirine in the vagina to reduce the risk of HIV-1 acquisition during sexual exposure.";
    }
  }

  requirement def UserManagedUseRequirement {
    subject ring : DapivirineRingSystem;
    doc
      /* The system shall support insertion, wear, replacement, and removal by the intended user without powered components. */
    require constraint {
      ring.ringBody.flexible == true;
      ring.adherenceMonitor.elapsedUseTime >= 0.0;
    }
  }

  requirement def PassiveOperationRequirement {
    subject ring : DapivirineRingSystem;
    doc
      /* The system shall perform its primary drug delivery function passively after placement in the vaginal environment. */
    require constraint {
      ring.diffusionPath.targetReleaseRate == ring.nominalReleaseRate;
    }
  }

  part dapivirineRingProduct : DapivirineRingSystem;

  satisfy SustainedLocalDeliveryRequirement by dapivirineRingProduct;
  satisfy HIVRiskReductionFunctionRequirement by dapivirineRingProduct;
  satisfy UserManagedUseRequirement by dapivirineRingProduct;
  satisfy PassiveOperationRequirement by dapivirineRingProduct;
}