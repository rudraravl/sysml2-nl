package PlexMediaStreamingSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BitrateValue :> ISQ::PowerValue;
	attribute def ResolutionValue :> String;
	attribute def BufferCapacityValue :> ISQ::MassValue;
	attribute def LatencyValue :> ISQ::TimeValue;
	attribute def QualityLevel :> String;
	
	item def MediaAsset {
		attribute title : String;
		attribute duration : ISQ::DurationValue;
		attribute originalBitrate : BitrateValue;
		attribute resolution : ResolutionValue;
		attribute codec : String;
		attribute fileSize : ISQ::MassValue;
	}
	
	item def PlaybackRequest {
		attribute assetId : String;
		attribute requestedQuality : QualityLevel;
		attribute clientCapability : ResolutionValue;
		attribute availableBandwidth : BitrateValue;
	}
	
	item def StreamPacket {
		attribute sequenceNumber : Integer;
		attribute bitrate : BitrateValue;
		attribute quality : QualityLevel;
		attribute dataSize : ISQ::MassValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def TranscodeJob {
		attribute sourceAsset : MediaAsset;
		attribute targetBitrate : BitrateValue;
		attribute targetResolution : ResolutionValue;
		attribute priority : Integer;
	}
	
	item def BufferStatus {
		attribute currentLevel : BufferCapacityValue;
		attribute fillRate : BitrateValue;
		attribute drainRate : BitrateValue;
		attribute healthStatus : String;
	}
	
	port def MediaRequestPort {
		in item playbackRequest : PlaybackRequest;
		out item acknowledgment : String;
	}
	
	port def StreamDeliveryPort {
		out item streamPacket : StreamPacket;
		in item clientFeedback : BufferStatus;
	}
	
	port def LibraryAccessPort {
		in item assetQuery : String;
		out item assetData : MediaAsset;
	}
	
	port def TranscodeControlPort {
		in item transcodeRequest : TranscodeJob;
		out item transcodedAsset : MediaAsset;
	}
	
	port def NetworkInterfacePort {
		in item incomingData : StreamPacket;
		out item outgoingData : StreamPacket;
		attribute bandwidth : BitrateValue;
	}
	
	part def MediaLibraryDatabase {
		port libraryInterface : ~LibraryAccessPort;
		attribute totalAssets : Integer;
		attribute totalStorageUsed : ISQ::MassValue;
		
		action def SearchAndRetrieve {
			in queryId : String;
			out foundAsset : MediaAsset;
		}
		
		action def IndexContent {
			in newAsset : MediaAsset;
			out indexed : Boolean;
		}
	}
	
	part def TranscodingEngine {
		port transcodeInterface : ~TranscodeControlPort;
		attribute maxConcurrentJobs : Integer;
		attribute currentLoad : Real;
		
		action def PerformTranscode {
			in job : TranscodeJob;
			out optimizedAsset : MediaAsset;
			
			first start;
			then action analyzeSource {
				in source : MediaAsset = job.sourceAsset;
				out sourceMetrics : Real;
			}
			then action selectCodec {
				in targetBitrate : BitrateValue = job.targetBitrate;
				out selectedCodec : String;
			}
			then action encodeVideo {
				in codec : String = selectCodec.selectedCodec;
				in targetRes : ResolutionValue = job.targetResolution;
				out encodedData : MediaAsset;
			}
			then assign optimizedAsset := encodeVideo.encodedData;
			then done;
		}
	}
	
	part def AdaptiveStreamingBuffer {
		attribute bufferCapacity : BufferCapacityValue;
		attribute currentBufferLevel : BufferCapacityValue;
		attribute minimumThreshold : BufferCapacityValue;
		attribute maximumThreshold : BufferCapacityValue;
		
		action def ManageBuffering {
			in incomingStream : StreamPacket;
			in consumptionRate : BitrateValue;
			out bufferHealth : BufferStatus;
			out shouldAdjustQuality : Boolean;
			
			first start;
			then action updateBuffer {
				in packet : StreamPacket = incomingStream;
				out newLevel : BufferCapacityValue;
			}
			then action evaluateHealth {
				in level : BufferCapacityValue = updateBuffer.newLevel;
				in threshold : BufferCapacityValue = minimumThreshold;
				out healthy : Boolean;
			}
			then decide;
				if evaluateHealth.healthy then maintainQuality;
				if not evaluateHealth.healthy then requestQualityAdjustment;
			action maintainQuality {
				out adjust : Boolean = false;
			}
			then done;
			action requestQualityAdjustment {
				out adjust : Boolean = true;
			}
			then done;
		}
	}
	
	part def SessionManager {
		port sessionControl : MediaRequestPort;
		attribute activeSessions : Integer;
		attribute maxSessions : Integer;
		
		action def InitiateSession {
			in request : PlaybackRequest;
			out sessionId : String;
			out approved : Boolean;
		}
		
		action def TerminateSession {
			in sessionId : String;
			out terminated : Boolean;
		}
	}
	
	part def QualityAdaptationController {
		attribute currentQuality : QualityLevel;
		attribute targetQuality : QualityLevel;
		
		action def AdaptQuality {
			in bufferStatus : BufferStatus;
			in networkBandwidth : BitrateValue;
			in clientCapability : ResolutionValue;
			out adjustedQuality : QualityLevel;
			out adjustedBitrate : BitrateValue;
			
			first start;
			then action assessBandwidth {
				in bandwidth : BitrateValue = networkBandwidth;
				in buffer : BufferStatus = bufferStatus;
				out availableCapacity : BitrateValue;
			}
			then action selectOptimalQuality {
				in capacity : BitrateValue = assessBandwidth.availableCapacity;
				in clientCap : ResolutionValue = clientCapability;
				out quality : QualityLevel;
				out bitrate : BitrateValue;
			}
			then assign adjustedQuality := selectOptimalQuality.quality;
			then assign adjustedBitrate := selectOptimalQuality.bitrate;
			then done;
		}
	}
	
	part def NetworkStreamingInterface {
		port networkPort : NetworkInterfacePort;
		attribute connectionStatus : String;
		attribute packetLossRate : Real;
		
		action def TransmitStream {
			in packet : StreamPacket;
			out transmitted : Boolean;
		}
		
		action def MonitorConnection {
			out bandwidth : BitrateValue;
			out latency : LatencyValue;
			out stability : Real;
		}
	}
	
	action def StreamingWorkflow {
		doc /* 
		Primary streaming workflow that coordinates all server components to deliver 
		adaptive media content from request to playback completion.
		*/
		
		first start;
		
		then action receiveClientRequest {
			in clientRequest : PlaybackRequest;
			out assetId : String;
			out requestedQuality : QualityLevel;
			out clientBandwidth : BitrateValue;
			out clientCapability : ResolutionValue;
		}
		
		then action authenticateAndAuthorize {
			in request : PlaybackRequest = receiveClientRequest.clientRequest;
			out authorized : Boolean;
			out sessionId : String;
		}
		
		then decide;
			if authenticateAndAuthorize.authorized then retrieveMediaAsset;
			if not authenticateAndAuthorize.authorized then rejectRequest;
		
		action rejectRequest;
		then done;
		
		action retrieveMediaAsset {
			in assetId : String = receiveClientRequest.assetId;
			out originalAsset : MediaAsset;
		}
		
		then action evaluateTranscodingNeed {
			in asset : MediaAsset = retrieveMediaAsset.originalAsset;
			in clientBandwidth : BitrateValue = receiveClientRequest.clientBandwidth;
			in clientCapability : ResolutionValue = receiveClientRequest.clientCapability;
			out needsTranscode : Boolean;
			out targetBitrate : BitrateValue;
			out targetResolution : ResolutionValue;
		}
		
		then decide;
			if evaluateTranscodingNeed.needsTranscode then transcodeMedia;
			if not evaluateTranscodingNeed.needsTranscode then directStream;
		
		action transcodeMedia {
			in sourceAsset : MediaAsset = retrieveMediaAsset.originalAsset;
			in targetBitrate : BitrateValue = evaluateTranscodingNeed.targetBitrate;
			in targetResolution : ResolutionValue = evaluateTranscodingNeed.targetResolution;
			out transcodedAsset : MediaAsset;
		}
		then prepareStream;
		
		action directStream {
			in asset : MediaAsset = retrieveMediaAsset.originalAsset;
			out streamAsset : MediaAsset;
		}
		then prepareStream;
		
		action prepareStream {
			in mediaAsset : MediaAsset;
			out streamPackets : StreamPacket[1..*];
		}
		
		then merge streamingLoop;
		
		then action monitorBuffer {
			out bufferStatus : BufferStatus;
			out adjustmentNeeded : Boolean;
		}
		
		then decide;
			if monitorBuffer.adjustmentNeeded then adaptStreamQuality;
			if not monitorBuffer.adjustmentNeeded then transmitPacket;
		
		action adaptStreamQuality {
			in currentBuffer : BufferStatus = monitorBuffer.bufferStatus;
			in networkBandwidth : BitrateValue = receiveClientRequest.clientBandwidth;
			out newQuality : QualityLevel;
			out newBitrate : BitrateValue;
		}
		then transmitPacket;
		
		action transmitPacket {
			in packet : StreamPacket;
			out transmitted : Boolean;
		}
		
		then action checkStreamCompletion {
			out complete : Boolean;
		}
		
		then decide;
			if not checkStreamCompletion.complete then streamingLoop;
			if checkStreamCompletion.complete then finalizeSession;
		
		action finalizeSession {
			in sessionId : String = authenticateAndAuthorize.sessionId;
			out finalized : Boolean;
		}
		
		then done;
	}
	
	part def PlexMediaServer {
		doc /* 
		The Plex Media Server is a comprehensive media streaming platform that organizes, 
		transcodes, and delivers digital media content to client devices across a network.
		Its primary function is to provide adaptive, high-quality media streaming by 
		intelligently managing content retrieval, real-time transcoding, quality adaptation, 
		and buffering to ensure optimal playback experience regardless of network conditions 
		or client device capabilities.
		*/
		
		port clientRequestPort : ~MediaRequestPort;
		port streamOutputPort : ~StreamDeliveryPort;
		
		part mediaLibrary : MediaLibraryDatabase {
			port :>> libraryInterface;
			attribute :>> totalAssets = 5000;
			attribute :>> totalStorageUsed = 10000.0 [kg];
		}
		
		part transcodingEngine : TranscodingEngine {
			port :>> transcodeInterface;
			attribute :>> maxConcurrentJobs = 8;
		}
		
		part streamBuffer : AdaptiveStreamingBuffer {
			attribute :>> bufferCapacity = 256.0 [kg];
			attribute :>> minimumThreshold = 64.0 [kg];
			attribute :>> maximumThreshold = 224.0 [kg];
		}
		
		part sessionManager : SessionManager {
			port :>> sessionControl;
			attribute :>> maxSessions = 50;
		}
		
		part qualityController : QualityAdaptationController;
		
		part networkInterface : NetworkStreamingInterface {
			port :>> networkPort;
		}
		
		connection libraryToTranscoder 
			connect mediaLibrary.libraryInterface to transcodingEngine.transcodeInterface;
		
		connection sessionToClient
			connect sessionManager.sessionControl to clientRequestPort;
		
		connection streamToNetwork
			connect streamOutputPort to networkInterface.networkPort;
		
		perform action orchestrateStreaming[*] ordered : StreamingWorkflow;
	}
	
	state def PlexServerStateMachine {
		doc /* State machine governing the operational states of the Plex Media Server. */
		
		entry; then idle;
		
		state idle {
			doc /* Server is running but not actively streaming. */
		}
		transition sessionInitiationTransition
			first idle
			accept clientRequestReceived
			then sessionInitiation;
		
		state sessionInitiation {
			entry action validateRequest;
			doc /* Validating client request and establishing session. */
		}
		transition sessionAuthorizedTransition
			first sessionInitiation
			accept sessionAuthorized
			then contentRetrieval;
		transition sessionRejectedTransition
			first sessionInitiation
			accept sessionRejected
			then idle;
		
		state contentRetrieval {
			entry action fetchMediaAsset;
			doc /* Retrieving requested media from library. */
		}
		transition toQualityAssessment
			first contentRetrieval
			then qualityAssessment;
		
		state qualityAssessment {
			entry action evaluateClientCapabilities;
			doc /* Determining optimal streaming quality and transcoding requirements. */
		}
		transition toTranscoding
			first qualityAssessment
			accept transcodingRequired
			then transcoding;
		transition toBufferingDirect
			first qualityAssessment
			accept directStreamingPossible
			then buffering;
		
		state transcoding {
			entry action initiateTranscode;
			do action monitorTranscodeProgress;
			doc /* Real-time transcoding of media to match client requirements. */
		}
		transition transcodingToBuffering
			first transcoding
			then buffering;
		
		state buffering {
			entry action initializeBuffer;
			do action fillBuffer;
			doc /* Buffering stream data before transmission. */
		}
		transition bufferingToStreaming
			first buffering
			accept bufferThresholdReached
			then activeStreaming;
		
		state activeStreaming {
			entry action startTransmission;
			do action continuousStreamMonitoring;
			doc /* Actively streaming media to client with continuous monitoring. */
		}
		transition streamingContinues
			first activeStreaming
			accept bufferHealthyAndStreamingContinues
			then activeStreaming;
		transition streamingToQualityAdjustment
			first activeStreaming
			accept bufferDepletedOrBandwidthChanged
			then qualityAdjustment;
		transition streamingToComplete
			first activeStreaming
			accept streamFinished
			then sessionComplete;
		transition streamingToError
			first activeStreaming
			accept networkErrorOrClientDisconnect
			then errorHandling;
		
		state qualityAdjustment {
			entry action recalculateQuality;
			doc /* Dynamically adjusting stream quality based on conditions. */
		}
		transition adjustmentToTranscoding
			first qualityAdjustment
			accept newTranscodingNeeded
			then transcoding;
		transition adjustmentToBuffering
			first qualityAdjustment
			accept qualityAdjustedWithoutTranscoding
			then buffering;
		
		state errorHandling {
			entry action logError;
			do action attemptRecovery;
			doc /* Handling streaming errors and attempting recovery. */
		}
		transition errorToBuffering
			first errorHandling
			accept recoverySuccessful
			then buffering;
		transition errorToComplete
			first errorHandling
			accept recoveryFailed
			then sessionComplete;
		
		state sessionComplete {
			entry action cleanupSession;
			doc /* Finalizing and cleaning up completed streaming session. */
		}
		transition completeToIdle
			first sessionComplete
			then idle;
	}
	
	part plexServerInstance : PlexMediaServer {
		part :>> mediaLibrary {
			attribute :>> totalAssets = 8500;
			attribute :>> totalStorageUsed = 15000.0 [kg];
		}
		
		part :>> transcodingEngine {
			attribute :>> maxConcurrentJobs = 12;
			attribute :>> currentLoad = 0.35;
		}
		
		part :>> streamBuffer {
			attribute :>> bufferCapacity = 512.0 [kg];
			attribute :>> currentBufferLevel = 128.0 [kg];
			attribute :>> minimumThreshold = 96.0 [kg];
			attribute :>> maximumThreshold = 448.0 [kg];
		}
		
		part :>> sessionManager {
			attribute :>> maxSessions = 100;
			attribute :>> activeSessions = 23;
		}
		
		part :>> networkInterface {
			attribute :>> connectionStatus = "active";
			attribute :>> packetLossRate = 0.002;
		}
		
		exhibit state serverBehavior : PlexServerStateMachine;
	}
	
	requirement def PrimaryStreamingRequirement {
		doc /* 
		The Plex Media Server shall deliver media content to client devices by 
		retrieving assets from the library, performing adaptive transcoding when necessary, 
		managing streaming buffers, and dynamically adjusting quality based on network 
		conditions and client capabilities to ensure continuous, high-quality playback.
		*/
		
		subject server : PlexMediaServer;
		
		require constraint contentDelivery {
			doc /* Server shall successfully deliver requested media content to authorized clients. */
		}
		
		require constraint adaptiveQuality {
			doc /* Server shall adapt streaming quality within 3 seconds of detecting bandwidth changes. */
		}
		
		require constraint bufferManagement {
			doc /* Server shall maintain buffer level above minimum threshold during active streaming. */
		}
	}
	
	requirement def TranscodingPerformanceRequirement {
		doc /* 
		The transcoding engine shall convert media formats in real-time to match 
		client device capabilities and network bandwidth constraints.
		*/
		
		subject engine : TranscodingEngine;
		
		require constraint transcodingLatency {
			doc /* Transcoding initiation latency shall not exceed 2 seconds for standard definition content. */
		}
		
		require constraint codecSupport {
			doc /* Engine shall support H.264, H.265, VP9, and AV1 video codecs with AAC and Opus audio. */
		}
		
		require constraint concurrentJobs {
			doc /* Engine shall handle at least 8 concurrent transcoding jobs without degradation. */
		}
	}
	
	requirement def BufferingRequirement {
		doc /* 
		The adaptive streaming buffer shall maintain sufficient buffered content 
		to prevent playback interruptions during normal network fluctuations.
		*/
		
		subject buffer : AdaptiveStreamingBuffer;
		
		require constraint minimumBufferDepth {
			doc /* Buffer shall maintain minimum 30 seconds of playback content during active streaming. */
		}
		
		require constraint bufferRecovery {
			doc /* Buffer shall recover to healthy state within 10 seconds after depletion event. */
		}
	}
	
	requirement def NetworkPerformanceRequirement {
		doc /* 
		The network streaming interface shall maintain reliable connections and 
		monitor network conditions to support quality adaptation decisions.
		*/
		
		subject network : NetworkStreamingInterface;
		
		require constraint packetLoss {
			doc /* Packet loss rate shall remain below 1% during normal operation. */
		}
		
		require constraint latencyMonitoring {
			doc /* Network latency shall be monitored continuously with 100ms sampling interval. */
		}
	}
	
	requirement <'PLEX-SYS-001'> systemRequirement : PrimaryStreamingRequirement {
		subject plexServerInstance;
		
		assume constraint networkConnectivity {
			doc /* Network infrastructure provides minimum 10 Mbps sustained bandwidth. */
		}
		
		assume constraint storageAvailability {
			doc /* Media library storage is accessible with read latency under 50ms. */
		}
		
		require contentDelivery;
		require adaptiveQuality;
		require bufferManagement;
	}
	
	requirement <'PLEX-TRANS-001'> transcodingRequirement : TranscodingPerformanceRequirement {
		subject plexServerInstance.transcodingEngine;
		
		require transcodingLatency;
		require codecSupport;
		require concurrentJobs;
	}
	
	requirement <'PLEX-BUF-001'> bufferRequirement : BufferingRequirement {
		subject plexServerInstance.streamBuffer;
		
		require minimumBufferDepth;
		require bufferRecovery;
	}
	
	requirement <'PLEX-NET-001'> networkRequirement : NetworkPerformanceRequirement {
		subject plexServerInstance.networkInterface;
		
		require packetLoss;
		require latencyMonitoring;
	}
}
