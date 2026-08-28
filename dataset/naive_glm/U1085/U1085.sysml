package HomeServerSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ============================================================
    // Value Types with Units
    // ============================================================
    value type StorageCapacity :> Real { unit "TB"; }
    value type DataRateMbps :> Real { unit "Mbps"; }
    value type Hours :> Real { unit "h"; }
    value type Days :> Real { unit "day"; }
    value type Percent :> Real { unit "%"; }
    value type Wattage :> Real { unit "W"; }
    value type Cores :> Integer;
    value type Users :> Integer;
    value type Streams :> Integer;

    // ============================================================
    // Enumerations
    // ============================================================
    enum def MediaKind { MUSIC; MOVIE; PHOTO; }
    enum def AuthStatus { SUCCESS; FAILURE; LOCKED; }
    enum def RequestType { FILE_ACCESS; MEDIA_STREAM; BACKUP; ADMIN; }
    enum def RaidLevel { RAID0; RAID1; RAID5; RAID6; RAID10; }
    enum def PowerMode { ACTIVE; IDLE; SUSPEND; }

    // ============================================================
    // Item Types
    // ============================================================
    item def Credential {
        attribute username : String;
        attribute passwordHash : String;
    }

    item def File {
        attribute name : String;
        attribute path : String;
        attribute sizeMB : Real;
        attribute owner : String;
        attribute created : String;
        attribute modified : String;
    }

    item def MediaAsset {
        attribute title : String;
        attribute kind : MediaKind;
        attribute sizeMB : Real;
        attribute durationHrs : Hours;
        attribute codec : String;
    }

    item def MediaStream {
        attribute assetId : String;
        attribute clientIp : String;
        attribute dataRate : DataRateMbps;
    }

    item def BackupItem {
        attribute fileRef : String;
        attribute timestamp : String;
        attribute retentionDays : Days;
    }

    item def NetworkPacket {
        attribute source : String;
        attribute destination : String;
        attribute payloadSizeKB : Real;
    }

    item def UserRequest {
        attribute requestId : String;
        attribute type : RequestType;
        attribute target : String;
        attribute credentials : Credential;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def NetworkPort {
        in item incomingPackets : NetworkPacket;
        out item outgoingPackets : NetworkPacket;
    }

    port def RequestPort {
        in item request : UserRequest;
        out item response : String;
    }

    port def StoragePort {
        in item readRequest : String;
        in item writeRequest : File;
        out item retrievedFile : File;
    }

    port def MediaPort {
        in item streamRequest : MediaAsset;
        out item stream : MediaStream;
    }

    port def AuthPort {
        in item credentials : Credential;
        out item token : String;
        out item status : AuthStatus;
    }

    port def BackupPort {
        in item backupTarget : File;
        out item backupRecord : BackupItem;
    }

    port def PowerPort {
        out attribute power : Wattage;
    }

    // ============================================================
    // Requirement Definitions
    // ============================================================
    requirement def MinCapacityRequirement {
        attribute minCapacity : StorageCapacity;
        doc { The storage subsystem shall provide at least the minimum capacity. }
    }

    requirement def RedundancyRequirement {
        attribute requiredRaidLevel : RaidLevel;
        doc { Storage shall use the specified RAID level for data redundancy protecting against a single drive failure. }
    }

    requirement def UptimeRequirement {
        attribute minUptime : Percent = 99.5;
        doc { The system shall achieve at least the specified uptime annually. }
    }

    requirement def ResponseTimeRequirement {
        attribute maxResponseMs : Real;
        doc { The system shall respond to user requests within the specified time. }
    }

    requirement def MaxStreamsRequirement {
        attribute maxStreams : Streams;
        doc { The media server shall support the specified number of simultaneous streams. }
    }

    requirement def MaxUsersRequirement {
        attribute maxUsers : Users;
        doc { The authentication service shall support up to the specified number of users. }
    }

    requirement def BackupRetentionRequirement {
        attribute retentionDays : Days;
        doc { Backups shall be retained for the specified period before automatic pruning. }
    }

    requirement def CoreCountRequirement {
        attribute minCores : Cores;
        doc { The processing unit shall have at least the specified number of cores. }
    }

    requirement def IdlePowerRequirement {
        attribute maxIdlePower : Wattage;
        doc { The system shall not exceed the specified power consumption when idle. }
    }

    // ============================================================
    // Component Part Definitions
    // ============================================================

    part def ProcessingUnit {
        attribute coreCount : Cores;
        attribute clockGHz : Real;
        attribute maxLoad : Percent;
        attribute active : Boolean = false;

        port requestPort : RequestPort;
        port authOut : ~AuthPort;
        port mediaOut : ~MediaPort;
        port backupOut : ~BackupPort;
        port powerIn : ~PowerPort;

        stateMachine ProcessingBehavior {
            state Idle;
            state Active;
            transition t_idle2active from Idle to Active when requestPort.request.isPresent;
            transition t_active2idle from Active to Idle when !requestPort.request.isPresent;
        }

        action def ProcessRequest {
            in request : UserRequest;
            out response : String;
            doc { Receive, authenticate, route, and respond to a user request. }
            first authenticate;
            then route;
            then respond;
        }

        action def Authenticate {
            doc { Forward credentials to the authentication service for validation. }
        }

        action def Route {
            doc { Dispatch the authorized request to the storage or media subsystem. }
        }

        action def Respond {
            doc { Package and return the result through the network interface. }
        }
    }

    part def StorageSubsystem {
        attribute capacity : StorageCapacity;
        attribute raidLevel : RaidLevel;
        attribute diskCount : Integer;
        attribute usableCapacity : StorageCapacity;
        attribute disksFailed : Integer = 0;

        port storageBus : StoragePort;
        port powerIn : ~PowerPort;

        constraint CapacityConstraint { capacity >= 4.0 [TB]; }
        constraint RedundancyConstraint { raidLevel == RaidLevel::RAID5; }
        constraint DiskCountConstraint { diskCount >= 3; }
        constraint UsableCapacityConstraint { usableCapacity == (diskCount - 1) * (capacity / diskCount); }

        stateMachine StorageHealth {
            state Normal;
            state Degraded;
            state Rebuilding;
            state Failed;
            transition t_degrade from Normal to Degraded when disksFailed == 1;
            transition t_rebuild_start from Degraded to Rebuilding when disksFailed == 0;
            transition t_rebuild_complete from Rebuilding to Normal when rebuildComplete;
            transition t_second_fail from Degraded to Failed when disksFailed == 2;
        }

        action def ReadFile {
            in path : String;
            out file : File;
            doc { Retrieve a file from the RAID array by path. }
        }

        action def WriteFile {
            in file : File;
            doc { Persist a file and update parity. }
        }

        action def RebuildParity {
            doc { Rebuild parity data after disk replacement. }
        }
    }

    part def NetworkInterface {
        attribute ipAddress : String;
        attribute macAddress : String;
        attribute bandwidthMbps : DataRateMbps;
        attribute connected : Boolean;

        port externalPort : NetworkPort;
        port internalPort : ~RequestPort;
        port powerIn : ~PowerPort;

        action def RoutePacket {
            in packet : NetworkPacket;
            out routed : NetworkPacket;
            doc { Route an incoming packet to the appropriate internal service. }
        }

        action def ReceivePacket {
            out packet : NetworkPacket;
            doc { Accept a packet from the external home network. }
        }

        action def SendPacket {
            in packet : NetworkPacket;
            doc { Transmit a packet to the external home network. }
        }

        action def ParseRequest {
            in packet : NetworkPacket;
            out request : UserRequest;
            doc { Deserialize a network packet into a structured user request. }
        }
    }

    part def MediaServerModule {
        attribute maxConcurrentStreams : Streams;
        attribute activeStreams : Streams;
        attribute libraryCount : Integer;

        port mediaPort : MediaPort;
        port storageIn : ~StoragePort;
        port powerIn : ~PowerPort;

        constraint MaxStreamsConstraint { maxConcurrentStreams == 5; }
        constraint ActiveStreamsConstraint { activeStreams <= maxConcurrentStreams; }

        stateMachine StreamingState {
            state Idle;
            state Streaming;
            state Throttled;
            transition t_start from Idle to Streaming when mediaPort.streamRequest.isPresent && activeStreams < maxConcurrentStreams;
            transition t_stop from Streaming to Idle when activeStreams == 0;
            transition t_throttle from Streaming to Throttled when activeStreams >= maxConcurrentStreams;
            transition t_unthrottle from Throttled to Streaming when activeStreams < maxConcurrentStreams;
        }

        action def ServeStream {
            in asset : MediaAsset;
            out stream : MediaStream;
            doc { Stream a media asset to a requesting client device. }
        }

        action def TranscodeAsset {
            in asset : MediaAsset;
            out transcoded : MediaAsset;
            doc { Transcode a media asset for the target client codec. }
        }
    }

    part def BackupManager {
        attribute scheduleHours : Hours;
        attribute retentionDays : Days;
        attribute lastBackup : String;
        attribute backupCount : Integer;

        port backupPort : BackupPort;
        port storageIn : ~StoragePort;
        port powerIn : ~PowerPort;

        constraint RetentionConstraint { retentionDays == 30.0 [day]; }
        constraint ScheduleConstraint { scheduleHours <= 24.0 [h]; }

        stateMachine BackupLifecycle {
            state Idle;
            state Scheduled;
            state Running;
            state Verifying;
            state Pruning;
            transition t_schedule from Idle to Scheduled when backupTimeReached;
            transition t_start_backup from Scheduled to Running when scheduleTriggered;
            transition t_complete from Running to Verifying when backupComplete;
            transition t_verify from Verifying to Pruning when verifyOk;
            transition t_prune from Pruning to Idle when pruningComplete;
        }

        action def PerformBackup {
            in target : File;
            out record : BackupItem;
            doc { Copy a file snapshot into the backup store with a retention timestamp. }
        }

        action def VerifyBackup {
            in record : BackupItem;
            out ok : Boolean;
            doc { Verify backup integrity by checksum comparison. }
        }

        action def PruneOldBackups {
            doc { Delete backups older than the retention period. }
        }
    }

    part def AuthenticationService {
        attribute maxUsers : Users;
        attribute registeredUsers : Users;
        attribute sessionTimeoutMin : Real;

        port authPort : AuthPort;
        port powerIn : ~PowerPort;

        constraint MaxUsersConstraint { maxUsers == 10; }
        constraint RegisteredUsersConstraint { registeredUsers <= maxUsers; }

        stateMachine AuthBehavior {
            state Waiting;
            state Authenticating;
            state Granted;
            state Denied;
            transition t_receive from Waiting to Authenticating when authPort.credentials.isPresent;
            transition t_grant from Authenticating to Granted when credentialsValid;
            transition t_reject from Authenticating to Denied when !credentialsValid;
            transition t_end_session from Granted to Waiting when sessionEnd;
            transition t_reset from Denied to Waiting when reset;
        }

        action def ValidateCredentials {
            in creds : Credential;
            out status : AuthStatus;
            doc { Validate username and password hash against the credential store. }
        }

        action def RegisterUser {
            in creds : Credential;
            doc { Add a new user credential to the store if capacity allows. }
        }

        action def RevokeSession {
            in token : String;
            doc { Invalidate a previously issued authentication token. }
        }
    }

    part def PowerManagement {
        attribute idlePower : Wattage;
        attribute peakPower : Wattage;
        attribute efficiency : Percent;
        attribute currentMode : PowerMode;

        port powerOut : PowerPort;

        stateMachine PowerStates {
            state IdleMode;
            state ActiveMode;
            state EcoMode;
            transition t_wake from IdleMode to ActiveMode when loadDetected;
            transition t_sleep from ActiveMode to IdleMode when !loadDetected;
            transition t_eco from IdleMode to EcoMode when idleForLong;
            transition t_eco_wake from EcoMode to ActiveMode when loadDetected;
        }

        action def RegulateVoltage {
            out voltage : Real;
            doc { Regulate supply voltage to all subsystems. }
        }

        action def MonitorConsumption {
            out draw : Wattage;
            doc { Measure instantaneous power draw for reporting and throttling. }
        }
    }

    // ============================================================
    // Top-Level Home Server System
    // ============================================================
    part def HomeServerSystem {
        attribute name : String = "HomeHub-3000";
        attribute uptimeTarget : Percent = 99.5;
        attribute raidLevel : RaidLevel = RaidLevel::RAID5;

        // External boundary port
        port externalNetwork : NetworkPort;

        // Requirements
        requirement minStorage : MinCapacityRequirement {
            attribute minCapacity = 4.0 [TB];
        }
        requirement redundancy : RedundancyRequirement {
            attribute requiredRaidLevel = RaidLevel::RAID5;
        }
        requirement uptime : UptimeRequirement {
            attribute minUptime = 99.5 [%];
        }
        requirement responseTime : ResponseTimeRequirement {
            attribute maxResponseMs = 2000.0;
        }
        requirement maxStreams1 : MaxStreamsRequirement {
            attribute maxStreams = 5;
        }
        requirement userLimit : MaxUsersRequirement {
            attribute maxUsers = 10;
        }
        requirement backupRetention : BackupRetentionRequirement {
            attribute retentionDays = 30.0 [day];
        }
        requirement coreReq : CoreCountRequirement {
            attribute minCores = 4;
        }
        requirement idlePowerReq : IdlePowerRequirement {
            attribute maxIdlePower = 30.0 [W];
        }

        // Component parts
        part processingUnit : ProcessingUnit {
            attribute coreCount = 4;
            attribute clockGHz = 2.4;
            attribute maxLoad = 100.0 [%];
            satisfy coreReq by coreCount;
        }

        part storage : StorageSubsystem {
            attribute capacity = 6.0 [TB];
            attribute raidLevel = RaidLevel::RAID5;
            attribute diskCount = 4;
            attribute usableCapacity = 4.5 [TB];
            satisfy minStorage by capacity;
            satisfy redundancy by raidLevel;
        }

        part network : NetworkInterface {
            attribute ipAddress = "192.168.1.10";
            attribute macAddress = "00:1A:2B:3C:4D:5E";
            attribute bandwidthMbps = 1000.0;
            attribute connected = true;
        }

        part media : MediaServerModule {
            attribute maxConcurrentStreams = 5;
            attribute activeStreams = 0;
            attribute libraryCount = 1200;
            satisfy maxStreams1 by maxConcurrentStreams;
        }

        part backupMgr : BackupManager {
            attribute scheduleHours = 24.0 [h];
            attribute retentionDays = 30.0 [day];
            attribute lastBackup = "2024-01-15T02:00:00Z";
            attribute backupCount = 30;
            satisfy backupRetention by retentionDays;
        }

        part auth : AuthenticationService {
            attribute maxUsers = 10;
            attribute registeredUsers = 4;
            attribute sessionTimeoutMin = 30.0;
            satisfy userLimit by maxUsers;
        }

        part power : PowerManagement {
            attribute idlePower = 18.0 [W];
            attribute peakPower = 120.0 [W];
            attribute efficiency = 92.0 [%];
            attribute currentMode = PowerMode::IDLE;
            satisfy idlePowerReq by idlePower;
        }

        // Connections
        connection between externalNetwork and network.externalPort;
        connection between network.internalPort and processingUnit.requestPort;
        connection between processingUnit.authOut and auth.authPort;
        connection between processingUnit.mediaOut and media.mediaPort;
        connection between media.storageIn and storage.storageBus;
        connection between backupMgr.storageIn and storage.storageBus;
        connection between processingUnit.backupOut and backupMgr.backupPort;
        connection between power.powerOut and processingUnit.powerIn;
        connection between power.powerOut and storage.powerIn;
        connection between power.powerOut and network.powerIn;
        connection between power.powerOut and media.powerIn;
        connection between power.powerOut and backupMgr.powerIn;
        connection between power.powerOut and auth.powerIn;

        // System-level state machine
        stateMachine SystemOperation {
            state Idle;
            state Authenticating;
            state Serving;
            state Streaming;
            state BackingUp;
            state Fault;
            transition t_recv from Idle to Authenticating when externalNetwork.incomingPackets.isPresent;
            transition t_auth_file from Authenticating to Serving when auth.authPort.status == AuthStatus::SUCCESS;
            transition t_auth_stream from Authenticating to Streaming when auth.authPort.status == AuthStatus::SUCCESS;
            transition t_auth_fail from Authenticating to Idle when auth.authPort.status == AuthStatus::FAILURE;
            transition t_file_done from Serving to Idle when fileDelivered;
            transition t_stream_done from Streaming to Idle when streamEnded;
            transition t_backup_start from Idle to BackingUp when backupScheduleReached;
            transition t_backup_done from BackingUp to Idle when backupComplete;
            transition t_serve_fault from Serving to Fault when storageError;
            transition t_stream_fault from Streaming to Fault when streamError;
            transition t_recover from Fault to Idle when recoveryComplete;
        }

        // Top-level orchestration action
        action def HandleUserRequest {
            in request : UserRequest;
            out response : String;
            doc { Orchestrate authentication, routing, and response delivery for a single user request. }
            first authenticate;
            then authorize;
            then route;
            then respond;
        }

        action def Authenticate {
            doc { Forward credentials to the AuthenticationService and obtain a status. }
        }

        action def Authorize {
            doc { Evaluate authentication status; proceed only on SUCCESS. }
        }

        action def Route {
            doc { Dispatch the request to the storage subsystem for file access or to the media server for streaming. }
        }

        action def Respond {
            doc { Package the result and send it back through the network interface. }
        }
    }
}
