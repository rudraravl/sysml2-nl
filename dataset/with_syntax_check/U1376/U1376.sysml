package 'Alternating Current Power Distribution System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ACVoltageValue :> ISQ::VoltageValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::VoltageUnit;
	}
	
	attribute def ACCurrentValue :> ISQ::ElectricCurrentValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::ElectricCurrentUnit;
	}
	
	attribute def ACFrequencyValue :> ISQ::FrequencyValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::FrequencyUnit;
	}
	
	attribute def PowerValue :> ISQ::PowerValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::PowerUnit;
	}
	
	attribute def PhaseAngleValue :> ISQ::AngleValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::PlaneAngleUnit;
	}
	
	attribute def PowerFactorValue :> Real;
	
	item def ACWaveform {
		attribute rmsVoltage : ACVoltageValue;
		attribute rmsCurrent : ACCurrentValue;
		attribute frequency : ACFrequencyValue;
		attribute phaseAngle : PhaseAngleValue;
	}
	
	item def PowerDemand {
		attribute activePower : PowerValue;
		attribute reactivePower : PowerValue;
		attribute powerFactor : PowerFactorValue;
	}
	
	port def ACSupplyPort {
		out item acWaveform : ACWaveform;
	}
	
	port def ACConsumptionPort {
		in item acWaveform : ACWaveform;
	}
	
	port def ControlPort {
		in item demandSignal : PowerDemand;
		out item statusSignal : Boolean;
	}
	
	part def PowerGenerator {
		port acOutput : ACSupplyPort;
		
		attribute nominalVoltage : ACVoltageValue;
		attribute nominalFrequency : ACFrequencyValue;
		attribute maxCapacity : PowerValue;
		attribute currentOutput : PowerValue;
		
		perform action generatePower {
			out generatedWaveform : ACWaveform;
		}
	}
	
	part def StepUpTransformer {
		port primaryInput : ACConsumptionPort;
		port secondaryOutput : ACSupplyPort;
		
		attribute primaryVoltage : ACVoltageValue;
		attribute secondaryVoltage : ACVoltageValue;
		attribute turnsRatio : Real;
		attribute efficiency : Real;
		
		perform action stepUpVoltage {
			in inputWaveform : ACWaveform;
			out outputWaveform : ACWaveform;
		}
	}
	
	part def TransmissionLine {
		port lineInput : ACConsumptionPort;
		port lineOutput : ACSupplyPort;
		
		attribute resistance : ISQ::ResistanceValue;
		attribute reactance : ISQ::ResistanceValue;
		attribute lineLength : ISQ::LengthValue;
		attribute voltageDrop : ACVoltageValue;
		
		perform action transmitPower {
			in inputWaveform : ACWaveform;
			out outputWaveform : ACWaveform;
		}
	}
	
	part def StepDownTransformer {
		port primaryInput : ACConsumptionPort;
		port secondaryOutput : ACSupplyPort;
		
		attribute primaryVoltage : ACVoltageValue;
		attribute secondaryVoltage : ACVoltageValue;
		attribute turnsRatio : Real;
		attribute efficiency : Real;
		
		perform action stepDownVoltage {
			in inputWaveform : ACWaveform;
			out outputWaveform : ACWaveform;
		}
	}
	
	part def ProtectionRelay {
		port relayInput : ACConsumptionPort;
		port relayOutput : ACSupplyPort;
		port controlInterface : ControlPort;
		
		attribute tripCurrent : ACCurrentValue;
		attribute tripVoltage : ACVoltageValue;
		attribute relayState : Boolean;
		
		action def MonitorAndProtect {
			in inputWaveform : ACWaveform;
			in tripCurrentThreshold : ACCurrentValue;
			in tripVoltageThreshold : ACVoltageValue;
			out outputWaveform : ACWaveform;
			out isFaulted : Boolean;
		}
		
		perform action protectCircuit : MonitorAndProtect {
			in inputWaveform;
			in tripCurrentThreshold = tripCurrent;
			in tripVoltageThreshold = tripVoltage;
			out outputWaveform;
			out isFaulted;
		}
	}
	
	part def DistributionLoad {
		port loadInput : ACConsumptionPort;
		port loadControl : ControlPort;
		
		attribute ratedPower : PowerValue;
		attribute actualConsumption : PowerValue;
		attribute loadPowerFactor : PowerFactorValue;
		
		perform action consumePower {
			in suppliedWaveform : ACWaveform;
			out demand : PowerDemand;
		}
	}
	
	part def VoltageRegulator {
		port regulatorInput : ACConsumptionPort;
		port regulatorOutput : ACSupplyPort;
		
		attribute targetVoltage : ACVoltageValue;
		attribute voltageRange : Real;
		
		perform action regulateVoltage {
			in inputWaveform : ACWaveform;
			out regulatedWaveform : ACWaveform;
		}
	}
	
	action def MonitorSystemVoltage {
		in waveform : ACWaveform;
		out voltageLevel : ACVoltageValue;
	}
	
	action def MonitorSystemFrequency {
		in waveform : ACWaveform;
		out frequencyLevel : ACFrequencyValue;
	}
	
	action def BalanceLoad {
		in totalDemand : PowerDemand;
		in generatorCapacity : PowerValue;
		out balanceCommand : Real;
	}
	
	action def DistributeElectricalPower {
		first start;
		then merge continuousDistribution;
		
		action monitorVoltage : MonitorSystemVoltage {
			in waveform;
			out voltageLevel;
		}
		then action monitorFrequency : MonitorSystemFrequency {
			in waveform = monitorVoltage.waveform;
			out frequencyLevel;
		}
		then decide;
			if monitorFrequency.frequencyLevel.num < 59.0 then adjustSystem;
			if monitorFrequency.frequencyLevel.num > 61.0 then adjustSystem;
			if monitorVoltage.voltageLevel.num < 110000.0 then adjustSystem;
			if monitorVoltage.voltageLevel.num > 130000.0 then adjustSystem;
			if monitorFrequency.frequencyLevel.num >= 59.0 then maintainDistribution;
		
		action adjustSystem : BalanceLoad {
			in totalDemand;
			in generatorCapacity;
			out balanceCommand;
		}
		then continuousDistribution;
		
		action maintainDistribution;
		then continuousDistribution;
		
		then done;
	}
	
	part def ACPowerDistributionSystem {
		part generator : PowerGenerator {
			attribute :>> nominalVoltage {
				attribute :>> num = 13800.0;
				attribute :>> mRef = SI::V;
			}
			attribute :>> nominalFrequency {
				attribute :>> num = 60.0;
				attribute :>> mRef = SI::Hz;
			}
			attribute :>> maxCapacity {
				attribute :>> num = 1000000.0;
				attribute :>> mRef = SI::W;
			}
		}
		
		part stepUpXfmr : StepUpTransformer {
			attribute :>> primaryVoltage {
				attribute :>> num = 13800.0;
				attribute :>> mRef = SI::V;
			}
			attribute :>> secondaryVoltage {
				attribute :>> num = 138000.0;
				attribute :>> mRef = SI::V;
			}
			attribute :>> turnsRatio = 10.0;
			attribute :>> efficiency = 0.98;
		}
		
		part transmissionLine : TransmissionLine {
			attribute :>> lineLength {
				attribute :>> num = 100000.0;
				attribute :>> mRef = SI::m;
			}
		}
		
		part protectionRelay : ProtectionRelay {
			attribute :>> tripCurrent {
				attribute :>> num = 5000.0;
				attribute :>> mRef = SI::A;
			}
			attribute :>> tripVoltage {
				attribute :>> num = 150000.0;
				attribute :>> mRef = SI::V;
			}
		}
		
		part stepDownXfmr : StepDownTransformer {
			attribute :>> primaryVoltage {
				attribute :>> num = 138000.0;
				attribute :>> mRef = SI::V;
			}
			attribute :>> secondaryVoltage {
				attribute :>> num = 13800.0;
				attribute :>> mRef = SI::V;
			}
			attribute :>> turnsRatio = 0.1;
			attribute :>> efficiency = 0.98;
		}
		
		part regulator : VoltageRegulator {
			attribute :>> targetVoltage {
				attribute :>> num = 13800.0;
				attribute :>> mRef = SI::V;
			}
			attribute :>> voltageRange = 0.05;
		}
		
		part load : DistributionLoad {
			attribute :>> ratedPower {
				attribute :>> num = 900000.0;
				attribute :>> mRef = SI::W;
			}
			attribute :>> loadPowerFactor = 0.92;
		}
		
		connection genToStepUp connect generator.acOutput to stepUpXfmr.primaryInput;
		connection stepUpToTransmission connect stepUpXfmr.secondaryOutput to transmissionLine.lineInput;
		connection transmissionToRelay connect transmissionLine.lineOutput to protectionRelay.relayInput;
		connection relayToStepDown connect protectionRelay.relayOutput to stepDownXfmr.primaryInput;
		connection stepDownToRegulator connect stepDownXfmr.secondaryOutput to regulator.regulatorInput;
		connection regulatorToLoad connect regulator.regulatorOutput to load.loadInput;
		
		perform action distributePower : DistributeElectricalPower;
	}
	
	part acSystem : ACPowerDistributionSystem;
	
	requirement def SystemPrimaryFunction {
		doc /* The primary function of the AC Power Distribution System is to 
		       efficiently and reliably generate, transmit, and distribute 
		       alternating current electrical power from a central generation 
		       source to distributed loads while maintaining stable voltage and 
		       frequency levels throughout the network. */
		
		subject system : ACPowerDistributionSystem;
		
		require voltageRegulation {
			doc /* The system shall maintain voltage within ±5% of nominal at load. */
		}
		
		require frequencyStability {
			doc /* The system shall maintain frequency at 60 Hz ±1 Hz. */
		}
		
		require faultProtection {
			doc /* The system shall isolate faults within 100 milliseconds. */
		}
		
		require powerQuality {
			doc /* The system shall maintain power factor above 0.9. */
		}
		
		require efficiency {
			doc /* The system shall achieve end-to-end efficiency above 90%. */
		}
	}
	
	requirement systemReq : SystemPrimaryFunction {
		subject acSystem;
	}
}
