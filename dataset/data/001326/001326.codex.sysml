package ThreeDPrintingSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Millimeter :> Length {
    unit = mm;
  }

  attribute def DegreeCelsius :> Temperature {
    unit = degC;
  }

  attribute def Minute :> Time {
    unit = min;
  }

  attribute def Gram :> Mass {
    unit = g;
  }

  attribute def Watt :> Power {
    unit = W;
  }

  attribute def CubicMillimeterPerSecond {
    unit = mm^3 / s;
  }

  attribute def Percent {
    unit = 1;
  }

  item def DigitalPrintJob {
    attribute modelName : String;
    attribute layerHeight : Millimeter;
    attribute infillRatio : Percent;
    attribute estimatedDuration : Minute;
    attribute estimatedMaterialUse : Gram;
    attribute buildVolumeX : Millimeter;
    attribute buildVolumeY : Millimeter;
    attribute buildVolumeZ : Millimeter;
  }

  item def GCodeCommand {
    attribute commandText : String;
    attribute commandedFeedRate : Millimeter;
    attribute commandedExtrusion : Millimeter;
  }

  item def Filament {
    attribute material : String;
    attribute diameter : Millimeter;
    attribute massRemaining : Gram;
    attribute recommendedNozzleTemperature : DegreeCelsius;
    attribute recommendedBedTemperature : DegreeCelsius;
  }

  item def MoltenPolymer {
    attribute material : String;
    attribute volumetricFlowRate : CubicMillimeterPerSecond;
    attribute temperature : DegreeCelsius;
  }

  item def PrintedPart {
    attribute partName : String;
    attribute mass : Gram;
    attribute dimensionalTolerance : Millimeter;
    attribute layerCount : Integer;
    attribute completed : Boolean;
  }

  item def StatusMessage {
    attribute currentState : String;
    attribute progress : Percent;
    attribute elapsedTime : Minute;
    attribute faultCode : String;
  }

  port def JobInputPort {
    in item job : DigitalPrintJob;
  }

  port def CommandPort {
    out item command : GCodeCommand;
  }

  port def FilamentInputPort {
    in item filament : Filament;
  }

  port def MeltOutputPort {
    out item melt : MoltenPolymer;
  }

  port def PartOutputPort {
    out item part : PrintedPart;
  }

  port def StatusPort {
    out item status : StatusMessage;
  }

  port def PowerPort {
    in attribute supplyPower : Watt;
  }

  part def ThreeDPrinter {
    attribute buildPlateWidth : Millimeter = 220 [mm];
    attribute buildPlateDepth : Millimeter = 220 [mm];
    attribute buildHeight : Millimeter = 250 [mm];
    attribute nominalPower : Watt = 350 [W];
    attribute maxNozzleTemperature : DegreeCelsius = 285 [degC];
    attribute maxBedTemperature : DegreeCelsius = 110 [degC];
    attribute minimumLayerHeight : Millimeter = 0.08 [mm];
    attribute maximumLayerHeight : Millimeter = 0.32 [mm];

    port powerPort : PowerPort;
    port jobPort : JobInputPort;
    port statusPort : StatusPort;
    port outputPort : PartOutputPort;

    part controller : PrintController;
    part motionSystem : CartesianMotionSystem;
    part extrusionSystem : ExtrusionSystem;
    part thermalSystem : ThermalSystem;
    part buildPlatform : BuildPlatform;
    part enclosure : PrinterEnclosure;
    part userInterface : OperatorInterface;
    part safetySystem : SafetySystem;

    connect jobPort to controller.jobPort;
    connect controller.commandPort to motionSystem.commandPort;
    connect controller.commandPort to extrusionSystem.commandPort;
    connect extrusionSystem.meltPort to buildPlatform.depositionPort;
    connect thermalSystem.nozzleHeatPort to extrusionSystem.nozzleHeatPort;
    connect thermalSystem.bedHeatPort to buildPlatform.bedHeatPort;
    connect buildPlatform.partPort to outputPort;
    connect controller.statusPort to statusPort;
    connect safetySystem.interlockPort to controller.interlockPort;
    connect userInterface.jobPort to controller.jobPort;
    connect controller.statusPort to userInterface.statusPort;

    perform action printObject;
  }

  part def PrintController {
    attribute firmwareVersion : String = "FDM-Control-4.2";
    attribute commandedLayerHeight : Millimeter;
    attribute progress : Percent;
    attribute elapsedTime : Minute;

    port jobPort : JobInputPort;
    port commandPort : CommandPort;
    port statusPort : StatusPort;
    port interlockPort : SafetyInterlockPort;

    action def SliceAndSchedulePrint {
      in item printJob : DigitalPrintJob;
      out item motionCommands : GCodeCommand;
    }

    action def MonitorPrint {
      in item commandFeedback : StatusMessage;
      out item printStatus : StatusMessage;
    }
  }

  part def CartesianMotionSystem {
    attribute positionX : Millimeter;
    attribute positionY : Millimeter;
    attribute positionZ : Millimeter;
    attribute maximumTravelSpeed : Millimeter = 300 [mm];
    attribute positioningTolerance : Millimeter = 0.05 [mm];

    port commandPort : CommandPort;

    part xAxis : LinearAxis {
      attribute travel : Millimeter = 220 [mm];
    }

    part yAxis : LinearAxis {
      attribute travel : Millimeter = 220 [mm];
    }

    part zAxis : LinearAxis {
      attribute travel : Millimeter = 250 [mm];
    }
  }

  part def LinearAxis {
    attribute travel : Millimeter;
    attribute currentPosition : Millimeter;
    attribute stepResolution : Millimeter = 0.01 [mm];
    attribute holdingTorqueEnabled : Boolean;
  }

  part def ExtrusionSystem {
    attribute nozzleDiameter : Millimeter = 0.40 [mm];
    attribute filamentFeedRate : Millimeter;
    attribute extrusionMultiplier : Percent = 1.00;
    attribute nozzleTemperature : DegreeCelsius;

    port commandPort : CommandPort;
    port filamentPort : FilamentInputPort;
    port nozzleHeatPort : HeatTransferPort;
    port meltPort : MeltOutputPort;

    part filamentDrive : FilamentDrive;
    part hotEnd : HotEnd;
    part nozzle : Nozzle;

    connect filamentPort to filamentDrive.filamentPort;
    connect filamentDrive.filamentOutPort to hotEnd.filamentPort;
    connect hotEnd.meltPort to nozzle.meltPort;
    connect nozzle.outputPort to meltPort;
  }

  part def FilamentDrive {
    attribute driveGearDiameter : Millimeter = 7.0 [mm];
    attribute motorCurrentLimit : Real = 1.2;
    attribute slipDetected : Boolean;

    port filamentPort : FilamentInputPort;
    port filamentOutPort : FilamentInputPort;
  }

  part def HotEnd {
    attribute heaterPower : Watt = 40 [W];
    attribute targetTemperature : DegreeCelsius;
    attribute measuredTemperature : DegreeCelsius;

    port filamentPort : FilamentInputPort;
    port meltPort : MeltOutputPort;
  }

  part def Nozzle {
    attribute orificeDiameter : Millimeter = 0.40 [mm];
    attribute extrusionWidth : Millimeter = 0.45 [mm];

    port meltPort : MeltOutputPort;
    port outputPort : MeltOutputPort;
  }

  part def ThermalSystem {
    attribute ambientTemperature : DegreeCelsius = 23 [degC];
    attribute nozzleTargetTemperature : DegreeCelsius;
    attribute bedTargetTemperature : DegreeCelsius;
    attribute thermalStabilityBand : DegreeCelsius = 2 [degC];

    port nozzleHeatPort : HeatTransferPort;
    port bedHeatPort : HeatTransferPort;

    part nozzleHeater : Heater {
      attribute ratedPower : Watt = 40 [W];
    }

    part bedHeater : Heater {
      attribute ratedPower : Watt = 220 [W];
    }

    part nozzleSensor : TemperatureSensor;
    part bedSensor : TemperatureSensor;
  }

  port def HeatTransferPort {
    out attribute heatPower : Watt;
    out attribute targetTemperature : DegreeCelsius;
  }

  part def Heater {
    attribute ratedPower : Watt;
    attribute enabled : Boolean;
    attribute dutyCycle : Percent;
  }

  part def TemperatureSensor {
    attribute measuredTemperature : DegreeCelsius;
    attribute accuracy : DegreeCelsius = 1.5 [degC];
    attribute samplePeriod : Time = 0.5 [s];
  }

  part def BuildPlatform {
    attribute surfaceTemperature : DegreeCelsius;
    attribute adhesionState : String;
    attribute removablePlateInstalled : Boolean = true;

    port bedHeatPort : HeatTransferPort;
    port depositionPort : MeltOutputPort;
    port partPort : PartOutputPort;
  }

  part def PrinterEnclosure {
    attribute doorClosed : Boolean;
    attribute internalTemperature : DegreeCelsius;
    attribute airFilterInstalled : Boolean = true;

    part coolingFan : CoolingFan;
    part frame : StructuralFrame;
  }

  part def CoolingFan {
    attribute speedPercent : Percent;
    attribute airflowEnabled : Boolean;
  }

  part def StructuralFrame {
    attribute rigidityClass : String = "desktop-rigid-frame";
    attribute vibrationLimit : Millimeter = 0.10 [mm];
  }

  part def OperatorInterface {
    attribute displayBrightness : Percent;
    attribute selectedProfile : String;

    port jobPort : JobInputPort;
    port statusPort : StatusPort;
  }

  port def SafetyInterlockPort {
    out attribute emergencyStopRequested : Boolean;
    out attribute doorOpen : Boolean;
    out attribute thermalFault : Boolean;
    out attribute filamentRunout : Boolean;
  }

  part def SafetySystem {
    attribute emergencyStopLatched : Boolean;
    attribute maximumAllowedNozzleTemperature : DegreeCelsius = 295 [degC];
    attribute maximumAllowedBedTemperature : DegreeCelsius = 120 [degC];

    port interlockPort : SafetyInterlockPort;

    part doorSwitch : DoorSwitch;
    part filamentRunoutSensor : FilamentRunoutSensor;
    part thermalCutoff : ThermalCutoff;
  }

  part def DoorSwitch {
    attribute closed : Boolean;
  }

  part def FilamentRunoutSensor {
    attribute filamentPresent : Boolean;
  }

  part def ThermalCutoff {
    attribute tripped : Boolean;
    attribute tripTemperature : DegreeCelsius = 300 [degC];
  }

  action def PreparePrint {
    in item job : DigitalPrintJob;
    out item acceptedJob : DigitalPrintJob;

    first start;
    then validateBuildVolume;
    then validateMaterialProfile;
    then heatNozzleAndBed;
    then homeAxes;
    then purgeNozzle;
    then done;

    action validateBuildVolume;
    action validateMaterialProfile;
    action heatNozzleAndBed;
    action homeAxes;
    action purgeNozzle;
  }

  action def ExecuteLayeredFabrication {
    in item job : DigitalPrintJob;
    in item filament : Filament;
    out item printedPart : PrintedPart;

    first begin;
    then depositPerimeters;
    then depositInfill;
    then raiseBuildHeight;
    then repeatLayerUntilComplete;
    then coolAndReleasePart;
    then complete;

    action depositPerimeters;
    action depositInfill;
    action raiseBuildHeight;
    action repeatLayerUntilComplete;
    action coolAndReleasePart;
  }

  action def printObject {
    in item printJob : DigitalPrintJob;
    in item loadedFilament : Filament;
    out item finishedPart : PrintedPart;

    first receiveJob;
    then prepare : PreparePrint {
      in job = printJob;
    }
    then fabricate : ExecuteLayeredFabrication {
      in job = printJob;
      in filament = loadedFilament;
      out printedPart = finishedPart;
    }
    then reportCompletion;

    action receiveJob;
    action reportCompletion;
  }

  state def PrinterOperatingState {
    entry action publishStatus;

    state Off;
    state Idle;
    state JobLoaded;
    state Heating;
    state Homing;
    state Printing;
    state Paused;
    state Cooling;
    state Complete;
    state Fault;

    transition initial then Off;
    transition Off_to_Idle
      first Off
      accept PowerApplied
      then Idle;

    transition Idle_to_JobLoaded
      first Idle
      accept PrintJobReceived
      then JobLoaded;

    transition JobLoaded_to_Heating
      first JobLoaded
      accept JobValidated
      then Heating;

    transition Heating_to_Homing
      first Heating
      accept TargetTemperaturesReached
      then Homing;

    transition Homing_to_Printing
      first Homing
      accept AxesHomed
      then Printing;

    transition Printing_to_Paused
      first Printing
      accept PauseRequested
      then Paused;

    transition Paused_to_Printing
      first Paused
      accept ResumeRequested
      then Printing;

    transition Printing_to_Cooling
      first Printing
      accept ToolpathComplete
      then Cooling;

    transition Cooling_to_Complete
      first Cooling
      accept PartReleased
      then Complete;

    transition Complete_to_Idle
      first Complete
      accept PartRemoved
      then Idle;

    transition any_to_Fault
      first Off
      accept CriticalFaultDetected
      then Fault;

    transition Fault_to_Idle
      first Fault
      accept FaultCleared
      then Idle;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The 3D printing system shall transform a validated digital print job and compatible filament into a physical three-dimensional part by controlled layer-by-layer deposition of molten material within the specified build volume. */

    subject printer : ThreeDPrinter;

    require constraint {
      printer.buildPlateWidth >= 220 [mm] and
      printer.buildPlateDepth >= 220 [mm] and
      printer.buildHeight >= 250 [mm]
    }
  }

  requirement def DimensionalAccuracyRequirement {
    doc /* The printer shall fabricate completed parts with dimensional error no greater than 0.20 mm for features within the usable build volume. */

    subject part : PrintedPart;

    require constraint {
      part.dimensionalTolerance <= 0.20 [mm]
    }
  }

  requirement def LayerHeightRequirement {
    doc /* The printer shall support layer heights from 0.08 mm through 0.32 mm for standard thermoplastic filament printing. */

    subject printer : ThreeDPrinter;

    require constraint {
      printer.minimumLayerHeight <= 0.08 [mm] and
      printer.maximumLayerHeight >= 0.32 [mm]
    }
  }

  requirement def ThermalControlRequirement {
    doc /* The thermal system shall regulate nozzle and bed temperatures within 2 degrees Celsius of their commanded targets during steady-state printing. */

    subject thermalSystem : ThermalSystem;

    require constraint {
      thermalSystem.thermalStabilityBand <= 2 [degC]
    }
  }

  requirement def SafetyRequirement {
    doc /* The safety system shall stop extrusion and motion when emergency stop, door-open, filament-runout, or thermal fault conditions are detected. */

    subject safetySystem : SafetySystem;

    require constraint {
      safetySystem.maximumAllowedNozzleTemperature <= 295 [degC] and
      safetySystem.maximumAllowedBedTemperature <= 120 [degC]
    }
  }

  requirement def StatusReportingRequirement {
    doc /* The system shall report operating state, progress, elapsed time, and fault information to the operator interface during all powered operating states. */

    subject printer : ThreeDPrinter;
  }

  part desktopFdmPrinter : ThreeDPrinter {
    attribute buildPlateWidth = 220 [mm];
    attribute buildPlateDepth = 220 [mm];
    attribute buildHeight = 250 [mm];
    attribute nominalPower = 350 [W];

    part sampleJob : DigitalPrintJob {
      attribute modelName = "calibration_bracket";
      attribute layerHeight = 0.20 [mm];
      attribute infillRatio = 0.25;
      attribute estimatedDuration = 95 [min];
      attribute estimatedMaterialUse = 38 [g];
      attribute buildVolumeX = 84 [mm];
      attribute buildVolumeY = 62 [mm];
      attribute buildVolumeZ = 36 [mm];
    }

    part plaFilament : Filament {
      attribute material = "PLA";
      attribute diameter = 1.75 [mm];
      attribute massRemaining = 750 [g];
      attribute recommendedNozzleTemperature = 210 [degC];
      attribute recommendedBedTemperature = 60 [degC];
    }
  }

  satisfy PrimaryFunctionRequirement by desktopFdmPrinter;
  satisfy LayerHeightRequirement by desktopFdmPrinter;
  satisfy ThermalControlRequirement by desktopFdmPrinter.thermalSystem;
  satisfy SafetyRequirement by desktopFdmPrinter.safetySystem;
  satisfy StatusReportingRequirement by desktopFdmPrinter;

}