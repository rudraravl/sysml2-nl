package OpenHABHomeAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeviceIdentifier :> String;
    attribute def ItemName :> String;
    attribute def ChannelIdentifier :> String;
    attribute def BindingType :> String;
    attribute def RuleIdentifier :> String;
    
    attribute def Temperature :> Real;
    attribute def Brightness :> Real;
    attribute def Humidity :> Real;
    attribute def PowerLevel :> Real;
    
    enum def ItemState {
        on;
        off;
        undefined;
    }
    
    enum def CommandType {
        switchOn;
        switchOff;
        setLevel;
        refresh;
    }
    
    item def SensorData {
        attribute deviceId : DeviceIdentifier;
        attribute timestamp : Real;
        attribute value : Real;
        attribute unit : String;
    }
    
    item def DeviceCommand {
        attribute targetDevice : DeviceIdentifier;
        attribute commandType : CommandType;
        attribute commandValue : Real;
    }
    
    item def ItemUpdate {
        attribute itemName : ItemName;
        attribute newState : ItemState;
        attribute numericValue : Real;
    }
    
    item def RuleEvent {
        attribute ruleId : RuleIdentifier;
        attribute triggerSource : ItemName;
        attribute eventData : SensorData;
    }
    
    port def SensorPort {
        out item reading : SensorData;
    }
    
    port def ActuatorPort {
        in item command : DeviceCommand;
    }
    
    port def EventBusPort {
        in item inEvent : ItemUpdate;
        out item outEvent : ItemUpdate;
    }
    
    port def RestAPIPort {
        in item request : DeviceCommand;
        out item response : ItemUpdate;
    }
    
    part def TemperatureSensor {
        attribute deviceId : DeviceIdentifier;
        attribute currentTemperature : Temperature;
        port sensorOut : SensorPort;
        
        action measureTemperature {
            out measurement : SensorData;
        }
    }
    
    part def MotionSensor {
        attribute deviceId : DeviceIdentifier;
        attribute motionDetected : Boolean;
        port sensorOut : SensorPort;
        
        action detectMotion {
            out detection : SensorData;
        }
    }
    
    part def LightSensor {
        attribute deviceId : DeviceIdentifier;
        attribute currentBrightness : Brightness;
        port sensorOut : SensorPort;
        
        action measureBrightness {
            out measurement : SensorData;
        }
    }
    
    part def SmartLight {
        attribute deviceId : DeviceIdentifier;
        attribute brightnessLevel : Brightness;
        attribute powerState : ItemState;
        port actuatorIn : ActuatorPort;
        
        action setBrightness {
            in level : Brightness;
        }
        
        action togglePower {
            in state : ItemState;
        }
        
        state lightControl {
            entry; then off;
            
            state off {
                entry action turnOff;
            }
            accept commandReceived : DeviceCommand
                when commandReceived.commandType == CommandType::switchOn
                then on;
            
            state on {
                entry action turnOn;
            }
            accept commandReceived : DeviceCommand
                when commandReceived.commandType == CommandType::switchOff
                then off;
            accept commandReceived : DeviceCommand
                when commandReceived.commandType == CommandType::setLevel
                then adjusting;
            
            state adjusting {
                entry action adjustBrightness : setBrightness;
            }
            then on;
        }
    }
    
    part def SmartThermostat {
        attribute deviceId : DeviceIdentifier;
        attribute targetTemperature : Temperature;
        attribute currentTemperature : Temperature;
        attribute operatingMode : String;
        port actuatorIn : ActuatorPort;
        port sensorIn : SensorPort;
        
        action setTargetTemperature {
            in temp : Temperature;
        }
        
        action setMode {
            in mode : String;
        }
        
        action checkTemperature;
        action activateHeating;
        action activateCooling;
        
        state thermostatControl {
            entry; then idle;
            
            state idle;
            accept tempUpdate : SensorData
                then evaluating;
            
            state evaluating {
                entry action performCheck : checkTemperature;
            }
            then decide;
            
            decide;
                if currentTemperature < targetTemperature then heating;
                if currentTemperature > targetTemperature then cooling;
                else idle;
            
            state heating {
                entry action performHeating : activateHeating;
            }
            then idle;
            
            state cooling {
                entry action performCooling : activateCooling;
            }
            then idle;
        }
    }
    
    part def Binding {
        attribute bindingType : BindingType;
        attribute protocol : String;
        
        action discoverDevices {
            out devices : DeviceIdentifier[*];
        }
        
        action translateCommand {
            in command : DeviceCommand;
            out nativeCommand : String;
        }
        
        action translateReading {
            in nativeData : String;
            out reading : SensorData;
        }
    }
    
    part def Thing {
        attribute thingId : DeviceIdentifier;
        attribute thingType : String;
        attribute channels : ChannelIdentifier[*];
        attribute binding : BindingType;
        
        action updateChannel {
            in channelId : ChannelIdentifier;
            in value : Real;
        }
        
        action getChannelValue {
            in channelId : ChannelIdentifier;
            out value : Real;
        }
    }
    
    part def Item {
        attribute itemName : ItemName;
        attribute itemType : String;
        attribute currentState : ItemState;
        attribute linkedChannel : ChannelIdentifier;
        
        action updateState {
            in newState : ItemState;
        }
        
        action sendCommand {
            in command : CommandType;
        }
    }
    
    part def EventBus {
        port eventPort : EventBusPort[*];
        
        action publishEvent {
            in event : ItemUpdate;
        }
        
        action subscribeToItem {
            in itemName : ItemName;
            out updates : ItemUpdate[*];
        }
        
        action routeEvent {
            in event : ItemUpdate;
            out subscribers : ItemName[*];
        }
    }
    
    part def RulesEngine {
        attribute activeRules : RuleIdentifier[*];
        port eventIn : EventBusPort;
        port commandOut : EventBusPort;
        
        action evaluateRule {
            in ruleId : RuleIdentifier;
            in triggerEvent : ItemUpdate;
            out actions : DeviceCommand[*];
        }
        
        action executeActions {
            in actions : DeviceCommand[*];
        }
        
        action checkConditions : evaluateRule;
        action performActions : executeActions;
        
        state ruleProcessing {
            entry; then listening;
            
            state listening;
            accept eventReceived : ItemUpdate
                then evaluating;
            
            state evaluating {
                entry action runCheck : checkConditions;
            }
            then decide;
            
            decide;
                if runCheck.actions->size() > 0 then executing;
                else listening;
            
            state executing {
                entry action runActions : performActions;
            }
            then listening;
        }
    }
    
    part def PersistenceService {
        attribute storageBackend : String;
        attribute retentionPolicy : String;
        
        action storeItemState {
            in itemName : ItemName;
            in state : ItemState;
            in timestamp : Real;
        }
        
        action queryHistory {
            in itemName : ItemName;
            in startTime : Real;
            in endTime : Real;
            out history : ItemUpdate[*];
        }
        
        action restoreState {
            in itemName : ItemName;
            out lastKnownState : ItemState;
        }
    }
    
    part def UserInterface {
        port apiPort : RestAPIPort;
        
        action displayDashboard {
            in items : Item[*];
        }
        
        action acceptUserCommand {
            out command : DeviceCommand;
        }
        
        action showItemStatus {
            in itemName : ItemName;
            in currentState : ItemState;
        }
        
        action configureItem {
            in itemName : ItemName;
            in configuration : String;
        }
    }
    
    action def MonitorEnvironment {
        in sensorReadings : SensorData[*];
        out environmentStatus : String;
    }
    
    action def ProcessAutomationRules {
        in events : ItemUpdate[*];
        in rules : RuleIdentifier[*];
        out commands : DeviceCommand[*];
    }
    
    action def ControlDevices {
        in commands : DeviceCommand[*];
        out confirmations : ItemUpdate[*];
    }
    
    part def OpenHABCore {
        doc /*
            OpenHAB core runtime that orchestrates all home automation functions
            including device integration, event processing, rule execution,
            persistence, and user interaction through a unified platform.
        */
        
        part eventBus : EventBus {
            port eventPort;
        }
        
        part rulesEngine : RulesEngine {
            port eventIn;
            port commandOut;
        }
        
        part persistence : PersistenceService {
            :>> storageBackend = "rrd4j";
            :>> retentionPolicy = "everyChange";
        }
        
        part ui : UserInterface {
            port apiPort;
        }
        
        part zigbeeBinding : Binding {
            :>> bindingType = "zigbee";
            :>> protocol = "zigbee3.0";
        }
        
        part zWaveBinding : Binding {
            :>> bindingType = "zwave";
            :>> protocol = "zwave-plus";
        }
        
        part mqttBinding : Binding {
            :>> bindingType = "mqtt";
            :>> protocol = "mqtt-v3.1.1";
        }
        
        part livingRoomTempSensor : TemperatureSensor {
            :>> deviceId = "temp_living_01";
            port sensorOut;
        }
        
        part livingRoomMotionSensor : MotionSensor {
            :>> deviceId = "motion_living_01";
            port sensorOut;
        }
        
        part outdoorLightSensor : LightSensor {
            :>> deviceId = "light_outdoor_01";
            port sensorOut;
        }
        
        part livingRoomLight : SmartLight {
            :>> deviceId = "light_living_01";
            :>> brightnessLevel = 0.0;
            :>> powerState = ItemState::off;
            port actuatorIn;
        }
        
        part bedroomLight : SmartLight {
            :>> deviceId = "light_bedroom_01";
            :>> brightnessLevel = 0.0;
            :>> powerState = ItemState::off;
            port actuatorIn;
        }
        
        part mainThermostat : SmartThermostat {
            :>> deviceId = "thermostat_main";
            :>> targetTemperature = 294.15;
            :>> operatingMode = "auto";
            port actuatorIn;
            port sensorIn;
        }
        
        part tempThing : Thing {
            :>> thingId = "thing_temp_living";
            :>> thingType = "temperature-sensor";
            :>> binding = "zigbee";
        }
        
        part lightThing : Thing {
            :>> thingId = "thing_light_living";
            :>> thingType = "dimmable-light";
            :>> binding = "zigbee";
        }
        
        part tempItem : Item {
            :>> itemName = "LivingRoom_Temperature";
            :>> itemType = "Number:Temperature";
            :>> currentState = ItemState::undefined;
        }
        
        part lightItem : Item {
            :>> itemName = "LivingRoom_Light";
            :>> itemType = "Dimmer";
            :>> currentState = ItemState::off;
        }
        
        connection sensorToEventBus1 connect
            livingRoomTempSensor.sensorOut to eventBus.eventPort;
        
        connection sensorToEventBus2 connect
            livingRoomMotionSensor.sensorOut to eventBus.eventPort;
        
        connection sensorToEventBus3 connect
            outdoorLightSensor.sensorOut to eventBus.eventPort;
        
        connection eventBusToRules connect
            eventBus.eventPort to rulesEngine.eventIn;
        
        connection rulesToEventBus connect
            rulesEngine.commandOut to eventBus.eventPort;
        
        connection eventBusToLight1 connect
            eventBus.eventPort to livingRoomLight.actuatorIn;
        
        connection eventBusToLight2 connect
            eventBus.eventPort to bedroomLight.actuatorIn;
        
        connection eventBusToThermostat connect
            eventBus.eventPort to mainThermostat.actuatorIn;
        
        connection thermostatSensorConnection connect
            livingRoomTempSensor.sensorOut to mainThermostat.sensorIn;
        
        connection uiToEventBus connect
            ui.apiPort to eventBus.eventPort;
        
        perform action orchestrateHomeAutomation {
            doc /*
                Primary automation workflow that continuously monitors sensors,
                processes events through rules engine, executes automation logic,
                controls devices, and persists state changes.
            */
            
            first start;
            then merge continuousAutomation;
            
            action gatherSensorData : MonitorEnvironment {
                in sensorReadings = (
                    livingRoomTempSensor.measureTemperature.measurement,
                    livingRoomMotionSensor.detectMotion.detection,
                    outdoorLightSensor.measureBrightness.measurement
                );
                out environmentStatus;
            }
            
            flow gatherSensorData.sensorReadings to publishToEventBus.readings;
            
            action publishToEventBus {
                in readings : SensorData[*];
                action publish : eventBus.publishEvent;
            }
            
            flow publishToEventBus.readings to processRules.events;
            
            action processRules : ProcessAutomationRules {
                in events : ItemUpdate[*];
                in rules = rulesEngine.activeRules;
                out commands : DeviceCommand[*];
            }
            
            flow processRules.commands to executeCommands.commands;
            
            action executeCommands : ControlDevices {
                in commands : DeviceCommand[*];
                out confirmations : ItemUpdate[*];
            }
            
            flow executeCommands.confirmations to persistStates.updates;
            
            action persistStates {
                in updates : ItemUpdate[*];
                action store : persistence.storeItemState;
            }
            
            then continuousAutomation;
            then done;
        }
    }
    
    part openHABSystem : OpenHABCore;
    
    requirement def SystemRequirements {
        doc /*
            High-level requirements defining the capabilities and constraints
            of the OpenHAB home automation system.
        */
        
        requirement deviceIntegration {
            doc /*
                The system shall integrate devices from multiple protocols
                including Zigbee, Z-Wave, and MQTT through standardized bindings.
            */
        }
        
        requirement eventDrivenArchitecture {
            doc /*
                The system shall employ an event-driven architecture where
                all state changes are published to a central event bus for
                processing by rules and other subscribers.
            */
        }
        
        requirement ruleBasedAutomation {
            doc /*
                The system shall support user-defined automation rules that
                trigger actions based on item state changes and conditions.
            */
        }
        
        requirement statePersistence {
            doc /*
                The system shall persist item states and historical data
                to enable trend analysis and state restoration after restart.
            */
        }
        
        requirement userInterface {
            doc /*
                The system shall provide REST API and user interface for
                monitoring device status and issuing control commands.
            */
        }
        
        requirement extensibility {
            doc /*
                The system shall support extensibility through bindings,
                transformations, and custom rule actions.
            */
        }
    }
    
    requirement openHABSystemRequirements : SystemRequirements {
        subject openHABSystem;
        
        require deviceIntegration;
        require eventDrivenArchitecture;
        require ruleBasedAutomation;
        require statePersistence;
        require userInterface;
        require extensibility;
    }
    
    requirement def PrimaryFunction {
        doc /*
            The OpenHAB system shall provide a vendor-neutral, open-source
            home automation platform that integrates diverse smart home devices,
            processes sensor data through a central event bus, executes
            user-defined automation rules, controls actuators, persists state
            and historical data, and provides unified monitoring and control
            interfaces for comprehensive home automation management.
        */
    }
    
    requirement primaryFunction : PrimaryFunction {
        subject openHABSystem;
        satisfy primaryFunction by openHABSystem.orchestrateHomeAutomation;
    }
}
