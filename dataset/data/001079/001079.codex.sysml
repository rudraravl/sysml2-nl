package HallProbeSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def MagneticFluxDensity {
    attribute value : Real;
    attribute unit : String = "tesla";
  }

  attribute def ElectricPotential {
    attribute value : Real;
    attribute unit : String = "volt";
  }

  attribute def ElectricCurrent {
    attribute value : Real;
    attribute unit : String = "ampere";
  }

  attribute def Temperature {
    attribute value : Real;
    attribute unit : String = "degreeCelsius";
  }

  attribute def Distance {
    attribute value : Real;
    attribute unit : String = "millimeter";
  }

  item def MagneticField {
    attribute fluxDensity : MagneticFluxDensity;
    attribute polarity : String;
    attribute fieldAxis : String;
  }

  item def BiasCurrent {
    attribute current : ElectricCurrent;
    attribute stabilityPercent : Real;
  }

  item def HallVoltageSignal {
    attribute voltage : ElectricPotential;
    attribute noiseRms : ElectricPotential;
    attribute temperatureCompensated : Boolean;
  }

  item def MagneticFieldMeasurement {
    attribute measuredFluxDensity : MagneticFluxDensity;
    attribute uncertainty : MagneticFluxDensity;
    attribute temperature : Temperature;
    attribute timestamp : String;
  }

  item def CalibrationData {
    attribute sensitivityVoltPerTesla : Real;
    attribute offsetVoltage : ElectricPotential;
    attribute referenceTemperature : Temperature;
    attribute serialNumber : String;
  }

  port def MagneticSensingPort {
    in item field : MagneticField;
  }

  port def BiasSupplyPort {
    in item bias : BiasCurrent;
  }

  port def AnalogSignalPort {
    out item signal : HallVoltageSignal;
  }

  port def MeasurementOutputPort {
    out item measurement : MagneticFieldMeasurement;
  }

  port def CalibrationPort {
    in item calibration : CalibrationData;
  }

  part def HallElement {
    attribute activeAreaWidth : Distance = (value = 0.25, unit = "millimeter");
    attribute activeAreaLength : Distance = (value = 0.25, unit = "millimeter");
    attribute nominalSensitivityVoltPerTesla : Real = 0.045;
    attribute maximumField : MagneticFluxDensity = (value = 2.0, unit = "tesla");
    attribute operatingTemperatureMin : Temperature = (value = -40.0, unit = "degreeCelsius");
    attribute operatingTemperatureMax : Temperature = (value = 125.0, unit = "degreeCelsius");

    port magneticInput : MagneticSensingPort;
    port biasInput : BiasSupplyPort;
    port hallVoltageOutput : AnalogSignalPort;

    action generateHallVoltage {
      in item appliedField : MagneticField;
      in item bias : BiasCurrent;
      out item hallSignal : HallVoltageSignal;

      first start;
      then computeTransverseVoltage;
      then addOffsetAndNoise;
      then outputSignal;
      then done;

      action computeTransverseVoltage;
      action addOffsetAndNoise;
      action outputSignal;
    }
  }

  part def BiasCurrentSource {
    attribute nominalCurrent : ElectricCurrent = (value = 0.010, unit = "ampere");
    attribute currentTolerancePercent : Real = 0.5;
    attribute rippleCurrent : ElectricCurrent = (value = 0.00001, unit = "ampere");

    port biasOutput : BiasSupplyPort;

    action regulateBiasCurrent {
      out item regulatedBias : BiasCurrent;

      first start;
      then measureCurrent;
      then compareToReference;
      then adjustDrive;
      then provideBias;
      then done;

      action measureCurrent;
      action compareToReference;
      action adjustDrive;
      action provideBias;
    }
  }

  part def SignalConditioner {
    attribute gain : Real = 100.0;
    attribute lowPassCutoffHz : Real = 1000.0;
    attribute inputOffsetMax : ElectricPotential = (value = 0.0002, unit = "volt");
    attribute outputRangeMin : ElectricPotential = (value = 0.0, unit = "volt");
    attribute outputRangeMax : ElectricPotential = (value = 5.0, unit = "volt");

    port rawSignalInput : AnalogSignalPort;
    port conditionedSignalOutput : AnalogSignalPort;

    action amplifyAndFilter {
      in item rawSignal : HallVoltageSignal;
      out item conditionedSignal : HallVoltageSignal;

      first start;
      then subtractOffset;
      then amplifySignal;
      then filterNoise;
      then limitOutputRange;
      then done;

      action subtractOffset;
      action amplifySignal;
      action filterNoise;
      action limitOutputRange;
    }
  }

  part def TemperatureSensor {
    attribute measurementRangeMin : Temperature = (value = -40.0, unit = "degreeCelsius");
    attribute measurementRangeMax : Temperature = (value = 125.0, unit = "degreeCelsius");
    attribute accuracy : Temperature = (value = 0.5, unit = "degreeCelsius");

    port temperatureOutput : MeasurementOutputPort;

    action measureTemperature {
      out attribute measuredTemperature : Temperature;

      first start;
      then sampleThermalElement;
      then linearizeReading;
      then outputTemperature;
      then done;

      action sampleThermalElement;
      action linearizeReading;
      action outputTemperature;
    }
  }

  part def MeasurementProcessor {
    attribute adcResolutionBits : Integer = 16;
    attribute samplingRateHz : Real = 2000.0;
    attribute measurementRange : MagneticFluxDensity = (value = 2.0, unit = "tesla");
    attribute nominalAccuracy : MagneticFluxDensity = (value = 0.002, unit = "tesla");

    port conditionedSignalInput : AnalogSignalPort;
    port calibrationInput : CalibrationPort;
    port measurementOutput : MeasurementOutputPort;

    action convertSignalToField {
      in item conditionedSignal : HallVoltageSignal;
      in item calibration : CalibrationData;
      out item fieldMeasurement : MagneticFieldMeasurement;

      first start;
      then sampleVoltage;
      then removeCalibratedOffset;
      then applySensitivityScale;
      then compensateTemperatureDrift;
      then estimateUncertainty;
      then publishMeasurement;
      then done;

      action sampleVoltage;
      action removeCalibratedOffset;
      action applySensitivityScale;
      action compensateTemperatureDrift;
      action estimateUncertainty;
      action publishMeasurement;
    }

    state def MeasurementStateMachine {
      state off;
      state initializing;
      state calibrating;
      state measuring;
      state faulted;

      transition first off then initializing;
      transition initializing then calibrating
        accept after 1.0 [s];
      transition calibrating then measuring
        accept when calibrationValid;
      transition measuring then faulted
        accept when signalOutOfRange;
      transition faulted then initializing
        accept resetCommand;
    }
  }

  part def UserInterface {
    attribute displayResolutionDigits : Integer = 5;
    attribute updateRateHz : Real = 10.0;

    port measurementInput : MeasurementOutputPort;

    action displayMagneticField {
      in item measurement : MagneticFieldMeasurement;

      first start;
      then formatValueWithUnits;
      then showPolarity;
      then showUncertainty;
      then done;

      action formatValueWithUnits;
      action showPolarity;
      action showUncertainty;
    }
  }

  part def HallProbeSystem {
    attribute primaryFunction : String =
      "Detect the magnetic flux density at the probe tip and convert it into a calibrated electrical measurement for display, logging, or control.";
    attribute operatingVoltage : ElectricPotential = (value = 5.0, unit = "volt");
    attribute measurementRange : MagneticFluxDensity = (value = 2.0, unit = "tesla");
    attribute targetAccuracy : MagneticFluxDensity = (value = 0.005, unit = "tesla");
    attribute responseTimeMs : Real = 5.0;

    port sensedField : MagneticSensingPort;
    port measurementOut : MeasurementOutputPort;
    port calibrationIn : CalibrationPort;

    part hallElement : HallElement;
    part biasSource : BiasCurrentSource;
    part conditioner : SignalConditioner;
    part temperatureSensor : TemperatureSensor;
    part processor : MeasurementProcessor;
    part userInterface : UserInterface;

    connect sensedField to hallElement.magneticInput;
    connect biasSource.biasOutput to hallElement.biasInput;
    connect hallElement.hallVoltageOutput to conditioner.rawSignalInput;
    connect conditioner.conditionedSignalOutput to processor.conditionedSignalInput;
    connect calibrationIn to processor.calibrationInput;
    connect processor.measurementOutput to measurementOut;
    connect processor.measurementOutput to userInterface.measurementInput;

    action performMagneticFieldMeasurement {
      in item externalField : MagneticField;
      in item calibration : CalibrationData;
      out item measurement : MagneticFieldMeasurement;

      first start;
      then establishBiasCurrent;
      then senseHallVoltage;
      then conditionSignal;
      then computeFieldDensity;
      then reportMeasurement;
      then done;

      action establishBiasCurrent;
      action senseHallVoltage;
      action conditionSignal;
      action computeFieldDensity;
      action reportMeasurement;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc "The system shall measure magnetic flux density using the Hall effect and provide a calibrated magnetic field measurement.";
    subject system : HallProbeSystem;
    require constraint {
      system.measurementRange.value >= 2.0
    }
  }

  requirement def AccuracyRequirement {
    doc "The system shall report magnetic flux density with uncertainty no greater than 0.005 tesla over the specified range.";
    subject system : HallProbeSystem;
    require constraint {
      system.targetAccuracy.value <= 0.005
    }
  }

  requirement def ResponseTimeRequirement {
    doc "The system shall update the magnetic field measurement within 5 milliseconds after a field change at the sensing port.";
    subject system : HallProbeSystem;
    require constraint {
      system.responseTimeMs <= 5.0
    }
  }

  requirement def TemperatureOperatingRequirement {
    doc "The Hall element shall operate from -40 degreeCelsius to 125 degreeCelsius.";
    subject element : HallElement;
    require constraint {
      element.operatingTemperatureMin.value <= -40.0 and
      element.operatingTemperatureMax.value >= 125.0
    }
  }

  requirement def BiasStabilityRequirement {
    doc "The bias current source shall maintain current stability within 0.5 percent during measurement.";
    subject source : BiasCurrentSource;
    require constraint {
      source.currentTolerancePercent <= 0.5
    }
  }

  requirement def SignalRangeRequirement {
    doc "The conditioned analog signal shall remain within the processor input range of 0 volt to 5 volt.";
    subject conditioner : SignalConditioner;
    require constraint {
      conditioner.outputRangeMin.value >= 0.0 and
      conditioner.outputRangeMax.value <= 5.0
    }
  }

  part hallProbe : HallProbeSystem;

  requirement primaryFunctionSatisfied : PrimaryFunctionRequirement {
    subject system = hallProbe;
  }

  requirement accuracySatisfied : AccuracyRequirement {
    subject system = hallProbe;
  }

  requirement responseTimeSatisfied : ResponseTimeRequirement {
    subject system = hallProbe;
  }

  requirement temperatureSatisfied : TemperatureOperatingRequirement {
    subject element = hallProbe.hallElement;
  }

  requirement biasStabilitySatisfied : BiasStabilityRequirement {
    subject source = hallProbe.biasSource;
  }

  requirement signalRangeSatisfied : SignalRangeRequirement {
    subject conditioner = hallProbe.conditioner;
  }
}