package 'Adaptive DBS System' {
	private import ScalarValues::*;

	attribute def Current :> Real;
	attribute def Frequency :> Real;
	attribute def Duration :> Real;
	attribute def BiomarkerLevel :> Real;
	attribute def Power :> Real;

	item def NeuralSignal;
	item def BiomarkerData {
		attribute level : BiomarkerLevel;
	}
	item def StimulationCommand {
		attribute current : Current;
		attribute frequency : Frequency;
		attribute duration : Duration;
	}
	item def ElectricalPulse {
		attribute current : Current;
		attribute frequency : Frequency;
		attribute duration : Duration;
	}
	item def TelemetryData;
	item def ProgrammerCommand;
	item def PowerSupply {
		attribute power : Power;
	}

	action def ReceiveBiomarker {
		in data : BiomarkerData;
		out level : BiomarkerLevel;
	}
	action def ComputeStimulation {
		in level : BiomarkerLevel;
		out command : StimulationCommand;
	}
	action def DeliverStimulation {
		in command : StimulationCommand;
		out pulse : ElectricalPulse;
	}
	action def ControlTherapy {
		loop action therapy {
			action receive : ReceiveBiomarker {
				in data;
				out level;
			}
			then if receive.level > 10.0 {
				action compute : ComputeStimulation {
					in level = receive.level;
					out command;
				}
				then action deliver : DeliverStimulation {
					in command = compute.command;
					out pulse;
				}
			}
		}
	}

	part def SensingElectrode {
		port neuralOut {
			out signal : NeuralSignal;
		}
	}

	part def BiomarkerExtractor {
		port neuralIn {
			in signal : NeuralSignal;
		}
		port biomarkerOut {
			out data : BiomarkerData;
		}
		port powerIn {
			in supply : PowerSupply;
		}
	}

	part def ClosedLoopController {
		port biomarkerIn {
			in data : BiomarkerData;
		}
		port commandOut {
			out command : StimulationCommand;
		}
		port telemetryIn {
			in cmd : ProgrammerCommand;
		}
		port telemetryOut {
			out data : TelemetryData;
		}
		port powerIn {
			in supply : PowerSupply;
		}
		attribute threshold : BiomarkerLevel = 10.0;
		attribute maxCurrent : Current = 5.0;
		attribute baseFrequency : Frequency = 130.0;
		attribute pulseDuration : Duration = 60.0;
	}

	part def PulseGenerator {
		port commandIn {
			in command : StimulationCommand;
		}
		port pulseOut {
			out pulse : ElectricalPulse;
		}
		port powerIn {
			in supply : PowerSupply;
		}
	}

	part def StimulationElectrode {
		port pulseIn {
			in pulse : ElectricalPulse;
		}
	}

	part def ImplantableBattery {
		port powerOut {
			out supply : PowerSupply;
		}
	}

	part def WirelessTelemetry {
		port internalDataIn {
			in data : TelemetryData;
		}
		port internalCmdOut {
			out cmd : ProgrammerCommand;
		}
		port externalDataOut {
			out data : TelemetryData;
		}
		port externalCmdIn {
			in cmd : ProgrammerCommand;
		}
		port powerIn {
			in supply : PowerSupply;
		}
	}

	part def ExternalProgrammer {
		port progDataIn {
			in data : TelemetryData;
		}
		port progCmdOut {
			out cmd : ProgrammerCommand;
		}
	}

	part def AdaptiveDBSDevice {
		part sensingElectrode : SensingElectrode;
		part biomarkerExtractor : BiomarkerExtractor;
		part closedLoopController : ClosedLoopController;
		part pulseGenerator : PulseGenerator;
		part stimulationElectrode : StimulationElectrode;
		part implantableBattery : ImplantableBattery;
		part wirelessTelemetry : WirelessTelemetry;

		flow neuralFlow of NeuralSignal
			from sensingElectrode.neuralOut.signal to biomarkerExtractor.neuralIn.signal;
		flow biomarkerFlow of BiomarkerData
			from biomarkerExtractor.biomarkerOut.data to closedLoopController.biomarkerIn.data;
		flow commandFlow of StimulationCommand
			from closedLoopController.commandOut.command to pulseGenerator.commandIn.command;
		flow pulseFlow of ElectricalPulse
			from pulseGenerator.pulseOut.pulse to stimulationElectrode.pulseIn.pulse;
		flow telemetryDataFlow of TelemetryData
			from closedLoopController.telemetryOut.data to wirelessTelemetry.internalDataIn.data;
		flow programmerCmdFlow of ProgrammerCommand
			from wirelessTelemetry.internalCmdOut.cmd to closedLoopController.telemetryIn.cmd;
		flow powerToExtractor of PowerSupply
			from implantableBattery.powerOut.supply to biomarkerExtractor.powerIn.supply;
		flow powerToController of PowerSupply
			from implantableBattery.powerOut.supply to closedLoopController.powerIn.supply;
		flow powerToPulseGen of PowerSupply
			from implantableBattery.powerOut.supply to pulseGenerator.powerIn.supply;
		flow powerToTelemetry of PowerSupply
			from implantableBattery.powerOut.supply to wirelessTelemetry.powerIn.supply;
	}

	part dbsDevice : AdaptiveDBSDevice;
	part externalProgrammer : ExternalProgrammer;

	interface TelemetryInterface connect dbsDevice.wirelessTelemetry.externalDataOut to externalProgrammer.progDataIn {
		flow dataFlow of TelemetryData
			from dbsDevice.wirelessTelemetry.externalDataOut.data to externalProgrammer.progDataIn.data;
	}
	interface ProgrammerInterface connect externalProgrammer.progCmdOut to dbsDevice.wirelessTelemetry.externalCmdIn {
		flow cmdFlow of ProgrammerCommand
			from externalProgrammer.progCmdOut.cmd to dbsDevice.wirelessTelemetry.externalCmdIn.cmd;
	}

	state machine def DBSOperationalState {
		attribute biomarkerLevel : BiomarkerLevel;
		attribute threshold : BiomarkerLevel;
		initial state Idle;
		state Monitoring;
		state Analyzing;
		state Stimulating;
		state Charging;
		transition from Idle to Monitoring;
		transition from Monitoring to Analyzing;
		transition from Analyzing to Stimulating;
		transition from Stimulating to Monitoring;
		transition from Idle to Charging;
		transition from Charging to Idle;
	}

	requirement def AdaptiveTherapyRequirement {
		doc /* The system shall automatically adjust stimulation parameters based on real-time biomarker levels. */
	}
	requirement def ContinuousMonitoringRequirement {
		doc /* The system shall continuously monitor neural activity to detect pathological biomarkers. */
	}
	requirement def BatteryOptimizationRequirement {
		doc /* The system shall optimize stimulation duty cycle to extend implantable battery life. */
	}
	requirement def TelemetryAccessRequirement {
		doc /* The system shall enable two-way wireless communication for clinical monitoring and parameter tuning. */
	}

	requirement adaptiveTherapyReq : AdaptiveTherapyRequirement;
	requirement continuousMonitoringReq : ContinuousMonitoringRequirement;
	requirement batteryOptimizationReq : BatteryOptimizationRequirement;
	requirement telemetryAccessReq : TelemetryAccessRequirement;

	satisfy adaptiveTherapyReq by dbsDevice.closedLoopController;
	satisfy continuousMonitoringReq by dbsDevice.sensingElectrode;
	satisfy batteryOptimizationReq by dbsDevice.closedLoopController;
	satisfy telemetryAccessReq by dbsDevice.wirelessTelemetry;
}
