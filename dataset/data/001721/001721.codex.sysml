package OpenRemoteBasedSystem {
  import ScalarValues::*;
  import SI::*;

  attribute def Percent :> Real;
  attribute def Kilowatt :> Real;
  attribute def KilowattHour :> Real;
  attribute def DegreeCelsius :> Real;
  attribute def Millisecond :> Real;
  attribute def Second :> Real;
  attribute def Volt :> Real;
  attribute def Ampere :> Real;

  item def TelemetrySample {
    attribute assetId : String;
    attribute attributeName : String;
    attribute numericValue : Real;
    attribute unitSymbol : String;
    attribute timestampEpochMs : Integer;
    attribute quality : String;
  }

  item def AssetStateUpdate {
    attribute assetId : String;
    attribute stateName : String;
    attribute value : String;
    attribute timestampEpochMs : Integer;
  }

  item def ControlCommand {
    attribute commandId : String;
    attribute targetAssetId : String;
    attribute commandName : String;
    attribute requestedValue : String;
    attribute priority : Integer;
    attribute issuedBy : String;
  }

  item def AlarmEvent {
    attribute alarmId : String;
    attribute sourceAssetId : String;
    attribute severity : String;
    attribute message : String;
    attribute timestampEpochMs : Integer;
    attribute acknowledged : Boolean;
  }

  item def UserRequest {
    attribute userId : String;
    attribute tenantId : String;
    attribute operation : String;
    attribute authorizationToken : String;
  }

  port def TelemetryInPort {
    in item telemetry : TelemetrySample;
  }

  port def StateUpdatePort {
    in item stateUpdate : AssetStateUpdate;
    out item command : ControlCommand;
  }

  port def CommandOutPort {
    out item command : ControlCommand;
  }

  port def AlarmPort {
    out item alarm : AlarmEvent;
  }

  port def ApiPort {
    in item request : UserRequest;
    out item stateUpdate : AssetStateUpdate;
    out item alarm : AlarmEvent;
  }

  port def FieldBusPort {
    in item telemetry : TelemetrySample;
    out item command : ControlCommand;
  }

  part def FieldAsset {
    attribute assetId : String;
    attribute online : Boolean;
    attribute samplingPeriod : Second;
    port fieldBus : FieldBusPort;
  }

  part def HvacUnit :> FieldAsset {
    attribute supplyAirTemperature : DegreeCelsius;
    attribute returnAirTemperature : DegreeCelsius;
    attribute coolingSetpoint : DegreeCelsius;
    attribute fanSpeed : Percent;
    attribute powerDemand : Kilowatt;
  }

  part def SolarInverter :> FieldAsset {
    attribute dcVoltage : Volt;
    attribute dcCurrent : Ampere;
    attribute acPowerOutput : Kilowatt;
    attribute dailyEnergy : KilowattHour;
    attribute curtailmentLimit : Percent;
  }

  part def SmartMeter :> FieldAsset {
    attribute instantaneousDemand : Kilowatt;
    attribute importedEnergy : KilowattHour;
    attribute exportedEnergy : KilowattHour;
    attribute voltage : Volt;
  }

  part def ProtocolAdapter {
    attribute protocolName : String;
    attribute pollingInterval : Second;
    port fieldSide : FieldBusPort;
    port platformSide : TelemetryInPort;
    port commandSide : CommandOutPort;
  }

  part def EdgeGateway {
    attribute gatewayId : String;
    attribute connected : Boolean;
    attribute bufferedSamples : Integer;
    port modbusAdapter : FieldBusPort;
    port bacnetAdapter : FieldBusPort;
    port mqttTelemetryOut : TelemetryInPort;
    port mqttCommandIn : CommandOutPort;

    part modbus : ProtocolAdapter {
      attribute protocolName = "Modbus TCP";
      attribute pollingInterval = 5.0;
    }

    part bacnet : ProtocolAdapter {
      attribute protocolName = "BACnet/IP";
      attribute pollingInterval = 10.0;
    }
  }

  part def AssetRegistry {
    attribute registeredAssetCount : Integer;
    port statePort : StateUpdatePort;
  }

  part def RuleEngine {
    attribute activeRuleCount : Integer;
    attribute evaluationPeriod : Second;
    port stateIn : StateUpdatePort;
    port commandOut : CommandOutPort;
    port alarmOut : AlarmPort;
  }

  part def TimeSeriesStore {
    attribute retentionDays : Integer;
    attribute writeLatencyTarget : Millisecond;
    port telemetryIn : TelemetryInPort;
  }

  part def IdentityAndAccessService {
    attribute tenantCount : Integer;
    attribute sessionTimeout : Second;
    port api : ApiPort;
  }

  part def DashboardApplication {
    attribute activeUserSessions : Integer;
    port browserApi : ApiPort;
  }

  part def NotificationService {
    attribute pendingNotifications : Integer;
    port alarmIn : AlarmPort;
  }

  part def OpenRemoteManager {
    attribute managerVersion : String;
    attribute tenantId : String;
    attribute primaryFunction : String = "Collect telemetry from connected assets, maintain normalized digital asset state, evaluate automation rules, issue control commands, and expose operational views through APIs and dashboards.";

    port telemetryIn : TelemetryInPort;
    port assetState : StateUpdatePort;
    port commandOut : CommandOutPort;
    port api : ApiPort;
    port alarms : AlarmPort;

    part registry : AssetRegistry;
    part rules : RuleEngine;
    part store : TimeSeriesStore {
      attribute retentionDays = 730;
      attribute writeLatencyTarget = 250.0;
    }
    part identity : IdentityAndAccessService {
      attribute sessionTimeout = 1800.0;
    }
    part dashboard : DashboardApplication;
    part notifications : NotificationService;
  }

  part def OpenRemoteBasedEnergyAndBuildingSystem {
    attribute siteName : String;
    attribute normalTelemetryPeriod : Second;
    attribute alarmResponseTarget : Second;

    part manager : OpenRemoteManager {
      attribute managerVersion = "OpenRemote Manager";
      attribute tenantId = "site-operations";
    }

    part gateway : EdgeGateway {
      attribute gatewayId = "edge-gw-01";
      attribute connected = true;
    }

    part hvac : HvacUnit {
      attribute assetId = "hvac-zone-a";
      attribute samplingPeriod = 5.0;
      attribute coolingSetpoint = 23.0;
    }

    part inverter : SolarInverter {
      attribute assetId = "solar-inverter-01";
      attribute samplingPeriod = 5.0;
      attribute curtailmentLimit = 100.0;
    }

    part meter : SmartMeter {
      attribute assetId = "main-meter-01";
      attribute samplingPeriod = 1.0;
    }

    connection hvacToGateway connect hvac.fieldBus to gateway.bacnetAdapter;
    connection inverterToGateway connect inverter.fieldBus to gateway.modbusAdapter;
    connection meterToGateway connect meter.fieldBus to gateway.modbusAdapter;
    connection telemetryToManager connect gateway.mqttTelemetryOut to manager.telemetryIn;
    connection commandsToGateway connect manager.commandOut to gateway.mqttCommandIn;
    connection managerStateToRegistry connect manager.assetState to manager.registry.statePort;
    connection managerStateToRules connect manager.assetState to manager.rules.stateIn;
    connection telemetryToStore connect manager.telemetryIn to manager.store.telemetryIn;
    connection rulesToCommands connect manager.rules.commandOut to manager.commandOut;
    connection rulesToAlarms connect manager.rules.alarmOut to manager.alarms;
    connection alarmsToNotifications connect manager.alarms to manager.notifications.alarmIn;
    connection dashboardToApi connect manager.dashboard.browserApi to manager.api;
    connection identityToApi connect manager.identity.api to manager.api;
  }

  action def NormalizeTelemetry {
    in item rawSample : TelemetrySample;
    out item normalizedUpdate : AssetStateUpdate;
  }

  action def EvaluateAutomationRules {
    in item currentState : AssetStateUpdate;
    out item command : ControlCommand;
    out item alarm : AlarmEvent;
  }

  action def DispatchControlCommand {
    in item command : ControlCommand;
    out item acceptedCommand : ControlCommand;
  }

  action def NotifyOperator {
    in item alarm : AlarmEvent;
  }

  action def OpenRemoteOperationalLoop {
    in item telemetry : TelemetrySample;
    out item command : ControlCommand;
    out item alarm : AlarmEvent;

    action normalize : NormalizeTelemetry {
      in rawSample = telemetry;
    }

    action evaluate : EvaluateAutomationRules {
      in currentState = normalize.normalizedUpdate;
    }

    action dispatch : DispatchControlCommand {
      in command = evaluate.command;
    }

    action notify : NotifyOperator {
      in alarm = evaluate.alarm;
    }
  }

  state def ManagerRuntimeState {
    state Initializing;
    state Connected;
    state Degraded;
    state Automating;
    state AlarmHandling;
    state Offline;

    transition first Initializing;
    transition initComplete from Initializing to Connected;
    transition telemetryHealthy from Connected to Automating;
    transition gatewayLost from Connected to Degraded;
    transition ruleAlarmRaised from Automating to AlarmHandling;
    transition alarmAcknowledged from AlarmHandling to Automating;
    transition persistentConnectionLoss from Degraded to Offline;
    transition connectionRestored from Offline to Connected;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall use OpenRemote Manager as the central IoT and asset-management platform to acquire telemetry, maintain normalized asset state, execute automation rules, send commands to field assets, and provide operator access through dashboards and APIs. */
  }

  requirement def TelemetryCollectionRequirement {
    doc /* The system shall collect telemetry from HVAC, inverter, and meter assets through protocol adapters and publish normalized asset updates within 5 seconds during normal operation. */
  }

  requirement def CommandDispatchRequirement {
    doc /* The system shall dispatch authorized control commands from automation rules or authenticated operators to the correct field asset with priority handling. */
  }

  requirement def AlarmRequirement {
    doc /* The system shall create an alarm event when asset telemetry exceeds configured operating limits and shall forward the alarm to the notification service. */
  }

  requirement def SecurityRequirement {
    doc /* The system shall authenticate API users, associate each request with a tenant, and reject unauthorized command operations before commands reach field assets. */
  }

  requirement def AvailabilityRequirement {
    doc /* The system shall continue buffering telemetry at the edge gateway during temporary manager connectivity loss and forward buffered samples after reconnection. */
  }

  satisfy PrimaryFunctionRequirement by OpenRemoteBasedEnergyAndBuildingSystem.manager;
  satisfy TelemetryCollectionRequirement by OpenRemoteBasedEnergyAndBuildingSystem.gateway;
  satisfy CommandDispatchRequirement by OpenRemoteBasedEnergyAndBuildingSystem.manager.rules;
  satisfy AlarmRequirement by OpenRemoteBasedEnergyAndBuildingSystem.manager.notifications;
  satisfy SecurityRequirement by OpenRemoteBasedEnergyAndBuildingSystem.manager.identity;
  satisfy AvailabilityRequirement by OpenRemoteBasedEnergyAndBuildingSystem.gateway;
}