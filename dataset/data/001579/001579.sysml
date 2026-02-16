package SmartHomeHubSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    doc /* 
        This model describes a smart home hub system that serves as the central 
        control and coordination point for all connected smart devices in a residential 
        environment. The hub monitors environmental conditions, processes user commands, 
        executes automation rules, manages security, and maintains connectivity with 
        cloud services for remote access and data analytics.
    */

    attribute def DeviceID;
    attribute def CommandType;
    attribute def EventType;
    attribute def AutomationRuleID;

    enum def DeviceState { online; offline; error; }
    enum def SecurityMode { disarmed; armed_home; armed_away; }
    enum def HVACMode { off; heat; cool; auto; }

    attribute def Temperature :> ISQ::TemperatureValue;
    attribute def Humidity :> Real;
    attribute def LightLevel :> ISQ::LuminousIntensityValue;
    attribute def PowerLevel :> ISQ::PowerValue;

    item def SensorReading {
        attribute deviceId : DeviceID;
        attribute timestamp : Real;
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute lightLevel : LightLevel;
        attribute motionDetected : Boolean;
    }

    item def DeviceCommand {
        attribute commandType : CommandType;
        attribute targetDevice : DeviceID;
        attribute powerLevel : PowerLevel;
        attribute setpoint : Temperature;
        attribute enabled : Boolean;
    }

    item def SecurityEvent {
        attribute eventType : EventType;
        attribute sourceDevice : DeviceID;
        attribute timestamp : Real;
        attribute severity : Real;
    }

    item def AutomationRule {
        attribute ruleId : AutomationRuleID;
        attribute condition : String;
        attribute actionSpec : String;
        attribute enabled : Boolean;
    }

    port def SensorDataPort {
        in sensorData : SensorReading;
    }

    port def DeviceControlPort {
        out command : DeviceCommand;
        in status : DeviceState;
    }

    port def UserInterfacePort {
        in userCommand : DeviceCommand;
        out systemStatus : String;
    }

    port def CloudConnectivityPort {
        out telemetryData : SensorReading;
        in remoteCommand : DeviceCommand;
    }

    part def SmartDevice {
        attribute deviceId : DeviceID;
        attribute deviceType : String;
        attribute currentState : DeviceState;
        port controlPort : ~DeviceControlPort;
    }

    part def TemperatureSensor :> SmartDevice {
        attribute currentTemperature : Temperature;
        port dataPort : ~SensorDataPort;
    }

    part def HumiditySensor :> SmartDevice {
        attribute currentHumidity : Humidity;
        port dataPort : ~SensorDataPort;
    }

    part def MotionSensor :> SmartDevice {
        attribute motionDetected : Boolean;
        port dataPort : ~SensorDataPort;
    }

    part def SmartThermostat :> SmartDevice {
        attribute targetTemperature : Temperature;
        attribute currentMode : HVACMode;
        attribute fanSpeed : Real;
    }

    part def SmartLight :> SmartDevice {
        attribute brightness : Real;
        attribute colorTemperature : Real;
        attribute isOn : Boolean;
    }

    part def SmartLock :> SmartDevice {
        attribute isLocked : Boolean;
        attribute accessCode : String;
    }

    part def SecurityCamera :> SmartDevice {
        attribute isRecording : Boolean;
        attribute resolution : String;
    }

    part def CommunicationModule {
        attribute protocol : String;
        attribute signalStrength : Real;
        port cloudPort : CloudConnectivityPort;

        action def TransmitToCloud {
            in data : SensorReading;
            out success : Boolean;
        }

        action def ReceiveFromCloud {
            out command : DeviceCommand;
        }
    }

    part def AutomationEngine {
        attribute activeRules : AutomationRule[*];

        action def EvaluateRules {
            in sensorData : SensorReading;
            in rules : AutomationRule[*];
            out triggeredCommands : DeviceCommand[*];
        }

        action def ExecuteAutomation {
            in rule : AutomationRule;
            in currentConditions : SensorReading;
            out commands : DeviceCommand[*];
        }
    }

    part def SecurityManager {
        attribute currentSecurityMode : SecurityMode;
        attribute alertsEnabled : Boolean;

        action def MonitorSecurity {
            in deviceStatuses : DeviceState[*];
            in sensorData : SensorReading;
            out events : SecurityEvent[*];
        }

        action def HandleSecurityEvent {
            in event : SecurityEvent;
            out responseCommands : DeviceCommand[*];
        }

        state def SecurityStateMachine {
            entry; then disarmed;

            state disarmed {
                accept cmd : DeviceCommand;
                if cmd.commandType == "arm_home" then armedHome;
                if cmd.commandType == "arm_away" then armedAway;
            }

            state armedHome {
                accept cmd : DeviceCommand;
                if cmd.commandType == "disarm" then disarmed;
                if cmd.commandType == "arm_away" then armedAway;
            }

            state armedAway {
                accept cmd : DeviceCommand;
                if cmd.commandType == "disarm" then disarmed;
            }
        }
    }

    part def DataProcessor {
        action def ProcessSensorData {
            in rawData : SensorReading;
            out processedData : SensorReading;
        }

        action def AggregateData {
            in dataStream : SensorReading[*];
            out summary : String;
        }

        action def AnalyzeTrends {
            in historicalData : SensorReading[*];
            out insights : String;
        }
    }

    action def CollectSensorData {
        in sensors : TemperatureSensor[*];
        in humiditySensors : HumiditySensor[*];
        in motionSensors : MotionSensor[*];
        out aggregatedData : SensorReading;
    }

    action def ProcessUserCommand {
        in userInput : DeviceCommand;
        out deviceCommands : DeviceCommand[*];
    }

    action def ControlDevice {
        in command : DeviceCommand;
        in targetDevice : SmartDevice;
        out executionStatus : Boolean;
    }

    action def ManageHomeAutomation {
        in userCommands : DeviceCommand[*];
        in sensorInputs : SensorReading[*];
        out deviceControls : DeviceCommand[*];
        out systemState : String;

        first start;
        then merge continuousOperation;

        action collectSensors : CollectSensorData {
            in sensors;
            in humiditySensors;
            in motionSensors;
            out aggregatedData;
        }

        then action processData {
            in rawData = collectSensors.aggregatedData;
            out processedData : SensorReading;
        }

        then decide;
            if processData.processedData.temperature > 24.0 then activateCooling;
            if processData.processedData.lightLevel < 50.0 then turnOnLights;
            if processData.processedData.motionDetected then checkSecurity;

        action activateCooling : ControlDevice {
            in command;
            in targetDevice;
            out executionStatus;
        }
        then continuousOperation;

        action turnOnLights : ControlDevice {
            in command;
            in targetDevice;
            out executionStatus;
        }
        then continuousOperation;

        action checkSecurity {
            in deviceStatuses : DeviceState[*];
            in sensorData : SensorReading;
            out events : SecurityEvent[*];
        }
        then continuousOperation;

        then action syncCloud {
            in data : SensorReading;
            out success : Boolean;
        }

        then continuousOperation;
    }

    part def SmartHomeHub {
        doc /* 
            The Smart Home Hub is the central intelligent controller that integrates 
            all connected smart devices, processes environmental data, executes automation 
            rules, manages security protocols, and provides unified control through local 
            and remote interfaces. Its primary function is to create a seamless, automated, 
            and secure home environment by coordinating device interactions based on user 
            preferences, environmental conditions, and learned patterns.
        */
    }

    part smartHomeHub : SmartHomeHub {
        part communicationModule : CommunicationModule {
            attribute protocol = "WiFi/Zigbee/Z-Wave";
            attribute signalStrength = 85.0;
        }

        part automationEngine : AutomationEngine;

        part securityManager : SecurityManager {
            attribute currentSecurityMode = SecurityMode::disarmed;
            attribute alertsEnabled = true;
        }

        part dataProcessor : DataProcessor;

        part livingRoomTempSensor : TemperatureSensor {
            attribute deviceId = "TEMP_LR_001";
            attribute deviceType = "Temperature Sensor";
            attribute currentTemperature = 22.5;
            attribute currentState = DeviceState::online;
        }

        part bedroomTempSensor : TemperatureSensor {
            attribute deviceId = "TEMP_BR_001";
            attribute deviceType = "Temperature Sensor";
            attribute currentTemperature = 21.0;
            attribute currentState = DeviceState::online;
        }

        part livingRoomHumiditySensor : HumiditySensor {
            attribute deviceId = "HUM_LR_001";
            attribute deviceType = "Humidity Sensor";
            attribute currentHumidity = 45.0;
            attribute currentState = DeviceState::online;
        }

        part hallwayMotionSensor : MotionSensor {
            attribute deviceId = "MOT_HW_001";
            attribute deviceType = "Motion Sensor";
            attribute motionDetected = false;
            attribute currentState = DeviceState::online;
        }

        part mainThermostat : SmartThermostat {
            attribute deviceId = "THERM_001";
            attribute deviceType = "Smart Thermostat";
            attribute targetTemperature = 22.0;
            attribute currentMode = HVACMode::auto;
            attribute fanSpeed = 50.0;
            attribute currentState = DeviceState::online;
        }

        part livingRoomLight : SmartLight {
            attribute deviceId = "LIGHT_LR_001";
            attribute deviceType = "Smart Light";
            attribute brightness = 75.0;
            attribute colorTemperature = 3000.0;
            attribute isOn = true;
            attribute currentState = DeviceState::online;
        }

        part bedroomLight : SmartLight {
            attribute deviceId = "LIGHT_BR_001";
            attribute deviceType = "Smart Light";
            attribute brightness = 50.0;
            attribute colorTemperature = 2700.0;
            attribute isOn = false;
            attribute currentState = DeviceState::online;
        }

        part frontDoorLock : SmartLock {
            attribute deviceId = "LOCK_FD_001";
            attribute deviceType = "Smart Lock";
            attribute isLocked = true;
            attribute accessCode = "encrypted_code";
            attribute currentState = DeviceState::online;
        }

        part frontDoorCamera : SecurityCamera {
            attribute deviceId = "CAM_FD_001";
            attribute deviceType = "Security Camera";
            attribute isRecording = true;
            attribute resolution = "1080p";
            attribute currentState = DeviceState::online;
        }

        port userInterface : UserInterfacePort;
        port cloudConnection : CloudConnectivityPort;

        connect livingRoomTempSensor.dataPort to dataProcessor;
        connect bedroomTempSensor.dataPort to dataProcessor;
        connect livingRoomHumiditySensor.dataPort to dataProcessor;
        connect hallwayMotionSensor.dataPort to dataProcessor;

        connect mainThermostat.controlPort to automationEngine;
        connect livingRoomLight.controlPort to automationEngine;
        connect bedroomLight.controlPort to automationEngine;
        connect frontDoorLock.controlPort to securityManager;
        connect frontDoorCamera.controlPort to securityManager;

        connect communicationModule.cloudPort to cloudConnection;

        perform action orchestrate : ManageHomeAutomation {
            in userCommands;
            in sensorInputs;
            out deviceControls;
            out systemState;
        }
    }

    requirement def CentralControlRequirement {
        doc /* 
            The Smart Home Hub shall provide centralized control and monitoring 
            of all connected smart devices within the home network with 99.9% uptime.
        */
        subject smartHomeHub;
        require constraint {
            smartHomeHub.communicationModule.protocol == "WiFi/Zigbee/Z-Wave"
        }
    }

    requirement def AutomationRequirement {
        doc /* 
            The Smart Home Hub shall execute automation rules based on sensor 
            data and user-defined conditions with response time less than 500ms.
        */
        subject smartHomeHub;
        require constraint {
            smartHomeHub.automationEngine.activeRules->size() >= 0
        }
    }

    requirement def SecurityRequirement {
        doc /* 
            The Smart Home Hub shall monitor security devices continuously and 
            generate alerts for unauthorized access within 1 second of detection.
        */
        subject smartHomeHub;
        require constraint {
            smartHomeHub.securityManager.alertsEnabled == true
        }
    }

    requirement def DataProcessingRequirement {
        doc /* 
            The Smart Home Hub shall collect, process, and aggregate sensor 
            data from all connected devices at minimum 1Hz sampling rate.
        */
        subject smartHomeHub;
    }

    requirement def CloudConnectivityRequirement {
        doc /* 
            The Smart Home Hub shall maintain connectivity with cloud services 
            for remote access, data backup, and software updates with 128-bit encryption.
        */
        subject smartHomeHub;
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* 
            The Smart Home Hub shall optimize energy consumption by coordinating 
            HVAC and lighting systems to reduce total home energy usage by at least 15%.
        */
        subject smartHomeHub;
    }

    requirement smartHomeHubRequirements {
        doc /* 
            Top-level requirements for the Smart Home Hub system defining 
            its core capabilities, performance metrics, and operational constraints.
        */
        require CentralControlRequirement;
        require AutomationRequirement;
        require SecurityRequirement;
        require DataProcessingRequirement;
        require CloudConnectivityRequirement;
        require EnergyEfficiencyRequirement;
    }
}
