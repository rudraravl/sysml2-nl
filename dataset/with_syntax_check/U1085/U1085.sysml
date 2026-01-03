package 'Home Server System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def NetworkAddress;
    attribute def UserCredentials;
    attribute def MediaMetadata;
    attribute def FileMetadata;
    
    attribute def DataRate {
        attribute value : Real;
        attribute unit : String;
    }
    
    attribute def StorageCapacity {
        attribute capacity : Real;
        attribute unit : String;
    }
    
    attribute def PowerConsumption {
        attribute watts : Real;
    }
    
    item def UserRequest {
        attribute requestType : String;
        attribute userId : String;
        attribute timestamp : Real;
    }
    
    item def DataPacket {
        attribute payload : String;
        attribute size : Real;
    }
    
    item def MediaStream {
        attribute contentId : String;
        attribute bitrate : Real;
        attribute format : String;
    }
    
    item def BackupData {
        attribute sourceFiles : FileMetadata[*];
        attribute backupTimestamp : Real;
        attribute compressionRatio : Real;
    }
    
    port def NetworkPort {
        in item request : UserRequest;
        out item response : DataPacket;
    }
    
    port def StoragePort {
        in item dataWrite : BackupData;
        out item dataRead : BackupData;
    }
    
    port def MediaStreamPort {
        out item stream : MediaStream;
    }
    
    port def PowerPort {
        in item power : PowerConsumption;
    }
    
    part def NetworkInterface {
        port networkPort : NetworkPort;
        attribute ipAddress : NetworkAddress;
        attribute bandwidth : DataRate;
        
        perform action routeTraffic {
            in incomingRequest : UserRequest;
            out outgoingResponse : DataPacket;
        }
    }
    
    part def StorageSubsystem {
        port storagePort : StoragePort;
        attribute totalCapacity : StorageCapacity;
        attribute usedCapacity : StorageCapacity;
        attribute raidLevel : Integer;
        
        perform action writeData {
            in dataIn : BackupData;
            out writeSuccess : Boolean;
        }
        
        perform action readData {
            in requestIn : UserRequest;
            out dataOut : BackupData;
        }
    }
    
    part def MediaServerModule {
        port mediaPort : MediaStreamPort;
        attribute librarySize : StorageCapacity;
        attribute activeStreams : Integer;
        attribute maxConcurrentStreams : Integer;
        
        perform action streamContent {
            in streamRequest : UserRequest;
            out mediaStream : MediaStream;
        }
    }
    
    part def ProcessingUnit {
        attribute coreCount : Integer;
        attribute clockSpeed : Real;
        attribute currentLoad : Real;
        
        perform action processRequest {
            in request : UserRequest;
            out result : DataPacket;
        }
    }
    
    part def BackupManager {
        attribute scheduleInterval : Real;
        attribute lastBackupTime : Real;
        attribute retentionPolicy : Integer;
        
        perform action executeBackup {
            in sourceData : BackupData;
            out backupStatus : Boolean;
        }
    }
    
    part def AuthenticationService {
        attribute activeUsers : Integer;
        attribute maxUsers : Integer;
        
        perform action authenticateUser {
            in credentials : UserCredentials;
            out authenticated : Boolean;
        }
    }
    
    part def PowerManagement {
        port powerPort : PowerPort;
        attribute inputVoltage : Real;
        attribute outputPower : PowerConsumption;
        attribute efficiency : Real;
    }
    
    action def AuthenticateRequest {
        in request : UserRequest;
        out authorized : Boolean;
    }
    
    action def RouteRequest {
        in request : UserRequest;
        in authorized : Boolean;
        out routingDecision : String;
    }
    
    action def HandleFileRequest {
        in request : UserRequest;
        out response : DataPacket;
    }
    
    action def StreamMedia {
        in request : UserRequest;
        out stream : MediaStream;
    }
    
    action def PerformBackup {
        in backupData : BackupData;
        out backupComplete : Boolean;
    }
    
    action def MonitorResources {
        out cpuLoad : Real;
        out memoryUsage : Real;
        out storageUsage : Real;
    }
    
    part def HomeServer {
        doc /* A centralized home server system that provides network-attached storage,
               media streaming, automated backup services, and file sharing capabilities
               for residential users across multiple client devices. */
        
        attribute powerLevel : Real;
        
        part networkInterface : NetworkInterface {
            port :>> networkPort;
        }
        
        part storage : StorageSubsystem {
            port :>> storagePort;
            attribute :>> raidLevel = 5;
        }
        
        part mediaServer : MediaServerModule {
            port :>> mediaPort;
            attribute :>> maxConcurrentStreams = 5;
        }
        
        part processor : ProcessingUnit {
            attribute :>> coreCount = 4;
            attribute :>> clockSpeed = 3.2;
        }
        
        part backupManager : BackupManager {
            attribute :>> retentionPolicy = 30;
        }
        
        part authService : AuthenticationService {
            attribute :>> maxUsers = 10;
        }
        
        part powerMgmt : PowerManagement {
            port :>> powerPort;
            attribute :>> efficiency = 0.88;
        }
        
        connection storageConn connect networkInterface.networkPort to storage.storagePort;
        connection mediaConn connect networkInterface.networkPort to mediaServer.mediaPort;
        connection powerDist connect powerMgmt.powerPort to networkInterface;
        
        perform action provideHomeServerServices {
            doc /* Primary high-level function: Provide centralized data storage, media streaming,
                   automated backup, and file sharing services to residential network clients. */
            
            in userRequests : UserRequest[*];
            out serviceResponses : DataPacket[*];
            out mediaStreams : MediaStream[*];
            out backupStatus : Boolean;
            
            first start;
            then merge serviceLoop;
            
            action authenticate : AuthenticateRequest {
                in request;
                out authorized;
            }
            
            then decide;
                if authenticate.authorized then routeRequest;
                else rejectRequest;
            
            action routeRequest : RouteRequest {
                in request;
                in authorized = authenticate.authorized;
                out routingDecision;
            }
            
            then decide;
                if routeRequest.routingDecision == "file" then handleFile;
                if routeRequest.routingDecision == "media" then streamMedia;
                if routeRequest.routingDecision == "backup" then performBackup;
            
            action handleFile : HandleFileRequest {
                in request;
                out response;
            }
            flow handleFile.response to mergeResponses.fileResponse;
            then mergeResponses;
            
            action streamMedia : StreamMedia {
                in request;
                out stream;
            }
            flow streamMedia.stream to mergeResponses.mediaStream;
            then mergeResponses;
            
            action performBackup : PerformBackup {
                in backupData;
                out backupComplete;
            }
            flow performBackup.backupComplete to mergeResponses.backupResult;
            then mergeResponses;
            
            action rejectRequest;
            then serviceLoop;
            
            merge mergeResponses {
                in fileResponse : DataPacket;
                in mediaStream : MediaStream;
                in backupResult : Boolean;
            }
            
            then action monitorResources : MonitorResources {
                out cpuLoad;
                out memoryUsage;
                out storageUsage;
            }
            
            then serviceLoop;
        }
        
        exhibit state serverStates {
            entry; then idle;
            
            state idle;
            accept requestReceived;
            then active;
            
            state active {
                state servingFiles;
                state streamingMedia;
                state performingBackup;
            }
            if requestComplete then idle;
            
            state maintenance;
            if maintenanceComplete then idle;
            
            state shutdown;
        }
    }
    
    part homeServerInstance : HomeServer {
        attribute serverName : String := "HomeServerPrimary";
        attribute maxConcurrentConnections : Integer := 20;
        attribute operatingTemperature : Real;
    }
    
    requirement def PerformanceRequirement {
        doc /* Performance requirements for home server operations. */
        subject server : HomeServer;
        
        require constraint responseTime {
            doc /* Server shall respond to user requests within 2 seconds under normal load. */
        }
        
        require constraint uptime {
            doc /* Server shall maintain 99.5% uptime over any 30-day period. */
        }
        
        require constraint throughput {
            doc /* Server shall support minimum aggregate throughput of 1 Gbps. */
        }
    }
    
    requirement def StorageRequirement {
        doc /* Storage capacity and reliability requirements. */
        subject storage : StorageSubsystem;
        
        require constraint minimumCapacity {
            doc /* Storage subsystem shall provide at least 4TB of usable capacity. */
        }
        
        require constraint dataProtection {
            doc /* Storage shall implement RAID-5 for data redundancy and protection. */
        }
        
        require constraint backupFrequency {
            doc /* Automated backups shall execute at least once every 24 hours. */
        }
    }
    
    requirement def PowerRequirement {
        doc /* Power consumption and efficiency requirements. */
        subject power : PowerManagement;
        
        require constraint maxPower {
            doc /* Total system power consumption shall not exceed 200W under full load. */
        }
        
        require constraint efficiency {
            doc /* Power supply efficiency shall be at least 85% at typical load. */
        }
        
        require constraint idlePower {
            doc /* Idle power consumption shall not exceed 40W. */
        }
    }
    
    requirement <'SYS-HS-001'> homeServerMissionRequirement {
        doc /* The home server shall provide reliable, centralized services for data storage,
               media streaming, automated backup, and file sharing to support residential
               network users with high availability and performance. */
        
        subject homeServerInstance;
        
        require performanceReq : PerformanceRequirement {
            subject server = homeServerInstance;
        }
        
        require storageReq : StorageRequirement {
            subject storage = homeServerInstance.storage;
        }
        
        require powerReq : PowerRequirement {
            subject power = homeServerInstance.powerMgmt;
        }
    }
}
