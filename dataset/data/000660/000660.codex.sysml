package LaryngoscopySystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Millimeter :> LengthUnit;
  attribute def Degree :> PlaneAngleUnit;
  attribute def Lumen :> Unit;
  attribute def Lux :> Unit;
  attribute def Pixel :> Unit;
  attribute def Percent :> DimensionlessUnit;
  attribute def Newton :> ForceUnit;
  attribute def Volt :> ElectricPotentialUnit;
  attribute def Watt :> PowerUnit;
  attribute def Celsius :> TemperatureUnit;
  attribute def Second :> TimeUnit;

  value type Length_mm :> Real {
    unit = Millimeter;
  }

  value type Angle_deg :> Real {
    unit = Degree;
  }

  value type Illuminance_lux :> Real {
    unit = Lux;
  }

  value type LuminousFlux_lm :> Real {
    unit = Lumen;
  }

  value type Force_N :> Real {
    unit = Newton;
  }

  value type Voltage_V :> Real {
    unit = Volt;
  }

  value type Power_W :> Real {
    unit = Watt;
  }

  value type Temperature_C :> Real {
    unit = Celsius;
  }

  value type Time_s :> Real {
    unit = Second;
  }

  value type Percentage :> Real {
    unit = Percent;
  }

  value type PixelCount :> Integer {
    unit = Pixel;
  }

  item def OralAirway {
    attribute mouthOpening : Length_mm;
    attribute tonguePosition : String;
    attribute airwayPatency : Percentage;
  }

  item def LaryngealView {
    attribute fieldOfViewAngle : Angle_deg;
    attribute glotticExposure : Percentage;
    attribute illuminationLevel : Illuminance_lux;
    attribute imageWidth : PixelCount;
    attribute imageHeight : PixelCount;
  }

  item def VideoSignal {
    attribute frameRate : Real;
    attribute resolutionWidth : PixelCount;
    attribute resolutionHeight : PixelCount;
    attribute latency : Time_s;
  }

  item def ElectricalEnergy {
    attribute voltage : Voltage_V;
    attribute availableCharge : Percentage;
    attribute powerDraw : Power_W;
  }

  item def ControlCommand {
    attribute commandName : String;
    attribute requestedIntensity : Percentage;
    attribute recordingEnabled : Boolean;
  }

  item def ClinicalGuidance {
    attribute recommendedBladeAngle : Angle_deg;
    attribute recommendedLiftForce : Force_N;
    attribute message : String;
  }

  port def AirwayAccessPort {
    inout airway : OralAirway;
  }

  port def OpticalViewPort {
    out view : LaryngealView;
  }

  port def VideoOutputPort {
    out signal : VideoSignal;
  }

  port def PowerInputPort {
    in energy : ElectricalEnergy;
  }

  port def ControlInputPort {
    in command : ControlCommand;
  }

  port def GuidanceOutputPort {
    out guidance : ClinicalGuidance;
  }

  part def LaryngoscopySystem {
    attribute primaryFunction : String = "Provide illuminated visualization of the larynx and vocal cords to support airway assessment and tracheal tube placement.";
    attribute systemReady : Boolean;
    attribute sterileBarrierIntact : Boolean;
    attribute maximumSurfaceTemperature : Temperature_C = 41.0;
    attribute minimumMouthOpening : Length_mm = 18.0;
    attribute targetGlotticExposure : Percentage = 80.0;

    port airwayInterface : AirwayAccessPort;
    port viewOutput : OpticalViewPort;
    port videoOutput : VideoOutputPort;
    port powerInput : PowerInputPort;
    port controlInput : ControlInputPort;
    port guidanceOutput : GuidanceOutputPort;

    part handle : HandleAssembly;
    part blade : LaryngoscopeBlade;
    part illumination : IlluminationModule;
    part imaging : ImagingModule;
    part display : DisplayModule;
    part controller : ControlProcessor;
    part powerSubsystem : PowerSubsystem;
    part safetyMonitor : SafetyMonitor;

    connect powerInput to powerSubsystem.externalPowerPort;
    connect powerSubsystem.devicePowerPort to handle.powerPort;
    connect powerSubsystem.devicePowerPort to illumination.powerPort;
    connect powerSubsystem.devicePowerPort to imaging.powerPort;
    connect powerSubsystem.devicePowerPort to display.powerPort;
    connect powerSubsystem.devicePowerPort to controller.powerPort;

    connect controlInput to controller.operatorControlPort;
    connect controller.lightControlPort to illumination.controlPort;
    connect controller.cameraControlPort to imaging.controlPort;
    connect controller.displayControlPort to display.controlPort;

    connect blade.airwayPort to airwayInterface;
    connect illumination.lightPort to blade.lightGuidePort;
    connect blade.opticalPort to imaging.scenePort;
    connect imaging.videoPort to display.videoInputPort;
    connect imaging.videoPort to videoOutput;
    connect display.guidancePort to guidanceOutput;
    connect safetyMonitor.safetyStatusPort to controller.safetyInputPort;

    perform action prepareForUse;
    perform action visualizeLarynx;
    perform action supportIntubation;

    state laryngoscopyLifecycle {
      entry; then Off;

      state Off;
      state SelfTest;
      state Ready;
      state Inserted;
      state Visualizing;
      state GuidingTubePlacement;
      state Completed;
      state Fault;

      transition Off_to_SelfTest
        first Off
        accept ControlCommand
        if controlInput.command.commandName == "powerOn"
        then SelfTest;

      transition SelfTest_to_Ready
        first SelfTest
        if powerSubsystem.batteryLevel >= 20.0 and sterileBarrierIntact == true and safetyMonitor.overTemperature == false
        then Ready;

      transition SelfTest_to_Fault
        first SelfTest
        if powerSubsystem.batteryLevel < 20.0 or sterileBarrierIntact == false or safetyMonitor.overTemperature == true
        then Fault;

      transition Ready_to_Inserted
        first Ready
        accept OralAirway
        if airwayInterface.airway.mouthOpening >= minimumMouthOpening
        then Inserted;

      transition Inserted_to_Visualizing
        first Inserted
        if illumination.actualIntensity > 30.0 and imaging.focusLocked == true
        then Visualizing;

      transition Visualizing_to_GuidingTubePlacement
        first Visualizing
        if viewOutput.view.glotticExposure >= targetGlotticExposure
        then GuidingTubePlacement;

      transition GuidingTubePlacement_to_Completed
        first GuidingTubePlacement
        accept ControlCommand
        if controlInput.command.commandName == "procedureComplete"
        then Completed;

      transition Ready_to_Off
        first Ready
        accept ControlCommand
        if controlInput.command.commandName == "powerOff"
        then Off;

      transition Completed_to_Off
        first Completed
        accept ControlCommand
        if controlInput.command.commandName == "powerOff"
        then Off;

      transition Any_to_Fault
        first Ready
        if safetyMonitor.overTemperature == true or powerSubsystem.batteryLevel < 5.0
        then Fault;
    }
  }

  part def HandleAssembly {
    attribute gripDiameter : Length_mm = 34.0;
    attribute sealedAgainstFluidIngress : Boolean = true;
    attribute mass : Real;
    port powerPort : PowerInputPort;
  }

  part def LaryngoscopeBlade {
    attribute bladeLength : Length_mm = 120.0;
    attribute bladeWidth : Length_mm = 18.0;
    attribute distalTipRadius : Length_mm = 3.0;
    attribute insertionAngle : Angle_deg;
    attribute liftForce : Force_N;

    port airwayPort : AirwayAccessPort;
    port lightGuidePort : OpticalViewPort;
    port opticalPort : OpticalViewPort;
  }

  part def IlluminationModule {
    attribute commandedIntensity : Percentage;
    attribute actualIntensity : Percentage;
    attribute luminousFlux : LuminousFlux_lm = 45.0;
    attribute colorTemperature : Temperature_C;
    attribute surfaceTemperature : Temperature_C;

    port powerPort : PowerInputPort;
    port controlPort : ControlInputPort;
    port lightPort : OpticalViewPort;

    action adjustIllumination {
      in requestedIntensity : Percentage;
      out deliveredView : LaryngealView;
      first start;
      then setIntensity;
      then verifyOutput;
      then done;
    }
  }

  part def ImagingModule {
    attribute focusLocked : Boolean;
    attribute sensorWidth : PixelCount = 1920;
    attribute sensorHeight : PixelCount = 1080;
    attribute frameRate : Real = 30.0;
    attribute lensFieldOfView : Angle_deg = 72.0;

    port powerPort : PowerInputPort;
    port controlPort : ControlInputPort;
    port scenePort : OpticalViewPort;
    port videoPort : VideoOutputPort;

    action captureLaryngealImage {
      in opticalScene : LaryngealView;
      out video : VideoSignal;
    }
  }

  part def DisplayModule {
    attribute diagonalSize : Length_mm = 89.0;
    attribute brightness : Percentage;
    attribute contrast : Percentage;
    attribute overlayEnabled : Boolean = true;

    port powerPort : PowerInputPort;
    port controlPort : ControlInputPort;
    port videoInputPort : VideoOutputPort;
    port guidancePort : GuidanceOutputPort;

    action showLaryngealView {
      in video : VideoSignal;
      out guidance : ClinicalGuidance;
    }
  }

  part def ControlProcessor {
    attribute softwareVersion : String = "2.1.0";
    attribute bootComplete : Boolean;
    attribute imageEnhancementEnabled : Boolean = true;

    port powerPort : PowerInputPort;
    port operatorControlPort : ControlInputPort;
    port lightControlPort : ControlInputPort;
    port cameraControlPort : ControlInputPort;
    port displayControlPort : ControlInputPort;
    port safetyInputPort : GuidanceOutputPort;

    action computeGuidance {
      in view : LaryngealView;
      out guidance : ClinicalGuidance;
    }
  }

  part def PowerSubsystem {
    attribute batteryLevel : Percentage;
    attribute nominalVoltage : Voltage_V = 7.4;
    attribute maximumPowerOutput : Power_W = 12.0;
    attribute chargingEnabled : Boolean;

    port externalPowerPort : PowerInputPort;
    port devicePowerPort : PowerInputPort;

    action regulatePower {
      in sourceEnergy : ElectricalEnergy;
      out regulatedEnergy : ElectricalEnergy;
    }
  }

  part def SafetyMonitor {
    attribute overTemperature : Boolean;
    attribute excessiveLiftForce : Boolean;
    attribute lowBatteryWarning : Boolean;
    attribute maximumMeasuredTemperature : Temperature_C;
    attribute measuredLiftForce : Force_N;

    port safetyStatusPort : GuidanceOutputPort;

    action evaluateSafety {
      in bladeForce : Force_N;
      in surfaceTemperature : Temperature_C;
      in batteryLevel : Percentage;
      out safetyGuidance : ClinicalGuidance;
    }
  }

  action def PrepareForUse {
    in command : ControlCommand;
    in energy : ElectricalEnergy;
    out ready : Boolean;
  }

  action def VisualizeLarynx {
    in airway : OralAirway;
    out view : LaryngealView;
    out video : VideoSignal;
  }

  action def SupportIntubation {
    in view : LaryngealView;
    out guidance : ClinicalGuidance;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : LaryngoscopySystem;
    doc /* The system shall provide illuminated visualization of the larynx and vocal cords during laryngoscopy to support airway assessment and tracheal intubation. */
    require constraint {
      system.viewOutput.view.illuminationLevel >= 10000.0 and
      system.viewOutput.view.glotticExposure >= 60.0
    }
  }

  requirement def IlluminationRequirement {
    subject system : LaryngoscopySystem;
    doc /* The illumination subsystem shall deliver sufficient light to the distal blade region without exceeding safe surface temperature. */
    require constraint {
      system.illumination.luminousFlux >= 30.0 and
      system.illumination.surfaceTemperature <= system.maximumSurfaceTemperature
    }
  }

  requirement def VideoRequirement {
    subject system : LaryngoscopySystem;
    doc /* The imaging subsystem shall provide real-time video suitable for identifying laryngeal anatomy. */
    require constraint {
      system.imaging.sensorWidth >= 1280 and
      system.imaging.sensorHeight >= 720 and
      system.imaging.frameRate >= 25.0 and
      system.videoOutput.signal.latency <= 0.150
    }
  }

  requirement def AirwayAccessRequirement {
    subject system : LaryngoscopySystem;
    doc /* The blade shall be insertable through a clinically relevant mouth opening while providing a view path to the glottis. */
    require constraint {
      system.blade.bladeWidth <= system.minimumMouthOpening and
      system.blade.liftForce <= 45.0
    }
  }

  requirement def PowerRequirement {
    subject system : LaryngoscopySystem;
    doc /* The power subsystem shall supply regulated energy for illumination, imaging, display, and control during the procedure. */
    require constraint {
      system.powerSubsystem.nominalVoltage >= 7.0 and
      system.powerSubsystem.maximumPowerOutput >= 10.0 and
      system.powerSubsystem.batteryLevel >= 20.0
    }
  }

  requirement def SafetyRequirement {
    subject system : LaryngoscopySystem;
    doc /* The system shall warn or enter a fault condition if thermal, force, or battery limits could compromise safe operation. */
    require constraint {
      system.safetyMonitor.overTemperature == false and
      system.safetyMonitor.excessiveLiftForce == false and
      system.safetyMonitor.lowBatteryWarning == false
    }
  }

  satisfy PrimaryFunctionRequirement by LaryngoscopySystem;
  satisfy IlluminationRequirement by IlluminationModule;
  satisfy VideoRequirement by ImagingModule;
  satisfy AirwayAccessRequirement by LaryngoscopeBlade;
  satisfy PowerRequirement by PowerSubsystem;
  satisfy SafetyRequirement by SafetyMonitor;

  part laryngoscopyDevice : LaryngoscopySystem {
    attribute sterileBarrierIntact = true;
    attribute systemReady = false;

    part handle {
      attribute mass = 0.24;
    }

    part blade {
      attribute insertionAngle = 35.0;
      attribute liftForce = 18.0;
    }

    part illumination {
      attribute commandedIntensity = 75.0;
      attribute actualIntensity = 72.0;
      attribute colorTemperature = 5.5;
      attribute surfaceTemperature = 34.0;
    }

    part imaging {
      attribute focusLocked = true;
    }

    part display {
      attribute brightness = 80.0;
      attribute contrast = 65.0;
    }

    part controller {
      attribute bootComplete = true;
    }

    part powerSubsystem {
      attribute batteryLevel = 86.0;
      attribute chargingEnabled = false;
    }

    part safetyMonitor {
      attribute overTemperature = false;
      attribute excessiveLiftForce = false;
      attribute lowBatteryWarning = false;
      attribute maximumMeasuredTemperature = 34.0;
      attribute measuredLiftForce = 18.0;
    }
  }
}