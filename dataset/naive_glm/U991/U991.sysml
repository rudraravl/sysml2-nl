package AutomationBiasMitigationSystem {

    value type TimeDuration :> Real { unit 's'; }
    value type AcceptanceRate :> Real { unit 'percent'; }
    value type BiasMetricValue :> Real { unit '1'; }
    value type CompensationFactor :> Real { unit '1'; }

    enum def ConfidenceLevel { veryLow; low; medium; high; veryHigh; }
    enum def BiasSeverity { minimal; low; moderate; high; critical; }

    item def RawData {
        attribute source : String;
        attribute timestamp : TimeDuration;
        attribute content : String;
        attribute priority : Integer;
    }

    item def ProcessedInfo {
        attribute summary : String;
        attribute context : String;
        attribute urgency : Integer;
        attribute keyFactors : String;
    }

    item def Recommendation {
        attribute suggestedAction : String;
        attribute confidence : ConfidenceLevel;
        attribute rationale : String;
        attribute alternatives : String;
    }

    item def OperatorResponse {
        attribute finalDecision : String;
        attribute acceptedAdvice : Boolean;
        attribute deliberationTime : TimeDuration;
        attribute comments : String;
    }

    item def BiasAssessment {
        attribute biasMetric : BiasMetricValue;
        attribute severity : BiasSeverity;
        attribute acceptanceRate : AcceptanceRate;
        attribute averageDeliberationTime : TimeDuration;
        attribute trend : String;
    }

    item def FinalDecision {
        attribute decision : String;
        attribute compensationApplied : Boolean;
        attribute compensationFactor : CompensationFactor;
        attribute rationale : String;
    }

    item def EventRecord {
        attribute recordId : String;
        attribute rawData : RawData;
        attribute processedInfo : ProcessedInfo;
        attribute recommendation : Recommendation;
        attribute operatorResponse : OperatorResponse;
        attribute biasAssessment : BiasAssessment;
        attribute finalDecision : FinalDecision;
        attribute timestamp : TimeDuration;
    }

    item def AlertMessage {
        attribute text : String;
        attribute severity : BiasSeverity;
        attribute guidance : String;
    }

    interface def RawDataPort {
        out item data : RawData;
    }

    interface def ProcessedInfoPort {
        out item info : ProcessedInfo;
    }

    interface def RecommendationPort {
        out item rec : Recommendation;
    }

    interface def OperatorResponsePort {
        out item response : OperatorResponse;
    }

    interface def BiasAssessmentPort {
        out item assessment : BiasAssessment;
    }

    interface def FinalDecisionPort {
        out item decision : FinalDecision;
    }

    interface def EventRecordPort {
        out item record : EventRecord;
    }

    interface def AlertPort {
        out item alert : AlertMessage;
    }

    part def SituationAnalyzer {
        port dataIn : RawDataPort;
        port infoOut : ProcessedInfoPort;

        attribute processingLatency : TimeDuration = 0.5;

        action def AnalyzeSituation {
            in raw : RawData;
            out info : ProcessedInfo;
        }

        action analyze : AnalyzeSituation {
            in raw = dataIn.data;
            out info = infoOut.info;
        }

        perform action analyze {
            info.summary = "Processed summary of " + raw.content;
            info.context = "Derived context from source " + raw.source;
            info.urgency = raw.priority;
            info.keyFactors = "Extracted key factors from raw data";
        }
    }

    part def AutomatedAdvisor {
        port infoIn : ProcessedInfoPort;
        port recOut : RecommendationPort;

        attribute expertiseLevel : String = "ExpertSystem";

        action def GenerateRecommendation {
            in info : ProcessedInfo;
            out rec : Recommendation;
        }

        action generate : GenerateRecommendation {
            in info = infoIn.info;
            out rec = recOut.rec;
        }

        perform action generate {
            rec.suggestedAction = "Recommended action for urgency " + info.urgency.toString();
            rec.confidence = (info.urgency > 7) ? ConfidenceLevel::high : ConfidenceLevel::medium;
            rec.rationale = "Based on context: " + info.context;
            rec.alternatives = "Alternative action A; Alternative action B";
        }
    }

    part def OperatorWorkstation {
        port recIn : RecommendationPort;
        port responseOut : OperatorResponsePort;
        port alertIn : AlertPort;
        port assessmentIn : BiasAssessmentPort;

        attribute operatorId : String = "OP-001";
        attribute displayedRecommendation : Recommendation;
        attribute capturedResponse : OperatorResponse;
        attribute lastAlert : AlertMessage;

        action def DisplayRecommendation {
            in rec : Recommendation;
        }

        action def CaptureResponse {
            out response : OperatorResponse;
        }

        action display : DisplayRecommendation {
            in rec = recIn.rec;
        }

        action capture : CaptureResponse {
            out response = responseOut.response;
        }

        perform action display {
            displayedRecommendation = rec;
        }

        perform action capture {
            response.finalDecision = "Operator decision based on " + displayedRecommendation.suggestedAction;
            response.acceptedAdvice = (displayedRecommendation.confidence == ConfidenceLevel::high) ? true : false;
            response.deliberationTime = 3.2;
            response.comments = "Operator reviewed rationale";
        }

        state machine def OperatorInteraction {
            state Idle;
            state Reviewing;
            state Deliberating;
            state Responded;

            transition idle_to_reviewing first Idle to Reviewing
                when recIn.rec.received;

            transition reviewing_to_deliberating Reviewing to Deliberating
                when displayedRecommendation.confidence != ConfidenceLevel::veryLow;

            transition deliberating_to_responded Deliberating to Responded
                when capture.response.sent;

            transition responded_to_idle Responded to Idle
                when responseOut.response.delivered;
        }

        state machine :>> OperatorInteraction;
    }

    part def BiasMonitor {
        port responseIn : OperatorResponsePort;
        port recIn : RecommendationPort;
        port assessmentOut : BiasAssessmentPort;
        port alertOut : AlertPort;

        attribute windowSize : Integer = 20;
        attribute acceptanceCount : Integer = 0;
        attribute totalResponses : Integer = 0;
        attribute totalDeliberationTime : TimeDuration = 0;
        attribute currentBiasMetric : BiasMetricValue = 0.0;
        attribute currentSeverity : BiasSeverity = BiasSeverity::minimal;
        attribute thresholdLow : BiasMetricValue = 0.3;
        attribute thresholdModerate : BiasMetricValue = 0.5;
        attribute thresholdHigh : BiasMetricValue = 0.7;
        attribute thresholdCritical : BiasMetricValue = 0.85;

        action def UpdateBiasMetric {
            in response : OperatorResponse;
            in rec : Recommendation;
            out assessment : BiasAssessment;
            out alert : AlertMessage;
        }

        action update : UpdateBiasMetric {
            in response = responseIn.response;
            in rec = recIn.rec;
            out assessment = assessmentOut.assessment;
            out alert = alertOut.alert;
        }

        perform action update {
            totalResponses = totalResponses + 1;
            if response.acceptedAdvice {
                acceptanceCount = acceptanceCount + 1;
            }
            totalDeliberationTime = totalDeliberationTime + response.deliberationTime;

            attribute acceptanceRate : AcceptanceRate = (acceptanceCount / totalResponses) * 100.0;
            attribute avgDeliberation : TimeDuration = totalDeliberationTime / totalResponses;

            attribute confidenceWeight : Real = 
                (rec.confidence == ConfidenceLevel::veryHigh) ? 1.0 :
                (rec.confidence == ConfidenceLevel::high) ? 0.8 :
                (rec.confidence == ConfidenceLevel::medium) ? 0.6 :
                (rec.confidence == ConfidenceLevel::low) ? 0.4 : 0.2;

            attribute speedFactor : Real = (response.deliberationTime < 2.0) ? 0.8 : 0.2;
            attribute acceptanceFactor : Real = (acceptanceRate > 80.0) ? 0.8 : 0.3;

            currentBiasMetric = (acceptanceFactor * 0.5) + (speedFactor * 0.3) + (confidenceWeight * 0.2);

            currentSeverity = 
                (currentBiasMetric >= thresholdCritical) ? BiasSeverity::critical :
                (currentBiasMetric >= thresholdHigh) ? BiasSeverity::high :
                (currentBiasMetric >= thresholdModerate) ? BiasSeverity::moderate :
                (currentBiasMetric >= thresholdLow) ? BiasSeverity::low : BiasSeverity::minimal;

            assessment.biasMetric = currentBiasMetric;
            assessment.severity = currentSeverity;
            assessment.acceptanceRate = acceptanceRate;
            assessment.averageDeliberationTime = avgDeliberation;
            assessment.trend = (currentBiasMetric > 0.5) ? "increasing" : "stable";

            alert.severity = currentSeverity;
            alert.text = "Automation bias alert: severity " + currentSeverity.toString();
            alert.guidance = (currentSeverity == BiasSeverity::critical) ? 
                "Pause and independently verify the recommendation before accepting." :
                "Take additional time to review the rationale and alternatives.";
        }

        state machine def BiasDetectionStates {
            state Nominal;
            state Watch;
            state Intervene;
            state CriticalIntervention;

            transition nominal_to_watch Nominal to Watch
                when currentBiasMetric >= thresholdLow;

            transition watch_to_intervene Watch to Intervene
                when currentBiasMetric >= thresholdModerate;

            transition intervene_to_critical Intervene to CriticalIntervention
                when currentBiasMetric >= thresholdCritical;

            transition critical_to_watch CriticalIntervention to Watch
                when currentBiasMetric < thresholdHigh;

            transition watch_to_nominal Watch to Nominal
                when currentBiasMetric < thresholdLow;
        }

        state machine :>> BiasDetectionStates;
    }

    part def DecisionIntegrator {
        port recIn : RecommendationPort;
        port responseIn : OperatorResponsePort;
        port assessmentIn : BiasAssessmentPort;
        port decisionOut : FinalDecisionPort;

        attribute defaultCompensationFactor : CompensationFactor = 1.0;
        attribute criticalCompensationFactor : CompensationFactor = 1.5;
        attribute highCompensationFactor : CompensationFactor = 1.25;

        action def IntegrateDecision {
            in rec : Recommendation;
            in response : OperatorResponse;
            in assessment : BiasAssessment;
            out decision : FinalDecision;
        }

        action integrate : IntegrateDecision {
            in rec = recIn.rec;
            in response = responseIn.response;
            in assessment = assessmentIn.assessment;
            out decision = decisionOut.decision;
        }

        perform action integrate {
            attribute factor : CompensationFactor = 
                (assessment.severity == BiasSeverity::critical) ? criticalCompensationFactor :
                (assessment.severity == BiasSeverity::high) ? highCompensationFactor :
                defaultCompensationFactor;

            decision.compensationApplied = (factor > defaultCompensationFactor);
            decision.compensationFactor = factor;

            if assessment.severity == BiasSeverity::critical || assessment.severity == BiasSeverity::high {
                decision.decision = response.finalDecision;
                decision.rationale = "Operator judgment weighted by factor " + factor.toString() + " due to detected bias.";
            } else {
                decision.decision = response.acceptedAdvice ? rec.suggestedAction : response.finalDecision;
                decision.rationale = "Standard integration of operator response and recommendation.";
            }
        }
    }

    part def EventRecorder {
        port dataIn : RawDataPort;
        port infoIn : ProcessedInfoPort;
        port recIn : RecommendationPort;
        port responseIn : OperatorResponsePort;
        port assessmentIn : BiasAssessmentPort;
        port decisionIn : FinalDecisionPort;
        port recordOut : EventRecordPort;

        attribute recordCount : Integer = 0;
        attribute storageCapacity : Integer = 100000;

        action def RecordEvent {
            in data : RawData;
            in info : ProcessedInfo;
            in rec : Recommendation;
            in response : OperatorResponse;
            in assessment : BiasAssessment;
            in decision : FinalDecision;
            out record : EventRecord;
        }

        action record : RecordEvent {
            in data = dataIn.data;
            in info = infoIn.info;
            in rec = recIn.rec;
            in response = responseIn.response;
            in assessment = assessmentIn.assessment;
            in decision = decisionIn.decision;
            out record = recordOut.record;
        }

        perform action record {
            recordCount = recordCount + 1;
            record.recordId = "REC-" + recordCount.toString();
            record.rawData = data;
            record.processedInfo = info;
            record.recommendation = rec;
            record.operatorResponse = response;
            record.biasAssessment = assessment;
            record.finalDecision = decision;
            record.timestamp = data.timestamp;
        }
    }

    part def AutomationBiasMitigationSystem {
        port externalDataIn : RawDataPort;
        port externalDecisionOut : FinalDecisionPort;
        port externalRecordOut : EventRecordPort;

        part situationAnalyzer : SituationAnalyzer {
            port dataIn = externalDataIn;
        }

        part automatedAdvisor : AutomatedAdvisor {
            port infoIn = situationAnalyzer.infoOut;
        }

        part operatorWorkstation : OperatorWorkstation {
            port recIn = automatedAdvisor.recOut;
        }

        part biasMonitor : BiasMonitor {
            port responseIn = operatorWorkstation.responseOut;
            port recIn = automatedAdvisor.recOut;
            port alertOut = operatorWorkstation.alertIn;
            port assessmentOut = operatorWorkstation.assessmentIn;
        }

        part decisionIntegrator : DecisionIntegrator {
            port recIn = automatedAdvisor.recOut;
            port responseIn = operatorWorkstation.responseOut;
            port assessmentIn = biasMonitor.assessmentOut;
            port decisionOut = externalDecisionOut;
        }

        part eventRecorder : EventRecorder {
            port dataIn = externalDataIn;
            port infoIn = situationAnalyzer.infoOut;
            port recIn = automatedAdvisor.recOut;
            port responseIn = operatorWorkstation.responseOut;
            port assessmentIn = biasMonitor.assessmentOut;
            port decisionIn = decisionIntegrator.decisionOut;
            port recordOut = externalRecordOut;
        }

        connection situationToAdvisor connect situationAnalyzer.infoOut to automatedAdvisor.infoIn;
        connection advisorToWorkstation connect automatedAdvisor.recOut to operatorWorkstation.recIn;
        connection workstationToMonitor connect operatorWorkstation.responseOut to biasMonitor.responseIn;
        connection advisorToMonitor connect automatedAdvisor.recOut to biasMonitor.recIn;
        connection monitorToWorkstationAlert connect biasMonitor.alertOut to operatorWorkstation.alertIn;
        connection monitorToWorkstationAssessment connect biasMonitor.assessmentOut to operatorWorkstation.assessmentIn;
        connection monitorToIntegrator connect biasMonitor.assessmentOut to decisionIntegrator.assessmentIn;
        connection advisorToIntegrator connect automatedAdvisor.recOut to decisionIntegrator.recIn;
        connection workstationToIntegrator connect operatorWorkstation.responseOut to decisionIntegrator.responseIn;
        connection integratorToRecorder connect decisionIntegrator.decisionOut to eventRecorder.decisionIn;
        connection monitorToRecorder connect biasMonitor.assessmentOut to eventRecorder.assessmentIn;
        connection workstationToRecorder connect operatorWorkstation.responseOut to eventRecorder.responseIn;
        connection advisorToRecorder connect automatedAdvisor.recOut to eventRecorder.recIn;
        connection analyzerToRecorder connect situationAnalyzer.infoOut to eventRecorder.infoIn;
        connection dataToRecorder connect externalDataIn to eventRecorder.dataIn;
    }

    requirement def MaintainCriticalEngagement {
        subject : AutomationBiasMitigationSystem;
        objective {
            doc "The system shall ensure operators remain critically engaged and avoid blind trust in automated recommendations.";
        }
    }

    requirement def DetectAutomationBias {
        subject : BiasMonitor;
        objective {
            doc "The system shall detect emerging automation bias based on acceptance rate, deliberation speed, and automation confidence.";
        }
    }

    requirement def IssueBiasAlerts {
        subject : BiasMonitor;
        objective {
            doc "The system shall issue alerts to the operator workstation when automation bias severity exceeds low.";
        }
    }

    requirement def ApplyCompensationFactor {
        subject : DecisionIntegrator;
        objective {
            doc "The decision integrator shall apply a compensation factor when high or critical bias is detected.";
        }
    }

    requirement def LogCompleteEvent {
        subject : EventRecorder;
        objective {
            doc "The event recorder shall log raw data, processed info, recommendation, operator response, bias assessment, and final decision for every event.";
        }
    }

    requirement def CaptureOperatorDeliberation {
        subject : OperatorWorkstation;
        objective {
            doc "The operator workstation shall capture the operator's final decision, acceptance of advice, and deliberation time.";
        }
    }

    requirement def ProvideRecommendationWithRationale {
        subject : AutomatedAdvisor;
        objective {
            doc "The automated advisor shall provide a recommendation including suggested action, confidence level, and rationale.";
        }
    }

    requirement satisfaction MaintainCriticalEngagement satisfied by biasMonitor;
    requirement satisfaction DetectAutomationBias satisfied by biasMonitor;
    requirement satisfaction IssueBiasAlerts satisfied by biasMonitor;
    requirement satisfaction ApplyCompensationFactor satisfied by decisionIntegrator;
    requirement satisfaction LogCompleteEvent satisfied by eventRecorder;
    requirement satisfaction CaptureOperatorDeliberation satisfied by operatorWorkstation;
    requirement satisfaction ProvideRecommendationWithRationale satisfied by automatedAdvisor;
}
