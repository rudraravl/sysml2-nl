package LeftAtrialAppendageOcclusionModel {

  import ScalarValues::*;

  attribute def Length_mm :> Real {
    doc /* Linear dimension in millimeters. */
  }

  attribute def Diameter_mm :> Length_mm {
    doc /* Diameter in millimeters. */
  }

  attribute def Area_mm2 :> Real {
    doc /* Area in square millimeters. */
  }

  attribute def Volume_mL :> Real {
    doc /* Volume in milliliters. */
  }

  attribute def Pressure_mmHg :> Real {
    doc /* Blood or device pressure in millimeters of mercury. */
  }

  attribute def FlowRate_mL_per_min :> Real {
    doc /* Volumetric flow rate in milliliters per minute. */
  }

  attribute def Force_N :> Real {
    doc /* Mechanical force in newtons. */
  }

  attribute def Time_min :> Real {
    doc /* Duration in minutes. */
  }

  attribute def Time_day :> Real {
    doc /* Duration in days. */
  }

  attribute def Angle_deg :> Real {
    doc /* Angular orientation in degrees. */
  }

  attribute def Percent :> Real {
    doc /* Dimensionless percentage value. */
  }

  attribute def FrenchSize_Fr :> Real {
    doc /* Catheter outer diameter expressed in French size. */
  }

  enum def ImplantFrameMaterialKind {
    enum nitinol;
    enum cobaltChromium;
    enum stainlessSteel;
  }

  enum def MembraneMaterialKind {
    enum expandedPTFE;
    enum polyester;
    enum polyurethane;
  }

  enum def ImagingModalityKind {
    enum transesophagealEchocardiography;
    enum intracardiacEchocardiography;
    enum fluoroscopy;
    enum computedTomography;
  }

  enum def ProcedurePhaseKind {
    enum preProcedurePlanning;
    enum vascularAccess;
    enum transseptalAccess;
    enum appendageAssessment;
    enum deviceSelection;
    enum deviceDelivery;
    enum deploymentAssessment;
    enum release;
    enum closureAndRecovery;
    enum followUp;
  }

  enum def SealStatusKind {
    enum notSealed;
    enum positioned;
    enum mechanicallySealed;
    enum hemodynamicallySealed;
    enum endothelialized;
  }

  item def Blood {
    attribute pressure : Pressure_mmHg;
    attribute flowRate : FlowRate_mL_per_min;
    attribute oxygenSaturation : Percent;
    attribute anticoagulated : Boolean;
  }

  item def ThrombusMaterial {
    attribute volume : Volume_mL;
    attribute mobilityIndex : Percent;
  }

  item def ContrastAgent {
    attribute injectedVolume : Volume_mL;
    attribute iodineConcentration_mg_per_mL : Real;
  }

  item def ImagingSignal {
    attribute modality : ImagingModalityKind;
    attribute frameRate_Hz : Real;
    attribute spatialResolution_mm : Length_mm;
  }

  item def DeploymentCommand {
    attribute advanceDistance : Length_mm;
    attribute retractDistance : Length_mm;
    attribute rotationAngle : Angle_deg;
    attribute releaseRequested : Boolean;
  }

  item def ImplantItem {
    attribute nominalDiameter : Diameter_mm;
    attribute frameMaterial : ImplantFrameMaterialKind;
    attribute membraneMaterial : MembraneMaterialKind;
    attribute sterile : Boolean;
  }

  item def SealedAppendageResult {
    attribute sealStatus : SealStatusKind;
    attribute residualLeakWidth : Length_mm;
    attribute deviceCompression : Percent;
    attribute embolicMaterialEscapeRate : FlowRate_mL_per_min;
    attribute stableUnderTugTest : Boolean;
  }

  port def BloodPort {
    in item incomingBlood : Blood;
    out item outgoingBlood : Blood;
    attribute localPressure : Pressure_mmHg;
  }

  port def LAAOstiumPort {
    in item atrialBlood : Blood;
    out item appendageBlood : Blood;
    out item embolicMaterial : ThrombusMaterial;
    attribute ostiumDiameter : Diameter_mm;
    attribute landingZoneDiameter : Diameter_mm;
  }

  port def SealInterfacePort {
    in item atrialBlood : Blood;
    out item filteredOrBlockedBlood : Blood;
    in item embolicMaterialLoad : ThrombusMaterial;
    attribute residualLeakWidth : Length_mm;
    attribute contactPressure : Pressure_mmHg;
  }

  port def MechanicalCouplingPort {
    in item command : DeploymentCommand;
    out item implantTransfer : ImplantItem;
    attribute axialForce : Force_N;
    attribute torque_Nmm : Real;
  }

  port def ImagingPort {
    in item imageSignal : ImagingSignal;
    out item contrast : ContrastAgent;
    attribute visualizationConfidence : Percent;
  }

  port def FlushPort {
    in item heparinizedSaline : Blood;
    attribute flushRate : FlowRate_mL_per_min;
  }

  port def OperatorCommandPort {
    out item command : DeploymentCommand;
    in item imageSignal : ImagingSignal;
    attribute operatorReadiness : Percent;
  }

  part def LeftAtrium {
    port bloodInterface : BloodPort;
    part appendage : LeftAtrialAppendage;
    attribute meanPressure : Pressure_mmHg = 10.0;
    attribute appendageFlowRateBeforeOcclusion : FlowRate_mL_per_min = 35.0;
  }

  part def LeftAtrialAppendage {
    doc /* Anatomical cul-de-sac where thrombus may form in atrial fibrillation. */
    port ostium : LAAOstiumPort;
    attribute ostiumDiameter : Diameter_mm;
    attribute landingZoneDiameter : Diameter_mm;
    attribute depth : Length_mm;
    attribute lobeCount : Integer;
    attribute thrombusPresent : Boolean;
    attribute spontaneousEchoContrast : Percent;
    constraint adequateLandingZone {
      landingZoneDiameter > 12.0 and landingZoneDiameter < 36.0 and depth >= landingZoneDiameter
    }
  }

  part def InteratrialSeptum {
    port punctureSite : MechanicalCouplingPort;
    attribute septalThickness : Length_mm = 3.0;
    attribute punctureHeightFromMitralAnnulus : Length_mm;
    attribute puncturePosteriorOffset : Length_mm;
  }

  part def FemoralVenousAccess {
    port sheathEntry : MechanicalCouplingPort;
    attribute accessDiameter : FrenchSize_Fr = 14.0;
    attribute hemostasisAchieved : Boolean;
  }

  part def PatientCardiacAnatomy {
    part leftAtrium : LeftAtrium;
    part interatrialSeptum : InteratrialSeptum;
    part femoralVein : FemoralVenousAccess;
    port imagingInterface : ImagingPort;
    attribute atrialFibrillationPresent : Boolean = true;
    attribute contraindicationToLongTermAnticoagulation : Boolean = true;
    attribute baselineStrokeRiskScore : Real;
    attribute baselineBleedingRiskScore : Real;
  }

  part def OccluderFrame {
    attribute material : ImplantFrameMaterialKind = ImplantFrameMaterialKind::nitinol;
    attribute unconstrainedDiameter : Diameter_mm;
    attribute deployedDiameter : Diameter_mm;
    attribute strutThickness : Length_mm;
    attribute radialForce : Force_N;
    constraint superelasticFrame {
      radialForce >= 0.8 and radialForce <= 4.5
    }
  }

  part def OcclusiveMembrane {
    attribute material : MembraneMaterialKind = MembraneMaterialKind::expandedPTFE;
    attribute poreSize_um : Real;
    attribute membraneArea : Area_mm2;
    attribute permeabilityIndex : Percent;
    constraint lowPermeability {
      permeabilityIndex <= 5.0
    }
  }

  part def FixationAnchor {
    attribute count : Integer;
    attribute penetrationDepth : Length_mm;
    attribute pulloutResistance : Force_N;
    constraint atraumaticButStable {
      penetrationDepth <= 2.0 and pulloutResistance >= 5.0
    }
  }

  part def ProximalHub {
    port releaseCoupler : MechanicalCouplingPort;
    attribute hubHeight : Length_mm;
    attribute threadEngaged : Boolean;
    attribute radiopaqueMarkerVisible : Boolean = true;
  }

  part def LAAOccluderImplant {
    doc /* Permanent implant that occludes the left atrial appendage ostium to prevent thrombus migration into systemic circulation. */
    part frame : OccluderFrame;
    part membrane : OcclusiveMembrane;
    part anchors : FixationAnchor;
    part hub : ProximalHub;
    port appendageFace : SealInterfacePort;
    port atrialFace : SealInterfacePort;
    port deliveryInterface : MechanicalCouplingPort;
    attribute nominalDiameter : Diameter_mm;
    attribute nominalLength : Length_mm;
    attribute compressionAfterDeployment : Percent;
    attribute residualPeriDeviceLeak : Length_mm;
    attribute deviceEmbolized : Boolean = false;
    attribute endothelializationTime : Time_day = 45.0;
    attribute sealStatus : SealStatusKind = SealStatusKind::notSealed;
    constraint appropriateCompression {
      compressionAfterDeployment >= 8.0 and compressionAfterDeployment <= 20.0
    }
    constraint acceptableLeak {
      residualPeriDeviceLeak <= 5.0
    }
    connection hubToDelivery connect hub.releaseCoupler to deliveryInterface;
    connection membraneToAppendageFace connect membrane to appendageFace;
    connection frameToAnchors connect frame to anchors;
  }

  part def AccessSheath {
    port venousEnd : MechanicalCouplingPort;
    port atrialEnd : MechanicalCouplingPort;
    port flush : FlushPort;
    attribute innerDiameter : FrenchSize_Fr = 12.0;
    attribute workingLength : Length_mm = 750.0;
    attribute curveAngle : Angle_deg = 45.0;
    attribute radiopaqueTipVisible : Boolean = true;
  }

  part def DeliveryCatheter {
    port proximalEnd : MechanicalCouplingPort;
    port distalEnd : MechanicalCouplingPort;
    port flush : FlushPort;
    attribute outerDiameter : FrenchSize_Fr = 10.0;
    attribute usableLength : Length_mm = 850.0;
    attribute deflectable : Boolean = true;
  }

  part def PushCable {
    port handleEnd : MechanicalCouplingPort;
    port implantEnd : MechanicalCouplingPort;
    attribute tensileCapacity : Force_N = 30.0;
    attribute releaseTurnsRequired : Real = 5.0;
    attribute connectedToImplant : Boolean = true;
  }

  part def HemostasisValve {
    port accessSide : MechanicalCouplingPort;
    port catheterSide : MechanicalCouplingPort;
    attribute leakRate_mL_per_min : FlowRate_mL_per_min = 0.2;
    constraint hemostatic {
      leakRate_mL_per_min <= 1.0
    }
  }

  part def TranscatheterDeliverySystem {
    doc /* Removable delivery equipment used to transport, position, recapture, and release the LAA occluder implant. */
    part sheath : AccessSheath;
    part catheter : DeliveryCatheter;
    part pushCable : PushCable;
    part valve : HemostasisValve;
    port operatorInterface : OperatorCommandPort;
    port venousAccessInterface : MechanicalCouplingPort;
    port transseptalInterface : MechanicalCouplingPort;
    port implantInterface : MechanicalCouplingPort;
    attribute sterileBarrierIntact : Boolean = true;
    attribute airFreeLumen : Boolean = true;
    connection venousAccessToValve connect venousAccessInterface to valve.accessSide;
    connection valveToCatheter connect valve.catheterSide to catheter.proximalEnd;
    connection catheterToSheath connect catheter.distalEnd to sheath.atrialEnd;
    connection pushCableToImplant connect pushCable.implantEnd to implantInterface;
    connection operatorToPushCable connect operatorInterface to pushCable.handleEnd;
    connection sheathToSeptum connect sheath.atrialEnd to transseptalInterface;
  }

  part def ImagingAndGuidanceSubsystem {
    doc /* Imaging support used to size the appendage, guide transseptal access, verify device position, and assess residual leak. */
    port patientImaging : ImagingPort;
    port operatorDisplay : OperatorCommandPort;
    attribute primaryModality : ImagingModalityKind = ImagingModalityKind::transesophagealEchocardiography;
    attribute secondaryModality : ImagingModalityKind = ImagingModalityKind::fluoroscopy;
    attribute minimumVisualizationConfidence : Percent = 85.0;
    attribute measuredOstiumDiameter : Diameter_mm;
    attribute measuredLandingZoneDiameter : Diameter_mm;
    attribute measuredResidualLeak : Length_mm;
    constraint adequateVisualization {
      minimumVisualizationConfidence >= 80.0
    }
  }

  part def ClinicalOperator {
    port commandConsole : OperatorCommandPort;
    attribute trainedForLAAO : Boolean = true;
    attribute procedureExperienceCount : Integer;
    attribute radiationProtectionUsed : Boolean = true;
  }

  action def PreProcedurePlanning {
    in patient : PatientCardiacAnatomy;
    out selectedNominalDiameter : Diameter_mm;
    out appendageSuitable : Boolean;
    attribute plannedCompression : Percent;
    constraint selectionRule {
      selectedNominalDiameter >= patient.leftAtrium.appendage.landingZoneDiameter * 1.08 and
      selectedNominalDiameter <= patient.leftAtrium.appendage.landingZoneDiameter * 1.20
    }
  }

  action def EstablishVenousAndTransseptalAccess {
    in patient : PatientCardiacAnatomy;
    in deliverySystem : TranscatheterDeliverySystem;
    out leftAtrialAccessAchieved : Boolean;
    attribute accessTime : Time_min;
    constraint accessSafety {
      accessTime <= 45.0
    }
  }

  action def AssessAppendage {
    in patient : PatientCardiacAnatomy;
    in imaging : ImagingAndGuidanceSubsystem;
    out ostiumDiameter : Diameter_mm;
    out landingZoneDiameter : Diameter_mm;
    out thrombusExcluded : Boolean;
  }

  action def LoadAndAdvanceImplant {
    in implant : LAAOccluderImplant;
    in deliverySystem : TranscatheterDeliverySystem;
    out implantAtAppendage : Boolean;
    attribute flushVolume : Volume_mL;
    constraint airManagement {
      deliverySystem.airFreeLumen == true and flushVolume >= 20.0
    }
  }

  action def DeployImplant {
    in implant : LAAOccluderImplant;
    in patient : PatientCardiacAnatomy;
    in deliverySystem : TranscatheterDeliverySystem;
    out deployedImplant : LAAOccluderImplant;
    attribute deploymentForce : Force_N;
    attribute deploymentTime : Time_min;
    constraint deploymentEnvelope {
      deploymentForce <= 15.0 and deploymentTime <= 20.0
    }
  }

  action def VerifyPositionSealAndStability {
    in implant : LAAOccluderImplant;
    in patient : PatientCardiacAnatomy;
    in imaging : ImagingAndGuidanceSubsystem;
    out acceptableForRelease : Boolean;
    out result : SealedAppendageResult;
    constraint passCriteria {
      result.residualLeakWidth <= 5.0 and
      result.deviceCompression >= 8.0 and
      result.deviceCompression <= 20.0 and
      result.stableUnderTugTest == true
    }
  }

  action def RecaptureAndReposition {
    in implant : LAAOccluderImplant;
    in deliverySystem : TranscatheterDeliverySystem;
    out repositioned : Boolean;
    attribute recaptureForce : Force_N;
    constraint recaptureLimit {
      recaptureForce <= 20.0
    }
  }

  action def ReleaseImplant {
    in implant : LAAOccluderImplant;
    in deliverySystem : TranscatheterDeliverySystem;
    out implantReleased : Boolean;
    constraint releaseCondition {
      implant.residualPeriDeviceLeak <= 5.0 and
      implant.compressionAfterDeployment >= 8.0 and
      implant.compressionAfterDeployment <= 20.0
    }
  }

  action def WithdrawDeliverySystem {
    in deliverySystem : TranscatheterDeliverySystem;
    in patient : PatientCardiacAnatomy;
    out vascularHemostasisAchieved : Boolean;
    attribute withdrawalTime : Time_min;
  }

  action def EndothelializeImplantSurface {
    in implant : LAAOccluderImplant;
    out healedImplant : LAAOccluderImplant;
    attribute healingDuration : Time_day = 45.0;
    constraint healingExpected {
      healingDuration >= 30.0 and healingDuration <= 180.0
    }
  }

  action def OccludeLeftAtrialAppendage {
    doc /* Primary high-level function: place a permanent occluding implant at the left atrial appendage ostium so blood-borne thrombus formed within the appendage is blocked from entering the left atrium and systemic circulation. */
    in patient : PatientCardiacAnatomy;
    in implant : LAAOccluderImplant;
    in deliverySystem : TranscatheterDeliverySystem;
    in imaging : ImagingAndGuidanceSubsystem;
    out sealedResult : SealedAppendageResult;

    action plan : PreProcedurePlanning;
    action access : EstablishVenousAndTransseptalAccess;
    action assess : AssessAppendage;
    action loadAdvance : LoadAndAdvanceImplant;
    action deploy : DeployImplant;
    action verify : VerifyPositionSealAndStability;
    action recaptureIfNeeded : RecaptureAndReposition;
    action release : ReleaseImplant;
    action withdraw : WithdrawDeliverySystem;
    action endothelialize : EndothelializeImplantSurface;

    flow patient to plan.patient;
    flow plan.selectedNominalDiameter to implant.nominalDiameter;
    flow patient to access.patient;
    flow deliverySystem to access.deliverySystem;
    flow patient to assess.patient;
    flow imaging to assess.imaging;
    flow implant to loadAdvance.implant;
    flow deliverySystem to loadAdvance.deliverySystem;
    flow implant to deploy.implant;
    flow patient to deploy.patient;
    flow deliverySystem to deploy.deliverySystem;
    flow deploy.deployedImplant to verify.implant;
    flow patient to verify.patient;
    flow imaging to verify.imaging;
    flow verify.result to sealedResult;
    flow deploy.deployedImplant to release.implant;
    flow deliverySystem to release.deliverySystem;
    flow deliverySystem to withdraw.deliverySystem;
    flow patient to withdraw.patient;
    flow deploy.deployedImplant to endothelialize.implant;
  }

  state def ImplantLifecycle {
    doc /* Lifecycle of the permanent occluder from sterile package through chronic healing. */
    state SterilePackaged;
    state FlushedAndLoaded;
    state AdvancedThroughSheath;
    state PositionedAtAppendageOstium;
    state PartiallyDeployed;
    state FullyDeployedAttached;
    state AssessmentPassed;
    state RecapturedForRepositioning;
    state ReleasedInAppendage;
    state AcuteMechanicalSeal;
    state ChronicEndothelialSeal;

    transition initial then SterilePackaged;
    transition prepare first SterilePackaged then FlushedAndLoaded;
    transition advance first FlushedAndLoaded then AdvancedThroughSheath;
    transition position first AdvancedThroughSheath then PositionedAtAppendageOstium;
    transition deployPartial first PositionedAtAppendageOstium then PartiallyDeployed;
    transition deployFull first PartiallyDeployed then FullyDeployedAttached;
    transition passAssessment first FullyDeployedAttached then AssessmentPassed;
    transition recapture first FullyDeployedAttached then RecapturedForRepositioning;
    transition repositionAgain first RecapturedForRepositioning then PositionedAtAppendageOstium;
    transition releaseDevice first AssessmentPassed then ReleasedInAppendage;
    transition establishSeal first ReleasedInAppendage then AcuteMechanicalSeal;
    transition tissueHealing first AcuteMechanicalSeal then ChronicEndothelialSeal;
  }

  state def ProcedureLifecycle {
    state Planning;
    state VenousAccess;
    state TransseptalCrossing;
    state AppendageMeasurement;
    state Delivery;
    state Deployment;
    state Verification;
    state Release;
    state Recovery;
    state FollowUp;

    transition initial then Planning;
    transition planned first Planning then VenousAccess;
    transition venousAccessObtained first VenousAccess then TransseptalCrossing;
    transition leftAtriumReached first TransseptalCrossing then AppendageMeasurement;
    transition deviceSelected first AppendageMeasurement then Delivery;
    transition deviceAtOstium first Delivery then Deployment;
    transition deployed first Deployment then Verification;
    transition acceptable first Verification then Release;
    transition released first Release then Recovery;
    transition discharged first Recovery then FollowUp;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall occlude the left atrial appendage at a high level by creating a stable barrier across the appendage ostium that prevents thrombus generated within the appendage from migrating into the left atrium and systemic arterial circulation. */
    subject laaoSystem : LeftAtrialAppendageOcclusionSystem;
    require constraint primaryFunctionSatisfied {
      laaoSystem.implant.sealStatus == SealStatusKind::hemodynamicallySealed or
      laaoSystem.implant.sealStatus == SealStatusKind::endothelialized
    }
  }

  requirement def ResidualLeakRequirement {
    doc /* After release, residual peri-device leak shall not exceed the clinically accepted threshold for effective appendage occlusion. */
    subject implant : LAAOccluderImplant;
    require constraint leakLimit {
      implant.residualPeriDeviceLeak <= 5.0
    }
  }

  requirement def ImplantCompressionRequirement {
    doc /* The deployed implant shall be compressed enough for fixation but not so much as to injure appendage tissue or deform the device. */
    subject implant : LAAOccluderImplant;
    require constraint compressionRange {
      implant.compressionAfterDeployment >= 8.0 and implant.compressionAfterDeployment <= 20.0
    }
  }

  requirement def StabilityRequirement {
    doc /* The implant shall remain stable during a controlled tug test and after release. */
    subject result : SealedAppendageResult;
    require constraint stability {
      result.stableUnderTugTest == true
    }
  }

  requirement def ThromboembolicProtectionRequirement {
    doc /* The occlusion barrier shall reduce escape of embolic material from the appendage to a negligible rate. */
    subject result : SealedAppendageResult;
    require constraint embolicEscapeLimit {
      result.embolicMaterialEscapeRate <= 0.1
    }
  }

  requirement def DeliveryCompatibilityRequirement {
    doc /* The delivery system shall deliver the selected implant through venous and transseptal access without introducing air and while maintaining hemostasis. */
    subject deliverySystem : TranscatheterDeliverySystem;
    require constraint deliverySafe {
      deliverySystem.sterileBarrierIntact == true and deliverySystem.airFreeLumen == true
    }
  }

  requirement def VisualizationRequirement {
    doc /* The system shall support imaging-based assessment of anatomy, implant position, compression, stability, and residual leak. */
    subject imaging : ImagingAndGuidanceSubsystem;
    require constraint visualizationAdequate {
      imaging.minimumVisualizationConfidence >= 80.0 and imaging.measuredResidualLeak <= 5.0
    }
  }

  requirement def HealingRequirement {
    doc /* The implant surface shall support tissue coverage that converts the acute mechanical seal into a chronic endothelialized seal. */
    subject implant : LAAOccluderImplant;
    require constraint endothelialization {
      implant.endothelializationTime <= 180.0
    }
  }

  part def LeftAtrialAppendageOcclusionSystem {
    doc /* System of implant, delivery equipment, imaging guidance, operator interaction, and patient cardiac interfaces whose primary function is left atrial appendage occlusion for reduction of thromboembolic stroke risk. */
    part patientAnatomy : PatientCardiacAnatomy;
    part implant : LAAOccluderImplant;
    part deliverySystem : TranscatheterDeliverySystem;
    part imaging : ImagingAndGuidanceSubsystem;
    part operator : ClinicalOperator;

    port operatorPort : OperatorCommandPort;
    port imagingPort : ImagingPort;
    port bloodSystemInterface : BloodPort;

    perform action primaryFunction : OccludeLeftAtrialAppendage;
    exhibit state procedureState : ProcedureLifecycle;
    exhibit state implantState : ImplantLifecycle;

    connection operatorToSystem connect operator.commandConsole to operatorPort;
    connection operatorToDelivery connect operator.commandConsole to deliverySystem.operatorInterface;
    connection operatorToImaging connect operator.commandConsole to imaging.operatorDisplay;
    connection imagingToPatient connect imaging.patientImaging to patientAnatomy.imagingInterface;
    connection venousAccess connect deliverySystem.venousAccessInterface to patientAnatomy.femoralVein.sheathEntry;
    connection transseptalAccess connect deliverySystem.transseptalInterface to patientAnatomy.interatrialSeptum.punctureSite;
    connection implantToDelivery connect deliverySystem.implantInterface to implant.deliveryInterface;
    connection implantAppendageSeal connect implant.appendageFace to patientAnatomy.leftAtrium.appendage.ostium;
    connection atrialBloodInterface connect patientAnatomy.leftAtrium.bloodInterface to bloodSystemInterface;

    attribute currentPhase : ProcedurePhaseKind = ProcedurePhaseKind::preProcedurePlanning;
    attribute intendedUseStrokeRiskReduction : Boolean = true;
    attribute acuteSealAchieved : Boolean;
    attribute longTermSealAchieved : Boolean;
    attribute procedureDuration : Time_min;
    attribute contrastVolumeUsed : Volume_mL;
    attribute residualLeakAfterRelease : Length_mm;
    attribute systemicThrombusEscapePrevented : Boolean;

    constraint primaryHighLevelFunction {
      intendedUseStrokeRiskReduction == true and
      residualLeakAfterRelease <= 5.0 and
      systemicThrombusEscapePrevented == true
    }

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
      subject laaoSystem = this;
    }

    requirement leakRequirement : ResidualLeakRequirement {
      subject implant = this.implant;
    }

    requirement compressionRequirement : ImplantCompressionRequirement {
      subject implant = this.implant;
    }

    requirement deliveryRequirement : DeliveryCompatibilityRequirement {
      subject deliverySystem = this.deliverySystem;
    }

    requirement visualizationRequirement : VisualizationRequirement {
      subject imaging = this.imaging;
    }

    requirement healingRequirement : HealingRequirement {
      subject implant = this.implant;
    }
  }

  part laaoSystemExample : LeftAtrialAppendageOcclusionSystem {
    attribute procedureDuration = 72.0;
    attribute contrastVolumeUsed = 85.0;
    attribute residualLeakAfterRelease = 2.0;
    attribute acuteSealAchieved = true;
    attribute longTermSealAchieved = false;
    attribute systemicThrombusEscapePrevented = true;

    part patientAnatomy {
      attribute baselineStrokeRiskScore = 4.0;
      attribute baselineBleedingRiskScore = 3.0;
      part leftAtrium {
        attribute meanPressure = 11.0;
        attribute appendageFlowRateBeforeOcclusion = 32.0;
        part appendage {
          attribute ostiumDiameter = 21.0;
          attribute landingZoneDiameter = 19.5;
          attribute depth = 31.0;
          attribute lobeCount = 2;
          attribute thrombusPresent = false;
          attribute spontaneousEchoContrast = 35.0;
        }
      }
      part interatrialSeptum {
        attribute punctureHeightFromMitralAnnulus = 42.0;
        attribute puncturePosteriorOffset = 12.0;
      }
      part femoralVein {
        attribute accessDiameter = 14.0;
        attribute hemostasisAchieved = true;
      }
    }

    part implant {
      attribute nominalDiameter = 24.0;
      attribute nominalLength = 18.0;
      attribute compressionAfterDeployment = 14.0;
      attribute residualPeriDeviceLeak = 2.0;
      attribute deviceEmbolized = false;
      attribute endothelializationTime = 45.0;
      attribute sealStatus = SealStatusKind::hemodynamicallySealed;
      part frame {
        attribute unconstrainedDiameter = 24.0;
        attribute deployedDiameter = 20.6;
        attribute strutThickness = 0.18;
        attribute radialForce = 2.1;
      }
      part membrane {
        attribute poreSize_um = 30.0;
        attribute membraneArea = 452.0;
        attribute permeabilityIndex = 2.0;
      }
      part anchors {
        attribute count = 10;
        attribute penetrationDepth = 1.2;
        attribute pulloutResistance = 8.0;
      }
      part hub {
        attribute hubHeight = 2.5;
        attribute threadEngaged = false;
        attribute radiopaqueMarkerVisible = true;
      }
    }

    part deliverySystem {
      attribute sterileBarrierIntact = true;
      attribute airFreeLumen = true;
      part sheath {
        attribute innerDiameter = 12.0;
        attribute workingLength = 750.0;
        attribute curveAngle = 45.0;
        attribute radiopaqueTipVisible = true;
      }
      part catheter {
        attribute outerDiameter = 10.0;
        attribute usableLength = 850.0;
        attribute deflectable = true;
      }
      part pushCable {
        attribute tensileCapacity = 30.0;
        attribute releaseTurnsRequired = 5.0;
        attribute connectedToImplant = false;
      }
      part valve {
        attribute leakRate_mL_per_min = 0.2;
      }
    }

    part imaging {
      attribute primaryModality = ImagingModalityKind::transesophagealEchocardiography;
      attribute secondaryModality = ImagingModalityKind::fluoroscopy;
      attribute minimumVisualizationConfidence = 92.0;
      attribute measuredOstiumDiameter = 21.0;
      attribute measuredLandingZoneDiameter = 19.5;
      attribute measuredResidualLeak = 2.0;
    }

    part operator {
      attribute trainedForLAAO = true;
      attribute procedureExperienceCount = 185;
      attribute radiationProtectionUsed = true;
    }
  }
}
