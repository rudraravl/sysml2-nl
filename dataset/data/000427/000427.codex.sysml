package AuricularSplintSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Millimeter :> Length;
  attribute def Gram :> Mass;
  attribute def Newton :> Force;
  attribute def DegreeCelsius :> Temperature;
  attribute def Hour :> Time;
  attribute def Percent :> Real;

  enum def SplintStateKind {
    enum idle;
    enum positioned;
    enum stabilized;
    enum monitoring;
    enum removalReady;
    enum removed;
  }

  enum def SkinConditionKind {
    enum normal;
    enum mildRedness;
    enum pressureMark;
    enum irritation;
    enum compromised;
  }

  item def AuricleContactLoad {
    attribute distributedForce : Newton;
    attribute contactArea : Millimeter^2;
    attribute pressureUniformity : Percent;
  }

  item def SkinStatus {
    attribute condition : SkinConditionKind;
    attribute localTemperature : DegreeCelsius;
    attribute moistureLevel : Percent;
    attribute rednessIndex : Percent;
  }

  item def ClinicalInstruction {
    attribute prescribedWearDuration : Hour;
    attribute inspectionInterval : Hour;
    attribute maximumAllowedRedness : Percent;
    attribute removalAuthorized : Boolean;
  }

  item def AdjustmentCommand {
    attribute targetRetentionForce : Newton;
    attribute targetHelixOffset : Millimeter;
    attribute targetAntihelixSupportHeight : Millimeter;
  }

  port def AuricleSupportPort {
    out load : AuricleContactLoad;
    in skinStatus : SkinStatus;
  }

  port def ClinicianInterfacePort {
    in instruction : ClinicalInstruction;
    in adjustment : AdjustmentCommand;
    out status : SplintStatus;
  }

  port def CaregiverInterfacePort {
    out dailyStatus : SplintStatus;
    in removalRequest : Boolean;
  }

  port def VentilationPort {
    in ambientAirTemperature : DegreeCelsius;
    out evaporatedMoistureRate : Percent;
  }

  item def SplintStatus {
    attribute state : SplintStateKind;
    attribute elapsedWearTime : Hour;
    attribute retentionForce : Newton;
    attribute skinCondition : SkinConditionKind;
    attribute fitAcceptable : Boolean;
  }

  part def AuricularSplintSystem {
    attribute primaryFunction : String = "Maintain the external ear in a clinically intended contour by applying gentle, distributed, adjustable support to auricular cartilage while protecting skin and enabling periodic inspection.";
    attribute prescribedWearDuration : Hour = 336 [Hour];
    attribute currentWearTime : Hour = 0 [Hour];
    attribute targetRetentionForce : Newton = 0.35 [Newton];
    attribute maximumRetentionForce : Newton = 0.80 [Newton];
    attribute maximumSkinRedness : Percent = 30.0 [Percent];

    port supportedAuricle : AuricleSupportPort;
    port clinicianInterface : ClinicianInterfacePort;
    port caregiverInterface : CaregiverInterfacePort;
    port ventilation : VentilationPort;

    part splintFrame : ConformingFrame;
    part helixSupport : HelixSupportRim;
    part antihelixSupport : AntihelixFormingPad;
    part conchalRelief : ConchalReliefRegion;
    part retentionBand : RetentionBand;
    part skinContactLayer : BiocompatibleContactLayer;
    part adjustmentFeature : AdjustmentFeature;
    part inspectionWindow : InspectionWindow;
    part monitoringLogic : SplintMonitoringLogic;

    connect splintFrame.frameLoadPort to supportedAuricle;
    connect helixSupport.helixLoadPort to supportedAuricle;
    connect antihelixSupport.antihelixLoadPort to supportedAuricle;
    connect skinContactLayer.skinSensingPort to supportedAuricle;
    connect monitoringLogic.clinicianPort to clinicianInterface;
    connect monitoringLogic.caregiverPort to caregiverInterface;
    connect conchalRelief.airPort to ventilation;
    connect inspectionWindow.airPort to ventilation;
    connect adjustmentFeature.commandPort to clinicianInterface;

    action applySplint {
      in instruction : ClinicalInstruction;
      in adjustment : AdjustmentCommand;
      out status : SplintStatus;

      first start;
      then positionFrame;
      then alignHelixSupport;
      then alignAntihelixSupport;
      then setRetentionForce;
      then verifySkinClearance;
      then reportPositioned;

      action start;
      action positionFrame {
        out frameOffset : Millimeter;
      }
      action alignHelixSupport {
        in frameOffset : Millimeter;
        out helixOffset : Millimeter;
      }
      action alignAntihelixSupport {
        out antihelixHeight : Millimeter;
      }
      action setRetentionForce {
        in targetForce : Newton;
        out actualForce : Newton;
      }
      action verifySkinClearance {
        in actualForce : Newton;
        out fitAcceptable : Boolean;
      }
      action reportPositioned {
        in fitAcceptable : Boolean;
        out status : SplintStatus;
      }
    }

    action inspectSplint {
      in skinStatus : SkinStatus;
      in elapsedWearTime : Hour;
      out status : SplintStatus;

      first readSkinStatus;
      then evaluatePressure;
      then evaluateWearDuration;
      then determineDisposition;

      action readSkinStatus {
        out observedCondition : SkinConditionKind;
        out rednessIndex : Percent;
      }
      action evaluatePressure {
        in rednessIndex : Percent;
        out pressureAcceptable : Boolean;
      }
      action evaluateWearDuration {
        in elapsedWearTime : Hour;
        out durationComplete : Boolean;
      }
      action determineDisposition {
        in pressureAcceptable : Boolean;
        in durationComplete : Boolean;
        out status : SplintStatus;
      }
    }

    state def SplintLifecycle {
      entry action initializeStatus;

      state idle;
      state positioned;
      state stabilized;
      state monitoring;
      state removalReady;
      state removed;

      transition first idle;
      transition idle_to_positioned
        first idle
        then positioned
        accept ClinicalInstruction
        do applySplint;

      transition positioned_to_stabilized
        first positioned
        then stabilized
        if monitoringLogic.fitAcceptable == true;

      transition stabilized_to_monitoring
        first stabilized
        then monitoring
        after 1 [Hour];

      transition monitoring_to_stabilized
        first monitoring
        then stabilized
        if monitoringLogic.skinCondition != SkinConditionKind::compromised
        do inspectSplint;

      transition monitoring_to_removalReady
        first monitoring
        then removalReady
        if currentWearTime >= prescribedWearDuration or monitoringLogic.skinCondition == SkinConditionKind::compromised;

      transition removalReady_to_removed
        first removalReady
        then removed
        accept caregiverInterface::removalRequest;
    }

    perform applySplint;
    perform inspectSplint;
    exhibit state SplintLifecycle;
  }

  part def ConformingFrame {
    attribute frameThickness : Millimeter = 1.2 [Millimeter];
    attribute frameWidth : Millimeter = 7.0 [Millimeter];
    attribute frameMass : Gram = 2.8 [Gram];
    attribute curvatureRadius : Millimeter = 18.0 [Millimeter];
    attribute materialElasticModulus : Real = 2.4;

    port frameLoadPort : AuricleSupportPort;
  }

  part def HelixSupportRim {
    attribute helixChannelWidth : Millimeter = 4.0 [Millimeter];
    attribute supportArcLength : Millimeter = 42.0 [Millimeter];
    attribute nominalContactForce : Newton = 0.18 [Newton];

    port helixLoadPort : AuricleSupportPort;
  }

  part def AntihelixFormingPad {
    attribute padHeight : Millimeter = 5.5 [Millimeter];
    attribute padWidth : Millimeter = 8.0 [Millimeter];
    attribute padCompliance : Real = 0.65;
    attribute nominalContactForce : Newton = 0.12 [Newton];

    port antihelixLoadPort : AuricleSupportPort;
  }

  part def ConchalReliefRegion {
    attribute reliefDepth : Millimeter = 3.0 [Millimeter];
    attribute minimumVentGap : Millimeter = 1.5 [Millimeter];

    port airPort : VentilationPort;
  }

  part def RetentionBand {
    attribute bandWidth : Millimeter = 6.0 [Millimeter];
    attribute adjustableLength : Millimeter = 65.0 [Millimeter];
    attribute minimumRetentionForce : Newton = 0.15 [Newton];
    attribute maximumRetentionForce : Newton = 0.80 [Newton];
  }

  part def BiocompatibleContactLayer {
    attribute layerThickness : Millimeter = 0.8 [Millimeter];
    attribute shoreHardness : Real = 20.0;
    attribute moisturePermeability : Percent = 55.0 [Percent];
    attribute hypoallergenic : Boolean = true;

    port skinSensingPort : AuricleSupportPort;
  }

  part def AdjustmentFeature {
    attribute forceIncrement : Newton = 0.05 [Newton];
    attribute positionIncrement : Millimeter = 0.5 [Millimeter];
    attribute locked : Boolean = true;

    port commandPort : ClinicianInterfacePort;

    action adjustFit {
      in command : AdjustmentCommand;
      out achievedRetentionForce : Newton;
      out achievedHelixOffset : Millimeter;
      out achievedAntihelixSupportHeight : Millimeter;
    }
  }

  part def InspectionWindow {
    attribute windowLength : Millimeter = 14.0 [Millimeter];
    attribute windowWidth : Millimeter = 6.0 [Millimeter];
    attribute permitsVisualInspection : Boolean = true;

    port airPort : VentilationPort;
  }

  part def SplintMonitoringLogic {
    attribute fitAcceptable : Boolean = false;
    attribute skinCondition : SkinConditionKind = SkinConditionKind::normal;
    attribute elapsedWearTime : Hour = 0 [Hour];
    attribute reportedRetentionForce : Newton = 0.0 [Newton];

    port clinicianPort : ClinicianInterfacePort;
    port caregiverPort : CaregiverInterfacePort;

    action computeFitStatus {
      in load : AuricleContactLoad;
      in skin : SkinStatus;
      in instruction : ClinicalInstruction;
      out status : SplintStatus;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The auricular splint system shall maintain the external ear in a prescribed anatomical contour by applying gentle distributed support to auricular cartilage. */
    attribute requiredWearDuration : Hour;
    attribute maximumSupportForce : Newton;
  }

  requirement def SkinProtectionRequirement {
    doc /* The auricular splint system shall limit localized pressure and permit inspection so that skin condition remains clinically acceptable during wear. */
    attribute maximumRednessIndex : Percent;
    attribute inspectionInterval : Hour;
  }

  requirement def AdjustabilityRequirement {
    doc /* The auricular splint system shall allow clinician-controlled adjustment of retention force and support geometry without replacing the complete splint. */
    attribute minimumForceIncrement : Newton;
    attribute minimumPositionIncrement : Millimeter;
  }

  requirement def VentilationRequirement {
    doc /* The auricular splint system shall provide relief openings and air paths to reduce moisture accumulation at the skin contact interface. */
    attribute minimumVentGap : Millimeter;
    attribute minimumMoisturePermeability : Percent;
  }

  requirement def RemovalRequirement {
    doc /* The auricular splint system shall support removal after completion of prescribed wear duration or when skin condition becomes compromised. */
    attribute removalAuthorized : Boolean;
  }

  requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
    requiredWearDuration = 336 [Hour];
    maximumSupportForce = 0.80 [Newton];
  }

  requirement skinProtectionRequirement : SkinProtectionRequirement {
    maximumRednessIndex = 30.0 [Percent];
    inspectionInterval = 8 [Hour];
  }

  requirement adjustabilityRequirement : AdjustabilityRequirement {
    minimumForceIncrement = 0.05 [Newton];
    minimumPositionIncrement = 0.5 [Millimeter];
  }

  requirement ventilationRequirement : VentilationRequirement {
    minimumVentGap = 1.5 [Millimeter];
    minimumMoisturePermeability = 50.0 [Percent];
  }

  requirement removalRequirement : RemovalRequirement {
    removalAuthorized = true;
  }

  part auricularSplintSystem : AuricularSplintSystem;

  satisfy primaryFunctionRequirement by auricularSplintSystem;
  satisfy skinProtectionRequirement by auricularSplintSystem.skinContactLayer;
  satisfy skinProtectionRequirement by auricularSplintSystem.inspectionWindow;
  satisfy adjustabilityRequirement by auricularSplintSystem.adjustmentFeature;
  satisfy ventilationRequirement by auricularSplintSystem.conchalRelief;
  satisfy ventilationRequirement by auricularSplintSystem.skinContactLayer;
  satisfy removalRequirement by auricularSplintSystem.monitoringLogic;

  constraint def ContactForceLimit {
    in actualForce : Newton;
    in maximumForce : Newton;
    actualForce <= maximumForce;
  }

  constraint def SkinRednessLimit {
    in rednessIndex : Percent;
    in maximumRedness : Percent;
    rednessIndex <= maximumRedness;
  }

  constraint def WearDurationComplete {
    in elapsedWearTime : Hour;
    in prescribedWearDuration : Hour;
    elapsedWearTime >= prescribedWearDuration;
  }

  assert constraint ContactForceLimit {
    actualForce = auricularSplintSystem.targetRetentionForce;
    maximumForce = auricularSplintSystem.maximumRetentionForce;
  }

  assert constraint SkinRednessLimit {
    rednessIndex = auricularSplintSystem.monitoringLogic.computeFitStatus::status.skinCondition == SkinConditionKind::normal ? 0.0 [Percent] : 30.0 [Percent];
    maximumRedness = auricularSplintSystem.maximumSkinRedness;
  }
}