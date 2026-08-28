package InternetAccessSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type DataRateValue : RealValue {
        @Unit unit "Mbps";
    }
    value type LatencyValue : RealValue {
        @Unit unit "ms";
    }
    value type DataVolumeValue : RealValue {
        @Unit unit "MB";
    }
    value type PortNumberValue : IntegerValue {
        constraint { it in 0..65535 }
    }
    value type IPAddressValue : StringValue;
    value type DomainNameValue : StringValue;
    value type URLValue : StringValue;
    value type SecurityRuleIDValue : StringValue;

    // ===== Item Types =====
    item def DomainName;
    item def IPAddress;
    item def URL;
    item def DataPacket {
        attribute sourceIP : IPAddressValue;
        attribute destinationIP : IPAddressValue;
        attribute sourcePort : PortNumberValue;
        attribute destinationPort : PortNumberValue;
        attribute payloadSize : DataVolumeValue;
    }
    item def WebRequest :> DataPacket {
        attribute requestedURL : URLValue;
    }
    item def WebResponse :> DataPacket {
        attribute contentSize : DataVolumeValue;
        attribute statusCode : IntegerValue;
    }
    item def DNSQuery :> DataPacket {
        attribute domain : DomainNameValue;
    }
    item def DNSResponse :> DataPacket {
        attribute resolvedIP : IPAddressValue;
    }
    item def MaliciousPacket :> DataPacket;
    item def SecurityRule {
        attribute ruleID : SecurityRuleIDValue;
        attribute description : StringValue;
        attribute action : StringValue; // "allow" or "block"
    }
    item def WebPageContent {
        attribute htmlData : StringValue;
        attribute size : DataVolumeValue;
    }

    // ===== Port Definitions =====
    port def NetworkPort {
        in item dataPacket : DataPacket;
        out item forwardedPacket : DataPacket;
    }
    port def BrowserPort {
        out item webRequest : WebRequest;
        in item webResponse : WebResponse;
    }
    port def DNSPort {
        out item dnsQuery : DNSQuery;
        in item dnsResponse : DNSResponse;
    }
    port def ServerPort {
        in item incomingRequest : WebRequest;
        out item outgoingResponse : WebResponse;
    }
    port def ModemWANPort {
        in item upstreamPacket : DataPacket;
        out item downstreamPacket : DataPacket;
    }
    port def ModemLANPort {
        in item lanInbound : DataPacket;
        out item lanOutbound : DataPacket;
    }

    // ===== Requirements =====
    requirement def BandwidthRequirement {
        subject system : InternetAccessSystem;
        attribute minBandwidth : DataRateValue = 100.0;
        constraint { system.measuredBandwidth >= minBandwidth }
    }
    requirement def LatencyRequirement {
        subject system : InternetAccessSystem;
        attribute maxLatency : LatencyValue = 50.0;
        constraint { system.measuredLatency <= maxLatency }
    }
    requirement def SecurityRequirement {
        subject system : InternetAccessSystem;
        attribute requiredBlockedThreats : IntegerValue = 100;
        constraint { system.blockedThreatCount >= requiredBlockedThreats }
    }
    requirement def AvailabilityRequirement {
        subject system : InternetAccessSystem;
        attribute minUptimePercent : RealValue = 99.5;
        constraint { system.uptimePercent >= minUptimePercent }
    }

    // ===== State Machine for Modem =====
    state def ModemState;
    state def ModemStates :> ModemState {
        entry; then Offline;
        state Offline {
            entry action { /* modem powered off or disconnected */ }
            transition on ModemPowerOn to Synchronizing;
        }
        state Synchronizing {
            entry action { /* negotiate link with ISP */ }
            do action { /* exchange handshake signals */ }
            transition on SyncComplete to Online;
            transition on SyncFailed to Offline;
        }
        state Online {
            entry action { /* link established, data flow enabled */ }
            do action { /* transmit and receive data */ }
            transition on ModemPowerOff to Offline;
        }
    }

    // ===== Action Definitions =====
    action def ResolveDomain {
        in domain : DomainName;
        out ip : IPAddress;
    }
    action def EstablishConnection {
        in sourceIP : IPAddress;
        in destinationIP : IPAddress;
        out connectionEstablished : BooleanValue;
    }
    action def TransmitPacket {
        in packet : DataPacket;
        out transmitted : BooleanValue;
    }
    action def InspectPacket {
        in packet : DataPacket;
        in rules : SecurityRule[0..*];
        out inspectedPacket : DataPacket;
        out isBlocked : BooleanValue;
    }
    action def ForwardPacket {
        in packet : DataPacket;
        out forwardedPacket : DataPacket;
    }
    action def ProcessWebRequest {
        in request : WebRequest;
        out response : WebResponse;
    }
    action def RenderPage {
        in content : WebPageContent;
    }

    // ===== Part Definitions =====
    part def Modem {
        port wanPort : ModemWANPort;
        port lanPort : ModemLANPort;
        attribute currentModemState : ModemState;
        exhibit state modemBehavior : ModemStates;
        action convertSignals {
            in digitalData : DataPacket;
            out analogSignal : DataPacket;
        }
    }

    part def Router {
        port lanPort : NetworkPort;
        port wanPort : NetworkPort;
        attribute routingTable : IPAddressValue[0..*];
        action forwardTraffic : ForwardPacket;
    }

    part def Firewall {
        port internalPort : NetworkPort;
        port externalPort : NetworkPort;
        attribute securityRules : SecurityRule[0..*];
        action inspectTraffic : InspectPacket;
    }

    part def WebBrowser {
        port userPort : BrowserPort;
        attribute currentURL : URLValue;
        action sendRequest {
            out request : WebRequest;
        }
        action receiveResponse {
            in response : WebResponse;
        }
        action renderPage : RenderPage;
    }

    part def ISPNetwork {
        port ingressPort : NetworkPort;
        port egressPort : NetworkPort;
        attribute backboneBandwidth : DataRateValue = 10000.0;
        action routeTraffic : ForwardPacket;
    }

    part def WebServer {
        port serverPort : ServerPort;
        attribute hostedDomain : DomainNameValue;
        attribute serverIPAddress : IPAddressValue;
        action processRequest : ProcessWebRequest;
    }

    part def DNSResolver {
        port queryPort : DNSPort;
        attribute cache : DomainNameValue[0..*];
        action resolveDomain : ResolveDomain;
    }

    // ===== Top-Level System =====
    part def InternetAccessSystem {
        // Performance attributes
        attribute measuredBandwidth : DataRateValue = 150.0;
        attribute measuredLatency : LatencyValue = 30.0;
        attribute blockedThreatCount : IntegerValue = 150;
        attribute uptimePercent : RealValue = 99.9;

        // Requirements
        satisfy bandwidthReq : BandwidthRequirement {
            subject = InternetAccessSystem.this;
        }
        satisfy latencyReq : LatencyRequirement {
            subject = InternetAccessSystem.this;
        }
        satisfy securityReq : SecurityRequirement {
            subject = InternetAccessSystem.this;
        }
        satisfy availabilityReq : AvailabilityRequirement {
            subject = InternetAccessSystem.this;
        }

        // Parts
        part browser : WebBrowser;
        part firewall : Firewall;
        part router : Router;
        part modem : Modem;
        part ispNetwork : ISPNetwork;
        part dnsResolver : DNSResolver;
        part webServer : WebServer;

        // Connections - User side to ISP
        connection browserToFirewall connect browser.userPort to firewall.internalPort;
        connection firewallToRouter connect firewall.externalPort to router.wanPort;
        connection routerToModem connect router.lanPort to modem.lanPort;
        connection modemToISP connect modem.wanPort to ispNetwork.ingressPort;

        // ISP to Web Server
        connection ispToWebServer connect ispNetwork.egressPort to webServer.serverPort;

        // DNS path
        connection browserToDNS connect browser.userPort to dnsResolver.queryPort;
        connection dnsToISP connect dnsResolver.queryPort to ispNetwork.ingressPort;

        // End-to-end browsing action
        action browseWeb {
            // Step 1: User requests a webpage
            action initiateRequest : WebBrowser.sendRequest {
                out request : WebRequest;
            }
            // Step 2: DNS resolution
            action resolveDomainName : DNSResolver.resolveDomain {
                in domain : DomainName;
                out ip : IPAddress;
            }
            // Step 3: Firewall inspection (outbound)
            action inspectOutbound : Firewall.inspectTraffic {
                in packet : DataPacket;
                in rules : SecurityRule[0..*];
                out inspectedPacket : DataPacket;
                out isBlocked : BooleanValue;
            }
            // Step 4: Router forwarding
            action routeOutbound : Router.forwardTraffic {
                in packet : DataPacket;
                out forwardedPacket : DataPacket;
            }
            // Step 5: Modem conversion and transmission
            action modemTransmit : Modem.convertSignals {
                in digitalData : DataPacket;
                out analogSignal : DataPacket;
            }
            // Step 6: ISP routing
            action ispRoute : ISPNetwork.routeTraffic {
                in packet : DataPacket;
                out forwardedPacket : DataPacket;
            }
            // Step 7: Web server processes request
            action serverProcess : WebServer.processRequest {
                in request : WebRequest;
                out response : WebResponse;
            }
            // Step 8: ISP routes response back
            action ispRouteBack : ISPNetwork.routeTraffic {
                in packet : DataPacket;
                out forwardedPacket : DataPacket;
            }
            // Step 9: Modem receives and converts back
            action modemReceive : Modem.convertSignals {
                in analogSignal : DataPacket;
                out digitalData : DataPacket;
            }
            // Step 10: Router forwards to firewall
            action routeInbound : Router.forwardTraffic {
                in packet : DataPacket;
                out forwardedPacket : DataPacket;
            }
            // Step 11: Firewall inspection (inbound)
            action inspectInbound : Firewall.inspectTraffic {
                in packet : DataPacket;
                in rules : SecurityRule[0..*];
                out inspectedPacket : DataPacket;
                out isBlocked : BooleanValue;
            }
            // Step 12: Browser renders page
            action renderPage : WebBrowser.renderPage {
                in content : WebPageContent;
            }

            // Action flow
            flow initiateRequest.request to resolveDomainName.domain;
            flow resolveDomainName.ip to inspectOutbound.packet;
            flow inspectOutbound.inspectedPacket to routeOutbound.packet;
            flow routeOutbound.forwardedPacket to modemTransmit.digitalData;
            flow modemTransmit.analogSignal to ispRoute.packet;
            flow ispRoute.forwardedPacket to serverProcess.request;
            flow serverProcess.response to ispRouteBack.packet;
            flow ispRouteBack.forwardedPacket to modemReceive.analogSignal;
            flow modemReceive.digitalData to routeInbound.packet;
            flow routeInbound.forwardedPacket to inspectInbound.packet;
            flow inspectInbound.inspectedPacket to renderPage.content;
        }
    }
}
