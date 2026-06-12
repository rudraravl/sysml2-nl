package ImageSensorSensingUnitModel {

  package Units {
    attribute def PixelCount;
    attribute def BitDepth;
    attribute def FrameRate { :> ISQ::frequency; }
    attribute def ExposureTime { :> ISQ::time; }
    attribute def Irradiance { :> ISQ::irradiance; }
    attribute def Temperature { :> ISQ::thermodynamicTemperature; }
    attribute def Voltage { :> ISQ::electricPotential; }
    attribute def Current { :> ISQ::electricCurrent; }
    attribute def Power { :> ISQ::power; }
    attribute def DataRate;
    attribute def SignalToNoiseRatio;
  }

  item def OpticalRadiation {
    attribute wavelength : ISQ::length;
    attribute irradiance : Units::Irradiance;
  }

  item def SceneImage {
    attribute width : Units::PixelCount;
    attribute height : Units::PixelCount;
    attribute bitDepth : Units::BitDepth;
    attribute frameRate : Units::FrameRate;
    attribute exposureTime : Units::ExposureTime;
    attribute timestamp : ISQ::time;
  }

  item def DigitalImageFrame {
    attribute width : Units::PixelCount = 1920;
    attribute height : Units::PixelCount = 1080;
    attribute bitDepth : Units::BitDepth = 12;
    attribute timestamp : ISQ::time;
    attribute valid : Boolean;
  }

  item def MeasurementReport {
    attribute measuredQuantityName : String = "image-derived optical scene intensity";
    attribute meanSceneIrradiance : Units::Irradiance;
    attribute peakPixelValue : Integer;
    attribute confidence : Real;
    attribute timestamp : ISQ::time;
    attribute status : MeasurementStatus;
  }

  enum def MeasurementStatus {
    enum ok;
    enum saturated;
    enum underexposed;
    enum sensorFault;
    enum calibrationRequired;
  }

  item def PowerSupply {
    attribute voltage : Units::Voltage;
    attribute currentLimit : Units::Current;
  }

  item def ConfigurationCommand {
    attribute requestedFrameRate : Units::FrameRate;
    attribute requestedExposureTime : Units::ExposureTime;
    attribute autoExposureEnabled : Boolean;
    attribute gain : Real;
  }

  port def OpticalInputPort {
    in opticalRadiation : OpticalRadiation;
  }

  port def ImageOutputPort {
    out frame : DigitalImageFrame;
  }

  port def MeasurementOutputPort {
    out report : MeasurementReport;
  }

  port def PowerInputPort {
    in supply : PowerSupply;
  }

  port def ConfigurationInputPort {
    in command : ConfigurationCommand;
  }

  port def InternalImageBusPort {
    out frame : DigitalImageFrame;
  }

  port def InternalControlPort {
    out command : ConfigurationCommand;
  }

  action def CaptureImage {
    in opticalInput : OpticalRadiation;
    in exposureTime : Units::ExposureTime;
    in gain : Real;
    out rawFrame : DigitalImageFrame;
  }

  action def CorrectImage {
    in rawFrame : DigitalImageFrame;
    in darkOffset : Integer;
    in flatFieldGain : Real;
    out correctedFrame : DigitalImageFrame;
  }

  action def EstimateSceneIntensity {
    in correctedFrame : DigitalImageFrame;
    out report : MeasurementReport;
  }

  action def AdjustExposure {
    in previousReport : MeasurementReport;
    in currentConfiguration : ConfigurationCommand;
    out nextConfiguration : ConfigurationCommand;
  }

  state def SensingUnitStateMachine {
    state initial Off;

    state Off;
    state Powering;
    state SelfTest;
    state Calibrating;
    state Ready;
    state Measuring;
    state Fault;

    transition Off_to_Powering
      first Off
      then Powering;

    transition Powering_to_SelfTest
      first Powering
      then SelfTest;

    transition SelfTest_to_Calibrating
      first SelfTest
      then Calibrating;

    transition Calibrating_to_Ready
      first Calibrating
      then Ready;

    transition Ready_to_Measuring
      first Ready
      then Measuring;

    transition Measuring_to_Ready
      first Measuring
      then Ready;

    transition Measuring_to_Fault
      first Measuring
      then Fault;

    transition SelfTest_to_Fault
      first SelfTest
      then Fault;

    transition Fault_to_Off
      first Fault
      then Off;
  }

  part def LensAssembly {
    port sceneInput : OpticalInputPort;
    port focusedOutput : OpticalInputPort;

    attribute apertureNumber : Real = 2.8;
    attribute focalLength : ISQ::length = 0.006 [SI::m];
    attribute transmissionEfficiency : Real = 0.88;
  }

  part def ImageSensor {
    port opticalInput : OpticalInputPort;
    port imageOutput : ImageOutputPort;
    port powerInput : PowerInputPort;
    port configurationInput : ConfigurationInputPort;

    attribute sensorTechnology : String = "CMOS active pixel image sensor";
    attribute activeWidth : Units::PixelCount = 1920;
    attribute activeHeight : Units::PixelCount = 1080;
    attribute pixelPitch : ISQ::length = 2.2e-6 [SI::m];
    attribute bitDepth : Units::BitDepth = 12;
    attribute maximumFrameRate : Units::FrameRate = 60 [SI::Hz];
    attribute nominalExposureTime : Units::ExposureTime = 0.01 [SI::s];
    attribute darkCurrent : Units::Current = 2.0e-12 [SI::A];
    attribute operatingTemperature : Units::Temperature;
    attribute signalToNoiseRatio : Units::SignalToNoiseRatio = 38;

    action capture : CaptureImage;
  }

  part def ImageSignalProcessor {
    port rawImageInput : ImageOutputPort;
    port processedImageOutput : ImageOutputPort;
    port measurementOutput : MeasurementOutputPort;

    attribute darkOffset : Integer = 64;
    attribute flatFieldGain : Real = 1.0;
    attribute saturationThreshold : Integer = 4095;
    attribute underExposureThreshold : Integer = 128;

    action correction : CorrectImage;
    action estimation : EstimateSceneIntensity;
  }

  part def Controller {
    port configurationOutput : InternalControlPort;
    port measurementInput : MeasurementOutputPort;

    attribute autoExposureEnabled : Boolean = true;
    attribute targetMeanPixelValue : Integer = 2048;
    attribute minimumExposureTime : Units::ExposureTime = 0.0001 [SI::s];
    attribute maximumExposureTime : Units::ExposureTime = 0.033 [SI::s];
    attribute commandedFrameRate : Units::FrameRate = 30 [SI::Hz];

    action exposureControl : AdjustExposure;
    state behavior : SensingUnitStateMachine;
  }

  part def PowerConditioner {
    port externalPowerInput : PowerInputPort;
    port sensorPowerOutput : PowerInputPort;
    port processorPowerOutput : PowerInputPort;
    port controllerPowerOutput : PowerInputPort;

    attribute inputVoltage : Units::Voltage = 12 [SI::V];
    attribute regulatedVoltage : Units::Voltage = 3.3 [SI::V];
    attribute maximumOutputPower : Units::Power = 2.5 [SI::W];
    attribute conversionEfficiency : Real = 0.91;
  }

  part def ImageBasedSensingUnit {
    port sceneInput : OpticalInputPort;
    port powerInput : PowerInputPort;
    port configurationInput : ConfigurationInputPort;
    port imageOutput : ImageOutputPort;
    port measurementOutput : MeasurementOutputPort;

    part lens : LensAssembly;
    part sensor : ImageSensor;
    part processor : ImageSignalProcessor;
    part controller : Controller;
    part powerConditioner : PowerConditioner;

    attribute measuredQuantity : String = "optical scene intensity represented by calibrated image frames";
    attribute measurementFrameRate : Units::FrameRate = 30 [SI::Hz];
    attribute horizontalResolution : Units::PixelCount = 1920;
    attribute verticalResolution : Units::PixelCount = 1080;
    attribute measurementLatency : ISQ::time <= 0.050 [SI::s];
    attribute operatingTemperatureMin : Units::Temperature = 253.15 [SI::K];
    attribute operatingTemperatureMax : Units::Temperature = 333.15 [SI::K];

    connect sceneInput to lens.sceneInput;
    connect lens.focusedOutput to sensor.opticalInput;
    connect sensor.imageOutput to processor.rawImageInput;
    connect processor.processedImageOutput to imageOutput;
    connect processor.measurementOutput to measurementOutput;
    connect processor.measurementOutput to controller.measurementInput;
    connect controller.configurationOutput to sensor.configurationInput;
    connect configurationInput to sensor.configurationInput;
    connect powerInput to powerConditioner.externalPowerInput;
    connect powerConditioner.sensorPowerOutput to sensor.powerInput;
  }

  requirement def MeasureQuantityUsingImageSensorRequirement {
    subject sensingUnit : ImageBasedSensingUnit;

    require constraint {
      sensingUnit.sensor.sensorTechnology == "CMOS active pixel image sensor"
    }

    require constraint {
      sensingUnit.horizontalResolution >= 1920 and
      sensingUnit.verticalResolution >= 1080
    }

    require constraint {
      sensingUnit.measurementFrameRate >= 30 [SI::Hz]
    }

    require constraint {
      sensingUnit.measurementLatency <= 0.050 [SI::s]
    }

    doc /* The sensing unit shall measure the relevant optical quantity using an image sensor and shall output both calibrated image frames and an image-derived measurement report. */
  }

  requirement def ImageMeasurementAccuracyRequirement {
    subject sensingUnit : ImageBasedSensingUnit;

    require constraint {
      sensingUnit.processor.saturationThreshold == 4095
    }

    require constraint {
      sensingUnit.sensor.bitDepth >= 12
    }

    doc /* The sensing unit shall provide calibrated digital image data with sufficient dynamic range to estimate scene intensity without saturation during nominal exposure. */
  }

  requirement def AutoExposureRequirement {
    subject sensingUnit : ImageBasedSensingUnit;

    require constraint {
      sensingUnit.controller.autoExposureEnabled == true
    }

    require constraint {
      sensingUnit.controller.minimumExposureTime < sensingUnit.controller.maximumExposureTime
    }

    doc /* The sensing unit shall automatically adjust image sensor exposure to keep the measured scene intensity within the valid operating range. */
  }

  requirement def PowerRequirement {
    subject sensingUnit : ImageBasedSensingUnit;

    require constraint {
      sensingUnit.powerConditioner.inputVoltage == 12 [SI::V]
    }

    require constraint {
      sensingUnit.powerConditioner.maximumOutputPower <= 2.5 [SI::W]
    }

    doc /* The sensing unit shall operate from a regulated external power input and condition power for the image sensor, processor, and controller. */
  }

  part sensingUnit : ImageBasedSensingUnit;

  satisfy MeasureQuantityUsingImageSensorRequirement by sensingUnit;
  satisfy ImageMeasurementAccuracyRequirement by sensingUnit;
  satisfy AutoExposureRequirement by sensingUnit;
  satisfy PowerRequirement by sensingUnit;
}