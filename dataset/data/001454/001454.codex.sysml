package HomeServerSystemModel {
    import ScalarValues::*;

    attribute def Watt :> Real;
    attribute def Volt :> Real;
    attribute def Ampere :> Real;
    attribute def Celsius :> Real;
    attribute def Gigabyte :> Real;
    attribute def Terabyte :> Real;
    attribute def MegabitPerSecond :> Real;
    attribute def Millisecond :> Real;
    attribute def Percent :> Real;

    item def EthernetFrame {
        attribute sourceMac: String;
        attribute destinationMac: String;
        attribute payloadBytes: Integer;
    }

    item def MediaStream {
        attribute codec: String;
        attribute bitrate: MegabitPerSecond;
        attribute resolution: String;
    }

    item def BackupImage {
        attribute deviceId: String;
        attribute size: Gigabyte;
        attribute encrypted: Boolean;
    }

    item def AutomationCommand {
        attribute targetDeviceId: String;
        attribute commandName: String;
        attribute authenticated: Boolean;
    }

    item def HealthReport {
        attribute cpuLoad: Percent;
        attribute memoryLoad: Percent;
        attribute storageUsed: Percent;
        attribute temperature: Celsius;
        attribute serviceStatus: String;
    }

    port def EthernetPort {
        inout frame: EthernetFrame;
    }

    port def PowerInputPort {
        in voltage: Volt;
        in current: Ampere;
    }

    port def UsbPort {
        inout frame: EthernetFrame;
    }

    port def BackupPort {
        in backup: BackupImage;
    }

    port def MediaPort {
        out stream: MediaStream;
    }

    port def AutomationPort {
        in command: AutomationCommand;
    }

    port def MonitoringPort {
        out report: HealthReport;
    }

    part def Processor {
        attribute coreCount: Integer;
        attribute nominalPower: Watt;
        attribute temperature: Celsius;
    }

    part def Memory {
        attribute capacity: Gigabyte;
        attribute used: Gigabyte;
    }

    part def StorageArray {
        attribute rawCapacity: Terabyte;
        attribute usableCapacity: Terabyte;
        attribute usedCapacity: Terabyte;
        attribute redundancyMode: String;
        attribute encryptedAtRest: Boolean;
    }

    part def NetworkAdapter {
        attribute maxThroughput: MegabitPerSecond;
        port lan: EthernetPort;
    }

    part def PowerSupply {
        attribute ratedPower: Watt;
        port acInput: PowerInputPort;
    }

    part def CoolingSystem {
        attribute fanCount: Integer;
        attribute targetTemperature: Celsius;
    }

    part def BackupService {
        attribute schedule: String;
        attribute retentionDays: Integer;
        port backupIn: BackupPort;
    }

    part def MediaService {
        attribute supportedCodecs: String;
        attribute maxConcurrentStreams: Integer;
        port mediaOut: MediaPort;
    }

    part def AutomationGateway {
        attribute supportedProtocols: String;
        port automationIn: AutomationPort;
    }

    part def MonitoringService {
        attribute samplePeriodMs: Millisecond;
        port healthOut: MonitoringPort;
    }

    action def AuthenticateUser {
        in username: String;
        in credentialHash: String;
        out authorized: Boolean;
    }

    action def StoreBackup {
        in image: BackupImage;
        out stored: Boolean;
    }

    action def ServeMedia {
        in titleId: String;
        out stream: MediaStream;
    }

    action def DispatchAutomationCommand {
        in command: AutomationCommand;
        out accepted: Boolean;
    }

    action def PublishHealthReport {
        out report: HealthReport;
    }

    state def HomeServerOperatingState {
        entry action PublishHealthReport;

        state Off;
        state Booting;
        state Ready;
        state ServingMedia;
        state RunningBackup;
        state DispatchingAutomation;
        state Degraded;
        state Shutdown;

        transition first Off;
        transition Off_to_Booting
            first Off
            then Booting;

        transition Booting_to_Ready
            first Booting
            then Ready;

        transition Ready_to_ServingMedia
            first Ready
            accept ServeMedia
            then ServingMedia;

        transition ServingMedia_to_Ready
            first ServingMedia
            then Ready;

        transition Ready_to_RunningBackup
            first Ready
            accept StoreBackup
            then RunningBackup;

        transition RunningBackup_to_Ready
            first RunningBackup
            then Ready;

        transition Ready_to_DispatchingAutomation
            first Ready
            accept DispatchAutomationCommand
            then DispatchingAutomation;

        transition DispatchingAutomation_to_Ready
            first DispatchingAutomation
            then Ready;

        transition Ready_to_Degraded
            first Ready
            if temperature > 75.0
            then Degraded;

        transition Degraded_to_Ready
            first Degraded
            if temperature < 60.0
            then Ready;

        transition Ready_to_Shutdown
            first Ready
            then Shutdown;

        transition Shutdown_to_Off
            first Shutdown
            then Off;
    }

    part def HomeServer {
        doc
        /* Primary function: provide a centralized, always-on household computing node that stores shared files, protects home devices with scheduled backups, streams local media, brokers trusted home automation commands, and reports operational health. */

        attribute hostName: String;
        attribute idlePower: Watt;
        attribute maximumPower: Watt;
        attribute storageCapacity: Terabyte;
        attribute networkLatency: Millisecond;
        attribute availabilityTarget: Percent;

        port powerIn: PowerInputPort;
        port lan: EthernetPort;
        port backupIn: BackupPort;
        port mediaOut: MediaPort;
        port automationIn: AutomationPort;
        port healthOut: MonitoringPort;

        part cpu: Processor {
            attribute coreCount = 8;
            attribute nominalPower = 45.0;
            attribute temperature = 38.0;
        }

        part ram: Memory {
            attribute capacity = 64.0;
            attribute used = 12.0;
        }

        part disks: StorageArray {
            attribute rawCapacity = 32.0;
            attribute usableCapacity = 24.0;
            attribute usedCapacity = 8.5;
            attribute redundancyMode = "RAID-Z1";
            attribute encryptedAtRest = true;
        }

        part network: NetworkAdapter {
            attribute maxThroughput = 2500.0;
        }

        part psu: PowerSupply {
            attribute ratedPower = 300.0;
        }

        part cooling: CoolingSystem {
            attribute fanCount = 3;
            attribute targetTemperature = 55.0;
        }

        part backupService: BackupService {
            attribute schedule = "daily at 02:00 local time";
            attribute retentionDays = 30;
        }

        part mediaService: MediaService {
            attribute supportedCodecs = "H.264,H.265,AV1,AAC,FLAC";
            attribute maxConcurrentStreams = 4;
        }

        part automationGateway: AutomationGateway {
            attribute supportedProtocols = "Matter,Zigbee,MQTT";
        }

        part monitoringService: MonitoringService {
            attribute samplePeriodMs = 5000.0;
        }

        perform stateMachine: HomeServerOperatingState;

        bind powerIn = psu.acInput;
        bind lan = network.lan;
        bind backupIn = backupService.backupIn;
        bind mediaOut = mediaService.mediaOut;
        bind automationIn = automationGateway.automationIn;
        bind healthOut = monitoringService.healthOut;
    }

    part def HomeNetwork {
        port routerLan: EthernetPort;
        port clientBackup: BackupPort;
        port clientMedia: MediaPort;
        port smartHomeControl: AutomationPort;
        port adminMonitoring: MonitoringPort;

        part server: HomeServer {
            attribute hostName = "home-server";
            attribute idlePower = 38.0;
            attribute maximumPower = 180.0;
            attribute storageCapacity = 24.0;
            attribute networkLatency = 3.0;
            attribute availabilityTarget = 99.5;
        }

        connect routerLan to server.lan;
        connect clientBackup to server.backupIn;
        connect server.mediaOut to clientMedia;
        connect smartHomeControl to server.automationIn;
        connect server.healthOut to adminMonitoring;
    }

    requirement def CentralizedStorageRequirement {
        doc /* The home server shall provide shared, encrypted storage for household users and devices. */
        require constraint { server.disks.usableCapacity >= 16.0 }
        require constraint { server.disks.encryptedAtRest == true }
    }

    requirement def BackupRequirement {
        doc /* The home server shall accept scheduled backup images from household devices and retain them for at least 30 days. */
        require constraint { server.backupService.retentionDays >= 30 }
    }

    requirement def MediaStreamingRequirement {
        doc /* The home server shall stream local media to household clients with at least four concurrent streams. */
        require constraint { server.mediaService.maxConcurrentStreams >= 4 }
    }

    requirement def AutomationGatewayRequirement {
        doc /* The home server shall receive authenticated automation commands and dispatch them to supported home device protocols. */
        require constraint { server.automationGateway.supportedProtocols != "" }
    }

    requirement def AvailabilityRequirement {
        doc /* The home server shall target high household availability during normal operation. */
        require constraint { server.availabilityTarget >= 99.0 }
    }

    requirement def ThermalProtectionRequirement {
        doc /* The home server shall enter degraded operation when internal temperature exceeds safe limits. */
        require constraint { server.cooling.targetTemperature <= 60.0 }
    }

    satisfy CentralizedStorageRequirement by HomeNetwork::server;
    satisfy BackupRequirement by HomeNetwork::server;
    satisfy MediaStreamingRequirement by HomeNetwork::server;
    satisfy AutomationGatewayRequirement by HomeNetwork::server;
    satisfy AvailabilityRequirement by HomeNetwork::server;
    satisfy ThermalProtectionRequirement by HomeNetwork::server;
}