package InteractiveDataVisualizationSystem {
    private import ScalarValues::*;

    unit fps;
    unit ms;
    unit B;

    attribute def FramesPerSecond :> Real { unit fps; }
    attribute def Milliseconds :> Real { unit ms; }
    attribute def Bytes :> Real { unit B; }
    attribute def Confidence :> Real;

    item def RawData {
        attribute size : Bytes;
        attribute source : String;
        attribute payload : String;
    }
    item def CleanedData {
        attribute recordCount : Integer;
        attribute size : Bytes;
        attribute quality : Real;
    }
    item def RenderedFrame {
        attribute frameId : Integer;
        attribute frameRate : FramesPerSecond;
        attribute layout : String;
    }
    item def UserInteraction {
        attribute interactionType : String;
        attribute parameters : String;
    }
    item def ControlCommand {
        attribute target : String;
        attribute commandType : String;
        attribute params : String;
    }
    item def Insight {
        attribute insightType : String;
        attribute description : String;
        attribute confidence : Confidence;
    }

    port def RawDataInPort { in raw : RawData; }
    port def CleanedDataOutPort { out cleaned : CleanedData; }
    port def CleanedDataInPort { in cleaned : CleanedData; }
    port def RenderOutPort { out renderedFrame : RenderedFrame; }
    port def InteractionInPort { in interaction : UserInteraction; }
    port def ControlOutPort { out command : ControlCommand; }
    port def ControlInPort { in command : ControlCommand; }
    port def InsightOutPort { out insight : Insight; }
    port def InsightInPort { in insight : Insight; }

    part def DataProcessor {
        port rawIn : RawDataInPort;
        port cleanedOut : CleanedDataOutPort;
        exhibit state dataProcessorBehavior {
            entry; then idle;
            state idle;
            transition onRawData
                first idle
                accept raw : RawData via rawIn
                do action {
                    first start;
                    then action validate { }
                    then action clean { }
                    then action aggregate { }
                    then send new CleanedData(1, 1000.0, 1.0) via cleanedOut;
                }
                then idle;
        }
    }

    part def CacheManager {
        port cleanedIn : CleanedDataInPort;
        port cleanedOut : CleanedDataOutPort;
        attribute maxCacheSize : Bytes = 1000000000.0;
        exhibit state cacheLifecycle {
            entry; then idle;
            state idle;
            transition cacheData
                first idle
                accept data : CleanedData via cleanedIn
                do send new CleanedData(1, 1000.0, 1.0) via cleanedOut
                then idle;
        }
    }

    part def AnalyticsEngine {
        port cleanedIn : CleanedDataInPort;
        port insightOut : InsightOutPort;
        attribute minConfidence : Confidence = 0.8;
        exhibit state analyticsLifecycle {
            entry; then idle;
            state idle;
            transition analyze
                first idle
                accept data : CleanedData via cleanedIn
                do action {
                    first start;
                    then action detectPatterns { }
                    then action detectTrends { }
                    then action detectAnomalies { }
                    then send new Insight("pattern", "Detected significant pattern in data", 0.85) via insightOut;
                }
                then idle;
        }
    }

    part def RenderingEngine {
        port cleanedIn : CleanedDataInPort;
        port controlIn : ControlInPort;
        port insightIn : InsightInPort;
        port renderOut : RenderOutPort;
        attribute targetFrameRate : FramesPerSecond = 60.0;
        attribute currentFrameId : Integer = 0;
        exhibit state renderingLifecycle {
            entry; then preparing;
            state preparing;
            transition startRender
                first preparing
                accept data : CleanedData via cleanedIn
                then rendering;
            state rendering {
                entry send new RenderedFrame(currentFrameId + 1, targetFrameRate, "default") via renderOut;
            }
            transition optimize
                first rendering
                if true
                then optimizing;
            state optimizing;
            transition onCommand
                first optimizing
                accept cmd : ControlCommand via controlIn
                then preparing;
            transition onInsight
                first optimizing
                accept insight : Insight via insightIn
                then rendering;
        }
    }

    part def InteractionManager {
        port interactionIn : InteractionInPort;
        port controlOut : ControlOutPort;
        exhibit state listening {
            entry; then idle;
            state idle;
            transition handleInteraction
                first idle
                accept interaction : UserInteraction via interactionIn
                do action {
                    first start;
                    then action interpretIntent { }
                    then send new ControlCommand("renderingEngine", "update", "parameters") via controlOut;
                }
                then idle;
        }
    }

    part def VisualizationSystem {
        port rawIn : RawDataInPort;
        port interactionIn : InteractionInPort;
        port displayOut : RenderOutPort;

        part dataProcessor : DataProcessor;
        part cacheManager : CacheManager;
        part analyticsEngine : AnalyticsEngine;
        part renderingEngine : RenderingEngine;
        part interactionManager : InteractionManager;

        bind rawIn = dataProcessor.rawIn;
        bind interactionIn = interactionManager.interactionIn;
        bind displayOut = renderingEngine.renderOut;

        flow cleanedToCacheFlow of CleanedData from dataProcessor.cleanedOut.cleaned to cacheManager.cleanedIn.cleaned;
        flow cleanedToAnalyticsFlow of CleanedData from dataProcessor.cleanedOut.cleaned to analyticsEngine.cleanedIn.cleaned;
        flow cachedToRenderFlow of CleanedData from cacheManager.cleanedOut.cleaned to renderingEngine.cleanedIn.cleaned;
        flow controlToRenderFlow of ControlCommand from interactionManager.controlOut.command to renderingEngine.controlIn.command;
        flow insightToRenderFlow of Insight from analyticsEngine.insightOut.insight to renderingEngine.insightIn.insight;

        requirement def RenderingPerformanceRequirement {
            doc /* The rendering engine shall maintain a frame rate of at least 60 fps. */
            subject renderingEngine : RenderingEngine;
            attribute minFrameRate : FramesPerSecond = 60.0;
            constraint { renderingEngine.targetFrameRate >= minFrameRate; }
        }
        requirement def CacheLatencyRequirement {
            doc /* The cache manager shall support high-speed data retrieval with cache size above 1 GB. */
            subject cacheManager : CacheManager;
            attribute minCacheSize : Bytes = 1000000000.0;
            constraint { cacheManager.maxCacheSize >= minCacheSize; }
        }
        requirement def AnalyticsConfidenceRequirement {
            doc /* The analytics engine shall only surface insights with confidence >= 0.8. */
            subject analyticsEngine : AnalyticsEngine;
            attribute minConfidence : Confidence = 0.8;
            constraint { analyticsEngine.minConfidence >= minConfidence; }
        }
        requirement def RealTimeInteractionRequirement {
            doc /* The system shall respond to user interactions within 100 ms. */
            subject interactionManager : InteractionManager;
            attribute maxLatency : Milliseconds = 100.0;
        }
        requirement def DataIntegrityRequirement {
            doc /* The data processor shall validate and clean all incoming raw data. */
            subject dataProcessor : DataProcessor;
        }

        requirement renderingPerformance : RenderingPerformanceRequirement {
            subject :>> renderingEngine = renderingEngine;
        }
        requirement cacheLatency : CacheLatencyRequirement {
            subject :>> cacheManager = cacheManager;
        }
        requirement analyticsConfidence : AnalyticsConfidenceRequirement {
            subject :>> analyticsEngine = analyticsEngine;
        }
        requirement realTimeInteraction : RealTimeInteractionRequirement {
            subject :>> interactionManager = interactionManager;
        }
        requirement dataIntegrity : DataIntegrityRequirement {
            subject :>> dataProcessor = dataProcessor;
        }
    }

    part visualizationSystem : VisualizationSystem;
}
