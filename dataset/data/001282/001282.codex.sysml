package ThermometerSpecification {

  import ScalarValues::*;
  import SI::*;

  value def Celsius :> Real {
    unit = "degC";
  }

  value def Kelvin :> Real {
    unit = "K";
  }

  value def Second :> Real {
    unit = "s";
  }

  value def Volt :> Real {
    unit = "V";
  }

  value def Percent :> Real {
    unit = "%";
  }

  value def TemperatureAccuracy :> Celsius;
  value def ResponseTime :> Second;
  value def BatteryVoltage :> Volt;
  value def BatteryCharge :> Percent;

  item def ThermalCondition {
    attribute temperature : Celsius;
    attribute contactStability : Percent;
  }

  item def TemperatureReading {
    attribute measuredTemperature : Celsius;
    attribute uncertainty : Celsius;
    attribute timestamp : Second;
    attribute valid : Boolean;
  }

  item def DisplayMessage {
    attribute shownTemperature : Celsius;
    attribute unitsText : String;
    attribute statusText : String;
  }

  port def ThermalProbePort {
    in item thermalInput : ThermalCondition;
  }

  port def DisplayPort {
    out item displayOutput : DisplayMessage;
  }

  port def PowerPort {
    in attribute suppliedVoltage : BatteryVoltage;
    in attribute remainingCharge : BatteryCharge;
  }

  port def ControlPort {
    in attribute powerButtonPressed : Boolean;
    in attribute unitButtonPressed : Boolean;
  }

  port def ReadingPort {
    out item reading : TemperatureReading;
  }

  action def SenseTemperature {
    in item sensedCondition : ThermalCondition;
    out attribute sensorVoltage : Volt;
  }

  action def ConvertSensorSignal {
    in attribute sensorVoltage : Volt;
    out attribute calculatedTemperature : Celsius;
  }

  action def ValidateReading {
    in attribute calculatedTemperature : Celsius;
    in attribute contactStability : Percent;
    out item validatedReading : TemperatureReading;
  }

  action def PresentReading {
    in item validatedReading : TemperatureReading;
    out item displayMessage : DisplayMessage;
  }

  action def MeasureAndDisplayTemperature {
    in item bodyOrEnvironmentCondition : ThermalCondition;
    out item finalReading : TemperatureReading;
    out item finalDisplay : DisplayMessage;

    action sense : SenseTemperature {
      in item sensedCondition = bodyOrEnvironmentCondition;
    }

    action convert : ConvertSensorSignal {
      in attribute sensorVoltage = sense.sensorVoltage;
    }

    action validate : ValidateReading {
      in attribute calculatedTemperature = convert.calculatedTemperature;
      in attribute contactStability = bodyOrEnvironmentCondition.contactStability;
    }

    action present : PresentReading {
      in item validatedReading = validate.validatedReading;
    }

    bind finalReading = validate.validatedReading;
    bind finalDisplay = present.displayMessage;
  }

  state def ThermometerOperationalState {
    entry action initializeElectronics;

    state off;
    state starting;
    state ready;
    state measuring;
    state displaying;
    state lowBattery;
    state fault;

    transition initial then off;

    transition off_to_starting
      first off
      accept powerOn
      then starting;

    transition starting_to_ready
      first starting
      accept selfTestPassed
      then ready;

    transition starting_to_fault
      first starting
      accept selfTestFailed
      then fault;

    transition ready_to_measuring
      first ready
      accept stableThermalContact
      then measuring;

    transition measuring_to_displaying
      first measuring
      accept readingValidated
      then displaying;

    transition displaying_to_ready
      first displaying
      accept displayHoldElapsed
      then ready;

    transition ready_to_lowBattery
      first ready
      accept batteryChargeLow
      then lowBattery;

    transition measuring_to_fault
      first measuring
      accept sensorOutOfRange
      then fault;

    transition lowBattery_to_off
      first lowBattery
      accept powerOff
      then off;

    transition fault_to_off
      first fault
      accept powerOff
      then off;
  }

  part def TemperatureSensor {
    port probe : ThermalProbePort;
    out attribute analogSignal : Volt;

    attribute measurableMinimum : Celsius = -40.0;
    attribute measurableMaximum : Celsius = 125.0;
    attribute sensorAccuracy : TemperatureAccuracy = 0.15;
  }

  part def SignalProcessor {
    in attribute analogSignal : Volt;
    out item processedReading : TemperatureReading;

    attribute samplingPeriod : Second = 0.25;
    attribute filteringWindow : Second = 1.0;
  }

  part def UserDisplay {
    port display : DisplayPort;

    attribute refreshPeriod : Second = 0.5;
    attribute selectedUnitText : String = "degC";
  }

  part def BatterySubsystem {
    port powerOut : PowerPort;

    attribute nominalVoltage : BatteryVoltage = 3.0;
    attribute minimumOperatingVoltage : BatteryVoltage = 2.2;
    attribute chargeRemaining : BatteryCharge;
  }

  part def UserControls {
    port controls : ControlPort;
  }

  part def Thermometer {
    port probe : ThermalProbePort;
    port readingOut : ReadingPort;
    port displayOut : DisplayPort;
    port controlIn : ControlPort;

    part sensor : TemperatureSensor;
    part processor : SignalProcessor;
    part display : UserDisplay;
    part battery : BatterySubsystem;
    part controls : UserControls;

    attribute operatingTemperatureMinimum : Celsius = 0.0;
    attribute operatingTemperatureMaximum : Celsius = 50.0;
    attribute specifiedAccuracy : TemperatureAccuracy = 0.2;
    attribute maximumResponseTime : ResponseTime = 3.0;

    perform action primaryFunction : MeasureAndDisplayTemperature;

    exhibit state operatingState : ThermometerOperationalState;

    connect probe to sensor.probe;
    connect displayOut to display.display;
    connect controlIn to controls.controls;

    bind processor.analogSignal = sensor.analogSignal;
    bind readingOut.reading = processor.processedReading;
  }

  part def MeasurementSubject {
    port thermalInterface : ThermalProbePort;

    attribute actualTemperature : Celsius;
  }

  part def ThermometerSystem {
    part thermometer : Thermometer;
    part subject : MeasurementSubject;

    connect subject.thermalInterface to thermometer.probe;

    attribute ambientTemperature : Celsius;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : ThermometerSystem;

    doc
    /*
     The thermometer system shall determine the temperature of a contacted
     subject or local environment and present a human-readable temperature
     reading as its primary high-level function.
    */

    require constraint {
      system.thermometer.readingOut.reading.valid == true
    }
  }

  requirement def AccuracyRequirement {
    subject thermometer : Thermometer;

    require constraint {
      thermometer.specifiedAccuracy <= 0.2
    }
  }

  requirement def ResponseTimeRequirement {
    subject thermometer : Thermometer;

    require constraint {
      thermometer.maximumResponseTime <= 3.0
    }
  }

  requirement def MeasurementRangeRequirement {
    subject thermometer : Thermometer;

    require constraint {
      thermometer.sensor.measurableMinimum <= -40.0 and
      thermometer.sensor.measurableMaximum >= 125.0
    }
  }

  requirement def DisplayRequirement {
    subject thermometer : Thermometer;

    require constraint {
      thermometer.display.selectedUnitText == "degC"
    }
  }

  requirement def PowerRequirement {
    subject thermometer : Thermometer;

    require constraint {
      thermometer.battery.nominalVoltage == 3.0 and
      thermometer.battery.minimumOperatingVoltage >= 2.2
    }
  }

  satisfy PrimaryFunctionRequirement by ThermometerSystem;
  satisfy AccuracyRequirement by Thermometer;
  satisfy ResponseTimeRequirement by Thermometer;
  satisfy MeasurementRangeRequirement by Thermometer;
  satisfy DisplayRequirement by Thermometer;
  satisfy PowerRequirement by Thermometer;
}