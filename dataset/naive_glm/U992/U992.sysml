package DeterministicFiniteStateAutomaton {

    import ScalarValues::*;

    // ===== Units =====

    unit symbol_count "count of symbols";
    unit position_index "zero-based index position";

    // ===== Value Types =====

    value type Symbol :> String {
        doc { A single symbol from the input alphabet. }
    }

    value type State :> String {
        doc { An identifier for a state in the automaton. }
    }

    value type OutputSymbol :> String {
        doc { A single symbol produced as output by a transition. }
    }

    value type SymbolCount :> Integer {
        unit symbol_count;
    }

    value type Position :> Integer {
        unit position_index;
    }

    // ===== Item Definitions =====

    item def SymbolSequence {
        attribute symbols: Symbol[0..*] ordered;
        attribute length: SymbolCount = symbols->size();
    }

    item def OutputSequence {
        attribute symbols: OutputSymbol[0..*] ordered;
        attribute length: SymbolCount = symbols->size();
    }

    item def TransitionRule {
        attribute currentState: State;
        attribute inputSymbol: Symbol;
        attribute nextState: State;
        attribute outputSymbol: OutputSymbol;
    }

    item def TransitionTableData {
        attribute rules: TransitionRule[0..*];
        attribute initialState: State;
        attribute acceptingStates: State[0..*];
        attribute alphabet: Symbol[0..*];
        attribute states: State[0..*];
        attribute loaded: Boolean = false;
    }

    item def AcceptanceResult {
        attribute finalState: State;
        attribute accepted: Boolean;
        attribute acceptingStates: State[0..*];
    }

    // ===== Port Definitions =====

    port def SymbolPort {
        out symbol: Symbol;
        out endOfTape: Boolean;
    }

    port def TransitionResultPort {
        out nextState: State;
        out outputSymbol: OutputSymbol;
    }

    port def OutputPort {
        out output: OutputSymbol;
    }

    port def FinalStatePort {
        out finalState: State;
    }

    port def AcceptancePort {
        out result: AcceptanceResult;
    }

    // ===== Action Definitions =====

    action def ReadNextSymbolAction {
        in sequence: SymbolSequence;
        in position: Position;
        out symbol: Symbol;
        out endOfTape: Boolean;
        out nextPosition: Position;
        out exhausted: Boolean;
    }

    action def ComputeTransitionAction {
        in currentState: State;
        in inputSymbol: Symbol;
        in rules: TransitionRule[0..*];
        out nextState: State;
        out outputSymbol: OutputSymbol;
    }

    action def CollectOutputAction {
        in output: OutputSymbol;
        inout buffer: OutputSequence;
    }

    action def CheckAcceptanceAction {
        in finalState: State;
        in acceptingStates: State[0..*];
        out accepted: Boolean;
    }

    // ===== Part Definitions =====

    part def InputTape {
        port symbolOut: SymbolPort;
        attribute sequence: SymbolSequence;
        attribute position: Position = 0;
        attribute exhausted: Boolean = false;
        attribute sequenceLoaded: Boolean = false;

        action loadSequence {
            in symbols: Symbol[0..*];
            sequence.symbols := symbols;
            sequence.length := symbols->size();
            position := 0;
            exhausted := false;
            sequenceLoaded := true;
        }

        action readNext {
            if position < sequence.length then {
                symbolOut.symbol := sequence.symbols->at(position);
                symbolOut.endOfTape := false;
                position := position + 1;
            } else {
                symbolOut.endOfTape := true;
                exhausted := true;
            }
        }
    }

    part def TapeReader {
        port tapeIn: ~SymbolPort;
        port symbolOut: SymbolPort;
        attribute currentSymbol: Symbol;
        attribute endOfTape: Boolean = false;
        attribute symbolAvailable: Boolean = false;

        action read {
            currentSymbol := tapeIn.symbol;
            endOfTape := tapeIn.endOfTape;
            symbolAvailable := true;
        }

        action forward {
            symbolOut.symbol := currentSymbol;
            symbolOut.endOfTape := endOfTape;
            symbolAvailable := false;
        }
    }

    part def TransitionTable {
        attribute data: TransitionTableData;

        action load {
            in rules: TransitionRule[0..*];
            in initialState: State;
            in acceptingStates: State[0..*];
            in alphabet: Symbol[0..*];
            in states: State[0..*];
            data.rules := rules;
            data.initialState := initialState;
            data.acceptingStates := acceptingStates;
            data.alphabet := alphabet;
            data.states := states;
            data.loaded := true;
        }

        action lookup {
            in currentState: State;
            in inputSymbol: Symbol;
            out nextState: State;
            out outputSymbol: OutputSymbol;

            attribute matchingRule: TransitionRule =
                data.rules->select(r | r.currentState = currentState and r.inputSymbol = inputSymbol)->first();
            nextState := matchingRule.nextState;
            outputSymbol := matchingRule.outputSymbol;
        }
    }

    part def StateController {
        port symbolIn: ~SymbolPort;
        port transitionOut: TransitionResultPort;
        port finalStateOut: FinalStatePort;
        part transitionTable: TransitionTable;
        attribute currentState: State;
        attribute processingComplete: Boolean = false;
        attribute transitionComputed: Boolean = false;

        action initialize {
            currentState := transitionTable.data.initialState;
        }

        action compute {
            transitionTable.lookup(
                currentState = currentState,
                inputSymbol = symbolIn.symbol
            );
            transitionOut.nextState := transitionTable.lookup.nextState;
            transitionOut.outputSymbol := transitionTable.lookup.outputSymbol;
            currentState := transitionTable.lookup.nextState;
            transitionComputed := true;
        }

        action finalize {
            finalStateOut.finalState := currentState;
            processingComplete := true;
        }

        state machine controllerBehavior {
            initial Idle;
            state Ready {
                entry { currentState := transitionTable.data.initialState; }
            }
            state Computing;
            state Finalized;

            transition Idle to Ready when transitionTable.data.loaded;
            transition Ready to Computing when symbolIn.symbol;
            transition Computing to Ready when !symbolIn.endOfTape;
            transition Computing to Finalized when symbolIn.endOfTape;
        }
    }

    part def OutputCollector {
        port outputIn: ~OutputPort;
        attribute buffer: OutputSequence;

        action collect {
            buffer.symbols := buffer.symbols->including(outputIn.output);
            buffer.length := buffer.symbols->size();
        }

        action reset {
            buffer.symbols := {};
            buffer.length := 0;
        }
    }

    part def AcceptanceChecker {
        port finalStateIn: ~FinalStatePort;
        port acceptanceOut: AcceptancePort;
        attribute acceptingStates: State[0..*];
        attribute result: AcceptanceResult;

        action configure {
            in states: State[0..*];
            acceptingStates := states;
        }

        action check {
            result.finalState := finalStateIn.finalState;
            result.accepted := acceptingStates->includes(finalStateIn.finalState);
            result.acceptingStates := acceptingStates;
            acceptanceOut.result := result;
        }
    }

    // ===== System Assembly =====

    part def FiniteStateAutomaton {
        attribute systemInitialized: Boolean = false;
        attribute tableLoaded: Boolean = false;
        attribute processingStarted: Boolean = false;

        part inputTape: InputTape;
        part tapeReader: TapeReader;
        part stateController: StateController;
        part outputCollector: OutputCollector;
        part acceptanceChecker: AcceptanceChecker;

        connection tapeToReader connect inputTape.symbolOut to tapeReader.tapeIn;
        connection readerToController connect tapeReader.symbolOut to stateController.symbolIn;
        connection controllerToOutput connect stateController.transitionOut to outputCollector.outputIn;
        connection controllerToChecker connect stateController.finalStateOut to acceptanceChecker.finalStateIn;

        action initializeSystem {
            in inputSymbols: Symbol[0..*];
            in rules: TransitionRule[0..*];
            in initialState: State;
            in acceptingStates: State[0..*];
            in alphabet: Symbol[0..*];
            in states: State[0..*];

            outputCollector.reset;
            inputTape.loadSequence(symbols = inputSymbols);
            stateController.transitionTable.load(
                rules = rules,
                initialState = initialState,
                acceptingStates = acceptingStates,
                alphabet = alphabet,
                states = states
            );
            acceptanceChecker.configure(states = acceptingStates);
            stateController.initialize;
            systemInitialized := true;
            tableLoaded := true;
        }

        action processSingleSymbol {
            inputTape.readNext;
            tapeReader.read;
            tapeReader.forward;
            stateController.compute;
            outputCollector.collect;
        }

        action completeProcessing {
            stateController.finalize;
            acceptanceChecker.check;
        }

        state machine lifecycle {
            initial Uninitialized;
            state Initialized {
                entry { systemInitialized := true; }
            }
            state Ready {
                entry { stateController.initialize; }
            }
            state Processing {
                entry { processSingleSymbol; }
            }
            state Completed {
                entry { completeProcessing; }
            }

            transition Uninitialized to Initialized when inputTape.sequenceLoaded;
            transition Initialized to Ready when stateController.transitionTable.data.loaded;
            transition Ready to Processing when tapeReader.symbolAvailable;
            transition Processing to Processing if !inputTape.exhausted;
            transition Processing to Completed if inputTape.exhausted;
        }
    }

    // ===== Requirements =====

    requirement def ProcessInputSequenceReq {
        subject automaton: FiniteStateAutomaton;
        requirement {
            The automaton shall process an ordered sequence of input symbols
            from the Input Tape one symbol at a time in the correct order.
        }
    }

    requirement def ProduceOutputSequenceReq {
        subject automaton: FiniteStateAutomaton;
        requirement {
            The automaton shall produce a corresponding ordered sequence of
            output symbols stored in the Output Buffer.
        }
    }

    requirement def DetermineAcceptanceReq {
        subject automaton: FiniteStateAutomaton;
        requirement {
            The automaton shall determine whether the input sequence is valid
            by comparing the final state against a predefined set of accepting states.
        }
    }

    requirement def UseTransitionTableReq {
        subject controller: StateController;
        requirement {
            The State Controller shall use the Transition Table to determine
            the next state and output symbol for each current state and input symbol pair.
        }
    }

    requirement def LifecycleComplianceReq {
        subject automaton: FiniteStateAutomaton;
        requirement {
            The automaton shall follow the lifecycle: initialized, ready, processing, completed.
        }
    }

    requirement def DeterministicTransitionsReq {
        subject table: TransitionTable;
        requirement {
            For each combination of current state and input symbol, the Transition Table
            shall specify exactly one next state and one output symbol.
        }
    }

    requirement def ExhaustInputReq {
        subject automaton: FiniteStateAutomaton;
        requirement {
            The automaton shall continue processing until the entire input sequence
            has been exhausted.
        }
    }

    requirement def OrderedOutputReq {
        subject collector: OutputCollector;
        requirement {
            The Output Collector shall store output symbols in the same order
            as the corresponding input symbols were processed.
        }
    }

    requirement def TapeReaderSeqReq {
        subject reader: TapeReader;
        requirement {
            The Tape Reader shall read from the Input Tape one symbol at a time
            and forward each symbol to the State Controller in the correct sequence.
        }
    }

    requirement def AcceptanceCheckerReq {
        subject checker: AcceptanceChecker;
        requirement {
            The Acceptance Checker shall examine the machine's final state after
            the entire input sequence is processed and compare it against the
            predefined list of accepting states to decide whether the input
            sequence is valid.
        }
    }

    requirement def TransitionTableLoadReq {
        subject table: TransitionTable;
        requirement {
            The Transition Table shall be loaded with transition rules, an initial
            state, accepting states, an alphabet, and a set of states before the
            automaton enters the Ready state.
        }
    }

    requirement def OutputBufferReq {
        subject collector: OutputCollector;
        requirement {
            The Output Collector shall maintain an Output Buffer that stores
            all generated output symbols in an ordered sequence.
        }
    }

}
