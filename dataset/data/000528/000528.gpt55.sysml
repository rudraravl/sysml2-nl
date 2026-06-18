package AirtraqBasedAirwayVisualizationSystem {

  import ScalarValues::*;
  import SI::*;

  attribute def Length :> Real {
    doc /* Linear distance, default unit millimeter. */
    attribute unit : String = "mm";
  }

  attribute def Angle :> Real {
    doc /* Plane angle, default unit degree. */
    attribute unit : String = "deg";
  }

  attribute def TimeDuration :> Real {
    doc /* Elapsed time, default unit second. */
    attribute unit : String = "s";
  }

  attribute def ElectricPotential :> Real {
    doc /* Electric potential, default unit volt. */
    attribute unit : String = "V";
  }

  attribute def ElectricCurrent :> Real {
    doc /* Electric current, default unit milliampere. */
    attribute unit : String = "mA";
  }

  attribute def ElectricChargeCapacity :> Real {
    doc /* Battery capacity, default unit milliampere-hour. */
    attribute unit : String = "mA*h";
  }

  attribute def Power :> Real {
    doc /* Power, default unit watt. */
    attribute unit : String = "W";
  }

  attribute def Temperature :> Real {
    doc /* Temperature, default unit degree Celsius. */
    attribute unit : String = "degC";
  }

  attribute def Force :> Real {
    doc /* Force, default unit newton. */
    attribute unit : String = "N";
  }

  attribute def FlowRate :> Real {
    doc /* Volumetric flow rate, default unit liter per minute. */
    attribute unit : String = "L/min";
  }

  attribute def LuminousFlux :> Real {
    doc /* Luminous flux, default unit lumen. */
    attribute unit : String = "lm";
  }

  attribute def Illuminance :> Real {
    doc /* Illuminance, default unit lux. */
    attribute unit : String = "lx";
  }

  attribute def PixelCount :> Integer {
    doc /* Count of image pixels. */
    attribute unit : String = "pixel";
  }

  attribute def Frequency :> Real {
    doc /* Frequency, default unit hertz. */
    attribute unit : String = "Hz";
  }

  attribute def Percentage :> Real {
    doc /* Ratio expressed as percent. */
    attribute unit : String = "%";
  }

  enum def DeviceMode {
    enum off;
    enum selfTest;
    enum ready;
    enum inserted;
    enum visualizingGlottis;
    enum guidingTube;
    enum confirmingPlacement;
    enum withdrawn;
    enum fault;
  }

  enum def AirwayRegion {
    enum oralCavity;
    enum oropharynx;
    enum epiglottis;
    enum glottis;
    enum trachea;
    enum esophagus;
  }

  enum def ImageQuality {
    enum inadequate;
    enum usable;
    enum clear;
    enum excellent;
  }

  enum def TubePlacementStatus {
    enum notInserted;
    enum advancing;
    enum throughVocalCords;
    enum suspectedEsophageal;
    enum confirmedTracheal;
  }

  item def ElectricalEnergy {
    attribute voltage : ElectricPotential;
    attribute current : ElectricCurrent;
    attribute power : Power;
  }

  item def IlluminationBeam {
    attribute luminousFlux : LuminousFlux;
    attribute illuminanceAtTip : Illuminance;
    attribute beamDivergence : Angle;
    attribute colorTemperature : Temperature;
  }

  item def ReflectedAirwayLight {
    attribute intensity : Illuminance;
    attribute sourceRegion : AirwayRegion;
    attribute glotticContrast : Percentage;
  }

  item def VideoFrame {
    attribute horizontalResolution : PixelCount;
    attribute verticalResolution : PixelCount;
    attribute frameRate : Frequency;
    attribute fieldOfView : Angle;
    attribute quality : ImageQuality;
    attribute targetRegion : AirwayRegion;
  }

  item def AnatomicalView {
    attribute visibleRegion : AirwayRegion;
    attribute glotticOpeningVisible : Boolean;
    attribute viewingAngle : Angle;
    attribute airwayContactForce : Force;
    attribute imageQuality : ImageQuality;
  }

  item def EndotrachealTube {
    attribute outerDiameter : Length;
    attribute innerDiameter : Length;
    attribute length : Length;
    attribute cuffInflated : Boolean;
    attribute distalTipLocation : AirwayRegion;
  }

  item def AirwayContactLoad {
    attribute forceMagnitude : Force;
    attribute contactLocation : AirwayRegion;
    attribute safeContact : Boolean;
  }

  item def OxygenFlow {
    attribute flowRate : FlowRate;
    attribute humidified : Boolean;
  }

  item def UserCommand {
    attribute powerRequest : Boolean;
    attribute brightnessRequest : Percentage;
    attribute captureImageRequest : Boolean;
  }

  item def PlacementConfirmation {
    attribute tubeStatus : TubePlacementStatus;
    attribute glottisSeenDuringPassage : Boolean;
    attribute confirmationConfidence : Percentage;
  }

  port def PowerInputPort {
    in item command : UserCommand;
    out item suppliedEnergy : ElectricalEnergy;
  }

  port def PowerConsumerPort {
    in item energy : ElectricalEnergy;
  }

  port def IlluminationOutputPort {
    out item light : IlluminationBeam;
  }

  port def AirwayOpticalInputPort {
    in item reflectedLight : ReflectedAirwayLight;
  }

  port def ImageDataPort {
    out item frame : VideoFrame;
  }

  port def DisplayDataPort {
    in item frame : VideoFrame;
    out item view : AnatomicalView;
  }

  port def PatientContactPort {
    out item contactLoad : AirwayContactLoad;
    in item anatomicalView : AnatomicalView;
  }

  port def TubeGuidePort {
    inout item tube : EndotrachealTube;
    out item placement : PlacementConfirmation;
  }

  port def OxygenPort {
    in item oxygen : OxygenFlow;
  }

  part def BatteryPack {
    attribute nominalVoltage : ElectricPotential = 3.7;
    attribute capacity : ElectricChargeCapacity = 2400.0;
    attribute remainingCharge : Percentage = 100.0;
    attribute maximumContinuousPower : Power = 5.0;

    port powerOut : PowerInputPort;

    constraint minimumEnergyForUse {
      remainingCharge >= 20.0
    }
  }

  part def PowerController {
    attribute outputVoltage : ElectricPotential = 3.3;
    attribute maximumOutputCurrent : ElectricCurrent = 900.0;
    attribute selfTestDuration : TimeDuration = 2.0;

    port batteryIn : PowerConsumerPort;
    port regulatedOut : PowerInputPort;
  }

  part def Handle {
    attribute length : Length = 135.0;
    attribute gripDiameter : Length = 32.0;
    attribute massReadyToUse_g : Real = 120.0;
    attribute ingressProtectionRating : String = "splash-resistant disposable optical airway device";

    port userInput : PowerInputPort;
    port internalPower : PowerInputPort;
  }

  part def CurvedBlade {
    attribute bladeLength : Length = 118.0;
    attribute distalTipWidth : Length = 18.0;
    attribute curvatureAngle : Angle = 68.0;
    attribute maximumRecommendedContactForce : Force = 15.0;
    attribute singleUse : Boolean = true;

    port patientInterface : PatientContactPort;
    port oxygenIn : OxygenPort;
    port tubeChannel : TubeGuidePort;
  }

  part def OpticalChannel {
    attribute opticalPathLength : Length = 145.0;
    attribute prismDeflectionAngle : Angle = 42.0;
    attribute antiFogWindowTemperature : Temperature = 38.0;
    attribute minimumClearAperture : Length = 6.0;

    port airwayLightIn : AirwayOpticalInputPort;
    port cameraLightOut : AirwayOpticalInputPort;
  }

  part def LEDLightSource {
    attribute luminousFlux : LuminousFlux = 35.0;
    attribute powerConsumption : Power = 0.85;
    attribute nominalColorTemperature : Temperature = 5600.0;
    attribute adjustableBrightness : Boolean = true;

    port powerIn : PowerConsumerPort;
    port lightOut : IlluminationOutputPort;
  }

  part def AntiFogHeater {
    attribute operatingTemperature : Temperature = 38.0;
    attribute warmUpTime : TimeDuration = 10.0;
    attribute powerConsumption : Power = 0.55;

    port powerIn : PowerConsumerPort;
  }

  part def CameraSensor {
    attribute horizontalResolution : PixelCount = 640;
    attribute verticalResolution : PixelCount = 480;
    attribute frameRate : Frequency = 30.0;
    attribute sensorDiagonal : Length = 4.5;
    attribute minimumIlluminance : Illuminance = 10.0;

    port powerIn : PowerConsumerPort;
    port opticalIn : AirwayOpticalInputPort;
    port videoOut : ImageDataPort;
  }

  part def DisplayModule {
    attribute diagonalSize : Length = 70.0;
    attribute brightness : Illuminance = 450.0;
    attribute refreshRate : Frequency = 30.0;
    attribute displayedFieldOfView : Angle = 80.0;

    port powerIn : PowerConsumerPort;
    port videoIn : DisplayDataPort;
  }

  part def EndotrachealTubeGuideChannel {
    attribute compatibleTubeOuterDiameterMin : Length = 6.0;
    attribute compatibleTubeOuterDiameterMax : Length = 9.5;
    attribute channelLength : Length = 110.0;
    attribute exitAngleRelativeToBlade : Angle = 24.0;

    port guide : TubeGuidePort;
  }

  part def OxygenInsufflationChannel {
    attribute nominalFlow : FlowRate = 2.0;
    attribute maximumFlow : FlowRate = 6.0;
    attribute outletOffsetFromTip : Length = 8.0;

    port oxygenIn : OxygenPort;
  }

  part def AirwayEnvironment {
    attribute mouthOpening : Length = 25.0;
    attribute glotticAxisAngle : Angle = 35.0;
    attribute secretionLevel : Percentage = 15.0;
    attribute tissueSensitivityLimit : Force = 20.0;

    port patientInterface : PatientContactPort;
    port reflectedLightOut : AirwayOpticalInputPort;
    port tubePath : TubeGuidePort;
  }

  action def PowerOnAirtraq {
    in item command : UserCommand;
    out item electricalEnergy : ElectricalEnergy;

    action validateCommand {
      in item command;
    }

    action energizeController {
      out item electricalEnergy;
    }

    first validateCommand then energizeController;
  }

  action def PerformSelfTest {
    in item energy : ElectricalEnergy;
    out ok : Boolean;

    action testBattery;
    action testIllumination;
    action testCamera;
    action testDisplay;
    action testHeater;

    first testBattery then testIllumination then testCamera then testDisplay then testHeater;
  }

  action def IlluminateAirway {
    in item energy : ElectricalEnergy;
    out item light : IlluminationBeam;

    action convertElectricalPowerToLight;
    action directBeamAlongBladeTip;

    first convertElectricalPowerToLight then directBeamAlongBladeTip;
  }

  action def CaptureAirwayImage {
    in item reflectedLight : ReflectedAirwayLight;
    out item frame : VideoFrame;

    action focusOpticalPath;
    action senseImage;
    action formatVideoFrame;

    first focusOpticalPath then senseImage then formatVideoFrame;
  }

  action def DisplayAnatomicalView {
    in item frame : VideoFrame;
    out item view : AnatomicalView;

    action enhanceContrast;
    action renderLiveView;
    action identifyVisibleRegion;

    first enhanceContrast then renderLiveView then identifyVisibleRegion;
  }

  action def GuideEndotrachealTube {
    inout item tube : EndotrachealTube;
    in item view : AnatomicalView;
    out item placement : PlacementConfirmation;

    action alignTubeTipWithGlotticOpening;
    action advanceTubeThroughGuideChannel;
    action observeTubePassingVocalCords;
    action reportPlacement;

    first alignTubeTipWithGlotticOpening then advanceTubeThroughGuideChannel then observeTubePassingVocalCords then reportPlacement;
  }

  action def RemoveDeviceWhileLeavingTube {
    inout item tube : EndotrachealTube;
    in item placement : PlacementConfirmation;

    action stabilizeTube;
    action withdrawBladeAlongTube;
    action verifyTubeNotDislodged;

    first stabilizeTube then withdrawBladeAlongTube then verifyTubeNotDislodged;
  }

  action def AirtraqPrimaryUseScenario {
    in item operatorCommand : UserCommand;
    inout item tube : EndotrachealTube;
    out item finalPlacement : PlacementConfirmation;

    action powerOn : PowerOnAirtraq;
    action selfTest : PerformSelfTest;
    action illuminate : IlluminateAirway;
    action imageCapture : CaptureAirwayImage;
    action displayView : DisplayAnatomicalView;
    action guideTube : GuideEndotrachealTube;
    action removeDevice : RemoveDeviceWhileLeavingTube;

    first powerOn then selfTest then illuminate then imageCapture then displayView then guideTube then removeDevice;
  }

  state def AirtraqOperatingStateMachine {
    attribute mode : DeviceMode = DeviceMode::off;
    attribute batteryCharge : Percentage;
    attribute glotticViewAvailable : Boolean = false;
    attribute tubePlacementStatus : TubePlacementStatus = TubePlacementStatus::notInserted;

    state off;
    state selfTest;
    state ready;
    state inserted;
    state visualizingGlottis;
    state guidingTube;
    state confirmingPlacement;
    state withdrawn;
    state fault;

    transition powerButtonPressed
      first off
      then selfTest;

    transition selfTestPassed
      first selfTest
      then ready
      if batteryCharge >= 20.0;

    transition selfTestFailed
      first selfTest
      then fault
      if batteryCharge < 20.0;

    transition bladeInserted
      first ready
      then inserted;

    transition glottisVisible
      first inserted
      then visualizingGlottis
      if glotticViewAvailable == true;

    transition tubeAdvanced
      first visualizingGlottis
      then guidingTube;

    transition tubeThroughVocalCords
      first guidingTube
      then confirmingPlacement
      if tubePlacementStatus == TubePlacementStatus::throughVocalCords;

    transition placementConfirmed
      first confirmingPlacement
      then withdrawn
      if tubePlacementStatus == TubePlacementStatus::confirmedTracheal;

    transition excessiveForceDetected
      first inserted
      then fault;

    transition powerOff
      first withdrawn
      then off;
  }

  part def AirtraqBasedSystem {
    doc /* An Airtraq-based system is a self-contained optical/video laryngoscope system whose primary high-level function is to enable an operator to see the laryngeal inlet and guide an endotracheal tube into the trachea without requiring a direct line of sight. */

    attribute primaryFunction : String =
      "Provide illuminated indirect visualization of the glottis and mechanically guide an endotracheal tube into the trachea during airway intubation.";
    attribute overallLength : Length = 180.0;
    attribute maximumBladeInsertionDepth : Length = 120.0;
    attribute nominalFieldOfView : Angle = 80.0;
    attribute maximumSafeContactForce : Force = 15.0;
    attribute readyTimeAfterPowerOn : TimeDuration = 12.0;
    attribute intendedTubeOuterDiameterMin : Length = 6.0;
    attribute intendedTubeOuterDiameterMax : Length = 9.5;
    attribute intendedUseSinglePatient : Boolean = true;

    part battery : BatteryPack;
    part controller : PowerController;
    part handle : Handle;
    part blade : CurvedBlade;
    part opticalChannel : OpticalChannel;
    part lightSource : LEDLightSource;
    part antiFogHeater : AntiFogHeater;
    part camera : CameraSensor;
    part display : DisplayModule;
    part tubeGuide : EndotrachealTubeGuideChannel;
    part oxygenChannel : OxygenInsufflationChannel;
    part patientAirway : AirwayEnvironment;

    port userPowerAndCommand : PowerInputPort;
    port patientContact : PatientContactPort;
    port endotrachealTubeInterface : TubeGuidePort;
    port oxygenSupplyInterface : OxygenPort;

    connection userToHandle connect userPowerAndCommand to handle.userInput;
    connection handleToController connect handle.internalPower to controller.batteryIn;
    connection batteryToController connect battery.powerOut to controller.batteryIn;
    connection controllerToLight connect controller.regulatedOut to lightSource.powerIn;
    connection controllerToCamera connect controller.regulatedOut to camera.powerIn;
    connection controllerToDisplay connect controller.regulatedOut to display.powerIn;
    connection controllerToHeater connect controller.regulatedOut to antiFogHeater.powerIn;

    connection lightToPatient connect lightSource.lightOut to blade.patientInterface;
    connection patientContactConnection connect blade.patientInterface to patientAirway.patientInterface;
    connection reflectedAirwayLightToOptics connect patientAirway.reflectedLightOut to opticalChannel.airwayLightIn;
    connection opticalChannelToCamera connect opticalChannel.cameraLightOut to camera.opticalIn;
    connection cameraToDisplay connect camera.videoOut to display.videoIn;

    connection bladeTubeChannelToGuide connect blade.tubeChannel to tubeGuide.guide;
    connection externalTubeToGuide connect endotrachealTubeInterface to tubeGuide.guide;
    connection guideToPatientAirway connect tubeGuide.guide to patientAirway.tubePath;

    connection externalOxygenToBlade connect oxygenSupplyInterface to oxygenChannel.oxygenIn;
    connection oxygenChannelToBlade connect oxygenChannel.oxygenIn to blade.oxygenIn;

    perform action primaryUse : AirtraqPrimaryUseScenario;

    exhibit state operatingStates : AirtraqOperatingStateMachine;

    constraint safeContactForce {
      maximumSafeContactForce <= patientAirway.tissueSensitivityLimit
    }

    constraint supportsIntendedTubeRange {
      tubeGuide.compatibleTubeOuterDiameterMin <= intendedTubeOuterDiameterMin and
      tubeGuide.compatibleTubeOuterDiameterMax >= intendedTubeOuterDiameterMax
    }

    constraint providesAdequateFieldOfView {
      nominalFieldOfView >= 60.0
    }

    constraint readyWithinClinicalPreparationTime {
      readyTimeAfterPowerOn <= 15.0
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The Airtraq-based system shall provide a high-level intubation aid function by illuminating the airway, presenting an indirect view of the glottis, and guiding an endotracheal tube toward and through the vocal cords. */

    subject device : AirtraqBasedSystem;

    require constraint {
      device.nominalFieldOfView >= 60.0
    }

    require constraint {
      device.intendedTubeOuterDiameterMin <= 6.0 and device.intendedTubeOuterDiameterMax >= 9.5
    }

    require constraint {
      device.readyTimeAfterPowerOn <= 15.0
    }
  }

  requirement def AirwayVisualizationRequirement {
    doc /* The system shall generate a live view of the glottic opening adequate for tube guidance under illuminated conditions at the distal blade tip. */

    subject device : AirtraqBasedSystem;

    require constraint {
      device.display.displayedFieldOfView >= 60.0
    }

    require constraint {
      device.camera.frameRate >= 25.0
    }

    require constraint {
      device.lightSource.luminousFlux >= 20.0
    }
  }

  requirement def TubeGuidanceRequirement {
    doc /* The system shall include a guide path compatible with common adult endotracheal tube sizes and oriented so the tube exits toward the visualized glottis. */

    subject device : AirtraqBasedSystem;

    require constraint {
      device.tubeGuide.compatibleTubeOuterDiameterMin <= 6.0
    }

    require constraint {
      device.tubeGuide.compatibleTubeOuterDiameterMax >= 9.5
    }

    require constraint {
      device.tubeGuide.exitAngleRelativeToBlade >= 15.0 and device.tubeGuide.exitAngleRelativeToBlade <= 35.0
    }
  }

  requirement def PatientSafetyRequirement {
    doc /* The system shall limit tissue contact loads and maintain anti-fog temperature within a safe clinical range. */

    subject device : AirtraqBasedSystem;

    require constraint {
      device.maximumSafeContactForce <= 15.0
    }

    require constraint {
      device.antiFogHeater.operatingTemperature >= 35.0 and device.antiFogHeater.operatingTemperature <= 42.0
    }
  }

  requirement def PowerReadinessRequirement {
    doc /* The system shall have sufficient battery energy and regulated power for illumination, imaging, display, and anti-fog operation during preparation and intubation. */

    subject device : AirtraqBasedSystem;

    require constraint {
      device.battery.remainingCharge >= 20.0
    }

    require constraint {
      device.battery.maximumContinuousPower >=
        device.lightSource.powerConsumption +
        device.antiFogHeater.powerConsumption
    }
  }

  part airtraqIntubationAid : AirtraqBasedSystem {
    attribute primaryFunction =
      "At a high level, the Airtraq-based system functions as an indirect airway visualization and endotracheal tube guidance device for tracheal intubation.";

    satisfy PrimaryFunctionRequirement by airtraqIntubationAid;
    satisfy AirwayVisualizationRequirement by airtraqIntubationAid;
    satisfy TubeGuidanceRequirement by airtraqIntubationAid;
    satisfy PatientSafetyRequirement by airtraqIntubationAid;
    satisfy PowerReadinessRequirement by airtraqIntubationAid;
  }

}
