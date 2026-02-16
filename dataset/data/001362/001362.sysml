package 'Automaton Based System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def InputSymbol {
		attribute value : String;
	}
	
	attribute def StateLabel {
		attribute name : String;
	}
	
	attribute def OutputSymbol {
		attribute value : String;
	}
	
	attribute def TransitionCondition {
		attribute fromState : StateLabel;
		attribute inputSymbol : InputSymbol;
		attribute toState : StateLabel;
		attribute outputSymbol : OutputSymbol;
	}
	
	item def InputTape {
		attribute symbols : InputSymbol[*] ordered;
		attribute readPosition : Integer;
		attribute length : Integer;
	}
	
	item def TransitionTable {
		attribute rules : TransitionCondition[*];
		attribute initialState : StateLabel;
		attribute acceptingStates : StateLabel[*];
	}
	
	item def OutputBuffer {
		attribute outputs : OutputSymbol[*] ordered;
	}
	
	port def InputPort {
		in symbol : InputSymbol;
		in endOfInput : Boolean;
	}
	
	port def OutputPort {
		out symbol : OutputSymbol;
		out accepted : Boolean;
	}
	
	port def StatePort {
		inout currentState : StateLabel;
	}
	
	part def TapeReader {
		attribute tape : InputTape;
		port readPort {
			out symbol : InputSymbol;
			out position : Integer;
			out hasMore : Boolean;
		}
		
		action def AdvanceTape {
			in currentPosition : Integer;
			out nextSymbol : InputSymbol;
			out nextPosition : Integer;
			out moreSymbols : Boolean;
		}
		
		perform action readSequence : AdvanceTape;
	}
	
	part def StateController {
		attribute transitionTable : TransitionTable;
		port controlPort {
			in inputSymbol : InputSymbol;
			inout state : StateLabel;
			out output : OutputSymbol;
		}
		
		action def LookupTransition {
			in currentState : StateLabel;
			in input : InputSymbol;
			out nextState : StateLabel;
			out emittedOutput : OutputSymbol;
			out transitionFound : Boolean;
		}
		
		perform action executeTransition : LookupTransition;
	}
	
	part def AcceptanceChecker {
		port checkPort {
			in finalState : StateLabel;
			in acceptingStates : StateLabel[*];
			out isAccepted : Boolean;
		}
		
		action def VerifyAcceptance {
			in state : StateLabel;
			in validStates : StateLabel[*];
			out result : Boolean;
		}
		
		perform action checkFinalState : VerifyAcceptance;
	}
	
	part def OutputCollector {
		attribute buffer : OutputBuffer;
		port collectorPort {
			in symbol : OutputSymbol;
			out collectedSymbols : OutputSymbol[*];
		}
		
		action def AppendOutput {
			in newSymbol : OutputSymbol;
			in currentBuffer : OutputSymbol[*];
			out updatedBuffer : OutputSymbol[*];
		}
		
		perform action collectSymbols : AppendOutput;
	}
	
	action def ProcessSingleSymbol {
		in inputSymbol : InputSymbol;
		in currentState : StateLabel;
		in transitions : TransitionCondition[*];
		out nextState : StateLabel;
		out outputSymbol : OutputSymbol;
		out validTransition : Boolean;
	}
	
	action def ExecuteAutomaton {
		in inputTape : InputTape;
		in transTable : TransitionTable;
		out outputSequence : OutputSymbol[*] ordered;
		out finalAccepted : Boolean;
		
		attribute state : StateLabel := transTable.initialState;
		attribute position : Integer := 0;
		attribute outputs : OutputSymbol[*] := ();
		
		first start;
		then merge processingLoop;
		
		then action readInput {
			in pos = position;
			in tape = inputTape;
			out currentSymbol : InputSymbol;
		}
		
		then decide;
			if position < inputTape.length then processSymbol;
			else finalize;
		
		action processSymbol {
			action transition : ProcessSingleSymbol {
				in inputSymbol = readInput.currentSymbol;
				in currentState = state;
				in transitions = transTable.rules;
				out nextState : StateLabel;
				out outputSymbol : OutputSymbol;
				out validTransition : Boolean;
			}
			
			then assign state := transition.nextState;
			then assign outputs := outputs->including(transition.outputSymbol);
			then assign position := position + 1;
		}
		then processingLoop;
		
		action finalize {
			action checkAcceptance {
				in finalState = state;
				in acceptStates = transTable.acceptingStates;
				out isAccepted : Boolean;
			}
			
			then assign outputSequence := outputs;
			then assign finalAccepted := checkAcceptance.isAccepted;
		}
		then done;
	}
	
	state def AutomatonOperationalStates {
		entry; then initialized;
		
		state initialized {
			entry assign statusIndicator = "INITIALIZED";
		}
		
		transition init_to_ready
			first initialized
			accept configurationLoaded
			then ready;
		
		state ready {
			entry assign statusIndicator = "READY";
		}
		
		transition ready_to_processing
			first ready
			accept inputReceived
			then processing;
		
		state processing {
			entry assign statusIndicator = "PROCESSING";
			
			state readingInput {
				entry assign processingPhase = "READING";
			}
			
			state computingTransition {
				entry assign processingPhase = "COMPUTING";
			}
			
			state emittingOutput {
				entry assign processingPhase = "EMITTING";
			}
			
			transition read_to_compute
				first readingInput
				accept symbolRead
				then computingTransition;
			
			transition compute_to_emit
				first computingTransition
				accept transitionComputed
				then emittingOutput;
			
			transition emit_to_read
				first emittingOutput
				if moreInput
				then readingInput;
			
			transition emit_to_complete
				first emittingOutput
				if noMoreInput
				then processingComplete;
			
			state processingComplete;
		}
		
		transition processing_to_completed
			first processing.processingComplete
			then completed;
		
		state completed {
			entry assign statusIndicator = "COMPLETED";
		}
		
		transition completed_to_ready
			first completed
			accept reset
			then ready;
		
		attribute statusIndicator : String;
		attribute processingPhase : String;
		attribute moreInput : Boolean;
		attribute noMoreInput : Boolean;
	}
	
	part def FiniteStateAutomaton {
		doc /* 
		A finite state automaton that processes sequential input symbols according to 
		a predefined transition table, producing output symbols and determining acceptance 
		based on final state. The automaton operates as a deterministic sequential machine 
		that transforms input sequences into output sequences while tracking state transitions.
		*/
		
		attribute automatonType : String;
		attribute numberOfStates : Integer;
		
		part tapeReader : TapeReader;
		part stateController : StateController;
		part acceptanceChecker : AcceptanceChecker;
		part outputCollector : OutputCollector;
		
		port inputInterface : InputPort;
		port outputInterface : OutputPort;
		port stateInterface : StatePort;
		
		connection inputToReader connect inputInterface.symbol to tapeReader.readPort.symbol;
		connection readerToController connect tapeReader.readPort.symbol to stateController.controlPort.inputSymbol;
		connection controllerToState connect stateController.controlPort.state to stateInterface.currentState;
		connection controllerToOutput connect stateController.controlPort.output to outputCollector.collectorPort.symbol;
		connection outputToInterface connect outputCollector.collectorPort.collectedSymbols to outputInterface.symbol;
		connection stateToChecker connect stateInterface.currentState to acceptanceChecker.checkPort.finalState;
		connection checkerToOutput connect acceptanceChecker.checkPort.isAccepted to outputInterface.accepted;
		
		perform action executeAutomatonBehavior : ExecuteAutomaton {
			in inputTape = tapeReader.tape;
			in transTable = stateController.transitionTable;
			out outputSequence : OutputSymbol[*];
			out finalAccepted : Boolean;
		}
		
		exhibit state operationalBehavior : AutomatonOperationalStates;
	}
	
	requirement def <'REQ-AUTO-001'> AutomatonPrimaryFunction {
		doc /* 
		The automaton system shall process input symbol sequences according to state 
		transition rules to produce output sequences and determine input acceptance.
		*/
		
		subject automaton : FiniteStateAutomaton;
		
		require constraint sequentialProcessing {
			doc /* The automaton shall process input symbols in sequential order from the input tape. */
		}
		
		require constraint deterministicTransitions {
			doc /* For each state and input symbol pair, the automaton shall execute exactly one transition. */
		}
		
		require constraint outputGeneration {
			doc /* The automaton shall generate an output symbol for each processed input symbol. */
		}
		
		require constraint acceptanceDecision {
			doc /* The automaton shall determine acceptance based on whether the final state is in the set of accepting states. */
		}
	}
	
	requirement def <'REQ-AUTO-002'> AutomatonReliability {
		doc /* 
		The automaton system shall operate reliably with deterministic behavior 
		and complete processing for all valid input sequences.
		*/
		
		subject automaton : FiniteStateAutomaton;
		
		require constraint completeness {
			doc /* The automaton shall process all symbols in the input tape until completion. */
		}
		
		require constraint determinism {
			doc /* The automaton shall produce identical outputs for identical input sequences. */
		}
	}
	
	part automatonInstance : FiniteStateAutomaton {
		attribute :>> automatonType = "DeterministicFiniteAutomaton";
		attribute :>> numberOfStates = 4;
		
		part :>> tapeReader {
			attribute :>> tape {
				attribute :>> symbols = (
					InputSymbol { value = "0" },
					InputSymbol { value = "1" },
					InputSymbol { value = "1" },
					InputSymbol { value = "0" }
				);
				attribute :>> readPosition = 0;
				attribute :>> length = 4;
			}
		}
		
		part :>> stateController {
			attribute :>> transitionTable {
				attribute :>> initialState = StateLabel { name = "q0" };
				attribute :>> acceptingStates = (
					StateLabel { name = "q2" },
					StateLabel { name = "q3" }
				);
				attribute :>> rules = (
					TransitionCondition {
						fromState = StateLabel { name = "q0" };
						inputSymbol = InputSymbol { value = "0" };
						toState = StateLabel { name = "q1" };
						outputSymbol = OutputSymbol { value = "A" };
					},
					TransitionCondition {
						fromState = StateLabel { name = "q0" };
						inputSymbol = InputSymbol { value = "1" };
						toState = StateLabel { name = "q2" };
						outputSymbol = OutputSymbol { value = "B" };
					},
					TransitionCondition {
						fromState = StateLabel { name = "q1" };
						inputSymbol = InputSymbol { value = "0" };
						toState = StateLabel { name = "q1" };
						outputSymbol = OutputSymbol { value = "C" };
					},
					TransitionCondition {
						fromState = StateLabel { name = "q1" };
						inputSymbol = InputSymbol { value = "1" };
						toState = StateLabel { name = "q3" };
						outputSymbol = OutputSymbol { value = "D" };
					}
				);
			}
		}
		
		part :>> outputCollector {
			attribute :>> buffer {
				attribute :>> outputs = ();
			}
		}
		
		satisfy primaryFunction : AutomatonPrimaryFunction {
			subject automaton = automatonInstance;
		}
		
		satisfy reliability : AutomatonReliability {
			subject automaton = automatonInstance;
		}
	}
}
