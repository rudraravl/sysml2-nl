package TelepresenceSystem {
    import ScalarValues::*;
    import ISQ::*;
    import Quantities::*;

    // ===== Value Types =====
    value type Resolution {
        attribute width : Integer;
        attribute height : Integer;
    }

    value type FrameRate :> Real {
        unit "fps";
    }

    value type Latency :> Real {
        unit "ms";
    }

    value type Bandwidth :> Real {
        unit "Mbps";
    }

    value type BitRate :> Real {
        unit "kbps";
    }

    value type SampleRate :> Real {
        unit "kHz";
    }

    // ===== Item Types =====
    item def VideoFrame {
        attribute resolution : Resolution;
        attribute frameRate : FrameRate;
    }

    item def AudioSample {
        attribute sampleRate : SampleRate;
        attribute channels : Integer;
    }

    item def VideoPacket {
        attribute payloadSize : Integer;
        attribute sequenceNumber : Integer;
        attribute timestamp : Integer;
    }

    item def AudioPacket {
        attribute payloadSize : Integer;
        attribute sequenceNumber : Integer;
        attribute timestamp : Integer;
    }

    item def NetworkStats {
        attribute bandwidth : Bandwidth;
        attribute latency : Latency;
        attribute packetLoss : Real;
    }

    // ===== Port Definitions =====
    port def VideoOutPort {
        out videoFrame : VideoFrame;
    }

    port def VideoInPort {
        in videoFrame : VideoFrame;
    }

    port def AudioOutPort {
        out audioSample : AudioSample;
    }

    port def AudioInPort {
        in audioSample : AudioSample;
    }

    port def VideoPacketOutPort {
        out videoPacket : VideoPacket;
    }

    port def VideoPacketInPort {
        in videoPacket : VideoPacket;
    }

    port def AudioPacketOutPort {
        out audioPacket : AudioPacket;
    }

    port def AudioPacketInPort {
        in audioPacket : AudioPacket;
    }

    port def NetworkOutPort {
        out videoPacket : VideoPacket;
        out audioPacket : AudioPacket;
    }

    port def NetworkInPort {
        in videoPacket : VideoPacket;
        in audioPacket : AudioPacket;
    }

    // ===== Parts: Media Devices =====
    part def Camera {
        port videoOut : VideoOutPort;
        attribute resolution : Resolution = (width=1280, height=720);
        attribute frameRate : FrameRate = 30.0 [fps];
    }

    part def Microphone {
        port audioOut : AudioOutPort;
        attribute sampleRate : SampleRate = 48.0 [kHz];
        attribute channels : Integer = 2;
    }

    part def Display {
        port videoIn : VideoInPort;
        attribute resolution : Resolution = (width=1920, height=1080);
    }

    part def Speaker {
        port audioIn : AudioInPort;
        attribute sampleRate : SampleRate = 48.0 [kHz];
    }

    // ===== Parts: Encoders and Decoders =====
    part def VideoEncoder {
        port videoIn : VideoInPort;
        port packetOut : VideoPacketOutPort;
        attribute targetBitRate : BitRate = 2500.0 [kbps];
    }

    part def AudioEncoder {
        port audioIn : AudioInPort;
        port packetOut : AudioPacketOutPort;
        attribute targetBitRate : BitRate = 128.0 [kbps];
    }

    part def VideoDecoder {
        port packetIn : VideoPacketInPort;
        port videoOut : VideoOutPort;
    }

    part def AudioDecoder {
        port packetIn : AudioPacketInPort;
        port audioOut : AudioOutPort;
    }

    // ===== Network Interface with State Machine =====
    part def NetworkInterface {
        port netOut : NetworkOutPort;
        port netIn : NetworkInPort;
        attribute currentStats : NetworkStats;
        attribute maxLatency : Latency = 150.0 [ms];
        attribute minBandwidth : Bandwidth = 2.0 [Mbps];

        state connectionStateMachine {
            entry; then disconnected;

            state disconnected {
                entry action { send ConnectRequest; }
                on ConnectRequest via netIn;
                transition disconnected_connecting
                    first disconnected
                    accept ConnectRequest
                    then connecting;
            }

            state connecting {
                entry action { perform Handshake; }
                transition connecting_connected
                    first connecting
                    accept HandshakeComplete
                    then connected;
                transition connecting_reconnecting
                    first connecting
                    accept Timeout
                    then reconnecting;
            }

            state connected {
                entry action { start QualityMonitor; }
                do action { monitorQuality(); }
                transition connected_reconnecting
                    first connected
                    accept QualityDegraded
                    then reconnecting;
                transition connected_disconnected
                    first connected
                    accept Disconnect
                    then disconnected;
            }

            state reconnecting {
                entry action { perform ReconnectAttempt; }
                transition reconnecting_connected
                    first reconnecting
                    accept HandshakeComplete
                    then connected;
                transition reconnecting_disconnected
                    first reconnecting
                    accept MaxRetriesExceeded
                    then disconnected;
            }
        }

        action monitorQuality {
            in stats : NetworkStats;
            decision checkQuality {
                if stats.latency > maxLatency or stats.bandwidth < minBandwidth
                then send QualityDegraded;
            }
        }
    }

    // ===== Quality Monitor =====
    part def QualityMonitor {
        port statsOut : NetworkStats;
        attribute thresholdLatency : Latency = 150.0 [ms];
        attribute thresholdBandwidth : Bandwidth = 2.0 [Mbps];
        attribute thresholdPacketLoss : Real = 0.05;

        action monitor {
            in currentStats : NetworkStats;
            out qualityAlert : Boolean;
            decision assess {
                if currentStats.latency > thresholdLatency
                then qualityAlert = true;
                if currentStats.bandwidth < thresholdBandwidth
                then qualityAlert = true;
                if currentStats.packetLoss > thresholdPacketLoss
                then qualityAlert = true;
                else qualityAlert = false;
            }
        }
    }

    // ===== Session Controller =====
    part def SessionController {
        port controlOut;
        attribute sessionActive : Boolean = false;
        attribute avSyncThreshold : Latency = 50.0 [ms];

        action manageSession {
            in qualityAlert : Boolean;
            out endSession : Boolean;
            decision evaluate {
                if qualityAlert == true
                then endSession = true;
                else endSession = false;
            }
        }

        action synchronizeAV {
            in videoTimestamp : Integer;
            in audioTimestamp : Integer;
            out syncOffset : Latency;
            decision computeOffset {
                syncOffset = (videoTimestamp - audioTimestamp) as Latency;
                if syncOffset > avSyncThreshold
                then send SyncWarning;
            }
        }
    }

    // ===== Endpoint =====
    part def Endpoint {
        // Media capture devices
        part camera : Camera;
        part microphone : Microphone;

        // Media rendering devices
        part display : Display;
        part speaker : Speaker;

        // Encoders
        part videoEncoder : VideoEncoder;
        part audioEncoder : AudioEncoder;

        // Decoders
        part videoDecoder : VideoDecoder;
        part audioDecoder : AudioDecoder;

        // Network
        part networkInterface : NetworkInterface;

        // Quality monitoring and session control
        part qualityMonitor : QualityMonitor;
        part sessionController : SessionController;

        // Internal connections: capture -> encode -> network
        connection cameraToVideoEncoder connect camera.videoOut to videoEncoder.videoIn;
        connection micToAudioEncoder connect microphone.audioOut to audioEncoder.audioIn;
        connection videoEncoderToNet connect videoEncoder.packetOut.videoPacket to networkInterface.netOut.videoPacket;
        connection audioEncoderToNet connect audioEncoder.packetOut.audioPacket to networkInterface.netOut.audioPacket;

        // Internal connections: network -> decode -> render
        connection netToVideoDecoder connect networkInterface.netIn.videoPacket to videoDecoder.packetIn.videoPacket;
        connection netToAudioDecoder connect networkInterface.netIn.audioPacket to audioDecoder.packetIn.audioPacket;
        connection videoDecoderToDisplay connect videoDecoder.videoOut.videoFrame to display.videoIn.videoFrame;
        connection audioDecoderToSpeaker connect audioDecoder.audioOut.audioSample to speaker.audioIn.audioSample;
    }

    // ===== Telepresence System =====
    part def TelepresenceSystem {
        part endpointA : Endpoint;
        part endpointB : Endpoint;

        // Bidirectional network connections between endpoints
        connection endpointA_to_endpointB_video
            connect endpointA.networkInterface.netOut.videoPacket
            to endpointB.networkInterface.netIn.videoPacket;
        connection endpointA_to_endpointB_audio
            connect endpointA.networkInterface.netOut.audioPacket
            to endpointB.networkInterface.netIn.audioPacket;
        connection endpointB_to_endpointA_video
            connect endpointB.networkInterface.netOut.videoPacket
            to endpointA.networkInterface.netIn.videoPacket;
        connection endpointB_to_endpointA_audio
            connect endpointB.networkInterface.netOut.audioPacket
            to endpointA.networkInterface.netIn.audioPacket;
    }

    // ===== Requirements =====
    requirement def VideoQualityRequirement {
        doc /* The system shall support at least 720p video resolution at 30 frames per second. */
        subject telepresenceSystem : TelepresenceSystem;
        assume :> telepresenceSystem.endpointA.camera.resolution >= (width=1280, height=720);
        assume :> telepresenceSystem.endpointB.camera.resolution >= (width=1280, height=720);
        require :> telepresenceSystem.endpointA.camera.frameRate >= 30.0 [fps];
        require :> telepresenceSystem.endpointB.camera.frameRate >= 30.0 [fps];
    }

    requirement def LatencyRequirement {
        doc /* The end-to-end latency shall not exceed 150 milliseconds. */
        subject telepresenceSystem : TelepresenceSystem;
        attribute maxLatency : Latency = 150.0 [ms];
        require :> telepresenceSystem.endpointA.networkInterface.maxLatency <= maxLatency;
        require :> telepresenceSystem.endpointB.networkInterface.maxLatency <= maxLatency;
    }

    requirement def AVSyncRequirement {
        doc /* Audio and video streams shall be synchronized within 50 milliseconds. */
        subject telepresenceSystem : TelepresenceSystem;
        attribute syncThreshold : Latency = 50.0 [ms];
        require :> telepresenceSystem.endpointA.sessionController.avSyncThreshold <= syncThreshold;
        require :> telepresenceSystem.endpointB.sessionController.avSyncThreshold <= syncThreshold;
    }

    requirement def NetworkQualityRequirement {
        doc /* The network shall maintain minimum bandwidth of 2 Mbps and packet loss below 5%. */
        subject telepresenceSystem : TelepresenceSystem;
        attribute minBandwidth : Bandwidth = 2.0 [Mbps];
        attribute maxPacketLoss : Real = 0.05;
        require :> telepresenceSystem.endpointA.networkInterface.minBandwidth >= minBandwidth;
        require :> telepresenceSystem.endpointB.networkInterface.minBandwidth >= minBandwidth;
        require :> telepresenceSystem.endpointA.qualityMonitor.thresholdPacketLoss <= maxPacketLoss;
        require :> telepresenceSystem.endpointB.qualityMonitor.thresholdPacketLoss <= maxPacketLoss;
    }

    requirement def SessionRobustnessRequirement {
        doc /* The system shall automatically end the session if quality falls below acceptable levels. */
        subject telepresenceSystem : TelepresenceSystem;
        require :> telepresenceSystem.endpointA.sessionController.manageSession.endSession == true
            when telepresenceSystem.endpointA.qualityMonitor.monitor.qualityAlert == true;
        require :> telepresenceSystem.endpointB.sessionController.manageSession.endSession == true
            when telepresenceSystem.endpointB.qualityMonitor.monitor.qualityAlert == true;
    }

    requirement package TelepresenceRequirements {
        requirement videoQualityReq : VideoQualityRequirement;
        requirement latencyReq : LatencyRequirement;
        requirement avSyncReq : AVSyncRequirement;
        requirement networkQualityReq : NetworkQualityRequirement;
        requirement sessionRobustnessReq : SessionRobustnessRequirement;
    }

    // ===== Verification =====
    verification def VerifyVideoQuality {
        subject telepresenceSystem : TelepresenceSystem;
        objective verifyVideoQuality {
            doc /* Verify that both endpoints support 720p at 30fps. */
        }
    }

    verification def VerifyLatency {
        subject telepresenceSystem : TelepresenceSystem;
        objective verifyLatency {
            doc /* Verify end-to-end latency is below 150ms. */
        }
    }

    verification def VerifyAVSync {
        subject telepresenceSystem : TelepresenceSystem;
        objective verifyAVSync {
            doc /* Verify audio-video synchronization within 50ms. */
        }
    }
}
