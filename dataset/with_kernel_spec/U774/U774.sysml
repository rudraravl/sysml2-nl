package 'Microwave Chemistry Sensing System' {
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		public import ScalarValues::*;
		public import ISQ::*;
		public import SI::*;

		alias Temperature for ISQ::TemperatureValue;
		alias Frequency for ISQ::FrequencyValue;

		attribute def PermittivityValue :> Real;
		attribute def ConductivityValue :> Real;
		attribute def ConcentrationValue :> Real;
		attribute def UncertaintyValue :> Real;
		attribute def ValidityFlag :> Boolean;

		attribute def MeasurementCmd;
		attribute def PowerOn;
		attribute def PowerOff;
		attribute def CalibrationModel;

		item def ChemicalSample {
			attribute temperature: Temperature;
		}

		item def MicrowaveSignal {
			attribute frequency: Frequency;
			attribute power: Real;
		}

		item def ReflectedSignal :> MicrowaveSignal;
		item def TransmittedSignal :> MicrowaveSignal;

		item def DetectorData {
			attribute amplitude: Real;
			attribute phaseShift: Real;
			attribute frequencyShift: Frequency;
		}

		item def AnalyzedProperties {
			attribute permittivity: PermittivityValue;
			attribute conductivity: ConductivityValue;
		}

		item def ConcentrationResult {
			attribute concentration: ConcentrationValue;
			attribute uncertainty: UncertaintyValue;
			attribute validity: ValidityFlag;
		}

		action def 'Initialize & Calibrate' {
			out status: Boolean;
		}

		action def 'Stabilize Temperature' {
			in targetTemp: Temperature;
			out sampleTemp: Temperature;
		}

		action def 'Generate Microwave' {
			out signal: MicrowaveSignal;
		}

		action def 'Detect Signal' {
			in signal: MicrowaveSignal;
			out data: DetectorData;
		}

		action def 'Analyze Signal' {
			in reflectedData: DetectorData;
			in transmittedData: DetectorData;
			out properties: AnalyzedProperties;
		}

		action def 'Calculate Concentration' {
			in properties: AnalyzedProperties;
			in sampleTemp: Temperature;
			in model: CalibrationModel;
			out result: ConcentrationResult;
		}

		action def 'Acquire Data' {
			out reflectedData: DetectorData;
			out transmittedData: DetectorData;
		}

		action def 'Process Data' {
			in reflectedData: DetectorData;
			in transmittedData: DetectorData;
			in sampleTemp: Temperature;
			in model: CalibrationModel;
			out result: ConcentrationResult;
		}

		action def 'Perform Measurement' {
			in measurementCmd: MeasurementCmd;
			in targetTemp: Temperature;
			in model: CalibrationModel;
			out result: ConcentrationResult;
		}

		part def TemperatureController {
			out sampleTemp: Temperature;
			perform action 'stabilize temperature': 'Stabilize Temperature';
		}

		part def MicrowaveSource {
			out signal: MicrowaveSignal;
			perform action 'generate microwave': 'Generate Microwave';
		}

		part def ResonantCavity {
			in item inputSignal: MicrowaveSignal;
			out item reflectedSignal: ReflectedSignal;
			out item transmittedSignal: TransmittedSignal;
			in item sample: ChemicalSample;
			in sampleTemp: Temperature;
		}

		part def MicrowaveDetector {
			in item signal: MicrowaveSignal;
			out data: DetectorData;
			perform action 'detect signal': 'Detect Signal';
		}

		part def SignalAnalyzer {
			in reflectedData: DetectorData;
			in transmittedData: DetectorData;
			out properties: AnalyzedProperties;
			perform action 'analyze signal': 'Analyze Signal';
		}

		part def ConcentrationCalculator {
			in properties: AnalyzedProperties;
			in sampleTemp: Temperature;
			out result: ConcentrationResult;
			perform action 'calculate concentration': 'Calculate Concentration';
		}

		part def MicrowaveSensingSystem {
			exhibit state 'system states': 'System States';
			perform action 'perform measurement': 'Perform Measurement';
		}

		state def 'System States';

		requirement 'Measurement Accuracy Requirement' {
			doc /* The system shall measure chemical concentration with an uncertainty less than 5%. */
			attribute maxUncertainty: UncertaintyValue = 5.0;
		}

		requirement 'Temperature Stability Requirement' {
			doc /* The temperature controller shall stabilize the sample to within 0.1 K of the target before measurement. */
			attribute tolerance: Temperature = 0.1 [K];
		}

		requirement 'Signal Quality Requirement' {
			doc /* The microwave source shall generate a stable signal at 2.45 GHz with power greater than 1 mW. */
			attribute minPower: Real = 0.001;
			attribute targetFreq: Frequency = 2450000000 [Hz];
		}
	}

	package Usages {
		private import Definitions::*;

		part 'sensing system': MicrowaveSensingSystem {
			part temperatureController: TemperatureController;
			part microwaveSource: MicrowaveSource;
			part resonantCavity: ResonantCavity;
			part reflectedDetector: MicrowaveDetector;
			part transmittedDetector: MicrowaveDetector;
			part signalAnalyzer: SignalAnalyzer;
			part concentrationCalculator: ConcentrationCalculator;

			flow temperatureController.sampleTemp to concentrationCalculator.sampleTemp;
			flow temperatureController.sampleTemp to resonantCavity.sampleTemp;
			flow microwaveSource.signal to resonantCavity.inputSignal;
			flow resonantCavity.reflectedSignal to reflectedDetector.signal;
			flow resonantCavity.transmittedSignal to transmittedDetector.signal;
			flow reflectedDetector.data to signalAnalyzer.reflectedData;
			flow transmittedDetector.data to signalAnalyzer.transmittedData;
			flow signalAnalyzer.properties to concentrationCalculator.properties;

			state 'system states': 'System States' {
				entry action initial;
				transition initial then 'power off';

				state 'power off';
				transition 'power on'
					first 'power off'
					accept PowerOn
					then 'initializing';

				state 'initializing' {
					do action 'initialize & calibrate': 'Initialize & Calibrate';
				}
				transition 'init complete'
					first 'initializing'
					then 'ready';

				state 'ready';
				transition 'measure cmd'
					first 'ready'
					accept measurementCmd : MeasurementCmd
					then 'stabilizing temperature';

				state 'stabilizing temperature' {
					do action 'stabilize temp': 'Stabilize Temperature' {
						in targetTemp = 298.15 [K];
					}
				}
				transition 'temp reached'
					first 'stabilizing temperature'
					then 'acquiring data';

				state 'acquiring data' {
					do action 'acquire': 'Acquire Data';
				}
				transition 'signals captured'
					first 'acquiring data'
					then 'processing';

				state 'processing' {
					do action 'process': 'Process Data';
				}
				transition 'results ready'
					first 'processing'
					then 'ready';

				transition 'power off cmd'
					first 'ready'
					accept PowerOff
					then 'power off';
			}

			action 'perform measurement': 'Perform Measurement' {
				in measurementCmd: MeasurementCmd;
				in targetTemp: Temperature;
				in model: CalibrationModel;
				out result: ConcentrationResult;

				action 'stabilize temperature': 'Stabilize Temperature' {
					in targetTemp = 'perform measurement'::targetTemp;
				}
				flow 'stabilize temperature'.sampleTemp to 'calculate concentration'.sampleTemp;

				action 'generate microwave': 'Generate Microwave';
				flow 'generate microwave'.signal to 'detect reflected'.signal;
				flow 'generate microwave'.signal to 'detect transmitted'.signal;

				action 'detect reflected': 'Detect Signal';
				action 'detect transmitted': 'Detect Signal';

				flow 'detect reflected'.data to 'analyze signal'.reflectedData;
				flow 'detect transmitted'.data to 'analyze signal'.transmittedData;

				action 'analyze signal': 'Analyze Signal';

				flow 'analyze signal'.properties to 'calculate concentration'.properties;

				action 'calculate concentration': 'Calculate Concentration' {
					in model = 'perform measurement'::model;
					out result = 'perform measurement'::result;
				}

				first start;
				then 'stabilize temperature';
				then 'generate microwave';
				then 'detect reflected';
				then 'detect transmitted';
				then 'analyze signal';
				then 'calculate concentration';
			}
		}

		satisfy 'Measurement Accuracy Requirement' by 'sensing system';
		satisfy 'Temperature Stability Requirement' by 'sensing system'.temperatureController;
		satisfy 'Signal Quality Requirement' by 'sensing system'.microwaveSource;
	}
}
