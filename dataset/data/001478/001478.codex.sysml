package InternetOfThingsMonitoringSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def TemperatureCelsius :> real {
    unit = "degC";
  }

  attribute def RelativeHumidity :> real {
    unit = "%";
  }

  attribute def PressureKPa :> real {
    unit = "kPa";
  }

  attribute def Voltage :> real {
    unit = "V";
  }

  attribute def EnergyWh :> real {
    unit = "Wh";
  }

  attribute def DataRateKbps :> real {
    unit = "kbps";
  }

  attribute def LatencyMs :> real {
    unit = "ms";
  }

  attribute def DistanceM :> real {
    unit = "m";
  }

  enum def DeviceMode {
    enum idle;
    enum sampling;
    enum transmitting;
    enum updating;
    enum faulted;
  }

  enum def AlertSeverity {
    enum information;
    enum warning;
    enum critical;
  }

  item def SensorReading {
    attribute sensorId : String;
    attribute measuredAtEpochSeconds : Integer;
    attribute temperature : TemperatureCelsius;
    attribute humidity : RelativeHumidity;
    attribute pressure : PressureKPa;
    attribute batteryVoltage : Voltage;
  }

  item def TelemetryPacket {
    attribute deviceId : String;
    attribute gatewayId : String;
    attribute sequenceNumber : Integer;
    attribute payloadBytes : Integer;
    attribute encrypted : Boolean;
    item reading : SensorReading;
  }

  item def DeviceCommand {
    attribute commandId : String;
    attribute targetDeviceId : String;
    attribute samplingIntervalSeconds : Integer;
    attribute reportingIntervalSeconds : Integer;
    attribute requestFirmwareUpdate : Boolean;
  }

  item def AlertMessage {
    attribute alertId : String;
    attribute sourceDeviceId : String;
    attribute severity : AlertSeverity;
    attribute text : String;
    attribute issuedAtEpochSeconds : Integer;
  }

  port def SensorDataPort {
    out item reading : SensorReading;
  }

  port def WirelessDevicePort {
    out item telemetry : TelemetryPacket;
    in item command : DeviceCommand;
  }

  port def GatewayFieldPort {
    in item telemetry : TelemetryPacket;
    out item command : DeviceCommand;
  }

  port def CloudIngestionPort {
    in item telemetry : TelemetryPacket;
  }

  port def CloudCommandPort {
    out item command : DeviceCommand;
  }

  port def AlertPort {
    out item alert : AlertMessage;
  }

  part def EnvironmentalSensor {
    attribute sensorId : String;
    attribute accuracyTemperature : TemperatureCelsius = 0.3;
    attribute accuracyHumidity : RelativeHumidity = 2.0;
    attribute samplePeriodSeconds : Integer = 60;

    port dataOut : SensorDataPort;

    action senseEnvironment {
      out item reading : SensorReading;
    }
  }

  part def BatteryPowerModule {
    attribute nominalVoltage : Voltage = 3.7;
    attribute remainingEnergy : EnergyWh;
    attribute lowVoltageThreshold : Voltage = 3.3;

    action supplyPower {
      out attribute outputVoltage : Voltage;
    }

    action estimateRemainingEnergy {
      out attribute energy : EnergyWh;
    }
  }

  part def EdgeProcessor {
    attribute processorId : String;
    attribute currentMode : DeviceMode;

    port sensorInput : SensorDataPort;
    port radioPort : WirelessDevicePort;

    action validateReading {
      in item reading : SensorReading;
      out attribute valid : Boolean;
    }

    action encryptTelemetry {
      in item reading : SensorReading;
      out item telemetry : TelemetryPacket;
    }

    action applyCommand {
      in item command : DeviceCommand;
      out attribute accepted : Boolean;
    }

    state operationalBehavior {
      state idle;
      state sampling;
      state transmitting;
      state updating;
      state faulted;

      transition first idle;
      transition idle to sampling;
      transition sampling to transmitting;
      transition transmitting to idle;
      transition idle to updating;
      transition updating to idle;
      transition idle to faulted;
      transition sampling to faulted;
      transition transmitting to faulted;
      transition faulted to idle;
    }
  }

  part def IoTDeviceNode {
    attribute deviceId : String;
    attribute installationLocation : String;
    attribute maximumGatewayDistance : DistanceM = 500.0;

    part sensor : EnvironmentalSensor;
    part battery : BatteryPowerModule;
    part processor : EdgeProcessor;

    port wireless : WirelessDevicePort;

    connection sensorToProcessor connect sensor.dataOut to processor.sensorInput;
    connection processorToWireless connect processor.radioPort to wireless;
  }

  part def IoTGateway {
    attribute gatewayId : String;
    attribute maxConnectedDevices : Integer = 250;
    attribute fieldNetworkRate : DataRateKbps = 250.0;
    attribute backhaulRate : DataRateKbps = 10000.0;

    port fieldNetwork : GatewayFieldPort;
    port cloudIngest : CloudIngestionPort;
    port commandDownlink : CloudCommandPort;

    action aggregateTelemetry {
      in item telemetry : TelemetryPacket;
      out item forwardedTelemetry : TelemetryPacket;
    }

    action routeCommand {
      in item command : DeviceCommand;
      out item routedCommand : DeviceCommand;
    }
  }

  part def CloudIoTPlatform {
    attribute platformId : String;
    attribute ingestionLatencyLimit : LatencyMs = 2000.0;
    attribute retentionDays : Integer = 365;

    port telemetryIn : CloudIngestionPort;
    port commandOut : CloudCommandPort;
    port alertOut : AlertPort;

    action ingestTelemetry {
      in item telemetry : TelemetryPacket;
    }

    action analyzeTelemetry {
      in item telemetry : TelemetryPacket;
      out item alert : AlertMessage;
    }

    action issueDeviceCommand {
      out item command : DeviceCommand;
    }
  }

  part def OperationsDashboard {
    attribute dashboardId : String;
    attribute refreshPeriodSeconds : Integer = 5;

    port alertsIn : AlertPort;

    action displayAlert {
      in item alert : AlertMessage;
    }

    action displayEnvironmentalTrend {
      in item telemetry : TelemetryPacket;
    }
  }

  part def IoTEnvironmentalMonitoringSystem {
    attribute systemName : String = "Distributed IoT Environmental Monitoring System";

    part nodeA : IoTDeviceNode {
      attribute deviceId = "NODE-A";
      attribute installationLocation = "Warehouse Zone A";
    }

    part nodeB : IoTDeviceNode {
      attribute deviceId = "NODE-B";
      attribute installationLocation = "Warehouse Zone B";
    }

    part gateway : IoTGateway {
      attribute gatewayId = "GATEWAY-01";
    }

    part cloud : CloudIoTPlatform {
      attribute platformId = "CLOUD-IOT-01";
    }

    part dashboard : OperationsDashboard {
      attribute dashboardId = "OPS-DASHBOARD-01";
    }

    connection nodeAToGateway connect nodeA.wireless to gateway.fieldNetwork;
    connection nodeBToGateway connect nodeB.wireless to gateway.fieldNetwork;
    connection gatewayToCloud connect gateway.cloudIngest to cloud.telemetryIn;
    connection cloudCommandsToGateway connect cloud.commandOut to gateway.commandDownlink;
    connection cloudAlertsToDashboard connect cloud.alertOut to dashboard.alertsIn;

    action primaryFunction {
      objective {
        "Collect environmental measurements from distributed IoT device nodes, securely transmit telemetry through a gateway to a cloud platform, analyze conditions, and notify operators when monitored values exceed configured limits."
      }

      first start;
      then collectReadings;
      then transmitTelemetry;
      then analyzeReadings;
      then notifyOperators;
      then end;

      action collectReadings;
      action transmitTelemetry;
      action analyzeReadings;
      action notifyOperators;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : IoTEnvironmentalMonitoringSystem;
    require constraint {
      system.systemName == "Distributed IoT Environmental Monitoring System"
    }
    doc /* The system shall monitor distributed physical environments using IoT sensor nodes and provide centralized telemetry, analysis, and alerting. */
  }

  requirement def SamplingRequirement {
    subject node : IoTDeviceNode;
    require constraint {
      node.sensor.samplePeriodSeconds <= 60
    }
    doc /* Each IoT device node shall sample temperature, humidity, pressure, and battery voltage at least once per minute. */
  }

  requirement def SecureTelemetryRequirement {
    subject packet : TelemetryPacket;
    require constraint {
      packet.encrypted == true
    }
    doc /* All telemetry sent from an IoT device node to the gateway and cloud platform shall be encrypted. */
  }

  requirement def IngestionLatencyRequirement {
    subject cloud : CloudIoTPlatform;
    require constraint {
      cloud.ingestionLatencyLimit <= 2000.0
    }
    doc /* The cloud platform shall ingest telemetry within two seconds of receipt from the IoT gateway. */
  }

  requirement def GatewayCapacityRequirement {
    subject gateway : IoTGateway;
    require constraint {
      gateway.maxConnectedDevices >= 250
    }
    doc /* The IoT gateway shall support at least 250 connected field devices. */
  }

  requirement def BatteryVoltageRequirement {
    subject battery : BatteryPowerModule;
    require constraint {
      battery.lowVoltageThreshold >= 3.3
    }
    doc /* The device node shall identify low-battery conditions before voltage falls below reliable operating limits. */
  }

  satisfy PrimaryFunctionRequirement by IoTEnvironmentalMonitoringSystem;
  satisfy SamplingRequirement by IoTDeviceNode;
  satisfy SecureTelemetryRequirement by TelemetryPacket;
  satisfy IngestionLatencyRequirement by CloudIoTPlatform;
  satisfy GatewayCapacityRequirement by IoTGateway;
  satisfy BatteryVoltageRequirement by BatteryPowerModule;
}