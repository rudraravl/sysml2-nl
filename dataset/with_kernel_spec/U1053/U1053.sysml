package EthicalGovernanceSystem {
    private import ScalarValues::*;

    attribute def Score :> Real {
        assert constraint { that >= 0.0 and that <= 100.0 }
    }

    enum def RiskLevel {
        low;
        medium;
        high;
    }

    enum def Recommendation {
        approve;
        reject;
        escalate;
    }

    enum def ViolationType {
        bias;
        privacy;
        transparency;
        accountability;
        compliance;
    }

    attribute def EthicalScores {
        attribute fairness : Score;
        attribute privacy : Score;
        attribute transparency : Score;
        attribute accountability : Score;
        attribute compliance : Score;
    }

    item def TechnologyProposal {
        attribute title : String;
        attribute purpose : String;
        attribute intendedUse : String;
        attribute impactOnPeople : String;
        attribute populationGroups : String;
        attribute dataUsage : String;
        attribute decisionMaking : String;
        attribute oversight : String;
        attribute legalFrameworks : String;
    }

    item def BiasFindings {
        attribute biasScore : Score;
        attribute biasedGroups : String;
        attribute explanation : String;
    }

    item def PrivacyFindings {
        attribute privacyScore : Score;
        attribute dataMinimization : Boolean;
        attribute encryption : Boolean;
        attribute userConsent : Boolean;
        attribute explanation : String;
    }

    item def TransparencyFindings {
        attribute transparencyScore : Score;
        attribute explainabilityLevel : Score;
        attribute auditability : Boolean;
        attribute explanation : String;
    }

    item def AccountabilityFindings {
        attribute accountabilityScore : Score;
        attribute clearOwner : Boolean;
        attribute oversightBody : String;
        attribute explanation : String;
    }

    item def ComplianceFindings {
        attribute complianceScore : Score;
        attribute frameworksChecked : String;
        attribute violations : String;
        attribute explanation : String;
    }

    item def EthicalAssessment {
        attribute scores : EthicalScores;
        attribute overallRisk : RiskLevel;
        attribute summary : String;
    }

    item def Decision {
        attribute recommendation : Recommendation;
        attribute justification : String;
        attribute conditions : String [0..*];
        attribute humanOverride : Boolean;
    }

    item def UsageData {
        attribute timestamp : Real;
        attribute requestVolume : Real;
        attribute demographicDistributions : String;
        attribute errorRate : Real;
    }

    item def UserFeedback {
        attribute complaintType : String;
        attribute severity : RiskLevel;
        attribute description : String;
    }

    item def ViolationAlert {
        attribute violationType : ViolationType;
        attribute severity : RiskLevel;
        attribute detectedAt : Real;
        attribute description : String;
    }

    port def ProposalPort {
        out item proposal : TechnologyProposal;
    }

    port def BiasFindingsPort {
        out item findings : BiasFindings;
    }

    port def PrivacyFindingsPort {
        out item findings : PrivacyFindings;
    }

    port def TransparencyFindingsPort {
        out item findings : TransparencyFindings;
    }

    port def AccountabilityFindingsPort {
        out item findings : AccountabilityFindings;
    }

    port def ComplianceFindingsPort {
        out item findings : ComplianceFindings;
    }

    port def AssessmentPort {
        out item assessment : EthicalAssessment;
    }

    port def DecisionPort {
        out item decision : Decision;
    }

    port def ViolationAlertPort {
        out item alert : ViolationAlert;
    }

    port def UsageDataPort {
        out item usage : UsageData;
    }

    port def FeedbackPort {
        out item feedback : UserFeedback;
    }

    action def AnalyzeBiasAction {
        in proposal : TechnologyProposal;
        out findings : BiasFindings;
    }

    action def AnalyzePrivacyAction {
        in proposal : TechnologyProposal;
        out findings : PrivacyFindings;
    }

    action def AnalyzeTransparencyAction {
        in proposal : TechnologyProposal;
        out findings : TransparencyFindings;
    }

    action def AnalyzeAccountabilityAction {
        in proposal : TechnologyProposal;
        out findings : AccountabilityFindings;
    }

    action def ValidateComplianceAction {
        in proposal : TechnologyProposal;
        out findings : ComplianceFindings;
    }

    action def CompileAssessmentAction {
        in bias : BiasFindings;
        in privacy : PrivacyFindings;
        in transparency : TransparencyFindings;
        in accountability : AccountabilityFindings;
        in compliance : ComplianceFindings;
        out assessment : EthicalAssessment;
    }

    action def DecideAction {
        in assessment : EthicalAssessment;
        out decision : Decision;
    }

    action def ReviewAction {
        in assessment : EthicalAssessment;
        in automatedDecision : Decision;
        in reviewerNotes : String;
        out finalDecision : Decision;
    }

    action def MonitorAction {
        in usage : UsageData;
        in feedback : UserFeedback;
        out alert : ViolationAlert;
    }

    part def BiasAnalysisEngine {
        port proposalIn : ~ProposalPort;
        port findingsOut : BiasFindingsPort;
        action analyze : AnalyzeBiasAction;
        bind analyze.proposal = proposalIn.proposal;
        bind analyze.findings = findingsOut.findings;
    }

    part def PrivacyImpactAnalyzer {
        port proposalIn : ~ProposalPort;
        port findingsOut : PrivacyFindingsPort;
        action analyze : AnalyzePrivacyAction;
        bind analyze.proposal = proposalIn.proposal;
        bind analyze.findings = findingsOut.findings;
    }

    part def TransparencyEvaluator {
        port proposalIn : ~ProposalPort;
        port findingsOut : TransparencyFindingsPort;
        action analyze : AnalyzeTransparencyAction;
        bind analyze.proposal = proposalIn.proposal;
        bind analyze.findings = findingsOut.findings;
    }

    part def AccountabilityFramework {
        port proposalIn : ~ProposalPort;
        port findingsOut : AccountabilityFindingsPort;
        action analyze : AnalyzeAccountabilityAction;
        bind analyze.proposal = proposalIn.proposal;
        bind analyze.findings = findingsOut.findings;
    }

    part def ComplianceValidator {
        port proposalIn : ~ProposalPort;
        port findingsOut : ComplianceFindingsPort;
        action validate : ValidateComplianceAction;
        bind validate.proposal = proposalIn.proposal;
        bind validate.findings = findingsOut.findings;
    }

    part def EthicalAssessmentCompiler {
        port biasIn : ~BiasFindingsPort;
        port privacyIn : ~PrivacyFindingsPort;
        port transparencyIn : ~TransparencyFindingsPort;
        port accountabilityIn : ~AccountabilityFindingsPort;
        port complianceIn : ~ComplianceFindingsPort;
        port assessmentOut : AssessmentPort;
        action compile : CompileAssessmentAction;
        bind compile.bias = biasIn.findings;
        bind compile.privacy = privacyIn.findings;
        bind compile.transparency = transparencyIn.findings;
        bind compile.accountability = accountabilityIn.findings;
        bind compile.compliance = complianceIn.findings;
        bind compile.assessment = assessmentOut.assessment;
    }

    part def EthicalDecisionEngine {
        port assessmentIn : ~AssessmentPort;
        port decisionOut : DecisionPort;
        action makeDecision : DecideAction;
        bind makeDecision.assessment = assessmentIn.assessment;
        bind makeDecision.decision = decisionOut.decision;
    }

    part def HumanOversightInterface {
        port assessmentIn : ~AssessmentPort;
        port automatedDecisionIn : ~DecisionPort;
        port finalDecisionOut : DecisionPort;
        attribute reviewerId : String;
        attribute notes : String;
        action review : ReviewAction;
        bind review.assessment = assessmentIn.assessment;
        bind review.automatedDecision = automatedDecisionIn.decision;
        bind review.reviewerNotes = notes;
        bind review.finalDecision = finalDecisionOut.decision;
    }

    part def ContinuousMonitoringSystem {
        port usageIn : ~UsageDataPort;
        port feedbackIn : ~FeedbackPort;
        port alertOut : ViolationAlertPort;
        action monitor : MonitorAction;
        bind monitor.usage = usageIn.usage;
        bind monitor.feedback = feedbackIn.feedback;
        bind monitor.alert = alertOut.alert;
    }

    part def EthicalGovernanceSystem {
        port proposalIn : ~ProposalPort;
        port finalDecisionOut : DecisionPort;
        port violationAlertOut : ViolationAlertPort;
        port usageIn : ~UsageDataPort;
        port feedbackIn : ~FeedbackPort;

        part biasAnalysisEngine : BiasAnalysisEngine;
        part privacyImpactAnalyzer : PrivacyImpactAnalyzer;
        part transparencyEvaluator : TransparencyEvaluator;
        part accountabilityFramework : AccountabilityFramework;
        part complianceValidator : ComplianceValidator;
        part assessmentCompiler : EthicalAssessmentCompiler;
        part ethicalDecisionEngine : EthicalDecisionEngine;
        part humanOversightInterface : HumanOversightInterface;
        part continuousMonitoringSystem : ContinuousMonitoringSystem;

        connect proposalIn to biasAnalysisEngine.proposalIn;
        connect proposalIn to privacyImpactAnalyzer.proposalIn;
        connect proposalIn to transparencyEvaluator.proposalIn;
        connect proposalIn to accountabilityFramework.proposalIn;
        connect proposalIn to complianceValidator.proposalIn;

        connect biasAnalysisEngine.findingsOut to assessmentCompiler.biasIn;
        connect privacyImpactAnalyzer.findingsOut to assessmentCompiler.privacyIn;
        connect transparencyEvaluator.findingsOut to assessmentCompiler.transparencyIn;
        connect accountabilityFramework.findingsOut to assessmentCompiler.accountabilityIn;
        connect complianceValidator.findingsOut to assessmentCompiler.complianceIn;

        connect assessmentCompiler.assessmentOut to ethicalDecisionEngine.assessmentIn;
        connect assessmentCompiler.assessmentOut to humanOversightInterface.assessmentIn;

        connect ethicalDecisionEngine.decisionOut to humanOversightInterface.automatedDecisionIn;
        connect humanOversightInterface.finalDecisionOut to finalDecisionOut;

        connect usageIn to continuousMonitoringSystem.usageIn;
        connect feedbackIn to continuousMonitoringSystem.feedbackIn;
        connect continuousMonitoringSystem.alertOut to violationAlertOut;
    }

    requirement def MinimumScoreRequirement {
        attribute actualScore : Score;
        attribute threshold : Score;
        require constraint { actualScore >= threshold }
    }

    requirement fairnessRequirement : MinimumScoreRequirement {
        :>> threshold = 80.0;
    }

    requirement privacyRequirement : MinimumScoreRequirement {
        :>> threshold = 85.0;
    }

    requirement transparencyRequirement : MinimumScoreRequirement {
        :>> threshold = 75.0;
    }

    requirement accountabilityRequirement : MinimumScoreRequirement {
        :>> threshold = 80.0;
    }

    requirement complianceRequirement : MinimumScoreRequirement {
        :>> threshold = 90.0;
    }

    requirement def ContinuousOversightRequirement {
        attribute monitoringActive : Boolean;
        require constraint { monitoringActive }
    }

    requirement continuousOversight : ContinuousOversightRequirement {
        :>> monitoringActive = true;
    }

    part governanceSystem : EthicalGovernanceSystem;
}
