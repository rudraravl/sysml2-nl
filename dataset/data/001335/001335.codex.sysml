package AirQualityEggSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Concentration {
    value : Real;
    unit : Unit;
  }

  attribute def TemperatureCelsius {
    value : Real;
    unit = "degC";
  }

  attribute def RelativeHumidity {
    value : Real;
    unit = "%";
  }

  attribute def PressureHectoPascal {
    value : Real;
    unit = "hPa";
  }

  attribute def AirQualityIndex {
    value : Integer;
    unit = "AQI";
  }

  attribute def Voltage {
    value : Real;
    unit = "V";
  }

  attribute def Current {
    value : Real;
    unit = "mA";
  }

  attribute def Power {
    value : Real;
    unit = "W";
  }

  attribute def Timestamp {
    value : String;
  }

  item def AmbientAirSample {
    attribute sampledAt : Timestamp;
    attribute particulateMatter25 : Concentration { :>> unit = "ug/m^3"; }
    attribute volatileOrganicCompounds : Concentration { :>> unit = "ppb"; }
    attribute carbonMonoxide : Concentration { :>> unit = "ppm"; }
    attribute carbonDioxide : Concentration { :>> unit = "ppm"; }
    attribute nitrogenDioxide : Concentration { :>> unit = "ppb"; }
    attribute temperature : TemperatureCelsius;
    attribute humidity : RelativeHumidity;
    attribute pressure : PressureHectoPascal;
  }

  item def SensorReading {
    attribute measuredAt : Timestamp;
    attribute value : Real;
    attribute qualityFlag : String;
  }

  item def ProcessedAirQualityRecord {
    attribute recordedAt : Timestamp;
    attribute pm25 : Concentration { :>> unit = "ug/m^3"; }
    attribute voc : Concentration { :>> unit = "ppb"; }
    attribute co : Concentration { :>> unit = "ppm"; }
    attribute co2 : Concentration { :>> unit = "ppm"; }
    attribute no2 : Concentration { :>> unit = "ppb"; }
    attribute temperature : TemperatureCelsius;
    attribute humidity : RelativeHumidity;
    attribute pressure : PressureHectoPascal;
    attribute indoorAirQualityIndex : AirQualityIndex;
    attribute healthCategory : String;
  }

  item def ConfigurationCommand {
    attribute targetSamplingPeriodSeconds : Real;
    attribute cloudUploadEnabled : Boolean;
    attribute localAlertEnabled : Boolean;
    attribute calibrationModeRequested : Boolean;
  }

  item def AirQualityAlert {
    attribute issuedAt : Timestamp;
    attribute severity : String;
    attribute cause : String;
    attribute recommendedAction : String;
  }

  item def ElectricalEnergy {
    attribute supplyVoltage : Voltage;
    attribute loadCurrent : Current;
    attribute availablePower : Power;
  }

  port def AirIntakePort {
    in item ambientAir : AmbientAirSample;
  }

  port def DigitalDataOutPort {
    out item record : ProcessedAirQualityRecord;
    out item alert : AirQualityAlert;
  }

  port def DigitalCommandInPort {
    in item command : ConfigurationCommand;
  }

  port def PowerInputPort {
    in item energy : ElectricalEnergy;
  }

  port def SensorSignalPort {
    out item reading : SensorReading;
  }

  port def SensorControlPort {
    in item command : ConfigurationCommand;
  }

  port def WirelessPort {
    out item transmittedRecord : ProcessedAirQualityRecord;
    out item transmittedAlert : AirQualityAlert;
    in item receivedCommand : ConfigurationCommand;
  }

  port def UserIndicationPort {
    out item userAlert : AirQualityAlert;
    out item latestRecord : ProcessedAirQualityRecord;
  }

  part def ParticulateMatterSensor {
    attribute measurementRangeMin : Concentration { :>> value = 0.0; :>> unit = "ug/m^3"; }
    attribute measurementRangeMax : Concentration { :>> value = 1000.0; :>> unit = "ug/m^3"; }
    attribute accuracy : Concentration { :>> value = 5.0; :>> unit = "ug/m^3"; }
    attribute warmupTimeSeconds : Real = 10.0;

    port airIn : AirIntakePort;
    port signalOut : SensorSignalPort;
    port controlIn : SensorControlPort;
  }

  part def GasSensorArray {
    attribute vocRangeMax : Concentration { :>> value = 5000.0; :>> unit = "ppb"; }
    attribute coRangeMax : Concentration { :>> value = 1000.0; :>> unit = "ppm"; }
    attribute no2RangeMax : Concentration { :>> value = 1000.0; :>> unit = "ppb"; }
    attribute warmupTimeSeconds : Real = 60.0;

    port airIn : AirIntakePort;
    port signalOut : SensorSignalPort;
    port controlIn : SensorControlPort;
  }

  part def EnvironmentalSensor {
    attribute temperatureAccuracy : TemperatureCelsius { :>> value = 0.5; }
    attribute humidityAccuracy : RelativeHumidity { :>> value = 3.0; }
    attribute pressureAccuracy : PressureHectoPascal { :>> value = 1.0; }

    port airIn : AirIntakePort;
    port signalOut : SensorSignalPort;
    port controlIn : SensorControlPort;
  }

  part def MicrocontrollerUnit {
    attribute samplingPeriodSeconds : Real = 60.0;
    attribute storageCapacityRecords : Integer = 1440;
    attribute firmwareVersion : String = "AQE-2.0.0";

    port pmSensorIn : SensorSignalPort;
    port gasSensorIn : SensorSignalPort;
    port envSensorIn : SensorSignalPort;
    port commandIn : DigitalCommandInPort;
    port dataOut : DigitalDataOutPort;
    port sensorControlOut : SensorControlPort;

    action def AcquireSensorData {
      in item rawPm : SensorReading;
      in item rawGas : SensorReading;
      in item rawEnvironment : SensorReading;
      out item airSample : AmbientAirSample;
    }

    action def ValidateAndFilter {
      in item rawSample : AmbientAirSample;
      out item filteredSample : AmbientAirSample;
    }

    action def ComputeAirQuality {
      in item filteredSample : AmbientAirSample;
      out item record : ProcessedAirQualityRecord;
    }

    action def EvaluateAlerts {
      in item record : ProcessedAirQualityRecord;
      out item alert : AirQualityAlert;
    }

    state def ControllerOperatingState {
      entry action InitializeElectronics;
      state Off;
      state Booting;
      state SensorWarmup;
      state Monitoring;
      state Uploading;
      state Alerting;
      state Calibration;
      state Fault;

      transition first Off;
      transition Off_to_Booting
        first Off then Booting
        accept PowerApplied;
      transition Booting_to_Warmup
        first Booting then SensorWarmup
        accept FirmwareReady;
      transition Warmup_to_Monitoring
        first SensorWarmup then Monitoring
        accept SensorsStable;
      transition Monitoring_to_Uploading
        first Monitoring then Uploading
        accept UploadPeriodElapsed;
      transition Uploading_to_Monitoring
        first Uploading then Monitoring
        accept UploadComplete;
      transition Monitoring_to_Alerting
        first Monitoring then Alerting
        accept ThresholdExceeded;
      transition Alerting_to_Monitoring
        first Alerting then Monitoring
        accept AirQualityNormal;
      transition Monitoring_to_Calibration
        first Monitoring then Calibration
        accept CalibrationCommanded;
      transition Calibration_to_Monitoring
        first Calibration then Monitoring
        accept CalibrationComplete;
      transition Monitoring_to_Fault
        first Monitoring then Fault
        accept SensorFaultDetected;
    }
  }

  part def WirelessCommunicationModule {
    attribute supportedProtocol : String = "WiFi 802.11n";
    attribute encryptionMode : String = "TLS 1.3";
    attribute retryLimit : Integer = 5;

    port dataIn : DigitalDataOutPort;
    port wireless : WirelessPort;
  }

  part def LocalUserInterface {
    attribute displayType : String = "RGB status LED plus compact numeric display";
    attribute audibleAlarmEnabled : Boolean = true;

    port indicationIn : UserIndicationPort;
  }

  part def PowerSubsystem {
    attribute nominalInputVoltage : Voltage { :>> value = 5.0; }
    attribute maximumCurrent : Current { :>> value = 1000.0; }
    attribute maximumPower : Power { :>> value = 5.0; }

    port externalPowerIn : PowerInputPort;
    port regulatedPowerOut : PowerInputPort;
  }

  part def CloudAirQualityService {
    attribute retentionDays : Integer = 365;
    attribute aggregationIntervalMinutes : Real = 15.0;

    port wirelessEndpoint : WirelessPort;
  }

  part def AirQualityEgg {
    doc /* The Air Quality Egg continuously samples surrounding indoor air, measures pollutant and environmental conditions, computes a local air quality index, alerts occupants when thresholds are exceeded, and publishes time-stamped air quality records for trend monitoring. */

    attribute deviceIdentifier : String = "AQE-HOME-001";
    attribute operatingTemperatureMin : TemperatureCelsius { :>> value = 0.0; }
    attribute operatingTemperatureMax : TemperatureCelsius { :>> value = 50.0; }
    attribute nominalSamplingPeriodSeconds : Real = 60.0;
    attribute pm25AlertThreshold : Concentration { :>> value = 35.0; :>> unit = "ug/m^3"; }
    attribute co2AlertThreshold : Concentration { :>> value = 1000.0; :>> unit = "ppm"; }
    attribute vocAlertThreshold : Concentration { :>> value = 500.0; :>> unit = "ppb"; }

    port airIn : AirIntakePort;
    port powerIn : PowerInputPort;
    port wireless : WirelessPort;
    port userIndication : UserIndicationPort;
    port configuration : DigitalCommandInPort;

    part pmSensor : ParticulateMatterSensor;
    part gasArray : GasSensorArray;
    part envSensor : EnvironmentalSensor;
    part controller : MicrocontrollerUnit;
    part radio : WirelessCommunicationModule;
    part ui : LocalUserInterface;
    part power : PowerSubsystem;

    connect airIn to pmSensor.airIn;
    connect airIn to gasArray.airIn;
    connect airIn to envSensor.airIn;

    connect powerIn to power.externalPowerIn;
    connect power.regulatedPowerOut to controller.commandIn;

    connect pmSensor.signalOut to controller.pmSensorIn;
    connect gasArray.signalOut to controller.gasSensorIn;
    connect envSensor.signalOut to controller.envSensorIn;

    connect controller.sensorControlOut to pmSensor.controlIn;
    connect controller.sensorControlOut to gasArray.controlIn;
    connect controller.sensorControlOut to envSensor.controlIn;

    connect configuration to controller.commandIn;
    connect controller.dataOut to radio.dataIn;
    connect radio.wireless to wireless;
    connect controller.dataOut to userIndication;
    connect userIndication to ui.indicationIn;
  }

  part def AirQualityEggDeployment {
    part egg : AirQualityEgg;
    part cloud : CloudAirQualityService;

    connect egg.wireless to cloud.wirelessEndpoint;
  }

  action def HighLevelAirQualityMonitoringFunction {
    in item ambientAir : AmbientAirSample;
    in item configuration : ConfigurationCommand;
    out item displayedRecord : ProcessedAirQualityRecord;
    out item publishedRecord : ProcessedAirQualityRecord;
    out item occupantAlert : AirQualityAlert;

    action sampleAir;
    action sensePollutants;
    action senseEnvironment;
    action filterMeasurements;
    action computeIndex;
    action compareThresholds;
    action displayStatus;
    action publishToCloud;

    flow sampleAir then sensePollutants;
    flow sampleAir then senseEnvironment;
    flow sensePollutants then filterMeasurements;
    flow senseEnvironment then filterMeasurements;
    flow filterMeasurements then computeIndex;
    flow computeIndex then compareThresholds;
    flow computeIndex then displayStatus;
    flow computeIndex then publishToCloud;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall provide continuous high-level indoor air quality monitoring by sampling ambient air, measuring particulate matter, gaseous pollutants, temperature, humidity, and pressure, computing a time-stamped air quality record, indicating local status, issuing alerts for unhealthy conditions, and publishing records to a remote service. */
  }

  requirement def SamplingRequirement {
    doc /* The Air Quality Egg shall acquire a complete air quality sample at least once every 60 seconds during normal monitoring operation. */
    attribute maximumSamplingIntervalSeconds : Real = 60.0;
  }

  requirement def MeasurementRequirement {
    doc /* The Air Quality Egg shall measure PM2.5, VOC, CO, CO2, NO2, temperature, relative humidity, and barometric pressure from the surrounding ambient air. */
  }

  requirement def AlertRequirement {
    doc /* The Air Quality Egg shall issue a local alert when PM2.5 exceeds 35 ug/m^3, CO2 exceeds 1000 ppm, or VOC exceeds 500 ppb for two consecutive samples. */
  }

  requirement def PublishingRequirement {
    doc /* The Air Quality Egg shall publish processed air quality records to a remote cloud service when network connectivity is available and shall retain records locally when connectivity is unavailable. */
  }

  requirement def CalibrationRequirement {
    doc /* The Air Quality Egg shall support commanded calibration of pollutant sensors and shall return to monitoring after calibration completes successfully. */
  }

  requirement def PowerRequirement {
    doc /* The Air Quality Egg shall operate from a 5 V external power supply with total steady-state power consumption not exceeding 5 W. */
  }

  satisfy PrimaryFunctionRequirement by AirQualityEgg;
  satisfy SamplingRequirement by MicrocontrollerUnit;
  satisfy MeasurementRequirement by ParticulateMatterSensor;
  satisfy MeasurementRequirement by GasSensorArray;
  satisfy MeasurementRequirement by EnvironmentalSensor;
  satisfy AlertRequirement by MicrocontrollerUnit;
  satisfy PublishingRequirement by WirelessCommunicationModule;
  satisfy CalibrationRequirement by MicrocontrollerUnit;
  satisfy PowerRequirement by PowerSubsystem;

  concern def OccupantHealthConcern {
    doc /* Occupants need timely awareness of indoor pollutant levels that may affect comfort or health. */
  }

  concern def LongTermTrendConcern {
    doc /* Building owners need historical air quality records to identify recurring ventilation and pollution patterns. */
  }

  view def PrimaryFunctionView {
    expose AirQualityEgg;
    expose HighLevelAirQualityMonitoringFunction;
    expose PrimaryFunctionRequirement;
    expose MeasurementRequirement;
    expose AlertRequirement;
    expose PublishingRequirement;
  }

  viewpoint def AirQualityMonitoringViewpoint {
    frame concern OccupantHealthConcern;
    frame concern LongTermTrendConcern;
    require PrimaryFunctionView;
  }
}