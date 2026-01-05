package 'NanoTetherballSensingUnit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def PhysicalStimulus {
		attribute appliedForce: ForceValue;
		attribute timestamp: Real;
	}

	item def SensorReading {
		attribute measuredDisplacement: LengthValue;
		attribute outputVoltage: VoltageValue;
		attribute timestamp: Real;
		attribute isValid: Boolean;
	}

	port def StimulusInputPort {
		in item stimulus: PhysicalStimulus;
	}

	port def SensorOutputPort {
		out item reading: SensorReading;
	}

	port def PowerPort {
		in attribute voltage: VoltageValue;
		in attribute current: ElectricCurrentValue;
	}

	part def NanoTetherballElement {
		attribute tetherLength: LengthValue;
		attribute tetherStiffness: Real;
		attribute nanoparticleMass: MassValue;
		attribute resonantFrequency: FrequencyValue;
		attribute currentDisplacement: LengthValue;
	}

	part def PiezoelectricTransducer {
		attribute sensitivity: Real;
		attribute outputVoltage: VoltageValue;

		action convertDisplacementToVoltage {
			in displacement: LengthValue;
			out voltage: VoltageValue;
		}
	}

	part def SignalConditioner {
		attribute gain: Real;
		attribute filterCutoffFreq: FrequencyValue;

		action amplifyAndFilter {
			in rawVoltage: VoltageValue;
			out conditionedVoltage: VoltageValue;
		}
	}

	part def AnalogToDigitalConverter {
		attribute resolution: Real;
		attribute samplingRate: FrequencyValue;

		action digitize {
			in analogVoltage: VoltageValue;
			out digitalReading: SensorReading;
		}
	}

	part def NanoTetherballSensor {
		attribute sensorID: String;
		attribute calibrationFactor: Real;
		attribute operatingTemperature: TemperatureValue;

		port stimulusPort: StimulusInputPort;
		port outputPort: SensorOutputPort;
		port powerPort: PowerPort;

		part tetherballElement: NanoTetherballElement[1] {
			attribute :>> tetherLength = 500.0[SI::nm];
			attribute :>> tetherStiffness = 0.05;
			attribute :>> nanoparticleMass = 1.0e-15[SI::kg];
			attribute :>> resonantFrequency = 1.0e6[SI::Hz];
			attribute :>> currentDisplacement = 0.0[SI::nm];
		}

		part transducer: PiezoelectricTransducer[1] {
			attribute :>> sensitivity = 2.5;
			attribute :>> outputVoltage = 0.0[SI::V];
		}

		part conditioner: SignalConditioner[1] {
			attribute :>> gain = 100.0;
			attribute :>> filterCutoffFreq = 10.0e3[SI::Hz];
		}

		part adc: AnalogToDigitalConverter[1] {
			attribute :>> resolution = 16.0;
			attribute :>> samplingRate = 100.0e3[SI::Hz];
		}

		connection stimulusToElement connect stimulusPort to tetherballElement;
		connection elementToTransducer connect tetherballElement to transducer;
		connection transducerToConditioner connect transducer to conditioner;
		connection conditionerToADC connect conditioner to adc;
		connection adcToOutput connect adc to outputPort;
	}

	action def SensingProcess {
		in item stimulus: PhysicalStimulus;
		out item reading: SensorReading;

		action receiveStimulus {
			in item inputStimulus: PhysicalStimulus;
			out appliedForce: ForceValue;
		}

		then action mechanicalDeflection {
			in force: ForceValue;
			out displacement: LengthValue;
		}

		flow from receiveStimulus.appliedForce to mechanicalDeflection.force;

		then action transduction {
			in displacementInput: LengthValue;
			out rawVoltage: VoltageValue;
		}

		flow from mechanicalDeflection.displacement to transduction.displacementInput;

		then action signalConditioning {
			in rawVoltageInput: VoltageValue;
			out conditionedVoltage: VoltageValue;
		}

		flow from transduction.rawVoltage to signalConditioning.rawVoltageInput;

		then action digitization {
			in conditionedVoltageInput: VoltageValue;
			out outputReading: SensorReading;
		}

		flow from signalConditioning.conditionedVoltage to digitization.conditionedVoltageInput;

		bind receiveStimulus.inputStimulus = stimulus;
		bind digitization.outputReading = reading;
	}

	state def SensorOperationalStates {
		entry; then idle;

		state idle;

		transition idle_to_active
			first idle
			accept StimulusDetected
			then active;

		state active {
			state measuring;
			then state processing;
			then state outputting;
		}

		transition active_to_idle
			first active
			accept MeasurementComplete
			then idle;

		state fault;

		transition any_to_fault
			accept ErrorDetected
			then fault;

		transition fault_to_idle
			first fault
			accept SystemReset
			then idle;
	}

	part def SensingUnit {
		attribute unitID: String;
		attribute measurementRange: ForceValue;
		attribute accuracy: Real;

		port inputPort: StimulusInputPort;
		port dataPort: SensorOutputPort;
		port power: PowerPort;

		part sensor: NanoTetherballSensor[1] {
			attribute :>> sensorID = "NTS-001";
			attribute :>> calibrationFactor = 1.05;
			attribute :>> operatingTemperature = 298.15[SI::K];
		}

		part controller {
			attribute processingRate: FrequencyValue = 1.0e6[SI::Hz];

			perform sensingProcess: SensingProcess;

			exhibit sensorStates: SensorOperationalStates;
		}

		connect inputPort to sensor.stimulusPort;
		connect sensor.outputPort to dataPort;
		connect power to sensor.powerPort;
	}

	requirement def SensorPerformanceRequirement {
		doc /* The nano-tetherball sensor shall measure force with specified accuracy and range. */

		subject sensor: NanoTetherballSensor;

		require constraint {
			sensor.tetherballElement.resonantFrequency >= 500.0e3[SI::Hz]
		}

		require constraint {
			sensor.adc.resolution >= 12.0
		}

		require constraint {
			sensor.adc.samplingRate >= 50.0e3[SI::Hz]
		}
	}

	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall provide measurement accuracy within 2% of full scale. */

		subject unit: SensingUnit;

		require constraint {
			unit.accuracy <= 0.02
		}
	}

	requirement def OperationalRequirement {
		doc /* The sensor shall operate continuously under specified environmental conditions. */

		subject sensor: NanoTetherballSensor;

		require constraint {
			sensor.operatingTemperature >= 273.15[SI::K] and
			sensor.operatingTemperature <= 323.15[SI::K]
		}
	}

	part sensingUnitInstance: SensingUnit {
		attribute :>> unitID = "SU-NTS-100";
		attribute :>> measurementRange = 1.0e-9[SI::N];
		attribute :>> accuracy = 0.015;

		satisfy performanceReq: SensorPerformanceRequirement {
			subject testSensor = sensor;
		}

		satisfy accuracyReq: MeasurementAccuracyRequirement {
			subject testUnit = sensingUnitInstance;
		}

		satisfy operationalReq: OperationalRequirement {
			subject testSensor = sensor;
		}
	}

	action def CalibrateNanoTetherballSensor {
		in sensor: NanoTetherballSensor;
		in referenceForce: ForceValue;
		out calibrationFactor: Real;

		action applyReferenceStimulus {
			in refForce: ForceValue;
			out appliedStimulus: PhysicalStimulus;
		}

		then action measureResponse {
			in stimulus: PhysicalStimulus;
			out measuredReading: SensorReading;
		}

		flow from applyReferenceStimulus.appliedStimulus to measureResponse.stimulus;

		then action calculateCalibration {
			in expectedForce: ForceValue;
			in actualReading: SensorReading;
			out calFactor: Real;
		}

		flow from measureResponse.measuredReading to calculateCalibration.actualReading;
		bind applyReferenceStimulus.refForce = referenceForce;
		bind calculateCalibration.expectedForce = referenceForce;
		bind calculateCalibration.calFactor = calibrationFactor;
	}

	verification def VerifySensorAccuracy {
		subject testSensor: NanoTetherballSensor;

		in testForce: ForceValue = 5.0e-10[SI::N];

		objective accuracyObjective {
			doc /* Verify that sensor measurement error is within acceptable tolerance. */
		}

		return verdict: Boolean;
	}

	part testConfiguration {
		part testUnit: SensingUnit :> sensingUnitInstance;

		perform calibration: CalibrateNanoTetherballSensor {
			in :>> sensor = testUnit.sensor;
			in :>> referenceForce = 1.0e-9[SI::N];
		}

		then perform verification: VerifySensorAccuracy {
			subject :>> testSensor = testUnit.sensor;
		}
	}
}
