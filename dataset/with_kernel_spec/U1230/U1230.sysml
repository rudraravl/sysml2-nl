package TechnologyForecastingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def TrendStrength :> Real {
        assert constraint { that >= -1.0 and that <= 1.0 }
    }
    
    attribute def MaturityLevel :> Real {
        assert constraint { that >= 1.0 and that <= 9.0 }
    }
    
    attribute def AdoptionRate :> Real {
        assert constraint { that >= 0.0 and that <= 100.0 }
    }
    
    attribute def DisruptionPotential :> Real {
        assert constraint { that >= 0.0 and that <= 1.0 }
    }
    
    attribute def ConfidenceScore :> Real {
        assert constraint { that >= 0.0 and that <= 1.0 }
    }
    
    attribute def DurationHours :> Real;
    
    item def HistoricalData {
        attribute patentFilings : Natural;
        attribute researchPubCount : Natural;
        attribute investmentAmounts : Real;
        attribute pastAdoptionRates : AdoptionRate[*];
    }
    
    item def MarketIndicators {
        attribute fundingTrendStrengths : TrendStrength[*];
        attribute competitorActivityLevel : TrendStrength;
        attribute regulatoryEnvironmentFavorability : TrendStrength;
        attribute consumerDemandStrength : TrendStrength;
    }
    
    item def TechnologyDataPackage {
        item histData : HistoricalData;
        item mktIndicators : MarketIndicators;
    }
    
    item def TrendAnalysisResult {
        attribute growthRate : TrendStrength;
        attribute acceleration : TrendStrength;
        attribute marketVolatility : TrendStrength;
    }
    
    item def TechnologyForecast {
        attribute futureMaturity : MaturityLevel;
        attribute expectedAdoptionRate : AdoptionRate;
        attribute emergenceTimeline : ISQ::time;
        attribute disruptionPotential : DisruptionPotential;
        attribute confidence : ConfidenceScore;
    }
    
    item def StrategicRecommendation {
        attribute investmentSuggestion : String;
        attribute riskAssessment : String;
        attribute strategicActionItems : String[*];
    }
    
    action def AcquireTechnologyData {
        out dataPackage : TechnologyDataPackage;
    }
    
    action def AnalyzeTrends {
        in dataPackage : TechnologyDataPackage;
        out trendResult : TrendAnalysisResult;
    }
    
    action def GenerateForecast {
        in trendResult : TrendAnalysisResult;
        out rawForecast : TechnologyForecast;
    }
    
    action def ValidateForecast {
        in rawForecast : TechnologyForecast;
        in minConfidence : ConfidenceScore;
        out validatedForecast : TechnologyForecast;
    }
    
    action def GenerateRecommendations {
        in forecast : TechnologyForecast;
        out recommendation : StrategicRecommendation;
    }
    
    action def ForecastingPipeline {
        out finalRecommendation : StrategicRecommendation;
        out finalForecast : TechnologyForecast;
        
        perform action acquire : AcquireTechnologyData;
        then perform action analyze : AnalyzeTrends {
            in dataPackage = acquire.dataPackage;
        }
        then perform action generate : GenerateForecast {
            in trendResult = analyze.trendResult;
        }
        then perform action validate : ValidateForecast {
            in rawForecast = generate.rawForecast;
            in minConfidence = 0.8;
        }
        then perform action recommend : GenerateRecommendations {
            in forecast = validate.validatedForecast;
        }
        then assign finalRecommendation := recommend.recommendation;
        then assign finalForecast := validate.validatedForecast;
    }
    
    part def DataAcquisitionModule {
        port dataPackageOut : TechnologyDataPackage;
        perform action acquire : AcquireTechnologyData;
    }
    
    part def AnalyticsEngine {
        port dataPackageIn : TechnologyDataPackage;
        port trendResultOut : TrendAnalysisResult;
        perform action analyze : AnalyzeTrends;
    }
    
    part def ForecastingEngine {
        port trendResultIn : TrendAnalysisResult;
        port forecastOut : TechnologyForecast;
        perform action generate : GenerateForecast;
        perform action validate : ValidateForecast;
    }
    
    part def RecommendationEngine {
        port forecastIn : TechnologyForecast;
        port recommendationOut : StrategicRecommendation;
        perform action recommend : GenerateRecommendations;
    }
    
    part def TechnologyForecastingSystem {
        attribute processDuration : DurationHours;
        
        part acquisition : DataAcquisitionModule;
        part analytics : AnalyticsEngine;
        part forecasting : ForecastingEngine;
        part recommendation : RecommendationEngine;
        
        connect acquisition.dataPackageOut to analytics.dataPackageIn;
        connect analytics.trendResultOut to forecasting.trendResultIn;
        connect forecasting.forecastOut to recommendation.forecastIn;
        
        port finalRecommendation : StrategicRecommendation;
        connect recommendation.recommendationOut to finalRecommendation;
        
        perform action executePipeline : ForecastingPipeline;
        
        assert constraint { processDuration <= 24.0 }
    }
    
    requirement def CompletionTimeRequirement {
        doc /* The entire forecasting process must be completed within 24 hours. */
        attribute maxDuration : DurationHours = 24.0;
    }
    
    requirement def ConfidenceThresholdRequirement {
        doc /* Every forecast must meet a minimum confidence score. */
        attribute minConfidence : ConfidenceScore = 0.8;
    }
    
    state machine def ForecastingStateMachine {
        state acquiring;
        state analyzing;
        state forecasting;
        state validating;
        state recommending;
        
        transition from acquiring to analyzing;
        transition from analyzing to forecasting;
        transition from forecasting to validating;
        transition from validating to recommending;
    }
}
