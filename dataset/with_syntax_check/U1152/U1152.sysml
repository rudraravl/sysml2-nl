package OpenSourceIoTGateway {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MACAddress;
    attribute def IPAddress;
    attribute def DeviceID;
    attribute def SensorType;
    attribute def ProtocolType;
    
    attribute def DataRate :> Real;
    attribute def PacketCount :> Natural;
    attribute def SignalStrength :> Real;
    attribute def BatteryLevel :> Real;
    attribute def ProcessingLatency :> DurationValue;
    
    item def SensorData {
        attribute deviceId : DeviceID;
        attribute sensorType : SensorType;
        attribute timestamp : DurationValue;
        attribute value : Real;
        attribute unit : String;
    }
    
    item def AggregatedData {
        attribute sourceDevices : DeviceID[1..*];
        attribute dataPoints : SensorData[1..*];
        attribute aggregationTime : DurationValue;
    }
    
    item def CloudMessage {
        attribute payload : AggregatedData;
        attribute messageId : String;
        attribute priority : Natural;
    }
    
    item def DeviceRegistration {
        attribute deviceId : DeviceID;
        attribute protocol : ProtocolType;
        attribute capabilities : SensorType[1..*];
    }
    
    port def SensorNetworkPort {
        in item sensorData : SensorData;
        out item registration : DeviceRegistration;
    }
    
    port def CloudPort {
        out item cloudMessage : CloudMessage;
        in item configuration : String;
    }
    
    port def LocalStoragePort {
        in item dataToStore : SensorData;
        out item retrievedData : SensorData;
    }
    
    port def MonitoringPort {
        out attribute connectedDevices : Natural;
        out attribute dataRate : DataRate;
        out attribute processingLatency : ProcessingLatency;
        out attribute storageUsed : MassValue;
    }
    
    part def IoTGateway;
    part def WirelessReceiver;
    part def DataAggregator;
    part def CloudConnector;
    part def LocalStorage;
    part def DeviceManager;
    part def SecurityModule;
    part def SystemMonitor;
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def ReliabilityRequirement;
    requirement def SecurityRequirement;
    
    package StakeholderRequirements {
        requirement <'REQ-200'> primaryFunction : FunctionalRequirement {
            doc /* The IoT Gateway shall collect sensor data from multiple 
                 * wireless IoT devices using open-source protocols, aggregate 
                 * the data locally, and forward it to cloud services while 
                 * providing local storage and device management capabilities.
                 */
            subject gateway : IoTGateway;
        }
        
        requirement <'REQ-201'> deviceCapacity : PerformanceRequirement {
            doc /* The gateway shall support at least 100 concurrent 
                 * IoT device connections with minimal latency.
                 */
            subject gateway : IoTGateway;
        }
        
        requirement <'REQ-202'> dataReliability : ReliabilityRequirement {
            doc /* The gateway shall ensure no data loss during temporary 
                 * cloud connectivity outages through local buffering.
                 */
            subject gateway : IoTGateway;
        }
        
        requirement <'REQ-203'> openSourceCompliance : FunctionalRequirement {
            doc /* The gateway shall use open-source software stack 
                 * including Linux OS, MQTT broker, and standard protocols.
                 */
            subject gateway : IoTGateway;
        }
    }
    
    package SystemArchitecture {
        part iotGateway : IoTGateway {
            attribute maxDevices : Natural = 100;
            attribute bufferSize : MassValue = 1024[kg];
            attribute maxLatency : ProcessingLatency = 100[s];
            attribute firmwareVersion : String = "OpenGW-2.4.1";
            
            port sensorNetwork : SensorNetworkPort;
            port cloudInterface : CloudPort;
            port monitoring : MonitoringPort;
            
            part receiver : WirelessReceiver {
                attribute supportedProtocols : ProtocolType[3] = ("MQTT", "CoAP", "Zigbee");
                attribute signalRange : LengthValue = 100[m];
                port receiverPort : SensorNetworkPort;
            }
            
            part aggregator : DataAggregator {
                attribute aggregationInterval : DurationValue = 5[s];
                attribute maxBufferSize : Natural = 1000;
                port dataInput : SensorNetworkPort;
                port dataOutput : LocalStoragePort;
            }
            
            part cloudConn : CloudConnector {
                attribute cloudEndpoint : IPAddress;
                attribute retryAttempts : Natural = 3;
                attribute connectionTimeout : DurationValue = 30[s];
                port cloudPort : CloudPort;
                port dataSource : LocalStoragePort;
            }
            
            part storage : LocalStorage {
                attribute capacity : MassValue = 2048[kg];
                attribute usedSpace : MassValue = 512[kg];
                attribute retentionPeriod : DurationValue = 7[s];
                port storagePort : LocalStoragePort;
            }
            
            part deviceMgr : DeviceManager {
                attribute registeredDevices : Natural = 0;
                attribute maxDevices : Natural = 100;
                port managementPort : SensorNetworkPort;
            }
            
            part security : SecurityModule {
                attribute encryptionEnabled : Boolean = true;
                attribute certificateExpiry : DurationValue;
            }
            
            part monitor : SystemMonitor {
                attribute pollingInterval : DurationValue = 2[s];
                port monitorPort : MonitoringPort;
            }
            
            connect receiver.receiverPort to sensorNetwork;
            connect receiver.receiverPort to aggregator.dataInput;
            connect aggregator.dataOutput to storage.storagePort;
            connect storage.storagePort to cloudConn.dataSource;
            connect cloudConn.cloudPort to cloudInterface;
            connect monitor.monitorPort to monitoring;
            connect deviceMgr.managementPort to sensorNetwork;
        }
        
        satisfy StakeholderRequirements::primaryFunction by iotGateway;
        satisfy StakeholderRequirements::deviceCapacity by iotGateway;
        satisfy StakeholderRequirements::dataReliability by iotGateway;
        satisfy StakeholderRequirements::openSourceCompliance by iotGateway;
    }
    
    package SystemRequirements {
        requirement <'REQ-2001'> maxDeviceConnections {
            subject gateway :>> SystemArchitecture::iotGateway;
            assert constraint {
                gateway.maxDevices >= 100
            }
        }
        
        requirement <'REQ-2002'> processingLatency {
            subject gateway :>> SystemArchitecture::iotGateway;
            assert constraint {
                gateway.maxLatency <= 200[s]
            }
        }
        
        requirement <'REQ-2003'> storageCapacity {
            subject storage :>> SystemArchitecture::iotGateway.storage;
            assert constraint {
                storage.capacity >= 1024[kg]
            }
        }
        
        requirement <'REQ-2004'> dataRetention {
            subject storage :>> SystemArchitecture::iotGateway.storage;
            assert constraint {
                storage.retentionPeriod >= 3[s]
            }
        }
        
        requirement <'REQ-2005'> protocolSupport {
            subject receiver :>> SystemArchitecture::iotGateway.receiver;
            assert constraint {
                receiver.supportedProtocols->size >= 2
            }
        }
        
        requirement <'REQ-2006'> securityEnabled {
            subject security :>> SystemArchitecture::iotGateway.security;
            assert constraint {
                security.encryptionEnabled == true
            }
        }
    }
    
    package Behaviors {
        action def ReceiveSensorData {
            in port networkPort : SensorNetworkPort;
            out data : SensorData;
            out deviceId : DeviceID;
        }
        
        action def ValidateData {
            in data : SensorData;
            out isValid : Boolean;
            out validatedData : SensorData;
        }
        
        action def AggregateData {
            in dataStream : SensorData[*];
            in interval : DurationValue;
            out aggregated : AggregatedData;
        }
        
        action def StoreLocally {
            in data : SensorData;
            in port storagePort : LocalStoragePort;
            out stored : Boolean;
        }
        
        action def ForwardToCloud {
            in aggregated : AggregatedData;
            out message : CloudMessage;
            out port cloudPort : CloudPort;
        }
        
        action def RegisterDevice {
            in registration : DeviceRegistration;
            out registered : Boolean;
            out assignedId : DeviceID;
        }
        
        action def MonitorSystem {
            out deviceCount : Natural;
            out dataRate : DataRate;
            out latency : ProcessingLatency;
            out storageUsed : MassValue;
        }
        
        action def ProcessSensorData {
            in port sensorPort : SensorNetworkPort;
            in port storagePort : LocalStoragePort;
            out port cloudPort : CloudPort;
            
            first start;
            then action receive : ReceiveSensorData {
                in port networkPort = sensorPort;
                out incomingData : SensorData;
                out sourceDevice : DeviceID;
            }
            then action validate : ValidateData {
                in data = receive.incomingData;
                out isValid;
                out validatedData;
            }
            then decide;
                if validate.isValid then storeData;
                if not validate.isValid then rejectData;
            
            action storeData : StoreLocally {
                in data = validate.validatedData;
                in port storagePort;
                out stored;
            }
            then done;
            
            action rejectData {
                out errorLog : String;
            }
            then done;
        }
        
        state def GatewayOperationStates {
            entry; then initializing;
            
            state initializing {
                entry assign systemStatus = "Starting";
            }
            then ready;
            
            state ready {
                entry assign systemStatus = "Ready";
            }
            accept at ready
                then receiving
                when DataArrival;
            
            state receiving {
                do action receiveData : ReceiveSensorData;
            }
            then processing;
            
            state processing {
                do action processData : ProcessSensorData;
            }
            then decide;
                if cloudAvailable then transmitting;
                if not cloudAvailable then buffering;
            
            state transmitting {
                do action transmitToCloud : ForwardToCloud;
            }
            then ready;
            
            state buffering {
                entry assign bufferMode = true;
                do action bufferData : StoreLocally;
            }
            then ready;
            
            accept at processing
                then maintenance
                when MaintenanceRequest;
            
            state maintenance {
                entry assign systemStatus = "Maintenance";
            }
            then ready when MaintenanceComplete;
            
            accept at ready
                then shutdown
                when ShutdownSignal;
            
            state shutdown;
        }
    }
    
    package OperationalScenarios {
        action operateGateway {
            first start;
            then action monitor : Behaviors::MonitorSystem {
                out currentDevices : Natural;
                out currentRate : DataRate;
                out currentLatency : ProcessingLatency;
                out currentStorage : MassValue;
            }
            then decide;
                if monitor.currentDevices > 0 then processData;
                if monitor.currentDevices == 0 then waitForDevices;
            
            action processData : Behaviors::ProcessSensorData;
            then done;
            
            action waitForDevices {
                out waitTime : DurationValue = 10[s];
            }
            then done;
        }
        
        action deviceRegistrationScenario {
            first start;
            then action receiveRegistration {
                out newDevice : DeviceRegistration;
            }
            then action register : Behaviors::RegisterDevice {
                in registration = receiveRegistration.newDevice;
                out registered;
                out assignedId;
            }
            then decide;
                if register.registered then confirmRegistration;
                if not register.registered then rejectRegistration;
            
            action confirmRegistration {
                in deviceId = register.assignedId;
                out confirmation : String;
            }
            then done;
            
            action rejectRegistration {
                out reason : String;
            }
            then done;
        }
    }
}
