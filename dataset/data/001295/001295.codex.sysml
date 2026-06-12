package TriDAR_RelativeNavigationSystem {

  import ScalarValues::*;
  import SI::*;

  attribute def Length;
  attribute def Angle;
  attribute def Time;
  attribute def Velocity;
  attribute def Frequency;
  attribute def Power;
  attribute def Temperature;
  attribute def Irradiance;
  attribute def Confidence;
  attribute def BooleanFlag;

  item def LaserPulse {
    attribute wavelength : Length = 1550 [SI::nano*SI::m];
    attribute pulseWidth : Time;
    attribute repetitionRate : Frequency;
    attribute emittedPower : Power;
  }

  item def RangeImage {
    attribute frameTime : Time;
    attribute horizontalFieldOfView : Angle;
    attribute verticalFieldOfView : Angle;
    attribute rangeResolution : Length;
    attribute maxRange : Length;
    attribute pointCount : ScalarValues::Integer;
  }

  item def ThermalImage {
    attribute frameTime : Time;
    attribute horizontalFieldOfView : Angle;
    attribute verticalFieldOfView : Angle;
    attribute detectorTemperature : Temperature;
    attribute targetContrast : Temperature;
  }

  item def RelativeNavigationSolution {
    attribute range : Length;
    attribute rangeRate : Velocity;
    attribute lineOfSightAzimuth : Angle;
    attribute lineOfSightElevation : Angle;
    attribute relativeAttitudeRoll : Angle;
    attribute relativeAttitudePitch : Angle;
    attribute relativeAttitudeYaw : Angle;
    attribute poseConfidence : Confidence;
    attribute solutionAge : Time;
  }

  item def VehicleStateEstimate {
    attribute targetAcquired : BooleanFlag;
    attribute dockingAxisAligned : BooleanFlag;
    attribute closingRateSafe : BooleanFlag;
    attribute navigationQuality : Confidence;
  }

  item def CommandedRelativeMotion {
    attribute desiredClosingRate : Velocity;
    attribute desiredLateralRate : Velocity;
    attribute desiredVerticalRate : Velocity;
    attribute desiredYawRate : Angle;
  }

  item def FaultReport {
    attribute faultCode : ScalarValues::String;
    attribute faultSeverity : ScalarValues::Integer;
    attribute timeSinceDetection : Time;
  }

  port def OpticalEmissionPort {
    out item pulse : LaserPulse;
  }

  port def OpticalReceivePort {
    in item rangeFrame : RangeImage;
    in item thermalFrame : ThermalImage;
  }

  port def NavigationOutputPort {
    out item navSolution : RelativeNavigationSolution;
    out item stateEstimate : VehicleStateEstimate;
  }

  port def GuidanceCommandPort {
    out item motionCommand : CommandedRelativeMotion;
  }

  port def FaultPort {
    out item fault : FaultReport;
  }

  port def PowerInputPort {
    in attribute suppliedVoltage : ScalarValues::Real;
    in attribute suppliedPower : Power;
  }

  port def DataPort {
    inout item navData : RelativeNavigationSolution;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : TriDARBasedRendezvousSystem;
    require constraint {
      system.primaryFunction ==
      "Provide autonomous, high-confidence relative pose and range-rate estimates for spacecraft rendezvous, proximity operations, and docking using TriDAR laser range imaging and thermal imaging."
    }
  }

  requirement def AcquisitionRangeRequirement {
    subject sensor : TriDARSensorHead;
    require constraint {
      sensor.maximumAcquisitionRange >= 2000 [SI::m]
    }
  }

  requirement def DockingPrecisionRequirement {
    subject processor : RelativeNavigationProcessor;
    require constraint {
      processor.finalApproachRangeError <= 0.05 [SI::m] and
      processor.finalApproachAttitudeError <= 0.5 [SI::degree]
    }
  }

  requirement def SafeClosingRateRequirement {
    subject guidance : RendezvousGuidanceController;
    require constraint {
      guidance.maximumCommandedClosingRate <= 0.20 [SI::m/SI::s]
    }
  }

  requirement def FaultDetectionRequirement {
    subject monitor : HealthAndFaultManager;
    require constraint {
      monitor.maximumFaultDetectionLatency <= 1.0 [SI::s]
    }
  }

  action def EmitLaserScan {
    in attribute scanPattern : ScalarValues::String;
    out item pulseTrain : LaserPulse;
  }

  action def CaptureRangeAndThermalFrames {
    in item pulseTrain : LaserPulse;
    out item rangeFrame : RangeImage;
    out item thermalFrame : ThermalImage;
  }

  action def RegisterTargetGeometry {
    in item rangeFrame : RangeImage;
    in item thermalFrame : ThermalImage;
    out item navSolution : RelativeNavigationSolution;
  }

  action def ValidateNavigationQuality {
    in item navSolution : RelativeNavigationSolution;
    out item stateEstimate : VehicleStateEstimate;
  }

  action def ComputeApproachCommand {
    in item navSolution : RelativeNavigationSolution;
    in item stateEstimate : VehicleStateEstimate;
    out item motionCommand : CommandedRelativeMotion;
  }

  state def RendezvousNavigationStateMachine {
    entry action InitializeSensor;
    state Standby;
    state Search;
    state AcquireTarget;
    state TrackTarget;
    state FinalApproach;
    state DockingHold;
    state Faulted;

    transition first Standby;
    transition Standby_to_Search
      first Standby then Search
      accept StartRendezvous;

    transition Search_to_AcquireTarget
      first Search then AcquireTarget
      if targetCandidateDetected;

    transition AcquireTarget_to_TrackTarget
      first AcquireTarget then TrackTarget
      if poseConfidenceAcceptable;

    transition TrackTarget_to_FinalApproach
      first TrackTarget then FinalApproach
      if rangeBelowFinalApproachThreshold;

    transition FinalApproach_to_DockingHold
      first FinalApproach then DockingHold
      if captureEnvelopeReached;

    transition Any_to_Faulted
      first Standby then Faulted
      accept CriticalFault;

    transition Search_to_Faulted
      first Search then Faulted
      accept CriticalFault;

    transition AcquireTarget_to_Faulted
      first AcquireTarget then Faulted
      accept CriticalFault;

    transition TrackTarget_to_Faulted
      first TrackTarget then Faulted
      accept CriticalFault;

    transition FinalApproach_to_Faulted
      first FinalApproach then Faulted
      accept CriticalFault;
  }

  part def LaserTransmitter {
    attribute wavelength : Length = 1550 [SI::nano*SI::m];
    attribute pulseWidth : Time = 12 [SI::nano*SI::s];
    attribute repetitionRate : Frequency = 20000 [SI::Hz];
    attribute peakOpticalPower : Power = 8 [SI::W];

    port opticalOut : OpticalEmissionPort;

    perform action emit : EmitLaserScan;
  }

  part def RangeImagingReceiver {
    attribute rangeResolution : Length = 0.02 [SI::m];
    attribute maximumRange : Length = 2500 [SI::m];
    attribute minimumRange : Length = 0.5 [SI::m];
    attribute frameRate : Frequency = 10 [SI::Hz];

    port opticalIn : OpticalReceivePort;
  }

  part def ThermalImager {
    attribute spectralBandLower : Length = 8 [SI::micro*SI::m];
    attribute spectralBandUpper : Length = 14 [SI::micro*SI::m];
    attribute frameRate : Frequency = 10 [SI::Hz];
    attribute thermalSensitivity : Temperature = 0.05 [SI::K];

    port thermalOut : OpticalReceivePort;
  }

  part def TriDARSensorHead {
    attribute mass : ScalarValues::Real = 14.5;
    attribute maximumAcquisitionRange : Length = 2500 [SI::m];
    attribute minimumTrackingRange : Length = 0.5 [SI::m];
    attribute horizontalFieldOfView : Angle = 40 [SI::degree];
    attribute verticalFieldOfView : Angle = 30 [SI::degree];
    attribute operatingTemperatureLow : Temperature = 253 [SI::K];
    attribute operatingTemperatureHigh : Temperature = 323 [SI::K];

    part transmitter : LaserTransmitter;
    part receiver : RangeImagingReceiver;
    part thermalImager : ThermalImager;

    port powerIn : PowerInputPort;
    port opticalOut : OpticalEmissionPort;
    port opticalIn : OpticalReceivePort;

    connection laserPath connect transmitter.opticalOut to opticalOut;
    connection returnPath connect opticalIn to receiver.opticalIn;
    connection thermalPath connect thermalImager.thermalOut to opticalIn;

    perform action scanAndCapture : CaptureRangeAndThermalFrames;
  }

  part def RelativeNavigationProcessor {
    attribute nominalUpdateRate : Frequency = 10 [SI::Hz];
    attribute finalApproachRangeError : Length = 0.03 [SI::m];
    attribute finalApproachAttitudeError : Angle = 0.3 [SI::degree];
    attribute minimumPoseConfidence : Confidence = 0.92;
    attribute maximumSolutionAge : Time = 0.2 [SI::s];

    port sensorDataIn : OpticalReceivePort;
    port navigationOut : NavigationOutputPort;

    perform action targetRegistration : RegisterTargetGeometry;
    perform action qualityValidation : ValidateNavigationQuality;
  }

  part def RendezvousGuidanceController {
    attribute finalApproachStartRange : Length = 30 [SI::m];
    attribute maximumCommandedClosingRate : Velocity = 0.15 [SI::m/SI::s];
    attribute lateralDeadband : Length = 0.03 [SI::m];
    attribute attitudeDeadband : Angle = 0.2 [SI::degree];

    port navIn : DataPort;
    port commandOut : GuidanceCommandPort;

    perform action commandComputation : ComputeApproachCommand;
  }

  part def HealthAndFaultManager {
    attribute maximumFaultDetectionLatency : Time = 0.5 [SI::s];
    attribute minimumAllowableInputPower : Power = 45 [SI::W];
    attribute maximumAllowableInputPower : Power = 120 [SI::W];
    attribute maximumDroppedFrameInterval : Time = 0.5 [SI::s];

    port faultOut : FaultPort;
  }

  part def SpacecraftAvionicsInterface {
    port navDataBus : DataPort;
    port guidanceBus : GuidanceCommandPort;
    port faultBus : FaultPort;
  }

  part def TargetSpacecraft {
    attribute dockingPortDiameter : Length = 1.2 [SI::m];
    attribute cooperativeReflectorCount : ScalarValues::Integer = 0;
    attribute thermalFeatureContrast : Temperature = 8 [SI::K];

    port reflectedOptics : OpticalReceivePort;
  }

  part def TriDARBasedRendezvousSystem {
    attribute primaryFunction : ScalarValues::String =
      "Provide autonomous, high-confidence relative pose and range-rate estimates for spacecraft rendezvous, proximity operations, and docking using TriDAR laser range imaging and thermal imaging.";

    attribute systemMass : ScalarValues::Real = 24.0;
    attribute nominalInputPower : Power = 85 [SI::W];
    attribute navigationAvailability : Confidence = 0.995;

    part sensorHead : TriDARSensorHead;
    part navigationProcessor : RelativeNavigationProcessor;
    part guidanceController : RendezvousGuidanceController;
    part faultManager : HealthAndFaultManager;
    part avionicsInterface : SpacecraftAvionicsInterface;
    part target : TargetSpacecraft;

    port powerIn : PowerInputPort;
    port navigationOut : NavigationOutputPort;
    port commandOut : GuidanceCommandPort;
    port faultOut : FaultPort;

    connection powerDistribution connect powerIn to sensorHead.powerIn;
    connection opticalEmission connect sensorHead.opticalOut to target.reflectedOptics;
    connection sensorToProcessor connect sensorHead.opticalIn to navigationProcessor.sensorDataIn;
    connection processorToAvionics connect navigationProcessor.navigationOut to navigationOut;
    connection navToGuidance connect navigationOut to guidanceController.navIn;
    connection guidanceToAvionics connect guidanceController.commandOut to commandOut;
    connection faultToAvionics connect faultManager.faultOut to faultOut;

    perform action missionLoop {
      first sensorHead.scanAndCapture;
      then navigationProcessor.targetRegistration;
      then navigationProcessor.qualityValidation;
      then guidanceController.commandComputation;
    }

    exhibit stateMachine : RendezvousNavigationStateMachine;
  }

  satisfy PrimaryFunctionRequirement by TriDARBasedRendezvousSystem;
  satisfy AcquisitionRangeRequirement by TriDARSensorHead;
  satisfy DockingPrecisionRequirement by RelativeNavigationProcessor;
  satisfy SafeClosingRateRequirement by RendezvousGuidanceController;
  satisfy FaultDetectionRequirement by HealthAndFaultManager;

}