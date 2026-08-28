package ProportionalCounterSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	private import Quantities::*;
	private import SequenceFunctions::size;

	attribute def EnergyValue :> ScalarQuantityValue;
	attribute def VoltageValue :> ScalarQuantityValue;
	attribute def ChargeValue :> ScalarQuantityValue;
	attribute def CountRateValue :> ScalarQuantityValue;
	attribute def PressureValue :> ScalarQuantityValue;

	part def IonizingParticle {
		attribute energy : EnergyValue;
		attribute type : String;
	}

	part def ElectronIonPair;

	part def AvalancheCharge {
		attribute totalCharge : ChargeValue;
	}

	part def ElectricalPulse {
		attribute amplitude : VoltageValue;
		attribute duration : TimeValue;
	}

	port def ParticleInPort {
		in item particle : IonizingParticle;
	}

	port def SignalOutPort {
		out item pulse : ElectricalPulse;
	}

	port def SignalInPort {
		in item pulse : ElectricalPulse;
	}

	port def PowerOutPort {
		out attribute voltage : VoltageValue;
	}

	port def PowerInPort {
		in attribute voltage : VoltageValue;
	}

	port def ControlOutPort {
		out attribute command : String;
		in attribute status : String;
	}

	port def ControlInPort {
		in attribute command : String;
		out attribute status : String;
	}

	calc def EnergyToCharge {
		in energy : EnergyValue;
		return : ChargeValue = energy * (1e-16 [C/J]);
	}

	action def DetectAction {
		in particle : IonizingParticle;
		in voltage : VoltageValue;
		out pulse : ElectricalPulse;

		private attribute ionizationEnergy : EnergyValue = 4.16e-18 [J];

		action ionize {
			in p : IonizingParticle = particle;
			out pairs : ElectronIonPair[*];
			assert constraint { pairs->size() == p.energy / ionizationEnergy }
		}
		then action accelerate {
			in pairs : ElectronIonPair[*] = ionize.pairs;
			in v : VoltageValue = voltage;
			out acceleratedElectrons : ElectronIonPair[*];
		}
		then action avalanche {
			in electrons : ElectronIonPair[*] = accelerate.acceleratedElectrons;
			out avalancheCharge : AvalancheCharge;
			assert constraint {
				avalancheCharge.totalCharge == EnergyToCharge(particle.energy)
			}
		}
		then action generatePulse {
			in avCharge : AvalancheCharge = avalanche.avalancheCharge;
			out p : ElectricalPulse;
			assert constraint { p.amplitude == avCharge.totalCharge * (1e6 [V/C]) }
		}
	}

	action def ProcessPulseAction {
		in pulse : ElectricalPulse;
		out energy : EnergyValue;
		assert constraint { energy == pulse.amplitude * (1e-10 [J/V]) }
	}

	part def Detector {
		port particleIn : ParticleInPort;
		port signalOut : SignalOutPort;
		port powerIn : PowerInPort;

		attribute gasType : String = "P10 (Argon/Methane)";
		attribute gasPressure : PressureValue;

		part chamber {
			attribute length : LengthValue;
			attribute radius : LengthValue;
			part anodeWire {
				attribute radius : LengthValue;
			}
			part cathodeWall {
				attribute radius : LengthValue;
			}
		}

		action detect : DetectAction {
			in particle = particleIn.particle;
			in voltage = powerIn.voltage;
			out pulse = signalOut.pulse;
		}
	}

	part def HighVoltageSupply {
		port powerOut : PowerOutPort;
		port controlIn : ControlInPort;
		attribute outputVoltage : VoltageValue;
	}

	part def ChargeAmplifier {
		port signalIn : SignalInPort;
		port signalOut : SignalOutPort;
		attribute gain : Real;
	}

	part def PulseShaper {
		port signalIn : SignalInPort;
		port signalOut : SignalOutPort;
		attribute shapingTime : TimeValue;
	}

	part def DataAcquisitionSystem {
		port signalIn : SignalInPort;
		port controlIn : ControlInPort;

		attribute measuredEnergy : EnergyValue;
		attribute totalCount : Integer = 0;
		attribute countRate : CountRateValue;

		action process : ProcessPulseAction {
			in pulse = signalIn.pulse;
			out energy = measuredEnergy;
		}
	}

	part def ControlUnit {
		port hvControl : ControlOutPort;
		port daqControl : ControlOutPort;
		attribute operatingVoltage : VoltageValue = 1000 [V];
	}

	part def ProportionalCounterSystem {
		part detector : Detector;
		part hvSupply : HighVoltageSupply;
		part amplifier : ChargeAmplifier;
		part shaper : PulseShaper;
		part daq : DataAcquisitionSystem;
		part controller : ControlUnit;

		connect detector.powerIn to hvSupply.powerOut;
		connect detector.signalOut to amplifier.signalIn;
		connect amplifier.signalOut to shaper.signalIn;
		connect shaper.signalOut to daq.signalIn;
		connect controller.hvControl to hvSupply.controlIn;
		connect controller.daqControl to daq.controlIn;
	}

	requirement def EnergyMeasurementRequirement {
		subject detector : Detector;
		doc /* The amplitude of the measured pulse shall be directly proportional to the energy of the incident ionizing radiation particle. */
		require constraint {
			detector.detect.pulse.amplitude == detector.detect.particle.energy * (1e-10 [V/J])
		}
	}

	requirement def DetectionEfficiencyRequirement {
		subject system : ProportionalCounterSystem;
		doc /* The system shall count pulses over time to determine the radiation intensity. */
		require constraint {
			system.daq.countRate >= 1000 [1/s]
		}
	}

	attribute def StartSignal;
	attribute def StopSignal;
	attribute def HVOnSignal;
	attribute def HVOffSignal;

	state def SystemOperationStates {
		entry; then off;
		state off;
		transition off_to_standby
			first off
			accept StartSignal
			then standby;
		state standby;
		transition standby_to_active
			first standby
			accept HVOnSignal
			then active;
		state active;
		transition active_to_standby
			first active
			accept HVOffSignal
			then standby;
		transition standby_to_off
			first standby
			accept StopSignal
			then off;
	}
}
