package NeuroethicsGovernanceSystem {
    private import ScalarValues::*;
    private import NumericalFunctions::*;

    attribute def EthicalScore :> Real;
    attribute def RiskLevel :> Real;

    item def NeuralData {
        attribute dataId : String;
        attribute participantId : String;
        attribute rawSignal : String;
        attribute isAnonymized : Boolean = false;
        attribute isEncrypted : Boolean = false;
    }

    item def ConsentRecord {
        attribute recordId : String;
        attribute participantId : String;
        attribute consentGranted : Boolean;
        attribute withdrawalRequested : Boolean = false;
    }

    item def PrivacyAssessment {
        attribute riskScore : RiskLevel;
        attribute passed : Boolean;
    }

    item def EthicalEvaluation {
        attribute privacyScore : EthicalScore;
        attribute autonomyScore : EthicalScore;
        attribute beneficenceScore : EthicalScore;
        attribute justiceScore : EthicalScore;
        attribute overallScore : EthicalScore;
        attribute recommendation : String;
    }

    item def AlertNotification {
        attribute alertId : String;
        attribute violationType : String;
        attribute severity : String;
        attribute description : String;
    }

    item def MonitoringEvent {
        attribute eventId : String;
        attribute eventType : String;
        attribute isViolation : Boolean;
    }

    item def DataUsageContext {
        attribute purpose : String;
        attribute researcherId : String;
        attribute institution : String;
    }

    port def NeuralDataInput { in item data : NeuralData; }
    port def NeuralDataOutput { out item data : NeuralData; }
    port def ConsentRecordPort { out item record : ConsentRecord; }
    port def PrivacyAssessmentPort { out item assessment : PrivacyAssessment; }
    port def EthicalEvaluationPort { out item evaluation : EthicalEvaluation; }
    port def AlertPort { out item alert : AlertNotification; }
    port def MonitoringEventPort { in item evt : MonitoringEvent; }
    port def DataUsageContextPort { in item context : DataUsageContext; }

    calc def ComputeOverallScore {
        in privacy : EthicalScore;
        in autonomy : EthicalScore;
        in beneficence : EthicalScore;
        in justice : EthicalScore;
        return overall : EthicalScore = 0.25 * privacy + 0.25 * autonomy + 0.25 * beneficence + 0.25 * justice;
    }

    action def AnonymizeAction {
        in data : NeuralData;
        out result : NeuralData;
    }

    action def EncryptAction {
        in data : NeuralData;
        out result : NeuralData;
    }

    action def ScorePrivacyAction {
        in data : NeuralData;
        in context : DataUsageContext;
        out score : EthicalScore;
    }

    action def ScoreAutonomyAction {
        in data : NeuralData;
        in context : DataUsageContext;
        out score : EthicalScore;
    }

    action def ScoreBeneficenceAction {
        in data : NeuralData;
        in context : DataUsageContext;
        out score : EthicalScore;
    }

    action def ScoreJusticeAction {
        in data : NeuralData;
        in context : DataUsageContext;
        out score : EthicalScore;
    }

    action def GenerateAlertAction {
        in evt : MonitoringEvent;
        out alert : AlertNotification;
    }

    state machine def ConsentStates {
        state Validating {
            transition to Granted;
            transition to Rejected;
        }
        state Granted;
        state Rejected;
    }

    state machine def MonitoringStates {
        state Monitoring {
            transition to ViolationDetected;
        }
        state ViolationDetected {
            transition to Monitoring;
        }
    }

    part def ConsentManagementModule {
        port consentIn : NeuralDataInput;
        port consentOut : NeuralDataOutput;
        port recordOut : ConsentRecordPort;
        attribute consentDatabase : ConsentRecord[0..*];
        attribute validatedCount : Integer = 0;
        attribute rejectedCount : Integer = 0;
        exhibit ConsentStates;
    }

    part def DataPrivacyModule {
        port privacyIn : NeuralDataInput;
        port privacyOut : NeuralDataOutput;
        port assessmentOut : PrivacyAssessmentPort;
        attribute riskThreshold : RiskLevel = 30.0;
        action processData {
            in rawData : NeuralData;
            out securedData : NeuralData;
            first start;
            then action anon : AnonymizeAction {
                in data = rawData;
            }
            then action enc : EncryptAction {
                in data = anon.result;
            }
            then bind securedData = enc.result;
            then done;
        }
    }

    part def EthicalReviewEngine {
        port reviewIn : NeuralDataInput;
        port contextIn : DataUsageContextPort;
        port evaluationOut : EthicalEvaluationPort;
        attribute approvalThreshold : EthicalScore = 75.0;
        attribute humanReviewThreshold : EthicalScore = 50.0;
        action evaluateData {
            in data : NeuralData;
            in context : DataUsageContext;
            out evaluation : EthicalEvaluation;
            first start;
            then action scoreP : ScorePrivacyAction {
                in data = data;
                in context = context;
            }
            then action scoreA : ScoreAutonomyAction {
                in data = data;
                in context = context;
            }
            then action scoreB : ScoreBeneficenceAction {
                in data = data;
                in context = context;
            }
            then action scoreJ : ScoreJusticeAction {
                in data = data;
                in context = context;
            }
            then calc computeOverall : ComputeOverallScore {
                in privacy = scoreP.score;
                in autonomy = scoreA.score;
                in beneficence = scoreB.score;
                in justice = scoreJ.score;
            }
            then done;
        }
    }

    part def ContinuousMonitoringModule {
        port monitoringIn : NeuralDataInput;
        port evtIn : MonitoringEventPort;
        port alertOut : AlertPort;
        attribute activeViolations : Integer = 0;
        attribute monitoringActive : Boolean = true;
        exhibit MonitoringStates;
    }

    part def NeuroethicsGovernanceSystem {
        part consentModule : ConsentManagementModule;
        part privacyModule : DataPrivacyModule;
        part reviewEngine : EthicalReviewEngine;
        part monitoringModule : ContinuousMonitoringModule;

        port systemInput : NeuralDataInput;
        port systemContextInput : DataUsageContextPort;
        port systemAlertOutput : AlertPort;
        port systemEvaluationOutput : EthicalEvaluationPort;
        port systemPrivacyAssessmentOutput : PrivacyAssessmentPort;

        connect systemInput to consentModule.consentIn;
        connect consentModule.consentOut to privacyModule.privacyIn;
        connect privacyModule.privacyOut to reviewEngine.reviewIn;
        connect systemContextInput to reviewEngine.contextIn;
        connect reviewEngine.reviewIn to monitoringModule.monitoringIn;
        connect monitoringModule.alertOut to systemAlertOutput;
        connect reviewEngine.evaluationOut to systemEvaluationOutput;
        connect privacyModule.assessmentOut to systemPrivacyAssessmentOutput;
    }

    part governanceSystem : NeuroethicsGovernanceSystem;

    requirement def ConsentVerificationRequirement {
        text "All neural data must have valid informed consent before processing.";
        attribute id : String = "REQ-CONSENT-001";
    }

    requirement def DataAnonymizationRequirement {
        text "Neural data must be anonymized to remove personal identifiers before further processing.";
        attribute id : String = "REQ-PRIVACY-001";
    }

    requirement def EthicalPrinciplesEvaluationRequirement {
        text "The system shall evaluate data usage against privacy, autonomy, beneficence, and justice principles.";
        attribute id : String = "REQ-ETHICS-001";
    }

    requirement def ContinuousMonitoringRequirement {
        text "Approved data usage must be continuously monitored for ethical compliance violations.";
        attribute id : String = "REQ-MONITOR-001";
    }

    requirement def ViolationAlertingRequirement {
        text "Any detected ethical violation shall trigger an immediate alert with details for intervention.";
        attribute id : String = "REQ-MONITOR-002";
    }

    requirement consentReq : ConsentVerificationRequirement {
        subject = governanceSystem.consentModule;
    }

    requirement anonymizationReq : DataAnonymizationRequirement {
        subject = governanceSystem.privacyModule;
    }

    requirement ethicalEvalReq : EthicalPrinciplesEvaluationRequirement {
        subject = governanceSystem.reviewEngine;
    }

    requirement monitoringReq : ContinuousMonitoringRequirement {
        subject = governanceSystem.monitoringModule;
    }

    requirement alertingReq : ViolationAlertingRequirement {
        subject = governanceSystem.monitoringModule;
    }
}
