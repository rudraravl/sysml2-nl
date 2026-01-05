package 'Automated Reasoning System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SequenceFunctions::*;
    
    attribute def ConfidenceScore :> Real;
    
    attribute def InferenceDepth :> Integer;
    
    item def LogicalFact {
        attribute factId : String;
        attribute predicate : String;
        attribute arguments : String[*];
        attribute confidence : ConfidenceScore;
        attribute source : String;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def InferenceRule {
        attribute ruleId : String;
        attribute name : String;
        attribute antecedents : String[1..*];
        attribute consequent : String;
        attribute priority : Integer;
        attribute applicabilityCondition : String;
    }
    
    item def QueryRequest {
        attribute queryId : String;
        attribute question : String;
        attribute context : String[*];
        attribute maxInferenceDepth : InferenceDepth;
        attribute minConfidence : ConfidenceScore;
    }
    
    item def InferenceTrace {
        attribute traceId : String;
        attribute appliedRules : String[*] ordered;
        attribute derivedFacts : String[*] ordered;
        attribute inferenceSteps : Integer;
    }
    
    item def ReasoningConclusion {
        attribute conclusionId : String;
        attribute answer : String;
        attribute supportingFacts : LogicalFact[*];
        attribute trace : InferenceTrace;
        attribute overallConfidence : ConfidenceScore;
        attribute completionTime : ISQ::TimeValue;
    }
    
    port def KnowledgeInputPort {
        in item fact : LogicalFact;
        in item rule : InferenceRule;
    }
    
    port def KnowledgeOutputPort {
        out item facts : LogicalFact[*];
        out item rules : InferenceRule[*];
    }
    
    port def QueryInterfacePort {
        in item query : QueryRequest;
        out item conclusion : ReasoningConclusion;
    }
    
    port def InferenceControlPort {
        in item factSet : LogicalFact[*];
        in item ruleSet : InferenceRule[*];
        in item queryContext : QueryRequest;
        out item derivedConclusions : ReasoningConclusion;
    }
    
    part def KnowledgeRepository {
        doc /* Stores and manages the knowledge base of facts and inference rules */
        
        attribute storedFacts : LogicalFact[*];
        attribute storedRules : InferenceRule[*];
        attribute factIndex : String;
        attribute ruleIndex : String;
        
        port knowledgeIn : KnowledgeInputPort;
        port knowledgeOut : KnowledgeOutputPort;
        
        action def AddFact {
            in newFact : LogicalFact;
            out updatedFacts : LogicalFact[*];
            
            first start;
            then action validateFact : ValidateFactConsistency {
                in fact = newFact;
                in existingFacts = storedFacts;
                out isValid : Boolean;
            }
            then decide;
                if validateFact.isValid then storeFact;
                else rejectFact;
            
            action storeFact {
                then assign updatedFacts := storedFacts->including(newFact);
            }
            then done;
            
            action rejectFact {
                then assign updatedFacts := storedFacts;
            }
            then done;
        }
        
        action def AddRule {
            in newRule : InferenceRule;
            out updatedRules : InferenceRule[*];
        }
        
        action def RetrieveRelevantKnowledge {
            in queryContext : String[*];
            out relevantFacts : LogicalFact[*];
            out applicableRules : InferenceRule[*];
        }
        
        action def ValidateFactConsistency {
            in fact : LogicalFact;
            in existingFacts : LogicalFact[*];
            out isValid : Boolean;
        }
    }
    
    part def ForwardChainingEngine {
        doc /* Performs forward chaining inference from facts to derive new conclusions */
        
        attribute workingMemory : LogicalFact[*];
        attribute firedRules : InferenceRule[*];
        attribute currentDepth : InferenceDepth;
        
        action def PerformForwardChaining {
            in initialFacts : LogicalFact[*];
            in rules : InferenceRule[*];
            in maxDepth : InferenceDepth;
            out derivedFacts : LogicalFact[*];
            out trace : InferenceTrace;
            
            private attribute localMemory := initialFacts;
            private attribute localFired : InferenceRule[*] := ();
            private attribute depth := 0;
            
            first start;
            then action iterateRules {
                for rule in rules {
                    action checkApplicability : CheckRuleApplicable {
                        in currentRule = rule;
                        in availableFacts = localMemory;
                        in alreadyFired = localFired;
                        out canApply : Boolean;
                    }
                    then decide;
                        if checkApplicability.canApply then applyThisRule;
                    
                    action applyThisRule {
                        action fireRule : FireInferenceRule {
                            in rule = rule;
                            in facts = localMemory;
                            out newFact : LogicalFact;
                        }
                        then assign localMemory := localMemory->including(fireRule.newFact);
                        then assign localFired := localFired->including(rule);
                        then assign depth := depth + 1;
                    }
                }
            }
            then action buildTrace : ConstructInferenceTrace {
                in appliedRules = localFired;
                in generatedFacts = localMemory;
                in inferenceDepth = depth;
                out inferenceTrace;
            }
            then assign derivedFacts := localMemory;
            then assign trace := buildTrace.inferenceTrace;
            then done;
        }
        
        action def CheckRuleApplicable {
            in currentRule : InferenceRule;
            in availableFacts : LogicalFact[*];
            in alreadyFired : InferenceRule[*];
            out canApply : Boolean;
        }
        
        action def FireInferenceRule {
            in rule : InferenceRule;
            in facts : LogicalFact[*];
            out newFact : LogicalFact;
        }
        
        action def ConstructInferenceTrace {
            in appliedRules : InferenceRule[*];
            in generatedFacts : LogicalFact[*];
            in inferenceDepth : InferenceDepth;
            out inferenceTrace : InferenceTrace;
        }
    }
    
    part def BackwardChainingEngine {
        doc /* Performs backward chaining inference from goal to find supporting facts */
        
        attribute goalStack : String[*];
        attribute provenGoals : String[*];
        attribute searchDepth : InferenceDepth;
        
        action def PerformBackwardChaining {
            in goal : String;
            in facts : LogicalFact[*];
            in rules : InferenceRule[*];
            in maxDepth : InferenceDepth;
            out isProven : Boolean;
            out supportingFacts : LogicalFact[*];
            out trace : InferenceTrace;
            
            private attribute localStack := (goal);
            private attribute localProven : String[*] := ();
            private attribute localSupporting : LogicalFact[*] := ();
            private attribute depth := 0;
            
            first start;
            then action searchGoals {
                action checkFacts : SearchFactsForGoal {
                    in targetGoal = goal;
                    in knownFacts = facts;
                    out found : Boolean;
                    out matchingFacts : LogicalFact[*];
                }
                then decide;
                    if checkFacts.found then markProven;
                    else findRules;
                
                action markProven {
                    then assign localProven := localProven->including(goal);
                    then assign localSupporting := localSupporting->union(checkFacts.matchingFacts);
                    then assign isProven := true;
                }
                then merge buildResult;
                
                action findRules {
                    action selectRule : FindRuleForGoal {
                        in targetGoal = goal;
                        in ruleSet = rules;
                        out matchingRule : InferenceRule;
                        out hasMatch : Boolean;
                    }
                    then decide;
                        if selectRule.hasMatch then expandGoal;
                        else notProven;
                    
                    action expandGoal {
                        then assign depth := depth + 1;
                    }
                    then merge buildResult;
                    
                    action notProven {
                        then assign isProven := false;
                    }
                    then merge buildResult;
                }
            }
            
            merge action buildResult {
                action createTrace : ConstructBackwardTrace {
                    in provenGoalList = localProven;
                    in searchDepth = depth;
                    out backwardTrace;
                }
                then assign trace := createTrace.backwardTrace;
                then assign supportingFacts := localSupporting;
            }
            then done;
        }
        
        action def SearchFactsForGoal {
            in targetGoal : String;
            in knownFacts : LogicalFact[*];
            out found : Boolean;
            out matchingFacts : LogicalFact[*];
        }
        
        action def FindRuleForGoal {
            in targetGoal : String;
            in ruleSet : InferenceRule[*];
            out matchingRule : InferenceRule;
            out hasMatch : Boolean;
        }
        
        action def ConstructBackwardTrace {
            in provenGoalList : String[*];
            in searchDepth : InferenceDepth;
            out backwardTrace : InferenceTrace;
        }
    }
    
    part def ConsistencyValidator {
        doc /* Validates logical consistency of the knowledge base */
        
        action def CheckKnowledgeConsistency {
            in facts : LogicalFact[*];
            in rules : InferenceRule[*];
            out isConsistent : Boolean;
            out contradictions : String[*];
            
            first start;
            then action detectDirectContradictions : FindDirectContradictions {
                in factSet = facts;
                out directConflicts : String[*];
            }
            then action detectRuleConflicts : FindRuleConflicts {
                in ruleSet = rules;
                in factBase = facts;
                out ruleConflicts : String[*];
            }
            then action detectCircularDependencies : FindCircularRules {
                in ruleSet = rules;
                out circularChains : String[*];
            }
            then decide;
                if (detectDirectContradictions.directConflicts->size() > 0 |
                    detectRuleConflicts.ruleConflicts->size() > 0 |
                    detectCircularDependencies.circularChains->size() > 0)
                then inconsistent;
                else consistent;
            
            action inconsistent {
                then assign isConsistent := false;
                then assign contradictions := 
                    detectDirectContradictions.directConflicts
                    ->union(detectRuleConflicts.ruleConflicts)
                    ->union(detectCircularDependencies.circularChains);
            }
            then done;
            
            action consistent {
                then assign isConsistent := true;
                then assign contradictions := ();
            }
            then done;
        }
        
        action def FindDirectContradictions {
            in factSet : LogicalFact[*];
            out directConflicts : String[*];
        }
        
        action def FindRuleConflicts {
            in ruleSet : InferenceRule[*];
            in factBase : LogicalFact[*];
            out ruleConflicts : String[*];
        }
        
        action def FindCircularRules {
            in ruleSet : InferenceRule[*];
            out circularChains : String[*];
        }
    }
    
    part def ExplanationGenerator {
        doc /* Generates human-readable explanations of reasoning process */
        
        action def GenerateExplanation {
            in conclusion : ReasoningConclusion;
            in query : QueryRequest;
            out explanation : String;
            out visualTrace : String;
            
            first start;
            then action formatTrace : FormatInferenceTrace {
                in trace = conclusion.trace;
                out formattedSteps : String;
            }
            then action highlightKeyFacts : IdentifyKeyFacts {
                in supportingFacts = conclusion.supportingFacts;
                in allSteps = conclusion.trace.derivedFacts;
                out keyFactDescriptions : String[*];
            }
            then action createVisualization : GenerateProofDiagram {
                in inferenceSteps = conclusion.trace.appliedRules;
                in factFlow = conclusion.trace.derivedFacts;
                out diagram : String;
            }
            then action assembleText : ComposeExplanationText {
                in originalQuestion = query.question;
                in finalAnswer = conclusion.answer;
                in reasoningSteps = formatTrace.formattedSteps;
                in keyFacts = highlightKeyFacts.keyFactDescriptions;
                in confidenceLevel = conclusion.overallConfidence;
                out fullText : String;
            }
            then assign explanation := assembleText.fullText;
            then assign visualTrace := createVisualization.diagram;
            then done;
        }
        
        action def FormatInferenceTrace {
            in trace : InferenceTrace;
            out formattedSteps : String;
        }
        
        action def IdentifyKeyFacts {
            in supportingFacts : LogicalFact[*];
            in allSteps : String[*];
            out keyFactDescriptions : String[*];
        }
        
        action def GenerateProofDiagram {
            in inferenceSteps : String[*];
            in factFlow : String[*];
            out diagram : String;
        }
        
        action def ComposeExplanationText {
            in originalQuestion : String;
            in finalAnswer : String;
            in reasoningSteps : String;
            in keyFacts : String[*];
            in confidenceLevel : ConfidenceScore;
            out fullText : String;
        }
    }
    
    part def ReasoningCoordinator {
        doc /* Coordinates the overall reasoning process and strategy selection */
        
        attribute currentStrategy : String;
        
        action def CoordinateReasoning {
            in query : QueryRequest;
            in facts : LogicalFact[*];
            in rules : InferenceRule[*];
            out conclusion : ReasoningConclusion;
            
            first start;
            then action selectStrategy : DetermineReasoningStrategy {
                in queryType = query.question;
                in knowledgeSize = facts->size();
                in ruleComplexity = rules->size();
                out strategy : String;
            }
            then decide;
                if selectStrategy.strategy == "forward" then useForward;
                if selectStrategy.strategy == "backward" then useBackward;
                else useForward;
            
            action useForward {
                action forward : ForwardChainingEngine::PerformForwardChaining {
                    in initialFacts = facts;
                    in rules = rules;
                    in maxDepth = query.maxInferenceDepth;
                    out derivedFacts;
                    out trace;
                }
                then action extractAnswer : ExtractAnswerFromDerivedFacts {
                    in allFacts = forward.derivedFacts;
                    in originalQuery = query;
                    out answer : String;
                    out relevantFacts : LogicalFact[*];
                    out confidence : ConfidenceScore;
                }
                then merge constructConclusion;
            }
            
            action useBackward {
                action backward : BackwardChainingEngine::PerformBackwardChaining {
                    in goal = query.question;
                    in facts = facts;
                    in rules = rules;
                    in maxDepth = query.maxInferenceDepth;
                    out isProven;
                    out supportingFacts;
                    out trace;
                }
                then action formAnswer : FormulateBackwardAnswer {
                    in proven = backward.isProven;
                    in facts = backward.supportingFacts;
                    in originalQuery = query;
                    out answer : String;
                    out confidence : ConfidenceScore;
                }
                then merge constructConclusion;
            }
            
            merge action constructConclusion {
                action buildConclusion : AssembleConclusion {
                    in queryId = query.queryId;
                    in answer : String;
                    in facts : LogicalFact[*];
                    in trace : InferenceTrace;
                    in confidence : ConfidenceScore;
                    out finalConclusion : ReasoningConclusion;
                }
                then assign conclusion := buildConclusion.finalConclusion;
            }
            then done;
        }
        
        action def DetermineReasoningStrategy {
            in queryType : String;
            in knowledgeSize : Integer;
            in ruleComplexity : Integer;
            out strategy : String;
        }
        
        action def ExtractAnswerFromDerivedFacts {
            in allFacts : LogicalFact[*];
            in originalQuery : QueryRequest;
            out answer : String;
            out relevantFacts : LogicalFact[*];
            out confidence : ConfidenceScore;
        }
        
        action def FormulateBackwardAnswer {
            in proven : Boolean;
            in facts : LogicalFact[*];
            in originalQuery : QueryRequest;
            out answer : String;
            out confidence : ConfidenceScore;
        }
        
        action def AssembleConclusion {
            in queryId : String;
            in answer : String;
            in facts : LogicalFact[*];
            in trace : InferenceTrace;
            in confidence : ConfidenceScore;
            out finalConclusion : ReasoningConclusion;
        }
    }
    
    part def AutomatedReasoningSystem {
        doc /* 
            An automated reasoning system that performs logical inference over a knowledge base
            to answer queries and derive new conclusions. The system accepts facts and inference rules,
            applies forward chaining, backward chaining, or hybrid reasoning strategies, validates
            knowledge consistency, and generates human-readable explanations of its reasoning process.
            
            Primary function: Given a query and a knowledge base of facts and rules, the system
            automatically derives logical conclusions through systematic inference, selects appropriate
            reasoning strategies, validates consistency, and provides transparent explanations of
            how conclusions were reached.
        */
        
        part repository : KnowledgeRepository {
            port :>> knowledgeIn;
            port :>> knowledgeOut;
        }
        
        part forwardEngine : ForwardChainingEngine;
        
        part backwardEngine : BackwardChainingEngine;
        
        part validator : ConsistencyValidator;
        
        part explainer : ExplanationGenerator;
        
        part coordinator : ReasoningCoordinator;
        
        port systemQueryInterface : QueryInterfacePort;
        port systemKnowledgeInterface : KnowledgeInputPort;
        
        connection factInput : ItemFlow
            connect systemKnowledgeInterface.fact to repository.knowledgeIn.fact;
        
        connection ruleInput : ItemFlow
            connect systemKnowledgeInterface.rule to repository.knowledgeIn.rule;
        
        perform action processQuery[*] ordered references mainReasoningProcess;
    }
    
    part automatedReasoningSystem : AutomatedReasoningSystem;
    
    action def ProcessQueryWithReasoning {
        in query : QueryRequest;
        out conclusion : ReasoningConclusion;
        out explanation : String;
    }
    
    action def GenerateInconsistencyReport {
        in conflicts : String[*];
        in queryId : String;
        out errorConclusion : ReasoningConclusion;
        out errorExplanation : String;
    }
    
    action mainReasoningProcess : ProcessQueryWithReasoning {
        in query : QueryRequest;
        out conclusion : ReasoningConclusion;
        out explanation : String;
        
        first start;
        then action loadKnowledge : automatedReasoningSystem.repository::RetrieveRelevantKnowledge {
            in queryContext = query.context;
            out relevantFacts;
            out applicableRules;
        }
        then action validateConsistency : automatedReasoningSystem.validator::CheckKnowledgeConsistency {
            in facts = loadKnowledge.relevantFacts;
            in rules = loadKnowledge.applicableRules;
            out isConsistent;
            out contradictions;
        }
        then decide;
            if validateConsistency.isConsistent then proceedWithReasoning;
            else reportInconsistency;
        
        action proceedWithReasoning {
            action reason : automatedReasoningSystem.coordinator::CoordinateReasoning {
                in query = mainReasoningProcess::query;
                in facts = loadKnowledge.relevantFacts;
                in rules = loadKnowledge.applicableRules;
                out conclusion;
            }
            then action explain : automatedReasoningSystem.explainer::GenerateExplanation {
                in conclusion = reason.conclusion;
                in query = mainReasoningProcess::query;
                out explanation;
                out visualTrace;
            }
            then assign conclusion := reason.conclusion;
            then assign explanation := explain.explanation;
        }
        then done;
        
        action reportInconsistency {
            action createErrorReport : GenerateInconsistencyReport {
                in conflicts = validateConsistency.contradictions;
                in queryId = query.queryId;
                out errorConclusion;
                out errorExplanation;
            }
            then assign conclusion := createErrorReport.errorConclusion;
            then assign explanation := createErrorReport.errorExplanation;
        }
        then done;
    }
    
    requirement def AutomatedReasoningRequirements {
        doc /* Requirements for the automated reasoning system */
        
        requirement <'AR-1'> soundnessRequirement {
            doc /* The system shall only derive conclusions that are logically valid given the knowledge base */
            subject system : AutomatedReasoningSystem;
        }
        
        requirement <'AR-2'> completenessRequirement {
            doc /* The system shall derive all conclusions reachable within the specified inference depth */
            subject coordinator : ReasoningCoordinator;
        }
        
        requirement <'AR-3'> consistencyValidationRequirement {
            doc /* The system shall detect and report logical contradictions before performing inference */
            subject validator : ConsistencyValidator;
        }
        
        requirement <'AR-4'> explanationRequirement {
            doc /* The system shall provide complete, human-readable explanations for all conclusions */
            subject explainer : ExplanationGenerator;
        }
        
        requirement <'AR-5'> strategySelectionRequirement {
            doc /* The system shall select appropriate reasoning strategies based on query characteristics */
            subject coordinator : ReasoningCoordinator;
        }
        
        requirement <'AR-6'> performanceRequirement {
            doc /* The system shall complete reasoning within bounded time and space */
            subject system : AutomatedReasoningSystem;
        }
        
        requirement <'AR-7'> confidenceTrackingRequirement {
            doc /* The system shall track and report confidence levels for all conclusions */
            subject system : AutomatedReasoningSystem;
        }
    }
    
    requirement systemMission : AutomatedReasoningRequirements {
        doc /* 
            The automated reasoning system shall accept a knowledge base of logical facts and inference rules,
            perform systematic logical inference to answer queries, automatically select appropriate reasoning
            strategies (forward chaining, backward chaining, or hybrid), validate the consistency of the
            knowledge base, track confidence levels throughout the inference process, and provide complete,
            transparent explanations of how conclusions were derived from the available knowledge.
        */
        
        require soundnessRequirement;
        require completenessRequirement;
        require consistencyValidationRequirement;
        require explanationRequirement;
        require strategySelectionRequirement;
        require performanceRequirement;
        require confidenceTrackingRequirement;
    }
}
