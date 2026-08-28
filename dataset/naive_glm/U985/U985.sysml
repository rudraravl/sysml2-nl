package AutomatedReasoningSystem {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ===== Value Types =====
    value def ConfidenceScore :> Real {
        doc "Confidence score in the range [0.0, 1.0].";
        constraint { 0.0 <= self and self <= 1.0 }
    }

    value def Timestamp :> String {
        doc "ISO-8601 formatted timestamp of fact ingestion.";
    }

    // ===== Item Types =====
    item def Source :> String {
        doc "Origin of a logical fact (e.g., 'sensor', 'user', 'database').";
    }

    item def Subject :> String;
    item def Predicate :> String;
    item def ObjectVal :> String;

    item def LogicalFact {
        doc "A simple statement of truth, e.g., 'Socrates is a man'.";
        attribute subject : Subject;
        attribute predicate : Predicate;
        attribute object : ObjectVal;
        attribute confidence : ConfidenceScore = 1.0;
        attribute source : Source = "unknown";
        attribute timestamp : Timestamp = "1970-01-01T00:00:00Z";
    }

    item def InferenceRule {
        doc "A logical principle mapping premises to a conclusion.";
        attribute name : String;
        attribute premises : LogicalFact[0..*];
        attribute conclusion : LogicalFact;
        attribute confidence : ConfidenceScore = 1.0;
    }

    item def Query {
        doc "A user-submitted question or hypothesis.";
        attribute text : String;
        attribute isHypothesis : Boolean;
        attribute target : LogicalFact;
    }

    item def ReasoningStep {
        doc "A single step in a reasoning trace.";
        attribute stepNumber : Integer;
        attribute appliedRule : InferenceRule;
        attribute derivedFact : LogicalFact;
        attribute stepConfidence : ConfidenceScore;
    }

    item def ReasoningConclusion {
        doc "The result of a reasoning process with full traceability.";
        attribute answer : Boolean;
        attribute answerText : String;
        attribute supportingFacts : LogicalFact[0..*];
        attribute overallConfidence : ConfidenceScore;
        attribute trace : ReasoningStep[0..*];
    }

    item def Explanation {
        doc "Human-readable narrative of the reasoning process.";
        attribute narrative : String;
        attribute conclusionRef : ReasoningConclusion;
    }

    item def ConflictReport {
        doc "Report of contradictions found during validation.";
        attribute description : String;
        attribute conflictingFacts : LogicalFact[0..*];
        attribute conflictingRules : InferenceRule[0..*];
    }

    // ===== Port Definitions =====
    port def QueryInPort {
        in item userQuery : Query;
    }

    port def ConclusionOutPort {
        out item conclusion : ReasoningConclusion;
    }

    port def ExplanationOutPort {
        out item explanation : Explanation;
    }

    port def KnowledgeAccessPort {
        out item facts : LogicalFact[0..*];
        out item rules : InferenceRule[0..*];
        in item newFacts : LogicalFact[0..*];
        in item newRules : InferenceRule[0..*];
    }

    port def ValidationRequestPort {
        in item facts : LogicalFact[0..*];
        in item rules : InferenceRule[0..*];
        out item isValid : Boolean;
        out item conflictReport : ConflictReport;
    }

    port def ReasoningEnginePort {
        in item query : Query;
        in item facts : LogicalFact[0..*];
        in item rules : InferenceRule[0..*];
        out item conclusion : ReasoningConclusion;
    }

    // ===== Parts =====
    part def KnowledgeRepository {
        doc "Central memory storing logical facts and inference rules.";
        port knowledgeAccess : KnowledgeAccessPort;

        attribute storedFacts : LogicalFact[0..*];
        attribute storedRules : InferenceRule[0..*];

        action def StoreFact {
            in fact : LogicalFact;
            then storedFacts := storedFacts.append(fact);
        }

        action def StoreRule {
            in rule : InferenceRule;
            then storedRules := storedRules.append(rule);
        }

        action def RetrieveAll {
            out facts : LogicalFact[0..*] := storedFacts;
            out rules : InferenceRule[0..*] := storedRules;
        }

        action def RetrieveRelevant {
            in query : Query;
            out facts : LogicalFact[0..*];
            out rules : InferenceRule[0..*];
            doc "Filter facts and rules relevant to the query target.";
        }

        exhibit {
            state Idle;
            state Reading;
            state Writing;
            transition idleToReading from Idle to Reading when knowledgeAccess.facts.requested;
            transition readingToIdle from Reading to Idle;
            transition idleToWriting from Idle to Writing when knowledgeAccess.newFacts.received;
            transition writingToIdle from Writing to Idle;
        }
    }

    part def ConsistencyValidator {
        doc "Checks knowledge base for contradictions and logical loops.";
        port validation : ValidationRequestPort;

        action def CheckContradictoryFacts {
            in facts : LogicalFact[0..*];
            out conflicts : ConflictReport[0..*];
            doc "Detect facts with same subject and predicate but conflicting objects.";
        }

        action def CheckRuleLoops {
            in rules : InferenceRule[0..*];
            out conflicts : ConflictReport[0..*];
            doc "Detect circular rule dependencies that create logical loops.";
        }

        action def Validate {
            in facts : LogicalFact[0..*];
            in rules : InferenceRule[0..*];
            out isValid : Boolean;
            out conflictReport : ConflictReport;

            action checkFacts : CheckContradictoryFacts {
                in facts := facts;
            }
            action checkRules : CheckRuleLoops {
                in rules := rules;
            }
            then decide {
                if checkFacts.conflicts.isEmpty and checkRules.conflicts.isEmpty then {
                    isValid := true;
                    conflictReport := ConflictReport { description = "No conflicts detected."; };
                } else {
                    isValid := false;
                    conflictReport := ConflictReport {
                        description = "Contradictions or loops detected.";
                        conflictingFacts := checkFacts.conflicts.conflictingFacts;
                        conflictingRules := checkRules.conflicts.conflictingRules;
                    };
                }
            }
        }

        exhibit {
            state Idle;
            state CheckingFacts;
            state CheckingRules;
            state Reporting;
            transition startValidation from Idle to CheckingFacts when validation.facts.received;
            transition factsDone from CheckingFacts to CheckingRules;
            transition rulesDone from CheckingRules to Reporting;
            transition reportDone from Reporting to Idle;
        }
    }

    part def ForwardChainingEngine {
        doc "Data-driven reasoning: applies rules to known facts iteratively to derive all possible conclusions.";
        port enginePort : ReasoningEnginePort;

        attribute derivedFacts : LogicalFact[0..*];
        attribute trace : ReasoningStep[0..*];
        attribute stepCounter : Integer = 0;

        action def ApplyRule {
            in rule : InferenceRule;
            in knownFacts : LogicalFact[0..*];
            out newFact : LogicalFact;
            out success : Boolean;
            doc "If all premises of the rule are satisfied by knownFacts, derive the conclusion.";
        }

        action def ForwardChain {
            in query : Query;
            in facts : LogicalFact[0..*];
            in rules : InferenceRule[0..*];
            out conclusion : ReasoningConclusion;

            attribute workingFacts : LogicalFact[0..*] := facts;
            attribute currentTrace : ReasoningStep[0..*];
            attribute stepNum : Integer := 0;
            attribute newFactsFound : Boolean := true;

            while newFactsFound {
                newFactsFound := false;
                for rule in rules {
                    action apply : ApplyRule {
                        in rule := rule;
                        in knownFacts := workingFacts;
                    }
                    if apply.success {
                        workingFacts := workingFacts.append(apply.newFact);
                        stepNum := stepNum + 1;
                        currentTrace := currentTrace.append(ReasoningStep {
                            stepNumber := stepNum,
                            appliedRule := rule,
                            derivedFact := apply.newFact,
                            stepConfidence := rule.confidence * apply.newFact.confidence
                        });
                        newFactsFound := true;
                    }
                }
            }
            then conclusion := ReasoningConclusion {
                answer := true,
                answerText := "Forward chaining complete; all derivable facts produced.",
                supportingFacts := workingFacts,
                overallConfidence := 1.0,
                trace := currentTrace
            };
        }

        exhibit {
            state Idle;
            state ApplyingRules;
            state DerivingFacts;
            state CheckingProgress;
            state Complete;

            transition start from Idle to ApplyingRules when enginePort.query.received;
            transition ruleApplied from ApplyingRules to DerivingFacts;
            transition factDerived from DerivingFacts to CheckingProgress;
            transition moreFacts from CheckingProgress to ApplyingRules when newFactsFound == true;
            transition noMoreFacts from CheckingProgress to Complete when newFactsFound == false;
            transition reset from Complete to Idle;
        }
    }

    part def BackwardChainingEngine {
        doc "Goal-driven reasoning: works backward from a hypothesis to find supporting facts.";
        port enginePort : ReasoningEnginePort;

        attribute trace : ReasoningStep[0..*];
        attribute stepCounter : Integer = 0;

        action def MatchFact {
            in goal : LogicalFact;
            in facts : LogicalFact[0..*];
            out matched : Boolean;
            out confidence : ConfidenceScore;
            doc "Check if the goal fact directly exists in the known facts.";
        }

        action def FindProvingRules {
            in goal : LogicalFact;
            in rules : InferenceRule[0..*];
            out matchingRules : InferenceRule[0..*];
            doc "Find rules whose conclusion matches the goal.";
        }

        action def ProveGoal {
            in goal : LogicalFact;
            in facts : LogicalFact[0..*];
            in rules : InferenceRule[0..*];
            out proven : Boolean;
            out confidence : ConfidenceScore;
            out stepTrace : ReasoningStep[0..*];

            action match : MatchFact {
                in goal := goal;
                in facts := facts;
            }
            if match.matched {
                proven := true;
                confidence := match.confidence;
                stepTrace := {};
            } else {
                action findRules : FindProvingRules {
                    in goal := goal;
                    in rules := rules;
                }
                for rule in findRules.matchingRules {
                    attribute subGoalTrace : ReasoningStep[0..*];
                    attribute allPremisesProven : Boolean := true;
                    attribute combinedConfidence : ConfidenceScore := rule.confidence;
                    for premise in rule.premises {
                        action provePremise : ProveGoal {
                            in goal := premise;
                            in facts := facts;
                            in rules := rules;
                        }
                        if not provePremise.proven {
                            allPremisesProven := false;
                        } else {
                            combinedConfidence := combinedConfidence * provePremise.confidence;
                            subGoalTrace := subGoalTrace.append(provePremise.stepTrace);
                        }
                    }
                    if allPremisesProven {
                        stepCounter := stepCounter + 1;
                        proven := true;
                        confidence := combinedConfidence;
                        stepTrace := subGoalTrace.append(ReasoningStep {
                            stepNumber := stepCounter,
                            appliedRule := rule,
                            derivedFact := goal,
                            stepConfidence := combinedConfidence
                        });
                    }
                }
                if not proven {
                    proven := false;
                    confidence := 0.0;
                    stepTrace := {};
                }
            }
        }

        action def BackwardChain {
            in query : Query;
            in facts : LogicalFact[0..*];
            in rules : InferenceRule[0..*];
            out conclusion : ReasoningConclusion;

            action prove : ProveGoal {
                in goal := query.target;
                in facts := facts;
                in rules := rules;
            }
            then conclusion := ReasoningConclusion {
                answer := prove.proven,
                answerText := if prove.proven then "Hypothesis confirmed." else "Hypothesis could not be proven.",
                supportingFacts := facts,
                overallConfidence := prove.confidence,
                trace := prove.stepTrace
            };
        }

        exhibit {
            state Idle;
            state SearchingRules;
            state EvaluatingPreconditions;
            state Backtracking;
            state Complete;

            transition start from Idle to SearchingRules when enginePort.query.received;
            transition rulesFound from SearchingRules to EvaluatingPreconditions;
            transition needMoreProof from EvaluatingPreconditions to SearchingRules;
            transition proofComplete from EvaluatingPreconditions to Complete;
            transition proofFailed from EvaluatingPreconditions to Backtracking;
            transition backtrackDone from Backtracking to SearchingRules;
            transition reset from Complete to Idle;
        }
    }

    part def ExplanationGenerator {
        doc "Translates a reasoning trace into a human-readable narrative.";
        port explanationOut : ExplanationOutPort;
        in item conclusion : ReasoningConclusion;

        action def FormatStep {
            in step : ReasoningStep;
            out text : String;
            doc "Convert a single reasoning step into a readable sentence.";
        }

        action def GenerateExplanation {
            in conclusion : ReasoningConclusion;
            out explanation : Explanation;

            attribute narrativeText : String := "Reasoning Conclusion Report:\n";
            attribute narrativeText := narrativeText + "Answer: " + conclusion.answerText + "\n";
            attribute narrativeText := narrativeText + "Overall Confidence: " + conclusion.overallConfidence.toString + "\n";
            attribute narrativeText := narrativeText + "Logical Steps:\n";

            for step in conclusion.trace {
                action fmt : FormatStep {
                    in step := step;
                }
                narrativeText := narrativeText + "  Step " + step.stepNumber.toString + ": " + fmt.text + "\n";
            }

            narrativeText := narrativeText + "Supporting Facts:\n";
            for fact in conclusion.supportingFacts {
                narrativeText := narrativeText + "  - " + fact.subject + " " + fact.predicate + " " + fact.object + "\n";
            }

            then explanation := Explanation {
                narrative := narrativeText,
                conclusionRef := conclusion
            };
        }

        exhibit {
            state Idle;
            state FormattingSteps;
            state AssemblingNarrative;
            state Done;

            transition start from Idle to FormattingSteps when conclusion.received;
            transition stepsFormatted from FormattingSteps to AssemblingNarrative;
            transition narrativeReady from AssemblingNarrative to Done;
            transition reset from Done to Idle;
        }
    }

    part def ReasoningCoordinator {
        doc "Orchestrates the entire reasoning process from query to explanation.";
        port queryIn : QueryInPort;
        port conclusionOut : ConclusionOutPort;
        port explanationOut : ExplanationOutPort;
        port knowledgeAccess : KnowledgeAccessPort;
        port validationPort : ValidationRequestPort;
        port forwardEnginePort : ReasoningEnginePort;
        port backwardEnginePort : ReasoningEnginePort;

        part validator : ConsistencyValidator {
            port validation : ValidationRequestPort;
        }
        part forwardEngine : ForwardChainingEngine {
            port enginePort : ReasoningEnginePort;
        }
        part backwardEngine : BackwardChainingEngine {
            port enginePort : ReasoningEnginePort;
        }
        part explanationGen : ExplanationGenerator {
            port explanationOut : ExplanationOutPort;
        }

        action def Coordinate {
            in query : Query;
            out conclusion : ReasoningConclusion;
            out explanation : Explanation;

            // 1. Retrieve relevant knowledge
            action retrieve {
                out facts : LogicalFact[0..*];
                out rules : InferenceRule[0..*];
            }

            // 2. Validate consistency
            action validate : ConsistencyValidator::Validate {
                in facts := retrieve.facts;
                in rules := retrieve.rules;
                out isValid : Boolean;
                out conflictReport : ConflictReport;
            }

            // 3. Select strategy and execute reasoning
            if validate.isValid {
                if not query.isHypothesis {
                    // Open-ended query: use forward chaining
                    action forward : ForwardChainingEngine::ForwardChain {
                        in query := query;
                        in facts := retrieve.facts;
                        in rules := retrieve.rules;
                        out conclusion : ReasoningConclusion;
                    }
                    conclusion := forward.conclusion;
                } else {
                    // Hypothesis verification: use backward chaining
                    action backward : BackwardChainingEngine::BackwardChain {
                        in query := query;
                        in facts := retrieve.facts;
                        in rules := retrieve.rules;
                        out conclusion : ReasoningConclusion;
                    }
                    conclusion := backward.conclusion;
                }
            } else {
                conclusion := ReasoningConclusion {
                    answer := false,
                    answerText := "Reasoning aborted: knowledge base contains contradictions.",
                    supportingFacts := {},
                    overallConfidence := 0.0,
                    trace := {}
                };
            }

            // 4. Generate explanation
            action explain : ExplanationGenerator::GenerateExplanation {
                in conclusion := conclusion;
                out explanation : Explanation;
            }
            explanation := explain.explanation;
        }

        exhibit coordinatorStateMachine {
            state Idle;
            state RetrievingKnowledge;
            state Validating;
            state SelectingStrategy;
            state ForwardReasoning;
            state BackwardReasoning;
            state Aborting;
            state GeneratingExplanation;
            state Complete;

            transition queryReceived from Idle to RetrievingKnowledge when queryIn.userQuery.received;
            transition knowledgeReady from RetrievingKnowledge to Validating;
            transition validationPassed from Validating to SelectingStrategy when validationPort.isValid == true;
            transition validationFailed from Validating to Aborting when validationPort.isValid == false;
            transition useForward from SelectingStrategy to ForwardReasoning when queryIn.userQuery.isHypothesis == false;
            transition useBackward from SelectingStrategy to BackwardReasoning when queryIn.userQuery.isHypothesis == true;
            transition forwardDone from ForwardReasoning to GeneratingExplanation;
            transition backwardDone from BackwardReasoning to GeneratingExplanation;
            transition abortDone from Aborting to GeneratingExplanation;
            transition explanationReady from GeneratingExplanation to Complete;
            transition reset from Complete to Idle;
        }
    }

    // ===== Top-Level System =====
    part def AutomatedReasoningSystem {
        doc "A software-based logic engine that analyzes facts and rules to answer questions and derive conclusions.";
        port queryIn : QueryInPort;
        port conclusionOut : ConclusionOutPort;
        port explanationOut : ExplanationOutPort;

        part knowledgeRepo : KnowledgeRepository {
            port knowledgeAccess : KnowledgeAccessPort;
        }
        part coordinator : ReasoningCoordinator {
            port queryIn : QueryInPort;
            port conclusionOut : ConclusionOutPort;
            port explanationOut : ExplanationOutPort;
            port knowledgeAccess : KnowledgeAccessPort;
            port validationPort : ValidationRequestPort;
            port forwardEnginePort : ReasoningEnginePort;
            port backwardEnginePort : ReasoningEnginePort;
        }

        connection knowledgeConn connect coordinator.knowledgeAccess to knowledgeRepo.knowledgeAccess {
            item flow of LogicalFact;
            item flow of InferenceRule;
        }

        connection queryConn connect queryIn to coordinator.queryIn {
            item flow of Query;
        }
        connection conclusionConn connect coordinator.conclusionOut to conclusionOut {
            item flow of ReasoningConclusion;
        }
        connection explanationConn connect coordinator.explanationOut to explanationOut {
            item flow of Explanation;
        }

        // Internal connections within coordinator
        connection validationConn connect coordinator.validationPort to coordinator.validator.validation {
            item flow of LogicalFact;
            item flow of InferenceRule;
            item flow of Boolean;
            item flow of ConflictReport;
        }
        connection forwardConn connect coordinator.forwardEnginePort to coordinator.forwardEngine.enginePort {
            item flow of Query;
            item flow of LogicalFact;
            item flow of InferenceRule;
            item flow of ReasoningConclusion;
        }
        connection backwardConn connect coordinator.backwardEnginePort to coordinator.backwardEngine.enginePort {
            item flow of Query;
            item flow of LogicalFact;
            item flow of InferenceRule;
            item flow of ReasoningConclusion;
        }
        connection explanationInternalConn connect coordinator.explanationOut to coordinator.explanationGen.explanationOut {
            item flow of Explanation;
        }
    }

    // ===== Requirements =====
    requirement def ReasoningSystemRequirement {
        doc "The automated reasoning system shall analyze known facts and rules to answer complex questions and derive logically sound conclusions.";
    }

    requirement def KnowledgeStorageRequirement :> ReasoningSystemRequirement {
        doc "The system shall maintain a Knowledge Repository that stores Logical Facts and Inference Rules, where each fact includes a confidence score, source, and timestamp.";
        subject AutomatedReasoningSystem;
    }

    requirement def ConsistencyValidationRequirement :> ReasoningSystemRequirement {
        doc "The system shall use a Consistency Validator to check for contradictions (conflicting facts and rule-induced logical loops) before reasoning.";
        subject AutomatedReasoningSystem;
    }

    requirement def ForwardChainingRequirement :> ReasoningSystemRequirement {
        doc "For open-ended queries, the system shall employ a Forward Chaining Engine that iteratively applies rules to known facts until no new conclusions can be derived.";
        subject AutomatedReasoningSystem;
    }

    requirement def BackwardChainingRequirement :> ReasoningSystemRequirement {
        doc "For hypothesis verification and direct questions, the system shall employ a Backward Chaining Engine that works backward from the goal to establish preconditions.";
        subject AutomatedReasoningSystem;
    }

    requirement def ConclusionTraceabilityRequirement :> ReasoningSystemRequirement {
        doc "The system shall produce a Reasoning Conclusion that includes supporting facts, overall confidence, and a complete trace of all logical steps taken.";
        subject AutomatedReasoningSystem;
    }

    requirement def ExplanationRequirement :> ReasoningSystemRequirement {
        doc "The system shall include an Explanation Generator that translates the reasoning trace into a human-readable narrative for transparency and verifiability.";
        subject AutomatedReasoningSystem;
    }

    requirement def CoordinatorOrchestrationRequirement :> ReasoningSystemRequirement {
        doc "A Reasoning Coordinator shall orchestrate the full pipeline: knowledge retrieval, consistency validation, strategy selection, reasoning execution, and explanation generation.";
        subject AutomatedReasoningSystem;
    }

    // ===== Satisfaction =====
    satisfaction satisfy KnowledgeStorageRequirement by AutomatedReasoningSystem::knowledgeRepo;
    satisfaction satisfy ConsistencyValidationRequirement by AutomatedReasoningSystem::coordinator::validator;
    satisfaction satisfy ForwardChainingRequirement by AutomatedReasoningSystem::coordinator::forwardEngine;
    satisfaction satisfy BackwardChainingRequirement by AutomatedReasoningSystem::coordinator::backwardEngine;
    satisfaction satisfy ConclusionTraceabilityRequirement by AutomatedReasoningSystem::coordinator;
    satisfaction satisfy ExplanationRequirement by AutomatedReasoningSystem::coordinator::explanationGen;
    satisfaction satisfy CoordinatorOrchestrationRequirement by AutomatedReasoningSystem::coordinator;
}
