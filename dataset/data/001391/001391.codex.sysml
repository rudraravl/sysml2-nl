package CyberEthicsSystemModel {
    import ScalarValues::*;
    import SI::*;

    enum def ConsentState {
        enum granted;
        enum denied;
        enum expired;
        enum unknown;
    }

    enum def EthicalRiskLevel {
        enum negligible;
        enum low;
        enum moderate;
        enum high;
        enum unacceptable;
    }

    enum def EnforcementDecision {
        enum allow;
        enum warn;
        enum restrict;
        enum block;
        enum escalate;
    }

    attribute def EthicalRiskScore : Real {
        range 0.0 .. 100.0;
    }

    attribute def ConfidenceScore : Real {
        range 0.0 .. 1.0;
    }

    attribute def ProcessingLatency : Real {
        unit = "ms";
    }

    item def DigitalAction {
        attribute actorId : String;
        attribute systemId : String;
        attribute actionName : String;
        attribute targetResource : String;
        attribute declaredPurpose : String;
        attribute timestamp : String;
    }

    item def PersonalData {
        attribute dataSubjectId : String;
        attribute category : String;
        attribute sensitivity : EthicalRiskLevel;
        attribute consent : ConsentState;
        attribute retentionDays : Integer;
    }

    item def EthicalAssessment {
        attribute riskScore : EthicalRiskScore;
        attribute riskLevel : EthicalRiskLevel;
        attribute confidence : ConfidenceScore;
        attribute rationale : String;
        attribute assessedAt : String;
    }

    item def EthicsPolicy {
        attribute policyId : String;
        attribute name : String;
        attribute principle : String;
        attribute maximumPermittedRisk : EthicalRiskLevel;
        attribute requiresHumanReview : Boolean;
    }

    item def EnforcementInstruction {
        attribute decision : EnforcementDecision;
        attribute reason : String;
        attribute requiredRemediation : String;
    }

    item def AuditRecord {
        attribute recordId : String;
        attribute actorId : String;
        attribute actionName : String;
        attribute decision : EnforcementDecision;
        attribute riskScore : EthicalRiskScore;
        attribute immutableHash : String;
    }

    port def ActionObservationPort {
        in observedAction : DigitalAction;
        in relatedData : PersonalData;
    }

    port def PolicyInputPort {
        in activePolicy : EthicsPolicy;
    }

    port def AssessmentPort {
        out assessment : EthicalAssessment;
    }

    port def EnforcementPort {
        out instruction : EnforcementInstruction;
    }

    port def AuditPort {
        out auditRecord : AuditRecord;
    }

    part def CyberEthicsGovernanceSystem {
        attribute primaryFunction : String = "Evaluate digital actions against cyberethical principles and produce enforceable guidance that protects privacy, autonomy, fairness, accountability, and human oversight.";
        attribute maximumAssessmentLatency : ProcessingLatency = 250.0;

        port actionObservation : ActionObservationPort;
        port policyInput : PolicyInputPort;
        port assessmentOutput : AssessmentPort;
        port enforcementOutput : EnforcementPort;
        port auditOutput : AuditPort;

        part actionCollector : ActionCollector;
        part consentVerifier : ConsentVerifier;
        part policyRepository : EthicsPolicyRepository;
        part riskAnalyzer : EthicalRiskAnalyzer;
        part decisionEngine : EthicalDecisionEngine;
        part humanReviewGateway : HumanReviewGateway;
        part auditLedger : AuditLedger;

        connect actionObservation to actionCollector.observationInput;
        connect policyInput to policyRepository.policyInput;
        connect actionCollector.actionOutput to consentVerifier.actionInput;
        connect actionCollector.dataOutput to consentVerifier.dataInput;
        connect consentVerifier.verifiedActionOutput to riskAnalyzer.actionInput;
        connect consentVerifier.verifiedDataOutput to riskAnalyzer.dataInput;
        connect policyRepository.policyOutput to riskAnalyzer.policyInput;
        connect riskAnalyzer.assessmentOutput to decisionEngine.assessmentInput;
        connect policyRepository.policyOutput to decisionEngine.policyInput;
        connect decisionEngine.reviewRequestOutput to humanReviewGateway.reviewInput;
        connect humanReviewGateway.reviewDecisionOutput to decisionEngine.reviewDecisionInput;
        connect riskAnalyzer.assessmentOutput to assessmentOutput;
        connect decisionEngine.enforcementOutput to enforcementOutput;
        connect decisionEngine.auditEventOutput to auditLedger.auditInput;
        connect auditLedger.auditOutput to auditOutput;
    }

    part def ActionCollector {
        port observationInput : ActionObservationPort;
        port actionOutput {
            out action : DigitalAction;
        }
        port dataOutput {
            out data : PersonalData;
        }
    }

    part def ConsentVerifier {
        port actionInput {
            in action : DigitalAction;
        }
        port dataInput {
            in data : PersonalData;
        }
        port verifiedActionOutput {
            out action : DigitalAction;
        }
        port verifiedDataOutput {
            out data : PersonalData;
        }

        attribute rejectsUnknownConsent : Boolean = true;
    }

    part def EthicsPolicyRepository {
        port policyInput : PolicyInputPort;
        port policyOutput {
            out policy : EthicsPolicy;
        }

        attribute policyVersion : String;
        attribute updateIntervalHours : Integer = 24;
    }

    part def EthicalRiskAnalyzer {
        port actionInput {
            in action : DigitalAction;
        }
        port dataInput {
            in data : PersonalData;
        }
        port policyInput {
            in policy : EthicsPolicy;
        }
        port assessmentOutput : AssessmentPort;

        attribute privacyWeight : Real = 0.30;
        attribute fairnessWeight : Real = 0.25;
        attribute autonomyWeight : Real = 0.20;
        attribute accountabilityWeight : Real = 0.15;
        attribute safetyWeight : Real = 0.10;
    }

    part def EthicalDecisionEngine {
        port assessmentInput {
            in assessment : EthicalAssessment;
        }
        port policyInput {
            in policy : EthicsPolicy;
        }
        port reviewDecisionInput {
            in decision : EnforcementInstruction;
        }
        port reviewRequestOutput {
            out assessment : EthicalAssessment;
        }
        port enforcementOutput : EnforcementPort;
        port auditEventOutput {
            out auditRecord : AuditRecord;
        }

        attribute humanReviewThreshold : EthicalRiskLevel = EthicalRiskLevel::high;
    }

    part def HumanReviewGateway {
        port reviewInput {
            in assessment : EthicalAssessment;
        }
        port reviewDecisionOutput {
            out decision : EnforcementInstruction;
        }

        attribute reviewerRole : String = "Cyberethics Officer";
        attribute maximumReviewTimeHours : Integer = 8;
    }

    part def AuditLedger {
        port auditInput {
            in auditRecord : AuditRecord;
        }
        port auditOutput : AuditPort;

        attribute appendOnly : Boolean = true;
        attribute retentionYears : Integer = 7;
    }

    action def AssessCyberEthics {
        in action : DigitalAction;
        in data : PersonalData;
        in policy : EthicsPolicy;
        out assessment : EthicalAssessment;

        action verifyConsent;
        action evaluatePrivacyImpact;
        action evaluateFairnessImpact;
        action evaluateAutonomyImpact;
        action evaluateAccountability;
        action calculateRiskScore;
        action classifyRiskLevel;
    }

    action def DecideEnforcement {
        in assessment : EthicalAssessment;
        in policy : EthicsPolicy;
        out instruction : EnforcementInstruction;

        action compareRiskToPolicy;
        action determineHumanReviewNeed;
        action selectDecision;
        action generateRemediation;
        action createAuditRecord;
    }

    state def CyberEthicsGovernanceLifecycle {
        state idle;
        state collectingEvidence;
        state verifyingConsent;
        state assessingEthicalRisk;
        state decidingEnforcement;
        state waitingForHumanReview;
        state issuingInstruction;
        state recordingAudit;
        state completed;

        transition first idle then collectingEvidence;
        transition collectingEvidence then verifyingConsent;
        transition verifyingConsent then assessingEthicalRisk;
        transition assessingEthicalRisk then decidingEnforcement;
        transition decidingEnforcement then waitingForHumanReview
            if assessment.riskLevel == EthicalRiskLevel::high or assessment.riskLevel == EthicalRiskLevel::unacceptable;
        transition decidingEnforcement then issuingInstruction
            if assessment.riskLevel == EthicalRiskLevel::negligible or assessment.riskLevel == EthicalRiskLevel::low or assessment.riskLevel == EthicalRiskLevel::moderate;
        transition waitingForHumanReview then issuingInstruction;
        transition issuingInstruction then recordingAudit;
        transition recordingAudit then completed;
        transition completed then idle;
    }

    requirement def ProtectConsent {
        subject system : CyberEthicsGovernanceSystem;
        require constraint {
            system.consentVerifier.rejectsUnknownConsent == true
        }
        doc /* The system shall prevent use of personal data when consent is denied, expired, or unknown unless a valid ethics policy explicitly requires human review. */
    }

    requirement def BoundAssessmentLatency {
        subject system : CyberEthicsGovernanceSystem;
        require constraint {
            system.maximumAssessmentLatency <= 250.0
        }
        doc /* The system shall complete automated cyberethical assessment within 250 ms for a single observed digital action. */
    }

    requirement def PreserveAuditability {
        subject ledger : AuditLedger;
        require constraint {
            ledger.appendOnly == true and ledger.retentionYears >= 7
        }
        doc /* The system shall retain immutable audit records for accountability and post-incident review. */
    }

    requirement def EnforceHumanOversight {
        subject system : CyberEthicsGovernanceSystem;
        require constraint {
            system.decisionEngine.humanReviewThreshold == EthicalRiskLevel::high
        }
        doc /* The system shall route high and unacceptable ethical risk assessments to a qualified human reviewer before final enforcement. */
    }

    requirement def SupportEthicalPrinciples {
        subject analyzer : EthicalRiskAnalyzer;
        require constraint {
            analyzer.privacyWeight + analyzer.fairnessWeight + analyzer.autonomyWeight + analyzer.accountabilityWeight + analyzer.safetyWeight == 1.0
        }
        doc /* The system shall assess cyberethical risk using privacy, fairness, autonomy, accountability, and safety factors. */
    }

    part cyberEthicsGovernanceSystem : CyberEthicsGovernanceSystem;
}