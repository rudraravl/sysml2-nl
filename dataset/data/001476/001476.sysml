package InternetSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def IPAddress {
        attribute octet1 : Integer;
        attribute octet2 : Integer;
        attribute octet3 : Integer;
        attribute octet4 : Integer;
    }

    attribute def DataRateValue :> Real;
    attribute def LatencyValue :> Real;
    attribute def PacketSizeValue :> Real;

    enum def ProtocolType {
        tcp;
        udp;
        http;
        https;
        dns;
    }

    enum def PacketState {
        created;
        queued;
        transmitting;
        delivered;
        dropped;
    }

    enum def ConnectionStatus {
        idle;
        establishing;
        active;
        closing;
        closed;
        error;
    }

    item def DataPacket {
        attribute sourceAddress : IPAddress;
        attribute destinationAddress : IPAddress;
        attribute protocol : ProtocolType;
        attribute payloadSize : PacketSizeValue;
        attribute payload : String;
        attribute sequenceNumber : Integer;
        attribute state : PacketState;
    }

    port def NetworkInterface {
        attribute address : IPAddress;
        attribute maxBandwidth : DataRateValue;
        in item incomingPackets : DataPacket[*];
        out item outgoingPackets : DataPacket[*];
    }

    part def Router {
        attribute routerID : String;
        attribute maxThroughput : DataRateValue;
        attribute routingTableSize : Integer;
        attribute currentLoad : Real;

        port interfaces : NetworkInterface[4..16];

        action routePacket {
            in packet : DataPacket;
            out forwardedPacket : DataPacket;

            first start;
            then action checkDestination {
                in inPacket : DataPacket = packet;
                out targetAddress : IPAddress;
            }
            then action lookupRoute {
                in destination : IPAddress = checkDestination.targetAddress;
                out nextHop : IPAddress;
                out outputInterface : NetworkInterface;
            }
            then decide;
                if lookupRoute.nextHop != null then forward;
                if lookupRoute.nextHop == null then drop;
            action forward {
                in packetToForward : DataPacket = packet;
                in outInterface : NetworkInterface = lookupRoute.outputInterface;
                out forwarded : DataPacket;
            }
            then done;
            action drop;
            then done;
        }
    }

    part def Server {
        attribute serverID : String;
        attribute serverType : String;
        attribute storageCapacity : PacketSizeValue;
        attribute processingPower : Real;
        attribute activeConnections : Integer;

        port networkPort : NetworkInterface;

        action handleRequest {
            in request : DataPacket;
            out response : DataPacket;

            first start;
            then action validateRequest {
                in incomingRequest : DataPacket = request;
                out isValid : Boolean;
            }
            then decide;
                if validateRequest.isValid == true then process;
                if validateRequest.isValid == false then reject;
            action process {
                in validRequest : DataPacket = request;
                out processedData : String;
            }
            then action buildResponse {
                in data : String = process.processedData;
                in originalRequest : DataPacket = request;
                out responsePacket : DataPacket;
            }
            then done;
            action reject {
                in invalidRequest : DataPacket = request;
                out errorResponse : DataPacket;
            }
            then done;
        }
    }

    part def ClientDevice {
        attribute deviceID : String;
        attribute deviceType : String;
        attribute userID : String;

        port networkPort : NetworkInterface;

        action sendRequest {
            in targetAddress : IPAddress;
            in requestData : String;
            out requestPacket : DataPacket;

            first start;
            then action createPacket {
                in destination : IPAddress = targetAddress;
                in data : String = requestData;
                out packet : DataPacket;
            }
            then action transmitPacket {
                in packetToSend : DataPacket = createPacket.packet;
                out transmitted : DataPacket;
            }
            then done;
        }

        action receiveResponse {
            in responsePacket : DataPacket;
            out processedResponse : String;

            first start;
            then action validateResponse {
                in packet : DataPacket = responsePacket;
                out isValid : Boolean;
            }
            then decide;
                if validateResponse.isValid == true then extract;
                if validateResponse.isValid == false then error;
            action extract {
                in validPacket : DataPacket = responsePacket;
                out extractedData : String;
            }
            then action displayContent {
                in content : String = extract.extractedData;
            }
            then done;
            action error;
            then done;
        }
    }

    connection def NetworkLink {
        end source : NetworkInterface;
        end destination : NetworkInterface;

        attribute linkBandwidth : DataRateValue;
        attribute linkLatency : LatencyValue;
        attribute linkStatus : ConnectionStatus;
        attribute packetLossRate : Real;
    }

    part def InternetBackbone {
        attribute networkID : String;
        attribute totalBandwidth : DataRateValue;
        attribute averageLatency : LatencyValue;
        attribute totalRouters : Integer;
        attribute totalServers : Integer;
        attribute totalClients : Integer;

        part coreRouters : Router[20..50] {
            attribute :>> maxThroughput : DataRateValue;
            attribute :>> routingTableSize : Integer;
        }

        part edgeRouters : Router[100..200] {
            attribute :>> maxThroughput : DataRateValue;
        }

        part contentServers : Server[50..100] {
            attribute :>> serverType = "content";
            attribute :>> storageCapacity : PacketSizeValue;
        }

        part dnsServers : Server[10..20] {
            attribute :>> serverType = "dns";
        }

        part clients : ClientDevice[10000..*] {
            attribute :>> deviceType : String;
        }

        connection coreLinks : NetworkLink[*]
            connect coreRouters.interfaces to coreRouters.interfaces;

        connection edgeToCore : NetworkLink[*]
            connect edgeRouters.interfaces to coreRouters.interfaces;

        connection serverLinks : NetworkLink[*]
            connect coreRouters.interfaces to contentServers.networkPort;

        connection dnsLinks : NetworkLink[*]
            connect coreRouters.interfaces to dnsServers.networkPort;

        connection clientLinks : NetworkLink[*]
            connect clients.networkPort to edgeRouters.interfaces;
    }

    part globalInternet : InternetBackbone {
        attribute :>> networkID = "GlobalInternet";
        attribute :>> totalBandwidth : DataRateValue = 1000000.0;
        attribute :>> averageLatency : LatencyValue = 0.05;

        perform action manageTraffic {
            first start;
            then merge continueManaging;
            then action monitorNetwork {
                out networkLoad : Real;
                out queuedPackets : DataPacket[*];
                out activeConnections : Integer;
            }
            then decide;
                if monitorNetwork.networkLoad < 0.75 then normalOperation;
                if monitorNetwork.networkLoad >= 0.75 then loadBalance;
            action normalOperation {
                in packets : DataPacket[*] = monitorNetwork.queuedPackets;
            }
            then continueManaging;
            action loadBalance {
                in packets : DataPacket[*] = monitorNetwork.queuedPackets;
                in connections : Integer = monitorNetwork.activeConnections;
            }
            then continueManaging;
        }
    }

    action def EndToEndCommunication {
        first start;
        then action clientRequest {
            out requestPacket : DataPacket;
        }
        then action routeToServer {
            in packet : DataPacket = clientRequest.requestPacket;
            out routedPacket : DataPacket;
        }
        then action serverProcess {
            in request : DataPacket = routeToServer.routedPacket;
            out response : DataPacket;
        }
        then action routeToClient {
            in responsePacket : DataPacket = serverProcess.response;
            out deliveredResponse : DataPacket;
        }
        then action clientReceive {
            in finalResponse : DataPacket = routeToClient.deliveredResponse;
        }
        then done;
    }

    requirement <'REQ-INT-001'> globalConnectivity {
        doc /* The Internet system shall provide global connectivity enabling
             * any client device to communicate with any server through the
             * distributed network of routers and links.
             */
        subject internetSystem :> globalInternet;

        require packetDelivery;
        require networkCapacity;
        require lowLatency;
    }

    requirement <'REQ-INT-002'> packetDelivery {
        doc /* The system shall successfully deliver at least 99.9% of packets
             * to their intended destinations under normal operating conditions.
             */
        subject routers :>> globalInternet.coreRouters;

        assert constraint {
            routers.routePacket.forwardedPacket.state == PacketState::delivered
        }
    }

    requirement <'REQ-INT-003'> networkCapacity {
        doc /* The total network bandwidth shall support concurrent data
             * transmission from all connected clients with aggregate throughput
             * of at least 1 Tbps.
             */
        subject backbone :>> globalInternet;

        assert constraint {
            backbone.totalBandwidth >= 1000000.0
        }
    }

    requirement <'REQ-INT-004'> lowLatency {
        doc /* Average end-to-end network latency shall not exceed 100 milliseconds
             * for optimal user experience in real-time applications.
             */
        subject backbone :>> globalInternet;

        assert constraint {
            backbone.averageLatency <= 0.1
        }
    }

    requirement <'REQ-INT-005'> scalability {
        doc /* The system shall scale to support at least 10,000 concurrent
             * client connections while maintaining performance requirements.
             */
        subject internetSystem :>> globalInternet;

        assert constraint {
            internetSystem.totalClients >= 10000
        }
    }

    satisfy globalConnectivity by globalInternet;
}
