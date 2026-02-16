package 'Infrared Sensing Unit Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	attribute def RadiantFluxValue :> ISQ::PowerValue;
	attribute def DistanceValue :> ISQ::LengthValue;
	attribute def AngleValue :> ISQ::PlaneAngleValue;
	attribute def EmissivityValue :> Real;
	attribute def VoltageValue :> ISQ::VoltageValue;
	attribute def ElectricCurrentValue :> ISQ::ElectricCurrentValue;
	attribute def PowerValue :> ISQ::PowerValue;

	item def InfraredRadiation {
		attribute radiantFlux: RadiantFluxValue;
		attribute wavelength: LengthValue;
		attribute sourceTemperature: TemperatureValue;
	}

	item def TemperatureMeasurement {
		attribute measuredTemperature: TemperatureValue;
		attribute measurementTime: Real;
		attribute measurementValid: Boolean;
		attribute measurementUncertainty: TemperatureValue;
	}

	port def RadiationInputPort {
		in item radiation: InfraredRadiation;
	}

	port def MeasurementOutputPort {
		out item measurement: TemperatureMeasurement;
	}

	port def PowerSupplyPort {
		in attribute voltage: VoltageValue;
		in attribute current: ElectricCurrentValue;
	}

	part def OpticalSystem {
		attribute fieldOfView: AngleValue;
		attribute focusDistance: DistanceValue;
		attribute transmittance: Real;

		port radiationIn: RadiationInputPort;
		port radiationOut {
			out item focusedRadiation: InfraredRadiation;
		}

		action focusRadiation {
			in item incidentRadiation: InfraredRadiation;
			out item focusedRadiation: InfraredRadiation;
		}
	}

	part def InfraredDetectorElement {
		attribute detectorType: String;
		attribute spectralRange: LengthValue;
		attribute responsivity: Real;
		attribute noiseEquivalentPower: RadiantFluxValue;

		port radiationInput {
			in item radiation: InfraredRadiation;
		}

		port signalOutput {
			out electricalSignal: VoltageValue;
		}

		action convertRadiationToSignal {
			in item radiation: InfraredRadiation;
			out signal: VoltageValue;
		}
	}

	part def SignalConditioner {
		attribute amplificationGain: Real;
		attribute filterBandwidth: Real;
		attribute offsetVoltage: VoltageValue;

		port signalIn {
			in rawSignal: VoltageValue;
		}

		port signalOut {
			out conditionedSignal: VoltageValue;
		}

		action conditionSignal {
			in rawSignal: VoltageValue;
			out conditionedSignal: VoltageValue;

			first start;
			then action amplify {
				in signal = rawSignal;
				out amplifiedSignal: VoltageValue;
			}
			then action filterAction {
				in signal = amplify.amplifiedSignal;
				out filteredSignal: VoltageValue;
			}
			then action compensateOffset {
				in signal = filterAction.filteredSignal;
				out compensatedSignal: VoltageValue;
			}
			bind compensateOffset.compensatedSignal = conditionSignal.conditionedSignal;
			then done;
		}
	}

	part def AnalogToDigitalConverter {
		attribute resolution: Real;
		attribute samplingRate: Real;
		attribute conversionTime: Real;

		port analogIn {
			in analogSignal: VoltageValue;
		}

		port digitalOut {
			out digitalValue: Real;
		}

		action convertToDigital {
			in analogSignal: VoltageValue;
			out digitalValue: Real;
		}
	}

	part def TemperatureProcessor {
		attribute emissivitySetting: EmissivityValue;
		attribute ambientTemperature: TemperatureValue;
		attribute calibrationCoefficients: Real[4];

		calc computeTemperature {
			in digitalSignal: Real;
			in emissivity: EmissivityValue;
			in ambient: TemperatureValue;
			return targetTemperature: TemperatureValue;
		}

		action processTemperature {
			in digitalSignal: Real;
			out item measurement: TemperatureMeasurement;
		}
	}

	part def InfraredPointSensor {
		attribute sensorID: String;
		attribute operatingWavelengthRange: LengthValue[2];
		attribute measurementRange: TemperatureValue[2];
		attribute accuracy: TemperatureValue;
		attribute responseTime: Real;

		port radiationInput: RadiationInputPort;
		port measurementOutput: MeasurementOutputPort;
		port power: PowerSupplyPort;

		part optics: OpticalSystem {
			attribute :>> fieldOfView = 1.0[deg];
			attribute :>> focusDistance = 0.5[m];
			attribute :>> transmittance = 0.95;
		}

		part detector: InfraredDetectorElement {
			attribute :>> detectorType = "Thermopile";
			attribute :>> spectralRange = 10.0e-6[m];
			attribute :>> responsivity = 50.0;
			attribute :>> noiseEquivalentPower = 1.0e-9[W];
		}

		part conditioner: SignalConditioner {
			attribute :>> amplificationGain = 100.0;
			attribute :>> filterBandwidth = 10.0;
			attribute :>> offsetVoltage = 0.0[V];
		}

		part adc: AnalogToDigitalConverter {
			attribute :>> resolution = 16.0;
			attribute :>> samplingRate = 10.0;
			attribute :>> conversionTime = 0.1;
		}

		part processor: TemperatureProcessor {
			attribute :>> emissivitySetting = 0.95;
			attribute :>> ambientTemperature = 298.15[K];
		}

		connection opticalPath connect radiationInput to optics.radiationIn;
		connection detectorPath connect optics.radiationOut to detector.radiationInput;
		connection signalPath connect detector.signalOutput to conditioner.signalIn;
		connection digitalPath connect conditioner.signalOut to adc.analogIn;
	}

	part def SensingUnit {
		attribute unitID: String;
		attribute operationalMode: SensorMode;
		attribute measurementInterval: Real;
		attribute powerConsumption: PowerValue;

		part sensor: InfraredPointSensor {
			attribute :>> sensorID = "IR-001";
			attribute :>> measurementRange = (233.15[K], 773.15[K]);
			attribute :>> accuracy = 0.5[K];
			attribute :>> responseTime = 0.5;
		}

		port radiationAperture: RadiationInputPort;
		port temperatureOutput: MeasurementOutputPort;
		port powerInput: PowerSupplyPort;

		connection radiationConnection connect radiationAperture to sensor.radiationInput;
		connection measurementConnection connect sensor.measurementOutput to temperatureOutput;
		connection powerConnection connect powerInput to sensor.power;

		action performMeasurement {
			in item radiation: InfraredRadiation;
			out item measurement: TemperatureMeasurement;

			first start;
			then action captureRadiation {
				in item incidentRadiation = radiation;
				out item capturedRadiation: InfraredRadiation;
			}
			then action detectSignal {
				in item radiation = captureRadiation.capturedRadiation;
				out rawSignal: VoltageValue;
			}
			then action processSignal {
				in signal = detectSignal.rawSignal;
				out digitalValue: Real;
			}
			then action calculateTemperature {
				in value = processSignal.digitalValue;
				out item result: TemperatureMeasurement;
			}
			bind calculateTemperature.result = measurement;
			then done;
		}
	}

	enum def SensorMode {
		standby;
		continuous;
		triggered;
		calibration;
	}

	state def SensorOperationState {
		entry; then idle;

		state idle {
			entry action powerOn;
		}

		transition idle_to_warmup
			first idle
			accept SensorCommand.startOperation
			then warmup;

		state warmup {
			entry action initializeSensor;
			do action stabilizeDetector;
		}

		transition warmup_to_ready
			first warmup
			if sensorStabilized
			then ready;

		state ready;

		transition ready_to_measuring
			first ready
			accept SensorCommand.measure
			then measuring;

		state measuring {
			entry action beginMeasurement;

			state acquiringData {
				do action captureRadiation;
			}

			transition acquiring_to_processing
				first acquiringData
				if dataAcquired
				then processingData;

			state processingData {
				do action computeTemperature;
			}

			transition processing_to_outputting
				first processingData
				then outputtingResult;

			state outputtingResult {
				entry action transmitMeasurement;
			}

			transition outputting_to_acquiring
				first outputtingResult
				if continuousModeActive
				then acquiringData;
		}

		transition measuring_to_ready
			first measuring
			accept SensorCommand.stopMeasurement
			then ready;

		transition ready_to_calibrating
			first ready
			accept SensorCommand.calibrate
			then calibrating;

		state calibrating {
			entry action startCalibration;
			do action performCalibrationSequence;
		}

		transition calibrating_to_ready
			first calibrating
			if calibrationComplete
			then ready;

		transition any_to_fault
			first ready
			accept SensorCommand.errorDetected
			then fault;

		state fault {
			entry action logFault;
			do action diagnostics;
		}

		transition fault_to_idle
			first fault
			accept SensorCommand.reset
			then idle;

		transition ready_to_idle
			first ready
			accept SensorCommand.shutdown
			then idle;
	}

	enum def SensorCommand {
		startOperation;
		measure;
		stopMeasurement;
		calibrate;
		errorDetected;
		reset;
		shutdown;
	}

	action def PowerOn {
		out systemReady: Boolean;
	}

	action def InitializeSensor {
		in sensorConfig: InfraredPointSensor;
		out initialized: Boolean;
	}

	action def StabilizeDetector {
		in targetTemperature: TemperatureValue;
		out stabilized: Boolean;
	}

	action def BeginMeasurement {
		in measurementMode: SensorMode;
		out measurementActive: Boolean;
	}

	action def CaptureRadiation {
		in item radiation: InfraredRadiation;
		out capturedData: Real;
	}

	action def ComputeTemperature {
		in rawData: Real;
		out item measurement: TemperatureMeasurement;
	}

	action def TransmitMeasurement {
		in item measurement: TemperatureMeasurement;
		out transmitted: Boolean;
	}

	action def StartCalibration {
		in calibrationMode: String;
		out calibrationStarted: Boolean;
	}

	action def PerformCalibrationSequence {
		out calibrationData: Real[10];
	}

	action def LogFault {
		in faultCode: String;
		in faultTime: Real;
	}

	action def Diagnostics {
		out diagnosticResults: String;
	}

	requirement def MeasurementRangeRequirement {
		doc /* The sensing unit shall measure temperatures from -40°C to 500°C. */
		subject unit: SensingUnit;
		require constraint {
			unit.sensor.measurementRange[1].num >= 233.15 and
			unit.sensor.measurementRange[2].num <= 773.15
		}
	}

	requirement def AccuracyRequirement {
		doc /* The sensing unit shall provide temperature measurements with accuracy better than ±0.5K. */
		subject unit: SensingUnit;
		require constraint {
			unit.sensor.accuracy.num <= 0.5
		}
	}

	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide measurement results within 1 second. */
		subject unit: SensingUnit;
		require constraint {
			unit.sensor.responseTime <= 1.0
		}
	}

	requirement def FieldOfViewRequirement {
		doc /* The infrared sensor shall have a field of view not exceeding 2 degrees. */
		subject unit: SensingUnit;
		require constraint {
			unit.sensor.optics.fieldOfView.num <= 2.0
		}
	}

	requirement def SpectralRangeRequirement {
		doc /* The sensor shall operate in the long-wave infrared spectrum (8-14 micrometers). */
		subject unit: SensingUnit;
		require constraint {
			unit.sensor.detector.spectralRange.num >= 8.0e-6 and
			unit.sensor.detector.spectralRange.num <= 14.0e-6
		}
	}

	part sensingUnitInstance: SensingUnit {
		attribute :>> unitID = "SENSING-UNIT-IR-001";
		attribute :>> operationalMode = SensorMode::continuous;
		attribute :>> measurementInterval = 1.0;
		attribute :>> powerConsumption = 2.5[W];

		part :>> sensor {
			attribute :>> operatingWavelengthRange = (8.0e-6[m], 14.0e-6[m]);

			part :>> optics {
				attribute :>> fieldOfView = 1.5[deg];
				attribute :>> focusDistance = 1.0[m];
			}

			part :>> detector {
				attribute :>> spectralRange = 10.0e-6[m];
				attribute :>> responsivity = 75.0;
			}

			part :>> processor {
				attribute :>> emissivitySetting = 0.98;
				attribute :>> ambientTemperature = 293.15[K];
			}
		}
	}

	requirement rangeReq: MeasurementRangeRequirement {
		subject unit = sensingUnitInstance;
	}

	requirement accuracyReq: AccuracyRequirement {
		subject unit = sensingUnitInstance;
	}

	requirement responseReq: ResponseTimeRequirement {
		subject unit = sensingUnitInstance;
	}

	requirement fovReq: FieldOfViewRequirement {
		subject unit = sensingUnitInstance;
	}

	requirement spectralReq: SpectralRangeRequirement {
		subject unit = sensingUnitInstance;
	}
}
