package HDHomeRunSystem {
    private import ScalarValues::*;
    private import SI::*;

    attribute def Frequency {
        attribute hertz : SI::FrequencyUnit;
    }
    attribute def DataRate {
        attribute bitsPerSecond : ScalarValues::Real;
    }
    attribute def SignalStrength {
        attribute dBm : ScalarValues::Real;
    }
    attribute def ChannelNumber {
        attribute number : ScalarValues::Integer;
    }
    attribute def IPAddress {
        attribute address : ScalarValues::String;
    }

    item def RFBroadcastSignal {
        attribute carrierFrequency : Frequency;
        attribute signalStrength : SignalStrength;
    }
    item def TunedSignal {
        attribute carrierFrequency : Frequency;
    }
    item def MPEGTransportStream {
        attribute bitrate : DataRate;
        attribute channelNumber : ChannelNumber;
    }
    item def IPPacket {
        attribute sourceAddress : IPAddress;
        attribute destinationAddress : IPAddress;
    }
    item def ChannelRequest :> IPPacket {
        attribute requestedChannel : ChannelNumber;
    }
    item def IPVideoStream :> IPPacket {
        ref transportStream : MPEGTransportStream;
    }
    item def TuneCommand {
        attribute tunerId : ScalarValues::Integer;
        attribute channelNumber : ChannelNumber;
    }
    item def StopCommand {
        attribute tunerId : ScalarValues::Integer;
    }
    item def StatusIndication {
        attribute tunerId : ScalarValues::Integer;
        attribute locked : ScalarValues::Boolean;
    }

    port def RFSourcePort {
        out item rfSignal : RFBroadcastSignal;
    }
    port def RFLoadPort {
        in item rfSignal : RFBroadcastSignal;
    }
    port def TunedSignalSourcePort {
        out item tunedSignal : TunedSignal;
    }
    port def TunedSignalLoadPort {
        in item tunedSignal : TunedSignal;
    }
    port def TransportStreamSourcePort {
        out item stream : MPEGTransportStream;
    }
    port def TransportStreamLoadPort {
        in item stream : MPEGTransportStream;
    }
    port def EthernetPort {
        in item incomingPacket : IPPacket;
        out item outgoingPacket : IPPacket;
    }
    port def TuneCommandInputPort {
        in item command : TuneCommand;
    }
    port def TuneCommandOutputPort {
        out item command : TuneCommand;
    }
    port def StopCommandInputPort {
        in item command : StopCommand;
    }
    port def StopCommandOutputPort {
        out item command : StopCommand;
    }
    port def StatusInputPort {
        in item status : StatusIndication;
    }
    port def StatusOutputPort {
        out item status : StatusIndication;
    }
    port def ChannelRequestInputPort {
        in item request : ChannelRequest;
    }
    port def ChannelRequestOutputPort {
        out item request : ChannelRequest;
    }

    connection def EthernetLink {
        end deviceA : EthernetPort;
        end deviceB : EthernetPort;
    }

    requirement def DualTunerConcurrency {
        doc /* The HDHomeRun device shall receive and stream two different television channels simultaneously using two independent tuner and demodulator chains. */
    }
    requirement def OTAReception {
        doc /* The system shall accept over-the-air RF television broadcast signals from a standard antenna. */
    }
    requirement def IPNetworkStreaming {
        doc /* The system shall encapsulate MPEG transport streams into IP packets and transmit them over Ethernet to client devices. */
    }

    requirement dualTunerConcurrency : DualTunerConcurrency;
    requirement otaReception : OTAReception;
    requirement ipNetworkStreaming : IPNetworkStreaming;

    action def DecodeTransportStream {
        in tunedSignal : TunedSignal;
        out transportStream : MPEGTransportStream;
    }
    action def ForwardChannelRequest {
        in incomingPacket : IPPacket;
        out request : ChannelRequest;
    }
    action def EncapsulateTransportStreams {
        in stream1 : MPEGTransportStream;
        in stream2 : MPEGTransportStream;
        out videoPacket : IPVideoStream;
    }
    action def AssignTuner {
        in channelRequest : ChannelRequest;
        out tuneCommand : TuneCommand;
    }
    action def MonitorTunerStatus {
        in status1 : StatusIndication;
        in status2 : StatusIndication;
    }
    action def SendChannelRequest {
        out request : ChannelRequest;
    }
    action def DisplayVideoStream;

    part def Antenna {
        attribute signalGain : SignalStrength;
        port rfOutput : RFSourcePort;
    }

    part def RFSplitter {
        port rfInput : RFLoadPort;
        port rfOutput1 : RFSourcePort;
        port rfOutput2 : RFSourcePort;
    }

    part def RFTuner {
        attribute tunerId : ScalarValues::Integer;
        port rfInput : RFLoadPort;
        port tunedOutput : TunedSignalSourcePort;
        port tuneCommandInput : TuneCommandInputPort;
        port stopCommandInput : StopCommandInputPort;
        port statusOutput : StatusOutputPort;

        state tunerState {
            entry; then idle;
            state idle;
            transition idle_to_locked
                first idle
                accept tuneCommand : TuneCommand via tuneCommandInput
                then locked;
            state locked {
                do action outputTunedSignal {
                    out tunedSignal : TunedSignal;
                    send tunedSignal via tunedOutput;
                }
                exit action reportUnlock {
                    out status : StatusIndication;
                    send status via statusOutput;
                }
            }
            transition locked_to_idle
                first locked
                accept stopCommand : StopCommand via stopCommandInput
                then idle;
        }
    }

    part def Demodulator {
        port tunedInput : TunedSignalLoadPort;
        port streamOutput : TransportStreamSourcePort;

        state demodulatorState {
            entry; then idle;
            state idle;
            transition idle_to_decoding
                first idle
                accept tunedSignal : TunedSignal via tunedInput
                then decoding;
            state decoding {
                do action decodeTransportStream : DecodeTransportStream;
            }
        }
    }

    part def EthernetInterface {
        port networkPort : EthernetPort;
        port streamInput1 : TransportStreamLoadPort;
        port streamInput2 : TransportStreamLoadPort;
        port requestOutput : ChannelRequestOutputPort;

        state interfaceState {
            entry; then idle;
            state idle;
            transition idle_to_processing
                first idle
                accept incomingPacket : IPPacket via networkPort
                then processing;
            state processing {
                do action forwardChannelRequest : ForwardChannelRequest;
            }
            transition processing_to_idle
                first processing
                accept after 1[s]
                then idle;
        }
    }

    part def ControlProcessor {
        port requestInput : ChannelRequestInputPort;
        port tuneCommandOutput1 : TuneCommandOutputPort;
        port tuneCommandOutput2 : TuneCommandOutputPort;
        port stopCommandOutput1 : StopCommandOutputPort;
        port stopCommandOutput2 : StopCommandOutputPort;
        port statusInput1 : StatusInputPort;
        port statusInput2 : StatusInputPort;

        attribute activeTuner : ScalarValues::Integer;

        state controlState {
            entry; then idle;
            state idle;
            transition idle_to_assigning
                first idle
                accept channelRequest : ChannelRequest via requestInput
                then assigning;
            state assigning {
                do action assignTuner : AssignTuner;
            }
            transition assigning_to_streaming
                first assigning
                accept after 0.001[s]
                then streaming;
            state streaming {
                do action monitorTunerStatus : MonitorTunerStatus;
            }
            transition streaming_to_idle
                first streaming
                accept after 3600[s]
                then idle;
        }
    }

    part def HDHomeRunDevice {
        satisfy dualTunerConcurrency;
        satisfy otaReception;
        satisfy ipNetworkStreaming;

        port antennaPort : RFLoadPort;
        port networkPort : EthernetPort;

        part splitter : RFSplitter;
        part tuner1 : RFTuner;
        part tuner2 : RFTuner;
        part demodulator1 : Demodulator;
        part demodulator2 : Demodulator;
        part ethernetInterface : EthernetInterface;
        part controller : ControlProcessor;

        connect antennaPort to splitter.rfInput;
        connect splitter.rfOutput1 to tuner1.rfInput;
        connect splitter.rfOutput2 to tuner2.rfInput;
        connect tuner1.tunedOutput to demodulator1.tunedInput;
        connect tuner2.tunedOutput to demodulator2.tunedInput;
        connect demodulator1.streamOutput to ethernetInterface.streamInput1;
        connect demodulator2.streamOutput to ethernetInterface.streamInput2;
        connect ethernetInterface.requestOutput to controller.requestInput;
        connect controller.tuneCommandOutput1 to tuner1.tuneCommandInput;
        connect controller.tuneCommandOutput2 to tuner2.tuneCommandInput;
        connect controller.stopCommandOutput1 to tuner1.stopCommandInput;
        connect controller.stopCommandOutput2 to tuner2.stopCommandInput;
        connect tuner1.statusOutput to controller.statusInput1;
        connect tuner2.statusOutput to controller.statusInput2;
    }

    part def ClientDevice {
        attribute clientAddress : IPAddress;
        port ethernetPort : EthernetPort;

        state clientState {
            entry; then idle;
            state idle;
            transition idle_to_requesting
                first idle
                accept after 5[s]
                then requesting;
            state requesting {
                do action sendChannelRequest : SendChannelRequest;
            }
            transition requesting_to_viewing
                first requesting
                accept videoStream : IPVideoStream via ethernetPort
                then viewing;
            state viewing {
                do action displayVideoStream : DisplayVideoStream;
            }
            transition viewing_to_idle
                first viewing
                accept after 3600[s]
                then idle;
        }
    }

    part hdHomeRunSystem {
        part antenna : Antenna;
        part hdHomeRun : HDHomeRunDevice;
        part client1 : ClientDevice;
        part client2 : ClientDevice;

        connect antenna.rfOutput to hdHomeRun.antennaPort;
        connection link1 : EthernetLink connect hdHomeRun.networkPort to client1.ethernetPort;
        connection link2 : EthernetLink connect hdHomeRun.networkPort to client2.ethernetPort;
    }
}
