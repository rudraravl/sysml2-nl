package 'Cyberethics Governance System' {
	private import ScalarValues::Real;
	private import ScalarValues::String;
	private import ScalarValues::Boolean;
	private import ScalarValues::Integer;

	item def DigitalAction {
		attribute actionId : String;
		attribute userId : String;
		attribute actionType : String;
		attribute timestamp : String;
	}

	item def EthicalPolicy {
		attribute policyId : String;
		attribute version : Integer;
		attribute rules : String[0..*];
	}

	item def RuleViolation {
		attribute ruleId : String;
		attribute description : String;
	}

	value type EthicalScore :> Real {
		constraint { 0.0 <= self and self <= 1.0 }
	}

	item def ComplianceDecision {
		attribute actionId : String;
		attribute isCompliant : Boolean;
		attribute score : EthicalScore;
		attribute violations : RuleViolation[0..*];
		attribute requiresHumanReview : Boolean;
	}

	item def HumanVerdict {
		attribute actionId : String;
		attribute reviewerId : String;
		attribute finalDecision : String;
		attribute rationale : String;
	}

	item def AuditLogEntry {
		attribute logId : String;
		attribute digitalAction : DigitalAction;
		attribute decision : ComplianceDecision;
		attribute humanVerdict : HumanVerdict[0..1];
		attribute timestamp : String;
	}

	item def AnomalyAlert {
		attribute alertId : String;
		attribute userId : String;
		attribute alertDetails : String;
		attribute severity : Real;
	}

	part def PolicyManagementModule {
		port policyOut {
			out policy : EthicalPolicy;
		}
		attribute currentPolicy : EthicalPolicy;
	}

	part def EthicalAnalysisEngine {
		port actionIn {
			in digitalAction : DigitalAction;
		}
		port policyIn {
			in policy : EthicalPolicy;
		}
		port decisionOut {
			out decision : ComplianceDecision;
		}
		port escalationOut {
			out escalatedDecision : ComplianceDecision;
		}
		port verdictIn {
			in verdict : HumanVerdict;
		}

		action def AnalyzeAction {
			in digitalAction : DigitalAction;
			in policy : EthicalPolicy;
			out decision : ComplianceDecision;
		}
	}

	part def HumanReviewInterface {
		port escalationIn {
			in decision : ComplianceDecision;
		}
		port verdictOut {
			out verdict : HumanVerdict;
		}
	}

	part def TransparencyAuditModule {
		port decisionIn {
			in decision : ComplianceDecision;
		}
		port verdictIn {
			in verdict : HumanVerdict;
		}
		port actionIn {
			in digitalAction : DigitalAction;
		}
		action def LogAudit {
			in digitalAction : DigitalAction;
			in decision : ComplianceDecision;
			in verdict : HumanVerdict[0..1];
		}
	}

	part def BehaviorMonitoringModule {
		port actionIn {
			in digitalAction : DigitalAction;
		}
		port alertOut {
			out alert : AnomalyAlert;
		}

		action def MonitorBehavior {
			in digitalAction : DigitalAction;
			out alert : AnomalyAlert;
		}
	}

	part def HumanReviewer {
		port verdictOut {
			out verdict : HumanVerdict;
		}
	}

	part def CyberethicsGovernanceSystem {
		port actionIn {
			in digitalAction : DigitalAction;
		}
		port verdictIn {
			in verdict : HumanVerdict;
		}
		port alertOut {
			out alert : AnomalyAlert;
		}

		part analysisEngine : EthicalAnalysisEngine;
		part policyManager : PolicyManagementModule;
		part humanReviewInterface : HumanReviewInterface;
		part auditModule : TransparencyAuditModule;
		part behaviorMonitor : BehaviorMonitoringModule;

		flow policyFlow of EthicalPolicy
			from policyManager.policyOut.policy to analysisEngine.policyIn.policy;

		flow actionFlow of DigitalAction
			from actionIn.digitalAction to analysisEngine.actionIn.digitalAction;

		flow actionMonitorFlow of DigitalAction
			from actionIn.digitalAction to behaviorMonitor.actionIn.digitalAction;

		flow auditActionFlow of DigitalAction
			from actionIn.digitalAction to auditModule.actionIn.digitalAction;

		flow decisionFlow of ComplianceDecision
			from analysisEngine.decisionOut.decision to auditModule.decisionIn.decision;

		flow escalationFlow of ComplianceDecision
			from analysisEngine.escalationOut.escalatedDecision to humanReviewInterface.escalationIn.decision;

		flow internalVerdictFlow of HumanVerdict
			from verdictIn.verdict to auditModule.verdictIn.verdict;

		flow alertFlow of AnomalyAlert
			from behaviorMonitor.alertOut.alert to alertOut.alert;

		state governanceStates {
			entry; then idle;
			state idle;
			accept digitalAction : DigitalAction via actionIn
				then analyzing;
			state analyzing;
			accept decision : ComplianceDecision
				if decision.requiresHumanReview
				then escalated;
			accept decision : ComplianceDecision
				if not decision.requiresHumanReview
				then logging;
			state escalated;
			accept verdict : HumanVerdict via verdictIn
				then logging;
			state logging;
			then idle;
		}
	}

	part governanceSystem : CyberethicsGovernanceSystem;
	part humanReviewer : HumanReviewer;

	flow reviewerVerdictFlow of HumanVerdict
		from humanReviewer.verdictOut.verdict to governanceSystem.verdictIn.verdict;

	requirement def EthicalGovernance {
		doc "The system shall monitor, analyze, and enforce ethical rules within a digital environment in real-time.";
	}

	requirement def RealTimeMonitoring {
		doc "The system shall monitor digital actions in real-time.";
	}

	requirement def HumanInLoopEscalation {
		doc "The system shall escalate complex or high-risk cases to human operators.";
	}

	requirement def AuditTrailLogging {
		doc "The system shall log all actions, decisions, and human verdicts.";
	}

	requirement def AnomalyDetection {
		doc "The system shall detect anomalous behavior patterns over time.";
	}

	satisfy EthicalGovernance by governanceSystem;
	satisfy RealTimeMonitoring by governanceSystem.behaviorMonitor;
	satisfy HumanInLoopEscalation by governanceSystem.humanReviewInterface;
	satisfy AuditTrailLogging by governanceSystem.auditModule;
	satisfy AnomalyDetection by governanceSystem.behaviorMonitor;
}
