package BongshinLeeInspiredVisualizationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def DataPointCount :> Integer;
    attribute def RefreshRate :> Real;
    attribute def ResponseTime :> DurationValue;
    attribute def VisualizationComplexity :> Real;
    attribute def CacheHitRate :> Real;
    
    enum def InteractionMode {
        explore;
        filterData;
        highlightElements;
        compare;
        annotate;
        zoom;
    }
    
    enum def VisualizationType {
        scatterPlot;
        lineChart;
        barChart;
        heatMap;
        networkGraph;
        timeSeriesView;
        parallelCoordinates;
    }
    
    enum def DataQuality {
        raw;
        cleaned;
        aggregated;
        normalized;
    }
    
    item def Dataset {
        attribute recordCount : DataPointCount;
        attribute dimensionality : Integer;
        attribute quality : DataQuality;
        attribute lastUpdated : TimeInstantValue;
    }
    
    item def VisualRepresentation {
        attribute visualType : VisualizationType;
        attribute complexity : VisualizationComplexity;
        attribute renderTime : ResponseTime;
        attribute elementCount : Integer;
    }
    
    item def UserInteraction {
        attribute mode : InteractionMode;
        attribute timestamp : TimeInstantValue;
        attribute targetElements : Integer;
    }
    
    item def AnalyticsInsight {
        attribute pattern : String;
        attribute confidence : Real;
        attribute timestamp : TimeInstantValue;
    }
    
    port def DataInputPort {
        in item dataStream : Dataset;
    }
    
    port def VisualizationOutputPort {
        out item renderedView : VisualRepresentation;
    }
    
    port def InteractionPort {
        in item userAction : UserInteraction;
        out item systemFeedback : VisualRepresentation;
    }
    
    port def AnalyticsPort {
        out item insight : AnalyticsInsight;
    }
    
    part def DataProcessor {
        attribute processingCapacity : DataPointCount;
        attribute throughput : Real;
        
        port dataIn : DataInputPort;
        port dataOut {
            out item processedData : Dataset;
        }
        
        action processData {
            in rawData : Dataset;
            out processedData : Dataset;
            
            first start;
            then action validateData {
                in data = rawData;
                out validatedData : Dataset;
            }
            then action cleanData {
                in data = validateData.validatedData;
                out cleanedData : Dataset;
            }
            then action aggregateData {
                in data = cleanData.cleanedData;
                out aggregatedData : Dataset;
            }
            then done;
            bind processedData = aggregateData.aggregatedData;
        }
    }
    
    part def RenderingEngine {
        attribute maxComplexity : VisualizationComplexity;
        attribute targetFrameRate : RefreshRate;
        attribute gpuMemory : MassValue;
        
        port visualOut : VisualizationOutputPort;
        port dataIn {
            in item dataset : Dataset;
        }
        
        action renderVisualization {
            in dataset : Dataset;
            in visualType : VisualizationType;
            out visual : VisualRepresentation;
            
            first start;
            then action selectLayout {
                in type = visualType;
                out layoutConfig : VisualizationType;
            }
            then action mapDataToVisual {
                in data = dataset;
                in layout = selectLayout.layoutConfig;
                out mappedElements : Integer;
            }
            then action applyAesthetics {
                in elementCount = mapDataToVisual.mappedElements;
                out styledVisualization : VisualRepresentation;
            }
            then action optimizeRendering {
                in visualization = applyAesthetics.styledVisualization;
                out optimizedVisual : VisualRepresentation;
            }
            then done;
            bind visual = optimizeRendering.optimizedVisual;
        }
        
        state def RenderingStateMachine {
            entry; then idle;
            
            state idle;
            transition idle_to_preparing
                first idle
                accept dataset : Dataset
                then preparing;
            
            state preparing;
            transition preparing_to_rendering
                first preparing
                then rendering;
            
            state rendering;
            transition rendering_to_optimizing
                first rendering
                then optimizing;
            
            state optimizing;
            transition optimizing_to_complete
                first optimizing
                then complete;
            
            state complete;
            transition complete_to_idle
                first complete
                then idle;
        }
    }
    
    part def InteractionManager {
        attribute responseThreshold : ResponseTime;
        attribute interactionHistory : Integer;
        
        port interactionPort : InteractionPort;
        
        state def InteractionStateMachine {
            entry; then idle;
            
            state idle;
            transition idle_to_processing
                first idle
                accept userAction : UserInteraction
                then processing;
            
            state processing {
                entry; then analyzeIntent;
                
                state analyzeIntent;
                transition analyzeIntent_to_explore
                    first analyzeIntent
                    if userAction.mode == InteractionMode::explore
                    then explore;
                transition analyzeIntent_to_filterData
                    first analyzeIntent
                    if userAction.mode == InteractionMode::filterData
                    then filterDataState;
                transition analyzeIntent_to_highlight
                    first analyzeIntent
                    if userAction.mode == InteractionMode::highlightElements
                    then highlightState;
                transition analyzeIntent_to_compare
                    first analyzeIntent
                    if userAction.mode == InteractionMode::compare
                    then compare;
                
                state explore;
                state filterDataState;
                state highlightState;
                state compare;
                
                transition explore_to_renderResponse
                    first explore
                    then renderResponse;
                transition filterData_to_renderResponse
                    first filterDataState
                    then renderResponse;
                transition highlight_to_renderResponse
                    first highlightState
                    then renderResponse;
                transition compare_to_renderResponse
                    first compare
                    then renderResponse;
                
                state renderResponse;
                transition renderResponse_to_done
                    first renderResponse
                    then done;
            }
            
            transition processing_to_idle
                first processing.done
                then idle;
        }
    }
    
    part def CacheManager {
        attribute cacheSize : DataPointCount;
        attribute hitRate : CacheHitRate;
        attribute evictionPolicy : String;
        
        action manageCaching {
            in request : Dataset;
            out cachedData : Dataset;
            
            first start;
            then decide;
                if request.recordCount > 10000 then storeInCache;
                if request.recordCount <= 10000 then bypassCache;
            
            action storeInCache {
                in data = request;
                out stored : Dataset;
            }
            then merge returnData;
            
            action bypassCache {
                in data = request;
                out passthrough : Dataset;
            }
            then returnData;
            
            merge returnData;
            then done;
        }
    }
    
    part def AnalyticsEngine {
        attribute patternRecognitionAccuracy : Real;
        attribute insightGenerationRate : RefreshRate;
        
        port analyticsOut : AnalyticsPort;
        port dataIn {
            in item dataset : Dataset;
        }
        
        action generateInsights {
            in dataset : Dataset;
            out insights : AnalyticsInsight;
            
            first start;
            then action detectPatterns {
                in data = dataset;
                out patterns : String;
            }
            then action calculateConfidence {
                in patterns = detectPatterns.patterns;
                out confidence : Real;
            }
            then action createInsight {
                in pattern = detectPatterns.patterns;
                in conf = calculateConfidence.confidence;
                out insight : AnalyticsInsight;
            }
            then done;
            bind insights = createInsight.insight;
        }
    }
    
    part def VisualizationSystem {
        attribute systemLatency : ResponseTime;
        attribute maxDataVolume : DataPointCount;
        attribute systemThroughput : Real;
        
        part processor : DataProcessor {
            attribute :>> processingCapacity = 1000000;
            attribute :>> throughput = 50000.0;
        }
        
        part renderer : RenderingEngine {
            attribute :>> maxComplexity = 0.95;
            attribute :>> targetFrameRate = 60.0;
            attribute :>> gpuMemory = 8000 [kg];
        }
        
        part interactionMgr : InteractionManager {
            attribute :>> responseThreshold = 100.0 [ms];
            attribute :>> interactionHistory = 1000;
        }
        
        part cache : CacheManager {
            attribute :>> cacheSize = 500000;
            attribute :>> hitRate = 0.85;
            attribute :>> evictionPolicy = "LRU";
        }
        
        part analytics : AnalyticsEngine {
            attribute :>> patternRecognitionAccuracy = 0.92;
            attribute :>> insightGenerationRate = 5.0;
        }
        
        connection dataFlow connect processor.dataOut to cache;
        connection cacheToRenderer connect cache to renderer.dataIn;
        connection visualFlow connect renderer.visualOut to interactionMgr.interactionPort;
        connection analyticsFlow connect processor.dataOut to analytics.dataIn;
        
        perform action visualizeData {
            first start;
            then merge continuousOperation;
            
            then action receiveData {
                out incomingData : Dataset;
            }
            
            then action processIncoming {
                in data = receiveData.incomingData;
                out processed : Dataset;
            }
            
            then action cacheProcessed {
                in data = processIncoming.processed;
                out cached : Dataset;
            }
            
            then action renderView {
                in data = cacheProcessed.cached;
                out view : VisualRepresentation;
            }
            
            then action generateAnalytics {
                in data = processIncoming.processed;
                out insight : AnalyticsInsight;
            }
            
            then action handleInteraction {
                in currentView = renderView.view;
            }
            
            then continuousOperation;
        }
    }
    
    package StakeholderRequirements {
        requirement <'REQ-VIS-001'> interactiveVisualization {
            doc /* The system shall provide interactive data visualization 
                 * capabilities enabling users to explore, filter, and analyze
                 * large-scale datasets in real-time, inspired by the research
                 * of Bongshin Lee in human-computer interaction and information
                 * visualization.
                 */
            subject system : VisualizationSystem;
        }
        
        requirement <'REQ-VIS-002'> analyticsSupport {
            doc /* The system shall automatically generate insights and patterns
                 * from visualized data to support data-driven decision making.
                 */
            subject system : VisualizationSystem;
        }
    }
    
    package SystemRequirements {
        requirement <'REQ-VIS-100'> responseTimeRequirement {
            subject system :>> visualizationSystemInstance;
            doc /* The system shall respond to user interactions within 150 milliseconds. */
            assert constraint {
                system.systemLatency <= 150.0 [ms]
            }
        }
        
        requirement <'REQ-VIS-101'> dataCapacityRequirement {
            subject system :>> visualizationSystemInstance;
            doc /* The system shall handle datasets with at least 1 million data points. */
            assert constraint {
                system.maxDataVolume >= 1000000
            }
        }
        
        requirement <'REQ-VIS-102'> renderingPerformance {
            subject renderer :>> visualizationSystemInstance.renderer;
            doc /* The rendering engine shall maintain at least 30 frames per second. */
            assert constraint {
                renderer.targetFrameRate >= 30.0
            }
        }
        
        requirement <'REQ-VIS-103'> cacheEfficiency {
            subject cache :>> visualizationSystemInstance.cache;
            doc /* The cache manager shall achieve at least 80% hit rate. */
            assert constraint {
                cache.hitRate >= 0.80
            }
        }
        
        requirement <'REQ-VIS-104'> analyticsAccuracy {
            subject analytics :>> visualizationSystemInstance.analytics;
            doc /* The analytics engine shall achieve at least 90% pattern recognition accuracy. */
            assert constraint {
                analytics.patternRecognitionAccuracy >= 0.90
            }
        }
        
        requirement <'REQ-VIS-105'> processingThroughput {
            subject processor :>> visualizationSystemInstance.processor;
            doc /* The data processor shall handle at least 40,000 records per second. */
            assert constraint {
                processor.throughput >= 40000.0
            }
        }
    }
    
    part visualizationSystemInstance : VisualizationSystem {
        attribute :>> systemLatency = 120.0 [ms];
        attribute :>> maxDataVolume = 1500000;
        attribute :>> systemThroughput = 55000.0;
    }
    
    satisfy StakeholderRequirements::interactiveVisualization by visualizationSystemInstance;
    satisfy StakeholderRequirements::analyticsSupport by visualizationSystemInstance.analytics;
    satisfy SystemRequirements::responseTimeRequirement by visualizationSystemInstance;
    satisfy SystemRequirements::dataCapacityRequirement by visualizationSystemInstance;
    satisfy SystemRequirements::renderingPerformance by visualizationSystemInstance.renderer;
    satisfy SystemRequirements::cacheEfficiency by visualizationSystemInstance.cache;
    satisfy SystemRequirements::analyticsAccuracy by visualizationSystemInstance.analytics;
    satisfy SystemRequirements::processingThroughput by visualizationSystemInstance.processor;
}
