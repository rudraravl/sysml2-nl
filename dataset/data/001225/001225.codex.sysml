package ResistanceThermometerSystem {

  value type Celsius {
    unit = "degC";
    quantityKind = "thermodynamic temperature";
  }

  value type Ohm {
    unit = "Ohm";
    quantityKind = "electrical resistance";
  }

  value type Volt {
    unit = "V";
    quantityKind = "electric potential";
  }

  value type MilliAmpere {
    unit = "mA";
    quantityKind = "electric current";
  }

  value type Second {
    unit = "s";
    quantityKind = "time";
  }

  value type Percent {
    unit = "%";
    quantityKind = "ratio";
  }

  item def ThermalCondition {
    attribute temperature : Celsius;
    attribute thermalStability : Celsius;
  }

  item def ExcitationCurrent {
    attribute current : MilliAmpere;
    attribute noise : Percent;
  }

  item def ResistanceSignal {
    attribute resistance : Ohm;
    attribute measuredVoltage : Volt;
  }

  item def TemperatureReading {
    attribute temperature : Celsius;
    attribute uncertainty : Celsius;
    attribute timestamp : Second;
    attribute valid : Boolean;
  }

  item def DiagnosticReport {
    attribute sensorOpenCircuit : Boolean;
    attribute sensorShortCircuit : Boolean;
    attribute adcFault : Boolean;
    attribute calibrationExpired : Boolean;
  }

  port def ThermalInputPort {
    in item thermalCondition : ThermalCondition;
  }

  port def CurrentOutputPort {
    out item excitation : ExcitationCurrent;
  }

  port def ResistanceInputPort {
    in item resistanceSignal : ResistanceSignal;
  }

  port def TemperatureOutputPort {
    out item reading : TemperatureReading;
  }

  port def DiagnosticOutputPort {
    out item report : DiagnosticReport;
  }

  part def RTDElement {
    attribute nominalResistance : Ohm = 100.0;
    attribute referenceTemperature : Celsius = 0.0;
    attribute alpha : Real = 0.00385;
    attribute selfHeatingCoefficient : Celsius = 0.05;

    port thermalPort : ThermalInputPort;
    port excitationPort : CurrentOutputPort;
    port resistancePort : ResistanceInputPort;

    action convertTemperatureToResistance {
      in item sensedCondition : ThermalCondition;
      in item excitation : ExcitationCurrent;
      out item resistanceSignal : ResistanceSignal;

      attribute deltaT : Celsius;
      attribute effectiveTemperature : Celsius;
      attribute calculatedResistance : Ohm;

      deltaT = sensedCondition.temperature - referenceTemperature;
      effectiveTemperature = sensedCondition.temperature + selfHeatingCoefficient;
      calculatedResistance = nominalResistance * (1.0 + alpha * deltaT);

      resistanceSignal.resistance = calculatedResistance;
      resistanceSignal.measuredVoltage = calculatedResistance * excitation.current;
    }
  }

  part def ConstantCurrentSource {
    attribute setCurrent : MilliAmpere = 1.0;
    attribute currentAccuracy : Percent = 0.05;
    attribute complianceVoltage : Volt = 5.0;

    port excitationOut : CurrentOutputPort;

    action generateExcitationCurrent {
      out item excitation : ExcitationCurrent;
      excitation.current = setCurrent;
      excitation.noise = currentAccuracy;
    }
  }

  part def SignalConditioner {
    attribute gain : Real = 32.0;
    attribute lowPassCutoffFrequencyHz : Real = 10.0;
    attribute bridgeOffset : Volt = 0.0;

    port resistanceIn : ResistanceInputPort;
    port conditionedOut : ResistanceInputPort;

    action amplifyAndFilter {
      in item rawSignal : ResistanceSignal;
      out item conditionedSignal : ResistanceSignal;

      conditionedSignal.resistance = rawSignal.resistance;
      conditionedSignal.measuredVoltage = (rawSignal.measuredVoltage - bridgeOffset) * gain;
    }
  }

  part def AnalogToDigitalConverter {
    attribute resolutionBits : Integer = 24;
    attribute samplePeriod : Second = 0.25;
    attribute referenceVoltage : Volt = 2.5;

    port analogIn : ResistanceInputPort;
    port digitalOut : ResistanceInputPort;

    action digitizeResistanceSignal {
      in item analogSignal : ResistanceSignal;
      out item digitalSignal : ResistanceSignal;

      digitalSignal.resistance = analogSignal.resistance;
      digitalSignal.measuredVoltage = analogSignal.measuredVoltage;
    }
  }

  part def TemperatureProcessor {
    attribute lowerRange : Celsius = -200.0;
    attribute upperRange : Celsius = 850.0;
    attribute calibrationOffset : Celsius = 0.0;
    attribute calibrationGain : Real = 1.0;
    attribute maxAllowedUncertainty : Celsius = 0.5;

    port resistanceIn : ResistanceInputPort;
    port temperatureOut : TemperatureOutputPort;
    port diagnosticOut : DiagnosticOutputPort;

    action calculateTemperature {
      in item digitizedSignal : ResistanceSignal;
      out item reading : TemperatureReading;
      out item diagnostics : DiagnosticReport;

      attribute rawTemperature : Celsius;
      attribute compensatedTemperature : Celsius;

      rawTemperature = ((digitizedSignal.resistance / 100.0) - 1.0) / 0.00385;
      compensatedTemperature = rawTemperature * calibrationGain + calibrationOffset;

      reading.temperature = compensatedTemperature;
      reading.uncertainty = maxAllowedUncertainty;
      reading.valid = compensatedTemperature >= lowerRange and compensatedTemperature <= upperRange;

      diagnostics.sensorOpenCircuit = digitizedSignal.resistance > 400.0;
      diagnostics.sensorShortCircuit = digitizedSignal.resistance < 10.0;
      diagnostics.adcFault = false;
      diagnostics.calibrationExpired = false;
    }
  }

  part def LocalDisplay {
    port temperatureIn : TemperatureOutputPort;

    action showTemperature {
      in item reading : TemperatureReading;
    }
  }

  part def DigitalCommunicationInterface {
    attribute protocol : String = "Modbus RTU";
    attribute updatePeriod : Second = 1.0;

    port temperatureIn : TemperatureOutputPort;
    port diagnosticIn : DiagnosticOutputPort;
    port temperatureOut : TemperatureOutputPort;
    port diagnosticOut : DiagnosticOutputPort;

    action transmitMeasurement {
      in item reading : TemperatureReading;
      in item diagnostics : DiagnosticReport;
      out item publishedReading : TemperatureReading;
      out item publishedDiagnostics : DiagnosticReport;

      publishedReading = reading;
      publishedDiagnostics = diagnostics;
    }
  }

  state def ResistanceThermometerOperatingState {
    state Off;
    state PowerUpSelfTest;
    state Calibrating;
    state Measuring;
    state Reporting;
    state Fault;

    transition initial then Off;

    transition powerApplied
      first Off
      then PowerUpSelfTest;

    transition selfTestPassed
      first PowerUpSelfTest
      then Calibrating;

    transition calibrationLoaded
      first Calibrating
      then Measuring;

    transition measurementCalculated
      first Measuring
      then Reporting;

    transition reportPublished
      first Reporting
      then Measuring;

    transition diagnosticFailure
      first PowerUpSelfTest
      then Fault;

    transition sensorFailure
      first Measuring
      then Fault;

    transition resetCommand
      first Fault
      then PowerUpSelfTest;
  }

  action def HighLevelTemperatureMeasurementFunction {
    in item processCondition : ThermalCondition;
    out item temperatureReading : TemperatureReading;
    out item diagnosticReport : DiagnosticReport;

    action senseResistance;
    action conditionSignal;
    action convertSignal;
    action computeTemperature;
    action publishReading;

    flow processCondition to senseResistance;
    flow senseResistance to conditionSignal;
    flow conditionSignal to convertSignal;
    flow convertSignal to computeTemperature;
    flow computeTemperature to publishReading;
    flow publishReading to temperatureReading;
    flow computeTemperature to diagnosticReport;
  }

  part def ResistanceThermometer {
    attribute primaryFunction : String =
      "Measure the temperature of a process by converting RTD resistance into a calibrated temperature reading and reporting diagnostic status.";

    attribute measurementRangeLow : Celsius = -200.0;
    attribute measurementRangeHigh : Celsius = 850.0;
    attribute accuracy : Celsius = 0.5;
    attribute responseTime : Second = 3.0;

    port processThermalInput : ThermalInputPort;
    port measuredTemperatureOutput : TemperatureOutputPort;
    port diagnosticOutput : DiagnosticOutputPort;

    part rtdElement : RTDElement;
    part currentSource : ConstantCurrentSource;
    part signalConditioner : SignalConditioner;
    part adc : AnalogToDigitalConverter;
    part processor : TemperatureProcessor;
    part display : LocalDisplay;
    part communication : DigitalCommunicationInterface;

    perform HighLevelTemperatureMeasurementFunction;

    exhibit stateMachine : ResistanceThermometerOperatingState;

    connect processThermalInput to rtdElement.thermalPort;
    connect currentSource.excitationOut to rtdElement.excitationPort;
    connect rtdElement.resistancePort to signalConditioner.resistanceIn;
    connect signalConditioner.conditionedOut to adc.analogIn;
    connect adc.digitalOut to processor.resistanceIn;
    connect processor.temperatureOut to display.temperatureIn;
    connect processor.temperatureOut to communication.temperatureIn;
    connect processor.diagnosticOut to communication.diagnosticIn;
    connect communication.temperatureOut to measuredTemperatureOutput;
    connect communication.diagnosticOut to diagnosticOutput;
  }

  requirement def PrimaryFunctionRequirement {
    subject thermometer : ResistanceThermometer;

    doc
      "The resistance thermometer shall provide a calibrated temperature measurement of the process condition by exciting an RTD element, measuring its resistance, converting resistance to temperature, and publishing the resulting temperature reading.";

    require constraint {
      thermometer.measuredTemperatureOutput.reading.valid == true
    }
  }

  requirement def MeasurementRangeRequirement {
    subject thermometer : ResistanceThermometer;

    require constraint {
      thermometer.measurementRangeLow <= -200.0 and
      thermometer.measurementRangeHigh >= 850.0
    }
  }

  requirement def AccuracyRequirement {
    subject thermometer : ResistanceThermometer;

    require constraint {
      thermometer.accuracy <= 0.5
    }
  }

  requirement def ResponseTimeRequirement {
    subject thermometer : ResistanceThermometer;

    require constraint {
      thermometer.responseTime <= 3.0
    }
  }

  requirement def DiagnosticRequirement {
    subject thermometer : ResistanceThermometer;

    require constraint {
      thermometer.diagnosticOutput.report.sensorOpenCircuit == false and
      thermometer.diagnosticOutput.report.sensorShortCircuit == false and
      thermometer.diagnosticOutput.report.adcFault == false
    }
  }

  requirement def CommunicationUpdateRequirement {
    subject thermometer : ResistanceThermometer;

    require constraint {
      thermometer.communication.updatePeriod <= 1.0
    }
  }

  satisfy PrimaryFunctionRequirement by ResistanceThermometer;
  satisfy MeasurementRangeRequirement by ResistanceThermometer;
  satisfy AccuracyRequirement by ResistanceThermometer;
  satisfy ResponseTimeRequirement by ResistanceThermometer;
  satisfy DiagnosticRequirement by ResistanceThermometer;
  satisfy CommunicationUpdateRequirement by ResistanceThermometer;

  part resistanceThermometerSystem : ResistanceThermometer;

}