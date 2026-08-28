package ChemoreceptorSystemModel {
	private import ScalarValues::*;

	value def ConcentrationValue :> Real;
	value def ElectricPotentialValue :> Real;
	value def FrequencyValue :> Real;
	value def TimeValue :> Real;

	item def ChemicalStimulus {
		attribute concentration : ConcentrationValue;
	}
	item def ReceptorPotential {
		attribute amplitude : ElectricPotentialValue;
	}
	item def NeuralImpulse {
		attribute frequency : FrequencyValue;
		attribute amplitude : ElectricPotentialValue;
	}
	item def CommandSignal {
		attribute command : String;
	}

	port def ChemicalInputPort {
		in stimulus : ChemicalStimulus;
	}
	port def PotentialOutputPort {
		out potential : ReceptorPotential;
	}
	port def PotentialInputPort {
		in potential : ReceptorPotential;
	}
	port def ImpulseOutputPort {
		out impulse : NeuralImpulse;
	}
	port def ImpulseInputPort {
		in impulse : NeuralImpulse;
	}
	port def CommandOutputPort {
		out command : CommandSignal;
	}
	port def CommandInputPort {
		in command : CommandSignal;
	}

	action def DetectChemical {
		in stimulus : ChemicalStimulus;
		out potential : ReceptorPotential;
	}
	action def TransduceSignal {
		in potential : ReceptorPotential;
		out impulse : NeuralImpulse;
	}
	action def ProcessSignal {
		in impulse : NeuralImpulse;
		out command : CommandSignal;
	}
	action def TriggerResponse {
		in command : CommandSignal;
	}

	action def ChemoreceptionProcess {
		in stimulus : ChemicalStimulus;
		action detect : DetectChemical;
		action transduce : TransduceSignal;
		action process : ProcessSignal;
		action trigger : TriggerResponse;

		flow detect.potential to transduce.potential;
		flow transduce.impulse to process.impulse;
		flow process.command to trigger.command;

		first start;
		then detect;
		then transduce;
		then process;
		then trigger;
		then done;
	}

	part def ChemoreceptorCell {
		port chemicalInput : ChemicalInputPort;
		port potentialOutput : PotentialOutputPort;
		attribute threshold : ConcentrationValue = 0.001;

		state def CellStateMachine {
			entry; then Resting;
			state Resting;
			state Binding;
			state Transducing;
			state Sending;
			state Recovery;

			transition first Resting
				accept s : ChemicalStimulus via chemicalInput
				if s.concentration >= threshold
				then Binding;
			transition first Binding then Transducing;
			transition first Transducing then Sending;
			transition first Sending then Recovery;
			transition first Recovery then Resting;
		}
	}

	part def NeuralTransmitter {
		port potentialInput : PotentialInputPort;
		port impulseOutput : ImpulseOutputPort;
		attribute firingThreshold : ElectricPotentialValue = 15;

		state def TransmitterStateMachine {
			entry; then Idle;
			state Idle;
			state Firing;

			transition first Idle
				accept p : ReceptorPotential via potentialInput
				if p.amplitude >= firingThreshold
				then Firing;
			transition first Firing then Idle;
		}
	}

	part def SignalProcessor {
		port impulseInput : ImpulseInputPort;
		port commandOutput : CommandOutputPort;

		state def ProcessorStateMachine {
			entry; then Waiting;
			state Waiting;
			state Processing;

			transition first Waiting
				accept i : NeuralImpulse via impulseInput
				then Processing;
			transition first Processing then Waiting;
		}
	}

	part def EffectorUnit {
		port commandInput : CommandInputPort;

		state def EffectorStateMachine {
			entry; then Idle;
			state Idle;
			state Executing;

			transition first Idle
				accept c : CommandSignal via commandInput
				then Executing;
			transition first Executing then Idle;
		}
	}

	part def ChemoreceptorSystem {
		attribute responseTime : TimeValue;

		part receptorCell : ChemoreceptorCell;
		part transmitter : NeuralTransmitter;
		part processor : SignalProcessor;
		part effector : EffectorUnit;

		flow receptorCell.potentialOutput.potential to transmitter.potentialInput.potential;
		flow transmitter.impulseOutput.impulse to processor.impulseInput.impulse;
		flow processor.commandOutput.command to effector.commandInput.command;
	}

	part chemoreceptorSystem : ChemoreceptorSystem;

	requirement def SensitivityRequirement {
		doc /* The receptor cell shall detect chemical concentrations as low as 0.001 mol/m^3. */
		subject receptorCell : ChemoreceptorCell;
		attribute minDetectableConcentration : ConcentrationValue = 0.001;
	}

	requirement def ResponseTimeRequirement {
		doc /* The system shall generate a response within 100 milliseconds of initial detection. */
		subject system : ChemoreceptorSystem;
		attribute maxResponseTime : TimeValue = 100;
	}

	requirement sensitivity : SensitivityRequirement;
	requirement responseTime : ResponseTimeRequirement;

	satisfy sensitivity by chemoreceptorSystem;
	satisfy responseTime by chemoreceptorSystem;
}
