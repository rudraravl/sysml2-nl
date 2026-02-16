package SmartThingsHomeAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def SensorReading {
        attribute timestamp : String;
        attribute deviceID : String;
        attribute value : Real;
    }

    item def TemperatureReading :> SensorReading {
        attribute temperatureValue : ISQ::ThermodynamicTemperatureValue;
    }

    item def MotionEvent :> SensorReading {
        attribute motionDetected : Boolean;
        attribute location : String;
    }

    item def IlluminanceReading :> SensorReading {
        attribute lightLevel : ISQ::IlluminanceValue;
    }

    item def DeviceCommand {
        attribute targetDeviceID : String;
        attribute commandType : String;
        attribute timestamp : String;
    }

    item def LightingCommand :> DeviceCommand {
        attribute powerState : Boolean;
        attribute brightnessLevel : Real;
    }

    item def ThermostatCommand :> DeviceCommand {
        attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute hvacMode : String;
    }

    item def LockCommand :> DeviceCommand {
        attribute lockState : Boolean;
    }

    item def AutomationRule {
        attribute ruleID : String;
        attribute triggerType : String;
        attribute condition : String;
        attribute actionSpec : String;
        attribute enabled : Boolean;
    }

    item def StatusReport {
        attribute deviceID : String;
        attribute operationalState : String;
        attribute lastUpdate : String;
    }

    port def SensorDataPort {
        out reading : SensorReading;
    }

    port def ActuatorCommandPort {
        in command : DeviceCommand;
        out status : StatusReport;
    }

    port def HubInterfacePort {
        in sensorData : SensorReading;
        out deviceCommand : DeviceCommand;
        in deviceStatus : StatusReport;
    }

    port def UserAppPort {
        in userCommand : DeviceCommand;
        out systemStatus : StatusReport;
        out notification : String;
    }

    part def TemperatureSensor {
        attribute sensorID : String;
        attribute currentReading : ISQ::ThermodynamicTemperatureValue;
        port dataOut : SensorDataPort;
    }

    part def MotionSensor {
        attribute sensorID : String;
        attribute detectionRange : ISQ::LengthValue;
        port dataOut : SensorDataPort;
    }

    part def LightSensor {
        attribute sensorID : String;
        attribute sensitivity : Real;
        port dataOut : SensorDataPort;
    }

    part def SmartLight {
        attribute deviceID : String;
        attribute currentBrightness : Real;
        attribute isPoweredOn : Boolean;
        attribute powerConsumption : ISQ::PowerValue;
        port controlIn : ActuatorCommandPort;
    }

    part def SmartThermostat {
        attribute deviceID : String;
        attribute currentTemp : ISQ::ThermodynamicTemperatureValue;
        attribute targetTemp : ISQ::ThermodynamicTemperatureValue;
        attribute operatingMode : String;
        port controlIn : ActuatorCommandPort;
        port tempSensorOut : SensorDataPort;
    }

    part def SmartDoorLock {
        attribute deviceID : String;
        attribute isLocked : Boolean;
        attribute batteryLevel : Real;
        port controlIn : ActuatorCommandPort;
    }

    part def SmartThingsHub {
        attribute hubID : String;
        attribute connectedDeviceCount : Integer;
        attribute networkStatus : String;

        port deviceInterface : HubInterfacePort[*];
        port userInterface : UserAppPort;

        part ruleEngine {
            attribute activeRules : AutomationRule[*];
        }

        part eventProcessor;

        part commandDispatcher;
    }

    part def MobileApplication {
        attribute appVersion : String;
        attribute userID : String;
        port hubConnection : UserAppPort;
    }

    action def CollectSensorData {
        in sensorInputs : SensorReading[*];
        out aggregatedData : SensorReading[*];
    }

    action def EvaluateAutomationConditions {
        in sensorData : SensorReading[*];
        in automationRules : AutomationRule[*];
        out triggeredActions : DeviceCommand[*];
    }

    action def DispatchDeviceCommands {
        in commands : DeviceCommand[*];
        out commandResults : StatusReport[*];
    }

    action def GenerateUserNotifications {
        in events : SensorReading[*];
        in statuses : StatusReport[*];
        out notifications : String[*];
    }

    action def SmartHomeAutomationFlow {
        first start;

        then merge monitoringLoop;

        then action collectData : CollectSensorData {
            in sensorInputs[*];
            out aggregatedData[*];
        }

        then action evaluateConditions : EvaluateAutomationConditions {
            in sensorData = collectData.aggregatedData;
            in automationRules[*];
            out triggeredActions[*];
        }

        then decide;
            if evaluateConditions.triggeredActions->notEmpty() then dispatchCommands;
            if evaluateConditions.triggeredActions->isEmpty() then monitoringLoop;

        action dispatchCommands : DispatchDeviceCommands {
            in commands = evaluateConditions.triggeredActions;
            out commandResults[*];
        }

        then action notifyUsers : GenerateUserNotifications {
            in events = collectData.aggregatedData;
            in statuses = dispatchCommands.commandResults;
            out notifications[*];
        }

        then monitoringLoop;
    }

    state def SmartDeviceState {
        entry action initializeDevice;

        state Disconnected;
        state Connected {
            state Idle;
            state Operating {
                state Sensing;
                state Actuating;
            }
            state Updating;
        }
        state Fault;

        transition connect
            first Disconnected
            accept connectionEstablished
            then Connected.Idle;

        transition activate
            first Connected.Idle
            accept commandReceived
            then Connected.Operating;

        transition completeOperation
            first Connected.Operating
            accept operationComplete
            then Connected.Idle;

        transition updateFirmware
            first Connected.Idle
            accept updateRequested
            then Connected.Updating;

        transition finishUpdate
            first Connected.Updating
            accept updateComplete
            then Connected.Idle;

        transition detectFault
            first Connected
            accept faultDetected
            then Fault;

        transition recover
            first Fault
            accept recoveryComplete
            then Connected.Idle;

        transition disconnect
            first Connected
            accept connectionLost
            then Disconnected;
    }

    part smartHomeSystem : SmartThingsHub {
        attribute hubID = "HUB-001";

        part livingRoomTempSensor : TemperatureSensor {
            attribute sensorID = "TEMP-LR-01";
        }

        part hallwayMotionSensor : MotionSensor {
            attribute sensorID = "MOTION-HALL-01";
            attribute detectionRange = ISQ::m(5.0);
        }

        part bedroomLightSensor : LightSensor {
            attribute sensorID = "LIGHT-BR-01";
        }

        part livingRoomLight : SmartLight {
            attribute deviceID = "LIGHT-LR-01";
            attribute powerConsumption = ISQ::W(12.0);
        }

        part bedroomLight : SmartLight {
            attribute deviceID = "LIGHT-BR-01";
            attribute powerConsumption = ISQ::W(9.0);
        }

        part mainThermostat : SmartThermostat {
            attribute deviceID = "THERMO-MAIN-01";
            attribute targetTemp = ISQ::degC(22.0);
        }

        part frontDoorLock : SmartDoorLock {
            attribute deviceID = "LOCK-FRONT-01";
        }

        part userApp : MobileApplication {
            attribute appVersion = "3.2.1";
        }

        perform action orchestrateAutomation : SmartHomeAutomationFlow;

        connection livingRoomTempSensor.dataOut to deviceInterface;
        connection hallwayMotionSensor.dataOut to deviceInterface;
        connection bedroomLightSensor.dataOut to deviceInterface;
        connection deviceInterface to livingRoomLight.controlIn;
        connection deviceInterface to bedroomLight.controlIn;
        connection deviceInterface to mainThermostat.controlIn;
        connection mainThermostat.tempSensorOut to deviceInterface;
        connection deviceInterface to frontDoorLock.controlIn;
        connection userInterface to userApp.hubConnection;
    }

    occurrence def MotionActivatedLightingScenario {
        ref part hub :>> smartHomeSystem;
        ref part motionSensor :>> smartHomeSystem.hallwayMotionSensor;
        ref part lightSensor :>> smartHomeSystem.bedroomLightSensor;
        ref part light :>> smartHomeSystem.bedroomLight;
        ref part app :>> smartHomeSystem.userApp;

        message motionDetectedMsg of motionData : MotionEvent
            from motionSensor.dataOut.reading
            to hub.deviceInterface.sensorData;

        then message lightLevelMsg of luxData : IlluminanceReading
            from lightSensor.dataOut.reading
            to hub.deviceInterface.sensorData;

        then message lightOnCmd of lightCmd : LightingCommand
            from hub.deviceInterface.deviceCommand
            to light.controlIn.command;

        then message lightStatusMsg of lightStatus : StatusReport
            from light.controlIn.status
            to hub.deviceInterface.deviceStatus;

        then message userNotificationMsg of notification : String
            from hub.userInterface.notification
            to app.hubConnection.notification;
    }

    occurrence def ClimateControlScenario {
        ref part hub :>> smartHomeSystem;
        ref part tempSensor :>> smartHomeSystem.livingRoomTempSensor;
        ref part thermostat :>> smartHomeSystem.mainThermostat;

        message tempReadingMsg of tempData : TemperatureReading
            from tempSensor.dataOut.reading
            to hub.deviceInterface.sensorData;

        then message thermostatCmdMsg of thermoCmd : ThermostatCommand
            from hub.deviceInterface.deviceCommand
            to thermostat.controlIn.command;

        then message thermostatStatusMsg of thermoStatus : StatusReport
            from thermostat.controlIn.status
            to hub.deviceInterface.deviceStatus;
    }

    requirement def SystemRequirement;

    requirement <'STH-REQ-001'> primarySystemFunction : SystemRequirement {
        doc /* The SmartThings home automation system shall continuously monitor environmental 
               conditions and device states through connected sensors, automatically evaluate 
               predefined automation rules based on collected data, execute appropriate control 
               commands to actuators and smart devices, and provide real-time status updates 
               and notifications to users through the mobile application interface. */

        subject smartHomeSystem;

        require continuousSensorMonitoring;
        require automatedRuleEvaluation;
        require reliableDeviceControl;
        require userNotificationDelivery;
    }

    requirement <'STH-REQ-002'> continuousSensorMonitoring : SystemRequirement {
        doc /* The system shall collect and process sensor data from all connected devices 
               at intervals not exceeding 3 seconds to maintain current environmental awareness. */
    }

    requirement <'STH-REQ-003'> automatedRuleEvaluation : SystemRequirement {
        doc /* The system shall evaluate all active automation rules within 500 milliseconds 
               of receiving new sensor data to ensure timely automated responses. */
    }

    requirement <'STH-REQ-004'> reliableDeviceControl : SystemRequirement {
        doc /* The system shall successfully execute device control commands with a reliability 
               rate of at least 99.9% under normal operating conditions. */
    }

    requirement <'STH-REQ-005'> userNotificationDelivery : SystemRequirement {
        doc /* The system shall deliver event notifications to the mobile application within 
               1.5 seconds of triggering event detection. */
    }

    requirement <'STH-REQ-006'> deviceInteroperability : SystemRequirement {
        doc /* The system shall support seamless integration and communication with at least 
               100 different device types from multiple manufacturers using standard protocols. */
    }

    requirement <'STH-REQ-007'> systemScalability : SystemRequirement {
        doc /* The system shall support concurrent management of up to 250 connected devices 
               per hub without degradation in response time or reliability. */
    }

    requirement <'STH-REQ-008'> energyEfficiency : SystemRequirement {
        doc /* The system shall optimize device operation to reduce overall energy consumption 
               by at least 20% compared to manual control through intelligent scheduling and 
               occupancy-based automation. */
    }
}
