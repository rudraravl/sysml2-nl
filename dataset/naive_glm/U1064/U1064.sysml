package GPRSNetwork {
    import ScalarValues::*;
    
    // ===== Unit Definitions =====
    unit MHz;
    unit dBm;
    unit kbps;
    unit pct;
    
    // ===== Value Types =====
    value type Frequency :> Real {
        unit MHz;
    }
    
    value type SignalStrength :> Real {
        unit dBm;
    }
    
    value type DataRate :> Real {
        unit kbps;
    }
    
    value type BatteryLevel :> Real {
        unit pct;
        attribute min : BatteryLevel = 0;
        attribute max : BatteryLevel = 100;
    }
    
    value type IPAddress :> String;
    value type IMSI :> String;
    value type CellID :> String;
    value type APN :> String;
    value type TLLI :> String;
    
    // ===== Item Definitions =====
    item def DataPacket {
        attribute sourceIP : IPAddress;
        attribute destinationIP : IPAddress;
        attribute payloadSize : Integer;
        attribute sequenceNumber : Integer;
    }
    
    item def AttachRequest {
        attribute imsi : IMSI;
    }
    
    item def AttachAccept {
        attribute assignedTLLI : TLLI;
    }
    
    item def AttachReject {
        attribute reason : String;
    }
    
    item def DetachRequest {
        attribute imsi : IMSI;
    }
    
    item def DetachAccept;
    
    item def PDPContextRequest {
        attribute imsi : IMSI;
        attribute apn : APN;
        attribute requestedQoS : Integer;
    }
    
    item def PDPContextResponse {
        attribute success : Boolean;
        attribute assignedIP : IPAddress;
        attribute tlli : TLLI;
    }
    
    item def PDPDeactivateRequest {
        attribute imsi : IMSI;
    }
    
    item def PDPDeactivateAccept;
    
    item def AuthChallenge {
        attribute imsi : IMSI;
        attribute randValue : String;
    }
    
    item def AuthResponse {
        attribute imsi : IMSI;
        attribute sresValue : String;
    }
    
    item def RoutingAreaUpdate {
        attribute imsi : IMSI;
        attribute newCellID : CellID;
    }
    
    // ===== Port Definitions =====
    port def RadioAirPort {
        attribute carrierFrequency : Frequency;
        in item rx;
        out item tx;
    }
    
    port def BackhaulPort {
        in item rx;
        out item tx;
    }
    
    port def CoreNetworkPort {
        in item rx;
        out item tx;
    }
    
    port def InternetPort {
        in item inbound : DataPacket[*];
        out item outbound : DataPacket[*];
    }
    
    // ===== Mobile Station =====
    part def MobileStation {
        attribute imsi : IMSI;
        attribute batteryLevel : BatteryLevel = 100;
        attribute assignedIP : IPAddress;
        attribute currentTLLI : TLLI;
        attribute currentCellID : CellID;
        attribute isAttached : Boolean = false;
        attribute pdpContextActive : Boolean = false;
        
        port radioIf : RadioAirPort;
        
        part transceiver {
            attribute txPower : SignalStrength;
            attribute rxSensitivity : SignalStrength;
            attribute operatingFreq : Frequency;
            attribute maxDataRate : DataRate;
        }
        
        part battery {
            attribute chargeLevel : BatteryLevel = 100;
            attribute maxCapacity : BatteryLevel = 100;
        }
        
        action def initiateAttach {
            out attachReq : AttachRequest;
        }
        
        action def requestPDPContext {
            out contextReq : PDPContextRequest;
        }
        
        action def sendDataPacket {
            in payload : DataPacket;
            out transmittedPacket : DataPacket;
        }
        
        action def receiveDataPacket {
            in packet : DataPacket;
        }
        
        action def initiateDetach {
            out detachReq : DetachRequest;
        }
        
        state machine MobileStationSessionStates {
            state idle;
            state attaching;
            state active;
            state transferring;
            state releasing;
            
            transition from idle to attaching on AttachInitiated;
            transition from attaching to active on AttachAccepted [batteryLevel > 0];
            transition from attaching to idle on AttachRejected;
            transition from active to transferring on DataToSend;
            transition from transferring to active on TransferComplete;
            transition from active to releasing on DetachInitiated;
            transition from releasing to idle on DetachComplete;
        }
    }
    
    // ===== Base Transceiver Station =====
    part def BaseTransceiverStation {
        attribute cellID : CellID;
        attribute coverageRadius : Real;
        attribute operatingFrequency : Frequency;
        attribute numRadioChannels : Integer;
        attribute activeChannels : Integer = 0;
        
        port airIf : RadioAirPort;
        port backhaulIf : BackhaulPort;
        
        action def receiveFromAir {
            in radioSignal;
            out btsUplink;
        }
        
        action def transmitToAir {
            in btsDownlink;
            out radioSignal;
        }
        
        action def forwardToBackhaul {
            in dataFromMobile;
            out dataToBSC;
        }
        
        action def forwardFromBackhaul {
            in dataFromBSC;
            out dataToMobile;
        }
    }
    
    // ===== Base Station Controller =====
    part def BaseStationController {
        attribute managedCellIDs : CellID[*];
        attribute totalRadioChannels : Integer;
        attribute activeChannels : Integer = 0;
        
        port btsIf : BackhaulPort;
        port sgsnIf : BackhaulPort;
        
        action def allocateChannel {
            in cellID : CellID;
            out channelID : Integer;
        }
        
        action def releaseChannel {
            in channelID : Integer;
        }
        
        action def manageHandover {
            in sourceCell : CellID;
            in targetCell : CellID;
            out handoverResult : Boolean;
        }
        
        action def routeToSGSN {
            in uplinkData;
            out sgsnData;
        }
        
        action def routeFromSGSN {
            in sgsnData;
            out downlinkData;
        }
    }
    
    // ===== Base Station Subsystem =====
    part def BaseStationSubsystem {
        attribute bssID : String;
        
        part btsSet : BaseTransceiverStation[*];
        part bsc : BaseStationController;
        
        port airIf : RadioAirPort;
        port sgsnIf : BackhaulPort;
        
        connection bssAirToBtsAir : airIf to btsSet.airIf;
        connection btsToBsc : btsSet.backhaulIf to bsc.btsIf;
        connection bscToSgsnPort : bsc.sgsnIf to sgsnIf;
    }
    
    // ===== Serving GPRS Node (SGSN) =====
    part def ServingGPRSNode {
        attribute nodeID : String;
        attribute managedSubscribers : IMSI[*];
        attribute routingTable : String[*];
        attribute activeSessionCount : Integer = 0;
        
        port bssIf : BackhaulPort;
        port ggsnIf : CoreNetworkPort;
        
        part subscriberRegistry {
            attribute registeredIMSI : IMSI[*];
            attribute authKeys : String[*];
            attribute lastKnownCell : CellID[*];
            attribute assignedTLLI : TLLI[*];
        }
        
        action def authenticateSubscriber {
            in imsi : IMSI;
            out challenge : AuthChallenge;
        }
        
        action def verifyAuthResponse {
            in response : AuthResponse;
            out verified : Boolean;
        }
        
        action def handleAttach {
            in attachReq : AttachRequest;
            out attachAccept : AttachAccept;
        }
    
        action def handleDetach {
            in detachReq : DetachRequest;
            out detachAccept : DetachAccept;
        }
        
        action def forwardToGGSN {
            in packet : DataPacket;
            out routedPacket : DataPacket;
        }
        
        action def forwardFromGGSN {
            in packet : DataPacket;
            out routedPacket : DataPacket;
        }
        
        action def updateLocation {
            in update : RoutingAreaUpdate;
        }
        
        state machine SGSNSessionManagement {
            state noSession;
            state authenticating;
            state sessionActive;
            state contextEstablished;
            state sessionDetaching;
            
            transition from noSession to authenticating on AttachRequestReceived;
            transition from authenticating to sessionActive on AuthSuccess;
            transition from authenticating to noSession on AuthFailure;
            transition from sessionActive to contextEstablished on PDPContextEstablished;
            transition from contextEstablished to sessionDetaching on DetachRequestReceived;
            transition from sessionDetaching to noSession on DetachComplete;
        }
    }
    
    // ===== Gateway GPRS Node (GGSN) =====
    part def GatewayGPRSNode {
        attribute nodeID : String;
        attribute ipPool : IPAddress[*];
        attribute activeContextCount : Integer = 0;
        attribute maxContexts : Integer;
        attribute defaultAPN : APN;
        
        port sgsnIf : CoreNetworkPort;
        port internetIf : InternetPort;
        
        part ipRouter {
            attribute routingTable : String[*];
            attribute defaultGateway : String;
            attribute throughput : DataRate;
            
            action def routeOutbound {
                in packet : DataPacket;
                out routedPacket : DataPacket;
            }
            
            action def routeInbound {
                in packet : DataPacket;
                out routedPacket : DataPacket;
            }
        }
        
        part firewall {
            attribute ruleSet : String[*];
            attribute defaultPolicy : String = "deny";
            attribute packetsInspected : Integer = 0;
            attribute packetsDropped : Integer = 0;
            
            action def inspectOutbound {
                in packet : DataPacket;
                out allowed : Boolean;
            }
            
            action def inspectInbound {
                in packet : DataPacket;
                out allowed : Boolean;
            }
        }
        
        action def assignIPAddress {
            in request : PDPContextRequest;
            out assignedIP : IPAddress;
            out response : PDPContextResponse;
        }
        
        action def createPDPContext {
            in contextReq : PDPContextRequest;
            out contextResp : PDPContextResponse;
        }
        
        action def deletePDPContext {
            in deactivateReq : PDPDeactivateRequest;
            out deactivateAccept : PDPDeactivateAccept;
        }
        
        action def routeToInternet {
            in packet : DataPacket;
            out outboundPacket : DataPacket;
        }
        
        action def routeFromInternet {
            in packet : DataPacket;
            out inboundPacket : DataPacket;
        }
    }
    
    // ===== External Network =====
    part def ExternalNetwork {
        attribute networkName : String = "Public Internet";
        
        port gprsIf : InternetPort;
        
        part internetCloud {
            attribute description : String;
            attribute publicIPRange : String;
        }
    }
    
    // ===== GPRS Network Top-Level Assembly =====
    part def GPRSNetwork {
        attribute networkName : String = "GPRS Network";
        
        part mobileStation : MobileStation;
        part bss : BaseStationSubsystem;
        part sgsn : ServingGPRSNode;
        part ggsn : GatewayGPRSNode;
        part externalNet : ExternalNetwork;
        
        connection radioLink : mobileStation.radioIf to bss.airIf;
        connection backhaulLink : bss.sgsnIf to sgsn.bssIf;
        connection coreNetworkLink : sgsn.ggsnIf to ggsn.sgsnIf;
        connection internetLink : ggsn.internetIf to externalNet.gprsIf;
    }
    
    // ===== Requirements =====
    requirement def AttachmentRequirement {
        doc {
            The mobile station shall initiate an attachment process with the GPRS
            network via the Base Station Subsystem. The attachment request shall
            be received and processed by the SGSN, which shall authenticate the
            subscriber identified by IMSI before granting network access.
        }
        
        subject ms : MobileStation;
        subject bssNode : BaseStationSubsystem;
        subject sgsnNode : ServingGPRSNode;
    }
    
    requirement def DataContextRequirement {
        doc {
            Once attached, the mobile station shall request a PDP data context from
            the SGSN. The SGSN shall coordinate with the GGSN to establish the session
            and obtain an IP address. The GGSN shall assign a unique IP address from
            its pool and return it through the SGSN to the mobile station.
        }
        
        subject ms : MobileStation;
        subject sgsnNode : ServingGPRSNode;
        subject ggsnNode : GatewayGPRSNode;
    }
    
    requirement def DataTransferRequirement {
        doc {
            A data packet originating from the mobile station shall travel wirelessly
            from the mobile station to a Base Transceiver Station, then through a
            wired backhaul link to the SGSN via the Base Station Controller. The SGSN
            shall route the packet to the GGSN. The GGSN shall forward the packet to
            the external network through its internet port after firewall inspection.
            The process shall be reversed for incoming data from the internet.
        }
        
        subject ms : MobileStation;
        subject bssNode : BaseStationSubsystem;
        subject sgsnNode : ServingGPRSNode;
        subject ggsnNode : GatewayGPRSNode;
    }
    
    requirement def DisconnectionRequirement {
        doc {
            The GPRS system shall support the deactivation of the PDP context and
            the detachment of the mobile station. The mobile station shall transition
            through the releasing state and return to the idle state. The GGSN shall
            release the assigned IP address back to the pool. The SGSN shall remove
            the subscriber session from its registry.
        }
        
        subject ms : MobileStation;
        subject sgsnNode : ServingGPRSNode;
        subject ggsnNode : GatewayGPRSNode;
    }
    
    requirement def BatteryMonitoringRequirement {
        doc {
            The mobile station shall continuously track its battery level. The
            mobile station shall not initiate an attachment if the battery level
            is at or below zero. The mobile station shall only complete the
            attachment to the active state if the battery level is above zero.
        }
        
        subject ms : MobileStation;
    }
    
    requirement def AuthenticationRequirement {
        doc {
            The SGSN shall authenticate the mobile station using the IMSI before
            granting network access. Authentication shall employ a challenge-response
            mechanism. The SGSN shall reject attachment if authentication fails.
        }
        
        subject sgsnNode : ServingGPRSNode;
    }
    
    requirement def FirewallRequirement {
        doc {
            The GGSN shall include a firewall that inspects all data packets routed
            to and from the external network. Packets that do not match the firewall
            rule set shall be dropped. The default policy shall be to deny traffic
            unless explicitly allowed by a rule.
        }
        
        subject ggsnNode : GatewayGPRSNode;
    }
    
    requirement def MobilityManagementRequirement {
        doc {
            The SGSN shall track the location of the mobile station as it moves
            between different base stations. The Base Station Controller shall
            manage radio resource allocation and handover between base transceiver
            stations under its control.
        }
        
        subject sgsnNode : ServingGPRSNode;
        subject bssNode : BaseStationSubsystem;
    }
    
    requirement def StateMachineRequirement {
        doc {
            The mobile station shall operate through the session states of idle,
            attaching, active, transferring, and releasing. The SGSN shall manage
            session states including noSession, authenticating, sessionActive,
            contextEstablished, and sessionDetaching.
        }
        
        subject ms : MobileStation;
        subject sgsnNode : ServingGPRSNode;
    }
}
