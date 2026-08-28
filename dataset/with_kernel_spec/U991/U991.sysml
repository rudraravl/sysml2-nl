package AutomationBiasMitigationSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    enum def ConfidenceLevel {
        veryLow;
        low;
        medium;
        high;
        veryHigh;
    }

    enum def BiasSeverity {
        minimal;
        moderate;
        significant;
        severe;
        critical;
    }

    enum def DecisionOutcome {
        acceptAutomation;
        rejectAutomation;
        modifyAutomation;
    }

    item def RawSituationData {
        attribute description : String;
        attribute timestamp : String;
        attribute complexityScore : Real;
        attribute urgencyLevel : Real;
    }

    item def ProcessedSituation {
        attribute summary : String;
        attribute keyFactors : String[*];
        attribute riskLevel : Real;
        attribute timestamp : String;
    }

    item def Recommendation {
        attribute suggestedAction : String;
        attribute confidence : ConfidenceLevel;
        attribute rationale : String;
        attribute alternatives : String[*];
    }

    item def OperatorResponse {
        attribute finalDecision : String;
        attribute outcome : DecisionOutcome;
        attribute deliberationTime :> ISQ::time;
        attribute modifications : String [0..1];
    }

    item def BiasAssessment {
        attribute biasMetric : Real;
        attribute severity : BiasSeverity;
        attribute acceptanceRate : Real;
        attribute avgDeliberationTime :> ISQ::time;
        attribute mitigationGuidance : String;
    }

    item def BiasAlert {
        attribute severity : BiasSeverity;
        attribute alertText : String;
        attribute guidance : String;
    }

    item def FinalDecision {
        attribute decision : String;
        attribute source : String;
        attribute compensationFactor : Real := 1.0;
        attribute timestamp : String;
    }

    item def EventLog {
        attribute logId : String;
        attribute situationData : RawSituationData;
        attribute processedSituation : ProcessedSituation;
        attribute recommendation : Recommendation;
        attribute operatorResponse : OperatorResponse;
        attribute biasAssessment : BiasAssessment;
        attribute finalDecision : FinalDecision;
        attribute timestamp : String;
    }

    attribute def DataReceived;
    attribute def CycleComplete;

    calc def ConfidenceToScore {
        in confidence : ConfidenceLevel;
        return : Real =
            if confidence == ConfidenceLevel::veryLow then 0.2
            else if confidence == ConfidenceLevel::low then 0.4
            else if confidence == ConfidenceLevel::medium then 0.6
            else if confidence == ConfidenceLevel::high then 0.8
            else 1.0;
    }

    calc def ComputeBiasMetric {
        in confidenceScore : Real;
        in acceptanceRate : Real;
        in avgDeliberation :> ISQ::time;
        in fastThreshold :> ISQ::time;
        return : Real =
            (acceptanceRate * 0.5) + (confidenceScore * 0.3) +
            (fastThreshold / (avgDeliberation + fastThreshold) * 0.2);
    }

    calc def ClassifySeverity {
        in metric : Real;
        return : BiasSeverity =
            if metric < 0.2 then BiasSeverity::minimal
            else if metric < 0.4 then BiasSeverity::moderate
            else if metric < 0.6 then BiasSeverity::significant
            else if metric < 0.8 then BiasSeverity::severe
            else BiasSeverity::critical;
    }

    calc def DetermineCompensationFactor {
        in biasMetric : Real;
        in severity : BiasSeverity;
        return : Real =
            if severity == BiasSeverity::critical then 0.5
            else if severity == BiasSeverity::severe then 0.6
            else if severity == BiasSeverity::significant then 0.75
            else if severity == BiasSeverity::moderate then 0.9
            else 1.0;
    }

    action def AnalyzeSituation {
        in raw : RawSituationData;
        out processed : ProcessedSituation;
    }

    action def GenerateRecommendation {
        in situation : ProcessedSituation;
        out rec : Recommendation;
    }

    action def CaptureOperatorResponse {
        in rec : Recommendation;
        in alert : BiasAlert [0..*];
        out response : OperatorResponse;
    }

    action def AssessBias {
        in response : OperatorResponse;
        in recommendation : Recommendation;
        in acceptanceRate : Real := 0.5;
        in fastThreshold :> ISQ::time := 2.0 [SI::s];
        out assessment : BiasAssessment;
        out alert : BiasAlert [0..1];
    }

    action def IntegrateDecision {
        in rec : Recommendation;
        in response : OperatorResponse;
        in assessment : BiasAssessment;
        out decision : FinalDecision;
    }

    action def RecordEvent {
        in situationData : RawSituationData;
        in processedSituation : ProcessedSituation;
        in recommendation : Recommendation;
        in operatorResponse : OperatorResponse;
        in biasAssessment : BiasAssessment;
        in finalDecision : FinalDecision;
        out log : EventLog;
    }

    port def RawDataPort {
        in item raw : RawSituationData;
    }

    port def ProcessedSituationPort {
        out item processed : ProcessedSituation;
    }

    port def RecommendationPort {
        out item rec : Recommendation;
    }

    port def ResponsePort {
        out item response : OperatorResponse;
    }

    port def AlertPort {
        in item alert : BiasAlert;
    }

    port def AssessmentPort {
        out item assessment : BiasAssessment;
    }

    port def DecisionPort {
        out item decision : FinalDecision;
    }

    port def LogPort {
        in item log : EventLog;
    }

    part def SituationAnalyzer {
        port dataIn : RawDataPort;
        port situationOut : ProcessedSituationPort;
        attribute processingDelay :> ISQ::time := 0.5 [SI::s];
        action analyze : AnalyzeSituation;
    }

    part def AutomatedAdvisor {
        port situationIn : ~ProcessedSituationPort;
        port recommendationOut : RecommendationPort;
        attribute modelVersion : String := "v2.1";
        action advise : GenerateRecommendation;
    }

    part def OperatorWorkstation {
        port recommendationIn : ~RecommendationPort;
        port alertIn : AlertPort;
        port responseOut : ResponsePort;
        attribute operatorId : String;
        action capture : CaptureOperatorResponse;
    }

    part def BiasMonitor {
        port responseIn : ~ResponsePort;
        port recommendationIn : ~RecommendationPort;
        port alertOut : ~AlertPort;
        port assessmentOut : AssessmentPort;

        attribute responseHistory : OperatorResponse[*] := ();
        attribute acceptanceCount : Integer := 0;
        attribute totalCount : Integer := 0;
        attribute biasThreshold : Real := 0.7;
        attribute fastDeliberationThreshold :> ISQ::time := 2.0 [SI::s];

        action assess : AssessBias;
    }

    part def DecisionIntegrator {
        port recommendationIn : ~RecommendationPort;
        port responseIn : ~ResponsePort;
        port assessmentIn : ~AssessmentPort;
        port decisionOut : DecisionPort;

        attribute defaultCompensationFactor : Real := 1.0;
        attribute biasThreshold : Real := 0.5;

        action integrate : IntegrateDecision;
    }

    part def EventRecorder {
        port logIn : LogPort;
        attribute logs : EventLog[*] := ();
        attribute maxLogs : Integer := 10000;
        action record : RecordEvent;
    }

    part def DecisionSupportSystem {
        part situationAnalyzer : SituationAnalyzer;
        part automatedAdvisor : AutomatedAdvisor;
        part operatorWorkstation : OperatorWorkstation;
        part biasMonitor : BiasMonitor;
        part decisionIntegrator : DecisionIntegrator;
        part eventRecorder : EventRecorder;

        connect situationAnalyzer.situationOut to automatedAdvisor.situationIn;
        connect automatedAdvisor.recommendationOut to operatorWorkstation.recommendationIn;
        connect operatorWorkstation.responseOut to biasMonitor.responseIn;
        connect automatedAdvisor.recommendationOut to biasMonitor.recommendationIn;
        connect biasMonitor.alertOut to operatorWorkstation.alertIn;
        connect biasMonitor.assessmentOut to decisionIntegrator.assessmentIn;
        connect automatedAdvisor.recommendationOut to decisionIntegrator.recommendationIn;
        connect operatorWorkstation.responseOut to decisionIntegrator.responseIn;
        connect decisionIntegrator.decisionOut to eventRecorder.logIn;
    }

    action def DecisionCycle {
        in rawData : RawSituationData;
        out finalDecision : FinalDecision;
        out biasAlert : BiasAlert [0..1];
        out eventLog : EventLog;

        first start;
        then action analyze : AnalyzeSituation {
            in raw = rawData;
        }
        then action advise : GenerateRecommendation {
            in situation = analyze.processed;
        }
        then action capture : CaptureOperatorResponse {
            in rec = advise.rec;
        }
        then action assess : AssessBias {
            in response = capture.response;
            in recommendation = advise.rec;
        }
        then action integrate : IntegrateDecision {
            in rec = advise.rec;
            in response = capture.response;
            in assessment = assess.assessment;
        }
        then action record : RecordEvent {
            in situationData = rawData;
            in processedSituation = analyze.processed;
            in recommendation = advise.rec;
            in operatorResponse = capture.response;
            in biasAssessment = assess.assessment;
            in finalDecision = integrate.decision;
        }
        then done;

        bind finalDecision = integrate.decision;
        bind biasAlert = assess.alert;
        bind eventLog = record.log;
    }

    state def SystemOperation {
        attribute cycleCount : Integer := 0;

        entry assign cycleCount := 0;
        then state waiting;

        accept DataReceived
            then analyzing;

        state waiting;

        state analyzing;
        then advising;

        state advising;
        then capturing;

        state capturing;
        then assessing;

        state assessing;
        then integrating;

        state integrating;
        then recording;

        state recording {
            entry assign cycleCount := cycleCount + 1;
        }
        then waiting;
    }

    requirement def MitigateAutomationBias {
        doc
        /*
         * The system shall mitigate automation bias in human-automation teams
         * by monitoring operator behavior and providing corrective feedback.
         */
    }

    requirement def CaptureOperatorEngagement {
        subject system : DecisionSupportSystem;
        doc
        /*
         * The system shall capture the operator's final decision,
         * whether they accepted the automation's advice, and
         * how long they took to deliberate.
         */
    }

    requirement def DetectBiasEmergence {
        subject system : DecisionSupportSystem;
        doc
        /*
         * The system shall detect emerging automation bias based on
         * the automation's confidence, the operator's acceptance rate
         * over time, and their deliberation speed.
         */
    }

    requirement def IssueAlerts {
        subject system : DecisionSupportSystem;
        doc
        /*
         * The system shall issue alerts to the operator's workstation
         * proportional to the severity of detected bias, prompting
         * them to be more diligent or providing mitigation guidance.
         */
    }

    requirement def ApplyCompensationFactor {
        subject system : DecisionSupportSystem;
        doc
        /*
         * The decision integrator shall apply a compensation factor
         * giving more weight to the operator's judgment when a
         * high level of bias has been detected.
         */
    }

    requirement def LogCompleteEvent {
        subject system : DecisionSupportSystem;
        doc
        /*
         * The system shall log the complete event, from initial data
         * to final decision, including the operator's response and
         * the calculated bias level, for later analysis and training.
         */
    }

    requirement biasMitigation : MitigateAutomationBias;
    requirement captureEngagement : CaptureOperatorEngagement;
    requirement detectBias : DetectBiasEmergence;
    requirement issueAlerts : IssueAlerts;
    requirement applyCompensation : ApplyCompensationFactor;
    requirement logEvent : LogCompleteEvent;
}
