package CyberethicsGovernance {

    import ScalarValues::*;

    // ===== Value Types =====

    value type TimeStamp :> Real {
        doc { Milliseconds since epoch. }
    }

    value type DurationValue :> Real {
        doc { Duration in milliseconds. }
    }

    value type EthicalScore :> Real {
        doc { Ethical alignment score on a scale of 0 to 100. }
    }

    value type RiskLevel :> Real {
        doc { Risk level from 0.0 (none) to 1.0 (critical). }
    }

    value type SeverityLevel :> Real {
        doc { Severity of a rule violation from 0.0 to 1.0. }
    }

    value type ConfidenceValue :> Real {
        doc { Confidence in an automated decision from 0.0 to 1.0. }
    }

    // ===== Enumerations =====

    enumeration DecisionAction {
        value allow;
        value warn;
        value block;
        value escalate;
    }

    // ===== Item Definitions =====

    item def DigitalAction {
        attribute actionId : String;
        attribute userId : String;
        attribute actionType : String;
        attribute content : String;
        attribute timestamp : TimeStamp;
        attribute platformId : String;
        attribute context : String;
    }

    item def EthicalRule {
        attribute ruleId : String;
        attribute name : String;
        attribute description : String;
        attribute weight : Real;
        attribute threshold : EthicalScore;
    }

    item def EthicalPolicy {
        attribute policyId : String;
        attribute name : String;
        attribute version : String;
        attribute effectiveDate : TimeStamp;
        attribute rules : EthicalRule[0..*];
    }

    item def RuleViolation {
        attribute ruleId : String;
        attribute ruleName : String;
        attribute severity : SeverityLevel;
        attribute explanation : String;
    }

    item def ComplianceDecision {
        attribute decisionId : String;
        attribute actionId : String;
        attribute decisionAction : DecisionAction;
        attribute ethicalScore : EthicalScore;
        attribute riskLevel : RiskLevel;
        attribute confidence : ConfidenceValue;
        attribute violations : RuleViolation[0..*];
        attribute requiresHumanReview : Boolean;
        attribute timestamp : TimeStamp;
    }

    item def HumanReviewRequest {
        attribute requestId : String;
        attribute reviewedAction : DigitalAction;
        attribute preliminaryDecision : ComplianceDecision;
        attribute escalationReason : String;
        attribute submittedAt : TimeStamp;
    }

    item def HumanReviewVerdict {
        attribute verdictId : String;
        attribute requestId : String;
        attribute actionId : String;
        attribute finalDecision : DecisionAction;
        attribute rationale : String;
        attribute reviewerId : String;
        attribute timestamp : TimeStamp;
    }

    item def AuditRecord {
        attribute recordId : String;
        attribute auditedAction : DigitalAction;
        attribute decision : ComplianceDecision;
        attribute humanVerdict : HumanReviewVerdict[0..1];
        attribute loggedAt : TimeStamp;
    }

    item def BehaviorPattern {
        attribute userId : String;
        attribute totalActions : Integer;
        attribute flaggedActions : Integer;
        attribute firstSeen : TimeStamp;
        attribute lastSeen : TimeStamp;
        attribute averageEthicalScore : EthicalScore;
    }

    item def BehaviorAlert {
        attribute alertId : String;
        attribute userId : String;
        attribute alertType : String;
        attribute description : String;
        attribute severity : SeverityLevel;
        attribute detectedAt : TimeStamp;
    }

    // ===== Action Definitions =====

    action def EvaluateCompliance {
        in evaluatedAction : DigitalAction;
        in policy : EthicalPolicy;
        out decision : ComplianceDecision;
    }

    action def ComputeEthicalScore {
        in evaluatedAction : DigitalAction;
        in policy : EthicalPolicy;
        out score : EthicalScore;
        out violations : RuleViolation[0..*];
    }

    action def AssessRisk {
        in evaluatedAction : DigitalAction;
        in score : EthicalScore;
        out risk : RiskLevel;
    }

    action def EvaluateComplexity {
        in decision : ComplianceDecision;
        out shouldEscalate : Boolean;
    }

    action def SubmitForReview {
        in request : HumanReviewRequest;
        out verdict : HumanReviewVerdict;
    }

    action def LogAuditRecord {
        in auditedAction : DigitalAction;
        in decision : ComplianceDecision;
        in verdict : HumanReviewVerdict[0..1];
        out record : AuditRecord;
    }

    action def DetectAnomaly {
        in pattern : BehaviorPattern;
        out alert : BehaviorAlert;
    }

    action def UpdatePolicy {
        in newPolicy : EthicalPolicy;
    }

    // ===== Part Definitions =====

    part def PolicyManagementModule {
        in port policyUpdateIn : EthicalPolicy;
        out port policyOut : EthicalPolicy;

        attribute storedPolicies : EthicalPolicy[0..*];
        attribute activePolicy : EthicalPolicy;

        action updatePolicy : UpdatePolicy;

        action retrieveActivePolicy {
            out policy : EthicalPolicy;
        }

        action activatePolicy {
            in policyId : String;
        }
    }

    part def EthicalAnalysisEngine {
        in port actionIn : DigitalAction;
        in port policyIn : EthicalPolicy;
        out port decisionOut : ComplianceDecision;
        out port reviewRequestOut : HumanReviewRequest;

        attribute currentAction : DigitalAction;
        attribute currentPolicy : EthicalPolicy;
        attribute currentDecision : ComplianceDecision;
        attribute escalationThreshold : RiskLevel = 0.7;
        attribute confidenceThreshold : ConfidenceValue = 0.6;

        action evaluateCompliance : EvaluateCompliance;
        action computeScore : ComputeEthicalScore;
        action assessRisk : AssessRisk;
        action evaluateComplexity : EvaluateComplexity;

        action generateReviewRequest {
            in action : DigitalAction;
            in decision : ComplianceDecision;
            out request : HumanReviewRequest;
        }
    }

    part def HumanReviewInterface {
        in port reviewRequestIn : HumanReviewRequest;
        out port verdictOut : HumanReviewVerdict;

        attribute pendingRequests : HumanReviewRequest[0..*];
        attribute assignedReviewerId : String;

        action displayCase {
            in request : HumanReviewRequest;
        }

        action submitVerdict : SubmitForReview;

        action acknowledgeRequest {
            in request : HumanReviewRequest;
        }
    }

    part def TransparencyAuditModule {
        in port actionIn : DigitalAction;
        in port decisionIn : ComplianceDecision;
        in port verdictIn : HumanReviewVerdict;
        out port recordOut : AuditRecord;

        attribute auditTrail : AuditRecord[0..*];
        attribute totalRecordsLogged : Integer = 0;

        action logRecord : LogAuditRecord;

        action generateReport {
            in startTime : TimeStamp;
            in endTime : TimeStamp;
            out records : AuditRecord[0..*];
        }

        action verifyIntegrity {
            in recordId : String;
            out isValid : Boolean;
        }
    }

    part def BehaviorMonitoringModule {
        in port actionIn : DigitalAction;
        out port alertOut : BehaviorAlert;

        attribute observedPatterns : BehaviorPattern[0..*];
        attribute alertThreshold : Real = 0.75;
        attribute observationWindow : DurationValue = 86400000;

        action observeAction {
            in action : DigitalAction;
        }

        action updatePattern {
            in action : DigitalAction;
        }

        action detectAnomalies : DetectAnomaly;

        action generateAlert {
            in alert : BehaviorAlert;
        }
    }

    // ===== Requirements =====

    requirement def RealTimeMonitoring {
        doc {
            The system shall receive and process every digital action in real time
            as it occurs within the monitored digital environment.
        }
    }

    requirement def EthicalAnalysis {
        doc {
            The system shall evaluate each digital action against the currently
            active ethical policy maintained by the Policy Management Module.
        }
    }

    requirement def EthicalScoring {
        doc {
            The system shall assign an ethical score to every evaluated action,
            quantifying how well the action aligns with the ethical policy on
            a scale of 0 to 100.
        }
    }

    requirement def RuleViolationReporting {
        doc {
            The system shall produce a list of specific rule violations for
            each evaluated action, including the rule identifier, severity,
            and a human-readable explanation.
        }
    }

    requirement def HumanInTheLoop {
        doc {
            If the Ethical Analysis Engine determines an action is too complex,
            high-risk, or ethically ambiguous, the system shall escalate the
            case to the Human Review Interface and await a final human verdict
            before completing the audit process.
        }
    }

    requirement def TransparencyAudit {
        doc {
            The system shall log every digital action, the corresponding automated
            decision, and any human review verdict into a permanent audit trail
            maintained by the Transparency Audit Module.
        }
    }

    requirement def BehaviorAnomalyDetection {
        doc {
            The Behavior Monitoring Module shall continuously observe patterns in
            user actions over time and raise alerts about anomalous or suspicious
            behavior that might not be caught by evaluating single actions
            in isolation.
        }
    }

    requirement def PolicyManagement {
        doc {
            The system shall provide a Policy Management Module for configuring
            and updating the set of ethical rules that govern digital actions.
        }
    }

    requirement def LifecycleManagement {
        doc {
            The system shall operate in a defined lifecycle consisting of the
            states idle, analyzing, deciding, escalated (when needed), and
            auditing, before returning to idle for the next action.
        }
    }

    // ===== Top-Level System =====

    part def CyberethicsGovernanceSystem {
        in port actionIn : DigitalAction;
        in port policyUpdateIn : EthicalPolicy;
        out port alertOut : BehaviorAlert;
        out port reportOut : AuditRecord;

        attribute systemId : String = "CEGS-001";
        attribute isOperational : Boolean = true;
        attribute actionsProcessed : Integer = 0;
        attribute casesEscalated : Integer = 0;

        part policyModule : PolicyManagementModule;
        part analysisEngine : EthicalAnalysisEngine;
        part reviewInterface : HumanReviewInterface;
        part auditModule : TransparencyAuditModule;
        part behaviorMonitor : BehaviorMonitoringModule;

        // ---- Connections ----
        connect actionIn to analysisEngine.actionIn;
        connect actionIn to auditModule.actionIn;
        connect actionIn to behaviorMonitor.actionIn;
        connect policyUpdateIn to policyModule.policyUpdateIn;
        connect policyModule.policyOut to analysisEngine.policyIn;
        connect analysisEngine.decisionOut to auditModule.decisionIn;
        connect analysisEngine.reviewRequestOut to reviewInterface.reviewRequestIn;
        connect reviewInterface.verdictOut to auditModule.verdictIn;
        connect behaviorMonitor.alertOut to alertOut;
        connect auditModule.recordOut to reportOut;

        // ---- State Machine ----
        state governanceLifecycle {
            attribute currentAction : DigitalAction;
            attribute currentDecision : ComplianceDecision;
            attribute currentVerdict : HumanReviewVerdict[0..1];
            attribute actionReceived : Boolean = false;
            attribute analysisComplete : Boolean = false;
            attribute decisionReady : Boolean = false;
            attribute escalationNeeded : Boolean = false;
            attribute verdictReceived : Boolean = false;
            attribute auditComplete : Boolean = false;

            state idle {
                entry {
                    currentAction = null;
                    currentDecision = null;
                    currentVerdict = null;
                    analysisComplete = false;
                    decisionReady = false;
                    escalationNeeded = false;
                    verdictReceived = false;
                    auditComplete = false;
                }
            }

            state analyzing {
                entry {
                    perform analysisEngine.evaluateCompliance;
                    analysisComplete = true;
                }
                exit {
                    analysisComplete = false;
                }
            }

            state deciding {
                entry {
                    perform analysisEngine.evaluateComplexity;
                    decisionReady = true;
                    if currentDecision.requiresHumanReview {
                        escalationNeeded = true;
                    }
                }
                exit {
                    decisionReady = false;
                }
            }

            state escalated {
                entry {
                    perform reviewInterface.displayCase;
                }
                exit {
                    escalationNeeded = false;
                    verdictReceived = false;
                }
            }

            state auditing {
                entry {
                    perform auditModule.logRecord;
                    auditComplete = true;
                }
                exit {
                    auditComplete = false;
                    actionsProcessed = actionsProcessed + 1;
                    if currentDecision.requiresHumanReview {
                        casesEscalated = casesEscalated + 1;
                    }
                }
            }

            transition idle_to_analyzing
                idle -> analyzing
                when actionReceived;

            transition analyzing_to_deciding
                analyzing -> deciding
                when analysisComplete;

            transition deciding_to_escalated
                deciding -> escalated
                when decisionReady && escalationNeeded;

            transition deciding_to_auditing
                deciding -> auditing
                when decisionReady && !escalationNeeded;

            transition escalated_to_auditing
                escalated -> auditing
                when verdictReceived;

            transition auditing_to_idle
                auditing -> idle
                when auditComplete;
        }

        // ---- Requirement Satisfaction ----
        satisfies RealTimeMonitoring;
        satisfies EthicalAnalysis;
        satisfies EthicalScoring;
        satisfies RuleViolationReporting;
        satisfies HumanInTheLoop;
        satisfies TransparencyAudit;
        satisfies BehaviorAnomalyDetection;
        satisfies PolicyManagement;
        satisfies LifecycleManagement;
    }
}
