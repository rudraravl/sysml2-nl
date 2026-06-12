package ResidentialGatewaySystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Mbps :> Real {
        unit = "Mbit/s";
    }

    attribute def GHz :> Real {
        unit = "GHz";
    }

    attribute def dBm :> Real {
        unit = "dBm";
    }

    attribute def W :> Real {
        unit = "W";
    }

    attribute def ms :> Real {
        unit = "ms";
    }

    attribute def Celsius :> Real {
        unit = "degC";
    }

    enum def LinkStatus {
        enum disconnected;
        enum negotiating;
        enum connected;
        enum degraded;
        enum faulted;
    }

    enum def SecurityMode {
        enum open;
        enum wpa2Personal;
        enum wpa3Personal;
        enum wpa2Wpa3Mixed;
    }

    item def EthernetFrame {
        attribute sourceMac : String;
        attribute destinationMac : String;
        attribute vlanId : Integer;
        attribute payloadBytes : Integer;
    }

    item def IpPacket {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute protocol : String;
        attribute payloadBytes : Integer;
    }

    item def WifiFrame {
        attribute ssid : String;
        attribute stationMac : String;
        attribute channel : Integer;
        attribute receivedSignal : dBm;
        attribute payload : IpPacket;
    }

    item def ManagementCommand {
        attribute commandName : String;
        attribute authenticated : Boolean;
        attribute parameter : String;
    }

    item def TelemetryReport {
        attribute wanStatus : LinkStatus;
        attribute connectedClients : Integer;
        attribute cpuLoadPercent : Real;
        attribute enclosureTemperature : Celsius;
        attribute uptimeSeconds : Integer;
    }

    item def DcPower {
        attribute voltage : V;
        attribute current : A;
        attribute power : W;
    }

    port def WanDataPort {
        out item upstreamPacket : IpPacket;
        in item downstreamPacket : IpPacket;
        attribute status : LinkStatus;
        attribute lineRate : Mbps;
    }

    port def LanEthernetPort {
        in item clientFrame : EthernetFrame;
        out item gatewayFrame : EthernetFrame;
        attribute status : LinkStatus;
        attribute negotiatedRate : Mbps;
    }

    port def WifiRadioPort {
        in item uplinkFrame : WifiFrame;
        out item downlinkFrame : WifiFrame;
        attribute enabled : Boolean;
        attribute securityMode : SecurityMode;
        attribute frequency : GHz;
        attribute channel : Integer;
    }

    port def ManagementPort {
        in item command : ManagementCommand;
        out item telemetry : TelemetryReport;
    }

    port def PowerInputPort {
        in item supply : DcPower;
    }

    action def RoutePacket {
        in item packetIn : IpPacket;
        out item packetOut : IpPacket;
        attribute natApplied : Boolean;
        attribute firewallAllowed : Boolean;
    }

    action def AuthenticateWifiClient {
        in item associationRequest : WifiFrame;
        out accepted : Boolean;
        attribute selectedSecurityMode : SecurityMode;
    }

    action def AssignLocalAddress {
        in clientIdentifier : String;
        out assignedAddress : String;
        attribute leaseTimeSeconds : Integer;
    }

    action def PublishTelemetry {
        in item currentReport : TelemetryReport;
        out item reportOut : TelemetryReport;
    }

    state def GatewayOperatingState {
        entry action initializeHardware;
        state PowerOff;
        state Booting;
        state WanDiscovery;
        state Operational;
        state DegradedService;
        state FirmwareUpdate;
        state Fault;

        transition first PowerOff;
        transition PowerOff_to_Booting
            first PowerOff then Booting
            accept powerApplied;

        transition Booting_to_WanDiscovery
            first Booting then WanDiscovery
            accept bootComplete;

        transition WanDiscovery_to_Operational
            first WanDiscovery then Operational
            accept wanConnected;

        transition WanDiscovery_to_DegradedService
            first WanDiscovery then DegradedService
            accept wanUnavailable;

        transition Operational_to_DegradedService
            first Operational then DegradedService
            accept wanLinkDegraded;

        transition DegradedService_to_Operational
            first DegradedService then Operational
            accept wanRestored;

        transition Operational_to_FirmwareUpdate
            first Operational then FirmwareUpdate
            accept validUpdateCommand;

        transition FirmwareUpdate_to_Booting
            first FirmwareUpdate then Booting
            accept updateInstalled;

        transition Operational_to_Fault
            first Operational then Fault
            accept unrecoverableError;

        transition DegradedService_to_Fault
            first DegradedService then Fault
            accept unrecoverableError;

        transition Fault_to_Booting
            first Fault then Booting
            accept resetCommand;
    }

    part def ResidentialGateway {
        attribute modelName : String = "Integrated Residential Gateway";
        attribute maxLanClients : Integer = 128;
        attribute maxWifiClients : Integer = 64;
        attribute wanThroughputCapacity : Mbps = 1000.0 [Mbps];
        attribute lanSwitchingCapacity : Mbps = 4000.0 [Mbps];
        attribute wifi2GHzFrequency : GHz = 2.4 [GHz];
        attribute wifi5GHzFrequency : GHz = 5.0 [GHz];
        attribute nominalPowerConsumption : W = 18.0 [W];
        attribute maximumPowerConsumption : W = 30.0 [W];
        attribute normalOperatingTemperatureMax : Celsius = 45.0 [Celsius];

        port wan : WanDataPort;
        port lan1 : LanEthernetPort;
        port lan2 : LanEthernetPort;
        port lan3 : LanEthernetPort;
        port lan4 : LanEthernetPort;
        port wifi24 : WifiRadioPort;
        port wifi5 : WifiRadioPort;
        port management : ManagementPort;
        port powerInput : PowerInputPort;

        part broadbandModem {
            port networkSide : WanDataPort;
            attribute downstreamRate : Mbps = 1000.0 [Mbps];
            attribute upstreamRate : Mbps = 100.0 [Mbps];
            attribute status : LinkStatus;
        }

        part routerProcessor {
            port wanSide : WanDataPort;
            port lanSide : LanEthernetPort;
            attribute cpuClockRate : GHz = 1.4 [GHz];
            attribute packetForwardingLatency : ms = 2.0 [ms];

            perform action route : RoutePacket;
        }

        part firewall {
            attribute defaultInboundPolicy : String = "deny unsolicited inbound traffic";
            attribute defaultOutboundPolicy : String = "allow authenticated local outbound traffic";
            attribute stateTableEntries : Integer = 16384;
        }

        part natService {
            attribute publicAddress : String;
            attribute privateSubnet : String = "192.168.1.0/24";
            attribute translationEntries : Integer = 8192;
        }

        part dhcpServer {
            attribute poolStart : String = "192.168.1.100";
            attribute poolEnd : String = "192.168.1.199";
            attribute leaseTimeSeconds : Integer = 86400;

            perform action assignAddress : AssignLocalAddress;
        }

        part ethernetSwitch {
            port port1 : LanEthernetPort;
            port port2 : LanEthernetPort;
            port port3 : LanEthernetPort;
            port port4 : LanEthernetPort;
            attribute switchingCapacity : Mbps = 4000.0 [Mbps];
            attribute macAddressTableSize : Integer = 2048;
        }

        part wifiAccessPoint24 {
            port radio : WifiRadioPort;
            attribute ssid : String = "HomeGateway-2G";
            attribute securityMode : SecurityMode = SecurityMode::wpa3Personal;
            attribute maxClients : Integer = 32;
            attribute transmitPower : dBm = 20.0 [dBm];

            perform action authenticate : AuthenticateWifiClient;
        }

        part wifiAccessPoint5 {
            port radio : WifiRadioPort;
            attribute ssid : String = "HomeGateway-5G";
            attribute securityMode : SecurityMode = SecurityMode::wpa3Personal;
            attribute maxClients : Integer = 32;
            attribute transmitPower : dBm = 23.0 [dBm];

            perform action authenticate : AuthenticateWifiClient;
        }

        part managementAgent {
            port admin : ManagementPort;
            attribute localWebUiEnabled : Boolean = true;
            attribute remoteManagementEnabled : Boolean = false;
            attribute telemetryIntervalSeconds : Integer = 60;

            perform action publishTelemetry : PublishTelemetry;
        }

        part powerSubsystem {
            port dcInput : PowerInputPort;
            attribute inputVoltage : V = 12.0 [V];
            attribute maxInputCurrent : A = 2.5 [A];
            attribute regulated : Boolean = true;
        }

        exhibit state gatewayState : GatewayOperatingState;

        connect powerInput to powerSubsystem.dcInput;
        connect wan to broadbandModem.networkSide;
        connect broadbandModem.networkSide to routerProcessor.wanSide;
        connect routerProcessor.lanSide to ethernetSwitch.port1;
        connect lan1 to ethernetSwitch.port1;
        connect lan2 to ethernetSwitch.port2;
        connect lan3 to ethernetSwitch.port3;
        connect lan4 to ethernetSwitch.port4;
        connect wifi24 to wifiAccessPoint24.radio;
        connect wifi5 to wifiAccessPoint5.radio;
        connect management to managementAgent.admin;
    }

    part def ServiceProviderNetwork {
        port customerAccess : WanDataPort;
        attribute serviceName : String = "Residential broadband service";
        attribute committedDownstreamRate : Mbps = 500.0 [Mbps];
        attribute committedUpstreamRate : Mbps = 50.0 [Mbps];
    }

    part def HomeClientDevice {
        port networkInterface : LanEthernetPort;
        port wirelessInterface : WifiRadioPort;
        attribute deviceName : String;
        attribute assignedIpAddress : String;
        attribute authenticated : Boolean;
    }

    part residentialInternetAccessSystem {
        part gateway : ResidentialGateway;
        part providerNetwork : ServiceProviderNetwork;
        part laptop : HomeClientDevice {
            attribute deviceName : String = "Laptop";
        }
        part smartTv : HomeClientDevice {
            attribute deviceName : String = "Smart TV";
        }
        part phone : HomeClientDevice {
            attribute deviceName : String = "Phone";
        }

        connect providerNetwork.customerAccess to gateway.wan;
        connect laptop.networkInterface to gateway.lan1;
        connect smartTv.networkInterface to gateway.lan2;
        connect phone.wirelessInterface to gateway.wifi5;
    }

    requirement def PrimaryFunctionRequirement {
        subject gateway : ResidentialGateway;

        doc /* The residential gateway shall provide the primary high-level function of securely interconnecting home wired and wireless client devices with a broadband service provider network, while routing IP traffic, assigning local addresses, enforcing basic firewall protection, and exposing local management and telemetry. */

        require constraint {
            gateway.maxLanClients + gateway.maxWifiClients >= 128
        }

        require constraint {
            gateway.wanThroughputCapacity >= 500.0 [Mbps]
        }

        require constraint {
            gateway.nominalPowerConsumption <= 25.0 [W]
        }
    }

    requirement def SecureWirelessAccessRequirement {
        subject gateway : ResidentialGateway;

        require constraint {
            gateway.wifiAccessPoint24.securityMode == SecurityMode::wpa3Personal and
            gateway.wifiAccessPoint5.securityMode == SecurityMode::wpa3Personal
        }
    }

    requirement def LocalNetworkServiceRequirement {
        subject gateway : ResidentialGateway;

        require constraint {
            gateway.dhcpServer.leaseTimeSeconds >= 3600
        }

        require constraint {
            gateway.natService.translationEntries >= 4096
        }
    }

    requirement def AvailabilityBehaviorRequirement {
        subject gateway : ResidentialGateway;

        doc /* The gateway shall progress from power application through boot and WAN discovery to an operational state when a broadband link is available, and shall continue providing local network services in degraded service when WAN connectivity is unavailable. */
    }

    satisfy PrimaryFunctionRequirement by residentialInternetAccessSystem.gateway;
    satisfy SecureWirelessAccessRequirement by residentialInternetAccessSystem.gateway;
    satisfy LocalNetworkServiceRequirement by residentialInternetAccessSystem.gateway;
    satisfy AvailabilityBehaviorRequirement by residentialInternetAccessSystem.gateway;
}