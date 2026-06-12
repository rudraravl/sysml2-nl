package HomeNetworkSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def DataRate :> ISQ::dataRate {
        unit = "Mbit/s";
    }

    attribute def Frequency :> ISQ::frequency {
        unit = "GHz";
    }

    attribute def Latency :> ISQ::duration {
        unit = "ms";
    }

    attribute def Power :> ISQ::power {
        unit = "W";
    }

    attribute def SignalStrength {
        value rssi : Real;
        unit = "dBm";
    }

    attribute def IPAddress {
        value octet1 : Integer;
        value octet2 : Integer;
        value octet3 : Integer;
        value octet4 : Integer;
    }

    attribute def MACAddress {
        value addressText : String;
    }

    item def EthernetFrame {
        attribute sourceMac : MACAddress;
        attribute destinationMac : MACAddress;
        attribute payloadBytes : Integer;
        attribute vlanTag : Integer;
    }

    item def IPPacket {
        attribute sourceIp : IPAddress;
        attribute destinationIp : IPAddress;
        attribute protocol : String;
        attribute payloadBytes : Integer;
        attribute priorityClass : String;
    }

    item def WiFiSignal {
        attribute ssid : String;
        attribute band : Frequency;
        attribute channel : Integer;
        attribute strength : SignalStrength;
        attribute encrypted : Boolean;
    }

    item def InternetService {
        attribute downlinkCapacity : DataRate;
        attribute uplinkCapacity : DataRate;
        attribute providerName : String;
        attribute publicAddress : IPAddress;
    }

    item def NetworkCredential {
        attribute ssid : String;
        attribute passphraseHash : String;
        attribute securityMode : String;
    }

    port def EthernetPort {
        inout frame : EthernetFrame;
        attribute linkSpeed : DataRate;
        attribute linkUp : Boolean;
    }

    port def WANPort :> EthernetPort {
        in service : InternetService;
    }

    port def WiFiRadioPort {
        inout signal : WiFiSignal;
        inout packet : IPPacket;
        attribute band : Frequency;
        attribute maxThroughput : DataRate;
        attribute channel : Integer;
        attribute enabled : Boolean;
    }

    port def PowerPort {
        in powerInput : Power;
        attribute energized : Boolean;
    }

    port def ManagementPort {
        in command : String;
        out status : String;
    }

    port def ApplicationDataPort {
        inout packet : IPPacket;
        attribute averageLatency : Latency;
    }

    action def RoutePacket {
        in packetIn : IPPacket;
        out packetOut : IPPacket;
        attribute selectedInterface : String;
        attribute natApplied : Boolean;
    }

    action def AuthenticateWirelessClient {
        in credential : NetworkCredential;
        out authorized : Boolean;
        attribute failureReason : String;
    }

    action def AssignLocalAddress {
        in clientMac : MACAddress;
        out assignedIp : IPAddress;
        attribute leaseSeconds : Integer;
    }

    action def PrioritizeTraffic {
        in packetIn : IPPacket;
        out packetOut : IPPacket;
        attribute priorityClass : String;
    }

    action def MonitorConnectivity {
        out internetReachable : Boolean;
        out localNetworkHealthy : Boolean;
        attribute measuredLatency : Latency;
    }

    state def RouterOperationalState {
        entry action initializeHardware;
        state PoweredOff;
        state Booting;
        state WANDisconnected;
        state Online;
        state Degraded;
        state Maintenance;

        transition initial then PoweredOff;
        transition PoweredOff_to_Booting first PoweredOff then Booting
            accept PowerApplied;
        transition Booting_to_WANDisconnected first Booting then WANDisconnected
            accept BootComplete;
        transition WANDisconnected_to_Online first WANDisconnected then Online
            accept WANLinkEstablished;
        transition Online_to_Degraded first Online then Degraded
            accept ExcessivePacketLoss;
        transition Degraded_to_Online first Degraded then Online
            accept ConnectivityRestored;
        transition Online_to_Maintenance first Online then Maintenance
            accept AdminMaintenanceRequested;
        transition Maintenance_to_Online first Maintenance then Online
            accept MaintenanceCompleted;
        transition Online_to_WANDisconnected first Online then WANDisconnected
            accept WANLinkLost;
        transition WANDisconnected_to_PoweredOff first WANDisconnected then PoweredOff
            accept PowerRemoved;
    }

    part def InternetGateway {
        port power : PowerPort;
        port wan : WANPort;
        port lan1 : EthernetPort;
        port lan2 : EthernetPort;
        port management : ManagementPort;

        attribute routingCapacity : DataRate = 1000 [Mbit/s];
        attribute firewallEnabled : Boolean = true;
        attribute dhcpEnabled : Boolean = true;
        attribute natEnabled : Boolean = true;
        attribute privateGatewayAddress : IPAddress;

        perform action routePacket : RoutePacket;
        perform action assignAddress : AssignLocalAddress;
        perform action monitor : MonitorConnectivity;

        exhibit state operationalState : RouterOperationalState;
    }

    part def WirelessAccessPoint {
        port power : PowerPort;
        port uplink : EthernetPort;
        port radio24 : WiFiRadioPort;
        port radio5 : WiFiRadioPort;
        port management : ManagementPort;

        attribute primarySsid : String = "HomeNetwork";
        attribute guestSsid : String = "HomeNetwork-Guest";
        attribute maxAssociatedClients : Integer = 64;
        attribute securityMode : String = "WPA3-Personal";
        attribute transmitPower : Power = 0.2 [W];

        perform action authenticateClient : AuthenticateWirelessClient;
        perform action prioritizeWirelessTraffic : PrioritizeTraffic;
    }

    part def NetworkSwitch {
        port power : PowerPort;
        port uplink : EthernetPort;
        port port1 : EthernetPort;
        port port2 : EthernetPort;
        port port3 : EthernetPort;
        port port4 : EthernetPort;

        attribute switchingCapacity : DataRate = 2000 [Mbit/s];
        attribute supportsVlan : Boolean = true;
        attribute activePortCount : Integer;
    }

    part def BroadbandModem {
        port power : PowerPort;
        port serviceInput : WANPort;
        port customerEthernet : EthernetPort;
        port management : ManagementPort;

        attribute downstreamSyncRate : DataRate = 1000 [Mbit/s];
        attribute upstreamSyncRate : DataRate = 40 [Mbit/s];
        attribute providerProvisioned : Boolean = true;
    }

    part def SmartHomeHub {
        port power : PowerPort;
        port network : EthernetPort;
        port applicationData : ApplicationDataPort;

        attribute localAddress : IPAddress;
        attribute registeredDeviceCount : Integer;
        attribute automationRulesEnabled : Boolean = true;
    }

    part def PersonalComputer {
        port network : EthernetPort;
        port applicationData : ApplicationDataPort;

        attribute hostName : String;
        attribute localAddress : IPAddress;
        attribute mac : MACAddress;
        attribute typicalDownlinkNeed : DataRate = 100 [Mbit/s];
    }

    part def MobileDevice {
        port wifi : WiFiRadioPort;
        port applicationData : ApplicationDataPort;

        attribute deviceName : String;
        attribute localAddress : IPAddress;
        attribute mac : MACAddress;
        attribute roamingEnabled : Boolean = true;
    }

    part def NetworkPrinter {
        port network : EthernetPort;
        port applicationData : ApplicationDataPort;

        attribute printerName : String;
        attribute localAddress : IPAddress;
        attribute supportsSecurePrint : Boolean = true;
    }

    part def StreamingTelevision {
        port wifi : WiFiRadioPort;
        port applicationData : ApplicationDataPort;

        attribute displayName : String;
        attribute localAddress : IPAddress;
        attribute requiredVideoRate : DataRate = 25 [Mbit/s];
    }

    part def HomeNetwork {
        port providerService : WANPort;
        port adminInterface : ManagementPort;

        part modem : BroadbandModem;
        part gateway : InternetGateway;
        part switch : NetworkSwitch;
        part accessPoint : WirelessAccessPoint;
        part smartHub : SmartHomeHub;
        part workstation : PersonalComputer {
            attribute hostName = "HomeOfficePC";
        }
        part familyLaptop : PersonalComputer {
            attribute hostName = "FamilyLaptop";
        }
        part residentPhone : MobileDevice {
            attribute deviceName = "ResidentPhone";
        }
        part guestTablet : MobileDevice {
            attribute deviceName = "GuestTablet";
        }
        part printer : NetworkPrinter {
            attribute printerName = "StudyPrinter";
        }
        part livingRoomTv : StreamingTelevision {
            attribute displayName = "LivingRoomTV";
        }

        connection provider_to_modem
            connect providerService to modem.serviceInput;

        connection modem_to_gateway
            connect modem.customerEthernet to gateway.wan;

        connection gateway_to_switch
            connect gateway.lan1 to switch.uplink;

        connection switch_to_accessPoint
            connect switch.port1 to accessPoint.uplink;

        connection switch_to_workstation
            connect switch.port2 to workstation.network;

        connection switch_to_printer
            connect switch.port3 to printer.network;

        connection switch_to_smartHub
            connect switch.port4 to smartHub.network;

        connection accessPoint_to_phone
            connect accessPoint.radio5 to residentPhone.wifi;

        connection accessPoint_to_tablet
            connect accessPoint.radio24 to guestTablet.wifi;

        connection accessPoint_to_tv
            connect accessPoint.radio5 to livingRoomTv.wifi;

        connection admin_to_gateway
            connect adminInterface to gateway.management;

        attribute privateSubnet : String = "192.168.10.0/24";
        attribute guestSubnet : String = "192.168.30.0/24";
        attribute targetHouseholdCoverageArea : Real = 250.0;
        attribute targetHouseholdCoverageAreaUnit : String = "m^2";
        attribute minimumInternetDownlink : DataRate = 300 [Mbit/s];
        attribute minimumInternetUplink : DataRate = 20 [Mbit/s];
        attribute maximumInternalLatency : Latency = 10 [ms];
        attribute requiredAvailability : Real = 0.995;

        perform action monitorNetwork : MonitorConnectivity;
        perform action routeTraffic : RoutePacket;
        perform action prioritizeTraffic : PrioritizeTraffic;
    }

    requirement def ProvideHouseholdConnectivity {
        doc
        /* The home network shall provide shared local and internet connectivity for wired and wireless household devices. */
        subject network : HomeNetwork;
        require constraint {
            network.minimumInternetDownlink >= 300 [Mbit/s]
        }
    }

    requirement def SupportSecureWirelessAccess {
        doc
        /* The wireless access point shall authenticate resident and guest devices using encrypted wireless credentials. */
        subject ap : WirelessAccessPoint;
        require constraint {
            ap.securityMode == "WPA3-Personal"
        }
    }

    requirement def SegmentGuestTraffic {
        doc
        /* The home network shall separate guest wireless traffic from trusted household device traffic. */
        subject network : HomeNetwork;
        require constraint {
            network.guestSubnet != network.privateSubnet
        }
    }

    requirement def MaintainLowLocalLatency {
        doc
        /* The home network shall keep normal local packet latency below the target maximum for household applications. */
        subject network : HomeNetwork;
        require constraint {
            network.maximumInternalLatency <= 10 [ms]
        }
    }

    requirement def ProvideFirewallProtection {
        doc
        /* The internet gateway shall filter unsolicited inbound internet traffic before it reaches household devices. */
        subject gateway : InternetGateway;
        require constraint {
            gateway.firewallEnabled == true
        }
    }

    requirement def AssignPrivateAddresses {
        doc
        /* The internet gateway shall assign private IP addresses to local devices through DHCP. */
        subject gateway : InternetGateway;
        require constraint {
            gateway.dhcpEnabled == true
        }
    }

    requirement def SupportMediaStreaming {
        doc
        /* The home network shall support high-definition media streaming to the living room television while other devices remain connected. */
        subject tv : StreamingTelevision;
        require constraint {
            tv.requiredVideoRate <= 25 [Mbit/s]
        }
    }

    requirement def HomeNetworkPrimaryFunction {
        doc
        /* The primary function of the home network is to interconnect household computing, entertainment, printing, and smart-home devices and to provide them secure, managed access to internet services and local shared resources. */
        subject network : HomeNetwork;
        require ProvideHouseholdConnectivity;
        require SupportSecureWirelessAccess;
        require SegmentGuestTraffic;
        require MaintainLowLocalLatency;
        require ProvideFirewallProtection;
        require AssignPrivateAddresses;
        require SupportMediaStreaming;
    }

    package Verification {
        part testNetwork : HomeNetwork;

        satisfy ProvideHouseholdConnectivity by testNetwork;
        satisfy SegmentGuestTraffic by testNetwork;
        satisfy MaintainLowLocalLatency by testNetwork;
        satisfy HomeNetworkPrimaryFunction by testNetwork;
    }
}