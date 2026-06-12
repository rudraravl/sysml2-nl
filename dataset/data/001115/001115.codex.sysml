package LaserBeamProfilerSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value def OpticalPower {
    :> ISQ::power;
    unit = SI::watt;
  }

  value def Wavelength {
    :> ISQ::length;
    unit = SI::nanometre;
  }

  value def BeamDiameter {
    :> ISQ::length;
    unit = SI::millimetre;
  }

  value def ExposureTime {
    :> ISQ::time;
    unit = SI::millisecond;
  }

  value def Temperature {
    :> ISQ::thermodynamicTemperature;
    unit = SI::degreeCelsius;
  }

  value def FrameRate {
    :> ISQ::frequency;
    unit = SI::hertz;
  }

  value def PixelPitch {
    :> ISQ::length;
    unit = SI::micrometre;
  }

  value def Percentage {
    :> ScalarValues::Real;
    unit = "%";
  }

  value def SignalLevel {
    :> ScalarValues::Real;
  }

  item def LaserBeam {
    attribute wavelength : Wavelength;
    attribute averagePower : OpticalPower;
    attribute beamDiameterEstimate : BeamDiameter;
    attribute polarizationAngle : Real;
    attribute isPulsed : Boolean;
  }

  item def AttenuatedBeam {
    attribute attenuationRatio : Real;
    attribute residualPower : OpticalPower;
    attribute wavelength : Wavelength;
  }

  item def ImageFrame {
    attribute widthPixels : Integer;
    attribute heightPixels : Integer;
    attribute exposure : ExposureTime;
    attribute frameIndex : Integer;
    attribute peakSignal : SignalLevel;
    attribute backgroundSignal : SignalLevel;
    attribute saturatedPixelCount : Integer;
  }

  item def BeamProfile {
    attribute centroidX : PixelPitch;
    attribute centroidY : PixelPitch;
    attribute beamWidthX_D4Sigma : BeamDiameter;
    attribute beamWidthY_D4Sigma : BeamDiameter;
    attribute ellipticity : Real;
    attribute peakIrradiance : SignalLevel;
    attribute totalRelativePower : SignalLevel;
    attribute fitQuality : Percentage;
  }

  item def ControlCommand {
    attribute requestedExposure : ExposureTime;
    attribute requestedGain : Real;
    attribute startAcquisition : Boolean;
    attribute stopAcquisition : Boolean;
  }

  item def ProfileReport {
    attribute timestamp : String;
    attribute wavelength : Wavelength;
    attribute beamWidthX_D4Sigma : BeamDiameter;
    attribute beamWidthY_D4Sigma : BeamDiameter;
    attribute centroidX : PixelPitch;
    attribute centroidY : PixelPitch;
    attribute ellipticity : Real;
    attribute saturationDetected : Boolean;
    attribute passFail : Boolean;
  }

  port def OpticalInputPort {
    in item incomingBeam : LaserBeam;
  }

  port def OpticalOutputPort {
    out item outgoingBeam : AttenuatedBeam;
  }

  port def FramePort {
    out item frame : ImageFrame;
  }

  port def ProfilePort {
    out item profile : BeamProfile;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def ReportPort {
    out item report : ProfileReport;
  }

  port def ThermalPort {
    out attribute detectorTemperature : Temperature;
  }

  part def OpticalAttenuator {
    port beamIn : OpticalInputPort;
    port beamOut : OpticalOutputPort;

    attribute maximumInputPower : OpticalPower = 10 [W];
    attribute nominalAttenuationRatio : Real = 1000.0;
    attribute damageThresholdPower : OpticalPower = 20 [W];
    attribute clearAperture : BeamDiameter = 12 [mm];

    action attenuateBeam {
      in item rawBeam : LaserBeam;
      out item safeBeam : AttenuatedBeam;

      first start;
      then verifyPower;
      then reducePower;
      then emitSafeBeam;
      then done;

      action verifyPower {
        in item rawBeam : LaserBeam;
      }

      action reducePower {
        in item rawBeam : LaserBeam;
        out item safeBeam : AttenuatedBeam;
      }

      action emitSafeBeam {
        out item safeBeam : AttenuatedBeam;
      }
    }
  }

  part def ImagingSensor {
    port beamInput : OpticalInputPort;
    port frameOutput : FramePort;
    port thermalStatus : ThermalPort;

    attribute sensorWidthPixels : Integer = 2048;
    attribute sensorHeightPixels : Integer = 2048;
    attribute pixelPitch : PixelPitch = 5.5 [um];
    attribute minimumExposure : ExposureTime = 0.01 [ms];
    attribute maximumExposure : ExposureTime = 1000 [ms];
    attribute selectedExposure : ExposureTime = 1 [ms];
    attribute analogGain : Real = 1.0;
    attribute operatingTemperature : Temperature = 25 [degC];
    attribute saturationLevel : SignalLevel = 4095.0;
    attribute darkOffset : SignalLevel = 64.0;

    action acquireFrame {
      in item beam : AttenuatedBeam;
      out item rawFrame : ImageFrame;

      first exposeArray;
      then digitizePixels;
      then subtractDarkOffset;
      then publishFrame;

      action exposeArray {
        in item beam : AttenuatedBeam;
      }

      action digitizePixels {
        out item rawFrame : ImageFrame;
      }

      action subtractDarkOffset {
        inout item rawFrame : ImageFrame;
      }

      action publishFrame {
        out item rawFrame : ImageFrame;
      }
    }
  }

  part def ExposureController {
    port commandInput : CommandPort;
    port frameFeedback : FramePort;

    attribute targetPeakFraction : Percentage = 70 [%];
    attribute lowPeakThreshold : Percentage = 25 [%];
    attribute highPeakThreshold : Percentage = 90 [%];
    attribute currentExposure : ExposureTime = 1 [ms];
    attribute currentGain : Real = 1.0;

    action regulateExposure {
      in item frame : ImageFrame;
      out item command : ControlCommand;

      first evaluatePeak;
      then decideAdjustment;
      then issueCommand;

      action evaluatePeak {
        in item frame : ImageFrame;
      }

      action decideAdjustment {
        out item command : ControlCommand;
      }

      action issueCommand {
        out item command : ControlCommand;
      }
    }

    state def ExposureControlState {
      state idle;
      state increasingExposure;
      state decreasingExposure;
      state locked;
      state faultSaturation;

      transition first idle then locked;
      transition locked then increasingExposure
        if frameFeedback.frame.peakSignal < lowPeakThreshold;
      transition locked then decreasingExposure
        if frameFeedback.frame.peakSignal > highPeakThreshold;
      transition increasingExposure then locked;
      transition decreasingExposure then locked;
      transition locked then faultSaturation
        if frameFeedback.frame.saturatedPixelCount > 0;
      transition faultSaturation then decreasingExposure;
    }
  }

  part def ProfileProcessor {
    port frameInput : FramePort;
    port profileOutput : ProfilePort;

    attribute backgroundWindowSize : Integer = 32;
    attribute centroidThresholdFraction : Percentage = 13.5 [%];
    attribute minimumFitQuality : Percentage = 95 [%];

    action computeBeamProfile {
      in item frame : ImageFrame;
      out item profile : BeamProfile;

      first validateFrame;
      then estimateBackground;
      then subtractBackground;
      then computeCentroid;
      then computeSecondMoments;
      then computeD4SigmaWidths;
      then computeEllipticity;
      then publishProfile;

      action validateFrame {
        in item frame : ImageFrame;
      }

      action estimateBackground {
        in item frame : ImageFrame;
      }

      action subtractBackground {
        inout item frame : ImageFrame;
      }

      action computeCentroid {
        in item frame : ImageFrame;
      }

      action computeSecondMoments {
        in item frame : ImageFrame;
      }

      action computeD4SigmaWidths {
        out item profile : BeamProfile;
      }

      action computeEllipticity {
        inout item profile : BeamProfile;
      }

      action publishProfile {
        out item profile : BeamProfile;
      }
    }
  }

  part def DataReporter {
    port profileInput : ProfilePort;
    port reportOutput : ReportPort;

    attribute reportRate : FrameRate = 10 [Hz];
    attribute maximumAllowedEllipticity : Real = 1.20;
    attribute minimumAllowedFitQuality : Percentage = 95 [%];

    action generateReport {
      in item profile : BeamProfile;
      out item report : ProfileReport;

      first collectProfile;
      then evaluateLimits;
      then formatReport;
      then transmitReport;

      action collectProfile {
        in item profile : BeamProfile;
      }

      action evaluateLimits {
        in item profile : BeamProfile;
      }

      action formatReport {
        out item report : ProfileReport;
      }

      action transmitReport {
        out item report : ProfileReport;
      }
    }
  }

  part def UserInterface {
    port commandOutput : CommandPort;
    port reportInput : ReportPort;

    attribute displayRefreshRate : FrameRate = 30 [Hz];
    attribute selectedWavelength : Wavelength = 1064 [nm];
    attribute acquisitionEnabled : Boolean = false;

    action operatorSession {
      out item command : ControlCommand;
      in item report : ProfileReport;

      first configureMeasurement;
      then startAcquisition;
      then monitorProfile;
      then stopAcquisition;

      action configureMeasurement {
        out item command : ControlCommand;
      }

      action startAcquisition {
        out item command : ControlCommand;
      }

      action monitorProfile {
        in item report : ProfileReport;
      }

      action stopAcquisition {
        out item command : ControlCommand;
      }
    }
  }

  part def LaserBeamProfiler {
    port opticalInput : OpticalInputPort;
    port measurementReport : ReportPort;
    port operatorCommand : CommandPort;

    attribute supportedMinimumWavelength : Wavelength = 190 [nm];
    attribute supportedMaximumWavelength : Wavelength = 1700 [nm];
    attribute maximumMeasurableBeamDiameter : BeamDiameter = 11 [mm];
    attribute minimumMeasurableBeamDiameter : BeamDiameter = 0.055 [mm];
    attribute nominalFrameRate : FrameRate = 15 [Hz];

    part attenuator : OpticalAttenuator;
    part sensor : ImagingSensor;
    part controller : ExposureController;
    part processor : ProfileProcessor;
    part reporter : DataReporter;
    part ui : UserInterface;

    connect opticalInput.incomingBeam to attenuator.beamIn.incomingBeam;
    connect attenuator.beamOut.outgoingBeam to sensor.beamInput.incomingBeam;
    connect sensor.frameOutput.frame to processor.frameInput.frame;
    connect sensor.frameOutput.frame to controller.frameFeedback.frame;
    connect controller.commandInput.command to operatorCommand.command;
    connect processor.profileOutput.profile to reporter.profileInput.profile;
    connect reporter.reportOutput.report to measurementReport.report;
    connect ui.commandOutput.command to operatorCommand.command;
    connect measurementReport.report to ui.reportInput.report;

    action performBeamProfiling {
      in item beam : LaserBeam;
      out item report : ProfileReport;

      first receiveLaserBeam;
      then attenuateForSensorSafety;
      then acquireImageFrame;
      then regulateExposure;
      then computeSpatialProfile;
      then generateMeasurementReport;
      then deliverResults;

      action receiveLaserBeam {
        in item beam : LaserBeam;
      }

      action attenuateForSensorSafety {
        in item beam : LaserBeam;
        out item safeBeam : AttenuatedBeam;
      }

      action acquireImageFrame {
        in item safeBeam : AttenuatedBeam;
        out item frame : ImageFrame;
      }

      action regulateExposure {
        in item frame : ImageFrame;
        out item command : ControlCommand;
      }

      action computeSpatialProfile {
        in item frame : ImageFrame;
        out item profile : BeamProfile;
      }

      action generateMeasurementReport {
        in item profile : BeamProfile;
        out item report : ProfileReport;
      }

      action deliverResults {
        out item report : ProfileReport;
      }
    }

    state def ProfilerOperationalState {
      state poweredOff;
      state standby;
      state aligningBeam;
      state acquiring;
      state processing;
      state reporting;
      state saturated;
      state thermalFault;

      transition first poweredOff then standby;
      transition standby then aligningBeam
        if ui.acquisitionEnabled == true;
      transition aligningBeam then acquiring
        if sensor.frameOutput.frame.peakSignal > 0.0;
      transition acquiring then processing;
      transition processing then reporting;
      transition reporting then acquiring
        if ui.acquisitionEnabled == true;
      transition acquiring then saturated
        if sensor.frameOutput.frame.saturatedPixelCount > 0;
      transition saturated then acquiring
        if controller.currentExposure <= sensor.minimumExposure;
      transition acquiring then thermalFault
        if sensor.operatingTemperature > 55 [degC];
      transition thermalFault then standby
        if sensor.operatingTemperature < 45 [degC];
      transition reporting then standby
        if ui.acquisitionEnabled == false;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject profiler : LaserBeamProfiler;

    doc
    /*
     The laser beam profiler shall accept an incoming laser beam, safely attenuate it for detector operation, capture a calibrated two-dimensional intensity image, compute high-level spatial beam metrics including centroid, D4-sigma beam widths, ellipticity, peak level, and saturation status, and provide a measurement report to the operator at the configured reporting rate.
    */

    require constraint {
      profiler.nominalFrameRate >= 10 [Hz]
    }
  }

  requirement def WavelengthCoverageRequirement {
    subject profiler : LaserBeamProfiler;

    doc
    /*
     The profiler shall support beam profiling over the wavelength range from 190 nm to 1700 nm.
    */

    require constraint {
      profiler.supportedMinimumWavelength <= 190 [nm] and
      profiler.supportedMaximumWavelength >= 1700 [nm]
    }
  }

  requirement def SensorProtectionRequirement {
    subject attenuator : OpticalAttenuator;

    doc
    /*
     The optical attenuator shall reduce incoming laser power so that residual optical power reaching the imaging sensor remains below the sensor damage threshold during normal profiling.
    */

    require constraint {
      attenuator.maximumInputPower / attenuator.nominalAttenuationRatio < 0.02 [W]
    }
  }

  requirement def BeamMeasurementRangeRequirement {
    subject profiler : LaserBeamProfiler;

    doc
    /*
     The profiler shall measure beam diameters from 0.055 mm to 11 mm using the calibrated sensor pixel pitch and D4-sigma processing method.
    */

    require constraint {
      profiler.minimumMeasurableBeamDiameter <= 0.055 [mm] and
      profiler.maximumMeasurableBeamDiameter >= 11 [mm]
    }
  }

  requirement def SaturationDetectionRequirement {
    subject processor : ProfileProcessor;

    doc
    /*
     The processing function shall identify saturated image frames and prevent saturated measurements from being reported as passing measurements.
    */
  }

  requirement def ExposureControlRequirement {
    subject controller : ExposureController;

    doc
    /*
     The exposure controller shall maintain the image peak signal between 25 percent and 90 percent of detector full scale during normal acquisition.
    */

    require constraint {
      controller.lowPeakThreshold == 25 [%] and
      controller.highPeakThreshold == 90 [%]
    }
  }

  requirement def ProfileQualityRequirement {
    subject reporter : DataReporter;

    doc
    /*
     Reported beam profile measurements shall have a fit quality of at least 95 percent unless the report explicitly indicates a failed measurement.
    */

    require constraint {
      reporter.minimumAllowedFitQuality >= 95 [%]
    }
  }

  part profilerSystem : LaserBeamProfiler;

  satisfy PrimaryFunctionRequirement by profilerSystem;
  satisfy WavelengthCoverageRequirement by profilerSystem;
  satisfy BeamMeasurementRangeRequirement by profilerSystem;
  satisfy SensorProtectionRequirement by profilerSystem.attenuator;
  satisfy ExposureControlRequirement by profilerSystem.controller;
  satisfy ProfileQualityRequirement by profilerSystem.reporter;
}