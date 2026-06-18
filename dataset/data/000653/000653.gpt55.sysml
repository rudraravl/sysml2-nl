package UrologyInstrumentSystemModel {

  import ScalarValues::*;

  attribute def Millimetre {
    value : Real;
    unit : String = "mm";
  }

  attribute def Degree {
    value : Real;
    unit : String = "deg";
  }

  attribute def MillilitrePerMinute {
    value : Real;
    unit : String = "mL/min";
  }

  attribute def Watt {
    value : Real;
    unit : String = "W";
  }

  attribute def Newton {
    value : Real;
    unit : String = "N";
  }

  attribute def Second {
    value : Real;
    unit : String = "s";
  }

  attribute def Celsius {
    value : Real;
    unit : String = "degC";
  }

  attribute def Pressure_mmHg {
    value : Real;
    unit : String = "mmHg";
  }

  item def IrrigationFluid {
    attribute sterility : String;
    attribute temperature : Celsius;
    attribute flowRate : MillilitrePerMinute;
    attribute pressure : Pressure_mmHg;
  }

  item def Urine {
    attribute volumeFlow : MillilitrePerMinute;
    attribute colorDescription : String;
  }

  item def TissueSample {
    attribute sourceAnatomy : String;
    attribute sampleDiameter : Millimetre;
    attribute retrievalCondition : String;
  }

  item def StoneFragment {
    attribute maximumDiameter : Millimetre;
    attribute estimatedHardness : String;
  }

  item def OpticalImage {
    attribute fieldOfView : Degree;
    attribute resolutionDescription : String;
    attribute illuminationLevel : String;
  }

  item def ElectricalPower {
    attribute voltageDescription : String;
    attribute maximumPower : Watt;
  }

  item def MechanicalMotion {
    attribute axialTravel : Millimetre;
    attribute rotationAngle : Degree;
    attribute appliedForce : Newton;
  }

  item def LaserEnergy {
    attribute wavelengthDescription : String;
    attribute pulsePower : Watt;
    attribute pulseDuration : Second;
  }

  port def IrrigationInletPort {
    in item fluid : IrrigationFluid;
  }

  port def IrrigationOutletPort {
    out item fluid : IrrigationFluid;
  }

  port def DrainageInletPort {
    in item urine : Urine;
    in item fluid : IrrigationFluid;
    in item stoneFragment : StoneFragment;
  }

  port def DrainageOutletPort {
    out item urine : Urine;
    out item fluid : IrrigationFluid;
    out item stoneFragment : StoneFragment;
  }

  port def VisualizationPort {
    out item image : OpticalImage;
  }

  port def ImageInputPort {
    in item image : OpticalImage;
  }

  port def WorkingChannelPort {
    in item instrumentMotion : MechanicalMotion;
    out item tissueSample : TissueSample;
    out item stoneFragment : StoneFragment;
  }

  port def PowerInputPort {
    in item power : ElectricalPower;
  }

  port def PowerOutputPort {
    out item power : ElectricalPower;
  }

  port def LaserOutputPort {
    out item laser : LaserEnergy;
  }

  port def LaserInputPort {
    in item laser : LaserEnergy;
  }

  part def UrologyInstrumentSystem {
    attribute primaryFunction : String = "Provide controlled endoscopic access, visualization, irrigation, drainage, tissue manipulation, stone retrieval, and therapeutic energy delivery for diagnostic and operative procedures within the urinary tract.";
    attribute nominalOuterDiameter : Millimetre = (value = 7.5, unit = "mm");
    attribute maximumInsertionLength : Millimetre = (value = 430.0, unit = "mm");
    attribute maximumIrrigationPressure : Pressure_mmHg = (value = 100.0, unit = "mmHg");
    attribute maximumContinuousLaserPower : Watt = (value = 30.0, unit = "W");

    part cystoscope : Cystoscope;
    part ureteroscope : FlexibleUreteroscope;
    part resectoscope : Resectoscope;
    part irrigationPump : IrrigationPump;
    part suctionDrainageUnit : SuctionDrainageUnit;
    part cameraConsole : CameraConsole;
    part lightSource : EndoscopicLightSource;
    part laserGenerator : HolmiumLaserGenerator;
    part instrumentTray : UrologicInstrumentTray;
    part operatorInterface : OperatorInterface;

    port powerIn : PowerInputPort;
    port imageOut : VisualizationPort;
    port irrigationIn : IrrigationInletPort;
    port drainageOut : DrainageOutletPort;

    connect powerIn to cameraConsole.powerIn;
    connect powerIn to lightSource.powerIn;
    connect powerIn to irrigationPump.powerIn;
    connect powerIn to suctionDrainageUnit.powerIn;
    connect powerIn to laserGenerator.powerIn;

    connect irrigationPump.irrigationOut to cystoscope.irrigationIn;
    connect irrigationPump.irrigationOut to ureteroscope.irrigationIn;
    connect irrigationPump.irrigationOut to resectoscope.irrigationIn;

    connect cystoscope.drainageOut to suctionDrainageUnit.drainageIn;
    connect ureteroscope.drainageOut to suctionDrainageUnit.drainageIn;
    connect resectoscope.drainageOut to suctionDrainageUnit.drainageIn;
    connect suctionDrainageUnit.drainageOut to drainageOut;

    connect lightSource.lightPowerOut to cystoscope.lightIn;
    connect lightSource.lightPowerOut to ureteroscope.lightIn;
    connect lightSource.lightPowerOut to resectoscope.lightIn;

    connect cystoscope.imageOut to cameraConsole.imageIn;
    connect ureteroscope.imageOut to cameraConsole.imageIn;
    connect resectoscope.imageOut to cameraConsole.imageIn;
    connect cameraConsole.processedImageOut to imageOut;

    connect laserGenerator.laserOut to ureteroscope.laserIn;
    connect instrumentTray.biopsyForceps.toolInterface to cystoscope.workingChannel;
    connect instrumentTray.stoneBasket.toolInterface to ureteroscope.workingChannel;
    connect instrumentTray.resectionLoop.toolInterface to resectoscope.workingChannel;

    perform action conductUrologicProcedure : ConductUrologicProcedure;
    exhibit state systemOperationalState : UrologyInstrumentOperationalState;
  }

  part def Cystoscope {
    attribute intendedAnatomy : String = "Urethra and bladder";
    attribute sheathDiameter : Millimetre = (value = 6.7, unit = "mm");
    attribute viewingAngle : Degree = (value = 30.0, unit = "deg");
    attribute workingChannelDiameter : Millimetre = (value = 2.2, unit = "mm");
    attribute sterileReusableComponent : Boolean = true;

    port irrigationIn : IrrigationInletPort;
    port drainageOut : DrainageOutletPort;
    port imageOut : VisualizationPort;
    port lightIn : PowerInputPort;
    port workingChannel : WorkingChannelPort;

    perform action inspectBladder : VisualInspectUrinaryAnatomy;
  }

  part def FlexibleUreteroscope {
    attribute intendedAnatomy : String = "Ureter and renal collecting system";
    attribute distalTipDiameter : Millimetre = (value = 2.7, unit = "mm");
    attribute insertionLength : Millimetre = (value = 670.0, unit = "mm");
    attribute deflectionUp : Degree = (value = 270.0, unit = "deg");
    attribute deflectionDown : Degree = (value = 270.0, unit = "deg");
    attribute workingChannelDiameter : Millimetre = (value = 1.2, unit = "mm");

    port irrigationIn : IrrigationInletPort;
    port drainageOut : DrainageOutletPort;
    port imageOut : VisualizationPort;
    port lightIn : PowerInputPort;
    port workingChannel : WorkingChannelPort;
    port laserIn : LaserInputPort;

    perform action navigateUpperTract : NavigateUrinaryTract;
    perform action fragmentStone : FragmentUrinaryStone;
  }

  part def Resectoscope {
    attribute intendedAnatomy : String = "Bladder neck, prostate, and bladder lesions";
    attribute sheathDiameter : Millimetre = (value = 8.7, unit = "mm");
    attribute loopTravel : Millimetre = (value = 24.0, unit = "mm");
    attribute viewingAngle : Degree = (value = 12.0, unit = "deg");

    port irrigationIn : IrrigationInletPort;
    port drainageOut : DrainageOutletPort;
    port imageOut : VisualizationPort;
    port lightIn : PowerInputPort;
    port workingChannel : WorkingChannelPort;

    perform action resectTissue : ResectObstructingTissue;
  }

  part def IrrigationPump {
    attribute selectableFlowRate : MillilitrePerMinute = (value = 250.0, unit = "mL/min");
    attribute pressureLimit : Pressure_mmHg = (value = 100.0, unit = "mmHg");
    attribute fluidWarmingSetpoint : Celsius = (value = 37.0, unit = "degC");

    port powerIn : PowerInputPort;
    port irrigationOut : IrrigationOutletPort;

    perform action deliverIrrigation : DeliverIrrigationFluid;
  }

  part def SuctionDrainageUnit {
    attribute nominalVacuumPressure : Pressure_mmHg = (value = -120.0, unit = "mmHg");
    attribute collectionCanisterVolume : Millimetre = (value = 3000.0, unit = "mL");

    port powerIn : PowerInputPort;
    port drainageIn : DrainageInletPort;
    port drainageOut : DrainageOutletPort;

    perform action evacuateFluidAndFragments : EvacuateOperativeField;
  }

  part def CameraConsole {
    attribute videoFormat : String = "Full HD endoscopic video";
    attribute latency : Second = (value = 0.08, unit = "s");

    port powerIn : PowerInputPort;
    port imageIn : ImageInputPort;
    port processedImageOut : VisualizationPort;

    perform action processEndoscopicImage : ProcessEndoscopicImage;
  }

  part def EndoscopicLightSource {
    attribute illuminationType : String = "LED white light";
    attribute maximumOutputPower : Watt = (value = 80.0, unit = "W");
    attribute thermalCutoffTemperature : Celsius = (value = 45.0, unit = "degC");

    port powerIn : PowerInputPort;
    port lightPowerOut : PowerOutputPort;
  }

  part def HolmiumLaserGenerator {
    attribute clinicalUse : String = "Stone fragmentation and soft tissue incision";
    attribute maximumAveragePower : Watt = (value = 30.0, unit = "W");
    attribute wavelengthDescription : String = "Holmium:YAG near infrared";
    attribute pulseDuration : Second = (value = 0.00035, unit = "s");

    port powerIn : PowerInputPort;
    port laserOut : LaserOutputPort;

    perform action generateLaserPulses : GenerateTherapeuticLaserEnergy;
  }

  part def OperatorInterface {
    attribute displayMode : String = "Procedure status, image, irrigation pressure, laser readiness, and alarms";
    attribute alarmVolumeDescription : String = "Audible and visual clinical alarm";

    port imageIn : ImageInputPort;

    perform action presentStatus : PresentProcedureStatus;
  }

  part def UrologicInstrumentTray {
    part biopsyForceps : BiopsyForceps;
    part stoneBasket : StoneRetrievalBasket;
    part resectionLoop : ElectrosurgicalResectionLoop;
    part catheter : UrethralCatheter;
    part guidewire : HydrophilicGuidewire;
  }

  part def BiopsyForceps {
    attribute jawDiameter : Millimetre = (value = 1.8, unit = "mm");
    attribute usableLength : Millimetre = (value = 400.0, unit = "mm");
    attribute graspingForce : Newton = (value = 5.0, unit = "N");

    port toolInterface : WorkingChannelPort;

    perform action collectTissueSample : CollectBiopsySample;
  }

  part def StoneRetrievalBasket {
    attribute basketDiameterOpen : Millimetre = (value = 12.0, unit = "mm");
    attribute usableLength : Millimetre = (value = 900.0, unit = "mm");
    attribute wireCount : Integer = 4;

    port toolInterface : WorkingChannelPort;

    perform action captureStoneFragment : CaptureStoneFragment;
  }

  part def ElectrosurgicalResectionLoop {
    attribute loopWidth : Millimetre = (value = 6.0, unit = "mm");
    attribute loopTravel : Millimetre = (value = 24.0, unit = "mm");
    attribute appliedForceLimit : Newton = (value = 3.0, unit = "N");

    port toolInterface : WorkingChannelPort;
  }

  part def UrethralCatheter {
    attribute frenchSize : Integer = 18;
    attribute balloonVolume : Millimetre = (value = 10.0, unit = "mL");
    attribute drainageLumenDiameter : Millimetre = (value = 3.0, unit = "mm");
  }

  part def HydrophilicGuidewire {
    attribute diameter : Millimetre = (value = 0.89, unit = "mm");
    attribute length : Millimetre = (value = 1500.0, unit = "mm");
    attribute tipFlexibilityDescription : String = "Atraumatic flexible distal tip";
  }

  action def ConductUrologicProcedure {
    in item patientAnatomy : String;
    out item diagnosticImage : OpticalImage;
    out item retrievedTissue : TissueSample;
    out item removedStoneFragment : StoneFragment;

    first start;
    then prepareSterileField;
    then selectInstrument;
    then establishAccess;
    then irrigateAndVisualize;
    then diagnoseOrTreat;
    then evacuateAndRetrieve;
    then withdrawInstrument;
    then completeProcedure;
    then done;

    action prepareSterileField {
      out item readiness : String;
    }

    action selectInstrument {
      in item targetAnatomy : String;
      out item selectedInstrument : String;
    }

    action establishAccess {
      out item accessStatus : String;
    }

    action irrigateAndVisualize {
      in item fluid : IrrigationFluid;
      out item image : OpticalImage;
    }

    action diagnoseOrTreat {
      in item image : OpticalImage;
      out item tissue : TissueSample;
      out item fragment : StoneFragment;
    }

    action evacuateAndRetrieve {
      in item tissue : TissueSample;
      in item fragment : StoneFragment;
      out item fieldClearStatus : String;
    }

    action withdrawInstrument {
      out item withdrawalStatus : String;
    }

    action completeProcedure {
      out item procedureRecord : String;
    }
  }

  action def VisualInspectUrinaryAnatomy {
    in item fluid : IrrigationFluid;
    out item image : OpticalImage;
  }

  action def NavigateUrinaryTract {
    in item guidewirePosition : String;
    out item scopePosition : String;
  }

  action def FragmentUrinaryStone {
    in item laser : LaserEnergy;
    out item stoneFragment : StoneFragment;
  }

  action def ResectObstructingTissue {
    in item motion : MechanicalMotion;
    out item tissueSample : TissueSample;
  }

  action def DeliverIrrigationFluid {
    in item requestedFlow : MillilitrePerMinute;
    out item deliveredFluid : IrrigationFluid;
  }

  action def EvacuateOperativeField {
    in item urine : Urine;
    in item fluid : IrrigationFluid;
    in item stoneFragment : StoneFragment;
    out item evacuatedUrine : Urine;
    out item evacuatedFluid : IrrigationFluid;
    out item evacuatedFragment : StoneFragment;
  }

  action def ProcessEndoscopicImage {
    in item rawImage : OpticalImage;
    out item processedImage : OpticalImage;
  }

  action def GenerateTherapeuticLaserEnergy {
    in item requestedPower : Watt;
    out item laser : LaserEnergy;
  }

  action def PresentProcedureStatus {
    in item image : OpticalImage;
    in item alarmStatus : String;
  }

  action def CollectBiopsySample {
    in item jawMotion : MechanicalMotion;
    out item tissue : TissueSample;
  }

  action def CaptureStoneFragment {
    in item basketMotion : MechanicalMotion;
    out item fragment : StoneFragment;
  }

  state def UrologyInstrumentOperationalState {
    entry action initializeSystem;
    exit action shutdownSafely;

    state Off;
    state Setup;
    state Ready;
    state InUse;
    state Irrigating;
    state Visualizing;
    state Treating;
    state Retrieving;
    state Fault;
    state Decontamination;
    state Complete;

    transition initial then Off;
    transition powerApplied first Off then Setup;
    transition selfTestPassed first Setup then Ready;
    transition insertionStarted first Ready then InUse;
    transition irrigationCommanded first InUse then Irrigating;
    transition imageStable first Irrigating then Visualizing;
    transition therapyCommanded first Visualizing then Treating;
    transition retrievalCommanded first Treating then Retrieving;
    transition treatmentNotRequired first Visualizing then Retrieving;
    transition procedureEnded first Retrieving then Decontamination;
    transition decontaminationConfirmed first Decontamination then Complete;
    transition resetForNextCase first Complete then Ready;
    transition alarmDetected first Setup then Fault;
    transition alarmDetected first Ready then Fault;
    transition alarmDetected first InUse then Fault;
    transition alarmDetected first Irrigating then Fault;
    transition alarmDetected first Visualizing then Fault;
    transition alarmDetected first Treating then Fault;
    transition alarmDetected first Retrieving then Fault;
    transition faultCleared first Fault then Setup;

    action initializeSystem;
    action shutdownSafely;
  }

  requirement def HighLevelPrimaryFunctionRequirement {
    subject system : UrologyInstrumentSystem;
    require constraint {
      system.primaryFunction == "Provide controlled endoscopic access, visualization, irrigation, drainage, tissue manipulation, stone retrieval, and therapeutic energy delivery for diagnostic and operative procedures within the urinary tract."
    }
  }

  requirement def VisualizationRequirement {
    subject system : UrologyInstrumentSystem;
    require constraint {
      system.cystoscope.viewingAngle.value >= 0.0 and
      system.ureteroscope.deflectionUp.value >= 180.0 and
      system.cameraConsole.latency.value <= 0.10
    }
  }

  requirement def IrrigationSafetyRequirement {
    subject system : UrologyInstrumentSystem;
    require constraint {
      system.irrigationPump.pressureLimit.value <= system.maximumIrrigationPressure.value and
      system.irrigationPump.fluidWarmingSetpoint.value >= 35.0 and
      system.irrigationPump.fluidWarmingSetpoint.value <= 39.0
    }
  }

  requirement def WorkingChannelCompatibilityRequirement {
    subject system : UrologyInstrumentSystem;
    require constraint {
      system.cystoscope.workingChannelDiameter.value >= system.instrumentTray.biopsyForceps.jawDiameter.value and
      system.ureteroscope.workingChannelDiameter.value >= 1.0 and
      system.resectoscope.loopTravel.value >= system.instrumentTray.resectionLoop.loopTravel.value
    }
  }

  requirement def LaserTherapyLimitRequirement {
    subject system : UrologyInstrumentSystem;
    require constraint {
      system.laserGenerator.maximumAveragePower.value <= system.maximumContinuousLaserPower.value
    }
  }

  requirement def DrainageRequirement {
    subject system : UrologyInstrumentSystem;
    require constraint {
      system.suctionDrainageUnit.nominalVacuumPressure.value < 0.0
    }
  }

  requirement def SterilityAndReuseRequirement {
    subject system : UrologyInstrumentSystem;
    require constraint {
      system.cystoscope.sterileReusableComponent == true
    }
  }

  requirement def ProcedureStateSafetyRequirement {
    subject system : UrologyInstrumentSystem;
    require constraint {
      system.irrigationPump.pressureLimit.value <= 100.0 and
      system.lightSource.thermalCutoffTemperature.value <= 45.0
    }
  }

  satisfy HighLevelPrimaryFunctionRequirement by UrologyInstrumentSystem;
  satisfy VisualizationRequirement by CameraConsole;
  satisfy IrrigationSafetyRequirement by IrrigationPump;
  satisfy WorkingChannelCompatibilityRequirement by UrologicInstrumentTray;
  satisfy LaserTherapyLimitRequirement by HolmiumLaserGenerator;
  satisfy DrainageRequirement by SuctionDrainageUnit;
  satisfy SterilityAndReuseRequirement by Cystoscope;
  satisfy ProcedureStateSafetyRequirement by UrologyInstrumentSystem;

}
