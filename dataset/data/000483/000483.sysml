package 'Orphan Device System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeviceIdentifier {
        attribute deviceID : String;
        attribute deviceType : String;
        attribute serialNumber : String;
        attribute firmwareVersion : String;
    }
    
    attribute def ConnectionStatus {
        attribute isConnected : Boolean;
        attribute lastContactTime : TimeValue;
        attribute signalStrength : Real;
        attribute connectionQuality : Real;
    }
    
    attribute def NetworkAddress {
        attribute ipAddress : String;
        attribute macAddress : String;
        attribute port : Integer;
        attribute subnet : String;
    }
    
    item def DataPacket {
        attribute payload : String;
        attribute timestamp : TimeValue;
        attribute sourceID : String;
        attribute sequenceNumber : Integer;
        attribute priority : Integer;
    }
    
    item def HealthData {
        attribute cpuUsage : Real;
        attribute memoryUsage : Real;
        attribute temperature : TemperatureValue;
        attribute uptime : TimeValue;
    }
    
    port def CommunicationPort {
        out transmittedData : DataPacket;
        in receivedData : DataPacket;
        attribute status : ConnectionStatus;
    }
    
    port def PowerPort {
        in voltage : ISQ::VoltageValue;
        in current : ISQ::ElectricCurrentValue;
        out powerConsumption : ISQ::PowerValue;
    }
    
    port def DiagnosticPort {
        out healthReport : HealthData;
        in diagnosticCommand : String;
    }
    
    part def LocalDataStore {
        attribute storageCapacity : Integer;
        attribute currentUsage : Integer;
        attribute storedPackets : DataPacket[*];
        
        action storePacket {
            in packet : DataPacket;
            out success : Boolean;
        }
        
        action retrievePacket {
            in sequenceNum : Integer;
            out packet : DataPacket;
        }
        
        action clearStorage {
            out cleared : Boolean;
        }
    }
    
    part def ReconnectionController {
        attribute retryInterval : TimeValue;
        attribute maxRetries : Integer;
        attribute currentRetries : Integer;
        attribute backoffMultiplier : Real;
        
        action calculateNextRetry {
            in currentInterval : TimeValue;
            out nextInterval : TimeValue;
        }
        
        action resetRetryCount {
            out reset : Boolean;
        }
    }
    
    part def NetworkInterface {
        attribute networkAddr : NetworkAddress;
        port commPort : CommunicationPort;
        
        action establishConnection {
            in targetAddress : NetworkAddress;
            out connectionEstablished : Boolean;
        }
        
        action sendData {
            in packet : DataPacket;
            out transmitted : Boolean;
        }
        
        action receiveData {
            out packet : DataPacket;
        }
    }
    
    part def PowerManager {
        attribute batteryLevel : Real;
        attribute powerMode : String;
        port powerInput : PowerPort;
        
        action evaluatePowerState {
            in currentLevel : Real;
            out mode : String;
        }
        
        action enterLowPowerMode {
            out success : Boolean;
        }
        
        action enterNormalMode {
            out success : Boolean;
        }
    }
    
    part def DiagnosticMonitor {
        port diagnosticPort : DiagnosticPort;
        
        action collectHealthData {
            out health : HealthData;
        }
        
        action performSelfTest {
            out testPassed : Boolean;
        }
    }
    
    part def OrphanDevice {
        doc /* An orphan device is a network-connected device that has become 
               disconnected from its parent system or controller. It operates 
               autonomously, buffering critical data locally and continuously 
               attempting to reestablish connection while managing power and 
               maintaining operational integrity. */
        
        attribute deviceInfo : DeviceIdentifier;
        attribute connectionState : ConnectionStatus;
        
        port networkPort : CommunicationPort;
        port powerPort : PowerPort;
        port diagnosticPort : DiagnosticPort;
        
        part networkInterface : NetworkInterface;
        
        part dataStore : LocalDataStore {
            attribute storageCapacity = 5000;
            attribute currentUsage = 0;
        }
        
        part reconnectionController : ReconnectionController {
            attribute retryInterval = 30.0 [SI::s];
            attribute maxRetries = 20;
            attribute currentRetries = 0;
            attribute backoffMultiplier = 1.5;
        }
        
        part powerManager : PowerManager {
            attribute batteryLevel = 100.0;
            attribute powerMode = "normal";
        }
        
        part diagnosticMonitor : DiagnosticMonitor;
        
        connect networkInterface.commPort to networkPort;
        connect powerManager.powerInput to powerPort;
        connect diagnosticMonitor.diagnosticPort to diagnosticPort;
        
        perform action operateAsOrphan;
    }
    
    action def MonitorConnectionState {
        in currentStatus : ConnectionStatus;
        out isOrphaned : Boolean;
        out requiresAction : Boolean;
    }
    
    action def BufferCriticalData {
        in dataPacket : DataPacket;
        in storageCapacity : Integer;
        in currentUsage : Integer;
        out bufferSuccess : Boolean;
        out storageUpdated : Integer;
    }
    
    action def AttemptReconnection {
        in networkAddr : NetworkAddress;
        in retryCount : Integer;
        in retryInterval : TimeValue;
        out reconnectionSuccess : Boolean;
        out nextRetryTime : TimeValue;
    }
    
    action def SynchronizeBufferedData {
        in bufferedPackets : DataPacket[*];
        in connectionEstablished : Boolean;
        out syncComplete : Boolean;
        out packetsSent : Integer;
    }
    
    action def ManagePowerState {
        in batteryLevel : Real;
        in operationalMode : String;
        out newPowerMode : String;
        out powerAdjusted : Boolean;
    }
    
    action def PerformDiagnostics {
        out healthData : HealthData;
        out systemHealthy : Boolean;
    }
    
    action operateAsOrphan : OrphanDevice::operateAsOrphan {
        doc /* Primary function: Maintain autonomous operation when disconnected 
               from parent system. Buffer critical operational data locally, 
               continuously attempt reconnection using exponential backoff strategy, 
               manage power consumption based on battery state, perform self-diagnostics, 
               and synchronize all buffered data upon successful reconnection. */
        
        first start;
        then merge continuousOperation;
        
        action monitorConnection : MonitorConnectionState {
            in currentStatus;
            out isOrphaned;
            out requiresAction;
        }
        
        merge continuousOperation;
        then monitorConnection;
        then decide;
            if monitorConnection.isOrphaned then orphanedOperations;
            if not monitorConnection.isOrphaned then connectedOperations;
        
        action orphanedOperations {
            first bufferData : BufferCriticalData {
                in dataPacket;
                in storageCapacity;
                in currentUsage;
                out bufferSuccess;
                out storageUpdated;
            }
            then attemptReconnect : AttemptReconnection {
                in networkAddr;
                in retryCount;
                in retryInterval;
                out reconnectionSuccess;
                out nextRetryTime;
            }
            then decide;
                if attemptReconnect.reconnectionSuccess then synchronizeData;
                if not attemptReconnect.reconnectionSuccess then managePower;
            
            action managePower : ManagePowerState {
                in batteryLevel;
                in operationalMode;
                out newPowerMode;
                out powerAdjusted;
            }
            then performDiagnostics : PerformDiagnostics {
                out healthData;
                out systemHealthy;
            }
            then continuousOperation;
        }
        
        action synchronizeData : SynchronizeBufferedData {
            in bufferedPackets;
            in connectionEstablished;
            out syncComplete;
            out packetsSent;
        }
        then connectedOperations;
        
        action connectedOperations {
            then continuousOperation;
        }
    }
    
    requirement def OrphanDeviceRequirements {
        doc /* Requirements for orphan device autonomous operation and resilience */
        
        requirement <'ORD-REQ-001'> autonomousOperation {
            doc /* The device shall maintain autonomous operation when disconnected 
                   from the parent system for extended periods. */
        }
        
        requirement <'ORD-REQ-002'> dataBufferingCapacity {
            doc /* The device shall buffer critical data locally with minimum 
                   capacity of 5000 packets. */
        }
        
        requirement <'ORD-REQ-003'> reconnectionStrategy {
            doc /* The device shall attempt reconnection at regular intervals 
                   using exponential backoff strategy with initial interval 
                   not exceeding 30 seconds. */
        }
        
        requirement <'ORD-REQ-004'> powerConservation {
            doc /* The device shall enter low power mode when battery level 
                   falls below 20% to extend operational lifetime. */
        }
        
        requirement <'ORD-REQ-005'> dataSynchronization {
            doc /* The device shall synchronize all buffered data upon 
                   successful reconnection without data loss. */
        }
        
        requirement <'ORD-REQ-006'> selfDiagnostics {
            doc /* The device shall perform continuous self-diagnostics and 
                   report health status. */
        }
        
        requirement <'ORD-REQ-007'> reconnectionBackoff {
            doc /* The device shall implement exponential backoff with 
                   multiplier of at least 1.5 to prevent network congestion. */
        }
    }
    
    part orphanDeviceInstance : OrphanDevice {
        doc /* Complete orphan device system instance demonstrating autonomous 
               operation, local data buffering, intelligent reconnection management, 
               power conservation, and self-diagnostics when isolated from parent 
               network infrastructure. */
        
        attribute deviceInfo = DeviceIdentifier {
            deviceID = "ORD-2024-ALPHA-001";
            deviceType = "Autonomous Edge Sensor Node";
            serialNumber = "SN-78945-XR-2024";
            firmwareVersion = "v2.4.1";
        }
        
        attribute connectionState = ConnectionStatus {
            isConnected = false;
            lastContactTime = 0.0 [SI::s];
            signalStrength = 0.0;
            connectionQuality = 0.0;
        }
        
        satisfy OrphanDeviceRequirements::autonomousOperation;
        satisfy OrphanDeviceRequirements::dataBufferingCapacity;
        satisfy OrphanDeviceRequirements::reconnectionStrategy;
        satisfy OrphanDeviceRequirements::powerConservation;
        satisfy OrphanDeviceRequirements::dataSynchronization;
        satisfy OrphanDeviceRequirements::selfDiagnostics;
        satisfy OrphanDeviceRequirements::reconnectionBackoff;
    }
}
