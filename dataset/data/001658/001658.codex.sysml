package HomeOSModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Percent : Real {
    unit = "%";
  }

  attribute def Celsius : Real {
    unit = "degC";
  }

  attribute def Lux : Real {
    unit = "lx";
  }

  attribute def Watt : Real {
    unit = "W";
  }

  attribute def KilowattHour : Real {
    unit = "kW*h";
  }

  attribute def Seconds : Real {
    unit = "s";
  }

  attribute def Milliseconds : Real {
    unit = "ms";
  }

  attribute def IPv4Address : String;
  attribute def DeviceId : String;
  attribute def UserId : String;

  enum def SecurityMode {
    enum off;
    enum home;
    enum away;
    enum night;
  }

  enum def DeviceHealth {
    enum nominal;
    enum degraded;
    enum offline;
    enum faulted;
  }

  enum def CommandPriority {
    enum routine;
    enum userRequested;
    enum safetyCritical;
  }

  item def SensorReading {
    attribute sourceId : DeviceId;
    attribute timestamp : String;
    attribute health : DeviceHealth;
  }

  item def TemperatureReading specializes SensorReading {
    attribute value : Celsius;
  }

  item def OccupancyReading specializes SensorReading {
    attribute occupied : Boolean;
    attribute confidence : Percent;
  }

  item def IlluminanceReading specializes SensorReading {
    attribute value : Lux;
  }

  item def PowerReading specializes SensorReading {
    attribute instantaneousPower : Watt;
    attribute accumulatedEnergy : KilowattHour;
  }

  item def SecurityEvent specializes SensorReading {
    attribute zoneId : String;
    attribute intrusionDetected : Boolean;
    attribute tamperDetected : Boolean;
  }

  item def UserCommand {
    attribute commandId : String;
    attribute requester : UserId;
    attribute targetDevice : DeviceId;
    attribute priority : CommandPriority;
    attribute issuedAt : String;
    attribute payload : String;
  }

  item def AutomationCommand {
    attribute commandId : String;
    attribute targetDevice : DeviceId;
    attribute priority : CommandPriority;
    attribute issuedAt : String;
    attribute payload : String;
  }

  item def ActuatorStatus {
    attribute deviceId : DeviceId;
    attribute health : DeviceHealth;
    attribute acceptedLastCommand : Boolean;
    attribute measuredPower : Watt;
  }

  item def Notification {
    attribute recipient : UserId;
    attribute severity : CommandPriority;
    attribute message : String;
    attribute createdAt : String;
  }

  port def SensorDataPort {
    out item reading : SensorReading;
  }

  port def CommandInputPort {
    in item command : AutomationCommand;
  }

  port def UserCommandPort {
    in item command : UserCommand;
  }

  port def StatusPort {
    out item status : ActuatorStatus;
  }

  port def NotificationPort {
    out item notification : Notification;
  }

  port def NetworkPort {
    in item inboundCommand : UserCommand;
    out item outboundNotification : Notification;
  }

  part def HomeOSController {
    attribute controllerId : DeviceId;
    attribute softwareVersion : String;
    attribute ipAddress : IPv4Address;
    attribute controlLoopPeriod : Seconds = 2.0 [s];
    attribute maxCommandLatency : Milliseconds = 250.0 [ms];

    port userApi : UserCommandPort;
    port sensorBus : SensorDataPort;
    port actuatorBus : CommandInputPort;
    port notificationBus : NotificationPort;

    part automationEngine : AutomationEngine;
    part securityManager : SecurityManager;
    part energyManager : EnergyManager;
    part comfortManager : ComfortManager;
    part deviceRegistry : DeviceRegistry;

    state def ControllerState {
      entry action initializeRegistry;
      state booting;
      state operational;
      state degraded;
      state emergency;
      state shutdown;

      transition first booting;
      transition booting_to_operational
        first booting
        then operational
        accept after 5.0 [s];

      transition operational_to_degraded
        first operational
        then degraded
        accept DeviceHealth::degraded;

      transition degraded_to_operational
        first degraded
        then operational
        accept DeviceHealth::nominal;

      transition any_to_emergency
        first operational
        then emergency
        accept SecurityEvent;

      transition emergency_to_operational
        first emergency
        then operational
        accept UserCommand;

      transition operational_to_shutdown
        first operational
        then shutdown
        accept UserCommand;
    }

    action def SenseAnalyzeActuate {
      in item readings : SensorReading;
      in item userRequests : UserCommand;
      out item commands : AutomationCommand;
      out item notices : Notification;

      action validateInput;
      action updateHomeState;
      action evaluateRules;
      action resolveConflicts;
      action dispatchCommands;
      action publishNotifications;

      flow validateInput then updateHomeState;
      flow updateHomeState then evaluateRules;
      flow evaluateRules then resolveConflicts;
      flow resolveConflicts then dispatchCommands;
      flow dispatchCommands then publishNotifications;
    }
  }

  part def AutomationEngine {
    attribute enabled : Boolean = true;
    attribute ruleEvaluationPeriod : Seconds = 2.0 [s];

    port sensorInput : SensorDataPort;
    port userInput : UserCommandPort;
    port commandOutput : CommandInputPort;
    port notificationOutput : NotificationPort;

    action def EvaluateHomeAutomation {
      in item temperature : TemperatureReading;
      in item occupancy : OccupancyReading;
      in item light : IlluminanceReading;
      in item security : SecurityEvent;
      out item actuatorCommand : AutomationCommand;

      action selectApplicableRules;
      action calculateDesiredHomeState;
      action createDeviceCommands;

      flow selectApplicableRules then calculateDesiredHomeState;
      flow calculateDesiredHomeState then createDeviceCommands;
    }
  }

  part def SecurityManager {
    attribute mode : SecurityMode = SecurityMode::home;
    attribute alarmDelay : Seconds = 30.0 [s];

    port eventInput : SensorDataPort;
    port alarmCommandOutput : CommandInputPort;
    port alertOutput : NotificationPort;

    state def SecurityState {
      state disarmed;
      state armedHome;
      state armedAway;
      state armedNight;
      state alarmPending;
      state alarmActive;

      transition first disarmed;

      transition disarmed_to_home
        first disarmed
        then armedHome
        accept UserCommand;

      transition disarmed_to_away
        first disarmed
        then armedAway
        accept UserCommand;

      transition disarmed_to_night
        first disarmed
        then armedNight
        accept UserCommand;

      transition armed_to_pending
        first armedAway
        then alarmPending
        accept SecurityEvent;

      transition pending_to_active
        first alarmPending
        then alarmActive
        accept after 30.0 [s];

      transition pending_to_disarmed
        first alarmPending
        then disarmed
        accept UserCommand;

      transition active_to_disarmed
        first alarmActive
        then disarmed
        accept UserCommand;
    }

    action def HandleSecurityEvent {
      in item event : SecurityEvent;
      out item sirenCommand : AutomationCommand;
      out item alert : Notification;
    }
  }

  part def EnergyManager {
    attribute dailyEnergyBudget : KilowattHour = 35.0 [kW*h];
    attribute currentDailyEnergy : KilowattHour;
    attribute peakPowerLimit : Watt = 8000.0 [W];

    port powerInput : SensorDataPort;
    port loadCommandOutput : CommandInputPort;
    port notificationOutput : NotificationPort;

    action def OptimizeEnergyUse {
      in item power : PowerReading;
      out item loadCommands : AutomationCommand;
      out item energyNotice : Notification;

      action forecastDemand;
      action identifyFlexibleLoads;
      action shedOrScheduleLoads;

      flow forecastDemand then identifyFlexibleLoads;
      flow identifyFlexibleLoads then shedOrScheduleLoads;
    }
  }

  part def ComfortManager {
    attribute desiredOccupiedTemperature : Celsius = 21.0 [degC];
    attribute desiredUnoccupiedTemperature : Celsius = 17.0 [degC];
    attribute desiredIlluminance : Lux = 350.0 [lx];

    port comfortSensorInput : SensorDataPort;
    port comfortCommandOutput : CommandInputPort;

    action def MaintainComfort {
      in item temperature : TemperatureReading;
      in item occupancy : OccupancyReading;
      in item illuminance : IlluminanceReading;
      out item hvacCommand : AutomationCommand;
      out item lightingCommand : AutomationCommand;
    }
  }

  part def DeviceRegistry {
    attribute registeredDeviceCount : Integer;
    attribute offlineDeviceCount : Integer;

    action def RegisterDevice {
      in deviceId : DeviceId;
      in ipAddress : IPv4Address;
      out accepted : Boolean;
    }

    action def UpdateDeviceHealth {
      in deviceId : DeviceId;
      in health : DeviceHealth;
    }
  }

  part def SmartThermostat {
    attribute deviceId : DeviceId;
    attribute setpoint : Celsius = 21.0 [degC];
    attribute currentTemperature : Celsius;
    attribute health : DeviceHealth = DeviceHealth::nominal;

    port temperatureOut : SensorDataPort;
    port commandIn : CommandInputPort;
    port statusOut : StatusPort;
  }

  part def OccupancySensor {
    attribute deviceId : DeviceId;
    attribute detectionConfidence : Percent;
    attribute health : DeviceHealth = DeviceHealth::nominal;

    port occupancyOut : SensorDataPort;
  }

  part def SmartLight {
    attribute deviceId : DeviceId;
    attribute brightness : Percent = 0.0 [%];
    attribute powerUse : Watt;
    attribute health : DeviceHealth = DeviceHealth::nominal;

    port lightCommandIn : CommandInputPort;
    port statusOut : StatusPort;
  }

  part def SmartLock {
    attribute deviceId : DeviceId;
    attribute locked : Boolean = true;
    attribute health : DeviceHealth = DeviceHealth::nominal;

    port lockCommandIn : CommandInputPort;
    port statusOut : StatusPort;
  }

  part def DoorWindowSensor {
    attribute deviceId : DeviceId;
    attribute open : Boolean;
    attribute tampered : Boolean = false;
    attribute health : DeviceHealth = DeviceHealth::nominal;

    port securityOut : SensorDataPort;
  }

  part def SmartMeter {
    attribute deviceId : DeviceId;
    attribute instantaneousPower : Watt;
    attribute accumulatedEnergy : KilowattHour;
    attribute health : DeviceHealth = DeviceHealth::nominal;

    port powerOut : SensorDataPort;
  }

  part def Siren {
    attribute deviceId : DeviceId;
    attribute active : Boolean = false;
    attribute acousticPower : Percent = 100.0 [%];

    port sirenCommandIn : CommandInputPort;
    port statusOut : StatusPort;
  }

  part def UserMobileApp {
    attribute userId : UserId;
    attribute authenticated : Boolean;
    attribute sessionTimeout : Seconds = 900.0 [s];

    port network : NetworkPort;
  }

  part def HomeOSBasedSmartHomeSystem {
    doc
    /*
     * Primary function:
     * HomeOS coordinates sensing, automation, user control, security, comfort,
     * and energy management for a connected home by maintaining a current model
     * of home state and issuing timely commands to household devices.
     */

    attribute homeId : String;
    attribute nominalAvailability : Percent = 99.5 [%];

    part controller : HomeOSController {
      attribute controllerId = "homeos-controller-01";
      attribute softwareVersion = "HomeOS 4.2";
      attribute ipAddress = "192.168.1.10";
    }

    part thermostat : SmartThermostat {
      attribute deviceId = "thermostat-main";
    }

    part livingRoomOccupancy : OccupancySensor {
      attribute deviceId = "occupancy-living-room";
    }

    part hallwayDoorSensor : DoorWindowSensor {
      attribute deviceId = "door-front-hallway";
    }

    part kitchenLight : SmartLight {
      attribute deviceId = "light-kitchen-ceiling";
    }

    part frontDoorLock : SmartLock {
      attribute deviceId = "lock-front-door";
    }

    part utilityMeter : SmartMeter {
      attribute deviceId = "meter-main-panel";
    }

    part alarmSiren : Siren {
      attribute deviceId = "siren-hallway";
    }

    part mobileApp : UserMobileApp {
      attribute userId = "homeowner-primary";
    }

    connect thermostat.temperatureOut to controller.sensorBus;
    connect livingRoomOccupancy.occupancyOut to controller.sensorBus;
    connect hallwayDoorSensor.securityOut to controller.sensorBus;
    connect utilityMeter.powerOut to controller.sensorBus;

    connect mobileApp.network.inboundCommand to controller.userApi.command;
    connect controller.notificationBus.notification to mobileApp.network.outboundNotification;

    connect controller.actuatorBus to thermostat.commandIn;
    connect controller.actuatorBus to kitchenLight.lightCommandIn;
    connect controller.actuatorBus to frontDoorLock.lockCommandIn;
    connect controller.actuatorBus to alarmSiren.sirenCommandIn;

    connect controller.automationEngine.sensorInput to controller.sensorBus;
    connect controller.automationEngine.userInput to controller.userApi;
    connect controller.automationEngine.commandOutput to controller.actuatorBus;
    connect controller.automationEngine.notificationOutput to controller.notificationBus;

    connect controller.securityManager.eventInput to controller.sensorBus;
    connect controller.securityManager.alarmCommandOutput to controller.actuatorBus;
    connect controller.securityManager.alertOutput to controller.notificationBus;

    connect controller.energyManager.powerInput to controller.sensorBus;
    connect controller.energyManager.loadCommandOutput to controller.actuatorBus;
    connect controller.energyManager.notificationOutput to controller.notificationBus;

    connect controller.comfortManager.comfortSensorInput to controller.sensorBus;
    connect controller.comfortManager.comfortCommandOutput to controller.actuatorBus;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : HomeOSBasedSmartHomeSystem;

    doc
    /*
     * The system shall provide a unified HomeOS control layer that senses home
     * conditions, evaluates user preferences and automation policies, and
     * commands connected devices to maintain comfort, security, and efficient
     * energy use.
     */
  }

  requirement def CommandLatencyRequirement {
    subject controller : HomeOSController;

    attribute maxAllowedLatency : Milliseconds = 250.0 [ms];

    doc
    /*
     * The HomeOS controller shall dispatch non-emergency automation commands
     * within 250 ms after rule evaluation completes.
     */
  }

  requirement def SecurityAlertRequirement {
    subject security : SecurityManager;

    attribute maxAlertDelay : Seconds = 5.0 [s];

    doc
    /*
     * When armed and an intrusion event is confirmed, HomeOS shall notify the
     * authenticated user within 5 s and activate the siren after the configured
     * alarm delay unless disarmed by an authorized user.
     */
  }

  requirement def ComfortRequirement {
    subject comfort : ComfortManager;

    attribute occupiedTemperatureTolerance : Celsius = 1.0 [degC];
    attribute illuminanceTolerance : Lux = 50.0 [lx];

    doc
    /*
     * When occupancy is detected, HomeOS shall command HVAC and lighting devices
     * to maintain temperature and illuminance within configured comfort bands.
     */
  }

  requirement def EnergyBudgetRequirement {
    subject energy : EnergyManager;

    doc
    /*
     * HomeOS shall monitor household power use and defer flexible loads when
     * projected daily energy consumption exceeds the configured daily budget or
     * instantaneous load exceeds the peak power limit.
     */
  }

  requirement def DeviceHealthRequirement {
    subject registry : DeviceRegistry;

    doc
    /*
     * HomeOS shall track health for every registered device and expose degraded,
     * offline, or faulted devices to automation logic so unsafe or unavailable
     * devices are not selected for routine commands.
     */
  }

  satisfy PrimaryFunctionRequirement by HomeOSBasedSmartHomeSystem;
  satisfy CommandLatencyRequirement by HomeOSController;
  satisfy SecurityAlertRequirement by SecurityManager;
  satisfy ComfortRequirement by ComfortManager;
  satisfy EnergyBudgetRequirement by EnergyManager;
  satisfy DeviceHealthRequirement by DeviceRegistry;

}