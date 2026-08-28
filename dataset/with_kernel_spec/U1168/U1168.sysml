package 'Proactionary Principle Governance System' {
	doc
	/*
	 * This system implements a governance framework based on the Proactionary Principle,
	 * designed to evaluate Innovation Initiatives by systematically balancing their
	 * potential opportunities against their manageable risks. Rather than defaulting to
	 * prohibition in the face of uncertainty, the system proactively identifies a safe
	 * path forward for beneficial progress. It provides a structured workflow for risk
	 * assessment, opportunity analysis, balanced decision-making, and adaptive monitoring
	 * over the full lifecycle of an approved initiative.
	 */

	private import ScalarValues::*;
	private import ISQ::*;
	private import Quantities::*;

	attribute def ProbabilityValue :> Real {
		doc /* Probability of an adverse event occurring, in [0, 1]. */
		assert constraint { 0.0 <= that and that <= 1.0 }
	}

	attribute def SeverityValue :> Real {
		doc /* Severity of an adverse outcome, in [0, 1]. */
		assert constraint { 0.0 <= that and that <= 1.0 }
	}

	attribute def ScoreValue :> Real {
		doc /* Normalized aggregate score on a [0, 1] scale. */
		assert constraint { 0.0 <= that and that <= 1.0 }
	}

	attribute def NetValueValue :> Real {
		doc /* Net value of an initiative: opportunity weighted against risk. */
	}

	attribute def ConfidenceLevelValue :> Real {
		doc /* Confidence in the net value estimate, in [0, 1]. */
		assert constraint { 0.0 <= that and that <= 1.0 }
	}

	attribute def BenefitMagnitudeValue :> Real {
		doc /* Magnitude of the expected benefit, in [0, 1]. */
		assert constraint { 0.0 <= that and that <= 1.0 }
	}

	attribute def FeasibilityValue :> Real {
		doc /* Feasibility of achieving the benefit, in [0, 1]. */
		assert constraint { 0.0 <= that and that <= 1.0 }
	}

	attribute def InnovationDegreeValue :> Real {
		doc /* Degree of novelty / innovation, in [0, 1]. */
		assert constraint { 0.0 <= that and that <= 1.0 }
	}

	attribute def DeviationValue :> Real {
		doc /* Deviation between projected and observed quantities. */
	}

	attribute def TimeHorizonValue :> TimeValue {
		doc /* Time from the present to when a risk or benefit is anticipated to occur. */
	}

	enum def DecisionKind {
		approve;
		reject;
	}

	enum def RiskCategoryKind {
		technical;
		financial;
		regulatory;
		social;
		environmental;
	}

	enum def SafeguardKind {
		mitigation;
		monitoring;
		adaptiveThreshold;
		contingency;
	}

	item def InnovationInitiative {
		attribute name : String;
		attribute description : String;
		attribute category : RiskCategoryKind;
		attribute targetBenefit : BenefitMagnitudeValue;
		attribute expectedFeasibility : FeasibilityValue;
		attribute innovationDegree : InnovationDegreeValue;
	}

	item def RiskFactor {
		attribute description : String;
		attribute severity : SeverityValue;
		attribute likelihood : ProbabilityValue;
		attribute timeHorizon : TimeHorizonValue;
		attribute category : RiskCategoryKind;
	}

	item def SafeguardPackage {
		attribute id : String;
		attribute mitigationStrategy : String;
		attribute monitoringProtocol : String;
		attribute adaptiveThreshold : ProbabilityValue;
		attribute safeguardType : SafeguardKind;
		ref riskFactor : RiskFactor;
	}

	item def RiskAssessment {
		ref initiative : InnovationInitiative;
		ref riskFactors : RiskFactor[1..*];
		ref safeguards : SafeguardPackage[1..*];
		attribute riskScore : ScoreValue;
	}

	item def OpportunityAssessment {
		ref initiative : InnovationInitiative;
		attribute benefitMagnitude : BenefitMagnitudeValue;
		attribute feasibility : FeasibilityValue;
		attribute innovationDegree : InnovationDegreeValue;
		attribute opportunityScore : ScoreValue;
	}

	item def ProactionaryDecision {
		ref initiative : InnovationInitiative;
		attribute decision : DecisionKind;
		attribute netValue : NetValueValue;
		attribute confidence : ConfidenceLevelValue;
		attribute justification : String;
		ref requiredSafeguards : SafeguardPackage[*];
	}

	item def MonitoringReport {
		ref initiative : InnovationInitiative;
		attribute observedBenefit : BenefitMagnitudeValue;
		attribute observedRisk : ScoreValue;
		attribute expectedBenefit : BenefitMagnitudeValue;
		attribute expectedRisk : ScoreValue;
		attribute benefitDeviation : DeviationValue;
		attribute riskDeviation : DeviationValue;
		attribute significantDeviation : Boolean;
	}

	item def AdaptationDirective {
		ref initiative : InnovationInitiative;
		ref updatedSafeguards : SafeguardPackage[1..*];
		attribute rationale : String;
	}

	port def InitiativeInPort {
		in initiative : InnovationInitiative;
	}

	port def RiskAssessmentOutPort {
		out assessment : RiskAssessment;
	}

	port def OpportunityAssessmentOutPort {
		out assessment : OpportunityAssessment;
	}

	port def DecisionOutPort {
		out decision : ProactionaryDecision;
	}

	port def MonitoringReportInPort {
		in report : MonitoringReport;
	}

	port def AdaptationDirectiveOutPort {
		out directive : AdaptationDirective;
	}

	port def ConfidenceInPort {
		in confidence : ConfidenceLevelValue;
	}

	calc def CalculateRiskScore {
		doc
		/*
		 * Aggregate the severity, likelihood, and time-horizon-discounted contribution
		 * of each RiskFactor into a single normalized RiskScore.
		 */
		in risks : RiskFactor[1..*];
		return score : ScoreValue;
	}

	calc def DesignSafeguard {
		doc /* Produce a SafeguardPackage tailored to a given RiskFactor. */
		in risk : RiskFactor;
		return safeguard : SafeguardPackage;
	}

	calc def CalculateOpportunityScore {
		doc /* Combine benefit, feasibility, and innovation into an OpportunityScore. */
		in benefit : BenefitMagnitudeValue;
		in feasibility : FeasibilityValue;
		in innovation : InnovationDegreeValue;
		return score : ScoreValue;
	}

	calc def CalculateNetValue {
		doc /* NetValue = (opportunity * confidenceWeight) - risk. */
		in opportunity : ScoreValue;
		in risk : ScoreValue;
		in confidenceWeight : ConfidenceLevelValue;
		return net : NetValueValue;
	}

	calc def EvaluateConfidence {
		doc /* Return true when the confidence-weighted net value exceeds threshold. */
		in net : NetValueValue;
		in threshold : ConfidenceLevelValue;
		return approved : Boolean;
	}

	calc def ComputeDeviations {
		doc
		/*
		 * Compute benefit and risk deviations and flag a significant deviation when
		 * either exceeds the tolerance.
		 */
		in observedBenefit : BenefitMagnitudeValue;
		in expectedBenefit : BenefitMagnitudeValue;
		in observedRisk : ScoreValue;
		in expectedRisk : ScoreValue;
		in tolerance : DeviationValue;
		return benefitDeviation : DeviationValue;
		return riskDeviation : DeviationValue;
		return significant : Boolean;
	}

	action def AssessRisk {
		doc
		/*
		 * Analyzes an InnovationInitiative to identify potential downsides, quantifies a
		 * RiskScore, and designs a SafeguardPackage to manage the identified risks.
		 */
		in init : InnovationInitiative;
		out assessment : RiskAssessment;
		action identifyRiskFactors {
			doc /* Identify candidate RiskFactors from the proposal's category and description. */
			in proposal : InnovationInitiative = init;
			out risks : RiskFactor[1..*];
		}
		then action scoreRisk {
			doc /* Compute an aggregate RiskScore from the identified RiskFactors. */
			in risks : RiskFactor[1..*] = identifyRiskFactors.risks;
			out riskScore : ScoreValue;
		}
		then action designSafeguards {
			doc /* Produce a SafeguardPackage for each identified RiskFactor. */
			in risks : RiskFactor[1..*] = identifyRiskFactors.risks;
			out packages : SafeguardPackage[1..*];
		}
	}

	action def AnalyzeOpportunity {
		doc
		/*
		 * Evaluates an InnovationInitiative to quantify its potential upside, including
		 * benefits, feasibility, and innovation degree, producing an OpportunityScore.
		 */
		in init : InnovationInitiative;
		out assessment : OpportunityAssessment;
		action assessBenefits {
			doc /* Derive the expected benefit magnitude from the proposal. */
			in proposal : InnovationInitiative = init;
			out benefit : BenefitMagnitudeValue;
		}
		then action assessFeasibility {
			doc /* Estimate the feasibility of realizing the benefits. */
			in proposal : InnovationInitiative = init;
			out feasibility : FeasibilityValue;
		}
		then action assessInnovation {
			doc /* Quantify the degree of novelty / innovation. */
			in proposal : InnovationInitiative = init;
			out innovation : InnovationDegreeValue;
		}
		then action scoreOpportunity {
			doc /* Combine benefit, feasibility, and innovation into an OpportunityScore. */
			in benefit : BenefitMagnitudeValue = assessBenefits.benefit;
			in feasibility : FeasibilityValue = assessFeasibility.feasibility;
			in innovation : InnovationDegreeValue = assessInnovation.innovation;
			out opportunityScore : ScoreValue;
		}
	}

	action def Balance {
		doc
		/*
		 * The central core component that weighs an OpportunityAssessment against a
		 * RiskAssessment to calculate the NetValue and make a formal ProactionaryDecision
		 * based on a predefined ConfidenceLevelValue.
		 */
		in riskAssessment : RiskAssessment;
		in opportunityAssessment : OpportunityAssessment;
		in confidence : ConfidenceLevelValue;
		in threshold : ConfidenceLevelValue;
		out decision : ProactionaryDecision;
		action computeNetValue {
			doc /* NetValue = (opportunity * confidenceWeight) - risk. */
			in opportunity : ScoreValue = opportunityAssessment.opportunityScore;
			in risk : ScoreValue = riskAssessment.riskScore;
			in confidenceWeight : ConfidenceLevelValue = confidence;
			out netValue : NetValueValue;
		}
		then action evaluateConfidence {
			doc /* Return true when the confidence-weighted net value exceeds threshold. */
			in netValue : NetValueValue = computeNetValue.netValue;
			in thresholdValue : ConfidenceLevelValue = threshold;
			out isApproved : Boolean;
		}
		then action issueDecision {
			doc /* Issue a formal ProactionaryDecision: approve with safeguards or reject with justification. */
			in isApproved : Boolean = evaluateConfidence.isApproved;
			in netValue : NetValueValue = computeNetValue.netValue;
			in conf : ConfidenceLevelValue = confidence;
			in safeguards : SafeguardPackage[1..*] = riskAssessment.safeguards;
			in init : InnovationInitiative = opportunityAssessment.initiative;
			out proactionaryDecision : ProactionaryDecision;
		}
	}

	action def Monitor {
		doc
		/*
		 * Continuously tracks an approved InnovationInitiative's real-world performance,
		 * compares observed benefits and risks against initial projections, and triggers
		 * adaptations to the SafeguardPackages when deviations exceed the adaptive threshold.
		 */
		in report : MonitoringReport;
		in tolerance : DeviationValue;
		in currentSafeguards : SafeguardPackage[1..*];
		out directive : AdaptationDirective;
		action computeDeviations {
			doc /* Compute benefit and risk deviations and flag significant deviations. */
			in observedBenefit : BenefitMagnitudeValue = report.observedBenefit;
			in expectedBenefit : BenefitMagnitudeValue = report.expectedBenefit;
			in observedRisk : ScoreValue = report.observedRisk;
			in expectedRisk : ScoreValue = report.expectedRisk;
			in tol : DeviationValue = tolerance;
			out benefitDeviation : DeviationValue;
			out riskDeviation : DeviationValue;
			out isSignificant : Boolean;
		}
		then action adaptSafeguards {
			doc /* Dynamically modify safeguards when significant deviations are detected. */
			in isSignificant : Boolean = computeDeviations.isSignificant;
			in safeguards : SafeguardPackage[1..*] = currentSafeguards;
			out updatedSafeguards : SafeguardPackage[1..*];
		}
	}

	part def RiskAssessmentModule {
		doc
		/*
		 * Analyzes an InnovationInitiative to identify potential downsides, quantifies a
		 * RiskScore, and designs a SafeguardPackage to manage the identified risks.
		 */
		port initiativeIn : InitiativeInPort;
		port assessmentOut : RiskAssessmentOutPort;
		attribute riskTolerance : ScoreValue = 0.7;

		action assessRisk : AssessRisk {
			in init = initiativeIn.initiative;
			out assessment = assessmentOut.assessment;
		}

		exhibit state riskAssessmentStates {
			entry; then receiving;
			state receiving;
			transition receiving then analyzing when initiativeIn.initiative != null;
			state analyzing;
			transition analyzing then emitting when assessmentOut.assessment != null;
			state emitting;
			then receiving;
		}
	}

	part def OpportunityAnalysisModule {
		doc
		/*
		 * Evaluates an InnovationInitiative to quantify its potential upside, including
		 * benefits, feasibility, and innovation degree, producing an OpportunityScore.
		 */
		port initiativeIn : InitiativeInPort;
		port assessmentOut : OpportunityAssessmentOutPort;

		action analyzeOpportunity : AnalyzeOpportunity {
			in init = initiativeIn.initiative;
			out assessment = assessmentOut.assessment;
		}

		exhibit state opportunityAnalysisStates {
			entry; then collecting;
			state collecting;
			transition collecting then evaluating when initiativeIn.initiative != null;
			state evaluating;
			transition evaluating then emitting when assessmentOut.assessment != null;
			state emitting;
			then collecting;
		}
	}

	part def BalancingEngine {
		doc
		/*
		 * The central core component that weighs an OpportunityAssessment against a
		 * RiskAssessment to calculate the NetValue and make a formal ProactionaryDecision
		 * based on a predefined ConfidenceLevelValue.
		 */
		port riskIn : RiskAssessmentOutPort;
		port opportunityIn : OpportunityAssessmentOutPort;
		port confidenceIn : ConfidenceInPort;
		port decisionOut : DecisionOutPort;
		attribute confidenceThreshold : ConfidenceLevelValue = 0.6;

		action balance : Balance {
			in riskAssessment = riskIn.assessment;
			in opportunityAssessment = opportunityIn.assessment;
			in confidence = confidenceIn.confidence;
			in threshold = confidenceThreshold;
			out decision = decisionOut.decision;
		}

		exhibit state balancingStates {
			entry; then awaiting;
			state awaiting;
			transition awaiting then weighing when riskIn.assessment != null and opportunityIn.assessment != null and confidenceIn.confidence != null;
			state weighing;
			transition weighing then deciding when decisionOut.decision != null;
			state deciding;
			transition deciding then approved when decisionOut.decision.decision == DecisionKind::approve;
			transition deciding then rejected when decisionOut.decision.decision == DecisionKind::reject;
			state approved;
			then awaiting;
			state rejected;
			then awaiting;
		}
	}

	part def AdaptiveMonitor {
		doc
		/*
		 * Continuously tracks an approved InnovationInitiative's real-world performance,
		 * compares observed benefits and risks against initial projections, and triggers
		 * adaptations to the SafeguardPackages when deviations exceed the adaptive threshold.
		 */
		port reportIn : MonitoringReportInPort;
		port directiveOut : AdaptationDirectiveOutPort;
		attribute deviationTolerance : DeviationValue = 0.2;
		ref approvedSafeguards : SafeguardPackage[1..*];

		action monitor : Monitor {
			in report = reportIn.report;
			in tolerance = deviationTolerance;
			in currentSafeguards = approvedSafeguards;
			out directive = directiveOut.directive;
		}

		exhibit state monitoringStates {
			entry; then observing;
			state observing;
			transition observing then comparing when reportIn.report != null;
			state comparing;
			transition comparing then adapting when reportIn.report.significantDeviation == true;
			transition comparing then observing when reportIn.report.significantDeviation == false;
			state adapting;
			then issuing;
			state issuing;
			then observing;
		}
	}

	part def ProactionaryGovernanceSystem {
		doc
		/*
		 * The complete Proactionary Principle Governance System, composed of the risk
		 * assessment, opportunity analysis, balancing, and adaptive monitoring modules.
		 * Orchestrates the full lifecycle: intake, parallel assessment, balancing and
		 * decision, and continuous adaptive monitoring of approved initiatives.
		 */
		part riskAssessmentModule : RiskAssessmentModule;
		part opportunityAnalysisModule : OpportunityAnalysisModule;
		part balancingEngine : BalancingEngine;
		part adaptiveMonitor : AdaptiveMonitor;

		port initiativeIn : InitiativeInPort;
		port confidenceIn : ConfidenceInPort;
		port decisionOut : DecisionOutPort;
		port monitoringReportIn : MonitoringReportInPort;
		port adaptationDirectiveOut : AdaptationDirectiveOutPort;

		connect initiativeIn to riskAssessmentModule.initiativeIn;
		connect initiativeIn to opportunityAnalysisModule.initiativeIn;
		connect riskAssessmentModule.assessmentOut to balancingEngine.riskIn;
		connect opportunityAnalysisModule.assessmentOut to balancingEngine.opportunityIn;
		connect confidenceIn to balancingEngine.confidenceIn;
		connect balancingEngine.decisionOut to decisionOut;
		connect monitoringReportIn to adaptiveMonitor.reportIn;
		connect adaptiveMonitor.directiveOut to adaptationDirectiveOut;

		exhibit state governanceLifecycle {
			entry; then idle;
			state idle;
			transition idle then assessing when initiativeIn.initiative != null;
			state assessing;
			transition assessing then balancing when riskAssessmentModule.assessmentOut.assessment != null and opportunityAnalysisModule.assessmentOut.assessment != null;
			state balancing;
			transition balancing then decisionMade when balancingEngine.decisionOut.decision != null;
			state decisionMade;
			transition decisionMade then monitoring when balancingEngine.decisionOut.decision.decision == DecisionKind::approve;
			transition decisionMade then closed when balancingEngine.decisionOut.decision.decision == DecisionKind::reject;
			state monitoring;
			transition monitoring then adapting when monitoringReportIn.report != null and monitoringReportIn.report.significantDeviation == true;
			transition monitoring then closed when monitoringReportIn.report != null and monitoringReportIn.report.significantDeviation == false;
			state adapting;
			then monitoring;
			state closed;
			then idle;
		}
	}

	package ProactionaryRequirements {
		requirement def ProactionaryDecisionRequirement {
			doc
			/*
			 * A proactionary decision shall favor approval of an initiative whose net value
			 * is positive and whose confidence meets the threshold, rather than defaulting
			 * to rejection in the face of uncertainty.
			 */
			subject decision : ProactionaryDecision;
			attribute netValue : NetValueValue;
			attribute confidence : ConfidenceLevelValue;
			attribute confidenceThreshold : ConfidenceLevelValue;
			require constraint {
				(netValue > 0.0 and confidence >= confidenceThreshold) implies
				(decision.decision == DecisionKind::approve)
			}
			require constraint {
				(netValue <= 0.0 or confidence < confidenceThreshold) implies
				(decision.decision == DecisionKind::reject)
			}
		}

		requirement def SafeguardBindingRequirement {
			doc
			/*
			 * Every approved initiative shall have at least one required safeguard bound
			 * to an identified risk factor.
			 */
			subject decision : ProactionaryDecision;
			require constraint {
				(decision.decision == DecisionKind::approve) implies
				(decision.requiredSafeguards->size() >= 1)
			}
		}

		requirement def RejectionJustificationRequirement {
			doc
			/*
			 * Every rejected initiative shall carry a non-empty justification.
			 */
			subject decision : ProactionaryDecision;
			require constraint {
				(decision.decision == DecisionKind::reject) implies
				(decision.justification != "")
			}
		}

		requirement def AdaptationLoopRequirement {
			doc
			/*
			 * When a monitoring report indicates a significant deviation, an adaptation
			 * directive updating at least one safeguard shall be issued.
			 */
			subject report : MonitoringReport;
			ref directive : AdaptationDirective;
			require constraint {
				(report.significantDeviation == true) implies
				(directive.updatedSafeguards->size() >= 1)
			}
		}

		requirement def NetValueDefinitionRequirement {
			doc
			/*
			 * Net value shall be computed as the opportunity score weighted by confidence,
			 * minus the risk score.
			 */
			attribute opportunity : ScoreValue;
			attribute risk : ScoreValue;
			attribute confidence : ConfidenceLevelValue;
			attribute netValue : NetValueValue;
			require constraint {
				netValue == (opportunity * confidence) - risk
			}
		}

		requirement def ContinuousMonitoringRequirement {
			doc
			/*
			 * For every approved initiative, the AdaptiveMonitor shall observe real-world
			 * performance and remain in the monitoring or adapting state for the lifecycle
			 * of the initiative.
			 */
			subject decision : ProactionaryDecision;
			ref monitor : AdaptiveMonitor;
			require constraint {
				(decision.decision == DecisionKind::approve) implies
				(monitor != null)
			}
		}
	}

	requirement proactionaryDecisionRequirement : ProactionaryRequirements::ProactionaryDecisionRequirement {
		:>> confidenceThreshold = 0.6;
	}

	requirement safeguardBindingRequirement : ProactionaryRequirements::SafeguardBindingRequirement;
	requirement rejectionJustificationRequirement : ProactionaryRequirements::RejectionJustificationRequirement;
	requirement adaptationLoopRequirement : ProactionaryRequirements::AdaptationLoopRequirement;
	requirement netValueDefinitionRequirement : ProactionaryRequirements::NetValueDefinitionRequirement;
	requirement continuousMonitoringRequirement : ProactionaryRequirements::ContinuousMonitoringRequirement;
}
