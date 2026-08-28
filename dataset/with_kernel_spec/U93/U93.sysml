package 'Neurostimulation System' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def CurrentValue :> Real;
	attribute def FrequencyValue :> Real;
	attribute def TimeValue :> Real;
	attribute def ImpedanceValue :> Real;
	attribute def ChargeLevel :> Real;

	item def NeuralSignal;
	item def StimulationPulse {
		attribute amplitude : CurrentValue;
		attribute frequency : FrequencyValue;
		attribute pulseWidth : TimeValue;
	}
	item def TherapyCommand;
	item def SafetyAlert;
	item def SystemStatus;
	item def TherapyParameters {
		attribute targetAmplitude : CurrentValue;
		attribute targetFrequency : FrequencyValue;
		attribute targetPulseWidth : TimeValue;
	}
	item def ImpedanceMeasurement {
		attribute value : ImpedanceValue;
	}
	item def BatteryStatus {
		attribute charge : ChargeLevel;
	}

	action def 'MonitorNeuralActivity';
	action def 'DeliverStimulation';
	action def 'AdjustTherapy';
	action def 'HaltTherapy';

	part def Patient;
	part def LeadAssembly {
		port neuralOutPort { out neuralSignal : NeuralSignal; }
		port stimInPort { in stimPulse : StimulationPulse; }
		port impedanceOutPort { out impedance : ImpedanceMeasurement; }
	}

	part def SensingSubsystem {
		port neuralInPort { in neuralSignal : NeuralSignal; }
		port processedSignalOutPort { out processedSignal : NeuralSignal; }
		perform action 'MonitorNeuralActivity';
	}
	part def StimulationSubsystem {
		port commandInPort { in command : TherapyCommand; }
		port stimOutPort { out stimPulse : StimulationPulse; }
		port currentOutPort { out deliveredCurrent : CurrentValue; }
		perform action 'DeliverStimulation';
	}
	part def ControlSubsystem {
		port signalInPort { in processedSignal : NeuralSignal; }
		port alertInPort { in alert : SafetyAlert; }
		port configInPort { in therapyConfig : TherapyParameters; }
		port powerInPort { in powerStatus : BatteryStatus; }
		port commandOutPort { out command : TherapyCommand; }
		port statusOutPort { out systemStatus : SystemStatus; }
		perform action 'AdjustTherapy';
	}
	part def PowerSubsystem {
		port powerOutPort { out powerStatus : BatteryStatus; }
	}
	part def SafetySubsystem {
		port impedanceInPort { in impedance : ImpedanceMeasurement; }
		port currentInPort { in deliveredCurrent : CurrentValue; }
		port alertOutPort { out alert : SafetyAlert; }
	}

	state def IPGStates {
		entry; then standby;
		state standby;
		accept 'Start Therapy' then activeTherapy;
		state activeTherapy {
			accept 'Symptom Change' then adjusting;
			accept 'Fault Detected' then fault;
		}
		state adjusting {
			accept 'Optimization Complete' then activeTherapy;
			accept 'Fault Detected' then fault;
		}
		state fault {
			entry action 'HaltTherapy';
			accept 'Fault Cleared' then standby;
		}
	}

	part def ImplantablePulseGenerator {
		port leadNeuralInPort { in neuralSignal : NeuralSignal; }
		port leadStimOutPort { out stimPulse : StimulationPulse; }
		port leadImpedanceInPort { in impedance : ImpedanceMeasurement; }
		port programmerPort {
			in therapyConfig : TherapyParameters;
			out systemStatus : SystemStatus;
		}

		part sensingSubsystem : SensingSubsystem;
		part stimulationSubsystem : StimulationSubsystem;
		part controlSubsystem : ControlSubsystem;
		part powerSubsystem : PowerSubsystem;
		part safetySubsystem : SafetySubsystem;

		exhibit state ipgStates : IPGStates;
	}

	part def ExternalProgrammer {
		port ipgPort {
			out therapyConfig : TherapyParameters;
			in systemStatus : SystemStatus;
		}
	}

	part patient : Patient;
	part lead : LeadAssembly;
	part ipg : ImplantablePulseGenerator {
		flow neuralSignalFlow of NeuralSignal 
			from leadNeuralInPort.neuralSignal to sensingSubsystem.neuralInPort.neuralSignal;
		flow processedSignalFlow of NeuralSignal 
			from sensingSubsystem.processedSignalOutPort.processedSignal to controlSubsystem.signalInPort.processedSignal;
		flow therapyConfigFlow of TherapyParameters 
			from programmerPort.therapyConfig to controlSubsystem.configInPort.therapyConfig;
		flow commandFlow of TherapyCommand 
			from controlSubsystem.commandOutPort.command to stimulationSubsystem.commandInPort.command;
		flow stimPulseFlow of StimulationPulse 
			from stimulationSubsystem.stimOutPort.stimPulse to leadStimOutPort.stimPulse;
		flow currentFlow of CurrentValue 
			from stimulationSubsystem.currentOutPort.deliveredCurrent to safetySubsystem.currentInPort.deliveredCurrent;
		flow impedanceFlow of ImpedanceMeasurement 
			from leadImpedanceInPort.impedance to safetySubsystem.impedanceInPort.impedance;
		flow alertFlow of SafetyAlert 
			from safetySubsystem.alertOutPort.alert to controlSubsystem.alertInPort.alert;
		flow powerFlow of BatteryStatus 
			from powerSubsystem.powerOutPort.powerStatus to controlSubsystem.powerInPort.powerStatus;
		flow statusFlow of SystemStatus 
			from controlSubsystem.statusOutPort.systemStatus to programmerPort.systemStatus;
	}
	part programmer : ExternalProgrammer;

	interface leadToIPGNeuralInterface connect lead.neuralOutPort to ipg.leadNeuralInPort {
		flow neuralSignalFlow of NeuralSignal from lead.neuralOutPort.neuralSignal to ipg.leadNeuralInPort.neuralSignal;
	}
	interface ipgToLeadStimInterface connect ipg.leadStimOutPort to lead.stimInPort {
		flow stimPulseFlow of StimulationPulse from ipg.leadStimOutPort.stimPulse to lead.stimInPort.stimPulse;
	}
	interface leadToIPGImpedanceInterface connect lead.impedanceOutPort to ipg.leadImpedanceInPort {
		flow impedanceFlow of ImpedanceMeasurement from lead.impedanceOutPort.impedance to ipg.leadImpedanceInPort.impedance;
	}
	interface programmerToIPGInterface connect programmer.ipgPort to ipg.programmerPort {
		flow therapyConfigFlow of TherapyParameters from programmer.ipgPort.therapyConfig to ipg.programmerPort.therapyConfig;
		flow systemStatusFlow of SystemStatus from ipg.programmerPort.systemStatus to programmer.ipgPort.systemStatus;
	}

	requirement def SafetyRequirement {
		subject ipg : ImplantablePulseGenerator;
		doc /* The IPG must detect unsafe conditions and halt therapy to prevent patient harm. */
	}

	requirement def ClosedLoopRequirement {
		subject ipg : ImplantablePulseGenerator;
		doc /* The system must continuously monitor neural activity and adjust therapy in real-time. */
	}
}
