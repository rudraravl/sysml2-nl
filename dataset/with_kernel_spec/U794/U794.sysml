package OpticalFiberCommunicationSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;

	attribute def StartTransmission;
	attribute def StopTransmission;

	item def ElectricalSignal {
		attribute dataRate : FrequencyValue;
	}

	item def LightSignal {
		attribute wavelength : LengthValue;
		attribute power : PowerValue;
	}

	part def OpticalTransmitter {
		in port electricalIn : ElectricalSignal;
		out port opticalOut : LightSignal;

		part laserDiode {
			attribute wavelength : LengthValue = 1550 [nm];
			out item lightBeam : LightSignal;
		}
		part opticalModulator {
			in item data : ElectricalSignal;
			in item light : LightSignal;
			out item modulatedLight : LightSignal;
		}

		flow electricalIn to opticalModulator.data;
		flow laserDiode.lightBeam to opticalModulator.light;
		flow opticalModulator.modulatedLight to opticalOut;
	}

	part def OpticalFiber {
		in port fiberIn : LightSignal;
		out port fiberOut : LightSignal;

		attribute length : LengthValue = 20 [km];

		part core {
			attribute refractiveIndex : Real;
		}
		part cladding {
			attribute refractiveIndex : Real;
		}

		flow fiberIn to fiberOut;
	}

	part def OpticalReceiver {
		in port opticalIn : LightSignal;
		out port electricalOut : ElectricalSignal;

		part photodetector {
			in item light : LightSignal;
			out item current : ElectricalSignal;
		}
		part signalAmplifier {
			in item weakSignal : ElectricalSignal;
			out item amplifiedSignal : ElectricalSignal;
		}

		flow opticalIn to photodetector.light;
		flow photodetector.current to signalAmplifier.weakSignal;
		flow signalAmplifier.amplifiedSignal to electricalOut;
	}

	part def OpticalFiberSystem {
		in port systemIn : ElectricalSignal;
		out port systemOut : ElectricalSignal;

		attribute dataRate : FrequencyValue;
		attribute bitErrorRate : Real;
		attribute operatesInHarshEnvironment : Boolean;
		attribute signalQuality : Real;
		attribute threshold : Real;

		part transmitter : OpticalTransmitter;
		part fiber : OpticalFiber;
		part receiver : OpticalReceiver;

		flow systemIn to transmitter.electricalIn;
		flow transmitter.opticalOut to fiber.fiberIn;
		flow fiber.fiberOut to receiver.opticalIn;
		flow receiver.electricalOut to systemOut;

		exhibit state systemStates {
			entry; then idle;
			state idle;
			accept StartTransmission then active;
			state active parallel {
				state transmission;
				state monitoring {
					entry; then normal;
					state normal;
					accept when signalQuality < threshold
						then degraded;
					state degraded;
					accept when signalQuality >= threshold
						then normal;
				}
			}
			accept StopTransmission then idle;
		}
	}

	requirement def PerformanceRequirement {
		attribute minDataRate : FrequencyValue = 10 [GHz];
		subject system : OpticalFiberSystem;
		assert constraint { system.dataRate >= minDataRate }
	}

	requirement def SignalIntegrityRequirement {
		attribute maxBitErrorRate : Real = 1e-12;
		subject system : OpticalFiberSystem;
		assert constraint { system.bitErrorRate < maxBitErrorRate }
	}

	requirement def ReliabilityRequirement {
		subject system : OpticalFiberSystem;
		assert constraint { system.operatesInHarshEnvironment == true }
	}

	requirement SystemRequirements {
		subject system : OpticalFiberSystem;
		requirement performance : PerformanceRequirement;
		requirement integrity : SignalIntegrityRequirement;
		requirement reliability : ReliabilityRequirement;
	}

	part opticalFiberSystem : OpticalFiberSystem {
		satisfy SystemRequirements;
	}
}
