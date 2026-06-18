package IP500AllianceBasedBuildingAutomationModel {
    private import ScalarValues::*;

    doc /* 
     This package defines a smart-building communication system based on the IP500 Alliance concept.
     The high-level primary function is to provide a secure, vendor-neutral, IPv6-based wireless
     building automation network that interoperably connects sensors, actuators, controllers,
     building management applications, and external IP services.
    */

    enum def DeviceRoleKind {
        enum gateway;
        enum meshRouter;
        enum sleepySensor;
        enum actuator;
        enum supervisoryController;
        enum externalApplication;
    }

    enum def DeviceTrustStateKind {
        enum uncommissioned;
        enum provisioned;
        enum authenticated;
        enum authorized;
        enum quarantined;
        enum revoked;
    }

    enum def AlarmSeverityKind {
        enum normal;
        enum advisory;
        enum warning;
        enum critical;
        enum lifeSafety;
    }

    enum def BuildingDomainKind {
        enum fireSafety;
        enum accessControl;
        enum lighting;
        enum hvac;
        enum energyMonitoring;
        enum occupancy;
        enum supervisoryManagement;
    }

    enum def NetworkLifecycleKind {
        enum poweredOff;
        enum commissioning;
        enum secureMeshFormation;
        enum normalOperation;
        enum degradedOperation;
        enum maintenance;
        enum emergencyPriorityOperation;
    }

    attribute def FrequencyMHz :> Real {
        attribute unit : String = "MHz";
    }

    attribute def DataRateKbps :> Real {
        attribute unit : String = "kbit/s";
    }

    attribute def LatencyMs :> Real {
        attribute unit : String = "ms";
    }

    attribute def TimeSeconds :> Real {
        attribute unit : String = "s";
    }

    attribute def TimeMilliseconds :> Real {
        attribute unit : String = "ms";
    }

    attribute def VoltageV :> Real {
        attribute unit : String = "V";
    }

    attribute def CurrentmA :> Real {
        attribute unit : String = "mA";
    }

    attribute def PowerW :> Real {
        attribute unit : String = "W";
    }

    attribute def TemperatureC :> Real {
        attribute unit : String = "degC";
    }

    attribute def RelativeHumidityPercent :> Real {
        attribute unit : String = "%RH";
    }

    attribute def LengthMeters :> Real {
        attribute unit : String = "m";
    }

    attribute def AvailabilityPercent :> Real {
        attribute unit : String = "%";
    }

    attribute def PacketCount :> Integer {
        attribute unit : String = "packet";
    }

    attribute def ByteCount :> Integer {
        attribute unit : String = "byte";
    }

    attribute def HopCount :> Integer {
        attribute unit : String = "hop";
    }

    attribute def AddressString :> String;

    item def IPv6Packet {
        attribute sourceAddress : AddressString;
        attribute destinationAddress : AddressString;
        attribute hopLimit : HopCount;
        attribute payloadLength : ByteCount;
        attribute securityAuthenticated : Boolean;
        attribute priority : AlarmSeverityKind;
    }

    item def IP500MeshFrame {
        attribute frameSequenceNumber : Integer;
        attribute channel : FrequencyMHz;
        attribute linkQualityIndicator : Real;
        attribute encrypted : Boolean;
        attribute retryCount : Integer;
        item payload : IPv6Packet;
    }

    item def DeviceJoinRequest {
        attribute deviceIdentifier : String;
        attribute manufacturerIdentifier : String;
        attribute allianceProfileIdentifier : String;
        attribute requestedRole : DeviceRoleKind;
        attribute certificateFingerprint : String;
    }

    item def DeviceJoinResult {
        attribute accepted : Boolean;
        attribute assignedIpv6Address : AddressString;
        attribute assignedRole : DeviceRoleKind;
        attribute trustState : DeviceTrustStateKind;
        attribute rejectionReason : String;
    }

    item def BuildingControlCommand {
        attribute commandIdentifier : String;
        attribute destinationDomain : BuildingDomainKind;
        attribute priority : AlarmSeverityKind;
        attribute issuedBy : String;
        attribute commandName : String;
        attribute targetValue : String;
    }

    item def SensorObservation {
        attribute observationIdentifier : String;
        attribute sourceDeviceIdentifier : String;
        attribute domain : BuildingDomainKind;
        attribute severity : AlarmSeverityKind;
        attribute observedValue : String;
        attribute observationTimeSeconds : TimeSeconds;
    }

    item def AlarmEvent {
        attribute alarmIdentifier : String;
        attribute sourceDeviceIdentifier : String;
        attribute domain : BuildingDomainKind;
        attribute severity : AlarmSeverityKind;
        attribute description : String;
        attribute requiresAcknowledgement : Boolean;
    }

    item def SystemStatusReport {
        attribute lifecycle : NetworkLifecycleKind;
        attribute authenticatedDeviceCount : Integer;
        attribute routedPacketCount : PacketCount;
        attribute averageLatency : LatencyMs;
        attribute availability : AvailabilityPercent;
        attribute activeCriticalAlarmCount : Integer;
    }

    item def SecurityCredential {
        attribute credentialIdentifier : String;
        attribute issuer : String;
        attribute subjectDeviceIdentifier : String;
        attribute validFromSeconds : TimeSeconds;
        attribute validUntilSeconds : TimeSeconds;
        attribute revoked : Boolean;
    }

    item def TimeSynchronizationMessage {
        attribute timeSourceIdentifier : String;
        attribute networkTimeSeconds : TimeSeconds;
        attribute maximumClockError : TimeMilliseconds;
    }

    port def IP500WirelessPort {
        attribute supportedChannelLow : FrequencyMHz = 868.0;
        attribute supportedChannelHigh : FrequencyMHz = 928.0;
        attribute nominalDataRate : DataRateKbps = 250.0;
        in joinRequest : DeviceJoinRequest;
        out joinResult : DeviceJoinResult;
        inout meshFrame : IP500MeshFrame;
        in timeSync : TimeSynchronizationMessage;
    }

    port def IPv6BackhaulPort {
        attribute nominalDataRate : DataRateKbps = 100000.0;
        inout packet : IPv6Packet;
        in command : BuildingControlCommand;
        out status : SystemStatusReport;
        out alarm : AlarmEvent;
    }

    port def SensorServicePort {
        out observation : SensorObservation;
        out alarm : AlarmEvent;
        in command : BuildingControlCommand;
    }

    port def ActuatorServicePort {
        in command : BuildingControlCommand;
        out observation : SensorObservation;
        out alarm : AlarmEvent;
    }

    port def ManagementApplicationPort {
        out command : BuildingControlCommand;
        in status : SystemStatusReport;
        in alarm : AlarmEvent;
        in observation : SensorObservation;
    }

    port def PowerPort {
        in supplyVoltage : VoltageV;
        in supplyCurrent : CurrentmA;
    }

    part def IP500AllianceProfile {
        attribute profileName : String = "IP500 Alliance Secure IPv6 Building Automation Profile";
        attribute vendorNeutral : Boolean = true;
        attribute ipv6Based : Boolean = true;
        attribute supportsOpenApplicationProfiles : Boolean = true;
        attribute supportsSecureCommissioning : Boolean = true;
        attribute supportsWirelessMesh : Boolean = true;
        attribute minimumAvailabilityTarget : AvailabilityPercent = 99.5;
        attribute maximumNormalLatency : LatencyMs = 250.0;
        attribute maximumEmergencyLatency : LatencyMs = 50.0;
    }

    part def IP500Device {
        attribute deviceIdentifier : String;
        attribute manufacturerIdentifier : String;
        attribute role : DeviceRoleKind;
        attribute trustState : DeviceTrustStateKind = DeviceTrustStateKind::uncommissioned;
        attribute nominalSupplyVoltage : VoltageV = 3.3;
        attribute standbyCurrent : CurrentmA = 5.0;
        attribute maximumTransmitPower : PowerW = 0.025;
        attribute maximumIndoorRange : LengthMeters = 60.0;
        port wireless : IP500WirelessPort;
        port power : PowerPort;
    }

    part def IP500Gateway :> IP500Device {
        attribute deviceIdentifier : String = "IP500-GW-001";
        attribute role : DeviceRoleKind = DeviceRoleKind::gateway;
        attribute trustState : DeviceTrustStateKind = DeviceTrustStateKind::authorized;
        attribute supportsBorderRouting : Boolean = true;
        attribute supportsProtocolTranslation : Boolean = true;
        attribute maximumAuthenticatedDevices : Integer = 500;
        port backhaul : IPv6BackhaulPort;
    }

    part def IP500MeshRouter :> IP500Device {
        attribute role : DeviceRoleKind = DeviceRoleKind::meshRouter;
        attribute maintainsRoutingTable : Boolean = true;
        attribute maximumNeighborCount : Integer = 48;
        attribute routingUpdateInterval : TimeSeconds = 30.0;
    }

    part def SmokeDetector :> IP500Device {
        attribute role : DeviceRoleKind = DeviceRoleKind::sleepySensor;
        attribute domain : BuildingDomainKind = BuildingDomainKind::fireSafety;
        attribute smokeChamberTemperature : TemperatureC = 22.0;
        attribute alarmThresholdDescription : String = "UL-compliant smoke obscuration threshold";
        port service : SensorServicePort;
    }

    part def DoorAccessController :> IP500Device {
        attribute role : DeviceRoleKind = DeviceRoleKind::actuator;
        attribute domain : BuildingDomainKind = BuildingDomainKind::accessControl;
        attribute failSecure : Boolean = true;
        attribute unlockDuration : TimeSeconds = 5.0;
        port service : ActuatorServicePort;
    }

    part def LightingController :> IP500Device {
        attribute role : DeviceRoleKind = DeviceRoleKind::actuator;
        attribute domain : BuildingDomainKind = BuildingDomainKind::lighting;
        attribute dimmingSupported : Boolean = true;
        attribute maximumLoadPower : PowerW = 500.0;
        port service : ActuatorServicePort;
    }

    part def HVACZoneController :> IP500Device {
        attribute role : DeviceRoleKind = DeviceRoleKind::actuator;
        attribute domain : BuildingDomainKind = BuildingDomainKind::hvac;
        attribute temperatureSetpoint : TemperatureC = 21.0;
        attribute humiditySetpoint : RelativeHumidityPercent = 45.0;
        port service : ActuatorServicePort;
    }

    part def BuildingManagementSystem {
        attribute applicationIdentifier : String = "BMS-SUPERVISOR-001";
        attribute role : DeviceRoleKind = DeviceRoleKind::supervisoryController;
        attribute performsTrendLogging : Boolean = true;
        attribute performsAlarmManagement : Boolean = true;
        attribute performsEnergyOptimization : Boolean = true;
        port application : ManagementApplicationPort;
        port ipNetwork : IPv6BackhaulPort;
    }

    part def CloudOperationsService {
        attribute serviceIdentifier : String = "CLOUD-OPS-SECURE-BUILDING";
        attribute role : DeviceRoleKind = DeviceRoleKind::externalApplication;
        attribute storesLongTermAnalytics : Boolean = true;
        attribute supportsRemoteDiagnostics : Boolean = true;
        port application : ManagementApplicationPort;
        port ipNetwork : IPv6BackhaulPort;
    }

    action def ValidateAllianceProfile {
        in request : DeviceJoinRequest;
        out acceptedProfile : Boolean;
        attribute acceptedManufacturerRegistry : String = "IP500 Alliance member and certified device registry";
    }

    action def AuthenticateDeviceCredential {
        in request : DeviceJoinRequest;
        in credential : SecurityCredential;
        out trustState : DeviceTrustStateKind;
    }

    action def AssignIpv6Address {
        in request : DeviceJoinRequest;
        out assignedAddress : AddressString;
        attribute prefix : AddressString = "fd50:0500:0001::/64";
    }

    action def EstablishEncryptedMeshLink {
        in request : DeviceJoinRequest;
        out result : DeviceJoinResult;
        attribute encryptionRequired : Boolean = true;
        attribute replayProtectionRequired : Boolean = true;
    }

    action def RouteBuildingAutomationTraffic {
        in incomingFrame : IP500MeshFrame;
        out outgoingPacket : IPv6Packet;
        attribute honorsEmergencyPriority : Boolean = true;
        attribute maximumEmergencyForwardingLatency : LatencyMs = 50.0;
    }

    action def PublishSystemStatus {
        out report : SystemStatusReport;
        attribute reportingInterval : TimeSeconds = 60.0;
    }

    action def ProcessLifeSafetyAlarm {
        in alarm : AlarmEvent;
        out command : BuildingControlCommand;
        attribute preemptsNormalTraffic : Boolean = true;
        attribute acknowledgementRequired : Boolean = true;
    }

    action def SecureCommissioningWorkflow {
        in request : DeviceJoinRequest;
        out result : DeviceJoinResult;

        first validateProfile : ValidateAllianceProfile;
        then authenticateCredential : AuthenticateDeviceCredential;
        then assignAddress : AssignIpv6Address;
        then establishSecureLink : EstablishEncryptedMeshLink;

        flow request to validateProfile.request;
        flow request to authenticateCredential.request;
        flow request to assignAddress.request;
        flow request to establishSecureLink.request;
        flow assignAddress.assignedAddress to result.assignedIpv6Address;
        flow establishSecureLink.result to result;
    }

    action def NormalNetworkOperation {
        in meshInput : IP500MeshFrame;
        in managementCommand : BuildingControlCommand;
        out status : SystemStatusReport;
        out routedPacket : IPv6Packet;

        first routeTraffic : RouteBuildingAutomationTraffic;
        then publishStatus : PublishSystemStatus;

        flow meshInput to routeTraffic.incomingFrame;
        flow routeTraffic.outgoingPacket to routedPacket;
        flow publishStatus.report to status;
    }

    action def EmergencyPriorityOperation {
        in emergencyAlarm : AlarmEvent;
        out emergencyCommand : BuildingControlCommand;

        first processAlarm : ProcessLifeSafetyAlarm;
        flow emergencyAlarm to processAlarm.alarm;
        flow processAlarm.command to emergencyCommand;
    }

    state def IP500NetworkLifecycle {
        state poweredOff;
        state commissioning;
        state secureMeshFormation;
        state normalOperation;
        state degradedOperation;
        state maintenance;
        state emergencyPriorityOperation;

        transition initial then poweredOff;
        transition powerApplied first poweredOff then commissioning;
        transition devicesAccepted first commissioning then secureMeshFormation;
        transition meshRoutesStable first secureMeshFormation then normalOperation;
        transition linkQualityLow first normalOperation then degradedOperation;
        transition linkQualityRecovered first degradedOperation then normalOperation;
        transition maintenanceRequested first normalOperation then maintenance;
        transition maintenanceCompleted first maintenance then normalOperation;
        transition criticalAlarmReceived first normalOperation then emergencyPriorityOperation;
        transition emergencyCleared first emergencyPriorityOperation then normalOperation;
        transition powerRemoved first normalOperation then poweredOff;
        transition powerRemovedFromDegraded first degradedOperation then poweredOff;
        transition powerRemovedFromMaintenance first maintenance then poweredOff;
    }

    part def IP500AllianceBuildingAutomationSystem {
        doc /* 
         Primary function: provide a secure, interoperable, vendor-neutral, IPv6 wireless mesh
         infrastructure for commercial building automation, enabling certified IP500 devices from
         multiple manufacturers to exchange alarms, sensor observations, control commands, and
         status information with building management and external IP applications.
        */

        attribute systemIdentifier : String = "IP500-ALLIANCE-BASED-BUILDING-AUTOMATION-SYSTEM";
        attribute primaryFunction : String =
            "Securely interconnect multi-vendor building sensors, actuators, controllers, and supervisory applications over an IPv6 wireless mesh using IP500 Alliance principles.";
        attribute vendorNeutralInteroperabilitySupported : Boolean = true;
        attribute openIpv6CommunicationSupported : Boolean = true;
        attribute secureWirelessMeshSupported : Boolean = true;
        attribute certifiedDeviceCommissioningSupported : Boolean = true;
        attribute targetAvailability : AvailabilityPercent = 99.5;
        attribute maximumNormalControlLatency : LatencyMs = 250.0;
        attribute maximumLifeSafetyLatency : LatencyMs = 50.0;
        attribute normalOperatingChannel : FrequencyMHz = 868.3;
        attribute nominalMeshDataRate : DataRateKbps = 250.0;

        part allianceProfile : IP500AllianceProfile;

        part gateway : IP500Gateway;
        part routerFloor1 : IP500MeshRouter {
            attribute deviceIdentifier : String = "IP500-RTR-F1-001";
            attribute manufacturerIdentifier : String = "CertifiedVendorA";
            attribute trustState : DeviceTrustStateKind = DeviceTrustStateKind::authorized;
        }
        part routerFloor2 : IP500MeshRouter {
            attribute deviceIdentifier : String = "IP500-RTR-F2-001";
            attribute manufacturerIdentifier : String = "CertifiedVendorB";
            attribute trustState : DeviceTrustStateKind = DeviceTrustStateKind::authorized;
        }

        part lobbySmokeDetector : SmokeDetector {
            attribute deviceIdentifier : String = "IP500-SMK-LOBBY-001";
            attribute manufacturerIdentifier : String = "CertifiedVendorC";
            attribute trustState : DeviceTrustStateKind = DeviceTrustStateKind::authorized;
        }

        part plantRoomSmokeDetector : SmokeDetector {
            attribute deviceIdentifier : String = "IP500-SMK-PLANT-001";
            attribute manufacturerIdentifier : String = "CertifiedVendorD";
            attribute trustState : DeviceTrustStateKind = DeviceTrustStateKind::authorized;
        }

        part mainEntranceAccessController : DoorAccessController {
            attribute deviceIdentifier : String = "IP500-ACS-MAIN-001";
            attribute manufacturerIdentifier : String = "CertifiedVendorA";
            attribute trustState : DeviceTrustStateKind = DeviceTrustStateKind::authorized;
        }

        part officeLightingController : LightingController {
            attribute deviceIdentifier : String = "IP500-LGT-OFFICE-001";
            attribute manufacturerIdentifier : String = "CertifiedVendorB";
            attribute trustState : DeviceTrustStateKind = DeviceTrustStateKind::authorized;
        }

        part conferenceHVACController : HVACZoneController {
            attribute deviceIdentifier : String = "IP500-HVAC-CONF-001";
            attribute manufacturerIdentifier : String = "CertifiedVendorC";
            attribute trustState : DeviceTrustStateKind = DeviceTrustStateKind::authorized;
        }

        part bms : BuildingManagementSystem;
        part cloudService : CloudOperationsService;

        port buildingIpBackhaul : IPv6BackhaulPort;
        port operatorInterface : ManagementApplicationPort;

        connection gatewayToBuildingBackhaul connect gateway.backhaul to buildingIpBackhaul;
        connection gatewayToBms connect gateway.backhaul to bms.ipNetwork;
        connection gatewayToCloud connect gateway.backhaul to cloudService.ipNetwork;

        connection routerFloor1ToGateway connect routerFloor1.wireless to gateway.wireless;
        connection routerFloor2ToGateway connect routerFloor2.wireless to gateway.wireless;
        connection routerFloor1ToRouterFloor2 connect routerFloor1.wireless to routerFloor2.wireless;

        connection lobbySmokeToRouterFloor1 connect lobbySmokeDetector.wireless to routerFloor1.wireless;
        connection plantSmokeToRouterFloor2 connect plantRoomSmokeDetector.wireless to routerFloor2.wireless;
        connection accessControllerToRouterFloor1 connect mainEntranceAccessController.wireless to routerFloor1.wireless;
        connection lightingToRouterFloor1 connect officeLightingController.wireless to routerFloor1.wireless;
        connection hvacToRouterFloor2 connect conferenceHVACController.wireless to routerFloor2.wireless;

        connection bmsToOperatorInterface connect bms.application to operatorInterface;
        connection cloudToOperatorInterface connect cloudService.application to operatorInterface;

        perform commissioningBehavior : SecureCommissioningWorkflow;
        perform normalBehavior : NormalNetworkOperation;
        perform emergencyBehavior : EmergencyPriorityOperation;

        exhibit state lifecycle : IP500NetworkLifecycle;
    }

    constraint def AvailabilityConstraint {
        in actualAvailability : AvailabilityPercent;
        in requiredAvailability : AvailabilityPercent;
        actualAvailability >= requiredAvailability;
    }

    constraint def NormalLatencyConstraint {
        in actualLatency : LatencyMs;
        in maximumLatency : LatencyMs;
        actualLatency <= maximumLatency;
    }

    constraint def EmergencyLatencyConstraint {
        in actualLatency : LatencyMs;
        in maximumLatency : LatencyMs;
        actualLatency <= maximumLatency;
    }

    constraint def VendorNeutralConstraint {
        in vendorNeutral : Boolean;
        vendorNeutral == true;
    }

    constraint def SecureIpv6MeshConstraint {
        in ipv6Supported : Boolean;
        in secureMeshSupported : Boolean;
        ipv6Supported == true and secureMeshSupported == true;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : IP500AllianceBuildingAutomationSystem;
        doc /* 
         The system shall provide the primary high-level function of securely interconnecting
         certified multi-vendor building automation devices and applications using an IP500
         Alliance-style IPv6 wireless mesh communication architecture.
        */
        require constraint {
            system.vendorNeutralInteroperabilitySupported == true and
            system.openIpv6CommunicationSupported == true and
            system.secureWirelessMeshSupported == true
        }
    }

    requirement def SecureCommissioningRequirement {
        subject system : IP500AllianceBuildingAutomationSystem;
        doc /* 
         The system shall admit only certified devices with validated credentials and shall assign
         an IPv6 address before allowing operational traffic.
        */
        require constraint {
            system.certifiedDeviceCommissioningSupported == true
        }
    }

    requirement def NormalLatencyRequirement {
        subject system : IP500AllianceBuildingAutomationSystem;
        doc /* 
         The system shall support normal building automation control traffic with latency not
         exceeding the configured maximum normal control latency.
        */
        require constraint {
            system.maximumNormalControlLatency <= 250.0
        }
    }

    requirement def LifeSafetyPriorityRequirement {
        subject system : IP500AllianceBuildingAutomationSystem;
        doc /* 
         The system shall prioritize life-safety alarms over normal automation traffic and shall
         support emergency message delivery within the configured life-safety latency target.
        */
        require constraint {
            system.maximumLifeSafetyLatency <= 50.0
        }
    }

    requirement def AvailabilityRequirement {
        subject system : IP500AllianceBuildingAutomationSystem;
        doc /* 
         The system shall provide high availability suitable for commercial building automation
         by supporting redundant wireless routing through multiple mesh routers.
        */
        require constraint {
            system.targetAvailability >= 99.5
        }
    }

    requirement def OpenInteroperabilityRequirement {
        subject system : IP500AllianceBuildingAutomationSystem;
        doc /* 
         The system shall support interoperable communication among certified devices from
         different manufacturers without requiring proprietary application gateways between
         devices in the same building domain.
        */
        require constraint {
            system.vendorNeutralInteroperabilitySupported == true
        }
    }

    part ip500AllianceBasedSystem : IP500AllianceBuildingAutomationSystem;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject system = ip500AllianceBasedSystem;
    }

    requirement secureCommissioning : SecureCommissioningRequirement {
        subject system = ip500AllianceBasedSystem;
    }

    requirement normalLatency : NormalLatencyRequirement {
        subject system = ip500AllianceBasedSystem;
    }

    requirement lifeSafetyPriority : LifeSafetyPriorityRequirement {
        subject system = ip500AllianceBasedSystem;
    }

    requirement availability : AvailabilityRequirement {
        subject system = ip500AllianceBasedSystem;
    }

    requirement openInteroperability : OpenInteroperabilityRequirement {
        subject system = ip500AllianceBasedSystem;
    }

    satisfy primaryFunction by ip500AllianceBasedSystem;
    satisfy secureCommissioning by ip500AllianceBasedSystem.commissioningBehavior;
    satisfy normalLatency by ip500AllianceBasedSystem.normalBehavior;
    satisfy lifeSafetyPriority by ip500AllianceBasedSystem.emergencyBehavior;
    satisfy availability by ip500AllianceBasedSystem.routerFloor1;
    satisfy availability by ip500AllianceBasedSystem.routerFloor2;
    satisfy openInteroperability by ip500AllianceBasedSystem.allianceProfile;
}
