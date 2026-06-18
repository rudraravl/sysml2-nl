package OpenWebNetHighLevelSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Volt :> Real {
    doc /* Electric potential in volts. */
  }

  attribute def Watt :> Real {
    doc /* Active power in watts. */
  }

  attribute def Celsius :> Real {
    doc /* Temperature in degrees Celsius. */
  }

  attribute def Percent :> Real {
    doc /* Ratio expressed as percent. */
  }

  attribute def Millisecond :> Real {
    doc /* Time duration in milliseconds. */
  }

  attribute def Second :> Real {
    doc /* Time duration in seconds. */
  }

  attribute def Meter :> Real {
    doc /* Length in meters. */
  }

  enum def OpenWebNetWho {
    enum lighting;
    enum automation;
    enum temperatureControl;
    enum energyManagement;
    enum burglarAlarm;
    enum auxiliary;
    enum gatewayManagement;
  }

  enum def OpenWebNetCommandClass {
    enum statusRequest;
    enum statusResponse;
    enum actuationCommand;
    enum eventNotification;
    enum acknowledgement;
    enum negativeAcknowledgement;
    enum heartbeat;
  }

  enum def DeviceHealth {
    enum initializing;
    enum available;
    enum degraded;
    enum unavailable;
    enum faulted;
  }

  enum def LightLevel {
    enum off;
    enum low;
    enum medium;
    enum high;
    enum full;
  }

  enum def HvacMode {
    enum off;
    enum heat;
    enum cool;
    enum auto;
    enum fanOnly;
    enum eco;
  }

  enum def SecurityMode {
    enum disarmed;
    enum armedHome;
    enum armedAway;
    enum alarmActive;
  }

  item def OpenWebNetAddress {
    attribute area: Integer;
    attribute point: Integer;
    attribute interfaceId: Integer;
  }

  item def OpenWebNetFrame {
    attribute rawText: String;
    attribute who: OpenWebNetWho;
    attribute commandClass: OpenWebNetCommandClass;
    attribute where: OpenWebNetAddress;
    attribute what: String;
    attribute parameter: String;
    attribute checksumValid: Boolean;
    attribute timestamp: Second;
  }

  item def AutomationCommand {
    attribute targetAddress: OpenWebNetAddress;
    attribute domain: OpenWebNetWho;
    attribute requestedFunction: String;
    attribute requestedValue: String;
    attribute issuedAt: Second;
  }

  item def AutomationEvent {
    attribute sourceAddress: OpenWebNetAddress;
    attribute domain: OpenWebNetWho;
    attribute eventName: String;
    attribute eventValue: String;
    attribute observedAt: Second;
  }

  item def DeviceStatus {
    attribute address: OpenWebNetAddress;
    attribute health: DeviceHealth;
    attribute lastSeen: Second;
    attribute supplyVoltage: Volt;
    attribute activePower: Watt;
  }

  item def LightingStatus :> DeviceStatus {
    attribute level: LightLevel;
    attribute dimmingPercent: Percent;
  }

  item def ClimateStatus :> DeviceStatus {
    attribute measuredTemperature: Celsius;
    attribute setpointTemperature: Celsius;
    attribute mode: HvacMode;
  }

  item def SecurityStatus :> DeviceStatus {
    attribute mode: SecurityMode;
    attribute intrusionDetected: Boolean;
    attribute tamperDetected: Boolean;
  }

  item def UserIntent {
    attribute userId: String;
    attribute requestedScene: String;
    attribute priority: Integer;
    attribute createdAt: Second;
  }

  item def SceneResult {
    attribute sceneName: String;
    attribute success: Boolean;
    attribute completionTime: Second;
    attribute message: String;
  }

  port def OpenWebNetBusPort {
    in item receivedFrame: OpenWebNetFrame;
    out item transmittedFrame: OpenWebNetFrame;
  }

  port def IpClientPort {
    in item userIntent: UserIntent;
    out item sceneResult: SceneResult;
    out item automationEvent: AutomationEvent;
  }

  port def DeviceControlPort {
    in item command: AutomationCommand;
    out item status: DeviceStatus;
    out item event: AutomationEvent;
  }

  port def LightingControlPort :> DeviceControlPort {
    out item lightingStatus: LightingStatus;
  }

  port def ClimateControlPort :> DeviceControlPort {
    out item climateStatus: ClimateStatus;
  }

  port def SecurityControlPort :> DeviceControlPort {
    out item securityStatus: SecurityStatus;
  }

  port def PowerPort {
    in item supplyVoltage: Volt;
    out item consumedPower: Watt;
  }

  port def MaintenancePort {
    out item deviceStatus: DeviceStatus;
    in item diagnosticCommand: AutomationCommand;
  }

  action def ValidateOpenWebNetFrame {
    in item candidateFrame: OpenWebNetFrame;
    out item validFrame: OpenWebNetFrame;
    out attribute accepted: Boolean;
  }

  action def DecodeFrameToEvent {
    in item frame: OpenWebNetFrame;
    out item event: AutomationEvent;
  }

  action def EncodeCommandToFrame {
    in item command: AutomationCommand;
    out item frame: OpenWebNetFrame;
  }

  action def DispatchCommandToDevice {
    in item command: AutomationCommand;
    out item routedFrame: OpenWebNetFrame;
  }

  action def ExecuteScene {
    in item intent: UserIntent;
    out item command1: AutomationCommand;
    out item command2: AutomationCommand;
    out item command3: AutomationCommand;
    out item result: SceneResult;
  }

  action def PublishEventToClient {
    in item event: AutomationEvent;
    out item deliveredEvent: AutomationEvent;
  }

  action def MonitorDeviceHealth {
    in item status: DeviceStatus;
    out attribute isHealthy: Boolean;
    out item event: AutomationEvent;
  }

  state def GatewayLifecycle {
    entry action initializeGateway;
    state Offline;
    state Starting;
    state Operational;
    state Degraded;
    state Faulted;

    first Offline;
    transition Offline_to_Starting
      first Offline
      then Starting;

    transition Starting_to_Operational
      first Starting
      then Operational;

    transition Operational_to_Degraded
      first Operational
      then Degraded;

    transition Degraded_to_Operational
      first Degraded
      then Operational;

    transition Operational_to_Faulted
      first Operational
      then Faulted;

    transition Faulted_to_Starting
      first Faulted
      then Starting;
  }

  state def LightingActuatorLifecycle {
    state Unpowered;
    state Ready;
    state On;
    state Off;
    state Fault;

    first Unpowered;

    transition Unpowered_to_Ready
      first Unpowered
      then Ready;

    transition Ready_to_Off
      first Ready
      then Off;

    transition Off_to_On
      first Off
      then On;

    transition On_to_Off
      first On
      then Off;

    transition On_to_Fault
      first On
      then Fault;

    transition Off_to_Fault
      first Off
      then Fault;
  }

  state def SecurityControllerLifecycle {
    state Disarmed;
    state ArmedHome;
    state ArmedAway;
    state Alarm;
    state Fault;

    first Disarmed;

    transition Disarmed_to_ArmedHome
      first Disarmed
      then ArmedHome;

    transition Disarmed_to_ArmedAway
      first Disarmed
      then ArmedAway;

    transition ArmedHome_to_Disarmed
      first ArmedHome
      then Disarmed;

    transition ArmedAway_to_Disarmed
      first ArmedAway
      then Disarmed;

    transition ArmedHome_to_Alarm
      first ArmedHome
      then Alarm;

    transition ArmedAway_to_Alarm
      first ArmedAway
      then Alarm;

    transition Alarm_to_Disarmed
      first Alarm
      then Disarmed;

    transition Alarm_to_Fault
      first Alarm
      then Fault;
  }

  part def OpenWebNetAutomationBus {
    doc /* Two-wire OpenWebNet field bus segment carrying framed control, status, and event messages among gateway and automation devices. */

    attribute nominalVoltage: Volt = 27.0;
    attribute maximumSegmentLength: Meter = 500.0;
    attribute maximumFrameLatency: Millisecond = 250.0;

    port gatewayDrop: OpenWebNetBusPort;
    port lightingDrop: OpenWebNetBusPort;
    port climateDrop: OpenWebNetBusPort;
    port securityDrop: OpenWebNetBusPort;
    port energyDrop: OpenWebNetBusPort;
    port auxiliaryDrop: OpenWebNetBusPort;
  }

  part def OpenWebNetGateway {
    doc /* Translates user and integration requests into OpenWebNet frames, validates incoming frames, maintains device status, and exposes events to clients. */

    attribute ipAddress: String;
    attribute tcpPort: Integer = 20000;
    attribute maxConcurrentClients: Integer = 16;
    attribute heartbeatPeriod: Second = 30.0;
    attribute expectedAckTime: Millisecond = 500.0;
    attribute health: DeviceHealth = DeviceHealth::initializing;

    port fieldBus: OpenWebNetBusPort;
    port clientApi: IpClientPort;
    port maintenance: MaintenancePort;
    port power: PowerPort;

    perform action validateFrame: ValidateOpenWebNetFrame;
    perform action decodeFrame: DecodeFrameToEvent;
    perform action encodeCommand: EncodeCommandToFrame;
    perform action dispatchCommand: DispatchCommandToDevice;
    perform action executeScene: ExecuteScene;
    perform action publishEvent: PublishEventToClient;
    exhibit state lifecycle: GatewayLifecycle;
  }

  part def LightingController {
    doc /* OpenWebNet lighting actuator controlling switched and dimmed lighting loads. */

    attribute controllerAddress: OpenWebNetAddress;
    attribute channelCount: Integer = 4;
    attribute ratedLoadPowerPerChannel: Watt = 400.0;
    attribute standbyPower: Watt = 1.2;
    attribute health: DeviceHealth = DeviceHealth::available;

    port bus: OpenWebNetBusPort;
    port control: LightingControlPort;
    port power: PowerPort;
    port maintenance: MaintenancePort;

    perform action monitorHealth: MonitorDeviceHealth;
    exhibit state lifecycle: LightingActuatorLifecycle;
  }

  part def ClimateController {
    doc /* OpenWebNet temperature-control unit regulating room temperature using setpoints and operating modes. */

    attribute controllerAddress: OpenWebNetAddress;
    attribute currentMode: HvacMode = HvacMode::auto;
    attribute defaultHeatingSetpoint: Celsius = 20.0;
    attribute defaultCoolingSetpoint: Celsius = 24.0;
    attribute allowedSetpointMinimum: Celsius = 16.0;
    attribute allowedSetpointMaximum: Celsius = 30.0;
    attribute measurementAccuracy: Celsius = 0.5;
    attribute health: DeviceHealth = DeviceHealth::available;

    port bus: OpenWebNetBusPort;
    port control: ClimateControlPort;
    port power: PowerPort;
    port maintenance: MaintenancePort;

    perform action monitorHealth: MonitorDeviceHealth;
  }

  part def SecurityController {
    doc /* OpenWebNet burglar-alarm interface coordinating arming state, intrusion sensors, tamper events, and alarm notifications. */

    attribute controllerAddress: OpenWebNetAddress;
    attribute sirenTimeout: Second = 180.0;
    attribute entryDelay: Second = 30.0;
    attribute exitDelay: Second = 45.0;
    attribute health: DeviceHealth = DeviceHealth::available;

    port bus: OpenWebNetBusPort;
    port control: SecurityControlPort;
    port power: PowerPort;
    port maintenance: MaintenancePort;

    perform action monitorHealth: MonitorDeviceHealth;
    exhibit state lifecycle: SecurityControllerLifecycle;
  }

  part def EnergyMeter {
    doc /* OpenWebNet energy-management device measuring electrical consumption and reporting power events. */

    attribute meterAddress: OpenWebNetAddress;
    attribute nominalLineVoltage: Volt = 230.0;
    attribute maximumMeasuredPower: Watt = 12000.0;
    attribute measurementUpdatePeriod: Second = 10.0;
    attribute health: DeviceHealth = DeviceHealth::available;

    port bus: OpenWebNetBusPort;
    port control: DeviceControlPort;
    port power: PowerPort;
    port maintenance: MaintenancePort;

    perform action monitorHealth: MonitorDeviceHealth;
  }

  part def WallScenarioKeypad {
    doc /* OpenWebNet wall-mounted user interface that emits scene requests such as leaving home, night mode, or comfort mode. */

    attribute keypadAddress: OpenWebNetAddress;
    attribute buttonCount: Integer = 6;
    attribute ledFeedbackEnabled: Boolean = true;
    attribute health: DeviceHealth = DeviceHealth::available;

    port bus: OpenWebNetBusPort;
    port control: DeviceControlPort;
    port power: PowerPort;
    port maintenance: MaintenancePort;

    perform action monitorHealth: MonitorDeviceHealth;
  }

  part def MobileApplication {
    doc /* IP client enabling users to request scenes, inspect device status, and receive OpenWebNet automation events. */

    attribute applicationName: String = "OpenWebNet Home Console";
    attribute supportsRemoteAccess: Boolean = true;
    attribute sessionTimeout: Second = 900.0;

    port gatewayApi: IpClientPort;
  }

  part def OpenWebNetAutomationSystem {
    doc /* Primary function: provide a high-level home and building automation system based on OpenWebNet that supervises, translates, and routes user intents and device events so that lighting, climate, security, and energy devices can be controlled and monitored through a common OpenWebNet communication infrastructure. */

    attribute systemName: String = "Integrated OpenWebNet Automation System";
    attribute supportedProtocol: String = "OpenWebNet";
    attribute nominalBusVoltage: Volt = 27.0;
    attribute maximumUserCommandResponseTime: Second = 2.0;
    attribute minimumOperationalAvailability: Percent = 99.0;

    part gateway: OpenWebNetGateway {
      attribute ipAddress = "192.168.1.35";
    }

    part bus: OpenWebNetAutomationBus;

    part lighting: LightingController {
      attribute controllerAddress.area = 1;
      attribute controllerAddress.point = 11;
      attribute controllerAddress.interfaceId = 0;
    }

    part climate: ClimateController {
      attribute controllerAddress.area = 2;
      attribute controllerAddress.point = 1;
      attribute controllerAddress.interfaceId = 0;
    }

    part security: SecurityController {
      attribute controllerAddress.area = 3;
      attribute controllerAddress.point = 1;
      attribute controllerAddress.interfaceId = 0;
    }

    part energyMeter: EnergyMeter {
      attribute meterAddress.area = 4;
      attribute meterAddress.point = 1;
      attribute meterAddress.interfaceId = 0;
    }

    part scenarioKeypad: WallScenarioKeypad {
      attribute keypadAddress.area = 5;
      attribute keypadAddress.point = 1;
      attribute keypadAddress.interfaceId = 0;
    }

    part mobileApp: MobileApplication;

    connect gateway.fieldBus to bus.gatewayDrop;
    connect lighting.bus to bus.lightingDrop;
    connect climate.bus to bus.climateDrop;
    connect security.bus to bus.securityDrop;
    connect energyMeter.bus to bus.energyDrop;
    connect scenarioKeypad.bus to bus.auxiliaryDrop;
    connect mobileApp.gatewayApi to gateway.clientApi;

    perform action systemSceneExecution: ExecuteScene;
    perform action commandEncoding: EncodeCommandToFrame;
    perform action eventDecoding: DecodeFrameToEvent;
    perform action eventPublication: PublishEventToClient;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The OpenWebNetAutomationSystem shall provide a unified high-level automation function by accepting user intents, converting them into OpenWebNet commands, routing them to addressed OpenWebNet devices, collecting device events and status, and reporting outcomes to users and integrations. */

    subject system: OpenWebNetAutomationSystem;

    require constraint {
      system.supportedProtocol == "OpenWebNet"
    }
  }

  requirement def UserCommandResponseRequirement {
    doc /* The system shall acknowledge or complete normal user-initiated scene and device commands within the specified response time. */

    subject system: OpenWebNetAutomationSystem;

    require constraint {
      system.maximumUserCommandResponseTime <= 2.0
    }
  }

  requirement def BusVoltageRequirement {
    doc /* The OpenWebNet field bus shall be operated at the nominal bus voltage required for compatible OpenWebNet field devices. */

    subject system: OpenWebNetAutomationSystem;

    require constraint {
      system.nominalBusVoltage == 27.0
    }
  }

  requirement def FrameValidationRequirement {
    doc /* The gateway shall validate OpenWebNet frame integrity before dispatching commands or publishing events. */

    subject gateway: OpenWebNetGateway;

    require constraint {
      gateway.expectedAckTime <= 500.0
    }
  }

  requirement def DeviceCoverageRequirement {
    doc /* The system shall include OpenWebNet device domains for lighting, climate, security, energy management, and local scenario initiation. */

    subject system: OpenWebNetAutomationSystem;

    require constraint {
      system.lighting.channelCount >= 1 and
      system.climate.allowedSetpointMinimum < system.climate.allowedSetpointMaximum and
      system.security.sirenTimeout >= 60.0 and
      system.energyMeter.maximumMeasuredPower >= 3000.0 and
      system.scenarioKeypad.buttonCount >= 2
    }
  }

  requirement def AvailabilityRequirement {
    doc /* The integrated OpenWebNet automation system shall maintain the minimum specified operational availability for primary monitoring and control functions. */

    subject system: OpenWebNetAutomationSystem;

    require constraint {
      system.minimumOperationalAvailability >= 99.0
    }
  }

  satisfy PrimaryFunctionRequirement by OpenWebNetAutomationSystem;
  satisfy UserCommandResponseRequirement by OpenWebNetAutomationSystem;
  satisfy BusVoltageRequirement by OpenWebNetAutomationSystem;
  satisfy FrameValidationRequirement by OpenWebNetGateway;
  satisfy DeviceCoverageRequirement by OpenWebNetAutomationSystem;
  satisfy AvailabilityRequirement by OpenWebNetAutomationSystem;
}
