package 'Internet Access System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DataRate :> Real;
    
    attribute def Latency :> Real;
    
    attribute def IPAddress :> String;
    
    attribute def URL :> String;
    
    item def DataPacket {
        attribute sourceAddress : IPAddress;
        attribute destinationAddress : IPAddress;
        attribute payload : String;
        attribute size : Real;
    }
    
    item def HTTPRequest {
        attribute requestURL : URL;
        attribute method : String;
    }
    
    item def HTTPResponse {
        attribute statusCode : Integer;
        attribute content : String;
    }
    
    port def NetworkPort {
        out item transmittedPackets : DataPacket[*];
        in item receivedPackets : DataPacket[*];
        attribute bandwidth : DataRate;
    }
    
    part def Modem {
        doc /* Modulates and demodulates signals between digital and analog formats for ISP communication. */
        attribute maxDownloadSpeed : DataRate;
        attribute maxUploadSpeed : DataRate;
        
        port wanPort : NetworkPort;
        port lanPort : NetworkPort;
        
        state def ModemState {
            entry; then offline;
            
            state offline;
            transition offline_to_syncing
                first offline
                then syncing;
            
            state syncing;
            transition syncing_to_online
                first syncing
                then online;
            
            state online;
            transition online_to_syncing
                first online
                then syncing;
        }
    }
    
    part def Router {
        doc /* Routes data packets between local network devices and the internet gateway. */
        attribute routingTableSize : Integer;
        
        port wanPort : NetworkPort;
        port lanPorts : NetworkPort[4];
        
        action routePacket {
            in packet : DataPacket;
            out routedPacket : DataPacket;
            out destinationPort : Integer;
        }
        
        action performNAT {
            in privateAddress : IPAddress;
            in publicAddress : IPAddress;
            out translatedPacket : DataPacket;
        }
        
        state def RouterState {
            entry; then idle;
            
            state idle;
            transition idle_to_routing
                first idle
                then routing;
            
            state routing;
            transition routing_to_forwarding
                first routing
                then forwarding;
            
            state forwarding;
            transition forwarding_to_idle
                first forwarding
                then idle;
        }
    }
    
    part def DNSResolver {
        doc /* Resolves domain names to IP addresses for web navigation. */
        attribute cacheSize : Integer;
        
        port queryPort : NetworkPort;
        
        action resolveDomain {
            in domainName : URL;
            out resolvedIP : IPAddress;
        }
    }
    
    part def Firewall {
        doc /* Inspects and filters network traffic based on security rules. */
        attribute ruleCount : Integer;
        
        port inboundPort : NetworkPort;
        port outboundPort : NetworkPort;
        
        action inspectPacket {
            in packet : DataPacket;
            out isAllowed : Boolean;
        }
        
        action filterTraffic {
            in packet : DataPacket;
            out filteredPacket : DataPacket;
        }
    }
    
    part def WebBrowser {
        doc /* Sends HTTP requests and renders web content for the user. */
        attribute userAgent : String;
        
        port networkPort : NetworkPort;
        
        action sendHTTPRequest {
            in url : URL;
            out request : HTTPRequest;
        }
        
        action receiveHTTPResponse {
            in response : HTTPResponse;
            out renderedContent : String;
        }
    }
    
    part def ISPNetwork {
        doc /* Provides connectivity to the global internet infrastructure. */
        attribute networkCapacity : DataRate;
        
        port customerPort : NetworkPort;
        port backbonePort : NetworkPort;
        
        action routeToInternet {
            in packet : DataPacket;
            out routedPacket : DataPacket;
        }
    }
    
    part def WebServer {
        doc /* Hosts web content and responds to HTTP requests. */
        attribute serverAddress : IPAddress;
        
        port networkPort : NetworkPort;
        
        action processRequest {
            in request : HTTPRequest;
            out response : HTTPResponse;
        }
    }
    
    action def EstablishConnection {
        in sourceIP : IPAddress;
        in destinationIP : IPAddress;
        out connectionEstablished : Boolean;
    }
    
    action def TransmitData {
        in data : DataPacket;
        in bandwidth : DataRate;
        out transmissionTime : Real;
    }
    
    action def ProvideInternetAccess {
        doc /* Primary system behavior: enables user to access web content through coordinated network operations. */
        in userRequest : HTTPRequest;
        out userResponse : HTTPResponse;
        
        first start;
        then action initiateRequest {
            in url : URL;
            out request : HTTPRequest;
        }
        
        then action resolveDNS {
            in domainName : URL;
            out resolvedIP : IPAddress;
        }
        
        then action establishConn : EstablishConnection {
            in sourceIP : IPAddress;
            in destinationIP : IPAddress;
            out connectionEstablished : Boolean;
        }
        
        then decide;
            if establishConn.connectionEstablished then transmitRequest;
            if not establishConn.connectionEstablished then handleError;
        
        action transmitRequest : TransmitData {
            in data : DataPacket;
            in bandwidth : DataRate;
            out transmissionTime : Real;
        }
        then action filterOutbound {
            in packet : DataPacket;
            out filteredPacket : DataPacket;
        }
        
        then action routeToServer {
            in packet : DataPacket;
            out routedPacket : DataPacket;
        }
        
        then action serverProcess {
            in request : HTTPRequest;
            out response : HTTPResponse;
        }
        
        then action transmitResponse : TransmitData {
            in data : DataPacket;
            in bandwidth : DataRate;
            out transmissionTime : Real;
        }
        
        then action filterInbound {
            in packet : DataPacket;
            out filteredPacket : DataPacket;
        }
        
        then action renderContent {
            in response : HTTPResponse;
            out renderedContent : String;
        }
        
        then done;
        
        action handleError {
            out errorResponse : HTTPResponse;
        }
        then done;
    }
    
    part def InternetAccessSystem {
        doc /* Complete internet access system providing reliable connectivity from user devices to web servers. */
        
        attribute systemBandwidth : DataRate;
        attribute averageLatency : Latency;
        
        part userModem : Modem {
            attribute :>> maxDownloadSpeed = 1000.0;
            attribute :>> maxUploadSpeed = 100.0;
        }
        
        part userRouter : Router {
            attribute :>> routingTableSize = 256;
        }
        
        part dnsResolver : DNSResolver {
            attribute :>> cacheSize = 1000;
        }
        
        part firewall : Firewall {
            attribute :>> ruleCount = 50;
        }
        
        part browser : WebBrowser {
            attribute :>> userAgent = "Mozilla/5.0";
        }
        
        part ispNetwork : ISPNetwork {
            attribute :>> networkCapacity = 10000.0;
        }
        
        part webServer : WebServer {
            attribute :>> serverAddress = "203.0.113.42";
        }
        
        connection modemToRouter connect 
            userModem.lanPort to userRouter.wanPort;
        
        connection routerToFirewall connect
            userRouter.lanPorts to firewall.inboundPort;
        
        connection firewallToBrowser connect
            firewall.outboundPort to browser.networkPort;
        
        connection modemToISP connect
            userModem.wanPort to ispNetwork.customerPort;
        
        connection ispToServer connect
            ispNetwork.backbonePort to webServer.networkPort;
        
        perform action provideAccess : ProvideInternetAccess[*] ordered;
    }
    
    requirement def BandwidthRequirement {
        doc /* Bandwidth performance requirement. */
    }
    
    requirement def LatencyRequirement {
        doc /* Latency performance requirement. */
    }
    
    requirement def SecurityRequirement {
        doc /* Security requirement. */
    }
    
    requirement def InternetAccessRequirement {
        doc /* The internet access system shall provide reliable connectivity to remote web servers with acceptable performance. */
        
        subject system : InternetAccessSystem;
        
        require bandwidthRequirement : BandwidthRequirement;
        require latencyRequirement : LatencyRequirement;
        require securityRequirement : SecurityRequirement;
    }
    
    requirement bandwidthRequirement : BandwidthRequirement {
        doc /* The system shall support minimum download speeds of 100 Mbps and upload speeds of 10 Mbps. */
        
        attribute minDownload : DataRate = 100.0;
        attribute minUpload : DataRate = 10.0;
        
        require constraint {
            internetAccessSystem.userModem.maxDownloadSpeed >= minDownload and
            internetAccessSystem.userModem.maxUploadSpeed >= minUpload
        }
    }
    
    requirement latencyRequirement : LatencyRequirement {
        doc /* The system shall maintain average latency below 50 milliseconds for typical web requests. */
        
        attribute maxLatency : Latency = 50.0;
        
        require constraint {
            internetAccessSystem.averageLatency <= maxLatency
        }
    }
    
    requirement securityRequirement : SecurityRequirement {
        doc /* The system shall filter malicious traffic and protect user data through firewall inspection. */
        
        require constraint {
            internetAccessSystem.firewall.ruleCount > 0
        }
    }
    
    part internetAccessSystem : InternetAccessSystem;
    
    requirement <'SYS-001'> internetSystemRequirement : InternetAccessRequirement {
        subject system = internetAccessSystem;
        
        assume constraint validConfiguration {
            internetAccessSystem.userModem.maxDownloadSpeed > 0.0 and
            internetAccessSystem.userRouter.routingTableSize > 0
        }
    }
}
