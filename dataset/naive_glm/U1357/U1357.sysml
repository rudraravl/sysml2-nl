package MediaStreamingServer {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type Bandwidth {
        attribute value: Real;
        attribute unit: String = "Mbps";
    }
    value type Bitrate {
        attribute value: Real;
        attribute unit: String = "Mbps";
    }
    value type Resolution {
        attribute width: Integer;
        attribute height: Integer;
        attribute unit: String = "pixels";
    }
    value type BufferFillLevel {
        attribute value: Real;
        attribute unit: String = "percent";
    }
    value type PacketSize {
        attribute value: Integer;
        attribute unit: String = "bytes";
    }
    value type Duration {
        attribute value: Real;
        attribute unit: String = "seconds";
    }
    value type FrameRate {
        attribute value: Real;
        attribute unit: String = "fps";
    }
    value type QualityLevel {
        enum { low, medium, high, ultra };
    }

    // ===== Item Types =====
    item def MediaFile {
        attribute title: String;
        attribute filePath: String;
        attribute codec: String;
        attribute originalResolution: Resolution;
        attribute originalBitrate: Bitrate;
        attribute duration: Duration;
        attribute frameRate: FrameRate;
    }
    item def VideoStream {
        attribute resolution: Resolution;
        attribute bitrate: Bitrate;
        attribute codec: String;
        attribute frameRate: FrameRate;
        attribute qualityLevel: QualityLevel;
    }
    item def DataPacket {
        attribute sequenceNumber: Integer;
        attribute payload: DataValue;
        attribute size: PacketSize;
        attribute timestamp: Duration;
    }
    item def SessionRequest {
        attribute userId: String;
        attribute mediaId: String;
        attribute clientResolution: Resolution;
        attribute authToken: String;
    }
    item def ClientFeedback {
        attribute bufferFillLevel: BufferFillLevel;
        attribute measuredBandwidth: Bandwidth;
        attribute playbackStalled: Boolean;
    }
    item def QualityDecision {
        attribute targetResolution: Resolution;
        attribute targetBitrate: Bitrate;
        attribute requiresTranscoding: Boolean;
        attribute qualityLevel: QualityLevel;
    }
    item def AuthToken {
        attribute token: String;
        attribute valid: Boolean;
    }

    // ===== Port Definitions =====
    port def MediaRequestPort {
        out item sessionRequest: SessionRequest;
        in item authToken: AuthToken;
    }
    port def MediaFilePort {
        out item mediaFile: MediaFile;
    }
    port def QualityDecisionPort {
        out item qualityDecision: QualityDecision;
    }
    port def VideoStreamPort {
        out item videoStream: VideoStream;
    }
    port def DataPacketPort {
        out item dataPackets: DataPacket;
    }
    port def ClientFeedbackPort {
        in item clientFeedback: ClientFeedback;
    }
    port def NetworkStatusPort {
        out item bandwidth: Bandwidth;
    }

    // ===== Parts =====
    part def MediaLibraryDatabase {
        port mediaOut: MediaFilePort;
        attribute catalog: MediaFile[0..*];
        operation retrieveMedia(mediaId: String): MediaFile;
        operation indexMedia(file: MediaFile): Void;
        operation removeMedia(mediaId: String): Void;
    }

    part def SessionManager {
        port requestIn: MediaRequestPort;
        port mediaRequestOut: MediaRequestPort;
        port mediaFileIn: MediaFilePort;
        port streamOut: VideoStreamPort;
        attribute activeSessions: Integer;
        operation authenticate(request: SessionRequest): AuthToken;
        operation createSession(request: SessionRequest): Boolean;
        operation terminateSession(sessionId: String): Void;
    }

    part def QualityAdaptationController {
        port decisionOut: QualityDecisionPort;
        port feedbackIn: ClientFeedbackPort;
        port bandwidthIn: NetworkStatusPort;
        attribute currentQuality: QualityLevel;
        attribute lastDecision: QualityDecision;
        operation assessClient(clientRes: Resolution, bandwidth: Bandwidth): QualityDecision;
        operation adjustQuality(feedback: ClientFeedback): QualityDecision;
        operation determineTranscodingNeed(original: MediaFile, target: QualityDecision): Boolean;
    }

    part def TranscodingEngine {
        port mediaIn: MediaFilePort;
        port decisionIn: QualityDecisionPort;
        port streamOut: VideoStreamPort;
        attribute activeJobs: Integer;
        attribute maxConcurrentJobs: Integer = 4;
        operation transcode(file: MediaFile, decision: QualityDecision): VideoStream;
        operation cancelJob(jobId: String): Void;
    }

    part def AdaptiveStreamingBuffer {
        port streamIn: VideoStreamPort;
        port packetOut: DataPacketPort;
        attribute maxBufferSize: Integer = 10485760;
        attribute currentFillLevel: BufferFillLevel;
        operation bufferStream(stream: VideoStream): Void;
        operation flushBuffer(): Void;
        operation packetize(stream: VideoStream): DataPacket;
    }

    part def NetworkStreamingInterface {
        port packetIn: DataPacketPort;
        port feedbackOut: ClientFeedbackPort;
        port bandwidthOut: NetworkStatusPort;
        attribute measuredBandwidth: Bandwidth;
        operation sendPacket(packet: DataPacket): Void;
        operation measureBandwidth(): Bandwidth;
        operation receiveFeedback(): ClientFeedback;
    }

    part def ClientDevice {
        port packetIn: DataPacketPort;
        port feedbackOut: ClientFeedbackPort;
        attribute screenResolution: Resolution;
        attribute bufferLevel: BufferFillLevel;
        operation playStream(packet: DataPacket): Void;
        operation sendFeedback(): ClientFeedback;
    }

    // ===== Main System =====
    part def MediaStreamingServerSystem {
        port clientInterface: MediaRequestPort;
        port networkInterface: DataPacketPort;
        port feedbackInterface: ClientFeedbackPort;

        part library: MediaLibraryDatabase;
        part sessionMgr: SessionManager;
        part qualityCtrl: QualityAdaptationController;
        part transcoder: TranscodingEngine;
        part buffer: AdaptiveStreamingBuffer;
        part networkIface: NetworkStreamingInterface;

        connection reqToSession connect clientInterface to sessionMgr.requestIn;
        connection sessionToLibrary connect sessionMgr.mediaRequestOut to library.mediaOut;
        connection libraryToSession connect library.mediaOut to sessionMgr.mediaFileIn;
        connection sessionToTranscoder connect sessionMgr.streamOut to transcoder.mediaIn;
        connection qualityToTranscoder connect qualityCtrl.decisionOut to transcoder.decisionIn;
        connection transcoderToBuffer connect transcoder.streamOut to buffer.streamIn;
        connection bufferToNetwork connect buffer.packetOut to networkIface.packetIn;
        connection networkToClient connect networkIface.packetIn to networkInterface;
        connection clientFeedbackToQuality connect feedbackInterface to qualityCtrl.feedbackIn;
        connection networkBandwidthToQuality connect networkIface.bandwidthOut to qualityCtrl.bandwidthIn;

        // ===== State Machine =====
        state def ServerLifecycle {
            entry action { send ServerStatus.idle; }
            state idle {
                entry action { sessionMgr.activeSessions = 0; }
                transition idle_to_initiating
                    first idle
                    then initiating
                    accept SessionRequest;
            }
            state initiating {
                entry action {
                    sessionMgr.authenticate(current SessionRequest);
                    sessionMgr.createSession(current SessionRequest);
                    library.retrieveMedia(current SessionRequest.mediaId);
                    qualityCtrl.assessClient(current SessionRequest.clientResolution, networkIface.measuredBandwidth);
                }
                do action { qualityCtrl.determineTranscodingNeed(current MediaFile, current QualityDecision); }
                transition initiating_to_transcoding
                    first initiating
                    then transcoding
                    when qualityCtrl.lastDecision.requiresTranscoding == true;
                transition initiating_to_streaming
                    first initiating
                    then activeStreaming
                    when qualityCtrl.lastDecision.requiresTranscoding == false;
            }
            state transcoding {
                entry action { transcoder.transcode(current MediaFile, qualityCtrl.lastDecision); }
                do action {
                    buffer.bufferStream(current VideoStream);
                    qualityCtrl.adjustQuality(current ClientFeedback);
                }
                transition transcoding_to_streaming
                    first transcoding
                    then activeStreaming
                    when buffer.currentFillLevel.value > 20.0;
                transition transcoding_to_adapting
                    first transcoding
                    then adapting
                    when qualityCtrl.feedbackIn.clientFeedback.measuredBandwidth.value < qualityCtrl.lastDecision.targetBitrate.value;
            }
            state activeStreaming {
                entry action { buffer.packetize(current VideoStream); }
                do action {
                    networkIface.sendPacket(current DataPacket);
                    networkIface.measureBandwidth();
                    qualityCtrl.adjustQuality(current ClientFeedback);
                }
                transition streaming_to_adapting_down
                    first activeStreaming
                    then adapting
                    when qualityCtrl.feedbackIn.clientFeedback.bufferFillLevel.value < 30.0;
                transition streaming_to_adapting_up
                    first activeStreaming
                    then adapting
                    when qualityCtrl.feedbackIn.clientFeedback.measuredBandwidth.value > qualityCtrl.lastDecision.targetBitrate.value * 1.5;
                transition streaming_to_cleanup
                    first activeStreaming
                    then cleanup
                    when sessionMgr.activeSessions == 0;
            }
            state adapting {
                entry action {
                    qualityCtrl.adjustQuality(current ClientFeedback);
                    qualityCtrl.determineTranscodingNeed(current MediaFile, qualityCtrl.lastDecision);
                }
                transition adapting_to_transcoding
                    first adapting
                    then transcoding
                    when qualityCtrl.lastDecision.requiresTranscoding == true;
                transition adapting_to_streaming
                    first adapting
                    then activeStreaming
                    when qualityCtrl.lastDecision.requiresTranscoding == false;
            }
            state cleanup {
                entry action {
                    buffer.flushBuffer();
                    sessionMgr.terminateSession(current sessionId);
                    transcoder.cancelJob(current jobId);
                }
                transition cleanup_to_idle
                    first cleanup
                    then idle
                    when sessionMgr.activeSessions == 0;
            }
        }

        // ===== Requirements =====
        requirement def StreamingPerformanceRequirement {
            attribute id: String = "SPR-001";
            attribute text: String = "The system shall deliver media with less than 2 seconds initial buffering time under normal network conditions.";
            verify by ServerLifecycle.initiating;
        }
        requirement def AdaptiveQualityRequirement {
            attribute id: String = "AQR-002";
            attribute text: String = "The system shall adjust video quality within 5 seconds of detecting a network bandwidth change exceeding 20 percent.";
            verify by ServerLifecycle.adapting;
        }
        requirement def TranscodingRequirement {
            attribute id: String = "TR-003";
            attribute text: String = "The system shall transcode media files on-the-fly when the original resolution or bitrate exceeds client capabilities.";
            verify by ServerLifecycle.transcoding;
        }
        requirement def BufferManagementRequirement {
            attribute id: String = "BMR-004";
            attribute text: String = "The adaptive streaming buffer shall maintain a minimum fill level of 10 percent during active streaming to prevent stuttering.";
            verify by ServerLifecycle.activeStreaming;
        }
        requirement def AuthenticationRequirement {
            attribute id: String = "AR-005";
            attribute text: String = "The session manager shall authenticate every user request before establishing a streaming session.";
            verify by ServerLifecycle.initiating;
        }
        requirement def SessionLifecycleRequirement {
            attribute id: String = "SLR-006";
            attribute text: String = "The system shall clean up all resources including buffer flush and session termination when streaming completes.";
            verify by ServerLifecycle.cleanup;
        }
        requirement def NetworkMonitoringRequirement {
            attribute id: String = "NMR-007";
            attribute text: String = "The network streaming interface shall continuously measure available bandwidth and report changes to the quality adaptation controller.";
            verify by ServerLifecycle.activeStreaming;
        }
    }
}
