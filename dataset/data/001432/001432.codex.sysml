package FutureTechnologyAnalysisSystem {

    import ScalarValues::*;
    import SI::*;

    value def Confidence {
        unit = one;
    }

    value def Probability {
        unit = one;
    }

    value def Score {
        unit = one;
    }

    value def Year {
        unit = one;
    }

    value def CurrencyUSD {
        unit = one;
    }

    value def DataRate {
        unit = bit / s;
    }

    value def Energy {
        unit = J;
    }

    value def TimeDuration {
        unit = s;
    }

    value def ProcessingLatency {
        unit = s;
    }

    value def StorageCapacity {
        unit = bit;
    }

    item def RawTechnologySignal {
        attribute sourceId : String;
        attribute captureTime : String;
        attribute domainTag : String;
        attribute textPayload : String;
        attribute credibility : Confidence;
    }

    item def NormalizedTechnologySignal {
        attribute technologyName : String;
        attribute domain : String;
        attribute maturityEvidence : Score;
        attribute marketEvidence : Score;
        attribute policyEvidence : Score;
        attribute uncertainty : Probability;
    }

    item def TrendVector {
        attribute technologyName : String;
        attribute adoptionVelocity : Score;
        attribute investmentMomentum : Score;
        attribute scientificNovelty : Score;
        attribute infrastructureReadiness : Score;
        attribute regulatoryAlignment : Score;
    }

    item def ScenarioSet {
        attribute baselineScenario : String;
        attribute optimisticScenario : String;
        attribute constrainedScenario : String;
        attribute horizonStart : Year;
        attribute horizonEnd : Year;
        attribute scenarioConfidence : Confidence;
    }

    item def ImpactAssessment {
        attribute primaryFunctionStatement : String;
        attribute economicImpactUsd : CurrencyUSD;
        attribute energyImpact : Energy;
        attribute socialReadiness : Score;
        attribute riskSeverity : Score;
        attribute resilienceScore : Score;
    }

    item def TechnologyAnalysisReport {
        attribute title : String;
        attribute highLevelPrimaryFunction : String;
        attribute recommendedInvestmentTiming : Year;
        attribute confidence : Confidence;
        attribute summary : String;
    }

    port def SignalInPort {
        in rawSignal : RawTechnologySignal;
    }

    port def NormalizedSignalPort {
        out normalizedSignal : NormalizedTechnologySignal;
    }

    port def TrendPort {
        out trend : TrendVector;
    }

    port def ScenarioPort {
        out scenarios : ScenarioSet;
    }

    port def ImpactPort {
        out impact : ImpactAssessment;
    }

    port def ReportPort {
        out report : TechnologyAnalysisReport;
    }

    port def ControlPort {
        in startAnalysis : Boolean;
        in cancelAnalysis : Boolean;
        out analysisReady : Boolean;
        out faultDetected : Boolean;
    }

    action def IngestSignals {
        in raw : RawTechnologySignal;
        out accepted : RawTechnologySignal;
    }

    action def NormalizeSignals {
        in raw : RawTechnologySignal;
        out normalized : NormalizedTechnologySignal;
    }

    action def DetectTrends {
        in normalized : NormalizedTechnologySignal;
        out trend : TrendVector;
    }

    action def GenerateScenarios {
        in trend : TrendVector;
        out scenarios : ScenarioSet;
    }

    action def AssessImpacts {
        in scenarios : ScenarioSet;
        in trend : TrendVector;
        out impact : ImpactAssessment;
    }

    action def SynthesizeReport {
        in trend : TrendVector;
        in scenarios : ScenarioSet;
        in impact : ImpactAssessment;
        out report : TechnologyAnalysisReport;
    }

    state def AnalysisLifecycle {
        state idle;
        state collectingSignals;
        state normalizingEvidence;
        state modelingTrends;
        state generatingScenarios;
        state assessingImpacts;
        state synthesizingPrimaryFunction;
        state publishingReport;
        state faulted;
        state cancelled;

        transition first idle;

        transition start
            first idle
            then collectingSignals;

        transition collectionComplete
            first collectingSignals
            then normalizingEvidence;

        transition normalizationComplete
            first normalizingEvidence
            then modelingTrends;

        transition trendModelComplete
            first modelingTrends
            then generatingScenarios;

        transition scenarioModelComplete
            first generatingScenarios
            then assessingImpacts;

        transition impactAssessmentComplete
            first assessingImpacts
            then synthesizingPrimaryFunction;

        transition synthesisComplete
            first synthesizingPrimaryFunction
            then publishingReport;

        transition publishComplete
            first publishingReport
            then idle;

        transition analysisFault
            first collectingSignals
            then faulted;

        transition modelFault
            first modelingTrends
            then faulted;

        transition scenarioFault
            first generatingScenarios
            then faulted;

        transition cancelFromCollection
            first collectingSignals
            then cancelled;

        transition cancelFromModeling
            first modelingTrends
            then cancelled;

        transition resetFromFault
            first faulted
            then idle;

        transition resetFromCancel
            first cancelled
            then idle;
    }

    part def TechnologySignalCollector {
        port input : SignalInPort;
        port output : NormalizedSignalPort;

        attribute maxInputRate : DataRate = 5000000 [bit / s];
        attribute sourceDiversityTarget : Integer = 12;
        attribute minimumCredibility : Confidence = 0.65 [one];

        perform action ingest : IngestSignals;
        perform action normalize : NormalizeSignals;
    }

    part def EvidenceKnowledgeGraph {
        port input : NormalizedSignalPort;
        port output : TrendPort;

        attribute storageCapacity : StorageCapacity = 8000000000000 [bit];
        attribute relationshipConfidenceThreshold : Confidence = 0.7 [one];
        attribute updateLatencyTarget : ProcessingLatency = 2.0 [s];

        perform action detect : DetectTrends;
    }

    part def ForesightModelEngine {
        port input : TrendPort;
        port output : ScenarioPort;

        attribute forecastHorizonStart : Year = 2026 [one];
        attribute forecastHorizonEnd : Year = 2045 [one];
        attribute monteCarloSamples : Integer = 25000;
        attribute targetScenarioConfidence : Confidence = 0.8 [one];

        perform action scenarioGeneration : GenerateScenarios;
    }

    part def ImpactAndRiskEvaluator {
        port trendInput : TrendPort;
        port scenarioInput : ScenarioPort;
        port output : ImpactPort;

        attribute maxEvaluationLatency : ProcessingLatency = 8.0 [s];
        attribute riskAlertThreshold : Score = 0.75 [one];
        attribute energyBudgetPerRun : Energy = 250000 [J];

        perform action impactAssessment : AssessImpacts;
    }

    part def PrimaryFunctionSynthesizer {
        port trendInput : TrendPort;
        port scenarioInput : ScenarioPort;
        port impactInput : ImpactPort;
        port reportOutput : ReportPort;

        attribute minimumReportConfidence : Confidence = 0.72 [one];
        attribute targetReportLatency : ProcessingLatency = 3.0 [s];

        perform action reportSynthesis : SynthesizeReport;
    }

    part def FutureOrientedTechnologyAnalysisPlatform {
        port externalSignals : SignalInPort;
        port operatorControl : ControlPort;
        port finalReport : ReportPort;

        part collector : TechnologySignalCollector;
        part knowledgeGraph : EvidenceKnowledgeGraph;
        part modelEngine : ForesightModelEngine;
        part evaluator : ImpactAndRiskEvaluator;
        part synthesizer : PrimaryFunctionSynthesizer;

        attribute nominalEndToEndLatency : ProcessingLatency = 20.0 [s];
        attribute continuousOperationEnergyBudget : Energy = 1500000 [J];
        attribute targetForecastConfidence : Confidence = 0.78 [one];

        connection signalFeed
            connect externalSignals to collector.input;

        connection normalizedEvidenceFlow
            connect collector.output to knowledgeGraph.input;

        connection trendToScenarioEngine
            connect knowledgeGraph.output to modelEngine.input;

        connection trendToImpactEvaluator
            connect knowledgeGraph.output to evaluator.trendInput;

        connection scenariosToImpactEvaluator
            connect modelEngine.output to evaluator.scenarioInput;

        connection trendToSynthesizer
            connect knowledgeGraph.output to synthesizer.trendInput;

        connection scenariosToSynthesizer
            connect modelEngine.output to synthesizer.scenarioInput;

        connection impactToSynthesizer
            connect evaluator.output to synthesizer.impactInput;

        connection reportPublication
            connect synthesizer.reportOutput to finalReport;

        exhibit state lifecycle : AnalysisLifecycle;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         The system shall analyze future-oriented technology signals and produce
         a high-level statement of the technology system's primary function,
         expected trajectory, strategic impact, and uncertainty across a defined
         forecast horizon.
        */
    }

    requirement def EvidenceTraceabilityRequirement {
        doc
        /*
         Every synthesized primary function statement shall be traceable to
         normalized evidence, trend vectors, scenario assumptions, and impact
         assessment values.
        */
    }

    requirement def ForecastHorizonRequirement {
        doc
        /*
         The system shall support scenario analysis from year 2026 through year
         2045 for emerging technologies whose maturity and adoption paths are
         uncertain.
        */
    }

    requirement def ConfidenceRequirement {
        doc
        /*
         Published analysis reports shall include a confidence value no lower
         than 0.72 unless explicitly flagged as exploratory.
        */
    }

    requirement def LatencyRequirement {
        doc
        /*
         The platform shall complete a nominal end-to-end analysis run within
         20 seconds after receiving a valid start command and sufficient input
         signals.
        */
    }

    requirement def RiskRequirement {
        doc
        /*
         The platform shall identify systemic risks when modeled risk severity
         exceeds 0.75 and shall include those risks in the final technology
         analysis report.
        */
    }

    satisfy PrimaryFunctionRequirement by FutureOrientedTechnologyAnalysisPlatform;
    satisfy EvidenceTraceabilityRequirement by PrimaryFunctionSynthesizer;
    satisfy ForecastHorizonRequirement by ForesightModelEngine;
    satisfy ConfidenceRequirement by PrimaryFunctionSynthesizer;
    satisfy LatencyRequirement by FutureOrientedTechnologyAnalysisPlatform;
    satisfy RiskRequirement by ImpactAndRiskEvaluator;

    analysis def PrimaryFunctionAnalysis {
        subject platform : FutureOrientedTechnologyAnalysisPlatform;

        objective
        /*
         Determine the primary function of a future-oriented technology system
         by transforming weak signals into normalized evidence, modeling trends,
         creating forecast scenarios, assessing impacts, and synthesizing a
         concise strategic function statement.
        */

        return result : TechnologyAnalysisReport;
    }

    part platformInstance : FutureOrientedTechnologyAnalysisPlatform {
        attribute nominalEndToEndLatency = 18.5 [s];
        attribute continuousOperationEnergyBudget = 1200000 [J];
        attribute targetForecastConfidence = 0.82 [one];

        part collector {
            attribute maxInputRate = 7000000 [bit / s];
            attribute sourceDiversityTarget = 18;
            attribute minimumCredibility = 0.68 [one];
        }

        part knowledgeGraph {
            attribute storageCapacity = 16000000000000 [bit];
            attribute relationshipConfidenceThreshold = 0.74 [one];
            attribute updateLatencyTarget = 1.5 [s];
        }

        part modelEngine {
            attribute forecastHorizonStart = 2026 [one];
            attribute forecastHorizonEnd = 2045 [one];
            attribute monteCarloSamples = 50000;
            attribute targetScenarioConfidence = 0.83 [one];
        }

        part evaluator {
            attribute maxEvaluationLatency = 6.0 [s];
            attribute riskAlertThreshold = 0.75 [one];
            attribute energyBudgetPerRun = 210000 [J];
        }

        part synthesizer {
            attribute minimumReportConfidence = 0.74 [one];
            attribute targetReportLatency = 2.5 [s];
        }
    }
}