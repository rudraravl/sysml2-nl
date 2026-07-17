package OpportunityCostDecisionSystem {
    attribute def OptionsReceived;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MonetaryValue :> Real;
    attribute def UtilityScore :> Real;
    attribute def RiskFactor :> Real;
    attribute def TimeValue :> Real;
    
    item def Option {
        attribute optionId : String;
        attribute expectedValue : MonetaryValue;
        attribute requiredInvestment : MonetaryValue;
        attribute timeToRealize : TimeValue;
        attribute riskLevel : RiskFactor;
        attribute utilityScore : UtilityScore;
    }
    
    item def EvaluationCriteria {
        attribute returnWeight : Real;
        attribute riskWeight : Real;
        attribute timeWeight : Real;
        attribute utilityWeight : Real;
    }
    
    item def DecisionResult {
        attribute selectedOption : Option;
        attribute opportunityCost : MonetaryValue;
        attribute nextBestOption : Option;
        attribute justification : String;
    }
    
    port def OptionInputPort {
        in item candidateOptions : Option[2..*];
    }
    
    port def CriteriaInputPort {
        in item criteria : EvaluationCriteria;
    }
    
    port def DecisionOutputPort {
        out item decision : DecisionResult;
    }
    
    port def ResourceConstraintPort {
        in availableBudget : MonetaryValue;
        in availableTime : TimeValue;
    }
    
    part def OptionEvaluator {
        attribute evaluationThreshold : Real = 0.0;
        
        port optionsIn : OptionInputPort;
        port criteriaIn : CriteriaInputPort;
        port evaluatedOut {
            out rankedOptions : Option[1..*] ordered;
            out evaluationScores : Real[1..*] ordered;
        }
        
        action def RankOptions {
            in options : Option[2..*];
            in criteria : EvaluationCriteria;
            out ranked : Option[1..*] ordered;
            out scores : Real[1..*] ordered;
        }
        
        perform action evaluate : RankOptions;
    }
    
    part def OpportunityCostCalculator {
        attribute calculationMethod : String = "ValueDifferential";
        
        port rankedOptionsIn {
            in topOption : Option;
            in secondOption : Option;
        }
        port costOut {
            out opportunityCost : MonetaryValue;
            out costPercentage : Real;
        }
        
        action def ComputeOpportunityCost {
            in selected : Option;
            in nextBest : Option;
            out cost : MonetaryValue;
            out percentage : Real;
        }
        
        perform action compute : ComputeOpportunityCost;
    }
    
    part def DecisionValidator {
        attribute validationRules : String[1..*];
        
        port decisionIn {
            in proposedDecision : DecisionResult;
        }
        port constraintsIn : ResourceConstraintPort;
        port validationOut {
            out isValid : Boolean;
            out validatedDecision : DecisionResult;
            out violations : String[0..*];
        }
        
        action def ValidateDecision {
            in decision : DecisionResult;
            in budgetLimit : MonetaryValue;
            in timeLimit : TimeValue;
            out valid : Boolean;
            out issues : String[0..*];
        }
        
        perform action validate : ValidateDecision;
    }
    
    part def ReportGenerator {
        attribute reportFormat : String = "Detailed";
        
        port resultIn {
            in finalDecision : DecisionResult;
        }
        port reportOut {
            out decisionReport : String;
            out costAnalysis : String;
        }
        
        action def GenerateDecisionReport {
            in decision : DecisionResult;
            out report : String;
            out analysis : String;
        }
        
        perform action generate : GenerateDecisionReport;
    }
    
    action def OpportunityCostAnalysisWorkflow {
        first start;
        then action receiveOptions {
            out options : Option[2..*];
            out criteria : EvaluationCriteria;
        }
        then action rankAlternatives : OptionEvaluator::RankOptions {
            in options = receiveOptions.options;
            in criteria = receiveOptions.criteria;
            out ranked : Option[1..*] ordered;
            out scores : Real[1..*] ordered;
        }
        then action calculateCost : OpportunityCostCalculator::ComputeOpportunityCost {
            in selected : Option;
            in nextBest : Option;
            out cost : MonetaryValue;
            out percentage : Real;
        }
        then action prepareDecision {
            in topChoice : Option;
            in secondChoice : Option;
            in oppCost : MonetaryValue;
            out preliminaryDecision : DecisionResult;
        }
        then action validateChoice : DecisionValidator::ValidateDecision {
            in decision : DecisionResult;
            in budgetLimit : MonetaryValue;
            in timeLimit : TimeValue;
            out valid : Boolean;
            out issues : String[0..*];
        }
        then action generateReport : ReportGenerator::GenerateDecisionReport {
            in decision : DecisionResult;
            out report : String;
            out analysis : String;
        }
        then done;
    }
    
    state def DecisionSystemStates {
        entry; then idle;
        
        state idle;
        transition idle_to_evaluating
            first idle
            accept OptionsReceived
            then evaluating;
        
        state evaluating {
            entry; then rankingOptions;
            state rankingOptions;
            transition rankingOptions_to_scoringComplete
                first rankingOptions
                then scoringComplete;
            state scoringComplete;
        }
        transition evaluating_to_calculating
            first evaluating
            then calculating;
        
        state calculating {
            entry; then computeCost;
            state computeCost;
            transition computeCost_to_costDetermined
                first computeCost
                then costDetermined;
            state costDetermined;
        }
        transition calculating_to_validating
            first calculating
            then validating;
        
        state validating {
            entry; then checkConstraints;
            state checkConstraints;
            transition checkConstraints_to_validated
                first checkConstraints
                if "constraintsSatisfied"
                then validated;
            transition checkConstraints_to_revising
                first checkConstraints
                if "constraintsViolated"
                then revising;
            state validated;
            state revising;
            transition revising_to_checkConstraints
                first revising
                then checkConstraints;
        }
        transition validating_to_reporting
            first validating.validated
            then reporting;
        
        state reporting;
        transition reporting_to_idle
            first reporting
            then idle;
    }
    
    part opportunityCostSystem : OpportunityCostDecisionSystem {
        doc /* 
         * Primary Function: Evaluate multiple alternative courses of action,
         * select the optimal choice based on weighted criteria, and quantify
         * the opportunity cost as the value of the next-best foregone alternative.
         */
        
        attribute systemVersion : String = "1.0";
        attribute maxOptionsSupported : Integer = 10;
        
        part evaluator : OptionEvaluator {
            attribute :>> evaluationThreshold = 0.0;
        }
        
        part costCalculator : OpportunityCostCalculator {
            attribute :>> calculationMethod = "ValueDifferential";
        }
        
        part validator : DecisionValidator {
            attribute :>> validationRules = ("BudgetCompliance", "TimeCompliance", "RiskTolerance");
        }
        
        part reporter : ReportGenerator {
            attribute :>> reportFormat = "Detailed";
        }
        
        port systemOptionsIn : OptionInputPort;
        port systemCriteriaIn : CriteriaInputPort;
        port systemConstraintsIn : ResourceConstraintPort;
        port systemDecisionOut : DecisionOutputPort;
        
        connection evaluatorInput connect systemOptionsIn to evaluator.optionsIn;
        connection criteriaInput connect systemCriteriaIn to evaluator.criteriaIn;
        connection evaluatorToCalculator connect evaluator.evaluatedOut to costCalculator.rankedOptionsIn;
        connection calculatorToValidator connect costCalculator.costOut to validator.decisionIn;
        connection constraintsToValidator connect systemConstraintsIn to validator.constraintsIn;
        connection validatorToReporter connect validator.validationOut to reporter.resultIn;
        connection reporterToOutput connect reporter.reportOut to systemDecisionOut;
        
        perform action systemWorkflow : OpportunityCostAnalysisWorkflow;
        exhibit state systemBehavior : DecisionSystemStates;
    }
    
    requirement <'REQ-OCS-001'> primaryFunctionRequirement {
        doc /* 
         * The Opportunity Cost Decision System shall evaluate at least two 
         * alternative options and select the optimal choice while quantifying 
         * the opportunity cost as the expected value of the best foregone alternative.
         */
        subject system :>> opportunityCostSystem;
    }
    
    requirement <'REQ-OCS-002'> costCalculationRequirement {
        doc /* 
         * The opportunity cost shall be calculated as the difference in expected 
         * value between the second-ranked alternative and the selected top alternative.
         */
        subject calculator :>> opportunityCostSystem.costCalculator;
    }
    
    requirement <'REQ-OCS-003'> resourceConstraintRequirement {
        doc /* 
         * The system shall validate that the selected option does not exceed 
         * available budget and time constraints before finalizing the decision.
         */
        subject validator :>> opportunityCostSystem.validator;
    }
    
    requirement <'REQ-OCS-004'> multiCriteriaEvaluationRequirement {
        doc /* 
         * The system shall rank options using weighted criteria including 
         * expected return, risk level, time to realization, and utility score.
         */
        subject evaluator :>> opportunityCostSystem.evaluator;
    }
    
    requirement <'REQ-OCS-005'> reportingRequirement {
        doc /* 
         * The system shall generate a comprehensive decision report including 
         * the selected option, opportunity cost, next-best alternative, and 
         * justification for the decision.
         */
        subject reporter :>> opportunityCostSystem.reporter;
    }
    
    satisfy primaryFunctionRequirement by opportunityCostSystem;
    satisfy costCalculationRequirement by opportunityCostSystem.costCalculator;
    satisfy resourceConstraintRequirement by opportunityCostSystem.validator;
    satisfy multiCriteriaEvaluationRequirement by opportunityCostSystem.evaluator;
    satisfy reportingRequirement by opportunityCostSystem.reporter;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import OpportunityCostDecisionSystem::*;

    part opportunityCostSystem : OptionEvaluator {
        exhibit state sm : DecisionSystemStates;
    }

    action orchestrator {
        item testCriteria : EvaluationCriteria {
            attribute returnWeight = 0.0;
            attribute riskWeight = 0.0;
            attribute timeWeight = 0.0;
            attribute utilityWeight = 0.0;
        }
        action actionProbe : RankOptions {
            // TODO(human): unsupported input type for options: Option[2..*] (type is not a primitive, enum, extracted payload def, or known value type)
            in criteria = testCriteria;
        }
        attribute testOptionsReceived : OptionsReceived;
        action triggerOptionsReceived send testOptionsReceived to opportunityCostSystem;
        first actionProbe;
        then triggerOptionsReceived;
    }
}
