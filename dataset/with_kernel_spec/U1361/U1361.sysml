package SmartHomeAutomation {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    package Definitions {
        attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
        attribute def BrightnessValue :> ISQ::IlluminanceValue;
        attribute def BrightnessLevel :> Real;
        attribute def DurationValue :> ISQ::DurationValue;

        attribute def DeviceReady;
        attribute def CommandReceived;
        attribute def OperationComplete;
        attribute def ErrorDetected;
        attribute def Reset;
        attribute def DataReceived;
        attribute def RuleMatched;
        attribute def CommandSent;
        attribute def NotificationNeeded;
        attribute def NotificationSent;
        attribute def FaultDetected;

        item def TemperatureReading {
            attribute value : TemperatureValue;
            attribute location : String;
            attribute timestamp : TimeInstantValue;
        }
        item def MotionReading {
            attribute detected : Boolean;
            attribute location : String;
            attribute timestamp : TimeInstantValue;
        }
        item def BrightnessReading {
            attribute value : BrightnessValue;
            attribute location : String;
            attribute timestamp : TimeInstantValue;
        }
        item def LightCommand {
            attribute on : Boolean;
            attribute brightness : BrightnessLevel;
            attribute location : String;
        }
        item def ThermostatCommand {
            attribute targetTemp : TemperatureValue;
            attribute location : String;
        }
        item def LockCommand {
            attribute locked : Boolean;
            attribute location : String;
        }
        item def DeviceStatus {
            attribute deviceId : String;
            attribute operationalState : String;
            attribute timestamp : TimeInstantValue;
        }
        item def Notification {
            attribute msg : String;
            attribute priority : Integer;
            attribute timestamp : TimeInstantValue;
        }
        item def AutomationRule {
            attribute name : String;
            attribute condition : String;
            attribute actionType : String;
            attribute enabled : Boolean;
        }

        port def SensorDataPort {
            out tempReading : TemperatureReading;
            out motionReading : MotionReading;
            out brightnessReading : BrightnessReading;
        }
        port def HubSensorPort {
            in tempReading : TemperatureReading;
            in motionReading : MotionReading;
            in brightnessReading : BrightnessReading;
        }
        port def DeviceControlPort {
            in lightCmd : LightCommand;
            in thermostatCmd : ThermostatCommand;
            in lockCmd : LockCommand;
        }
        port def HubControlPort {
            out lightCmd : LightCommand;
            out thermostatCmd : ThermostatCommand;
            out lockCmd : LockCommand;
        }
        port def StatusReportPort {
            out status : DeviceStatus;
        }
        port def HubStatusPort {
            in status : DeviceStatus;
        }
        port def AppPort {
            out lightCmd : LightCommand;
            out thermostatCmd : ThermostatCommand;
            out lockCmd : LockCommand;
            out ruleUpdate : AutomationRule;
            in notification : Notification;
            in statusUpdate : DeviceStatus;
        }
        port def HubAppPort {
            in lightCmd : LightCommand;
            in thermostatCmd : ThermostatCommand;
            in lockCmd : LockCommand;
            in ruleUpdate : AutomationRule;
            out notification : Notification;
            out statusUpdate : DeviceStatus;
        }

        action def SenseTemperature {
            out reading : TemperatureReading;
        }
        action def SenseMotion {
            out reading : MotionReading;
        }
        action def SenseBrightness {
            out reading : BrightnessReading;
        }
        action def SetBrightness {
            in cmd : LightCommand;
        }
        action def SetTemperature {
            in cmd : ThermostatCommand;
        }
        action def SetLock {
            in cmd : LockCommand;
        }
        action def ReceiveSensorData {
            out tempReading : TemperatureReading;
            out motionReading : MotionReading;
            out brightnessReading : BrightnessReading;
        }
        action def SendLightCommand {
            in cmd : LightCommand;
        }
        action def SendThermostatCommand {
            in cmd : ThermostatCommand;
        }
        action def SendLockCommand {
            in cmd : LockCommand;
        }
        action def SendNotification {
            in notification : Notification;
        }
        action def EvaluateRules {
            in rules : AutomationRule[0..*];
            in tempReading : TemperatureReading;
            in motionReading : MotionReading;
            in brightnessReading : BrightnessReading;
            out lightCmd : LightCommand;
            out thermostatCmd : ThermostatCommand;
            out lockCmd : LockCommand;
            out notification : Notification;
        }
        action def ProcessSensorData {
            in tempReading : TemperatureReading;
            in motionReading : MotionReading;
            in brightnessReading : BrightnessReading;
        }
        action def DispatchCommand {
            in lightCmd : LightCommand;
            in thermostatCmd : ThermostatCommand;
            in lockCmd : LockCommand;
        }
        action def ProcessRules {
            first start;
            then action receive : ReceiveSensorData;
            then action evaluate : EvaluateRules {
                in tempReading = receive.tempReading;
                in motionReading = receive.motionReading;
                in brightnessReading = receive.brightnessReading;
            }
            then action sendLightCmd : SendLightCommand {
                in cmd = evaluate.lightCmd;
            }
            then action sendThermostatCmd : SendThermostatCommand {
                in cmd = evaluate.thermostatCmd;
            }
            then action sendLockCmd : SendLockCommand {
                in cmd = evaluate.lockCmd;
            }
            then action sendNotif : SendNotification {
                in notification = evaluate.notification;
            }
            then done;
        }
        action def DisplayDashboard {
            in status : DeviceStatus[0..*];
            in notifications : Notification[0..*];
        }

        action processSensorData : ProcessSensorData;
        action evaluateRules : EvaluateRules;
        action dispatchCommand : DispatchCommand;
        action sendNotif : SendNotification;

        state def DeviceStates {
            entry; then connected;
            state connected;
            accept DeviceReady
                then idle;
            state idle;
            accept CommandReceived
                then operating;
            state operating;
            accept OperationComplete
                then idle;
            accept ErrorDetected
                then fault;
            state fault;
            accept Reset
                then connected;
        }

        state def HubStates {
            entry; then active;
            state active {
                entry; then sensing;
                state sensing {
                    do processSensorData;
                }
                accept DataReceived
                    then evaluating;
                state evaluating {
                    do evaluateRules;
                }
                accept RuleMatched
                    then dispatching;
                state dispatching {
                    do dispatchCommand;
                }
                accept CommandSent
                    then sensing;
                accept NotificationNeeded
                    then notifying;
                state notifying {
                    do sendNotif;
                }
                accept NotificationSent
                    then sensing;
            }
            state standby;
            state error;
            accept FaultDetected
                then error;
            accept Reset
                then active;
        }

        part def SmartDevice {
            port controlPort : DeviceControlPort;
            port statusPort : StatusReportPort;
            exhibit state deviceStates : DeviceStates;
        }
        part def TemperatureSensor :> SmartDevice {
            port sensorPort : SensorDataPort;
            attribute location : String;
            perform action senseTemperature : SenseTemperature;
        }
        part def MotionSensor :> SmartDevice {
            port sensorPort : SensorDataPort;
            attribute location : String;
            perform action senseMotion : SenseMotion;
        }
        part def LightSensor :> SmartDevice {
            port sensorPort : SensorDataPort;
            attribute location : String;
            perform action senseBrightness : SenseBrightness;
        }
        part def SmartLight :> SmartDevice {
            attribute brightness : BrightnessLevel;
            attribute location : String;
            perform action setBrightness : SetBrightness;
        }
        part def SmartThermostat :> SmartDevice {
            attribute currentTemp : TemperatureValue;
            attribute location : String;
            perform action setTemperature : SetTemperature;
        }
        part def SmartDoorLock :> SmartDevice {
            attribute locked : Boolean;
            attribute location : String;
            perform action setLock : SetLock;
        }
        part def RuleEngine {
            attribute rules : AutomationRule[0..*];
            perform action evaluate : EvaluateRules;
        }
        part def SmartThingsHub {
            port hubSensorPort : HubSensorPort;
            port hubControlPort : HubControlPort;
            port hubStatusPort : HubStatusPort;
            port hubAppPort : HubAppPort;
            part ruleEngine : RuleEngine;
            perform action processRules : ProcessRules;
            exhibit state hubStates : HubStates;
        }
        part def Smartphone {
            port appPort : AppPort;
            perform action displayDashboard : DisplayDashboard;
        }

        requirement def ResponsivenessRequirement {
            doc /** Automated actions and user notifications must happen quickly and efficiently. */
            attribute responseTime : DurationValue;
            constraint { responseTime < 2 [s] }
        }
        requirement def ReliabilityRequirement {
            doc /** The system must reliably deliver commands and report device status. */
            attribute deliveryRate : Real;
            constraint { deliveryRate > 99.5 }
        }
        requirement def SystemIntegrationRequirement {
            doc /** The system shall integrate various smart devices, allowing them to work together to automate tasks and provide remote control and monitoring. */
        }
        requirement def ContinuousCycleRequirement {
            doc /** The system shall operate in a continuous cycle where sensors gather data, the hub evaluates rules, dispatches commands, and devices report status. */
        }
        requirement def UserInteractionRequirement {
            doc /** Users shall interact via a mobile app to view status, control devices, modify rules, and receive notifications. */
        }
        requirement def DeviceStatesRequirement {
            doc /** Smart devices shall maintain operational states: connected, idle, operating, or fault. */
        }
    }

    package Usages {
        private import Definitions::*;

        part homeSystem {
            part hub : SmartThingsHub {
                part :>> ruleEngine : RuleEngine;
            }
            part tempSensorLR : TemperatureSensor {
                attribute :>> location := "Living Room";
            }
            part motionSensorHW : MotionSensor {
                attribute :>> location := "Hallway";
            }
            part lightSensorBR : LightSensor {
                attribute :>> location := "Bedroom";
            }
            part hallwayLight : SmartLight {
                attribute :>> location := "Hallway";
            }
            part livingThermostat : SmartThermostat {
                attribute :>> location := "Living Room";
            }
            part frontDoorLock : SmartDoorLock {
                attribute :>> location := "Front Door";
            }
            part userPhone : Smartphone;

            interface tempSensorToHub connect tempSensorLR.sensorPort to hub.hubSensorPort {
                flow tempFlow of TemperatureReading
                    from tempSensorLR.sensorPort.tempReading to hub.hubSensorPort.tempReading;
            }
            interface motionSensorToHub connect motionSensorHW.sensorPort to hub.hubSensorPort {
                flow motionFlow of MotionReading
                    from motionSensorHW.sensorPort.motionReading to hub.hubSensorPort.motionReading;
            }
            interface lightSensorToHub connect lightSensorBR.sensorPort to hub.hubSensorPort {
                flow brightnessFlow of BrightnessReading
                    from lightSensorBR.sensorPort.brightnessReading to hub.hubSensorPort.brightnessReading;
            }
            interface hubToHallwayLight connect hub.hubControlPort to hallwayLight.controlPort {
                flow lightCmdFlow of LightCommand
                    from hub.hubControlPort.lightCmd to hallwayLight.controlPort.lightCmd;
            }
            interface hubToThermostat connect hub.hubControlPort to livingThermostat.controlPort {
                flow thermostatCmdFlow of ThermostatCommand
                    from hub.hubControlPort.thermostatCmd to livingThermostat.controlPort.thermostatCmd;
            }
            interface hubToFrontDoor connect hub.hubControlPort to frontDoorLock.controlPort {
                flow lockCmdFlow of LockCommand
                    from hub.hubControlPort.lockCmd to frontDoorLock.controlPort.lockCmd;
            }
            interface hallwayLightStatus connect hallwayLight.statusPort to hub.hubStatusPort {
                flow statusFlow of DeviceStatus
                    from hallwayLight.statusPort.status to hub.hubStatusPort.status;
            }
            interface thermostatStatus connect livingThermostat.statusPort to hub.hubStatusPort {
                flow statusFlow2 of DeviceStatus
                    from livingThermostat.statusPort.status to hub.hubStatusPort.status;
            }
            interface doorLockStatus connect frontDoorLock.statusPort to hub.hubStatusPort {
                flow statusFlow3 of DeviceStatus
                    from frontDoorLock.statusPort.status to hub.hubStatusPort.status;
            }
            interface phoneToHub connect userPhone.appPort to hub.hubAppPort {
                flow lightCmdFromApp of LightCommand
                    from userPhone.appPort.lightCmd to hub.hubAppPort.lightCmd;
                flow thermostatCmdFromApp of ThermostatCommand
                    from userPhone.appPort.thermostatCmd to hub.hubAppPort.thermostatCmd;
                flow lockCmdFromApp of LockCommand
                    from userPhone.appPort.lockCmd to hub.hubAppPort.lockCmd;
                flow ruleUpdateFlow of AutomationRule
                    from userPhone.appPort.ruleUpdate to hub.hubAppPort.ruleUpdate;
                flow notificationFlow of Notification
                    from hub.hubAppPort.notification to userPhone.appPort.notification;
                flow statusUpdateFlow of DeviceStatus
                    from hub.hubAppPort.statusUpdate to userPhone.appPort.statusUpdate;
            }
        }

        requirement responsiveness : ResponsivenessRequirement {
            doc /** The smart home system must respond to sensor events and user commands within 2 seconds. */
            attribute :>> responseTime = 2 [s];
        }
        requirement reliability : ReliabilityRequirement {
            doc /** The system must reliably deliver commands to devices and report accurate status. */
            attribute :>> deliveryRate = 99.9;
        }
        requirement systemIntegration : SystemIntegrationRequirement;
        requirement continuousCycle : ContinuousCycleRequirement;
        requirement userInteraction : UserInteractionRequirement;
        requirement deviceStates : DeviceStatesRequirement;

        satisfy responsiveness by homeSystem.hub;
        satisfy reliability by homeSystem.hub;
        satisfy systemIntegration by homeSystem.hub;
        satisfy continuousCycle by homeSystem.hub;
        satisfy userInteraction by homeSystem.userPhone;
        satisfy deviceStates by SmartDevice;
    }
}
