package SnowGaugeSystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def SnowDepth :> ISQ::length {
    unit = SI::metre;
  }

  attribute def LiquidEquivalentDepth :> ISQ::length {
    unit = SI::millimetre;
  }

  attribute def SnowfallRate :> ISQ::speed {
    unit = SI::millimetre / SI::hour;
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    unit = SI::degreeCelsius;
  }

  attribute def BatteryCharge :> ISQ::electricCharge {
    unit = SI::ampere * SI::hour;
  }

  attribute def ElectricPower :> ISQ::power {
    unit = SI::watt;
  }

  attribute def Voltage :> ISQ::electricPotential {
    unit = SI::volt;
  }

  attribute def TimeInterval :> ISQ::time {
    unit = SI::second;
  }

  attribute def Percent {
    :>> scalarValues = Real;
    unit = "%";
  }

  item def SnowSample {
    attribute depth : SnowDepth;
    attribute liquidEquivalent : LiquidEquivalentDepth;
    attribute densityRatio : Real;
    attribute collectionTime : TimeInterval;
  }

  item def DepthMeasurement {
    attribute measuredDepth : SnowDepth;
    attribute confidence : Percent;
    attribute sampleAge : TimeInterval;
  }

  item def WeatherPacket {
    attribute snowDepth : SnowDepth;
    attribute snowfallRate : SnowfallRate;
    attribute ambientTemperature : Temperature;
    attribute batteryStateOfCharge : Percent;
    attribute sensorHealth : Percent;
  }

  item def PowerEnergy {
    attribute supplyVoltage : Voltage;
    attribute availablePower : ElectricPower;
    attribute chargeRemaining : BatteryCharge;
  }

  port def SnowInletPort {
    in item incomingSnow : SnowSample;
  }

  port def MeasurementPort {
    out item depthReading : DepthMeasurement;
  }

  port def WeatherDataPort {
    out item telemetry : WeatherPacket;
  }

  port def PowerPort {
    in item power : PowerEnergy;
  }

  port def MaintenancePort {
    in item serviceCommand : String;
    out item serviceStatus : String;
  }

  part def SnowGaugeSystem {
    attribute currentSnowDepth : SnowDepth;
    attribute currentSnowfallRate : SnowfallRate;
    attribute ambientTemperature : Temperature;
    attribute measurementInterval : TimeInterval = 300 [SI::second];
    attribute batteryStateOfCharge : Percent;
    attribute operationalAvailability : Percent;

    port snowInlet : SnowInletPort;
    port weatherDataOut : WeatherDataPort;
    port externalPowerIn : PowerPort;
    port maintenance : MaintenancePort;

    part collector : SnowCollector;
    part depthSensor : UltrasonicDepthSensor;
    part temperatureSensor : AmbientTemperatureSensor;
    part controller : GaugeController;
    part dataLogger : DataLogger;
    part communications : WirelessTelemetryUnit;
    part powerSubsystem : PowerSubsystem;
    part enclosure : WeatherproofEnclosure;
    part heater : InletAntiIceHeater;

    connect snowInlet to collector.snowInlet;
    connect collector.sampleOut to depthSensor.sampleIn;
    connect depthSensor.measurementOut to controller.depthInput;
    connect temperatureSensor.temperatureOut to controller.temperatureInput;
    connect controller.telemetryOut to dataLogger.dataIn;
    connect dataLogger.loggedDataOut to communications.telemetryIn;
    connect communications.weatherDataOut to weatherDataOut;
    connect externalPowerIn to powerSubsystem.externalPowerIn;
    connect powerSubsystem.controlPowerOut to controller.powerIn;
    connect powerSubsystem.sensorPowerOut to depthSensor.powerIn;
    connect powerSubsystem.sensorPowerOut to temperatureSensor.powerIn;
    connect powerSubsystem.commsPowerOut to communications.powerIn;
    connect powerSubsystem.heaterPowerOut to heater.powerIn;
    connect controller.heaterCommandOut to heater.commandIn;
    connect maintenance to controller.maintenance;

    perform action measureAndReport : MeasureSnowDepth;
    exhibit state operationalState : SnowGaugeOperationalStates;
  }

  part def SnowCollector {
    attribute catchArea : ISQ::area = 0.05 [SI::squareMetre];
    attribute rimHeight : SnowDepth = 0.25 [SI::metre];
    attribute collectionEfficiency : Percent = 95 [%];

    port snowInlet : SnowInletPort;
    port sampleOut {
      out item collectedSample : SnowSample;
    }
  }

  part def UltrasonicDepthSensor {
    attribute minimumRange : SnowDepth = 0.03 [SI::metre];
    attribute maximumRange : SnowDepth = 2.50 [SI::metre];
    attribute depthAccuracy : SnowDepth = 0.005 [SI::metre];
    attribute measurementConfidence : Percent;

    port sampleIn {
      in item snowSample : SnowSample;
    }

    port measurementOut : MeasurementPort;
    port powerIn : PowerPort;
  }

  part def AmbientTemperatureSensor {
    attribute temperatureAccuracy : Temperature = 0.5 [SI::degreeCelsius];
    attribute measuredTemperature : Temperature;

    port temperatureOut {
      out item temperatureReading {
        attribute value : Temperature;
      }
    }

    port powerIn : PowerPort;
  }

  part def GaugeController {
    attribute lastDepth : SnowDepth;
    attribute calculatedRate : SnowfallRate;
    attribute healthScore : Percent;
    attribute lowBatteryThreshold : Percent = 20 [%];
    attribute heaterEnableTemperature : Temperature = 1 [SI::degreeCelsius];

    port depthInput : MeasurementPort;
    port temperatureInput {
      in item temperatureReading {
        attribute value : Temperature;
      }
    }

    port telemetryOut {
      out item packet : WeatherPacket;
    }

    port heaterCommandOut {
      out item heaterCommand : Boolean;
    }

    port powerIn : PowerPort;
    port maintenance : MaintenancePort;

    perform action computeSnowfallRate : ComputeSnowfallRate;
    perform action validateMeasurement : ValidateDepthMeasurement;
    perform action assembleTelemetry : AssembleWeatherPacket;
  }

  part def DataLogger {
    attribute storageCapacity : Integer = 100000;
    attribute retainedDays : Integer = 365;
    attribute recordsStored : Integer;

    port dataIn {
      in item packet : WeatherPacket;
    }

    port loggedDataOut {
      out item packet : WeatherPacket;
    }

    perform action storeTelemetry : StoreTelemetryRecord;
  }

  part def WirelessTelemetryUnit {
    attribute transmitInterval : TimeInterval = 900 [SI::second];
    attribute signalStrength : Percent;
    attribute retryLimit : Integer = 3;

    port telemetryIn {
      in item packet : WeatherPacket;
    }

    port weatherDataOut : WeatherDataPort;
    port powerIn : PowerPort;

    perform action transmitTelemetry : TransmitWeatherPacket;
  }

  part def PowerSubsystem {
    attribute nominalVoltage : Voltage = 12 [SI::volt];
    attribute batteryCapacity : BatteryCharge = 40 [SI::ampere * SI::hour];
    attribute stateOfCharge : Percent;
    attribute solarInputPower : ElectricPower;
    attribute loadPower : ElectricPower;

    port externalPowerIn : PowerPort;

    port controlPowerOut : PowerPort;
    port sensorPowerOut : PowerPort;
    port commsPowerOut : PowerPort;
    port heaterPowerOut : PowerPort;

    perform action managePower : ManageGaugePower;
  }

  part def WeatherproofEnclosure {
    attribute ingressProtectionRating : String = "IP66";
    attribute operatingTemperatureMinimum : Temperature = -40 [SI::degreeCelsius];
    attribute operatingTemperatureMaximum : Temperature = 50 [SI::degreeCelsius];
    attribute windSurvivalSpeed {
      :>> scalarValues = Real;
      unit = SI::metre / SI::second;
    } = 45 [SI::metre / SI::second];
  }

  part def InletAntiIceHeater {
    attribute heaterPower : ElectricPower = 8 [SI::watt];
    attribute enabled : Boolean;

    port powerIn : PowerPort;

    port commandIn {
      in item heaterCommand : Boolean;
    }
  }

  action def MeasureSnowDepth {
    in item snow : SnowSample;
    in item power : PowerEnergy;
    out item telemetry : WeatherPacket;

    first start;
    then collectSnowSample;
    then measureDistanceToSnowSurface;
    then compensateForTemperature;
    then computeDepthAndRate;
    then validateAndPackageData;
    then publishTelemetry;
    then done;

    action collectSnowSample;
    action measureDistanceToSnowSurface;
    action compensateForTemperature;
    action computeDepthAndRate;
    action validateAndPackageData;
    action publishTelemetry;
  }

  action def ComputeSnowfallRate {
    in attribute previousDepth : SnowDepth;
    in attribute currentDepth : SnowDepth;
    in attribute elapsedTime : TimeInterval;
    out attribute rate : SnowfallRate;
  }

  action def ValidateDepthMeasurement {
    in item rawMeasurement : DepthMeasurement;
    out item validatedMeasurement : DepthMeasurement;
    out attribute valid : Boolean;
  }

  action def AssembleWeatherPacket {
    in item measurement : DepthMeasurement;
    in attribute rate : SnowfallRate;
    in attribute temperature : Temperature;
    in attribute batterySoc : Percent;
    in attribute health : Percent;
    out item packet : WeatherPacket;
  }

  action def StoreTelemetryRecord {
    in item packet : WeatherPacket;
    out attribute stored : Boolean;
  }

  action def TransmitWeatherPacket {
    in item packet : WeatherPacket;
    out attribute acknowledged : Boolean;
  }

  action def ManageGaugePower {
    in item sourcePower : PowerEnergy;
    out item distributedPower : PowerEnergy;
    out attribute lowPowerMode : Boolean;
  }

  state def SnowGaugeOperationalStates {
    entry action initializeGauge;

    state initializing;
    state standby;
    state measuring;
    state processing;
    state transmitting;
    state lowPower;
    state fault;
    state maintenanceMode;

    transition first initializing;
    transition initializing then standby
      accept after 30 [SI::second];

    transition standby then measuring
      accept after 300 [SI::second];

    transition measuring then processing
      accept when measurementComplete;

    transition processing then transmitting
      accept when telemetryPacketReady;

    transition transmitting then standby
      accept when transmissionComplete;

    transition standby then lowPower
      accept when batteryBelowThreshold;

    transition lowPower then standby
      accept when batteryRecovered;

    transition measuring then fault
      accept when sensorFailureDetected;

    transition processing then fault
      accept when invalidMeasurementRepeated;

    transition fault then maintenanceMode
      accept when serviceCommandReceived;

    transition maintenanceMode then initializing
      accept when serviceComplete;

    state fault {
      entry action recordFault;
      do action disableHeater;
      exit action clearRecoverableFaults;
    }

    state lowPower {
      entry action reduceSamplingRate;
      do action disableTelemetryExceptAlarm;
      exit action restoreSamplingRate;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The snow gauge system shall determine accumulated snow depth at a fixed outdoor location and report validated snow depth, snowfall rate, ambient temperature, battery state, and health status to an external weather monitoring system. */
  }

  requirement def DepthMeasurementRangeRequirement {
    doc /* The snow gauge shall measure snow depth from 0.03 m to 2.50 m above the collector reference surface. */
    require constraint {
      SnowGaugeSystem::depthSensor::minimumRange <= 0.03 [SI::metre] and
      SnowGaugeSystem::depthSensor::maximumRange >= 2.50 [SI::metre]
    }
  }

  requirement def DepthAccuracyRequirement {
    doc /* The snow gauge shall report snow depth with an error no greater than 0.005 m under normal operating conditions. */
    require constraint {
      SnowGaugeSystem::depthSensor::depthAccuracy <= 0.005 [SI::metre]
    }
  }

  requirement def ReportingRequirement {
    doc /* The snow gauge shall publish a weather packet at least every 900 seconds during normal operation. */
    require constraint {
      SnowGaugeSystem::communications::transmitInterval <= 900 [SI::second]
    }
  }

  requirement def LowTemperatureOperationRequirement {
    doc /* The snow gauge shall operate in ambient temperatures from -40 degC to 50 degC. */
    require constraint {
      SnowGaugeSystem::enclosure::operatingTemperatureMinimum <= -40 [SI::degreeCelsius] and
      SnowGaugeSystem::enclosure::operatingTemperatureMaximum >= 50 [SI::degreeCelsius]
    }
  }

  requirement def PowerAutonomyRequirement {
    doc /* The snow gauge shall continue measuring and logging snow depth while operating from battery power and shall enter low-power mode when state of charge is below 20 percent. */
    require constraint {
      SnowGaugeSystem::powerSubsystem::batteryCapacity >= 40 [SI::ampere * SI::hour] and
      SnowGaugeSystem::controller::lowBatteryThreshold == 20 [%]
    }
  }

  requirement def DataRetentionRequirement {
    doc /* The snow gauge shall retain at least 365 days of local telemetry records. */
    require constraint {
      SnowGaugeSystem::dataLogger::retainedDays >= 365
    }
  }

  requirement def AntiIceRequirement {
    doc /* The snow gauge shall heat the inlet when ambient temperature is near freezing to reduce ice blockage. */
    require constraint {
      SnowGaugeSystem::heater::heaterPower >= 8 [SI::watt] and
      SnowGaugeSystem::controller::heaterEnableTemperature <= 1 [SI::degreeCelsius]
    }
  }

  satisfy PrimaryFunctionRequirement by SnowGaugeSystem;
  satisfy DepthMeasurementRangeRequirement by SnowGaugeSystem::depthSensor;
  satisfy DepthAccuracyRequirement by SnowGaugeSystem::depthSensor;
  satisfy ReportingRequirement by SnowGaugeSystem::communications;
  satisfy LowTemperatureOperationRequirement by SnowGaugeSystem::enclosure;
  satisfy PowerAutonomyRequirement by SnowGaugeSystem::powerSubsystem;
  satisfy DataRetentionRequirement by SnowGaugeSystem::dataLogger;
  satisfy AntiIceRequirement by SnowGaugeSystem::heater;

}