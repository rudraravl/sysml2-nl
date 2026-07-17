package 'Project Brillo IoT Platform' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    doc /* 
     * Project Brillo: A comprehensive IoT platform enabling secure device connectivity,
     * data collection, cloud processing, and intelligent control of distributed edge devices.
     * Primary function: Provide end-to-end infrastructure for IoT device management,
     * real-time sensor data aggregation, cloud-based analytics, and automated device control
     * with enterprise-grade security and scalability.
     */

    attribute def DeviceID :> String;
    attribute def SecurityToken :> String;
    attribute def ConnectionState :> String;

    item def SensorReading {
        attribute deviceId : DeviceID;
        attribute timestamp : TimeValue;
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
        attribute pressure : PressureValue;
    }

    item def ControlCommand {
        attribute targetDeviceId : DeviceID;
        attribute commandType : String;
        attribute parameter : Real;
        attribute priority : Integer;
    }

    item def DeviceStatus {
        attribute deviceId : DeviceID;
        attribute connectionState : ConnectionState;
        attribute batteryLevel : Real;
        attribute firmwareVersion : String;
        attribute lastHeartbeat : TimeValue;
    }

    item def AnalyticsResult {
        attribute deviceId : DeviceID;
        attribute anomalyDetected : Boolean;
        attribute predictedFailureTime : TimeValue;
        attribute recommendation : String;
    }

    port def EdgeDevicePort {
        out item sensorData : SensorReading[*];
        in item commands : ControlCommand[*];
        out item status : DeviceStatus[*];
    }

    port def CloudGatewayPort {
        in item incomingSensorData : SensorReading[*];
        out item outgoingCommands : ControlCommand[*];
        in item deviceStatuses : DeviceStatus[*];
    }

    port def AnalyticsPort {
        in item rawData : SensorReading[*];
        out item insights : AnalyticsResult[*];
    }

    port def ApplicationPort {
        in item analyticsResults : AnalyticsResult[*];
        out item userCommands : ControlCommand[*];
        in item deviceInfo : DeviceStatus[*];
    }

    part def EdgeDevice {
        attribute deviceId : DeviceID;
        attribute securityToken : SecurityToken;
        attribute connectionState : ConnectionState;

        port edgePort : EdgeDevicePort;

        part microcontroller {
            attribute processingPower : PowerValue;
            attribute memoryCapacity : Real;
        }

        part sensorArray {
            part temperatureSensor {
                perform action measureTemperature;
            }
            part humiditySensor {
                perform action measureHumidity;
            }
            part pressureSensor {
                perform action measurePressure;
            }
        }

        part communicationModule {
            attribute protocol : String;
            attribute signalStrength : Real;
            perform action transmitData;
            perform action receiveCommands;
        }

        part powerManagement {
            attribute batteryCapacity : Real;
            attribute currentCharge : Real;
            perform action monitorBattery;
        }

        part securityModule {
            attribute encryptionEnabled : Boolean;
            perform action authenticateConnection;
            perform action encryptData;
        }

        perform action operateDevice;
    }

    part def CloudGateway {
        attribute maxConcurrentConnections : Integer;
        attribute throughput : Real;

        port gatewayPort : CloudGatewayPort;

        part loadBalancer {
            attribute activeConnections : Integer;
            perform action distributeLoad;
        }

        part messageQueue {
            attribute queueDepth : Integer;
            attribute maxCapacity : Integer;
            perform action bufferMessages;
        }

        part protocolAdapter {
            perform action translateProtocols;
        }

        part connectionManager {
            perform action maintainConnections;
            perform action handleReconnection;
        }
    }

    part def CloudPlatform {
        port cloudPort : CloudGatewayPort;
        port analyticsPort : AnalyticsPort;
        port appPort : ApplicationPort;

        part dataIngestion {
            attribute ingestionRate : Real;
            perform action receiveData;
            perform action validateData;
        }

        part dataStorage {
            attribute storageCapacity : Real;
            attribute currentUsage : Real;
            perform action storeTimeSeries;
            perform action archiveHistorical;
        }

        part analyticsEngine {
            perform action processStreamData;
            perform action detectAnomalies;
            perform action generatePredictions;
        }

        part deviceRegistry {
            attribute registeredDevices : DeviceID[*];
            perform action registerDevice;
            perform action updateDeviceMetadata;
        }

        part commandDispatcher {
            perform action routeCommands;
            perform action prioritizeCommands;
            perform action trackExecution;
        }

        part securityService {
            attribute authenticationEnabled : Boolean;
            attribute encryptionStandard : String;
            perform action authenticateDevices;
            perform action enforceAccessControl;
            perform action auditActivity;
        }
    }

    part def UserApplication {
        port userPort : ApplicationPort;

        part dashboard {
            perform action displayMetrics;
            perform action visualizeData;
        }

        part controlInterface {
            perform action issueCommands;
            perform action configureDevices;
        }

        part alertingSystem {
            perform action notifyAnomalies;
            perform action escalateIssues;
        }
    }

    action def CollectSensorData {
        in device : EdgeDevice;
        out reading : SensorReading;
    }

    action def TransmitToCloud {
        in reading : SensorReading;
        in gateway : CloudGateway;
        out transmitted : Boolean;
    }

    action def AnalyzeData {
        in readings : SensorReading[*];
        out result : AnalyticsResult;
    }

    action def DispatchCommand {
        in command : ControlCommand;
        in targetDevice : EdgeDevice;
        out executed : Boolean;
    }

    action def MonitorDeviceHealth {
        in device : EdgeDevice;
        out status : DeviceStatus;
    }

    action def DeviceOperationCycle {
        first start;
        then merge operationLoop;

        action authenticate {
            doc /* Authenticate with cloud platform */
        }
        then operationLoop;

        action collectData : CollectSensorData {
            in device;
            out reading;
        }

        then action transmit : TransmitToCloud {
            in reading = collectData.reading;
            in gateway;
            out transmitted;
        }

        then action checkCommands {
            out commandAvailable : Boolean;
        }

        then decide;
            if checkCommands.commandAvailable then executeCommand;
            else reportStatus;

        action executeCommand : DispatchCommand {
            in command;
            in targetDevice;
            out executed;
        }
        then reportStatus;

        action reportStatus : MonitorDeviceHealth {
            in device;
            out status;
        }

        then action sleep {
            in duration : TimeValue;
        }

        then operationLoop;
    }

    state def EdgeDeviceLifecycle {
        entry; then initializing;

        state initializing {
            entry; then action bootup;
            action bootup;
            then action loadConfig;
            action loadConfig;
        }

        transition init_to_connecting
            first initializing
            then connecting;

        state connecting {
            entry; then action establishConnection;
            action establishConnection;
        }

        transition connecting_to_authenticated
            first connecting
            then authenticated;

        transition connecting_to_error
            first connecting
            then error;

        state authenticated {
            entry; then action performHandshake;
            action performHandshake;
        }

        transition authenticated_to_operational
            first authenticated
            then operational;

        state operational {
            entry; then active;

            state active {
                entry; then collecting;

                state collecting;
                transition collecting_to_transmitting
                    first collecting
                    then transmitting;

                state transmitting;
                transition transmitting_to_waiting
                    first transmitting
                    then waiting;

                state waiting;
                transition waiting_to_collecting
                    first waiting
                    then collecting;
            }

            state idle;
            transition active_to_idle
                first active
                then idle;

            transition idle_to_active
                first idle
                then active;
        }

        transition operational_to_error
            first operational
            then error;

        state error {
            entry; then action logError;
            action logError;
        }

        transition error_to_recovering
            first error
            then recovering;

        state recovering {
            entry; then action attemptRecovery;
            action attemptRecovery;
        }

        transition recovering_to_connecting
            first recovering
            then connecting;

        transition recovering_to_shutdown
            first recovering
            then shutdown;

        state shutdown;
    }

    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SecurityRequirement;
    requirement def ReliabilityRequirement;

    requirement <'FR-001'> deviceConnectivity : FunctionalRequirement {
        doc /* 
         * The system shall support simultaneous connections from at least 10,000 edge devices
         * with automatic load balancing and failover capabilities.
         */
        subject gateway : CloudGateway;
        require constraint {
            gateway.maxConcurrentConnections >= 10000
        }
    }

    requirement <'FR-002'> dataCollection : FunctionalRequirement {
        doc /*
         * Edge devices shall collect sensor data including temperature, humidity, and pressure
         * at configurable intervals between 1 second and 1 hour.
         */
        subject device : EdgeDevice;
    }

    requirement <'FR-003'> cloudProcessing : FunctionalRequirement {
        doc /*
         * The cloud platform shall process incoming sensor data streams, perform real-time
         * analytics, detect anomalies, and generate actionable insights.
         */
        subject platform : CloudPlatform;
    }

    requirement <'FR-004'> commandExecution : FunctionalRequirement {
        doc /*
         * The system shall enable remote command dispatch to edge devices with priority-based
         * queuing and execution confirmation.
         */
        subject platform : CloudPlatform;
    }

    requirement <'PR-001'> dataLatency : PerformanceRequirement {
        doc /*
         * Sensor data shall be transmitted from edge device to cloud platform with end-to-end
         * latency not exceeding 500 milliseconds under normal network conditions.
         */
    }

    requirement <'PR-002'> throughput : PerformanceRequirement {
        doc /*
         * The cloud gateway shall sustain data ingestion throughput of at least 100,000
         * messages per second with 99.9% availability.
         */
        subject gateway : CloudGateway;
        require constraint {
            gateway.throughput >= 100000.0
        }
    }

    requirement <'SR-001'> authentication : SecurityRequirement {
        doc /*
         * All edge devices shall authenticate with the cloud platform using mutual TLS
         * with device-specific certificates before data exchange.
         */
        subject device : EdgeDevice;
        require constraint {
            device.securityModule.encryptionEnabled == true
        }
    }

    requirement <'SR-002'> encryption : SecurityRequirement {
        doc /*
         * All data in transit between edge devices and cloud platform shall be encrypted
         * using AES-256 or equivalent encryption standard.
         */
        subject platform : CloudPlatform;
    }

    requirement <'RR-001'> deviceResilience : ReliabilityRequirement {
        doc /*
         * Edge devices shall implement automatic reconnection with exponential backoff
         * in case of network disruption, maintaining local data buffering for up to 24 hours.
         */
        subject device : EdgeDevice;
    }

    requirement <'RR-002'> platformAvailability : ReliabilityRequirement {
        doc /*
         * The cloud platform shall maintain 99.95% uptime with automatic failover and
         * redundant infrastructure across multiple availability zones.
         */
        subject platform : CloudPlatform;
    }

    part def BrilloPlatformSystem {
        part edgeDevices : EdgeDevice[1..*];
        part gateway : CloudGateway;
        part cloudPlatform : CloudPlatform;
        part userApp : UserApplication;
    }

    part brilloPlatformSystem : BrilloPlatformSystem {
        part :>> edgeDevices : EdgeDevice[1..*] {
            attribute :>> deviceId;
            attribute :>> securityToken;
            attribute :>> connectionState = "disconnected";
        }

        part :>> gateway : CloudGateway {
            attribute :>> maxConcurrentConnections = 15000;
            attribute :>> throughput = 150000.0;
        }

        part :>> cloudPlatform : CloudPlatform;

        part :>> userApp : UserApplication;

        connect edgeDevices.edgePort to gateway.gatewayPort;
        connect gateway.gatewayPort to cloudPlatform.cloudPort;
        connect cloudPlatform.appPort to userApp.userPort;

        perform action platformOperation : BrilloPlatformOperation;

        satisfy deviceConnectivity;
        satisfy dataCollection;
        satisfy cloudProcessing;
        satisfy commandExecution;
        satisfy dataLatency;
        satisfy throughput;
        satisfy authentication;
        satisfy encryption;
        satisfy deviceResilience;
        satisfy platformAvailability;
    }

    action def BrilloPlatformOperation {
        first start;
        then merge continuousOperation;

        action monitorDevices : MonitorDeviceHealth {
            in device;
            out status;
        }

        then action collectFromDevices : CollectSensorData {
            in device;
            out reading;
        }

        then action analyzeData : AnalyzeData {
            in readings;
            out result;
        }

        then action transmitToCloud : TransmitToCloud {
            in reading = collectFromDevices.reading;
            in gateway;
            out transmitted;
        }

        then action processInCloud {
            in data : SensorReading[*];
            in analytics : AnalyticsResult;
        }

        then decide;
            if analyzeData.result.anomalyDetected then generateAlert;
            else checkCommands;

        action generateAlert {
            in anomaly : AnalyticsResult;
        }
        then checkCommands;

        action checkCommands {
            out commandsPending : Boolean;
        }

        then decide;
            if checkCommands.commandsPending then dispatchCommands;
            else continuousOperation;

        action dispatchCommands : DispatchCommand {
            in command;
            in targetDevice;
            out executed;
        }

        then continuousOperation;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Project Brillo IoT Platform'::*;

    part testSubject : EdgeDevice {
        exhibit state sm : EdgeDeviceLifecycle;
    }

    action orchestrator {
        action collectDataProbe : CollectSensorData {
            // TODO(human): unsupported input type for device: EdgeDevice (type is not a primitive, enum, extracted payload def, or known value type)
        }
        first collectDataProbe;
    }
}
