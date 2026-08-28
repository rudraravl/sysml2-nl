package TechnologyForecastingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----

    value def Count :> Real;
    value def PatentCount :> Count;
    value def PublicationCount :> Count;
    value def AdoptionRatePct :> Real; // percentage 0..100
    value def InvestmentAmount :> Real; // in USD
    value def GrowthRate :> Real; // percent per year
    value def Acceleration :> Real; // percent per year^2
    value def VolatilityIndex :> Real; // dimensionless 0..1
    value def ConfidenceScore :> Real; // 0..1
    value def MaturityLevel :> Integer; // 1..9
    value def DisruptionPotential :> Real; // 0..1
    value def RiskScore :> Real; // 0..1
    value def Hours :> Real;
    value def Years :> Real;

    attribute def TechnologyId :> String;
    attribute def TechnologyName :> String;
    attribute def CompetitorName :> String;
    attribute def RegulatoryStatus :> String;
    attribute def DemandSignal :> String;
    attribute def RecommendationText :> String;
    attribute def StrategicAction :> String;
    attribute def RiskCategory :> String;

    // ---- Item Types ----

    item def HistoricalData {
        attribute technologyId : TechnologyId;
        attribute patentFilings : PatentCount;
        attribute publicationCount : PublicationCount;
        attribute investmentAmount : InvestmentAmount;
        attribute pastAdoptionRate : AdoptionRatePct;
    }

    item def MarketIndicator {
        attribute technologyId : TechnologyId;
        attribute fundingTrend : GrowthRate;
        attribute competitorActivity : CompetitorName[0..*];
        attribute regulatoryEnvironment : RegulatoryStatus;
        attribute consumerDemand : DemandSignal;
    }

    item def RawData {
        attribute technologyId : TechnologyId;
        attribute historical : HistoricalData;
        attribute market : MarketIndicator;
    }

    item def TrendAnalysis {
        attribute technologyId : TechnologyId;
        attribute growthRate : GrowthRate;
        attribute acceleration : Acceleration;
        attribute volatility : VolatilityIndex;
        attribute identifiedPatterns : String[0..*];
    }

    item def Forecast {
        attribute technologyId : TechnologyId;
        attribute maturityLevel : MaturityLevel;
        attribute expectedAdoptionRate : AdoptionRatePct;
        attribute emergenceTimeline : Years;
        attribute disruptionPotential : DisruptionPotential;
        attribute confidence : ConfidenceScore;
        attribute validated : Boolean;
    }

    item def Recommendation {
        attribute technologyId : TechnologyId;
        attribute investmentRecommendation : RecommendationText;
        attribute riskAssessment : RiskScore;
        attribute riskCategory : RiskCategory;
        attribute strategicActions : StrategicAction[0..*];
    }

    // ---- Port Definitions ----

    port def RawDataOut {
        out raw : RawData;
    }

    port def RawDataIn {
        in raw : RawData;
    }

    port def TrendOut {
        out trend : TrendAnalysis;
    }

    port def TrendIn {
        in trend : TrendAnalysis;
    }

    port def ForecastOut {
        out forecast : Forecast;
    }

    port def ForecastIn {
        in forecast : Forecast;
    }

    port def RecommendationOut {
        out recommendation : Recommendation;
    }

    // ---- Requirements ----

    requirement def SystemPurpose {
        doc <<* The Technology Forecasting System shall provide strategic foresight for businesses to make informed decisions about technology planning and investment. *>>
    }

    requirement def DataAcquisitionRequirement {
        subject dataAcquisition : DataAcquisitionModule;
        doc <<* The Data Acquisition Module shall gather historical data including patent filings, research publication counts, investment amounts, and past adoption rates. *>>
        doc <<* The Data Acquisition Module shall collect current market indicators including funding trends, competitor activity, regulatory environment, and consumer demand. *>>
    }

    requirement def AnalyticsRequirement {
        subject analytics : AnalyticsEngine;
        doc <<* The Analytics Engine shall use statistical and machine learning models to process gathered data. *>>
        doc <<* The Analytics Engine shall calculate growth rate, acceleration, and market volatility. *>>
    }

    requirement def ForecastingRequirement {
        subject forecasting : ForecastingEngine;
        doc <<* The Forecasting Engine shall generate a forecast including maturity level (1-9), expected adoption rate, emergence timeline, and disruption potential. *>>
        doc <<* Every forecast shall be internally validated to meet a minimum confidence score of 0.7. *>>
    }

    requirement def RecommendationRequirement {
        subject recommendation : RecommendationEngine;
        doc <<* The Recommendation Engine shall translate forecast data into investment recommendations, risk assessments, and strategic actions. *>>
    }

    requirement def LatencyRequirement {
        subject system : TechnologyForecastingSystem;
        doc <<* The entire process from data gathering to generating recommendations shall be completed within 24 hours. *>>
        constraint { self.maxDuration <= 24 [h] }
        attribute maxDuration : Hours = 24;
    }

    requirement def ConfidenceThresholdRequirement {
        subject forecast : Forecast;
        doc <<* A forecast shall only be finalized if its confidence score is at least 0.7. *>>
        constraint { forecast.confidence >= 0.7 }
    }

    // ---- Parts / Modules ----

    part def DataAcquisitionModule {
        port dataOut : RawDataOut;

        attribute targetTechnology : TechnologyId;

        state acquisitionStateMachine {
            entry;
            state Idle;
            state GatheringHistorical;
            state GatheringMarket;
            state Assembling;
            state Done;

            transition idle_to_gatheringHistorical
                first Idle then GatheringHistorical
                when acquisitionTrigger;

            transition gatheringHistorical_to_gatheringMarket
                first GatheringHistorical then GatheringMarket
                when historicalComplete;

            transition gatheringMarket_to_assembling
                first GatheringMarket then Assembling
                when marketComplete;

            transition assembling_to_done
                first Assembling then Done
                when assemblyComplete;
        }

        action acquireHistoricalData {
            out patents : PatentCount;
            out publications : PublicationCount;
            out investment : InvestmentAmount;
            out adoption : AdoptionRatePct;
        }

        action acquireMarketIndicators {
            out funding : GrowthRate;
            out competitors : CompetitorName[0..*];
            out regulation : RegulatoryStatus;
            out demand : DemandSignal;
        }

        action assembleRawData {
            in patents : PatentCount;
            in publications : PublicationCount;
            in investment : InvestmentAmount;
            in adoption : AdoptionRatePct;
            in funding : GrowthRate;
            in competitors : CompetitorName[0..*];
            in regulation : RegulatoryStatus;
            in demand : DemandSignal;
            out raw : RawData;
        }

        perform acquireHistoricalData then acquireMarketIndicators then assembleRawData;

        // Emit assembled data through port
        // (binding handled at system level)
    }

    part def AnalyticsEngine {
        port dataIn : RawDataIn;
        port trendOut : TrendOut;

        state analyticsStateMachine {
            entry;
            state Waiting;
            state Processing;
            state ComputingMetrics;
            state Emitting;

            transition waiting_to_processing
                first Waiting then Processing
                when dataReceived;

            transition processing_to_computing
                first Processing then ComputingMetrics
                when patternsIdentified;

            transition computing_to_emitting
                first ComputingMetrics then Emitting
                when metricsComputed;

            transition emitting_to_waiting
                first Emitting then Waiting
                when trendEmitted;
        }

        action processRawData {
            in raw : RawData;
            out patterns : String[0..*];
        }

        action computeMetrics {
            in raw : RawData;
            in patterns : String[0..*];
            out growth : GrowthRate;
            out accel : Acceleration;
            out volatility : VolatilityIndex;
        }

        action emitTrend {
            in growth : GrowthRate;
            in accel : Acceleration;
            in volatility : VolatilityIndex;
            in patterns : String[0..*];
            in technologyId : TechnologyId;
            out trend : TrendAnalysis;
        }

        perform processRawData then computeMetrics then emitTrend;
    }

    part def ForecastingEngine {
        port trendIn : TrendIn;
        port forecastOut : ForecastOut;

        attribute minConfidence : ConfidenceScore = 0.7;

        state forecastingStateMachine {
            entry;
            state Idle;
            state Generating;
            state Validating;
            state Accepted;
            state Rejected;

            transition idle_to_generating
                first Idle then Generating
                when trendReceived;

            transition generating_to_validating
                first Generating then Validating
                when forecastGenerated;

            transition validating_to_accepted
                first Validating then Accepted
                when confidence >= 0.7;

            transition validating_to_rejected
                first Validating then Rejected
                when confidence < 0.7;

            transition accepted_to_idle
                first Accepted then Idle
                when forecastEmitted;

            transition rejected_to_generating
                first Rejected then Generating
                when retryRequested;
        }

        action generateForecast {
            in trend : TrendAnalysis;
            out maturity : MaturityLevel;
            out adoption : AdoptionRatePct;
            out timeline : Years;
            out disruption : DisruptionPotential;
            out confidence : ConfidenceScore;
        }

        action validateForecast {
            in confidence : ConfidenceScore;
            out validated : Boolean;
        }

        action emitForecast {
            in maturity : MaturityLevel;
            in adoption : AdoptionRatePct;
            in timeline : Years;
            in disruption : DisruptionPotential;
            in confidence : ConfidenceScore;
            in validated : Boolean;
            in technologyId : TechnologyId;
            out forecast : Forecast;
        }

        perform generateForecast then validateForecast then emitForecast;
    }

    part def RecommendationEngine {
        port forecastIn : ForecastIn;
        port recommendationOut : RecommendationOut;

        state recommendationStateMachine {
            entry;
            state Idle;
            state Translating;
            state AssessingRisk;
            case actionFormulating;
            state Emitting;

            transition idle_to_translating
                first Idle then Translating
                when forecastReceived;

            transition translating_to_assessing
                first Translating then AssessingRisk
                when translationComplete;

            transition assessing_to_formulating
                first AssessingRisk then actionFormulating
                when riskAssessed;

            transition formulating_to_emitting
                first actionFormulating then Emitting
                when actionsFormulated;

            transition emitting_to_idle
                first Emitting then Idle
                when recommendationEmitted;
        }

        action translateForecast {
            in forecast : Forecast;
            out investmentRec : RecommendationText;
        }

        action assessRisk {
            in forecast : Forecast;
            out riskScore : RiskScore;
            out riskCategory : RiskCategory;
        }

        action formulateStrategicActions {
            in forecast : Forecast;
            out actions : StrategicAction[0..*];
        }

        action emitRecommendation {
            in investmentRec : RecommendationText;
            in riskScore : RiskScore;
            in riskCategory : RiskCategory;
            in actions : StrategicAction[0..*];
            in technologyId : TechnologyId;
            out recommendation : Recommendation;
        }

        perform translateForecast then assessRisk then formulateStrategicActions then emitRecommendation;
    }

    // ---- System ----

    part def TechnologyForecastingSystem {
        satisfy SystemPurpose;
        satisfy LatencyRequirement;

        attribute systemMaxDuration : Hours = 24;

        part dataAcquisition : DataAcquisitionModule {
            satisfy DataAcquisitionRequirement;
        }
        part analyticsEngine : AnalyticsEngine {
            satisfy AnalyticsRequirement;
        }
        part forecastingEngine : ForecastingEngine {
            satisfy ForecastingRequirement;
            satisfy ConfidenceThresholdRequirement;
        }
        part recommendationEngine : RecommendationEngine {
            satisfy RecommendationRequirement;
        }

        // Connections
        connection dataToAnalytics connect dataAcquisition.dataOut.raw to analyticsEngine.dataIn.raw;
        connection trendToForecast connect analyticsEngine.trendOut.trend to forecastingEngine.trendIn.trend;
        connection forecastToRecommendation connect forecastingEngine.forecastOut.forecast to recommendationEngine.forecastIn.forecast;

        // System-level orchestration state machine
        state systemOrchestration {
            entry;
            state AwaitingRequest;
            state AcquiringData;
            state Analyzing;
            state Forecasting;
            state Recommending;
            state Complete;

            transition await_to_acquire
                first AwaitingRequest then AcquiringData
                when requestReceived;

            transition acquire_to_analyze
                first AcquiringData then Analyzing
                when dataAcquisition.dataOut.raw->notEmpty();

            transition analyze_to_forecast
                first Analyzing then Forecasting
                when analyticsEngine.trendOut.trend->notEmpty();

            transition forecast_to_recommend
                first Forecasting then Recommending
                when forecastingEngine.forecastOut.forecast->notEmpty();

            transition recommend_to_complete
                first Recommending then Complete
                when recommendationEngine.recommendationOut.recommendation->notEmpty();

            transition complete_to_await
                first Complete then AwaitingRequest
                when resetRequested;
        }
    }

}
