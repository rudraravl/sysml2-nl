package TransitionEdgeSensingUnit {
	private import ISQ::TemperatureValue;
	private import ISQ::EnergyValue;
	private import ISQ::DurationValue;
	private import ISQ::ElectricVoltageValue;
	private import ISQ::ElectricCurrentValue;
	private import ISQ::ElectricResistanceValue;
	private import Time::TimeInstantValue;
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import SI::K;
	private import SI::J;
	private import SI::A;
	private import SI::s;

	attribute def PhotonSignal {
		attribute energy : EnergyValue;
	}

	attribute def VoltagePulseSignal {
		attribute amplitude : ElectricVoltageValue;
		attribute duration : DurationValue;
	}

	attribute def AmplifiedPulseSignal {
		attribute amplitude : ElectricVoltageValue;
		attribute duration : DurationValue;
	}

	attribute def PhotonEnergyResult {
		attribute photonEnergy : EnergyValue;
		attribute measurementTime : TimeInstantValue;
	}

	attribute def CalibrationCompleteSignal;

	item def CalibrationData {
		attribute pulseAreaToEnergyFactor : Real = 1.0e-19;
		attribute energyOffset : EnergyValue = 0.0 [J];
	}

	port def ThermalSourcePort {
		out temp : TemperatureValue;
	}

	port def ThermalSinkPort {
		in temp : TemperatureValue;
	}

	port def CurrentSourcePort {
		out current : ElectricCurrentValue;
	}

	port def CurrentSinkPort {
		in current : ElectricCurrentValue;
	}

	port def VoltagePulseOutPort {
		out pulse : VoltagePulseSignal;
	}

	port def VoltagePulseInPort {
		in pulse : VoltagePulseSignal;
	}

	port def AmplifiedPulseOutPort {
		out pulse : AmplifiedPulseSignal;
	}

	port def AmplifiedPulseInPort {
		in pulse : AmplifiedPulseSignal;
	}

	port def PhotonInputPort {
		in photon : PhotonSignal;
	}

	port def EnergyOutputPort {
		out result : PhotonEnergyResult;
	}

	action def MaintainCooling {
		in targetTemperature : TemperatureValue;
		out temp : TemperatureValue;
	}

	action def ProvideBiasCurrent {
		out current : ElectricCurrentValue;
	}

	action def PerformCalibration {
		in calibration : CalibrationData;
	}

	action def AbsorbPhoton {
		in photon : PhotonSignal;
		inout sensorTemperature : TemperatureValue;
		out newResistance : ElectricResistanceValue;
	}

	action def ThermalizeEnergy {
		inout sensorTemperature : TemperatureValue;
	}

	action def CoolDown {
		inout sensorTemperature : TemperatureValue;
		in targetTemperature : TemperatureValue;
	}

	action def GenerateVoltagePulse {
		in current : ElectricCurrentValue;
		in resistance : ElectricResistanceValue;
		out pulse : VoltagePulseSignal;
	}

	action def AmplifyVoltage {
		in pulseIn : VoltagePulseSignal;
		out pulseOut : AmplifiedPulseSignal;
	}

	action def CalculatePhotonEnergy {
		in pulse : AmplifiedPulseSignal;
		in calibration : CalibrationData;
		out result : PhotonEnergyResult;
	}

	part def Cryostat {
		attribute operatingTemperature : TemperatureValue = 0.1 [K];
		attribute currentTemperature : TemperatureValue = 0.1 [K];
		port coolingPort : ThermalSourcePort;

		state cryostatStates {
			entry; then cooling;
			state cooling {
				do action MaintainCooling {
					in targetTemperature = operatingTemperature;
					out temp = coolingPort.temp;
				}
			}
		}
	}

	part def BiasCircuit {
		attribute biasCurrent : ElectricCurrentValue = 1.0e-6 [A];
		port biasOut : CurrentSourcePort;

		state biasStates {
			entry; then biasing;
			state biasing {
				do action ProvideBiasCurrent {
					out current = biasOut.current;
				}
			}
		}
	}

	part def TES {
		attribute criticalTemperature : TemperatureValue = 0.1 [K];
		attribute currentTemperature : TemperatureValue = 0.1 [K];
		attribute resistance : ElectricResistanceValue = 0.0;
		attribute isSuperconducting : Boolean = true;

		port photonIn : PhotonInputPort;
		port thermalIn : ThermalSinkPort;
		port biasIn : CurrentSinkPort;
		port signalOut : VoltagePulseOutPort;

		state detectionStates {
			entry; then calibrating;

			state calibrating {
				entry assign resistance := 0.0;
				entry assign isSuperconducting := true;
				entry assign currentTemperature := criticalTemperature;
			}

			transition calibrating_to_ready
				first calibrating
				accept after 0.5 [s]
				then ready;

			state ready;

			transition ready_to_absorbing
				first ready
				accept photon : PhotonSignal via photonIn
				do action AbsorbPhoton {
					in photon = photon;
					inout sensorTemperature = currentTemperature;
					out newResistance = resistance;
				}
				then absorbing;

			state absorbing {
				entry assign isSuperconducting := false;
				do action GenerateVoltagePulse {
					in current = biasIn.current;
					in resistance = resistance;
					out pulse = signalOut.pulse;
				}
			}

			transition absorbing_to_recovering
				first absorbing
				accept after 0.001 [s]
				do action ThermalizeEnergy {
					inout sensorTemperature = currentTemperature;
				}
				then recovering;

			state recovering {
				entry assign isSuperconducting := true;
				do action CoolDown {
					inout sensorTemperature = currentTemperature;
					in targetTemperature = criticalTemperature;
				}
			}

			transition recovering_to_ready
				first recovering
				accept when currentTemperature <= criticalTemperature
				then ready;
		}
	}

	part def SQUIDAmplifier {
		attribute gain : Real = 1000.0;
		port signalIn : VoltagePulseInPort;
		port signalOut : AmplifiedPulseOutPort;

		state squidStates {
			entry; then amplifying;
			state amplifying {
				do action AmplifyVoltage {
					in pulseIn = signalIn.pulse;
					out pulseOut = signalOut.pulse;
				}
			}
		}
	}

	part def SignalProcessor {
		attribute calibration : CalibrationData;
		port signalIn : AmplifiedPulseInPort;
		port resultOut : EnergyOutputPort;

		state processorStates {
			entry; then calibrating;

			state calibrating {
				entry action PerformCalibration {
					in calibration = calibration;
				}
			}

			transition calibrating_to_ready
				first calibrating
				accept after 0.5 [s]
				then ready;

			state ready;

			transition ready_to_processing
				first ready
				accept pulse : AmplifiedPulseSignal via signalIn
				then processing;

			state processing {
				do action CalculatePhotonEnergy {
					in pulse = signalIn.pulse;
					in calibration = calibration;
					out result = resultOut.result;
				}
			}

			transition processing_to_ready
				first processing
				accept after 0.01 [s]
				then ready;
		}
	}

	part def TransitionEdgeSensingSystem {
		port photonInput : PhotonInputPort;
		port energyOutput : EnergyOutputPort;

		part cryostat : Cryostat;
		part tes : TES;
		part biasCircuit : BiasCircuit;
		part squidAmplifier : SQUIDAmplifier;
		part signalProcessor : SignalProcessor;

		connect photonInput to tes.photonIn;
		connect cryostat.coolingPort to tes.thermalIn;
		connect biasCircuit.biasOut to tes.biasIn;
		connect tes.signalOut to squidAmplifier.signalIn;
		connect squidAmplifier.signalOut to signalProcessor.signalIn;
		connect signalProcessor.resultOut to energyOutput;
	}

	requirement def OperatingTemperatureRequirement {
		/* The TES shall be maintained at an operating temperature of approximately 0.1 K. */
		attribute targetTemperature : TemperatureValue = 0.1 [K];
	}

	requirement def SinglePhotonDetectionRequirement {
		/* The system shall detect individual photons and output their energy with high precision. */
	}

	requirement def EnergyAccuracyRequirement {
		/* The measured photon energy shall be accurate to within 1 percent of the actual photon energy. */
		attribute relativeAccuracy : Real = 0.01;
	}

	requirement def RecoveryTimeRequirement {
		/* The sensor shall return to the ready state within the specified recovery time after photon absorption. */
		attribute maxRecoveryTime : DurationValue = 0.1 [s];
	}

	requirement def SuperconductingStateRequirement {
		/* The TES shall be in a superconducting state with zero resistance when in the ready state. */
	}

	requirement operatingTempReq : OperatingTemperatureRequirement {
		subject cryostat : Cryostat;
	}

	requirement singlePhotonReq : SinglePhotonDetectionRequirement {
		subject tesSystem : TransitionEdgeSensingSystem;
	}

	requirement energyAccuracyReq : EnergyAccuracyRequirement {
		subject tesSystem : TransitionEdgeSensingSystem;
	}

	requirement recoveryTimeReq : RecoveryTimeRequirement {
		subject tes : TES;
	}

	requirement superconductingReq : SuperconductingStateRequirement {
		subject tes : TES;
	}
}
