package DataVizAnalyticsSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQ::Mass;

    // ---- Value types with units ----
    value def FrameRate :> Real { unit "fps" }
    value def DataVolume :> Real { unit "MB" }
    value def Latency :> Real { unit "ms" }
    value def Confidence :> Real { unit "1" }
    value def PixelCount :> Integer { unit "px" }
    value def RecordCount :> Integer { unit "records" }

    // ---- Item types ----
    item def RawData {
        attribute volume : DataVolume;
        attribute recordCount : RecordCount;
    }
    item def ValidatedData {
        attribute isValid : Boolean;
        attribute recordCount : RecordCount;
    }
    item def CleanedData {
        attribute recordCount : RecordCount;
        attribute noiseRemoved : Boolean;
    }
    item def AggregatedData {
        attribute recordCount : RecordCount;
        attribute summaryLevel : String;
    }
    item def PreparedData {
        attribute recordCount : RecordCount;
        attribute summaryLevel : String;
    }
    item def CachedData {
        attribute key : String;
        attribute payload : PreparedData;
        attribute timestamp : Time;
    }
    item def CacheKey {
        attribute id : String;
    }
    item def LayoutSpec {
        attribute layoutType : String;
        attribute width : PixelCount;
        attribute height : PixelCount;
    }
    item def StyleSpec {
        attribute colorScheme : String;
        attribute shape : String;
    }
    item def RenderCommand {
        attribute layout : LayoutSpec;
        attribute style : StyleSpec;
        attribute data : PreparedData;
    }
    item def RenderedFrame {
        attribute frameRate : FrameRate;
        attribute width : PixelCount;
        attribute height : PixelCount;
    }
    item def UserInput {
        attribute inputType : String;
        attribute payload : String;
    }
    item def InteractionEvent {
        attribute eventType : String;
        attribute target : String;
        attribute parameters : String;
    }
    item def AnalyticsResult {
        attribute patternType : String;
        attribute confidence : Confidence;
        attribute affectedRecords : RecordCount;
    }
    item def Insight {
        attribute description : String;
        attribute severity : String;
        attribute confidence : Confidence;
    }
    item def VisualCue {
        attribute cueType : String;
        attribute target : String;
        attribute insight : Insight;
    }

    // ---- Port definitions ----
    port def RawDataInPort { in item raw : RawData; }
    port def PreparedDataOutPort { out item prepared : PreparedData; }
    port def PreparedDataInPort { in item prepared : PreparedData; }
    port def CachedDataOutPort { out item cached : CachedData; }
    port def CachedDataInPort { in item cached : CachedData; }
    port def RenderedFrameOutPort { out item frame : RenderedFrame; }
    port def RenderedFrameInPort { in item frame : RenderedFrame; }
    port def UserInputInPort { in item input : UserInput; }
    port def InteractionEventOutPort { out item event : InteractionEvent; }
    port def InteractionEventInPort { in item event : InteractionEvent; }
    port def AnalyticsResultOutPort { out item result : AnalyticsResult; }
    port def AnalyticsResultInPort { in item result : AnalyticsResult; }
    port def InsightOutPort { out item insight : Insight; }
    port def InsightInPort { in item insight : Insight; }
    port def VisualCueOutPort { out item cue : VisualCue; }
    port def VisualCueInPort { in item cue : VisualCue; }
    port def CacheStorePort { in item data : PreparedData; out item cached : CachedData; }
    port def CacheRetrievePort { in item key : CacheKey; out item cached : CachedData; }

    // ---- Data Processor ----
    part def DataProcessor {
        port rawIn : RawDataInPort;
        port preparedOut : PreparedDataOutPort;
        port cacheStore : CacheStorePort;
        port analyticsOut : PreparedDataOutPort;

        attribute throughput : DataVolume = 500.0;

        action def ValidateAction {
            in raw : RawData;
            out validated : ValidatedData;
        }
        action def CleanAction {
            in validated : ValidatedData;
            out cleaned : CleanedData;
        }
        action def AggregateAction {
            in cleaned : CleanedData;
            out aggregated : AggregatedData;
        }

        action performProcessing {
            in raw : RawData;
            out prepared : PreparedData;

            action validate : ValidateAction;
            action clean : CleanAction;
            action aggregate : AggregateAction;

            flow raw to validate.raw;
            flow validate.validated to clean.validated;
            flow clean.cleaned to aggregate.cleaned;
            flow aggregate.aggregated to prepared;
        }

        state processorStateMachine {
            entry { send rawIn.raw to performProcessing; }
            state idle;
            state validating;
            state cleaning;
            state aggregating;
            state emitting;
            transition idle to validating on rawIn.raw;
            transition validating to cleaning on performProcessing.validate.done;
            transition cleaning to aggregating on performProcessing.clean.done;
            transition aggregating to emitting on performProcessing.aggregate.done;
            transition emitting to idle on preparedOut.prepared;
        }
    }

    // ---- Rendering Engine ----
    part def RenderingEngine {
        port dataIn : PreparedDataInPort;
        port cachedIn : CachedDataInPort;
        port interactionIn : InteractionEventInPort;
        port cueIn : VisualCueInPort;
        port frameOut : RenderedFrameOutPort;

        attribute targetFrameRate : FrameRate = 60.0;
        attribute currentFrameRate : FrameRate;

        action def SelectLayoutAction {
            in data : PreparedData;
            out layout : LayoutSpec;
        }
        action def MapDataAction {
            in data : PreparedData;
            in layout : LayoutSpec;
            out command : RenderCommand;
        }
        action def ApplyStyleAction {
            in command : RenderCommand;
            in cue : VisualCue;
            out styledCommand : RenderCommand;
        }
        action def OptimizeAction {
            in command : RenderCommand;
            out frame : RenderedFrame;
        }

        action renderPipeline {
            in data : PreparedData;
            in cue : VisualCue;
            out frame : RenderedFrame;

            action selectLayout : SelectLayoutAction;
            action mapData : MapDataAction;
            action applyStyle : ApplyStyleAction;
            action optimize : OptimizeAction;

            flow data to selectLayout.data;
            flow selectLayout.layout to mapData.layout;
            flow data to mapData.data;
            flow mapData.command to applyStyle.command;
            flow cue to applyStyle.cue;
            flow applyStyle.styledCommand to optimize.command;
            flow optimize.frame to frame;
        }

        state renderStateMachine {
            state idle;
            state preparing;
            state rendering;
            state optimizing;
            transition idle to preparing on dataIn.prepared;
            transition preparing to rendering on renderPipeline.selectLayout.done;
            transition rendering to optimizing on renderPipeline.applyStyle.done;
            transition optimizing to idle on frameOut.frame;
            transition idle to preparing on interactionIn.event;
            transition idle to preparing on cueIn.cue;
        }
    }

    // ---- Interaction Manager ----
    part def InteractionManager {
        port userInputIn : UserInputInPort;
        port frameIn : RenderedFrameInPort;
        port eventOut : InteractionEventOutPort;

        action def InterpretInputAction {
            in input : UserInput;
            out event : InteractionEvent;
        }
        action def DispatchEventAction {
            in event : InteractionEvent;
        }

        action handleInteraction {
            in input : UserInput;
            out event : InteractionEvent;

            action interpret : InterpretInputAction;
            action dispatch : DispatchEventAction;

            flow input to interpret.input;
            flow interpret.event to event;
            flow interpret.event to dispatch.event;
        }

        state interactionStateMachine {
            state listening;
            state interpreting;
            state dispatching;
            transition listening to interpreting on userInputIn.input;
            transition interpreting to dispatching on handleInteraction.interpret.done;
            transition dispatching to listening on eventOut.event;
        }
    }

    // ---- Cache Manager ----
    part def CacheManager {
        port storeIn : CacheStorePort;
        port retrieveIn : CacheRetrievePort;
        port cachedOut : CachedDataOutPort;

        attribute capacity : DataVolume = 2048.0;
        attribute hitRate : Real = 0.85;

        action def StoreAction {
            in data : PreparedData;
            out cached : CachedData;
        }
        action def RetrieveAction {
            in key : CacheKey;
            out cached : CachedData;
        }
        action def EvictAction {
            in key : CacheKey;
        }

        action manageCache {
            in data : PreparedData;
            in key : CacheKey;
            out cached : CachedData;

            action store : StoreAction;
            action retrieve : RetrieveAction;
            action evict : EvictAction;

            flow data to store.data;
            flow store.cached to cached;
            flow key to retrieve.key;
            flow retrieve.cached to cached;
        }

        state cacheStateMachine {
            state ready;
            state storing;
            state retrieving;
            state evicting;
            transition ready to storing on storeIn.data;
            transition storing to ready on storeIn.cached;
            transition ready to retrieving on retrieveIn.key;
            transition retrieving to ready on retrieveIn.cached;
            transition ready to evicting when (capacity > 2048.0);
            transition evicting to ready on evictAction.done;
        }
    }

    // ---- Analytics Engine ----
    part def AnalyticsEngine {
        port dataIn : PreparedDataInPort;
        port resultOut : AnalyticsResultOutPort;
        port insightOut : InsightOutPort;
        port cueOut : VisualCueOutPort;

        attribute minConfidence : Confidence = 0.75;

        action def DetectPatternsAction {
            in data : PreparedData;
            out result : AnalyticsResult;
        }
        action def DetectTrendsAction {
            in data : PreparedData;
            out result : AnalyticsResult;
        }
        action def DetectAnomaliesAction {
            in data : PreparedData;
            out result : AnalyticsResult;
        }
        action def GenerateInsightAction {
            in result : AnalyticsResult;
            out insight : Insight;
        }
        action def GenerateVisualCueAction {
            in insight : Insight;
            out cue : VisualCue;
        }

        action analyzeData {
            in data : PreparedData;
            out insight : Insight;
            out cue : VisualCue;

            action detectPatterns : DetectPatternsAction;
            action detectTrends : DetectTrendsAction;
            action detectAnomalies : DetectAnomaliesAction;
            action generateInsight : GenerateInsightAction;
            action generateCue : GenerateVisualCueAction;

            flow data to detectPatterns.data;
            flow data to detectTrends.data;
            flow data to detectAnomalies.data;
            flow detectPatterns.result to generateInsight.result;
            flow detectTrends.result to generateInsight.result;
            flow detectAnomalies.result to generateInsight.result;
            flow generateInsight.insight to insight;
            flow generateInsight.insight to generateCue.insight;
            flow generateCue.cue to cue;
        }

        state analyticsStateMachine {
            state idle;
            state analyzing;
            state generating;
            state notifying;
            transition idle to analyzing on dataIn.prepared;
            transition analyzing to generating on analyzeData.detectAnomalies.done;
            transition generating to notifying on analyzeData.generateInsight.done;
            transition notifying to idle on cueOut.cue;
        }
    }

    // ---- Top-level system ----
    part def VisualizationAnalyticsSystem {
        port externalDataIn : RawDataInPort;
        port externalUserIn : UserInputInPort;
        port externalFrameOut : RenderedFrameOutPort;

        part dataProcessor : DataProcessor {
            port rawIn : RawDataInPort;
            port preparedOut : PreparedDataOutPort;
            port cacheStore : CacheStorePort;
            port analyticsOut : PreparedDataOutPort;
        }
        part renderingEngine : RenderingEngine {
            port dataIn : PreparedDataInPort;
            port cachedIn : CachedDataInPort;
            port interactionIn : InteractionEventInPort;
            port cueIn : VisualCueInPort;
            port frameOut : RenderedFrameOutPort;
        }
        part interactionManager : InteractionManager {
            port userInputIn : UserInputInPort;
            port frameIn : RenderedFrameInPort;
            port eventOut : InteractionEventOutPort;
        }
        part cacheManager : CacheManager {
            port storeIn : CacheStorePort;
            port retrieveIn : CacheRetrievePort;
            port cachedOut : CachedDataOutPort;
        }
        part analyticsEngine : AnalyticsEngine {
            port dataIn : PreparedDataInPort;
            port resultOut : AnalyticsResultOutPort;
            port insightOut : InsightOutPort;
            port cueOut : VisualCueOutPort;
        }

        connection rawFeed connect externalDataIn to dataProcessor.rawIn;
        connection userFeed connect externalUserIn to interactionManager.userInputIn;
        connection frameDisplay connect renderingEngine.frameOut to externalFrameOut;
        connection preparedToCache connect dataProcessor.preparedOut to cacheManager.storeIn;
        connection preparedToAnalytics connect dataProcessor.analyticsOut to analyticsEngine.dataIn;
        connection cacheToRendering connect cacheManager.cachedOut to renderingEngine.cachedIn;
        connection interactionToRendering connect interactionManager.eventOut to renderingEngine.interactionIn;
        connection cueToRendering connect analyticsEngine.cueOut to renderingEngine.cueIn;
        connection frameToInteraction connect renderingEngine.frameOut to interactionManager.frameIn;
    }

    // ---- Requirements ----
    requirement def RealTimeVisualizationRequirement {
        subject system : VisualizationAnalyticsSystem;
        objective {
            doc "The system shall allow users to explore large, complex datasets in real-time."
        }
        require system.renderingEngine.currentFrameRate >= 30.0 [fps];
    }

    requirement def DataProcessingRequirement {
        subject processor : DataProcessor;
        objective {
            doc "The processor shall validate, clean, and aggregate raw data before emission."
        }
        require processor.throughput >= 100.0 [MB];
    }

    requirement def RenderingQualityRequirement {
        subject engine : RenderingEngine;
        objective {
            doc "The rendering engine shall produce high-frame-rate visual representations."
        }
        require engine.targetFrameRate >= 60.0 [fps];
    }

    requirement def InteractionResponsivenessRequirement {
        subject manager : InteractionManager;
        objective {
            doc "User interactions shall be reflected in the visualization with minimal latency."
        }
        require manager.responseLatency <= 50.0 [ms];
    }

    requirement def CachePerformanceRequirement {
        subject cache : CacheManager;
        objective {
            doc "The cache manager shall reduce recomputation latency for repeated queries."
        }
        require cache.hitRate >= 0.80;
    }

    requirement def AnalyticsInsightRequirement {
        subject analytics : AnalyticsEngine;
        objective {
            doc "The analytics engine shall automatically detect patterns, trends, and anomalies and surface insights."
        }
        require analytics.minConfidence >= 0.75 [1];
    }

    requirement group VisualizationSystemRequirements {
        requirement realTimeReq : RealTimeVisualizationRequirement;
        requirement dataProcReq : DataProcessingRequirement;
        requirement renderReq : RenderingQualityRequirement;
        requirement interactionReq : InteractionResponsivenessRequirement;
        requirement cacheReq : CachePerformanceRequirement;
        requirement analyticsReq : AnalyticsInsightRequirement;
    }

    // ---- Satisfaction ----
    satisfaction satisfy realTimeReq by VisualizationAnalyticsSystem;
    satisfaction satisfy dataProcReq by VisualizationAnalyticsSystem::dataProcessor;
    satisfaction satisfy renderReq by VisualizationAnalyticsSystem::renderingEngine;
    satisfaction satisfy interactionReq by VisualizationAnalyticsSystem::interactionManager;
    satisfaction satisfy cacheReq by VisualizationAnalyticsSystem::cacheManager;
    satisfaction satisfy analyticsReq by VisualizationAnalyticsSystem::analyticsEngine;
}
