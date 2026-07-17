package OpenRemoteIoTAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeviceIdentifier :> String;
    attribute def AssetIdentifier :> String;
    attribute def RuleIdentifier :> String;
    attribute def TopicName :> String;
    attribute def MessagePayload :> String;
    
    attribute def TemperatureMeasurement {
        attribute value : ISQ::ThermodynamicTemperatureValue;
        attribute timestamp : ISQ::TimeValue;
        attribute sourceAsset : AssetIdentifier;
    }
    
    attribute def HumidityMeasurement {
        attribute value : Real;
        attribute timestamp : ISQ::TimeValue;
        attribute sourceAsset : AssetIdentifier;
    }
    
    attribute def PowerMeasurement {
        attribute value : ISQ::PowerValue;
        attribute timestamp : ISQ::TimeValue;
        attribute sourceAsset : AssetIdentifier;
    }
    
    attribute def LuminanceMeasurement {
        attribute value : ISQ::LuminanceValue;
        attribute timestamp : ISQ::TimeValue;
        attribute sourceAsset : AssetIdentifier;
    }
    
    attribute def ActuatorCommand {
        attribute targetAsset : AssetIdentifier;
        attribute commandType : String;
        attribute commandValue : Real;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def MQTTMessage {
        attribute topic : TopicName;
        attribute payload : MessagePayload;
        attribute qos : Integer;
    }
    
    port def SensorOutputPort {
        out temperatureReading : TemperatureMeasurement;
        out humidityReading : HumidityMeasurement;
        out powerReading : PowerMeasurement;
        out luminanceReading : LuminanceMeasurement;
    }
    
    port def ActuatorInputPort {
        in command : ActuatorCommand;
    }
    
    port def MQTTCommunicationPort {
        in incomingMessage : MQTTMessage;
        out outgoingMessage : MQTTMessage;
    }
    
    port def RuleProcessingPort {
        in sensorInput : TemperatureMeasurement;
        out commandOutput : ActuatorCommand;
    }
    
    port def UserDashboardPort {
        in userRequest : String;
        out visualizationData : String;
    }
    
    port def DataPersistencePort {
        in dataToStore : String;
        out historicalData : String;
    }
    
    part def IoTSensorDevice {
        attribute deviceId : DeviceIdentifier;
        attribute deviceType : String;
        attribute location : String;
        port sensorOutput : SensorOutputPort;
        port mqttPort : MQTTCommunicationPort;
        
        action def AcquireSensorData {
            out measurement : Real;
        }
    }
    
    part def TemperatureSensorDevice :> IoTSensorDevice {
        attribute deviceType redefines deviceType = "TemperatureSensor";
        
        action acquireTemperature : AcquireSensorData {
            out tempMeasurement : TemperatureMeasurement;
        }
    }
    
    part def HumiditySensorDevice :> IoTSensorDevice {
        attribute deviceType redefines deviceType = "HumiditySensor";
        
        action acquireHumidity : AcquireSensorData {
            out humidityMeasurement : HumidityMeasurement;
        }
    }
    
    part def PowerMeterDevice :> IoTSensorDevice {
        attribute deviceType redefines deviceType = "PowerMeter";
        
        action acquirePower : AcquireSensorData {
            out powerMeasurement : PowerMeasurement;
        }
    }
    
    part def LightSensorDevice :> IoTSensorDevice {
        attribute deviceType redefines deviceType = "LightSensor";
        
        action acquireLuminance : AcquireSensorData {
            out luminanceMeasurement : LuminanceMeasurement;
        }
    }
    
    part def ActuatorDevice {
        attribute deviceId : DeviceIdentifier;
        attribute deviceType : String;
        attribute location : String;
        port actuatorInput : ActuatorInputPort;
        port mqttPort : MQTTCommunicationPort;
        
        action def ExecuteActuatorCommand {
            in cmd : ActuatorCommand;
        }
    }
    
    part def HVACActuator :> ActuatorDevice {
        attribute deviceType redefines deviceType = "HVAC";
        attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute operatingMode : String;
        
        action executeHVAC : ExecuteActuatorCommand {
            in hvacCmd : ActuatorCommand;
        }
    }
    
    part def LightingActuator :> ActuatorDevice {
        attribute deviceType redefines deviceType = "Lighting";
        attribute brightnessLevel : Real;
        attribute isActive : Boolean;
        
        action executeLighting : ExecuteActuatorCommand {
            in lightCmd : ActuatorCommand;
        }
    }
    
    part def AssetManagementService {
        attribute registeredAssets : AssetIdentifier[*];
        
        action def RegisterNewAsset {
            in assetId : AssetIdentifier;
            in assetType : String;
            in assetLocation : String;
        }
        
        action def UpdateAssetStatus {
            in assetId : AssetIdentifier;
            in statusData : String;
        }
        
        action def RetrieveAssetInformation {
            in assetId : AssetIdentifier;
            out assetDetails : String;
        }
        
        action def DeregisterAsset {
            in assetId : AssetIdentifier;
        }
    }
    
    part def AutomationRuleEngine {
        attribute activeRules : RuleIdentifier[*];
        port rulePort : RuleProcessingPort;
        
        action def EvaluateAutomationRules {
            in sensorData : TemperatureMeasurement;
            out controlCommands : ActuatorCommand[*];
        }
        
        action def ProcessClimateControlRule {
            in temperatureData : TemperatureMeasurement;
            in humidityData : HumidityMeasurement;
            out hvacCommand : ActuatorCommand;
        }
        
        action def ProcessLightingRule {
            in luminanceData : LuminanceMeasurement;
            out lightingCommand : ActuatorCommand;
        }
    }
    
    part def TimeSeriesDataStore {
        port storagePort : DataPersistencePort;
        
        action def PersistSensorData {
            in dataRecord : String;
            in recordTimestamp : ISQ::TimeValue;
        }
        
        action def QueryHistoricalData {
            in assetId : AssetIdentifier;
            in startTime : ISQ::TimeValue;
            in endTime : ISQ::TimeValue;
            out timeSeriesData : String[*];
        }
        
        action def AggregateData {
            in assetId : AssetIdentifier;
            in aggregationPeriod : ISQ::TimeValue;
            out aggregatedResults : String;
        }
    }
    
    part def WebDashboardInterface {
        port dashboardPort : UserDashboardPort;
        
        action def RenderDashboard {
            in assetDataSet : String[*];
            out dashboardHTML : String;
        }
        
        action def HandleUserCommand {
            in userInput : String;
            out systemCommand : ActuatorCommand;
        }
        
        action def GenerateReport {
            in reportType : String;
            in timeRange : ISQ::TimeValue;
            out reportData : String;
        }
    }
    
    part def MQTTMessageBroker {
        attribute brokerHostname : String;
        attribute brokerPort : Integer;
        attribute connectedClients : Integer;
        
        action def PublishToTopic {
            in topicName : TopicName;
            in messagePayload : MessagePayload;
        }
        
        action def SubscribeToTopic {
            in topicName : TopicName;
            out messages : MQTTMessage[*];
        }
        
        action def UnsubscribeFromTopic {
            in topicName : TopicName;
        }
    }
    
    part def OpenRemoteCore {
        part assetManager : AssetManagementService;
        part ruleEngine : AutomationRuleEngine;
        part dataStore : TimeSeriesDataStore;
        part dashboard : WebDashboardInterface;
        part messageBroker : MQTTMessageBroker;
        
        part tempSensor1 : TemperatureSensorDevice {
            attribute deviceId = "TEMP_SENSOR_001";
            attribute location = "Zone_A";
        }
        
        part humiditySensor1 : HumiditySensorDevice {
            attribute deviceId = "HUMID_SENSOR_001";
            attribute location = "Zone_A";
        }
        
        part powerMeter1 : PowerMeterDevice {
            attribute deviceId = "POWER_METER_001";
            attribute location = "Zone_A";
        }
        
        part lightSensor1 : LightSensorDevice {
            attribute deviceId = "LIGHT_SENSOR_001";
            attribute location = "Zone_A";
        }
        
        part hvacUnit1 : HVACActuator {
            attribute deviceId = "HVAC_UNIT_001";
            attribute location = "Zone_A";
        }
        
        part lightingUnit1 : LightingActuator {
            attribute deviceId = "LIGHTING_001";
            attribute location = "Zone_A";
        }
        
        connection sensorToRuleEngine connect tempSensor1.sensorOutput to ruleEngine.rulePort;
        connection ruleToHVAC connect ruleEngine.rulePort to hvacUnit1.actuatorInput;
        connection lightSensorToRuleEngine connect lightSensor1.sensorOutput to ruleEngine.rulePort;
        connection ruleToLighting connect ruleEngine.rulePort to lightingUnit1.actuatorInput;
        
        action def ContinuousAutomationCycle {
            in attribute temperatureSetpoint : ISQ::ThermodynamicTemperatureValue = 294.15[K];
            in attribute humiditySetpoint : Real = 50.0;
            in attribute luminanceThreshold : ISQ::LuminanceValue = 300.0[cd/m^2];
            
            private attribute currentTemperature : TemperatureMeasurement;
            private attribute currentHumidity : HumidityMeasurement;
            private attribute currentPower : PowerMeasurement;
            private attribute currentLuminance : LuminanceMeasurement;
            private attribute generatedHVACCommand : ActuatorCommand;
            private attribute generatedLightCommand : ActuatorCommand;
            
            first start;
            then merge continuousLoop;
            
            then action collectAllSensorData {
                action readTemp : tempSensor1.acquireTemperature {
                    out tempMeasurement;
                }
                action readHumid : humiditySensor1.acquireHumidity {
                    out humidityMeasurement;
                }
                action readPower : powerMeter1.acquirePower {
                    out powerMeasurement;
                }
                action readLight : lightSensor1.acquireLuminance {
                    out luminanceMeasurement;
                }
            }
            
            then assign currentTemperature := collectAllSensorData.readTemp.tempMeasurement;
            then assign currentHumidity := collectAllSensorData.readHumid.humidityMeasurement;
            then assign currentPower := collectAllSensorData.readPower.powerMeasurement;
            then assign currentLuminance := collectAllSensorData.readLight.luminanceMeasurement;
            
            then action storeData : dataStore.PersistSensorData;
            
            then action evaluateClimate : ruleEngine.ProcessClimateControlRule {
                in temperatureData = currentTemperature;
                in humidityData = currentHumidity;
                out hvacCommand;
            }
            
            then assign generatedHVACCommand := evaluateClimate.hvacCommand;
            
            then action evaluateLighting : ruleEngine.ProcessLightingRule {
                in luminanceData = currentLuminance;
                out lightingCommand;
            }
            
            then assign generatedLightCommand := evaluateLighting.lightingCommand;
            
            then action executeHVACControl : hvacUnit1.executeHVAC {
                in hvacCmd = generatedHVACCommand;
            }
            
            then action executeLightControl : lightingUnit1.executeLighting {
                in lightCmd = generatedLightCommand;
            }
            
            then continuousLoop;
        }
        
        perform action automationCycle : ContinuousAutomationCycle;
    }
    
    requirement def OpenRemoteSystemRequirements {
        doc /* The OpenRemote IoT automation system shall provide comprehensive asset management, 
               rule-based automation, data persistence, and user interface capabilities for 
               monitoring and controlling distributed IoT devices. */
        
        requirement <'REQ-001'> assetManagementCapability {
            doc /* The system shall support dynamic registration, monitoring, and lifecycle management 
                   of heterogeneous IoT sensor and actuator devices. */
        }
        
        requirement <'REQ-002'> ruleBasedAutomationCapability {
            doc /* The system shall execute configurable automation rules that trigger actuator commands 
                   based on real-time sensor data and predefined conditions. */
        }
        
        requirement <'REQ-003'> timeSeriesDataPersistence {
            doc /* The system shall persist all sensor measurements as time-series data with timestamps 
                   for historical analysis and reporting. */
        }
        
        requirement <'REQ-004'> webBasedUserInterface {
            doc /* The system shall provide a web-based dashboard for real-time visualization of asset 
                   status and manual control of actuators. */
        }
        
        requirement <'REQ-005'> mqttProtocolSupport {
            doc /* The system shall utilize MQTT protocol for bidirectional communication between 
                   IoT devices and the central platform. */
        }
        
        requirement <'REQ-006'> realTimeResponsePerformance {
            doc /* The system shall process incoming sensor data and execute corresponding automation 
                   rules within 2 seconds of data receipt. */
        }
        
        requirement <'REQ-007'> scalabilityRequirement {
            doc /* The system shall support concurrent management of at least 1000 IoT devices 
                   without performance degradation. */
        }
    }
    
    requirement openRemoteSystemRequirement : OpenRemoteSystemRequirements {
        assume constraint validSensorRanges {
            doc /* All sensor measurements shall be within physically valid ranges: 
                   temperature 233.15K to 333.15K, humidity 0% to 100%, 
                   power 0W to 10000W, luminance 0 to 10000 cd/m^2. */
        }
        
        assume constraint networkConnectivity {
            doc /* All IoT devices shall maintain stable network connectivity with 
                   packet loss rate below 5%. */
        }
        
        require assetManagementCapability;
        require ruleBasedAutomationCapability;
        require timeSeriesDataPersistence;
        require webBasedUserInterface;
        require mqttProtocolSupport;
        require realTimeResponsePerformance;
        require scalabilityRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import OpenRemoteIoTAutomationSystem::*;

    part testSubject : TemperatureSensorDevice;
}
