package HomeNetwork {

    import ScalarValues::*;

    // ===== Unit Definitions =====

    unit bps;
    unit dBm;
    unit packets;
    unit degC;

    // ===== Value Types =====

    value type DataRate :> Real {
        unit bps;
    }

    value type SignalStrength :> Real {
        unit dBm;
    }

    value type PacketCount :> Integer {
        unit packets;
    }

    value type Temperature :> Real {
        unit degC;
    }

    value type IPAddressValue :> String;
    value type MACAddress :> String;
    value type SSID :> String;

    // ===== Item Definitions =====

    item def DataPacket {
        attribute sourceIP : IPAddressValue;
        attribute destinationIP : IPAddressValue;
        attribute payloadSize : Integer;
        attribute protocol : String;
        attribute isAuthorized : Boolean := false;
    }

    item def VideoStream :> DataPacket {
        attribute resolution : String;
        attribute frameRate : Integer;
    }

    item def SensorReading :> DataPacket {
        attribute temperature : Temperature;
        attribute timestamp : String;
    }

    item def DHCPRequest :> DataPacket {
        attribute requestingMAC : MACAddress;
    }

    item def DHCPResponse :> DataPacket {
        attribute assignedIP : IPAddressValue;
        attribute leaseDuration : Integer;
    }

    item def AuthRequest :> DataPacket {
        attribute deviceMAC : MACAddress;
        attribute credentials : String;
    }

    item def AuthResponse :> DataPacket {
        attribute authenticated : Boolean;
    }

    // ===== Port Definitions =====

    port def EthernetPort {
        attribute speed : DataRate;
        in item incomingPackets : DataPacket[*];
        out item outgoingPackets : DataPacket[*];
    }

    port def WANPort {
        attribute speed : DataRate;
        in item inboundTraffic : DataPacket[*];
        out item outboundTraffic : DataPacket[*];
    }

    port def WiFiPort {
        attribute ssid : SSID;
        attribute signalStrength : SignalStrength;
        in item receivedPackets : DataPacket[*];
        out item transmittedPackets : DataPacket[*];
    }

    // ===== Component Part Definitions =====

    part def ISP {
        port wanInterface : WANPort;
        attribute serviceName : String;

        action provideInternetAccess {
            in item request : DataPacket;
            out item response : DataPacket;
        }
    }

    part def Firewall {
        attribute filterRules : String[*];
        attribute blockedPacketCount : PacketCount := 0;

        action filterTraffic {
            in item incomingPacket : DataPacket;
            out item filteredPacket : DataPacket;
        }

        action updateRules {
            in item newRules : String[*];
        }
    }

    part def DHCPServer {
        attribute addressPool : IPAddressValue[*];
        attribute assignedAddresses : IPAddressValue[*];
        attribute leaseDuration : Integer;

        action assignAddress {
            in item request : DHCPRequest;
            out item response : DHCPResponse;
        }

        action releaseAddress {
            in item macAddress : MACAddress;
        }
    }

    part def Router {
        port wanPort : WANPort;
        port lanPorts : EthernetPort[4];
        port wifiPort : WiFiPort;

        part firewall : Firewall;
        part dhcpServer : DHCPServer;

        attribute maxThroughput : DataRate;
        attribute currentThroughput : DataRate;
        attribute throughputThreshold : DataRate;
        attribute isOperational : Boolean := false;
        attribute initializationComplete : Boolean := false;
        attribute throughputDegraded : Boolean := false;
        attribute powerFailure : Boolean := false;
        attribute powerRestored : Boolean := false;

        action forwardPacket {
            in item packet : DataPacket;
            out item forwardedPacket : DataPacket;
        }

        action inspectPacket {
            in item packet : DataPacket;
            out item inspectedPacket : DataPacket;
        }

        action routeToInternal {
            in item packet : DataPacket;
            out item internalPacket : DataPacket;
        }

        action routeToInternet {
            in item packet : DataPacket;
            out item externalPacket : DataPacket;
        }

        state routerOperation {
            state Initializing {
                entry action {
                    firewall.filterRules := {'drop_inbound_unsolicited', 'allow_outbound_all', 'drop_malicious_ips'};
                    initializationComplete := true;
                }
            }

            state Operational {
                entry action {
                    isOperational := true;
                    throughputDegraded := false;
                }
            }

            state Degraded {
                entry action {
                    throughputDegraded := true;
                }
            }

            state Offline {
                entry action {
                    isOperational := false;
                }
            }

            transition init_to_operational
                source Initializing
                target Operational
                when initializationComplete;

            transition operational_to_degraded
                source Operational
                target Degraded
                when currentThroughput < throughputThreshold;

            transition degraded_to_operational
                source Degraded
                target Operational
                when currentThroughput >= throughputThreshold;

            transition operational_to_offline
                source Operational
                target Offline
                when powerFailure;

            transition degraded_to_offline
                source Degraded
                target Offline
                when powerFailure;

            transition offline_to_initializing
                source Offline
                target Initializing
                when powerRestored;
        }
    }

    part def NetworkSwitch {
        port uplinkPort : EthernetPort;
        port devicePorts : EthernetPort[8];
        attribute switchingCapacity : DataRate;
        attribute portCount : Integer;
        attribute macTable : MACAddress[*];

        action directTraffic {
            in item packet : DataPacket;
            out item forwardedPacket : DataPacket;
        }

        action learnMACAddress {
            in item macAddress : MACAddress;
            in item portId : Integer;
        }
    }

    part def WirelessAccessPoint {
        port uplinkPort : EthernetPort;
        port wifiPort : WiFiPort;
        attribute ssid : SSID;
        attribute securityProtocol : String;
        attribute maxClients : Integer;
        attribute connectedClients : Integer := 0;

        action authenticateDevice {
            in item request : AuthRequest;
            out item response : AuthResponse;
        }

        action bridgeTraffic {
            in item wirelessPacket : DataPacket;
            out item wiredPacket : DataPacket;
        }

        action broadcastBeacon {
            out item beacon : DataPacket;
        }
    }

    // ===== Device Part Definitions =====

    part def NetworkDevice {
        attribute ipAddress : IPAddressValue;
        attribute macAddress : MACAddress;
        attribute deviceName : String;
    }

    part def WiredDevice :> NetworkDevice {
        port ethernetPort : EthernetPort;
    }

    part def WirelessDevice :> NetworkDevice {
        port wifiPort : WiFiPort;
    }

    part def DesktopPC :> WiredDevice {
        action browseWeb {
            out item request : DataPacket;
            in item response : DataPacket;
        }

        action syncData {
            out item syncRequest : DataPacket;
            in item syncResponse : DataPacket;
        }
    }

    part def SmartTV :> WiredDevice {
        action streamContent {
            in item stream : DataPacket;
        }

        action displayVideo {
            in item video : VideoStream;
        }
    }

    part def SecurityCamera :> WiredDevice {
        attribute cameraId : String;
        attribute isRecording : Boolean := false;

        action streamVideo {
            out item videoFeed : VideoStream;
        }

        action startRecording {
            assign isRecording := true;
        }

        action stopRecording {
            assign isRecording := false;
        }
    }

    part def Laptop :> WirelessDevice {
        action browseWeb {
            out item request : DataPacket;
            in item response : DataPacket;
        }

        action syncData {
            out item syncRequest : DataPacket;
            in item syncResponse : DataPacket;
        }
    }

    part def Smartphone :> WirelessDevice {
        action browseWeb {
            out item request : DataPacket;
            in item response : DataPacket;
        }

        action receiveNotifications {
            in item notification : DataPacket;
        }
    }

    part def SmartThermostat :> WirelessDevice {
        attribute currentTemperature : Temperature;
        attribute targetTemperature : Temperature;

        action sendSensorReading {
            out item reading : SensorReading;
        }

        action adjustTemperature {
            in item command : DataPacket;
        }
    }

    // ===== System Definition =====

    part def HomeNetworkSystem {
        attribute systemName : String := 'ResidentialHomeNetwork';

        part isp : ISP {
            attribute serviceName := 'ComcastHome';
        }

        part router : Router {
            attribute maxThroughput := 1000000000;
            attribute throughputThreshold := 100000000;
            part firewall : Firewall {
                attribute filterRules := {'drop_inbound_unsolicited', 'allow_outbound_all', 'drop_malicious_ips'};
            }
            part dhcpServer : DHCPServer {
                attribute addressPool := {'192.168.1.100', '192.168.1.101', '192.168.1.102', '192.168.1.103', '192.168.1.104', '192.168.1.105', '192.168.1.106', '192.168.1.107', '192.168.1.108', '192.168.1.109'};
                attribute leaseDuration := 86400;
            }
        }

        part livingRoomSwitch : NetworkSwitch {
            attribute switchingCapacity := 1000000000;
            attribute portCount := 8;
        }

        part bedroomAP : WirelessAccessPoint {
            attribute ssid := 'HomeNetwork_Bedroom';
            attribute securityProtocol := 'WPA3';
            attribute maxClients := 32;
        }

        part desktopPC : DesktopPC {
            attribute deviceName := 'OfficePC';
            attribute macAddress := '00:1A:2B:3C:4D:01';
        }

        part smartTV : SmartTV {
            attribute deviceName := 'LivingRoomTV';
            attribute macAddress := '00:1A:2B:3C:4D:02';
        }

        part securityCamera1 : SecurityCamera {
            attribute deviceName := 'FrontDoorCamera';
            attribute cameraId := 'CAM-001';
            attribute macAddress := '00:1A:2B:3C:4D:03';
        }

        part securityCamera2 : SecurityCamera {
            attribute deviceName := 'BackyardCamera';
            attribute cameraId := 'CAM-002';
            attribute macAddress := '00:1A:2B:3C:4D:04';
        }

        part laptop : Laptop {
            attribute deviceName := 'WorkLaptop';
            attribute macAddress := '00:1A:2B:3C:4D:05';
        }

        part smartphone : Smartphone {
            attribute deviceName := 'PersonalPhone';
            attribute macAddress := '00:1A:2B:3C:4D:06';
        }

        part smartThermostat : SmartThermostat {
            attribute deviceName := 'NestThermostat';
            attribute macAddress := '00:1A:2B:3C:4D:07';
            attribute targetTemperature := 22.0;
        }

        // ===== Connections =====

        connect isp.wanInterface to router.wanPort;
        connect router.lanPorts[1] to livingRoomSwitch.uplinkPort;
        connect router.lanPorts[2] to bedroomAP.uplinkPort;
        connect livingRoomSwitch.devicePorts[1] to desktopPC.ethernetPort;
        connect livingRoomSwitch.devicePorts[2] to smartTV.ethernetPort;
        connect livingRoomSwitch.devicePorts[3] to securityCamera1.ethernetPort;
        connect livingRoomSwitch.devicePorts[4] to securityCamera2.ethernetPort;
        connect router.wifiPort to smartphone.wifiPort;
        connect router.wifiPort to smartThermostat.wifiPort;
        connect bedroomAP.wifiPort to laptop.wifiPort;

        // ===== System-Level State Machine =====

        state systemOperation {
            state Initializing;
            state Operational;
            state Degraded;
            state Offline;

            transition init_to_op
                source Initializing
                target Operational
                when router.initializationComplete;

            transition op_to_degraded
                source Operational
                target Degraded
                when router.throughputDegraded;

            transition degraded_to_op
                source Degraded
                target Operational
                when not router.throughputDegraded;

            transition op_to_offline
                source Operational
                target Offline
                when router.powerFailure;

            transition degraded_to_offline
                source Degraded
                target Offline
                when router.powerFailure;

            transition offline_to_init
                source Offline
                target Initializing
                when router.powerRestored;
        }
    }

    // ===== Requirements =====

    requirement def InternetConnectivityRequirement {
        subject system : HomeNetworkSystem;
        objective : 'The system shall provide internet access to all connected devices via the ISP connection through the router WAN port.';
    }

    requirement def WiredConnectivityRequirement {
        subject system : HomeNetworkSystem;
        objective : 'The system shall provide wired Ethernet connectivity to stationary devices including the desktop PC, smart TV, and two security cameras via the network switch.';
    }

    requirement def WirelessConnectivityRequirement {
        subject system : HomeNetworkSystem;
        objective : 'The system shall provide wireless connectivity throughout the home via the router built-in WiFi and the bedroom wireless access point.';
    }

    requirement def SecurityFilteringRequirement {
        subject router : Router;
        objective : 'The router firewall shall filter incoming traffic to protect against unauthorized access by applying filter rules to all inbound packets.';
    }

    requirement def DHCPRequirement {
        subject router : Router;
        objective : 'The DHCP server shall automatically assign network addresses to new devices as they connect to the network.';
    }

    requirement def VideoStreamingRequirement {
        subject camera : SecurityCamera;
        objective : 'Each security camera shall stream live video feeds over the network as VideoStream packets to designated monitoring destinations.';
    }

    requirement def RecoveryRequirement {
        subject system : HomeNetworkSystem;
        objective : 'The system shall attempt to recover from failures and return to operational state from degraded or offline states when conditions normalize.';
    }

    requirement def WirelessAuthenticationRequirement {
        subject ap : WirelessAccessPoint;
        objective : 'The access point shall authenticate wireless devices before bridging their traffic to the wired network.';
    }

    requirement def PacketForwardingRequirement {
        subject router : Router;
        objective : 'The router shall inspect each data packet to determine its destination and forward it either to another device inside the home or out to the internet.';
    }

    requirement def SwitchTrafficDirectionRequirement {
        subject sw : NetworkSwitch;
        objective : 'The network switch shall efficiently direct traffic between the wired devices connected to it based on destination MAC addresses.';
    }

    requirement def OperationalStatesRequirement {
        subject system : HomeNetworkSystem;
        objective : 'The system shall support operational states including initializing, fully operational, degraded performance, and offline, with transitions governed by throughput, power, and initialization conditions.';
    }

    requirement def SensorDataTransmissionRequirement {
        subject thermostat : SmartThermostat;
        objective : 'The smart thermostat shall transmit sensor readings including temperature data over the wireless network to cloud synchronization services.';
    }

}
