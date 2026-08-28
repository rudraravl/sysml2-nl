package ProactionaryGovernanceSystem {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Value Types with Units ----
    value type SeverityValue :> Real { unit "severityIndex"; }
    value type LikelihoodValue :> Real { unit "probability"; }
    value type TimeHorizon :> Real { unit "month"; }
    value type BenefitScore :> Real { unit "score"; }
    value type FeasibilityScore :> Real { unit "score"; }
    value type InnovationDegree :> Real { unit "score"; }
    value type OpportunityScore :> Real { unit "score"; }
    value type RiskScore :> Real { unit "score"; }
    value type NetValue :> Real { unit "score"; }
    value type ConfidenceLevel :> Real { unit "percent"; }
    value type Deviation :> Real { unit "percent"; }
    value type ThresholdValue :> Real { unit "score"; }

    // ---- Item Definitions ----
    item def InnovationInitiative {
        attribute name : String;
        attribute description : String;
        attribute category : String; // "technology" | "venture" | "research"
        attribute proposedAt : String;
    }

    item def RiskAssessment {
        attribute riskScore : RiskScore;
        attribute severity : SeverityValue;
        attribute likelihood : LikelihoodValue;
        attribute timeHorizon : TimeHorizon;
        attribute description : String;
    }

    item def SafeguardPackage {
        attribute mitigationStrategies : String;
        attribute monitoringProtocols : String;
        attribute adaptiveThreshold : ThresholdValue;
        attribute reviewInterval : TimeHorizon;
    }

    item def OpportunityAssessment {
        attribute opportunityScore : OpportunityScore;
        attribute benefits : String;
        attribute feasibility : FeasibilityScore;
        attribute innovationDegree : InnovationDegree;
    }

    item def ProactionaryDecision {
        attribute approved : Boolean;
        attribute justification : String;
        attribute requiredSafeguards : SafeguardPackage;
        attribute netValue : NetValue;
        attribute confidence : ConfidenceLevel;
    }

    item def PerformanceReport {
        attribute actualBenefits : BenefitScore;
        attribute actualRisks : RiskScore;
        attribute deviation : Deviation;
        attribute timestamp : String;
    }

    item def AdaptationDirective {
        attribute modifiedSafeguards : SafeguardPackage;
        attribute reason : String;
        attribute severity : SeverityValue;
    }

    // ---- Port Definitions ----
    port def InitiativeInputPort {
        in item initiative : InnovationInitiative;
    }
    port def RiskAssessmentOutPort {
        out item riskAssessment : RiskAssessment;
        out item safeguard : SafeguardPackage;
    }
    port def OpportunityAssessmentOutPort {
        out item opportunityAssessment : OpportunityAssessment;
    }
    port def DecisionOutPort {
        out item decision : ProactionaryDecision;
    }
    port def PerformanceInPort {
        in item report : PerformanceReport;
    }
    port def AdaptationOutPort {
        out item directive : AdaptationDirective;
    }
    port def SafeguardUpdatePort {
        in item directive : AdaptationDirective;
    }

    // ---- Requirements ----
    requirement def EvaluateInitiativeRequirement {
        doc "The system shall evaluate new innovation initiatives by systematically balancing potential opportunities against manageable risks, defaulting to safe paths forward rather than prohibition."
        attribute id : String = "REQ-001";
        subject governanceSystem : ProactionaryGovernanceSystem;
        objective {
            doc "Each proposed InnovationInitiative shall produce a ProactionaryDecision."
        }
    }

    requirement def RiskAssessmentRequirement {
        doc "The Risk Assessment Module shall quantify risk by severity, likelihood, and time horizon, and shall design a corresponding SafeguardPackage."
        attribute id : String = "REQ-002";
        subject riskModule : RiskAssessmentModule;
        objective {
            doc "A SafeguardPackage shall accompany every RiskAssessment."
        }
    }

    requirement def OpportunityAnalysisRequirement {
        doc "The Opportunity Analysis Module shall assess benefits, feasibility, and innovation degree to calculate an opportunity score."
        attribute id : String = "REQ-003";
        subject opportunityModule : OpportunityAnalysisModule;
        objective {
            doc "An OpportunityAssessment shall be produced for each initiative."
        }
    }

    requirement def BalancingEngineRequirement {
        doc "The Balancing Engine shall calculate net value by weighing opportunity score against risk score and shall issue a ProactionaryDecision based on a predefined confidence level."
        attribute id : String = "REQ-004";
        subject balancingEngine : BalancingEngine;
        objective {
            doc "Approved decisions shall specify required safeguards; rejected decisions shall include clear justification."
        }
    }

    requirement def AdaptiveMonitorRequirement {
        doc "The Adaptive Monitor shall continuously track real-world performance, compare actual benefits and risks against initial projections, and trigger adaptations on significant deviations."
        attribute id : String = "REQ-005";
        subject adaptiveMonitor : AdaptiveMonitor;
        objective {
            doc "AdaptationDirective shall be issued when deviation exceeds adaptiveThreshold."
        }
    }

    // ---- Parts ----
    part def RiskAssessmentModule {
        port initiativeIn : InitiativeInputPort;
        port assessmentOut : RiskAssessmentOutPort;

        attribute defaultThreshold : ThresholdValue = 0.5;
        attribute defaultReviewInterval : TimeHorizon = 6.0;

        state riskAssessmentState {
            entry; then analyzing;
            state analyzing;
            transition analyzing to designingSafeguards
                when initiativeIn.initiative != null;
            state designingSafeguards;
            transition designingSafeguards to emitting
                when assessmentOut.safeguard != null;
            state emitting;
            transition emitting to analyzing
                when initiativeIn.initiative != null;
        }

        action assessRisk {
            in initiative : InnovationInitiative;
            out riskAssessment : RiskAssessment;
            out safeguard : SafeguardPackage;

            // Compute risk score as weighted combination
            perform {
                riskAssessment.riskScore := riskAssessment.severity * 0.5 + riskAssessment.likelihood * 0.5;
                safeguard.adaptiveThreshold := defaultThreshold;
                safeguard.reviewInterval := defaultReviewInterval;
            }
        }
    }

    part def OpportunityAnalysisModule {
        port initiativeIn : InitiativeInputPort;
        port assessmentOut : OpportunityAssessmentOutPort;

        attribute innovationWeight : Real = 0.3;
        attribute feasibilityWeight : Real = 0.4;
        attribute benefitWeight : Real = 0.3;

        state opportunityAnalysisState {
            entry; then evaluating;
            state evaluating;
            transition evaluating to scoring
                when initiativeIn.initiative != null;
            state scoring;
            transition scoring to emitting
                when assessmentOut.opportunityAssessment != null;
            state emitting;
            transition emitting to evaluating
                when initiativeIn.initiative != null;
        }

        action assessOpportunity {
            in initiative : InnovationInitiative;
            out opportunityAssessment : OpportunityAssessment;

            perform {
                opportunityAssessment.opportunityScore :=
                    opportunityAssessment.feasibility * feasibilityWeight +
                    opportunityAssessment.innovationDegree * innovationWeight +
                    benefitScore(opportunityAssessment) * benefitWeight;
            }
        }

        private action benefitScore {
            in assessment : OpportunityAssessment;
            return score : BenefitScore;
            perform { score := 0.0; }
        }
    }

    part def BalancingEngine {
        port riskIn : RiskAssessmentOutPort;
        port opportunityIn : OpportunityAssessmentOutPort;
        port decisionOut : DecisionOutPort;

        attribute confidenceThreshold : ConfidenceLevel = 70.0;
        attribute opportunityWeight : Real = 0.6;
        attribute riskWeight : Real = 0.4;

        state balancingState {
            entry; then awaitingInputs;
            state awaitingInputs;
            transition awaitingInputs to computing
                when riskIn.riskAssessment != null and opportunityIn.opportunityAssessment != null;
            state computing;
            transition computing to deciding
                when decisionOut.decision == null;
            state deciding;
            transition deciding to emitting
                when decisionOut.decision != null;
            state emitting;
            transition emitting to awaitingInputs
                when riskIn.riskAssessment != null;
        }

        action computeNetValue {
            in riskAssessment : RiskAssessment;
            in opportunityAssessment : OpportunityAssessment;
            out netValue : NetValue;

            perform {
                netValue := opportunityWeight * opportunityAssessment.opportunityScore -
                    riskWeight * riskAssessment.riskScore;
            }
        }

        action makeDecision {
            in riskAssessment : RiskAssessment;
            in opportunityAssessment : OpportunityAssessment;
            in safeguard : SafeguardPackage;
            in netValue : NetValue;
            out decision : ProactionaryDecision;

            perform {
                if netValue > 0.0 and confidenceThreshold <= 70.0 {
                    decision.approved := true;
                    decision.requiredSafeguards := safeguard;
                    decision.justification := "Net value positive with manageable risk; safeguards required.";
                } else {
                    decision.approved := false;
                    decision.justification := "Net value insufficient or risk exceeds confidence threshold.";
                }
                decision.netValue := netValue;
                decision.confidence := confidenceThreshold;
            }
        }
    }

    part def AdaptiveMonitor {
        port performanceIn : PerformanceInPort;
        port adaptationOut : AdaptationOutPort;
        port safeguardUpdate : SafeguardUpdatePort;

        attribute deviationThreshold : Deviation = 20.0;
        attribute baselineSafeguard : SafeguardPackage;

        state monitoringState {
            entry; then tracking;
            state tracking;
            transition tracking to evaluating
                when performanceIn.report != null;
            state evaluating;
            transition evaluating to adapting
                when performanceIn.report.deviation > deviationThreshold;
            transition evaluating to tracking
                when performanceIn.report.deviation <= deviationThreshold;
            state adapting;
            transition adapting to tracking
                when adaptationOut.directive != null;
        }

        action evaluatePerformance {
            in report : PerformanceReport;
            in baselineSafeguard : SafeguardPackage;
            out directive : AdaptationDirective;

            perform {
                directive.modifiedSafeguards := baselineSafeguard;
                directive.modifiedSafeguards.adaptiveThreshold :=
                    baselineSafeguard.adaptiveThreshold * 0.9;
                directive.reason := "Significant deviation detected; safeguards tightened.";
                directive.severity := report.actualRisks;
            }
        }
    }

    // ---- Top-level System ----
    part def ProactionaryGovernanceSystem {
        port initiativeInput : InitiativeInputPort;
        port decisionOutput : DecisionOutPort;
        port performanceInput : PerformanceInPort;
        port adaptationOutput : AdaptationOutPort;

        part riskAssessmentModule : RiskAssessmentModule {
            port initiativeIn : InitiativeInputPort;
            port assessmentOut : RiskAssessmentOutPort;
        }
        part opportunityAnalysisModule : OpportunityAnalysisModule {
            port initiativeIn : InitiativeInputPort;
            port assessmentOut : OpportunityAssessmentOutPort;
        }
        part balancingEngine : BalancingEngine {
            port riskIn : RiskAssessmentOutPort;
            port opportunityIn : OpportunityAssessmentOutPort;
            port decisionOut : DecisionOutPort;
        }
        part adaptiveMonitor : AdaptiveMonitor {
            port performanceIn : PerformanceInPort;
            port adaptationOut : AdaptationOutPort;
            port safeguardUpdate : SafeguardUpdatePort;
        }

        // Internal connections
        connection initiativeToRisk connect initiativeInput to riskAssessmentModule.initiativeIn;
        connection initiativeToOpportunity connect initiativeInput to opportunityAnalysisModule.initiativeIn;
        connection riskToEngine connect riskAssessmentModule.assessmentOut to balancingEngine.riskIn;
        connection opportunityToEngine connect opportunityAnalysisModule.assessmentOut to balancingEngine.opportunityIn;
        connection engineDecision connect balancingEngine.decisionOut to decisionOutput;
        connection performanceToMonitor connect performanceInput to adaptiveMonitor.performanceIn;
        connection monitorAdaptation connect adaptiveMonitor.adaptationOut to adaptationOutput;

        // Requirement satisfaction
        satisfy EvaluateInitiativeRequirement by self;
        satisfy RiskAssessmentRequirement by riskAssessmentModule;
        satisfy OpportunityAnalysisRequirement by opportunityAnalysisModule;
        satisfy BalancingEngineRequirement by balancingEngine;
        satisfy AdaptiveMonitorRequirement by adaptiveMonitor;
    }
}
