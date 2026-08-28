package QuantumComputingSystem {
	package Definitions {
		import ISQ::*;

		attribute def QubitCount;
		attribute def CoolDownComplete;
		attribute def QuantumAlgorithm;
		attribute def PulseSequence;
		attribute def MeasurementData;
		attribute def DigitalData;
		attribute def CorrectedData;
		attribute def FinalResult;
		attribute def CoolingSignal;

		part def QPU {
			attribute qubitCount : QubitCount = 127;
			in coolingIn : CoolingSignal;
			in controlPulseIn : PulseSequence;
			out measurementOut : MeasurementData;
		}

		part def CryogenicCoolingSystem {
			attribute targetTemperature : TemperatureValue = 0.015 [K];
			out coolingOut : CoolingSignal;
		}

		part def ClassicalControlSystem {
			in algorithmIn : QuantumAlgorithm;
			out pulseOut : PulseSequence;
			in correctedDataIn : CorrectedData;
			out resultOut : FinalResult;
		}

		part def ReadoutSystem {
			in measurementIn : MeasurementData;
			out digitalDataOut : DigitalData;
		}

		part def ErrorCorrectionUnit {
			in rawDataIn : DigitalData;
			out correctedDataOut : CorrectedData;
		}

		action def CoolDown {
			out item cooling : CoolingSignal;
		}
		action def CompileAlgorithm {
			in item algorithm : QuantumAlgorithm;
			out item pulses : PulseSequence;
		}
		action def ExecuteQuantumAlgorithm {
			in item pulses : PulseSequence;
			out item measurement : MeasurementData;
		}
		action def MeasureQubits {
			in item measurement : MeasurementData;
			out item digitalData : DigitalData;
		}
		action def CorrectErrors {
			in item rawData : DigitalData;
			out item correctedData : CorrectedData;
		}
		action def ProcessResult {
			in item correctedData : CorrectedData;
			out item result : FinalResult;
		}

		action def RunQuantumComputation {
			in item algorithm : QuantumAlgorithm;
			out item result : FinalResult;

			first start;
			then action compile : CompileAlgorithm {
				in item algorithm = RunQuantumComputation::algorithm;
				out item pulses;
			}
			flow from compile.pulses to execute.pulses;
			then action execute : ExecuteQuantumAlgorithm {
				in item pulses;
				out item measurement;
			}
			flow from execute.measurement to measure.measurement;
			then action measure : MeasureQubits {
				in item measurement;
				out item digitalData;
			}
			flow from measure.digitalData to correct.rawData;
			then action correct : CorrectErrors {
				in item rawData;
				out item correctedData;
			}
			flow from correct.correctedData to process.correctedData;
			then action process : ProcessResult {
				in item correctedData;
				out item result;
			}
			then done;
		}

		state def SystemStates {
			entry; then CoolingDown;

			state CoolingDown {
				do action coolDown : CoolDown;
			}
			transition first CoolingDown accept CoolDownComplete then Ready;

			state Ready;
			transition first Ready accept algorithm : QuantumAlgorithm then Executing;

			state Executing {
				do action execute : ExecuteQuantumAlgorithm;
			}
			transition first Executing then Measuring;

			state Measuring;
			transition first Measuring then ErrorCorrecting;

			state ErrorCorrecting;
			transition first ErrorCorrecting then Ready;
		}

		requirement def QuantumSystemRequirement {
			/* The system shall execute quantum algorithms leveraging superposition and entanglement to solve problems intractable for classical supercomputers. */
		}
		requirement def QPURequirement {
			/* The QPU shall contain 127 qubits. */
			attribute minQubits : QubitCount = 127;
		}
		requirement def CoolingRequirement {
			/* The cryogenic cooling system shall maintain the QPU at 0.015 Kelvin. */
			attribute maxTemp : TemperatureValue = 0.015 [K];
		}
		requirement def ErrorCorrectionRequirement {
			/* The error correction unit shall analyze measurement results and correct errors to improve reliability. */
		}
	}

	package Usages {
		private import Definitions::*;

		part quantumComputer {
			part classicalControl : ClassicalControlSystem;
			part coolingSystem : CryogenicCoolingSystem;
			part qpu : QPU;
			part readout : ReadoutSystem;
			part errorCorrection : ErrorCorrectionUnit;

			connect coolingSystem.coolingOut to qpu.coolingIn;
			connect classicalControl.pulseOut to qpu.controlPulseIn;
			connect qpu.measurementOut to readout.measurementIn;
			connect readout.digitalDataOut to errorCorrection.rawDataIn;
			connect errorCorrection.correctedDataOut to classicalControl.correctedDataIn;

			exhibit systemStates : SystemStates;
		}

		satisfy QuantumSystemRequirement by quantumComputer;
		satisfy QPURequirement by quantumComputer.qpu;
		satisfy CoolingRequirement by quantumComputer.coolingSystem;
		satisfy ErrorCorrectionRequirement by quantumComputer.errorCorrection;
	}
}
