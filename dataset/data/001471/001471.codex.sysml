package InfraredSensingSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Temperature {
    :> scalar;
    unit = K;
  }

  attribute def Distance {
    :> scalar;
    unit = m;
  }

  attribute def Power {
    :> scalar;
    unit = W;
  }

  attribute def Voltage {
    :> scalar;
    unit = V;
  }

  attribute def Current {
    :> scalar;
    unit = A;
  }

  attribute def Frequency {
    :> scalar;
    unit = Hz;
  }

  attribute def Angle {
    :> scalar;
    unit = rad;
  }

  attribute def BitRate {
    :> scalar;
    unit = bit / s;
  }

  attribute def Percent {
    :> scalar;
  }

  item def InfraredRadiation {
    attribute wavelength : Length;
    attribute radiantPower : Power;
    attribute sourceTemperature : Temperature;
    attribute incidentAngle : Angle;
  }

  item def ThermalImageFrame {
    attribute widthPixels : Integer;
    attribute heightPixels : Integer;
    attribute frameRate : Frequency;
    attribute minimumTemperature : Temperature;
    attribute maximumTemperature : Temperature;
    attribute calibrated : Boolean;
  }

  item def DetectionReport {
    attribute targetDetected : Boolean;
    attribute targetRange : Distance;
    attribute targetBearing : Angle;
    attribute confidence : Percent;
    attribute estimatedTargetTemperature : Temperature;
  }

  item def ElectricalPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute availablePower : Power;
  }

  item def Command {
    attribute enable : Boolean;
    attribute calibrate : Boolean;
    attribute standby : Boolean;
  }

  item def HealthStatus {
    attribute operational : Boolean;
    attribute detectorTemperature : Temperature;
    attribute processorLoad : Percent;
    attribute faultCode : Integer;
  }

  port def InfraredAperturePort {
    in item incidentRadiation : InfraredRadiation;
  }

  port def PowerInputPort {
    in item suppliedPower : ElectricalPower;
  }

  port def CommandInputPort {
    in item command : Command;
  }

  port def ImageOutputPort {
    out item frame : ThermalImageFrame;
  }

  port def DetectionOutputPort {
    out item report : DetectionReport;
  }

  port def HealthOutputPort {
    out item status : HealthStatus;
  }

  part def InfraredOptics {
    attribute apertureDiameter : Length = 0.05 [m];
    attribute fieldOfView : Angle = 0.785 [rad];
    attribute transmissionEfficiency : Percent = 88;
    port aperture : InfraredAperturePort;
    port focusedOutput : InfraredAperturePort;
  }

  part def InfraredDetectorArray {
    attribute pixelColumns : Integer = 640;
    attribute pixelRows : Integer = 480;
    attribute spectralLowerLimit : Length = 8.0e-6 [m];
    attribute spectralUpperLimit : Length = 14.0e-6 [m];
    attribute noiseEquivalentTemperatureDifference : Temperature = 0.05 [K];
    attribute operatingTemperature : Temperature = 80 [K];

    port opticalInput : InfraredAperturePort;
    port powerInput : PowerInputPort;
    out item rawFrame : ThermalImageFrame;
    out item detectorHealth : HealthStatus;
  }

  part def CryogenicCooler {
    attribute targetDetectorTemperature : Temperature = 80 [K];
    attribute cooldownTime : Time = 120 [s];
    attribute coolingPower : Power = 2.0 [W];

    port powerInput : PowerInputPort;
    out item coolerHealth : HealthStatus;
  }

  part def SignalProcessor {
    attribute clockFrequency : Frequency = 400.0e6 [Hz];
    attribute maximumFrameRate : Frequency = 60 [Hz];
    attribute processingLatency : Time = 0.035 [s];

    in item unprocessedFrame : ThermalImageFrame;
    out item calibratedFrame : ThermalImageFrame;
    out item detection : DetectionReport;
    port powerInput : PowerInputPort;
  }

  part def ControlElectronics {
    attribute nominalBusVoltage : Voltage = 28 [V];
    attribute maximumPowerDraw : Power = 45 [W];

    port externalPower : PowerInputPort;
    port commandInput : CommandInputPort;
    port detectorPower : PowerInputPort;
    port coolerPower : PowerInputPort;
    port processorPower : PowerInputPort;
    out item systemHealth : HealthStatus;
  }

  part def InfraredSystem {
    doc /* Primary function: passively receive infrared radiation from a scene, convert the radiation into calibrated thermal imagery, and report high-confidence detections of thermally distinct targets. */

    attribute nominalDetectionRange : Distance = 1000 [m];
    attribute minimumResolvableTemperatureDifference : Temperature = 0.1 [K];
    attribute imageFrameRate : Frequency = 30 [Hz];
    attribute totalMass : Mass = 3.8 [kg];

    port sceneInput : InfraredAperturePort;
    port powerInput : PowerInputPort;
    port commandInput : CommandInputPort;
    port imageOutput : ImageOutputPort;
    port detectionOutput : DetectionOutputPort;
    port healthOutput : HealthOutputPort;

    part optics : InfraredOptics;
    part detector : InfraredDetectorArray;
    part cooler : CryogenicCooler;
    part processor : SignalProcessor;
    part controller : ControlElectronics;

    connect sceneInput to optics.aperture;
    connect optics.focusedOutput to detector.opticalInput;
    connect powerInput to controller.externalPower;
    connect commandInput to controller.commandInput;
    connect controller.detectorPower to detector.powerInput;
    connect controller.coolerPower to cooler.powerInput;
    connect controller.processorPower to processor.powerInput;

    flow detector.rawFrame to processor.unprocessedFrame;
    flow processor.calibratedFrame to imageOutput.frame;
    flow processor.detection to detectionOutput.report;
    flow controller.systemHealth to healthOutput.status;
  }

  action def CoolDetector {
    in targetTemperature : Temperature;
    out detectorReady : Boolean;
  }

  action def AcquireInfraredFrame {
    in radiation : InfraredRadiation;
    out frame : ThermalImageFrame;
  }

  action def CalibrateThermalFrame {
    in rawFrame : ThermalImageFrame;
    out calibratedFrame : ThermalImageFrame;
  }

  action def DetectThermalTarget {
    in calibratedFrame : ThermalImageFrame;
    out report : DetectionReport;
  }

  action def ReportSystemHealth {
    in detectorHealth : HealthStatus;
    in coolerHealth : HealthStatus;
    out systemHealth : HealthStatus;
  }

  state def InfraredSystemOperatingState {
    entry action ReportSystemHealth;

    state Off;
    state Standby;
    state Cooling;
    state Calibrating;
    state Imaging;
    state Fault;

    transition first Off;

    transition Off_to_Standby
      first Off
      then Standby
      accept Command
      if command.enable;

    transition Standby_to_Cooling
      first Standby
      then Cooling
      accept Command
      if command.enable and not command.standby;

    transition Cooling_to_Calibrating
      first Cooling
      then Calibrating
      if detectorReady;

    transition Calibrating_to_Imaging
      first Calibrating
      then Imaging
      if calibratedFrame.calibrated;

    transition Imaging_to_Calibrating
      first Imaging
      then Calibrating
      accept Command
      if command.calibrate;

    transition Imaging_to_Standby
      first Imaging
      then Standby
      accept Command
      if command.standby;

    transition Any_to_Fault
      first Off
      then Fault
      if not status.operational;

    transition Fault_to_Standby
      first Fault
      then Standby
      accept Command
      if command.enable and command.calibrate;
  }

  requirement def PassiveInfraredDetectionRequirement {
    subject system : InfraredSystem;

    require constraint {
      system.nominalDetectionRange >= 1000 [m]
    }

    doc /* The system shall passively detect thermally distinct targets at or beyond 1000 meters without emitting active illumination. */
  }

  requirement def ThermalImageRequirement {
    subject system : InfraredSystem;

    require constraint {
      system.imageFrameRate >= 30 [Hz]
    }

    require constraint {
      system.minimumResolvableTemperatureDifference <= 0.1 [K]
    }

    doc /* The system shall produce calibrated thermal image frames at no less than 30 frames per second with temperature contrast sensitivity of 0.1 K or better. */
  }

  requirement def SpectralBandRequirement {
    subject detector : InfraredDetectorArray;

    require constraint {
      detector.spectralLowerLimit <= 8.0e-6 [m] and
      detector.spectralUpperLimit >= 14.0e-6 [m]
    }

    doc /* The detector shall operate across the long-wave infrared band from 8 micrometers to 14 micrometers. */
  }

  requirement def HealthMonitoringRequirement {
    subject system : InfraredSystem;

    require constraint {
      system.healthOutput.status.operational == true implies
      system.healthOutput.status.faultCode == 0
    }

    doc /* The system shall continuously report operational health, detector temperature, processor load, and fault state. */
  }

  requirement def PowerRequirement {
    subject controller : ControlElectronics;

    require constraint {
      controller.nominalBusVoltage == 28 [V] and
      controller.maximumPowerDraw <= 45 [W]
    }

    doc /* The system shall operate from a 28 V electrical supply and consume no more than 45 W during steady imaging operation. */
  }

  satisfy PassiveInfraredDetectionRequirement by InfraredSystem;
  satisfy ThermalImageRequirement by InfraredSystem;
  satisfy SpectralBandRequirement by InfraredDetectorArray;
  satisfy HealthMonitoringRequirement by InfraredSystem;
  satisfy PowerRequirement by ControlElectronics;
}