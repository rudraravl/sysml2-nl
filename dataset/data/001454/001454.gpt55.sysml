package HomeServerPrimaryFunctionModel {
    import ScalarValues::*;

    unit def watt;
    unit def volt;
    unit def ampere;
    unit def terabyte;
    unit def gigabyte;
    unit def megabitPerSecond;
    unit def millisecond;
    unit def percent;
    unit def degreeCelsius;
    unit def hour;
    unit def day;

    attribute def ElectricPower_W :> Real {
        doc "Unit: watt.";
    }

    attribute def ElectricPotential_V :> Real {
        doc "Unit: volt.";
    }

    attribute def ElectricCurrent_A :> Real {
        doc "Unit: ampere.";
    }

    attribute def StorageCapacity_TB :> Real {
        doc "Unit: terabyte.";
    }

    attribute def DataSize_GB :> Real {
        doc "Unit: gigabyte.";
    }

    attribute def DataRate_Mbps :> Real {
        doc "Unit: megabit per second.";
    }

    attribute def Latency_ms :> Real {
        doc "Unit: millisecond.";
    }

    attribute def Availability_percent :> Real {
        doc "Unit: percent.";
    }

    attribute def Temperature_degC :> Real {
        doc "Unit: degree Celsius.";
    }

    attribute def Duration_h :> Real {
        doc "Unit: hour.";
    }

    attribute def Retention_d :> Real {
        doc "Unit: day.";
    }

    enum def ServiceCategory {
        enum fileSharing;
        enum mediaStreaming;
        enum backup;
        enum homeAutomation;
        enum remoteAccess;
        enum monitoring;
        enum administration;
    }

    enum def RequestPriority {
        enum low;
        enum normal;
        enum high;
        enum emergency;
    }

    enum def SecurityDecision {
        enum permitted;
        enum denied;
        enum quarantined;
    }

    enum def HealthState {
        enum nominal;
        enum degraded;
        enum critical;
        enum maintenanceRequired;
    }

    item def EthernetFrame {
        attribute sourceMac: String;
        attribute destinationMac: String;
        attribute payloadSize: DataSize_GB;
        attribute vlanId: Integer;
    }

    item def IPPacket {
        attribute sourceAddress: String;
        attribute destinationAddress: String;
        attribute protocol: String;
        attribute payloadSize: DataSize_GB;
    }

    item def ClientRequest {
        attribute requesterId: String;
        attribute category: ServiceCategory;
        attribute priority: RequestPriority;
        attribute requestedObject: String;
        attribute encrypted: Boolean;
        attribute requestSize: DataSize_GB;
    }

    item def ServerResponse {
        attribute responderId: String;
        attribute category: ServiceCategory;
        attribute decision: SecurityDecision;
        attribute responseCode: Integer;
        attribute encrypted: Boolean;
        attribute responseSize: DataSize_GB;
    }

    item def MediaStream {
        attribute title: String;
        attribute bitrate: DataRate_Mbps;
        attribute resolution: String;
        attribute encrypted: Boolean;
    }

    item def BackupDataSet {
        attribute sourceDeviceId: String;
        attribute backupSize: DataSize_GB;
        attribute incremental: Boolean;
        attribute retentionPeriod: Retention_d;
    }

    item def RestoreImage {
        attribute targetDeviceId: String;
        attribute imageSize: DataSize_GB;
        attribute verified: Boolean;
    }

    item def HomeAutomationEvent {
        attribute deviceId: String;
        attribute eventName: String;
        attribute eventPriority: RequestPriority;
        attribute payloadSize: DataSize_GB;
    }

    item def HomeAutomationCommand {
        attribute targetDeviceId: String;
        attribute commandName: String;
        attribute safetyCritical: Boolean;
    }

    item def ManagementCommand {
        attribute administratorId: String;
        attribute commandName: String;
        attribute requiresPrivilege: Boolean;
    }

    item def HealthReport {
        attribute reportingComponent: String;
        attribute state: HealthState;
        attribute temperature: Temperature_degC;
        attribute powerDraw: ElectricPower_W;
        attribute freeStorage: StorageCapacity_TB;
    }

    item def AuditRecord {
        attribute timestampUtc: String;
        attribute actorId: String;
        attribute activity: String;
        attribute permitted: Boolean;
    }

    item def AuthToken {
        attribute subjectId: String;
        attribute issuer: String;
        attribute expirationUtc: String;
        attribute multiFactorAuthenticated: Boolean;
    }

    item def StorageBlock {
        attribute logicalPath: String;
        attribute blockSize: DataSize_GB;
        attribute checksumSha256: String;
        attribute encryptedAtRest: Boolean;
    }

    item def StorageControlMessage {
        attribute operation: String;
        attribute volumeId: String;
        attribute requestedSize: DataSize_GB;
    }

    item def ACPower {
        attribute voltage: ElectricPotential_V;
        attribute current: ElectricCurrent_A;
        attribute power: ElectricPower_W;
        attribute frequencyHz: Real;
    }

    item def DCPower {
        attribute voltage: ElectricPotential_V;
        attribute current: ElectricCurrent_A;
        attribute power: ElectricPower_W;
    }

    item def ThermalEnergyFlow {
        attribute heatLoad: ElectricPower_W;
        attribute exhaustTemperature: Temperature_degC;
    }

    port def NetworkPort {
        inout item frame: EthernetFrame;
        inout item packet: IPPacket;
    }

    port def ServicePort {
        in item request: ClientRequest;
        out item response: ServerResponse;
        out item media: MediaStream;
    }

    port def BackupPort {
        in item backupSet: BackupDataSet;
        out item restoreImage: RestoreImage;
        out item response: ServerResponse;
    }

    port def AutomationPort {
        in item event: HomeAutomationEvent;
        out item command: HomeAutomationCommand;
    }

    port def ManagementPort {
        in item command: ManagementCommand;
        in item token: AuthToken;
        out item report: HealthReport;
        out item audit: AuditRecord;
    }

    port def StoragePort {
        inout item block: StorageBlock;
        inout item control: StorageControlMessage;
    }

    port def HealthPort {
        out item report: HealthReport;
        out item audit: AuditRecord;
    }

    port def ACPowerInPort {
        in item power: ACPower;
    }

    port def ACPowerOutPort {
        out item power: ACPower;
    }

    port def DCPowerOutPort {
        out item power: DCPower;
    }

    port def DCPowerInPort {
        in item power: DCPower;
    }

    port def ThermalPort {
        inout item heat: ThermalEnergyFlow;
    }

    part def SolidStateDisk {
        attribute usableCapacity: StorageCapacity_TB;
        attribute sustainedReadRate: DataRate_Mbps;
        attribute sustainedWriteRate: DataRate_Mbps;
        attribute operatingTemperature: Temperature_degC;
        attribute powerDrawNominal: ElectricPower_W;
        attribute encrypted: Boolean;

        port storage: StoragePort;
        port dcPower: DCPowerInPort;
        port health: HealthPort;
        port thermal: ThermalPort;
    }

    part def StorageArray {
        attribute usableCapacity: StorageCapacity_TB = 24.0;
        attribute rawCapacity: StorageCapacity_TB = 36.0;
        attribute reservedForParity: StorageCapacity_TB = 12.0;
        attribute minimumFreeCapacity: StorageCapacity_TB = 2.0;
        attribute raidLevel: String = "RAID-Z2";
        attribute encryptedAtRest: Boolean = true;

        part disk1: SolidStateDisk {
            attribute usableCapacity = 6.0;
            attribute sustainedReadRate = 4500.0;
            attribute sustainedWriteRate = 3600.0;
            attribute operatingTemperature = 38.0;
            attribute powerDrawNominal = 6.0;
            attribute encrypted = true;
        }

        part disk2: SolidStateDisk {
            attribute usableCapacity = 6.0;
            attribute sustainedReadRate = 4500.0;
            attribute sustainedWriteRate = 3600.0;
            attribute operatingTemperature = 38.0;
            attribute powerDrawNominal = 6.0;
            attribute encrypted = true;
        }

        part disk3: SolidStateDisk {
            attribute usableCapacity = 6.0;
            attribute sustainedReadRate = 4500.0;
            attribute sustainedWriteRate = 3600.0;
            attribute operatingTemperature = 38.0;
            attribute powerDrawNominal = 6.0;
            attribute encrypted = true;
        }

        part disk4: SolidStateDisk {
            attribute usableCapacity = 6.0;
            attribute sustainedReadRate = 4500.0;
            attribute sustainedWriteRate = 3600.0;
            attribute operatingTemperature = 38.0;
            attribute powerDrawNominal = 6.0;
            attribute encrypted = true;
        }

        part disk5: SolidStateDisk {
            attribute usableCapacity = 6.0;
            attribute sustainedReadRate = 4500.0;
            attribute sustainedWriteRate = 3600.0;
            attribute operatingTemperature = 38.0;
            attribute powerDrawNominal = 6.0;
            attribute encrypted = true;
        }

        part disk6: SolidStateDisk {
            attribute usableCapacity = 6.0;
            attribute sustainedReadRate = 4500.0;
            attribute sustainedWriteRate = 3600.0;
            attribute operatingTemperature = 38.0;
            attribute powerDrawNominal = 6.0;
            attribute encrypted = true;
        }

        port data: StoragePort;
        port dcPower: DCPowerInPort;
        port health: HealthPort;
        port thermal: ThermalPort;

        connect data to disk1.storage;
        connect data to disk2.storage;
        connect data to disk3.storage;
        connect data to disk4.storage;
        connect data to disk5.storage;
        connect data to disk6.storage;
        connect dcPower to disk1.dcPower;
        connect dcPower to disk2.dcPower;
        connect dcPower to disk3.dcPower;
        connect dcPower to disk4.dcPower;
        connect dcPower to disk5.dcPower;
        connect dcPower to disk6.dcPower;
        connect disk1.health to health;
        connect disk2.health to health;
        connect disk3.health to health;
        connect disk4.health to health;
        connect disk5.health to health;
        connect disk6.health to health;
        connect disk1.thermal to thermal;
        connect disk2.thermal to thermal;
        connect disk3.thermal to thermal;
        connect disk4.thermal to thermal;
        connect disk5.thermal to thermal;
        connect disk6.thermal to thermal;
    }

    part def ComputeModule {
        attribute processorCores: Integer = 12;
        attribute memoryCapacity: DataSize_GB = 64.0;
        attribute virtualizationEnabled: Boolean = true;
        attribute nominalPower: ElectricPower_W = 85.0;
        attribute peakPower: ElectricPower_W = 140.0;

        port network: NetworkPort;
        port services: ServicePort;
        port storage: StoragePort;
        port automation: AutomationPort;
        port management: ManagementPort;
        port backup: BackupPort;
        port dcPower: DCPowerInPort;
        port health: HealthPort;
        port thermal: ThermalPort;
    }

    part def NetworkInterface {
        attribute lineRate: DataRate_Mbps = 2500.0;
        attribute supportsWakeOnLan: Boolean = true;
        attribute supportsVlan: Boolean = true;

        port externalLan: NetworkPort;
        port internalLan: NetworkPort;
        port dcPower: DCPowerInPort;
        port health: HealthPort;
    }

    part def SecurityGatewayService {
        attribute firewallEnabled: Boolean = true;
        attribute intrusionDetectionEnabled: Boolean = true;
        attribute remoteAccessVpnEnabled: Boolean = true;
        attribute maximumVpnThroughput: DataRate_Mbps = 500.0;

        port lan: NetworkPort;
        port service: ServicePort;
        port management: ManagementPort;
        port health: HealthPort;
    }

    part def FileService {
        attribute smbEnabled: Boolean = true;
        attribute nfsEnabled: Boolean = true;
        attribute webDavEnabled: Boolean = true;
        attribute defaultQuotaPerUser: DataSize_GB = 500.0;
        attribute maximumConcurrentSessions: Integer = 64;

        port service: ServicePort;
        port storage: StoragePort;
        port management: ManagementPort;
        port health: HealthPort;
    }

    part def MediaService {
        attribute libraryCapacity: StorageCapacity_TB = 10.0;
        attribute maximumConcurrentStreams: Integer = 8;
        attribute maximumStreamBitrate: DataRate_Mbps = 80.0;
        attribute hardwareTranscodingEnabled: Boolean = true;

        port service: ServicePort;
        port storage: StoragePort;
        port management: ManagementPort;
        port health: HealthPort;
    }

    part def BackupService {
        attribute dailyBackupWindow: Duration_h = 6.0;
        attribute minimumRetention: Retention_d = 90.0;
        attribute supportsIncrementalBackup: Boolean = true;
        attribute supportsBareMetalRestore: Boolean = true;

        port backup: BackupPort;
        port storage: StoragePort;
        port management: ManagementPort;
        port health: HealthPort;
    }

    part def HomeAutomationBroker {
        attribute supportedDeviceCount: Integer = 128;
        attribute localProcessingEnabled: Boolean = true;
        attribute cloudDependencyRequired: Boolean = false;
        attribute maximumCommandLatency: Latency_ms = 150.0;

        port automation: AutomationPort;
        port service: ServicePort;
        port management: ManagementPort;
        port health: HealthPort;
    }

    part def MonitoringService {
        attribute samplingPeriod: Duration_h = 0.017;
        attribute alertingEnabled: Boolean = true;
        attribute criticalDiskTemperature: Temperature_degC = 70.0;
        attribute criticalCpuTemperature: Temperature_degC = 90.0;
        attribute minimumAvailabilityTarget: Availability_percent = 99.5;

        port healthIn: HealthPort;
        port management: ManagementPort;
        port service: ServicePort;
    }

    part def PowerSupply {
        attribute inputVoltageNominal: ElectricPotential_V = 120.0;
        attribute outputVoltageNominal: ElectricPotential_V = 12.0;
        attribute maximumOutputPower: ElectricPower_W = 450.0;
        attribute efficiencyAtHalfLoad: Availability_percent = 92.0;

        port acInput: ACPowerInPort;
        port dcOutput: DCPowerOutPort;
        port health: HealthPort;
        port thermal: ThermalPort;
    }

    part def CoolingAssembly {
        attribute fanCount: Integer = 3;
        attribute maximumHeatRemoval: ElectricPower_W = 300.0;
        attribute nominalAcousticLevelDbA: Real = 28.0;
        attribute targetInternalTemperature: Temperature_degC = 45.0;

        port heatIn: ThermalPort;
        port heatOut: ThermalPort;
        port dcPower: DCPowerInPort;
        port health: HealthPort;
    }

    part def HomeServer {
        doc "Primary high-level function: provide a secure, always-available local digital hub for the household by centralizing file storage, automated backups, media streaming, home automation coordination, remote access, and operational monitoring over the home network.";

        attribute systemName: String = "Home Digital Hub";
        attribute supportsSecureFileStorage: Boolean = true;
        attribute supportsHouseholdBackup: Boolean = true;
        attribute supportsMediaStreaming: Boolean = true;
        attribute supportsHomeAutomation: Boolean = true;
        attribute supportsRemoteAccess: Boolean = true;
        attribute targetAvailability: Availability_percent = 99.5;
        attribute maximumNormalPowerDraw: ElectricPower_W = 220.0;
        attribute maximumServiceLatency: Latency_ms = 250.0;

        part compute: ComputeModule;
        part storage: StorageArray;
        part networkInterface: NetworkInterface;
        part securityGateway: SecurityGatewayService;
        part fileService: FileService;
        part mediaService: MediaService;
        part backupService: BackupService;
        part automationBroker: HomeAutomationBroker;
        part monitoring: MonitoringService;
        part powerSupply: PowerSupply;
        part cooling: CoolingAssembly;

        port acPowerIn: ACPowerInPort;
        port lan: NetworkPort;
        port serviceAccess: ServicePort;
        port backupAccess: BackupPort;
        port automationAccess: AutomationPort;
        port administration: ManagementPort;
        port thermalExhaust: ThermalPort;

        connect acPowerIn to powerSupply.acInput;
        connect powerSupply.dcOutput to compute.dcPower;
        connect powerSupply.dcOutput to storage.dcPower;
        connect powerSupply.dcOutput to networkInterface.dcPower;
        connect powerSupply.dcOutput to cooling.dcPower;

        connect lan to networkInterface.externalLan;
        connect networkInterface.internalLan to compute.network;
        connect compute.network to securityGateway.lan;
        connect securityGateway.service to serviceAccess;

        connect compute.storage to storage.data;
        connect fileService.storage to storage.data;
        connect mediaService.storage to storage.data;
        connect backupService.storage to storage.data;

        connect compute.services to fileService.service;
        connect compute.services to mediaService.service;
        connect compute.services to securityGateway.service;
        connect compute.backup to backupService.backup;
        connect compute.automation to automationBroker.automation;

        connect serviceAccess to fileService.service;
        connect serviceAccess to mediaService.service;
        connect serviceAccess to automationBroker.service;
        connect backupAccess to backupService.backup;
        connect automationAccess to automationBroker.automation;

        connect administration to compute.management;
        connect administration to securityGateway.management;
        connect administration to fileService.management;
        connect administration to mediaService.management;
        connect administration to backupService.management;
        connect administration to automationBroker.management;
        connect administration to monitoring.management;

        connect compute.health to monitoring.healthIn;
        connect storage.health to monitoring.healthIn;
        connect networkInterface.health to monitoring.healthIn;
        connect powerSupply.health to monitoring.healthIn;
        connect cooling.health to monitoring.healthIn;
        connect securityGateway.health to monitoring.healthIn;
        connect fileService.health to monitoring.healthIn;
        connect mediaService.health to monitoring.healthIn;
        connect backupService.health to monitoring.healthIn;
        connect automationBroker.health to monitoring.healthIn;

        connect compute.thermal to cooling.heatIn;
        connect storage.thermal to cooling.heatIn;
        connect powerSupply.thermal to cooling.heatIn;
        connect cooling.heatOut to thermalExhaust;

        action primaryFunction: ProvideHomeDigitalServices;
        state lifecycle: HomeServerLifecycle;
    }

    part def InternetGateway {
        attribute wanBandwidth: DataRate_Mbps = 1000.0;
        attribute lanBandwidth: DataRate_Mbps = 2500.0;
        attribute firewallEnabled: Boolean = true;

        port lan: NetworkPort;
        port wan: NetworkPort;
        port management: ManagementPort;
    }

    part def UserEndpoint {
        attribute deviceName: String;
        attribute ownerId: String;
        attribute wirelessCapable: Boolean;
        attribute typicalBackupSize: DataSize_GB;

        port network: NetworkPort;
        port services: ServicePort;
        port backup: BackupPort;
        port management: ManagementPort;
    }

    part def SmartHomeDevice {
        attribute deviceName: String;
        attribute deviceType: String;
        attribute safetyCritical: Boolean;
        attribute batteryPowered: Boolean;

        port network: NetworkPort;
        port automation: AutomationPort;
    }

    part def UninterruptiblePowerSupply {
        attribute batteryRuntimeAtServerLoad: Duration_h = 1.5;
        attribute maximumOutputPower: ElectricPower_W = 600.0;
        attribute outputVoltage: ElectricPotential_V = 120.0;

        port acInput: ACPowerInPort;
        port acOutput: ACPowerOutPort;
        port management: ManagementPort;
    }

    part def CloudBackupEndpoint {
        attribute providerName: String = "Encrypted Offsite Backup";
        attribute contractedCapacity: StorageCapacity_TB = 12.0;
        attribute uplinkLimit: DataRate_Mbps = 100.0;
        attribute encryptedBeforeUpload: Boolean = true;

        port network: NetworkPort;
        port backup: BackupPort;
    }

    part def HomeServerInstallation {
        doc "Household deployment context for the home server system.";

        part homeServer: HomeServer;
        part internetGateway: InternetGateway;
        part ups: UninterruptiblePowerSupply;
        part cloudBackup: CloudBackupEndpoint;

        part familyLaptop: UserEndpoint {
            attribute deviceName = "Family Laptop";
            attribute ownerId = "family";
            attribute wirelessCapable = true;
            attribute typicalBackupSize = 250.0;
        }

        part parentWorkstation: UserEndpoint {
            attribute deviceName = "Parent Workstation";
            attribute ownerId = "parent";
            attribute wirelessCapable = false;
            attribute typicalBackupSize = 500.0;
        }

        part livingRoomTv: UserEndpoint {
            attribute deviceName = "Living Room TV";
            attribute ownerId = "family";
            attribute wirelessCapable = true;
            attribute typicalBackupSize = 0.0;
        }

        part tablet: UserEndpoint {
            attribute deviceName = "Kitchen Tablet";
            attribute ownerId = "family";
            attribute wirelessCapable = true;
            attribute typicalBackupSize = 64.0;
        }

        part thermostat: SmartHomeDevice {
            attribute deviceName = "Main Thermostat";
            attribute deviceType = "climate";
            attribute safetyCritical = true;
            attribute batteryPowered = true;
        }

        part doorLock: SmartHomeDevice {
            attribute deviceName = "Front Door Lock";
            attribute deviceType = "accessControl";
            attribute safetyCritical = true;
            attribute batteryPowered = true;
        }

        part lightingBridge: SmartHomeDevice {
            attribute deviceName = "Lighting Bridge";
            attribute deviceType = "lighting";
            attribute safetyCritical = false;
            attribute batteryPowered = false;
        }

        port utilityPower: ACPowerInPort;
        port internetWan: NetworkPort;

        connect utilityPower to ups.acInput;
        connect ups.acOutput to homeServer.acPowerIn;
        connect internetWan to internetGateway.wan;
        connect internetGateway.lan to homeServer.lan;

        connect familyLaptop.network to internetGateway.lan;
        connect parentWorkstation.network to internetGateway.lan;
        connect livingRoomTv.network to internetGateway.lan;
        connect tablet.network to internetGateway.lan;
        connect thermostat.network to internetGateway.lan;
        connect doorLock.network to internetGateway.lan;
        connect lightingBridge.network to internetGateway.lan;

        connect familyLaptop.services to homeServer.serviceAccess;
        connect parentWorkstation.services to homeServer.serviceAccess;
        connect livingRoomTv.services to homeServer.serviceAccess;
        connect tablet.services to homeServer.serviceAccess;

        connect familyLaptop.backup to homeServer.backupAccess;
        connect parentWorkstation.backup to homeServer.backupAccess;
        connect tablet.backup to homeServer.backupAccess;

        connect thermostat.automation to homeServer.automationAccess;
        connect doorLock.automation to homeServer.automationAccess;
        connect lightingBridge.automation to homeServer.automationAccess;

        connect homeServer.backupAccess to cloudBackup.backup;
        connect cloudBackup.network to internetGateway.lan;
    }

    action def ClassifyInboundTraffic {
        in item inboundFrame: EthernetFrame;
        in item inboundPacket: IPPacket;
        out item request: ClientRequest;
    }

    action def AuthenticateSession {
        in item request: ClientRequest;
        in item token: AuthToken;
        out item authenticatedRequest: ClientRequest;
        out item audit: AuditRecord;
    }

    action def AuthorizeServiceUse {
        in item authenticatedRequest: ClientRequest;
        out item permittedRequest: ClientRequest;
        out item deniedResponse: ServerResponse;
    }

    action def ExecuteStorageService {
        in item request: ClientRequest;
        inout item block: StorageBlock;
        out item response: ServerResponse;
    }

    action def ExecuteMediaService {
        in item request: ClientRequest;
        inout item mediaBlock: StorageBlock;
        out item stream: MediaStream;
        out item response: ServerResponse;
    }

    action def ExecuteBackupService {
        in item backupSet: BackupDataSet;
        inout item backupBlock: StorageBlock;
        out item restoreImage: RestoreImage;
        out item response: ServerResponse;
    }

    action def ExecuteAutomationService {
        in item event: HomeAutomationEvent;
        in item request: ClientRequest;
        out item command: HomeAutomationCommand;
        out item response: ServerResponse;
    }

    action def MonitorHealth {
        in item componentReport: HealthReport;
        out item consolidatedReport: HealthReport;
        out item audit: AuditRecord;
    }

    action def PublishResponse {
        in item response: ServerResponse;
        in item media: MediaStream;
        out item outboundFrame: EthernetFrame;
    }

    action def ProvideHomeDigitalServices {
        doc "Top-level behavior that realizes the primary function of the home server: receive household network requests, authenticate and authorize users, execute local services, protect data, and return secure responses.";

        in item inboundFrame: EthernetFrame;
        in item inboundPacket: IPPacket;
        in item userToken: AuthToken;
        in item backupSet: BackupDataSet;
        in item automationEvent: HomeAutomationEvent;
        in item healthInput: HealthReport;

        out item outboundFrame: EthernetFrame;
        out item fileResponse: ServerResponse;
        out item mediaStream: MediaStream;
        out item backupRestoreImage: RestoreImage;
        out item automationCommand: HomeAutomationCommand;
        out item healthOutput: HealthReport;
        out item auditOutput: AuditRecord;

        action classify: ClassifyInboundTraffic;
        action authenticate: AuthenticateSession;
        action authorize: AuthorizeServiceUse;
        action storage: ExecuteStorageService;
        action media: ExecuteMediaService;
        action backup: ExecuteBackupService;
        action automation: ExecuteAutomationService;
        action monitor: MonitorHealth;
        action publish: PublishResponse;

        flow inboundFrame to classify.inboundFrame;
        flow inboundPacket to classify.inboundPacket;
        flow classify.request to authenticate.request;
        flow userToken to authenticate.token;
        flow authenticate.authenticatedRequest to authorize.authenticatedRequest;
        flow authorize.permittedRequest to storage.request;
        flow authorize.permittedRequest to media.request;
        flow authorize.permittedRequest to automation.request;
        flow backupSet to backup.backupSet;
        flow automationEvent to automation.event;
        flow healthInput to monitor.componentReport;
        flow storage.response to fileResponse;
        flow media.stream to mediaStream;
        flow backup.restoreImage to backupRestoreImage;
        flow automation.command to automationCommand;
        flow monitor.consolidatedReport to healthOutput;
        flow authenticate.audit to auditOutput;
        flow storage.response to publish.response;
        flow media.stream to publish.media;
        flow publish.outboundFrame to outboundFrame;
    }

    action def InitializeServer {
        out item report: HealthReport;
    }

    action def MountEncryptedStorage {
        in item command: ManagementCommand;
        out item report: HealthReport;
    }

    action def StartCoreServices {
        out item response: ServerResponse;
    }

    action def DegradeNonCriticalServices {
        out item report: HealthReport;
    }

    action def PerformGracefulShutdown {
        out item audit: AuditRecord;
    }

    item def PowerOnCommand {
        attribute source: String;
    }

    item def ShutdownCommand {
        attribute source: String;
        attribute graceful: Boolean;
    }

    item def MaintenanceCommand {
        attribute source: String;
        attribute approved: Boolean;
    }

    item def FaultDetected {
        attribute component: String;
        attribute severity: HealthState;
    }

    item def FaultCleared {
        attribute component: String;
    }

    state def HomeServerLifecycle {
        doc "Operational states for the home server from power-off through normal service, degraded operation, maintenance, and shutdown.";

        entry; then Off;

        state Off {
            doc "No household digital services are available; persistent data remains stored on nonvolatile encrypted media.";
        }

        state Booting {
            entry action initialize: InitializeServer;
            do action mountStorage: MountEncryptedStorage;
            exit action startServices: StartCoreServices;
        }

        state Operational {
            entry action startServices: StartCoreServices;

            state Idle {
                doc "Server is powered and ready, with no active user service transaction.";
            }

            state ServingFiles {
                do action serveFiles: ExecuteStorageService;
            }

            state StreamingMedia {
                do action streamMedia: ExecuteMediaService;
            }

            state RunningBackup {
                do action runBackup: ExecuteBackupService;
            }

            state CoordinatingAutomation {
                do action coordinateHome: ExecuteAutomationService;
            }

            state Monitoring {
                do action observe: MonitorHealth;
            }

            transition idle_to_file_service first Idle accept ClientRequest then ServingFiles;
            transition idle_to_media_service first Idle accept ClientRequest then StreamingMedia;
            transition idle_to_backup first Idle accept BackupDataSet then RunningBackup;
            transition idle_to_automation first Idle accept HomeAutomationEvent then CoordinatingAutomation;
            transition service_complete_to_idle first ServingFiles then Idle;
            transition stream_complete_to_idle first StreamingMedia then Idle;
            transition backup_complete_to_idle first RunningBackup then Idle;
            transition automation_complete_to_idle first CoordinatingAutomation then Idle;
            transition monitor_cycle first Idle then Monitoring;
            transition monitor_complete first Monitoring then Idle;
        }

        state Degraded {
            entry action degrade: DegradeNonCriticalServices;
            do action monitor: MonitorHealth;
        }

        state Maintenance {
            do action monitor: MonitorHealth;
        }

        state ShuttingDown {
            entry action shutdown: PerformGracefulShutdown;
        }

        transition power_on first Off accept PowerOnCommand then Booting;
        transition boot_complete first Booting then Operational;
        transition fault_detected first Operational accept FaultDetected then Degraded;
        transition fault_cleared first Degraded accept FaultCleared then Operational;
        transition maintenance_requested first Operational accept MaintenanceCommand then Maintenance;
        transition maintenance_complete first Maintenance then Operational;
        transition shutdown_from_operational first Operational accept ShutdownCommand then ShuttingDown;
        transition shutdown_from_degraded first Degraded accept ShutdownCommand then ShuttingDown;
        transition shutdown_complete first ShuttingDown then Off;
    }

    constraint def MinimumUsableStorageConstraint {
        in usableStorage: StorageCapacity_TB;
        in requiredStorage: StorageCapacity_TB;
        assert usableStorage >= requiredStorage;
    }

    constraint def MaximumLatencyConstraint {
        in observedLatency: Latency_ms;
        in maximumAllowedLatency: Latency_ms;
        assert observedLatency <= maximumAllowedLatency;
    }

    constraint def AvailabilityConstraint {
        in achievedAvailability: Availability_percent;
        in requiredAvailability: Availability_percent;
        assert achievedAvailability >= requiredAvailability;
    }

    constraint def PowerConstraint {
        in normalPower: ElectricPower_W;
        in maximumAllowedPower: ElectricPower_W;
        assert normalPower <= maximumAllowedPower;
    }

    requirement def PrimaryFunctionRequirement {
        doc "The home server shall act as the central secure digital hub for the household by providing local file storage, automated backup, media streaming, home automation coordination, secure remote access, and monitoring through the home network.";
        subject hs: HomeServer;

        require constraint {
            hs.supportsSecureFileStorage == true and
            hs.supportsHouseholdBackup == true and
            hs.supportsMediaStreaming == true and
            hs.supportsHomeAutomation == true and
            hs.supportsRemoteAccess == true
        }
    }

    requirement def StorageRequirement {
        doc "The home server shall provide at least 12 TB of usable fault-tolerant encrypted storage for household data.";
        subject hs: HomeServer;

        require storageCapacity: MinimumUsableStorageConstraint {
            in usableStorage = hs.storage.usableCapacity;
            in requiredStorage = 12.0;
        }
    }

    requirement def AvailabilityRequirement {
        doc "The home server shall target at least 99.5 percent household service availability during normal utility and network conditions.";
        subject hs: HomeServer;

        require availability: AvailabilityConstraint {
            in achievedAvailability = hs.targetAvailability;
            in requiredAvailability = 99.5;
        }
    }

    requirement def LatencyRequirement {
        doc "The home server shall respond to normal local service requests within 250 milliseconds excluding large media or backup data transfer time.";
        subject hs: HomeServer;

        require latency: MaximumLatencyConstraint {
            in observedLatency = hs.maximumServiceLatency;
            in maximumAllowedLatency = 250.0;
        }
    }

    requirement def PowerRequirement {
        doc "The home server shall not exceed 220 W during normal combined file, backup, media, and automation service operation.";
        subject hs: HomeServer;

        require power: PowerConstraint {
            in normalPower = hs.maximumNormalPowerDraw;
            in maximumAllowedPower = 220.0;
        }
    }

    requirement def SecurityRequirement {
        doc "The home server shall encrypt stored household data, require authenticated access, and produce audit records for administrative and remote access activities.";
        subject hs: HomeServer;

        require constraint {
            hs.storage.encryptedAtRest == true and
            hs.securityGateway.firewallEnabled == true and
            hs.securityGateway.intrusionDetectionEnabled == true and
            hs.securityGateway.remoteAccessVpnEnabled == true
        }
    }

    requirement def BackupRequirement {
        doc "The home server shall perform incremental backups for household endpoints and support restoration from verified backup images.";
        subject hs: HomeServer;

        require constraint {
            hs.backupService.supportsIncrementalBackup == true and
            hs.backupService.supportsBareMetalRestore == true and
            hs.backupService.minimumRetention >= 90.0
        }
    }

    part homeServerDeployment: HomeServerInstallation;

    satisfy PrimaryFunctionRequirement by homeServerDeployment.homeServer;
    satisfy StorageRequirement by homeServerDeployment.homeServer;
    satisfy AvailabilityRequirement by homeServerDeployment.homeServer;
    satisfy LatencyRequirement by homeServerDeployment.homeServer;
    satisfy PowerRequirement by homeServerDeployment.homeServer;
    satisfy SecurityRequirement by homeServerDeployment.homeServer;
    satisfy BackupRequirement by homeServerDeployment.homeServer;
}
