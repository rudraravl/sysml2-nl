package ContactImageSensingUnitModel {

  import ScalarValues::*;
  import SI::*;

  value def Millimeter :> Real;
  value def Micrometer :> Real;
  value def Volt :> Real;
  value def Ampere :> Real;
  value def Watt :> Real;
  value def Hertz :> Real;
  value def Lux :> Real;
  value def Celsius :> Real;
  value def PixelCount :> Integer;
  value def GrayLevel :> Integer;
  value def Percent :> Real;
  value def Millisecond :> Real;

  item def ElectricalPower {
    attribute voltage : Volt;
    attribute current : Ampere;
    attribute power : Watt;
  }

  item def ControlCommand {
    attribute commandId : Integer;
    attribute scanRequested : Boolean;
    attribute calibrationRequested : Boolean;
    attribute exposureTime : Millisecond;
  }

  item def StatusReport {
    attribute ready : Boolean;
    attribute scanning : Boolean;
    attribute calibrated : Boolean;
    attribute faultPresent : Boolean;
    attribute temperature : Celsius;
  }

  item def IlluminationPulse {
    attribute intensity : Lux;
    attribute duration : Millisecond;
  }

  item def ReflectedOpticalSignal {
    attribute wavelength : Micrometer;
    attribute intensity : Lux;
    attribute linePosition : Millimeter;
  }

  item def AnalogPixelLine {
    attribute pixelCount : PixelCount;
    attribute sampleRate : Hertz;
    attribute analogLevel : Volt;
  }

  item def DigitalPixelLine {
    attribute pixelCount : PixelCount;
    attribute bitDepth : Integer;
    attribute grayLevelMin : GrayLevel;
    attribute grayLevelMax : GrayLevel;
  }

  item def ContactImageMeasurement {
    attribute measuredWidth : Millimeter;
    attribute pixelPitch : Micrometer;
    attribute resolution : PixelCount;
    attribute averageReflectance : Percent;
    attribute minimumGrayLevel : GrayLevel;
    attribute maximumGrayLevel : GrayLevel;
    attribute valid : Boolean;
  }

  port def PowerInputPort {
    in item power : ElectricalPower;
  }

  port def CommandInputPort {
    in item command : ControlCommand;
  }

  port def StatusOutputPort {
    out item status : StatusReport;
  }

  port def IlluminationPort {
    out item light : IlluminationPulse;
  }

  port def OpticalInputPort {
    in item reflectedLight : ReflectedOpticalSignal;
  }

  port def AnalogLinePort {
    out item analogLine : AnalogPixelLine;
  }

  port def DigitalLinePort {
    in item rawLine : AnalogPixelLine;
    out item digitalLine : DigitalPixelLine;
  }

  port def MeasurementOutputPort {
    out item measurement : ContactImageMeasurement;
  }

  part def RegulatedPowerSupply {
    port input : PowerInputPort;
    port lowVoltageOutput : PowerInputPort;

    attribute inputVoltage : Volt = 24.0;
    attribute regulatedVoltage : Volt = 5.0;
    attribute maximumOutputCurrent : Ampere = 1.2;
    attribute efficiency : Percent = 88.0;
  }

  part def LEDLineIlluminator {
    port powerInput : PowerInputPort;
    port illuminationOutput : IlluminationPort;

    attribute emittedWavelength : Micrometer = 0.57;
    attribute nominalIntensity : Lux = 12000.0;
    attribute uniformity : Percent = 92.0;
    attribute activeWidth : Millimeter = 216.0;
  }

  part def ContactImageSensor {
    port opticalInput : OpticalInputPort;
    port analogOutput : AnalogLinePort;
    port powerInput : PowerInputPort;

    attribute sensingWidth : Millimeter = 216.0;
    attribute pixelPitch : Micrometer = 84.7;
    attribute pixelCount : PixelCount = 2550;
    attribute lineRate : Hertz = 1000.0;
    attribute bitEquivalentDynamicRange : Integer = 12;
    attribute operatingTemperatureMin : Celsius = 0.0;
    attribute operatingTemperatureMax : Celsius = 50.0;
  }

  part def AnalogFrontEnd {
    port sensorInput : DigitalLinePort;
    port digitalOutput : DigitalLinePort;
    port powerInput : PowerInputPort;

    attribute adcResolution : Integer = 12;
    attribute sampleRate : Hertz = 3000000.0;
    attribute gain : Real = 2.0;
    attribute offsetCorrectionEnabled : Boolean = true;
  }

  part def MeasurementProcessor {
    port digitalInput : DigitalLinePort;
    port measurementOutput : MeasurementOutputPort;
    port commandInput : CommandInputPort;
    port statusOutput : StatusOutputPort;

    attribute darkReferenceValid : Boolean = false;
    attribute whiteReferenceValid : Boolean = false;
    attribute reflectanceScaleMin : Percent = 0.0;
    attribute reflectanceScaleMax : Percent = 100.0;
    attribute minimumValidGrayLevel : GrayLevel = 16;
    attribute maximumValidGrayLevel : GrayLevel = 4095;

    action calibrate {
      in item darkLine : DigitalPixelLine;
      in item whiteLine : DigitalPixelLine;
      out attribute calibrationAccepted : Boolean;
    }

    action computeMeasurement {
      in item line : DigitalPixelLine;
      out item result : ContactImageMeasurement;
    }

    state behavior MeasurementControl {
      state off;
      state initializing;
      state idle;
      state calibrating;
      state scanning;
      state reporting;
      state fault;

      entry action initializeElectronics;
      entry action validateReferences;

      transition first off then initializing;
      transition initializing then idle
        accept StatusReport
        if ready and not faultPresent;

      transition idle then calibrating
        accept ControlCommand
        if calibrationRequested;

      transition calibrating then idle
        accept StatusReport
        if calibrated and not faultPresent;

      transition idle then scanning
        accept ControlCommand
        if scanRequested and calibrated;

      transition scanning then reporting
        accept DigitalPixelLine;

      transition reporting then idle
        accept ContactImageMeasurement
        if valid;

      transition initializing then fault
        accept StatusReport
        if faultPresent;

      transition calibrating then fault
        accept StatusReport
        if faultPresent;

      transition scanning then fault
        accept StatusReport
        if faultPresent;

      transition fault then initializing
        accept ControlCommand
        if calibrationRequested;
    }
  }

  part def ContactImageSensingUnit {
    port powerInput : PowerInputPort;
    port commandInput : CommandInputPort;
    port statusOutput : StatusOutputPort;
    port measurementOutput : MeasurementOutputPort;
    port opticalInput : OpticalInputPort;

    part powerSupply : RegulatedPowerSupply;
    part illuminator : LEDLineIlluminator;
    part sensor : ContactImageSensor;
    part frontEnd : AnalogFrontEnd;
    part processor : MeasurementProcessor;

    attribute measuredQuantity : String = "surface optical reflectance line image";
    attribute nominalScanWidth : Millimeter = 216.0;
    attribute nominalPixelPitch : Micrometer = 84.7;
    attribute nominalResolution : PixelCount = 2550;
    attribute maximumMeasurementLatency : Millisecond = 25.0;

    connect powerInput to powerSupply.input;
    connect powerSupply.lowVoltageOutput to illuminator.powerInput;
    connect powerSupply.lowVoltageOutput to sensor.powerInput;
    connect powerSupply.lowVoltageOutput to frontEnd.powerInput;

    connect commandInput to processor.commandInput;
    connect processor.statusOutput to statusOutput;

    connect illuminator.illuminationOutput to opticalInput;
    connect opticalInput to sensor.opticalInput;

    connect sensor.analogOutput to frontEnd.sensorInput;
    connect frontEnd.digitalOutput to processor.digitalInput;
    connect processor.measurementOutput to measurementOutput;
  }

  requirement def SensingUnitRequirement {
    subject unit : ContactImageSensingUnit;

    require constraint {
      unit.sensor.sensingWidth >= unit.nominalScanWidth
    }

    require constraint {
      unit.sensor.pixelPitch <= unit.nominalPixelPitch
    }

    require constraint {
      unit.sensor.pixelCount >= unit.nominalResolution
    }

    require constraint {
      unit.frontEnd.adcResolution >= 12
    }

    require constraint {
      unit.illuminator.uniformity >= 90.0
    }

    require constraint {
      unit.maximumMeasurementLatency <= 25.0
    }
  }

  requirement sensingUnitUsesContactImageSensor : SensingUnitRequirement {
    subject unit = contactImageSensingUnit;
    doc
    /*
     The sensing unit shall measure surface optical reflectance as a line image
     using a Contact Image Sensor, integrated illumination, analog conversion,
     digital processing, and calibrated measurement output.
    */
  }

  part contactImageSensingUnit : ContactImageSensingUnit;

}