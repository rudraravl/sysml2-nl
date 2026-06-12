package BubbleChamberSpecification {

  import ScalarValues::*;
  import SI::*;

  attribute def Temperature {
    attribute value: Real;
    attribute unit: String = "K";
  }

  attribute def Pressure {
    attribute value: Real;
    attribute unit: String = "Pa";
  }

  attribute def Volume {
    attribute value: Real;
    attribute unit: String = "m^3";
  }

  attribute def Duration {
    attribute value: Real;
    attribute unit: String = "s";
  }

  attribute def Energy {
    attribute value: Real;
    attribute unit: String = "GeV";
  }

  attribute def MagneticFieldStrength {
    attribute value: Real;
    attribute unit: String = "T";
  }

  item def ChargedParticle {
    attribute charge: Integer;
    attribute kineticEnergy: Energy;
    attribute momentum: Real;
  }

  item def PhotonPulse {
    attribute wavelength: Real;
    attribute duration: Duration;
  }

  item def BubbleTrack {
    attribute bubbleCount: Integer;
    attribute estimatedCurvature: Real;
    attribute reconstructedMomentum: Real;
    attribute confidence: Real;
  }

  item def ChamberImage {
    attribute exposureTime: Duration;
    attribute resolutionPixels: Integer;
    attribute timestamp: Duration;
  }

  item def ControlCommand {
    attribute requestedState: String;
    attribute triggerDelay: Duration;
  }

  item def ChamberStatus {
    attribute currentPressure: Pressure;
    attribute currentTemperature: Temperature;
    attribute readyForEvent: Boolean;
    attribute faultPresent: Boolean;
  }

  port def ParticleBeamPort {
    in item particle: ChargedParticle;
  }

  port def LightPort {
    out item pulse: PhotonPulse;
  }

  port def ImagePort {
    out item image: ChamberImage;
  }

  port def DataPort {
    out item track: BubbleTrack;
  }

  port def ControlPort {
    in item command: ControlCommand;
    out item status: ChamberStatus;
  }

  part def BubbleChamberSystem {
    attribute operatingTemperature: Temperature = (value = 289.0, unit = "K");
    attribute compressedPressure: Pressure = (value = 620000.0, unit = "Pa");
    attribute expandedPressure: Pressure = (value = 180000.0, unit = "Pa");
    attribute expansionWindow: Duration = (value = 0.015, unit = "s");

    port beamInput: ParticleBeamPort;
    port control: ControlPort;
    port dataOutput: DataPort;

    part chamberBody: PressureVessel;
    part workingFluid: SuperheatedLiquid;
    part expansionSystem: ExpansionCompressionSystem;
    part magnet: MagneticFieldAssembly;
    part illumination: IlluminationSystem;
    part cameraArray: ImagingSystem;
    part reconstructionComputer: TrackReconstructionComputer;
    part safetyController: SafetyController;

    connect beamInput to chamberBody.beamEntry;
    connect expansionSystem.volumeInterface to chamberBody.volumeControl;
    connect illumination.lightOutput to chamberBody.lightInput;
    connect chamberBody.imageView to cameraArray.sceneInput;
    connect cameraArray.imageOutput to reconstructionComputer.imageInput;
    connect reconstructionComputer.trackOutput to dataOutput;
    connect control to safetyController.operatorControl;
    connect safetyController.chamberControl to expansionSystem.controlInput;
    connect safetyController.statusInput to chamberBody.statusOutput;
  }

  part def PressureVessel {
    attribute internalVolume: Volume = (value = 0.75, unit = "m^3");
    attribute maximumSafePressure: Pressure = (value = 900000.0, unit = "Pa");

    port beamEntry: ParticleBeamPort;
    port lightInput: LightPort;
    port imageView: ImagePort;
    port volumeControl: ControlPort;
    port statusOutput: ControlPort;

    part transparentWindows: WindowAssembly;
    part fiducialMarkers: FiducialMarkerGrid;
  }

  part def SuperheatedLiquid {
    attribute liquidName: String = "liquid hydrogen";
    attribute nominalTemperature: Temperature = (value = 289.0, unit = "K");
    attribute nominalPressure: Pressure = (value = 180000.0, unit = "Pa");
    attribute sensitiveVolume: Volume = (value = 0.65, unit = "m^3");
  }

  part def ExpansionCompressionSystem {
    attribute pistonStrokeVolume: Volume = (value = 0.08, unit = "m^3");
    attribute expansionTime: Duration = (value = 0.006, unit = "s");
    attribute recompressionTime: Duration = (value = 0.050, unit = "s");

    port controlInput: ControlPort;
    port volumeInterface: ControlPort;

    part piston: HydraulicPiston;
    part pressureSensor: PressureSensor;
    part actuatorValve: FastValve;
  }

  part def MagneticFieldAssembly {
    attribute fieldStrength: MagneticFieldStrength = (value = 1.8, unit = "T");
    attribute fieldUniformity: Real = 0.97;

    part coilSet: MagnetCoils;
    part powerSupply: MagnetPowerSupply;
  }

  part def IlluminationSystem {
    attribute pulseDuration: Duration = (value = 0.000002, unit = "s");
    attribute wavelength: Real = 450.0;

    port lightOutput: LightPort;

    part flashLamp: FlashLamp;
    part diffuser: OpticalDiffuser;
    part triggerDriver: PulseDriver;
  }

  part def ImagingSystem {
    attribute cameraCount: Integer = 4;
    attribute frameResolutionPixels: Integer = 24000000;

    port sceneInput: ImagePort;
    port imageOutput: ImagePort;

    part cameras: Camera[4];
    part synchronizationUnit: TimingSynchronizer;
  }

  part def TrackReconstructionComputer {
    port imageInput: ImagePort;
    port trackOutput: DataPort;

    part imageProcessor: ImageProcessor;
    part geometryCalibrator: GeometryCalibrator;
    part momentumEstimator: MomentumEstimator;
  }

  part def SafetyController {
    attribute maximumAllowedPressure: Pressure = (value = 850000.0, unit = "Pa");
    attribute minimumAllowedPressure: Pressure = (value = 100000.0, unit = "Pa");

    port operatorControl: ControlPort;
    port chamberControl: ControlPort;
    port statusInput: ControlPort;
  }

  part def WindowAssembly;
  part def FiducialMarkerGrid;
  part def HydraulicPiston;
  part def PressureSensor;
  part def FastValve;
  part def MagnetCoils;
  part def MagnetPowerSupply;
  part def FlashLamp;
  part def OpticalDiffuser;
  part def PulseDriver;
  part def Camera;
  part def TimingSynchronizer;
  part def ImageProcessor;
  part def GeometryCalibrator;
  part def MomentumEstimator;

  action def DetectParticleTrajectory {
    in item incidentParticle: ChargedParticle;
    out item reconstructedTrack: BubbleTrack;

    action prepareSensitiveLiquid;
    action expandChamberVolume;
    action formBubblesAlongIonizationPath;
    action illuminateBubbleTrail;
    action captureStereoImages;
    action reconstructTrajectory;
    action recompressLiquid;

    first prepareSensitiveLiquid
      then expandChamberVolume
      then formBubblesAlongIonizationPath
      then illuminateBubbleTrail
      then captureStereoImages
      then reconstructTrajectory
      then recompressLiquid;
  }

  state def ChamberOperatingState {
    state Off;
    state PressurizedStandby;
    state ReadySuperheated;
    state Expanding;
    state Sensitive;
    state Imaging;
    state Recompressing;
    state Fault;

    transition initial then Off;
    transition Off then PressurizedStandby
      accept ControlCommand
      if command.requestedState == "START";

    transition PressurizedStandby then ReadySuperheated
      if not status.faultPresent;

    transition ReadySuperheated then Expanding
      accept ChargedParticle;

    transition Expanding then Sensitive
      after Duration(value = 0.006, unit = "s");

    transition Sensitive then Imaging
      after Duration(value = 0.015, unit = "s");

    transition Imaging then Recompressing
      after Duration(value = 0.002, unit = "s");

    transition Recompressing then PressurizedStandby
      after Duration(value = 0.050, unit = "s");

    transition PressurizedStandby then Fault
      if status.faultPresent;

    transition ReadySuperheated then Fault
      if status.faultPresent;

    transition Fault then Off
      accept ControlCommand
      if command.requestedState == "SHUTDOWN";
  }

  requirement def PrimaryFunctionRequirement {
    subject chamber: BubbleChamberSystem;

    doc /* The bubble chamber system shall provide a controlled superheated liquid volume that makes the trajectories of ionizing charged particles visible as bubble trails, records those trails as synchronized images, and reconstructs high-level particle track data for analysis. */
  }

  requirement def SensitiveVolumeRequirement {
    subject fluid: SuperheatedLiquid;

    require constraint {
      fluid.sensitiveVolume.value >= 0.60
    }
  }

  requirement def PressureSafetyRequirement {
    subject system: BubbleChamberSystem;

    require constraint {
      system.compressedPressure.value < system.chamberBody.maximumSafePressure.value
    }
  }

  requirement def ExpansionTimingRequirement {
    subject system: BubbleChamberSystem;

    require constraint {
      system.expansionWindow.value <= 0.020
    }
  }

  requirement def ImagingRequirement {
    subject imaging: ImagingSystem;

    require constraint {
      imaging.cameraCount >= 3 and imaging.frameResolutionPixels >= 12000000
    }
  }

  requirement def MagneticDeflectionRequirement {
    subject magnet: MagneticFieldAssembly;

    require constraint {
      magnet.fieldStrength.value >= 1.0 and magnet.fieldUniformity >= 0.95
    }
  }

  satisfy PrimaryFunctionRequirement by BubbleChamberSystem;
  satisfy SensitiveVolumeRequirement by SuperheatedLiquid;
  satisfy PressureSafetyRequirement by BubbleChamberSystem;
  satisfy ExpansionTimingRequirement by BubbleChamberSystem;
  satisfy ImagingRequirement by ImagingSystem;
  satisfy MagneticDeflectionRequirement by MagneticFieldAssembly;

  analysis def TrackDetectionAnalysis {
    in item particle: ChargedParticle;
    in attribute field: MagneticFieldStrength;
    out item track: BubbleTrack;

    objective {
      estimate track.reconstructedMomentum from particle.momentum and field.value;
    }
  }

}