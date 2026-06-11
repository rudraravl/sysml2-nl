package HindustanSyringesMedicalDeviceModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;
  import Quantities::*;

  attribute def Milliliter :> ISQ::volume {
    unit = "mL";
  }

  attribute def Millimeter :> ISQ::length {
    unit = "mm";
  }

  attribute def Newton :> ISQ::force {
    unit = "N";
  }

  attribute def Kilopascal :> ISQ::pressure {
    unit = "kPa";
  }

  attribute def DoseVolume :> Milliliter;
  attribute def NeedleGauge :> ScalarValues::Integer;
  attribute def SterilityState :> ScalarValues::String;
  attribute def ProductIdentifier :> ScalarValues::String;
  attribute def LotIdentifier :> ScalarValues::String;
  attribute def UseCycleCount :> ScalarValues::Integer;

  item def Medication {
    attribute name : String;
    attribute volume : DoseVolume;
    attribute viscosityClass : String;
    attribute sterile : Boolean;
  }

  item def Air {
    attribute volume : DoseVolume;
  }

  item def SharpsWaste {
    attribute contaminated : Boolean;
    attribute lockedNeedle : Boolean;
  }

  item def UserForce {
    attribute magnitude : Newton;
    attribute direction : String;
  }

  item def DoseDeliveryEvent {
    attribute deliveredVolume : DoseVolume;
    attribute complete : Boolean;
    attribute timestamp : String;
  }

  port def FluidPort {
    in item fluidIn : Medication;
    out item fluidOut : Medication;
  }

  port def MechanicalInputPort {
    in item appliedForce : UserForce;
  }

  port def WastePort {
    out item waste : SharpsWaste;
  }

  port def IndicationPort {
    out item event : DoseDeliveryEvent;
  }

  part def SterileHypodermicSyringe {
    attribute productId : ProductIdentifier;
    attribute lotId : LotIdentifier;
    attribute nominalCapacity : DoseVolume;
    attribute graduatedIncrement : DoseVolume;
    attribute barrelInnerDiameter : Millimeter;
    attribute maximumOperatingPressure : Kilopascal;
    attribute sterility : SterilityState;
    attribute singleUse : Boolean = true;
    attribute useCount : UseCycleCount = 0;

    port needleFluidPort : FluidPort;
    port thumbInputPort : MechanicalInputPort;
    port disposalPort : WastePort;
    port deliveryIndicatorPort : IndicationPort;

    part barrel {
      attribute capacity : DoseVolume;
      attribute transparent : Boolean = true;
      attribute graduationReadable : Boolean = true;
      attribute luerInterfacePresent : Boolean = true;
      port proximalOpening : FluidPort;
      port distalNozzle : FluidPort;
    }

    part plungerRod {
      attribute travelLength : Millimeter;
      attribute thumbPadDiameter : Millimeter;
      port thumbPad : MechanicalInputPort;
    }

    part pistonGasket {
      attribute sealIntegrity : Boolean = true;
      attribute slidingFriction : Newton;
    }

    part needleAssembly {
      attribute gauge : NeedleGauge;
      attribute length : Millimeter;
      attribute bevelType : String;
      attribute permanentlyAttached : Boolean;
      port hubInlet : FluidPort;
      port needleTip : FluidPort;
    }

    part protectiveNeedleCap {
      attribute capInstalled : Boolean = true;
      attribute maintainsSterileBarrier : Boolean = true;
    }

    part tamperEvidentPackage {
      attribute packageSealed : Boolean = true;
      attribute sterileBarrierIntact : Boolean = true;
      attribute labelReadable : Boolean = true;
    }

    part doseScale {
      attribute minimumMark : DoseVolume;
      attribute maximumMark : DoseVolume;
      attribute increment : DoseVolume;
    }

    connection barrelToNeedle connect barrel.distalNozzle to needleAssembly.hubInlet;
    connection needleToSystemPort connect needleAssembly.needleTip to needleFluidPort;
    connection thumbToRod connect thumbInputPort to plungerRod.thumbPad;
    connection packageMaintainsCap connect tamperEvidentPackage to protectiveNeedleCap;

    action def OpenPackage {
      inout syringe : SterileHypodermicSyringe;
      objective {
        doc /* Open the tamper-evident sterile barrier while preserving product identity and visual inspection. */
      }
      first start;
      then verifyLabel;
      then breakSterileBarrier;
      then exposeCappedSyringe;
      then done;

      action verifyLabel {
        out accepted : Boolean;
      }

      action breakSterileBarrier {
        inout sealed : Boolean;
      }

      action exposeCappedSyringe;
    }

    action def RemoveNeedleCap {
      inout syringe : SterileHypodermicSyringe;
      first start;
      then gripCap;
      then withdrawCapAxially;
      then inspectNeedle;
      then done;

      action gripCap;
      action withdrawCapAxially;
      action inspectNeedle {
        out needleUsable : Boolean;
      }
    }

    action def AspirateMedication {
      inout syringe : SterileHypodermicSyringe;
      in medicationSource : Medication;
      out loadedMedication : Medication;

      first insertNeedleIntoSource;
      then retractPlunger;
      then drawFluid;
      then alignDoseToGraduation;
      then done;

      action insertNeedleIntoSource;
      action retractPlunger {
        in force : UserForce;
      }
      action drawFluid {
        in source : Medication;
        out aspirated : Medication;
      }
      action alignDoseToGraduation {
        inout dose : Medication;
      }
    }

    action def ExpelAir {
      inout syringe : SterileHypodermicSyringe;
      in loadedMedication : Medication;
      out preparedMedication : Medication;
      out expelledAir : Air;

      first orientNeedleUp;
      then tapBarrel;
      then advancePlungerUntilFluidAtTip;
      then verifyNoVisibleAir;
      then done;

      action orientNeedleUp;
      action tapBarrel;
      action advancePlungerUntilFluidAtTip {
        in force : UserForce;
      }
      action verifyNoVisibleAir {
        out passed : Boolean;
      }
    }

    action def DeliverDose {
      inout syringe : SterileHypodermicSyringe;
      in preparedMedication : Medication;
      in injectionForce : UserForce;
      out deliveryEvent : DoseDeliveryEvent;

      first positionNeedle;
      then depressPlunger;
      then transferMedication;
      then confirmDoseComplete;
      then done;

      action positionNeedle;
      action depressPlunger {
        in force : UserForce;
      }
      action transferMedication {
        in medication : Medication;
        out delivered : Medication;
      }
      action confirmDoseComplete {
        out event : DoseDeliveryEvent;
      }
    }

    action def DisposeAfterUse {
      inout syringe : SterileHypodermicSyringe;
      out waste : SharpsWaste;

      first preventReuse;
      then placeInSharpsContainer;
      then recordWaste;
      then done;

      action preventReuse;
      action placeInSharpsContainer {
        out discarded : SharpsWaste;
      }
      action recordWaste;
    }

    state def SyringeUseLifecycle {
      state packaged;
      state inspected;
      state uncapped;
      state filled;
      state airPurged;
      state doseDelivered;
      state disposed;
      state rejected;

      entry action initialize {
        useCount = 0;
      }

      transition initial then packaged;

      transition packaged_to_inspected
        first packaged
        accept OpenPackage
        then inspected;

      transition inspected_to_rejected
        first inspected
        if not tamperEvidentPackage.sterileBarrierIntact or not doseScale.increment > 0 [mL]
        then rejected;

      transition inspected_to_uncapped
        first inspected
        accept RemoveNeedleCap
        then uncapped;

      transition uncapped_to_filled
        first uncapped
        accept AspirateMedication
        then filled;

      transition filled_to_airPurged
        first filled
        accept ExpelAir
        then airPurged;

      transition airPurged_to_doseDelivered
        first airPurged
        accept DeliverDose
        do {
          useCount = useCount + 1;
        }
        then doseDelivered;

      transition doseDelivered_to_disposed
        first doseDelivered
        accept DisposeAfterUse
        then disposed;

      transition reuse_block
        first doseDelivered
        if singleUse and useCount >= 1
        then disposed;
    }
  }

  part def HindustanSyringesMedicalDevicesSystem {
    attribute manufacturerName : String = "Hindustan Syringes & Medical Devices";
    attribute primaryFunction : String = "Provide sterile, single-use injection devices that enable controlled aspiration, measurement, and delivery of a specified medication dose into or from a patient or container.";
    attribute operatingContext : String = "Clinical, vaccination, diagnostic, and general healthcare medication delivery workflows.";

    port medicationInterface : FluidPort;
    port userInputInterface : MechanicalInputPort;
    port sharpsWasteInterface : WastePort;
    port deliveryStatusInterface : IndicationPort;

    part sterileSyringe : SterileHypodermicSyringe {
      attribute productId = "HMD-Sterile-Disposable-Syringe";
      attribute lotId = "HMD-LOT-TRACEABLE";
      attribute nominalCapacity = 5.0 [mL];
      attribute graduatedIncrement = 0.2 [mL];
      attribute barrelInnerDiameter = 12.0 [mm];
      attribute maximumOperatingPressure = 300 [kPa];
      attribute sterility = "Sterile before package opening";
    }

    part clinicalUser {
      attribute trained : Boolean = true;
      attribute verifiesPackageIntegrity : Boolean = true;
      port handForce : MechanicalInputPort;
    }

    part medicationContainer {
      attribute containerType : String = "vial or ampoule";
      port outlet : FluidPort;
    }

    part patientInterface {
      attribute targetSitePrepared : Boolean;
      port injectionSite : FluidPort;
    }

    part sharpsContainer {
      attribute punctureResistant : Boolean = true;
      attribute labeledForBiohazard : Boolean = true;
      port intake : WastePort;
    }

    connection userAppliesForce connect clinicalUser.handForce to sterileSyringe.thumbInputPort;
    connection sourceToSyringe connect medicationContainer.outlet to sterileSyringe.needleFluidPort;
    connection syringeToPatient connect sterileSyringe.needleFluidPort to patientInterface.injectionSite;
    connection syringeToWaste connect sterileSyringe.disposalPort to sharpsContainer.intake;
    connection externalMedicationInterface connect medicationInterface to sterileSyringe.needleFluidPort;
    connection externalUserInputInterface connect userInputInterface to sterileSyringe.thumbInputPort;
    connection externalWasteInterface connect sharpsWasteInterface to sterileSyringe.disposalPort;
    connection externalDeliveryStatusInterface connect deliveryStatusInterface to sterileSyringe.deliveryIndicatorPort;
  }

  requirement def PrimaryFunctionRequirement {
    id = "REQ-HMD-001";
    text = "The system shall provide a sterile, single-use syringe device capable of aspirating, measuring, and delivering a controlled medication dose through a needle interface.";
  }

  requirement def SterilityRequirement {
    id = "REQ-HMD-002";
    text = "The syringe sterile barrier shall remain intact until deliberate package opening by the clinical user.";
  }

  requirement def DoseMeasurementRequirement {
    id = "REQ-HMD-003";
    text = "The syringe barrel shall provide readable graduations that allow the user to align the plunger gasket with the intended dose volume.";
  }

  requirement def FluidDeliveryRequirement {
    id = "REQ-HMD-004";
    text = "The syringe shall transfer medication from the barrel through the needle assembly when user force is applied to the plunger rod.";
  }

  requirement def SingleUseRequirement {
    id = "REQ-HMD-005";
    text = "The syringe shall be disposed of after one completed dose delivery and shall not be returned to a reusable state.";
  }

  requirement def SharpsSafetyRequirement {
    id = "REQ-HMD-006";
    text = "After use, the syringe and attached needle shall be treated as contaminated sharps waste and routed to a puncture-resistant sharps container.";
  }

  requirement def TraceabilityRequirement {
    id = "REQ-HMD-007";
    text = "The packaged syringe shall provide readable product and lot identification for clinical traceability before use.";
  }

  satisfy PrimaryFunctionSatisfaction by HindustanSyringesMedicalDevicesSystem;
  satisfy SterilitySatisfaction by HindustanSyringesMedicalDevicesSystem::sterileSyringe::tamperEvidentPackage;
  satisfy DoseMeasurementSatisfaction by HindustanSyringesMedicalDevicesSystem::sterileSyringe::doseScale;
  satisfy FluidDeliverySatisfaction by HindustanSyringesMedicalDevicesSystem::sterileSyringe;
  satisfy SingleUseSatisfaction by HindustanSyringesMedicalDevicesSystem::sterileSyringe;
  satisfy SharpsSafetySatisfaction by HindustanSyringesMedicalDevicesSystem::sharpsContainer;
  satisfy TraceabilitySatisfaction by HindustanSyringesMedicalDevicesSystem::sterileSyringe::tamperEvidentPackage;

  exhibit state HindustanSyringesMedicalDevicesSystem::sterileSyringe::SyringeUseLifecycle by HindustanSyringesMedicalDevicesSystem::sterileSyringe;
}