package GlobalInternetNetwork {
    private import ScalarValues::*;
    private import SI::*;

    attribute def IPAddress :> ScalarValues::String {
        doc /* IPv4 or IPv6 address literal */
    }
    attribute def DataRate :> ScalarValues::Real {
        doc /* data-carrying capacity in bits per second */
    }
    attribute def LatencyValue :> ScalarValues::Real {
        doc /* one-way propagation delay in seconds */
    }
    attribute def ReliabilityValue :> ScalarValues::Real {
        doc /* packet-delivery probability in the range 0..1 */
    }
    attribute def DataPayload :> ScalarValues::String {
        doc /* application data carried inside a packet */
    }

    item def DataPacket {
        attribute sourceAddr : IPAddress;
        attribute destAddr : IPAddress;
        attribute payload : DataPayload;
        attribute protocolInfo : String;
        attribute sequenceId : Integer;
        attribute isRequest : Boolean;
    }

    attribute def RoutingEntry {
        attribute destNetwork : IPAddress;
        attribute nextHop : IPAddress;
        attribute portIndex : Integer;
    }

    attribute def RoutingTable {
        attribute entries : RoutingEntry[1..*];
    }

    port def NetworkPort {
        in item inPacket : DataPacket;
        out item outPacket : DataPacket;
    }

    part def NetworkLink {
        port endA : NetworkPort;
        port endB : NetworkPort;
        attribute bandwidth : DataRate;
        attribute latency : LatencyValue;
        attribute reliability : ReliabilityValue;
        attribute linkId : String;

        state LinkBehavior {
            entry;
            then Forwarding;
            state Forwarding;
            accept pkt : DataPacket via endA
            do action {
                first start;
                then send pkt via endB;
                then done;
            }
            then Forwarding;
            accept pkt : DataPacket via endB
            do action {
                first start;
                then send pkt via endA;
                then done;
            }
            then Forwarding;
        }
    }

    part def NetworkNode {
        port nic : NetworkPort[1..*];
        attribute ipAddress : IPAddress;
    }

    part def ClientDevice :> NetworkNode {
        attribute userName : String;
        attribute destServerAddr : IPAddress;
        attribute currentPayload : DataPayload;
        attribute lastResponse : DataPayload;

        state ClientBehavior {
            entry;
            then Sending;
            state Sending {
                entry send new DataPacket(ipAddress, destServerAddr, currentPayload, "TCP", 0, true) via nic;
            }
            then Waiting;
            state Waiting;
            accept pkt : DataPacket via nic
            do action {
                first start;
                then done;
            }
            then Idle;
            state Idle;
            then Sending;
        }
    }

    part def Server :> NetworkNode {
        attribute serviceName : String;
        attribute activeConnections : Integer = 0;

        state ServerBehavior {
            entry;
            then Listening;
            state Listening;
            accept receivedReq : DataPacket via nic
            do action {
                first start;
                then send new DataPacket(ipAddress, receivedReq.sourceAddr, receivedReq.payload, "TCP-RESP", receivedReq.sequenceId, false) via nic;
                then done;
            }
            then Listening;
        }
    }

    part def ContentServer :> Server {
        attribute hostedWebsites : String[1..*];
        attribute storedContent : DataPayload[0..*];
    }

    part def DNSServer :> Server {
        attribute domainTable : String[1..*];
        attribute resolvedAddress : IPAddress;
    }

    part def Router :> NetworkNode {
        attribute routingTable : RoutingTable;
        attribute packetsForwarded : Integer = 0;
        attribute congestionLevel : Real = 0.0;
        attribute maxQueueSize : Integer;

        state RouterBehavior {
            entry;
            then Receiving;
            state Receiving;
            accept pkt : DataPacket via nic
            do action {
                first start;
                then send pkt via nic;
                then done;
            }
            then Receiving;
        }
    }

    part def CoreRouter :> Router {
        attribute backboneCapacity : DataRate;
        attribute interconnectCount : Integer;
    }

    part def EdgeRouter :> Router {
        attribute clientCapacity : Integer;
        attribute connectedClients : Integer = 0;
    }

    part def NetworkMonitor {
        attribute observedLoad : Real = 0.0;
        attribute activeLinks : Integer = 0;
        attribute reportingInterval : LatencyValue;
    }

    part def TrafficManager {
        attribute congestionThreshold : Real = 0.8;
        attribute activePaths : Integer = 0;
        attribute reroutedPackets : Integer = 0;
    }

    part def GlobalInternetNetwork {
        part clients : ClientDevice[10000..100000];
        part edgeRouters : EdgeRouter[10..1000];
        part coreRouters : CoreRouter[2..20];
        part contentServers : ContentServer[5..500];
        part dnsServers : DNSServer[1..50];
        part clientLinks : NetworkLink[10000..100000];
        part edgeLinks : NetworkLink[10..1000];
        part coreLinks : NetworkLink[2..20];
        part serverLinks : NetworkLink[5..500];
        part dnsLinks : NetworkLink[1..50];
        part monitor : NetworkMonitor;
        part trafficManager : TrafficManager;

        connect clients.nic to clientLinks.endA;
        connect clientLinks.endB to edgeRouters.nic;
        connect edgeRouters.nic to edgeLinks.endA;
        connect edgeLinks.endB to coreRouters.nic;
        connect coreRouters.nic to coreLinks.endA;
        connect coreLinks.endB to coreRouters.nic;
        connect coreRouters.nic to serverLinks.endA;
        connect serverLinks.endB to contentServers.nic;
        connect coreRouters.nic to dnsLinks.endA;
        connect dnsLinks.endB to dnsServers.nic;
    }

    requirement def BandwidthRequirement {
        subject link : NetworkLink;
        attribute minimumBandwidth : DataRate = 1000000000;
        doc /* Core and edge links shall provide at least 1 Gbit/s */
        constraint { link.bandwidth >= minimumBandwidth }
    }

    requirement def LatencyRequirement {
        subject link : NetworkLink;
        attribute maximumLatency : LatencyValue = 0.05;
        doc /* End-to-end one-way latency shall not exceed 50 ms */
        constraint { link.latency <= maximumLatency }
    }

    requirement def ReliabilityRequirement {
        subject link : NetworkLink;
        attribute minimumReliability : ReliabilityValue = 0.999;
        doc /* Packet delivery probability shall be at least 99.9% */
        constraint { link.reliability >= minimumReliability }
    }

    requirement def ScalabilityRequirement {
        subject network : GlobalInternetNetwork;
        attribute minimumConcurrentClients : Integer = 10000;
        doc /* The network shall support at least 10,000 simultaneous client devices */
    }

    requirement def CongestionManagementRequirement {
        subject network : GlobalInternetNetwork;
        attribute congestionThreshold : Real = 0.8;
        doc /* Traffic management shall engage before network load exceeds 80% */
    }

    requirement NetworkPerformanceSpecification {
        subject network : GlobalInternetNetwork;
        doc /* Overall performance and reliability requirements for the global internet model */
        requirement bandwidthReq : BandwidthRequirement;
        requirement latencyReq : LatencyRequirement;
        requirement reliabilityReq : ReliabilityRequirement;
        requirement scalabilityReq : ScalabilityRequirement;
        requirement congestionReq : CongestionManagementRequirement;
    }

    part globalInternet : GlobalInternetNetwork;
    satisfy NetworkPerformanceSpecification by globalInternet;
}
