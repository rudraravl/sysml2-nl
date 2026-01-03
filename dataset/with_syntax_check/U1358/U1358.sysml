package 'QIVICON Smart Home System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeviceID;
    attribute def SecurityToken;
    attribute def NetworkAddress;
    
    attribute def TemperatureSetpoint :> ISQ::ThermodynamicTemperatureValue;
    attribute def PowerConsumption :> ISQ::PowerValue;
    attribute def EnergyUsage :> ISQ::EnergyValue;
    attribute def DataRate :> Real;
    
    enum def DeviceStatus {
        online;
        offline;
        error;
        standby;
    }
    
    enum def SecurityMode {
        disarmed;
        homeMode;
        awayMode;
        nightMode;
    }
    
    enum def HeatingMode {
        off;
        heating;
        cooling;
        auto;
    }
    
    port def CommunicationPort {
        in commandIn : String;
        out statusOut : String;
        out dataOut : Real;
    }
    
    port def NetworkPort {
        in dataReceived : String;
        out dataTransmitted : String;
        attribute bandwidth : DataRate;
    }
    
    port def PowerPort {
        in powerSupply : ISQ::PowerValue;
        out powerDraw : ISQ::PowerValue;
    }
    
    port def SensorPort {
        out sensorReading : Real;
        out timestamp : String;
    }
    
    part def SmartDevice {
        attribute id : DeviceID;
        attribute status : DeviceStatus;
        attribute firmwareVersion : String;
        port commPort : CommunicationPort;
        port netPort : NetworkPort;
        port pwrPort : PowerPort;
    }
    
    part def HeatingThermostat :> SmartDevice {
        attribute currentTemp : ISQ::ThermodynamicTemperatureValue;
        attribute targetTemp : ISQ::ThermodynamicTemperatureValue;
        attribute mode : HeatingMode;
        attribute valvePosition : Real;
        
        action controlHeating {
            in measuredTemp : ISQ::ThermodynamicTemperatureValue;
            in setpoint : ISQ::ThermodynamicTemperatureValue;
            out heatingActive : Boolean;
            out valveCmd : Real;
            
            first start;
            then action readTemperature {
                out currentReading := measuredTemp;
            }
            then decide;
                if readTemperature.currentReading < setpoint then enableHeating;
                if readTemperature.currentReading >= setpoint then disableHeating;
            action enableHeating {
                assign heatingActive := true;
                assign valveCmd := 1.0;
            }
            then done;
            action disableHeating {
                assign heatingActive := false;
                assign valveCmd := 0.0;
            }
            then done;
        }
    }
    
    part def SmartLightBulb :> SmartDevice {
        attribute brightness : Real;
        attribute colorTemp : Real;
        attribute isOn : Boolean;
        attribute powerUsage : ISQ::PowerValue;
        
        action adjustLight {
            in targetBrightness : Real;
            in targetColor : Real;
            out lightCommand : String;
            
            first start;
            then action validateInputs {
                out validBrightness : Real;
                out validColor : Real;
                assign validBrightness := targetBrightness;
                assign validColor := targetColor;
            }
            then action applySettings {
                assign brightness := validateInputs.validBrightness;
                assign colorTemp := validateInputs.validColor;
                assign lightCommand := "LIGHT_ADJUSTED";
            }
            then done;
        }
    }
    
    part def DoorWindowSensor :> SmartDevice {
        attribute isOpen : Boolean;
        attribute batteryLevel : Real;
        port sensorPort : SensorPort;
        
        action detectState {
            out openState : Boolean;
            out alertTriggered : Boolean;
            
            loop {
                action checkSensor {
                    out detected : Boolean;
                    assign detected := isOpen;
                }
                then decide;
                    if checkSensor.detected then reportOpen;
                    else reportClosed;
                action reportOpen {
                    assign openState := true;
                    assign alertTriggered := true;
                }
                then continueMonitoring;
                action reportClosed {
                    assign openState := false;
                    assign alertTriggered := false;
                }
                then continueMonitoring;
                action continueMonitoring;
            }
        }
    }
    
    part def SmartPlug :> SmartDevice {
        attribute switchState : Boolean;
        attribute currentPower : ISQ::PowerValue;
        attribute totalEnergy : ISQ::EnergyValue;
        attribute maxLoad : ISQ::PowerValue;
        
        action monitorPower {
            out powerReading : ISQ::PowerValue;
            out energyTotal : ISQ::EnergyValue;
            
            first start;
            then action measureCurrent {
                assign powerReading := currentPower;
            }
            then action accumulateEnergy {
                assign energyTotal := totalEnergy;
            }
            then done;
        }
        
        action switchControl {
            in command : Boolean;
            out newState : Boolean;
            
            first start;
            then decide;
                if command then turnOn;
                else turnOff;
            action turnOn {
                assign switchState := true;
                assign newState := true;
            }
            then done;
            action turnOff {
                assign switchState := false;
                assign newState := false;
            }
            then done;
        }
    }
    
    part def MotionSensor :> SmartDevice {
        attribute motionDetected : Boolean;
        attribute sensitivity : Real;
        attribute lastTriggerTime : String;
        port sensorPort : SensorPort;
        
        action monitorMotion {
            out motionEvent : Boolean;
            out eventTime : String;
            
            loop {
                action scanArea {
                    out detected : Boolean;
                }
                then decide;
                    if scanArea.detected then triggerMotion;
                    else noMotion;
                action triggerMotion {
                    assign motionEvent := true;
                    assign eventTime := "TIMESTAMP";
                    assign motionDetected := true;
                }
                then continueScanning;
                action noMotion {
                    assign motionEvent := false;
                    assign motionDetected := false;
                }
                then continueScanning;
                action continueScanning;
            }
        }
    }
    
    part def QIVICONHomeBase {
        attribute baseId : DeviceID;
        attribute securityToken : SecurityToken;
        attribute connectedDeviceCount : Integer;
        attribute systemMode : SecurityMode;
        
        port cloudPort : NetworkPort;
        port localPort : NetworkPort;
        port devicePorts : CommunicationPort[*];
        
        state def HomeBaseController {
            entry; then Initializing;
            
            state Initializing;
            
            state Operational {
                entry; then Monitoring;
                
                state Monitoring {
                    entry assign systemMode := SecurityMode::homeMode;
                }
                
                state AlertMode {
                    entry assign systemMode := SecurityMode::awayMode;
                }
                
                transition monitorToAlert
                    first Monitoring
                    accept securityEvent : String
                    then AlertMode;
                
                transition alertToMonitor
                    first AlertMode
                    accept clearEvent : String
                    then Monitoring;
            }
            
            transition initToOperational
                first Initializing
                accept startupComplete : String
                then Operational;
        }
        
        action routeCommands {
            in cloudCommand : String;
            in deviceId : DeviceID;
            out deviceCommand : String;
            out routingSuccess : Boolean;
            
            first start;
            then action authenticateCommand {
                in cmd := cloudCommand;
                out authenticated : Boolean;
                assign authenticated := true;
            }
            then decide;
                if authenticateCommand.authenticated then processCommand;
                else rejectCommand;
            action processCommand {
                action parseCommand {
                    assign deviceCommand := cloudCommand;
                }
                then action forwardToDevice {
                    assign routingSuccess := true;
                }
            }
            then done;
            action rejectCommand {
                assign routingSuccess := false;
            }
            then done;
        }
        
        action aggregateDeviceData {
            in deviceReadings : Real[*];
            in deviceStatuses : String[*];
            out aggregatedReport : String;
            
            first start;
            then action collectData {
                out dataCount : Integer;
            }
            then action formatReport {
                assign aggregatedReport := "DEVICE_STATUS_REPORT";
            }
            then action transmitToCloud;
            then done;
        }
    }
    
    part def CloudBackend {
        attribute platformId : String;
        attribute activeUsers : Integer;
        
        port gatewayInterface : NetworkPort;
        port userInterface : NetworkPort;
        port apiInterface : NetworkPort;
        
        action processUserCommand {
            in userRequest : String;
            in userId : String;
            out homeBaseCommand : String;
            out responseCode : Integer;
            
            first start;
            then action authenticateUser {
                in user := userId;
                out authorized : Boolean;
                assign authorized := true;
            }
            then decide;
                if authenticateUser.authorized then translateCommand;
                else rejectRequest;
            action translateCommand {
                assign homeBaseCommand := userRequest;
                assign responseCode := 200;
            }
            then action sendToHomeBase;
            then done;
            action rejectRequest {
                assign responseCode := 401;
            }
            then done;
        }
        
        action storeDeviceData {
            in deviceData : String;
            in timestamp : String;
            
            first start;
            then action validateData;
            then action persistToDatabase;
            then action updateAnalytics;
            then action triggerAutomation;
            then done;
        }
        
        action executeAutomationRule {
            in ruleTrigger : String;
            in deviceStates : String[*];
            out automationCommands : String[*];
            
            first start;
            then action evaluateConditions {
                out conditionsMet : Boolean;
                assign conditionsMet := true;
            }
            then decide;
                if evaluateConditions.conditionsMet then generateCommands;
                else skipAutomation;
            action generateCommands {
                assign automationCommands := ("CMD1", "CMD2");
            }
            then done;
            action skipAutomation;
            then done;
        }
    }
    
    part def MobileApp {
        attribute userId : String;
        attribute sessionToken : SecurityToken;
        attribute appVersion : String;
        
        port cloudConnection : NetworkPort;
        
        action sendDeviceCommand {
            in deviceId : DeviceID;
            in commandType : String;
            in commandValue : Real;
            out cloudRequest : String;
            
            first start;
            then action buildRequest {
                assign cloudRequest := commandType;
            }
            then action transmitRequest;
            then action awaitResponse;
            then done;
        }
        
        action displayDeviceStatus {
            in statusData : String;
            
            first start;
            then action parseStatusData;
            then action updateUserInterface;
            then action notifyUser;
            then done;
        }
    }
    
    connection def NetworkConnection {
        end source : NetworkPort;
        end target : NetworkPort;
    }
    
    connection def DeviceConnection {
        end hub : CommunicationPort;
        end device : CommunicationPort;
    }
    
    part def QIVICONSmartHomeSystem {
        doc /*
            The QIVICON Smart Home System is an integrated home automation platform
            that connects and manages diverse smart devices through a central home base.
            
            Primary Function:
            The system enables centralized monitoring and control of connected smart home
            devices including heating thermostats, lighting, security sensors, and smart
            plugs. Users interact with their home remotely via a mobile application that
            communicates through a cloud backend to the QIVICON home base, which coordinates
            all connected devices over a local network.
            
            The system provides:
            - Climate control through intelligent heating management
            - Lighting automation and remote control
            - Security monitoring via door/window and motion sensors
            - Energy management through smart plug monitoring
            - Cloud-based data storage and automation rules
            - Mobile access for remote monitoring and control
        */
    }
    
    part qiviconSmartHome : QIVICONSmartHomeSystem {
        part homeBase : QIVICONHomeBase {
            perform action routeCommands[*];
            perform action aggregateDeviceData[*];
        }
        
        part cloudBackend : CloudBackend {
            perform action processUserCommand[*];
            perform action storeDeviceData[*];
            perform action executeAutomationRule[*];
        }
        
        part mobileApp : MobileApp {
            perform action sendDeviceCommand[*];
            perform action displayDeviceStatus[*];
        }
        
        part livingRoomThermostat : HeatingThermostat {
            perform action controlHeating[*];
        }
        
        part bedroomThermostat : HeatingThermostat {
            perform action controlHeating[*];
        }
        
        part kitchenLight : SmartLightBulb {
            perform action adjustLight[*];
        }
        
        part hallwayLight : SmartLightBulb {
            perform action adjustLight[*];
        }
        
        part bedroomLight : SmartLightBulb {
            perform action adjustLight[*];
        }
        
        part frontDoorSensor : DoorWindowSensor {
            perform action detectState[*];
        }
        
        part windowSensor : DoorWindowSensor {
            perform action detectState[*];
        }
        
        part livingRoomMotion : MotionSensor {
            perform action monitorMotion[*];
        }
        
        part hallwayMotion : MotionSensor {
            perform action monitorMotion[*];
        }
        
        part coffeeMakerPlug : SmartPlug {
            perform action monitorPower[*];
            perform action switchControl[*];
        }
        
        part tvPlug : SmartPlug {
            perform action monitorPower[*];
            perform action switchControl[*];
        }
        
        connection cloudToHomeBase : NetworkConnection
            connect cloudBackend.gatewayInterface to homeBase.cloudPort;
        
        connection appToCloud : NetworkConnection
            connect mobileApp.cloudConnection to cloudBackend.userInterface;
        
        connection homeBaseToLivingRoomThermostat : DeviceConnection
            connect homeBase.devicePorts[1] to livingRoomThermostat.commPort;
        
        connection homeBaseToBedroomThermostat : DeviceConnection
            connect homeBase.devicePorts[2] to bedroomThermostat.commPort;
        
        connection homeBaseToKitchenLight : DeviceConnection
            connect homeBase.devicePorts[3] to kitchenLight.commPort;
        
        connection homeBaseToHallwayLight : DeviceConnection
            connect homeBase.devicePorts[4] to hallwayLight.commPort;
        
        connection homeBaseToBedroomLight : DeviceConnection
            connect homeBase.devicePorts[5] to bedroomLight.commPort;
        
        connection homeBaseToFrontDoor : DeviceConnection
            connect homeBase.devicePorts[6] to frontDoorSensor.commPort;
        
        connection homeBaseToWindow : DeviceConnection
            connect homeBase.devicePorts[7] to windowSensor.commPort;
        
        connection homeBaseToLivingRoomMotion : DeviceConnection
            connect homeBase.devicePorts[8] to livingRoomMotion.commPort;
        
        connection homeBaseToHallwayMotion : DeviceConnection
            connect homeBase.devicePorts[9] to hallwayMotion.commPort;
        
        connection homeBaseToCoffeePlug : DeviceConnection
            connect homeBase.devicePorts[10] to coffeeMakerPlug.commPort;
        
        connection homeBaseToTVPlug : DeviceConnection
            connect homeBase.devicePorts[11] to tvPlug.commPort;
    }
    
    action def ManageSmartHome {
        in userCommand : String;
        in deviceId : DeviceID;
        out systemResponse : String;
        out executionStatus : Boolean;
        
        first start;
        then merge controlLoop;
        
        action receiveUserInput {
            in request := userCommand;
            out parsedCommand : String;
            assign parsedCommand := request;
        }
        then action authenticateRequest {
            in command : String;
            out authorized : Boolean;
            assign authorized := true;
        }
        then decide;
            if authenticateRequest.authorized then routeToHomeBase;
            else rejectRequest;
        action routeToHomeBase {
            in command : String;
            out homeBaseCommand : String;
            assign homeBaseCommand := command;
        }
        then action executeOnDevice {
            in deviceCommand : String;
            out deviceResponse : String;
            assign deviceResponse := "EXECUTED";
        }
        then action collectDeviceStatus {
            in response : String;
            out statusData : String;
            assign statusData := response;
        }
        then action updateCloud {
            in data : String;
        }
        then action notifyUser {
            assign systemResponse := "COMMAND_COMPLETED";
            assign executionStatus := true;
        }
        then controlLoop;
        action rejectRequest {
            assign systemResponse := "UNAUTHORIZED";
            assign executionStatus := false;
        }
        then done;
    }
    
    requirement def SmartHomeSystemRequirements {
        doc /* Requirements for QIVICON Smart Home System */
        
        requirement deviceIntegration {
            doc /* System shall integrate multiple heterogeneous smart devices */
            subject system : QIVICONSmartHomeSystem;
        }
        
        requirement remoteControl {
            doc /* Users shall control devices remotely via mobile application */
            subject app : MobileApp;
        }
        
        requirement realTimeMonitoring {
            doc /* System shall provide real-time device status monitoring */
            subject homeBase : QIVICONHomeBase;
        }
        
        requirement energyTracking {
            doc /* System shall monitor and report energy consumption */
            subject plug : SmartPlug;
        }
        
        requirement securityMonitoring {
            doc /* System shall detect and alert on security events */
            subject sensor : DoorWindowSensor;
        }
        
        requirement cloudConnectivity {
            doc /* Home base shall maintain reliable cloud connection */
            subject homeBase : QIVICONHomeBase;
        }
        
        requirement automationSupport {
            doc /* System shall support rule-based automation */
            subject cloud : CloudBackend;
        }
        
        requirement temperatureControl {
            doc /* Thermostats shall maintain temperature within setpoint range */
            subject thermostat : HeatingThermostat;
        }
    }
    
    requirement systemRequirements : SmartHomeSystemRequirements {
        require deviceIntegration;
        require remoteControl;
        require realTimeMonitoring;
        require energyTracking;
        require securityMonitoring;
        require cloudConnectivity;
        require automationSupport;
        require temperatureControl;
    }
}
