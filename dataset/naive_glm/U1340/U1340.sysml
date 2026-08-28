package SmartHomeAutomation {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def TemperatureValue :> Real { unit '°C'; }
    value def BrightnessValue :> Real { unit '%'; min 0; max 100; }
    value def ColorTempValue :> Real { unit 'K'; min 1000; max 10000; }
    value def BatteryLevel :> Real { unit '%'; min 0; max 100; }
    value def FanSpeed :> Integer { min 0; max 5; }
    value def SignalStrength :> Real { unit 'dBm'; }

    // ===== Enumerations =====
    enum def DeviceType { light; thermostat; doorLock; motionSensor; temperatureSensor; }
    enum def LockState { locked; unlocked; }
    enum def ThermostatMode { off; heat; cool; auto; }
    enum def PowerState { on; off; }
    enum def MotionState { motionDetected; noMotion; }
    enum def DeviceLifecycleState { offline; pairing; ready; }
    enum def SceneType { goodnight; away; morning; welcome; }

    // ===== Item Definitions =====
    item def DeviceCommand {
        attribute deviceId : String;
        attribute commandType : String;
        attribute timestamp : String;
    }

    item def LightCommand :> DeviceCommand {
        attribute power : PowerState;
        attribute brightness : BrightnessValue;
        attribute colorTemp : ColorTempValue;
    }

    item def ThermostatCommand :> DeviceCommand {
        attribute targetTemp : TemperatureValue;
        attribute mode : ThermostatMode;
        attribute fanSpeed : FanSpeed;
    }

    item def LockCommand :> DeviceCommand {
        attribute lockState : LockState;
    }

    item def DeviceStatus {
        attribute deviceId : String;
        attribute online : Boolean;
        attribute timestamp : String;
    }

    item def LightStatus :> DeviceStatus {
        attribute power : PowerState;
        attribute brightness : BrightnessValue;
        attribute colorTemp : ColorTempValue;
    }

    item def ThermostatStatus :> DeviceStatus {
        attribute currentTemp : TemperatureValue;
        attribute targetTemp : TemperatureValue;
        attribute mode : ThermostatMode;
        attribute fanSpeed : FanSpeed;
    }

    item def LockStatusReport :> DeviceStatus {
        attribute lockState : LockState;
        attribute battery : BatteryLevel;
    }

    item def SensorData {
        attribute deviceId : String;
        attribute timestamp : String;
    }

    item def MotionSensorData :> SensorData {
        attribute motion : MotionState;
    }

    item def TemperatureSensorData :> SensorData {
        attribute temperature : TemperatureValue;
    }

    item def AutomationRule {
        attribute ruleId : String;
        attribute name : String;
        attribute enabled : Boolean;
    }

    item def SceneConfig {
        attribute sceneType : SceneType;
        attribute name : String;
    }

    item def AuthCredentials {
        attribute username : String;
        attribute token : String;
    }

    // ===== Port Definitions =====
    port def HubDevicePort {
        out commands : DeviceCommand;
        in status : DeviceStatus;
    }

    port def HubSensorPort {
        in sensorData : SensorData;
    }

    port def DevicePort {
        in commands : DeviceCommand;
        out status : DeviceStatus;
    }

    port def SensorPort {
        out sensorData : SensorData;
    }

    port def AppInterfacePort {
        out commands : DeviceCommand;
        in status : DeviceStatus;
        in auth : AuthCredentials;
    }

    port def HubAppPort {
        in commands : DeviceCommand;
        out status : DeviceStatus;
        in auth : AuthCredentials;
    }

    // ===== Abstract Smart Device =====
    abstract part def SmartDevice {
        attribute deviceId : String;
        attribute deviceType : DeviceType;
        attribute lifecycleState : DeviceLifecycleState = DeviceLifecycleState::offline;

        port devicePort : DevicePort;

        state deviceLifecycle {
            entry; then offline;

            state offline {
                entry { }
            }

            transition discoverDevice
                first offline
                accept 'DeviceDiscovered'
                then pairing;

            state pairing {
                entry { }
            }

            transition pairingSuccess
                first pairing
                accept 'PairingSuccess'
                then ready;

            transition pairingFailure
                first pairing
                accept 'PairingFailure'
                then offline;

            state ready {
                entry { }
            }

            transition connectionLost
                first ready
                accept 'ConnectionLost'
                then offline;

            transition reDiscover
                first offline
                accept 'DeviceDiscovered'
                then pairing;
        }
    }

    // ===== Smart Light Bulb =====
    part def SmartLightBulb :> SmartDevice {
        attribute power : PowerState = PowerState::off;
        attribute brightness : BrightnessValue = 100;
        attribute colorTemp : ColorTempValue = 3000;

        action setLightState {
            in cmd : LightCommand;
        }

        action reportLightStatus {
            out status : LightStatus;
        }

        state lightLifecycle {
            entry; then offline;

            state offline {
                entry { }
            }

            transition lightDiscovered
                first offline
                accept 'DeviceDiscovered'
                then pairing;

            state pairing {
                entry { }
            }

            transition lightPaired
                first pairing
                accept 'PairingSuccess'
                then ready;

            transition lightPairFail
                first pairing
                accept 'PairingFailure'
                then offline;

            state ready {
                entry { }
            }

            transition lightConnectionLost
                first ready
                accept 'ConnectionLost'
                then offline;
        }
    }

    // ===== Smart Thermostat =====
    part def SmartThermostat :> SmartDevice {
        attribute currentTemp : TemperatureValue = 22.0;
        attribute targetTemp : TemperatureValue = 22.0;
        attribute mode : ThermostatMode = ThermostatMode::auto;
        attribute fanSpeed : FanSpeed = 1;

        action setThermostatState {
            in cmd : ThermostatCommand;
        }

        action readCurrentTemperature {
            out temp : TemperatureValue;
        }

        action reportThermostatStatus {
            out status : ThermostatStatus;
        }

        state thermostatLifecycle {
            entry; then offline;

            state offline {
                entry { }
            }

            transition thermostatDiscovered
                first offline
                accept 'DeviceDiscovered'
                then pairing;

            state pairing {
                entry { }
            }

            transition thermostatPaired
                first pairing
                accept 'PairingSuccess'
                then ready;

            transition thermostatPairFail
                first pairing
                accept 'PairingFailure'
                then offline;

            state ready {
                entry { }
            }

            transition thermostatConnectionLost
                first ready
                accept 'ConnectionLost'
                then offline;
        }
    }

    // ===== Smart Door Lock =====
    part def SmartDoorLock :> SmartDevice {
        attribute lockState : LockState = LockState::locked;
        attribute battery : BatteryLevel = 100;

        action setLockState {
            in cmd : LockCommand;
        }

        action checkBattery {
            out level : BatteryLevel;
        }

        action reportLockStatus {
            out status : LockStatusReport;
        }

        state lockLifecycle {
            entry; then offline;

            state offline {
                entry { }
            }

            transition lockDiscovered
                first offline
                accept 'DeviceDiscovered'
                then pairing;

            state pairing {
                entry { }
            }

            transition lockPaired
                first pairing
                accept 'PairingSuccess'
                then ready;

            transition lockPairFail
                first pairing
                accept 'PairingFailure'
                then offline;

            state ready {
                entry { }
            }

            transition lockConnectionLost
                first ready
                accept 'ConnectionLost'
                then offline;
        }
    }

    // ===== Motion Sensor =====
    part def MotionSensor :> SmartDevice {
        attribute motion : MotionState = MotionState::noMotion;

        port sensorPort : SensorPort;

        action detectMotion {
            out data : MotionSensorData;
        }

        action reportMotion {
            out data : MotionSensorData;
        }

        state motionSensorLifecycle {
            entry; then offline;

            state offline {
                entry { }
            }

            transition motionSensorDiscovered
                first offline
                accept 'DeviceDiscovered'
                then pairing;

            state pairing {
                entry { }
            }

            transition motionSensorPaired
                first pairing
                accept 'PairingSuccess'
                then ready;

            transition motionSensorPairFail
                first pairing
                accept 'PairingFailure'
                then offline;

            state ready {
                entry { }
            }

            transition motionSensorConnectionLost
                first ready
                accept 'ConnectionLost'
                then offline;
        }
    }

    // ===== Temperature Sensor =====
    part def TemperatureSensor :> SmartDevice {
        attribute temperature : TemperatureValue = 22.0;

        port sensorPort : SensorPort;

        action readTemperature {
            out data : TemperatureSensorData;
        }

        action reportTemperature {
            out data : TemperatureSensorData;
        }

        state tempSensorLifecycle {
            entry; then offline;

            state offline {
                entry { }
            }

            transition tempSensorDiscovered
                first offline
                accept 'DeviceDiscovered'
                then pairing;

            state pairing {
                entry { }
            }

            transition tempSensorPaired
                first pairing
                accept 'PairingSuccess'
                then ready;

            transition tempSensorPairFail
                first pairing
                accept 'PairingFailure'
                then offline;

            state ready {
                entry { }
            }

            transition tempSensorConnectionLost
                first ready
                accept 'ConnectionLost'
                then offline;
        }
    }

    // ===== Automation Controller =====
    part def AutomationController {
        attribute rules : AutomationRule[0..*];
        attribute scenes : SceneConfig[0..*];
        attribute isDark : Boolean = false;

        port automationCommandPort : DevicePort;

        action executeRule {
            in rule : AutomationRule;
            in sensorInput : SensorData;
            out commands : DeviceCommand[0..*];
        }

        action executeScene {
            in scene : SceneConfig;
            out commands : DeviceCommand[0..*];
        }

        action evaluateGoodnightScene {
            doc { The Goodnight scene turns off all lights, locks the front door, and lowers the thermostat. }
            out lightCmd : LightCommand;
            out lockCmd : LockCommand;
            out thermostatCmd : ThermostatCommand;
        }

        action evaluateMotionRule {
            doc { Turns on the hallway light when motion is detected after dark. }
            in motionData : MotionSensorData;
            in dark : Boolean;
            out lightCmd : LightCommand;
        }

        action evaluateSchedule {
            in time : String;
            out commands : DeviceCommand[0..*];
        }

        state automationOperation {
            entry; then idle;

            state idle {
                entry { }
            }

            transition ruleTriggered
                first idle
                accept AutomationRule
                then evaluating;

            transition sceneTriggered
                first idle
                accept SceneConfig
                then evaluating;

            state evaluating {
                entry { }
            }

            transition evaluationComplete
                first evaluating
                accept 'EvaluationDone'
                then idle;
        }
    }

    // ===== Home Hub =====
    part def HomeHub {
        attribute hubId : String;
        attribute registeredDeviceIds : String[0..*];
        attribute networkOnline : Boolean = true;

        port hubDevicePort : HubDevicePort;
        port hubSensorPort : HubSensorPort;
        port hubAppPort : HubAppPort;

        part automationController : AutomationController;

        action discoverDevices {
            out discoveredDeviceIds : String[0..*];
        }

        action registerDevice {
            in deviceId : String;
            in deviceType : DeviceType;
        }

        action pairDevice {
            in deviceId : String;
            out success : Boolean;
        }

        action routeCommand {
            in command : DeviceCommand;
        }

        action broadcastStatus {
            in status : DeviceStatus;
        }

        action authenticateUser {
            in credentials : AuthCredentials;
            out success : Boolean;
        }

        state hubOperation {
            entry; then initializing;

            state initializing {
                entry { }
            }

            transition initComplete
                first initializing
                accept 'InitComplete'
                then operational;

            state operational {
                entry { }
            }

            transition hubOffline
                first operational
                accept 'NetworkDown'
                then degraded;

            state degraded {
                entry { }
            }

            transition hubRecovered
                first degraded
                accept 'NetworkUp'
                then operational;
        }
    }

    // ===== Mobile Application =====
    part def MobileApplication {
        attribute userId : String;
        attribute authenticated : Boolean = false;
        attribute appVersion : String;

        port appPort : AppInterfacePort;

        action authenticate {
            in credentials : AuthCredentials;
            out success : Boolean;
        }

        action sendCommand {
            in command : DeviceCommand;
        }

        action receiveStatus {
            in status : DeviceStatus;
        }

        action configureAutomation {
            in rule : AutomationRule;
        }

        action activateScene {
            in scene : SceneConfig;
        }

        action viewDeviceStatus {
            in deviceId : String;
            out status : DeviceStatus;
        }

        state appSession {
            entry; then unauthenticated;

            state unauthenticated {
                entry { }
            }

            transition login
                first unauthenticated
                accept AuthCredentials
                then authenticating;

            state authenticating {
                entry { }
            }

            transition authSuccess
                first authenticating
                accept 'AuthSuccess'
                then authenticated;

            transition authFailure
                first authenticating
                accept 'AuthFailure'
                then unauthenticated;

            state authenticated {
                entry { }
            }

            transition logout
                first authenticated
                accept 'Logout'
                then unauthenticated;
        }
    }

    // ===== Smart Home System =====
    part def SmartHomeSystem {
        attribute systemId : String;
        attribute homeName : String;

        port externalInterface : AppInterfacePort;

        part homeHub : HomeHub;
        part mobileApp : MobileApplication;
        part lightBulbs : SmartLightBulb[0..*];
        part thermostats : SmartThermostat[0..*];
        part doorLocks : SmartDoorLock[0..*];
        part motionSensors : MotionSensor[0..*];
        part temperatureSensors : TemperatureSensor[0..*];

        connection hubToApp
            connect homeHub.hubAppPort to mobileApp.appPort;

        connection hubToLights
            connect homeHub.hubDevicePort to lightBulbs.devicePort;

        connection hubToThermostats
            connect homeHub.hubDevicePort to thermostats.devicePort;

        connection hubToLocks
            connect homeHub.hubDevicePort to doorLocks.devicePort;

        connection hubToMotionSensors
            connect homeHub.hubSensorPort to motionSensors.sensorPort;

        connection hubToTempSensors
            connect homeHub.hubSensorPort to temperatureSensors.sensorPort;

        connection automationToHub
            connect homeHub.automationController.automationCommandPort to homeHub.hubDevicePort;

        connection appToExternal
            connect mobileApp.appPort to externalInterface;
    }

    // ===== Requirements =====
    requirement def SmartHomeRequirement {
        doc { The smart home automation system shall provide centralized control, monitoring, and automation of household accessories. }
    }

    requirement def HubDiscoveryRequirement {
        doc { The Home Hub shall discover, register, and communicate with all smart devices within the home. }
        subject hub : HomeHub;
    }

    requirement def MobileAppAuthRequirement {
        doc { The Mobile Application shall provide a secure, authenticated interface for remotely controlling devices, checking status, and configuring automations. }
        subject app : MobileApplication;
    }

    requirement def LightControlRequirement {
        doc { Smart Light Bulbs shall support on/off control, brightness adjustment, and color temperature adjustment remotely. }
        subject light : SmartLightBulb;
    }

    requirement def ThermostatControlRequirement {
        doc { Smart Thermostats shall manage current and target temperature, operating mode, and fan speed. }
        subject thermostat : SmartThermostat;
    }

    requirement def DoorLockRequirement {
        doc { Smart Door Locks shall provide remote security control with lock status and battery level monitoring. }
        subject lock : SmartDoorLock;
    }

    requirement def SensorIntegrationRequirement {
        doc { The system shall integrate motion sensors and temperature sensors providing real-time environment data for triggering automated actions. }
        subject motionSensor : MotionSensor;
        subject tempSensor : TemperatureSensor;
    }

    requirement def AutomationRequirement {
        doc { The Automation Controller shall execute pre-defined rules, schedules, and scenes without direct user input. }
        subject controller : AutomationController;
    }

    requirement def DeviceLifecycleRequirement {
        doc { Devices shall transition from offline to pairing to ready state upon successful connection with the Home Hub, ensuring robust connection management. }
        subject device : SmartDevice;
    }

    requirement def GoodnightSceneRequirement {
        doc { The Goodnight scene shall simultaneously turn off all lights, lock the front door, and lower the thermostat target temperature. }
        subject scene : SceneConfig;
    }

    requirement def MotionAutomationRequirement {
        doc { An automation rule shall turn on the hallway light automatically when the motion sensor detects movement after dark. }
        subject rule : AutomationRule;
    }

    requirement def CentralizedControlRequirement {
        doc { The Home Hub shall act as the central brain orchestrating all commands, automations, and status updates across the smart home ecosystem. }
        subject hub : HomeHub;
    }

    requirement smartHomeSystemRequirement : SmartHomeRequirement {
        subject system : SmartHomeSystem;
    }

    requirement hubDiscoveryReq : HubDiscoveryRequirement {
        subject hub : SmartHomeSystem::homeHub;
    }

    requirement centralizedControlReq : CentralizedControlRequirement {
        subject hub : SmartHomeSystem::homeHub;
    }

    requirement mobileAppReq : MobileAppAuthRequirement {
        subject app : SmartHomeSystem::mobileApp;
    }

    requirement lightControlReq : LightControlRequirement {
        subject light : SmartHomeSystem::lightBulbs;
    }

    requirement thermostatControlReq : ThermostatControlRequirement {
        subject thermostat : SmartHomeSystem::thermostats;
    }

    requirement doorLockReq : DoorLockRequirement {
        subject lock : SmartHomeSystem::doorLocks;
    }

    requirement sensorIntegrationReq : SensorIntegrationRequirement {
        subject motionSensor : SmartHomeSystem::motionSensors;
        subject tempSensor : SmartHomeSystem::temperatureSensors;
    }

    requirement automationReq : AutomationRequirement {
        subject controller : SmartHomeSystem::homeHub.automationController;
    }

    requirement deviceLifecycleReq : DeviceLifecycleRequirement {
        subject device : SmartHomeSystem::lightBulbs;
    }

    requirement goodnightSceneReq : GoodnightSceneRequirement {
        subject scene : SceneConfig;
    }

    requirement motionAutomationReq : MotionAutomationRequirement {
        subject rule : AutomationRule;
    }

    // ===== Concrete System Instance =====
    part homeSystem : SmartHomeSystem {
        attribute systemId = "SH-001";
        attribute homeName = "Smith Residence";

        part homeHub {
            attribute hubId = "HUB-001";
        }

        part mobileApp {
            attribute userId = "user@example.com";
            attribute appVersion = "2.1.0";
        }

        part lightBulbs[3] {
            attribute deviceId = "LIGHT-001";
            attribute deviceType = DeviceType::light;
        }

        part thermostats[1] {
            attribute deviceId = "THERMO-001";
            attribute deviceType = DeviceType::thermostat;
        }

        part doorLocks[2] {
            attribute deviceId = "LOCK-001";
            attribute deviceType = DeviceType::doorLock;
        }

        part motionSensors[2] {
            attribute deviceId = "MOTION-001";
            attribute deviceType = DeviceType::motionSensor;
        }

        part temperatureSensors[3] {
            attribute deviceId = "TEMP-001";
            attribute deviceType = DeviceType::temperatureSensor;
        }
    }
}
