package HomeyBasedSmartHomeSystem {

  value def Celsius;
  value def Percent;
  value def Lux;
  value def Watt;
  value def KilowattHour;
  value def Volt;
  value def MilliSecond;
  value def Decibel;
  value def PartsPerMillion;

  enum def DeviceProtocol {
    enum Zigbee;
    enum ZWave;
    enum WiFi;
    enum BluetoothLE;
    enum Matter;
    enum Infrared;
  }

  enum def DeviceMode {
    enum Off;
    enum Standby;
    enum Active;
    enum Fault;
    enum Updating;
  }

  enum def SecurityState {
    enum Disarmed;
    enum ArmedHome;
    enum ArmedAway;
    enum Alarm;
  }

  item def SensorEvent {
    attribute sourceId : String;
    attribute eventName : String;
    attribute timestampUtc : String;
  }

  item def TemperatureReading :> SensorEvent {
    attribute temperature : Celsius;
  }

  item def HumidityReading :> SensorEvent {
    attribute humidity : Percent;
  }

  item def IlluminanceReading :> SensorEvent {
    attribute illuminance : Lux;
  }

  item def MotionEvent :> SensorEvent {
    attribute motionDetected : Boolean;
  }

  item def SmokeEvent :> SensorEvent {
    attribute smokeDetected : Boolean;
    attribute carbonMonoxide : PartsPerMillion;
  }

  item def EnergyReading :> SensorEvent {
    attribute power : Watt;
    attribute accumulatedEnergy : KilowattHour;
    attribute voltage : Volt;
  }

  item def DeviceCommand {
    attribute targetId : String;
    attribute commandName : String;
    attribute requestedBy : String;
    attribute priority : Integer;
  }

  item def LightCommand :> DeviceCommand {
    attribute on : Boolean;
    attribute brightness : Percent;
    attribute colorTemperature : Celsius;
  }

  item def ThermostatCommand :> DeviceCommand {
    attribute targetTemperature : Celsius;
    attribute ecoMode : Boolean;
  }

  item def LockCommand :> DeviceCommand {
    attribute lockRequested : Boolean;
  }

  item def Notification {
    attribute recipient : String;
    attribute title : String;
    attribute body : String;
    attribute urgency : Integer;
  }

  item def AutomationFlow {
    attribute flowId : String;
    attribute name : String;
    attribute enabled : Boolean;
    attribute triggerEventName : String;
    attribute conditionExpression : String;
    attribute actionExpression : String;
  }

  port def WirelessDevicePort {
    attribute protocol : DeviceProtocol;
    attribute linkLatency : MilliSecond;
    in item command : DeviceCommand;
    out item event : SensorEvent;
  }

  port def SensorOutputPort {
    out item event : SensorEvent;
  }

  port def ActuatorInputPort {
    in item command : DeviceCommand;
  }

  port def AppServicePort {
    in item notification : Notification;
    out item command : DeviceCommand;
  }

  port def CloudServicePort {
    in item telemetry : SensorEvent;
    out item remoteCommand : DeviceCommand;
  }

  port def LocalNetworkPort {
    in item inboundCommand : DeviceCommand;
    out item outboundEvent : SensorEvent;
  }

  action def RegisterDevice {
    in item discoveredProtocol : DeviceProtocol;
    in item deviceIdentifier : String;
    out item registeredDeviceIdentifier : String;
  }

  action def EvaluateAutomationFlow {
    in item event : SensorEvent;
    in item flow : AutomationFlow;
    out item command : DeviceCommand;
    out item notification : Notification;
  }

  action def DispatchCommand {
    in item command : DeviceCommand;
    out item delivered : Boolean;
  }

  action def SendUserNotification {
    in item notification : Notification;
    out item acknowledged : Boolean;
  }

  action def MonitorEnergyUse {
    in item energy : EnergyReading;
    out item notification : Notification;
  }

  state def HomeyHubStateMachine {
    state Initializing;
    state DiscoveringDevices;
    state NormalAutomation;
    state RemoteAccessEnabled;
    state DegradedNetwork;
    state FirmwareUpdating;
    state FailSafeAlarm;

    transition first Initializing;
    transition Initializing then DiscoveringDevices;
    transition DiscoveringDevices then NormalAutomation;
    transition NormalAutomation then RemoteAccessEnabled;
    transition RemoteAccessEnabled then NormalAutomation;
    transition NormalAutomation then DegradedNetwork;
    transition DegradedNetwork then NormalAutomation;
    transition NormalAutomation then FirmwareUpdating;
    transition FirmwareUpdating then Initializing;
    transition NormalAutomation then FailSafeAlarm;
    transition FailSafeAlarm then NormalAutomation;
  }

  part def HomeyHub {
    attribute hubId : String;
    attribute installedFirmwareVersion : String;
    attribute maximumFlows : Integer;
    attribute localProcessingEnabled : Boolean;
    attribute cloudBackupEnabled : Boolean;
    attribute operatingMode : DeviceMode;

    port zigbee : WirelessDevicePort {
      attribute protocol = DeviceProtocol::Zigbee;
    }

    port zwave : WirelessDevicePort {
      attribute protocol = DeviceProtocol::ZWave;
    }

    port wifi : WirelessDevicePort {
      attribute protocol = DeviceProtocol::WiFi;
    }

    port bluetooth : WirelessDevicePort {
      attribute protocol = DeviceProtocol::BluetoothLE;
    }

    port matter : WirelessDevicePort {
      attribute protocol = DeviceProtocol::Matter;
    }

    port appApi : AppServicePort;
    port cloudApi : CloudServicePort;
    port localNetwork : LocalNetworkPort;

    perform action registerDevice : RegisterDevice;
    perform action evaluateAutomation : EvaluateAutomationFlow;
    perform action dispatchCommand : DispatchCommand;
    perform action notifyUser : SendUserNotification;
    perform action monitorEnergy : MonitorEnergyUse;

    exhibit state hubStates : HomeyHubStateMachine;
  }

  part def MobileApp {
    attribute authenticatedUser : String;
    attribute pushNotificationsEnabled : Boolean;
    port hubControl : AppServicePort;
  }

  part def HomeyCloud {
    attribute remoteAccessAvailable : Boolean;
    attribute backupRetentionDays : Integer;
    port relay : CloudServicePort;
  }

  part def SmartLight {
    attribute deviceId : String;
    attribute mode : DeviceMode;
    attribute brightness : Percent;
    attribute powerConsumption : Watt;
    port wireless : WirelessDevicePort;
  }

  part def SmartThermostat {
    attribute deviceId : String;
    attribute mode : DeviceMode;
    attribute currentTemperature : Celsius;
    attribute targetTemperature : Celsius;
    attribute humidity : Percent;
    port wireless : WirelessDevicePort;
  }

  part def MotionSensor {
    attribute deviceId : String;
    attribute mode : DeviceMode;
    attribute batteryLevel : Percent;
    attribute occupied : Boolean;
    port sensor : WirelessDevicePort;
  }

  part def SmartLock {
    attribute deviceId : String;
    attribute mode : DeviceMode;
    attribute locked : Boolean;
    attribute batteryLevel : Percent;
    port wireless : WirelessDevicePort;
  }

  part def EnergyMeter {
    attribute deviceId : String;
    attribute mode : DeviceMode;
    attribute instantaneousPower : Watt;
    attribute dailyEnergy : KilowattHour;
    attribute lineVoltage : Volt;
    port sensor : WirelessDevicePort;
  }

  part def SmokeAndCOSensor {
    attribute deviceId : String;
    attribute mode : DeviceMode;
    attribute alarmSoundLevel : Decibel;
    attribute carbonMonoxide : PartsPerMillion;
    attribute batteryLevel : Percent;
    port sensor : WirelessDevicePort;
  }

  part def HomeyBasedSmartHome {
    attribute primaryFunction : String = "Coordinate smart home devices through a Homey hub so that sensor events, user commands, and automation flows produce secure, energy-aware, and comfort-oriented actions across the home.";

    part hub : HomeyHub {
      attribute hubId = "homey-main-hub";
      attribute maximumFlows = 500;
      attribute localProcessingEnabled = true;
      attribute cloudBackupEnabled = true;
    }

    part app : MobileApp {
      attribute pushNotificationsEnabled = true;
    }

    part cloud : HomeyCloud {
      attribute remoteAccessAvailable = true;
      attribute backupRetentionDays = 30;
    }

    part livingRoomLight : SmartLight {
      attribute deviceId = "light-living-room";
      attribute brightness = 70;
      attribute powerConsumption = 9;
    }

    part hallwayLight : SmartLight {
      attribute deviceId = "light-hallway";
      attribute brightness = 60;
      attribute powerConsumption = 7;
    }

    part thermostat : SmartThermostat {
      attribute deviceId = "thermostat-main";
      attribute targetTemperature = 21;
    }

    part entryMotion : MotionSensor {
      attribute deviceId = "motion-entry";
      attribute batteryLevel = 92;
    }

    part frontDoorLock : SmartLock {
      attribute deviceId = "lock-front-door";
      attribute locked = true;
      attribute batteryLevel = 81;
    }

    part wholeHomeEnergyMeter : EnergyMeter {
      attribute deviceId = "meter-main-panel";
      attribute dailyEnergy = 18;
      attribute lineVoltage = 240;
    }

    part kitchenSmokeCO : SmokeAndCOSensor {
      attribute deviceId = "safety-kitchen";
      attribute alarmSoundLevel = 85;
      attribute batteryLevel = 96;
    }

    connect hub.appApi to app.hubControl;
    connect hub.cloudApi to cloud.relay;
    connect hub.zigbee to livingRoomLight.wireless;
    connect hub.zigbee to hallwayLight.wireless;
    connect hub.zwave to entryMotion.sensor;
    connect hub.zwave to frontDoorLock.wireless;
    connect hub.wifi to thermostat.wireless;
    connect hub.matter to wholeHomeEnergyMeter.sensor;
    connect hub.zigbee to kitchenSmokeCO.sensor;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : HomeyBasedSmartHome;
    require constraint {
      system.primaryFunction == "Coordinate smart home devices through a Homey hub so that sensor events, user commands, and automation flows produce secure, energy-aware, and comfort-oriented actions across the home."
    }
  }

  requirement def LocalAutomationRequirement {
    subject hub : HomeyHub;
    require constraint {
      hub.localProcessingEnabled == true
    }
  }

  requirement def RemoteAccessRequirement {
    subject cloud : HomeyCloud;
    require constraint {
      cloud.remoteAccessAvailable == true
    }
  }

  requirement def EnergyAwarenessRequirement {
    subject meter : EnergyMeter;
    require constraint {
      meter.dailyEnergy <= 60
    }
  }

  requirement def SecurityRequirement {
    subject lock : SmartLock;
    require constraint {
      lock.batteryLevel >= 20
    }
  }

  requirement def SafetyNotificationRequirement {
    subject detector : SmokeAndCOSensor;
    require constraint {
      detector.alarmSoundLevel >= 85
    }
  }

  requirement def AutomationCapacityRequirement {
    subject hub : HomeyHub;
    require constraint {
      hub.maximumFlows >= 100
    }
  }

  requirement def ComfortControlRequirement {
    subject thermostat : SmartThermostat;
    require constraint {
      thermostat.targetTemperature >= 16 and thermostat.targetTemperature <= 26
    }
  }

}