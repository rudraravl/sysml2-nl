package TelepresenceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def VideoFrame {
            attribute resolution : String;
            attribute frameRate : FrequencyValue;
        }
        item def AudioSample;
        item def Packet {
            attribute payload : String;
        }

        port def VideoOutPort {
            out video : VideoFrame;
        }
        port def VideoInPort {
            in video : VideoFrame;
        }
        port def AudioOutPort {
            out audio : AudioSample;
        }
        port def AudioInPort {
            in audio : AudioSample;
        }
        port def DataOutPort {
            out packets : Packet;
        }
        port def DataInPort {
            in packets : Packet;
        }
        port def NetworkPort {
            out tx : Packet;
            in rx : Packet;
        }

        action def CaptureVideo {
            out videoStream : VideoFrame;
        }
        action def CaptureAudio {
            out audioStream : AudioSample;
        }
        action def RenderVideo {
            in videoStream : VideoFrame;
        }
        action def PlayAudio {
            in audioStream : AudioSample;
        }
        action def EncodeVideo {
            in rawVideo : VideoFrame;
            out encodedPackets : Packet;
        }
        action def EncodeAudio {
            in rawAudio : AudioSample;
            out encodedPackets : Packet;
        }
        action def DecodeVideo {
            in encodedPackets : Packet;
            out rawVideo : VideoFrame;
        }
        action def DecodeAudio {
            in encodedPackets : Packet;
            out rawAudio : AudioSample;
        }

        part def Camera {
            port videoOut : VideoOutPort;
            perform action captureVideo : CaptureVideo;
            flow from captureVideo.videoStream to videoOut.video;
        }

        part def Microphone {
            port audioOut : AudioOutPort;
            perform action captureAudio : CaptureAudio;
            flow from captureAudio.audioStream to audioOut.audio;
        }

        part def Display {
            port videoIn : VideoInPort;
            perform action renderVideo : RenderVideo;
            flow from videoIn.video to renderVideo.videoStream;
        }

        part def Speaker {
            port audioIn : AudioInPort;
            perform action playAudio : PlayAudio;
            flow from audioIn.audio to playAudio.audioStream;
        }

        part def VideoEncoder {
            port videoIn : VideoInPort;
            port dataOut : DataOutPort;
            perform action encodeVideo : EncodeVideo;
            flow from videoIn.video to encodeVideo.rawVideo;
            flow from encodeVideo.encodedPackets to dataOut.packets;
        }

        part def AudioEncoder {
            port audioIn : AudioInPort;
            port dataOut : DataOutPort;
            perform action encodeAudio : EncodeAudio;
            flow from audioIn.audio to encodeAudio.rawAudio;
            flow from encodeAudio.encodedPackets to dataOut.packets;
        }

        part def VideoDecoder {
            port dataIn : DataInPort;
            port videoOut : VideoOutPort;
            perform action decodeVideo : DecodeVideo;
            flow from dataIn.packets to decodeVideo.encodedPackets;
            flow from decodeVideo.rawVideo to videoOut.video;
        }

        part def AudioDecoder {
            port dataIn : DataInPort;
            port audioOut : AudioOutPort;
            perform action decodeAudio : DecodeAudio;
            flow from dataIn.packets to decodeAudio.encodedPackets;
            flow from decodeAudio.rawAudio to audioOut.audio;
        }

        part def NetworkInterface {
            port encoderIn : DataInPort;
            port decoderOut : DataOutPort;
            port netPort : NetworkPort;

            attribute bandwidth : Real;
            attribute latency : TimeValue;
            attribute sessionActive : Boolean;

            flow from encoderIn.packets to netPort.tx;
            flow from netPort.rx to decoderOut.packets;

            exhibit state NetworkState {
                entry; then Disconnected;
                state Disconnected;
                then Connecting;
                state Connecting;
                then Connected;
                then Disconnected;
                state Connected;
                then Reconnecting;
                state Reconnecting;
                then Connected;
                then Disconnected;
            }
        }

        part def Endpoint {
            part camera : Camera;
            part microphone : Microphone;
            part display : Display;
            part speaker : Speaker;
            part videoEncoder : VideoEncoder;
            part audioEncoder : AudioEncoder;
            part videoDecoder : VideoDecoder;
            part audioDecoder : AudioDecoder;
            part networkInterface : NetworkInterface;

            connect camera.videoOut to videoEncoder.videoIn;
            connect microphone.audioOut to audioEncoder.audioIn;
            connect videoEncoder.dataOut to networkInterface.encoderIn;
            connect audioEncoder.dataOut to networkInterface.encoderIn;
            connect networkInterface.decoderOut to videoDecoder.dataIn;
            connect networkInterface.decoderOut to audioDecoder.dataIn;
            connect videoDecoder.videoOut to display.videoIn;
            connect audioDecoder.audioOut to speaker.audioIn;
        }

        part def Network {
            port port1 : NetworkPort;
            port port2 : NetworkPort;
            connect port1 to port2;
        }
    }

    package Requirements {
        private import Definitions::*;

        requirement def VideoQualityRequirement {
            doc /* The system shall provide at least 720p video at 30 frames per second. */
            attribute actualResolution : String;
            attribute actualFrameRate : FrequencyValue;
            require constraint {
                actualResolution == "720p" and actualFrameRate >= 30 [Hz]
            }
        }

        requirement def LatencyRequirement {
            doc /* The system shall maintain latency under 150 milliseconds. */
            attribute actualLatency : TimeValue;
            require constraint {
                actualLatency < 150 [ms]
            }
        }

        requirement def AudioVideoSyncRequirement {
            doc /* The system shall ensure precise audio-video synchronization. */
            attribute syncOffset : TimeValue;
            require constraint {
                syncOffset <= 30 [ms]
            }
        }

        requirement def ConnectionQualityRequirement {
            doc /* If quality falls below threshold, the session must end. */
            attribute minBandwidth : Real;
            attribute maxLatency : TimeValue;
            require constraint {
                minBandwidth > 0 and maxLatency <= 150 [ms]
            }
        }

        requirement videoQualityReq : VideoQualityRequirement {
            :>> actualResolution = "720p";
            :>> actualFrameRate = 30 [Hz];
        }

        requirement latencyReq : LatencyRequirement {
            :>> actualLatency = 100 [ms];
        }

        requirement avSyncReq : AudioVideoSyncRequirement {
            :>> syncOffset = 20 [ms];
        }

        requirement connQualityReq : ConnectionQualityRequirement {
            :>> minBandwidth = 2.0;
            :>> maxLatency = 150 [ms];
        }
    }

    package Usages {
        private import Definitions::*;
        private import Requirements::*;

        part telepresenceSystem {
            part endpoint1 : Endpoint {
                satisfy videoQualityReq;
                satisfy latencyReq;
                satisfy avSyncReq;
                satisfy connQualityReq;
            }
            part endpoint2 : Endpoint {
                satisfy videoQualityReq;
                satisfy latencyReq;
                satisfy avSyncReq;
                satisfy connQualityReq;
            }
            part network : Network;

            connect endpoint1.networkInterface.netPort to network.port1;
            connect endpoint2.networkInterface.netPort to network.port2;
        }
    }
}
