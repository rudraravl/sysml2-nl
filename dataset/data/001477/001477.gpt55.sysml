package InternetAccessHighLevelModel {

    import ScalarValues::*;

    enum def DataRateUnit {
        enum bitPerSecond;
        enum kilobitPerSecond;
        enum megabitPerSecond;
        enum gigabitPerSecond;
    }

    enum def TimeUnit {
        enum millisecond;
        enum second;
        enum minute;
    }

    enum def FrequencyUnit {
        enum megahertz;
        enum gigahertz;
    }

    enum def PowerUnit {
        enum watt;
        enum volt;
    }

    enum def AvailabilityUnit {
        enum percent;
    }

    enum def AddressFamily {
        enum IPv4;
        enum IPv6;
        enum dualStack;
    }

    enum def SecurityDisposition {
        enum allowed;
        enum denied;
        enum inspected;
        enum rateLimited;
    }

    enum def LinkHealth {
        enum unavailable;
        enum degraded;
        enum healthy;
    }

    enum def SubscriberAuthenticationStatus {
        enum unauthenticated;
        enum authenticating;
        enum authenticated;
        enum rejected;
    }

    attribute def DataRate {
        attribute value : Real;
        attribute unit : DataRateUnit;
    }

    attribute def Latency {
        attribute value : Real;
        attribute unit : TimeUnit;
    }

    attribute def Frequency {
        attribute value : Real;
        attribute unit : FrequencyUnit;
    }

    attribute def ElectricalPower {
        attribute value : Real;
        attribute unit : PowerUnit;
    }

    attribute def Availability {
        attribute value : Real;
        attribute unit : AvailabilityUnit;
    }

    attribute def PacketCount {
        attribute value : Integer;
    }

    attribute def ByteCount {
        attribute value : Integer;
    }

    attribute def AddressText {
        attribute value : String;
    }

    attribute def ServiceIdentifier {
        attribute value : String;
    }

    item def EthernetFrame {
        attribute sourceMacAddress : AddressText;
        attribute destinationMacAddress : AddressText;
        attribute etherType : String;
        attribute payloadBytes : ByteCount;
        item payload : IPPacket;
    }

    item def IPPacket {
        attribute sourceAddress : AddressText;
        attribute destinationAddress : AddressText;
        attribute addressFamily : AddressFamily;
        attribute protocol : String;
        attribute payloadBytes : ByteCount;
        attribute differentiatedServicesCodePoint : Integer;
    }

    item def DNSQuery {
        attribute requesterAddress : AddressText;
        attribute requestedName : String;
        attribute addressFamily : AddressFamily;
    }

    item def DNSResponse {
        attribute responderAddress : AddressText;
        attribute resolvedName : String;
        attribute resolvedAddress : AddressText;
        attribute timeToLiveSeconds : Integer;
    }

    item def SubscriberCredential {
        attribute subscriberId : ServiceIdentifier;
        attribute circuitId : ServiceIdentifier;
        attribute sharedSecretHash : String;
    }

    item def AuthenticationResult {
        attribute subscriberId : ServiceIdentifier;
        attribute status : SubscriberAuthenticationStatus;
        attribute assignedPrefix : AddressText;
        attribute assignedGateway : AddressText;
    }

    item def OpticalSignal {
        attribute wavelengthNanometers : Real;
        attribute receivePower : ElectricalPower;
        attribute lineRate : DataRate;
    }

    item def RadioSignal {
        attribute centerFrequency : Frequency;
        attribute channelWidthMHz : Real;
        attribute signalStrengthDbm : Real;
        attribute modulation : String;
    }

    item def ServiceTelemetry {
        attribute downstreamUtilization : Real;
        attribute upstreamUtilization : Real;
        attribute observedLatency : Latency;
        attribute droppedPackets : PacketCount;
        attribute linkHealth : LinkHealth;
    }

    port def EthernetPort {
        inout item frames : EthernetFrame;
        attribute administrativeName : String;
        attribute lineRate : DataRate;
        attribute enabled : Boolean;
    }

    port def WiFiRadioPort {
        inout item radioFrames : EthernetFrame;
        inout item radioSignal : RadioSignal;
        attribute ssid : String;
        attribute band : Frequency;
        attribute channel : Integer;
        attribute maxPhyRate : DataRate;
        attribute enabled : Boolean;
    }

    port def FiberAccessPort {
        inout item opticalCarrier : OpticalSignal;
        inout item frames : EthernetFrame;
        attribute opticalLineRate : DataRate;
        attribute linkState : LinkHealth;
    }

    port def IPServicePort {
        inout item packets : IPPacket;
        in item dnsQueries : DNSQuery;
        out item dnsResponses : DNSResponse;
        attribute routedPrefix : AddressText;
        attribute addressFamily : AddressFamily;
    }

    port def AuthenticationPort {
        out item credential : SubscriberCredential;
        in item result : AuthenticationResult;
    }

    port def ManagementTelemetryPort {
        out item telemetry : ServiceTelemetry;
        attribute samplingInterval : Latency;
    }

    action def AuthenticateSubscriber {
        in item credential : SubscriberCredential;
        out item result : AuthenticationResult;
        attribute maximumAuthenticationTime : Latency = (value = 5.0, unit = TimeUnit::second);
        attribute usesCircuitIdentifier : Boolean = true;
    }

    action def EstablishAccessLink {
        inout item carrier : OpticalSignal;
        out attribute health : LinkHealth;
        attribute maximumLinkTrainingTime : Latency = (value = 30.0, unit = TimeUnit::second);
    }

    action def AssignSubscriberAddressing {
        in item authentication : AuthenticationResult;
        out attribute delegatedPrefix : AddressText;
        out attribute defaultGateway : AddressText;
        attribute supportedAddressFamily : AddressFamily = AddressFamily::dualStack;
    }

    action def RouteAndTranslateTraffic {
        in item lanPackets : IPPacket;
        out item internetPackets : IPPacket;
        attribute natEnabled : Boolean = true;
        attribute firewallDefaultDisposition : SecurityDisposition = SecurityDisposition::denied;
        attribute maximumForwardingLatency : Latency = (value = 5.0, unit = TimeUnit::millisecond);
    }

    action def ResolveDomainNames {
        in item query : DNSQuery;
        out item response : DNSResponse;
        attribute recursiveResolutionEnabled : Boolean = true;
        attribute maximumResolutionLatency : Latency = (value = 100.0, unit = TimeUnit::millisecond);
    }

    action def MonitorServiceQuality {
        in item telemetrySample : ServiceTelemetry;
        out attribute health : LinkHealth;
        attribute samplingPeriod : Latency = (value = 10.0, unit = TimeUnit::second);
    }

    action def ProvideInternetAccess {
        in item subscriberFrames : EthernetFrame;
        out item internetPackets : IPPacket;
        in item dnsQuery : DNSQuery;
        out item dnsResponse : DNSResponse;

        attribute primaryFunction : String =
            "Provide managed Internet connectivity between subscriber devices and external Internet services by establishing an access link, authenticating the subscriber, assigning network addressing, forwarding IP traffic, resolving names, enforcing security policy, and monitoring service quality.";

        action establishAccessLink : EstablishAccessLink;
        action authenticateSubscriber : AuthenticateSubscriber;
        action assignSubscriberAddressing : AssignSubscriberAddressing;
        action routeAndTranslateTraffic : RouteAndTranslateTraffic;
        action resolveDomainNames : ResolveDomainNames;
        action monitorServiceQuality : MonitorServiceQuality;
    }

    state def InternetAccessLifecycle {
        state poweredOff;
        state booting;
        state linkTraining;
        state authenticating;
        state addressing;
        state online;
        state degradedService;
        state securityBlocked;
        state fault;

        transition initial then poweredOff;

        transition powerApplied
            first poweredOff
            then booting;

        transition bootComplete
            first booting
            then linkTraining;

        transition physicalLinkHealthy
            first linkTraining
            then authenticating;

        transition authenticationAccepted
            first authenticating
            then addressing;

        transition addressingComplete
            first addressing
            then online;

        transition congestionDetected
            first online
            then degradedService;

        transition serviceRestored
            first degradedService
            then online;

        transition prohibitedTrafficDetected
            first online
            then securityBlocked;

        transition securityPolicyCleared
            first securityBlocked
            then online;

        transition physicalLinkLost
            first online
            then linkTraining;

        transition unrecoverableError
            first booting
            then fault;

        transition resetRequested
            first fault
            then booting;
    }

    part def SubscriberDevice {
        port networkPort : EthernetPort {
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        attribute hostName : String;
        attribute deviceAddress : AddressText;
        attribute typicalDownstreamDemand : DataRate = (value = 25.0, unit = DataRateUnit::megabitPerSecond);
        attribute typicalUpstreamDemand : DataRate = (value = 5.0, unit = DataRateUnit::megabitPerSecond);
    }

    part def WiFiAccessPoint {
        port radio : WiFiRadioPort {
            :>> ssid = "Home-Internet";
            :>> band = (value = 5.0, unit = FrequencyUnit::gigahertz);
            :>> channel = 36;
            :>> maxPhyRate = (value = 1200.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        port wiredUplink : EthernetPort {
            :>> administrativeName = "ap-uplink";
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        attribute wpa3Enabled : Boolean = true;
        attribute maximumAssociatedClients : Integer = 64;
    }

    part def LocalEthernetSwitch {
        port gatewayPort : EthernetPort {
            :>> administrativeName = "switch-gateway";
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        port wiredClientPort1 : EthernetPort {
            :>> administrativeName = "switch-client-1";
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        port wiredClientPort2 : EthernetPort {
            :>> administrativeName = "switch-client-2";
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        port accessPointPort : EthernetPort {
            :>> administrativeName = "switch-ap";
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        attribute switchingCapacity : DataRate = (value = 8.0, unit = DataRateUnit::gigabitPerSecond);
        attribute learnedMacCapacity : Integer = 4096;
    }

    part def HomeLocalNetwork {
        port gatewayUplink : EthernetPort {
            :>> administrativeName = "home-lan-uplink";
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        part switch : LocalEthernetSwitch;
        part accessPoint : WiFiAccessPoint;

        part laptop : SubscriberDevice {
            :>> hostName = "family-laptop";
            :>> deviceAddress = (value = "192.168.10.21");
        }

        part smartTv : SubscriberDevice {
            :>> hostName = "living-room-tv";
            :>> deviceAddress = (value = "192.168.10.34");
            :>> typicalDownstreamDemand = (value = 40.0, unit = DataRateUnit::megabitPerSecond);
            :>> typicalUpstreamDemand = (value = 3.0, unit = DataRateUnit::megabitPerSecond);
        }

        part phone : SubscriberDevice {
            :>> hostName = "mobile-phone";
            :>> deviceAddress = (value = "192.168.10.45");
            :>> typicalDownstreamDemand = (value = 15.0, unit = DataRateUnit::megabitPerSecond);
            :>> typicalUpstreamDemand = (value = 4.0, unit = DataRateUnit::megabitPerSecond);
        }

        connect gatewayUplink to switch.gatewayPort;
        connect switch.accessPointPort to accessPoint.wiredUplink;
        connect switch.wiredClientPort1 to laptop.networkPort;
        connect switch.wiredClientPort2 to smartTv.networkPort;
    }

    part def BroadbandOpticalModem {
        port subscriberFiber : FiberAccessPort {
            :>> opticalLineRate = (value = 1.0, unit = DataRateUnit::gigabitPerSecond);
            :>> linkState = LinkHealth::healthy;
        }

        port residentialEthernet : EthernetPort {
            :>> administrativeName = "modem-lan";
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        attribute downstreamSyncRate : DataRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
        attribute upstreamSyncRate : DataRate = (value = 500.0, unit = DataRateUnit::megabitPerSecond);
        attribute receiveOpticalPower : ElectricalPower = (value = -18.0, unit = PowerUnit::watt);

        perform action linkTraining : EstablishAccessLink;
    }

    part def ResidentialRouter {
        port wanPort : EthernetPort {
            :>> administrativeName = "router-wan";
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        port lanPort : EthernetPort {
            :>> administrativeName = "router-lan";
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        port ipService : IPServicePort {
            :>> routedPrefix = (value = "192.168.10.0/24, 2001:db8:100:10::/64");
            :>> addressFamily = AddressFamily::dualStack;
        }

        port authenticationClient : AuthenticationPort;
        port managementTelemetry : ManagementTelemetryPort {
            :>> samplingInterval = (value = 10.0, unit = TimeUnit::second);
        }

        attribute lanIPv4Gateway : AddressText = (value = "192.168.10.1");
        attribute delegatedIPv6Prefix : AddressText = (value = "2001:db8:100:10::/64");
        attribute dhcpEnabled : Boolean = true;
        attribute dnsProxyEnabled : Boolean = true;
        attribute nat44Enabled : Boolean = true;
        attribute firewallEnabled : Boolean = true;
        attribute maximumNATSessions : Integer = 65536;
        attribute nominalForwardingCapacity : DataRate = (value = 900.0, unit = DataRateUnit::megabitPerSecond);

        perform action authenticate : AuthenticateSubscriber;
        perform action addressAssignment : AssignSubscriberAddressing;
        perform action forwarding : RouteAndTranslateTraffic;
        perform action dnsResolution : ResolveDomainNames;
        perform action telemetryMonitoring : MonitorServiceQuality;
    }

    part def SubscriberGateway {
        port providerPort : FiberAccessPort {
            :>> opticalLineRate = (value = 1.0, unit = DataRateUnit::gigabitPerSecond);
            :>> linkState = LinkHealth::healthy;
        }

        port homeLanPort : EthernetPort {
            :>> administrativeName = "gateway-home-lan";
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        port servicePort : IPServicePort {
            :>> routedPrefix = (value = "subscriber-prefix");
            :>> addressFamily = AddressFamily::dualStack;
        }

        part modem : BroadbandOpticalModem;
        part router : ResidentialRouter;

        attribute powerConsumption : ElectricalPower = (value = 18.0, unit = PowerUnit::watt);
        attribute subscriberAuthenticationStatus : SubscriberAuthenticationStatus = SubscriberAuthenticationStatus::authenticated;

        connect providerPort to modem.subscriberFiber;
        connect modem.residentialEthernet to router.wanPort;
        connect router.lanPort to homeLanPort;
        connect router.ipService to servicePort;

        exhibit state serviceLifecycle : InternetAccessLifecycle;
    }

    part def ProviderAccessNode {
        port subscriberFacingPort : FiberAccessPort {
            :>> opticalLineRate = (value = 1.0, unit = DataRateUnit::gigabitPerSecond);
            :>> linkState = LinkHealth::healthy;
        }

        port aggregationPort : EthernetPort {
            :>> administrativeName = "access-node-aggregation";
            :>> lineRate = (value = 10.0, unit = DataRateUnit::gigabitPerSecond);
            :>> enabled = true;
        }

        attribute servingArea : String = "neighborhood-zone-a";
        attribute maximumSubscribers : Integer = 512;
        attribute oversubscriptionRatio : Real = 16.0;
    }

    part def SubscriberAuthenticationServer {
        port authenticationService : AuthenticationPort;

        attribute realm : String = "subscriber.isp.example";
        attribute credentialDatabaseReplicated : Boolean = true;
        attribute maximumAuthenticationLatency : Latency = (value = 1.0, unit = TimeUnit::second);

        perform action authenticateSubscriber : AuthenticateSubscriber;
    }

    part def ProviderDNSResolver {
        port dnsService : IPServicePort {
            :>> routedPrefix = (value = "203.0.113.53/32, 2001:db8:53::53/128");
            :>> addressFamily = AddressFamily::dualStack;
        }

        attribute cacheEnabled : Boolean = true;
        attribute recursiveLookupEnabled : Boolean = true;
        attribute nominalQueryCapacity : DataRate = (value = 50.0, unit = DataRateUnit::megabitPerSecond);

        perform action resolveNames : ResolveDomainNames;
    }

    part def IPBackboneRouter {
        port accessSide : EthernetPort {
            :>> administrativeName = "backbone-access";
            :>> lineRate = (value = 10.0, unit = DataRateUnit::gigabitPerSecond);
            :>> enabled = true;
        }

        port internetSide : IPServicePort {
            :>> routedPrefix = (value = "0.0.0.0/0, ::/0");
            :>> addressFamily = AddressFamily::dualStack;
        }

        attribute routingProtocols : String = "BGP, OSPFv3";
        attribute routeTableCapacity : Integer = 2000000;
        attribute forwardingCapacity : DataRate = (value = 40.0, unit = DataRateUnit::gigabitPerSecond);
    }

    part def ISPCoreNetwork {
        port accessAggregation : EthernetPort {
            :>> administrativeName = "isp-access-aggregation";
            :>> lineRate = (value = 10.0, unit = DataRateUnit::gigabitPerSecond);
            :>> enabled = true;
        }

        port internetTransit : IPServicePort {
            :>> routedPrefix = (value = "public-internet");
            :>> addressFamily = AddressFamily::dualStack;
        }

        port authenticationEndpoint : AuthenticationPort;

        part authenticationServer : SubscriberAuthenticationServer;
        part dnsResolver : ProviderDNSResolver;
        part backboneRouter : IPBackboneRouter;

        attribute advertisedAutonomousSystem : Integer = 64512;
        attribute coreAvailabilityTarget : Availability = (value = 99.95, unit = AvailabilityUnit::percent);

        connect accessAggregation to backboneRouter.accessSide;
        connect backboneRouter.internetSide to internetTransit;
        connect authenticationEndpoint to authenticationServer.authenticationService;
    }

    part def ExternalInternet {
        port globalIPService : IPServicePort {
            :>> routedPrefix = (value = "global-routing-table");
            :>> addressFamily = AddressFamily::dualStack;
        }

        attribute description : String = "Interconnected public IP networks and services reachable through ISP transit and peering.";
        attribute assumedAvailability : Availability = (value = 99.9, unit = AvailabilityUnit::percent);
    }

    constraint def MinimumDownstreamCapacity {
        in capacity : DataRate;
        require constraint { capacity.value >= 100.0 }
    }

    constraint def MaximumRoundTripLatency {
        in latency : Latency;
        require constraint { latency.value <= 50.0 }
    }

    constraint def MinimumAvailability {
        in availability : Availability;
        require constraint { availability.value >= 99.5 }
    }

    requirement def PrimaryFunctionRequirement {
        subject accessSystem : InternetAccessSystem;

        attribute id : String = "REQ-IAS-001";
        attribute text : String =
            "The Internet access system shall provide subscriber devices with managed bidirectional IP connectivity to external Internet services at a high level by establishing the access link, authenticating the subscriber, assigning addresses, routing traffic, resolving domain names, applying security policy, and monitoring quality of service.";

        require constraint {
            accessSystem.nominalDownstreamRate.value >= 100.0
        }
    }

    requirement def AddressingRequirement {
        subject accessSystem : InternetAccessSystem;

        attribute id : String = "REQ-IAS-002";
        attribute text : String =
            "The Internet access system shall assign usable local addressing to subscriber devices and provide IPv4 and IPv6 reachability toward the ISP core.";

        require constraint {
            accessSystem.supportedAddressing == AddressFamily::dualStack
        }
    }

    requirement def SecurityRequirement {
        subject accessSystem : InternetAccessSystem;

        attribute id : String = "REQ-IAS-003";
        attribute text : String =
            "The Internet access system shall deny unsolicited inbound traffic by default while allowing subscriber-initiated outbound sessions and inspected return traffic.";

        require constraint {
            accessSystem.defaultInboundDisposition == SecurityDisposition::denied
        }
    }

    requirement def ServiceQualityRequirement {
        subject accessSystem : InternetAccessSystem;

        attribute id : String = "REQ-IAS-004";
        attribute text : String =
            "The Internet access system shall maintain nominal subscriber access latency below 50 milliseconds under normal operating conditions.";

        require constraint {
            accessSystem.nominalRoundTripLatency.value <= 50.0
        }
    }

    requirement def AvailabilityRequirement {
        subject accessSystem : InternetAccessSystem;

        attribute id : String = "REQ-IAS-005";
        attribute text : String =
            "The Internet access system shall provide service availability of at least 99.5 percent excluding external Internet destination failures.";

        require constraint {
            accessSystem.serviceAvailability.value >= 99.5
        }
    }

    part def InternetAccessSystem {
        port subscriberAccessPort : EthernetPort {
            :>> administrativeName = "subscriber-access";
            :>> lineRate = (value = 1000.0, unit = DataRateUnit::megabitPerSecond);
            :>> enabled = true;
        }

        port providerAccessPort : FiberAccessPort {
            :>> opticalLineRate = (value = 1.0, unit = DataRateUnit::gigabitPerSecond);
            :>> linkState = LinkHealth::healthy;
        }

        port publicInternetPort : IPServicePort {
            :>> routedPrefix = (value = "0.0.0.0/0, ::/0");
            :>> addressFamily = AddressFamily::dualStack;
        }

        port telemetryPort : ManagementTelemetryPort {
            :>> samplingInterval = (value = 10.0, unit = TimeUnit::second);
        }

        part homeNetwork : HomeLocalNetwork;
        part subscriberGateway : SubscriberGateway;
        part accessNode : ProviderAccessNode;
        part ispCore : ISPCoreNetwork;
        part internet : ExternalInternet;

        attribute systemName : String = "Managed Residential Internet Access System";
        attribute primaryFunction : String =
            "Connect subscriber devices to the public Internet by transforming local Ethernet and Wi-Fi traffic into authenticated, routed, secure, monitored IP service.";
        attribute nominalDownstreamRate : DataRate = (value = 300.0, unit = DataRateUnit::megabitPerSecond);
        attribute nominalUpstreamRate : DataRate = (value = 100.0, unit = DataRateUnit::megabitPerSecond);
        attribute nominalRoundTripLatency : Latency = (value = 25.0, unit = TimeUnit::millisecond);
        attribute serviceAvailability : Availability = (value = 99.7, unit = AvailabilityUnit::percent);
        attribute supportedAddressing : AddressFamily = AddressFamily::dualStack;
        attribute defaultInboundDisposition : SecurityDisposition = SecurityDisposition::denied;
        attribute currentLinkHealth : LinkHealth = LinkHealth::healthy;

        connect subscriberAccessPort to homeNetwork.gatewayUplink;
        connect homeNetwork.gatewayUplink to subscriberGateway.homeLanPort;
        connect subscriberGateway.providerPort to accessNode.subscriberFacingPort;
        connect accessNode.aggregationPort to ispCore.accessAggregation;
        connect ispCore.internetTransit to internet.globalIPService;
        connect publicInternetPort to internet.globalIPService;
        connect subscriberGateway.router.authenticationClient to ispCore.authenticationEndpoint;
        connect subscriberGateway.router.managementTelemetry to telemetryPort;

        perform action provideInternetAccess : ProvideInternetAccess;

        exhibit state lifecycle : InternetAccessLifecycle;
    }

    part internetAccessSystem : InternetAccessSystem;

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject accessSystem = internetAccessSystem;
    }

    requirement addressingRequirement : AddressingRequirement {
        subject accessSystem = internetAccessSystem;
    }

    requirement securityRequirement : SecurityRequirement {
        subject accessSystem = internetAccessSystem;
    }

    requirement serviceQualityRequirement : ServiceQualityRequirement {
        subject accessSystem = internetAccessSystem;
    }

    requirement availabilityRequirement : AvailabilityRequirement {
        subject accessSystem = internetAccessSystem;
    }

    satisfy primaryFunctionRequirement by internetAccessSystem;
    satisfy addressingRequirement by internetAccessSystem.subscriberGateway.router;
    satisfy securityRequirement by internetAccessSystem.subscriberGateway.router;
    satisfy serviceQualityRequirement by internetAccessSystem;
    satisfy availabilityRequirement by internetAccessSystem;

}
