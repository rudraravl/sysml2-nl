package HDHomeRunSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ChannelNumber;
    attribute def IPAddress;
    attribute def MACAddress;
    attribute def StreamProtocol;
    
    attribute def RFFrequency :> ISQ::FrequencyValue;
    attribute def Bitrate :> ISQ::DataRateValue;
    attribute def SignalStrength :> ISQ::PowerValue;
    
    item def RFSignal {
        attribute frequency : RFFrequency;
        attribute strength : SignalStrength;
    }
    
    item def TransportStream {
        attribute dataRate : Bitrate;
        attribute channelId : ChannelNumber;
    }
    
    item def IPStream {
        attribute dataRate : Bitrate;
        attribute protocol : StreamProtocol;
        attribute destinationIP : IPAddress;
    }
    
    port def RFPort {
        in item rfSignal : RFSignal;
    }
    
    port def NetworkPort {
        out item ipStream : IPStream;
        attribute macAddr : MACAddress;
        attribute ipAddr : IPAddress;
    }
    
    part def TVAntenna {
        port rfOutput : RFPort;
        
        action captureRFSignal {
            out signal : RFSignal;
        }
    }
    
    part def RFTuner {
        port rfInput : RFPort;
        attribute tunerIndex : Integer;
        attribute currentFrequency : RFFrequency;
        
        action tuneToFrequency {
            in targetFreq : RFFrequency;
            in rfSignal : RFSignal;
            out tunedSignal : RFSignal;
        }
    }
    
    part def ATSCDemodulator {
        action demodulate {
            in rfSignal : RFSignal;
            out transportStream : TransportStream;
        }
    }
    
    part def MPEGDecoder {
        action decodeStream {
            in transportStream : TransportStream;
            out decodedStream : TransportStream;
        }
    }
    
    part def IPEncapsulator {
        action encapsulateToIP {
            in transportStream : TransportStream;
            in destinationIP : IPAddress;
            out ipStream : IPStream;
        }
    }
    
    part def EthernetInterface {
        port networkPort : NetworkPort;
        attribute linkSpeed : Bitrate;
        
        action transmitStream {
            in ipStream : IPStream;
            out networkStream : IPStream;
        }
    }
    
    part def ControlProcessor {
        attribute firmwareVersion : String;
        
        action manageTuners {
            in channelRequest : ChannelNumber;
            out tunerAssignment : Integer;
        }
        
        action handleNetworkRequests {
            in clientRequest : IPAddress;
            out streamResponse : IPStream;
        }
    }
    
    part def HDHomeRunDevice {
        part antenna : TVAntenna;
        part tuner1 : RFTuner {
            attribute :>> tunerIndex = 1;
        }
        part tuner2 : RFTuner {
            attribute :>> tunerIndex = 2;
        }
        part demodulator1 : ATSCDemodulator;
        part demodulator2 : ATSCDemodulator;
        part decoder1 : MPEGDecoder;
        part decoder2 : MPEGDecoder;
        part encapsulator1 : IPEncapsulator;
        part encapsulator2 : IPEncapsulator;
        part ethernetInterface : EthernetInterface;
        part controller : ControlProcessor;
        
        port rfInput : RFPort;
        port lanOutput : NetworkPort;
        
        connection rfDistribution1 connect antenna.rfOutput to tuner1.rfInput;
        connection rfDistribution2 connect antenna.rfOutput to tuner2.rfInput;
        connection networkOutput connect ethernetInterface.networkPort to lanOutput;
        
        action convertBroadcastToIPTV {
            in channelSelection : ChannelNumber;
            in clientAddress : IPAddress;
            out streamOutput : IPStream;
        }
    }
    
    action def CaptureOTASignal {
        out broadcastSignal : RFSignal;
    }
    
    action def SelectChannel {
        in requestedChannel : ChannelNumber;
        in availableSignal : RFSignal;
        out selectedFrequency : RFFrequency;
        out tunedSignal : RFSignal;
    }
    
    action def DemodulateATSC {
        in tunedSignal : RFSignal;
        out digitalTransport : TransportStream;
    }
    
    action def DecodeMPEG {
        in digitalTransport : TransportStream;
        out cleanTransport : TransportStream;
    }
    
    action def PacketizeForIP {
        in cleanTransport : TransportStream;
        in targetClient : IPAddress;
        out ipPackets : IPStream;
    }
    
    action def TransmitToNetwork {
        in ipPackets : IPStream;
        out networkOutput : IPStream;
    }
    
    action def ConvertOTABroadcastToNetworkStream {
        in attribute selectedChannel : ChannelNumber;
        in attribute clientIP : IPAddress;
        out attribute finalStream : IPStream;
        
        first start;
        then action capture : CaptureOTASignal {
            out broadcastSignal;
        }
        then action select : SelectChannel {
            in requestedChannel = selectedChannel;
            in availableSignal = capture.broadcastSignal;
            out selectedFrequency;
            out tunedSignal;
        }
        then action demod : DemodulateATSC {
            in tunedSignal = select.tunedSignal;
            out digitalTransport;
        }
        then action decode : DecodeMPEG {
            in digitalTransport = demod.digitalTransport;
            out cleanTransport;
        }
        then action packetize : PacketizeForIP {
            in cleanTransport = decode.cleanTransport;
            in targetClient = clientIP;
            out ipPackets;
        }
        then action transmit : TransmitToNetwork {
            in ipPackets = packetize.ipPackets;
            out networkOutput;
        }
        then assign finalStream := transmit.networkOutput;
        then done;
    }
    
    part hdHomeRunSystem : HDHomeRunDevice {
        perform action streamBroadcast[*] ordered references ConvertOTABroadcastToNetworkStream;
        
        part antenna {
            perform streamBroadcast.capture;
        }
        
        part tuner1 {
            perform streamBroadcast.select;
        }
        
        part demodulator1 {
            perform streamBroadcast.demod;
        }
        
        part decoder1 {
            perform streamBroadcast.decode;
        }
        
        part encapsulator1 {
            perform streamBroadcast.packetize;
        }
        
        part ethernetInterface {
            perform streamBroadcast.transmit;
        }
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    
    requirement <'HDR-F-001'> receiveBroadcastTV : FunctionalRequirement {
        doc /* The HDHomeRun shall receive over-the-air digital television broadcast signals 
               in the ATSC format within the UHF and VHF frequency bands. */
        
        subject device : HDHomeRunDevice;
        
        require constraint validRFRange {
            54.0 <= 806.0
        }
    }
    
    requirement <'HDR-F-002'> dualTunerOperation : FunctionalRequirement {
        doc /* The HDHomeRun shall provide two independent tuners capable of 
               simultaneously receiving and processing different broadcast channels. */
        
        subject device : HDHomeRunDevice;
        
        require constraint independentTuners {
            1 != 2
        }
    }
    
    requirement <'HDR-F-003'> ipStreamDelivery : FunctionalRequirement {
        doc /* The HDHomeRun shall encapsulate received broadcast content into IP packets 
               and deliver them over Ethernet to network-connected client devices. */
        
        subject device : HDHomeRunDevice;
    }
    
    requirement <'HDR-P-001'> streamBitrate : PerformanceRequirement {
        doc /* Each tuner shall support streaming at bitrates up to 20 Mbps 
               to accommodate high-definition broadcast content. */
        
        subject device : HDHomeRunDevice;
    }
    
    requirement <'HDR-SYS-001'> primarySystemFunction : FunctionalRequirement {
        doc /* The primary function of the HDHomeRun system is to receive over-the-air 
               digital television broadcasts and convert them into IP-based video streams 
               that can be distributed over a local area network to multiple client devices 
               for viewing, recording, and time-shifting. */
        
        subject device : HDHomeRunDevice;
        
        require receiveBroadcastTV;
        require dualTunerOperation;
        require ipStreamDelivery;
        require streamBitrate;
    }
}
