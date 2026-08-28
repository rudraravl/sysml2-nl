package StrategicDecisionSupportSystem {
    import ScalarValues::*;
    import Collections::List;
    
    value type USD :> Real;
    value type Months :> Real;
    value type RiskFactor :> Real;
    value type UtilityValue :> Real;
    value type WeightFactor :> Real;
    value type ScoreValue :> Real;
    
    item def StrategicOption {
        attribute name : String;
        attribute expectedMonetaryValue : USD;
        attribute requiredInvestment : USD;
        attribute timeToRealize : Months;
        attribute riskLevel : RiskFactor;
        attribute utilityScore : UtilityValue;
    }
    
    item def EvaluationCriteria {
        attribute returnWeight : WeightFactor;
        attribute riskWeight : WeightFactor;
        attribute timeWeight : WeightFactor;
        attribute utilityWeight : WeightFactor;
    }
    
    item def UserConstraints {
        attribute maxBudget : USD;
        attribute maxTime : Months;
    }
    
    item def RankedOption {
        ref option : StrategicOption;
        attribute score : ScoreValue;
    }
    
    item def DecisionReport {
        ref selectedOption : StrategicOption;
        ref nextBestOption : StrategicOption;
        attribute opportunityCost : USD;
        attribute isFeasible : Boolean;
        attribute justification : String;
    }
    
    requirement def StrategicDecisionRequirements {
        doc / Requirements for the strategic decision support system. //
        
        requirement evaluateOptionsReq {
            doc / The Option Evaluator shall analyze and score all provided options based on the user's weighted criteria, producing a ranked list from best to worst. //
        }
        
        requirement calculateOpportunityCostReq {
            doc / The Opportunity Cost Calculator shall calculate the opportunity cost, defined as the value differential between the chosen best option and the second-best alternative. //
        }
        
        requirement validateDecisionReq {
            doc / The Decision Validator shall check the top-ranked choice against practical constraints, such as the user's available budget and time limits. If the best option violates a constraint, the system shall enter a state for revision. //
        }
        
        requirement generateReportReq {
            doc / The Report Generator shall create a comprehensive summary detailing the selected option, justifying the choice, presenting the calculated opportunity cost, and identifying the next-best alternative. //
        }
    }
    
    action def EvaluateOptionsAction {
        in options : List<StrategicOption>;
        in criteria : EvaluationCriteria;
        out rankedList : List<RankedOption>;
    }
    
    action def CalculateOpportunityCostAction {
        in rankedList : List<RankedOption>;
        out selectedOption : StrategicOption;
        out nextBestOption : StrategicOption;
        out opportunityCost : USD;
    }
    
    action def ValidateDecisionAction {
        in selectedOption : StrategicOption;
        in constraints : UserConstraints;
        out isValid : Boolean;
    }
    
    action def GenerateReportAction {
        in selectedOption : StrategicOption;
        in nextBestOption : StrategicOption;
        in opportunityCost : USD;
        in isValid : Boolean;
        out report : DecisionReport;
    }
    
    part def OptionEvaluator {
        port in optionsInput : List<StrategicOption>;
        port in criteriaInput : EvaluationCriteria;
        port out rankedOutput : List<RankedOption>;
        
        action evaluate : EvaluateOptionsAction;
        bind evaluate.options = optionsInput;
        bind evaluate.criteria = criteriaInput;
        bind evaluate.rankedList = rankedOutput;
    }
    
    part def OpportunityCostCalculator {
        port in rankedInput : List<RankedOption>;
        port out selectedOutput : StrategicOption;
        port out nextBestOutput : StrategicOption;
        port out costOutput : USD;
        
        action calculate : CalculateOpportunityCostAction;
        bind calculate.rankedList = rankedInput;
        bind calculate.selectedOption = selectedOutput;
        bind calculate.nextBestOption = nextBestOutput;
        bind calculate.opportunityCost = costOutput;
    }
    
    part def DecisionValidator {
        port in selectedInput : StrategicOption;
        port in constraintsInput : UserConstraints;
        port out validOutput : Boolean;
        
        action validate : ValidateDecisionAction;
        bind validate.selectedOption = selectedInput;
        bind validate.constraints = constraintsInput;
        bind validate.isValid = validOutput;
    }
    
    part def ReportGenerator {
        port in selectedInput : StrategicOption;
        port in nextBestInput : StrategicOption;
        port in costInput : USD;
        port in validInput : Boolean;
        port out reportOutput : DecisionReport;
        
        action generate : GenerateReportAction;
        bind generate.selectedOption = selectedInput;
        bind generate.nextBestOption = nextBestInput;
        bind generate.opportunityCost = costInput;
        bind generate.isValid = validInput;
        bind generate.report = reportOutput;
    }
    
    part def DecisionSupportSystem {
        port in optionsPort : List<StrategicOption>;
        port in criteriaPort : EvaluationCriteria;
        port in constraintsPort : UserConstraints;
        port out reportPort : DecisionReport;
        
        part evaluator : OptionEvaluator;
        part costCalculator : OpportunityCostCalculator;
        part validator : DecisionValidator;
        part reportGenerator : ReportGenerator;
        
        flow from optionsPort to evaluator.optionsInput;
        flow from criteriaPort to evaluator.criteriaInput;
        flow from evaluator.rankedOutput to costCalculator.rankedInput;
        flow from costCalculator.selectedOutput to validator.selectedInput;
        flow from costCalculator.selectedOutput to reportGenerator.selectedInput;
        flow from costCalculator.nextBestOutput to reportGenerator.nextBestInput;
        flow from costCalculator.costOutput to reportGenerator.costInput;
        flow from constraintsPort to validator.constraintsInput;
        flow from validator.validOutput to reportGenerator.validInput;
        flow from reportGenerator.reportOutput to reportPort;
        
        state machine DecisionProcess {
            state idle;
            state evaluating;
            state calculatingCost;
            state validating;
            state revising;
            state reporting;
            
            transition idle -> evaluating when optionsPort != null;
            transition evaluating -> calculatingCost when evaluator.rankedOutput != null;
            transition calculatingCost -> validating when costCalculator.costOutput != null;
            transition validating -> reporting when validator.validOutput == true;
            transition validating -> revising when validator.validOutput == false;
            transition revising -> evaluating when optionsPort != null;
            transition reporting -> idle when reportGenerator.reportOutput != null;
        }
    }
}
