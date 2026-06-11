package UltrasoundComputerTomographyModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Frequency :> scalar values::Real;
  attribute def AcousticPressure :> scalar values::Real;
  attribute def AcousticIntensity :> scalar values::Real;
  attribute def Temperature :> scalar values::Real;
  attribute def TimeDuration :> scalar values::Real;
  attribute def Length :> scalar values::Real;
  attribute def DataRate :> scalar values::Real;
  attribute def Voltage :> scalar values::Real;
  attribute def Power :> scalar values::Real;
  attribute def Ratio :> scalar values::Real;

  item def UltrasoundPulse {
    attribute centerFrequency : Frequency;
    attribute bandwidth : Frequency;
    attribute peakPressure : AcousticPressure;
    attribute pulseDuration : TimeDuration;
    attribute transmitAngle : scalar values::Real;
  }

  item def AcousticEchoSignal {
    attribute receiveChannelId : scalar values::Integer;
    attribute samplingRate : Frequency;
    attribute amplitude : Voltage;
    attribute timeOfFlight : TimeDuration;
    attribute signalToNoiseRatio : Ratio;
  }

  item def TomographyRawFrame {
    attribute projectionIndex : scalar values::Integer;
    attribute channelCount : scalar values::Integer;
    attribute acquisitionTime : TimeDuration;
    part echoSignals : AcousticEchoSignal[1..*];
  }

  item def ReconstructedVolume {
    attribute voxelSpacing : Length;
    attribute voxelCountX : scalar values::Integer;
    attribute voxelCountY : scalar values::Integer;
    attribute voxelCountZ : scalar values::Integer;
    attribute soundSpeedMapResolution : Length;
    attribute attenuationMapResolution : Length;
  }

  item def DiagnosticStudy {
    attribute studyId : scalar values::String;
    attribute patientAnonymousId : scalar values::String;
    attribute scanRegion : scalar values::String;
    attribute reconstructionStatus : scalar values::String;
    part volume : ReconstructedVolume;
  }

  port def AcousticTransmitPort {
    out item pulse : UltrasoundPulse;
  }

  port def AcousticReceivePort {
    in item echo : AcousticEchoSignal;
  }

  port def DigitalDataOutPort {
    out item study : DiagnosticStudy;
  }

  port def DigitalFramePort {
    out item frame : TomographyRawFrame;
  }

  port def RawFrameInPort {
    in item frame : TomographyRawFrame;
  }

  port def VolumeOutPort {
    out item volume : ReconstructedVolume;
  }

  port def VolumeInPort {
    in item volume : ReconstructedVolume;
  }

  port def PowerPort {
    in attribute supplyVoltage : Voltage;
    in attribute availablePower : Power;
  }

  port def CoolingPort {
    in attribute coolantTemperature : Temperature;
    out attribute heatLoad : Power;
  }

  part def RingTransducerArray {
    attribute elementCount : scalar values::Integer = 1024;
    attribute nominalFrequency : Frequency = 3.5;
    attribute apertureDiameter : Length = 0.28;
    attribute maxPulsePressure : AcousticPressure = 0.8;
    attribute maxSurfaceTemperature : Temperature = 41.0;

    port transmit : AcousticTransmitPort[1024];
    port receive : AcousticReceivePort[1024];
    port power : PowerPort;
    port cooling : CoolingPort;

    action generateSequentialPulse {
      in attribute projectionIndex : scalar values::Integer;
      out item pulse : UltrasoundPulse;
    }

    state transducerOperatingState {
      state Off;
      state Standby;
      state Calibrating;
      state Emitting;
      state Receiving;
      state Fault;

      entry; then Off;

      transition powerApplied first Off then Standby;
      transition startCalibration first Standby then Calibrating;
      transition calibrationComplete first Calibrating then Standby;
      transition startProjection first Standby then Emitting;
      transition pulseSent first Emitting then Receiving;
      transition echoesCaptured first Receiving then Standby;
      transition overTemperature first Standby then Fault;
      transition emissionFault first Emitting then Fault;
      transition reset first Fault then Standby;
      transition powerRemoved first Standby then Off;
    }
  }

  part def WaterCouplingBasin {
    attribute waterTemperature : Temperature = 35.0;
    attribute soundSpeedInWater : scalar values::Real = 1520.0;
    attribute fillVolume : scalar values::Real = 18.0;
    attribute degassingLevel : Ratio = 0.95;

    port acousticFromArray : AcousticTransmitPort;
    port acousticToArray : AcousticReceivePort;
    port cooling : CoolingPort;

    action stabilizeCouplingMedium {
      in attribute targetTemperature : Temperature;
      in attribute targetDegassingLevel : Ratio;
      out attribute stable : scalar values::Boolean;
    }

    state basinState {
      state Empty;
      state Filling;
      state Degassing;
      state TemperatureControl;
      state Ready;
      state Drain;

      entry; then Empty;

      transition fillCommand first Empty then Filling;
      transition filled first Filling then Degassing;
      transition degassed first Degassing then TemperatureControl;
      transition temperatureStable first TemperatureControl then Ready;
      transition drainCommand first Ready then Drain;
      transition drained first Drain then Empty;
    }
  }

  part def PatientSupport {
    attribute tablePosition : Length;
    attribute verticalTravel : Length = 0.45;
    attribute positionAccuracy : Length = 0.001;
    attribute maxPatientMass : scalar values::Real = 180.0;

    action positionAnatomyInRing {
      in attribute requestedPosition : Length;
      out attribute achievedPosition : Length;
      out attribute withinTolerance : scalar values::Boolean;
    }

    state supportState {
      state Locked;
      state Moving;
      state Positioned;
      state EmergencyStop;

      entry; then Locked;

      transition moveCommand first Locked then Moving;
      transition positionReached first Moving then Positioned;
      transition lockCommand first Positioned then Locked;
      transition obstructionDetected first Moving then EmergencyStop;
      transition resetStop first EmergencyStop then Locked;
    }
  }

  part def PulserReceiverElectronics {
    attribute transmitVoltage : Voltage = 120.0;
    attribute receiverDynamicRange : scalar values::Real = 96.0;
    attribute channelCount : scalar values::Integer = 1024;
    attribute maxPulseRepetitionFrequency : Frequency = 5000.0;

    port power : PowerPort;
    port pulseOut : AcousticTransmitPort[1024];
    port echoIn : AcousticReceivePort[1024];
    port frameOut : DigitalFramePort;

    action exciteTransducerElements {
      in item pulseCommand : UltrasoundPulse;
      out item emittedPulse : UltrasoundPulse;
    }

    action digitizeReceivedEchoes {
      in item analogEcho : AcousticEchoSignal[1..*];
      out item rawFrame : TomographyRawFrame;
    }
  }

  part def AcquisitionController {
    attribute projectionCount : scalar values::Integer = 720;
    attribute framesPerSecond : scalar values::Real = 10.0;
    attribute timingJitter : TimeDuration = 0.00000001;

    port rawFrameOut : DigitalFramePort;
    port power : PowerPort;

    action runTomographicScan {
      in attribute projectionCount : scalar values::Integer;
      out item frames : TomographyRawFrame[1..*];
    }

    state scanState {
      state Idle;
      state Preparing;
      state AcquiringProjection;
      state VerifyingFrame;
      state Completed;
      state Aborted;

      entry; then Idle;

      transition startScan first Idle then Preparing;
      transition readyToAcquire first Preparing then AcquiringProjection;
      transition projectionCaptured first AcquiringProjection then VerifyingFrame;
      transition frameValid first VerifyingFrame then AcquiringProjection;
      transition allProjectionsCaptured first VerifyingFrame then Completed;
      transition userAbort first Preparing then Aborted;
      transition acquisitionFault first AcquiringProjection then Aborted;
      transition reset first Completed then Idle;
      transition resetAbort first Aborted then Idle;
    }
  }

  part def ReconstructionComputer {
    attribute processorCount : scalar values::Integer = 64;
    attribute memoryCapacity : scalar values::Real = 256.0;
    attribute inputDataRate : DataRate = 6.0;
    attribute reconstructionTimeLimit : TimeDuration = 120.0;

    port rawFrameIn : RawFrameInPort;
    port volumeOut : VolumeOutPort;
    port power : PowerPort;

    action reconstructSoundSpeedAndAttenuation {
      in item frames : TomographyRawFrame[1..*];
      out item volume : ReconstructedVolume;
    }

    action applyArtifactReduction {
      in item preliminaryVolume : ReconstructedVolume;
      out item correctedVolume : ReconstructedVolume;
    }

    state reconstructionState {
      state WaitingForFrames;
      state Preprocessing;
      state IterativeReconstruction;
      state ArtifactCorrection;
      state VolumeReady;
      state ReconstructionFault;

      entry; then WaitingForFrames;

      transition framesReceived first WaitingForFrames then Preprocessing;
      transition preprocessingComplete first Preprocessing then IterativeReconstruction;
      transition convergenceReached first IterativeReconstruction then ArtifactCorrection;
      transition correctionComplete first ArtifactCorrection then VolumeReady;
      transition insufficientData first Preprocessing then ReconstructionFault;
      transition numericalFailure first IterativeReconstruction then ReconstructionFault;
      transition exportComplete first VolumeReady then WaitingForFrames;
      transition resetFault first ReconstructionFault then WaitingForFrames;
    }
  }

  part def VisualizationWorkstation {
    attribute displayResolutionX : scalar values::Integer = 3840;
    attribute displayResolutionY : scalar values::Integer = 2160;
    attribute maxInteractiveFrameRate : Frequency = 60.0;

    port volumeIn : VolumeInPort;
    port studyOut : DigitalDataOutPort;
    port power : PowerPort;

    action renderDiagnosticViews {
      in item volume : ReconstructedVolume;
      out item study : DiagnosticStudy;
    }

    action exportStudy {
      in item study : DiagnosticStudy;
      out attribute exported : scalar values::Boolean;
    }
  }

  part def SafetySupervisor {
    attribute maxAllowedAcousticIntensity : AcousticIntensity = 720.0;
    attribute maxAllowedWaterTemperature : Temperature = 39.0;
    attribute maxAllowedTransducerTemperature : Temperature = 41.0;
    attribute emergencyStopLatency : TimeDuration = 0.05;

    action monitorSafetyLimits {
      in attribute acousticIntensity : AcousticIntensity;
      in attribute waterTemperature : Temperature;
      in attribute transducerTemperature : Temperature;
      out attribute safeToScan : scalar values::Boolean;
    }

    action stopEmission {
      out attribute emissionDisabled : scalar values::Boolean;
    }

    state safetyState {
      state Safe;
      state Warning;
      state Interlocked;
      state EmergencyStopped;

      entry; then Safe;

      transition limitApproaching first Safe then Warning;
      transition limitNormal first Warning then Safe;
      transition limitExceeded first Warning then Interlocked;
      transition immediateHazard first Safe then EmergencyStopped;
      transition operatorReset first Interlocked then Safe;
      transition serviceReset first EmergencyStopped then Safe;
    }
  }

  part def UltrasoundComputerTomographySystem {
    attribute systemName : scalar values::String = "Ultrasound Computer Tomography System";
    attribute primaryFunction : scalar values::String =
      "Acquire multi-angle ultrasound transmission and reflection data around an immersed anatomy region and reconstruct a three-dimensional map of acoustic properties for diagnostic review.";
    attribute scanVolumeDiameter : Length = 0.22;
    attribute scanVolumeHeight : Length = 0.18;
    attribute nominalCenterFrequency : Frequency = 3.5;
    attribute targetVoxelSpacing : Length = 0.0008;
    attribute maximumScanDuration : TimeDuration = 180.0;

    part transducerArray : RingTransducerArray;
    part couplingBasin : WaterCouplingBasin;
    part patientSupport : PatientSupport;
    part pulserReceiver : PulserReceiverElectronics;
    part acquisitionController : AcquisitionController;
    part reconstructionComputer : ReconstructionComputer;
    part workstation : VisualizationWorkstation;
    part safetySupervisor : SafetySupervisor;

    port powerInput : PowerPort;
    port studyOutput : DigitalDataOutPort;

    connect powerInput to transducerArray.power;
    connect powerInput to pulserReceiver.power;
    connect powerInput to acquisitionController.power;
    connect powerInput to reconstructionComputer.power;
    connect powerInput to workstation.power;

    connect transducerArray.transmit to pulserReceiver.pulseOut;
    connect transducerArray.receive to pulserReceiver.echoIn;
    connect pulserReceiver.frameOut to acquisitionController.rawFrameOut;
    connect acquisitionController.rawFrameOut to reconstructionComputer.rawFrameIn;
    connect reconstructionComputer.volumeOut to workstation.volumeIn;
    connect workstation.studyOut to studyOutput;

    connect transducerArray.cooling to couplingBasin.cooling;

    action performUltrasoundTomographyStudy {
      in attribute patientAnonymousId : scalar values::String;
      in attribute scanRegion : scalar values::String;
      out item completedStudy : DiagnosticStudy;

      first start;
      then preparePatient;
      then stabilizeCoupling;
      then calibrateArray;
      then acquireProjectionData;
      then reconstructVolume;
      then generateDiagnosticStudy;
      then done;

      action preparePatient {
        out attribute positioned : scalar values::Boolean;
      }

      action stabilizeCoupling {
        out attribute couplingReady : scalar values::Boolean;
      }

      action calibrateArray {
        out attribute calibrated : scalar values::Boolean;
      }

      action acquireProjectionData {
        out item frames : TomographyRawFrame[720];
      }

      action reconstructVolume {
        in item frames : TomographyRawFrame[720];
        out item volume : ReconstructedVolume;
      }

      action generateDiagnosticStudy {
        in item volume : ReconstructedVolume;
        out item completedStudy : DiagnosticStudy;
      }
    }

    state systemLifecycle {
      state PoweredOff;
      state Initializing;
      state Ready;
      state PatientSetup;
      state CouplingPreparation;
      state Calibration;
      state Scanning;
      state Reconstruction;
      state Review;
      state Shutdown;
      state Fault;

      entry; then PoweredOff;

      transition powerOn first PoweredOff then Initializing;
      transition initializationComplete first Initializing then Ready;
      transition beginStudy first Ready then PatientSetup;
      transition patientPositioned first PatientSetup then CouplingPreparation;
      transition couplingReady first CouplingPreparation then Calibration;
      transition calibrationComplete first Calibration then Scanning;
      transition scanComplete first Scanning then Reconstruction;
      transition reconstructionComplete first Reconstruction then Review;
      transition studyClosed first Review then Ready;
      transition shutdownCommand first Ready then Shutdown;
      transition shutdownComplete first Shutdown then PoweredOff;
      transition safetyInterlock first PatientSetup then Fault;
      transition acquisitionFault first Scanning then Fault;
      transition reconstructionFault first Reconstruction then Fault;
      transition serviceReset first Fault then Ready;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : UltrasoundComputerTomographySystem;

    require constraint {
      system.primaryFunction ==
      "Acquire multi-angle ultrasound transmission and reflection data around an immersed anatomy region and reconstruct a three-dimensional map of acoustic properties for diagnostic review."
    }
  }

  requirement def ScanCoverageRequirement {
    subject system : UltrasoundComputerTomographySystem;

    require constraint {
      system.scanVolumeDiameter >= 0.20 and
      system.scanVolumeHeight >= 0.15 and
      system.acquisitionController.projectionCount >= 360
    }
  }

  requirement def ResolutionRequirement {
    subject system : UltrasoundComputerTomographySystem;

    require constraint {
      system.targetVoxelSpacing <= 0.001
    }
  }

  requirement def ScanDurationRequirement {
    subject system : UltrasoundComputerTomographySystem;

    require constraint {
      system.maximumScanDuration <= 180.0
    }
  }

  requirement def AcousticSafetyRequirement {
    subject system : UltrasoundComputerTomographySystem;

    require constraint {
      system.safetySupervisor.maxAllowedAcousticIntensity <= 720.0 and
      system.safetySupervisor.maxAllowedWaterTemperature <= 39.0 and
      system.safetySupervisor.maxAllowedTransducerTemperature <= 41.0
    }
  }

  requirement def ReconstructionOutputRequirement {
    subject volume : ReconstructedVolume;

    require constraint {
      volume.voxelSpacing <= 0.001 and
      volume.voxelCountX >= 200 and
      volume.voxelCountY >= 200 and
      volume.voxelCountZ >= 150
    }
  }

  requirement def DataIntegrityRequirement {
    subject frame : TomographyRawFrame;

    require constraint {
      frame.channelCount >= 512 and
      frame.projectionIndex >= 0
    }
  }

  satisfy PrimaryFunctionRequirement by UltrasoundComputerTomographySystem;
  satisfy ScanCoverageRequirement by UltrasoundComputerTomographySystem;
  satisfy ResolutionRequirement by UltrasoundComputerTomographySystem;
  satisfy ScanDurationRequirement by UltrasoundComputerTomographySystem;
  satisfy AcousticSafetyRequirement by SafetySupervisor;
  satisfy ReconstructionOutputRequirement by ReconstructionComputer;
  satisfy DataIntegrityRequirement by AcquisitionController;

  part ultrasoundComputerTomographySystem : UltrasoundComputerTomographySystem;

}