package StrategicTechnologyForesightPlatform {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value def TRL :> Integer {
        doc "Technology Readiness Level, 1 to 9";
        constraint { self >= 1 and self <= 9 }
    }

    value def DisruptionPotential :> Real {
        doc "Potential to disrupt market, 0.0 to 1.0";
        constraint { self >= 0.0 and self <= 1.0 }
    }

    value def GrowthRate :> Real {
        doc "Market growth rate as percentage";
        unit percent;
    }

    value def MarketValue :> Real {
        doc "Market value in USD millions";
        unit "USD";
    }

    value def Probability :> Real {
        doc "Probability of scenario occurrence, 0.0 to 1.0";
        constraint { self >= 0.0 and self <= 1.0 }
    }

    value def ConfidenceScore :> Real {
        doc "Confidence in analysis, 0.0 to 1.0";
        constraint { self >= 0.0 and self <= 1.0 }
    }

    value def PriorityRank :> Integer {
        doc "Priority ranking, 1 highest";
        constraint { self >= 1 }
    }

    enum def ImpactLevel { low; medium; high; critical; }

    enum def DataQuality { unverified; validated; rejected; }

    enum def AnalysisPhase { idle; acquiring; analyzing; planning; synthesizing; evaluating; complete; rerunning; }

    // ===== Item Definitions =====

    item def TechnologyProfile {
        attribute name : String;
        attribute trl : TRL;
        attribute disruptionPotential : DisruptionPotential;
        attribute description : String;
        attribute domain : String;
        attribute competingTechnologies : String[0..*];
    }

    item def MarketTrendData {
        attribute trendName : String;
        attribute growthRate : GrowthRate;
        attribute marketValue : MarketValue;
        attribute influencingFactors : String[0..*];
        attribute timeHorizonYrs : Integer;
        attribute region : String;
    }

    item def ValidatedData {
        attribute technologies : TechnologyProfile[0..*];
        attribute trends : MarketTrendData[0..*];
        attribute quality : DataQuality;
        attribute validationTimestamp : String;
        attribute validationNotes : String;
    }

    item def TechnologyAssessment {
        attribute technologyName : String;
        attribute readinessScore : TRL;
        attribute impactLevel : ImpactLevel;
        attribute benchmarkComparison : String;
        attribute adoptionFeasibility : ConfidenceScore;
        attribute timeToMarketYrs : Integer;
    }

    item def TrendInsight {
        attribute patternDescription : String;
        attribute earlySignals : String[0..*];
        attribute correlations : String[0..*];
        attribute significance : ImpactLevel;
        attribute confidenceInPattern : ConfidenceScore;
    }

    item def Scenario {
        attribute scenarioName : String;
        attribute description : String;
        attribute probability : Probability;
        attribute impactLevel : ImpactLevel;
        attribute timeHorizonYrs : Integer;
        attribute keyDrivers : String[0..*];
        attribute technologyInteractions : String[0..*];
    }

    item def StrategicRecommendation {
        attribute title : String;
        attribute description : String;
        attribute priority : ImpactLevel;
        attribute rank : PriorityRank;
        attribute rationale : String;
        attribute expectedOutcome : String;
        attribute timeToActYrs : Integer;
    }

    item def RiskItem {
        attribute description : String;
        attribute severity : ImpactLevel;
        attribute mitigationStrategy : String;
        attribute probability : Probability;
    }

    item def OpportunityItem {
        attribute description : String;
        attribute potential : ImpactLevel;
        attribute actionRequired : String;
        attribute timeWindowYrs : Integer;
    }

    item def ForesightReport {
        attribute reportId : String;
        attribute generationDate : String;
        attribute recommendations : StrategicRecommendation[0..*];
        attribute risks : RiskItem[0..*];
        attribute opportunities : OpportunityItem[0..*];
        attribute scenarios : Scenario[0..*];
        attribute technologyAssessments : TechnologyAssessment[0..*];
        attribute trendInsights : TrendInsight[0..*];
        attribute confidenceScore : ConfidenceScore;
        attribute executiveSummary : String;
        attribute analysisVersion : Integer;
    }

    // ===== Port Definitions =====

    port def ValidatedDataPort {
        out item validatedData : ValidatedData;
    }

    port def TechnologyAssessmentPort {
        out item assessments : TechnologyAssessment[0..*];
    }

    port def TrendInsightPort {
        out item insights : TrendInsight[0..*];
    }

    port def ScenarioPort {
        out item scenarios : Scenario[0..*];
    }

    port def ForesightReportPort {
        out item report : ForesightReport;
    }

    // ===== Requirement Definitions =====

    requirement def ShallGatherTechnologyProfiles {
        doc "The system shall gather detailed profiles of emerging technologies including TRL and disruption potential.";
        subject platform : StrategicTechnologyForesightPlatform;
        objective {
            platform.technologyProfilesCollected >= 1
        }
    }

    requirement def ShallGatherMarketTrends {
        doc "The system shall gather market trend data including growth rates, market value, and influencing factors.";
        subject platform : StrategicTechnologyForesightPlatform;
        objective {
            platform.marketTrendsCollected >= 1
        }
    }

    requirement def ShallValidateData {
        doc "The system shall validate incoming data to ensure accuracy and reliability.";
        subject platform : StrategicTechnologyForesightPlatform;
        objective {
            platform.dataQuality == DataQuality::validated
        }
    }

    requirement def ShallEvaluateTechnologies {
        doc "The system shall assess technology readiness, evaluate impact, and benchmark against competing technologies.";
        subject platform : StrategicTechnologyForesightPlatform;
        objective {
            platform.technologyAssessmentsGenerated >= 1
        }
    }

    requirement def ShallAnalyzeTrends {
        doc "The system shall identify patterns, detect early signals, and understand factor correlations.";
        subject platform : StrategicTechnologyForesightPlatform;
        objective {
            platform.trendInsightsGenerated >= 1
        }
    }

    requirement def ShallConstructScenarios {
        doc "The system shall construct plausible future scenarios with probability and impact levels.";
        subject platform : StrategicTechnologyForesightPlatform;
        objective {
            platform.scenariosConstructed >= 1
        }
    }

    requirement def ShallGenerateRecommendations {
        doc "The system shall generate prioritized strategic recommendations, identify risks and opportunities.";
        subject platform : StrategicTechnologyForesightPlatform;
        objective {
            platform.recommendationsGenerated >= 1
        }
    }

    requirement def ShallProduceForesightReport {
        doc "The system shall produce a Foresight Report with confidence score as primary output.";
        subject platform : StrategicTechnologyForesightPlatform;
        objective {
            platform.foresightReportProduced == true
        }
    }

    requirement def ShallRerunOnLowConfidence {
        doc "The system shall rerun analysis if confidence score is below threshold.";
        subject platform : StrategicTechnologyForesightPlatform;
        objective {
            platform.confidenceScore >= platform.confidenceThreshold
        }
    }

    // ===== Part Definitions: Modules =====

    part def DataAcquisitionModule {
        attribute collectedTechnologies : TechnologyProfile[0..*];
        attribute collectedTrends : MarketTrendData[0..*];
        attribute validationStatus : DataQuality = DataQuality::unverified;
        attribute validationNotes : String;

        port out validatedDataOut : ValidatedDataPort;

        action gatherTechnologyProfiles {
            out technologies : TechnologyProfile[0..*];
            doc "Gathers detailed profiles of emerging technologies including TRL and disruption potential.";
        }

        action gatherMarketTrends {
            out trends : MarketTrendData[0..*];
            doc "Gathers market trend data including growth rates, market value, and influencing factors.";
        }

        action validateData {
            in rawTechnologies : TechnologyProfile[0..*];
            in rawTrends : MarketTrendData[0..*];
            out validated : ValidatedData;
            doc "Validates incoming data to ensure accuracy and reliability.";
        }

        action emitValidatedData {
            in validated : ValidatedData;
            out data : ValidatedData;
            doc "Emits validated data to downstream engines.";
        }

        perform gatherTechnologyProfiles then gatherMarketTrends then validateData then emitValidatedData;
    }

    part def TechnologyEvaluationEngine {
        attribute assessments : TechnologyAssessment[0..*];
        attribute benchmarkDatabase : String;

        port in validatedDataIn : ~ValidatedDataPort;
        port out assessmentOut : TechnologyAssessmentPort;

        action assessReadiness {
            in technology : TechnologyProfile;
            out readinessScore : TRL;
            out timeToMarket : Integer;
            doc "Assesses each technology's readiness for real-world application.";
        }

        action evaluateImpact {
            in technology : TechnologyProfile;
            out impactLevel : ImpactLevel;
            out adoptionFeasibility : ConfidenceScore;
            doc "Evaluates each technology's potential impact.";
        }

        action benchmarkTechnologies {
            in technologies : TechnologyProfile[0..*];
            out comparisons : String[0..*];
            doc "Benchmarks each technology against competing technologies.";
        }

        action compileAssessments {
            in readinessScores : TRL[0..*];
            in impactLevels : ImpactLevel[0..*];
            in comparisons : String[0..*];
            out assessments : TechnologyAssessment[0..*];
            doc "Compiles all assessment results into TechnologyAssessment items.";
        }

        perform assessReadiness, evaluateImpact, benchmarkTechnologies then compileAssessments;
    }

    part def TrendAnalysisEngine {
        attribute insights : TrendInsight[0..*];
        attribute historicalBaseline : String;

        port in validatedDataIn : ~ValidatedDataPort;
        port out insightOut : TrendInsightPort;

        action identifyPatterns {
            in trends : MarketTrendData[0..*];
            out patterns : String[0..*];
            doc "Identifies significant patterns in market data.";
        }

        action detectEarlySignals {
            in trends : MarketTrendData[0..*];
            out signals : String[0..*];
            doc "Detects early signals of change in market trends.";
        }

        action analyzeCorrelations {
            in trends : MarketTrendData[0..*];
            out correlations : String[0..*];
            doc "Understands how different factors are correlated.";
        }

        action compileInsights {
            in patterns : String[0..*];
            in signals : String[0..*];
            in correlations : String[0..*];
            out insights : TrendInsight[0..*];
            doc "Compiles pattern, signal, and correlation results into TrendInsight items.";
        }

        perform identifyPatterns, detectEarlySignals, analyzeCorrelations then compileInsights;
    }

    part def ScenarioPlanningEngine {
        attribute scenarios : Scenario[0..*];
        attribute maxScenarios : Integer = 5;

        port in assessmentIn : ~TechnologyAssessmentPort;
        port in insightIn : ~TrendInsightPort;
        port out scenarioOut : ScenarioPort;

        action constructScenarios {
            in assessments : TechnologyAssessment[0..*];
            in insights : TrendInsight[0..*];
            out scenarios : Scenario[0..*];
            doc "Constructs distinct, plausible future scenarios by modeling how technologies and market forces interact over time.";
        }

        action assignProbabilities {
            in out scenarios : Scenario[0..*];
            doc "Assigns probability of occurrence to each scenario.";
        }

        action assignImpactLevels {
            in out scenarios : Scenario[0..*];
            doc "Assigns impact level to each scenario.";
        }

        action validateScenarioDiversity {
            in scenarios : Scenario[0..*];
            out valid : Boolean;
            doc "Ensures scenarios are sufficiently diverse and non-redundant.";
        }

        perform constructScenarios then assignProbabilities then assignImpactLevels then validateScenarioDiversity;
    }

    part def StrategicSynthesisEngine {
        attribute report : ForesightReport;
        attribute confidenceThreshold : ConfidenceScore = 0.70;
        attribute analysisVersion : Integer = 1;

        port in assessmentIn : ~TechnologyAssessmentPort;
        port in insightIn : ~TrendInsightPort;
        port in scenarioIn : ~ScenarioPort;
        port out reportOut : ForesightReportPort;

        action synthesizeRecommendations {
            in assessments : TechnologyAssessment[0..*];
            in insights : TrendInsight[0..*];
            in scenarios : Scenario[0..*];
            out recommendations : StrategicRecommendation[0..*];
            doc "Synthesizes complex inputs to generate prioritized strategic recommendations.";
        }

        action identifyRisks {
            in scenarios : Scenario[0..*];
            in assessments : TechnologyAssessment[0..*];
            out risks : RiskItem[0..*];
            doc "Identifies key risks from scenarios and technology assessments.";
        }

        action identifyOpportunities {
            in scenarios : Scenario[0..*];
            in insights : TrendInsight[0..*];
            out opportunities : OpportunityItem[0..*];
            doc "Identifies key opportunities from scenarios and trend insights.";
        }

        action calculateConfidence {
            in assessments : TechnologyAssessment[0..*];
            in insights : TrendInsight[0..*];
            in scenarios : Scenario[0..*];
            out confidence : ConfidenceScore;
            doc "Calculates a confidence score on the analysis itself.";
        }

        action compileReport {
            in recommendations : StrategicRecommendation[0..*];
            in risks : RiskItem[0..*];
            in opportunities : OpportunityItem[0..*];
            in scenarios : Scenario[0..*];
            in assessments : TechnologyAssessment[0..*];
            in insights : TrendInsight[0..*];
            in confidence : ConfidenceScore;
            out report : ForesightReport;
            doc "Compiles everything into a formal Foresight Report.";
        }

        perform synthesizeRecommendations, identifyRisks, identifyOpportunities, calculateConfidence then compileReport;
    }

    // ===== Top-Level Platform =====

    part def StrategicTechnologyForesightPlatform {
        doc "Strategic Technology Foresight Platform: analyzes emerging technologies and market trends to predict future developments and provide actionable recommendations.";

        attribute confidenceThreshold : ConfidenceScore = 0.70;
        attribute confidenceScore : ConfidenceScore = 0.0;
        attribute analysisRerun : Boolean = false;
        attribute foresightReportProduced : Boolean = false;
        attribute technologyProfilesCollected : Integer = 0;
        attribute marketTrendsCollected : Integer = 0;
        attribute dataQuality : DataQuality = DataQuality::unverified;
        attribute technologyAssessmentsGenerated : Integer = 0;
        attribute trendInsightsGenerated : Integer = 0;
        attribute scenariosConstructed : Integer = 0;
        attribute recommendationsGenerated : Integer = 0;
        attribute currentPhase : AnalysisPhase = AnalysisPhase::idle;
        attribute maxReruns : Integer = 2;
        attribute rerunCount : Integer = 0;

        // Subsystem parts
        part dataAcquisition : DataAcquisitionModule {
            port out validatedDataOut : ValidatedDataPort;
        }

        part technologyEvaluation : TechnologyEvaluationEngine {
            port in validatedDataIn : ~ValidatedDataPort;
            port out assessmentOut : TechnologyAssessmentPort;
        }

        part trendAnalysis : TrendAnalysisEngine {
            port in validatedDataIn : ~ValidatedDataPort;
            port out insightOut : TrendInsightPort;
        }

        part scenarioPlanning : ScenarioPlanningEngine {
            port in assessmentIn : ~TechnologyAssessmentPort;
            port in insightIn : ~TrendInsightPort;
            port out scenarioOut : ScenarioPort;
        }

        part strategicSynthesis : StrategicSynthesisEngine {
            port in assessmentIn : ~TechnologyAssessmentPort;
            port in insightIn : ~TrendInsightPort;
            port in scenarioIn : ~ScenarioPort;
            port out reportOut : ForesightReportPort;
        }

        // Connections: data flows between modules
        connection dataAcquisition.validatedDataOut to technologyEvaluation.validatedDataIn;
        connection dataAcquisition.validatedDataOut to trendAnalysis.validatedDataIn;
        connection technologyEvaluation.assessmentOut to scenarioPlanning.assessmentIn;
        connection trendAnalysis.insightOut to scenarioPlanning.insightIn;
        connection technologyEvaluation.assessmentOut to strategicSynthesis.assessmentIn;
        connection trendAnalysis.insightOut to strategicSynthesis.insightIn;
        connection scenarioPlanning.scenarioOut to strategicSynthesis.scenarioIn;

        // Requirement satisfactions
        requirement reqGatherTech : ShallGatherTechnologyProfiles;
        requirement reqGatherTrends : ShallGatherMarketTrends;
        requirement reqValidateData : ShallValidateData;
        requirement reqEvalTech : ShallEvaluateTechnologies;
        requirement reqAnalyzeTrends : ShallAnalyzeTrends;
        requirement reqConstructScenarios : ShallConstructScenarios;
        requirement reqGenRecs : ShallGenerateRecommendations;
        requirement reqProduceReport : ShallProduceForesightReport;
        requirement reqRerunLowConf : ShallRerunOnLowConfidence;

        satisfy reqGatherTech by dataAcquisition;
        satisfy reqGatherTrends by dataAcquisition;
        satisfy reqValidateData by dataAcquisition;
        satisfy reqEvalTech by technologyEvaluation;
        satisfy reqAnalyzeTrends by trendAnalysis;
        satisfy reqConstructScenarios by scenarioPlanning;
        satisfy reqGenRecs by strategicSynthesis;
        satisfy reqProduceReport by strategicSynthesis;
        satisfy reqRerunLowConf by self;

        // State machine governing the overall foresight process
        state def ForesightProcess {
            entry action {
                currentPhase = AnalysisPhase::acquiring;
            }

            state AcquiringData {
                doc "Data acquisition module gathers technology profiles and market trends, then validates data.";
                entry action {
                    currentPhase = AnalysisPhase::acquiring;
                    dataAcquisition.gatherTechnologyProfiles();
                }
                do action {
                    dataAcquisition.gatherMarketTrends();
                }
                exit action {
                    dataAcquisition.validateData();
                    technologyProfilesCollected = dataAcquisition.collectedTechnologies.size();
                    marketTrendsCollected = dataAcquisition.collectedTrends.size();
                    dataQuality = dataAcquisition.validationStatus;
                }
            }

            state AnalyzingTechnologiesAndTrends {
                doc "Technology evaluation and trend analysis engines run in parallel on validated data.";
                entry action {
                    currentPhase = AnalysisPhase::analyzing;
                    technologyEvaluation.assessReadiness();
                    trendAnalysis.identifyPatterns();
                }
                do action {
                    technologyEvaluation.evaluateImpact();
                    technologyEvaluation.benchmarkTechnologies();
                    trendAnalysis.detectEarlySignals();
                    trendAnalysis.analyzeCorrelations();
                }
                exit action {
                    technologyEvaluation.compileAssessments();
                    trendAnalysis.compileInsights();
                    technologyAssessmentsGenerated = technologyEvaluation.assessments.size();
                    trendInsightsGenerated = trendAnalysis.insights.size();
                }
            }

            state PlanningScenarios {
                doc "Scenario planning engine constructs future scenarios from technology and trend insights.";
                entry action {
                    currentPhase = AnalysisPhase::planning;
                    scenarioPlanning.constructScenarios();
                }
                do action {
                    scenarioPlanning.assignProbabilities();
                }
                exit action {
                    scenarioPlanning.assignImpactLevels();
                    scenarioPlanning.validateScenarioDiversity();
                    scenariosConstructed = scenarioPlanning.scenarios.size();
                }
            }

            state SynthesizingStrategy {
                doc "Strategic synthesis engine integrates all prior outputs to generate recommendations, risks, and opportunities.";
                entry action {
                    currentPhase = AnalysisPhase::synthesizing;
                    strategicSynthesis.synthesizeRecommendations();
                }
                do action {
                    strategicSynthesis.identifyRisks();
                    strategicSynthesis.identifyOpportunities();
                }
                exit action {
                    strategicSynthesis.calculateConfidence();
                    strategicSynthesis.compileReport();
                    recommendationsGenerated = strategicSynthesis.report.recommendations.size();
                }
            }

            state EvaluatingConfidence {
                doc "Evaluates the confidence score of the compiled report against the threshold.";
                entry action {
                    currentPhase = AnalysisPhase::evaluating;
                    confidenceScore = strategicSynthesis.report.confidenceScore;
                }
            }

            state RerunningAnalysis {
                doc "Reruns the full analysis if confidence is below threshold and rerun limit not exceeded.";
                entry action {
                    currentPhase = AnalysisPhase::rerunning;
                    analysisRerun = true;
                    rerunCount = rerunCount + 1;
                    strategicSynthesis.analysisVersion = strategicSynthesis.analysisVersion + 1;
                }
            }

            state Complete {
                doc "Foresight report is finalized and ready for decision-makers.";
                entry action {
                    currentPhase = AnalysisPhase::complete;
                    foresightReportProduced = true;
                    analysisRerun = false;
                }
            }

            // Transitions
            transition initial to AcquiringData;

            transition AcquiringData to AnalyzingTechnologiesAndTrends
                when dataQuality == DataQuality::validated
                if technologyProfilesCollected > 0 and marketTrendsCollected > 0;

            transition AcquiringData to AcquiringData
                when dataQuality == DataQuality::rejected
                if rerunCount < maxReruns;

            transition AnalyzingTechnologiesAndTrends to PlanningScenarios
                when technologyAssessmentsGenerated > 0 and trendInsightsGenerated > 0;

            transition PlanningScenarios to SynthesizingStrategy
                when scenariosConstructed > 0;

            transition SynthesizingStrategy to EvaluatingConfidence
                when recommendationsGenerated > 0;

            transition EvaluatingConfidence to Complete
                when confidenceScore >= confidenceThreshold;

            transition EvaluatingConfidence to RerunningAnalysis
                when confidenceScore < confidenceThreshold
                if rerunCount < maxReruns;

            transition RerunningAnalysis to AcquiringData
                when analysisRerun == true;

            transition EvaluatingConfidence to Complete
                when confidenceScore < confidenceThreshold
                if rerunCount >= maxReruns;
        }

        exhibit state ForesightProcess;
    }
}
