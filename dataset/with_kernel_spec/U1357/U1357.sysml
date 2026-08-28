package 'Media Streaming Server' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def Bandwidth :> Real;
		attribute def Bitrate :> Real;
		attribute def ResolutionHeight :> Integer;
		attribute def BufferLevel :> Real;
		attribute def SequenceNumber :> Integer;

		item def MediaRequest {
			attribute userId : String;
			attribute mediaId : String;
		}

		item def MediaMetadata {
			attribute mediaId : String;
			attribute title : String;
			attribute filePath : String;
			attribute originalResolution : ResolutionHeight;
			attribute originalBitrate : Bitrate;
		}

		item def AuthToken {
			attribute tokenValue : String;
		}

		item def ClientCapabilities {
			attribute maxResolution : ResolutionHeight;
			attribute supportedCodecs : String;
		}

		item def NetworkStatus {
			attribute availableBandwidth : Bandwidth;
			attribute latency : Real;
		}

		item def QualityDecision {
			attribute targetResolution : ResolutionHeight;
			attribute targetBitrate : Bitrate;
			attribute requiresTranscoding : Boolean;
		}

		item def VideoSegment {
			attribute sequenceNumber : SequenceNumber;
			attribute resolution : ResolutionHeight;
			attribute bitrate : Bitrate;
			attribute data : String;
		}

		item def StreamPacket {
			attribute sequenceNumber : SequenceNumber;
			attribute payload : String;
		}

		item def ClientFeedback {
			attribute bufferLevel : BufferLevel;
			attribute playbackStalled : Boolean;
		}

		item def QualityAdjustment {
			attribute newTargetResolution : ResolutionHeight;
			attribute newTargetBitrate : Bitrate;
			attribute direction : QualityDirection;
		}

		enum def QualityDirection {
			increase;
			decrease;
			maintain;
		}

		attribute def StartSignal;
		attribute def SessionEstablishedSignal;
		attribute def TranscodeNeededSignal;
		attribute def DirectPlaySignal;
		attribute def TranscodeCompleteSignal;
		attribute def StreamCompleteSignal;
		attribute def ErrorSignal;
		attribute def CleanupCompleteSignal;
		attribute def QualityDecreaseSignal;
		attribute def QualityIncreaseSignal;

		action def AuthenticateUser { in request: MediaRequest; out token: AuthToken; }
		action def RetrieveMediaMetadata { in mediaRequest: MediaRequest; out metadata: MediaMetadata; }
		action def AssessClientCapabilities { out capabilities: ClientCapabilities; }
		action def AssessNetwork { out status: NetworkStatus; }
		action def DecideQuality { in metadata: MediaMetadata; in capabilities: ClientCapabilities; in network: NetworkStatus; out decision: QualityDecision; }
		action def TranscodeMedia { in metadata: MediaMetadata; in decision: QualityDecision; out segment: VideoSegment; }
		action def BufferSegment { in segment: VideoSegment; out bufferedSegment: VideoSegment; }
		action def PacketizeAndSend { in segment: VideoSegment; out packet: StreamPacket; }
		action def MonitorClientFeedback { in rawFeedback: ClientFeedback; out feedback: ClientFeedback; }
		action def AdjustQuality { in feedback: ClientFeedback; in network: NetworkStatus; out adjustment: QualityAdjustment; }
		action def CleanupSession;

		state def ServerLifecycle;

		part def MediaLibraryDatabase {
			port mediaQueryPort {
				in mediaRequest : MediaRequest;
				out metadata : MediaMetadata;
			}
		}

		part def SessionManager {
			port requestPort {
				in request : MediaRequest;
			}
			port mediaRequestOutPort {
				out mediaRequest : MediaRequest;
			}
			port metadataInPort {
				in metadata : MediaMetadata;
			}
			port metadataOutPort {
				out metadata : MediaMetadata;
			}
		}

		part def QualityAdaptationController {
			port metadataInPort {
				in metadata : MediaMetadata;
			}
			port feedbackPort {
				in feedback : ClientFeedback;
			}
			port decisionPort {
				out decision : QualityDecision;
			}
			port adjustmentPort {
				out adjustment : QualityAdjustment;
			}
		}

		part def TranscodingEngine {
			port metadataInPort {
				in metadata : MediaMetadata;
			}
			port decisionInPort {
				in decision : QualityDecision;
			}
			port transcodeOutPort {
				out segment : VideoSegment;
			}
		}

		part def AdaptiveStreamingBuffer {
			port bufferInPort {
				in segment : VideoSegment;
			}
			port bufferOutPort {
				out bufferedSegment : VideoSegment;
			}
			attribute bufferCapacity : BufferLevel = 100.0;
			attribute currentLevel : BufferLevel;
		}

		part def NetworkStreamingInterface {
			port streamInPort {
				in bufferedSegment : VideoSegment;
			}
			port streamOutPort {
				out packet : StreamPacket;
			}
			port clientFeedbackInPort {
				in feedback : ClientFeedback;
			}
			port feedbackOutPort {
				out feedback : ClientFeedback;
			}
		}

		part def MediaStreamingServer {
			port incomingRequestPort {
				in request : MediaRequest;
			}
			port clientFeedbackInPort {
				in feedback : ClientFeedback;
			}
			port streamOutPort {
				out packet : StreamPacket;
			}

			part mediaLibraryDatabase : MediaLibraryDatabase;
			part sessionManager : SessionManager;
			part qualityAdaptationController : QualityAdaptationController;
			part transcodingEngine : TranscodingEngine;
			part adaptiveStreamingBuffer : AdaptiveStreamingBuffer;
			part networkStreamingInterface : NetworkStreamingInterface;

			flow requestFlow of MediaRequest
				from incomingRequestPort.request to sessionManager.requestPort.request;
			flow mediaRequestFlow of MediaRequest
				from sessionManager.mediaRequestOutPort.mediaRequest to mediaLibraryDatabase.mediaQueryPort.mediaRequest;
			flow metadataToSessionFlow of MediaMetadata
				from mediaLibraryDatabase.mediaQueryPort.metadata to sessionManager.metadataInPort.metadata;
			flow metadataToQualityFlow of MediaMetadata
				from sessionManager.metadataOutPort.metadata to qualityAdaptationController.metadataInPort.metadata;
			flow metadataToTranscoderFlow of MediaMetadata
				from sessionManager.metadataOutPort.metadata to transcodingEngine.metadataInPort.metadata;
			flow decisionFlow of QualityDecision
				from qualityAdaptationController.decisionPort.decision to transcodingEngine.decisionInPort.decision;
			flow segmentFlow of VideoSegment
				from transcodingEngine.transcodeOutPort.segment to adaptiveStreamingBuffer.bufferInPort.segment;
			flow bufferedSegmentFlow of VideoSegment
				from adaptiveStreamingBuffer.bufferOutPort.bufferedSegment to networkStreamingInterface.streamInPort.bufferedSegment;
			flow packetFlow of StreamPacket
				from networkStreamingInterface.streamOutPort.packet to streamOutPort.packet;
			flow clientFeedbackFlow of ClientFeedback
				from clientFeedbackInPort.feedback to networkStreamingInterface.clientFeedbackInPort.feedback;
			flow internalFeedbackFlow of ClientFeedback
				from networkStreamingInterface.feedbackOutPort.feedback to qualityAdaptationController.feedbackPort.feedback;

			action 'authenticate user': AuthenticateUser;
			action 'retrieve metadata': RetrieveMediaMetadata;
			action 'assess client': AssessClientCapabilities;
			action 'assess network': AssessNetwork;
			action 'decide quality': DecideQuality;
			action 'transcode media': TranscodeMedia;
			action 'buffer segment': BufferSegment;
			action 'packetize and send': PacketizeAndSend;
			action 'monitor feedback': MonitorClientFeedback;
			action 'adjust quality': AdjustQuality;
			action 'cleanup session': CleanupSession;

			exhibit state 'server lifecycle': ServerLifecycle {
				entry; then idle;
				state idle;
				accept StartSignal
					then initiating;
				state initiating {
					entry 'authenticate user';
				}
				accept SessionEstablishedSignal
					then deciding;
				state deciding {
					entry 'decide quality';
				}
				accept TranscodeNeededSignal
					then transcoding;
				accept DirectPlaySignal
					then streaming;
				state transcoding {
					entry 'transcode media';
				}
				accept TranscodeCompleteSignal
					then streaming;
				state streaming {
					do 'packetize and send';
				}
				accept QualityDecreaseSignal
					then adjusting;
				accept QualityIncreaseSignal
					then adjusting;
				state adjusting {
					entry 'adjust quality';
				}
				accept TranscodeNeededSignal
					then transcoding;
				accept DirectPlaySignal
					then streaming;
				accept StreamCompleteSignal
					then cleanup;
				accept ErrorSignal
					then cleanup;
				state cleanup {
					entry 'cleanup session';
				}
				accept CleanupCompleteSignal
					then idle;
			}
		}

		part def ClientDevice {
			port receivePort {
				in packet : StreamPacket;
			}
			port feedbackPort {
				out feedback : ClientFeedback;
			}
			attribute maxResolution : ResolutionHeight;
		}

		part def User {
			port requestPort {
				out request : MediaRequest;
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part user : User;
		part server : MediaStreamingServer;
		part client : ClientDevice;

		interface userToServerInterface connect user.requestPort to server.incomingRequestPort {
			flow userRequestFlow of MediaRequest
				from user.requestPort.request to server.incomingRequestPort.request;
		}

		interface serverToClientInterface connect server.streamOutPort to client.receivePort {
			flow packetFlow of StreamPacket
				from server.streamOutPort.packet to client.receivePort.packet;
		}

		interface clientToServerInterface connect client.feedbackPort to server.clientFeedbackInPort {
			flow clientFeedbackFlow of ClientFeedback
				from client.feedbackPort.feedback to server.clientFeedbackInPort.feedback;
		}
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def 'Provide Adaptive Streaming' {
			doc /*
			 * The media streaming server shall deliver digital media content
			 * to client devices over a network with adaptive quality.
			 */
			subject server : MediaStreamingServer;

			requirement 'Catalog Media' {
				doc /*
				 * The Media Library Database shall catalog and store all media files
				 * and provide metadata on request.
				 */
				subject mediaLibraryDatabase : MediaLibraryDatabase;
			}

			requirement 'Manage Sessions' {
				doc /*
				 * The Session Manager shall authenticate users and establish
				 * dedicated streaming sessions upon receiving a media request.
				 */
				subject sessionManager : SessionManager;
			}

			requirement 'Assess Quality Requirements' {
				doc /*
				 * The Quality Adaptation Controller shall assess client network
				 * bandwidth and screen resolution to determine if transcoding
				 * is necessary.
				 */
				subject qualityAdaptationController : QualityAdaptationController;
			}

			requirement 'Transcode On-the-fly' {
				doc /*
				 * The Transcoding Engine shall process video files on-the-fly,
				 * changing resolution or bitrate to match network and client
				 * capabilities when transcoding is required.
				 */
				subject transcodingEngine : TranscodingEngine;
			}

			requirement 'Buffer for Smooth Playback' {
				doc /*
				 * The Adaptive Streaming Buffer shall pre-load content to ensure
				 * smooth playback and prevent stuttering.
				 */
				subject adaptiveStreamingBuffer : AdaptiveStreamingBuffer;
			}

			requirement 'Stream in Packets' {
				doc /*
				 * The Network Streaming Interface shall send media in small
				 * packets to the client device.
				 */
				subject networkStreamingInterface : NetworkStreamingInterface;
			}

			requirement 'Dynamically Adjust Quality' {
				doc /*
				 * The system shall continuously monitor client buffer feedback
				 * and network conditions, lowering quality on slow connections
				 * and increasing quality on improved connections.
				 */
				subject qualityAdaptationController : QualityAdaptationController;
			}
		}

		requirement 'Adaptive Streaming Requirement' : 'Provide Adaptive Streaming';
	}
}
