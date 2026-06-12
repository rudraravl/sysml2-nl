package BongshinLeeInspiredSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent {
        :> ScalarValues::Real;
        unit = "%";
    }

    attribute def Millisecond {
        :> ScalarValues::Real;
        unit = "ms";
    }

    attribute def ConfidenceScore {
        :> ScalarValues::Real;
        range = "0..1";
    }

    attribute def VisualizationCount {
        :> ScalarValues::Integer;
    }

    item def RawDataset {
        attribute rowCount : ScalarValues::Integer;
        attribute columnCount : ScalarValues::Integer;
        attribute sourceName : ScalarValues::String;
        attribute containsSensitiveFields : ScalarValues::Boolean;
    }

    item def CleanDataset {
        attribute rowCount : ScalarValues::Integer;
        attribute columnCount : ScalarValues::Integer;
        attribute missingValueRate : Percent;
        attribute qualityScore : ConfidenceScore;
    }

    item def UserIntent {
        attribute taskType : ScalarValues::String;
        attribute targetAudience : ScalarValues::String;
        attribute explanationDepth : ScalarValues::String;
        attribute confidence : ConfidenceScore;
    }

    item def VisualEncodingSpec {
        attribute chartType : ScalarValues::String;
        attribute xChannel : ScalarValues::String;
        attribute yChannel : ScalarValues::String;
        attribute colorChannel : ScalarValues::String;
        attribute interactionEnabled : ScalarValues::Boolean;
        attribute accessibilityScore : ConfidenceScore;
    }

    item def InsightCandidate {
        attribute summary : ScalarValues::String;
        attribute evidenceStrength : ConfidenceScore;
        attribute noveltyScore : ConfidenceScore;
        attribute riskOfMisinterpretation : ConfidenceScore;
    }

    item def NarrativeExplanation {
        attribute title : ScalarValues::String;
        attribute conciseSummary : ScalarValues::String;
        attribute primaryFunctionStatement : ScalarValues::String;
        attribute readingLevel : ScalarValues::String;
    }

    item def UserFeedback {
        attribute rating : ScalarValues::Integer;
        attribute comment : ScalarValues::String;
        attribute requestedRevision : ScalarValues::Boolean;
    }

    port def DatasetInputPort {
        in rawData : RawDataset;
    }

    port def IntentInputPort {
        in intent : UserIntent;
    }

    port def VisualizationOutputPort {
        out encoding : VisualEncodingSpec;
        out explanation : NarrativeExplanation;
        out insights : InsightCandidate;
    }

    port def FeedbackPort {
        in feedback : UserFeedback;
    }

    part def DataQualityAnalyzer {
        port dataIn : DatasetInputPort;
        port cleanOut {
            out cleanData : CleanDataset;
        }

        attribute maxMissingValueRate : Percent = 15.0;
        attribute minimumQualityScore : ConfidenceScore = 0.80;

        action cleanAndProfile {
            in raw : RawDataset;
            out clean : CleanDataset;
        }
    }

    part def IntentInterpreter {
        port intentIn : IntentInputPort;
        port interpretedIntentOut {
            out interpretedIntent : UserIntent;
        }

        attribute minimumIntentConfidence : ConfidenceScore = 0.75;

        action inferAnalyticTask {
            in statedIntent : UserIntent;
            out interpretedIntent : UserIntent;
        }
    }

    part def VisualizationRecommender {
        port cleanDataIn {
            in cleanData : CleanDataset;
        }

        port intentIn {
            in interpretedIntent : UserIntent;
        }

        port encodingOut {
            out encoding : VisualEncodingSpec;
        }

        attribute maxRecommendationLatency : Millisecond = 500.0;
        attribute candidateVisualizationLimit : VisualizationCount = 8;

        action selectEncoding {
            in cleanData : CleanDataset;
            in interpretedIntent : UserIntent;
            out encoding : VisualEncodingSpec;
        }
    }

    part def InsightEngine {
        port cleanDataIn {
            in cleanData : CleanDataset;
        }

        port intentIn {
            in interpretedIntent : UserIntent;
        }

        port insightOut {
            out insight : InsightCandidate;
        }

        attribute minimumEvidenceStrength : ConfidenceScore = 0.70;
        attribute maximumMisinterpretationRisk : ConfidenceScore = 0.25;

        action detectInsight {
            in cleanData : CleanDataset;
            in interpretedIntent : UserIntent;
            out insight : InsightCandidate;
        }
    }

    part def NarrativeGenerator {
        port encodingIn {
            in encoding : VisualEncodingSpec;
        }

        port insightIn {
            in insight : InsightCandidate;
        }

        port explanationOut {
            out explanation : NarrativeExplanation;
        }

        attribute primaryFunction : ScalarValues::String =
            "Help people understand data by transforming raw datasets and analytic intent into accessible, interactive visual explanations.";

        action composeExplanation {
            in encoding : VisualEncodingSpec;
            in insight : InsightCandidate;
            out explanation : NarrativeExplanation;
        }
    }

    part def HumanCenteredReviewController {
        port feedbackIn : FeedbackPort;
        port revisionOut {
            out revisionNeeded : ScalarValues::Boolean;
        }

        attribute minimumUserRating : ScalarValues::Integer = 4;

        state def ReviewState {
            state awaitingFeedback;
            state accepted;
            state reviseVisualization;
            state reviseNarrative;

            transition first awaitingFeedback;

            transition accept
                first awaitingFeedback
                then accepted;

            transition reviseChart
                first awaitingFeedback
                then reviseVisualization;

            transition reviseText
                first awaitingFeedback
                then reviseNarrative;

            transition retryVisual
                first reviseVisualization
                then awaitingFeedback;

            transition retryNarrative
                first reviseNarrative
                then awaitingFeedback;
        }

        action assessFeedback {
            in feedback : UserFeedback;
            out revisionNeeded : ScalarValues::Boolean;
        }
    }

    part def BongshinLeeInspiredVisualAnalyticsSystem {
        port datasetInput : DatasetInputPort;
        port intentInput : IntentInputPort;
        port resultOutput : VisualizationOutputPort;
        port feedbackInput : FeedbackPort;

        part dataQualityAnalyzer : DataQualityAnalyzer;
        part intentInterpreter : IntentInterpreter;
        part visualizationRecommender : VisualizationRecommender;
        part insightEngine : InsightEngine;
        part narrativeGenerator : NarrativeGenerator;
        part reviewController : HumanCenteredReviewController;

        attribute systemName : ScalarValues::String = "Human-Centered Visual Analytics Assistant";
        attribute primaryFunctionHighLevel : ScalarValues::String =
            "Convert data and user goals into understandable, accessible visual narratives that support insight, communication, and iterative refinement.";

        connect datasetInput.rawData to dataQualityAnalyzer.dataIn.rawData;
        connect intentInput.intent to intentInterpreter.intentIn.intent;
        connect dataQualityAnalyzer.cleanOut.cleanData to visualizationRecommender.cleanDataIn.cleanData;
        connect dataQualityAnalyzer.cleanOut.cleanData to insightEngine.cleanDataIn.cleanData;
        connect intentInterpreter.interpretedIntentOut.interpretedIntent to visualizationRecommender.intentIn.interpretedIntent;
        connect intentInterpreter.interpretedIntentOut.interpretedIntent to insightEngine.intentIn.interpretedIntent;
        connect visualizationRecommender.encodingOut.encoding to narrativeGenerator.encodingIn.encoding;
        connect insightEngine.insightOut.insight to narrativeGenerator.insightIn.insight;
        connect visualizationRecommender.encodingOut.encoding to resultOutput.encoding;
        connect insightEngine.insightOut.insight to resultOutput.insights;
        connect narrativeGenerator.explanationOut.explanation to resultOutput.explanation;
        connect feedbackInput.feedback to reviewController.feedbackIn.feedback;

        action performVisualAnalysis {
            in raw : RawDataset;
            in intent : UserIntent;
            out encoding : VisualEncodingSpec;
            out insight : InsightCandidate;
            out explanation : NarrativeExplanation;

            first start;
            then cleanAndProfile;
            then inferAnalyticTask;
            then selectEncoding;
            then detectInsight;
            then composeExplanation;
            then deliverResult;
        }

        state def OperatingState {
            state idle;
            state ingestingData;
            state interpretingIntent;
            state recommendingVisualization;
            state generatingInsights;
            state composingNarrative;
            state awaitingReview;
            state revising;
            state complete;
            state error;

            transition initialize first idle;

            transition receiveDataset
                first idle
                then ingestingData;

            transition dataReady
                first ingestingData
                then interpretingIntent;

            transition intentReady
                first interpretingIntent
                then recommendingVisualization;

            transition encodingReady
                first recommendingVisualization
                then generatingInsights;

            transition insightReady
                first generatingInsights
                then composingNarrative;

            transition explanationReady
                first composingNarrative
                then awaitingReview;

            transition approved
                first awaitingReview
                then complete;

            transition revisionRequested
                first awaitingReview
                then revising;

            transition revisionComplete
                first revising
                then awaitingReview;

            transition invalidData
                first ingestingData
                then error;

            transition ambiguousIntent
                first interpretingIntent
                then error;
        }
    }

    requirement def HumanCenteredVisualizationRequirement {
        subject system : BongshinLeeInspiredVisualAnalyticsSystem;

        require constraint {
            system.primaryFunctionHighLevel ==
            "Convert data and user goals into understandable, accessible visual narratives that support insight, communication, and iterative refinement."
        }
    }

    requirement def DataQualityRequirement {
        subject analyzer : DataQualityAnalyzer;

        require constraint {
            analyzer.minimumQualityScore >= 0.80
        }
    }

    requirement def IntentConfidenceRequirement {
        subject interpreter : IntentInterpreter;

        require constraint {
            interpreter.minimumIntentConfidence >= 0.75
        }
    }

    requirement def ResponsivenessRequirement {
        subject recommender : VisualizationRecommender;

        require constraint {
            recommender.maxRecommendationLatency <= 500.0
        }
    }

    requirement def InsightTrustRequirement {
        subject engine : InsightEngine;

        require constraint {
            engine.minimumEvidenceStrength >= 0.70 and
            engine.maximumMisinterpretationRisk <= 0.25
        }
    }

    requirement def AccessibilityRequirement {
        subject spec : VisualEncodingSpec;

        require constraint {
            spec.accessibilityScore >= 0.85
        }
    }

    requirement def IterativeReviewRequirement {
        subject controller : HumanCenteredReviewController;

        require constraint {
            controller.minimumUserRating >= 4
        }
    }

    satisfy HumanCenteredVisualizationRequirement by BongshinLeeInspiredVisualAnalyticsSystem;
    satisfy DataQualityRequirement by DataQualityAnalyzer;
    satisfy IntentConfidenceRequirement by IntentInterpreter;
    satisfy ResponsivenessRequirement by VisualizationRecommender;
    satisfy InsightTrustRequirement by InsightEngine;
    satisfy AccessibilityRequirement by VisualEncodingSpec;
    satisfy IterativeReviewRequirement by HumanCenteredReviewController;
}