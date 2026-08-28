package IoTGatewaySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def SensorData {
        attribute sensorId : String;
        attribute sensorType : String;
        attribute value : Real;
        attribute unit : String;
        attribute timestamp : TimeValue;
    }

    item def AggregatedData {
        attribute aggregationTime : TimeValue;
        attribute readingCount : Integer;
    }

    item def EncryptedData {
        attribute payload : String;
        attribute payloadSize : Integer;
    }

    item def PerformanceMetrics {
        attribute connectedDevices : Integer;
        attribute dataThroughput : Real;
        attribute processingLatency : TimeValue;
    }

    item def Ack {
        attribute success : Boolean;
    }

    item def ConfigCommand {
        attribute command : String;
    }

    port def SensorPort {
        in item sensorData : SensorData;
        out item ack : Ack;
    }

    port def ValidatedDataPort {
        in item data : SensorData;
    }

    port def AggregatedDataPort {
        in item data : AggregatedData;
    }

    port def EncryptedDataPort {
        in item data : EncryptedData;
    }

    port def CloudPort {
        out item encryptedData : EncryptedData;
        in item cloudAck : Ack;
    }

    port def AdminPort {
        out item metrics : PerformanceMetrics;
        in item config : ConfigCommand;
    }

    part def IoTDevice {
        attribute deviceId : String;
        port wirelessOut : ~SensorPort;
    }

    part def TemperatureSensor :> IoTDevice;
    part def MotionDetector :> IoTDevice;
    part def SmartMeter :> IoTDevice;

    action def RegisterDevice {
        in device : IoTDevice;
        out registered : Boolean;
    }

    action def ValidateData {
        in data : SensorData;
        out valid : Boolean;
    }

    action def AggregateData {
        in data : SensorData[0..*];
        out aggregated : AggregatedData;
    }

    action def EncryptData {
        in data : AggregatedData;
        out encrypted : EncryptedData;
    }

    action def TransmitToCloud {
        in data : EncryptedData;
        out ack : Boolean;
    }

    action def StoreData {
        in data : EncryptedData;
    }

    action def FlushBuffer {
        out data : EncryptedData;
    }

    action def CollectMetrics {
        out metrics : PerformanceMetrics;
    }

    part def DeviceManager {
        port sensorIF : ~SensorPort;
        port validatedOut : ~ValidatedDataPort;
        perform action registerDevice : RegisterDevice;
        perform action validateData : ValidateData;
    }

    part def DataAggregator {
        port dataIn : ValidatedDataPort;
        port aggregatedOut : ~AggregatedDataPort;
        attribute aggregationInterval : TimeValue = 60 [s];
        perform action aggregateData : AggregateData;
    }

    part def SecurityModule {
        port dataIn : AggregatedDataPort;
        port encryptedOut : ~EncryptedDataPort;
        perform action encryptData : EncryptData;
    }

    part def LocalStorage {
        port dataIn : EncryptedDataPort;
        port dataOut : ~EncryptedDataPort;
        attribute bufferSize : Integer = 10000;
        perform action storeData : StoreData;
        perform action flushBuffer : FlushBuffer;
    }

    part def CloudConnector {
        port dataIn : EncryptedDataPort;
        port cloudIF : ~CloudPort;
        perform action transmitToCloud : TransmitToCloud;
    }

    part def SystemMonitor {
        port adminIF : ~AdminPort;
        perform action collectMetrics : CollectMetrics;
    }

    attribute def InitComplete;
    attribute def DataReceived;
    attribute def DataAggregated;
    attribute def TransmissionComplete;
    attribute def CloudConnectionLost;
    attribute def CloudConnectionRestored;
    attribute def MaintenanceRequest;
    attribute def MaintenanceComplete;

    state def GatewayStates {
        entry; then initializing;
        state initializing;
        accept InitComplete then ready;
        state ready;
        accept DataReceived then processing;
        accept CloudConnectionLost then buffering;
        accept MaintenanceRequest then maintenance;
        state processing;
        accept DataAggregated then transmitting;
        accept CloudConnectionLost then buffering;
        accept MaintenanceRequest then maintenance;
        state transmitting;
        accept TransmissionComplete then ready;
        accept CloudConnectionLost then buffering;
        accept MaintenanceRequest then maintenance;
        state buffering;
        accept CloudConnectionRestored then transmitting;
        accept MaintenanceRequest then maintenance;
        state maintenance;
        accept MaintenanceComplete then ready;
    }

    part def IoTGateway {
        attribute maxDevices : Integer = 100;
        attribute wirelessRange : LengthValue = 100 [m];
        attribute supportedProtocols : String = "MQTT, CoAP, Zigbee";

        port wirelessReceiver : SensorPort;
        port cloudLink : ~CloudPort;
        port adminInterface : AdminPort;

        part deviceManager : DeviceManager;
        part dataAggregator : DataAggregator;
        part securityModule : SecurityModule;
        part localStorage : LocalStorage;
        part cloudConnector : CloudConnector;
        part systemMonitor : SystemMonitor;

        connect wirelessReceiver to deviceManager.sensorIF;
        connect deviceManager.validatedOut to dataAggregator.dataIn;
        connect dataAggregator.aggregatedOut to securityModule.dataIn;
        connect securityModule.encryptedOut to cloudConnector.dataIn;
        connect securityModule.encryptedOut to localStorage.dataIn;
        connect localStorage.dataOut to cloudConnector.dataIn;
        connect cloudConnector.cloudIF to cloudLink;
        connect systemMonitor.adminIF to adminInterface;

        exhibit state gatewayStates : GatewayStates;
    }

    requirement def GatewayRequirements {
        subject gateway : IoTGateway;
        requirement ManageDevices {
            doc /* The gateway shall manage up to 100 IoT devices. */
        }
        requirement WirelessCommunication {
            doc /* The gateway shall support MQTT, CoAP, and Zigbee protocols within a 100-meter range. */
        }
        requirement DataAggregation {
            doc /* The gateway shall aggregate sensor data at regular intervals. */
        }
        requirement DataBuffering {
            doc /* The gateway shall buffer data locally when cloud connection is lost and forward when restored. */
        }
        requirement Encryption {
            doc /* All data transmissions shall be encrypted before forwarding to the cloud. */
        }
        requirement PerformanceMonitoring {
            doc /* The gateway shall monitor connected devices, data throughput, and processing latency. */
        }
    }
}
