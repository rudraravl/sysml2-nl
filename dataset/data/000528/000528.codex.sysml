package AirtraqLaryngoscopeSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Percent :> Real;
  attribute def Lumen :> Real;
  attribute def PixelCount :> Integer;
  attribute def Degree :> Real;
  attribute def SterilityState :> String;
  attribute def BatteryState :> String;
  attribute def DeviceMode :> String;
  attribute def AirwayViewQuality :> String;

  item def LightEnergy {
    attribute luminousFlux : Lumen;
    attribute wavelengthPeak : ISQ::length;
  }

  item def VideoSignal {
    attribute horizontalPixels : PixelCount;
    attribute verticalPixels : PixelCount;
    attribute frameRate : ISQ::frequency;
    attribute imageLatency : ISQ::time;
  }

  item def AnatomicalView {
    attribute viewQuality : AirwayViewQuality;
    attribute fieldOfView : Degree;
    attribute fogLevel : Percent;
  }

  item def EndotrachealTube {
    attribute internalDiameter : ISQ::length;
    attribute externalDiameter : ISQ::length;
    attribute insertionDepth : ISQ::length;
    attribute cuffInflated : Boolean;
  }

  item def ElectricalPower {
    attribute voltage : ISQ::electricPotential;
    attribute current : ISQ::electricCurrent;
    attribute availableCapacity : ISQ::electricCharge;
  }

  item def ClinicianCommand {
    attribute powerRequested : Boolean;
    attribute illuminationRequested : Boolean;
    attribute videoRequested : Boolean;
    attribute tubeReleaseRequested : Boolean;
  }

  item def PatientAirway {
    attribute mouthOpening : ISQ::length;
    attribute glotticOpeningVisible : Boolean;
    attribute tissueContactForce : ISQ::force;
  }

  port def OpticalInputPort {
    in item airwayView : AnatomicalView;
  }

  port def OpticalOutputPort {
    out item light : LightEnergy;
  }

  port def VideoOutputPort {
    out item video : VideoSignal;
  }

  port def PowerOutputPort {
    out item power : ElectricalPower;
  }

  port def PowerInputPort {
    in item power : ElectricalPower;
  }

  port def TubeGuidePort {
    inout item tube : EndotrachealTube;
  }

  port def AirwayInterfacePort {
    inout item airway : PatientAirway;
  }

  port def CommandInputPort {
    in item command : ClinicianCommand;
  }

  action def PowerOnDevice {
    in item command : ClinicianCommand;
    out attribute mode : DeviceMode;
  }

  action def IlluminateAirway {
    in item power : ElectricalPower;
    out item light : LightEnergy;
  }

  action def CaptureAirwayImage {
    in item airwayView : AnatomicalView;
    out item video : VideoSignal;
  }

  action def GuideEndotrachealTube {
    inout item tube : EndotrachealTube;
    in item airway : PatientAirway;
    out attribute tubeTipAlignedWithGlottis : Boolean;
  }

  action def ReleaseEndotrachealTube {
    inout item tube : EndotrachealTube;
    out attribute tubeFreeFromGuideChannel : Boolean;
  }

  action def PerformAirtraqIntubation {
    in item command : ClinicianCommand;
    inout item airway : PatientAirway;
    inout item tube : EndotrachealTube;

    action powerOn : PowerOnDevice;
    action illuminate : IlluminateAirway;
    action capture : CaptureAirwayImage;
    action guideTube : GuideEndotrachealTube;
    action releaseTube : ReleaseEndotrachealTube;

    first start;
    then powerOn;
    then illuminate;
    then capture;
    then guideTube;
    then releaseTube;
    then done;
  }

  part def BatteryModule {
    attribute nominalVoltage : ISQ::electricPotential = 3.7 [V];
    attribute capacity : ISQ::electricCharge = 1200 [mA*h];
    attribute remainingCharge : Percent;
    attribute state : BatteryState;

    port powerOut : PowerOutputPort;
  }

  part def LightSourceModule {
    attribute maximumFlux : Lumen = 45.0;
    attribute colorTemperature : Real = 5600.0;
    attribute operatingTemperature : ISQ::thermodynamicTemperature;
    attribute enabled : Boolean;

    port powerIn : PowerInputPort;
    port lightOut : OpticalOutputPort;
  }

  part def OpticalChannel {
    attribute fieldOfView : Degree = 80.0;
    attribute antiFogActive : Boolean;
    attribute opticalPathLength : ISQ::length = 105 [mm];
    attribute maximumFogLevel : Percent = 10.0;

    port viewIn : OpticalInputPort;
  }

  part def CameraModule {
    attribute horizontalResolution : PixelCount = 640;
    attribute verticalResolution : PixelCount = 480;
    attribute frameRate : ISQ::frequency = 30 [Hz];
    attribute latency : ISQ::time = 120 [ms];

    port powerIn : PowerInputPort;
    port opticalIn : OpticalInputPort;
    port videoOut : VideoOutputPort;
  }

  part def DisplayModule {
    attribute diagonalSize : ISQ::length = 2.8 [in];
    attribute brightness : Lumen = 300.0;
    attribute visible : Boolean;

    port powerIn : PowerInputPort;
    port videoIn : VideoOutputPort;
  }

  part def Blade {
    attribute bladeLength : ISQ::length = 110 [mm];
    attribute bladeWidth : ISQ::length = 18 [mm];
    attribute distalTipRadius : ISQ::length = 3 [mm];
    attribute sterileCondition : SterilityState;
    attribute singleUse : Boolean = true;

    port airwayInterface : AirwayInterfacePort;
  }

  part def TubeGuidingChannel {
    attribute compatibleTubeMinInternalDiameter : ISQ::length = 6.0 [mm];
    attribute compatibleTubeMaxInternalDiameter : ISQ::length = 8.5 [mm];
    attribute channelCurvatureAngle : Degree = 75.0;
    attribute tubeLoaded : Boolean;

    port tubePort : TubeGuidePort;
  }

  part def Handle {
    attribute gripLength : ISQ::length = 125 [mm];
    attribute mass : ISQ::mass = 85 [g];
    attribute sealedAgainstFluids : Boolean = true;

    port commandIn : CommandInputPort;
  }

  part def AirtraqDevice {
    attribute primaryFunction : String =
      "Provide an illuminated indirect view of the glottis while guiding an endotracheal tube into the trachea during airway intubation.";
    attribute deviceMode : DeviceMode;
    attribute totalMass : ISQ::mass = 185 [g];
    attribute readyForUse : Boolean;
    attribute maximumAllowableTissueForce : ISQ::force = 5 [N];

    part battery : BatteryModule;
    part lightSource : LightSourceModule;
    part optics : OpticalChannel;
    part camera : CameraModule;
    part display : DisplayModule;
    part blade : Blade;
    part tubeGuide : TubeGuidingChannel;
    part handle : Handle;

    port commandPort : CommandInputPort;
    port airwayPort : AirwayInterfacePort;
    port tubePort : TubeGuidePort;
    port videoPort : VideoOutputPort;

    connect battery.powerOut to lightSource.powerIn;
    connect battery.powerOut to camera.powerIn;
    connect battery.powerOut to display.powerIn;
    connect lightSource.lightOut to blade.airwayInterface;
    connect blade.airwayInterface to airwayPort;
    connect optics.viewIn to camera.opticalIn;
    connect camera.videoOut to display.videoIn;
    connect camera.videoOut to videoPort;
    connect tubeGuide.tubePort to tubePort;
    connect handle.commandIn to commandPort;

    perform action intubation : PerformAirtraqIntubation;
  }

  state def AirtraqOperationalState {
    entry action initializeDevice;

    state Off;
    state SelfTest;
    state Ready;
    state Inserted;
    state Viewing;
    state TubeAdvancing;
    state TubeReleased;
    state Fault;

    transition first Off;

    transition powerCommand
      first Off
      then SelfTest
      accept ClinicianCommand
      if command.powerRequested;

    transition selfTestPassed
      first SelfTest
      then Ready
      if battery.remainingCharge >= 20.0 and blade.sterileCondition == "sterile";

    transition selfTestFailed
      first SelfTest
      then Fault
      if battery.remainingCharge < 20.0 or blade.sterileCondition != "sterile";

    transition insertBlade
      first Ready
      then Inserted
      if airway.mouthOpening >= 18 [mm];

    transition obtainView
      first Inserted
      then Viewing
      if airway.glotticOpeningVisible and optics.maximumFogLevel <= 10.0;

    transition advanceTube
      first Viewing
      then TubeAdvancing
      accept ClinicianCommand
      if command.videoRequested and tubeGuide.tubeLoaded;

    transition releaseTube
      first TubeAdvancing
      then TubeReleased
      accept ClinicianCommand
      if command.tubeReleaseRequested;

    transition excessiveForceFault
      first Inserted
      then Fault
      if airway.tissueContactForce > 5 [N];

    transition shutdown
      first TubeReleased
      then Off
      accept ClinicianCommand
      if not command.powerRequested;
  }

  requirement def PrimaryFunctionRequirement {
    doc
      /* The Airtraq system shall provide an illuminated indirect view of the patient's glottis and guide a loaded endotracheal tube toward the tracheal inlet. */

    subject device : AirtraqDevice;

    require constraint {
      device.readyForUse implies
      device.primaryFunction ==
      "Provide an illuminated indirect view of the glottis while guiding an endotracheal tube into the trachea during airway intubation."
    }
  }

  requirement def IlluminationRequirement {
    doc
      /* The device shall deliver sufficient light to visualize upper airway anatomy during intubation. */

    subject lightSource : LightSourceModule;

    require constraint {
      lightSource.maximumFlux >= 35.0
    }
  }

  requirement def VideoRequirement {
    doc
      /* The device shall produce a real-time airway image suitable for guiding tube placement. */

    subject camera : CameraModule;

    require constraint {
      camera.horizontalResolution >= 640 and
      camera.verticalResolution >= 480 and
      camera.frameRate >= 25 [Hz] and
      camera.latency <= 150 [ms]
    }
  }

  requirement def TubeCompatibilityRequirement {
    doc
      /* The guiding channel shall accept common adult endotracheal tube sizes. */

    subject guide : TubeGuidingChannel;

    require constraint {
      guide.compatibleTubeMinInternalDiameter <= 6.0 [mm] and
      guide.compatibleTubeMaxInternalDiameter >= 8.0 [mm]
    }
  }

  requirement def PatientContactSafetyRequirement {
    doc
      /* The blade shall limit tissue contact force during normal insertion. */

    subject device : AirtraqDevice;

    require constraint {
      device.maximumAllowableTissueForce <= 5 [N]
    }
  }

  requirement def SingleUseSterilityRequirement {
    doc
      /* Patient-contacting blade surfaces shall be sterile before use and intended for single-patient use. */

    subject blade : Blade;

    require constraint {
      blade.singleUse == true and
      blade.sterileCondition == "sterile"
    }
  }

  part airtraqSystem : AirtraqDevice {
    attribute deviceMode = "Off";
    attribute readyForUse = false;

    part battery {
      attribute remainingCharge = 100.0;
      attribute state = "charged";
    }

    part lightSource {
      attribute enabled = false;
      attribute operatingTemperature = 295 [K];
    }

    part optics {
      attribute antiFogActive = true;
    }

    part display {
      attribute visible = true;
    }

    part blade {
      attribute sterileCondition = "sterile";
    }

    part tubeGuide {
      attribute tubeLoaded = true;
    }
  }

  satisfy PrimaryFunctionRequirement by airtraqSystem;
  satisfy IlluminationRequirement by airtraqSystem.lightSource;
  satisfy VideoRequirement by airtraqSystem.camera;
  satisfy TubeCompatibilityRequirement by airtraqSystem.tubeGuide;
  satisfy PatientContactSafetyRequirement by airtraqSystem;
  satisfy SingleUseSterilityRequirement by airtraqSystem.blade;
}