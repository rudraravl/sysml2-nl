package DewWarningSystemModel {
  import ScalarValues::*;
  import SI::*;

  attribute def TemperatureC :> Real { unit = "degC"; }
  attribute def RelativeHumidityPercent :> Real { unit = "%"; }
  attribute def PressureHPa :> Real { unit = "hPa"; }
  attribute def SpeedMps :> Real { unit = "m/s"; }
  attribute def VoltageV :> Real { unit = "V"; }
  attribute def TimeSecond :> Real { unit = "s"; }
  attribute def RiskIndex :> Real { unit = "1"; }

  enum def DewRiskLevel {
    enum low;
    enum guarded;
    enum warning;
    enum critical;
  }

  item def WeatherSample {
    attribute airTemperature : TemperatureC;
    attribute surfaceTemperature : TemperatureC;
    attribute dewPointTemperature : TemperatureC;
    attribute relativeHumidity : RelativeHumidityPercent;
    attribute barometricPressure : PressureHPa;
    attribute windSpeed : SpeedMps;
    attribute sampleAge : TimeSecond;
  }

  item def DewAssessment {
    attribute dewMargin : TemperatureC;
    attribute riskIndex : RiskIndex;
    attribute riskLevel : DewRiskLevel;
    attribute condensationExpectedWithin : TimeSecond;
  }

  item def WarningCommand {
    attribute active : Boolean;
    attribute riskLevel : DewRiskLevel;
    attribute messageCode : String;
    attribute audibleEnabled : Boolean;
    attribute visualEnabled : Boolean;
  }

  item def SupplyPower {
    attribute voltage : VoltageV;
    attribute available : Boolean;
  }

  port def WeatherSensePort {
    out item sample : WeatherSample;
  }

  port def AssessmentPort {
    in item sample : WeatherSample;
    out item assessment : DewAssessment;
  }

  port def WarningPort {
    in item command : WarningCommand;
  }

  port def PowerPort {
    in item power : SupplyPower;
  }

  action def EstimateDewPoint {
    in attribute airTemperature : TemperatureC;
    in attribute relativeHumidity : RelativeHumidityPercent;
    out attribute dewPointTemperature : TemperatureC;

    action computeMagnusApproximation;
  }

  action def AssessDewRisk {
    in item sample : WeatherSample;
    out item assessment : DewAssessment;

    action computeDewMargin;
    action classifyRisk;
    action estimateTimeToCondensation;

    flow sample.airTemperature to computeDewMargin;
    flow sample.surfaceTemperature to computeDewMargin;
    flow sample.relativeHumidity to classifyRisk;
    flow computeDewMargin to classifyRisk;
    flow classifyRisk to assessment.riskLevel;
  }

  action def IssueDewWarning {
    in item assessment : DewAssessment;
    out item command : WarningCommand;

    action selectMessage;
    action enableVisualWarning;
    action enableAudibleWarning;

    flow assessment.riskLevel to selectMessage;
    flow selectMessage to command.messageCode;
  }

  state def DewWarningOperatingStates {
    entry action initializeSelfTest;

    state Off;
    state Initializing;
    state Monitoring;
    state Guarded;
    state WarningActive;
    state CriticalWarning;
    state Faulted;

    transition first Off then Initializing;
    transition Initializing then Monitoring if selfTestPassed;
    transition Initializing then Faulted if selfTestFailed;
    transition Monitoring then Guarded if assessedRisk == DewRiskLevel::guarded;
    transition Monitoring then WarningActive if assessedRisk == DewRiskLevel::warning;
    transition Guarded then Monitoring if assessedRisk == DewRiskLevel::low;
    transition Guarded then WarningActive if assessedRisk == DewRiskLevel::warning;
    transition WarningActive then CriticalWarning if assessedRisk == DewRiskLevel::critical;
    transition WarningActive then Guarded if assessedRisk == DewRiskLevel::guarded;
    transition CriticalWarning then WarningActive if assessedRisk == DewRiskLevel::warning;
    transition Faulted then Initializing if resetRequested;
  }

  part def AirTemperatureSensor {
    port weatherOut : WeatherSensePort;
    port powerIn : PowerPort;

    attribute measurementRangeLow : TemperatureC = -40.0;
    attribute measurementRangeHigh : TemperatureC = 80.0;
    attribute accuracy : TemperatureC = 0.3;
    attribute updatePeriod : TimeSecond = 2.0;
  }

  part def SurfaceTemperatureSensor {
    port weatherOut : WeatherSensePort;
    port powerIn : PowerPort;

    attribute measurementRangeLow : TemperatureC = -40.0;
    attribute measurementRangeHigh : TemperatureC = 100.0;
    attribute accuracy : TemperatureC = 0.5;
    attribute updatePeriod : TimeSecond = 2.0;
  }

  part def HumidityPressureSensor {
    port weatherOut : WeatherSensePort;
    port powerIn : PowerPort;

    attribute humidityAccuracy : RelativeHumidityPercent = 2.0;
    attribute pressureAccuracy : PressureHPa = 1.0;
    attribute updatePeriod : TimeSecond = 5.0;
  }

  part def WindSensor {
    port weatherOut : WeatherSensePort;
    port powerIn : PowerPort;

    attribute speedAccuracy : SpeedMps = 0.2;
    attribute updatePeriod : TimeSecond = 5.0;
  }

  part def DewRiskController {
    port airIn : AssessmentPort;
    port surfaceIn : AssessmentPort;
    port humidityIn : AssessmentPort;
    port windIn : AssessmentPort;
    port warningOut : WarningPort;
    port powerIn : PowerPort;

    attribute warningThresholdMargin : TemperatureC = 1.5;
    attribute criticalThresholdMargin : TemperatureC = 0.3;
    attribute minimumValidHumidity : RelativeHumidityPercent = 70.0;
    attribute controlPeriod : TimeSecond = 2.0;

    perform action assess : AssessDewRisk;
    perform action warn : IssueDewWarning;
    exhibit state operating : DewWarningOperatingStates;
  }

  part def VisualIndicator {
    port commandIn : WarningPort;
    port powerIn : PowerPort;

    attribute lowColor : String = "green";
    attribute guardedColor : String = "amber";
    attribute warningColor : String = "red";
    attribute criticalFlashRate : Real = 2.0;
  }

  part def AudibleAlarm {
    port commandIn : WarningPort;
    port powerIn : PowerPort;

    attribute warningSoundLevel : Real = 65.0;
    attribute criticalSoundLevel : Real = 85.0;
    attribute muteDuration : TimeSecond = 300.0;
  }

  part def OperatorDisplay {
    port commandIn : WarningPort;
    port powerIn : PowerPort;

    attribute refreshPeriod : TimeSecond = 1.0;
    attribute displayedFields : String = "dew margin, dew point, humidity, risk level";
  }

  part def PowerModule {
    port powerOut : PowerPort;

    attribute nominalVoltage : VoltageV = 24.0;
    attribute minimumOperatingVoltage : VoltageV = 18.0;
    attribute maximumOperatingVoltage : VoltageV = 32.0;
  }

  part def DewWarningSystem {
    part powerModule : PowerModule;
    part airTemperatureSensor : AirTemperatureSensor;
    part surfaceTemperatureSensor : SurfaceTemperatureSensor;
    part humidityPressureSensor : HumidityPressureSensor;
    part windSensor : WindSensor;
    part controller : DewRiskController;
    part visualIndicator : VisualIndicator;
    part audibleAlarm : AudibleAlarm;
    part operatorDisplay : OperatorDisplay;

    port powerInput : PowerPort;
    port warningOutput : WarningPort;

    connection powerToAirSensor connect powerModule.powerOut to airTemperatureSensor.powerIn;
    connection powerToSurfaceSensor connect powerModule.powerOut to surfaceTemperatureSensor.powerIn;
    connection powerToHumiditySensor connect powerModule.powerOut to humidityPressureSensor.powerIn;
    connection powerToWindSensor connect powerModule.powerOut to windSensor.powerIn;
    connection powerToController connect powerModule.powerOut to controller.powerIn;
    connection powerToVisual connect powerModule.powerOut to visualIndicator.powerIn;
    connection powerToAudible connect powerModule.powerOut to audibleAlarm.powerIn;
    connection powerToDisplay connect powerModule.powerOut to operatorDisplay.powerIn;

    connection airData connect airTemperatureSensor.weatherOut to controller.airIn;
    connection surfaceData connect surfaceTemperatureSensor.weatherOut to controller.surfaceIn;
    connection humidityData connect humidityPressureSensor.weatherOut to controller.humidityIn;
    connection windData connect windSensor.weatherOut to controller.windIn;

    connection visualWarning connect controller.warningOut to visualIndicator.commandIn;
    connection audibleWarning connect controller.warningOut to audibleAlarm.commandIn;
    connection displayWarning connect controller.warningOut to operatorDisplay.commandIn;
    connection externalWarning connect controller.warningOut to warningOutput;

    perform action primaryFunction : WarnBeforeDewForms;
  }

  action def WarnBeforeDewForms {
    in item environmentalMeasurements : WeatherSample;
    out item warningCommand : WarningCommand;

    action estimateDewPoint : EstimateDewPoint;
    action assessDewRisk : AssessDewRisk;
    action issueWarning : IssueDewWarning;

    flow environmentalMeasurements to assessDewRisk.sample;
    flow assessDewRisk.assessment to issueWarning.assessment;
    flow issueWarning.command to warningCommand;
  }

  requirement def PrimaryFunctionRequirement {
    doc "The system shall monitor local atmospheric and surface conditions, determine the likelihood of dew formation, and warn the operator before condensation occurs on the protected surface.";
  }

  requirement def DewPointAccuracyRequirement {
    attribute maximumDewPointError : TemperatureC = 1.0;
    doc "The system shall estimate dew point temperature with an error no greater than 1.0 degC under valid sensor conditions.";
  }

  requirement def WarningTimingRequirement {
    attribute minimumAdvanceWarning : TimeSecond = 300.0;
    doc "The system shall issue a dew warning at least 300 seconds before predicted condensation when environmental trends permit prediction.";
  }

  requirement def CriticalWarningRequirement {
    attribute criticalMargin : TemperatureC = 0.3;
    doc "The system shall enter critical warning when protected surface temperature is within 0.3 degC of the computed dew point.";
  }

  requirement def AvailabilityRequirement {
    attribute requiredAvailability : Real = 0.99;
    doc "The system shall remain available for dew monitoring with at least 0.99 operational availability during powered service.";
  }

  satisfy PrimaryFunctionRequirement by DewWarningSystem;
  satisfy DewPointAccuracyRequirement by DewRiskController;
  satisfy WarningTimingRequirement by DewRiskController;
  satisfy CriticalWarningRequirement by DewRiskController;
  satisfy AvailabilityRequirement by DewWarningSystem;
}