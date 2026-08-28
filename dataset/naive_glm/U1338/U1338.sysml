package HDHomeRunModel {

    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====

    attribute def FrequencyValue :> Real {
        attribute unit : String = "MHz";
    }

    attribute def DataRateValue :> Real {
        attribute unit : String = "Mbps";
    }

    attribute def SignalStrengthValue :> Real {
        attribute unit : String = "dBm";
    }

    attribute def IPAddressValue :> String;

    attribute def ChannelNumberValue :> Integer;

    attribute def BitErrorRateValue :> Real {
        attribute unit : String = "ratio";
    }

    attribute def PacketCountValue :> Integer;

    // ===== Item Types =====

    item def RFSignal {
        attribute frequency : FrequencyValue;
        attribute strength : SignalStrengthValue;
        attribute modulationScheme : String;
    }

    item def Channel {
        attribute channelNumber : ChannelNumberValue;
        attribute frequency : FrequencyValue;
        attribute callSign : String;
        attribute programName : String;
    }

    item def MPEGTransportStream {
        attribute dataRate : DataRateValue;
        attribute programID : Integer;
        attribute packetCount : PacketCountValue;
    }

    item def IPVideoPacket {
        attribute sourceIP : IPAddressValue;
        attribute destinationIP : IPAddressValue;
        attribute sequenceNumber : Integer;
        attribute payloadSize : Integer;
    }

    item def ChannelRequest {
        attribute requestedChannel : ChannelNumberValue;
        attribute clientIP : IPAddressValue;
    }

    item def ChannelRelease {
        attribute clientIP : IPAddressValue;
    }

    item def TunerStatus {
        attribute tunerID : Integer;
        attribute lockedChannel : ChannelNumberValue;
        attribute isStreaming : Boolean;
    }

    // ===== Port Definitions =====

    port def RFPort {
        out rfSignal : RFSignal;
    }

    port def RFSignalOutPort {
        out rfSignal : RFSignal;
    }

    port def MPEGStreamPort {
        out mpegStream : MPEGTransportStream;
    }

    port def IPPort {
        out ipPackets : IPVideoPacket;
        in channelRequests : ChannelRequest;
        in channelReleases : ChannelRelease;
        out tunerStatuses : TunerStatus;
    }

    port def ControlPort {
        in channelRequests : ChannelRequest;
        in channelReleases : ChannelRelease;
        out tunerAssignments : TunerStatus;
    }

    port def TunerControlPort {
        in tuneFrequency : FrequencyValue;
        in releaseTuner : Boolean;
        out lockStatus : Boolean;
        out signalQuality : SignalStrengthValue;
    }

    port def DemodulatorControlPort {
        in enable : Boolean;
        out bitErrorRate : BitErrorRateValue;
        out streamActive : Boolean;
    }

    // ===== Part Definitions =====

    part def TVAntenna {
        port rfOut : RFPort;
        attribute gain : Real;
        attribute impedance : Real = 75.0;

        action def CaptureBroadcast {
            in broadcastRF : RFSignal;
            out capturedRF : RFSignal;
        }

        perform CaptureBroadcast;
    }

    part def RFSplitter {
        port rfInput : RFPort;
        port rfOutput1 : RFSignalOutPort;
        port rfOutput2 : RFSignalOutPort;
        attribute insertionLoss : Real = 3.5;

        action def SplitSignal {
            in inputSignal : RFSignal;
            out output1 : RFSignal;
            out output2 : RFSignal;
        }

        perform SplitSignal;
    }

    part def RFTuner {
        port rfIn : RFPort;
        port mpegOut : MPEGStreamPort;
        port control : TunerControlPort;
        attribute tunerID : Integer;
        attribute currentFrequency : FrequencyValue;
        attribute isLocked : Boolean = false;
        attribute bandwidth : DataRateValue;

        action def TuneToFrequency {
            in targetFrequency : FrequencyValue;
            out locked : Boolean;
        }

        action def DemodulateRF {
            in rfInput : RFSignal;
            out mpegOutput : MPEGTransportStream;
        }

        perform {
            action TuneToFrequency;
            action DemodulateRF;
        }
    }

    part def Demodulator {
        port mpegIn : MPEGStreamPort;
        port mpegOut : MPEGStreamPort;
        port control : DemodulatorControlPort;
        attribute modulationType : String;
        attribute fecCodeRate : String;
        attribute isActive : Boolean = false;

        action def ProcessTransportStream {
            in inputStream : MPEGTransportStream;
            out outputStream : MPEGTransportStream;
            out ber : BitErrorRateValue;
        }

        perform ProcessTransportStream;
    }

    part def IPEncapsulator {
        port mpegIn : MPEGStreamPort;
        port ipOut : IPPort;
        attribute deviceIP : IPAddressValue;
        attribute mtuSize : Integer = 1500;
        attribute packetSequence : Integer = 0;

        action def EncapsulateToIP {
            in mpegStream : MPEGTransportStream;
            out ipPackets : IPVideoPacket;
        }

        perform EncapsulateToIP;
    }

    part def ControlProcessor {
        port networkControl : ControlPort;
        port tuner1Control : TunerControlPort;
        port tuner2Control : TunerControlPort;
        port demod1Control : DemodulatorControlPort;
        port demod2Control : DemodulatorControlPort;
        attribute tuner1Available : Boolean = true;
        attribute tuner2Available : Boolean = true;
        attribute channelMap : Channel[0..*];

        action def AssignTuner {
            in request : ChannelRequest;
            out assignment : TunerStatus;
        }

        action def ReleaseTuner {
            in release : ChannelRelease;
        }

        action def LookupChannelFrequency {
            in channelNumber : ChannelNumberValue;
            out frequency : FrequencyValue;
        }

        perform {
            action AssignTuner;
            action ReleaseTuner;
            action LookupChannelFrequency;
        }

        state def ControlProcessorBehavior {
            entry;
            state Idle;
            state ProcessingRequest;
            state AssigningTuner;
            state Streaming;
            state ReleasingTuner;

            transition Idle to ProcessingRequest
                when networkControl.channelRequests->notEmpty();

            transition ProcessingRequest to AssigningTuner
                when true;

            transition AssigningTuner to Streaming
                when tuner1Control.lockStatus == true or tuner2Control.lockStatus == true;

            transition Streaming to ReleasingTuner
                when networkControl.channelReleases->notEmpty();

            transition ReleasingTuner to Idle
                when true;
        }

        exhibit ControlProcessorBehavior;
    }

    part def EthernetInterface {
        port ipIn : IPPort;
        port networkOut : IPPort;
        attribute macAddress : String;
        attribute linkSpeed : DataRateValue;
        attribute isLinkUp : Boolean = false;

        action def TransmitIPStream {
            in ipPackets : IPVideoPacket;
            out networkPackets : IPVideoPacket;
        }

        action def ReceiveControlMessages {
            in networkRequests : ChannelRequest;
            out forwardedRequests : ChannelRequest;
        }

        perform {
            action TransmitIPStream;
            action ReceiveControlMessages;
        }
    }

    part def TunerChain {
        port rfIn : RFPort;
        port mpegOut : MPEGStreamPort;
        port tunerControl : TunerControlPort;
        port demodControl : DemodulatorControlPort;
        attribute chainID : Integer;

        part tuner : RFTuner {
            port rfIn : RFPort;
            port mpegOut : MPEGStreamPort;
            port control : TunerControlPort;
        }

        part demodulator : Demodulator {
            port mpegIn : MPEGStreamPort;
            port mpegOut : MPEGStreamPort;
            port control : DemodulatorControlPort;
        }

        connection rfToTuner connect tuner.rfIn to rfIn;
        connection tunerToDemod connect tuner.mpegOut to demodulator.mpegIn;
        connection demodToOutput connect demodulator.mpegOut to mpegOut;
        connection tunerControlPass connect tuner.control to tunerControl;
        connection demodControlPass connect demodulator.control to demodControl;
    }

    part def HDHomeRunDevice {
        port rfInput : RFPort;
        port networkPort : IPPort;
        attribute deviceName : String = "HDHomeRun";
        attribute deviceIP : IPAddressValue;
        attribute firmwareVersion : String;
        attribute maxTuners : Integer = 2;

        part splitter : RFSplitter {
            port rfInput : RFPort;
            port rfOutput1 : RFSignalOutPort;
            port rfOutput2 : RFSignalOutPort;
        }

        part tunerChain1 : TunerChain {
            port rfIn : RFPort;
            port mpegOut : MPEGStreamPort;
            port tunerControl : TunerControlPort;
            port demodControl : DemodulatorControlPort;
            attribute chainID : Integer = 1;
        }

        part tunerChain2 : TunerChain {
            port rfIn : RFPort;
            port mpegOut : MPEGStreamPort;
            port tunerControl : TunerControlPort;
            port demodControl : DemodulatorControlPort;
            attribute chainID : Integer = 2;
        }

        part ipEncapsulator1 : IPEncapsulator {
            port mpegIn : MPEGStreamPort;
            port ipOut : IPPort;
            attribute deviceIP : IPAddressValue;
        }

        part ipEncapsulator2 : IPEncapsulator {
            port mpegIn : MPEGStreamPort;
            port ipOut : IPPort;
            attribute deviceIP : IPAddressValue;
        }

        part controlProcessor : ControlProcessor {
            port networkControl : ControlPort;
            port tuner1Control : TunerControlPort;
            port tuner2Control : TunerControlPort;
            port demod1Control : DemodulatorControlPort;
            port demod2Control : DemodulatorControlPort;
        }

        part ethernetInterface : EthernetInterface {
            port ipIn : IPPort;
            port networkOut : IPPort;
            attribute macAddress : String;
            attribute linkSpeed : DataRateValue;
        }

        connection rfInputToSplitter connect rfInput to splitter.rfInput;
        connection splitterToChain1 connect splitter.rfOutput1 to tunerChain1.rfIn;
        connection splitterToChain2 connect splitter.rfOutput2 to tunerChain2.rfIn;
        connection chain1ToEncap1 connect tunerChain1.mpegOut to ipEncapsulator1.mpegIn;
        connection chain2ToEncap2 connect tunerChain2.mpegOut to ipEncapsulator2.mpegIn;
        connection encap1ToEthernet connect ipEncapsulator1.ipOut to ethernetInterface.ipIn;
        connection encap2ToEthernet connect ipEncapsulator2.ipOut to ethernetInterface.ipIn;
        connection ethernetToNetwork connect ethernetInterface.networkOut to networkPort;
        connection controlToTuner1 connect controlProcessor.tuner1Control to tunerChain1.tunerControl;
        connection controlToTuner2 connect controlProcessor.tuner2Control to tunerChain2.tunerControl;
        connection controlToDemod1 connect controlProcessor.demod1Control to tunerChain1.demodControl;
        connection controlToDemod2 connect controlProcessor.demod2Control to tunerChain2.demodControl;
    }

    part def ClientDevice {
        port networkPort : IPPort;
        attribute deviceIP : IPAddressValue;
        attribute deviceType : String;
        attribute displayName : String;

        action def RequestChannel {
            in channelNumber : ChannelNumberValue;
            out request : ChannelRequest;
        }

        action def ReceiveVideoStream {
            in ipPackets : IPVideoPacket;
        }

        action def DisplayVideo {
            in videoStream : IPVideoPacket;
        }

        perform {
            action RequestChannel;
            action ReceiveVideoStream;
            action DisplayVideo;
        }

        state def ClientBehavior {
            entry;
            state Idle;
            state RequestingChannel;
            state ReceivingStream;
            state Displaying;

            transition Idle to RequestingChannel
                when true;

            transition RequestingChannel to ReceivingStream
                when networkPort.ipPackets->notEmpty();

            transition ReceivingStream to Displaying
                when true;

            transition Displaying to Idle
                when networkPort.channelReleases->notEmpty();
        }

        exhibit ClientBehavior;
    }

    // ===== System-level Part =====

    part def HDHomeRunSystem {
        part antenna : TVAntenna {
            port rfOut : RFPort;
            attribute gain : Real;
        }

        part device : HDHomeRunDevice {
            port rfInput : RFPort;
            port networkPort : IPPort;
        }

        part client1 : ClientDevice {
            port networkPort : IPPort;
            attribute deviceType : String = "Smartphone";
        }

        part client2 : ClientDevice {
            port networkPort : IPPort;
            attribute deviceType : String = "Smart TV";
        }

        connection antennaToDevice connect antenna.rfOut to device.rfInput;
        connection deviceToClient1 connect device.networkPort to client1.networkPort;
        connection deviceToClient2 connect device.networkPort to client2.networkPort;
    }

    // ===== Requirements =====

    requirement def ReceiveOTABroadcast {
        attribute id : String = "REQ-001";
        doc /* The system shall receive over-the-air digital TV broadcasts via a connected antenna. */
        subject : HDHomeRunSystem;
        objective {
            The system must capture RF broadcast signals in the frequency range
            54 MHz to 890 MHz and deliver them to the internal tuners.
        }
    }

    requirement def DualTunerSupport {
        attribute id : String = "REQ-002";
        doc /* The system shall support simultaneous streaming of two different channels. */
        subject : HDHomeRunDevice;
        objective {
            The device shall contain two independent tuner chains capable of
            receiving and streaming two distinct TV channels concurrently to
            different client devices on the network.
        }
    }

    requirement def ChannelTuning {
        attribute id : String = "REQ-003";
        doc /* The system shall tune to a requested channel frequency. */
        subject : RFTuner;
        objective {
            Upon receiving a channel request from a client, the control processor
            shall assign an available tuner to lock onto the requested channel's
            specific frequency within 2 seconds.
        }
    }

    requirement def DemodulationToMPEG {
        attribute id : String = "REQ-004";
        doc /* The system shall demodulate RF signals into MPEG transport streams. */
        subject : Demodulator;
        objective {
            The demodulator shall convert the isolated RF signal into a standard
            MPEG transport stream with a bit error rate below 1e-6.
        }
    }

    requirement def IPEncapsulation {
        attribute id : String = "REQ-005";
        doc /* The system shall encapsulate MPEG streams into IP packets. */
        subject : IPEncapsulator;
        objective {
            The IP encapsulator shall wrap MPEG transport stream data into UDP/IP
            packets with proper sequencing for network transmission.
        }
    }

    requirement def NetworkStreaming {
        attribute id : String = "REQ-006";
        doc /* The system shall stream IP video to requesting client devices. */
        subject : EthernetInterface;
        objective {
            The Ethernet interface shall transmit encapsulated IP video streams
            over the local network to the requesting client device at a minimum
            data rate of 10 Mbps per stream.
        }
    }

    requirement def ClientCompatibility {
        attribute id : String = "REQ-007";
        doc /* The system shall support various client device types. */
        subject : ClientDevice;
        objective {
            The system shall allow computers, smartphones, and smart TVs on the
            same local network to request and receive live TV streams without
            requiring built-in tuners.
        }
    }

    requirement def SignalSplitting {
        attribute id : String = "REQ-008";
        doc /* The RF splitter shall distribute the antenna signal to both tuners. */
        subject : RFSplitter;
        objective {
            The RF splitter shall divide the incoming antenna signal into two
            outputs with insertion loss not exceeding 4 dB, ensuring both
            tuner chains receive adequate signal strength.
        }
    }

    requirement def TunerRelease {
        attribute id : String = "REQ-009";
        doc /* The system shall release tuners when streaming is no longer needed. */
        subject : ControlProcessor;
        objective {
            When a client sends a channel release message or disconnects, the
            control processor shall free the assigned tuner and make it
            available for new channel requests.
        }
    }

    requirement package HDHomeRunRequirements {
        requirement req1 : ReceiveOTABroadcast;
        requirement req2 : DualTunerSupport;
        requirement req3 : ChannelTuning;
        requirement req4 : DemodulationToMPEG;
        requirement req5 : IPEncapsulation;
        requirement req6 : NetworkStreaming;
        requirement req7 : ClientCompatibility;
        requirement req8 : SignalSplitting;
        requirement req9 : TunerRelease;
    }

    // ===== Verification =====

    verification def VerifyDualTuner {
        subject : HDHomeRunDevice;
        objective {
            Verify that two clients can simultaneously request and receive
            different channels through the dual-tuner architecture.
        }
        return success : Boolean;
    }

    verification def VerifyChannelTuningTime {
        subject : RFTuner;
        objective {
            Verify that the tuner locks onto a requested frequency within 2 seconds.
        }
        return success : Boolean;
    }

    verification def VerifyStreamQuality {
        subject : Demodulator;
        objective {
            Verify that the demodulated MPEG transport stream maintains a bit
            error rate below 1e-6 under nominal signal conditions.
        }
        return success : Boolean;
    }

}
