package StrategicTechnologyForesightPlatform {
	doc
	/*
	 * This package defines a Strategic Technology Foresight Platform that integrates
	 * technology evaluation, trend analysis, scenario planning, and strategic synthesis.
	 */
	private import ScalarValues::*;

	attribute def TRL :> Integer {
		doc /* Technology Readiness Level 1-9 */
		assert constraint { that >= 1 and that <= 9 }
	}

	attribute def Probability :> Real {
		assert constraint { that >= 0.0 and that <= 1.0 }
	}

	attribute def ImpactLevel :> Real {
		assert constraint { that >= 0.0 and that <= 1.0 }
	}

	attribute def ConfidenceScore :> Real {
		assert constraint { that >= 0.0 and that <= 1.0 }
	}

	item def TechnologyProfile {
		attribute name : String;
		attribute trl : TRL;
		attribute disruptionPotential : Probability;
	}

	item def MarketTrend {
		attribute name : String;
		attribute growthRate : Real;
		attribute marketValue : Real;
		attribute influencingFactors : String[*];
	}

	item def ValidatedData {
		attribute techProfiles : TechnologyProfile[*];
		attribute marketTrends : MarketTrend[*];
	}

	item def TechnologyAssessment {
		attribute techName : String;
		attribute readiness : Real;
		attribute impact : ImpactLevel;
		attribute benchmark : String;
	}

	item def TrendInsight {
		attribute patterns : String[*];
		attribute earlySignals : String[*];
		attribute correlations : String[*];
	}

	item def FutureScenario {
		attribute description : String;
		attribute probability : Probability;
		attribute impactLevel : ImpactLevel;
	}

	item def Recommendation {
		attribute priority : Integer;
		attribute description : String;
	}

	item def Risk {
		attribute description : String;
		attribute level : Probability;
	}

	item def Opportunity {
		attribute description : String;
		attribute level : Probability;
	}

	item def ForesightReport {
		attribute recommendations : Recommendation[*];
		attribute risks : Risk[*];
		attribute opportunities : Opportunity[*];
		attribute confidenceScore : ConfidenceScore;
	}

	part def DataAcquisitionModule {
		out port dataOut : ValidatedData;
	}

	part def TechnologyEvaluationEngine {
		in port dataIn : ValidatedData;
		out port assessmentOut : TechnologyAssessment;
	}

	part def TrendAnalysisEngine {
		in port dataIn : ValidatedData;
		out port insightOut : TrendInsight;
	}

	part def ScenarioPlanningEngine {
		in port techIn : TechnologyAssessment;
		in port trendIn : TrendInsight;
		out port scenarioOut : FutureScenario;
	}

	part def StrategicSynthesisEngine {
		in port techIn : TechnologyAssessment;
		in port trendIn : TrendInsight;
		in port scenarioIn : FutureScenario;
		out port reportOut : ForesightReport;
		attribute confidenceThreshold : ConfidenceScore = 0.8;
	}

	state machine def PlatformBehavior {
		attribute currentConfidence : ConfidenceScore;
		attribute confidenceThreshold : ConfidenceScore = 0.8;

		state Idle;
		state AcquiringData;
		state Analyzing;
		state PlanningScenarios;
		state Synthesizing;
		state Reporting;
		state Reevaluating;

		transition from Idle to AcquiringData;
		transition from AcquiringData to Analyzing;
		transition from Analyzing to PlanningScenarios;
		transition from PlanningScenarios to Synthesizing;
		transition from Synthesizing to Reporting;
		transition from Reporting to Reevaluating if currentConfidence < confidenceThreshold;
		transition from Reevaluating to Analyzing;
		transition from Reporting to Idle if currentConfidence >= confidenceThreshold;
	}

	part def Platform {
		attribute currentConfidence : ConfidenceScore;
		attribute confidenceThreshold : ConfidenceScore = 0.8;

		part dataAcquisition : DataAcquisitionModule;
		part techEval : TechnologyEvaluationEngine;
		part trendAnalysis : TrendAnalysisEngine;
		part scenarioPlanning : ScenarioPlanningEngine;
		part strategicSynthesis : StrategicSynthesisEngine;

		connection dataToTechEval connect dataAcquisition.dataOut to techEval.dataIn;
		connection dataToTrendAnalysis connect dataAcquisition.dataOut to trendAnalysis.dataIn;
		connection techEvalToScenario connect techEval.assessmentOut to scenarioPlanning.techIn;
		connection trendAnalysisToScenario connect trendAnalysis.insightOut to scenarioPlanning.trendIn;
		connection techEvalToSynthesis connect techEval.assessmentOut to strategicSynthesis.techIn;
		connection trendAnalysisToSynthesis connect trendAnalysis.insightOut to strategicSynthesis.trendIn;
		connection scenarioToSynthesis connect scenarioPlanning.scenarioOut to strategicSynthesis.scenarioIn;

		state machine : PlatformBehavior;
	}

	requirement def DataValidationRequirement {
		doc /* The Data Acquisition Module must validate all incoming data for accuracy and reliability. */
		subject dataAcquisition : DataAcquisitionModule;
		require constraint { dataAcquisition.dataOut.techProfiles->size() > 0 }
	}

	requirement def ConfidenceThresholdRequirement {
		doc /* The Foresight Report must meet the minimum confidence threshold. */
		subject report : ForesightReport;
		attribute threshold : ConfidenceScore = 0.8;
		require constraint { report.confidenceScore >= threshold }
	}
}
