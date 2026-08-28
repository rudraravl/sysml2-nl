package SmartHomeAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def Temperature :> Real;
    attribute def Brightness :> Real;
    attribute def ColorTemperature :> Real;
    attribute def FanSpeed :> Integer;
    attribute def BatteryLevel :> Real;
    attribute def DeviceId :> String;

    enum def OperatingMode { OFF; HEAT; COOL; AUTO; ECO; }
    enum def LockState { LOCKED; UNLOCKED; }

    item def Command {
        attribute deviceId : DeviceId;
        attribute commandType : String;
        attribute parameter : Real;
    }
    item def StatusUpdate {
        attribute deviceId : DeviceId;
        attribute statusType : String;
        attribute value : Real;
    }
    item def SensorData {
        attribute sensorId : DeviceId;
        attribute sensorType : String;
        attribute value : Real;
        attribute timestamp : Real;
    }
    item def UserCommand {
        attribute targetDeviceId : DeviceId;
        attribute commandType : String;
        attribute parameter : Real;
    }

    port def NetworkPort {
        in item cmd : Command;
        out item status : StatusUpdate;
    }
    port def SensorPort {
        out item data : SensorData;
    }
    port def AppPort {
        in item userCmd : UserCommand;
        out item deviceStatus : StatusUpdate[*];
    }

    attribute def DiscoverSignal;
    attribute def PairSuccessSignal;
    attribute def PairFailureSignal;
    attribute def DisconnectSignal;

    action def DiscoverDevices { out deviceCount : Integer; }
    action def RegisterDevice { in deviceId : DeviceId; out success : Boolean; }
    action def TogglePower;
    action def AdjustBrightness { in level : Brightness; }
    action def SetColorTemp { in temp : ColorTemperature; }
    action def SetTargetTemp { in target : Temperature; }
    action def SetMode { in mode : OperatingMode; }
    action def SetFanSpeed { in speed : FanSpeed; }
    action def LockDevice;
    action def UnlockDevice;
    action def SenseMotion { out detected : Boolean; }
    action def SenseTemperature { out temp : Temperature; }
    action def ExecuteScene { in sceneName : String; out commands : Command[*]; }
    action def ExecuteRule { in ruleName : String; in sensorInput : SensorData; out command : Command; }
    action def ExecuteSchedule { in scheduleName : String; out commands : Command[*]; }
    action def SendStatus { out status : StatusUpdate; }

    state def DeviceLifecycle {
        entry; then offline;
        state offline;
        accept DiscoverSignal then pairing;
        state pairing;
        accept PairSuccessSignal then ready;
        accept PairFailureSignal then offline;
        state ready;
        accept DisconnectSignal then offline;
    }

    part def SmartDevice {
        attribute deviceId : DeviceId;
        port netPort : NetworkPort;
        exhibit state lifecycle : DeviceLifecycle;
    }

    part def SmartLightBulb :> SmartDevice {
        attribute isOn : Boolean;
        attribute brightness : Brightness;
        attribute colorTemp : ColorTemperature;
        perform action togglePower : TogglePower;
        perform action adjustBrightness : AdjustBrightness;
        perform action setColorTemp : SetColorTemp;
    }

    part def SmartThermostat :> SmartDevice {
        attribute currentTemp : Temperature;
        attribute targetTemp : Temperature;
        attribute mode : OperatingMode;
        attribute fanSpeed : FanSpeed;
        perform action setTargetTemp : SetTargetTemp;
        perform action setMode : SetMode;
        perform action setFanSpeed : SetFanSpeed;
    }

    part def SmartDoorLock :> SmartDevice {
        attribute lockStatus : LockState;
        attribute batteryLevel : BatteryLevel;
        perform action lock : LockDevice;
        perform action unlock : UnlockDevice;
    }

    part def Sensor :> SmartDevice {
        port sensorPort : SensorPort;
    }

    part def MotionSensor :> Sensor {
        attribute motionDetected : Boolean;
        perform action senseMotion : SenseMotion;
    }

    part def TemperatureSensor :> Sensor {
        attribute sensedTemp : Temperature;
        perform action senseTemperature : SenseTemperature;
    }

    part def AutomationController {
        attribute rules : String[*];
        attribute schedules : String[*];
        attribute scenes : String[*];
        perform action executeScene : ExecuteScene;
        perform action executeRule : ExecuteRule;
        perform action executeSchedule : ExecuteSchedule;
    }

    part def HomeHub {
        port appPort : AppPort;
        port devicePort : ~NetworkPort[*];
        port sensorPort : ~SensorPort[*];
        perform action discoverDevices : DiscoverDevices;
        perform action registerDevice : RegisterDevice;
    }

    part def MobileApplication {
        port appPort : ~AppPort;
        attribute isAuthenticated : Boolean;
    }

    requirement def CentralizedControlReq {
        doc /* The Home Hub shall discover, register, and communicate with all smart devices. */
        attribute deviceCount : Integer;
        attribute minDevices : Integer;
        require constraint { deviceCount >= minDevices }
    }

    requirement def SecureAccessReq {
        doc /* The Mobile Application shall provide a secure, authenticated interface for remote control. */
        attribute authenticated : Boolean;
        require constraint { authenticated == true }
    }

    requirement def LightControlReq {
        doc /* Smart Light Bulbs shall support remote on/off, brightness, and color temperature adjustment. */
        attribute brightnessValue : Brightness;
        require constraint { brightnessValue >= 0.0 and brightnessValue <= 100.0 }
    }

    requirement def ThermostatControlReq {
        doc /* Smart Thermostats shall manage climate by controlling temperature, mode, and fan speed. */
        attribute minTemp : Temperature;
        attribute maxTemp : Temperature;
        require constraint { minTemp <= maxTemp }
    }

    requirement def DoorLockReq {
        doc /* Smart Door Locks shall provide remote lock status monitoring and battery level reporting. */
        attribute minBatteryLevel : BatteryLevel;
        require constraint { minBatteryLevel > 0.0 }
    }

    requirement def SensorIntegrationReq {
        doc /* The system shall integrate Motion and Temperature Sensors for real-time environmental data. */
        attribute updateInterval : Real;
        attribute maxUpdateInterval : Real;
        require constraint { updateInterval <= maxUpdateInterval }
    }

    requirement def AutomationReq {
        doc /* The Automation Controller shall execute pre-defined rules, schedules, and scenes. */
        attribute automationExecuted : Boolean;
        require constraint { automationExecuted == true }
    }

    requirement def DeviceLifecycleReq {
        doc /* Devices shall transition from offline to pairing to ready upon successful network connection. */
        attribute pairingTime : Real;
        attribute maxPairingTime : Real;
        require constraint { pairingTime <= maxPairingTime }
    }

    part smartHomeSystem {
        part homeHub : HomeHub {
            part automationController : AutomationController;
        }
        part mobileApp : MobileApplication;

        part lightBulb1 : SmartLightBulb;
        part lightBulb2 : SmartLightBulb;
        part thermostat : SmartThermostat;
        part doorLock : SmartDoorLock;
        part motionSensor : MotionSensor;
        part tempSensor : TemperatureSensor;

        connect mobileApp.appPort to homeHub.appPort;
        connect homeHub.devicePort to lightBulb1.netPort;
        connect homeHub.devicePort to lightBulb2.netPort;
        connect homeHub.devicePort to thermostat.netPort;
        connect homeHub.devicePort to doorLock.netPort;
        connect homeHub.devicePort to motionSensor.netPort;
        connect homeHub.devicePort to tempSensor.netPort;
        connect motionSensor.sensorPort to homeHub.sensorPort;
        connect tempSensor.sensorPort to homeHub.sensorPort;
    }
}
