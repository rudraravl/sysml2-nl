package 'Hulu Streaming Platform' {
    private import ScalarValues::*;
    private import ISQ::*;

    unit def Mbps;
    unit def kbps;
    unit def ms;

    attribute def BandwidthValue :> Real;
    attribute def BitrateValue :> Real;
    attribute def LatencyValue :> Real;

    item def UserCredentials {
        attribute username : String;
        attribute password : String;
    }
    item def AuthToken {
        attribute token : String;
        attribute expiry : TimeValue[s];
    }
    item def SearchQuery {
        attribute keyword : String;
    }
    item def SearchResult {
        attribute contentId : String;
        attribute title : String;
        attribute available : Boolean;
    }
    item def ContentMetadata {
        attribute contentId : String;
        attribute title : String;
        attribute duration : TimeValue[s];
    }
    item def PlaybackCommand {
        attribute contentId : String;
        attribute requestedResolution : Integer;
        attribute startOffset : TimeValue[s];
    }
    item def VideoSegment {
        attribute segmentId : Integer;
        attribute resolution : Integer;
        attribute bitrate : BitrateValue[kbps];
        attribute payload : String;
    }
    item def NetworkMetrics {
        attribute bandwidth : BandwidthValue[Mbps];
        attribute latency : LatencyValue[ms];
        attribute jitter : LatencyValue[ms];
    }
    item def QualityAdjustment {
        attribute targetResolution : Integer;
        attribute targetBitrate : BitrateValue[kbps];
    }
    item def ViewingEvent {
        attribute userId : String;
        attribute contentId : String;
        attribute watchTime : TimeValue[s];
        attribute qualityLevel : Integer;
    }
    item def Recommendation {
        attribute contentId : String;
        attribute reason : String;
    }

    item def AuthSuccess;
    item def ContentSelected;
    item def StreamReady;
    item def BufferFull;
    item def PlaySignal;
    item def PauseSignal;
    item def StopSignal;
    item def MetricsAvailable;
    item def QualityAdjusted;
    item def DataProcessed;

    port def CatalogPort {
        in item searchQuery : SearchQuery;
        out item searchResult : SearchResult;
        out item contentMetadata : ContentMetadata;
    }
    port def StreamingPort {
        in item contentMetadata : ContentMetadata;
        out item streamReady : StreamReady;
    }
    port def CDNDataPort {
        in item playbackCommand : PlaybackCommand;
        out item videoSegment : VideoSegment;
    }
    port def MetricsPort {
        out item networkMetrics : NetworkMetrics;
    }
    port def QualityPort {
        out item qualityAdjustment : QualityAdjustment;
    }
    port def AnalyticsPort {
        in item viewingEvent : ViewingEvent;
        out item recommendation : Recommendation;
    }

    action def AuthenticateUser {
        in credentials : UserCredentials;
        out token : AuthToken;
    }
    action def SearchContent {
        in query : SearchQuery;
        out result : SearchResult;
    }
    action def RequestStream {
        in metadata : ContentMetadata;
        out ready : StreamReady;
    }
    action def BufferVideo {
        in segment : VideoSegment;
    }
    action def PlayVideo;
    action def SendViewingEvents {
        out event : ViewingEvent;
    }
    action def MonitorNetwork {
        out metrics : NetworkMetrics;
    }
    action def AdjustQuality {
        in metrics : NetworkMetrics;
        out adjustment : QualityAdjustment;
    }
    action def CollectAnalytics {
        in event : ViewingEvent;
    }
    action def GenerateRecommendation {
        in event : ViewingEvent;
        out recommendation : Recommendation;
    }

    state def PlaybackStateMachine {
        entry; then authenticating;
        state authenticating {
            do authenticateUser : AuthenticateUser;
        }
        accept AuthSuccess then searching;
        state searching {
            do searchContent : SearchContent;
        }
        accept ContentSelected then initializing;
        state initializing {
            do requestStream : RequestStream;
        }
        accept StreamReady then buffering;
        state buffering {
            do bufferVideo : BufferVideo;
        }
        accept BufferFull then playing;
        state playing {
            do playVideo : PlayVideo;
            do sendViewingEvents : SendViewingEvents;
        }
        accept PauseSignal then paused;
        accept StopSignal then authenticating;
        state paused;
        accept PlaySignal then playing;
        accept StopSignal then authenticating;
    }

    state def ABRStateMachine {
        entry; then monitoring;
        state monitoring {
            do monitorNetwork : MonitorNetwork;
        }
        accept MetricsAvailable then adjusting;
        state adjusting {
            do adjustQuality : AdjustQuality;
        }
        accept QualityAdjusted then monitoring;
    }

    state def AnalyticsStateMachine {
        entry; then collecting;
        state collecting {
            do collectAnalytics : CollectAnalytics;
        }
        accept DataProcessed then recommending;
        state recommending {
            do generateRecommendation : GenerateRecommendation;
        }
        accept DataProcessed then collecting;
    }

    part def ClientApplication {
        port catalogPort : ~CatalogPort;
        port streamingPort : ~StreamingPort;
        port cdnDataPort : ~CDNDataPort;
        port analyticsPort : ~AnalyticsPort;
        port metricsPort : MetricsPort;
        port qualityPort : ~QualityPort;
        attribute bufferLevel : TimeValue[s];
        exhibit state playbackStates : PlaybackStateMachine;
    }

    part def ContentCatalogService {
        port catalogPort : CatalogPort;
    }

    part def StreamingService {
        port streamingPort : StreamingPort;
    }

    part def ContentDeliveryNetwork {
        port cdnDataPort : CDNDataPort;
    }

    part def AdaptiveBitrateEngine {
        port metricsPort : ~MetricsPort;
        port qualityPort : QualityPort;
        attribute adjustmentTime : TimeValue[s];
        attribute currentResolution : Integer;
        exhibit state abrStates : ABRStateMachine;
    }

    part def AnalyticsService {
        port analyticsPort : AnalyticsPort;
        exhibit state analyticsStates : AnalyticsStateMachine;
    }

    requirement def SeamlessViewingExperience {
        doc /* The platform shall deliver uninterrupted playback by adapting video quality to changing network conditions. */
    }
    requirement def HighQualityStreaming {
        doc /* The platform shall provide at least 1080p resolution when available bandwidth exceeds 5 Mbps. */
    }
    requirement def PersonalizedRecommendations {
        doc /* The platform shall generate personalized recommendations based on viewing history and system performance data. */
    }
    requirement def LowLatencyDelivery {
        doc /* The CDN shall deliver video segments with latency less than 50 ms to ensure fast load times. */
    }

    part def HuluSystem {
        part clientApp : ClientApplication;
        part catalogService : ContentCatalogService;
        part streamingService : StreamingService;
        part cdn : ContentDeliveryNetwork;
        part abe : AdaptiveBitrateEngine;
        part analyticsService : AnalyticsService;
        connect clientApp.catalogPort to catalogService.catalogPort;
        connect clientApp.streamingPort to streamingService.streamingPort;
        connect clientApp.cdnDataPort to cdn.cdnDataPort;
        connect clientApp.analyticsPort to analyticsService.analyticsPort;
        connect clientApp.metricsPort to abe.metricsPort;
        connect abe.qualityPort to clientApp.qualityPort;
        satisfy SeamlessViewingExperience by abe;
        satisfy HighQualityStreaming by abe;
        satisfy PersonalizedRecommendations by analyticsService;
        satisfy LowLatencyDelivery by cdn;
    }

    part huluPlatform : HuluSystem;
}
