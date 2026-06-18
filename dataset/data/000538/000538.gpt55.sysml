package AutoclaveTapeHighLevelModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  /* Value and item definitions */

  attribute def TemperatureC :> ScalarValues::Real {
    doc "Temperature in degrees Celsius.";
  }

  attribute def PressureKPa :> ScalarValues::Real {
    doc "Absolute pressure in kilopascals.";
  }

  attribute def TimeMin :> ScalarValues::Real {
    doc "Elapsed time in minutes.";
  }

  attribute def RelativeHumidityPercent :> ScalarValues::Real {
    doc "Relative humidity percentage.";
  }

  attribute def SteamDose :> ScalarValues::Real {
    doc "Integrated exposure dose derived from steam contact, temperature, and time.";
  }

  attribute def AdhesionStrengthNPerCm :> ScalarValues::Real {
    doc "Peel adhesion strength in newtons per centimeter.";
  }

  attribute def OpticalContrastRatio :> ScalarValues::Real {
    doc "Contrast ratio between reacted indicator stripe and unreacted background.";
  }

  enum def IndicatorColor {
    enum UnexposedBeige;
    enum TransitioningTan;
    enum ExposedDarkBrown;
    enum OverexposedBlack;
    enum InvalidFaded;
  }

  enum def SterilizationCycleType {
    enum GravityDisplacement;
    enum PreVacuum;
    enum Flash;
    enum ExtendedWrappedLoad;
  }

  enum def TapeAssessment {
    enum NotProcessed;
    enum InProcess;
    enum ProcessedExposureIndicated;
    enum InsufficientExposure;
    enum AmbiguousUnreadable;
  }

  enum def AdhesionCondition {
    enum FullyAdhered;
    enum EdgeLifted;
    enum Detached;
  }

  item def SaturatedSteam {
    attribute temperature : TemperatureC;
    attribute pressure : PressureKPa;
    attribute relativeHumidity : RelativeHumidityPercent;
  }

  item def HeatFlux {
    attribute surfaceTemperature : TemperatureC;
    attribute exposureTime : TimeMin;
  }

  item def SterilizationExposure {
    attribute cycleType : SterilizationCycleType;
    attribute chamberTemperature : TemperatureC;
    attribute chamberPressure : PressureKPa;
    attribute humidity : RelativeHumidityPercent;
    attribute elapsedTime : TimeMin;
    attribute accumulatedDose : SteamDose;
  }

  item def VisualIndication {
    attribute observedColor : IndicatorColor;
    attribute contrast : OpticalContrastRatio;
    attribute assessment : TapeAssessment;
  }

  item def AttachmentLoad {
    attribute peelDemand : AdhesionStrengthNPerCm;
    attribute surfaceTemperature : TemperatureC;
    attribute exposureTime : TimeMin;
  }

  /* Port definitions */

  port def SteamExposurePort {
    in item steam : SaturatedSteam;
    in item heat : HeatFlux;
    in item exposure : SterilizationExposure;
  }

  port def IndicatorChemistryPort {
    in item exposure : SterilizationExposure;
    out item indication : VisualIndication;
  }

  port def VisualReadoutPort {
    out item indication : VisualIndication;
  }

  port def AdhesionPort {
    in item load : AttachmentLoad;
    out attribute condition : AdhesionCondition;
  }

  port def PackageSurfacePort {
    in item appliedTapeLoad : AttachmentLoad;
    out attribute acceptedAdhesion : AdhesionCondition;
  }

  port def OperatorObservationPort {
    in item indication : VisualIndication;
  }

  /* Part definitions */

  part def AutoclaveTapeSystem {
    doc "A chemical indicator adhesive tape used on wrapped packs or containers to provide a visible high-level indication that the package has been exposed to autoclave steam processing conditions.";

    attribute nominalActivationTemperature : TemperatureC = 121.0;
    attribute minimumActivationTime : TimeMin = 15.0;
    attribute nominalActivationDose : SteamDose = 100.0;
    attribute currentDose : SteamDose = 0.0;
    attribute currentColor : IndicatorColor = IndicatorColor::UnexposedBeige;
    attribute currentAssessment : TapeAssessment = TapeAssessment::NotProcessed;
    attribute adhesionCondition : AdhesionCondition = AdhesionCondition::FullyAdhered;

    port exposurePort : SteamExposurePort;
    port readoutPort : VisualReadoutPort;
    port attachmentPort : AdhesionPort;

    part backing : CrepePaperBacking;
    part adhesive : PressureSensitiveAdhesiveLayer;
    part indicatorPattern : ChemicalIndicatorStripePattern;
    part doseIntegrator : ExposureDoseIntegrator;
    part packageInterface : PackageAttachmentInterface;
    part userInterface : VisualUserInterface;

    connect exposurePort to backing.environmentPort;
    connect backing.transmittedExposurePort to indicatorPattern.exposureInputPort;
    connect indicatorPattern.indicationOutputPort to readoutPort;
    connect indicatorPattern.indicationOutputPort to userInterface.observationInputPort;
    connect exposurePort to doseIntegrator.exposureInputPort;
    connect doseIntegrator.doseOutputPort to indicatorPattern.doseInputPort;
    connect attachmentPort to adhesive.adhesionInputPort;
    connect adhesive.adhesionOutputPort to packageInterface.tapeSidePort;

    perform action indicateAutoclaveExposure : IndicateAutoclaveExposure {
      in exposureInput = exposurePort.exposure;
      in activationDose = nominalActivationDose;
      out visualResult = readoutPort.indication;
    }

    state behavior AutoclaveTapeLifecycle : AutoclaveTapeStateMachine {
      in exposure = exposurePort.exposure;
      in observedIndication = readoutPort.indication;
    }
  }

  part def CrepePaperBacking {
    doc "Porous heat-tolerant paper backing that carries adhesive and indicator stripes while allowing thermal exposure to reach the indicator chemistry.";

    attribute thicknessMm : ScalarValues::Real = 0.17;
    attribute maximumServiceTemperature : TemperatureC = 140.0;
    attribute steamPermeabilityIndex : ScalarValues::Real = 0.75;

    port environmentPort : SteamExposurePort;
    port transmittedExposurePort : SteamExposurePort;

    action transmitExposure : TransmitSteamHeat {
      in externalExposure = environmentPort.exposure;
      out internalExposure = transmittedExposurePort.exposure;
    }
  }

  part def PressureSensitiveAdhesiveLayer {
    doc "Adhesive layer that holds the tape to sterilization wrap, paper, or metal container surfaces during steam exposure.";

    attribute roomTemperaturePeelStrength : AdhesionStrengthNPerCm = 2.4;
    attribute hotWetMinimumPeelStrength : AdhesionStrengthNPerCm = 0.8;
    attribute maximumResidueRating : ScalarValues::Real = 1.0;
    attribute condition : AdhesionCondition = AdhesionCondition::FullyAdhered;

    port adhesionInputPort : AdhesionPort;
    port adhesionOutputPort : PackageSurfacePort;

    action maintainAttachment : MaintainAttachmentDuringCycle {
      in load = adhesionInputPort.load;
      out condition = adhesionOutputPort.acceptedAdhesion;
    }
  }

  part def ChemicalIndicatorStripePattern {
    doc "Printed chemical indicator stripes that irreversibly darken after sufficient saturated-steam exposure.";

    attribute initialColor : IndicatorColor = IndicatorColor::UnexposedBeige;
    attribute activatedColor : IndicatorColor = IndicatorColor::ExposedDarkBrown;
    attribute minimumReadableContrast : OpticalContrastRatio = 3.0;
    attribute activationTemperature : TemperatureC = 121.0;
    attribute activationTime : TimeMin = 15.0;
    attribute activationDose : SteamDose = 100.0;
    attribute actualColor : IndicatorColor = IndicatorColor::UnexposedBeige;
    attribute actualContrast : OpticalContrastRatio = 1.0;
    attribute assessment : TapeAssessment = TapeAssessment::NotProcessed;

    port exposureInputPort : IndicatorChemistryPort;
    port doseInputPort : IndicatorChemistryPort;
    port indicationOutputPort : VisualReadoutPort;

    perform action chemistryReaction : ReactIndicatorChemistry {
      in exposure = exposureInputPort.exposure;
      in doseThreshold = activationDose;
      out indication = indicationOutputPort.indication;
    }

    state behavior IndicatorChemistryStates : IndicatorStateMachine {
      in exposure = exposureInputPort.exposure;
      out indication = indicationOutputPort.indication;
    }
  }

  part def ExposureDoseIntegrator {
    doc "Logical model element that integrates temperature, humidity, pressure, and exposure time into a single activation dose.";

    attribute minimumSteamHumidity : RelativeHumidityPercent = 95.0;
    attribute referenceTemperature : TemperatureC = 121.0;
    attribute referenceTime : TimeMin = 15.0;
    attribute calculatedDose : SteamDose = 0.0;

    port exposureInputPort : SteamExposurePort;
    port doseOutputPort : IndicatorChemistryPort;

    action integrateDose : IntegrateSterilizationExposure {
      in exposure = exposureInputPort.exposure;
      out dose = doseOutputPort.exposure.accumulatedDose;
    }
  }

  part def PackageAttachmentInterface {
    doc "Interface between the adhesive tape and the wrapped load or container surface.";

    attribute compatibleWithCelluloseWrap : ScalarValues::Boolean = true;
    attribute compatibleWithMetalContainer : ScalarValues::Boolean = true;
    attribute acceptedAdhesionCondition : AdhesionCondition = AdhesionCondition::FullyAdhered;

    port tapeSidePort : PackageSurfacePort;
    port packageSidePort : PackageSurfacePort;
  }

  part def VisualUserInterface {
    doc "Human-readable visual output area on the tape where the operator observes the color change.";

    attribute requiredViewingDistanceCm : ScalarValues::Real = 50.0;
    attribute minimumAmbientIlluminanceLux : ScalarValues::Real = 300.0;

    port observationInputPort : OperatorObservationPort;

    action interpretTape : InterpretVisualIndicator {
      in indication = observationInputPort.indication;
    }
  }

  part def AutoclaveChamber {
    doc "External environment that supplies saturated steam, pressure, heat, and exposure duration to the tape.";

    attribute setPointTemperature : TemperatureC = 121.0;
    attribute setPointPressure : PressureKPa = 205.0;
    attribute cycleHoldTime : TimeMin = 15.0;
    attribute humidity : RelativeHumidityPercent = 100.0;
    attribute cycleType : SterilizationCycleType = SterilizationCycleType::GravityDisplacement;

    port chamberExposurePort : SteamExposurePort;

    action runCycle : RunAutoclaveCycle {
      out deliveredExposure = chamberExposurePort.exposure;
    }
  }

  part def WrappedInstrumentPack {
    doc "Representative load to which autoclave tape is applied.";

    attribute packIdentifier : ScalarValues::String = "Wrapped surgical instrument pack";
    attribute surfaceTemperature : TemperatureC = 22.0;
    attribute surfaceIsDryBeforeApplication : ScalarValues::Boolean = true;

    port surfacePort : PackageSurfacePort;
  }

  part def Operator {
    doc "Person who reads the tape after processing and uses the indication as evidence of exposure, not as proof of sterility.";

    port observationPort : OperatorObservationPort;

    action observeAndClassify : InterpretVisualIndicator;
  }

  part def AutoclaveTapeUseContext {
    doc "Operational context showing tape applied to a wrapped pack and exposed in an autoclave.";

    part tape : AutoclaveTapeSystem;
    part chamber : AutoclaveChamber;
    part pack : WrappedInstrumentPack;
    part operator : Operator;

    connect chamber.chamberExposurePort to tape.exposurePort;
    connect tape.attachmentPort to pack.surfacePort;
    connect tape.readoutPort to operator.observationPort;
  }

  /* Action definitions */

  action def RunAutoclaveCycle {
    doc "Generate a sterilization exposure profile representative of a saturated-steam autoclave cycle.";

    out item deliveredExposure : SterilizationExposure;

    attribute targetTemperature : TemperatureC = 121.0;
    attribute targetPressure : PressureKPa = 205.0;
    attribute holdTime : TimeMin = 15.0;
    attribute targetHumidity : RelativeHumidityPercent = 100.0;

    first start;
    then heatChamber;
    then admitSaturatedSteam;
    then holdAtSterilizationCondition;
    then exhaustAndDry;
    then provideExposure;

    action heatChamber {
      out attribute temperature : TemperatureC;
    }

    action admitSaturatedSteam {
      out attribute humidity : RelativeHumidityPercent;
      out attribute pressure : PressureKPa;
    }

    action holdAtSterilizationCondition {
      in attribute temperature : TemperatureC;
      in attribute pressure : PressureKPa;
      in attribute humidity : RelativeHumidityPercent;
      out attribute elapsedTime : TimeMin;
    }

    action exhaustAndDry {
      out attribute finalPressure : PressureKPa;
    }

    action provideExposure {
      out item deliveredExposure : SterilizationExposure;
    }

    flow heatChamber.temperature to holdAtSterilizationCondition.temperature;
    flow admitSaturatedSteam.pressure to holdAtSterilizationCondition.pressure;
    flow admitSaturatedSteam.humidity to holdAtSterilizationCondition.humidity;
    flow holdAtSterilizationCondition.elapsedTime to provideExposure.deliveredExposure.elapsedTime;
  }

  action def TransmitSteamHeat {
    doc "Transmit thermal and moisture exposure through the paper backing toward the indicator chemistry.";

    in item externalExposure : SterilizationExposure;
    out item internalExposure : SterilizationExposure;

    attribute attenuationFactor : ScalarValues::Real = 0.95;

    first receiveExternalExposure;
    then conductHeatThroughBacking;
    then passMoistureToIndicator;
    then outputInternalExposure;

    action receiveExternalExposure {
      in item exposure : SterilizationExposure;
    }

    action conductHeatThroughBacking {
      in item exposure : SterilizationExposure;
      out attribute transmittedTemperature : TemperatureC;
    }

    action passMoistureToIndicator {
      in item exposure : SterilizationExposure;
      out attribute transmittedHumidity : RelativeHumidityPercent;
    }

    action outputInternalExposure {
      out item internalExposure : SterilizationExposure;
    }

    flow receiveExternalExposure.exposure to conductHeatThroughBacking.exposure;
    flow receiveExternalExposure.exposure to passMoistureToIndicator.exposure;
    flow conductHeatThroughBacking.transmittedTemperature to outputInternalExposure.internalExposure.chamberTemperature;
    flow passMoistureToIndicator.transmittedHumidity to outputInternalExposure.internalExposure.humidity;
  }

  action def IntegrateSterilizationExposure {
    doc "Compute indicator exposure dose from time above activation temperature in saturated steam.";

    in item exposure : SterilizationExposure;
    out attribute dose : SteamDose;

    attribute activationTemperature : TemperatureC = 121.0;
    attribute humidityRequirement : RelativeHumidityPercent = 95.0;

    first receiveExposure;
    then verifySteamCondition;
    then accumulateTemperatureTimeDose;
    then outputDose;

    action receiveExposure {
      in item exposure : SterilizationExposure;
    }

    action verifySteamCondition {
      in item exposure : SterilizationExposure;
      out attribute steamValid : ScalarValues::Boolean;
    }

    action accumulateTemperatureTimeDose {
      in attribute steamValid : ScalarValues::Boolean;
      in item exposure : SterilizationExposure;
      out attribute dose : SteamDose;
    }

    action outputDose {
      in attribute dose : SteamDose;
      out attribute integratedDose : SteamDose;
    }

    flow receiveExposure.exposure to verifySteamCondition.exposure;
    flow receiveExposure.exposure to accumulateTemperatureTimeDose.exposure;
    flow verifySteamCondition.steamValid to accumulateTemperatureTimeDose.steamValid;
    flow accumulateTemperatureTimeDose.dose to outputDose.dose;
    flow outputDose.integratedDose to dose;
  }

  action def ReactIndicatorChemistry {
    doc "Irreversibly change indicator stripe color when exposure dose reaches the activation threshold.";

    in item exposure : SterilizationExposure;
    in attribute doseThreshold : SteamDose;
    out item indication : VisualIndication;

    first senseExposure;
    then compareDoseWithThreshold;
    then transformReactivePigment;
    then generateVisualIndication;

    action senseExposure {
      in item exposure : SterilizationExposure;
      out attribute measuredDose : SteamDose;
    }

    action compareDoseWithThreshold {
      in attribute measuredDose : SteamDose;
      in attribute threshold : SteamDose;
      out attribute activated : ScalarValues::Boolean;
    }

    action transformReactivePigment {
      in attribute activated : ScalarValues::Boolean;
      out attribute color : IndicatorColor;
      out attribute contrast : OpticalContrastRatio;
    }

    action generateVisualIndication {
      in attribute color : IndicatorColor;
      in attribute contrast : OpticalContrastRatio;
      out item indication : VisualIndication;
    }

    flow senseExposure.measuredDose to compareDoseWithThreshold.measuredDose;
    flow doseThreshold to compareDoseWithThreshold.threshold;
    flow compareDoseWithThreshold.activated to transformReactivePigment.activated;
    flow transformReactivePigment.color to generateVisualIndication.color;
    flow transformReactivePigment.contrast to generateVisualIndication.contrast;
    flow generateVisualIndication.indication to indication;
  }

  action def MaintainAttachmentDuringCycle {
    doc "Maintain sufficient adhesion to keep the tape in place during heating, steam exposure, and drying.";

    in item load : AttachmentLoad;
    out attribute condition : AdhesionCondition;

    first applyToPackageSurface;
    then resistSteamAndHeat;
    then resistPeelForces;
    then reportAdhesionCondition;

    action applyToPackageSurface {
      out attribute initialCondition : AdhesionCondition;
    }

    action resistSteamAndHeat {
      in item load : AttachmentLoad;
      out attribute hotWetCondition : AdhesionCondition;
    }

    action resistPeelForces {
      in attribute hotWetCondition : AdhesionCondition;
      out attribute finalCondition : AdhesionCondition;
    }

    action reportAdhesionCondition {
      in attribute finalCondition : AdhesionCondition;
      out attribute condition : AdhesionCondition;
    }

    flow resistSteamAndHeat.hotWetCondition to resistPeelForces.hotWetCondition;
    flow resistPeelForces.finalCondition to reportAdhesionCondition.finalCondition;
    flow reportAdhesionCondition.condition to condition;
  }

  action def InterpretVisualIndicator {
    doc "Classify the processed tape by observing the final stripe color and contrast.";

    in item indication : VisualIndication;
    out attribute classification : TapeAssessment;

    first viewTape;
    then compareStripeToReference;
    then classifyExposureIndication;

    action viewTape {
      in item indication : VisualIndication;
      out attribute observedColor : IndicatorColor;
      out attribute observedContrast : OpticalContrastRatio;
    }

    action compareStripeToReference {
      in attribute observedColor : IndicatorColor;
      in attribute observedContrast : OpticalContrastRatio;
      out attribute readable : ScalarValues::Boolean;
    }

    action classifyExposureIndication {
      in attribute readable : ScalarValues::Boolean;
      in attribute observedColor : IndicatorColor;
      out attribute classification : TapeAssessment;
    }

    flow viewTape.observedColor to compareStripeToReference.observedColor;
    flow viewTape.observedContrast to compareStripeToReference.observedContrast;
    flow compareStripeToReference.readable to classifyExposureIndication.readable;
    flow viewTape.observedColor to classifyExposureIndication.observedColor;
    flow classifyExposureIndication.classification to classification;
  }

  action def IndicateAutoclaveExposure {
    doc "Primary function: provide a visible indication that the taped item has been exposed to sufficient autoclave steam conditions.";

    in item exposureInput : SterilizationExposure;
    in attribute activationDose : SteamDose;
    out item visualResult : VisualIndication;

    first receiveSteamExposure;
    then integrateExposureDose;
    then activateIndicatorChemistry;
    then presentVisibleResult;

    action receiveSteamExposure {
      in item exposure : SterilizationExposure;
      out item acceptedExposure : SterilizationExposure;
    }

    action integrateExposureDose {
      in item exposure : SterilizationExposure;
      out attribute dose : SteamDose;
    }

    action activateIndicatorChemistry {
      in attribute dose : SteamDose;
      in attribute threshold : SteamDose;
      out attribute color : IndicatorColor;
      out attribute contrast : OpticalContrastRatio;
    }

    action presentVisibleResult {
      in attribute color : IndicatorColor;
      in attribute contrast : OpticalContrastRatio;
      out item visualResult : VisualIndication;
    }

    flow exposureInput to receiveSteamExposure.exposure;
    flow receiveSteamExposure.acceptedExposure to integrateExposureDose.exposure;
    flow integrateExposureDose.dose to activateIndicatorChemistry.dose;
    flow activationDose to activateIndicatorChemistry.threshold;
    flow activateIndicatorChemistry.color to presentVisibleResult.color;
    flow activateIndicatorChemistry.contrast to presentVisibleResult.contrast;
    flow presentVisibleResult.visualResult to visualResult;
  }

  /* State machines */

  state def AutoclaveTapeStateMachine {
    doc "Lifecycle states of the tape from application through operator reading.";

    in item exposure : SterilizationExposure;
    in item observedIndication : VisualIndication;

    state Unapplied {
      entry action {
        out attribute condition : AdhesionCondition = AdhesionCondition::Detached;
      }
    }

    state Applied {
      entry action {
        out attribute condition : AdhesionCondition = AdhesionCondition::FullyAdhered;
      }
    }

    state Heating {
      entry action {
        out attribute assessment : TapeAssessment = TapeAssessment::InProcess;
      }
    }

    state SteamExposureAccumulating {
      entry action {
        out attribute assessment : TapeAssessment = TapeAssessment::InProcess;
      }
    }

    state ExposureIndicated {
      entry action {
        out attribute assessment : TapeAssessment = TapeAssessment::ProcessedExposureIndicated;
      }
    }

    state InsufficientExposure {
      entry action {
        out attribute assessment : TapeAssessment = TapeAssessment::InsufficientExposure;
      }
    }

    state ReadAndArchived {
      entry action {
        out attribute archived : ScalarValues::Boolean = true;
      }
    }

    transition applyTape first Unapplied then Applied;
    transition startCycle first Applied then Heating;
    transition reachSteamCondition first Heating then SteamExposureAccumulating
      if exposure.chamberTemperature >= 121.0 and exposure.humidity >= 95.0;
    transition sufficientDose first SteamExposureAccumulating then ExposureIndicated
      if exposure.accumulatedDose >= 100.0;
    transition cycleEndsEarly first SteamExposureAccumulating then InsufficientExposure
      if exposure.accumulatedDose < 100.0;
    transition operatorReadsAccepted first ExposureIndicated then ReadAndArchived;
    transition operatorReadsRejected first InsufficientExposure then ReadAndArchived;
  }

  state def IndicatorStateMachine {
    doc "Chemical indicator color-transition behavior.";

    in item exposure : SterilizationExposure;
    out item indication : VisualIndication;

    state Unreacted {
      entry action {
        out attribute color : IndicatorColor = IndicatorColor::UnexposedBeige;
        out attribute assessment : TapeAssessment = TapeAssessment::NotProcessed;
      }
    }

    state Warming {
      entry action {
        out attribute color : IndicatorColor = IndicatorColor::TransitioningTan;
        out attribute assessment : TapeAssessment = TapeAssessment::InProcess;
      }
    }

    state Reacting {
      entry action {
        out attribute color : IndicatorColor = IndicatorColor::TransitioningTan;
        out attribute assessment : TapeAssessment = TapeAssessment::InProcess;
      }
    }

    state FullyReacted {
      entry action {
        out attribute color : IndicatorColor = IndicatorColor::ExposedDarkBrown;
        out attribute contrast : OpticalContrastRatio = 3.5;
        out attribute assessment : TapeAssessment = TapeAssessment::ProcessedExposureIndicated;
      }
    }

    state Unreadable {
      entry action {
        out attribute color : IndicatorColor = IndicatorColor::InvalidFaded;
        out attribute assessment : TapeAssessment = TapeAssessment::AmbiguousUnreadable;
      }
    }

    transition heatBegins first Unreacted then Warming
      if exposure.chamberTemperature > 60.0;
    transition validSteamBegins first Warming then Reacting
      if exposure.chamberTemperature >= 121.0 and exposure.humidity >= 95.0;
    transition thresholdReached first Reacting then FullyReacted
      if exposure.accumulatedDose >= 100.0;
    transition excessiveExposure first FullyReacted then Unreadable
      if exposure.chamberTemperature > 140.0;
  }

  /* Requirements */

  requirement def PrimaryFunctionRequirement {
    doc "The autoclave tape shall provide a visible high-level indication that the taped item has been exposed to autoclave steam processing conditions.";
    subject tape : AutoclaveTapeSystem;

    require constraint {
      tape.readoutPort.indication.assessment == TapeAssessment::ProcessedExposureIndicated
      implies tape.readoutPort.indication.observedColor == IndicatorColor::ExposedDarkBrown
    }
  }

  requirement def ActivationRequirement {
    doc "The indicator stripes shall visibly change from unexposed beige to dark brown after receiving at least the activation dose at saturated-steam conditions of 121 degrees Celsius for 15 minutes.";
    subject tape : AutoclaveTapeSystem;

    require constraint {
      tape.exposurePort.exposure.chamberTemperature >= 121.0 and
      tape.exposurePort.exposure.humidity >= 95.0 and
      tape.exposurePort.exposure.elapsedTime >= 15.0 and
      tape.exposurePort.exposure.accumulatedDose >= tape.nominalActivationDose
      implies tape.readoutPort.indication.observedColor == IndicatorColor::ExposedDarkBrown
    }
  }

  requirement def NonSterilityProofRequirement {
    doc "The tape indication shall represent exposure to process conditions and shall not by itself assert biological sterility of the load.";
    subject tape : AutoclaveTapeSystem;

    require constraint {
      tape.readoutPort.indication.assessment == TapeAssessment::ProcessedExposureIndicated
      implies tape.currentAssessment != TapeAssessment::AmbiguousUnreadable
    }
  }

  requirement def ReadabilityRequirement {
    doc "After sufficient exposure, the indicator pattern shall provide a minimum optical contrast ratio for unaided operator reading at normal workbench illumination.";
    subject tape : AutoclaveTapeSystem;

    require constraint {
      tape.exposurePort.exposure.accumulatedDose >= tape.nominalActivationDose
      implies tape.readoutPort.indication.contrast >= 3.0
    }
  }

  requirement def AdhesionRequirement {
    doc "The adhesive layer shall keep the tape attached to the package surface throughout the steam cycle and drying phase.";
    subject tape : AutoclaveTapeSystem;

    require constraint {
      tape.adhesionCondition == AdhesionCondition::FullyAdhered or
      tape.adhesionCondition == AdhesionCondition::EdgeLifted
    }
  }

  requirement def TemperatureToleranceRequirement {
    doc "The backing and indicator chemistry shall tolerate normal autoclave cycle temperatures without becoming unreadable.";
    subject tape : AutoclaveTapeSystem;

    require constraint {
      tape.exposurePort.exposure.chamberTemperature <= 140.0
      implies tape.readoutPort.indication.assessment != TapeAssessment::AmbiguousUnreadable
    }
  }

  requirement def InsufficientExposureRequirement {
    doc "If the tape is not exposed to sufficient steam dose, it shall not present the accepted dark-brown processed indication.";
    subject tape : AutoclaveTapeSystem;

    require constraint {
      tape.exposurePort.exposure.accumulatedDose < tape.nominalActivationDose
      implies tape.readoutPort.indication.assessment != TapeAssessment::ProcessedExposureIndicated
    }
  }

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject tape = AutoclaveTapeUseContext::tape;
  }

  requirement activationPerformance : ActivationRequirement {
    subject tape = AutoclaveTapeUseContext::tape;
  }

  requirement exposureOnlyClaim : NonSterilityProofRequirement {
    subject tape = AutoclaveTapeUseContext::tape;
  }

  requirement visualReadability : ReadabilityRequirement {
    subject tape = AutoclaveTapeUseContext::tape;
  }

  requirement adhesionDuringCycle : AdhesionRequirement {
    subject tape = AutoclaveTapeUseContext::tape;
  }

  requirement thermalCompatibility : TemperatureToleranceRequirement {
    subject tape = AutoclaveTapeUseContext::tape;
  }

  requirement insufficientExposurePrevention : InsufficientExposureRequirement {
    subject tape = AutoclaveTapeUseContext::tape;
  }

}
