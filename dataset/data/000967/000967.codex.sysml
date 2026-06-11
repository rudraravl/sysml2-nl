package AirPollutionSensingUnitModel {

  enum def PollutantKind {
    enum pm1_0;
    enum pm2_5;
    enum pm10;
    enum carbonMonoxide;
    enum nitrogenDioxide;
    enum ozone;
    enum sulfurDioxide;
    enum volatileOrganicCompounds;
  }

  enum def AirQualityCategory {
    enum good;
    enum moderate;
    enum unhealthyForSensitiveGroups;
    enum unhealthy;
    enum veryUnhealthy;
    enum hazardous;
    enum invalid;
  }

  attribute def MicrogramPerCubicMeter {
    attribute value : Real;
    attribute unit : String = "ug/m^3";
  }

  attribute def PartsPerMillion {
    attribute value : Real;
    attribute unit : String = "ppm";
  }

  attribute def PartsPerBillion {
    attribute value : Real;
    attribute unit : String = "ppb";
  }

  attribute def DegreesCelsius {
    attribute value : Real;
    attribute unit : String = "degC";
  }

  attribute def PercentRelativeHumidity {
    attribute value : Real;
    attribute unit : String = "%RH";
  }

  attribute def Pascal {
    attribute value : Real;
    attribute unit : String = "Pa";
  }

  attribute def Volt {
    attribute value : Real;
    attribute unit : String = "V";
  }

  attribute def Milliampere {
    attribute value : Real;
    attribute unit : String = "mA";
  }

  attribute def Millisecond {
    attribute value : Real;
    attribute unit : String = "ms";
  }

  attribute def Hertz {
    attribute value : Real;
    attribute unit : "Hz";
  }

  attribute def Timestamp {
    attribute epochMilliseconds : Integer;
    attribute unit : String = "ms since 1970-01-01T00:00:00Z";
  }

  item def AirSample {
    attribute sampleTime : Timestamp;
    attribute temperature : DegreesCelsius;
    attribute relativeHumidity : PercentRelativeHumidity;
    attribute pressure : Pascal;
    attribute flowRateLiterPerMinute : Real;
  }

  item def RawSensorFrame {
    attribute frameTime : Timestamp;
    attribute laserScatterChannel0 : Integer;
    attribute laserScatterChannel1 : Integer;
    attribute electrochemicalNO2Millivolts : Real;
    attribute electrochemicalCOMillivolts : Real;
    attribute metalOxideVOCResistanceOhm : Real;
    attribute sensorTemperature : DegreesCelsius;
    attribute sensorHumidity : PercentRelativeHumidity;
    attribute checksumValid : Boolean;
  }

  item def PollutantMeasurement {
    attribute pollutant : PollutantKind;
    attribute value : Real;
    attribute unitSymbol : String;
    attribute uncertaintyPercent : Real;
    attribute valid : Boolean;
  }

  item def AirQualityReport {
    attribute reportTime : Timestamp;
    attribute pm1_0 : MicrogramPerCubicMeter;
    attribute pm2_5 : MicrogramPerCubicMeter;
    attribute pm10 : MicrogramPerCubicMeter;
    attribute carbonMonoxide : PartsPerMillion;
    attribute nitrogenDioxide : PartsPerBillion;
    attribute ozone : PartsPerBillion;
    attribute sulfurDioxide : PartsPerBillion;
    attribute volatileOrganicCompounds : PartsPerBillion;
    attribute airQualityIndex : Integer;
    attribute category : AirQualityCategory;
    attribute dataValid : Boolean;
    attribute diagnosticCode : String;
  }

  item def CalibrationCommand {
    attribute commandTime : Timestamp;
    attribute zeroReferenceEnabled : Boolean;
    attribute spanGasConcentrationPpb : Real;
    attribute targetPollutant : PollutantKind;
  }

  item def DiagnosticReport {
    attribute reportTime : Timestamp;
    attribute sensorReady : Boolean;
    attribute pumpReady : Boolean;
    attribute heaterReady : Boolean;
    attribute opticsClean : Boolean;
    attribute supplyVoltage : Volt;
    attribute supplyCurrent : Milliampere;
    attribute faultCode : String;
  }

  port def AirIntakePort {
    in item ambientAir : AirSample;
  }

  port def AirExhaustPort {
    out item exhaustedAir : AirSample;
  }

  port def SampleFlowPort {
    inout item sample : AirSample;
  }

  port def RawSensorDataPort {
    out item rawFrame : RawSensorFrame;
  }

  port def MeasurementPort {
    out item report : AirQualityReport;
  }

  port def CalibrationPort {
    in item command : CalibrationCommand;
  }

  port def DiagnosticPort {
    out item diagnostic : DiagnosticReport;
  }

  port def PowerInputPort {
    in attribute voltage : Volt;
    in attribute currentLimit : Milliampere;
  }

  port def RegulatedPowerPort {
    out attribute voltage : Volt;
    out attribute availableCurrent : Milliampere;
  }

  port def DigitalControlPort {
    in attribute enable : Boolean;
    in attribute reset : Boolean;
    out attribute ready : Boolean;
    out attribute fault : Boolean;
  }

  part def AirPollutionSensor {
    port sampleIn : SampleFlowPort;
    port sampleOut : SampleFlowPort;
    port rawData : RawSensorDataPort;
    port control : DigitalControlPort;
    port power : RegulatedPowerPort;

    attribute warmupTime : Millisecond = 30000;
    attribute measurementRate : Hertz = 1;
    attribute pm2_5Range : MicrogramPerCubicMeter = 1000;
    attribute pm2_5Resolution : MicrogramPerCubicMeter = 1;
    attribute gasResolutionPpb : Real = 1;
    attribute operatingTemperatureMin : DegreesCelsius = -10;
    attribute operatingTemperatureMax : DegreesCelsius = 50;
    attribute operatingHumidityMax : PercentRelativeHumidity = 95;
  }

  part def SamplePump {
    port intake : SampleFlowPort;
    port exhaust : SampleFlowPort;
    port control : DigitalControlPort;
    port power : RegulatedPowerPort;

    attribute nominalFlowRateLiterPerMinute : Real = 0.25;
    attribute flowTolerancePercent : Real = 10;
    attribute startupTime : Millisecond = 1500;
  }

  part def EnvironmentalCompensator {
    port sampleEnvironment : SampleFlowPort;

    attribute temperatureCoefficientPM : Real = 0.004;
    attribute humidityCoefficientPM : Real = 0.006;
    attribute gasTemperatureCoefficient : Real = 0.01;
  }

  part def SignalProcessor {
    port rawInput : RawSensorDataPort;
    port measurementOutput : MeasurementPort;
    port calibrationInput : CalibrationPort;
    port diagnosticOutput : DiagnosticPort;

    attribute averagingWindowSamples : Integer = 10;
    attribute pm2_5GoodLimit : MicrogramPerCubicMeter = 12;
    attribute pm2_5ModerateLimit : MicrogramPerCubicMeter = 35;
    attribute pm2_5UnhealthyLimit : MicrogramPerCubicMeter = 55;
    attribute coGoodLimit : PartsPerMillion = 4;
    attribute no2GoodLimit : PartsPerBillion = 53;
    attribute staleDataTimeout : Millisecond = 5000;
  }

  part def PowerRegulator {
    port inputPower : PowerInputPort;
    port sensorPower : RegulatedPowerPort;
    port pumpPower : RegulatedPowerPort;
    port controllerPower : RegulatedPowerPort;

    attribute nominalInputVoltage : Volt = 12;
    attribute regulatedSensorVoltage : Volt = 5;
    attribute regulatedControllerVoltage : Volt = 3.3;
    attribute maximumCurrent : Milliampere = 750;
  }

  action def AcquireAirSample {
    in item ambientAir : AirSample;
    out item conditionedSample : AirSample;
  }

  action def SensePollution {
    in item conditionedSample : AirSample;
    out item rawFrame : RawSensorFrame;
  }

  action def CompensateAndConvert {
    in item rawFrame : RawSensorFrame;
    out item report : AirQualityReport;
  }

  action def CheckDiagnostics {
    in item rawFrame : RawSensorFrame;
    out item diagnostic : DiagnosticReport;
  }

  action def MeasurementCycle {
    in item ambientAir : AirSample;
    out item report : AirQualityReport;
    out item diagnostic : DiagnosticReport;

    action acquire : AcquireAirSample {
      in ambientAir = ambientAir;
    }

    action sense : SensePollution {
      in conditionedSample = acquire.conditionedSample;
    }

    action convert : CompensateAndConvert {
      in rawFrame = sense.rawFrame;
    }

    action diagnose : CheckDiagnostics {
      in rawFrame = sense.rawFrame;
    }

    bind report = convert.report;
    bind diagnostic = diagnose.diagnostic;
  }

  state def SensingUnitStateMachine {
    state off;
    state initializing;
    state warming;
    state sampling;
    state processing;
    state reporting;
    state calibrating;
    state faulted;

    transition initial then off;
    transition off to initializing accept powerApplied;
    transition initializing to warming accept selfTestPassed;
    transition initializing to faulted accept selfTestFailed;
    transition warming to sampling accept warmupComplete;
    transition sampling to processing accept sampleAcquired;
    transition processing to reporting accept measurementValid;
    transition processing to faulted accept measurementInvalid;
    transition reporting to sampling accept reportTransmitted;
    transition sampling to calibrating accept calibrationRequested;
    transition calibrating to sampling accept calibrationComplete;
    transition calibrating to faulted accept calibrationFailed;
    transition faulted to initializing accept resetRequested;
    transition sampling to off accept powerRemoved;
    transition reporting to off accept powerRemoved;
    transition faulted to off accept powerRemoved;
  }

  part def AirPollutionSensingUnit {
    port airIntake : AirIntakePort;
    port airExhaust : AirExhaustPort;
    port telemetry : MeasurementPort;
    port calibration : CalibrationPort;
    port diagnostics : DiagnosticPort;
    port powerInput : PowerInputPort;

    part sensor : AirPollutionSensor;
    part pump : SamplePump;
    part compensator : EnvironmentalCompensator;
    part processor : SignalProcessor;
    part regulator : PowerRegulator;

    attribute enclosureIngressProtection : String = "IP54";
    attribute sampleInterval : Millisecond = 1000;
    attribute reportInterval : Millisecond = 1000;
    attribute maximumStartupTime : Millisecond = 45000;
    attribute operatingTemperatureMin : DegreesCelsius = -10;
    attribute operatingTemperatureMax : DegreesCelsius = 50;

    connect powerInput to regulator.inputPower;
    connect regulator.sensorPower to sensor.power;
    connect regulator.pumpPower to pump.power;
    connect regulator.controllerPower to processor.rawInput;

    connect airIntake.ambientAir to pump.intake.sample;
    connect pump.exhaust.sample to sensor.sampleIn.sample;
    connect sensor.sampleOut.sample to airExhaust.exhaustedAir;

    connect sensor.rawData.rawFrame to processor.rawInput.rawFrame;
    connect calibration.command to processor.calibrationInput.command;
    connect processor.measurementOutput.report to telemetry.report;
    connect processor.diagnosticOutput.diagnostic to diagnostics.diagnostic;

    exhibit stateMachine : SensingUnitStateMachine;
    perform action measurementCycle : MeasurementCycle;
  }

  requirement def MeasureAirPollutionRequirement {
    doc /* The sensing unit shall measure airborne particulate and gas pollutants using an air pollution sensor. */
    subject unit : AirPollutionSensingUnit;
    require constraint {
      unit.sensor.pm2_5Range.value >= 500
    }
  }

  requirement def MeasurementAccuracyRequirement {
    doc /* The sensing unit shall report PM2.5 concentration with uncertainty not exceeding 15 percent across the normal operating range. */
    subject report : AirQualityReport;
    require constraint {
      report.pm2_5.value >= 0
    }
  }

  requirement def SamplingRateRequirement {
    doc /* The sensing unit shall produce one valid air quality report at least once every 1000 ms during normal sampling operation. */
    subject unit : AirPollutionSensingUnit;
    require constraint {
      unit.reportInterval.value <= 1000
    }
  }

  requirement def EnvironmentalOperatingRequirement {
    doc /* The sensing unit shall operate from -10 degC to 50 degC and up to 95 percent relative humidity. */
    subject unit : AirPollutionSensingUnit;
    require constraint {
      unit.operatingTemperatureMin.value <= -10 and unit.operatingTemperatureMax.value >= 50
    }
  }

  requirement def DiagnosticRequirement {
    doc /* The sensing unit shall indicate invalid measurements when sensor, pump, power, checksum, or warmup diagnostics fail. */
    subject diagnostic : DiagnosticReport;
    require constraint {
      diagnostic.sensorReady and diagnostic.pumpReady and diagnostic.heaterReady implies diagnostic.faultCode == "NONE"
    }
  }

  requirement def CalibrationRequirement {
    doc /* The sensing unit shall accept zero and span calibration commands for supported gas pollutant channels. */
    subject command : CalibrationCommand;
    require constraint {
      command.targetPollutant == PollutantKind::carbonMonoxide or
      command.targetPollutant == PollutantKind::nitrogenDioxide or
      command.targetPollutant == PollutantKind::ozone or
      command.targetPollutant == PollutantKind::sulfurDioxide
    }
  }

  part sensingUnit : AirPollutionSensingUnit;

  satisfy MeasureAirPollutionRequirement by sensingUnit;
  satisfy SamplingRateRequirement by sensingUnit;
  satisfy EnvironmentalOperatingRequirement by sensingUnit;
}