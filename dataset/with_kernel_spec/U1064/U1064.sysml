package GPRSNetwork {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQSpaceTime::*;
    private import ISQElectromagnetism::*;

    // ---- Value Types ----
    attribute def BatteryLevel :> ScalarValues::Real;
    attribute def SignalStrength :> ScalarValues::Real;
    attribute def Frequency :> ScalarValues::Real;
    attribute def DataRate :> ScalarValues::Real;

    // ---- Item Definitions ----
    item def IMSI {
        attribute value : String;
    }
    item def IPAddress {
        attribute value : String;
    }
    item def CellId {
        attribute value : Integer;
    }
    item def RoutingAreaCode {
        attribute value : Integer;
    }
    item def AccessPointName {
        attribute value : String;
    }
    item def DataVolume {
        attribute bytes : Integer;
    }

    item def AttachRequest {
        attribute imsi : IMSI;
    }
    item def AttachAccept {
        attribute routingArea : RoutingAreaCode;
        attribute temporaryId : String;
    }
    item def PDPContextRequest {
        attribute imsi : IMSI;
        attribute accessPointName : AccessPointName;
    }
    item def PDPContextResponse {
        attribute ipAddress : IPAddress;
        attribute contextId : String;
    }
    item def DataPacket {
        attribute sourceIP : IPAddress;
        attribute destinationIP : IPAddress;
        attribute payload : String;
        attribute size : DataVolume;
        attribute sequenceNumber : Integer;
    }
    item def DetachRequest {
        attribute imsi : IMSI;
    }
    item def DetachAccept {
        attribute imsi : IMSI;
    }
    item def AuthenticationChallenge {
        attribute randValue : String;
    }
    item def AuthenticationResponse {
        attribute sresValue : String;
    }

    // ---- Port Definitions ----
    port def UmRadioPort {
        out item attachRequest : AttachRequest;
        in item attachAccept : AttachAccept;
        out item pdpContextRequest : PDPContextRequest;
        in item pdpContextResponse : PDPContextResponse;
        out item detachRequest : DetachRequest;
        in item detachAccept : DetachAccept;
        out item uplinkData : DataPacket;
        in item downlinkData : DataPacket;
        attribute frequency : Frequency;
    }
    port def AbisPort {
        inout item attachRequest : AttachRequest;
        inout item attachAccept : AttachAccept;
        inout item pdpContextRequest : PDPContextRequest;
        inout item pdpContextResponse : PDPContextResponse;
        inout item detachRequest : DetachRequest;
        inout item detachAccept : DetachAccept;
        inout item data : DataPacket;
    }
    port def GbPort {
        inout item attachRequest : AttachRequest;
        inout item attachAccept : AttachAccept;
        inout item pdpContextRequest : PDPContextRequest;
        inout item pdpContextResponse : PDPContextResponse;
        inout item detachRequest : DetachRequest;
        inout item detachAccept : DetachAccept;
        inout item uplinkData : DataPacket;
        inout item downlinkData : DataPacket;
        inout item authChallenge : AuthenticationChallenge;
        inout item authResponse : AuthenticationResponse;
    }
    port def GnPort {
        inout item pdpContextRequest : PDPContextRequest;
        inout item pdpContextResponse : PDPContextResponse;
        inout item detachRequest : DetachRequest;
        inout item detachAccept : DetachAccept;
        inout item data : DataPacket;
    }
    port def GiPort {
        inout item data : DataPacket;
    }

    // ---- Action Definitions ----
    action def AuthenticateSubscriber {
        in item req : AttachRequest;
        out item challenge : AuthenticationChallenge;
        in item response : AuthenticationResponse;
        out item attachAccept : AttachAccept;
        first start;
        then action sendChallenge {
            out item ch : AuthenticationChallenge = new AuthenticationChallenge("random123");
        }
        then action verifyResponse {
            in item resp : AuthenticationResponse = response;
        }
        then action grantAccess {
            out item acc : AttachAccept = new AttachAccept(new RoutingAreaCode(1), "tempId456");
        }
        then done;
        bind challenge = sendChallenge.ch;
        bind attachAccept = grantAccess.acc;
    }

    action def AssignIPAddress {
        in item req : PDPContextRequest;
        out item resp : PDPContextResponse;
        first start;
        then action allocateIP {
            in item inReq : PDPContextRequest = req;
            out item assignedIP : IPAddress = new IPAddress("10.0.0.1");
        }
        then action createContext {
            in item ip : IPAddress = allocateIP.assignedIP;
            out item contextId : String = "ctx001";
        }
        then action buildResponse {
            in item ip : IPAddress = allocateIP.assignedIP;
            in item ctxId : String = createContext.contextId;
            out item outResp : PDPContextResponse = new PDPContextResponse(ip, ctxId);
        }
        then done;
        bind resp = buildResponse.outResp;
    }

    action def RouteDataPacket {
        in item packet : DataPacket;
        out item routedPacket : DataPacket;
        first start;
        then action forward {
            in item inPkt : DataPacket = packet;
            out item outPkt : DataPacket = inPkt;
        }
        then done;
        bind routedPacket = forward.outPkt;
    }

    action def FirewallCheck {
        in item packet : DataPacket;
        out item filteredPacket : DataPacket;
        first start;
        then action inspect {
            in item inPkt : DataPacket = packet;
            out item outPkt : DataPacket = inPkt;
        }
        then done;
        bind filteredPacket = inspect.outPkt;
    }

    // ---- Part Definitions ----
    part def MobileStation {
        attribute imsi : IMSI;
        attribute batteryLevel : BatteryLevel;
        attribute assignedIP : IPAddress;
        attribute signalStrength : SignalStrength;
        port radio : UmRadioPort;

        state MS_SessionLifecycle {
            entry assign batteryLevel = 75;
            initial;
            transition from initial to idle;

            state idle {
                transition from idle to attaching
                    when batteryLevel > 5;
            }
            state attaching {
                entry send new AttachRequest(imsi) via radio;
                accept acc : AttachAccept via radio;
                then active;
            }
            state active {
                entry send new PDPContextRequest(imsi, new AccessPointName("internet")) via radio;
                accept resp : PDPContextResponse via radio;
                do assign assignedIP = resp.ipAddress;
                then transferring;
            }
            state transferring {
                entry send new DataPacket(assignedIP, new IPAddress("0.0.0.0"), "payload", new DataVolume(1024), 1) via radio;
                accept pkt : DataPacket via radio;
                then transferring;
                transition from transferring to releasing
                    when batteryLevel < 10;
            }
            state releasing {
                entry send new DetachRequest(imsi) via radio;
                accept dacc : DetachAccept via radio;
                then idle;
            }
        }
    }

    part def BaseTransceiverStation {
        attribute cellId : CellId;
        attribute coverageRadiusKm : Real;
        attribute operatingFrequency : Frequency;
        port radio : UmRadioPort;
        port abis : AbisPort;

        action relayPacket {
            in item pkt : DataPacket;
            out item fwdPkt : DataPacket;
            first start;
            then action forward {
                in item inPkt : DataPacket = pkt;
                out item outPkt : DataPacket = inPkt;
            }
            then done;
            bind fwdPkt = forward.outPkt;
        }
    }

    part def BaseStationController {
        attribute bscId : String;
        attribute managedCellIds : CellId[1..*];
        attribute routingArea : RoutingAreaCode;
        port abis : AbisPort;
        port gb : GbPort;

        action manageRadioResources {
            in item req : AttachRequest;
            out item fwdReq : AttachRequest;
            first start;
            then action allocate {
                in item inReq : AttachRequest = req;
                out item outReq : AttachRequest = inReq;
            }
            then done;
            bind fwdReq = allocate.outReq;
        }
    }

    part def BaseStationSubsystem {
        attribute bssId : String;
        part btsList : BaseTransceiverStation[1..*];
        part bsc : BaseStationController;

        port radio : UmRadioPort;
        port gb : GbPort;

        connect radio to btsList.radio;
        connect btsList.abis to bsc.abis;
        connect bsc.gb to gb;
    }

    part def SGSN {
        attribute sgsnId : String;
        attribute routingArea : RoutingAreaCode;
        attribute registeredIMSI : IMSI[0..*];
        port gb : GbPort;
        port gn : GnPort;

        action authenticateMS {
            in item req : AttachRequest;
            out item challenge : AuthenticationChallenge;
            in item response : AuthenticationResponse;
            out item attachAccept : AttachAccept;
            first start;
            then action sendChallenge {
                out item ch : AuthenticationChallenge = new AuthenticationChallenge("random123");
            }
            then action verifyResponse {
                in item resp : AuthenticationResponse = response;
            }
            then action grantAccess {
                out item acc : AttachAccept = new AttachAccept(routingArea, "tempId456");
            }
            then done;
            bind challenge = sendChallenge.ch;
            bind attachAccept = grantAccess.acc;
        }

        action routePacket {
            in item pkt : DataPacket;
            out item fwdPkt : DataPacket;
            first start;
            then action forwardToGGSN {
                in item inPkt : DataPacket = pkt;
                out item outPkt : DataPacket = inPkt;
            }
            then done;
            bind fwdPkt = forwardToGGSN.outPkt;
        }

        state SGSN_SessionManagement {
            initial;
            transition from initial to waiting;
            state waiting {
                accept req : AttachRequest via gb;
                then authenticating;
            }
            state authenticating {
                entry authenticateMS;
                then waitingPDP;
            }
            state waitingPDP {
                accept req : PDPContextRequest via gb;
                do send new PDPContextRequest(req.imsi, req.accessPointName) via gn;
                then waitingGGSN;
            }
            state waitingGGSN {
                accept resp : PDPContextResponse via gn;
                do send new PDPContextResponse(resp.ipAddress, resp.contextId) via gb;
                then active;
            }
            state active {
                accept data : DataPacket via gb;
                do routePacket;
                then active;
            }
        }
    }

    part def GGSN {
        attribute ggsnId : String;
        attribute ipPool : IPAddress[1..*];
        attribute activeContexts : String[0..*];
        port gn : GnPort;
        port gi : GiPort;
        part ipRouter;
        part firewall;

        action createPDPContext {
            in item req : PDPContextRequest;
            out item resp : PDPContextResponse;
            first start;
            then action assignIP {
                in item inReq : PDPContextRequest = req;
                out item assignedIP : IPAddress = new IPAddress("10.0.0.1");
            }
            then action createContext {
                in item ip : IPAddress = assignIP.assignedIP;
                out item contextId : String = "ctx001";
            }
            then action buildResponse {
                in item ip : IPAddress = assignIP.assignedIP;
                in item ctxId : String = createContext.contextId;
                out item outResp : PDPContextResponse = new PDPContextResponse(ip, ctxId);
            }
            then done;
            bind resp = buildResponse.outResp;
        }

        action routeToExternal {
            in item pkt : DataPacket;
            out item outPkt : DataPacket;
            first start;
            then action firewallCheck {
                in item inPkt : DataPacket = pkt;
                out item filteredPkt : DataPacket = inPkt;
            }
            then action route {
                in item inPkt : DataPacket = firewallCheck.filteredPkt;
                out item outPkt : DataPacket = inPkt;
            }
            then done;
            bind outPkt = route.outPkt;
        }

        state pdpContextManager {
            initial;
            transition from initial to waitPDP;
            state waitPDP {
                accept req : PDPContextRequest via gn;
                do createPDPContext;
                then active;
            }
            state active {
                accept data : DataPacket via gn;
                do routeToExternal;
                then active;
            }
        }
    }

    part def ExternalNetwork {
        attribute networkName : String;
        port gi : GiPort;
    }

    // ---- Top-level GPRS Network Assembly ----
    part def GPRSNetworkSystem {
        part mobileStation : MobileStation;
        part bss : BaseStationSubsystem;
        part sgsn : SGSN;
        part ggsn : GGSN;
        part externalNetwork : ExternalNetwork;

        connect mobileStation.radio to bss.radio;
        connect bss.gb to sgsn.gb;
        connect sgsn.gn to ggsn.gn;
        connect ggsn.gi to externalNetwork.gi;

        action dataSessionLifecycle {
            in item msAttach : AttachRequest;
            out item sessionEstablished : PDPContextResponse;
            first start;
            then action attachPhase {
                in item req : AttachRequest = msAttach;
                out item acc : AttachAccept;
            }
            then action pdpContextPhase {
                in item req : PDPContextRequest;
                out item resp : PDPContextResponse;
            }
            then action dataTransferPhase {
                in item uplinkPacket : DataPacket;
                out item downlinkPacket : DataPacket;
            }
            then action detachPhase {
                in item req : DetachRequest;
                out item acc : DetachAccept;
            }
            then done;
            bind sessionEstablished = pdpContextPhase.resp;
        }
    }

    // ---- Requirements ----
    requirement def GPRSAttachRequirement {
        doc /* Mobile stations shall attach to the GPRS network before any data transfer. */
        subject ms : MobileStation;
    }
    requirement def GPRSDataTransferRequirement {
        doc /* The GPRS network shall route data packets between a mobile station and an external network. */
        subject gprsNetwork : GPRSNetworkSystem;
    }
    requirement def GPRSDetachRequirement {
        doc /* The GPRS network shall support graceful detach and deactivation of data sessions. */
        subject ms : MobileStation;
    }
    requirement def AuthenticationRequirement {
        doc /* The SGSN shall authenticate the mobile station before granting network access. */
        subject sgsnNode : SGSN;
    }
    requirement def IPAssignmentRequirement {
        doc /* The GGSN shall assign an IP address to the mobile station upon PDP context creation. */
        subject ggsnNode : GGSN;
    }
    requirement def BatteryLevelRequirement {
        doc /* The mobile station shall initiate detach when battery level falls below 10 percent. */
        subject ms : MobileStation;
    }

    requirement package GPRSRequirements {
        requirement gprsAttachReq : GPRSAttachRequirement;
        requirement gprsDataTransferReq : GPRSDataTransferRequirement;
        requirement gprsDetachReq : GPRSDetachRequirement;
        requirement authenticationReq : AuthenticationRequirement;
        requirement ipAssignmentReq : IPAssignmentRequirement;
        requirement batteryLevelReq : BatteryLevelRequirement;
    }
}
