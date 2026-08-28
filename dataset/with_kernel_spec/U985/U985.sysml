package AutomatedReasoningSystem {
    private import ScalarValues::String;
    private import ScalarValues::Boolean;
    private import ScalarValues::Real;
    private import ScalarValues::Integer;

    value def Confidence :> Real;
    value def Timestamp :> Integer;

    item def LogicalFact {
        attribute statement : String;
        attribute confidence : Confidence;
        attribute source : String;
        attribute timestamp : Timestamp;
    }

    item def InferenceRule {
        attribute name : String;
        attribute antecedent : String;
        attribute consequent : String;
        attribute confidence : Confidence;
    }

    item def Query {
        attribute text : String;
        attribute isHypothesis : Boolean;
        attribute goal : String;
    }

    item def ReasoningStep {
        attribute description : String;
        attribute appliedRule : String;
        attribute derivedFact : String;
        attribute stepConfidence : Confidence;
    }

    item def ReasoningConclusion {
        attribute answer : String;
        attribute overallConfidence : Confidence;
        ref item supportingFacts : LogicalFact[0..*];
        ref item reasoningTrace : ReasoningStep[0..*];
        attribute isValid : Boolean;
    }

    item def Explanation {
        attribute narrative : String;
        ref item conclusion : ReasoningConclusion[1];
    }

    item def ConsistencyReport {
        attribute isConsistent : Boolean;
        attribute conflictDescription : String[0..*];
    }

    port def QueryPort {
        in ref query : Query;
        out ref conclusion : ReasoningConclusion;
        out ref explanation : Explanation;
    }

    port def KnowledgeAccessPort {
        out ref facts : LogicalFact[0..*];
        out ref rules : InferenceRule[0..*];
        in ref newFacts : LogicalFact[0..*];
    }

    port def ValidationRequestPort {
        in ref facts : LogicalFact[0..*];
        in ref rules : InferenceRule[0..*];
        out ref report : ConsistencyReport;
    }

    port def ForwardChainingPort {
        in ref facts : LogicalFact[0..*];
        in ref rules : InferenceRule[0..*];
        in ref query : Query;
        out ref derivedFacts : LogicalFact[0..*];
        out ref trace : ReasoningStep[0..*];
    }

    port def BackwardChainingPort {
        in ref facts : LogicalFact[0..*];
        in ref rules : InferenceRule[0..*];
        in ref query : Query;
        out ref proven : Boolean;
        out ref trace : ReasoningStep[0..*];
    }

    port def ExplanationPort {
        in ref conclusion : ReasoningConclusion;
        out ref explanation : Explanation;
    }

    interface def QueryInterface {
        end user : ~QueryPort;
        end coordinator : QueryPort;
    }

    interface def KnowledgeInterface {
        end coordinator : ~KnowledgeAccessPort;
        end repository : KnowledgeAccessPort;
    }

    interface def ValidationInterface {
        end coordinator : ~ValidationRequestPort;
        end validator : ValidationRequestPort;
    }

    interface def ForwardChainingInterface {
        end coordinator : ~ForwardChainingPort;
        end forwardEngine : ForwardChainingPort;
    }

    interface def BackwardChainingInterface {
        end coordinator : ~BackwardChainingPort;
        end backwardEngine : BackwardChainingPort;
    }

    interface def ExplanationInterface {
        end coordinator : ~ExplanationPort;
        end generator : ExplanationPort;
    }

    part def KnowledgeRepository {
        item storedFacts : LogicalFact[0..*];
        item storedRules : InferenceRule[0..*];
        port knowledgePort : KnowledgeAccessPort;
        perform action updateKnowledge {
            in ref incoming : LogicalFact[0..*];
            then action addFacts {
                in ref incomingFacts : LogicalFact[0..*];
                out ref updatedFacts : LogicalFact[0..*];
            }
            flow factFlow from updateKnowledge.incoming to updateKnowledge.addFacts.incomingFacts;
        }
    }

    part def ConsistencyValidator {
        port validationPort : ValidationRequestPort;
        perform action validate {
            in ref facts : LogicalFact[0..*];
            in ref rules : InferenceRule[0..*];
            then action checkContradictions {
                in ref facts : LogicalFact[0..*];
                in ref rules : InferenceRule[0..*];
                out attribute contradictions : String[0..*];
                out attribute consistent : Boolean;
            }
            then action checkLoops {
                in ref rules : InferenceRule[0..*];
                out attribute loops : String[0..*];
                out attribute consistent : Boolean;
            }
            then merge combineResults;
            then action generateReport {
                in attribute contradictions : String[0..*];
                in attribute loops : String[0..*];
                out ref report : ConsistencyReport;
            }
        }
    }

    part def ForwardChainingEngine {
        port forwardPort : ForwardChainingPort;
        perform action forwardChain {
            in ref initialFacts : LogicalFact[0..*];
            in ref rules : InferenceRule[0..*];
            in ref query : Query;
            then action applyRules {
                in ref currentFacts : LogicalFact[0..*];
                in ref availableRules : InferenceRule[0..*];
                out ref newFacts : LogicalFact[0..*];
                out ref steps : ReasoningStep[0..*];
            }
            then decide;
                if true then mergeFacts;
                else finalize;
            then action mergeFacts {
                in ref currentFacts : LogicalFact[0..*];
                in ref newFacts : LogicalFact[0..*];
                out ref combinedFacts : LogicalFact[0..*];
            }
            then applyRules;
            then action finalize {
                in ref allFacts : LogicalFact[0..*];
                in ref allSteps : ReasoningStep[0..*];
                out ref derivedFacts : LogicalFact[0..*];
                out ref trace : ReasoningStep[0..*];
            }
        }
    }

    part def BackwardChainingEngine {
        port backwardPort : BackwardChainingPort;
        perform action backwardChain {
            in ref facts : LogicalFact[0..*];
            in ref rules : InferenceRule[0..*];
            in ref query : Query;
            then action matchGoal {
                in ref goal : String;
                in ref availableFacts : LogicalFact[0..*];
                out attribute found : Boolean;
            }
            then decide;
                if true then succeed;
                else findRules;
            then action findRules {
                in ref goal : String;
                in ref availableRules : InferenceRule[0..*];
                out ref matchingRules : InferenceRule[0..*];
            }
            then action proveAntecedents {
                in ref matchingRules : InferenceRule[0..*];
                in ref availableFacts : LogicalFact[0..*];
                out attribute allProven : Boolean;
                out ref steps : ReasoningStep[0..*];
            }
            then merge conclude;
            then action succeed {
                out attribute proven : Boolean;
                out ref steps : ReasoningStep[0..*];
            }
            then conclude;
        }
    }

    part def ExplanationGenerator {
        port explanationPort : ExplanationPort;
        perform action generateExplanation {
            in ref conclusion : ReasoningConclusion;
            then action buildNarrative {
                in ref conclusion : ReasoningConclusion;
                out attribute narrative : String;
            }
            then action assembleExplanation {
                in attribute narrative : String;
                in ref conclusion : ReasoningConclusion;
                out ref explanation : Explanation;
            }
        }
    }

    state def CoordinatorBehavior {
        entry;
        then idle;
        state idle;
        transition t1 first idle then validating;
        state validating;
        transition t2 first validating then reasoning;
        transition t3 first validating then errorState;
        state reasoning;
        transition t4 first reasoning then forwardChaining;
        transition t5 first reasoning then backwardChaining;
        state forwardChaining;
        state backwardChaining;
        transition t6 first forwardChaining then concluding;
        transition t7 first backwardChaining then concluding;
        state concluding;
        transition t8 first concluding then explaining;
        state explaining;
        transition t9 first explaining then idle;
        state errorState;
        transition t10 first errorState then idle;
    }

    part def ReasoningCoordinator {
        port queryPort : QueryPort;
        port knowledgePort : ~KnowledgeAccessPort;
        port validationPort : ~ValidationRequestPort;
        port forwardPort : ~ForwardChainingPort;
        port backwardPort : ~BackwardChainingPort;
        port explanationPort : ~ExplanationPort;
        exhibit state behavior : CoordinatorBehavior;
    }

    part def AutomatedReasoningSystem {
        port userPort : QueryPort;

        part coordinator : ReasoningCoordinator;
        part repository : KnowledgeRepository;
        part validator : ConsistencyValidator;
        part forwardEngine : ForwardChainingEngine;
        part backwardEngine : BackwardChainingEngine;
        part explanationGenerator : ExplanationGenerator;

        interface queryInterface : QueryInterface connect userPort to coordinator.queryPort;
        interface knowledgeInterface : KnowledgeInterface connect coordinator.knowledgePort to repository.knowledgePort;
        interface validationInterface : ValidationInterface connect coordinator.validationPort to validator.validationPort;
        interface forwardInterface : ForwardChainingInterface connect coordinator.forwardPort to forwardEngine.forwardPort;
        interface backwardInterface : BackwardChainingInterface connect coordinator.backwardPort to backwardEngine.backwardPort;
        interface explanationInterface : ExplanationInterface connect coordinator.explanationPort to explanationGenerator.explanationPort;
    }

    requirement def ReasoningSystemRequirement {
        doc /* The automated reasoning system shall analyze facts and rules to derive conclusions. */
    }

    requirement def KnowledgeStorageRequirement {
        doc /* The system shall maintain a repository of logical facts and inference rules. */
    }

    requirement def ConsistencyValidationRequirement {
        doc /* The system shall validate knowledge for contradictions before reasoning. */
    }

    requirement def ForwardChainingRequirement {
        doc /* The forward chaining engine shall derive all possible facts from known facts and rules. */
    }

    requirement def BackwardChainingRequirement {
        doc /* The backward chaining engine shall prove or disprove a specific hypothesis. */
    }

    requirement def ExplanationRequirement {
        doc /* The system shall generate a human-readable explanation of its reasoning. */
    }

    part reasoningSystem : AutomatedReasoningSystem;

    satisfy ReasoningSystemRequirement by reasoningSystem;
    satisfy KnowledgeStorageRequirement by reasoningSystem.repository;
    satisfy ConsistencyValidationRequirement by reasoningSystem.validator;
    satisfy ForwardChainingRequirement by reasoningSystem.forwardEngine;
    satisfy BackwardChainingRequirement by reasoningSystem.backwardEngine;
    satisfy ExplanationRequirement by reasoningSystem.explanationGenerator;
}
