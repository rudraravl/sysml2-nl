package GlobalInternetModel {
    import ScalarValues::*;
    
    // --- Item Definitions ---
    item def IPv4Address {
        attribute octet1 : Integer;
        attribute octet2 : Integer;
        attribute octet3 : Integer;
        attribute octet4 : Integer;
    }
    
    item def Payload {
        attribute size : Integer; // in bytes
    }
    
    item def ProtocolInfo {
        attribute protocolType : String;
        attribute ttl : Integer; // Time to live
    }
    
    item def DataPacket {
        attribute sourceIP : IPv4Address;
        attribute destinationIP : IPv4Address;
        attribute payload : Payload;
        attribute protocolInfo : ProtocolInfo;
    }
    
    // --- Port Definitions ---
    port def NetworkPort {
        attribute ipAddress : IPv4Address;
        out packetOut : DataPacket;
        in packetIn : DataPacket;
    }
    
    // --- Part Definitions ---
    part def NetworkLink {
        attribute bandwidth : Integer; // Mbps
        attribute latency : Real; // ms
        attribute reliability : Real; // 0.0 to 1.0
        
        port linkEndA : ~NetworkPort;
        port linkEndB : ~NetworkPort;
    }
    
    part def NetworkNode {
        port eth0 : NetworkPort;
    }
    
    part def ClientDevice :> NetworkNode {
        attribute deviceType : String;
        
        state ClientBehavior {
            state Idle;
            state SendingRequest {
                entry action sendPacket { 
                    // send DataPacket via eth0 
                }
            }
            state WaitingResponse;
            state ProcessingResponse {
                entry action processPacket { 
                    // process received DataPacket 
                }
            }
            
            transition first Idle to SendingRequest;
            transition SendingRequest to WaitingResponse;
            transition WaitingResponse to ProcessingResponse;
            transition ProcessingResponse to Idle;
        }
    }
    
    part def Server :> NetworkNode {
        attribute serverType : String;
        
        state ServerBehavior {
            state Idle;
            state ProcessingRequest {
                entry action processRequest { 
                    // process incoming DataPacket 
                }
            }
            state SendingResponse {
                entry action sendResponse { 
                    // send DataPacket via eth0 
                }
            }
            
            transition first Idle to ProcessingRequest;
            transition ProcessingRequest to SendingResponse;
            transition SendingResponse to Idle;
        }
    }
    
    part def ContentServer :> Server {
        attribute content : String;
    }
    
    part def DNSServer :> Server {
        attribute dnsRecords : String;
    }
    
    part def Router :> NetworkNode {
        port eth1 : NetworkPort;
        port eth2 : NetworkPort;
        
        action route {
            in incomingPacket : DataPacket;
            out outgoingPacket : DataPacket;
        }
    }
    
    part def EdgeRouter :> Router {
        // Connects clients to core
    }
    
    part def CoreRouter :> Router {
        // High-capacity backbone
    }
    
    part def NetworkMonitor {
        attribute networkLoad : Real;
        
        action monitorLoad {
            out load : Real;
        }
        
        action manageTraffic {
            in load : Real;
            out routingUpdate : String;
        }
    }
    
    // --- Requirements ---
    requirement def PerformanceRequirements {
        requirement latencyReq {
            doc "The end-to-end latency must be less than 50 ms."
            attribute maxLatency : Real = 50.0; // ms
        }
        requirement bandwidthReq {
            doc "The core network bandwidth must be at least 10000 Mbps."
            attribute minBandwidth : Integer = 10000; // Mbps
        }
        requirement reliabilityReq {
            doc "The packet delivery reliability must be at least 99.99%."
            attribute minReliability : Real = 0.9999;
        }
    }
    
    // --- System Assembly ---
    part def GlobalInternet {
        satisfy PerformanceRequirements;
        
        part clients : ClientDevice[*];
        part servers : Server[*];
        part edgeRouters : EdgeRouter[*];
        part coreRouters : CoreRouter[*];
        part links : NetworkLink[*];
        part monitor : NetworkMonitor;
    }
    
    part globalInternet : GlobalInternet {
        part client1 : ClientDevice {
            attribute deviceType = "PC";
        }
        part edge1 : EdgeRouter;
        part core1 : CoreRouter;
        part server1 : ContentServer;
        part dns1 : DNSServer;
        part monitor1 : NetworkMonitor;
        
        part link1 : NetworkLink {
            attribute bandwidth = 1000;
            attribute latency = 5.0;
            attribute reliability = 0.999;
        }
        part link2 : NetworkLink {
            attribute bandwidth = 10000;
            attribute latency = 2.0;
            attribute reliability = 0.9999;
        }
        part link3 : NetworkLink {
            attribute bandwidth = 10000;
            attribute latency = 2.0;
            attribute reliability = 0.9999;
        }
        part link4 : NetworkLink {
            attribute bandwidth = 1000;
            attribute latency = 5.0;
            attribute reliability = 0.999;
        }
        
        connect client1.eth0 to link1.linkEndA;
        connect edge1.eth0 to link1.linkEndB;
        
        connect edge1.eth1 to link2.linkEndA;
        connect core1.eth0 to link2.linkEndB;
        
        connect core1.eth1 to link3.linkEndA;
        connect server1.eth0 to link3.linkEndB;
        
        connect core1.eth2 to link4.linkEndA;
        connect dns1.eth0 to link4.linkEndB;
    }
}
