package ResidentialGatewayModel {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def SecurityRule {
        attribute ruleID : String;
        attribute ruleAction : String;
        attribute sourceIP : IPAddress;
        attribute destIP : IPAddress;
        attribute protocol : String;
    }
    attribute def NetworkConfig {
        attribute ssid : String;
        attribute encryptionKey : String;
        attribute channel : Integer;
        attribute frequency : Real;
    }
    attribute def SystemHealth {
        attribute cpuUsage : Real;
        attribute memUsage : Real;
        attribute uptime : Real;
        attribute temperature : Real;
    }

    item def IPAddress {
        attribute value : String;
        attribute isPublic : Boolean;
    }
    item def DataPacket {
        attribute sourceIP : IPAddress;
        attribute destIP : IPAddress;
        attribute payloadSize : Integer;
        attribute protocol : String;
    }
    item def DNSQuery {
        attribute domainName : String;
    }
    item def DNSResponse {
        attribute domainName : String;
        attribute resolvedIP : IPAddress;
        attribute ttl : Real;
    }
    item def DHCPRequest {
        attribute clientMAC : String;
    }
    item def DHCPResponse {
        attribute assignedIP : IPAddress;
        attribute leaseDuration : Real;
    }
    item def DHCPLease {
        attribute assignedIP : IPAddress;
        attribute clientMAC : String;
        attribute leaseDuration : Real;
    }
    item def ConfigData {
        attribute networkConfig : NetworkConfig;
        attribute firewallRules : SecurityRule[0..*];
    }
    item def StatusReport {
        attribute health : SystemHealth;
        attribute activeLeases : DHCPLease[0..*];
    }

    port def WANPort {
        in item incomingInternetData : DataPacket;
        out item outgoingInternetData : DataPacket;
    }
    port def EthernetPort {
        inout item ethernetData : DataPacket;
    }
    port def WirelessPort {
        attribute ssid : String;
        in item wirelessInbound : DataPacket;
        out item wirelessOutbound : DataPacket;
    }
    port def ManagementPort {
        in item configRequest : ConfigData;
        out item statusResponse : StatusReport;
    }
    port def InternalDataPort {
        in item dataIn : DataPacket;
        out item dataOut : DataPacket;
    }

    part def WANInterface {
        port wanPort : WANPort;
        port internalPort : InternalDataPort;
        attribute publicIP : IPAddress;

        action processIncoming {
            in item rawInternetData : DataPacket;
            out item internalPacket : DataPacket;
        }
        action processOutgoing {
            in item internalPacket : DataPacket;
            out item internetData : DataPacket;
        }
    }

    part def WirelessAccessPoint {
        port wirelessPort : WirelessPort;
        port internalPort : InternalDataPort;
        attribute config : NetworkConfig;

        action broadcastSSID {
            out item beacon : String;
        }
        action authenticateDevice {
            in item credentials : String;
            out item authResult : Boolean;
        }
        action transmitWireless {
            in item packet : DataPacket;
            out item wirelessOutbound : DataPacket;
        }
        action receiveWireless {
            in item wirelessInbound : DataPacket;
            out item packet : DataPacket;
        }
    }

    part def EthernetSwitch {
        port ethPort1 : EthernetPort;
        port ethPort2 : EthernetPort;
        port ethPort3 : EthernetPort;
        port ethPort4 : EthernetPort;
        port internalPort : InternalDataPort;

        action forwardFrame {
            in item ingressFrame : DataPacket;
            out item egressFrame : DataPacket;
        }
    }

    part def RoutingEngine {
        port lanSide : InternalDataPort;
        port wanSide : InternalDataPort;
        port dhcpPort : InternalDataPort;
        port dnsPort : InternalDataPort;
        attribute routingTable : String;

        action inspectPacket {
            in item packet : DataPacket;
            out item destInfo : String;
        }
        action routeToWAN {
            in item packet : DataPacket;
            out item routedPacket : DataPacket;
        }
        action routeToLAN {
            in item packet : DataPacket;
            out item routedPacket : DataPacket;
        }
    }

    part def FirewallNATModule {
        port lanSide : InternalDataPort;
        port wanSide : InternalDataPort;
        attribute securityRules : SecurityRule[1..*];
        attribute natTable : String;

        action applyNAT {
            in item packet : DataPacket;
            out item translatedPacket : DataPacket;
        }
        action reverseNAT {
            in item packet : DataPacket;
            out item restoredPacket : DataPacket;
        }
        action inspectFirewall {
            in item packet : DataPacket;
            out item inspectedPacket : DataPacket;
            out item blocked : Boolean;
        }
    }

    part def DHCPService {
        port internalPort : InternalDataPort;
        attribute leasePool : IPAddress[1..*];
        attribute assignedLeases : DHCPLease[0..*];

        action assignAddress {
            in item clientMAC : String;
            out item lease : DHCPLease;
        }
        action renewLease {
            in item existingLease : DHCPLease;
            out item renewedLease : DHCPLease;
        }
    }

    part def DNSProxy {
        port internalPort : InternalDataPort;
        port upstreamPort : InternalDataPort;
        attribute cache : DNSResponse[0..*];

        action lookup {
            in item domainName : String;
            out item resolvedIP : String;
        }
        action cacheLookup {
            in item domainName : String;
            out item cachedResult : String;
        }
        action forwardQuery {
            in item domainName : String;
            out item upstreamQuery : DNSQuery;
        }
    }

    part def ManagementController {
        port mgmtPort : ManagementPort;
        port internalPort : InternalDataPort;
        attribute health : SystemHealth;

        action updateConfig {
            in item newConfig : NetworkConfig;
            out item ack : Boolean;
        }
        action updateFirewallRules {
            in item newRules : SecurityRule[1..*];
            out item ack : Boolean;
        }
        action reportHealth {
            out item healthReport : SystemHealth;
        }
    }

    requirement def GatewayRequirements {
        requirement ProvideInternetAccess {
            doc /* The gateway shall connect the local home network to the ISP-provided internet. */
        }
        requirement ProvideWiFi {
            doc /* The gateway shall broadcast a Wi-Fi network with a configurable SSID and encryption key. */
        }
        requirement ProvideWiredEthernet {
            doc /* The gateway shall provide at least four Ethernet ports for wired local connections. */
        }
        requirement ProvideSecurity {
            doc /* The gateway shall include a firewall and NAT to protect and obscure the internal network. */
        }
        requirement ProvideDHCP {
            doc /* The gateway shall automatically assign local IP addresses to connected devices. */
        }
        requirement ProvideDNS {
            doc /* The gateway shall proxy DNS queries and cache results for faster browsing. */
        }
        requirement ProvideManagement {
            doc /* The gateway shall expose a management interface for configuration and monitoring. */
        }
    }

    part def ResidentialGateway {
        port externalWAN : WANPort;
        port externalWireless : WirelessPort;
        port externalEth1 : EthernetPort;
        port externalEth2 : EthernetPort;
        port externalEth3 : EthernetPort;
        port externalEth4 : EthernetPort;
        port externalMgmt : ManagementPort;

        part wanInterface : WANInterface;
        part wirelessAP : WirelessAccessPoint;
        part ethSwitch : EthernetSwitch;
        part routingEngine : RoutingEngine;
        part firewallNAT : FirewallNATModule;
        part dhcpService : DHCPService;
        part dnsProxy : DNSProxy;
        part mgmtController : ManagementController;

        connect externalWAN to wanInterface.wanPort;
        connect externalWireless to wirelessAP.wirelessPort;
        connect externalEth1 to ethSwitch.ethPort1;
        connect externalEth2 to ethSwitch.ethPort2;
        connect externalEth3 to ethSwitch.ethPort3;
        connect externalEth4 to ethSwitch.ethPort4;
        connect externalMgmt to mgmtController.mgmtPort;

        connect wanInterface.internalPort to firewallNAT.wanSide;
        connect firewallNAT.lanSide to routingEngine.wanSide;
        connect routingEngine.lanSide to wirelessAP.internalPort;
        connect routingEngine.lanSide to ethSwitch.internalPort;
        connect routingEngine.dhcpPort to dhcpService.internalPort;
        connect routingEngine.dnsPort to dnsProxy.internalPort;
        connect dnsProxy.upstreamPort to firewallNAT.wanSide;
        connect mgmtController.internalPort to routingEngine.lanSide;

        action outgoingTrafficFlow {
            first start;
            then action natTranslate {
                in item packet : DataPacket;
                out item translatedPacket : DataPacket;
            }
            then action firewallCheck {
                in item packet : DataPacket;
                out item inspectedPacket : DataPacket;
            }
            then action routeToInternet {
                in item packet : DataPacket;
                out item routedPacket : DataPacket;
            }
            then action sendToWAN {
                in item packet : DataPacket;
            }
            then done;
        }

        action incomingTrafficFlow {
            first start;
            then action receiveFromWAN {
                in item rawInternetData : DataPacket;
                out item internalPacket : DataPacket;
            }
            then action firewallScreen {
                in item packet : DataPacket;
                out item inspectedPacket : DataPacket;
            }
            then action reverseNATTranslate {
                in item packet : DataPacket;
                out item restoredPacket : DataPacket;
            }
            then action routeToLAN {
                in item packet : DataPacket;
                out item routedPacket : DataPacket;
            }
            then done;
        }
    }

    part homeGateway : ResidentialGateway {
        attribute deviceName : String = "HomeGateway-001";
        attribute manufacturer : String = "TechCorp";
        attribute modelNumber : String = "RG-2400";
    }

    part def ISP {
        port ispPort : ~WANPort;
    }

    part def LocalDevice {
        attribute deviceType : String;
        attribute macAddress : String;
        port localEthPort : ~EthernetPort;
        port localWifiPort : ~WirelessPort;
    }

    part def HomeNetwork {
        part isp : ISP;
        part gateway : ResidentialGateway;
        part desktopPC : LocalDevice {
            :>> deviceType = "Desktop";
        }
        part gamingConsole : LocalDevice {
            :>> deviceType = "Console";
        }
        part smartphone : LocalDevice {
            :>> deviceType = "Phone";
        }
        part smartTV : LocalDevice {
            :>> deviceType = "SmartTV";
        }

        connect isp.ispPort to gateway.externalWAN;
        connect desktopPC.localEthPort to gateway.externalEth1;
        connect gamingConsole.localEthPort to gateway.externalEth2;
        connect smartphone.localWifiPort to gateway.externalWireless;
        connect smartTV.localWifiPort to gateway.externalWireless;
    }

    part homeNetworkInstance : HomeNetwork;
}
