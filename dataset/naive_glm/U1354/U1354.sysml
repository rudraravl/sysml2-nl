package IoTAutomationSystem {
    import ScalarValues::*;
    
    // ============================================================
    // VALUE TYPES
    // ============================================================
    
    value type TemperatureC :> Real {
        attribute unit : String = "degC";
        attribute min : Real = -40.0;
        attribute max : Real = 85.0;
    }
    
    value type HumidityPct :> Real {
        attribute unit : String = "%RH";
        attribute min : Real = 0.0;
        attribute max : Real = 100.0;
    }
    
    value type PowerW :> Real {
        attribute unit : String = "W";
        attribute min : Real = 0.0;
    }
    
    value type LightLx :> Real {
        attribute unit : String = "lx";
        attribute min : Real = 0.0;
    }
    
    value type BrightnessPct :> Real {
        attribute unit : String = "%";
        attribute min : Real = 0.0;
        attribute max : Real = 100.0;
    }
    
    value type FanSpeedPct :> Real {
        attribute unit : String = "%";
        attribute min : Real = 0.0;
        attribute max : Real = 100.0;
    }
    
    value type TimestampMs :> Integer {
        attribute unit : String = "ms";
    }
    
    value type MqttTopic :> String;
    value type SensorId :> String;
    value type Location :> String;
    value type RuleId :> String;
    
    // ============================================================
    // ENUMERATIONS
    // ============================================================
    
    enum def HvacMode {
        off;
        cool;
        heat;
        fan;
        auto;
    }
    
    enum def DeviceType {
        temperatureSensor;
        humiditySensor;
        powerMeter;
        lightSensor;
        hvacUnit;
        lightingUnit;
    }
    
    enum def Priority {
        low;
        normal;
        high;
        critical;
    }
    
    enum def OccupancyState {
        occupied;
        unoccupied;
    }
    
    // ============================================================
    // ITEM DEFINITIONS (MQTT MESSAGES)
    // ============================================================
    
    item def MqttMessage {
        attribute topic : MqttTopic;
        attribute qos : Integer = 0;
        attribute retained : Boolean = false;
        attribute timestamp : TimestampMs;
    }
    
    item def SensorReading :> MqttMessage {
        attribute sensorId : SensorId;
        attribute location : Location;
        attribute value : Real;
    }
    
    item def TemperatureReading :> SensorReading {
        redefines value : TemperatureC;
    }
    
    item def HumidityReading :> SensorReading {
        redefines value : HumidityPct;
    }
    
    item def PowerReading :> SensorReading {
        redefines value : PowerW;
    }
    
    item def LightReading :> SensorReading {
        redefines value : LightLx;
    }
    
    item def ActuatorCommand :> MqttMessage {
        attribute actuatorId : SensorId;
        attribute source : String = "automation";
    }
    
    item def HvacCommand :> ActuatorCommand {
        attribute mode : HvacMode;
        attribute setpoint : TemperatureC;
        attribute fanSpeed : FanSpeedPct;
    }
    
    item def LightCommand :> ActuatorCommand {
        attribute on : Boolean;
        attribute brightness : BrightnessPct;
    }
    
    item def DeviceRegistration :> MqttMessage {
        attribute deviceId : SensorId;
        attribute deviceType : DeviceType;
        attribute location : Location;
    }
    
    item def DeviceHeartbeat :> MqttMessage {
        attribute deviceId : SensorId;
        attribute online : Boolean;
    }
    
    item def DashboardOverride :> MqttMessage {
        attribute deviceId : SensorId;
        attribute overrideActive : Boolean;
        attribute command : ActuatorCommand;
    }
    
    item def RuleDefinition {
        attribute ruleId : RuleId;
        attribute name : String;
        attribute description : String;
        attribute enabled : Boolean = true;
        attribute priority : Priority = Priority::normal;
    }
    
    item def TemperatureRule :> RuleDefinition {
        attribute setpointHigh : TemperatureC;
        attribute setpointLow : TemperatureC;
        attribute targetHvacId : SensorId;
        attribute targetMode : HvacMode;
        attribute targetSetpoint : TemperatureC;
        attribute targetFanSpeed : FanSpeedPct;
    }
    
    item def LightRule :> RuleDefinition {
        attribute lightThreshold : LightLx;
        attribute targetLightId : SensorId;
        attribute targetBrightness : BrightnessPct;
    }
    
    // ============================================================
    // PORT DEFINITIONS
    // ============================================================
    
    port def MqttEndpoint {
        in item publish : MqttMessage;
        out item deliver : MqttMessage;
        attribute subscribedTopics : MqttTopic[0..*];
    }
    
    // ============================================================
    // SENSOR DEFINITIONS
    // ============================================================
    
    abstract part def Sensor {
        attribute id : SensorId;
        attribute location : Location;
        attribute samplePeriodMs : Integer = 60000;
        attribute firmwareVersion : String = "1.0.0";
        attribute batteryLevelPct : Integer = 100;
        attribute online : Boolean = true;
        
        port mqttClient : ~MqttEndpoint;
        
        value lastReading : SensorReading;
        
        state SensorLifecycle {
            state PoweredOff;
            state Idle;
            state Sampling;
            state Publishing;
            
            transition PoweredOff -> Idle when bootSignal;
            transition Idle -> Sampling when sampleTimerFires;
            transition Sampling -> Publishing when measurementReady;
            transition Publishing -> Idle when publishAck;
            transition Idle -> PoweredOff when powerFailure;
            transition Sampling -> PoweredOff when powerFailure;
        }
        
        action def takeMeasurement {
            out reading : SensorReading;
        }
        
        action def publishReading {
            in reading : SensorReading;
            out message : MqttMessage;
        }
    }
    
    part def TemperatureSensor :> Sensor {
        redefines firmwareVersion = "1.2.1";
        redefines samplePeriodMs = 30000;
        attribute accuracy : TemperatureC = 0.5;
        value currentTemperature : TemperatureC;
        
        action def takeMeasurement {
            out reading : TemperatureReading;
        }
    }
    
    part def HumiditySensor :> Sensor {
        redefines firmwareVersion = "1.1.0";
        redefines samplePeriodMs = 60000;
        attribute accuracy : HumidityPct = 2.0;
        value currentHumidity : HumidityPct;
        
        action def takeMeasurement {
            out reading : HumidityReading;
        }
    }
    
    part def PowerMeter :> Sensor {
        redefines firmwareVersion = "2.0.3";
        redefines samplePeriodMs = 5000;
        attribute maxCapacity : PowerW = 10000.0;
        value currentPower : PowerW;
        
        action def takeMeasurement {
            out reading : PowerReading;
        }
    }
    
    part def LightSensor :> Sensor {
        redefines firmwareVersion = "1.0.5";
        redefines samplePeriodMs = 15000;
        attribute maxRange : LightLx = 10000.0;
        value currentIlluminance : LightLx;
        
        action def takeMeasurement {
            out reading : LightReading;
        }
    }
    
    // ============================================================
    // ACTUATOR DEFINITIONS
    // ============================================================
    
    abstract part def Actuator {
        attribute id : SensorId;
        attribute location : Location;
        attribute lastCommand : ActuatorCommand;
        attribute online : Boolean = true;
        
        port mqttClient : ~MqttEndpoint;
        
        state ActuatorLifecycle {
            state Offline;
            state Standby;
            state Active;
            state Faulted;
            
            transition Offline -> Standby when bootComplete;
            transition Standby -> Active when commandReceived;
            transition Active -> Standby when commandCompleted;
            transition Standby -> Faulted when hardwareFault;
            transition Active -> Faulted when hardwareFault;
            transition Faulted -> Offline when resetCommand;
        }
        
        action def applyCommand {
            in cmd : ActuatorCommand;
        }
        
        action def emitStatus {
            out status : DeviceHeartbeat;
        }
    }
    
    part def HvacUnit :> Actuator {
        attribute mode : HvacMode = HvacMode::off;
        attribute setpoint : TemperatureC = 22.0;
        attribute fanSpeed : FanSpeedPct = 0.0;
        attribute coolingCapacity : PowerW = 2500.0;
        attribute heatingCapacity : PowerW = 3000.0;
        
        action def applyCommand {
            in cmd : HvacCommand;
        }
    }
    
    part def LightingUnit :> Actuator {
        attribute on : Boolean = false;
        attribute brightness : BrightnessPct = 0.0;
        attribute maxPower : PowerW = 60.0;
        
        action def applyCommand {
            in cmd : LightCommand;
        }
    }
    
    // ============================================================
    // PLATFORM SERVICE DEFINITIONS
    // ============================================================
    
    abstract part def PlatformService {
        attribute serviceId : String;
        attribute version : String;
        attribute running : Boolean = true;
        attribute uptimePct : Real = 99.5;
        
        port mqttClient : ~MqttEndpoint;
    }
    
    part def AssetManagementService :> PlatformService {
        redefines serviceId = "asset-mgmt-svc";
        redefines version = "3.4.0";
        
        attribute registeredDevices : DeviceRegistration[0..*] = {};
        attribute deviceCount : Integer = 0;
        attribute syncIntervalMs : Integer = 30000;
        
        action def registerDevice {
            in reg : DeviceRegistration;
        }
        
        action def deregisterDevice {
            in deviceId : SensorId;
        }
        
        action def lookupDevice {
            in deviceId : SensorId;
            return reg : DeviceRegistration;
        }
        
        action def listDevicesByLocation {
            in loc : Location;
            return regs : DeviceRegistration[0..*];
        }
        
        action def listDevicesByType {
            in dtype : DeviceType;
            return regs : DeviceRegistration[0..*];
        }
        
        action def updateHeartbeat {
            in deviceId : SensorId;
            in timestamp : TimestampMs;
        }
        
        state AssetMgmtState {
            state Uninitialized;
            state InventoryReady;
            state Synchronizing;
            state Synced;
            state Degraded;
            
            transition Uninitialized -> InventoryReady when databaseConnected;
            transition InventoryReady -> Synchronizing when syncTriggered;
            transition Synchronizing -> Synced when syncComplete;
            transition Synced -> Synchronizing when deviceAdded;
            transition Synced -> Synchronizing when deviceRemoved;
            transition Synced -> Degraded when databaseUnreachable;
            transition Degraded -> Synchronizing when databaseReconnected;
        }
    }
    
    part def AutomationRuleEngine :> PlatformService {
        redefines serviceId = "rule-engine-svc";
        redefines version = "5.1.2";
        
        attribute rules : RuleDefinition[0..*];
        attribute activeOverrides : DashboardOverride[0..*] = {};
        attribute evaluationLatencyMs : Integer = 0;
        attribute processedMessages : Integer = 0;
        attribute dispatchedCommands : Integer = 0;
        attribute defaultHvacSetpoint : TemperatureC = 22.0;
        attribute defaultLightSetpoint : LightLx = 300.0;
        
        action def loadRules {
            in ruleSet : RuleDefinition[0..*];
        }
        
        action def enableRule {
            in ruleId : RuleId;
        }
        
        action def disableRule {
            in ruleId : RuleId;
        }
        
        action def evaluateTemperatureRule {
            in reading : TemperatureReading;
            in rule : TemperatureRule;
            return cmd : HvacCommand;
        }
        
        action def evaluateLightRule {
            in reading : LightReading;
            in rule : LightRule;
            return cmd : LightCommand;
        }
        
        action def dispatchCommand {
            in cmd : ActuatorCommand;
            out message : MqttMessage;
        }
        
        action def handleOverride {
            in override : DashboardOverride;
        }
        
        action def clearOverride {
            in deviceId : SensorId;
        }
        
        state RuleEngineState {
            state Inactive;
            state Listening;
            state Evaluating;
            state Dispatching;
            state Overridden;
            state Cooldown;
            
            transition Inactive -> Listening when engineStart;
            transition Listening -> Evaluating when messageReceived;
            transition Evaluating -> Dispatching when ruleMatched;
            transition Evaluating -> Listening when noMatch;
            transition Dispatching -> Listening when commandSent;
            transition Dispatching -> Cooldown when rateLimitTriggered;
            transition Cooldown -> Listening when cooldownElapsed;
            transition Listening -> Overridden when overrideReceived;
            transition Overridden -> Listening when overrideCleared;
            transition Listening -> Inactive when engineStop;
        }
    }
    
    part def TimeSeriesDataStore :> PlatformService {
        redefines serviceId = "timeseries-svc";
        redefines version = "2.7.1";
        
        attribute storageBackend : String = "InfluxDB";
        attribute retentionDays : Integer = 365;
        attribute compressionActive : Boolean = false;
        attribute batchSize : Integer = 1000;
        value storedSamples : Integer = 0;
        value diskUsageBytes : Integer = 0;
        
        action def storeReading {
            in reading : SensorReading;
        }
        
        action def queryHistory {
            in sensorId : SensorId;
            in fromTs : TimestampMs;
            in toTs : TimestampMs;
            return readings : SensorReading[0..*];
        }
        
        action def computeAggregate {
            in sensorId : SensorId;
            in fromTs : TimestampMs;
            in toTs : TimestampMs;
            return meanValue : Real;
            return maxValue : Real;
            return minValue : Real;
        }
        
        action def pruneOldData {
            in cutoffTs : TimestampMs;
        }
        
        action def exportDataset {
            in sensorId : SensorId;
            in fromTs : TimestampMs;
            in toTs : TimestampMs;
            return data : String;
        }
        
        state DataStoreState {
            state Empty;
            state Recording;
            state Compacting;
            state Archived;
            state Degraded;
            
            transition Empty -> Recording when firstSample;
            transition Recording -> Compacting when compactionTriggered;
            transition Compacting -> Recording when compactionDone;
            transition Recording -> Archived when retentionExceeded;
            transition Archived -> Recording when oldDataPruned;
            transition Recording -> Degraded when storageFull;
            transition Degraded -> Recording when storageFreed;
        }
    }
    
    part def WebDashboard :> PlatformService {
        redefines serviceId = "web-dashboard-svc";
        redefines version = "4.0.0";
        
        attribute connectedUsers : Integer = 0;
        attribute refreshIntervalMs : Integer = 5000;
        attribute overrideActive : Boolean = false;
        attribute theme : String = "light";
        
        action def renderRealtimeView {
            return html : String;
        }
        
        action def renderDeviceStatus {
            in deviceId : SensorId;
            return html : String;
        }
        
        action def renderHistoricalChart {
            in sensorId : SensorId;
            in fromTs : TimestampMs;
            in toTs : TimestampMs;
            return html : String;
        }
        
        action def applyManualOverride {
            in override : DashboardOverride;
        }
        
        action def clearOverride {
            in deviceId : SensorId;
        }
        
        action def authenticateUser {
            in username : String;
            in password : String;
            return granted : Boolean;
        }
        
        state DashboardState {
            state LoggedOut;
            state Viewing;
            state Overriding;
            
            transition LoggedOut -> Viewing when userLogsIn;
            transition Viewing -> Overriding when overrideInitiated;
            transition Overriding -> Viewing when overrideCleared;
            transition Viewing -> LoggedOut when userLogsOut;
            transition Overriding -> LoggedOut when userLogsOut;
        }
    }
    
    // ============================================================
    // MQTT BROKER
    // ============================================================
    
    part def MqttBroker {
        attribute brokerId : String = "mqtt-broker";
        attribute host : String = "0.0.0.0";
        attribute listenPort : Integer = 1883;
        attribute maxConnections : Integer = 1000;
        attribute retainedMessages : Boolean = true;
        attribute activeConnections : Integer = 0;
        attribute messageQueueDepth : Integer = 0;
        
        port clientEndpoints : MqttEndpoint[0..*];
        
        action def routeMessage {
            in message : MqttMessage;
        }
        
        action def retainMessage {
            in message : MqttMessage;
        }
        
        action def authenticateClient {
            in clientId : String;
            return granted : Boolean;
        }
        
        action def subscribeTopic {
            in clientId : String;
            in topic : MqttTopic;
        }
        
        action def unsubscribeTopic {
            in clientId : String;
            in topic : MqttTopic;
        }
        
        state BrokerState {
            state Stopped;
            state Starting;
            state Running;
            state Degraded;
            
            transition Stopped -> Starting when startupCommand;
            transition Starting -> Running when listenersBound;
            transition Running -> Degraded when highLoadDetected;
            transition Degraded -> Running when loadRecovers;
            transition Running -> Stopped when shutdownCommand;
            transition Degraded -> Stopped when shutdownCommand;
        }
    }
    
    // ============================================================
    // NETWORKS
    // ============================================================
    
    part def SensorNetwork {
        attribute networkId : String;
        attribute coverageLocation : Location;
        attribute totalDevices : Integer = 0;
        
        part temperatureSensors : TemperatureSensor[*];
        part humiditySensors : HumiditySensor[*];
        part powerMeters : PowerMeter[*];
        part lightSensors : LightSensor[*];
        
        action def commissionSensor {
            in sensor : Sensor;
        }
        
        action def decommissionSensor {
            in sensorId : SensorId;
        }
    }
    
    part def ActuatorNetwork {
        attribute networkId : String;
        attribute coverageLocation : Location;
        attribute totalDevices : Integer = 0;
        
        part hvacUnits : HvacUnit[*];
        part lightingUnits : LightingUnit[*];
        
        action def commissionActuator {
            in actuator : Actuator;
        }
        
        action def decommissionActuator {
            in actuatorId : SensorId;
        }
    }
    
    // ============================================================
    // CENTRAL PLATFORM
    // ============================================================
    
    part def CentralPlatform {
        attribute platformId : String = "central-platform";
        attribute deploymentRegion : String = "primary";
        attribute uptimeTargetPct : Real = 99.5;
        attribute maintenanceMode : Boolean = false;
        
        part broker : MqttBroker;
        part assetMgmt : AssetManagementService;
        part ruleEngine : AutomationRuleEngine;
        part dataStore : TimeSeriesDataStore;
        part dashboard : WebDashboard;
        
        connection brokerToAssetMgmt between broker.clientEndpoints and assetMgmt.mqttClient;
        connection brokerToRuleEngine between broker.clientEndpoints and ruleEngine.mqttClient;
        connection brokerToDataStore between broker.clientEndpoints and dataStore.mqttClient;
        connection brokerToDashboard between broker.clientEndpoints and dashboard.mqttClient;
        
        state PlatformState {
            state Offline;
            state Booting;
            state Online;
            state Maintenance;
            state Failing;
            
            transition Offline -> Booting when platformStart;
            transition Booting -> Online when allServicesReady;
            transition Online -> Maintenance when maintenanceRequested;
            transition Maintenance -> Online when maintenanceComplete;
            transition Online -> Failing when criticalServiceDown;
            transition Failing -> Booting when failoverTriggered;
            transition Online -> Offline when platformStop;
        }
    }
    
    // ============================================================
    // TOP-LEVEL BUILDING AUTOMATION SYSTEM
    // ============================================================
    
    part def BuildingAutomationSystem {
        attribute systemId : String = "building-automation-001";
        attribute siteName : String;
        attribute timezone : String = "UTC";
        attribute commissioningDate : String;
        attribute occupancy : OccupancyState = OccupancyState::unoccupied;
        attribute defaultTemperatureSetpoint : TemperatureC = 22.0;
        attribute defaultHumiditySetpoint : HumidityPct = 50.0;
        attribute defaultLightSetpoint : LightLx = 300.0;
        
        part sensorNetwork : SensorNetwork;
        part actuatorNetwork : ActuatorNetwork;
        part centralPlatform : CentralPlatform;
        
        connection tempSensorsToBroker between sensorNetwork.temperatureSensors.mqttClient and centralPlatform.broker.clientEndpoints;
        connection humiditySensorsToBroker between sensorNetwork.humiditySensors.mqttClient and centralPlatform.broker.clientEndpoints;
        connection powerMetersToBroker between sensorNetwork.powerMeters.mqttClient and centralPlatform.broker.clientEndpoints;
        connection lightSensorsToBroker between sensorNetwork.lightSensors.mqttClient and centralPlatform.broker.clientEndpoints;
        connection hvacToBroker between actuatorNetwork.hvacUnits.mqttClient and centralPlatform.broker.clientEndpoints;
        connection lightingToBroker between actuatorNetwork.lightingUnits.mqttClient and centralPlatform.broker.clientEndpoints;
        
        action def commissioning {
            in site : String;
            in startDate : String;
        }
        
        action def gracefulShutdown {
        }
        
        state SystemLifecycle {
            state Decommissioned;
            state Commissioned;
            state Operating;
            state Idle;
            state Emergency;
            
            transition Decommissioned -> Commissioned when commissionComplete;
            transition Commissioned -> Operating when systemStart;
            transition Operating -> Idle when occupancyCleared;
            transition Idle -> Operating when occupancyDetected;
            transition Operating -> Emergency when emergencyAlarm;
            transition Idle -> Emergency when emergencyAlarm;
            transition Emergency -> Operating when alarmCleared;
            transition Operating -> Decommissioned when systemDecommission;
        }
    }
    
    // ============================================================
    // REQUIREMENTS
    // ============================================================
    
    requirement def SensorDataAcquisition {
        subject sys : BuildingAutomationSystem;
        doc 'The system shall periodically acquire environmental measurements from all connected sensors at their configured sampling rates and publish them to the MQTT broker.';
    }
    
    requirement def AutomatedHvacControl {
        subject sys : BuildingAutomationSystem;
        attribute setpoint : TemperatureC = 22.0;
        attribute tolerance : TemperatureC = 0.5;
        doc 'When the measured temperature exceeds the configured setpoint plus tolerance, the automation rule engine shall issue a cooling command to the appropriate HVAC unit; when the temperature falls below the setpoint minus tolerance, a heating command shall be issued.';
    }
    
    requirement def AutomatedLightingControl {
        subject sys : BuildingAutomationSystem;
        attribute lightThreshold : LightLx = 200.0;
        doc 'The automation rule engine shall adjust lighting brightness based on ambient light readings from the light sensors, increasing brightness when ambient light falls below the configured threshold.';
    }
    
    requirement def DataLogging {
        subject sys : BuildingAutomationSystem;
        attribute retentionDays : Integer = 365;
        doc 'All sensor measurements shall be logged with timestamps into the time-series data store for at least the configured retention period and remain queryable for reporting and trend analysis.';
    }
    
    requirement def ManualOverride {
        subject sys : BuildingAutomationSystem;
        doc 'The web dashboard shall allow an authorized operator to view real-time sensor data, view device status, and manually override automated control decisions; overrides shall take precedence over rule engine outputs until explicitly cleared.';
    }
    
    requirement def AssetInventory {
        subject sys : BuildingAutomationSystem;
        doc 'The asset management service shall maintain a live inventory of every connected device, recording its identity, type, and location, and shall track device online/offline status via heartbeats.';
    }
    
    requirement def ReliableMessaging {
        subject sys : BuildingAutomationSystem;
        attribute maxLatencyMs : Integer = 500;
        doc 'The MQTT broker shall route messages between sensors, actuators, and platform services with end-to-end delivery latency not exceeding the configured maximum, supporting retained messages and Quality-of-Service levels.';
    }
    
    requirement def ContinuousOperation {
        subject sys : BuildingAutomationSystem;
        doc 'The automation cycle (sensing, evaluation, actuation, logging, dashboard display) shall run continuously without operator intervention until intentionally stopped or placed in emergency mode.';
    }
    
    requirement def PowerMonitoring {
        subject sys : BuildingAutomationSystem;
        attribute samplingIntervalMs : Integer = 5000;
        doc 'The system shall monitor power consumption via power meters at the configured sampling interval and persist measurements for energy analysis and anomaly detection.';
    }
    
    // ============================================================
    // REQUIREMENT SATISFACTION
    // ============================================================
    
    satisfy SensorDataAcquisition by SensorNetwork;
    satisfy AutomatedHvacControl by AutomationRuleEngine;
    satisfy AutomatedLightingControl by AutomationRuleEngine;
    satisfy DataLogging by TimeSeriesDataStore;
    satisfy ManualOverride by WebDashboard;
    satisfy AssetInventory by AssetManagementService;
    satisfy ReliableMessaging by MqttBroker;
    satisfy ContinuousOperation by BuildingAutomationSystem;
    satisfy PowerMonitoring by PowerMeter;
}
