package ResidentialNetworkSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def IPAddress :> String;
    attribute def MACAddress :> String;
    attribute def FrequencyValue :> Real;
    attribute def SignalStrengthValue :> Real;
    attribute def DataRateValue :> Real;

    item def DataPacket {
        attribute sourceIP : IPAddress;
        attribute destIP : IPAddress;
        attribute payloadSize : Integer;
    }
    item def VideoStream :> DataPacket {
        attribute resolution : String;
        attribute frameRate : Real;
    }
    item def SensorData :> DataPacket {
        attribute temperature : Real;
        attribute humidity : Real;
    }

    port def EthernetPort {
        in item dataIn : DataPacket;
        out item dataOut : DataPacket;
        attribute macAddress : MACAddress;
        attribute linkSpeed : DataRateValue;
    }

    port def WiFiPort {
        in item dataIn : DataPacket;
        out item dataOut : DataPacket;
        attribute ssid : String;
        attribute frequency : FrequencyValue;
        attribute signalStrength : SignalStrengthValue;
    }

    port def WANPort {
        in item internetIn : DataPacket;
        out item internetOut : DataPacket;
        attribute linkSpeed : DataRateValue;
    }

    connection def EthernetCable {
        end a : EthernetPort;
        end b : EthernetPort;
        attribute length : Real;
        attribute category : String = "Cat6";
    }

    connection def WiFiLink {
        end a : WiFiPort;
        end b : WiFiPort;
        attribute frequency : FrequencyValue;
    }

    connection def WANLink {
        end a : WANPort;
        end b : WANPort;
    }

    part def ISP {
        port wanInterface : WANPort;
        attribute providerName : String;
    }

    part def Router {
        port wanPort : WANPort;
        port lanPort1 : EthernetPort;
        port lanPort2 : EthernetPort;
        port wifiPort : WiFiPort;

        attribute firewallEnabled : Boolean = true;
        attribute dhcpEnabled : Boolean = true;
        attribute assignedIPs : IPAddress[0..*];

        part firewall {
            action filterTraffic {
                in packet : DataPacket;
                out result : Boolean;
            }
        }

        part dhcpServer {
            attribute addressPoolStart : IPAddress;
            attribute addressPoolEnd : IPAddress;
            action assignIP {
                in mac : MACAddress;
                out ip : IPAddress;
            }
        }

        action forwardPacket {
            in packet : DataPacket;
        }
        action routeToInternet {
            in packet : DataPacket;
        }
        action routeToLocal {
            in packet : DataPacket;
        }
    }

    part def NetworkSwitch {
        port uplinkPort : EthernetPort;
        port lanPort1 : EthernetPort;
        port lanPort2 : EthernetPort;
        port lanPort3 : EthernetPort;
        port lanPort4 : EthernetPort;

        action forwardPacket {
            in packet : DataPacket;
            in ingressPort : Integer;
            out egressPort : Integer;
        }
    }

    part def WirelessAccessPoint {
        port ethernetPort : EthernetPort;
        port wifiPort : WiFiPort;

        attribute ssid : String;
        attribute securityProtocol : String = "WPA3";

        action authenticateDevice {
            in mac : MACAddress;
            out result : Boolean;
        }
        action bridgeTraffic {
            in wirelessPacket : DataPacket;
            out wiredPacket : DataPacket;
        }
    }

    part def WiredDevice {
        port ethPort : EthernetPort;
        attribute ipAddress : IPAddress;
    }

    part def WirelessDevice {
        port wifiPort : WiFiPort;
        attribute ipAddress : IPAddress;
    }

    part def DesktopPC :> WiredDevice {
        attribute cpuCores : Integer;
        attribute ramGB : Integer;
    }

    part def SmartTV :> WiredDevice {
        attribute screenResolution : String;
    }

    part def SecurityCamera :> WiredDevice {
        out item videoFeed : VideoStream;
        action streamVideo {
            out video : VideoStream;
        }
    }

    part def Laptop :> WirelessDevice {
        attribute batteryCapacity : Real;
    }

    part def Smartphone :> WirelessDevice {
        attribute osVersion : String;
    }

    part def SmartThermostat :> WirelessDevice {
        out item sensorReading : SensorData;
        action sendReading {
            out data : SensorData;
        }
    }

    state machine def NetworkOperationalStates {
        in routerRef : Router;

        state Initializing;
        state Operational;
        state Degraded;
        state Offline;

        transition first to Initializing;
        transition Initializing to Operational
            when (routerRef.dhcpEnabled);
        transition Operational to Degraded
            when (routerRef.wifiPort.signalStrength < -70.0);
        transition Operational to Offline
            when (routerRef.wanPort.linkSpeed == 0.0);
        transition Degraded to Operational
            when (routerRef.wifiPort.signalStrength >= -70.0);
        transition Degraded to Offline
            when (routerRef.wanPort.linkSpeed == 0.0);
        transition Offline to Initializing
            when (true);
    }

    requirement def ProvideInternetAccess {
        doc /* The system shall provide internet access to all connected devices. */
    }

    requirement def NetworkSecurity {
        doc /* The router firewall shall filter unauthorized incoming traffic. */
        attribute firewallActive : Boolean = true;
    }

    requirement def DHCPAssignment {
        doc /* The DHCP server shall automatically assign IP addresses to new devices. */
    }

    requirement def WirelessCoverage {
        doc /* The wireless access point shall extend WiFi coverage to the bedroom area. */
    }

    requirement def SystemReliability {
        doc /* The system shall transition to degraded state upon link failure and attempt recovery. */
    }

    part homeNetwork {
        part isp : ISP;
        part router : Router;
        part livingRoomSwitch : NetworkSwitch;
        part bedroomAP : WirelessAccessPoint;
        part desktopPC : DesktopPC;
        part smartTV : SmartTV;
        part securityCam1 : SecurityCamera;
        part securityCam2 : SecurityCamera;
        part laptop : Laptop;
        part smartphone : Smartphone;
        part thermostat : SmartThermostat;

        exhibit networkStates : NetworkOperationalStates {
            in routerRef = router;
        }

        connect router.wanPort to isp.wanInterface;
        connect router.lanPort1 to livingRoomSwitch.uplinkPort;
        connect router.lanPort2 to bedroomAP.ethernetPort;
        connect livingRoomSwitch.lanPort1 to desktopPC.ethPort;
        connect livingRoomSwitch.lanPort2 to smartTV.ethPort;
        connect livingRoomSwitch.lanPort3 to securityCam1.ethPort;
        connect livingRoomSwitch.lanPort4 to securityCam2.ethPort;
        connect laptop.wifiPort to router.wifiPort;
        connect smartphone.wifiPort to bedroomAP.wifiPort;
        connect thermostat.wifiPort to bedroomAP.wifiPort;

        flow securityCam1.videoFeed to livingRoomSwitch.lanPort3.dataIn;
        flow securityCam2.videoFeed to livingRoomSwitch.lanPort4.dataIn;
        flow thermostat.sensorReading to bedroomAP.wifiPort.dataIn;

        requirement req_internet : ProvideInternetAccess;
        requirement req_security : NetworkSecurity;
        requirement req_dhcp : DHCPAssignment;
        requirement req_coverage : WirelessCoverage;
        requirement req_reliability : SystemReliability;

        satisfy req_internet by router;
        satisfy req_security by router.firewall;
        satisfy req_dhcp by router.dhcpServer;
        satisfy req_coverage by bedroomAP;
        satisfy req_reliability by router;
    }
}
