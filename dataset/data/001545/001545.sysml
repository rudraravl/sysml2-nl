package 'Residential Gateway System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MACAddress :> String;
    attribute def IPv4Address :> String;
    attribute def IPv6Address :> String;
    attribute def SSID :> String;
    attribute def EncryptionKey :> String;
    
    attribute def DataRate :> Real;
    attribute def SignalPower :> Real;
    attribute def RadioFrequency :> Real;
    
    item def NetworkPacket {
        attribute sourceAddress : IPv4Address;
        attribute destinationAddress : IPv4Address;
        attribute payloadSize : Real;
        attribute protocol : String;
    }
    
    item def WiFiFrame {
        attribute sourceMac : MACAddress;
        attribute destinationMac : MACAddress;
        attribute encapsulatedPacket : NetworkPacket;
    }
    
    item def ConfigurationCommand {
        attribute commandType : String;
        attribute parameters : String;
    }
    
    port def WANPort {
        in item inboundTraffic : NetworkPacket[*];
        out item outboundTraffic : NetworkPacket[*];
        attribute publicIP : IPv4Address;
        attribute linkSpeed : DataRate;
    }
    
    port def EthernetPort {
        in item deviceInput : NetworkPacket[*];
        out item deviceOutput : NetworkPacket[*];
        attribute portMAC : MACAddress;
        attribute portSpeed : DataRate;
    }
    
    port def WirelessPort {
        in item wirelessInput : WiFiFrame[*];
        out item wirelessOutput : WiFiFrame[*];
        attribute networkSSID : SSID;
        attribute channel : RadioFrequency;
        attribute txPower : SignalPower;
    }
    
    port def ManagementPort {
        in item commands : ConfigurationCommand[*];
        out item status : ConfigurationCommand[*];
    }
    
    part def WANInterface {
        port wanPort : WANPort;
        
        action def ReceiveFromISP {
            in packet : NetworkPacket;
            out validatedPacket : NetworkPacket;
        }
        
        action def TransmitToISP {
            in packet : NetworkPacket;
            out sentPacket : NetworkPacket;
        }
    }
    
    part def RoutingEngine {
        attribute routingTable : IPv4Address[*];
        attribute defaultGateway : IPv4Address;
        
        action def DetermineRoute {
            in packet : NetworkPacket;
            in destination : IPv4Address;
            out nextHop : String;
            out routedPacket : NetworkPacket;
        }
        
        action def UpdateRoutes {
            in newRoute : IPv4Address;
        }
    }
    
    part def FirewallEngine {
        attribute firewallRules : String[*];
        attribute blockedAddresses : IPv4Address[*];
        
        action def InspectPacket {
            in packet : NetworkPacket;
            out isPermitted : Boolean;
            out inspectedPacket : NetworkPacket;
        }
        
        action def ApplySecurityPolicy {
            in packet : NetworkPacket;
            in rule : String;
            out decision : Boolean;
        }
        
        action def LogSecurityEvent {
            in packet : NetworkPacket;
            in eventType : String;
        }
    }
    
    part def NATModule {
        attribute privateSubnet : IPv4Address;
        attribute publicAddress : IPv4Address;
        attribute sessionTable : String[*];
        
        action def TranslateOutbound {
            in privateIP : IPv4Address;
            in privatePort : Integer;
            out publicIP : IPv4Address;
            out publicPort : Integer;
            out translatedPacket : NetworkPacket;
        }
        
        action def TranslateInbound {
            in publicPort : Integer;
            out privateIP : IPv4Address;
            out privatePort : Integer;
            out translatedPacket : NetworkPacket;
        }
        
        action def MaintainSessions {
            in sessionID : String;
            in timeout : Real;
        }
    }
    
    part def EthernetSwitch {
        port ethernetPorts : EthernetPort[4];
        attribute macTable : MACAddress[*];
        
        action def ForwardFrame {
            in packet : NetworkPacket;
            in targetMAC : MACAddress;
            out forwardedPacket : NetworkPacket;
            out outputPort : Integer;
        }
        
        action def LearnMAC {
            in mac : MACAddress;
            in port : Integer;
        }
        
        action def FloodUnknown {
            in packet : NetworkPacket;
        }
    }
    
    part def WirelessAccessPoint {
        port wirelessPort : WirelessPort;
        attribute associatedDevices : MACAddress[*];
        attribute beaconInterval : Real;
        
        action def AuthenticateClient {
            in clientMAC : MACAddress;
            in credentials : EncryptionKey;
            out authenticated : Boolean;
        }
        
        action def TransmitBeacon {
            out beacon : WiFiFrame;
        }
        
        action def BridgeWirelessToWired {
            in wirelessFrame : WiFiFrame;
            out wiredPacket : NetworkPacket;
        }
        
        action def BridgeWiredToWireless {
            in wiredPacket : NetworkPacket;
            out wirelessFrame : WiFiFrame;
        }
    }
    
    part def DHCPService {
        attribute addressPool : IPv4Address[*];
        attribute leaseDatabase : String[*];
        attribute leaseTime : Real;
        
        action def AssignAddress {
            in clientMAC : MACAddress;
            out assignedIP : IPv4Address;
            out subnetMask : IPv4Address;
            out gateway : IPv4Address;
            out dnsServer : IPv4Address;
        }
        
        action def RenewLease {
            in clientIP : IPv4Address;
            out newExpiry : Real;
        }
        
        action def ReleaseLease {
            in clientIP : IPv4Address;
        }
    }
    
    part def DNSProxy {
        attribute cachedRecords : String[*];
        attribute upstreamDNS : IPv4Address;
        
        action def ResolveQuery {
            in domainName : String;
            out resolvedIP : IPv4Address;
            out fromCache : Boolean;
        }
        
        action def ForwardQuery {
            in query : String;
            out response : IPv4Address;
        }
        
        action def CacheRecord {
            in domain : String;
            in address : IPv4Address;
            in ttl : Real;
        }
    }
    
    part def ManagementController {
        port managementPort : ManagementPort;
        attribute adminCredentials : String;
        
        action def ProcessConfiguration {
            in command : ConfigurationCommand;
            out success : Boolean;
        }
        
        action def MonitorHealth {
            out cpuUsage : Real;
            out memoryUsage : Real;
            out uptime : Real;
            out activeConnections : Integer;
        }
        
        action def GenerateReport {
            out statusReport : ConfigurationCommand;
        }
    }
    
    requirement def ConnectivityRequirement {
        doc /* The gateway shall provide reliable connectivity between 
               local network devices and the internet service provider. */
        
        attribute uplinkAvailability : Real;
        
        require constraint {
            uplinkAvailability >= 0.999
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The gateway shall support minimum throughput of 1 Gbps 
               on WAN interface and aggregate 1 Gbps on LAN interfaces. */
        
        attribute wanThroughput : Real;
        attribute lanAggregateThroughput : Real;
        
        require constraint {
            wanThroughput >= 1000.0 and
            lanAggregateThroughput >= 1000.0
        }
    }
    
    requirement def SecurityRequirement {
        doc /* The gateway shall implement stateful packet inspection, 
               network address translation, and WPA3 wireless security. */
        
        attribute statefulFirewall : Boolean;
        attribute natEnabled : Boolean;
        attribute wirelessEncryption : String;
        
        require constraint {
            statefulFirewall == true and
            natEnabled == true and
            wirelessEncryption == "WPA3"
        }
    }
    
    requirement def CapacityRequirement {
        doc /* The gateway shall support at least 64 simultaneous 
               device connections across wired and wireless interfaces. */
        
        attribute maxConcurrentDevices : Integer;
        
        require constraint {
            maxConcurrentDevices >= 64
        }
    }
    
    part def ResidentialGateway {
        doc /* A residential gateway device that connects home network devices 
               to an internet service provider, providing routing, security, 
               network address translation, wireless access, and network services. */
        
        part wanInterface : WANInterface;
        part routingEngine : RoutingEngine;
        part firewallEngine : FirewallEngine;
        part natModule : NATModule;
        part ethernetSwitch : EthernetSwitch;
        part wirelessAP : WirelessAccessPoint;
        part dhcpService : DHCPService;
        part dnsProxy : DNSProxy;
        part managementController : ManagementController;
        
        connection wanToRouter connect wanInterface.wanPort to routingEngine;
        connection routerToFirewall connect routingEngine to firewallEngine;
        connection firewallToNAT connect firewallEngine to natModule;
        connection natToSwitch connect natModule to ethernetSwitch;
        connection natToWireless connect natModule to wirelessAP;
        connection switchToDHCP connect ethernetSwitch to dhcpService;
        connection routerToDNS connect routingEngine to dnsProxy;
        connection managementToAll connect managementController to routingEngine;
        
        perform action operateGateway;
    }
    
    action def ProcessDownstreamTraffic {
        in internetPacket : NetworkPacket;
        out deliveredPacket : NetworkPacket;
    }
    
    action def ProcessUpstreamTraffic {
        in localPacket : NetworkPacket;
        out internetPacket : NetworkPacket;
    }
    
    action operateGateway {
        doc /* Primary function: Route and secure bidirectional network traffic 
               between local devices and the internet while providing essential 
               network services including address assignment and name resolution. */
        
        first start;
        then fork;
        
        action handleDownstream {
            loop {
                action receiveFromInternet : ProcessDownstreamTraffic {
                    in internetPacket : NetworkPacket;
                    out processedPacket : NetworkPacket;
                }
                then action inspectIncoming {
                    in packet = receiveFromInternet.processedPacket;
                    out permitted : Boolean;
                    out securePacket : NetworkPacket;
                }
                then decide;
                    if inspectIncoming.permitted then translateInbound;
                    else dropPacket;
                
                action translateInbound {
                    in packet = inspectIncoming.securePacket;
                    out translatedPacket : NetworkPacket;
                }
                then action routeToLocal {
                    in packet = translateInbound.translatedPacket;
                    out deliveredPacket : NetworkPacket;
                }
                action dropPacket;
            }
        }
        
        action handleUpstream {
            loop {
                action receiveFromLocal : ProcessUpstreamTraffic {
                    in localPacket : NetworkPacket;
                    out processedPacket : NetworkPacket;
                }
                then action translateOutbound {
                    in packet = receiveFromLocal.processedPacket;
                    out translatedPacket : NetworkPacket;
                }
                then action inspectOutgoing {
                    in packet = translateOutbound.translatedPacket;
                    out permitted : Boolean;
                    out securePacket : NetworkPacket;
                }
                then decide;
                    if inspectOutgoing.permitted then routeToInternet;
                    else blockPacket;
                
                action routeToInternet {
                    in packet = inspectOutgoing.securePacket;
                    out internetPacket : NetworkPacket;
                }
                action blockPacket;
            }
        }
        
        action provideServices {
            loop {
                action serveDHCP {
                    out assignedAddress : IPv4Address;
                }
                then action resolveDNS {
                    in query : String;
                    out resolvedAddress : IPv4Address;
                }
                then action maintainWireless {
                    out beaconSent : Boolean;
                }
            }
        }
        
        action manageSystem {
            loop {
                action monitorStatus {
                    out healthMetrics : ConfigurationCommand;
                }
                then action processConfig {
                    in configCommand : ConfigurationCommand;
                    out applied : Boolean;
                }
            }
        }
    }
    
    part residentialGatewaySystem : ResidentialGateway;
    
    requirement systemRequirements {
        doc /* Complete requirements specification for residential gateway system. */
        
        require connectivity : ConnectivityRequirement;
        require performance : PerformanceRequirement;
        require security : SecurityRequirement;
        require capacity : CapacityRequirement;
        
        satisfy residentialGatewaySystem;
    }
}
