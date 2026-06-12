package UMTS_System_Model {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def FrequencyMHz :> Real {
        unit = "MHz";
    }

    attribute def PowerdBm :> Real {
        unit = "dBm";
    }

    attribute def DataRateMbps :> Real {
        unit = "Mbit/s";
    }

    attribute def LatencyMs :> Real {
        unit = "ms";
    }

    attribute def AvailabilityPercent :> Real {
        unit = "%";
    }

    attribute def CellRadiusKm :> Real {
        unit = "km";
    }

    item def VoiceFrame {
        attribute codecRate : DataRateMbps;
        attribute payloadSizeBits : Integer;
    }

    item def PacketData {
        attribute dataRate : DataRateMbps;
        attribute qosClass : String;
        attribute priority : Integer;
    }

    item def RadioSignal {
        attribute carrierFrequency : FrequencyMHz;
        attribute transmitPower : PowerdBm;
        attribute spreadingCode : String;
        attribute scramblingCode : String;
    }

    item def MobilityContext {
        attribute subscriberId : String;
        attribute servingCellId : String;
        attribute locationAreaCode : String;
        attribute authenticationState : String;
    }

    item def ControlMessage {
        attribute messageType : String;
        attribute transactionId : Integer;
        attribute integrityProtected : Boolean;
    }

    item def CoreNetworkTraffic {
        attribute bearerId : Integer;
        attribute serviceType : String;
        attribute peakRate : DataRateMbps;
    }

    port def UuRadioPort {
        out radioDownlink : RadioSignal;
        in radioUplink : RadioSignal;
        out controlDownlink : ControlMessage;
        in controlUplink : ControlMessage;
        in userDataUplink : PacketData;
        out userDataDownlink : PacketData;
        in voiceUplink : VoiceFrame;
        out voiceDownlink : VoiceFrame;
    }

    port def IubPort {
        in ranUserTraffic : CoreNetworkTraffic;
        out ranUserTrafficForwarded : CoreNetworkTraffic;
        in ranControl : ControlMessage;
        out ranControlForwarded : ControlMessage;
    }

    port def IuCsPort {
        in circuitVoice : VoiceFrame;
        out circuitVoice : VoiceFrame;
        in mobilityControl : ControlMessage;
        out mobilityControl : ControlMessage;
    }

    port def IuPsPort {
        in packetTraffic : PacketData;
        out packetTraffic : PacketData;
        in packetControl : ControlMessage;
        out packetControl : ControlMessage;
    }

    port def ServicePort {
        in subscriberRequest : ControlMessage;
        out serviceResponse : ControlMessage;
        in uplinkPayload : PacketData;
        out downlinkPayload : PacketData;
        in uplinkVoice : VoiceFrame;
        out downlinkVoice : VoiceFrame;
    }

    part def UserEquipment {
        attribute imsi : String;
        attribute maxUplinkRate : DataRateMbps;
        attribute maxDownlinkRate : DataRateMbps;
        attribute transmitPower : PowerdBm;
        attribute authenticated : Boolean;

        port radio : UuRadioPort;
        port services : ServicePort;

        action registerToNetwork {
            in subscriber : MobilityContext;
            out registrationRequest : ControlMessage;
        }

        action originateVoiceCall {
            in calledPartyNumber : String;
            out setupMessage : ControlMessage;
            out encodedVoice : VoiceFrame;
        }

        action sendPacketSession {
            in payload : PacketData;
            out uplinkPacket : PacketData;
        }

        state def UEOperatingState {
            entry action initializeRadio;
            state PoweredOff;
            state Searching;
            state Camped;
            state Connected;
            state Handover;
            state EmergencyOnly;

            transition powerOn first PoweredOff then Searching;
            transition cellFound first Searching then Camped;
            transition attachAccepted first Camped then Connected;
            transition radioLinkDegrades first Connected then Handover;
            transition handoverComplete first Handover then Connected;
            transition noSuitableCell first Searching then EmergencyOnly;
            transition powerOff first Connected then PoweredOff;
        }
    }

    part def NodeB {
        attribute nodeBId : String;
        attribute downlinkCarrier : FrequencyMHz;
        attribute uplinkCarrier : FrequencyMHz;
        attribute maxTransmitPower : PowerdBm;
        attribute supportedCellRadius : CellRadiusKm;

        port uu : UuRadioPort;
        port iub : IubPort;

        action spreadAndModulate {
            in traffic : CoreNetworkTraffic;
            out downlinkSignal : RadioSignal;
        }

        action despreadAndDemodulate {
            in uplinkSignal : RadioSignal;
            out traffic : CoreNetworkTraffic;
        }

        action measureRadioLink {
            in uplinkSignal : RadioSignal;
            out receivedPower : PowerdBm;
            out qualityIndicator : Real;
        }

        state def NodeBState {
            state Disabled;
            state Synchronizing;
            state BroadcastingCell;
            state CarryingTraffic;
            state Faulted;

            transition enable first Disabled then Synchronizing;
            transition syncLocked first Synchronizing then BroadcastingCell;
            transition bearerEstablished first BroadcastingCell then CarryingTraffic;
            transition noActiveBearer first CarryingTraffic then BroadcastingCell;
            transition hardwareFault first BroadcastingCell then Faulted;
            transition reset first Faulted then Synchronizing;
        }
    }

    part def RadioNetworkController {
        attribute rncId : String;
        attribute maxActiveUsers : Integer;
        attribute admissionThreshold : Real;
        attribute targetAccessLatency : LatencyMs;

        port iubToNodeB : IubPort;
        port iuCs : IuCsPort;
        port iuPs : IuPsPort;

        action admitRadioBearer {
            in request : ControlMessage;
            out decision : ControlMessage;
        }

        action allocateSpreadingCode {
            in subscriber : MobilityContext;
            out codeAssignment : ControlMessage;
        }

        action coordinateHandover {
            in context : MobilityContext;
            out handoverCommand : ControlMessage;
        }

        action routeTraffic {
            in bearerTraffic : CoreNetworkTraffic;
            out circuitTraffic : VoiceFrame;
            out packetTraffic : PacketData;
        }

        state def RNCControlState {
            state Idle;
            state AuthenticatingAccess;
            state AllocatingBearer;
            state SupervisingConnection;
            state PerformingHandover;
            state ReleasingBearer;

            transition accessRequest first Idle then AuthenticatingAccess;
            transition authenticationPassed first AuthenticatingAccess then AllocatingBearer;
            transition bearerReady first AllocatingBearer then SupervisingConnection;
            transition mobilityEvent first SupervisingConnection then PerformingHandover;
            transition handoverDone first PerformingHandover then SupervisingConnection;
            transition releaseRequest first SupervisingConnection then ReleasingBearer;
            transition releaseComplete first ReleasingBearer then Idle;
        }
    }

    part def MobileSwitchingCenter {
        attribute mscId : String;
        attribute supportedVoiceCodec : String;
        attribute callSetupLatency : LatencyMs;

        port iuCs : IuCsPort;
        port publicVoiceNetwork : ServicePort;

        action authenticateSubscriber {
            in context : MobilityContext;
            out result : ControlMessage;
        }

        action establishCircuitCall {
            in setup : ControlMessage;
            out callAssignment : ControlMessage;
        }

        action switchVoice {
            in mobileVoice : VoiceFrame;
            out networkVoice : VoiceFrame;
        }
    }

    part def ServingGprsSupportNode {
        attribute sgsnId : String;
        attribute maxPacketRate : DataRateMbps;
        attribute sessionSetupLatency : LatencyMs;

        port iuPs : IuPsPort;
        port gateway : ServicePort;

        action attachPacketSubscriber {
            in context : MobilityContext;
            out attachAccept : ControlMessage;
        }

        action establishPacketBearer {
            in request : ControlMessage;
            out bearerAccept : ControlMessage;
        }

        action forwardPackets {
            in mobilePacket : PacketData;
            out externalPacket : PacketData;
        }
    }

    part def GatewayGprsSupportNode {
        attribute ggsnId : String;
        attribute internetAddressPool : String;
        attribute gatewayCapacity : DataRateMbps;

        port packetCore : ServicePort;
        port internet : ServicePort;

        action assignIpAddress {
            in subscriber : MobilityContext;
            out assignedAddress : ControlMessage;
        }

        action routeInternetTraffic {
            in subscriberPacket : PacketData;
            out internetPacket : PacketData;
        }
    }

    part def HomeLocationRegister {
        attribute operatorCode : String;
        attribute subscriberCount : Integer;
        attribute databaseAvailability : AvailabilityPercent;

        port subscriberData : ServicePort;

        action provideAuthenticationVector {
            in subscriber : MobilityContext;
            out authenticationVector : ControlMessage;
        }

        action provideServiceProfile {
            in subscriber : MobilityContext;
            out serviceProfile : ControlMessage;
        }
    }

    part def UMTSSystem {
        attribute systemName : String = "Universal Mobile Telecommunications System";
        attribute primaryFunction : String =
            "Provide wide-area mobile telecommunications by connecting authenticated user equipment to voice and packet data services through a radio access network and core network.";
        attribute pairedUplinkBand : FrequencyMHz = 1920.0;
        attribute pairedDownlinkBand : FrequencyMHz = 2110.0;
        attribute nominalCellRadius : CellRadiusKm = 3.0;
        attribute targetUserPlaneLatency : LatencyMs = 150.0;
        attribute minimumAvailability : AvailabilityPercent = 99.95;

        part ue : UserEquipment {
            attribute maxUplinkRate = 5.76;
            attribute maxDownlinkRate = 14.4;
            attribute transmitPower = 24.0;
        }

        part nodeB : NodeB {
            attribute nodeBId = "NB-001";
            attribute downlinkCarrier = 2140.0;
            attribute uplinkCarrier = 1950.0;
            attribute maxTransmitPower = 43.0;
            attribute supportedCellRadius = 5.0;
        }

        part rnc : RadioNetworkController {
            attribute rncId = "RNC-001";
            attribute maxActiveUsers = 2048;
            attribute admissionThreshold = 0.80;
            attribute targetAccessLatency = 250.0;
        }

        part msc : MobileSwitchingCenter {
            attribute mscId = "MSC-001";
            attribute supportedVoiceCodec = "AMR";
            attribute callSetupLatency = 4000.0;
        }

        part sgsn : ServingGprsSupportNode {
            attribute sgsnId = "SGSN-001";
            attribute maxPacketRate = 1000.0;
            attribute sessionSetupLatency = 2000.0;
        }

        part ggsn : GatewayGprsSupportNode {
            attribute ggsnId = "GGSN-001";
            attribute internetAddressPool = "10.64.0.0/10";
            attribute gatewayCapacity = 5000.0;
        }

        part hlr : HomeLocationRegister {
            attribute operatorCode = "00101";
            attribute subscriberCount = 1000000;
            attribute databaseAvailability = 99.999;
        }

        connect ue.radio to nodeB.uu;
        connect nodeB.iub to rnc.iubToNodeB;
        connect rnc.iuCs to msc.iuCs;
        connect rnc.iuPs to sgsn.iuPs;
        connect sgsn.gateway to ggsn.packetCore;
        connect msc.publicVoiceNetwork to hlr.subscriberData;
        connect ggsn.internet to hlr.subscriberData;

        action provideMobileService {
            in subscriberContext : MobilityContext;
            in requestedPacketData : PacketData;
            in requestedVoice : VoiceFrame;
            out deliveredPacketData : PacketData;
            out deliveredVoice : VoiceFrame;

            first start;
            then ue.registerToNetwork;
            then hlr.provideAuthenticationVector;
            then msc.authenticateSubscriber;
            then rnc.admitRadioBearer;
            then rnc.allocateSpreadingCode;
            then nodeB.spreadAndModulate;
            then nodeB.despreadAndDemodulate;
            then rnc.routeTraffic;
            then msc.switchVoice;
            then sgsn.forwardPackets;
            then ggsn.routeInternetTraffic;
            then done;
        }

        state def SystemOperationalState {
            state OutOfService;
            state Initializing;
            state RadioCoverageAvailable;
            state SubscriberAttached;
            state ServiceActive;
            state MobilityMaintained;
            state DegradedService;

            transition energize first OutOfService then Initializing;
            transition cellBroadcastAvailable first Initializing then RadioCoverageAvailable;
            transition subscriberAuthenticated first RadioCoverageAvailable then SubscriberAttached;
            transition bearerEstablished first SubscriberAttached then ServiceActive;
            transition handoverRequired first ServiceActive then MobilityMaintained;
            transition handoverCompleted first MobilityMaintained then ServiceActive;
            transition capacityExceeded first ServiceActive then DegradedService;
            transition capacityRestored first DegradedService then ServiceActive;
            transition shutdown first ServiceActive then OutOfService;
        }
    }

    requirement def UMTSPrimaryFunctionRequirement {
        subject system : UMTSSystem;
        require constraint {
            system.primaryFunction ==
            "Provide wide-area mobile telecommunications by connecting authenticated user equipment to voice and packet data services through a radio access network and core network."
        }
    }

    requirement def RadioAccessRequirement {
        subject system : UMTSSystem;
        require constraint {
            system.pairedUplinkBand >= 1920.0 and
            system.pairedUplinkBand <= 1980.0 and
            system.pairedDownlinkBand >= 2110.0 and
            system.pairedDownlinkBand <= 2170.0
        }
    }

    requirement def VoiceServiceRequirement {
        subject msc : MobileSwitchingCenter;
        require constraint {
            msc.supportedVoiceCodec == "AMR" and
            msc.callSetupLatency <= 5000.0
        }
    }

    requirement def PacketServiceRequirement {
        subject sgsn : ServingGprsSupportNode;
        require constraint {
            sgsn.maxPacketRate >= 384.0 and
            sgsn.sessionSetupLatency <= 3000.0
        }
    }

    requirement def MobilityRequirement {
        subject rnc : RadioNetworkController;
        require constraint {
            rnc.maxActiveUsers >= 1000 and
            rnc.targetAccessLatency <= 500.0
        }
    }

    requirement def AvailabilityRequirement {
        subject system : UMTSSystem;
        require constraint {
            system.minimumAvailability >= 99.9
        }
    }

    satisfy UMTSPrimaryFunctionRequirement by UMTSSystem;
    satisfy RadioAccessRequirement by UMTSSystem;
    satisfy VoiceServiceRequirement by MobileSwitchingCenter;
    satisfy PacketServiceRequirement by ServingGprsSupportNode;
    satisfy MobilityRequirement by RadioNetworkController;
    satisfy AvailabilityRequirement by UMTSSystem;
}