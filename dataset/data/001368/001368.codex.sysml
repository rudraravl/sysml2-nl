package BioethicsSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Percent : Real {
    unit = "%";
  }

  attribute def Score : Real {
    unit = "1";
  }

  attribute def Hour : Real {
    unit = "h";
  }

  attribute def CaseIdentifier : String;
  attribute def PersonIdentifier : String;
  attribute def DocumentIdentifier : String;

  item def ClinicalCase {
    attribute caseId : CaseIdentifier;
    attribute submittedBy : PersonIdentifier;
    attribute urgencyLevel : Score;
    attribute estimatedReviewTime : Hour;
    attribute patientRisk : Score;
    attribute societalImpact : Score;
  }

  item def ConsentRecord {
    attribute documentId : DocumentIdentifier;
    attribute patientId : PersonIdentifier;
    attribute capacityConfirmed : Boolean;
    attribute informedConsentComplete : Boolean;
    attribute withdrawalAllowed : Boolean;
  }

  item def EthicalAssessment {
    attribute autonomyScore : Score;
    attribute beneficenceScore : Score;
    attribute nonMaleficenceScore : Score;
    attribute justiceScore : Score;
    attribute privacyScore : Score;
    attribute conflictSeverity : Score;
  }

  item def Recommendation {
    attribute recommendationId : DocumentIdentifier;
    attribute approved : Boolean;
    attribute conditionsRequired : Boolean;
    attribute escalationRequired : Boolean;
    attribute rationaleSummary : String;
  }

  item def AuditRecord {
    attribute auditId : DocumentIdentifier;
    attribute complete : Boolean;
    attribute traceabilityScore : Percent;
  }

  port def CaseSubmissionPort {
    in item submittedCase : ClinicalCase;
  }

  port def ConsentPort {
    in item consent : ConsentRecord;
  }

  port def AssessmentPort {
    out item assessment : EthicalAssessment;
  }

  port def RecommendationPort {
    out item recommendation : Recommendation;
  }

  port def AuditPort {
    out item audit : AuditRecord;
  }

  part def BioethicsDecisionSupportSystem {
    attribute operatingPrinciple : String = "Support ethically justified review of clinical and research decisions by balancing autonomy, beneficence, non-maleficence, justice, and privacy.";
    attribute minimumTraceability : Percent = 95.0;
    attribute emergencyReviewLimit : Hour = 2.0;
    attribute standardReviewLimit : Hour = 72.0;

    port caseInput : CaseSubmissionPort;
    port consentInput : ConsentPort;
    port assessmentOutput : AssessmentPort;
    port recommendationOutput : RecommendationPort;
    port auditOutput : AuditPort;

    part intake : CaseIntakeModule;
    part consentVerifier : ConsentVerificationModule;
    part principleAnalyzer : EthicalPrincipleAnalysisModule;
    part riskBalancer : RiskBenefitBalancingModule;
    part equityReviewer : JusticeAndEquityReviewModule;
    part privacyReviewer : PrivacySafeguardModule;
    part deliberationManager : DeliberationManagementModule;
    part recommendationEngine : RecommendationGenerationModule;
    part auditLogger : EthicsAuditModule;

    connect caseInput to intake.externalCaseInput;
    connect consentInput to consentVerifier.externalConsentInput;
    connect intake.caseOutput to principleAnalyzer.caseInput;
    connect intake.caseOutput to riskBalancer.caseInput;
    connect intake.caseOutput to equityReviewer.caseInput;
    connect intake.caseOutput to privacyReviewer.caseInput;
    connect consentVerifier.consentStatusOutput to principleAnalyzer.consentInput;
    connect principleAnalyzer.assessmentOutput to deliberationManager.principleAssessmentInput;
    connect riskBalancer.riskAssessmentOutput to deliberationManager.riskAssessmentInput;
    connect equityReviewer.justiceAssessmentOutput to deliberationManager.justiceAssessmentInput;
    connect privacyReviewer.privacyAssessmentOutput to deliberationManager.privacyAssessmentInput;
    connect deliberationManager.integratedAssessmentOutput to recommendationEngine.assessmentInput;
    connect recommendationEngine.recommendationOutput to recommendationOutput;
    connect deliberationManager.integratedAssessmentOutput to assessmentOutput;
    connect recommendationEngine.recommendationOutput to auditLogger.recommendationInput;
    connect deliberationManager.integratedAssessmentOutput to auditLogger.assessmentInput;
    connect auditLogger.auditOutput to auditOutput;

    perform action reviewBioethicsCase;
    exhibit state reviewLifecycle;
  }

  part def CaseIntakeModule {
    port externalCaseInput : CaseSubmissionPort;
    port caseOutput {
      out item acceptedCase : ClinicalCase;
    }

    action validateCase {
      in item rawCase : ClinicalCase;
      out item acceptedCase : ClinicalCase;
      attribute completenessThreshold : Percent = 90.0;
    }
  }

  part def ConsentVerificationModule {
    port externalConsentInput : ConsentPort;
    port consentStatusOutput {
      out item verifiedConsent : ConsentRecord;
    }

    action verifyConsent {
      in item consent : ConsentRecord;
      out item verifiedConsent : ConsentRecord;
    }
  }

  part def EthicalPrincipleAnalysisModule {
    port caseInput {
      in item acceptedCase : ClinicalCase;
    }
    port consentInput {
      in item verifiedConsent : ConsentRecord;
    }
    port assessmentOutput {
      out item principleAssessment : EthicalAssessment;
    }

    action evaluateAutonomyAndBeneficence {
      in item acceptedCase : ClinicalCase;
      in item verifiedConsent : ConsentRecord;
      out item principleAssessment : EthicalAssessment;
    }
  }

  part def RiskBenefitBalancingModule {
    port caseInput {
      in item acceptedCase : ClinicalCase;
    }
    port riskAssessmentOutput {
      out item riskAssessment : EthicalAssessment;
    }

    action compareExpectedBenefitAndHarm {
      in item acceptedCase : ClinicalCase;
      out item riskAssessment : EthicalAssessment;
      attribute maximumTolerableHarmScore : Score = 3.0;
    }
  }

  part def JusticeAndEquityReviewModule {
    port caseInput {
      in item acceptedCase : ClinicalCase;
    }
    port justiceAssessmentOutput {
      out item justiceAssessment : EthicalAssessment;
    }

    action evaluateFairAccessAndBurden {
      in item acceptedCase : ClinicalCase;
      out item justiceAssessment : EthicalAssessment;
      attribute minimumJusticeScore : Score = 7.0;
    }
  }

  part def PrivacySafeguardModule {
    port caseInput {
      in item acceptedCase : ClinicalCase;
    }
    port privacyAssessmentOutput {
      out item privacyAssessment : EthicalAssessment;
    }

    action evaluateDataProtection {
      in item acceptedCase : ClinicalCase;
      out item privacyAssessment : EthicalAssessment;
      attribute minimumPrivacyScore : Score = 8.0;
    }
  }

  part def DeliberationManagementModule {
    port principleAssessmentInput {
      in item principleAssessment : EthicalAssessment;
    }
    port riskAssessmentInput {
      in item riskAssessment : EthicalAssessment;
    }
    port justiceAssessmentInput {
      in item justiceAssessment : EthicalAssessment;
    }
    port privacyAssessmentInput {
      in item privacyAssessment : EthicalAssessment;
    }
    port integratedAssessmentOutput : AssessmentPort;

    action integrateEthicalFindings {
      in item principleAssessment : EthicalAssessment;
      in item riskAssessment : EthicalAssessment;
      in item justiceAssessment : EthicalAssessment;
      in item privacyAssessment : EthicalAssessment;
      out item assessment : EthicalAssessment;
    }
  }

  part def RecommendationGenerationModule {
    port assessmentInput {
      in item assessment : EthicalAssessment;
    }
    port recommendationOutput : RecommendationPort;

    action generateRecommendation {
      in item assessment : EthicalAssessment;
      out item recommendation : Recommendation;
      attribute approvalThreshold : Score = 7.5;
      attribute escalationThreshold : Score = 6.0;
    }
  }

  part def EthicsAuditModule {
    port assessmentInput {
      in item assessment : EthicalAssessment;
    }
    port recommendationInput {
      in item recommendation : Recommendation;
    }
    port auditOutput : AuditPort;

    action recordDecisionTrace {
      in item assessment : EthicalAssessment;
      in item recommendation : Recommendation;
      out item audit : AuditRecord;
    }
  }

  action def ReviewBioethicsCase {
    in item submittedCase : ClinicalCase;
    in item consent : ConsentRecord;
    out item recommendation : Recommendation;
    out item audit : AuditRecord;

    first start;
    then validateSubmittedCase;
    then verifyConsent;
    then assessEthicalPrinciples;
    then balanceRiskAndBenefit;
    then reviewJusticeAndPrivacy;
    then deliberate;
    then issueRecommendation;
    then logAudit;
    then done;

    action start;
    action validateSubmittedCase;
    action verifyConsent;
    action assessEthicalPrinciples;
    action balanceRiskAndBenefit;
    action reviewJusticeAndPrivacy;
    action deliberate;
    action issueRecommendation;
    action logAudit;
    action done;
  }

  state def BioethicsReviewLifecycle {
    entry action initializeReview;

    state Received;
    state Screening;
    state ConsentCheck;
    state EthicalAnalysis;
    state Deliberation;
    state RecommendationIssued;
    state EscalatedToCommittee;
    state Closed;

    transition first Received;
    transition Received then Screening;
    transition Screening then ConsentCheck;
    transition ConsentCheck then EthicalAnalysis if consentValid;
    transition ConsentCheck then EscalatedToCommittee if consentInvalidOrContested;
    transition EthicalAnalysis then Deliberation;
    transition Deliberation then RecommendationIssued if conflictSeverityAcceptable;
    transition Deliberation then EscalatedToCommittee if conflictSeverityHigh;
    transition RecommendationIssued then Closed;
    transition EscalatedToCommittee then Closed;

    attribute consentValid : Boolean;
    attribute consentInvalidOrContested : Boolean;
    attribute conflictSeverityAcceptable : Boolean;
    attribute conflictSeverityHigh : Boolean;

    action initializeReview;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall provide high-level bioethical decision support by receiving a clinical or research case, verifying consent, evaluating ethical principles, balancing risks and benefits, reviewing justice and privacy impacts, and producing a traceable recommendation. */
  }

  requirement def AutonomyRequirement {
    doc /* The system shall explicitly evaluate patient or participant autonomy, including decision-making capacity, informed consent completeness, and ability to withdraw. */
  }

  requirement def BeneficenceRequirement {
    doc /* The system shall evaluate whether the proposed action provides a credible expected benefit to the patient, participant, or affected community. */
  }

  requirement def NonMaleficenceRequirement {
    doc /* The system shall identify and score foreseeable harms and shall require escalation when harm exceeds the defined tolerable threshold. */
  }

  requirement def JusticeRequirement {
    doc /* The system shall evaluate fair access, fair distribution of burdens, and protection of vulnerable populations. */
  }

  requirement def PrivacyRequirement {
    doc /* The system shall evaluate privacy safeguards for sensitive health and identity data before issuing a recommendation. */
  }

  requirement def TraceabilityRequirement {
    doc /* The system shall generate an audit record linking the submitted case, ethical assessment, recommendation, rationale, and review state history. */
  }

  requirement def TimelinessRequirement {
    doc /* The system shall support emergency bioethics review within two hours and standard bioethics review within seventy-two hours. */
  }

  satisfy PrimaryFunctionRequirement by BioethicsDecisionSupportSystem;
  satisfy AutonomyRequirement by EthicalPrincipleAnalysisModule;
  satisfy BeneficenceRequirement by EthicalPrincipleAnalysisModule;
  satisfy NonMaleficenceRequirement by RiskBenefitBalancingModule;
  satisfy JusticeRequirement by JusticeAndEquityReviewModule;
  satisfy PrivacyRequirement by PrivacySafeguardModule;
  satisfy TraceabilityRequirement by EthicsAuditModule;
  satisfy TimelinessRequirement by DeliberationManagementModule;

  part bioethicsSystem : BioethicsDecisionSupportSystem {
    attribute operatingPrinciple = "Enable consistent, transparent, and humane ethical review for healthcare and life-science decisions.";
  }

}