package ProjectBrillo {
    import ScalarValues::*;
    
    package Types {
        attribute def TemperatureValue :> Real {
            doc / Temperature measurement in degrees Celsius. Range: -40 to 125. /;
            attribute min : Real = -40.0;
            attribute max : Real = 125.0;
        }
        
        attribute def HumidityValue :> Real {
            doc / Relative humidity in percent. Range: 0 to 100. /;
            attribute min : Real = 0.0;
            attribute max : Real = 100.0;
        }
        
        attribute def PressureValue :> Real {
            doc / Atmospheric pressure in hectopascals. /;
            attribute min : Real = 300.0;
            attribute max : Real = 1100.0;
        }
        
        attribute def BatteryLevelValue :> Real {
            doc / Battery voltage in millivolts. /;
            attribute min : Real = 0.0;
            attribute max : Real = 5000.0;
        }
        
        attribute def FrequencyValue :> Real {
            doc / Frequency in hertz. /;
        }
        
        attribute def DurationValue :> Real {
            doc / Duration in milliseconds. /;
        }
        
        attribute def SignalStrengthValue :> Real {
            doc / Signal strength in dBm. /;
            attribute min : Real = -120.0;
            attribute max : Real = 10.0;
        }
        
        attribute def DataRateValue :> Real {
            doc / Data rate in kilobits per second. /;
        }
        
        attribute def PowerValue :> Real {
            doc / Power consumption in milliwatts. /;
        }
        
        attribute def MemorySizeValue :> Integer {
            doc / Memory size in kilobytes. /;
        }
        
        attribute def LatencyValue :> Real {
            doc / Latency in milliseconds. /;
        }
    }
    
    package Items {
        import Types::*;
        
        enum CommandType {
            SET_FREQUENCY;
            SET_SAMPLING_INTERVAL;
            REBOOT;
            CALIBRATE;
            ENABLE_SENSOR;
            DISABLE_SENSOR;
            UPDATE_FIRMWARE;
            SHUTDOWN;
        }
        
        enum AlertSeverity {
            INFO;
            WARNING;
            CRITICAL;
        }
        
        enum DeviceStatusType {
            ONLINE;
            OFFLINE;
            ERROR;
            MAINTENANCE;
        }
        
        enum AlertType {
            TEMPERATURE_ANOMALY;
            HUMIDITY_ANOMALY;
            PRESSURE_ANOMALY;
            BATTERY_LOW;
            SIGNAL_WEAK;
            DEVICE_FAILURE_PREDICTED;
            CONNECTION_LOST;
        }
        
        item def SensorReading {
            attribute temperature : TemperatureValue;
            attribute humidity : HumidityValue;
            attribute pressure : PressureValue;
            attribute timestamp : String;
            attribute deviceId : String;
        }
        
        item def Command {
            attribute commandType : CommandType;
            attribute deviceId : String;
            attribute parameter : String;
            attribute timestamp : String;
        }
        
        item def Alert {
            attribute alertType : AlertType;
            attribute severity : AlertSeverity;
            attribute deviceId : String;
            attribute message : String;
            attribute timestamp : String;
        }
        
        item def DeviceStatusReport {
            attribute deviceId : String;
            attribute status : DeviceStatusType;
            attribute batteryLevel : BatteryLevelValue;
            attribute signalStrength : SignalStrengthValue;
            attribute uptime : DurationValue;
            attribute timestamp : String;
        }
        
        item def TelemetryMessage {
            attribute deviceId : String;
            attribute sensorReading : SensorReading;
            attribute statusReport : DeviceStatusReport;
            attribute sequenceNumber : Integer;
        }
        
        item def DeviceRegistration {
            attribute deviceId : String;
            attribute manufacturer : String;
            attribute model : String;
            attribute firmwareVersion : String;
            attribute sensors : String;
        }
        
        item def AnalyticsResult {
            attribute deviceId : String;
            attribute insight : String;
            attribute isAnomaly : Boolean;
            attribute failurePrediction : String;
            attribute confidence : Real;
            attribute timestamp : String;
        }
    }
    
    package EdgeDevice {
        import Types::*;
        import Items::*;
        
        port def SensorDataPort {
            out sensorReading : SensorReading;
        }
        
        port def EdgeCommPort {
            out telemetry : TelemetryMessage;
            in command : Command;
        }
        
        part def Microcontroller {
            attribute clockFrequency : FrequencyValue;
            attribute flashMemory : MemorySizeValue;
            attribute ramSize : MemorySizeValue;
            
            action def processData {
                in rawReading : SensorReading;
                out processedReading : SensorReading;
            }
            
            action def executeCommand {
                in command : Command;
                out result : Boolean;
            }
        }
        
        part def PowerManagement {
            attribute batteryCapacity : BatteryLevelValue;
            attribute currentLevel : BatteryLevelValue;
            attribute powerConsumption : PowerValue;
            attribute lowPowerThreshold : BatteryLevelValue;
            
            state powerState {
                state Active;
                state Sleep;
                state LowPower;
                state Critical;
                
                transition Active -> Sleep when currentLevel < 20.0;
                transition Sleep -> Active when currentLevel > 50.0;
                transition Active -> LowPower when currentLevel < 10.0;
                transition LowPower -> Critical when currentLevel < 5.0;
                transition LowPower -> Active when currentLevel > 30.0;
            }
        }
        
        part def TemperatureSensor {
            attribute accuracy : TemperatureValue;
            attribute samplingFrequency : FrequencyValue;
            attribute minRange : TemperatureValue;
            attribute maxRange : TemperatureValue;
            
            action def read {
                out value : TemperatureValue;
            }
        }
        
        part def HumiditySensor {
            attribute accuracy : HumidityValue;
            attribute samplingFrequency : FrequencyValue;
            attribute minRange : HumidityValue;
            attribute maxRange : HumidityValue;
            
            action def read {
                out value : HumidityValue;
            }
        }
        
        part def PressureSensor {
            attribute accuracy : PressureValue;
            attribute samplingFrequency : FrequencyValue;
            attribute minRange : PressureValue;
            attribute maxRange : PressureValue;
            
            action def read {
                out value : PressureValue;
            }
        }
        
        part def SensorArray {
            part temperatureSensor : TemperatureSensor;
            part humiditySensor : HumiditySensor;
            part pressureSensor : PressureSensor;
            
            action def collectAll {
                out temperature : TemperatureValue;
                out humidity : HumidityValue;
                out pressure : PressureValue;
            }
            
            action def buildReading {
                in temperature : TemperatureValue;
                in humidity : HumidityValue;
                in pressure : PressureValue;
                out reading : SensorReading;
            }
        }
        
        part def SecurityModule {
            attribute encryptionAlgorithm : String;
            attribute authenticationProtocol : String;
            attribute certificateId : String;
            
            action def encrypt {
                in data : String;
                out encryptedData : String;
            }
            
            action def decrypt {
                in encryptedData : String;
                out data : String;
            }
            
            action def authenticate {
                in credentials : String;
                out authenticated : Boolean;
            }
            
            action def generateHash {
                in data : String;
                out hash : String;
            }
        }
        
        part def CommunicationModule {
            attribute protocol : String;
            attribute maxDataRate : DataRateValue;
            attribute signalStrength : SignalStrengthValue;
            attribute retryLimit : Integer;
            
            action def transmit {
                in message : TelemetryMessage;
            }
            
            action def receive {
                out command : Command;
            }
            
            action def handshake {
                out success : Boolean;
            }
            
            state connectionState {
                state Disconnected;
                state Connected;
                state Error;
                state Reconnecting;
                
                transition Disconnected -> Connected;
                transition Connected -> Error when signalStrength < -90.0;
                transition Error -> Reconnecting;
                transition Reconnecting -> Connected;
                transition Reconnecting -> Disconnected;
            }
        }
        
        part def EdgeDevice {
            attribute deviceId : String;
            attribute firmwareVersion : String;
            attribute samplingInterval : DurationValue;
            attribute manufacturer : String;
            attribute model : String;
            
            port sensorPort : SensorDataPort;
            port commPort : EdgeCommPort;
            
            part microcontroller : Microcontroller;
            part powerManagement : PowerManagement;
            part sensorArray : SensorArray;
            part communication : CommunicationModule;
            part security : SecurityModule;
            
            state lifecycle {
                state Booting;
                state Authenticating;
                state Connecting;
                state Operational;
                state Collecting;
                state Transmitting;
                state CheckingCommands;
                state ReportingStatus;
                state Sleeping;
                state ErrorRecovery;
                state Reconnecting;
                
                transition Booting -> Authenticating;
                transition Authenticating -> Connecting;
                transition Connecting -> Operational;
                transition Operational -> Collecting;
                transition Collecting -> Transmitting;
                transition Transmitting -> CheckingCommands;
                transition CheckingCommands -> ReportingStatus;
                transition ReportingStatus -> Sleeping;
                transition Sleeping -> Collecting;
                transition Connecting -> ErrorRecovery;
                transition Authenticating -> ErrorRecovery;
                transition Transmitting -> ErrorRecovery;
                transition ErrorRecovery -> Reconnecting;
                transition Reconnecting -> Connecting;
            }
            
            action def operationalCycle {
                action collectData {
                    out reading : SensorReading;
                }
                action encryptData {
                    in reading : SensorReading;
                    out encrypted : SensorReading;
                }
                action transmitData {
                    in reading : SensorReading;
                    out message : TelemetryMessage;
                }
                action checkCommands {
                    out command : Command;
                }
                action reportStatus {
                    out status : DeviceStatusReport;
                }
                action enterSleep {
                    in duration : DurationValue;
                }
                
                flow collectData.reading to encryptData.reading;
                flow encryptData.encrypted to transmitData.reading;
            }
            
            action def bootSequence {
                action initHardware {
                    out ready : Boolean;
                }
                action loadFirmware {
                    out loaded : Boolean;
                }
                action selfTest {
                    out passed : Boolean;
                }
                
                flow initHardware.ready to loadFirmware.loaded;
                flow loadFirmware.loaded to selfTest.passed;
            }
            
            action def recoverFromError {
                action diagnose {
                    out errorType : String;
                }
                action resetConnection {
                    out success : Boolean;
                }
                action reAuthenticate {
                    out authenticated : Boolean;
                }
                
                flow diagnose.errorType to resetConnection.success;
                flow resetConnection.success to reAuthenticate.authenticated;
            }
        }
    }
    
    package CloudGateway {
        import Items::*;
        import Types::*;
        
        port def GatewayEdgePort {
            in telemetry : TelemetryMessage;
            out command : Command;
        }
        
        port def GatewayCloudPort {
            out telemetry : TelemetryMessage;
            in command : Command;
        }
        
        part def LoadBalancer {
            attribute maxConnections : Integer;
            attribute currentConnections : Integer;
            attribute algorithm : String;
            attribute healthyServerThreshold : Integer;
            
            action def distribute {
                in message : TelemetryMessage;
                out routed : TelemetryMessage;
            }
            
            action def checkHealth {
                out healthyCount : Integer;
            }
            
            state loadState {
                state Nominal;
                state HighLoad;
                state Overloaded;
                state Degraded;
                
                transition Nominal -> HighLoad when currentConnections > 5000;
                transition HighLoad -> Overloaded when currentConnections > 9000;
                transition HighLoad -> Nominal when currentConnections < 3000;
                transition Overloaded -> HighLoad when currentConnections < 8000;
                transition Nominal -> Degraded when healthyCount < 2;
                transition Degraded -> Nominal when healthyCount >= 2;
            }
        }
        
        part def MessageQueue {
            attribute capacity : Integer;
            attribute currentSize : Integer;
            attribute persistenceEnabled : Boolean;
            attribute maxRetentionTime : DurationValue;
            
            action def enqueue {
                in message : TelemetryMessage;
                out success : Boolean;
            }
            
            action def dequeue {
                out message : TelemetryMessage;
                out success : Boolean;
            }
            
            action def purge {
                in olderThan : DurationValue;
                out purgedCount : Integer;
            }
            
            state queueState {
                state Empty;
                state Partial;
                state Full;
                state Overflow;
                
                transition Empty -> Partial;
                transition Partial -> Full when currentSize >= capacity;
                transition Full -> Overflow when currentSize > capacity;
                transition Overflow -> Full;
                transition Full -> Partial;
                transition Partial -> Empty;
            }
        }
        
        part def ProtocolTranslator {
            attribute supportedProtocols : String;
            
            action def translate {
                in incoming : TelemetryMessage;
                in sourceProtocol : String;
                in targetProtocol : String;
                out translated : TelemetryMessage;
            }
            
            action def detectProtocol {
                in message : TelemetryMessage;
                out protocol : String;
            }
        }
        
        part def CloudGateway {
            attribute maxConcurrentConnections : Integer;
            attribute throughput : DataRateValue;
            attribute averageLatency : LatencyValue;
            
            port edgePort : GatewayEdgePort;
            port cloudPort : GatewayCloudPort;
            
            part loadBalancer : LoadBalancer;
            part messageQueue : MessageQueue;
            part protocolTranslator : ProtocolTranslator;
            
            state gatewayState {
                state Receiving;
                state Balancing;
                state Buffering;
                state Translating;
                state Forwarding;
                state Error;
                state Recovering;
                
                transition Receiving -> Balancing;
                transition Balancing -> Buffering;
                transition Buffering -> Translating;
                transition Translating -> Forwarding;
                transition Forwarding -> Receiving;
                transition Buffering -> Error;
                transition Translating -> Error;
                transition Error -> Recovering;
                transition Recovering -> Receiving;
            }
            
            action def processMessage {
                action receive {
                    out telemetry : TelemetryMessage;
                }
                action balance {
                    in telemetry : TelemetryMessage;
                    out balanced : TelemetryMessage;
                }
                action buffer {
                    in balanced : TelemetryMessage;
                    out buffered : TelemetryMessage;
                }
                action translate {
                    in buffered : TelemetryMessage;
                    out translated : TelemetryMessage;
                }
                action forward {
                    in translated : TelemetryMessage;
                }
                
                flow receive.telemetry to balance.telemetry;
                flow balance.balanced to buffer.balanced;
                flow buffer.buffered to translate.buffered;
                flow translate.translated to forward.translated;
            }
            
            action def handleCommand {
                action receiveCommand {
                    out command : Command;
                }
                action routeCommand {
                    in command : Command;
                    out routed : Command;
                }
                action sendToDevice {
                    in routed : Command;
                }
                
                flow receiveCommand.command to routeCommand.command;
                flow routeCommand.routed to sendToDevice.routed;
            }
        }
    }
    
    package CloudPlatform {
        import Items::*;
        import Types::*;
        
        port def PlatformGatewayPort {
            in telemetry : TelemetryMessage;
            out command : Command;
        }
        
        port def PlatformAppPort {
            out analyticsResult : AnalyticsResult;
            out alert : Alert;
            in userCommand : Command;
        }
        
        part def DataStorage {
            attribute capacity : Integer;
            attribute storageType : String;
            attribute retentionDays : Integer;
            
            action def store {
                in data : TelemetryMessage;
                out storedId : String;
            }
            
            action def retrieve {
                in query : String;
                out data : SensorReading;
            }
            
            action def archive {
                in olderThan : DurationValue;
                out archivedCount : Integer;
            }
            
            action def backup {
                out success : Boolean;
            }
        }
        
        part def DeviceRegistry {
            attribute registeredDevices : Integer;
            attribute activeDevices : Integer;
            
            action def register {
                in device : DeviceRegistration;
                out success : Boolean;
            }
            
            action def deregister {
                in deviceId : String;
                out success : Boolean;
            }
            
            action def getStatus {
                in deviceId : String;
                out status : DeviceStatusType;
            }
            
            action def updateStatus {
                in deviceId : String;
                in status : DeviceStatusType;
            }
            
            action def listDevices {
                in filter : String;
                out devices : String;
            }
        }
        
        part def AnalyticsEngine {
            attribute processingRate : DataRateValue;
            attribute modelVersion : String;
            attribute anomalyThreshold : Real;
            
            action def analyze {
                in data : SensorReading;
                out result : AnalyticsResult;
            }
            
            action def detectAnomaly {
                in data : SensorReading;
                out isAnomaly : Boolean;
                out severity : AlertSeverity;
            }
            
            action def predictFailure {
                in data : SensorReading;
                out prediction : String;
                out confidence : Real;
            }
            
            action def generateInsight {
                in data : SensorReading;
                out insight : String;
            }
            
            state analyticsState {
                state Idle;
                state Processing;
                state Alerting;
                state Learning;
                
                transition Idle -> Processing;
                transition Processing -> Alerting;
                transition Processing -> Idle;
                transition Alerting -> Idle;
                transition Idle -> Learning;
                transition Learning -> Idle;
            }
        }
        
        part def CommandDispatcher {
            attribute activeCommands : Integer;
            attribute maxRetryAttempts : Integer;
            
            action def dispatch {
                in command : Command;
                out dispatched : Command;
            }
            
            action def schedule {
                in command : Command;
                in delay : DurationValue;
                out scheduled : Command;
            }
            
            action def cancel {
                in commandId : String;
                out cancelled : Boolean;
            }
            
            action def confirmExecution {
                in commandId : String;
                out confirmed : Boolean;
            }
        }
        
        part def SecurityService {
            attribute activeTokens : Integer;
            attribute encryptionStandard : String;
            attribute tokenExpiry : DurationValue;
            
            action def authenticateDevice {
                in credentials : String;
                out authenticated : Boolean;
            }
            
            action def authorizeAccess {
                in userId : String;
                in resource : String;
                out authorized : Boolean;
            }
            
            action def revokeToken {
                in deviceId : String;
                out revoked : Boolean;
            }
            
            action def issueToken {
                in deviceId : String;
                out token : String;
            }
            
            state securityState {
                state Authenticating;
                state Authorized;
                state Denied;
                state TokenExpired;
                
                transition Authenticating -> Authorized;
                transition Authenticating -> Denied;
                transition Denied -> Authenticating;
                transition Authorized -> TokenExpired;
                transition TokenExpired -> Authenticating;
            }
        }
        
        part def CloudPlatform {
            port gatewayPort : PlatformGatewayPort;
            port appPort : PlatformAppPort;
            
            part dataStorage : DataStorage;
            part deviceRegistry : DeviceRegistry;
            part analyticsEngine : AnalyticsEngine;
            part commandDispatcher : CommandDispatcher;
            part securityService : SecurityService;
            
            state platformState {
                state Ingesting;
                state Authenticating;
                state Storing;
                state Analyzing;
                state Dispatching;
                state Idle;
                state Error;
                
                transition Idle -> Ingesting;
                transition Ingesting -> Authenticating;
                transition Authenticating -> Storing;
                transition Storing -> Analyzing;
                transition Analyzing -> Dispatching;
                transition Dispatching -> Idle;
                transition Ingesting -> Error;
                transition Authenticating -> Error;
                transition Error -> Idle;
            }
            
            action def processTelemetry {
                action ingest {
                    in telemetry : TelemetryMessage;
                    out reading : SensorReading;
                    out deviceId : String;
                    out statusReport : DeviceStatusReport;
                }
                action authenticate {
                    in deviceId : String;
                    out authenticated : Boolean;
                }
                action store {
                    in telemetry : TelemetryMessage;
                }
                action updateRegistry {
                    in deviceId : String;
                    in statusReport : DeviceStatusReport;
                }
                action analyze {
                    in reading : SensorReading;
                    out result : AnalyticsResult;
                    out alert : Alert;
                }
                action dispatch {
                    in command : Command;
                }
                
                flow ingest.reading to analyze.reading;
                flow ingest.deviceId to authenticate.deviceId;
                flow ingest.telemetry to store.telemetry;
                flow ingest.deviceId to updateRegistry.deviceId;
                flow ingest.statusReport to updateRegistry.statusReport;
                flow analyze.result to appPort.analyticsResult;
                flow analyze.alert to appPort.alert;
            }
            
            action def handleUserCommand {
                action receiveCommand {
                    out command : Command;
                }
                action authorize {
                    in command : Command;
                    out authorized : Boolean;
                }
                action route {
                    in command : Command;
                    out routed : Command;
                }
                
                flow receiveCommand.command to authorize.command;
                flow authorize.authorized to route.command;
            }
        }
    }
    
    package UserApplication {
        import Items::*;
        import Types::*;
        
        port def AppCloudPort {
            in analyticsResult : AnalyticsResult;
            in alert : Alert;
            out userCommand : Command;
        }
        
        part def Dashboard {
            attribute refreshRate : Integer;
            attribute theme : String;
            attribute maxWidgets : Integer;
            
            action def display {
                in data : SensorReading;
            }
            
            action def visualize {
                in analytics : AnalyticsResult;
            }
            
            action def showMetrics {
                in metrics : String;
            }
            
            action def renderChart {
                in data : SensorReading;
                in chartType : String;
            }
            
            state dashboardState {
                state Loading;
                state Displaying;
                state Refreshing;
                state Error;
                
                transition Loading -> Displaying;
                transition Displaying -> Refreshing;
                transition Refreshing -> Displaying;
                transition Loading -> Error;
                transition Error -> Loading;
            }
        }
        
        part def ControlInterface {
            attribute supportedCommands : String;
            
            action def issueCommand {
                in commandType : CommandType;
                in deviceId : String;
                out command : Command;
            }
            
            action def configureDevice {
                in deviceId : String;
                in parameter : String;
                in value : String;
                out command : Command;
            }
            
            action def batchCommand {
                in commands : Command[*];
                out batchId : String;
            }
            
            action def undoCommand {
                in commandId : String;
                out undone : Boolean;
            }
        }
        
        part def AlertingSystem {
            attribute notificationPreferences : String;
            attribute notificationChannel : String;
            attribute quietHours : Boolean;
            
            action def notify {
                in alert : Alert;
            }
            
            action def logAlert {
                in alert : Alert;
            }
            
            action def acknowledge {
                in alertId : String;
                out acknowledged : Boolean;
            }
            
            action def escalate {
                in alert : Alert;
                out escalated : Boolean;
            }
            
            state alertState {
                state Monitoring;
                state Notifying;
                state Acknowledged;
                state Escalated;
                
                transition Monitoring -> Notifying;
                transition Notifying -> Acknowledged;
                transition Notifying -> Escalated;
                transition Acknowledged -> Monitoring;
                transition Escalated -> Monitoring;
            }
        }
        
        part def UserApplication {
            port cloudPort : AppCloudPort;
            
            part dashboard : Dashboard;
            part controlInterface : ControlInterface;
            part alertingSystem : AlertingSystem;
            
            state appState {
                state Idle;
                state ViewingDashboard;
                state IssuingCommand;
                state HandlingAlert;
                state Configuring;
                
                transition Idle -> ViewingDashboard;
                transition ViewingDashboard -> IssuingCommand;
                transition IssuingCommand -> ViewingDashboard;
                transition Idle -> HandlingAlert;
                transition HandlingAlert -> Idle;
                transition ViewingDashboard -> Configuring;
                transition Configuring -> ViewingDashboard;
            }
            
            action def handleAlert {
                action receive {
                    in alert : Alert;
                }
                action displayAlert {
                    in alert : Alert;
                }
                action notify {
                    in alert : Alert;
                }
                action log {
                    in alert : Alert;
                }
                
                flow receive.alert to displayAlert.alert;
                flow receive.alert to notify.alert;
                flow receive.alert to log.alert;
            }
            
            action def sendCommand {
                action createCommand {
                    in commandType : CommandType;
                    in deviceId : String;
                    out command : Command;
                }
                action validateCommand {
                    in command : Command;
                    out valid : Boolean;
                }
                action transmit {
                    in command : Command;
                }
                
                flow createCommand.command to validateCommand.command;
                flow validateCommand.valid to transmit.command;
            }
        }
    }
    
    package System {
        import EdgeDevice::*;
        import CloudGateway::*;
        import CloudPlatform::*;
        import UserApplication::*;
        import Items::*;
        import Types::*;
        
        part def BrilloSystem {
            part edgeDevices : EdgeDevice[*];
            part cloudGateway : CloudGateway;
            part cloudPlatform : CloudPlatform;
            part userApp : UserApplication;
            
            connection edgeDevices.commPort to cloudGateway.edgePort;
            connection cloudGateway.cloudPort to cloudPlatform.gatewayPort;
            connection cloudPlatform.appPort to userApp.cloudPort;
        }
    }
    
    package Requirements {
        import Types::*;
        import Items::*;
        
        requirement def EdgeDeviceSecurityRequirement {
            doc / Edge devices must encrypt all transmitted data and authenticate all connections to the cloud platform. /;
            attribute encryptionStandard : String;
            attribute authenticationProtocol : String;
        }
        
        requirement def GatewayScalabilityRequirement {
            doc / The cloud gateway must support at least the specified number of simultaneous device connections. /;
            attribute maxConnections : Integer;
            attribute maxThroughput : DataRateValue;
        }
        
        requirement def PlatformPerformanceRequirement {
            doc / The cloud platform must process telemetry data within the specified latency. /;
            attribute maxLatency : DurationValue;
            attribute maxDataLoss : Integer;
        }
        
        requirement def DataIntegrityRequirement {
            doc / All sensor data must be transmitted without loss through the message queue. /;
            attribute maxDataLoss : Integer;
        }
        
        requirement def ReliabilityRequirement {
            doc / The system must automatically recover from connection failures within the specified time. /;
            attribute maxRecoveryTime : DurationValue;
        }
        
        requirement def AnalyticsAccuracyRequirement {
            doc / The analytics engine must detect anomalies with the specified minimum accuracy. /;
            attribute minAccuracy : Real;
        }
        
        requirement def UserInterfaceRequirement {
            doc / The user application must display real-time data and allow remote device control. /;
            attribute maxRefreshInterval : DurationValue;
        }
        
        requirement def EdgeDeviceLifecycleRequirement {
            doc / Edge devices must follow the specified operational lifecycle including boot, connect, operational loop, and error recovery. /;
            attribute maxBootTime : DurationValue;
        }
        
        requirement EdgeDeviceSecurity : EdgeDeviceSecurityRequirement {
            doc / All edge device communication shall use AES-256 encryption and mutual TLS authentication. /;
            attribute encryptionStandard = "AES-256";
            attribute authenticationProtocol = "mutual-TLS";
        }
        
        requirement GatewayCapacity : GatewayScalabilityRequirement {
            doc / The cloud gateway shall support at least 10,000 simultaneous edge device connections with a throughput of at least 500 kbps. /;
            attribute maxConnections = 10000;
            attribute maxThroughput = 500.0;
        }
        
        requirement PlatformLatency : PlatformPerformanceRequirement {
            doc / The cloud platform shall process telemetry data within 100 milliseconds with zero data loss. /;
            attribute maxLatency = 100.0;
            attribute maxDataLoss = 0;
        }
        
        requirement SystemReliability : ReliabilityRequirement {
            doc / The system shall automatically recover from connection failures within 30 seconds. /;
            attribute maxRecoveryTime = 30000.0;
        }
        
        requirement AnalyticsPerformance : AnalyticsAccuracyRequirement {
            doc / The analytics engine shall detect anomalies with at least 95 percent accuracy. /;
            attribute minAccuracy = 0.95;
        }
        
        requirement DataLossPrevention : DataIntegrityRequirement {
            doc / The message queue shall guarantee zero data loss during peak load conditions with persistent storage. /;
            attribute maxDataLoss = 0;
        }
        
        requirement UserAppUsability : UserInterfaceRequirement {
            doc / The dashboard shall refresh at most every 5 seconds and support real-time alerting with sub-second notification delivery. /;
            attribute maxRefreshInterval = 5000.0;
        }
        
        requirement EdgeDeviceBootTime : EdgeDeviceLifecycleRequirement {
            doc / Edge devices shall complete boot and secure connection within 10 seconds of power-on. /;
            attribute maxBootTime = 10000.0;
        }
    }
}
