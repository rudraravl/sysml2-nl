package SyretteSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Volume :> ISQ::volume {
    unit = SI::millilitre;
  }

  attribute def FlowRate :> ISQ::volumeFlowRate {
    unit = SI::millilitre / SI::second;
  }

  attribute def Pressure :> ISQ::pressure {
    unit = SI::kilopascal;
  }

  attribute def Force :> ISQ::force {
    unit = SI::newton;
  }

  attribute def DoseMass :> ISQ::mass {
    unit = SI::milligram;
  }

  attribute def Duration :> ISQ::time {
    unit = SI::second;
  }

  item def LiquidMedication {
    attribute activeIngredientMass : DoseMass;
    attribute doseVolume : Volume;
    attribute sterilityMaintained : Boolean;
    attribute intendedRoute : String;
  }

  item def ManualCompressionForce {
    attribute magnitude : Force;
  }

  item def DeliveredDose {
    attribute deliveredVolume : Volume;
    attribute deliveredIngredientMass : DoseMass;
    attribute deliveryComplete : Boolean;
  }

  item def NeedleCap {
    attribute attached : Boolean;
    attribute sterilityBarrierIntact : Boolean;
  }

  port def MedicationOutletPort {
    out item medication : LiquidMedication;
  }

  port def MedicationInletPort {
    in item medication : LiquidMedication;
  }

  port def ForceInputPort {
    in item compressionForce : ManualCompressionForce;
  }

  port def TissueInterfacePort {
    in item medication : LiquidMedication;
    out item deliveredDose : DeliveredDose;
  }

  port def SterilityBarrierPort {
    inout item cap : NeedleCap;
  }

  action def RemoveNeedleCap {
    in item cap : NeedleCap;
    out item removedCap : NeedleCap;
  }

  action def InsertNeedle {
    in attribute insertionDepth : Length;
    out attribute needlePositioned : Boolean;
  }

  action def CompressReservoir {
    in item appliedForce : ManualCompressionForce;
    in item storedMedication : LiquidMedication;
    out item expelledMedication : LiquidMedication;
  }

  action def InjectMedication {
    in item medicationThroughNeedle : LiquidMedication;
    out item deliveredDose : DeliveredDose;
  }

  action def DisposeUsedSyrette {
    in attribute needleExposed : Boolean;
    out attribute disposalReady : Boolean;
  }

  state def SyretteOperationalState {
    state Sealed;
    state Ready;
    state NeedleInserted;
    state Delivering;
    state DoseDelivered;
    state Used;

    transition first Sealed;

    transition removeCap
      first Sealed
      then Ready;

    transition insertNeedle
      first Ready
      then NeedleInserted;

    transition applyCompression
      first NeedleInserted
      then Delivering;

    transition reservoirCollapsed
      first Delivering
      then DoseDelivered;

    transition withdrawAndDispose
      first DoseDelivered
      then Used;
  }

  part def FlexibleReservoir {
    attribute nominalCapacity : Volume = 1.0 [SI::millilitre];
    attribute fillVolume : Volume = 0.8 [SI::millilitre];
    attribute residualVolume : Volume = 0.05 [SI::millilitre];
    attribute maximumSafeCompressionPressure : Pressure = 200 [SI::kilopascal];

    port forceInput : ForceInputPort;
    port outlet : MedicationOutletPort;

    item medication : LiquidMedication {
      attribute activeIngredientMass = 10 [SI::milligram];
      attribute doseVolume = 0.8 [SI::millilitre];
      attribute sterilityMaintained = true;
      attribute intendedRoute = "subcutaneous or intramuscular injection";
    }

    perform action compress : CompressReservoir;
  }

  part def HypodermicNeedle {
    attribute boreDiameter : Length = 0.4 [SI::millimetre];
    attribute exposedLength : Length = 16 [SI::millimetre];
    attribute bevelSharpnessMaintained : Boolean = true;
    attribute sterileInternalPath : Boolean = true;

    port inlet : MedicationInletPort;
    port tissueInterface : TissueInterfacePort;

    perform action insert : InsertNeedle;
    perform action inject : InjectMedication;
  }

  part def ProtectiveCap {
    attribute capAttached : Boolean = true;
    attribute sterilityBarrierIntact : Boolean = true;
    attribute tamperEvidenceVisible : Boolean = false;

    port barrier : SterilityBarrierPort;

    perform action remove : RemoveNeedleCap;
  }

  part def UserHand {
    attribute availableCompressionForce : Force = 35 [SI::newton];

    port compressionOutput : ForceInputPort;
  }

  part def InjectionSite {
    attribute tissueType : String = "patient tissue";
    attribute acceptableNeedleDepth : Length = 12 [SI::millimetre];

    port tissuePort : TissueInterfacePort;
  }

  part def SingleDoseSyretteSystem {
    attribute primaryFunction : String =
      "Store one sterile measured liquid medication dose and deliver it through an attached needle when the flexible reservoir is manually compressed.";

    attribute expectedDoseVolume : Volume = 0.8 [SI::millilitre];
    attribute minimumDeliveredVolume : Volume = 0.75 [SI::millilitre];
    attribute maximumDeliveryDuration : Duration = 10 [SI::second];
    attribute nominalFlowRate : FlowRate = 0.12 [SI::millilitre / SI::second];

    part reservoir : FlexibleReservoir;
    part needle : HypodermicNeedle;
    part cap : ProtectiveCap;
    part operatorHand : UserHand;
    part patientInjectionSite : InjectionSite;

    port forceInput : ForceInputPort;
    port medicationExit : TissueInterfacePort;

    connection handToReservoir
      connect operatorHand.compressionOutput to reservoir.forceInput;

    connection reservoirToNeedle
      connect reservoir.outlet to needle.inlet;

    connection needleToTissue
      connect needle.tissueInterface to patientInjectionSite.tissuePort;

    connection systemForceBoundary
      connect forceInput to reservoir.forceInput;

    connection systemMedicationBoundary
      connect medicationExit to needle.tissueInterface;

    exhibit state operationalState : SyretteOperationalState;

    perform action capRemoval : RemoveNeedleCap;
    perform action needleInsertion : InsertNeedle;
    perform action reservoirCompression : CompressReservoir;
    perform action medicationInjection : InjectMedication;
    perform action finalDisposal : DisposeUsedSyrette;
  }

  requirement def PrimaryFunctionRequirement {
    subject syrette : SingleDoseSyretteSystem;

    require constraint {
      syrette.expectedDoseVolume >= 0.8 [SI::millilitre]
    }

    doc /* The syrette shall provide a compact, single-use mechanism for holding a sterile measured medication dose and injecting that dose through its attached needle when squeezed by a user. */
  }

  requirement def SterilityRequirement {
    subject syrette : SingleDoseSyretteSystem;

    require constraint {
      syrette.cap.sterilityBarrierIntact == true
    }

    doc /* The medication path shall remain sterile until the protective cap is removed immediately before use. */
  }

  requirement def DoseDeliveryRequirement {
    subject syrette : SingleDoseSyretteSystem;

    require constraint {
      syrette.minimumDeliveredVolume >= 0.75 [SI::millilitre] and
      syrette.maximumDeliveryDuration <= 10 [SI::second]
    }

    doc /* The syrette shall deliver at least the minimum specified medication volume within the allowed delivery time after reservoir compression begins. */
  }

  requirement def SingleUseRequirement {
    subject syrette : SingleDoseSyretteSystem;

    require constraint {
      syrette.reservoir.residualVolume <= 0.05 [SI::millilitre]
    }

    doc /* After dose delivery, the syrette shall be considered used and not refillable for another injection. */
  }

  requirement def ManualOperationRequirement {
    subject syrette : SingleDoseSyretteSystem;

    require constraint {
      syrette.operatorHand.availableCompressionForce <= 35 [SI::newton]
    }

    doc /* The syrette shall be operable by manual squeezing without requiring powered assistance. */
  }

  satisfy PrimaryFunctionRequirement by SingleDoseSyretteSystem;
  satisfy SterilityRequirement by SingleDoseSyretteSystem;
  satisfy DoseDeliveryRequirement by SingleDoseSyretteSystem;
  satisfy SingleUseRequirement by SingleDoseSyretteSystem;
  satisfy ManualOperationRequirement by SingleDoseSyretteSystem;

}