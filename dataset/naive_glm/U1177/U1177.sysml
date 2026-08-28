package ResidentialGatewayModel {
    import ScalarValues::*;
    
    attribute def IPv4Address :> String;
    attribute def MACAddress :> String;
    attribute def SSID :> String;
    attribute def WPAKey :> String;
    attribute def DomainName :> String;
    
    value type DataRate :> Real { unit "bps"; }
    value type DataSize :> Real { unit "bytes"; }
    value type SignalStrength :> Real { unit "dBm"; }
    value type Frequency :> Real { unit "GHz"; }
    
    item def DataPacket {
        attribute srcIP : IPv4Address;
        attribute dstIP : IPv4Address;
        attribute srcMAC : MACAddress;
        attribute dstMAC : MACAddress;
        attribute payloadSize : DataSize;
        attribute protocol : String;
    }
    
    item def NatMapping {
        attribute internalIP : IPv4Address;
        attribute internalPort : Integer;
        attribute externalPort : Integer;
        attribute protocol : String;
    }
    
    item def SecurityRule {
        attribute ruleId : Integer;
        attribute action : String;
        attribute srcIP : IPv4Address;
        attribute dstIP : IPv4Address;
        attribute port : Integer;
    }
    
    item def DhcpLease {
        attribute clientMAC : MACAddress;
        attribute assignedIP : IPv4Address;
        attribute leaseTime : Integer;
    }
    
    item def DnsRecord {
        attribute domain : DomainName;
        attribute resolvedIP : IPv4Address;
        attribute ttl : Integer;
    }
    
    item def GatewayStatus {
        attribute cpuUsage : Real;
        attribute uptime : Integer;
        attribute internetConnected : Boolean;
    }
    
    item def GatewayConfig {
        attribute ssid : SSID;
        attribute wifiPassword : WPAKey;
        attribute adminPassword : WPAKey;
    }

    port def WANPort {
        in dataIn : DataPacket;
        out dataOut : DataPacket;
    }
    
    port def LANPort {
        in dataIn : DataPacket;
        out dataOut : DataPacket;
    }
    
    port def WirelessPort {
        in dataIn : DataPacket;
        out dataOut : DataPacket;
    }
    
    port def InternalDataPort {
        in inPackets : DataPacket;
        out outPackets : DataPacket;
    }
    
    port def ManagementPort {
        in configData : GatewayConfig;
        out statusData : GatewayStatus;
    }
    
    part def WANInterface {
        attribute publicIPAddress : IPv4Address;
        attribute linkRate : DataRate;
        
        port externalWAN : WANPort;
        port internalOut : InternalDataPort;
        
        action receiveFromInternet {
            in packet : DataPacket;
        }
        action sendToInternet {
            out packet : DataPacket;
        }
    }
    
    part def WirelessAccessPoint {
        attribute ssid : SSID;
        attribute encryptionKey : WPAKey;
        attribute frequencyBand : Frequency;
        attribute txPower : SignalStrength;
        attribute connectedDevices : MACAddress[0..*];
        
        port wirelessPort : WirelessPort;
        port internalPort : InternalDataPort;
        
        action broadcastSSID;
        action authenticateDevice {
            in mac : MACAddress;
            in key : WPAKey;
            out success : Boolean;
        }
    }
    
    part def EthernetSwitch {
        attribute portCount : Integer = 4;
        
        port lanPorts : LANPort[4];
        port internalPort : InternalDataPort;
        
        action forwardFrame {
            in frame : DataPacket;
            out frame : DataPacket;
        }
    }
    
    part def FirewallNatModule {
        attribute securityRules : SecurityRule[0..*];
        attribute natTable : NatMapping[0..*];
        attribute publicIP : IPv4Address;
        
        port upstreamPort : InternalDataPort;
        port downstreamPort : InternalDataPort;
        
        action screenIncoming {
            in packet : DataPacket;
            out allowed : Boolean;
        }
        action translateOutgoing {
            in packet : DataPacket;
            out translatedPacket : DataPacket;
        }
        action determineInternalDestination {
            in packet : DataPacket;
            out internalIP : IPv4Address;
        }
    }
    
    part def RoutingEngine {
        attribute routingTable : IPv4Address[0..*];
        
        port upstreamPort : InternalDataPort;
        port ethernetPort : InternalDataPort;
        port wifiPort : InternalDataPort;
        
        action routePacket {
            in packet : DataPacket;
            out interfaceType : String;
        }
    }
    
    part def DhcpService {
        attribute leasePool : DhcpLease[0..*];
        attribute subnet : IPv4Address;
        attribute gatewayIP : IPv4Address;
        attribute dnsIP : IPv4Address;
        attribute startIP : IPv4Address;
        attribute endIP : IPv4Address;
        
        port internalPort : InternalDataPort;
        
        action assignIP {
            in mac : MACAddress;
            out assignedIP : IPv4Address;
        }
    }
    
    part def DnsProxy {
        attribute cache : DnsRecord[0..*];
        
        port internalPort : InternalDataPort;
        
        action lookupDomain {
            in domain : DomainName;
            out ip : IPv4Address;
        }
    }
    
    part def ManagementController {
        attribute adminPassword : WPAKey;
        attribute currentStatus : GatewayStatus;
        
        port mgmtPort : ManagementPort;
        port internalDataPort : InternalDataPort;
        
        action applyConfig {
            in config : GatewayConfig;
        }
        action monitorHealth;
    }
    
    part def ResidentialGateway {
        attribute modelNumber : String;
        attribute publicIP : IPv4Address;
        
        port wanPort : WANPort;
        port lanPorts : LANPort[4];
        port wifiPort : WirelessPort;
        port mgmtPort : ManagementPort;
        
        part wanInterface : WANInterface {
            publicIPAddress = publicIP;
        }
        part wifiAP : WirelessAccessPoint;
        part ethSwitch : EthernetSwitch;
        part firewallNat : FirewallNatModule;
        part routingEngine : RoutingEngine;
        part dhcpService : DhcpService;
        part dnsProxy : DnsProxy;
        part mgmtController : ManagementController;
        
        connection wanToFirewall from wanInterface.internalOut to firewallNat.upstreamPort;
        connection firewallToRouter from firewallNat.downstreamPort to routingEngine.upstreamPort;
        connection routerToSwitch from routingEngine.ethernetPort to ethSwitch.internalPort;
        connection routerToWifi from routingEngine.wifiPort to wifiAP.internalPort;
        
        connection routerToDhcp from routingEngine.ethernetPort to dhcpService.internalPort;
        connection routerToDns from routingEngine.ethernetPort to dnsProxy.internalPort;
        connection mgmtToFirewall from mgmtController.internalDataPort to firewallNat.downstreamPort;
        
        connection extWanToWan from wanPort to wanInterface.externalWAN;
        connection extLanToLan from lanPorts to ethSwitch.lanPorts;
        connection extWifiToWifi from wifiPort to wifiAP.wirelessPort;
        connection extMgmtToMgmt from mgmtPort to mgmtController.mgmtPort;
        
        action processOutgoingTraffic {
            in localPacket : DataPacket;
            
            action translateOutgoingAction {
                in packet = localPacket;
                out translatedPacket : DataPacket;
            }
            action checkFirewallOutgoing {
                in packet = translatedPacket;
                out allowed : Boolean;
            }
            action routeToWan {
                in packet = translatedPacket;
            }
            action sendToWan {
                out packet = translatedPacket;
            }
        }
        
        action processIncomingTraffic {
            in externalPacket : DataPacket;
            
            action screenIncomingAction {
                in packet = externalPacket;
                out allowed : Boolean;
            }
            action determineDest {
                in packet = externalPacket;
                out internalIP : IPv4Address;
            }
            action routePacketAction {
                in packet = externalPacket;
                out interfaceType : String;
            }
        }
        
        state machine GatewayStateMachine {
            state Off;
            state Booting;
            state Operational;
            state Error;
            
            transition from Off to Booting;
            transition from Booting to Operational;
            transition from Operational to Error;
            transition from Error to Booting;
        }
        
        requirement provideWANConnection {
            subject wanInterface : WANInterface;
            objective "The gateway shall provide a connection to the ISP via the WAN port.";
        }
        
        requirement provideWirelessNetwork {
            subject wifiAP : WirelessAccessPoint;
            objective "The gateway shall broadcast an SSID and authenticate devices using WPA.";
        }
        
        requirement routeTraffic {
            subject routingEngine : RoutingEngine;
            objective "The gateway shall inspect every packet and direct it to the correct interface.";
        }
        
        requirement performFirewallNat {
            subject firewallNat : FirewallNatModule;
            objective "The gateway shall screen incoming and outgoing traffic and translate addresses.";
        }
    }
}
