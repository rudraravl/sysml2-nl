package PlanarHallSensingUnitModel {

  import ScalarValues::*;
  import SI::*;

  attribute def MagneticFluxDensity {
    attribute value : Real;
    attribute unit : String = "mT";
  }

  attribute def MagneticFieldAngle {
    attribute value : Real;
    attribute unit : String = "deg";
  }

  attribute def Voltage {
    attribute value : Real;
    attribute unit : String = "mV";
  }

  attribute def Current {
    attribute value : Real;
    attribute unit : String = "mA";
  }

  attribute def Temperature {
    attribute value : Real;
    attribute unit : String = "degC";
  }

  attribute def Time {
    attribute value : Real;
    attribute unit : String = "ms";
  }

  attribute def Resolution {
    attribute value : Real;
    attribute unit : String = "uT";
  }

  item def MagneticField {
    attribute fluxDensity : MagneticFluxDensity;
    attribute inPlaneAngle : MagneticFieldAngle;
    attribute temperature : Temperature;
  }

  item def BiasCurrent {
    attribute current : Current;
  }

  item def DifferentialHallVoltage {
    attribute voltage : Voltage;
  }

  item def DigitalMeasurement {
    attribute fluxDensity : MagneticFluxDensity;
    attribute inPlaneAngle : MagneticFieldAngle;
    attribute sensorTemperature : Temperature;
    attribute timestamp : Time;
    attribute valid : Boolean;
  }

  item def DiagnosticStatus {
    attribute sensorOpenCircuit : Boolean;
    attribute sensorSaturated : Boolean;
    attribute overTemperature : Boolean;
    attribute calibrationValid : Boolean;
    attribute measurementValid : Boolean;
  }

  port def MagneticFieldInputPort {
    in item field : MagneticField;
  }

  port def BiasCurrentPort {
    out item bias : BiasCurrent;
  }

  port def HallVoltagePort {
    in item hallVoltage : DifferentialHallVoltage;
  }

  port def DigitalMeasurementPort {
    out item measurement : DigitalMeasurement;
  }

  port def DiagnosticPort {
    out item status : DiagnosticStatus;
  }

  port def PowerPort {
    in attribute supplyVoltage : Voltage;
    in attribute supplyCurrent : Current;
  }

  port def GroundPort {
    out attribute referenceVoltage : Voltage;
  }

  action def ExcitePlanarHallElement {
    in item commandedBias : BiasCurrent;
    out item generatedBias : BiasCurrent;

    first start;
    then regulateCurrent;
    then verifyCurrent;
    then done;

    action regulateCurrent;
    action verifyCurrent;
  }

  action def SensePlanarHallVoltage {
    in item field : MagneticField;
    in item bias : BiasCurrent;
    out item rawVoltage : DifferentialHallVoltage;

    first exposeSensor;
    then producePlanarHallVoltage;
    then rejectCommonMode;
    then done;

    action exposeSensor;
    action producePlanarHallVoltage;
    action rejectCommonMode;
  }

  action def ConvertAndFilterMeasurement {
    in item rawVoltage : DifferentialHallVoltage;
    in attribute temperature : Temperature;
    out item measurement : DigitalMeasurement;

    first sampleAnalogVoltage;
    then compensateOffset;
    then compensateTemperature;
    then computeFluxDensityAndAngle;
    then lowPassFilter;
    then publishMeasurement;

    action sampleAnalogVoltage;
    action compensateOffset;
    action compensateTemperature;
    action computeFluxDensityAndAngle;
    action lowPassFilter;
    action publishMeasurement;
  }

  state def SensingUnitLifecycle {
    entry;
    state Off;
    state Initializing;
    state Calibrating;
    state Measuring;
    state Fault;
    state Shutdown;

    transition initial then Off;

    transition powerApplied
      first Off
      then Initializing;

    transition initializationComplete
      first Initializing
      then Calibrating;

    transition calibrationComplete
      first Calibrating
      then Measuring;

    transition faultDetected
      first Measuring
      then Fault;

    transition faultCleared
      first Fault
      then Calibrating;

    transition powerRemoved
      first Measuring
      then Shutdown;

    transition shutdownComplete
      first Shutdown
      then Off;
  }

  part def PlanarHallSensorElement {
    port fieldInput : MagneticFieldInputPort;
    port biasInput : HallVoltagePort;
    port hallOutput : HallVoltagePort;

    attribute sensitivity : Real = 0.85;
    attribute sensitivityUnit : String = "mV/mT/mA";
    attribute nominalResistance : Real = 1200.0;
    attribute resistanceUnit : String = "ohm";
    attribute maximumField : MagneticFluxDensity = (value = 100.0, unit = "mT");
    attribute operatingTemperatureMin : Temperature = (value = -40.0, unit = "degC");
    attribute operatingTemperatureMax : Temperature = (value = 125.0, unit = "degC");

    perform action senseVoltage : SensePlanarHallVoltage;
  }

  part def PrecisionCurrentSource {
    port power : PowerPort;
    port ground : GroundPort;
    port biasOutput : BiasCurrentPort;

    attribute nominalBiasCurrent : Current = (value = 5.0, unit = "mA");
    attribute currentTolerance : Real = 0.5;
    attribute currentToleranceUnit : String = "%";
    attribute complianceVoltage : Voltage = (value = 3300.0, unit = "mV");

    perform action exciteSensor : ExcitePlanarHallElement;
  }

  part def InstrumentationAmplifier {
    port hallInput : HallVoltagePort;
    port amplifiedOutput : HallVoltagePort;
    port power : PowerPort;
    port ground : GroundPort;

    attribute gain : Real = 100.0;
    attribute inputOffset : Voltage = (value = 0.05, unit = "mV");
    attribute bandwidth : Real = 1000.0;
    attribute bandwidthUnit : String = "Hz";
    attribute commonModeRejection : Real = 90.0;
    attribute commonModeRejectionUnit : String = "dB";
  }

  part def AnalogToDigitalConverter {
    port analogInput : HallVoltagePort;
    port power : PowerPort;
    port ground : GroundPort;

    attribute resolutionBits : Integer = 16;
    attribute sampleRate : Real = 1000.0;
    attribute sampleRateUnit : String = "sample/s";
    attribute referenceVoltage : Voltage = (value = 2500.0, unit = "mV");
  }

  part def TemperatureSensor {
    attribute measuredTemperature : Temperature;
    attribute accuracy : Temperature = (value = 1.0, unit = "degC");
    attribute updatePeriod : Time = (value = 100.0, unit = "ms");
  }

  part def SignalProcessor {
    port measurementOutput : DigitalMeasurementPort;
    port diagnosticOutput : DiagnosticPort;

    attribute offsetCalibration : Voltage = (value = 0.0, unit = "mV");
    attribute gainCalibration : Real = 1.0;
    attribute filterCutoffFrequency : Real = 50.0;
    attribute filterCutoffUnit : String = "Hz";
    attribute measurementResolution : Resolution = (value = 10.0, unit = "uT");
    attribute measurementLatency : Time = (value = 20.0, unit = "ms");

    perform action convertAndFilter : ConvertAndFilterMeasurement;
  }

  part def ShieldAndPackage {
    attribute ingressProtection : String = "IP54";
    attribute magneticReferenceAxisMarked : Boolean = true;
    attribute connectorPins : Integer = 6;
    attribute material : String = "glass-filled polymer";
  }

  part def PlanarHallSensingUnit {
    port magneticInput : MagneticFieldInputPort;
    port powerInput : PowerPort;
    port groundReference : GroundPort;
    port measurementOutput : DigitalMeasurementPort;
    port diagnosticOutput : DiagnosticPort;

    attribute measuredQuantity : String = "in-plane magnetic flux density and field angle";
    attribute measurementRange : MagneticFluxDensity = (value = 100.0, unit = "mT");
    attribute fieldResolution : Resolution = (value = 10.0, unit = "uT");
    attribute outputPeriod : Time = (value = 10.0, unit = "ms");
    attribute operatingTemperatureMin : Temperature = (value = -40.0, unit = "degC");
    attribute operatingTemperatureMax : Temperature = (value = 85.0, unit = "degC");

    part sensor : PlanarHallSensorElement;
    part currentSource : PrecisionCurrentSource;
    part amplifier : InstrumentationAmplifier;
    part adc : AnalogToDigitalConverter;
    part temperatureSensor : TemperatureSensor;
    part processor : SignalProcessor;
    part enclosure : ShieldAndPackage;

    connect magneticInput to sensor.fieldInput;
    connect powerInput to currentSource.power;
    connect powerInput to amplifier.power;
    connect powerInput to adc.power;
    connect groundReference to currentSource.ground;
    connect groundReference to amplifier.ground;
    connect groundReference to adc.ground;
    connect currentSource.biasOutput to sensor.biasInput;
    connect sensor.hallOutput to amplifier.hallInput;
    connect amplifier.amplifiedOutput to adc.analogInput;
    connect processor.measurementOutput to measurementOutput;
    connect processor.diagnosticOutput to diagnosticOutput;

    exhibit state lifecycle : SensingUnitLifecycle;
  }

  requirement def MeasureWithPlanarHallSensor {
    subject unit : PlanarHallSensingUnit;

    require constraint {
      unit.measuredQuantity == "in-plane magnetic flux density and field angle"
    }

    require constraint {
      unit.fieldResolution.value <= 10.0
    }

    require constraint {
      unit.outputPeriod.value <= 10.0
    }

    require constraint {
      unit.measurementRange.value >= 100.0
    }
  }

  requirement def SensorTechnologyRequirement {
    subject sensor : PlanarHallSensorElement;

    require constraint {
      sensor.sensitivity > 0.0
    }

    require constraint {
      sensor.maximumField.value >= 100.0
    }
  }

  requirement def EnvironmentalRequirement {
    subject unit : PlanarHallSensingUnit;

    require constraint {
      unit.operatingTemperatureMin.value <= -40.0
    }

    require constraint {
      unit.operatingTemperatureMax.value >= 85.0
    }
  }

  requirement def DiagnosticRequirement {
    subject unit : PlanarHallSensingUnit;

    require constraint {
      unit.diagnosticOutput.status.calibrationValid == true implies
      unit.diagnosticOutput.status.measurementValid == true
    }
  }

  satisfy MeasureWithPlanarHallSensor by PlanarHallSensingUnit;
  satisfy SensorTechnologyRequirement by PlanarHallSensorElement;
  satisfy EnvironmentalRequirement by PlanarHallSensingUnit;
  satisfy DiagnosticRequirement by PlanarHallSensingUnit;

}