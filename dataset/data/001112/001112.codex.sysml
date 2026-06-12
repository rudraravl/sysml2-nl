package LidarBasedSensingSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Wavelength :> Real {
    unit = "nm";
  }

  attribute def Range :> Real {
    unit = "m";
  }

  attribute def Angle :> Real {
    unit = "deg";
  }

  attribute def TimeDuration :> Real {
    unit = "ns";
  }

  attribute def Frequency :> Real {
    unit = "Hz";
  }

  attribute def Power :> Real {
    unit = "W";
  }

  attribute def Voltage :> Real {
    unit = "V";
  }

  attribute def Current :> Real {
    unit = "A";
  }

  attribute def DataRate :> Real {
    unit = "Mbps";
  }

  attribute def Temperature :> Real {
    unit = "degC";
  }

  item def ElectricalPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute power : Power;
  }

  item def LaserPulse {
    attribute wavelength : Wavelength;
    attribute pulseWidth : TimeDuration;
    attribute peakPower : Power;
    attribute emissionAzimuth : Angle;
    attribute emissionElevation : Angle;
    attribute timestamp : TimeDuration;
  }

  item def ReflectedPhotonSignal {
    attribute wavelength : Wavelength;
    attribute returnTime : TimeDuration;
    attribute intensity : Power;
    attribute incidentAzimuth : Angle;
    attribute incidentElevation : Angle;
  }

  item def TimingReference {
    attribute tickPeriod : TimeDuration;
    attribute synchronizationError : TimeDuration;
  }

  item def ScanCommand {
    attribute startAzimuth : Angle;
    attribute stopAzimuth : Angle;
    attribute startElevation : Angle;
    attribute stopElevation : Angle;
    attribute frameRate : Frequency;
  }

  item def RawRangeSample {
    attribute timeOfFlight : TimeDuration;
    attribute intensity : Power;
    attribute azimuth : Angle;
    attribute elevation : Angle;
  }

  item def Point3D {
    attribute x : Range;
    attribute y : Range;
    attribute z : Range;
    attribute reflectivity : Real;
    attribute timestamp : TimeDuration;
  }

  item def PointCloudFrame {
    attribute frameId : Integer;
    attribute pointCount : Integer;
    attribute frameTimestamp : TimeDuration;
    item points : Point3D[0..*];
  }

  item def HealthStatus {
    attribute laserTemperature : Temperature;
    attribute receiverTemperature : Temperature;
    attribute supplyVoltage : Voltage;
    attribute faultCode : Integer;
    attribute operational : Boolean;
  }

  port def PowerInputPort {
    in item powerIn : ElectricalPower;
  }

  port def OpticalTransmitPort {
    out item emittedPulse : LaserPulse;
  }

  port def OpticalReceivePort {
    in item returnSignal : ReflectedPhotonSignal;
  }

  port def TimingPort {
    inout item timing : TimingReference;
  }

  port def CommandPort {
    in item command : ScanCommand;
  }

  port def PointCloudOutputPort {
    out item frame : PointCloudFrame;
  }

  port def HealthOutputPort {
    out item health : HealthStatus;
  }

  port def SamplePort {
    out item sample : RawRangeSample;
  }

  part def LaserEmitter {
    attribute nominalWavelength : Wavelength = 905.0;
    attribute maximumPeakPower : Power = 75.0;
    attribute pulseWidth : TimeDuration = 8.0;
    attribute pulseRepetitionFrequency : Frequency = 200000.0;

    port powerPort : PowerInputPort;
    port timingPort : TimingPort;
    port opticalOut : OpticalTransmitPort;

    action emitPulse {
      in item command : ScanCommand;
      in item timing : TimingReference;
      out item pulse : LaserPulse;

      first start;
      then setPulse {
        pulse.wavelength = nominalWavelength;
        pulse.pulseWidth = pulseWidth;
        pulse.peakPower = maximumPeakPower;
        pulse.timestamp = timing.tickPeriod;
      }
      then sendPulse;
      then done;
    }
  }

  part def BeamSteeringAssembly {
    attribute azimuthFieldOfView : Angle = 120.0;
    attribute elevationFieldOfView : Angle = 30.0;
    attribute angularResolution : Angle = 0.1;
    attribute scanFrameRate : Frequency = 20.0;

    port commandPort : CommandPort;
    port timingPort : TimingPort;
    port opticalIn : OpticalReceivePort;
    port opticalOut : OpticalTransmitPort;

    action steerBeam {
      in item scan : ScanCommand;
      in item incomingPulse : LaserPulse;
      out item directedPulse : LaserPulse;

      first receiveScan;
      then applyAzimuth;
      then applyElevation;
      then emitDirectedPulse;
      then done;
    }
  }

  part def OpticalReceiver {
    attribute receiverApertureDiameter : Range = 0.025;
    attribute detectorGain : Real = 1000000.0;
    attribute minimumDetectablePower : Power = 0.000000001;

    port opticalIn : OpticalReceivePort;
    port timingPort : TimingPort;
    port sampleOut : SamplePort;
    port healthOut : HealthOutputPort;

    action detectReturn {
      in item returnSignal : ReflectedPhotonSignal;
      in item timing : TimingReference;
      out item sample : RawRangeSample;

      first acquirePhotonSignal;
      then compareDetectionThreshold;
      then computeTimeOfFlight {
        sample.timeOfFlight = returnSignal.returnTime;
        sample.intensity = returnSignal.intensity;
        sample.azimuth = returnSignal.incidentAzimuth;
        sample.elevation = returnSignal.incidentElevation;
      }
      then publishSample;
      then done;
    }
  }

  part def TimingController {
    attribute clockFrequency : Frequency = 1000000000.0;
    attribute timingResolution : TimeDuration = 1.0;
    attribute maximumJitter : TimeDuration = 0.25;

    port timingDistribution : TimingPort;

    action synchronizeMeasurement {
      out item timing : TimingReference;

      first lockClock;
      then generateTicks {
        timing.tickPeriod = timingResolution;
        timing.synchronizationError = maximumJitter;
      }
      then distributeTiming;
      then done;
    }
  }

  part def SignalProcessor {
    attribute speedOfLight : Real = 299792458.0;
    attribute maximumRange : Range = 250.0;
    attribute minimumRange : Range = 0.5;
    attribute rangeAccuracy : Range = 0.03;
    attribute processingLatency : TimeDuration = 500000.0;

    port sampleIn : SamplePort;
    port frameOut : PointCloudOutputPort;
    port healthOut : HealthOutputPort;

    action calculateRange {
      in item sample : RawRangeSample;
      out item point : Point3D;

      first receiveSample;
      then rejectInvalidSample;
      then computeRange;
      then convertPolarToCartesian;
      then assignReflectivity;
      then done;
    }

    action assemblePointCloud {
      in item samples : RawRangeSample[1..*];
      out item frame : PointCloudFrame;

      first initializeFrame;
      then calculatePoints;
      then filterNoise;
      then timestampFrame;
      then publishFrame;
      then done;
    }
  }

  part def ControlComputer {
    attribute defaultFrameRate : Frequency = 20.0;
    attribute startupTime : TimeDuration = 2000000000.0;
    attribute outputDataRate : DataRate = 1000.0;

    port powerPort : PowerInputPort;
    port commandOut : CommandPort;
    port pointCloudIn : PointCloudOutputPort;
    port healthIn : HealthOutputPort;
    port healthOut : HealthOutputPort;

    action planScan {
      out item command : ScanCommand;

      first initializeScanPlan;
      then setHorizontalCoverage {
        command.startAzimuth = -60.0;
        command.stopAzimuth = 60.0;
      }
      then setVerticalCoverage {
        command.startElevation = -15.0;
        command.stopElevation = 15.0;
      }
      then setFrameRate {
        command.frameRate = defaultFrameRate;
      }
      then issueCommand;
      then done;
    }

    state def OperatingStateMachine {
      state off;
      state initializing;
      state standby;
      state scanning;
      state degraded;
      state fault;

      transition off_to_initializing first off then initializing;
      transition initializing_to_standby first initializing then standby;
      transition standby_to_scanning first standby then scanning;
      transition scanning_to_degraded first scanning then degraded;
      transition degraded_to_scanning first degraded then scanning;
      transition any_to_fault first off then fault;
      transition fault_to_standby first fault then standby;
    }
  }

  part def LidarSensorSystem {
    attribute systemMass : Real = 2.8;
    attribute operatingTemperatureMin : Temperature = -20.0;
    attribute operatingTemperatureMax : Temperature = 60.0;
    attribute ratedSupplyVoltage : Voltage = 24.0;
    attribute primaryFunction : String = "Emit laser pulses, measure reflected return time and intensity, and produce a three-dimensional point cloud describing surrounding objects and surfaces.";

    port mainPower : PowerInputPort;
    port scanCommand : CommandPort;
    port pointCloudOutput : PointCloudOutputPort;
    port healthOutput : HealthOutputPort;

    part emitter : LaserEmitter;
    part scanner : BeamSteeringAssembly;
    part receiver : OpticalReceiver;
    part timing : TimingController;
    part processor : SignalProcessor;
    part controller : ControlComputer;

    connect mainPower.powerIn to emitter.powerPort.powerIn;
    connect mainPower.powerIn to controller.powerPort.powerIn;
    connect controller.commandOut.command to scanner.commandPort.command;
    connect scanCommand.command to scanner.commandPort.command;
    connect timing.timingDistribution.timing to emitter.timingPort.timing;
    connect timing.timingDistribution.timing to scanner.timingPort.timing;
    connect timing.timingDistribution.timing to receiver.timingPort.timing;
    connect emitter.opticalOut.emittedPulse to scanner.opticalIn.returnSignal;
    connect scanner.opticalOut.emittedPulse to receiver.opticalIn.returnSignal;
    connect receiver.sampleOut.sample to processor.sampleIn.sample;
    connect processor.frameOut.frame to pointCloudOutput.frame;
    connect processor.frameOut.frame to controller.pointCloudIn.frame;
    connect receiver.healthOut.health to controller.healthIn.health;
    connect processor.healthOut.health to controller.healthIn.health;
    connect controller.healthOut.health to healthOutput.health;

    perform action controller.planScan;
    perform action timing.synchronizeMeasurement;
    perform action emitter.emitPulse;
    perform action scanner.steerBeam;
    perform action receiver.detectReturn;
    perform action processor.assemblePointCloud;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The LIDAR system shall determine the three-dimensional location and reflectivity of objects in its field of view by transmitting laser pulses and processing returned optical signals into point cloud frames. */
    subject system : LidarSensorSystem;

    require constraint {
      system.processor.maximumRange >= 200.0
    }
  }

  requirement def RangeAccuracyRequirement {
    doc /* The LIDAR system shall estimate object range with an error no greater than 0.05 m under nominal operating conditions. */
    subject system : LidarSensorSystem;

    require constraint {
      system.processor.rangeAccuracy <= 0.05
    }
  }

  requirement def FieldOfViewRequirement {
    doc /* The LIDAR system shall scan at least 100 degrees in azimuth and at least 25 degrees in elevation. */
    subject system : LidarSensorSystem;

    require constraint {
      system.scanner.azimuthFieldOfView >= 100.0 and
      system.scanner.elevationFieldOfView >= 25.0
    }
  }

  requirement def FrameRateRequirement {
    doc /* The LIDAR system shall generate point cloud frames at no less than 10 Hz. */
    subject system : LidarSensorSystem;

    require constraint {
      system.scanner.scanFrameRate >= 10.0
    }
  }

  requirement def EyeSafetyRequirement {
    doc /* The laser emitter shall limit transmitted pulse energy by controlling wavelength, pulse width, and peak power within configured operating limits. */
    subject emitter : LaserEmitter;

    require constraint {
      emitter.nominalWavelength >= 900.0 and
      emitter.nominalWavelength <= 910.0 and
      emitter.maximumPeakPower <= 75.0
    }
  }

  requirement def TimingResolutionRequirement {
    doc /* The timing controller shall provide sufficient timing resolution for centimeter-scale range estimation. */
    subject controller : TimingController;

    require constraint {
      controller.timingResolution <= 1.0
    }
  }

  requirement def HealthMonitoringRequirement {
    doc /* The system shall report operating health including temperature, supply voltage, operational state, and fault code. */
    subject system : LidarSensorSystem;

    require constraint {
      system.operatingTemperatureMin <= -20.0 and
      system.operatingTemperatureMax >= 60.0
    }
  }

  satisfy PrimaryFunctionRequirement by LidarSensorSystem;
  satisfy RangeAccuracyRequirement by LidarSensorSystem;
  satisfy FieldOfViewRequirement by LidarSensorSystem;
  satisfy FrameRateRequirement by LidarSensorSystem;
  satisfy EyeSafetyRequirement by LaserEmitter;
  satisfy TimingResolutionRequirement by TimingController;
  satisfy HealthMonitoringRequirement by LidarSensorSystem;

  part lidarSystem : LidarSensorSystem;

}