package ThermistorTemperatureControlSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  unit degC {
    symbol = "degC";
  }

  attribute def TemperatureCelsius {
    :> ISQ::temperature;
    unit = degC;
  }

  attribute def ResistanceOhm {
    :> ISQ::resistance;
    unit = SI::ohm;
  }

  attribute def Voltage {
    :> ISQ::electricPotential;
    unit = SI::volt;
  }

  attribute def Current {
    :> ISQ::electricCurrent;
    unit = SI::ampere;
  }

  attribute def Power {
    :> ISQ::power;
    unit = SI::watt;
  }

  attribute def TimeMs {
    :> ISQ::time;
    unit = SI::millisecond;
  }

  item def AnalogVoltageSignal {
    attribute voltage : Voltage;
    attribute sourceImpedance : ResistanceOhm;
  }

  item def DigitalTemperatureSample {
    attribute temperature : TemperatureCelsius;
    attribute timestamp : TimeMs;
    attribute valid : Boolean;
  }

  item def ControlCommand {
    attribute heaterEnable : Boolean;
    attribute fanEnable : Boolean;
    attribute alarmEnable : Boolean;
  }

  port def AnalogVoltagePort {
    out item signal : AnalogVoltageSignal;
  }

  port def AnalogVoltageInputPort {
    in item signal : AnalogVoltageSignal;
  }

  port def TemperatureDataPort {
    out item sample : DigitalTemperatureSample;
  }

  port def TemperatureDataInputPort {
    in item sample : DigitalTemperatureSample;
  }

  port def ControlCommandPort {
    out item command : ControlCommand;
  }

  port def ControlCommandInputPort {
    in item command : ControlCommand;
  }

  port def ElectricalPowerPort {
    in item supplyVoltage : AnalogVoltageSignal;
  }

  part def Thermistor {
    attribute nominalResistance : ResistanceOhm = 10000 [SI::ohm];
    attribute betaCoefficient : Real = 3950;
    attribute referenceTemperature : TemperatureCelsius = 25 [degC];
    attribute measuredResistance : ResistanceOhm;
    attribute selfHeatingPower : Power;

    port senseOutput : AnalogVoltagePort;

    action computeResistanceFromTemperature {
      in temperature : TemperatureCelsius;
      out resistance : ResistanceOhm;
    }
  }

  part def VoltageDivider {
    attribute fixedResistor : ResistanceOhm = 10000 [SI::ohm];
    attribute dividerSupply : Voltage = 3.3 [SI::volt];

    port thermistorNode : AnalogVoltageInputPort;
    port analogOutput : AnalogVoltagePort;
    port powerInput : ElectricalPowerPort;
  }

  part def AnalogToDigitalConverter {
    attribute resolutionBits : Integer = 12;
    attribute referenceVoltage : Voltage = 3.3 [SI::volt];
    attribute samplePeriod : TimeMs = 100 [SI::millisecond];

    port analogInput : AnalogVoltageInputPort;
    port digitalOutput : TemperatureDataPort;

    action sampleVoltage {
      in analogSignal : AnalogVoltageSignal;
      out rawCount : Integer;
    }
  }

  part def TemperatureProcessor {
    attribute lowTemperatureLimit : TemperatureCelsius = 0 [degC];
    attribute highTemperatureLimit : TemperatureCelsius = 70 [degC];
    attribute criticalTemperatureLimit : TemperatureCelsius = 85 [degC];
    attribute filteredTemperature : TemperatureCelsius;
    attribute faultDetected : Boolean;

    port sampleInput : TemperatureDataInputPort;
    port commandOutput : ControlCommandPort;

    action convertVoltageToTemperature {
      in voltage : Voltage;
      out temperature : TemperatureCelsius;
    }

    action filterTemperature {
      in currentSample : TemperatureCelsius;
      in previousFilteredValue : TemperatureCelsius;
      out filteredValue : TemperatureCelsius;
    }

    action evaluateControl {
      in measuredTemperature : TemperatureCelsius;
      out command : ControlCommand;
    }

    state temperatureControlStateMachine {
      entry; then idle;

      state idle;
      state monitoring;
      state heating;
      state cooling;
      state alarm;
      state sensorFault;

      transition start from idle to monitoring;

      transition lowTemperature from monitoring to heating
        if filteredTemperature < lowTemperatureLimit;

      transition normalFromHeating from heating to monitoring
        if filteredTemperature >= lowTemperatureLimit;

      transition highTemperature from monitoring to cooling
        if filteredTemperature > highTemperatureLimit;

      transition normalFromCooling from cooling to monitoring
        if filteredTemperature <= highTemperatureLimit;

      transition criticalTemperature from monitoring to alarm
        if filteredTemperature >= criticalTemperatureLimit;

      transition criticalWhileCooling from cooling to alarm
        if filteredTemperature >= criticalTemperatureLimit;

      transition recoveredFromAlarm from alarm to monitoring
        if filteredTemperature < highTemperatureLimit;

      transition invalidSample from monitoring to sensorFault
        if faultDetected == true;

      transition sensorRecovered from sensorFault to monitoring
        if faultDetected == false;
    }
  }

  part def HeaterDriver {
    attribute ratedPower : Power = 25 [SI::watt];

    port commandInput : ControlCommandInputPort;
    port powerInput : ElectricalPowerPort;

    action enableHeater {
      in enable : Boolean;
    }
  }

  part def CoolingFanDriver {
    attribute ratedPower : Power = 5 [SI::watt];

    port commandInput : ControlCommandInputPort;
    port powerInput : ElectricalPowerPort;

    action enableFan {
      in enable : Boolean;
    }
  }

  part def AlarmIndicator {
    port commandInput : ControlCommandInputPort;

    action indicateAlarm {
      in enable : Boolean;
    }
  }

  part def PowerSupply {
    attribute outputVoltage : Voltage = 3.3 [SI::volt];
    attribute maximumCurrent : Current = 1.0 [SI::ampere];

    port lowVoltageOutput : AnalogVoltagePort;
  }

  part def ThermistorBasedTemperatureSystem {
    attribute primaryFunction : String =
      "Measure temperature using a thermistor, convert resistance variation into a digital temperature estimate, and command heating, cooling, or alarm responses to keep the monitored environment within limits.";

    part thermistor : Thermistor;
    part divider : VoltageDivider;
    part adc : AnalogToDigitalConverter;
    part processor : TemperatureProcessor;
    part heater : HeaterDriver;
    part fan : CoolingFanDriver;
    part alarm : AlarmIndicator;
    part supply : PowerSupply;

    connect supply.lowVoltageOutput to divider.powerInput;
    connect supply.lowVoltageOutput to heater.powerInput;
    connect supply.lowVoltageOutput to fan.powerInput;

    connect thermistor.senseOutput to divider.thermistorNode;
    connect divider.analogOutput to adc.analogInput;
    connect adc.digitalOutput to processor.sampleInput;

    connect processor.commandOutput to heater.commandInput;
    connect processor.commandOutput to fan.commandInput;
    connect processor.commandOutput to alarm.commandInput;

    action performTemperatureControl {
      first start;
      then sampleThermistor;
      then convertAndFilter;
      then decideControl;
      then actuateOutputs;

      action start;
      action sampleThermistor;
      action convertAndFilter;
      action decideControl;
      action actuateOutputs;
    }
  }

  requirement def TemperatureMeasurementRequirement {
    subject system : ThermistorBasedTemperatureSystem;

    require constraint {
      system.adc.samplePeriod <= 100 [SI::millisecond]
    }

    doc /* The system shall sample the thermistor signal at least every 100 ms. */
  }

  requirement def TemperatureRangeRequirement {
    subject system : ThermistorBasedTemperatureSystem;

    require constraint {
      system.processor.lowTemperatureLimit == 0 [degC] and
      system.processor.highTemperatureLimit == 70 [degC]
    }

    doc /* The system shall maintain normal control limits between 0 degC and 70 degC. */
  }

  requirement def CriticalAlarmRequirement {
    subject system : ThermistorBasedTemperatureSystem;

    require constraint {
      system.processor.criticalTemperatureLimit == 85 [degC]
    }

    doc /* The system shall command an alarm when the filtered temperature reaches 85 degC. */
  }

  requirement def SensorConversionRequirement {
    subject system : ThermistorBasedTemperatureSystem;

    require constraint {
      system.thermistor.nominalResistance == 10000 [SI::ohm] and
      system.divider.fixedResistor == 10000 [SI::ohm]
    }

    doc /* The thermistor sensing circuit shall use a 10 kohm NTC thermistor with a matched 10 kohm divider resistor. */
  }

  requirement def HighLevelFunctionRequirement {
    subject system : ThermistorBasedTemperatureSystem;

    doc /* The system shall provide temperature-dependent monitoring and control based on thermistor resistance variation. */
  }

  part thermistorTemperatureController : ThermistorBasedTemperatureSystem;

  satisfy TemperatureMeasurementRequirement by thermistorTemperatureController;
  satisfy TemperatureRangeRequirement by thermistorTemperatureController;
  satisfy CriticalAlarmRequirement by thermistorTemperatureController;
  satisfy SensorConversionRequirement by thermistorTemperatureController;
  satisfy HighLevelFunctionRequirement by thermistorTemperatureController;
}