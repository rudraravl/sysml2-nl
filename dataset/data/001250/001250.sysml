package 'Single-Photon Avalanche Diode System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def QuantumEfficiency {
		attribute value : Real;
	}

	attribute def DarkCountRate {
		attribute value : Real;
	}

	attribute def TimingJitter {
		attribute value : TimeValue;
	}

	item def Photon {
		attribute wavelength : LengthValue;
		attribute energy : EnergyValue;
		attribute arrivalTime : TimeValue;
	}

	item def AvalancheCurrent {
		attribute peakCurrent : ElectricCurrentValue;
		attribute risetime : TimeValue;
	}

	item def OutputPulse {
		attribute amplitude : ElectricPotentialValue;
		attribute width : TimeValue;
		attribute timestamp : TimeValue;
	}

	item def BiasVoltage {
		attribute level : ElectricPotentialValue;
		attribute excessBias : ElectricPotentialValue;
	}

	port def OpticalInputPort {
		in photonStream : Photon[0..*];
	}

	port def BiasInputPort {
		in biasSignal : BiasVoltage;
	}

	port def AvalancheOutputPort {
		out avalanche : AvalancheCurrent;
	}

	port def PulseOutputPort {
		out pulse : OutputPulse;
	}

	port def QuenchControlPort {
		out quenchCommand : Boolean;
		in resetComplete : Boolean;
	}

	action def AbsorbPhoton {
		in photon : Photon;
		out carrierGenerated : Boolean;
	}

	action def InitiateAvalanche {
		in carrier : Boolean;
		in bias : BiasVoltage;
		out avalancheCurrent : AvalancheCurrent;
	}

	action def GenerateOutputPulse {
		in avalanche : AvalancheCurrent;
		out pulse : OutputPulse;
	}

	action def QuenchAvalanche {
		in avalanche : AvalancheCurrent;
		out quenchSignal : Boolean;
	}

	action def ResetDiode {
		in quenchComplete : Boolean;
		out resetSignal : Boolean;
	}

	part def SPADDiode {
		attribute quantumEfficiency : QuantumEfficiency;
		attribute darkCountRate : DarkCountRate;
		attribute breakdownVoltage : ElectricPotentialValue;
		attribute deadTime : TimeValue;

		port opticalIn : OpticalInputPort;
		port biasIn : BiasInputPort;
		port avalancheOut : AvalancheOutputPort;
		port quenchControl : QuenchControlPort;
	}

	part def PassiveQuenchingCircuit {
		attribute quenchResistance : Real;
		attribute resetTime : TimeValue;

		port avalancheIn : ~AvalancheOutputPort;
		port control : ~QuenchControlPort;
		port biasOut : ~BiasInputPort;
	}

	part def BiasSupply {
		attribute outputVoltage : ElectricPotentialValue;
		attribute excessBias : ElectricPotentialValue;

		port biasOutput : BiasInputPort;
	}

	part def DiscriminatorCircuit {
		attribute threshold : ElectricPotentialValue;
		attribute timeResolution : TimeValue;

		port pulseIn : ~PulseOutputPort;
		port detectionOut : PulseOutputPort;
	}

	part def CoolingSystem {
		attribute operatingTemperature : TemperatureValue;
		attribute coolingPower : PowerValue;
	}

	action def SPADDetectionProcess {
		first start;
		then merge waitForPhoton;

		action waitForPhoton {
			out photonDetected : Boolean;
		}
		then decide;
			if waitForPhoton.photonDetected then absorbPhoton;
			if !waitForPhoton.photonDetected then waitForPhoton;

		action absorbPhoton : AbsorbPhoton;
		then decide;
			if absorbPhoton.carrierGenerated then triggerAvalanche;
			if !absorbPhoton.carrierGenerated then waitForPhoton;

		action triggerAvalanche : InitiateAvalanche;
		then action emitPulse : GenerateOutputPulse {
			in avalanche = triggerAvalanche.avalancheCurrent;
		}
		then action quenchProcess : QuenchAvalanche {
			in avalanche = triggerAvalanche.avalancheCurrent;
		}
		then action resetProcess : ResetDiode {
			in quenchComplete = quenchProcess.quenchSignal;
		}
		then waitForPhoton;
	}

	part spadSystem {
		doc /* 
		 * Single-Photon Avalanche Diode System
		 * 
		 * Primary Function: Detect individual photons with high temporal precision
		 * by operating a reverse-biased p-n junction above its breakdown voltage.
		 * When a single photon is absorbed, it triggers a self-sustaining avalanche
		 * multiplication process that generates a macroscopic current pulse. The
		 * system then actively quenches this avalanche and resets the diode to
		 * detect subsequent photons, enabling photon counting and timing applications.
		 */

		port opticalInput : OpticalInputPort;
		port digitalOutput : PulseOutputPort;

		part diode : SPADDiode {
			attribute :>> quantumEfficiency {
				attribute :>> value = 0.70;
			}
			attribute :>> darkCountRate {
				attribute :>> value = 50.0;
			}
			attribute :>> breakdownVoltage = 24.5 [SI::V];
			attribute :>> deadTime = 25.0 [SI::ns];
		}

		part quenchCircuit : PassiveQuenchingCircuit {
			attribute :>> quenchResistance = 50.0e3;
			attribute :>> resetTime = 30.0 [SI::ns];
			perform detectionProcess.quenchProcess;
			perform detectionProcess.resetProcess;
		}

		part biasSupply : BiasSupply {
			attribute :>> outputVoltage = 27.0 [SI::V];
			attribute :>> excessBias = 2.5 [SI::V];
		}

		part discriminator : DiscriminatorCircuit {
			attribute :>> threshold = 0.3 [SI::V];
			attribute :>> timeResolution = 50.0 [SI::ps];
			perform detectionProcess.emitPulse;
		}

		part cooling : CoolingSystem {
			attribute :>> operatingTemperature = 243.15 [SI::K];
			attribute :>> coolingPower = 5.0 [SI::W];
		}

		perform action detectionProcess[*] ordered references SPADDetectionProcess;

		connect opticalInput to diode.opticalIn;
		connect biasSupply.biasOutput to quenchCircuit.biasOut;
		connect quenchCircuit.biasOut to diode.biasIn;
		connect diode.avalancheOut to quenchCircuit.avalancheIn;
		connect diode.quenchControl to quenchCircuit.control;
		connect discriminator.detectionOut to digitalOutput;
	}

	requirement def HighDetectionEfficiency {
		doc /* The SPAD system shall achieve quantum efficiency greater than 60% 
		       in the target wavelength range to maximize photon detection probability. */
		subject system : SPADDiode;
		require constraint { system.quantumEfficiency.value >= 0.60 }
	}

	requirement def LowDarkCounts {
		doc /* The SPAD system shall maintain dark count rate below 100 Hz at operating
		       temperature to minimize false detection events. */
		subject system : SPADDiode;
		require constraint { system.darkCountRate.value <= 100.0 }
	}

	requirement def FastRecoveryTime {
		doc /* The SPAD system shall reset within 50 nanoseconds after avalanche quenching
		       to enable high photon count rates. */
		subject system : SPADDiode;
		require constraint { system.deadTime <= 50.0 [SI::ns] }
	}

	requirement def PreciseTiming {
		doc /* The SPAD system shall provide timing resolution better than 100 picoseconds
		       for accurate photon arrival time measurement. */
		subject system : DiscriminatorCircuit;
		require constraint { system.timeResolution <= 100.0 [SI::ps] }
	}

	requirement spadSystemRequirements {
		doc /* Comprehensive requirements for Single-Photon Avalanche Diode system
		       ensuring high-performance single-photon detection capabilities. */
		subject spadSystem;
		require HighDetectionEfficiency;
		require LowDarkCounts;
		require FastRecoveryTime;
		require PreciseTiming;
	}
}
