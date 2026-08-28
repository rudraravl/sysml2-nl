package 'Deterministic Finite State Automaton' {
    private import ScalarValues::*;
    private import SequenceFunctions::*;

    item def InputSymbol {
        attribute value : String;
    }

    item def OutputSymbol {
        attribute value : String;
    }

    item def State {
        attribute name : String;
    }

    item def TransitionRule {
        attribute currentState : State;
        attribute inputSymbol : InputSymbol;
        attribute nextState : State;
        attribute outputSymbol : OutputSymbol;
    }

    item def AcceptanceDecision {
        attribute accepted : Boolean;
    }

    calc def LookupTransition {
        in rules : TransitionRule[*];
        in state : State;
        in input : InputSymbol;
        return rule : TransitionRule = rules->select(r | r.currentState.name == state.name and r.inputSymbol.value == input.value)->first();
    }

    calc def EvaluateAcceptance {
        in finalState : State;
        in acceptingStates : State[*];
        return result : Boolean = acceptingStates->exists(s | s.name == finalState.name);
    }

    action def ReadSymbolAction {
        in attribute symbols : InputSymbol[*];
        in attribute position : Integer;
        out attribute readSymbol : InputSymbol = symbols#(position);
        out attribute isExhausted : Boolean = position > symbols->size();
        out attribute nextPosition : Integer = position + 1;
    }

    action def ComputeTransitionAction {
        in attribute rules : TransitionRule[*];
        in attribute state : State;
        in attribute input : InputSymbol;
        private attribute rule : TransitionRule := LookupTransition(rules, state, input);
        out attribute nextState : State = rule.nextState;
        out attribute outputSymbol : OutputSymbol = rule.outputSymbol;
    }

    action def CollectOutputAction {
        in attribute outputSymbol : OutputSymbol;
        in attribute buffer : OutputSymbol[*];
        out attribute result : OutputSymbol[*] = buffer->including(outputSymbol);
    }

    action def CheckAcceptanceAction {
        in attribute finalState : State;
        in attribute acceptingStates : State[*];
        out attribute accepted : Boolean = EvaluateAcceptance(finalState, acceptingStates);
    }

    part def InputTape {
        attribute symbols : InputSymbol[*] := ();
        port dataPort {
            out symbol : InputSymbol;
            out exhausted : Boolean;
        }
    }

    part def TapeReader {
        port inPort {
            in symbol : InputSymbol;
            in exhausted : Boolean;
        }
        port outPort {
            out symbol : InputSymbol;
            out exhausted : Boolean;
        }
        flow of InputSymbol from inPort.symbol to outPort.symbol;
        flow of Boolean from inPort.exhausted to outPort.exhausted;
    }

    part def StateController {
        attribute transitionRules : TransitionRule[*];
        attribute currentState : State;
        attribute acceptingStates : State[*];

        port inputPort {
            in symbol : InputSymbol;
            in exhausted : Boolean;
        }
        port outputPort {
            out outputSymbol : OutputSymbol;
        }
        port statePort {
            out finalState : State;
        }
    }

    part def OutputCollector {
        port inputPort {
            in outputSymbol : OutputSymbol;
        }
        port bufferPort {
            out buffer : OutputSymbol[*];
        }
        attribute outputBuffer : OutputSymbol[*] := ();
    }

    part def AcceptanceChecker {
        port stateInPort {
            in finalState : State;
        }
        port decisionPort {
            out accepted : Boolean;
        }
        attribute acceptingStates : State[*];
        attribute accepted : Boolean;
    }

    part def DFA_System {
        port startPort {
            in startSignal : Boolean;
        }
        port resultPort {
            out accepted : Boolean;
            out outputSequence : OutputSymbol[*];
        }

        attribute initialState : State;
        attribute acceptingStates : State[*];
        attribute transitionRules : TransitionRule[*];

        part inputTape : InputTape;
        part tapeReader : TapeReader;
        part stateController : StateController;
        part outputCollector : OutputCollector;
        part acceptanceChecker : AcceptanceChecker;

        flow of InputSymbol from inputTape.dataPort.symbol to tapeReader.inPort.symbol;
        flow of Boolean from inputTape.dataPort.exhausted to tapeReader.inPort.exhausted;
        flow of InputSymbol from tapeReader.outPort.symbol to stateController.inputPort.symbol;
        flow of Boolean from tapeReader.outPort.exhausted to stateController.inputPort.exhausted;
        flow of OutputSymbol from stateController.outputPort.outputSymbol to outputCollector.inputPort.outputSymbol;
        flow of State from stateController.statePort.finalState to acceptanceChecker.stateInPort.finalState;
        flow of Boolean from acceptanceChecker.decisionPort.accepted to resultPort.accepted;
        flow of OutputSymbol[*] from outputCollector.bufferPort.buffer to resultPort.outputSequence;

        state def DFALifecycle {
            entry;
            then Initializing;
            state Initializing {
                entry assign stateController.currentState := initialState;
                then Ready;
            }
            state Ready {
                accept start : Boolean via startPort
                then Processing;
            }
            state Processing {
                do action processLoop {
                    private attribute currentState : State := initialState;
                    private attribute outputBuffer : OutputSymbol[*] := ();
                    for sym in inputTape.symbols {
                        perform action compute : ComputeTransitionAction {
                            in attribute rules = stateController.transitionRules;
                            in attribute state = currentState;
                            in attribute input = sym;
                        }
                        then assign currentState := compute.nextState;
                        then perform action collect : CollectOutputAction {
                            in attribute outputSymbol = compute.outputSymbol;
                            in attribute buffer = outputBuffer;
                        }
                        then assign outputBuffer := collect.result;
                    }
                    then assign stateController.currentState := currentState;
                    then assign outputCollector.outputBuffer := outputBuffer;
                    then assign acceptanceChecker.accepted := EvaluateAcceptance(currentState, acceptanceChecker.acceptingStates);
                }
                then Completed;
            }
            state Completed {
                then done;
            }
        }

        state dfaState : DFALifecycle;
    }

    requirement def DFARequirements {
        requirement {
            doc /* The automaton shall process all input symbols from the input tape sequentially. */
        }
        requirement {
            doc /* The automaton shall produce an output symbol for each input symbol processed. */
        }
        requirement {
            doc /* The automaton shall determine acceptance by comparing the final state against the set of accepting states. */
        }
        requirement {
            doc /* The automaton shall store all output symbols in an ordered output buffer. */
        }
    }
}
