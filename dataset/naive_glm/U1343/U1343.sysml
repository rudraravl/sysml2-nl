package HuluStreamingPlatform {

    package ValueTypes {
        value type BandwidthValue > Real { unit 'Mbps'; }
        value type LatencyValue > Real { unit 'ms'; }
        value type ResolutionValue > Integer { unit 'pixel'; }
        value type BitrateValue > Real { unit 'Mbps'; }
        value type BufferDurationValue > Real { unit 's'; }
        value type FileSizeValue > Real { unit 'MB'; }
        value type TimestampValue > Real { unit 's'; }
        value type DurationValue > Real { unit 's'; }
        value type DataValue > Real { unit 'MB'; }
        value type ScoreValue > Real { unit '1'; }
    }

    package ItemTypes {
        import ValueTypes::*;

        item def ContentMetadata {
            attribute contentId : String;
            attribute title : String;
            attribute duration : DurationValue;
            attribute availableResolutions : ResolutionValue[1..*];
            attribute isAvailable : Boolean;
        }

        item def VideoSegment {
            attribute segmentId : String;
            attribute contentId : String;
            attribute resolution : ResolutionValue;
            attribute bitrate : BitrateValue;
            attribute size : FileSizeValue;
            attribute data : DataValue;
            attribute sequenceNumber : Integer;
        }

        item def NetworkMetrics {
            attribute bandwidth : BandwidthValue;
            attribute latency : LatencyValue;
            attribute packetLoss : Real;
            attribute timestamp : TimestampValue;
        }

        item def PlaybackCommand {
            attribute command : String;
            attribute contentId : String;
            attribute targetResolution : ResolutionValue;
        }

        item def BitrateCommand {
            attribute targetResolution : ResolutionValue;
            attribute targetBitrate : BitrateValue;
            attribute reason : String;
        }

        item def AnalyticsEvent {
            attribute eventType : String;
            attribute userId : String;
            attribute contentId : String;
            attribute timestamp : TimestampValue;
            attribute watchDuration : DurationValue;
            attribute bufferEvents : Integer;
        }

        item def Recommendation {
            attribute contentId : String;
            attribute score : ScoreValue;
            attribute reason : String;
        }

        item def UserCredentials {
            attribute username : String;
            attribute token : String;
        }
    }

    package Ports {
        import ItemTypes::*;

        port def CatalogRequestPort {
            out attribute contentRequest : String;
            in attribute contentResponse : ContentMetadata;
        }

        port def StreamingControlPort {
            out attribute streamInit : PlaybackCommand;
            in attribute streamStatus : String;
        }

        port def VideoDeliveryPort {
            in attribute videoSegment : VideoSegment;
        }

        port def NetworkMetricsPort {
            out attribute metrics : NetworkMetrics;
        }

        port def BitrateCommandPort {
            out attribute command : BitrateCommand;
        }

        port def AnalyticsPort {
            out attribute events : AnalyticsEvent;
            in attribute recommendations : Recommendation;
        }

        port def UserInteractionPort {
            in attribute searchQuery : String;
            in attribute playbackControl : String;
            out attribute displayContent : ContentMetadata;
        }

        port def CDNRequestPort {
            out attribute segmentRequest : String;
            in attribute segmentDelivery : VideoSegment;
        }
    }

    package Components {
        import ValueTypes::*;
        import ItemTypes::*;
        import Ports::*;

        part def ClientApplication {
            port catalogPort : CatalogRequestPort;
            port streamingPort : StreamingControlPort;
            port videoPort : VideoDeliveryPort;
            port metricsPort : NetworkMetricsPort;
            port analyticsPort : AnalyticsPort;
            port userPort : UserInteractionPort;

            attribute currentContent : ContentMetadata;
            attribute bufferLevel : BufferDurationValue := 0.0;
            attribute currentResolution : ResolutionValue := 1080;
            attribute isAuthenticated : Boolean := false;

            state playbackState {
                entry action { send "playbackState entered"; }
                initial Idle;
                state Authenticating {
                    entry action { perform authenticateUser; }
                }
                state Searching {
                    entry action { perform searchContent; }
                }
                state Initializing {
                    entry action { perform initializeStream; }
                }
                state Buffering {
                    entry action { perform bufferVideo; }
                }
                state Playing {
                    entry action { perform playVideo; }
                }
                state Paused;
                state Stopped;

                transition Idle -> Authenticating
                    on userPort.searchQuery
                    guard userPort.searchQuery == "login";

                transition Authenticating -> Searching
                    when isAuthenticated == true;

                transition Searching -> Initializing
                    on catalogPort.contentResponse
                    guard catalogPort.contentResponse.isAvailable == true;

                transition Searching -> Idle
                    on catalogPort.contentResponse
                    guard catalogPort.contentResponse.isAvailable == false;

                transition Initializing -> Buffering
                    on streamingPort.streamStatus
                    guard streamingPort.streamStatus == "ready";

                transition Buffering -> Playing
                    when bufferLevel >= 5.0;

                transition Playing -> Buffering
                    when bufferLevel < 2.0;

                transition Playing -> Paused
                    on userPort.playbackControl
                    guard userPort.playbackControl == "pause";

                transition Paused -> Playing
                    on userPort.playbackControl
                    guard userPort.playbackControl == "resume";

                transition Playing -> Stopped
                    on userPort.playbackControl
                    guard userPort.playbackControl == "stop";

                transition Paused -> Stopped
                    on userPort.playbackControl
                    guard userPort.playbackControl == "stop";
            }

            action def authenticateUser {
                in credentials : UserCredentials;
                out success : Boolean;
                action verifyToken {
                    in token := credentials.token;
                    out valid := success;
                }
            }

            action def searchContent {
                in query : String;
                out metadata : ContentMetadata;
                action sendCatalogRequest {
                    out request := query;
                }
            }

            action def initializeStream {
                in content : ContentMetadata;
                out command : PlaybackCommand;
                action buildCommand {
                    in target := content;
                    out cmd := command;
                }
            }

            action def bufferVideo {
                in segment : VideoSegment;
                out bufferLevel : BufferDurationValue;
                action accumulateBuffer {
                    in seg := segment;
                    out level := bufferLevel;
                }
            }

            action def playVideo {
                in segment : VideoSegment;
                action renderFrame {
                    in seg := segment;
                }
            }

            action def collectMetrics {
                out metrics : NetworkMetrics;
                action sampleNetwork {
                    out m := metrics;
                }
            }
        }

        part def ContentCatalogService {
            port clientPort : CatalogRequestPort;

            attribute catalog : ContentMetadata[0..*];
            attribute totalTitles : Integer := 0;

            action def verifyContent {
                in contentId : String;
                out metadata : ContentMetadata;
                action lookup {
                    in id := contentId;
                    out result := metadata;
                }
            }

            action def updateCatalog {
                in newContent : ContentMetadata;
                action addTitle {
                    in item := newContent;
                }
            }
        }

        part def StreamingService {
            port clientPort : StreamingControlPort;
            port cdnPort : CDNRequestPort;
            port abrPort : BitrateCommandPort;

            attribute activeSessions : String[0..*];
            attribute sessionResolution : ResolutionValue := 1080;
            attribute sessionBitrate : BitrateValue := 5.0;

            action def manageSession {
                in command : PlaybackCommand;
                out status : String;
                action createSession {
                    in cmd := command;
                    out ready := status;
                }
            }

            action def requestSegment {
                in contentId : String;
                in sequence : Integer;
                out request : String;
                action buildRequest {
                    in cid := contentId;
                    in seq := sequence;
                    out req := request;
                }
            }

            action def applyBitrateCommand {
                in command : BitrateCommand;
                action updateResolution {
                    in cmd := command;
                    ref attribute sessionResolution := command.targetResolution;
                    ref attribute sessionBitrate := command.targetBitrate;
                }
            }
        }

        part def CDN {
            port streamingPort : CDNRequestPort;
            port clientPort : VideoDeliveryPort;

            attribute edgeServers : String[0..*];
            attribute cachedContent : String[0..*];
            attribute region : String;

            action def deliverSegment {
                in request : String;
                out segment : VideoSegment;
                action locateEdge {
                    in req := request;
                    out serverId : String;
                }
                action fetchSegment {
                    in sid : String;
                    in req := request;
                    out seg := segment;
                }
            }

            action def cacheContent {
                in contentId : String;
                action replicateToEdges {
                    in cid := contentId;
                }
            }
        }

        part def AdaptiveBitrateEngine {
            port metricsPort : NetworkMetricsPort;
            port commandPort : BitrateCommandPort;

            attribute currentBandwidth : BandwidthValue := 10.0;
            attribute currentLatency : LatencyValue := 50.0;
            attribute targetResolution : ResolutionValue := 1080;
            attribute targetBitrate : BitrateValue := 5.0;
            attribute highBandwidthThreshold : BandwidthValue := 25.0;
            attribute lowBandwidthThreshold : BandwidthValue := 5.0;
            attribute ultraHdResolution : ResolutionValue := 2160;
            attribute hdResolution : ResolutionValue := 1080;
            attribute sdResolution : ResolutionValue := 480;

            state abrState {
                initial Monitoring;
                state Upgrading {
                    entry action { perform adjustBitrate; }
                }
                state Downgrading {
                    entry action { perform adjustBitrate; }
                }
                state Stable;

                transition Monitoring -> Upgrading
                    when metricsPort.metrics.bandwidth > highBandwidthThreshold
                    guard targetResolution < ultraHdResolution;

                transition Monitoring -> Downgrading
                    when metricsPort.metrics.bandwidth < lowBandwidthThreshold
                    guard targetResolution > sdResolution;

                transition Monitoring -> Stable
                    when metricsPort.metrics.bandwidth >= lowBandwidthThreshold
                    and metricsPort.metrics.bandwidth <= highBandwidthThreshold;

                transition Upgrading -> Monitoring
                    when targetResolution == ultraHdResolution;

                transition Downgrading -> Monitoring
                    when targetResolution == sdResolution;

                transition Stable -> Monitoring
                    when metricsPort.metrics.bandwidth != currentBandwidth;
            }

            action def monitorNetwork {
                in metrics : NetworkMetrics;
                action updateBandwidth {
                    ref attribute currentBandwidth := metrics.bandwidth;
                    ref attribute currentLatency := metrics.latency;
                }
            }

            action def adjustBitrate {
                out command : BitrateCommand;
                action computeTarget {
                    in bandwidth := currentBandwidth;
                    out resolution : ResolutionValue;
                    out bitrate : BitrateValue;
                    if bandwidth > 25.0 {
                        assign resolution := ultraHdResolution;
                        assign bitrate := 15.0;
                    } else if bandwidth > 10.0 {
                        assign resolution := hdResolution;
                        assign bitrate := 5.0;
                    } else {
                        assign resolution := sdResolution;
                        assign bitrate := 1.5;
                    }
                }
                action buildCommand {
                    in res : ResolutionValue;
                    in br : BitrateValue;
                    out cmd := command;
                    assign cmd.targetResolution := res;
                    assign cmd.targetBitrate := br;
                    assign cmd.reason := "adaptive_bitrate_adjustment";
                }
            }
        }

        part def AnalyticsService {
            port clientPort : AnalyticsPort;

            attribute events : AnalyticsEvent[0..*];
            attribute recommendations : Recommendation[0..*];
            attribute userProfiles : String[0..*];

            action def collectEvent {
                in event : AnalyticsEvent;
                action storeEvent {
                    in evt := event;
                    ref attribute events.append(event);
                }
            }

            action def generateRecommendations {
                in userId : String;
                out recs : Recommendation[0..*];
                action analyzeHabits {
                    in uid := userId;
                    out recommendations := recs;
                }
            }

            action def reportSystemPerformance {
                out report : String;
                action aggregateMetrics {
                    out r := report;
                }
            }
        }
    }

    package System {
        import ValueTypes::*;
        import ItemTypes::*;
        import Ports::*;
        import Components::*;

        part def HuluPlatform {
            part clientApp : ClientApplication;
            part catalog : ContentCatalogService;
            part streaming : StreamingService;
            part cdn : CDN;
            part abrEngine : AdaptiveBitrateEngine;
            part analytics : AnalyticsService;

            connect clientApp.catalogPort to catalog.clientPort;
            connect clientApp.streamingPort to streaming.clientPort;
            connect streaming.cdnPort to cdn.streamingPort;
            connect cdn.clientPort to clientApp.videoPort;
            connect clientApp.metricsPort to abrEngine.metricsPort;
            connect abrEngine.commandPort to streaming.abrPort;
            connect clientApp.analyticsPort to analytics.clientPort;

            attribute platformName : String := "Hulu";
            attribute version : String := "2.0";
            attribute maxConcurrentStreams : Integer := 1000000;
        }
    }

    package Requirements {
        import System::*;
        import ValueTypes::*;

        requirement def StreamingQualityRequirement {
            attribute minBandwidth : BandwidthValue := 5.0;
            attribute targetResolution : ResolutionValue := 1080;
            require { clientApp.currentResolution >= 480; }
        }

        requirement def BufferingRequirement {
            attribute maxInitialBufferTime : BufferDurationValue := 5.0;
            require { clientApp.bufferLevel >= 2.0; }
        }

        requirement def CatalogAvailabilityRequirement {
            require { catalog.catalog->size() > 0; }
        }

        requirement def AdaptiveBitrateRequirement {
            attribute highThreshold : BandwidthValue := 25.0;
            attribute lowThreshold : BandwidthValue := 5.0;
            require { abrEngine.targetResolution >= abrEngine.sdResolution; }
            require { abrEngine.targetResolution <= abrEngine.ultraHdResolution; }
        }

        requirement def AnalyticsCollectionRequirement {
            require { analytics.events->size() >= 0; }
        }

        requirement def CDNLatencyRequirement {
            attribute maxLatency : LatencyValue := 100.0;
            require { cdn.region != ""; }
        }

        requirement HuluStreamingRequirements : StreamingQualityRequirement {
            subject platform : HuluPlatform;
            require { platform.clientApp.currentResolution >= 480; }
            require { platform.abrEngine.targetResolution <= 2160; }
        }
    }
}
