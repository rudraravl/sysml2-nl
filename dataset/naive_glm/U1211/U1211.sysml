package SmartHomeHub {

    value type TemperatureValue :> Real { unit 'degC'; }
    value type HumidityValue :> Real { unit '%'; }
    value type BrightnessValue :> Real { unit '%'; }
    value type PowerValue :> Real { unit 'W'; }
    value type TimeValue :> Real { unit 's'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type ColorValue :> String;
    value type BooleanValue :> Boolean;

    item def SensorData {
        value timestamp : TimeValue;
        attribute sensorId : String;
    }
    item def TemperatureData :> SensorData {
        value temperature : TemperatureValue;
    }
    item def HumidityData :> SensorData {
        value humidity : HumidityValue;
    }
    item def MotionData :> SensorData {
        value motionDetected : BooleanValue;
    }
    item def ProcessedData {
        value timestamp : TimeValue;
        ref sensorData : SensorData;
        attribute analysisResult : String;
    }
    item def DeviceCommand {
        attribute deviceId : String;
        attribute action : String;
        attribute value : String;
    }
    item def Alert {
        attribute message : String;
        attribute severity : String;
        value timestamp : TimeValue;
    }
    item def Rule {
        attribute name : String;
        attribute condition : String;
        attribute action : String;
        attribute enabled : BooleanValue;
    }
    item def SecurityEvent {
        attribute type : String;
        value timestamp : TimeValue;
    }
    item def VideoStream {
        attribute resolution : String;
        value frameRate : FrequencyValue;
    }

    port def DeviceSidePort {
        in data : SensorData;
        out command : DeviceCommand;
    }
    port def DevicePort {
        out data : SensorData;
        in command : DeviceCommand;
    }
    port def CloudClientPort {
        in remoteCommand : DeviceCommand;
        out alert : Alert;
    }
    port def CloudServicePort {
        in alert : Alert;
        out remoteCommand : DeviceCommand;
    }
    port def HubUserPort {
        in userCommand : DeviceCommand;
        out status : SensorData;
    }
    port def UserAppPort {
        out userCommand : DeviceCommand;
        in status : SensorData;
    }
    port def DataOutPort { out data : SensorData; }
    port def DataInPort { in data : SensorData; }
    port def ProcessedOutPort { out processed : ProcessedData; }
    port def ProcessedInPort { in processed : ProcessedData; }
    port def CommandOutPort { out command : DeviceCommand; }
    port def CommandInPort { in command : DeviceCommand; }
    port def AlertOutPort { out alert : Alert; }
    port def AlertInPort { in alert : Alert; }

    part def WiFiProtocol {
        attribute ssid : String;
        attribute connected : BooleanValue;
    }
    part def ZigbeeProtocol {
        attribute networkId : String;
        attribute connected : BooleanValue;
    }
    part def ZWaveProtocol {
        attribute homeId : String;
        attribute connected : BooleanValue;
    }
    part def CloudClient {
        attribute serverUrl : String;
        attribute linkUp : BooleanValue;
        attribute linkDown : BooleanValue;
    }

    part def CommunicationModule {
        port deviceInterface : DeviceSidePort;
        port cloudInterface : CloudClientPort;
        port userInterface : HubUserPort;
        port commandIn : CommandInPort;
        port sensorDataOut : DataOutPort;
        port userCommandOut : CommandOutPort;
        port alertIn : AlertInPort;

        part wifi : WiFiProtocol;
        part zigbee : ZigbeeProtocol;
        part zWave : ZWaveProtocol;
        part cloudClient : CloudClient;

        connect deviceInterface.data to sensorDataOut.data;
        connect userInterface.userCommand to userCommandOut.command;
        connect alertIn.alert to cloudInterface.alert;

        state machine ConnectionState {
            state Disconnected;
            state Connected;
            transition Disconnected to Connected when cloudClient.linkUp;
            transition Connected to Disconnected when cloudClient.linkDown;
        }
    }

    part def DataProcessor {
        port dataIn : DataInPort;
        port processedData : ProcessedOutPort;

        action processData {
            in data : SensorData;
            out processed : ProcessedData;
        }

        state machine ProcessingState {
            state Idle;
            state Processing;
            transition Idle to Processing when dataIn.data;
            transition Processing to Idle when processedData.processed;
        }
    }

    part def AutomationEngine {
        port sensorInput : ProcessedInPort;
        port commandOut : CommandOutPort;
        port userCommandIn : CommandInPort;

        attribute rules : Rule[*];

        action evaluateRules {
            in data : ProcessedData;
            in userCommand : DeviceCommand;
            out command : DeviceCommand;
        }

        state machine EngineState {
            state Idle;
            state Evaluating;
            state Executing;
            transition Idle to Evaluating when sensorInput.processed;
            transition Evaluating to Executing when evaluateRules.command;
            transition Executing to Idle when commandOut.command;
        }
    }

    part def SecurityManager {
        port sensorInput : ProcessedInPort;
        port commandOut : CommandOutPort;
        port userCommandIn : CommandInPort;
        port alertOut : AlertOutPort;

        attribute mode : String;

        state machine SecurityState {
            state Disarmed;
            state ArmedAway;
            state ArmedStay;

            transition Disarmed to ArmedAway when userCommandIn.command.action == "armAway";
            transition ArmedAway to Disarmed when userCommandIn.command.action == "disarm";
            transition Disarmed to ArmedStay when userCommandIn.command.action == "armStay";
            transition ArmedStay to Disarmed when userCommandIn.command.action == "disarm";

            transition ArmedAway to ArmedAway when sensorInput.processed.sensorData.motionDetected == true;
            transition ArmedStay to ArmedStay when sensorInput.processed.sensorData.motionDetected == true;
        }
    }

    part def Hub {
        part commModule : CommunicationModule;
        part automationEngine : AutomationEngine;
        part securityManager : SecurityManager;
        part dataProcessor : DataProcessor;

        connect commModule.sensorDataOut.data to dataProcessor.dataIn.data;
        connect dataProcessor.processedData.processed to automationEngine.sensorInput.processed;
        connect dataProcessor.processedData.processed to securityManager.sensorInput.processed;
        connect automationEngine.commandOut.command to commModule.commandIn.command;
        connect securityManager.commandOut.command to commModule.commandIn.command;
        connect securityManager.alertOut.alert to commModule.alertIn.alert;
        connect commModule.userCommandOut.command to securityManager.userCommandIn.command;
        connect commModule.userCommandOut.command to automationEngine.userCommandIn.command;
    }

    part def SmartDevice {
        port devicePort : DevicePort;
        attribute deviceId : String;
        attribute power : PowerValue;
    }

    part def EnvironmentalSensor :> SmartDevice {
        action sense {
            out data : SensorData;
        }
    }

    part def TemperatureSensor :> EnvironmentalSensor {
        redefinition sense {
            out data : TemperatureData;
        }
    }

    part def HumiditySensor :> EnvironmentalSensor {
        redefinition sense {
            out data : HumidityData;
        }
    }

    part def MotionSensor :> EnvironmentalSensor {
        redefinition sense {
            out data : MotionData;
        }
    }

    part def SmartThermostat :> SmartDevice {
        attribute currentTemperature : TemperatureValue;
        attribute targetTemperature : TemperatureValue;
        attribute mode : String;

        action setTemperature {
            in target : TemperatureValue;
        }
        action setMode {
            in mode : String;
        }
    }

    part def SmartLight :> SmartDevice {
        attribute brightness : BrightnessValue;
        attribute color : ColorValue;
        attribute on : BooleanValue;

        action setBrightness {
            in level : BrightnessValue;
        }
        action setColor {
            in color : ColorValue;
        }
        action toggle {
            in on : BooleanValue;
        }
    }

    part def SmartLock :> SmartDevice {
        attribute locked : BooleanValue;

        action lock;
        action unlock;
    }

    part def SecurityCamera :> SmartDevice {
        attribute recording : BooleanValue;
        out stream : VideoStream;

        action startRecording;
        action stopRecording;
    }

    part def CloudService {
        port cloudPort : CloudServicePort;
        attribute storageUrl : String;

        action backupData {
            in data : SensorData;
        }
        action sendAlert {
            in alert : Alert;
        }
    }

    part def UserApp {
        port userPort : UserAppPort;
        attribute userId : String;

        action sendCommand {
            out command : DeviceCommand;
        }
        action receiveAlert {
            in alert : Alert;
        }
    }

    part def SmartHomeSystem {
        part hub : Hub;
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part motionSensor : MotionSensor;
        part thermostat : SmartThermostat;
        part light : SmartLight;
        part lock : SmartLock;
        part camera : SecurityCamera;
        part cloud : CloudService;
        part userApp : UserApp;

        connect tempSensor.devicePort.data to hub.commModule.deviceInterface.data;
        connect humiditySensor.devicePort.data to hub.commModule.deviceInterface.data;
        connect motionSensor.devicePort.data to hub.commModule.deviceInterface.data;
        connect thermostat.devicePort.data to hub.commModule.deviceInterface.data;
        connect light.devicePort.data to hub.commModule.deviceInterface.data;
        connect lock.devicePort.data to hub.commModule.deviceInterface.data;
        connect camera.devicePort.data to hub.commModule.deviceInterface.data;

        connect hub.commModule.deviceInterface.command to tempSensor.devicePort.command;
        connect hub.commModule.deviceInterface.command to humiditySensor.devicePort.command;
        connect hub.commModule.deviceInterface.command to motionSensor.devicePort.command;
        connect hub.commModule.deviceInterface.command to thermostat.devicePort.command;
        connect hub.commModule.deviceInterface.command to light.devicePort.command;
        connect hub.commModule.deviceInterface.command to lock.devicePort.command;
        connect hub.commModule.deviceInterface.command to camera.devicePort.command;

        connect hub.commModule.cloudInterface.alert to cloud.cloudPort.alert;
        connect cloud.cloudPort.remoteCommand to hub.commModule.cloudInterface.remoteCommand;

        connect userApp.userPort.userCommand to hub.commModule.userInterface.userCommand;
        connect hub.commModule.userInterface.status to userApp.userPort.status;
    }

    requirement def HubFunctionalRequirement {
        subject : Hub;
    }

    requirement CentralControl :> HubFunctionalRequirement {
        doc /* The hub shall integrate, monitor, and control connected smart devices. */
    }

    requirement MultiProtocolCommunication :> HubFunctionalRequirement {
        doc /* The communication module shall support WiFi, Zigbee, and Z-Wave protocols. */
    }

    requirement CloudConnectivity :> HubFunctionalRequirement {
        doc /* The hub shall maintain a connection to cloud services for remote access and data backup. */
    }

    requirement AutomationRules :> HubFunctionalRequirement {
        doc /* The automation engine shall execute user-defined rules based on sensor data and time. */
    }

    requirement SecurityModes :> HubFunctionalRequirement {
        doc /* The security manager shall support armed away, armed stay, and disarmed modes. */
    }

    requirement DataProcessing :> HubFunctionalRequirement {
        doc /* The data processor shall collect and analyze information from all connected sensors. */
    }

    requirement RemoteControl :> HubFunctionalRequirement {
        doc /* Users shall be able to send direct commands to control devices locally or remotely. */
    }

    requirement SecurityResponse :> HubFunctionalRequirement {
        doc /* When motion is detected while armed, the hub shall lock doors, start camera recording, and send an alert. */
    }

    requirement TemperatureControl :> HubFunctionalRequirement {
        doc /* If a temperature sensor reports a room is too warm, the hub shall command the thermostat to cool. */
    }
}
