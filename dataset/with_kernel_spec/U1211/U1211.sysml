package SmartHomeSystem {
    private import ScalarValues::*;
    
    value type Temperature :> Real;
    value type Humidity :> Real;
    value type Brightness :> Real;
    
    item def TemperatureReading {
        attribute value : Temperature;
    }
    item def HumidityReading {
        attribute value : Humidity;
    }
    item def MotionReading {
        attribute detected : Boolean;
    }
    item def ThermostatCommand {
        attribute targetTemp : Temperature;
    }
    item def LightCommand {
        attribute brightness : Brightness;
        attribute color : String;
    }
    item def LockCommand {
        attribute lockState : Boolean;
    }
    item def CameraCommand {
        attribute recordFlag : Boolean;
    }
    item def SecurityAlert {
        attribute alertText : String;
    }
    item def UserCommand {
        attribute targetDevice : String;
        attribute commandText : String;
    }
    
    port def SensorPort {
        out item temp : TemperatureReading;
        out item hum : HumidityReading;
        out item mot : MotionReading;
    }
    port def CmdPort {
        out item thermoCmd : ThermostatCommand;
        out item lightCmd : LightCommand;
        out item lockCmd : LockCommand;
        out item camCmd : CameraCommand;
    }
    port def CloudPort {
        in item userCmd : UserCommand;
        out item alert : SecurityAlert;
    }
    
    part def CloudService {
        port cloudPort : ~CloudPort;
    }
    
    part def TemperatureSensor {
        port sensorOut : SensorPort;
        perform action sense {
            action readTemp;
            then action sendTemp send new TemperatureReading(25.0) via sensorOut;
        }
    }
    part def HumiditySensor {
        port sensorOut : SensorPort;
        perform action sense {
            action readHum;
            then action sendHum send new HumidityReading(50.0) via sensorOut;
        }
    }
    part def MotionSensor {
        port sensorOut : SensorPort;
        perform action sense {
            action detect;
            then action sendMot send new MotionReading(true) via sensorOut;
        }
    }
    
    part def SmartThermostat {
        port cmdPort : ~CmdPort;
        exhibit state thermostatStates {
            entry; then idle;
            state idle;
            transition adjust
                first idle
                accept cmd : ThermostatCommand via cmdPort
                then idle;
        }
    }
    part def SmartLight {
        port cmdPort : ~CmdPort;
        attribute brightness : Brightness = 0;
        attribute color : String = "white";
        perform action adjust {
            action receive accept cmd : LightCommand via cmdPort;
        }
    }
    part def SmartLock {
        port cmdPort : ~CmdPort;
        attribute locked : Boolean = false;
        exhibit state lockStates {
            state locked;
            state unlocked;
            transition lock
                first unlocked
                accept cmd : LockCommand via cmdPort
                then locked;
            transition unlock
                first locked
                accept cmd : LockCommand via cmdPort
                then unlocked;
        }
    }
    part def SecurityCamera {
        port cmdPort : ~CmdPort;
        attribute recording : Boolean = false;
        perform action record {
            action receive accept cmd : CameraCommand via cmdPort;
        }
    }
    
    part def CommunicationModule {
        port cloudPort : CloudPort;
        port sensorIn : ~SensorPort;
        port cmdOut : CmdPort;
        perform action route {
            action receiveSensor;
            then action forwardData;
        }
    }
    
    part def DataProcessor {
        port sensorIn : ~SensorPort;
        port dataOut : SensorPort;
        perform action process {
            action collectTemp accept TemperatureReading via sensorIn;
            then action forwardTemp send new TemperatureReading(25.0) via dataOut;
            then action collectMot accept MotionReading via sensorIn;
            then action forwardMot send new MotionReading(true) via dataOut;
        }
    }
    
    part def AutomationEngine {
        port sensorIn : ~SensorPort;
        port cmdOut : CmdPort;
        exhibit state automationStates {
            entry; then idle;
            state idle;
            transition onHighTemp
                first idle
                accept temp : TemperatureReading via sensorIn
                if temp.value > 25.0
                do send new ThermostatCommand(22.0) via cmdOut
                then idle;
        }
    }
    
    part def SecurityManager {
        port sensorIn : ~SensorPort;
        port cmdOut : CmdPort;
        port cloudPort : CloudPort;
        exhibit state securityStates {
            entry; then disarmed;
            state disarmed;
            state armedAway;
            transition arm
                first disarmed
                accept cmd : UserCommand via cloudPort
                then armedAway;
            transition disarm
                first armedAway
                accept cmd : UserCommand via cloudPort
                then disarmed;
            transition respondToMotion
                first armedAway
                accept mot : MotionReading via sensorIn
                do action handleAlarm {
                    action lockDoor send new LockCommand(true) via cmdOut;
                    then action startCamera send new CameraCommand(true) via cmdOut;
                    then action sendAlert send new SecurityAlert("Motion detected!") via cloudPort;
                }
                then armedAway;
        }
    }
    
    part def SmartHomeHub {
        part comm : CommunicationModule;
        part proc : DataProcessor;
        part auto : AutomationEngine;
        part sec : SecurityManager;
        
        port externalSensorPort : ~SensorPort;
        port externalCmdPort : CmdPort;
        port externalCloudPort : CloudPort;
        
        connect externalSensorPort to proc.sensorIn;
        connect proc.dataOut to auto.sensorIn;
        connect proc.dataOut to sec.sensorIn;
        connect auto.cmdOut to externalCmdPort;
        connect sec.cmdOut to externalCmdPort;
        connect sec.cloudPort to comm.cloudPort;
        connect externalCloudPort to comm.cloudPort;
    }
    
    part smartHomeSystem {
        part hub : SmartHomeHub;
        part tempSensor : TemperatureSensor;
        part humSensor : HumiditySensor;
        part motSensor : MotionSensor;
        part thermostat : SmartThermostat;
        part light : SmartLight;
        part lock : SmartLock;
        part camera : SecurityCamera;
        part cloud : CloudService;
        
        connect tempSensor.sensorOut to hub.externalSensorPort;
        connect humSensor.sensorOut to hub.externalSensorPort;
        connect motSensor.sensorOut to hub.externalSensorPort;
        
        connect hub.externalCmdPort to thermostat.cmdPort;
        connect hub.externalCmdPort to light.cmdPort;
        connect hub.externalCmdPort to lock.cmdPort;
        connect hub.externalCmdPort to camera.cmdPort;
        
        connect hub.externalCloudPort to cloud.cloudPort;
    }
    
    requirement def SmartHomeHubRequirements {
        text "The system shall integrate various smart devices using multiple protocols. The system shall automatically control devices based on sensor data and user-defined rules. The system shall manage home security and respond to events.";
    }
}
