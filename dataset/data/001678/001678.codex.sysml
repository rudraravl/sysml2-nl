package ProjectBrilloIoTSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    alias kBps for 'kilo byte per second';

    attribute def Percent :> Real {
        doc /* Percentage value from 0 to 100. */
    }

    attribute def Millisecond :> Real {
        unit = "ms";
    }

    attribute def Celsius :> Real {
        unit = "degC";
    }

    attribute def Lux :> Real {
        unit = "lx";
    }

    attribute def KilobytePerSecond :> Real {
        unit = "kB/s";
    }

    attribute def Watt :> Real {
        unit = "W";
    }

    attribute def Volt :> Real {
        unit = "V";
    }

    enum def ConnectivityState {
        enum offline;
        enum discovering;
        enum pairing;
        enum authenticated;
        enum cloudConnected;
        enum degraded;
    }

    enum def DeviceMode {
        enum booting;
        enum provisioning;
        enum operational;
        enum updating;
        enum safeMode;
        enum shutdown;
    }

    enum def SecurityLevel {
        enum unauthenticated;
        enum localAuthenticated;
        enum cloudAuthenticated;
        enum hardwareBackedTrusted;
    }

    enum def UpdateStatus {
        enum idle;
        enum checking;
        enum downloading;
        enum verifying;
        enum applying;
        enum rolledBack;
        enum completed;
    }

    item def SensorSample {
        attribute sampleId : String;
        attribute timestampMs : Millisecond;
        attribute temperature : Celsius;
        attribute ambientLight : Lux;
        attribute batteryPercent : Percent;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute issuedAtMs : Millisecond;
        attribute targetService : String;
        attribute commandName : String;
        attribute requestedSecurityLevel : SecurityLevel;
        attribute payloadSizeBytes : Integer;
    }

    item def TelemetryPacket {
        attribute packetId : String;
        attribute createdAtMs : Millisecond;
        attribute deviceIdentifier : String;
        attribute payloadBytes : Integer;
        attribute encrypted : Boolean;
        attribute qosLevel : Integer;
    }

    item def ProvisioningCredential {
        attribute networkSsid : String;
        attribute networkKeyHash : String;
        attribute ownerAccountId : String;
        attribute expiresAtMs : Millisecond;
    }

    item def FirmwareImage {
        attribute version : String;
        attribute sizeBytes : Integer;
        attribute signatureAlgorithm : String;
        attribute signatureValid : Boolean;
        attribute minimumBatteryPercent : Percent;
    }

    item def DiagnosticEvent {
        attribute eventId : String;
        attribute severity : Integer;
        attribute source : String;
        attribute message : String;
        attribute timestampMs : Millisecond;
    }

    port def SensorDataPort {
        out item sample : SensorSample;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def TelemetryPort {
        out item telemetry : TelemetryPacket;
        in item command : ControlCommand;
    }

    port def ProvisioningPort {
        in item credential : ProvisioningCredential;
        out item diagnostic : DiagnosticEvent;
    }

    port def UpdatePort {
        in item image : FirmwareImage;
        out item diagnostic : DiagnosticEvent;
    }

    port def PowerPort {
        in attribute supplyVoltage : Volt;
        out attribute consumedPower : Watt;
    }

    port def DiagnosticsPort {
        out item event : DiagnosticEvent;
    }

    part def ProjectBrilloDevice {
        doc /* High-level function: provide a secure, updateable, network-connected IoT device platform that discovers local peripherals, authenticates with a user or cloud account, collects sensor data, executes authorized commands, and publishes encrypted telemetry through managed services. */

        attribute deviceId : String;
        attribute mode : DeviceMode;
        attribute connectivity : ConnectivityState;
        attribute securityLevel : SecurityLevel;
        attribute bootTimeMs : Millisecond;
        attribute telemetryRate : KilobytePerSecond;
        attribute cpuLoadPercent : Percent;
        attribute memoryUsedPercent : Percent;
        attribute batteryPercent : Percent;

        port power : PowerPort;
        port provisioning : ProvisioningPort;
        port telemetry : TelemetryPort;
        port update : UpdatePort;
        port diagnostics : DiagnosticsPort;

        part hardware : BrilloHardwarePlatform;
        part brilloOs : BrilloOperatingSystem;
        part weaveService : WeaveCommunicationService;
        part cloudGateway : CloudGatewayAdapter;
        part deviceManager : DeviceLifecycleManager;
        part securityManager : HardwareBackedSecurityManager;
        part sensorHub : SensorHub;
        part actuatorController : ActuatorController;
        part otaManager : OverTheAirUpdateManager;
        part diagnosticsAgent : DiagnosticsAgent;

        connect power to hardware.powerInput;
        connect hardware.osRuntime to brilloOs.runtimeHost;
        connect sensorHub.sensorOutput to brilloOs.sensorInput;
        connect brilloOs.telemetryOutput to weaveService.localTelemetry;
        connect weaveService.cloudTelemetry to cloudGateway.telemetryLink;
        connect cloudGateway.commandLink to weaveService.cloudCommands;
        connect weaveService.localCommands to brilloOs.commandInput;
        connect brilloOs.actuatorCommands to actuatorController.commandInput;
        connect provisioning to deviceManager.provisioningInput;
        connect deviceManager.securityRequests to securityManager.authenticationInput;
        connect securityManager.securityStatus to weaveService.securityInput;
        connect update to otaManager.updateInput;
        connect otaManager.firmwareOutput to brilloOs.updateInput;
        connect diagnosticsAgent.diagnosticsOutput to diagnostics;
        connect brilloOs.diagnosticsOutput to diagnosticsAgent.osDiagnostics;
        connect hardware.diagnosticsOutput to diagnosticsAgent.hardwareDiagnostics;
    }

    part def BrilloHardwarePlatform {
        attribute processorCores : Integer = 4;
        attribute memoryMiB : Integer = 512;
        attribute flashMiB : Integer = 4096;
        attribute nominalVoltage : Volt = 5.0;
        attribute idlePower : Watt = 0.8;
        attribute peakPower : Watt = 4.5;

        port powerInput : PowerPort;
        port osRuntime;
        port diagnosticsOutput : DiagnosticsPort;

        part trustedExecutionElement : TrustedExecutionElement;
        part networkInterface : NetworkInterface;
        part physicalSensors : PhysicalSensorArray;
        part actuatorBus : ActuatorBus;

        connect networkInterface.diagnosticsOutput to diagnosticsOutput;
        connect physicalSensors.diagnosticsOutput to diagnosticsOutput;
        connect trustedExecutionElement.diagnosticsOutput to diagnosticsOutput;
    }

    part def TrustedExecutionElement {
        attribute keyStoreCapacity : Integer = 16;
        attribute supportsSecureBoot : Boolean = true;
        attribute measuredBootHash : String;
        attribute rootOfTrustValid : Boolean;

        port diagnosticsOutput : DiagnosticsPort;
    }

    part def NetworkInterface {
        attribute wifiEnabled : Boolean;
        attribute bluetoothLowEnergyEnabled : Boolean;
        attribute ipv6Enabled : Boolean = true;
        attribute uplinkRate : KilobytePerSecond;
        attribute packetLossPercent : Percent;

        port diagnosticsOutput : DiagnosticsPort;
    }

    part def PhysicalSensorArray {
        port sensorOutput : SensorDataPort;
        port diagnosticsOutput : DiagnosticsPort;

        part temperatureSensor : TemperatureSensor;
        part ambientLightSensor : AmbientLightSensor;
        part batteryMonitor : BatteryMonitor;

        connect temperatureSensor.sampleOutput to sensorOutput;
        connect ambientLightSensor.sampleOutput to sensorOutput;
        connect batteryMonitor.sampleOutput to sensorOutput;
    }

    part def TemperatureSensor {
        attribute measurementRangeLow : Celsius = -20.0;
        attribute measurementRangeHigh : Celsius = 85.0;
        attribute accuracy : Celsius = 0.5;
        port sampleOutput : SensorDataPort;
    }

    part def AmbientLightSensor {
        attribute minimumLux : Lux = 0.0;
        attribute maximumLux : Lux = 10000.0;
        attribute accuracyPercent : Percent = 5.0;
        port sampleOutput : SensorDataPort;
    }

    part def BatteryMonitor {
        attribute minimumVoltage : Volt = 3.2;
        attribute maximumVoltage : Volt = 4.2;
        attribute accuracyPercent : Percent = 2.0;
        port sampleOutput : SensorDataPort;
    }

    part def ActuatorBus {
        attribute busName : String = "GPIO-I2C-PWM";
        attribute maxAttachedActuators : Integer = 8;
    }

    part def BrilloOperatingSystem {
        attribute kernelVersion : String;
        attribute serviceStartTimeoutMs : Millisecond = 8000.0;
        attribute secureBootRequired : Boolean = true;
        attribute sandboxingEnabled : Boolean = true;
        attribute systemHealthPercent : Percent;

        port runtimeHost;
        port sensorInput : SensorDataPort;
        port commandInput : CommandPort;
        port actuatorCommands : CommandPort;
        port telemetryOutput : TelemetryPort;
        port updateInput : UpdatePort;
        port diagnosticsOutput : DiagnosticsPort;

        part serviceSupervisor : ServiceSupervisor;
        part dataCollector : SensorDataCollector;
        part commandRouter : CommandRouter;
        part localPolicyEngine : LocalPolicyEngine;

        connect sensorInput to dataCollector.sensorInput;
        connect dataCollector.telemetryOutput to telemetryOutput;
        connect commandInput to localPolicyEngine.commandInput;
        connect localPolicyEngine.approvedCommands to commandRouter.commandInput;
        connect commandRouter.actuatorCommands to actuatorCommands;
        connect serviceSupervisor.diagnosticsOutput to diagnosticsOutput;
        connect dataCollector.diagnosticsOutput to diagnosticsOutput;
        connect commandRouter.diagnosticsOutput to diagnosticsOutput;
    }

    part def ServiceSupervisor {
        attribute managedServiceCount : Integer;
        attribute restartLimitPerHour : Integer = 5;
        attribute lastRestartAtMs : Millisecond;
        port diagnosticsOutput : DiagnosticsPort;
    }

    part def SensorDataCollector {
        attribute samplingPeriodMs : Millisecond = 1000.0;
        attribute batchSize : Integer = 10;
        attribute compressionEnabled : Boolean = true;

        port sensorInput : SensorDataPort;
        port telemetryOutput : TelemetryPort;
        port diagnosticsOutput : DiagnosticsPort;
    }

    part def CommandRouter {
        attribute maxCommandLatencyMs : Millisecond = 250.0;
        attribute rejectedCommandCount : Integer;

        port commandInput : CommandPort;
        port actuatorCommands : CommandPort;
        port diagnosticsOutput : DiagnosticsPort;
    }

    part def LocalPolicyEngine {
        attribute requireOwnerAuthorization : Boolean = true;
        attribute minimumSecurityLevel : SecurityLevel = SecurityLevel::cloudAuthenticated;

        port commandInput : CommandPort;
        port approvedCommands : CommandPort;
    }

    part def WeaveCommunicationService {
        attribute protocolName : String = "Weave";
        attribute encryptionEnabled : Boolean = true;
        attribute sessionTimeoutMs : Millisecond = 300000.0;
        attribute maxTelemetryRate : KilobytePerSecond = 256.0;
        attribute currentConnectivity : ConnectivityState;

        port localTelemetry : TelemetryPort;
        port cloudTelemetry : TelemetryPort;
        port cloudCommands : CommandPort;
        port localCommands : CommandPort;
        port securityInput;
    }

    part def CloudGatewayAdapter {
        attribute endpointUri : String;
        attribute retryBackoffMs : Millisecond = 2000.0;
        attribute maxRetries : Integer = 6;
        attribute connected : Boolean;

        port telemetryLink : TelemetryPort;
        port commandLink : CommandPort;
    }

    part def DeviceLifecycleManager {
        attribute provisioned : Boolean;
        attribute ownerAccountId : String;
        attribute lastProvisionedAtMs : Millisecond;

        port provisioningInput : ProvisioningPort;
        port securityRequests;
    }

    part def HardwareBackedSecurityManager {
        attribute secureBootPassed : Boolean;
        attribute deviceCertificateInstalled : Boolean;
        attribute activeSecurityLevel : SecurityLevel;
        attribute failedAuthenticationCount : Integer;

        port authenticationInput;
        port securityStatus;
    }

    part def SensorHub {
        attribute activeSensorCount : Integer;
        attribute aggregateSamplePeriodMs : Millisecond = 1000.0;

        port sensorOutput : SensorDataPort;
    }

    part def ActuatorController {
        attribute attachedActuatorCount : Integer;
        attribute lastCommandLatencyMs : Millisecond;

        port commandInput : CommandPort;
    }

    part def OverTheAirUpdateManager {
        attribute status : UpdateStatus;
        attribute currentVersion : String;
        attribute pendingVersion : String;
        attribute downloadRate : KilobytePerSecond;
        attribute updateWindowStartMs : Millisecond;
        attribute updateWindowEndMs : Millisecond;

        port updateInput : UpdatePort;
        port firmwareOutput : UpdatePort;
    }

    part def DiagnosticsAgent {
        attribute retainedEventCount : Integer;
        attribute maxRetainedEvents : Integer = 1000;
        attribute lastUploadAtMs : Millisecond;

        port osDiagnostics : DiagnosticsPort;
        port hardwareDiagnostics : DiagnosticsPort;
        port diagnosticsOutput : DiagnosticsPort;
    }

    action def BootDevice {
        in attribute secureBootRequired : Boolean;
        out attribute bootSucceeded : Boolean;
        out item event : DiagnosticEvent;

        first start;
        then verifyRootOfTrust;
        then loadKernel;
        then startSystemServices;
        then reportBootResult;
        then done;

        action verifyRootOfTrust {
            out attribute trusted : Boolean;
        }

        action loadKernel {
            in attribute trusted : Boolean;
            out attribute kernelLoaded : Boolean;
        }

        action startSystemServices {
            in attribute kernelLoaded : Boolean;
            out attribute servicesStarted : Boolean;
        }

        action reportBootResult {
            in attribute servicesStarted : Boolean;
            out attribute bootSucceeded : Boolean;
        }
    }

    action def ProvisionDevice {
        in item credential : ProvisioningCredential;
        out attribute provisioned : Boolean;
        out attribute securityLevel : SecurityLevel;

        first receiveCredential;
        then validateCredential;
        then bindOwnerAccount;
        then installDeviceCertificate;
        then establishCloudSession;
        then done;
    }

    action def CollectAndPublishTelemetry {
        in item sample : SensorSample;
        out item telemetry : TelemetryPacket;

        first readSensorSample;
        then normalizeSample;
        then packageTelemetry;
        then encryptTelemetry;
        then publishTelemetry;
        then done;
    }

    action def ExecuteAuthorizedCommand {
        in item command : ControlCommand;
        out attribute accepted : Boolean;
        out item event : DiagnosticEvent;

        first receiveCommand;
        then authenticateCommand;
        then evaluatePolicy;
        then routeToService;
        then emitCommandResult;
        then done;
    }

    action def ApplyOtaUpdate {
        in item image : FirmwareImage;
        out attribute applied : Boolean;
        out attribute rollbackRequired : Boolean;

        first checkBatteryAndWindow;
        then downloadImage;
        then verifySignature;
        then stageImage;
        then rebootIntoUpdatedSlot;
        then confirmHealth;
        then done;
    }

    state def BrilloDeviceLifecycle {
        entry action BootDevice;

        state booting;
        state provisioning;
        state operational;
        state degraded;
        state updating;
        state safeMode;
        state shutdown;

        transition first booting;
        transition booting_to_provisioning
            first booting
            accept after 8000 ms
            then provisioning;

        transition provisioning_to_operational
            first provisioning
            accept ProvisioningCredential
            then operational;

        transition operational_to_degraded
            first operational
            accept DiagnosticEvent
            if event.severity >= 3
            then degraded;

        transition degraded_to_operational
            first degraded
            accept after 60000 ms
            if self.systemHealthPercent >= 90.0
            then operational;

        transition operational_to_updating
            first operational
            accept FirmwareImage
            if image.signatureValid == true and image.minimumBatteryPercent <= self.batteryPercent
            then updating;

        transition updating_to_operational
            first updating
            accept after 120000 ms
            then operational;

        transition updating_to_safeMode
            first updating
            accept DiagnosticEvent
            if event.severity >= 4
            then safeMode;

        transition any_to_shutdown
            first operational
            accept ControlCommand
            if command.commandName == "shutdown"
            then shutdown;
    }

    state def ConnectivityLifecycle {
        state offline;
        state discovering;
        state pairing;
        state authenticated;
        state cloudConnected;
        state degraded;

        transition first offline;
        transition offline_to_discovering first offline then discovering;
        transition discovering_to_pairing first discovering accept ProvisioningCredential then pairing;
        transition pairing_to_authenticated first pairing accept after 3000 ms then authenticated;
        transition authenticated_to_cloudConnected first authenticated accept after 2000 ms then cloudConnected;
        transition cloudConnected_to_degraded first cloudConnected accept DiagnosticEvent if event.severity >= 2 then degraded;
        transition degraded_to_cloudConnected first degraded accept after 30000 ms then cloudConnected;
    }

    requirement def SecureIoTGatewayRequirement {
        doc /* The system shall operate as a secure IoT device platform that connects local sensors and actuators to authenticated local and cloud services. */
    }

    requirement def ProvisioningRequirement {
        doc /* The device shall support owner-based provisioning using time-limited credentials and shall not publish telemetry before provisioning completes. */
        attribute maximumProvisioningTimeMs : Millisecond = 120000.0;
    }

    requirement def SecureBootRequirement {
        doc /* The device shall verify its boot chain using hardware-backed trust before starting network services. */
        attribute secureBootMandatory : Boolean = true;
    }

    requirement def TelemetryRequirement {
        doc /* The device shall collect environmental and power telemetry, encrypt it, and publish it to the cloud gateway at a bounded data rate. */
        attribute maximumTelemetryRate : KilobytePerSecond = 256.0;
        attribute nominalSamplingPeriodMs : Millisecond = 1000.0;
    }

    requirement def CommandAuthorizationRequirement {
        doc /* The device shall execute only commands that satisfy authentication and local policy checks. */
        attribute requiredSecurityLevel : SecurityLevel = SecurityLevel::cloudAuthenticated;
        attribute maximumCommandLatencyMs : Millisecond = 250.0;
    }

    requirement def OtaUpdateRequirement {
        doc /* The device shall accept signed firmware images, apply them inside an update window, and roll back when post-update health validation fails. */
        attribute signatureRequired : Boolean = true;
        attribute minimumBatteryPercent : Percent = 40.0;
    }

    requirement def DiagnosticsRequirement {
        doc /* The device shall retain diagnostic events from hardware, operating system services, connectivity, command routing, and updates. */
        attribute minimumRetainedEvents : Integer = 1000;
    }

    satisfy SecureIoTGatewayRequirement by ProjectBrilloDevice;
    satisfy ProvisioningRequirement by DeviceLifecycleManager;
    satisfy SecureBootRequirement by TrustedExecutionElement;
    satisfy TelemetryRequirement by SensorDataCollector;
    satisfy CommandAuthorizationRequirement by LocalPolicyEngine;
    satisfy OtaUpdateRequirement by OverTheAirUpdateManager;
    satisfy DiagnosticsRequirement by DiagnosticsAgent;

    part brilloReferenceDevice : ProjectBrilloDevice {
        attribute deviceId = "brillo-reference-hub-001";
        attribute mode = DeviceMode::booting;
        attribute connectivity = ConnectivityState::offline;
        attribute securityLevel = SecurityLevel::unauthenticated;
        attribute bootTimeMs = 0.0;
        attribute telemetryRate = 0.0;
        attribute cpuLoadPercent = 0.0;
        attribute memoryUsedPercent = 0.0;
        attribute batteryPercent = 100.0;

        part hardware {
            attribute processorCores = 4;
            attribute memoryMiB = 512;
            attribute flashMiB = 4096;
            attribute nominalVoltage = 5.0;
            attribute idlePower = 0.8;
            attribute peakPower = 4.5;
        }

        part brilloOs {
            attribute kernelVersion = "Brillo-embedded-linux";
            attribute serviceStartTimeoutMs = 8000.0;
            attribute secureBootRequired = true;
            attribute sandboxingEnabled = true;
            attribute systemHealthPercent = 100.0;
        }

        part weaveService {
            attribute protocolName = "Weave";
            attribute encryptionEnabled = true;
            attribute sessionTimeoutMs = 300000.0;
            attribute maxTelemetryRate = 256.0;
            attribute currentConnectivity = ConnectivityState::offline;
        }

        part cloudGateway {
            attribute endpointUri = "iot-cloud-gateway.example/brillo";
            attribute retryBackoffMs = 2000.0;
            attribute maxRetries = 6;
            attribute connected = false;
        }

        part otaManager {
            attribute status = UpdateStatus::idle;
            attribute currentVersion = "1.0.0";
            attribute pendingVersion = "";
            attribute downloadRate = 0.0;
        }
    }

}