package 'Thermopile Laser Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;

	comment about ThermopileLaserSensingUnit
	/* This model describes a sensing unit that uses a thermopile laser sensor
	 * to measure optical power from a laser source. The thermopile converts
	 * incident laser radiation into a measurable voltage through thermoelectric
	 * effect, which is then processed to determine the optical power. */

	attribute def VoltageUnit :> MeasurementUnit;
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}

	item def LaserRadiation {
		attribute wavelength : LengthValue;
		attribute power : PowerValue;
		attribute beamDiameter : LengthValue;
	}

	item def ThermoelectricSignal {
		attribute voltage : VoltageValue;
		attribute temperature : TemperatureValue;
	}

	item def PowerMeasurement {
		attribute measuredPower : PowerValue;
		attribute timestamp : Real;
		attribute uncertainty : Real;
	}

	port def OpticalInputPort {
		in item radiation : LaserRadiation;
	}

	port def SignalOutputPort {
		out item signal : ThermoelectricSignal;
	}

	port def DataOutputPort {
		out item measurement : PowerMeasurement;
	}

	port def PowerSupplyPort {
		in item voltage : VoltageValue;
	}

	part def ThermopileSensor {
		attribute numberOfJunctions : Integer;
		attribute responsivity : Real;
		attribute absorptionCoefficient : Real;
		attribute thermalTimeConstant : TimeValue;

		port opticalPort : OpticalInputPort;
		port signalPort : SignalOutputPort;

		action def ConvertRadiationToVoltage {
			in item radiation : LaserRadiation;
			out item signal : ThermoelectricSignal;
		}
	}

	part def SignalAmplifier {
		attribute gain : Real;
		attribute bandwidth : Real;
		attribute inputImpedance : Real;

		port inputPort : SignalOutputPort;
		port outputPort : SignalOutputPort;

		action def AmplifySignal {
			in item inputSignal : ThermoelectricSignal;
			out item amplifiedSignal : ThermoelectricSignal;
		}
	}

	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : Real;
		attribute referenceVoltage : VoltageValue;

		port analogInput : SignalOutputPort;

		action def Digitize {
			in item analogSignal : ThermoelectricSignal;
			out digitalValue : Real;
		}
	}

	part def SignalProcessor {
		attribute calibrationFactor : Real;
		attribute offsetCorrection : Real;

		port dataOutput : DataOutputPort;

		action def CalculatePower {
			in digitalValue : Real;
			in calibration : Real;
			out item measurement : PowerMeasurement;

			action applyCalibration {
				in rawValue : Real;
				in factor : Real;
				out calibratedValue : Real;
			}
			then applyOffset;

			action applyOffset {
				in calibratedValue : Real;
				in offset : Real;
				out correctedValue : Real;
			}
			then generateMeasurement;

			action generateMeasurement {
				in finalValue : Real;
				out item result : PowerMeasurement;
			}
		}
	}

	part def ThermopileLaserSensingUnit {
		attribute operatingRange : PowerValue[2];
		attribute measurementAccuracy : Real;
		attribute responseTime : TimeValue;

		port opticalInput : OpticalInputPort;
		port measurementOutput : DataOutputPort;
		port powerSupply : PowerSupplyPort;

		part thermopile : ThermopileSensor[1] {
			attribute :>> numberOfJunctions = 100;
			attribute :>> responsivity = 45.0;
			attribute :>> absorptionCoefficient = 0.95;
			attribute :>> thermalTimeConstant = 0.5[s];
		}

		part amplifier : SignalAmplifier[1] {
			attribute :>> gain = 100.0;
			attribute :>> bandwidth = 1000.0;
			attribute :>> inputImpedance = 1.0e6;
		}

		part adc : AnalogToDigitalConverter[1] {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1000.0;
			attribute :>> referenceVoltage = 5.0[V];
		}

		part processor : SignalProcessor[1] {
			attribute :>> calibrationFactor = 0.022;
			attribute :>> offsetCorrection = 0.001;
		}

		connection opticalToThermopile
			connect opticalInput to thermopile.opticalPort;

		connection thermopileToAmplifier
			connect thermopile.signalPort to amplifier.inputPort;

		connection amplifierToADC
			connect amplifier.outputPort to adc.analogInput;

		connection processorToOutput
			connect processor.dataOutput to measurementOutput;
	}

	action def MeasurementSequence {
		in item incomingRadiation : LaserRadiation;
		out item finalMeasurement : PowerMeasurement;

		action detectRadiation : ThermopileSensor::ConvertRadiationToVoltage {
			in item radiation;
			out item rawSignal;
		}
		then amplifySignal;

		action amplifySignal : SignalAmplifier::AmplifySignal {
			in item inputSignal;
			out item amplifiedSignal;
		}
		then digitizeSignal;

		action digitizeSignal : AnalogToDigitalConverter::Digitize {
			in item analogSignal;
			out digitalValue;
		}
		then processMeasurement;

		action processMeasurement : SignalProcessor::CalculatePower {
			in digitalValue;
			in calibration;
			out item measurement;
		}

		flow from detectRadiation.rawSignal to amplifySignal.inputSignal;
		flow from amplifySignal.amplifiedSignal to digitizeSignal.analogSignal;
		flow from digitizeSignal.digitalValue to processMeasurement.digitalValue;
		bind detectRadiation.radiation = incomingRadiation;
		bind processMeasurement.measurement = finalMeasurement;
	}

	state def SensorOperationalStates {
		entry; then idle;

		state idle;

		transition idleToWarmup
			first idle
			accept at Time::Clocks::epoch_s
			then warmup;

		state warmup;

		transition warmupToReady
			first warmup
			accept at Time::Clocks::epoch_s
			then ready;

		state ready;

		transition readyToMeasuring
			first ready
			accept at Time::Clocks::epoch_s
			then measuring;

		state measuring;

		transition measuringToReady
			first measuring
			accept at Time::Clocks::epoch_s
			then ready;

		transition readyToIdle
			first ready
			accept at Time::Clocks::epoch_s
			then idle;

		transition errorTransition
			first measuring
			accept at Time::Clocks::epoch_s
			then error;

		state error;

		transition errorToIdle
			first error
			accept at Time::Clocks::epoch_s
			then idle;
	}

	requirement def PowerMeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure optical power with an accuracy
		     * of ±3% over the range of 1mW to 10W. */

		subject unit : ThermopileLaserSensingUnit;

		require constraint {
			unit.measurementAccuracy <= 0.03
		}
	}

	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide a stable measurement within
		     * 1 second of radiation exposure. */

		subject unit : ThermopileLaserSensingUnit;

		require constraint {
			unit.responseTime <= 1.0[s]
		}
	}

	requirement def OperatingRangeRequirement {
		doc /* The sensing unit shall measure optical power from 0.001W to 10W. */

		subject unit : ThermopileLaserSensingUnit;
	}

	requirement def WavelengthRangeRequirement {
		doc /* The thermopile sensor shall respond to laser wavelengths
		     * from 400nm to 1100nm. */

		subject sensor : ThermopileSensor;
	}

	part sensingUnitInstance : ThermopileLaserSensingUnit {
		attribute :>> operatingRange = (0.001[W], 10.0[W]);
		attribute :>> measurementAccuracy = 0.025;
		attribute :>> responseTime = 0.8[s];

		perform action operation : MeasurementSequence;
		exhibit state behavior : SensorOperationalStates;
	}

	satisfy PowerMeasurementAccuracyRequirement by sensingUnitInstance;
	satisfy ResponseTimeRequirement by sensingUnitInstance;
	satisfy OperatingRangeRequirement by sensingUnitInstance;
	satisfy WavelengthRangeRequirement by sensingUnitInstance.thermopile;
}
