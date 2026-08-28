package MicrowaveRadiometerSystem {
	private import ISQ::power;
	private import ISQ::frequency;
	private import ISQ::electricPotential;
	private import ISQ::thermodynamicTemperature;
	private import ISQ::time;
	private import SI::*;

	item def MicrowaveRadiation {
		attribute power :> power;
	}

	item def MicrowaveSignal {
		attribute power :> power;
		attribute frequency :> frequency;
	}

	item def DCVoltage {
		attribute voltage :> electricPotential;
	}

	item def IntegratedVoltage {
		attribute voltage :> electricPotential;
	}

	item def BrightnessTemperatureData {
		attribute brightnessTemp :> thermodynamicTemperature;
	}

	item def CalibrationData {
		attribute hotLoadTemp :> thermodynamicTemperature;
		attribute coldLoadTemp :> thermodynamicTemperature;
	}

	part def AntennaSubsystem {
		in ref item sceneRadiation : MicrowaveRadiation;
		out item microwaveSignal : MicrowaveSignal;
	}

	part def ReceiverSubsystem {
		in item microwaveSignal : MicrowaveSignal;
		out item amplifiedSignal : MicrowaveSignal;
	}

	part def DetectorSubsystem {
		in item amplifiedSignal : MicrowaveSignal;
		out item dcVoltage : DCVoltage;
	}

	part def IntegratorSubsystem {
		in item dcVoltage : DCVoltage;
		out item integratedVoltage : IntegratedVoltage;
		attribute integrationTime :> time = 1.0 [s];
	}

	part def ProcessorSubsystem {
		in item integratedVoltage : IntegratedVoltage;
		in ref item calibrationData : CalibrationData;
		out item temperatureData : BrightnessTemperatureData;
	}

	part def CalibrationSubsystem {
		part hotLoad {
			attribute temp :> thermodynamicTemperature = 300.0 [K];
		}
		part coldLoad {
			attribute temp :> thermodynamicTemperature = 2.7 [K];
		}
		out ref item calibrationData : CalibrationData;
	}

	attribute def PowerOnSignal;
	attribute def CalibrationCompleteSignal;
	attribute def PeriodicCalibrationSignal;

	state def OperationalStates {
		entry; then off;
		state off;
		accept PowerOnSignal then calibrating;
		state calibrating;
		accept CalibrationCompleteSignal then measuring;
		state measuring;
		accept PeriodicCalibrationSignal then calibrating;
	}

	part def MicrowaveRadiometer;

	part radiometer : MicrowaveRadiometer {
		ref item targetScene : MicrowaveRadiation;

		part antenna : AntennaSubsystem {
			in ref item :>> sceneRadiation = radiometer::targetScene;
		}
		part receiver : ReceiverSubsystem;
		part detector : DetectorSubsystem;
		part integrator : IntegratorSubsystem;
		part processor : ProcessorSubsystem;
		part calibration : CalibrationSubsystem;

		flow antenna.microwaveSignal to receiver.microwaveSignal;
		flow receiver.amplifiedSignal to detector.amplifiedSignal;
		flow detector.dcVoltage to integrator.dcVoltage;
		flow integrator.integratedVoltage to processor.integratedVoltage;
		flow calibration.calibrationData to processor.calibrationData;

		state operationalStates : OperationalStates;
	}

	requirement def BrightnessTemperatureRequirement {
		subject targetScene : MicrowaveRadiation;
		attribute measuredBrightnessTemp :> thermodynamicTemperature;
		attribute actualBrightnessTemp :> thermodynamicTemperature;
		doc /* The system shall measure the brightness temperature of the target scene. */
		require constraint { 
			measuredBrightnessTemp == actualBrightnessTemp 
		}
	}
}
