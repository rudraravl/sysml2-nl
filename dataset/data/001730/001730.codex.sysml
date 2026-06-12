package TuyaIncSmartIoTPlatformModel {

  import ScalarValues::*;
  import NumericalFunctions::*;

  item def CommandMessage {
    attribute commandId : String;
    attribute deviceId : String;
    attribute functionCode : String;
    attribute payload : String;
    attribute issuedAtEpochMs : Integer;
  }

  item def TelemetryMessage {
    attribute deviceId : String;
    attribute productKey : String;
    attribute propertyCode : String;
    attribute value : String;
    attribute reportedAtEpochMs : Integer;
  }

  item def FirmwareImage {
    attribute imageId : String;
    attribute version : String;
    attribute sizeBytes : Integer;
    attribute checksumSha256 : String;
    attribute signed : Boolean;
  }

  item def UserCredential {
    attribute userId : String;
    attribute authToken : String;
    attribute expiresAtEpochMs : Integer;
  }

  item def AutomationRule {
    attribute ruleId : String;
    attribute triggerExpression : String;
    attribute actionExpression : String;
    attribute enabled : Boolean;
  }

  attribute def Latency_ms : Real {
    doc /* milliseconds */
  }

  attribute def Availability_percent : Real {
    doc /* percent */
  }

  attribute def DataRate_kbps : Real {
    doc /* kilobits per second */
  }

  attribute def Power_W : Real {
    doc /* watts */
  }

  attribute def Energy_Wh : Real {
    doc /* watt hours */
  }

  attribute def Temperature_degC : Real {
    doc /* degrees Celsius */
  }

  attribute def Humidity_percent : Real {
    doc /* relative humidity percent */
  }

  port def CloudApiPort {
    in item credential : UserCredential;
    in item command : CommandMessage;
    in item rule : AutomationRule;
    out item telemetry : TelemetryMessage;
  }

  port def DeviceMessagingPort {
    in item command : CommandMessage;
    in item firmware : FirmwareImage;
    out item telemetry : TelemetryMessage;
  }

  port def MobileAppPort {
    out item credential : UserCredential;
    out item command : CommandMessage;
    out item rule : AutomationRule;
    in item telemetry : TelemetryMessage;
  }

  port def OtaDistributionPort {
    out item firmware : FirmwareImage;
  }

  interface def UserCloudInterface {
    end userSide : MobileAppPort;
    end cloudSide : CloudApiPort;
  }

  interface def DeviceCloudInterface {
    end cloudSide : DeviceMessagingPort;
    end deviceSide : DeviceMessagingPort;
  }

  interface def OtaInterface {
    end source : OtaDistributionPort;
    end sink : DeviceMessagingPort;
  }

  part def TuyaCloudPlatform {
    doc /* Primary high-level function: provide a cloud-based IoT platform that connects users, smart devices, applications, automation logic, and device lifecycle services so consumer and enterprise devices can be monitored, controlled, updated, and integrated at scale. */

    attribute apiAvailability : Availability_percent = 99.9;
    attribute targetCommandLatency : Latency_ms = 500.0;
    attribute maxDeviceMessageRate : DataRate_kbps = 256.0;

    port userApi : CloudApiPort;
    port deviceBroker : DeviceMessagingPort;
    port otaOut : OtaDistributionPort;

    part identityService : IdentityService;
    part deviceRegistry : DeviceRegistry;
    part messageBroker : IoTMessageBroker;
    part automationEngine : AutomationEngine;
    part otaService : FirmwareUpdateService;
    part dataStore : DeviceDataStore;

    connect userApi to identityService.userAccess;
    connect userApi to automationEngine.ruleInput;
    connect userApi to messageBroker.cloudCommandInput;
    connect deviceBroker to messageBroker.deviceMessageExchange;
    connect deviceBroker to dataStore.telemetryInput;
    connect otaOut to otaService.firmwareOutput;
  }

  part def IdentityService {
    attribute maxTokenLifetime_s : Real = 86400.0;
    attribute multiFactorSupported : Boolean = true;
    port userAccess : CloudApiPort;
  }

  part def DeviceRegistry {
    attribute registeredDeviceCapacity : Integer = 10000000;
    attribute productModelCapacity : Integer = 100000;
    port provisioningApi : CloudApiPort;
  }

  part def IoTMessageBroker {
    attribute targetPublishLatency : Latency_ms = 200.0;
    attribute retainedTelemetryHours : Real = 24.0;
    port cloudCommandInput : CloudApiPort;
    port deviceMessageExchange : DeviceMessagingPort;
  }

  part def AutomationEngine {
    attribute maxRulesPerUser : Integer = 200;
    attribute targetRuleEvaluationLatency : Latency_ms = 300.0;
    port ruleInput : CloudApiPort;
    port commandOutput : CloudApiPort;
  }

  part def FirmwareUpdateService {
    attribute stagedRolloutSupported : Boolean = true;
    attribute minBatteryLevelForUpdate_percent : Real = 30.0;
    port firmwareOutput : OtaDistributionPort;
  }

  part def DeviceDataStore {
    attribute retentionDays : Integer = 30;
    attribute encryptedAtRest : Boolean = true;
    port telemetryInput : DeviceMessagingPort;
  }

  part def TuyaMobileApplication {
    attribute supportedPlatforms : String = "iOS, Android";
    attribute targetUiCommandLatency : Latency_ms = 150.0;
    port appPort : MobileAppPort;

    part dashboard : DeviceDashboard;
    part sceneEditor : SceneEditor;
    part accountClient : AccountClient;

    connect appPort to dashboard.cloudPort;
    connect appPort to sceneEditor.cloudPort;
    connect appPort to accountClient.cloudPort;
  }

  part def DeviceDashboard {
    port cloudPort : MobileAppPort;
  }

  part def SceneEditor {
    port cloudPort : MobileAppPort;
  }

  part def AccountClient {
    port cloudPort : MobileAppPort;
  }

  part def TuyaEnabledSmartDevice {
    attribute productKey : String;
    attribute deviceId : String;
    attribute nominalPower : Power_W = 6.5;
    attribute dailyEnergyBudget : Energy_Wh = 80.0;
    attribute secureBootEnabled : Boolean = true;

    port cloudLink : DeviceMessagingPort;

    part networkModule : WiFiModule;
    part controlModule : EmbeddedControlModule;
    part sensorPack : EnvironmentalSensorPack;
    part actuator : SmartRelayActuator;

    connect cloudLink to networkModule.cloudRadioPort;
    connect networkModule.localControllerPort to controlModule.networkPort;
    connect sensorPack.telemetryPort to controlModule.sensorPort;
    connect controlModule.actuatorPort to actuator.controlPort;
  }

  part def WiFiModule {
    attribute transmitRate : DataRate_kbps = 1024.0;
    attribute receiveRate : DataRate_kbps = 1024.0;
    attribute standbyPower : Power_W = 0.4;
    port cloudRadioPort : DeviceMessagingPort;
    port localControllerPort : DeviceMessagingPort;
  }

  part def EmbeddedControlModule {
    attribute firmwareVersion : String = "1.0.0";
    attribute commandProcessingLatency : Latency_ms = 50.0;
    port networkPort : DeviceMessagingPort;
    port sensorPort : DeviceMessagingPort;
    port actuatorPort : DeviceMessagingPort;
  }

  part def EnvironmentalSensorPack {
    attribute measuredTemperature : Temperature_degC = 22.0;
    attribute measuredHumidity : Humidity_percent = 45.0;
    attribute samplingPeriod_s : Real = 60.0;
    port telemetryPort : DeviceMessagingPort;
  }

  part def SmartRelayActuator {
    attribute maxLoadPower : Power_W = 600.0;
    attribute relayClosed : Boolean = false;
    port controlPort : DeviceMessagingPort;
  }

  part def TuyaIncIoTEcosystem {
    doc /* A high-level model of a Tuya Inc.-style IoT ecosystem whose primary function is to enable cloud-managed smart device connectivity, monitoring, control, automation, and firmware lifecycle management. */

    part cloud : TuyaCloudPlatform;
    part mobileApp : TuyaMobileApplication;
    part smartPlug : TuyaEnabledSmartDevice {
      :>> productKey = "TY-SMART-PLUG";
      :>> deviceId = "device-001";
      :>> nominalPower = 3.0;
    }
    part thermostat : TuyaEnabledSmartDevice {
      :>> productKey = "TY-THERMOSTAT";
      :>> deviceId = "device-002";
      :>> nominalPower = 5.0;
    }

    interface userCloud : UserCloudInterface connect
      userCloud::userSide ::> mobileApp.appPort to
      userCloud::cloudSide ::> cloud.userApi;

    interface plugCloud : DeviceCloudInterface connect
      plugCloud::cloudSide ::> cloud.deviceBroker to
      plugCloud::deviceSide ::> smartPlug.cloudLink;

    interface thermostatCloud : DeviceCloudInterface connect
      thermostatCloud::cloudSide ::> cloud.deviceBroker to
      thermostatCloud::deviceSide ::> thermostat.cloudLink;

    interface otaPlug : OtaInterface connect
      otaPlug::source ::> cloud.otaOut to
      otaPlug::sink ::> smartPlug.cloudLink;

    interface otaThermostat : OtaInterface connect
      otaThermostat::source ::> cloud.otaOut to
      otaThermostat::sink ::> thermostat.cloudLink;
  }

  action def AuthenticateUser {
    in item credential : UserCredential;
    out authenticated : Boolean;
    attribute maxLatency : Latency_ms = 250.0;
  }

  action def RegisterDevice {
    in item credential : UserCredential;
    in deviceProductKey : String;
    out registeredDeviceId : String;
  }

  action def SendDeviceCommand {
    in item command : CommandMessage;
    out accepted : Boolean;
    attribute maxEndToEndLatency : Latency_ms = 500.0;
  }

  action def ReportTelemetry {
    in item telemetry : TelemetryMessage;
    out stored : Boolean;
    attribute maxIngestLatency : Latency_ms = 300.0;
  }

  action def EvaluateAutomationRule {
    in item telemetry : TelemetryMessage;
    in item rule : AutomationRule;
    out item generatedCommand : CommandMessage;
    attribute maxEvaluationLatency : Latency_ms = 300.0;
  }

  action def DeployFirmwareUpdate {
    in item firmware : FirmwareImage;
    out deployed : Boolean;
    attribute maxRolloutDuration_min : Real = 60.0;
  }

  state def DeviceLifecycleState {
    entry action InitializeHardware;
    state Unprovisioned;
    state Provisioning;
    state Connected;
    state ReportingTelemetry;
    state ExecutingCommand;
    state UpdatingFirmware;
    state Offline;
    state Faulted;

    transition first Unprovisioned;
    transition Unprovisioned_to_Provisioning
      first Unprovisioned then Provisioning
      accept RegisterDevice;

    transition Provisioning_to_Connected
      first Provisioning then Connected
      if provisioningSuccessful;

    transition Connected_to_ReportingTelemetry
      first Connected then ReportingTelemetry
      accept ReportTelemetry;

    transition ReportingTelemetry_to_Connected
      first ReportingTelemetry then Connected;

    transition Connected_to_ExecutingCommand
      first Connected then ExecutingCommand
      accept SendDeviceCommand;

    transition ExecutingCommand_to_Connected
      first ExecutingCommand then Connected;

    transition Connected_to_UpdatingFirmware
      first Connected then UpdatingFirmware
      accept DeployFirmwareUpdate;

    transition UpdatingFirmware_to_Connected
      first UpdatingFirmware then Connected
      if firmwareVerified;

    transition Connected_to_Offline
      first Connected then Offline
      if networkUnavailable;

    transition Offline_to_Connected
      first Offline then Connected
      if networkRestored;

    transition any_to_Faulted
      first Connected then Faulted
      if unrecoverableDeviceError;
  }

  state def CloudServiceState {
    state Starting;
    state Operational;
    state Degraded;
    state Maintenance;
    state IncidentResponse;

    transition first Starting;
    transition Starting_to_Operational
      first Starting then Operational
      if healthChecksPassed;

    transition Operational_to_Degraded
      first Operational then Degraded
      if serviceLatencyExceeded;

    transition Degraded_to_Operational
      first Degraded then Operational
      if serviceLatencyRecovered;

    transition Operational_to_Maintenance
      first Operational then Maintenance
      if plannedMaintenanceWindow;

    transition Maintenance_to_Operational
      first Maintenance then Operational
      if maintenanceComplete;

    transition Degraded_to_IncidentResponse
      first Degraded then IncidentResponse
      if customerImpactDetected;

    transition IncidentResponse_to_Operational
      first IncidentResponse then Operational
      if incidentResolved;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall provide a cloud-centered IoT platform that allows authenticated users and applications to connect, monitor, control, automate, and update Tuya-enabled smart devices. */
    subject ecosystem : TuyaIncIoTEcosystem;
    require constraint {
      ecosystem.cloud.apiAvailability >= 99.9
    }
  }

  requirement def CommandLatencyRequirement {
    doc /* The system shall deliver accepted user commands from application to connected device within 500 ms under nominal network conditions. */
    subject cloud : TuyaCloudPlatform;
    require constraint {
      cloud.targetCommandLatency <= 500.0
    }
  }

  requirement def TelemetryIngestionRequirement {
    doc /* The system shall ingest device telemetry and make it available to applications for monitoring and automation. */
    subject store : DeviceDataStore;
    require constraint {
      store.retentionDays >= 30
    }
  }

  requirement def SecurityRequirement {
    doc /* The system shall protect user identity, device identity, data in transit, firmware authenticity, and stored telemetry. */
    subject ecosystem : TuyaIncIoTEcosystem;
    require constraint {
      ecosystem.cloud.dataStore.encryptedAtRest == true and
      ecosystem.smartPlug.secureBootEnabled == true and
      ecosystem.thermostat.secureBootEnabled == true
    }
  }

  requirement def FirmwareLifecycleRequirement {
    doc /* The system shall distribute signed firmware images to connected devices using staged rollout controls. */
    subject service : FirmwareUpdateService;
    require constraint {
      service.stagedRolloutSupported == true and
      service.minBatteryLevelForUpdate_percent >= 30.0
    }
  }

  requirement def AutomationRequirement {
    doc /* The system shall evaluate enabled automation rules and produce device commands when telemetry or user events satisfy rule conditions. */
    subject engine : AutomationEngine;
    require constraint {
      engine.maxRulesPerUser >= 100 and
      engine.targetRuleEvaluationLatency <= 300.0
    }
  }

}