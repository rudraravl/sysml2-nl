package ScintillatorDetectionSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def RadiationParticle {
		attribute energy : EnergyValue;
	}

	item def LightFlash {
		attribute intensity : Real;
	}

	item def ElectricalPulse {
		attribute amplitude : ElectricPotentialValue;
	}

	item def EventData {
		attribute energy : EnergyValue;
		attribute timestamp : TimeValue;
	}

	action def 'Absorb Radiation' {
		in particle : RadiationParticle;
		out flash : LightFlash;
	}

	action def 'Multiply Signal' {
		in flash : LightFlash;
		out pulse : ElectricalPulse;
	}

	action def 'Analyze Signal' {
		in pulse : ElectricalPulse;
		out data : EventData;
	}

	action def 'Process Event' {
		in particle : RadiationParticle;
		out data : EventData;

		action 'absorb radiation': 'Absorb Radiation' {
			in particle = 'Process Event'::particle;
		}
		action 'multiply signal': 'Multiply Signal';
		action 'analyze signal': 'Analyze Signal';

		flow 'absorb radiation'.flash to 'multiply signal'.flash;
		flow 'multiply signal'.pulse to 'analyze signal'.pulse;
		flow 'analyze signal'.data to data;

		first start;
		then 'absorb radiation';
		then 'multiply signal';
		then 'analyze signal';
		then done;
	}

	part def ScintillatorCrystal {
		attribute material : String = "Sodium Iodide";
		in item particle : RadiationParticle;
		out item flash : LightFlash;
		perform action 'absorb radiation': 'Absorb Radiation' {
			in particle = ScintillatorCrystal::particle;
		}
		flow 'absorb radiation'.flash to ScintillatorCrystal::flash;
	}

	part def PhotomultiplierTube {
		in item flash : LightFlash;
		out item pulse : ElectricalPulse;
		perform action 'multiply signal': 'Multiply Signal' {
			in flash = PhotomultiplierTube::flash;
		}
		flow 'multiply signal'.pulse to PhotomultiplierTube::pulse;
	}

	part def SignalAnalyzer {
		in item pulse : ElectricalPulse;
		out item data : EventData;
		perform action 'analyze signal': 'Analyze Signal' {
			in pulse = SignalAnalyzer::pulse;
		}
		flow 'analyze signal'.data to SignalAnalyzer::data;
	}

	part def ScintillationDetector {
		in item particle : RadiationParticle;
		out item data : EventData;

		part crystal : ScintillatorCrystal {
			in item particle = ScintillationDetector::particle;
		}
		part pmt : PhotomultiplierTube;
		part analyzer : SignalAnalyzer;

		flow crystal.flash to pmt.flash;
		flow pmt.pulse to analyzer.pulse;
		flow analyzer.data to ScintillationDetector::data;

		state detectionBehavior {
			entry; then ready;
			state ready;
			transition ready_to_active
				first ready
				accept particle : RadiationParticle
				then active;
			state active {
				perform action 'process event': 'Process Event' {
					in particle = ScintillationDetector::particle;
				}
				flow 'process event'.data to ScintillationDetector::data;
			}
			transition active_to_ready
				first active
				accept data : EventData
				then ready;
		}
	}

	requirement EnergyMeasurementRequirement {
		doc /* The system shall measure the energy of detected radiation particles. */
		subject detector : ScintillationDetector;
		constraint { detector.data.energy == detector.particle.energy }
	}

	part detector : ScintillationDetector {
		satisfy EnergyMeasurementRequirement;
	}
}
