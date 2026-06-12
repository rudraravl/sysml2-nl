package EthernetSystemModel {
    import ScalarValues::*;
    import SI::*;

    enum def LinkState {
        enum linkDown;
        enum autoNegotiating;
        enum linkUp;
        enum fault;
    }

    enum def DuplexMode {
        enum halfDuplex;
        enum fullDuplex;
    }

    enum def FramePriority {
        enum bestEffort;
        enum background;
        enum excellentEffort;
        enum criticalApplications;
        enum video;
        enum voice;
        enum internetworkControl;
        enum networkControl;
    }

    attribute def DataRate :> Real {
        doc /* Unit: megabit per second */
    }

    attribute def CableLength :> Real {
        doc /* Unit: meter */
    }

    attribute def TimeInterval :> Real {
        doc /* Unit: millisecond */
    }

    attribute def FrameSize :> Integer {
        doc /* Unit: octet */
    }

    attribute def BitErrorRatio :> Real {
        doc /* Unit: errors per transmitted bit */
    }

    attribute def MACAddress :> String;
    attribute def EtherType :> String;
    attribute def VLANIdentifier :> Integer;

    item def EthernetFrame {
        attribute destination : MACAddress;
        attribute source : MACAddress;
        attribute etherType : EtherType;
        attribute payloadSize : FrameSize;
        attribute priority : FramePriority;
        attribute vlanId : VLANIdentifier;
        attribute frameCheckSequence : Integer;
    }

    item def EthernetSymbolStream {
        attribute lineRate : DataRate;
        attribute encodedBits : Integer;
        attribute errorRatio : BitErrorRatio;
    }

    item def ManagementMessage {
        attribute command : String;
        attribute targetPort : String;
        attribute value : String;
    }

    port def EthernetDataPort {
        in item receivedFrame : EthernetFrame;
        out item transmittedFrame : EthernetFrame;
        in item receivedSymbols : EthernetSymbolStream;
        out item transmittedSymbols : EthernetSymbolStream;
        attribute negotiatedRate : DataRate;
        attribute duplex : DuplexMode;
        attribute state : LinkState;
    }

    port def ManagementPort {
        in item request : ManagementMessage;
        out item response : ManagementMessage;
    }

    interface def EthernetLinkInterface {
        end port a : EthernetDataPort;
        end port b : EthernetDataPort;

        flow a.transmittedSymbols to b.receivedSymbols;
        flow b.transmittedSymbols to a.receivedSymbols;
        flow a.transmittedFrame to b.receivedFrame;
        flow b.transmittedFrame to a.receivedFrame;
    }

    part def PhysicalMedium {
        attribute length : CableLength;
        attribute category : String;
        attribute maximumSupportedRate : DataRate;
        attribute propagationDelay : TimeInterval;
        attribute bitErrorRatio : BitErrorRatio;
    }

    part def EthernetPHY {
        port mediaPort : EthernetDataPort;
        attribute supportedRate : DataRate;
        attribute linkState : LinkState;
        attribute duplexMode : DuplexMode;

        perform action AutoNegotiateLink;
        perform action EncodeFrameToSymbols;
        perform action DecodeSymbolsToFrame;
    }

    part def EthernetMAC {
        port macPort : EthernetDataPort;
        attribute macAddress : MACAddress;
        attribute maximumFrameSize : FrameSize;
        attribute minimumFrameSize : FrameSize;

        perform action ValidateFrame;
        perform action AppendFrameCheckSequence;
        perform action FilterByDestinationAddress;
    }

    part def NetworkInterfaceCard {
        port externalEthernet : EthernetDataPort;

        part mac : EthernetMAC;
        part phy : EthernetPHY;

        connection macToPhy : EthernetLinkInterface connect mac.macPort to phy.mediaPort;
        connection externalPath : EthernetLinkInterface connect phy.mediaPort to externalEthernet;
    }

    part def EthernetEndStation {
        port ethernet : EthernetDataPort;

        attribute stationName : String;
        attribute assignedAddress : MACAddress;

        part nic : NetworkInterfaceCard;

        connection stationEthernetConnection : EthernetLinkInterface connect nic.externalEthernet to ethernet;

        perform action SendApplicationData;
        perform action ReceiveApplicationData;
    }

    part def EthernetSwitchPort {
        port external : EthernetDataPort;

        attribute portIdentifier : String;
        attribute administrativeState : LinkState;
        attribute learnedAddressCount : Integer;
        attribute configuredRate : DataRate;

        part phy : EthernetPHY;
        part mac : EthernetMAC;

        connection phyToMac : EthernetLinkInterface connect phy.mediaPort to mac.macPort;
        connection outside : EthernetLinkInterface connect external to phy.mediaPort;
    }

    part def SwitchingFabric {
        port ingress : EthernetDataPort;
        port egress : EthernetDataPort;

        attribute forwardingLatency : TimeInterval;
        attribute switchingCapacity : DataRate;
        attribute addressTableEntries : Integer;

        perform action LearnSourceAddress;
        perform action SelectEgressPort;
        perform action ForwardFrame;
        perform action DropInvalidFrame;
    }

    part def ManagedEthernetSwitch {
        port management : ManagementPort;

        part port1 : EthernetSwitchPort {
            attribute portIdentifier = "ge-0/1";
            attribute configuredRate = 1000.0;
        }

        part port2 : EthernetSwitchPort {
            attribute portIdentifier = "ge-0/2";
            attribute configuredRate = 1000.0;
        }

        part port3 : EthernetSwitchPort {
            attribute portIdentifier = "ge-0/3";
            attribute configuredRate = 1000.0;
        }

        part fabric : SwitchingFabric {
            attribute forwardingLatency = 0.020;
            attribute switchingCapacity = 3000.0;
            attribute addressTableEntries = 8192;
        }

        connection port1ToFabric : EthernetLinkInterface connect port1.external to fabric.ingress;
        connection port2ToFabric : EthernetLinkInterface connect port2.external to fabric.ingress;
        connection port3ToFabric : EthernetLinkInterface connect port3.external to fabric.ingress;
    }

    action def AutoNegotiateLink {
        in attribute advertisedRate : DataRate;
        in attribute peerRate : DataRate;
        out attribute selectedRate : DataRate;
        out attribute resultingState : LinkState;

        first start;
        then exchangeCapabilities;
        then chooseHighestCommonRate;
        then establishFullDuplex;
        then reportLinkUp;
    }

    action def EncodeFrameToSymbols {
        in item frame : EthernetFrame;
        out item symbols : EthernetSymbolStream;

        first receiveFrameFromMAC;
        then serializeFrameBits;
        then encodeLineSymbols;
        then transmitSymbolsToMedium;
    }

    action def DecodeSymbolsToFrame {
        in item symbols : EthernetSymbolStream;
        out item frame : EthernetFrame;

        first receiveSymbolsFromMedium;
        then recoverClock;
        then decodeLineSymbols;
        then assembleFrame;
    }

    action def ValidateFrame {
        in item candidateFrame : EthernetFrame;
        out attribute valid : Boolean;

        first checkMinimumSize;
        then checkMaximumSize;
        then verifyFrameCheckSequence;
        then reportValidationResult;
    }

    action def AppendFrameCheckSequence {
        in item payloadFrame : EthernetFrame;
        out item protectedFrame : EthernetFrame;

        first calculateCrc32;
        then appendFcsField;
    }

    action def FilterByDestinationAddress {
        in item frame : EthernetFrame;
        in attribute localAddress : MACAddress;
        out attribute accepted : Boolean;

        first compareDestinationWithLocalAddress;
        then acceptUnicastBroadcastOrSubscribedMulticast;
    }

    action def LearnSourceAddress {
        in item frame : EthernetFrame;
        in attribute ingressPortId : String;
        out attribute tableUpdated : Boolean;

        first readSourceAddress;
        then updateForwardingDatabase;
    }

    action def SelectEgressPort {
        in item frame : EthernetFrame;
        out attribute selectedPortId : String;
        out attribute floodRequired : Boolean;

        first lookupDestinationAddress;
        then selectKnownPortOrFloodSet;
    }

    action def ForwardFrame {
        in item frame : EthernetFrame;
        in attribute egressPortId : String;
        out item forwardedFrame : EthernetFrame;

        first queueFrame;
        then transmitOnSelectedPort;
    }

    action def DropInvalidFrame {
        in item frame : EthernetFrame;
        out attribute discarded : Boolean;

        first identifyReason;
        then incrementDiscardCounter;
        then removeFrameFromPipeline;
    }

    action def SendApplicationData {
        in attribute payloadLength : FrameSize;
        out item frame : EthernetFrame;

        first createEthernetPayload;
        then addressDestination;
        then submitToNetworkInterface;
    }

    action def ReceiveApplicationData {
        in item frame : EthernetFrame;
        out attribute payloadAccepted : Boolean;

        first inspectFrame;
        then deliverPayloadToApplication;
    }

    state def EthernetPortLifecycle {
        entry action initializePort;

        state disabled;
        state negotiating;
        state operational;
        state degraded;
        state failed;

        transition disabled_to_negotiating
            first disabled
            accept enablePort
            then negotiating;

        transition negotiating_to_operational
            first negotiating
            accept negotiationComplete
            if negotiatedRate > 0.0
            then operational;

        transition operational_to_degraded
            first operational
            accept excessiveErrors
            if bitErrorRatio > 0.000000001
            then degraded;

        transition degraded_to_operational
            first degraded
            accept errorRateRecovered
            then operational;

        transition operational_to_failed
            first operational
            accept carrierLost
            then failed;

        transition failed_to_negotiating
            first failed
            accept retryLink
            then negotiating;
    }

    requirement def PrimaryFunctionRequirement {
        subject ethernetSystem : OfficeEthernetNetwork;

        require constraint {
            ethernetSystem transports EthernetFrame between connected end stations using MAC addressing, physical signaling, and switch forwarding.
        }
    }

    requirement def LinkRateRequirement {
        subject switchPort : EthernetSwitchPort;

        require constraint {
            switchPort.configuredRate >= 1000.0
        }
    }

    requirement def FrameSizeRequirement {
        subject mac : EthernetMAC;

        require constraint {
            mac.minimumFrameSize == 64 and mac.maximumFrameSize == 1518
        }
    }

    requirement def CableLengthRequirement {
        subject cable : PhysicalMedium;

        require constraint {
            cable.length <= 100.0
        }
    }

    requirement def ForwardingLatencyRequirement {
        subject fabric : SwitchingFabric;

        require constraint {
            fabric.forwardingLatency <= 0.100
        }
    }

    requirement def ErrorRateRequirement {
        subject cable : PhysicalMedium;

        require constraint {
            cable.bitErrorRatio <= 0.000000000001
        }
    }

    part def OfficeEthernetNetwork {
        doc /* Primary function: provide high-speed local area network connectivity by carrying Ethernet frames among hosts through standardized links, MAC-layer addressing, and switch-based forwarding. */

        part engineeringWorkstation : EthernetEndStation {
            attribute stationName = "Engineering Workstation";
            attribute assignedAddress = "00:11:22:33:44:10";
        }

        part fileServer : EthernetEndStation {
            attribute stationName = "File Server";
            attribute assignedAddress = "00:11:22:33:44:20";
        }

        part printer : EthernetEndStation {
            attribute stationName = "Network Printer";
            attribute assignedAddress = "00:11:22:33:44:30";
        }

        part accessSwitch : ManagedEthernetSwitch;

        part cableA : PhysicalMedium {
            attribute length = 18.0;
            attribute category = "Category 6 twisted pair";
            attribute maximumSupportedRate = 1000.0;
            attribute propagationDelay = 0.000090;
            attribute bitErrorRatio = 0.0000000000001;
        }

        part cableB : PhysicalMedium {
            attribute length = 32.0;
            attribute category = "Category 6 twisted pair";
            attribute maximumSupportedRate = 1000.0;
            attribute propagationDelay = 0.000160;
            attribute bitErrorRatio = 0.0000000000001;
        }

        part cableC : PhysicalMedium {
            attribute length = 24.0;
            attribute category = "Category 6 twisted pair";
            attribute maximumSupportedRate = 1000.0;
            attribute propagationDelay = 0.000120;
            attribute bitErrorRatio = 0.0000000000001;
        }

        connection workstationLink : EthernetLinkInterface connect engineeringWorkstation.ethernet to accessSwitch.port1.external;
        connection serverLink : EthernetLinkInterface connect fileServer.ethernet to accessSwitch.port2.external;
        connection printerLink : EthernetLinkInterface connect printer.ethernet to accessSwitch.port3.external;

        satisfy PrimaryFunctionRequirement by OfficeEthernetNetwork;
        satisfy LinkRateRequirement by accessSwitch.port1;
        satisfy LinkRateRequirement by accessSwitch.port2;
        satisfy LinkRateRequirement by accessSwitch.port3;
        satisfy CableLengthRequirement by cableA;
        satisfy CableLengthRequirement by cableB;
        satisfy CableLengthRequirement by cableC;
        satisfy ForwardingLatencyRequirement by accessSwitch.fabric;
        satisfy ErrorRateRequirement by cableA;
        satisfy ErrorRateRequirement by cableB;
        satisfy ErrorRateRequirement by cableC;
    }
}