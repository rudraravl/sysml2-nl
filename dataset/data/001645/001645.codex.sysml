package ConnectedDevicesSystemModel {

  import ScalarValues::*;
  import SI::*;

  item def DeviceStatus {
    attribute deviceId : String;
    attribute online : Boolean;
    attribute batteryPercent : Real;
    attribute firmwareVersion : String;
    attribute lastSeenAge_s : Real;
  }

  item def SensorReading {
    attribute sourceId : String;
    attribute timestamp_s : Real;
    attribute temperature_C : Real;
    attribute humidity_percent : Real;
    attribute motionDetected : Boolean;
    attribute airQualityIndex : Real;
  }

  item def ControlCommand {
    attribute targetId : String;
    attribute commandName : String;
    attribute commandValue : String;
    attribute issuedAt_s : Real;
    attribute priority : Integer;
  }

  item def AlertMessage {
    attribute alertId : String;
    attribute severity : String;
    attribute sourceId : String;
    attribute message : String;
    attribute createdAt_s : Real;
  }

  item def EncryptedPacket {
    attribute packetId : String;
    attribute payloadBytes : Integer;
    attribute encryptionAlgorithm : String;
    attribute integrityVerified : Boolean;
  }

  value type TemperatureCelsius specializes Real {
    unit = "degC";
  }

  value type RelativeHumidityPercent specializes Real {
    unit = "%";
  }

  value type BatteryPercent specializes Real {
    unit = "%";
  }

  value type DataRateMbps specializes Real {
    unit = "Mbit/s";
  }

  value type LatencyMs specializes Real {
    unit = "ms";
  }

  value type PowerW specializes Real {
    unit = "W";
  }

  port def WirelessDataPort {
    in item incomingPacket : EncryptedPacket;
    out item outgoingPacket : EncryptedPacket;
  }

  port def SensorDataPort {
    out item reading : SensorReading;
    out item status : DeviceStatus;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def AlertPort {
    out item alert : AlertMessage;
  }

  part def ConnectedDevice {
    attribute deviceId : String;
    attribute nominalPower_W : PowerW;
    attribute batteryCapacity_percent : BatteryPercent;
    attribute minimumOperatingBattery_percent : BatteryPercent = 10.0;
    attribute wirelessThroughput_Mbps : DataRateMbps;
    attribute maximumCommandLatency_ms : LatencyMs = 500.0;

    port sensorOut : SensorDataPort;
    port commandIn : CommandPort;
    port network : WirelessDataPort;
    port alertOut : AlertPort;

    state deviceLifecycle {
      entry; then initializing;

      state initializing;
      state operational;
      state degraded;
      state offline;
      state updatingFirmware;

      transition initializing_to_operational
        first initializing
        then operational
        if batteryCapacity_percent >= minimumOperatingBattery_percent;

      transition initializing_to_degraded
        first initializing
        then degraded
        if batteryCapacity_percent < minimumOperatingBattery_percent;

      transition operational_to_degraded
        first operational
        then degraded
        if batteryCapacity_percent < minimumOperatingBattery_percent;

      transition degraded_to_operational
        first degraded
        then operational
        if batteryCapacity_percent >= 25.0;

      transition operational_to_updating
        first operational
        then updatingFirmware
        accept ControlCommand
        if commandIn::command.commandName == "InstallFirmware";

      transition updating_to_operational
        first updatingFirmware
        then operational;

      transition any_to_offline
        first operational
        then offline
        if batteryCapacity_percent <= 0.0;
    }

    action collectAndPublishTelemetry {
      out item reading : SensorReading;
      out item status : DeviceStatus;

      first start;
      then sampleSensors;
      then validateReading;
      then encryptPayload;
      then publishToNetwork;
      then done;
    }

    action executeCommand {
      in item command : ControlCommand;
      out item resultStatus : DeviceStatus;

      first receive;
      then authenticate;
      then applyCommand;
      then reportStatus;
      then done;
    }
  }

  part def EnvironmentalSensorDevice specializes ConnectedDevice {
    attribute temperatureAccuracy_C : TemperatureCelsius = 0.5;
    attribute humidityAccuracy_percent : RelativeHumidityPercent = 3.0;
    attribute samplingPeriod_s : Real = 30.0;
  }

  part def SmartActuatorDevice specializes ConnectedDevice {
    attribute actuatorPosition_percent : Real;
    attribute maximumLoad_W : PowerW = 1200.0;
    attribute failSafePosition_percent : Real = 0.0;
  }

  part def EdgeGateway {
    attribute gatewayId : String;
    attribute maxSupportedDevices : Integer = 64;
    attribute localStorage_GB : Real = 32.0;
    attribute uplinkThroughput_Mbps : DataRateMbps = 100.0;
    attribute maximumCloudLatency_ms : LatencyMs = 1000.0;

    port deviceNetwork : WirelessDataPort;
    port cloudNetwork : WirelessDataPort;
    port alertOut : AlertPort;

    part firewall {
      attribute packetInspectionEnabled : Boolean = true;
      attribute blockedPacketCount : Integer;
    }

    part messageBroker {
      attribute retainedTopicCount : Integer;
      attribute queuedMessageCount : Integer;
      attribute maxQueueDepth : Integer = 10000;
    }

    action routeDeviceData {
      in item devicePacket : EncryptedPacket;
      out item cloudPacket : EncryptedPacket;

      first receiveFromDevice;
      then verifyIntegrity;
      then classifyPayload;
      then applySecurityPolicy;
      then forwardToCloud;
      then done;
    }

    action dispatchCloudCommand {
      in item cloudPacket : EncryptedPacket;
      out item devicePacket : EncryptedPacket;

      first receiveFromCloud;
      then validateCommand;
      then resolveTargetDevice;
      then forwardToDevice;
      then done;
    }

    state connectivity {
      entry; then booting;

      state booting;
      state connectedToCloud;
      state localOnly;
      state maintenance;

      transition boot_to_connected
        first booting
        then connectedToCloud;

      transition connected_to_localOnly
        first connectedToCloud
        then localOnly
        if maximumCloudLatency_ms > 1000.0;

      transition localOnly_to_connected
        first localOnly
        then connectedToCloud
        if maximumCloudLatency_ms <= 1000.0;

      transition connected_to_maintenance
        first connectedToCloud
        then maintenance
        accept ControlCommand
        if deviceNetwork::incomingPacket.integrityVerified == true;
    }
  }

  part def CloudDevicePlatform {
    attribute platformId : String;
    attribute deviceRegistryCapacity : Integer = 1000000;
    attribute telemetryRetention_days : Integer = 365;
    attribute commandAuditRetention_days : Integer = 2555;
    attribute serviceAvailability_percent : Real = 99.9;

    port gatewayLink : WirelessDataPort;
    port alertOut : AlertPort;

    part deviceRegistry {
      attribute registeredDeviceCount : Integer;
      attribute revokedDeviceCount : Integer;
    }

    part telemetryStore {
      attribute storedReadingCount : Integer;
      attribute averageIngestLatency_ms : LatencyMs;
    }

    part rulesEngine {
      attribute activeRuleCount : Integer;
      attribute evaluatedEventsPerSecond : Real;
    }

    part commandService {
      attribute pendingCommandCount : Integer;
      attribute commandSuccessRate_percent : Real;
    }

    action ingestTelemetry {
      in item packet : EncryptedPacket;
      out item reading : SensorReading;

      first receivePacket;
      then decryptPacket;
      then authenticateDevice;
      then normalizeTelemetry;
      then storeTelemetry;
      then evaluateRules;
      then done;
    }

    action issueRemoteCommand {
      in item command : ControlCommand;
      out item packet : EncryptedPacket;

      first authorizeUser;
      then validateTarget;
      then serializeCommand;
      then encryptCommand;
      then sendToGateway;
      then done;
    }
  }

  part def UserApplication {
    attribute activeUserSessions : Integer;
    attribute dashboardRefreshPeriod_s : Real = 5.0;

    port cloudLink : WirelessDataPort;
    port alertIn {
      in item alert : AlertMessage;
    }

    action visualizeDeviceFleet {
      in item status : DeviceStatus;
      in item reading : SensorReading;

      first loadDashboard;
      then renderDeviceHealth;
      then renderTelemetryTrends;
      then showAlerts;
      then done;
    }

    action requestDeviceAction {
      out item command : ControlCommand;

      first selectDevice;
      then composeCommand;
      then submitCommand;
      then awaitAcknowledgement;
      then done;
    }
  }

  part def ConnectedDevicesSystem {
    attribute systemName : String = "Connected Device Monitoring and Control System";
    attribute primaryFunction : String =
      "Collect telemetry from connected field devices, securely route the data through an edge gateway to a cloud platform, analyze device state, notify users of abnormal conditions, and deliver authorized remote commands back to devices.";

    attribute minimumFleetAvailability_percent : Real = 99.0;
    attribute maximumTelemetryLatency_ms : LatencyMs = 2000.0;
    attribute maximumAlertLatency_ms : LatencyMs = 3000.0;
    attribute minimumEncryptionKeyLength_bits : Integer = 256;

    part gateway : EdgeGateway {
      attribute gatewayId = "GW-PRIMARY-001";
    }

    part cloud : CloudDevicePlatform {
      attribute platformId = "CDP-PROD";
    }

    part userApp : UserApplication;

    part livingRoomSensor : EnvironmentalSensorDevice {
      attribute deviceId = "ENV-LR-001";
      attribute nominalPower_W = 2.5;
      attribute batteryCapacity_percent = 86.0;
      attribute wirelessThroughput_Mbps = 2.0;
      attribute samplingPeriod_s = 30.0;
    }

    part entrySensor : EnvironmentalSensorDevice {
      attribute deviceId = "ENV-ENT-002";
      attribute nominalPower_W = 2.0;
      attribute batteryCapacity_percent = 72.0;
      attribute wirelessThroughput_Mbps = 2.0;
      attribute samplingPeriod_s = 15.0;
    }

    part hvacController : SmartActuatorDevice {
      attribute deviceId = "ACT-HVAC-003";
      attribute nominalPower_W = 8.0;
      attribute batteryCapacity_percent = 100.0;
      attribute wirelessThroughput_Mbps = 5.0;
      attribute actuatorPosition_percent = 50.0;
    }

    connect livingRoomSensor.network to gateway.deviceNetwork;
    connect entrySensor.network to gateway.deviceNetwork;
    connect hvacController.network to gateway.deviceNetwork;
    connect gateway.cloudNetwork to cloud.gatewayLink;
    connect cloud.gatewayLink to userApp.cloudLink;
    connect livingRoomSensor.alertOut to gateway.alertOut;
    connect entrySensor.alertOut to gateway.alertOut;
    connect hvacController.alertOut to gateway.alertOut;
    connect cloud.alertOut to userApp.alertIn;

    action operateConnectedDeviceFleet {
      first collectFieldTelemetry;
      then secureGatewayRouting;
      then cloudIngestionAndAnalysis;
      then notifyUserWhenRequired;
      then dispatchAuthorizedCommands;
      then updateDeviceStates;
      then done;

      action collectFieldTelemetry {
        out item reading1 : SensorReading;
        out item reading2 : SensorReading;
        out item status1 : DeviceStatus;
        out item status2 : DeviceStatus;
      }

      action secureGatewayRouting {
        in item devicePacket : EncryptedPacket;
        out item cloudPacket : EncryptedPacket;
      }

      action cloudIngestionAndAnalysis {
        in item telemetryPacket : EncryptedPacket;
        out item alert : AlertMessage;
      }

      action notifyUserWhenRequired {
        in item alert : AlertMessage;
      }

      action dispatchAuthorizedCommands {
        in item command : ControlCommand;
        out item encryptedCommand : EncryptedPacket;
      }

      action updateDeviceStates {
        in item commandPacket : EncryptedPacket;
      }
    }

    state systemOperationalState {
      entry; then starting;

      state starting;
      state monitoring;
      state alerting;
      state commanding;
      state degradedService;
      state shutdown;

      transition start_to_monitoring
        first starting
        then monitoring;

      transition monitoring_to_alerting
        first monitoring
        then alerting
        accept AlertMessage;

      transition alerting_to_monitoring
        first alerting
        then monitoring;

      transition monitoring_to_commanding
        first monitoring
        then commanding
        accept ControlCommand;

      transition commanding_to_monitoring
        first commanding
        then monitoring;

      transition monitoring_to_degraded
        first monitoring
        then degradedService
        if gateway.maximumCloudLatency_ms > maximumTelemetryLatency_ms;

      transition degraded_to_monitoring
        first degradedService
        then monitoring
        if gateway.maximumCloudLatency_ms <= maximumTelemetryLatency_ms;

      transition monitoring_to_shutdown
        first monitoring
        then shutdown
        accept ControlCommand
        if cloud.commandService.pendingCommandCount == 0;
    }
  }

  requirement def SecureTelemetryRequirement {
    subject system : ConnectedDevicesSystem;
    require constraint {
      system.minimumEncryptionKeyLength_bits >= 256
    }
  }

  requirement def TelemetryLatencyRequirement {
    subject system : ConnectedDevicesSystem;
    require constraint {
      system.maximumTelemetryLatency_ms <= 2000.0
    }
  }

  requirement def AlertLatencyRequirement {
    subject system : ConnectedDevicesSystem;
    require constraint {
      system.maximumAlertLatency_ms <= 3000.0
    }
  }

  requirement def FleetAvailabilityRequirement {
    subject system : ConnectedDevicesSystem;
    require constraint {
      system.minimumFleetAvailability_percent >= 99.0
    }
  }

  requirement def BatteryHealthRequirement {
    subject device : ConnectedDevice;
    require constraint {
      device.batteryCapacity_percent >= device.minimumOperatingBattery_percent
    }
  }

  requirement def GatewayCapacityRequirement {
    subject gateway : EdgeGateway;
    require constraint {
      gateway.maxSupportedDevices >= 3
    }
  }

  requirement secureTelemetryRequirement : SecureTelemetryRequirement {
    subject system = connectedDevicesSystem;
  }

  requirement telemetryLatencyRequirement : TelemetryLatencyRequirement {
    subject system = connectedDevicesSystem;
  }

  requirement alertLatencyRequirement : AlertLatencyRequirement {
    subject system = connectedDevicesSystem;
  }

  requirement fleetAvailabilityRequirement : FleetAvailabilityRequirement {
    subject system = connectedDevicesSystem;
  }

  requirement livingRoomBatteryRequirement : BatteryHealthRequirement {
    subject device = connectedDevicesSystem.livingRoomSensor;
  }

  requirement entrySensorBatteryRequirement : BatteryHealthRequirement {
    subject device = connectedDevicesSystem.entrySensor;
  }

  requirement hvacControllerBatteryRequirement : BatteryHealthRequirement {
    subject device = connectedDevicesSystem.hvacController;
  }

  requirement gatewayCapacityRequirement : GatewayCapacityRequirement {
    subject gateway = connectedDevicesSystem.gateway;
  }

  part connectedDevicesSystem : ConnectedDevicesSystem;

}