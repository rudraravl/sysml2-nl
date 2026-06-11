package PessarySystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Millimeter :> Length;
  attribute def Gram :> Mass;
  attribute def Newton :> Force;
  attribute def Kilopascal :> Pressure;
  attribute def Celsius :> Temperature;
  attribute def Hour :> Time;
  attribute def Day :> Time;

  enum def DeviceLifecycleState {
    enum inserted;
    enum supporting;
    enum monitoring;
    enum removed;
    enum cleaning;
    enum stored;
  }

  enum def FitQuality {
    enum undersized;
    enum acceptable;
    enum oversized;
  }

  enum def TissueCondition {
    enum normal;
    enum irritated;
    enum ulcerated;
    enum bleeding;
  }

  enum def MaterialGrade {
    enum medicalSilicone;
    enum inertPolymer;
  }

  item def VaginalWallTissue {
    attribute tissueCondition : TissueCondition;
    attribute contactPressureLimit : Kilopascal;
    attribute surfaceTemperature : Celsius;
  }

  item def PelvicOrganLoad {
    attribute downwardForce : Newton;
    attribute displacementWithoutSupport : Millimeter;
  }

  item def SupportReaction {
    attribute upwardSupportForce : Newton;
    attribute lateralStabilizingForce : Newton;
    attribute contactPressure : Kilopascal;
  }

  item def FitAssessment {
    attribute fitQuality : FitQuality;
    attribute retainedDuringActivity : Boolean;
    attribute permitsComfortableRemoval : Boolean;
    attribute voidingUnobstructed : Boolean;
  }

  item def CleaningMedium {
    attribute waterTemperature : Celsius;
    attribute mildSoapPresent : Boolean;
  }

  item def ClinicalInstruction {
    attribute maximumWearInterval : Day;
    attribute followUpInterval : Day;
    attribute userRemovalAllowed : Boolean;
  }

  item def ComfortFeedback {
    attribute painReported : Boolean;
    attribute pressureSensationLevel : Real;
    attribute dischargeConcernReported : Boolean;
  }

  port def TissueInterfacePort {
    in item pelvicOrganLoad : PelvicOrganLoad;
    inout item tissue : VaginalWallTissue;
    out item supportReaction : SupportReaction;
  }

  port def UserInteractionPort {
    in item comfortFeedback : ComfortFeedback;
    out item clinicalInstruction : ClinicalInstruction;
    out item fitAssessment : FitAssessment;
  }

  port def CleaningPort {
    in item cleaningMedium : CleaningMedium;
    out item fitAssessment : FitAssessment;
  }

  part def Pessary {
    attribute outerDiameter : Millimeter;
    attribute crossSectionDiameter : Millimeter;
    attribute mass : Gram;
    attribute material : MaterialGrade = MaterialGrade::medicalSilicone;
    attribute nominalElasticModulus : Kilopascal;
    attribute maximumContactPressure : Kilopascal;
    attribute reusable : Boolean = true;
    attribute radiopaqueMarkerPresent : Boolean = false;

    port tissuePort : TissueInterfacePort;
    port userPort : UserInteractionPort;
    port cleaningPort : CleaningPort;

    part supportBody {
      attribute continuousRingGeometry : Boolean = true;
      attribute deformationUnderInsertion : Millimeter;
      attribute restoredDiameterAfterInsertion : Millimeter;
      attribute smoothSurfaceFinish : Boolean = true;
    }

    part sizingFeature {
      attribute sizeCode : String;
      attribute availableDiameterMinimum : Millimeter;
      attribute availableDiameterMaximum : Millimeter;
      attribute availableDiameterStep : Millimeter;
    }

    part retentionFeature {
      attribute reliesOnVaginalWallContact : Boolean = true;
      attribute retentionForce : Newton;
      attribute expulsionResistance : Newton;
    }

    part safetyFeature {
      attribute biocompatible : Boolean = true;
      attribute latexFree : Boolean = true;
      attribute nonAbsorbent : Boolean = true;
      attribute inspectableForCracks : Boolean = true;
    }

    action supportPelvicOrgans {
      in item load : PelvicOrganLoad;
      inout item tissue : VaginalWallTissue;
      out item reaction : SupportReaction;

      first start;
      then distributeLoad;
      then stabilizePosition;
      then deliverSupport;
      then done;

      action distributeLoad {
        in item load;
        inout item tissue;
        out attribute calculatedContactPressure : Kilopascal;
      }

      action stabilizePosition {
        in attribute calculatedContactPressure : Kilopascal;
        out attribute retained : Boolean;
      }

      action deliverSupport {
        in item load;
        in attribute retained : Boolean;
        out item reaction;
      }
    }

    action assessFit {
      in item feedback : ComfortFeedback;
      in item reaction : SupportReaction;
      out item assessment : FitAssessment;

      first evaluateRetention;
      then evaluateComfort;
      then evaluateFunction;
      then reportFit;

      action evaluateRetention {
        out attribute retainedDuringActivity : Boolean;
      }

      action evaluateComfort {
        in item feedback;
        out attribute acceptableComfort : Boolean;
      }

      action evaluateFunction {
        out attribute voidingUnobstructed : Boolean;
      }

      action reportFit {
        out item assessment;
      }
    }

    action cleanDevice {
      in item cleaningMedium : CleaningMedium;
      out attribute cleanSurface : Boolean;
      out attribute damageObserved : Boolean;

      first rinse;
      then wash;
      then inspect;
      then dry;

      action rinse;
      action wash;
      action inspect {
        out attribute damageObserved : Boolean;
      }
      action dry {
        out attribute cleanSurface : Boolean;
      }
    }

    state def PessaryLifecycle {
      entry action initializeStored;

      state Stored;
      state Inserted;
      state ProvidingSupport;
      state MonitoringFit;
      state Removed;
      state Cleaning;
      state Retired;

      transition first Stored;

      transition insert
        first Stored
        then Inserted;

      transition beginSupport
        first Inserted
        then ProvidingSupport;

      transition checkFit
        first ProvidingSupport
        then MonitoringFit;

      transition continueUse
        first MonitoringFit
        then ProvidingSupport
        if fitAcceptable;

      transition removeForCleaning
        first ProvidingSupport
        then Removed;

      transition clean
        first Removed
        then Cleaning;

      transition storeAfterCleaning
        first Cleaning
        then Stored
        if damageNotObserved;

      transition retireDamagedDevice
        first Cleaning
        then Retired
        if damageObserved;

      transition removeForSymptoms
        first MonitoringFit
        then Removed
        if painOrIrritationReported;

      attribute fitAcceptable : Boolean;
      attribute damageObserved : Boolean;
      attribute damageNotObserved : Boolean;
      attribute painOrIrritationReported : Boolean;
    }
  }

  part def PelvicSupportEnvironment {
    part vaginalCanal {
      attribute restingDiameter : Millimeter;
      attribute expandedDiameterDuringInsertion : Millimeter;
      attribute tissueCondition : TissueCondition;
    }

    part pelvicOrgans {
      attribute unsupportedDisplacement : Millimeter;
      attribute downwardLoad : Newton;
    }

    port tissueBoundary : TissueInterfacePort;
  }

  part def User {
    attribute canSelfRemove : Boolean;
    attribute reportsSymptoms : Boolean;

    port interaction : UserInteractionPort;
  }

  part def Clinician {
    attribute trainedInPessaryFitting : Boolean = true;

    port instructionPort : UserInteractionPort;

    action selectPessarySize {
      in attribute vaginalCanalDiameter : Millimeter;
      in attribute pelvicOrganLoad : Newton;
      out attribute selectedOuterDiameter : Millimeter;
      out item instruction : ClinicalInstruction;
    }

    action reviewFollowUp {
      in item feedback : ComfortFeedback;
      in item assessment : FitAssessment;
      out item instruction : ClinicalInstruction;
    }
  }

  part def CleaningStation {
    port cleaningInterface : CleaningPort;

    part basin {
      attribute capacity : Milliliter;
      attribute cleanWaterAvailable : Boolean;
    }

    part dryingSurface {
      attribute lintFree : Boolean = true;
      attribute clean : Boolean = true;
    }
  }

  part def PessarySupportSystem {
    attribute primaryFunction : String =
      "Provide removable, non-surgical mechanical support to pelvic organs by occupying the vaginal canal and transferring pelvic organ load to surrounding vaginal tissue at tolerable contact pressure.";

    part pessary : Pessary {
      attribute outerDiameter = 70 [Millimeter];
      attribute crossSectionDiameter = 9 [Millimeter];
      attribute mass = 24 [Gram];
      attribute nominalElasticModulus = 900 [Kilopascal];
      attribute maximumContactPressure = 8 [Kilopascal];
    }

    part anatomy : PelvicSupportEnvironment {
      part vaginalCanal {
        attribute restingDiameter = 55 [Millimeter];
        attribute expandedDiameterDuringInsertion = 72 [Millimeter];
        attribute tissueCondition = TissueCondition::normal;
      }

      part pelvicOrgans {
        attribute unsupportedDisplacement = 28 [Millimeter];
        attribute downwardLoad = 3.5 [Newton];
      }
    }

    part user : User {
      attribute canSelfRemove = true;
      attribute reportsSymptoms = false;
    }

    part clinician : Clinician;

    part cleaningStation : CleaningStation;

    connect pessary.tissuePort to anatomy.tissueBoundary;
    connect pessary.userPort to user.interaction;
    connect clinician.instructionPort to user.interaction;
    connect pessary.cleaningPort to cleaningStation.cleaningInterface;

    item pelvicLoad : PelvicOrganLoad {
      attribute downwardForce = 3.5 [Newton];
      attribute displacementWithoutSupport = 28 [Millimeter];
    }

    item normalTissue : VaginalWallTissue {
      attribute tissueCondition = TissueCondition::normal;
      attribute contactPressureLimit = 10 [Kilopascal];
      attribute surfaceTemperature = 37 [Celsius];
    }

    item nominalReaction : SupportReaction {
      attribute upwardSupportForce = 3.2 [Newton];
      attribute lateralStabilizingForce = 1.1 [Newton];
      attribute contactPressure = 6 [Kilopascal];
    }

    item nominalInstruction : ClinicalInstruction {
      attribute maximumWearInterval = 90 [Day];
      attribute followUpInterval = 90 [Day];
      attribute userRemovalAllowed = true;
    }

    perform pessary.supportPelvicOrgans {
      in load = pelvicLoad;
      inout tissue = normalTissue;
      out reaction = nominalReaction;
    }

    perform clinician.selectPessarySize;

    perform pessary.assessFit;

    perform pessary.cleanDevice;
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /* The pessary system shall provide removable mechanical support for pelvic organs at a high level by positioning a biocompatible support body within the vaginal canal. */

    subject system : PessarySupportSystem;

    require constraint {
      system.pessary.reusable == true
    }
  }

  requirement def LoadSupportRequirement {
    doc
    /* The pessary shall generate sufficient upward support reaction to reduce unsupported pelvic organ displacement. */

    subject system : PessarySupportSystem;

    require constraint {
      system.nominalReaction.upwardSupportForce >= 0.75 * system.pelvicLoad.downwardForce
    }
  }

  requirement def ContactPressureRequirement {
    doc
    /* The pessary shall distribute support loads so tissue contact pressure remains below the selected tissue pressure limit during nominal use. */

    subject system : PessarySupportSystem;

    require constraint {
      system.nominalReaction.contactPressure <= system.normalTissue.contactPressureLimit
    }
  }

  requirement def BiocompatibilityRequirement {
    doc
    /* Patient-contacting pessary material shall be biocompatible, latex-free, smooth, and nonabsorbent. */

    subject device : Pessary;

    require constraint {
      device.safetyFeature.biocompatible == true and
      device.safetyFeature.latexFree == true and
      device.safetyFeature.nonAbsorbent == true and
      device.supportBody.smoothSurfaceFinish == true
    }
  }

  requirement def FitAssessmentRequirement {
    doc
    /* The pessary system shall support clinical or user assessment of retention, comfort, removability, and unobstructed voiding. */

    subject device : Pessary;

    require constraint {
      device.retentionFeature.reliesOnVaginalWallContact == true
    }
  }

  requirement def CleaningRequirement {
    doc
    /* The pessary shall support removal, cleaning with mild soap and water, inspection, drying, and storage before reuse. */

    subject device : Pessary;

    require constraint {
      device.reusable == true and
      device.safetyFeature.inspectableForCracks == true
    }
  }

  requirement def FollowUpRequirement {
    doc
    /* The pessary system shall include clinical instructions for wear interval, follow-up interval, and whether the user may remove the device independently. */

    subject system : PessarySupportSystem;

    require constraint {
      system.nominalInstruction.maximumWearInterval <= 90 [Day] and
      system.nominalInstruction.followUpInterval <= 90 [Day]
    }
  }

  satisfy PrimaryFunctionRequirement by PessarySupportSystem;
  satisfy LoadSupportRequirement by PessarySupportSystem;
  satisfy ContactPressureRequirement by PessarySupportSystem;
  satisfy BiocompatibilityRequirement by Pessary;
  satisfy FitAssessmentRequirement by Pessary;
  satisfy CleaningRequirement by Pessary;
  satisfy FollowUpRequirement by PessarySupportSystem;

}