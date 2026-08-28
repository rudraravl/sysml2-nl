package DecisionSupportSystem {
	private import ScalarValues::*;
	private import ScalarFunctions::*;
	private import ControlFunctions::*;

	attribute def MonetaryValue :> Real {
		doc /* Monetary amount in currency units. */
	}
	attribute def TimeToRealize :> Real {
		doc /* Time to realize benefits, in months. */
	}
	attribute def RiskScore :> Real {
		doc /* Risk level from 0.0 (no risk) to 1.0 (maximum risk). */
		assert constraint { that >= 0.0 and that <= 1.0 }
	}
	attribute def UtilityScore :> Real {
		doc /* Subjective utility score from 0.0 to 1.0. */
		assert constraint { that >= 0.0 and that <= 1.0 }
	}
	attribute def Weight :> Real {
		doc /* Importance weight from 0.0 to 1.0. */
		assert constraint { that >= 0.0 and that <= 1.0 }
	}
	attribute def EvaluationScore :> Real {
		doc /* Composite weighted evaluation score for an option. */
	}

	item def Option {
		doc /* A candidate course of action under consideration. */
		attribute name : String;
		attribute expectedMonetaryValue : MonetaryValue;
		attribute requiredInvestment : MonetaryValue;
		attribute timeToRealize : TimeToRealize;
		attribute riskLevel : RiskScore;
		attribute utilityScore : UtilityScore;
	}

	item def EvaluationCriteria {
		doc /* User-defined weights for return, risk, time, and utility. */
		attribute returnWeight : Weight;
		attribute riskWeight : Weight;
		attribute timeWeight : Weight;
		attribute utilityWeight : Weight;
		assert constraint {
			returnWeight + riskWeight + timeWeight + utilityWeight == 1.0
		}
	}

	item def RankedOption {
		doc /* An option paired with its computed evaluation score. */
		ref attribute option : Option;
		attribute score : EvaluationScore;
	}

	item def OpportunityCostResult {
		doc /* Result of comparing the best and second-best options. */
		ref attribute bestOption : Option;
		ref attribute secondBestOption : Option;
		attribute opportunityCost : MonetaryValue;
		attribute scoreDifferential : EvaluationScore;
	}

	item def DecisionReport {
		doc /* Final report summarizing the validated decision. */
		ref attribute selectedOption : Option;
		attribute justification : String;
		ref attribute nextBestOption : Option;
		attribute opportunityCost : MonetaryValue;
		attribute feasible : Boolean;
	}

	item def Constraints {
		doc /* Practical limits on budget and time. */
		attribute budgetLimit : MonetaryValue;
		attribute timeLimit : TimeToRealize;
	}

	calc def EvaluateOption {
		doc /* Compute a composite weighted score for a single option. */
		in option : Option;
		in criteria : EvaluationCriteria;
		return score : EvaluationScore;
	}

	calc def RankOptions {
		doc /* Produce a list of ranked options sorted best-to-worst by score. */
		in options : Option[2..*];
		in criteria : EvaluationCriteria;
		return ranked : RankedOption[2..*];
	}

	calc def CalculateOpportunityCost {
		doc /* Compute the value differential between the best and second-best options. */
		in ranked : RankedOption[2..*];
		return result : OpportunityCostResult;
	}

	calc def ValidateDecision {
		doc /* Check the best option against budget and time constraints. */
		in ranked : RankedOption[2..*];
		in constraints : Constraints;
		return feasible : Boolean;
	}

	calc def GenerateReport {
		doc /* Assemble a comprehensive decision report. */
		in ranked : RankedOption[2..*];
		in costResult : OpportunityCostResult;
		in feasible : Boolean;
		return report : DecisionReport;
	}

	port def OptionInputPort {
		in item options : Option[2..*];
		in item criteria : EvaluationCriteria;
	}
	port def RankedOutputPort {
		out item rankedOptions : RankedOption[2..*];
	}
	port def CostResultPort {
		out item costResult : OpportunityCostResult;
	}
	port def ValidationOutputPort {
		out item feasible : Boolean;
	}
	port def ReportPort {
		out item report : DecisionReport;
	}
	port def ConstraintsInputPort {
		in item constraints : Constraints;
	}

	part def OptionEvaluator {
		doc /* Analyzes and scores all provided options based on weighted criteria. */
		port optionInput : OptionInputPort;
		port rankedOutput : RankedOutputPort;
		calc rank : RankOptions {
			in options = optionInput.options;
			in criteria = optionInput.criteria;
			return ranked;
		}
		flow from rank.ranked to rankedOutput.rankedOptions;
	}

	part def OpportunityCostCalculator {
		doc /* Calculates the opportunity cost between the top two ranked options. */
		port rankedInput : ~RankedOutputPort;
		port costOutput : CostResultPort;
		calc cost : CalculateOpportunityCost {
			in ranked = rankedInput.rankedOptions;
			return result;
		}
		flow from cost.result to costOutput.costResult;
	}

	part def DecisionValidator {
		doc /* Validates the top-ranked choice against budget and time constraints. */
		port rankedInput : ~RankedOutputPort;
		port constraintsInput : ConstraintsInputPort;
		port validationOutput : ValidationOutputPort;
		calc validate : ValidateDecision {
			in ranked = rankedInput.rankedOptions;
			in constraints = constraintsInput.constraints;
			return feasible;
		}
		flow from validate.feasible to validationOutput.feasible;
	}

	part def ReportGenerator {
		doc /* Creates a comprehensive summary report of the validated decision. */
		port rankedInput : ~RankedOutputPort;
		port costResultInput : ~CostResultPort;
		port feasibilityInput : ~ValidationOutputPort;
		port reportOutput : ReportPort;
		calc generate : GenerateReport {
			in ranked = rankedInput.rankedOptions;
			in costResult = costResultInput.costResult;
			in feasible = feasibilityInput.feasible;
			return report;
		}
		flow from generate.report to reportOutput.report;
	}

	state machine def DecisionWorkflow {
		doc /* Workflow states for the decision-support system. */
		state idle {
			doc /* Awaiting next decision-making task. */
			transition to evaluating;
		}
		state evaluating {
			doc /* Evaluating all options against weighted criteria. */
			transition to calculatingCost;
		}
		state calculatingCost {
			doc /* Calculating opportunity cost between top two options. */
			transition to validating;
		}
		state validating {
			doc /* Validating the best option against constraints. */
			transition to reporting;
			transition to revising;
		}
		state revising {
			doc /* Best option violated a constraint; awaiting revised inputs. */
			transition to evaluating;
		}
		state reporting {
			doc /* Generating the final decision report. */
			transition to idle;
		}
	}

	part def DecisionSupportSystem {
		doc /* Top-level decision-support system integrating all components. */
		port optionInput : OptionInputPort;
		port constraintsInput : ConstraintsInputPort;
		port reportOutput : ReportPort;

		part optionEvaluator : OptionEvaluator {
			port :>> optionInput;
		}
		part opportunityCostCalculator : OpportunityCostCalculator;
		part decisionValidator : DecisionValidator {
			port :>> constraintsInput;
		}
		part reportGenerator : ReportGenerator {
			port :>> reportOutput;
		}

		connect optionEvaluator.rankedOutput to opportunityCostCalculator.rankedInput;
		connect optionEvaluator.rankedOutput to decisionValidator.rankedInput;
		connect optionEvaluator.rankedOutput to reportGenerator.rankedInput;
		connect opportunityCostCalculator.costOutput to reportGenerator.costResultInput;
		connect decisionValidator.validationOutput to reportGenerator.feasibilityInput;

		exhibit state workflow : DecisionWorkflow;
	}

	requirement def ShallEvaluateOptions {
		doc /* The system shall evaluate all provided options using weighted criteria. */
		subject decisionSystem : DecisionSupportSystem;
		in ref options : Option[2..*];
		in ref criteria : EvaluationCriteria;
		require constraint { options->size() >= 2 }
	}

	requirement def ShallCalculateOpportunityCost {
		doc /* The system shall calculate opportunity cost as the value differential between the best and second-best options. */
		subject decisionSystem : DecisionSupportSystem;
		in ref ranked : RankedOption[2..*];
		require constraint { ranked[1].score >= ranked[2].score }
	}

	requirement def ShallValidateDecision {
		doc /* The system shall validate the best option against budget and time constraints. */
		subject decisionSystem : DecisionSupportSystem;
		in ref ranked : RankedOption[2..*];
		in ref constraints : Constraints;
		require constraint {
			ranked[1].option.requiredInvestment <= constraints.budgetLimit and
			ranked[1].option.timeToRealize <= constraints.timeLimit
		}
	}

	requirement def ShallGenerateReport {
		doc /* The system shall generate a report detailing the selected option, justification, opportunity cost, and next-best alternative. */
		subject decisionSystem : DecisionSupportSystem;
		in ref report : DecisionReport;
		require constraint { report.selectedOption <> null }
	}

	package ExampleUsage {
		private import DecisionSupportSystem::*;

		item optionA : Option {
			attribute :>> name = "Investment A";
			attribute :>> expectedMonetaryValue = 150000.0;
			attribute :>> requiredInvestment = 50000.0;
			attribute :>> timeToRealize = 12.0;
			attribute :>> riskLevel = 0.3;
			attribute :>> utilityScore = 0.8;
		}
		item optionB : Option {
			attribute :>> name = "Investment B";
			attribute :>> expectedMonetaryValue = 120000.0;
			attribute :>> requiredInvestment = 40000.0;
			attribute :>> timeToRealize = 8.0;
			attribute :>> riskLevel = 0.2;
			attribute :>> utilityScore = 0.7;
		}
		item optionC : Option {
			attribute :>> name = "Investment C";
			attribute :>> expectedMonetaryValue = 180000.0;
			attribute :>> requiredInvestment = 80000.0;
			attribute :>> timeToRealize = 18.0;
			attribute :>> riskLevel = 0.6;
			attribute :>> utilityScore = 0.9;
		}
		item userCriteria : EvaluationCriteria {
			attribute :>> returnWeight = 0.4;
			attribute :>> riskWeight = 0.3;
			attribute :>> timeWeight = 0.2;
			attribute :>> utilityWeight = 0.1;
		}
		item userConstraints : Constraints {
			attribute :>> budgetLimit = 90000.0;
			attribute :>> timeLimit = 24.0;
		}

		part exampleSystem : DecisionSupportSystem {
			port :>> optionInput {
				in item :>> options = (optionA, optionB, optionC);
				in item :>> criteria = userCriteria;
			}
			port :>> constraintsInput {
				in item :>> constraints = userConstraints;
			}
		}
	}
}
