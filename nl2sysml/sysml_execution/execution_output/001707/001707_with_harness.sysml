package HomeKitSystem {
    attribute def networkAvailable;
    attribute def pairRequest;
    attribute def pairSuccess;
    attribute def pairFailure;
    attribute def commandComplete;
    attribute def networkLost;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeviceIdentifier;
    attribute def DeviceName;
    attribute def RoomName;
    attribute def SceneName;
    attribute def UserCredential;
    
    value def TemperatureSetting :> ISQ::TemperatureValue;
    value def BrightnessLevel :> Real {
        attribute constraint validRange { 0.0 <= self and self <= 100.0 }
    }
    value def LockStatus;
    value def PowerStatus;
    
    item def ControlMessage {
        attribute targetDevice : DeviceIdentifier;
        attribute commandType : String;
        attribute commandValue : Real;
    }
    
    item def StatusMessage {
        attribute sourceDevice : DeviceIdentifier;
        attribute deviceState : String;
        attribute timestamp : Real;
    }
    
    item def SensorData {
        attribute sensorID : DeviceIdentifier;
        attribute readingValue : Real;
        attribute readingType : String;
    }
    
    port def CommandPort {
        in command : ControlMessage;
        out status : StatusMessage;
    }
    
    port def DataPort {
        out data : SensorData;
    }
    
    port def NetworkPort {
        in incomingMessage : String;
        out outgoingMessage : String;
    }
    
    part def AccessoryDevice {
        attribute id : DeviceIdentifier;
        attribute name : DeviceName;
        attribute room : RoomName;
        attribute isReachable : Boolean;
        port controlPort : CommandPort;
        port networkPort : NetworkPort;
    }
    
    part def SmartLightBulb :> AccessoryDevice {
        attribute brightness : BrightnessLevel;
        attribute powerOn : PowerStatus;
        attribute colorTemperature : Real;
    }
    
    part def SmartThermostat :> AccessoryDevice {
        attribute currentTemperature : TemperatureSetting;
        attribute targetTemperature : TemperatureSetting;
        attribute mode : String;
        attribute fanSpeed : Real;
    }
    
    part def SmartDoorLock :> AccessoryDevice {
        attribute locked : LockStatus;
        attribute batteryLevel : Real;
    }
    
    part def MotionSensor :> AccessoryDevice {
        attribute motionDetected : Boolean;
        attribute lastMotionTime : Real;
        port sensorPort : DataPort;
    }
    
    part def TemperatureSensor :> AccessoryDevice {
        attribute temperature : TemperatureSetting;
        port sensorPort : DataPort;
    }
    
    part def HomeHub {
        attribute hubID : DeviceIdentifier;
        attribute registeredDevices : DeviceIdentifier[*];
        attribute activeScenes : SceneName[*];
        port hubNetwork : NetworkPort;
        port devicePorts[*] : CommandPort;
    }
    
    part def MobileApplication {
        attribute userID : String;
        attribute isAuthenticated : Boolean;
        port appNetwork : NetworkPort;
        port userControl : CommandPort;
    }
    
    part def AutomationController {
        attribute automationRules : String[*];
        attribute triggeredEvents : String[*];
        attribute scheduledTasks : String[*];
    }
    
    action def AuthenticateUser {
        in credentials : UserCredential;
        out authenticated : Boolean;
        out sessionToken : String;
    }
    
    action def DiscoverDevices {
        in hubID : DeviceIdentifier;
        out discoveredDevices : DeviceIdentifier[*];
    }
    
    action def SendDeviceCommand {
        in device : DeviceIdentifier;
        in command : ControlMessage;
        out success : Boolean;
        out response : StatusMessage;
    }
    
    action def ReadSensorData {
        in sensor : AccessoryDevice;
        out data : SensorData;
    }
    
    action def ExecuteScene {
        in sceneName : SceneName;
        in devices : DeviceIdentifier[*];
        out executionStatus : Boolean;
    }
    
    action def EvaluateAutomation {
        in sensorInput : SensorData;
        in rules : String[*];
        out triggeredActions : ControlMessage[*];
    }
    
    action def ManageHomeEnvironment {
        in userRequest : ControlMessage;
        out systemResponse : StatusMessage;
        
        first start;
        then merge awaitInput;
        
        then action authenticate : AuthenticateUser {
            in credentials;
            out authenticated;
            out sessionToken;
        }
        
        then decide;
            if authenticate.authenticated == true then processRequest;
            if authenticate.authenticated == false then denyAccess;
        
        action processRequest {
            action routeCommand : SendDeviceCommand {
                in device = userRequest.targetDevice;
                in command = userRequest;
                out success;
                out response;
            }
            then collectSensorData;
        }
        
        action collectSensorData {
            action readSensors : ReadSensorData {
                in sensor;
                out data;
            }
            then evaluateConditions;
        }
        
        action evaluateConditions {
            action checkAutomation : EvaluateAutomation {
                in sensorInput = collectSensorData.readSensors.data;
                in rules;
                out triggeredActions;
            }
            then executeAutomations;
        }
        
        action executeAutomations {
            action applyActions : SendDeviceCommand {
                in device;
                in command;
                out success;
                out response;
            }
            then respondToUser;
        }
        
        action respondToUser {
            assign systemResponse := processRequest.routeCommand.response;
        }
        then awaitInput;
        
        action denyAccess {
            assign systemResponse := StatusMessage {
                sourceDevice = "System";
                deviceState = "Access Denied";
                timestamp = 0.0;
            };
        }
        then done;
    }
    
    state def AccessoryLifecycle {
        entry; then offline;
        
        state offline {
            doc /* Device is not connected to the network */
        }
        
        transition offline_to_discovering
            first offline
            accept networkAvailable
            then discovering;
        
        state discovering {
            doc /* Device is being discovered by the hub */
        }
        
        transition discovering_to_pairing
            first discovering
            accept pairRequest
            then pairing;
        
        state pairing {
            doc /* Device is pairing with the hub */
        }
        
        transition pairing_to_ready
            first pairing
            accept pairSuccess
            then ready;
        
        transition pairing_to_offline
            first pairing
            accept pairFailure
            then offline;
        
        state ready {
            entry; then idle;
            
            state idle {
                doc /* Device is connected and waiting for commands */
            }
            
            transition idle_to_executing
                first idle
                accept command : ControlMessage
                then executing;
            
            state executing {
                doc /* Device is executing a command */
            }
            
            transition executing_to_idle
                first executing
                accept commandComplete
                then idle;
        }
        
        transition ready_to_offline
            first ready
            accept networkLost
            then offline;
    }
    
    requirement def SystemRequirement;
    requirement def FunctionalRequirement :> SystemRequirement;
    requirement def PerformanceRequirement :> SystemRequirement;
    requirement def SecurityRequirement :> SystemRequirement;
    
    requirement <'REQ-HK-001'> primaryFunction : FunctionalRequirement {
        doc /* The HomeKit system shall provide centralized control, automation, 
             and monitoring of smart home accessories through a unified hub and 
             user interface, enabling users to manage lighting, climate, security, 
             and other home functions remotely and automatically. */
        
        subject homeKitSystem : HomeKitSystemInstance;
    }
    
    requirement <'REQ-HK-002'> deviceDiscovery : FunctionalRequirement {
        doc /* The system shall automatically discover and register compatible 
             smart home accessories on the local network. */
        
        require constraint {
            homeHub.registeredDevices->size() >= 0
        }
    }
    
    requirement <'REQ-HK-003'> userAuthentication : SecurityRequirement {
        doc /* The system shall authenticate users before granting access to 
             device control and automation features. */
        
        require constraint {
            mobileApp.isAuthenticated == true
        }
    }
    
    requirement <'REQ-HK-004'> automationExecution : FunctionalRequirement {
        doc /* The system shall execute automation rules based on sensor inputs, 
             time schedules, and user-defined conditions. */
    }
    
    requirement <'REQ-HK-005'> responseTime : PerformanceRequirement {
        doc /* The system shall respond to user commands within 500 milliseconds 
             under normal network conditions. */
    }
    
    requirement <'REQ-HK-006'> sceneManagement : FunctionalRequirement {
        doc /* The system shall support creation and execution of scenes that 
             control multiple accessories simultaneously. */
    }
    
    part homeKitSystemInstance : HomeKitSystemInstance {
        doc /* A comprehensive home automation system that integrates smart 
             accessories including lights, thermostats, locks, and sensors 
             through a central hub. The system provides remote control via 
             mobile application, automated responses based on sensor data and 
             schedules, and scene-based control for coordinated device actions. 
             Users can monitor and control their home environment from anywhere, 
             while automation rules enhance convenience and energy efficiency. */
        
        part homeHub : HomeHub {
            perform action orchestrate : ManageHomeEnvironment;
        }
        
        part mobileApp : MobileApplication {
            perform orchestrate.authenticate;
        }
        
        part automation : AutomationController {
            perform orchestrate.evaluateConditions;
        }
        
        part livingRoomLight : SmartLightBulb {
            attribute room = "Living Room";
            exhibit AccessoryLifecycle;
            perform orchestrate.processRequest;
        }
        
        part bedroomLight : SmartLightBulb {
            attribute room = "Bedroom";
            exhibit AccessoryLifecycle;
            perform orchestrate.processRequest;
        }
        
        part mainThermostat : SmartThermostat {
            attribute room = "Hallway";
            exhibit AccessoryLifecycle;
            perform orchestrate.processRequest;
        }
        
        part frontDoorLock : SmartDoorLock {
            attribute room = "Entrance";
            exhibit AccessoryLifecycle;
            perform orchestrate.processRequest;
        }
        
        part hallwayMotion : MotionSensor {
            attribute room = "Hallway";
            exhibit AccessoryLifecycle;
            perform orchestrate.collectSensorData;
        }
        
        part outdoorTemp : TemperatureSensor {
            attribute room = "Exterior";
            exhibit AccessoryLifecycle;
            perform orchestrate.collectSensorData;
        }
        
        connection appToHub connect mobileApp.appNetwork to homeHub.hubNetwork;
        connection hubToLivingLight connect homeHub.devicePorts to livingRoomLight.controlPort;
        connection hubToBedroomLight connect homeHub.devicePorts to bedroomLight.controlPort;
        connection hubToThermostat connect homeHub.devicePorts to mainThermostat.controlPort;
        connection hubToLock connect homeHub.devicePorts to frontDoorLock.controlPort;
        connection hubToMotion connect homeHub.devicePorts to hallwayMotion.controlPort;
        connection hubToTempSensor connect homeHub.devicePorts to outdoorTemp.controlPort;
        
        satisfy primaryFunction by homeKitSystemInstance;
        satisfy deviceDiscovery by homeHub;
        satisfy userAuthentication by mobileApp;
        satisfy automationExecution by automation;
        satisfy responseTime by homeHub, mobileApp;
        satisfy sceneManagement by homeHub, automation;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import HomeKitSystem::*;

    part testSubject : AccessoryDevice {
        exhibit state sm : AccessoryLifecycle;
    }

    action orchestrator {
        attribute testDevice : DeviceIdentifier;
        item testCommand : ControlMessage {
            attribute targetDevice : DeviceIdentifier;
            attribute commandType = "";
            attribute commandValue = 0.0;
        }
        action routeCommandProbe : SendDeviceCommand {
            in device = testDevice;
            in command = testCommand;
        }
        attribute testNetworkAvailable : networkAvailable;
        attribute testPairRequest : pairRequest;
        attribute testPairSuccess : pairSuccess;
        attribute testNetworkLost : networkLost;
        action triggernetworkAvailable send testNetworkAvailable to testSubject;
        action triggerpairRequest send testPairRequest to testSubject;
        action triggerpairSuccess send testPairSuccess to testSubject;
        action triggernetworkLost send testNetworkLost to testSubject;
        first routeCommandProbe;
        then triggernetworkAvailable;
        then triggerpairRequest;
        then triggerpairSuccess;
        then triggernetworkLost;
    }
}
