package EthicalArtificialIntelligenceSystem {
    import ScalarValues::*;
    import Quantities::*;
    import MeasurementReferences::*;

    attribute def Percent : Real {
        range = "0.0..100.0";
        unit = "%";
    }

    attribute def RiskScore : Real {
        range = "0.0..1.0";
    }

    attribute def ConfidenceScore : Real {
        range = "0.0..1.0";
    }

    attribute def Millisecond : Real {
        unit = "ms";
    }

    attribute def Count : Integer;

    attribute def AuditRecordId : String;
    attribute def ModelVersionId : String;
    attribute def HumanRole : String;

    item def UserRequest {
        attribute requestId : String;
        attribute subjectCategory : String;
        attribute requestedPurpose : String;
        attribute rawContent : String;
        attribute consentStatus : Boolean;
        attribute timestampUtc : String;
    }

    item def ContextData {
        attribute contextId : String;
        attribute jurisdiction : String;
        attribute userAgeBracket : String;
        attribute sensitivityLevel : RiskScore;
        attribute dataMinimizationApplied : Boolean;
    }

    item def AIRecommendation {
        attribute recommendationId : String;
        attribute summary : String;
        attribute confidence : ConfidenceScore;
        attribute modelVersion : ModelVersionId;
        attribute generatedAtUtc : String;
    }

    item def EthicalAssessment {
        attribute assessmentId : String;
        attribute fairnessRisk : RiskScore;
        attribute privacyRisk : RiskScore;
        attribute safetyRisk : RiskScore;
        attribute explainabilityScore : ConfidenceScore;
        attribute humanReviewRequired : Boolean;
        attribute approvedForRelease : Boolean;
    }

    item def ExplanationPackage {
        attribute explanationId : String;
        attribute plainLanguageReason : String;
        attribute keyFactors : String;
        attribute limitations : String;
        attribute appealAvailable : Boolean;
    }

    item def AuditRecord {
        attribute auditRecordId : AuditRecordId;
        attribute requestId : String;
        attribute decisionOutcome : String;
        attribute reviewerRole : HumanRole;
        attribute retentionDays : Count;
        attribute integrityHash : String;
    }

    item def PolicyRuleSet {
        attribute policyVersion : String;
        attribute fairnessThreshold : RiskScore;
        attribute privacyThreshold : RiskScore;
        attribute safetyThreshold : RiskScore;
        attribute minimumExplainability : ConfidenceScore;
        attribute requiresHumanOverrideForHighImpact : Boolean;
    }

    port def RequestInputPort {
        in request : UserRequest;
        in context : ContextData;
    }

    port def RecommendationOutputPort {
        out recommendation : AIRecommendation;
        out explanation : ExplanationPackage;
    }

    port def AssessmentPort {
        out assessment : EthicalAssessment;
    }

    port def AuditPort {
        out record : AuditRecord;
    }

    port def PolicyPort {
        in policy : PolicyRuleSet;
    }

    part def EthicalAIPlatform {
        attribute availabilityTarget : Percent = 99.9;
        attribute maximumAssessmentLatency : Millisecond = 750.0;
        attribute maximumStoredPersonalDataDays : Count = 30;

        port requestIn : RequestInputPort;
        port recommendationOut : RecommendationOutputPort;
        port assessmentOut : AssessmentPort;
        port auditOut : AuditPort;
        port policyIn : PolicyPort;

        part intake : RequestIntake;
        part privacyGuard : PrivacyGuard;
        part policyEngine : EthicalPolicyEngine;
        part aiCore : ResponsibleInferenceEngine;
        part fairnessMonitor : FairnessMonitor;
        part safetyMonitor : SafetyMonitor;
        part explainabilityEngine : ExplainabilityEngine;
        part humanOversight : HumanOversightConsole;
        part auditLedger : AuditLedger;

        connect requestIn.request to intake.receivedRequest;
        connect requestIn.context to intake.receivedContext;
        connect policyIn.policy to policyEngine.activePolicy;
        connect intake.validatedRequest to privacyGuard.incomingRequest;
        connect intake.validatedContext to privacyGuard.incomingContext;
        connect privacyGuard.minimizedRequest to aiCore.request;
        connect privacyGuard.minimizedContext to aiCore.context;
        connect aiCore.candidateRecommendation to fairnessMonitor.candidateRecommendation;
        connect aiCore.candidateRecommendation to safetyMonitor.candidateRecommendation;
        connect aiCore.candidateRecommendation to explainabilityEngine.candidateRecommendation;
        connect fairnessMonitor.fairnessAssessment to policyEngine.fairnessAssessment;
        connect safetyMonitor.safetyAssessment to policyEngine.safetyAssessment;
        connect privacyGuard.privacyAssessment to policyEngine.privacyAssessment;
        connect explainabilityEngine.explanation to policyEngine.explanation;
        connect policyEngine.ethicalAssessment to humanOversight.pendingAssessment;
        connect aiCore.candidateRecommendation to humanOversight.pendingRecommendation;
        connect humanOversight.finalRecommendation to recommendationOut.recommendation;
        connect humanOversight.finalExplanation to recommendationOut.explanation;
        connect policyEngine.ethicalAssessment to assessmentOut.assessment;
        connect humanOversight.auditRecord to auditLedger.recordIn;
        connect auditLedger.recordOut to auditOut.record;
    }

    part def RequestIntake {
        port receivedRequest {
            in request : UserRequest;
        }
        port receivedContext {
            in context : ContextData;
        }
        port validatedRequest {
            out request : UserRequest;
        }
        port validatedContext {
            out context : ContextData;
        }

        action validateRequest {
            in request : UserRequest;
            in context : ContextData;
            out validRequest : UserRequest;
            out validContext : ContextData;

            first start;
            then checkConsent;
            then checkPurpose;
            then normalizeMetadata;
            then done;

            action checkConsent;
            action checkPurpose;
            action normalizeMetadata;
        }
    }

    part def PrivacyGuard {
        attribute defaultRetentionDays : Count = 30;
        attribute maximumPrivacyRiskAllowed : RiskScore = 0.25;

        port incomingRequest {
            in request : UserRequest;
        }
        port incomingContext {
            in context : ContextData;
        }
        port minimizedRequest {
            out request : UserRequest;
        }
        port minimizedContext {
            out context : ContextData;
        }
        port privacyAssessment {
            out assessment : EthicalAssessment;
        }

        action minimizeData {
            in request : UserRequest;
            in context : ContextData;
            out minimizedRequest : UserRequest;
            out minimizedContext : ContextData;
            out privacyRisk : RiskScore;

            first classifySensitiveData;
            then removeUnneededIdentifiers;
            then verifyConsentBasis;
            then calculatePrivacyRisk;
            then emitMinimizedPayload;

            action classifySensitiveData;
            action removeUnneededIdentifiers;
            action verifyConsentBasis;
            action calculatePrivacyRisk;
            action emitMinimizedPayload;
        }
    }

    part def ResponsibleInferenceEngine {
        attribute modelVersion : ModelVersionId = "ethical-ai-core-4.2.0";
        attribute minimumModelConfidence : ConfidenceScore = 0.70;
        attribute maximumInferenceLatency : Millisecond = 400.0;

        port request {
            in request : UserRequest;
        }
        port context {
            in context : ContextData;
        }
        port candidateRecommendation {
            out recommendation : AIRecommendation;
        }

        action generateRecommendation {
            in request : UserRequest;
            in context : ContextData;
            out recommendation : AIRecommendation;

            first retrievePermittedKnowledge;
            then inferCandidateAnswer;
            then calibrateConfidence;
            then attachModelVersion;
            then emitCandidateRecommendation;

            action retrievePermittedKnowledge;
            action inferCandidateAnswer;
            action calibrateConfidence;
            action attachModelVersion;
            action emitCandidateRecommendation;
        }
    }

    part def FairnessMonitor {
        attribute maximumDisparateImpactRisk : RiskScore = 0.20;
        attribute minimumCoverageAcrossGroups : Percent = 95.0;

        port candidateRecommendation {
            in recommendation : AIRecommendation;
        }
        port fairnessAssessment {
            out assessment : EthicalAssessment;
        }

        action assessFairness {
            in recommendation : AIRecommendation;
            out fairnessRisk : RiskScore;

            first detectProtectedClassProxy;
            then compareGroupOutcomeDistributions;
            then estimateDisparateImpact;
            then generateFairnessFinding;

            action detectProtectedClassProxy;
            action compareGroupOutcomeDistributions;
            action estimateDisparateImpact;
            action generateFairnessFinding;
        }
    }

    part def SafetyMonitor {
        attribute maximumSafetyRiskAllowed : RiskScore = 0.15;
        attribute harmfulInstructionBlockRateTarget : Percent = 99.5;

        port candidateRecommendation {
            in recommendation : AIRecommendation;
        }
        port safetyAssessment {
            out assessment : EthicalAssessment;
        }

        action assessSafety {
            in recommendation : AIRecommendation;
            out safetyRisk : RiskScore;

            first screenForHarmfulAdvice;
            then checkHighImpactDomain;
            then checkUncertaintyDisclosure;
            then generateSafetyFinding;

            action screenForHarmfulAdvice;
            action checkHighImpactDomain;
            action checkUncertaintyDisclosure;
            action generateSafetyFinding;
        }
    }

    part def ExplainabilityEngine {
        attribute minimumExplanationCompleteness : ConfidenceScore = 0.80;
        attribute maximumExplanationLatency : Millisecond = 150.0;

        port candidateRecommendation {
            in recommendation : AIRecommendation;
        }
        port explanation {
            out explanation : ExplanationPackage;
        }

        action generateExplanation {
            in recommendation : AIRecommendation;
            out explanation : ExplanationPackage;

            first identifyDecisionFactors;
            then translateToPlainLanguage;
            then stateLimitsAndUncertainty;
            then includeAppealPath;
            then emitExplanation;

            action identifyDecisionFactors;
            action translateToPlainLanguage;
            action stateLimitsAndUncertainty;
            action includeAppealPath;
            action emitExplanation;
        }
    }

    part def EthicalPolicyEngine {
        attribute defaultFairnessThreshold : RiskScore = 0.20;
        attribute defaultPrivacyThreshold : RiskScore = 0.25;
        attribute defaultSafetyThreshold : RiskScore = 0.15;
        attribute defaultMinimumExplainability : ConfidenceScore = 0.80;

        port activePolicy {
            in policy : PolicyRuleSet;
        }
        port fairnessAssessment {
            in assessment : EthicalAssessment;
        }
        port privacyAssessment {
            in assessment : EthicalAssessment;
        }
        port safetyAssessment {
            in assessment : EthicalAssessment;
        }
        port explanation {
            in explanation : ExplanationPackage;
        }
        port ethicalAssessment {
            out assessment : EthicalAssessment;
        }

        action evaluateEthics {
            in policy : PolicyRuleSet;
            in fairness : EthicalAssessment;
            in privacy : EthicalAssessment;
            in safety : EthicalAssessment;
            in explanation : ExplanationPackage;
            out assessment : EthicalAssessment;

            first aggregateRisks;
            then compareAgainstPolicyThresholds;
            then determineHumanReviewNeed;
            then determineReleaseApproval;
            then emitEthicalAssessment;

            action aggregateRisks;
            action compareAgainstPolicyThresholds;
            action determineHumanReviewNeed;
            action determineReleaseApproval;
            action emitEthicalAssessment;
        }
    }

    part def HumanOversightConsole {
        attribute reviewerRoleRequired : HumanRole = "EthicsReviewer";
        attribute maximumReviewQueueMinutes : Real = 60.0;

        port pendingAssessment {
            in assessment : EthicalAssessment;
        }
        port pendingRecommendation {
            in recommendation : AIRecommendation;
        }
        port finalRecommendation {
            out recommendation : AIRecommendation;
        }
        port finalExplanation {
            out explanation : ExplanationPackage;
        }
        port auditRecord {
            out record : AuditRecord;
        }

        state def OversightStateMachine {
            entry action initializeQueue;

            state AwaitingAssessment;
            state AutoApproved;
            state ManualReviewRequired;
            state HumanApproved;
            state HumanRejected;
            state Released;
            state Escalated;

            transition first AwaitingAssessment;
            transition AwaitingAssessment to AutoApproved
                if pendingAssessment.assessment.approvedForRelease and not pendingAssessment.assessment.humanReviewRequired;
            transition AwaitingAssessment to ManualReviewRequired
                if pendingAssessment.assessment.humanReviewRequired;
            transition ManualReviewRequired to HumanApproved
                if reviewerDecision == "approve";
            transition ManualReviewRequired to HumanRejected
                if reviewerDecision == "reject";
            transition ManualReviewRequired to Escalated
                if reviewerDecision == "escalate";
            transition AutoApproved to Released;
            transition HumanApproved to Released;
        }

        action reviewDecision {
            in assessment : EthicalAssessment;
            in recommendation : AIRecommendation;
            out finalRecommendation : AIRecommendation;
            out explanation : ExplanationPackage;
            out record : AuditRecord;

            first inspectEthicalAssessment;
            then applyHumanJudgment;
            then approveRejectOrEscalate;
            then createAuditRecord;

            action inspectEthicalAssessment;
            action applyHumanJudgment;
            action approveRejectOrEscalate;
            action createAuditRecord;
        }
    }

    part def AuditLedger {
        attribute retentionDays : Count = 2555;
        attribute tamperEvidenceEnabled : Boolean = true;

        port recordIn {
            in record : AuditRecord;
        }
        port recordOut {
            out record : AuditRecord;
        }

        action storeAuditRecord {
            in record : AuditRecord;
            out storedRecord : AuditRecord;

            first validateRecordCompleteness;
            then computeIntegrityHash;
            then persistRecord;
            then emitStoredRecord;

            action validateRecordCompleteness;
            action computeIntegrityHash;
            action persistRecord;
            action emitStoredRecord;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject platform : EthicalAIPlatform;

        doc /* The system shall provide AI recommendations only after evaluating the request, context, candidate output, and explanation against explicit ethical policy controls for fairness, privacy, safety, transparency, accountability, and human oversight. */
    }

    requirement def ConsentRequirement {
        subject guard : PrivacyGuard;

        doc /* The system shall process personal or sensitive data only when consent status and lawful purpose are present in the incoming request context. */
    }

    requirement def DataMinimizationRequirement {
        subject guard : PrivacyGuard;

        doc /* The system shall remove identifiers and nonessential attributes before inference unless the active ethical policy explicitly permits their use. */
    }

    requirement def FairnessRequirement {
        subject monitor : FairnessMonitor;

        attribute maximumAllowedFairnessRisk : RiskScore = 0.20;

        doc /* The system shall block or route for human review any recommendation whose estimated fairness risk exceeds 0.20. */
    }

    requirement def SafetyRequirement {
        subject monitor : SafetyMonitor;

        attribute maximumAllowedSafetyRisk : RiskScore = 0.15;

        doc /* The system shall prevent release of recommendations that contain unsafe instructions, unsupported high-impact guidance, or missing uncertainty disclosure. */
    }

    requirement def ExplainabilityRequirement {
        subject explainer : ExplainabilityEngine;

        attribute minimumExplainabilityScore : ConfidenceScore = 0.80;

        doc /* The system shall produce a plain-language explanation identifying key factors, limitations, uncertainty, and appeal availability for every released recommendation. */
    }

    requirement def AccountabilityRequirement {
        subject ledger : AuditLedger;

        attribute minimumRetentionDays : Count = 2555;

        doc /* The system shall create tamper-evident audit records for every automated, human-reviewed, rejected, or escalated decision. */
    }

    requirement def HumanOversightRequirement {
        subject console : HumanOversightConsole;

        doc /* The system shall route high-impact, high-risk, low-confidence, or policy-ambiguous recommendations to an authorized human reviewer before release. */
    }

    requirement def PerformanceRequirement {
        subject platform : EthicalAIPlatform;

        attribute maximumEndToEndAssessmentLatency : Millisecond = 750.0;

        doc /* The system shall complete automated ethical assessment within 750 milliseconds for routine requests that do not require manual review. */
    }

    satisfy PrimaryFunctionRequirement by EthicalAIPlatform;
    satisfy ConsentRequirement by PrivacyGuard;
    satisfy DataMinimizationRequirement by PrivacyGuard;
    satisfy FairnessRequirement by FairnessMonitor;
    satisfy SafetyRequirement by SafetyMonitor;
    satisfy ExplainabilityRequirement by ExplainabilityEngine;
    satisfy AccountabilityRequirement by AuditLedger;
    satisfy HumanOversightRequirement by HumanOversightConsole;
    satisfy PerformanceRequirement by EthicalAIPlatform;

    analysis def EthicalReleaseDecisionAnalysis {
        in fairnessRisk : RiskScore;
        in privacyRisk : RiskScore;
        in safetyRisk : RiskScore;
        in explainabilityScore : ConfidenceScore;
        out approved : Boolean;
        out humanReviewRequired : Boolean;

        constraint ethicalApprovalRule {
            fairnessRisk <= 0.20 and
            privacyRisk <= 0.25 and
            safetyRisk <= 0.15 and
            explainabilityScore >= 0.80
        }

        constraint manualReviewRule {
            fairnessRisk > 0.10 or
            privacyRisk > 0.15 or
            safetyRisk > 0.08 or
            explainabilityScore < 0.90
        }
    }

    use case def ProvideEthicalAIRecommendation {
        subject platform : EthicalAIPlatform;
        actor requester;
        actor ethicsReviewer;

        objective {
            doc /* Produce a useful AI recommendation while enforcing ethical constraints, explaining the decision, preserving user rights, and recording accountable evidence. */
        }

        include validateRequest;
        include minimizeData;
        include generateRecommendation;
        include assessFairness;
        include assessSafety;
        include generateExplanation;
        include evaluateEthics;
        include reviewDecision;
        include storeAuditRecord;
    }
}