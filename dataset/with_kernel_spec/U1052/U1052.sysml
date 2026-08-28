package EthicalAIGovernance {
	private import ScalarValues::*;
	
	attribute def ConfidenceLevel :> ScalarValues::Real {
		doc /* Confidence level in percent (0.0 to 100.0). */
	}
	
	attribute def SeverityScore :> ScalarValues::Real {
		doc /* Severity score from 0.0 to 1.0. */
	}
	
	attribute def DemographicParityMetric :> ScalarValues::Real {
		doc /* Demographic parity metric, range -1.0 to 1.0 (0 is ideal). */
	}
	
	attribute def EqualizedOddsMetric :> ScalarValues::Real {
		doc /* Equalized odds metric, range -1.0 to 1.0 (0 is ideal). */
	}
	
	enum def RiskLevelEnum {
		LOW;
		MEDIUM;
		HIGH;
	}
	
	enum def BiasTypeEnum {
		HISTORICAL;
		ALGORITHMIC;
		REPRESENTATIONAL;
		MEASUREMENT;
		AGGREGATION;
	}
	
	enum def ProtectedAttributeEnum {
		AGE;
		RACE;
		GENDER;
		DISABILITY;
		RELIGION;
		SOCIOECONOMIC;
	}
	
	enum def ComplianceFrameworkEnum {
		EU_AI_ACT;
		GDPR;
		ISO_42001;
		NIST_AI_RMF;
	}
	
	item def DecisionRequest {
		attribute requestId : String;
		attribute requestorId : String;
		attribute requestType : String;
		attribute requestDetails : String;
		attribute timestamp : String;
		attribute dataPayload : String;
	}
	
	item def BiasReport {
		attribute reportId : String;
		attribute biasDetected : Boolean;
		attribute biasType : BiasTypeEnum;
		attribute severity : SeverityScore;
		attribute affectedGroup : ProtectedAttributeEnum;
	}
	
	item def FairnessReport {
		attribute reportId : String;
		attribute fairOutcome : Boolean;
		attribute protectedGroup : ProtectedAttributeEnum;
		attribute demographicParity : DemographicParityMetric;
		attribute equalizedOdds : EqualizedOddsMetric;
	}
	
	item def ComplianceReport {
		attribute reportId : String;
		attribute compliant : Boolean;
		attribute framework : ComplianceFrameworkEnum;
		attribute violations : String;
	}
	
	item def Explanation {
		attribute explanationId : String;
		attribute summary : String;
		attribute justification : String;
		attribute contributingFactors : String;
	}
	
	item def HumanReviewVerdict {
		attribute verdictId : String;
		attribute reviewerId : String;
		attribute approved : Boolean;
		attribute comments : String;
		attribute reviewTimestamp : String;
	}
	
	item def DecisionOutcome {
		attribute outcomeId : String;
		attribute decisionText : String;
		attribute approved : Boolean;
		attribute requiresHumanReview : Boolean;
		attribute explanationRef : String;
	}
	
	item def AuditRecord {
		attribute recordId : String;
		attribute encrypted : Boolean;
		attribute immutable : Boolean;
		attribute hash : String;
		attribute timestamp : String;
		attribute content : String;
	}
	
	attribute def RequestReceivedSignal;
	attribute def AnalysisCompleteSignal;
	attribute def HighRiskFlagSignal;
	attribute def LowRiskClearSignal;
	attribute def ReviewCompleteSignal;
	attribute def DecisionFinalizedSignal;
	attribute def AuditCompleteSignal;
	
	action def ReceiveRequest {
		out request : DecisionRequest;
	}
	
	action def AnalyzeRequest {
		in request : DecisionRequest;
		out riskLevel : RiskLevelEnum;
		out confidence : ConfidenceLevel;
	}
	
	action def DetectBias {
		in request : DecisionRequest;
		out report : BiasReport;
	}
	
	action def ValidateFairness {
		in request : DecisionRequest;
		out report : FairnessReport;
	}
	
	action def GenerateExplanation {
		in request : DecisionRequest;
		in biasReport : BiasReport;
		in fairnessReport : FairnessReport;
		out explanation : Explanation;
	}
	
	action def CheckCompliance {
		in request : DecisionRequest;
		out report : ComplianceReport;
	}
	
	action def ConductEthicalAssessment {
		in request : DecisionRequest;
		in riskLevel : RiskLevelEnum;
		in biasReport : BiasReport;
		in fairnessReport : FairnessReport;
		in complianceReport : ComplianceReport;
		in explanation : Explanation;
		out requiresHumanReview : Boolean;
		out preliminaryVerdict : HumanReviewVerdict;
	}
	
	action def ConductHumanReview {
		in request : DecisionRequest;
		in explanation : Explanation;
		in preliminaryVerdict : HumanReviewVerdict;
		in reviewRequired : Boolean;
		out verdict : HumanReviewVerdict;
	}
	
	action def FinalizeDecision {
		in request : DecisionRequest;
		in verdict : HumanReviewVerdict;
		in explanation : Explanation;
		in requiresHumanReview : Boolean;
		out outcome : DecisionOutcome;
	}
	
	action def LogAudit {
		in request : DecisionRequest;
		in explanation : Explanation;
		in verdict : HumanReviewVerdict;
		in outcome : DecisionOutcome;
		out auditRecord : AuditRecord;
	}
	
	action def GovernanceProcess {
		first start;
		then action receive : ReceiveRequest {
			out request : DecisionRequest;
		}
		then action analyze : AnalyzeRequest {
			in request = receive.request;
			out riskLevel : RiskLevelEnum;
			out confidence : ConfidenceLevel;
		}
		then action bias : DetectBias {
			in request = receive.request;
			out report : BiasReport;
		}
		then action fairness : ValidateFairness {
			in request = receive.request;
			out report : FairnessReport;
		}
		then action compliance : CheckCompliance {
			in request = receive.request;
			out report : ComplianceReport;
		}
		then action transparency : GenerateExplanation {
			in request = receive.request;
			in biasReport = bias.report;
			in fairnessReport = fairness.report;
			out explanation : Explanation;
		}
		then action assessment : ConductEthicalAssessment {
			in request = receive.request;
			in riskLevel = analyze.riskLevel;
			in biasReport = bias.report;
			in fairnessReport = fairness.report;
			in complianceReport = compliance.report;
			in explanation = transparency.explanation;
			out requiresHumanReview : Boolean;
			out preliminaryVerdict : HumanReviewVerdict;
		}
		then action humanReview : ConductHumanReview {
			in request = receive.request;
			in explanation = transparency.explanation;
			in preliminaryVerdict = assessment.preliminaryVerdict;
			in reviewRequired = assessment.requiresHumanReview;
			out verdict : HumanReviewVerdict;
		}
		then action finalize : FinalizeDecision {
			in request = receive.request;
			in verdict = humanReview.verdict;
			in explanation = transparency.explanation;
			in requiresHumanReview = assessment.requiresHumanReview;
			out outcome : DecisionOutcome;
		}
		then action audit : LogAudit {
			in request = receive.request;
			in explanation = transparency.explanation;
			in verdict = humanReview.verdict;
			in outcome = finalize.outcome;
			out auditRecord : AuditRecord;
		}
		then done;
	}
	
	state def GovernanceLifecycle {
		entry; then idle;
		state idle;
		transition idle_to_analyzing
			first idle
			accept RequestReceivedSignal
			then analyzing;
		state analyzing;
		transition analyzing_to_evaluating
			first analyzing
			accept AnalysisCompleteSignal
			then evaluating;
		state evaluating;
		transition evaluating_to_reviewing
			first evaluating
			accept HighRiskFlagSignal
			then reviewing;
		transition evaluating_to_auditing
			first evaluating
			accept LowRiskClearSignal
			then auditing;
		state reviewing;
		transition reviewing_to_auditing
			first reviewing
			accept ReviewCompleteSignal
			then auditing;
		state auditing;
		transition auditing_to_idle
			first auditing
			accept AuditCompleteSignal
			then idle;
	}
	
	part def BiasDetectionEngine {
		port requestInPort {
			in request : DecisionRequest;
		}
		port biasReportOutPort {
			out biasReport : BiasReport;
		}
		perform action detectBias : DetectBias;
	}
	
	part def FairnessValidator {
		port requestInPort {
			in request : DecisionRequest;
		}
		port fairnessReportOutPort {
			out fairnessReport : FairnessReport;
		}
		attribute fairnessEnforced : Boolean = true;
		perform action validateFairness : ValidateFairness;
	}
	
	part def TransparencyModule {
		port requestInPort {
			in request : DecisionRequest;
		}
		port biasReportInPort {
			in biasReport : BiasReport;
		}
		port fairnessReportInPort {
			in fairnessReport : FairnessReport;
		}
		port explanationOutPort {
			out explanation : Explanation;
		}
		attribute explanationEnabled : Boolean = true;
		perform action generateExplanation : GenerateExplanation;
	}
	
	part def EthicalReviewBoard {
		port reviewRequestInPort {
			in request : DecisionRequest;
			in explanation : Explanation;
			in preliminaryVerdict : HumanReviewVerdict;
		}
		port verdictOutPort {
			out verdict : HumanReviewVerdict;
		}
		perform action conductReview : ConductHumanReview;
	}
	
	part def ComplianceMonitor {
		port requestInPort {
			in request : DecisionRequest;
		}
		port complianceReportOutPort {
			out complianceReport : ComplianceReport;
		}
		attribute monitoredFrameworks : ComplianceFrameworkEnum[1..*];
		attribute complianceEnforced : Boolean = true;
		perform action checkCompliance : CheckCompliance;
	}
	
	part def AuditTrailManager {
		port auditInPort {
			in request : DecisionRequest;
			in explanation : Explanation;
			in verdict : HumanReviewVerdict;
			in outcome : DecisionOutcome;
		}
		port auditOutPort {
			out auditRecord : AuditRecord;
		}
		attribute encryptionEnabled : Boolean = true;
		attribute immutabilityEnsured : Boolean = true;
		perform action logAudit : LogAudit;
	}
	
	part def GovernanceController {
		port requestInPort {
			in request : DecisionRequest;
		}
		port decisionOutPort {
			out outcome : DecisionOutcome;
		}
		port requestDispatchPort {
			out request : DecisionRequest;
		}
		port biasReportPort {
			in biasReport : BiasReport;
		}
		port fairnessReportPort {
			in fairnessReport : FairnessReport;
		}
		port complianceReportPort {
			in complianceReport : ComplianceReport;
		}
		port explanationPort {
			in explanation : Explanation;
		}
		port reviewOutPort {
			out request : DecisionRequest;
			out explanation : Explanation;
			out preliminaryVerdict : HumanReviewVerdict;
		}
		port reviewVerdictPort {
			in verdict : HumanReviewVerdict;
		}
		port auditOutPort {
			out request : DecisionRequest;
			out explanation : Explanation;
			out verdict : HumanReviewVerdict;
			out outcome : DecisionOutcome;
		}
		port auditRecordPort {
			in auditRecord : AuditRecord;
		}
		attribute ethicalAssessmentPerformed : Boolean = true;
		attribute humanReviewRoutingEnabled : Boolean = true;
		perform action governanceProcess : GovernanceProcess;
		state governanceLifecycle : GovernanceLifecycle;
	}
	
	part def GovernanceSystem {
		port externalRequestPort {
			in request : DecisionRequest;
		}
		port externalDecisionPort {
			out outcome : DecisionOutcome;
		}
		
		part controller : GovernanceController;
		part biasEngine : BiasDetectionEngine;
		part fairnessValidator : FairnessValidator;
		part transparencyModule : TransparencyModule;
		part ethicalReviewBoard : EthicalReviewBoard;
		part complianceMonitor : ComplianceMonitor;
		part auditTrailManager : AuditTrailManager;
		
		flow externalToControllerFlow of DecisionRequest
			from externalRequestPort.request to controller.requestInPort.request;
		flow controllerToBiasFlow of DecisionRequest
			from controller.requestDispatchPort.request to biasEngine.requestInPort.request;
		flow controllerToFairnessFlow of DecisionRequest
			from controller.requestDispatchPort.request to fairnessValidator.requestInPort.request;
		flow controllerToComplianceFlow of DecisionRequest
			from controller.requestDispatchPort.request to complianceMonitor.requestInPort.request;
		flow controllerToTransparencyFlow of DecisionRequest
			from controller.requestDispatchPort.request to transparencyModule.requestInPort.request;
		flow biasReportToTransparencyFlow of BiasReport
			from biasEngine.biasReportOutPort.biasReport to transparencyModule.biasReportInPort.biasReport;
		flow biasReportToControllerFlow of BiasReport
			from biasEngine.biasReportOutPort.biasReport to controller.biasReportPort.biasReport;
		flow fairnessReportToTransparencyFlow of FairnessReport
			from fairnessValidator.fairnessReportOutPort.fairnessReport to transparencyModule.fairnessReportInPort.fairnessReport;
		flow fairnessReportToControllerFlow of FairnessReport
			from fairnessValidator.fairnessReportOutPort.fairnessReport to controller.fairnessReportPort.fairnessReport;
		flow complianceReportToControllerFlow of ComplianceReport
			from complianceMonitor.complianceReportOutPort.complianceReport to controller.complianceReportPort.complianceReport;
		flow explanationToControllerFlow of Explanation
			from transparencyModule.explanationOutPort.explanation to controller.explanationPort.explanation;
		flow controllerReviewRequestFlow of DecisionRequest
			from controller.reviewOutPort.request to ethicalReviewBoard.reviewRequestInPort.request;
		flow controllerReviewExplanationFlow of Explanation
			from controller.reviewOutPort.explanation to ethicalReviewBoard.reviewRequestInPort.explanation;
		flow controllerReviewVerdictFlow of HumanReviewVerdict
			from controller.reviewOutPort.preliminaryVerdict to ethicalReviewBoard.reviewRequestInPort.preliminaryVerdict;
		flow reviewVerdictToControllerFlow of HumanReviewVerdict
			from ethicalReviewBoard.verdictOutPort.verdict to controller.reviewVerdictPort.verdict;
		flow controllerAuditRequestFlow of DecisionRequest
			from controller.auditOutPort.request to auditTrailManager.auditInPort.request;
		flow controllerAuditExplanationFlow of Explanation
			from controller.auditOutPort.explanation to auditTrailManager.auditInPort.explanation;
		flow controllerAuditVerdictFlow of HumanReviewVerdict
			from controller.auditOutPort.verdict to auditTrailManager.auditInPort.verdict;
		flow controllerAuditOutcomeFlow of DecisionOutcome
			from controller.auditOutPort.outcome to auditTrailManager.auditInPort.outcome;
		flow auditRecordToControllerFlow of AuditRecord
			from auditTrailManager.auditOutPort.auditRecord to controller.auditRecordPort.auditRecord;
		flow decisionOutFlow of DecisionOutcome
			from controller.decisionOutPort.outcome to externalDecisionPort.outcome;
	}
	
	part governanceSystem : GovernanceSystem;
	
	requirement def EthicalDecisionRequirement {
		doc /* Every automated decision must be evaluated against ethical principles before finalization. */
		subject :>> governanceSystem : GovernanceSystem;
		require constraint { governanceSystem.controller.ethicalAssessmentPerformed == true }
	}
	
	requirement def FairnessRequirement {
		doc /* Decisions must not disproportionately harm protected groups. */
		subject :>> governanceSystem : GovernanceSystem;
		require constraint { governanceSystem.fairnessValidator.fairnessEnforced == true }
	}
	
	requirement def TransparencyRequirement {
		doc /* Every decision must produce a human-understandable explanation. */
		subject :>> governanceSystem : GovernanceSystem;
		require constraint { governanceSystem.transparencyModule.explanationEnabled == true }
	}
	
	requirement def HumanOversightRequirement {
		doc /* High-risk, low-confidence, or ethically ambiguous decisions must be routed to the Ethical Review Board. */
		subject :>> governanceSystem : GovernanceSystem;
		require constraint { governanceSystem.controller.humanReviewRoutingEnabled == true }
	}
	
	requirement def AccountabilityRequirement {
		doc /* Every step must be recorded in an encrypted, immutable audit trail. */
		subject :>> governanceSystem : GovernanceSystem;
		require constraint { governanceSystem.auditTrailManager.encryptionEnabled == true }
		require constraint { governanceSystem.auditTrailManager.immutabilityEnsured == true }
	}
	
	requirement def ComplianceRequirement {
		doc /* All operations must adhere to applicable regulatory frameworks. */
		subject :>> governanceSystem : GovernanceSystem;
		require constraint { governanceSystem.complianceMonitor.complianceEnforced == true }
		require constraint { governanceSystem.complianceMonitor.monitoredFrameworks->size() > 0 }
	}
	
	requirement ethicalDecisionReq : EthicalDecisionRequirement;
	requirement fairnessReq : FairnessRequirement;
	requirement transparencyReq : TransparencyRequirement;
	requirement humanOversightReq : HumanOversightRequirement;
	requirement accountabilityReq : AccountabilityRequirement;
	requirement complianceReq : ComplianceRequirement;
}
