package 'Hulu Streaming System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def UserID :> String;
    attribute def ContentID :> String;
    attribute def SessionID :> String;
    
    attribute def VideoQualityLevel {
        attribute level : String;
    }
    
    attribute def BitrateUnit;
    
    value def BitrateValue :> ISQ::PowerValue {
        attribute :>> num : Real;
    }
    
    value def ResolutionValue {
        attribute width : Integer;
        attribute height : Integer;
    }
    
    item def UserRequest {
        attribute userID : UserID;
        attribute contentID : ContentID;
        attribute requestedQuality : VideoQualityLevel;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def VideoSegment {
        attribute segmentID : Integer;
        attribute contentID : ContentID;
        attribute quality : VideoQualityLevel;
        attribute bitrate : BitrateValue;
        attribute duration : ISQ::DurationValue;
        attribute resolution : ResolutionValue;
    }
    
    item def StreamSession {
        attribute sessionID : SessionID;
        attribute userID : UserID;
        attribute contentID : ContentID;
        attribute startTime : ISQ::TimeValue;
        attribute currentPosition : ISQ::DurationValue;
        attribute bufferLevel : ISQ::DurationValue;
    }
    
    item def NetworkMetrics {
        attribute bandwidth : BitrateValue;
        attribute latency : ISQ::DurationValue;
        attribute packetLoss : Real;
    }
    
    port def UserInterfacePort {
        in item userRequest : UserRequest;
        out item sessionStatus : StreamSession;
        out item videoSegment : VideoSegment;
    }
    
    port def ContentCatalogPort {
        in item contentQuery : ContentID;
        out item contentMetadata : String;
        out item contentAvailable : Boolean;
    }
    
    port def StreamingPort {
        in item segmentRequest : ContentID;
        in item qualityLevel : VideoQualityLevel;
        out item videoSegment : VideoSegment;
    }
    
    port def CDNPort {
        in item contentRequest : ContentID;
        in item quality : VideoQualityLevel;
        out item deliveredSegment : VideoSegment;
    }
    
    port def NetworkMonitorPort {
        out item metrics : NetworkMetrics;
    }
    
    action def AuthenticateUser {
        in userID : UserID;
        out authenticated : Boolean;
        out sessionID : SessionID;
    }
    
    action def SearchContent {
        in contentID : ContentID;
        out found : Boolean;
        out metadata : String;
    }
    
    action def SelectQuality {
        in bandwidth : BitrateValue;
        in bufferLevel : ISQ::DurationValue;
        in requestedQuality : VideoQualityLevel;
        out selectedQuality : VideoQualityLevel;
    }
    
    action def FetchSegment {
        in contentID : ContentID;
        in quality : VideoQualityLevel;
        in segmentIndex : Integer;
        out segment : VideoSegment;
    }
    
    action def BufferSegment {
        in segment : VideoSegment;
        in currentBuffer : ISQ::DurationValue;
        out newBuffer : ISQ::DurationValue;
    }
    
    action def RenderVideo {
        in segment : VideoSegment;
        out rendered : Boolean;
    }
    
    action def MonitorNetwork {
        out bandwidth : BitrateValue;
        out latency : ISQ::DurationValue;
    }
    
    action def AdaptBitrate {
        in currentQuality : VideoQualityLevel;
        in bandwidth : BitrateValue;
        in bufferLevel : ISQ::DurationValue;
        out newQuality : VideoQualityLevel;
    }
    
    part def ClientApplication {
        port uiPort : UserInterfacePort;
        port streamPort : StreamingPort;
        port monitorPort : NetworkMonitorPort;
        
        attribute currentSession : StreamSession;
        attribute playbackBuffer : ISQ::DurationValue;
        attribute activeQuality : VideoQualityLevel;
        
        state playbackStateMachine {
            entry; then idle;
            
            state idle;
            transition idle_to_authenticating
                first idle
                accept request : UserRequest
                then authenticating;
            
            state authenticating;
            transition authenticating_to_searching
                first authenticating
                then searching;
            
            transition authenticating_to_error
                first authenticating
                then errorState;
            
            state searching;
            transition searching_to_initializing
                first searching
                then initializing;
            
            transition searching_to_error
                first searching
                then errorState;
            
            state initializing;
            transition initializing_to_buffering
                first initializing
                then buffering;
            
            state buffering;
            transition buffering_to_playing
                first buffering
                then playing;
            
            state playing;
            transition playing_to_buffering
                first playing
                then buffering;
            
            transition playing_to_paused
                first playing
                accept pauseCommand
                then paused;
            
            state paused;
            transition paused_to_playing
                first paused
                accept resumeCommand
                then playing;
            
            transition paused_to_stopped
                first paused
                accept stopCommand
                then stopped;
            
            transition playing_to_stopped
                first playing
                accept stopCommand
                then stopped;
            
            state stopped;
            transition stopped_to_idle
                first stopped
                then idle;
            
            state errorState;
            transition error_to_idle
                first errorState
                accept retryCommand
                then idle;
        }
    }
    
    part def ContentCatalogService {
        port catalogPort : ContentCatalogPort;
        
        attribute contentLibrary : ContentID[*];
        
        perform action searchCatalog : SearchContent;
    }
    
    part def StreamingService {
        port streamPort : StreamingPort;
        port cdnPort : CDNPort;
        
        attribute activeStreams : StreamSession[*];
        
        perform action manageStream {
            action receiveRequest {
                in segmentRequest : ContentID;
                in qualityLevel : VideoQualityLevel;
            }
            then action routeToCDN {
                out cdnRequest : ContentID;
            }
            then action deliverSegment {
                in segment : VideoSegment;
                out delivered : Boolean;
            }
        }
    }
    
    part def ContentDeliveryNetwork {
        port cdnPort : CDNPort;
        
        attribute edgeServers : String[*];
        attribute cachedContent : ContentID[*];
        
        perform action deliverContent : FetchSegment;
    }
    
    part def AdaptiveBitrateEngine {
        port monitorPort : NetworkMonitorPort;
        
        attribute qualityLadder : VideoQualityLevel[*];
        attribute bitrateThresholds : BitrateValue[*];
        
        perform action optimizeQuality : AdaptBitrate;
    }
    
    part def AnalyticsService {
        attribute viewingMetrics : StreamSession[*];
        attribute performanceData : NetworkMetrics[*];
        
        action def CollectMetrics {
            in session : StreamSession;
            in metrics : NetworkMetrics;
        }
        
        action def GenerateRecommendations {
            in userID : UserID;
            out recommendations : ContentID[*];
        }
    }
    
    part def HuluStreamingPlatform;
    
    part huluPlatform : HuluStreamingPlatform {
        part client : ClientApplication {
            port :>> uiPort;
            port :>> streamPort;
            port :>> monitorPort;
        }
        
        part catalog : ContentCatalogService {
            port :>> catalogPort;
        }
        
        part streamingService : StreamingService {
            port :>> streamPort;
            port :>> cdnPort;
        }
        
        part cdn : ContentDeliveryNetwork {
            port :>> cdnPort;
        }
        
        part abrEngine : AdaptiveBitrateEngine {
            port :>> monitorPort;
        }
        
        part analytics : AnalyticsService;
        
        connection clientToStreaming connect client.streamPort to streamingService.streamPort;
        connection streamingToCDN connect streamingService.cdnPort to cdn.cdnPort;
        connection clientToMonitor connect client.monitorPort to abrEngine.monitorPort;
        
        perform action deliverOnDemandContent : DeliverOnDemandContent;
    }
    
    action def DeliverOnDemandContent {
        in userRequest : UserRequest;
        out streamDelivered : VideoSegment[*] := ( );
        
        private attribute sessionActive : Boolean := false;
        private attribute currentQuality : VideoQualityLevel;
        private attribute segmentIndex : Integer := 1;
        private attribute bufferLevel : ISQ::DurationValue;
        
        first start;
        then action authenticate : AuthenticateUser {
            in userID = userRequest.userID;
            out authenticated : Boolean;
            out sessionID : SessionID;
        }
        then decide;
            if authenticate.authenticated then searchContent;
            if not authenticate.authenticated then terminateUnauthorized;
        
        action searchContent : SearchContent {
            in contentID = userRequest.contentID;
            out found : Boolean;
        }
        then decide;
            if searchContent.found then initializeStream;
            if not searchContent.found then terminateNotFound;
        
        action initializeStream {
            action selectInitial : SelectQuality {
                in bandwidth : BitrateValue;
                in bufferLevel : ISQ::DurationValue;
                in requestedQuality = userRequest.requestedQuality;
                out selectedQuality : VideoQualityLevel;
            }
            then assign currentQuality := selectInitial.selectedQuality;
            then assign sessionActive := true;
        }
        then merge streamingLoop;
        
        loop action streamingLoop {
            action monitorConditions : MonitorNetwork {
                out bandwidth : BitrateValue;
                out latency : ISQ::DurationValue;
            }
            then action adaptQuality : AdaptBitrate {
                in currentQuality;
                in bandwidth = monitorConditions.bandwidth;
                in bufferLevel;
                out newQuality : VideoQualityLevel;
            }
            then assign currentQuality := adaptQuality.newQuality;
            then action fetchSegment : FetchSegment {
                in contentID = userRequest.contentID;
                in quality = currentQuality;
                in segmentIndex;
                out segment : VideoSegment;
            }
            then action updateBuffer : BufferSegment {
                in segment = fetchSegment.segment;
                in currentBuffer = bufferLevel;
                out newBuffer : ISQ::DurationValue;
            }
            then assign bufferLevel := updateBuffer.newBuffer;
            then assign streamDelivered := streamDelivered->including(fetchSegment.segment);
            then assign segmentIndex := segmentIndex + 1;
            then decide;
                if sessionActive then streamingLoop;
                if not sessionActive then finalizeStream;
        }
        
        action finalizeStream;
        then done;
        
        action terminateUnauthorized;
        then done;
        
        action terminateNotFound;
        then done;
    }
    
    requirement def StreamingFunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def QualityRequirement;
    requirement def ReliabilityRequirement;
    
    requirement <'HULU-REQ-001'> primaryStreamingFunction : StreamingFunctionalRequirement {
        doc /* The Hulu streaming system shall deliver on-demand video content to authenticated users 
                across multiple devices with adaptive quality based on network conditions. */
        
        subject huluPlatform;
        
        assume requirement userAuthentication {
            doc /* Users shall be authenticated before accessing content. */
        }
        
        assume requirement contentAvailability {
            doc /* Requested content shall be available in the content catalog. */
        }
        
        require requirement adaptiveStreaming : QualityRequirement {
            doc /* The system shall automatically adjust video quality based on available bandwidth 
                    to maintain continuous playback without buffering interruptions. */
        }
        
        require requirement lowLatencyStartup : PerformanceRequirement {
            doc /* Video playback shall begin within 3 seconds of user request under normal network conditions. */
        }
        
        require requirement bufferManagement : PerformanceRequirement {
            doc /* The system shall maintain a playback buffer of at least 3 seconds before initiating playback 
                    and shall not allow buffer to drop below 1 second during active streaming. */
        }
        
        require requirement highAvailability : ReliabilityRequirement {
            doc /* The streaming platform shall maintain 99.9% uptime availability over a rolling 30-day period. */
        }
    }
    
    requirement <'HULU-REQ-002'> qualityAdaptation : QualityRequirement {
        doc /* The adaptive bitrate engine shall select optimal video quality to maximize viewer experience 
                while preventing rebuffering events. */
        
        require constraint bitrateSelection {
            doc /* Selected bitrate shall not exceed 85% of measured available bandwidth. */
        }
        
        require constraint smoothTransitions {
            doc /* Quality level transitions shall occur without playback interruption or frame drops. */
        }
    }
    
    requirement <'HULU-REQ-003'> contentDelivery : PerformanceRequirement {
        doc /* The content delivery network shall efficiently distribute video segments from geographically 
                optimized edge servers to minimize latency. */
        
        require constraint edgeLatency {
            doc /* Network latency from CDN edge server to client shall not exceed 50 milliseconds. */
        }
        
        require constraint cacheEfficiency {
            doc /* Popular content shall be cached at edge servers with a cache hit rate of at least 90%. */
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Hulu Streaming System'::*;

    action orchestrator {
        attribute testContentID : ContentID = "";
        action searchContentProbe : SearchContent {
            in contentID = testContentID;
        }
        first searchContentProbe;
    }
}
