package InternetAccessSystem {
    private import ScalarValues::*;
    private import SI::*;
    
    item def DataPacket {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute sequenceNumber : Integer;
    }
    
    item def WebRequest :> DataPacket {
        attribute url : String;
        attribute httpMethod : String;
    }
    
    item def WebResponse :> DataPacket {
        attribute statusCode : Integer;
        attribute content : String;
        attribute contentType : String;
    }
    
    item def DNSQuery {
        attribute domainName : String;
        attribute queryId : Integer;
    }
    
    item def DNSResponse {
        attribute domainName : String;
        attribute ipAddress : String;
        attribute ttl : Integer;
    }
    
    item def SecurityRule {
        attribute ruleID : String;
        attribute sourceIP : String[0..1];
        attribute destinationIP : String[0..1];
        attribute portNum : Integer[0..1];
        attribute actionType : String;
    }
    
    port def NetPort {
        in ref inData : DataPacket;
        out ref outData : DataPacket;
    }
    
    port def LANPort :> NetPort;
    port def WANPort :> NetPort;
    
    port def DNSPort {
        in ref inQuery : DNSQuery;
        out ref outResponse : DNSResponse;
    }
    
    interface def NetworkLink {
        end source : ~NetPort;
        end target : NetPort;
    }
    
    interface def DNSLink {
        end source : ~DNSPort;
        end target : DNSPort;
    }
    
    attribute def DataRate :> Real;
    attribute def Latency :> Real;
    
    part def Modem {
        doc
        /*
         * Establishes physical connection to the ISP.
         * Converts digital data into signals suitable for the ISP network.
         */
        port lanPort : LANPort;
        port wanPort : WANPort;
        attribute macAddress : String;
        attribute ispConnectionType : String;
        attribute maxDownstreamRate : DataRate;
        attribute maxUpstreamRate : DataRate;
        
        state modemState {
            state offline;
            state synchronizing {
                entry action performHandshake;
            }
            state online {
                entry action establishLink;
            }
            transition initiateSync from offline to synchronizing;
            transition syncComplete from synchronizing to online;
            transition connectionLost from online to offline;
        }
        
        perform action forwarding {
            in ref inputPacket : DataPacket;
            out ref outputPacket : DataPacket;
            action modulate {
                in ref input : DataPacket;
                out ref output : DataPacket = input;
            }
        }
        flow inFlow from lanPort.inData to forwarding.inputPacket;
        flow outFlow from forwarding.modulate.output to wanPort.outData;
    }
    
    part def Router {
        doc
        /*
         * Manages the local network. Directs traffic between
         * multiple devices and the single internet connection.
         */
        port lanPort : LANPort;
        port wanPort : WANPort;
        attribute routingTable : String[*];
        attribute localSubnet : String;
        attribute defaultGateway : String;
        
        perform action routing {
            in ref inputPacket : DataPacket;
            out ref outputPacket : DataPacket;
            action lookupRoute {
                in ref packet : DataPacket;
                out ref destination : String = packet.destinationAddress;
            }
            then action forward {
                in ref packet : DataPacket;
                out ref output : DataPacket = packet;
            }
        }
        flow inFlow from lanPort.inData to routing.inputPacket;
        flow outFlow from routing.forward.output to wanPort.outData;
    }
    
    part def Firewall {
        doc
        /*
         * Inspects all incoming and outgoing network traffic.
         * Blocks potentially malicious data based on security rules.
         */
        port downstreamPort : LANPort;
        port upstreamPort : WANPort;
        attribute securityRules : SecurityRule[*];
        attribute blockedCount : Integer;
        attribute allowedCount : Integer;
        
        perform action inspection {
            in ref inputPacket : DataPacket;
            out ref outputPacket : DataPacket;
            action checkRules {
                in ref packet : DataPacket;
                out ref isMalicious : Boolean;
            }
            then action passPacket {
                in ref packet : DataPacket;
                in ref isMalicious : Boolean;
                out ref output : DataPacket = packet;
            }
        }
        flow inFlow from downstreamPort.inData to inspection.inputPacket;
        flow outFlow from inspection.passPacket.output to upstreamPort.outData;
    }
    
    part def WebBrowser {
        doc
        /*
         * Sends requests for websites and interprets received data
         * to render pages for the user.
         */
        port netPort : ~NetPort {
            out ref :>> inData;
            in ref :>> outData;
        }
        port dnsPort : ~DNSPort {
            out ref :>> inQuery;
            in ref :>> outResponse;
        }
        attribute currentURL : String;
        attribute renderedContent : String;
        attribute userAgent : String;
        
        perform action browse {
            action resolveDomain {
                out ref query : DNSQuery = new DNSQuery(currentURL, 1);
            }
            then action receiveDNS {
                in ref response : DNSResponse;
                out ref resolvedIP : String = response.ipAddress;
            }
            then action sendRequest {
                in ref ip : String;
                out ref request : WebRequest = new WebRequest("192.168.1.100", ip, 1, currentURL, "GET");
            }
            then action receiveResponse {
                in ref response : WebResponse;
                out ref content : String = response.content;
            }
            then action renderPage {
                in ref content : String;
                out ref rendered : String = content;
            }
        }
        flow dnsQueryFlow from browse.resolveDomain.query to dnsPort.inQuery;
        flow dnsResponseFlow from dnsPort.outResponse to browse.receiveDNS.response;
        flow requestFlow from browse.sendRequest.request to netPort.inData;
        flow responseFlow from netPort.outData to browse.receiveResponse.response;
    }
    
    part def DNSResolver {
        doc
        /*
         * Translates human-readable website names into
         * numerical IP addresses. Acts as the internet phonebook.
         */
        port dnsPort : DNSPort;
        attribute dnsCache : String[*];
        attribute upstreamServers : String[*];
        
        perform action resolve {
            in ref query : DNSQuery;
            out ref response : DNSResponse;
            action checkCache {
                in ref domainName : String;
                out ref found : Boolean;
                out ref cachedIP : String;
            }
            then action returnResult {
                in ref domainName : String;
                in ref ip : String;
                out ref response : DNSResponse = new DNSResponse(domainName, ip, 3600);
            }
        }
        flow queryIn from dnsPort.inQuery to resolve.query;
        flow responseOut from resolve.returnResult.response to dnsPort.outResponse;
    }
    
    part def WebServer {
        doc
        /*
         * Hosts website content and responds to browser requests.
         */
        port netPort : NetPort;
        attribute serverIP : String;
        attribute hostedContent : String;
        attribute portNumber : Integer;
        attribute maxConnections : Integer;
        
        perform action serve {
            in ref request : WebRequest;
            out ref response : WebResponse;
            action processRequest {
                in ref req : WebRequest;
                out ref resp : WebResponse = new WebResponse(req.sourceAddress, serverIP, req.sequenceNumber, 200, hostedContent, "text/html");
            }
        }
        flow requestIn from netPort.inData to serve.request;
        flow responseOut from serve.processRequest.resp to netPort.outData;
    }
    
    part def ISPNetwork {
        doc
        /*
         * Large-scale infrastructure that routes traffic
         * across the internet between clients and servers.
         */
        port ingressPort : WANPort;
        port egressPort : WANPort;
        attribute backboneNodes : Integer;
        attribute peeringPoints : Integer;
        attribute routingCapacity : DataRate;
        
        perform action routeTraffic {
            in ref inputPacket : DataPacket;
            out ref outputPacket : DataPacket;
            action route {
                in ref input : DataPacket;
                out ref output : DataPacket = input;
            }
        }
        flow inFlow from ingressPort.inData to routeTraffic.inputPacket;
        flow outFlow from routeTraffic.route.output to egressPort.outData;
    }
    
    part def InternetAccessAssembly {
        doc
        /*
         * Complete internet access system assembly connecting all
         * components for end-to-end web browsing.
         */
        part userBrowser : WebBrowser {
            attribute currentURL : String = "www.example.com";
            attribute userAgent : String = "Mozilla/5.0";
        }
        part localDNS : DNSResolver;
        part localFirewall : Firewall {
            attribute securityRules : SecurityRule[*] = (
                new SecurityRule("R1", "", "", 22, "BLOCK"),
                new SecurityRule("R2", "", "", 23, "BLOCK"),
                new SecurityRule("R3", "", "", 80, "ALLOW"),
                new SecurityRule("R4", "", "", 443, "ALLOW")
            );
        }
        part localRouter : Router {
            attribute localSubnet : String = "192.168.1.0/24";
            attribute defaultGateway : String = "192.168.1.1";
        }
        part localModem : Modem {
            attribute ispConnectionType : String = "DOCSIS 3.1";
            attribute maxDownstreamRate : DataRate = 1000000000;
            attribute maxUpstreamRate : DataRate = 100000000;
        }
        part ispNet : ISPNetwork {
            attribute backboneNodes : Integer = 12;
            attribute peeringPoints : Integer = 5;
        }
        part remoteServer : WebServer {
            attribute serverIP : String = "93.184.216.34";
            attribute hostedContent : String = "<html><body>Example Domain</body></html>";
            attribute portNumber : Integer = 443;
        }
        
        interface dnsConnection : DNSLink connect userBrowser.dnsPort to localDNS.dnsPort;
        interface browserToFirewall : NetworkLink connect userBrowser.netPort to localFirewall.downstreamPort;
        interface firewallToRouter : NetworkLink connect localFirewall.upstreamPort to localRouter.lanPort;
        interface routerToModem : NetworkLink connect localRouter.wanPort to localModem.lanPort;
        interface modemToISP : NetworkLink connect localModem.wanPort to ispNet.ingressPort;
        interface ispToServer : NetworkLink connect ispNet.egressPort to remoteServer.netPort;
    }
    
    requirement def BandwidthRequirement {
        doc /* System shall provide adequate bandwidth for web browsing. */
        attribute minDownstreamRate : DataRate;
        attribute minUpstreamRate : DataRate;
    }
    
    requirement def LatencyRequirement {
        doc /* System shall meet latency targets for responsive browsing. */
        attribute maxRoundTripLatency : Latency;
    }
    
    requirement def SecurityRequirement {
        doc /* System shall filter malicious traffic through firewall. */
        attribute minSecurityRules : Integer;
        attribute blockMaliciousTraffic : Boolean;
    }
    
    requirement def AvailabilityRequirement {
        doc /* System shall maintain modem availability. */
        attribute uptime : Real;
    }
    
    requirement bandwidthSpec : BandwidthRequirement {
        attribute minDownstreamRate = 25000000;
        attribute minUpstreamRate = 5000000;
    }
    
    requirement latencySpec : LatencyRequirement {
        attribute maxRoundTripLatency = 100;
    }
    
    requirement securitySpec : SecurityRequirement {
        attribute minSecurityRules = 10;
        attribute blockMaliciousTraffic = true;
    }
    
    requirement availabilitySpec : AvailabilityRequirement {
        attribute uptime = 99.5;
    }
}
