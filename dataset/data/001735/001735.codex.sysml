package XiaomiSmartHomeSystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def TemperatureCelsius :> Real {
    unit = "degC";
  }

  attribute def RelativeHumidityPercent :> Real {
    unit = "%";
  }

  attribute def IlluminanceLux :> Real {
    unit = "lx";
  }

  attribute def PowerWatt :> Real {
    unit = "W";
  }

  attribute def EnergyKiloWattHour :> Real {
    unit = "kW.h";
  }

  attribute def TimeSecond :> Real {
    unit = "s";
  }

  attribute def DataRateMbps :> Real {
    unit = "Mbit/s";
  }

  attribute def BatteryPercent :> Real {
    unit = "%";
  }

  attribute def AirQualityIndex :> Real {
    unit = "AQI";
  }

  enum def ConnectivityProtocol {
    enum WiFi;
    enum Zigbee;
    enum BluetoothMesh;
    enum Thread;
    enum Infrared;
    enum Ethernet;
    enum Cellular;
  }

  enum def DeviceMode {
    enum Off;
    enum Standby;
    enum Active;
    enum Eco;
    enum Fault;
  }

  enum def OccupancyState {
    enum Vacant;
    enum Occupied;
    enum Unknown;
  }

  enum def SecurityState {
    enum Disarmed;
    enum ArmedHome;
    enum ArmedAway;
    enum Alarm;
  }

  item def SensorReading {
    attribute timestamp : TimeSecond;
    attribute sourceDeviceId : String;
  }

  item def TemperatureReading :> SensorReading {
    attribute temperature : TemperatureCelsius;
  }

  item def HumidityReading :> SensorReading {
    attribute humidity : RelativeHumidityPercent;
  }

  item def MotionReading :> SensorReading {
    attribute occupied : Boolean;
  }

  item def DoorWindowReading :> SensorReading {
    attribute open : Boolean;
  }

  item def AirQualityReading :> SensorReading {
    attribute pm25MicrogramsPerCubicMeter : Real;
    attribute co2Ppm : Real;
    attribute aqi : AirQualityIndex;
  }

  item def PowerReading :> SensorReading {
    attribute instantaneousPower : PowerWatt;
    attribute accumulatedEnergy : EnergyKiloWattHour;
  }

  item def CommandMessage {
    attribute commandId : String;
    attribute targetDeviceId : String;
    attribute issuedAt : TimeSecond;
    attribute authenticated : Boolean;
  }

  item def LightCommand :> CommandMessage {
    attribute on : Boolean;
    attribute brightnessPercent : Real;
    attribute colorTemperatureKelvin : Real;
  }

  item def ClimateCommand :> CommandMessage {
    attribute targetTemperature : TemperatureCelsius;
    attribute fanSpeedPercent : Real;
    attribute mode : DeviceMode;
  }

  item def SecurityCommand :> CommandMessage {
    attribute requestedState : SecurityState;
  }

  item def SceneCommand :> CommandMessage {
    attribute sceneName : String;
  }

  item def Notification {
    attribute notificationId : String;
    attribute severity : String;
    attribute message : String;
    attribute createdAt : TimeSecond;
  }

  port def WirelessNetworkPort {
    in item receivedCommand : CommandMessage;
    out item sentReading : SensorReading;
    out item sentNotification : Notification;
  }

  port def SensorDataPort {
    out item reading : SensorReading;
  }

  port def ActuatorCommandPort {
    in item command : CommandMessage;
  }

  port def PowerPort {
    in attribute supplyVoltage : Real;
    in attribute availablePower : PowerWatt;
    out attribute consumedPower : PowerWatt;
  }

  part def XiaomiSmartHome {
    attribute primaryFunction : String = "Coordinate Xiaomi smart devices, sensors, automation scenes, and user commands to monitor home conditions, improve comfort, manage energy use, and protect occupants through centralized intelligent control.";
    attribute maxSupportedDevices : Integer = 128;
    attribute localAutomationLatency : TimeSecond = 0.2;
    attribute cloudCommandLatency : TimeSecond = 2.0;
    attribute nominalNetworkRate : DataRateMbps = 100.0;
    attribute securityState : SecurityState = SecurityState::Disarmed;
    attribute occupancyState : OccupancyState = OccupancyState::Unknown;

    port internet : WirelessNetworkPort;
    port mainsPower : PowerPort;

    part hub : SmartHomeHub;
    part mobileApp : MiHomeMobileApp;
    part cloud : XiaomiCloudService;
    part livingRoom : SmartRoom {
      attribute roomName = "Living Room";
      attribute targetTemperature = 22.0;
      attribute targetIlluminance = 350.0;
    }
    part bedroom : SmartRoom {
      attribute roomName = "Bedroom";
      attribute targetTemperature = 20.0;
      attribute targetIlluminance = 120.0;
    }
    part kitchen : SmartRoom {
      attribute roomName = "Kitchen";
      attribute targetTemperature = 21.0;
      attribute targetIlluminance = 500.0;
    }
    part entryway : SecurityZone {
      attribute zoneName = "Entryway";
    }
    part energyManager : EnergyManager;
    part automationEngine : AutomationEngine;
    part notificationManager : NotificationManager;

    connect mainsPower to hub.power;
    connect hub.network to internet;
    connect hub.cloudLink to cloud.network;
    connect mobileApp.cloudLink to cloud.network;
    connect automationEngine.commandOut to hub.network;
    connect hub.network to livingRoom.roomNetwork;
    connect hub.network to bedroom.roomNetwork;
    connect hub.network to kitchen.roomNetwork;
    connect hub.network to entryway.zoneNetwork;
    connect livingRoom.powerTelemetry to energyManager.powerInput;
    connect bedroom.powerTelemetry to energyManager.powerInput;
    connect kitchen.powerTelemetry to energyManager.powerInput;
    connect entryway.securityEvents to notificationManager.eventInput;
    connect automationEngine.notificationOut to notificationManager.eventInput;
    connect notificationManager.notificationOut to mobileApp.notificationIn;

    action operateSmartHome {
      first start;
      then collectSensorReadings;
      then evaluateAutomationRules;
      then dispatchDeviceCommands;
      then updateUserStatus;
      then start;

      action collectSensorReadings {
        out item readings : SensorReading;
      }

      action evaluateAutomationRules {
        in item readings : SensorReading;
        out item commands : CommandMessage;
        out item alerts : Notification;
      }

      action dispatchDeviceCommands {
        in item commands : CommandMessage;
      }

      action updateUserStatus {
        in item alerts : Notification;
      }
    }

    state def SmartHomeOperatingState {
      entry action initializeHub;
      state Initializing;
      state NormalMonitoring;
      state AutomatingComfort;
      state EnergySaving;
      state SecurityAlert;
      state DegradedNetwork;
      state MaintenanceRequired;

      transition first Initializing;
      transition Initializing to NormalMonitoring
        accept after 10.0 [hub.isOnline];

      transition NormalMonitoring to AutomatingComfort
        accept when automationEngine.pendingComfortAction;

      transition AutomatingComfort to NormalMonitoring
        accept when not automationEngine.pendingComfortAction;

      transition NormalMonitoring to EnergySaving
        accept when energyManager.totalInstantaneousPower > 3500.0;

      transition EnergySaving to NormalMonitoring
        accept when energyManager.totalInstantaneousPower < 2500.0;

      transition NormalMonitoring to SecurityAlert
        accept when securityState == SecurityState::Alarm;

      transition SecurityAlert to NormalMonitoring
        accept when securityState != SecurityState::Alarm;

      transition NormalMonitoring to DegradedNetwork
        accept when not hub.cloudReachable;

      transition DegradedNetwork to NormalMonitoring
        accept when hub.cloudReachable;

      transition NormalMonitoring to MaintenanceRequired
        accept when hub.deviceFaultCount > 0;
    }
  }

  part def SmartHomeHub {
    attribute deviceId : String;
    attribute mode : DeviceMode = DeviceMode::Active;
    attribute isOnline : Boolean = true;
    attribute cloudReachable : Boolean = true;
    attribute deviceFaultCount : Integer = 0;
    attribute zigbeeProtocol : ConnectivityProtocol = ConnectivityProtocol::Zigbee;
    attribute wifiProtocol : ConnectivityProtocol = ConnectivityProtocol::WiFi;
    attribute bluetoothProtocol : ConnectivityProtocol = ConnectivityProtocol::BluetoothMesh;

    port power : PowerPort;
    port network : WirelessNetworkPort;
    port cloudLink : WirelessNetworkPort;

    action routeMessage {
      in item inbound : CommandMessage;
      out item outbound : CommandMessage;
    }

    action synchronizeWithCloud {
      in item localReadings : SensorReading;
      out item remoteCommands : CommandMessage;
    }
  }

  part def MiHomeMobileApp {
    attribute signedInUserId : String;
    attribute remoteAccessEnabled : Boolean = true;
    attribute pushNotificationsEnabled : Boolean = true;

    port cloudLink : WirelessNetworkPort;
    port notificationIn {
      in item notification : Notification;
    }

    action issueSceneCommand {
      in attribute sceneName : String;
      out item sceneCommand : SceneCommand;
    }

    action displayHomeStatus {
      in item readings : SensorReading;
      in item notifications : Notification;
    }
  }

  part def XiaomiCloudService {
    attribute encryptedStorageEnabled : Boolean = true;
    attribute remoteAutomationEnabled : Boolean = true;
    attribute accountRegion : String = "US";

    port network : WirelessNetworkPort;

    action authenticateUserCommand {
      in item command : CommandMessage;
      out item authenticatedCommand : CommandMessage;
    }

    action persistTelemetry {
      in item readings : SensorReading;
    }
  }

  part def SmartRoom {
    attribute roomName : String;
    attribute targetTemperature : TemperatureCelsius;
    attribute targetIlluminance : IlluminanceLux;
    attribute occupancy : OccupancyState = OccupancyState::Unknown;

    port roomNetwork : WirelessNetworkPort;
    port powerTelemetry {
      out item reading : PowerReading;
    }

    part temperatureHumiditySensor : TemperatureHumiditySensor;
    part motionSensor : MotionSensor;
    part smartLight : XiaomiSmartLight;
    part smartPlug : XiaomiSmartPlug;
    part airPurifier : XiaomiAirPurifier;
    part climateController : XiaomiClimateController;

    connect roomNetwork to temperatureHumiditySensor.network;
    connect roomNetwork to motionSensor.network;
    connect roomNetwork to smartLight.network;
    connect roomNetwork to smartPlug.network;
    connect roomNetwork to airPurifier.network;
    connect roomNetwork to climateController.network;
    connect smartPlug.powerTelemetry to powerTelemetry;

    action maintainComfort {
      in item temperatureReading : TemperatureReading;
      in item motionReading : MotionReading;
      out item lightCommand : LightCommand;
      out item climateCommand : ClimateCommand;
    }

    state def RoomAutomationState {
      state VacantEco;
      state OccupiedComfort;
      state NightQuiet;
      state AirCleaning;

      transition first VacantEco;
      transition VacantEco to OccupiedComfort
        accept when occupancy == OccupancyState::Occupied;
      transition OccupiedComfort to VacantEco
        accept after 900.0 [occupancy == OccupancyState::Vacant];
      transition OccupiedComfort to NightQuiet
        accept when roomName == "Bedroom";
      transition OccupiedComfort to AirCleaning
        accept when airPurifier.currentAqi > 100.0;
      transition AirCleaning to OccupiedComfort
        accept when airPurifier.currentAqi <= 50.0;
    }
  }

  part def SecurityZone {
    attribute zoneName : String;
    attribute armed : Boolean = false;

    port zoneNetwork : WirelessNetworkPort;
    port securityEvents {
      out item notification : Notification;
    }

    part doorSensor : DoorWindowSensor;
    part camera : XiaomiSecurityCamera;
    part siren : XiaomiSiren;

    connect zoneNetwork to doorSensor.network;
    connect zoneNetwork to camera.network;
    connect zoneNetwork to siren.network;

    action evaluateIntrusion {
      in item doorState : DoorWindowReading;
      in item motionState : MotionReading;
      out item alert : Notification;
      out item sirenCommand : SecurityCommand;
    }
  }

  part def TemperatureHumiditySensor {
    attribute deviceId : String;
    attribute protocol : ConnectivityProtocol = ConnectivityProtocol::Zigbee;
    attribute batteryLevel : BatteryPercent = 100.0;
    attribute samplePeriod : TimeSecond = 60.0;
    attribute measuredTemperature : TemperatureCelsius;
    attribute measuredHumidity : RelativeHumidityPercent;

    port network : WirelessNetworkPort;
    port sensing : SensorDataPort;

    action measureEnvironment {
      out item temperature : TemperatureReading;
      out item humidity : HumidityReading;
    }
  }

  part def MotionSensor {
    attribute deviceId : String;
    attribute protocol : ConnectivityProtocol = ConnectivityProtocol::Zigbee;
    attribute batteryLevel : BatteryPercent = 100.0;
    attribute detectionRangeMeter : Real = 7.0;
    attribute motionDetected : Boolean = false;

    port network : WirelessNetworkPort;
    port sensing : SensorDataPort;

    action detectOccupancy {
      out item motion : MotionReading;
    }
  }

  part def DoorWindowSensor {
    attribute deviceId : String;
    attribute protocol : ConnectivityProtocol = ConnectivityProtocol::Zigbee;
    attribute batteryLevel : BatteryPercent = 100.0;
    attribute open : Boolean = false;

    port network : WirelessNetworkPort;
    port sensing : SensorDataPort;

    action reportOpenClose {
      out item state : DoorWindowReading;
    }
  }

  part def XiaomiSmartLight {
    attribute deviceId : String;
    attribute protocol : ConnectivityProtocol = ConnectivityProtocol::WiFi;
    attribute mode : DeviceMode = DeviceMode::Standby;
    attribute brightnessPercent : Real = 0.0;
    attribute colorTemperatureKelvin : Real = 3000.0;
    attribute ratedPower : PowerWatt = 9.0;

    port network : WirelessNetworkPort;
    port commandIn : ActuatorCommandPort;
    port power : PowerPort;

    action setLighting {
      in item command : LightCommand;
    }

    state def LightState {
      state Off;
      state On;
      state Adaptive;

      transition first Off;
      transition Off to On accept when brightnessPercent > 0.0;
      transition On to Off accept when brightnessPercent == 0.0;
      transition On to Adaptive accept when mode == DeviceMode::Eco;
      transition Adaptive to On accept when mode == DeviceMode::Active;
    }
  }

  part def XiaomiSmartPlug {
    attribute deviceId : String;
    attribute protocol : ConnectivityProtocol = ConnectivityProtocol::WiFi;
    attribute relayClosed : Boolean = false;
    attribute instantaneousPower : PowerWatt = 0.0;
    attribute accumulatedEnergy : EnergyKiloWattHour = 0.0;
    attribute maxLoadPower : PowerWatt = 2300.0;

    port network : WirelessNetworkPort;
    port commandIn : ActuatorCommandPort;
    port powerTelemetry {
      out item reading : PowerReading;
    }

    action switchLoad {
      in item command : CommandMessage;
    }

    action measurePower {
      out item reading : PowerReading;
    }
  }

  part def XiaomiAirPurifier {
    attribute deviceId : String;
    attribute protocol : ConnectivityProtocol = ConnectivityProtocol::WiFi;
    attribute mode : DeviceMode = DeviceMode::Standby;
    attribute currentAqi : AirQualityIndex = 25.0;
    attribute fanSpeedPercent : Real = 0.0;
    attribute ratedPower : PowerWatt = 45.0;

    port network : WirelessNetworkPort;
    port commandIn : ActuatorCommandPort;
    port airQualityOut : SensorDataPort;

    action measureAirQuality {
      out item reading : AirQualityReading;
    }

    action purifyAir {
      in item command : ClimateCommand;
    }
  }

  part def XiaomiClimateController {
    attribute deviceId : String;
    attribute protocol : ConnectivityProtocol = ConnectivityProtocol::Infrared;
    attribute targetTemperature : TemperatureCelsius = 22.0;
    attribute fanSpeedPercent : Real = 40.0;
    attribute mode : DeviceMode = DeviceMode::Eco;

    port network : WirelessNetworkPort;
    port commandIn : ActuatorCommandPort;

    action controlAirConditioner {
      in item command : ClimateCommand;
    }
  }

  part def XiaomiSecurityCamera {
    attribute deviceId : String;
    attribute protocol : ConnectivityProtocol = ConnectivityProtocol::WiFi;
    attribute recordingEnabled : Boolean = false;
    attribute motionTrackingEnabled : Boolean = true;
    attribute nightVisionEnabled : Boolean = true;
    attribute powerConsumption : PowerWatt = 5.0;

    port network : WirelessNetworkPort;
    port motionOut : SensorDataPort;

    action recordEventClip {
      in item trigger : MotionReading;
      out item alert : Notification;
    }
  }

  part def XiaomiSiren {
    attribute deviceId : String;
    attribute protocol : ConnectivityProtocol = ConnectivityProtocol::Zigbee;
    attribute active : Boolean = false;
    attribute soundLevelDb : Real = 95.0;

    port network : WirelessNetworkPort;
    port commandIn : ActuatorCommandPort;

    action soundAlarm {
      in item command : SecurityCommand;
    }
  }

  part def EnergyManager {
    attribute totalInstantaneousPower : PowerWatt = 0.0;
    attribute dailyEnergy : EnergyKiloWattHour = 0.0;
    attribute peakPowerLimit : PowerWatt = 3500.0;

    port powerInput {
      in item reading : PowerReading;
    }

    action calculateEnergyUse {
      in item readings : PowerReading;
      out attribute totalPower : PowerWatt;
      out attribute dailyTotal : EnergyKiloWattHour;
    }

    action reduceNonessentialLoads {
      out item commands : CommandMessage;
    }
  }

  part def AutomationEngine {
    attribute pendingComfortAction : Boolean = false;
    attribute awayModeEnabled : Boolean = false;
    attribute sleepSceneEnabled : Boolean = false;

    port commandOut : WirelessNetworkPort;
    port notificationOut {
      out item notification : Notification;
    }

    action executeMorningScene {
      out item lightCommand : LightCommand;
      out item climateCommand : ClimateCommand;
    }

    action executeAwayScene {
      out item securityCommand : SecurityCommand;
      out item lightCommand : LightCommand;
      out item plugCommand : CommandMessage;
    }

    action executeSleepScene {
      out item lightCommand : LightCommand;
      out item climateCommand : ClimateCommand;
      out item securityCommand : SecurityCommand;
    }
  }

  part def NotificationManager {
    attribute lastNotificationSeverity : String = "info";

    port eventInput {
      in item notification : Notification;
    }

    port notificationOut {
      out item notification : Notification;
    }

    action sendPushNotification {
      in item event : Notification;
      out item push : Notification;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The Xiaomi Smart Home shall provide centralized monitoring and automated control of connected home devices to improve comfort, security, energy efficiency, and remote accessibility. */
    subject smartHome : XiaomiSmartHome;
    require constraint {
      smartHome.maxSupportedDevices >= 64
    }
  }

  requirement def LocalAutomationLatencyRequirement {
    doc /* Safety and comfort automation rules shall execute locally within 0.5 seconds when the hub and device network are available. */
    subject smartHome : XiaomiSmartHome;
    require constraint {
      smartHome.localAutomationLatency <= 0.5
    }
  }

  requirement def EnergyVisibilityRequirement {
    doc /* The system shall measure and report smart plug energy consumption for room-level and daily energy awareness. */
    subject manager : EnergyManager;
    require constraint {
      manager.peakPowerLimit <= 3500.0
    }
  }

  requirement def SecurityAlertRequirement {
    doc /* When armed, unauthorized entry detection shall activate a siren, start camera recording, and notify the mobile application. */
    subject zone : SecurityZone;
    require constraint {
      zone.armed implies zone.siren.soundLevelDb >= 90.0
    }
  }

  requirement def ComfortAutomationRequirement {
    doc /* Occupied rooms shall automatically adjust lighting and climate according to target illuminance and target temperature. */
    subject room : SmartRoom;
    require constraint {
      room.targetIlluminance > 0.0 and room.targetTemperature >= 16.0 and room.targetTemperature <= 28.0
    }
  }

  satisfy PrimaryFunctionRequirement by XiaomiSmartHome;
  satisfy LocalAutomationLatencyRequirement by XiaomiSmartHome;
  satisfy EnergyVisibilityRequirement by EnergyManager;
  satisfy SecurityAlertRequirement by SecurityZone;
  satisfy ComfortAutomationRequirement by SmartRoom;
}