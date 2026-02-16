package SensingUnitModel {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	attribute def MicrowaveFrequency :> FrequencyValue;
	
	attribute def BrightnessTemperature :> TemperatureValue;
	
	attribute def RadiantIntensity :> PowerValue;
	
	attribute def SpatialResolution :> LengthValue;
	
	attribute def ScanAngle :> AngleValue;
	
	attribute def Polarization {
		attribute mode: String;
	}
	
	item def TargetScene {
		attribute surfaceTemperature: TemperatureValue;
		attribute atmosphericMoisture: Real;
		attribute emissivity: Real;
	}
	
	item def MicrowaveRadiation {
		attribute frequency: MicrowaveFrequency;
		attribute intensity: RadiantIntensity;
		attribute polarization: Polarization;
		attribute brightnessTemp: BrightnessTemperature;
	}
	
	item def SensorMeasurement {
		attribute brightnessTemperatures: BrightnessTemperature[*];
		attribute frequencies: MicrowaveFrequency[*];
		attribute scanPosition: ScanAngle;
		attribute timestamp: TimeInstantValue;
		attribute quality: Real;
	}
	
	item def CalibrationData {
		attribute warmTargetReading: BrightnessTemperature;
		attribute coldTargetReading: BrightnessTemperature;
		attribute gainCoefficients: Real[*];
		attribute offsetCoefficients: Real[*];
	}
	
	port def RadiationInputPort {
		in item radiation: MicrowaveRadiation;
	}
	
	port def MeasurementOutputPort {
		out item measurement: SensorMeasurement;
	}
	
	port def ControlCommandPort {
		in attribute command: String;
		out attribute status: String;
	}
	
	port def CalibrationPort {
		in item calibrationData: CalibrationData;
	}
	
	part def AntennaSubsystem {
		attribute apertureDiameter: LengthValue;
		attribute beamWidth: AngleValue;
		attribute antennaEfficiency: Real;
		
		port sceneInput: RadiationInputPort;
		port rfOutput {
			out item capturedRadiation: MicrowaveRadiation;
		}
	}
	
	part def ReceiverChannel {
		attribute channelFrequency: MicrowaveFrequency;
		attribute channelBandwidth: MicrowaveFrequency;
		attribute noiseFigure: Real;
		attribute channelPolarization: Polarization;
		
		port rfInput {
			in item radiation: MicrowaveRadiation;
		}
		port detectedOutput {
			out attribute detectedVoltage: Real;
		}
	}
	
	part def RadiometerSubsystem {
		attribute integrationTime: DurationValue;
		attribute numberOfChannels: Integer;
		
		port voltageInput {
			in attribute voltage: Real;
		}
		port calibrationInput: CalibrationPort;
		port temperatureOutput {
			out attribute calibratedTemperature: BrightnessTemperature;
		}
	}
	
	part def ScanningMechanism {
		attribute scanRate: Real;
		attribute swathWidth: LengthValue;
		attribute crossTrackAngle: ScanAngle;
		
		port controlInput {
			in attribute scanControl: String;
		}
		port positionOutput {
			out attribute currentPosition: ScanAngle;
		}
	}
	
	part def SignalProcessor {
		attribute processingMode: String;
		attribute filteringEnabled: Boolean;
		
		port rawDataInput {
			in attribute temperature: BrightnessTemperature;
			in attribute position: ScanAngle;
			in attribute frequency: MicrowaveFrequency;
		}
		port processedOutput: MeasurementOutputPort;
	}
	
	part def CalibrationSubsystem {
		attribute warmTargetTemperature: TemperatureValue;
		attribute coldTargetTemperature: TemperatureValue;
		attribute calibrationInterval: DurationValue;
		
		port calibrationTrigger {
			in attribute trigger: String;
		}
		port calibrationOutput {
			out item calibrationData: CalibrationData;
		}
	}
	
	part def SpecialSensorMicrowaveImager {
		attribute instrumentId: String;
		attribute operatingFrequencies: MicrowaveFrequency[*];
		attribute spatialResolution: SpatialResolution;
		attribute swathCoverage: LengthValue;
		
		port sceneObservation: RadiationInputPort;
		port measurementOutput: MeasurementOutputPort;
		port systemControl: ControlCommandPort;
		
		part antenna: AntennaSubsystem[1] {
			attribute :>> apertureDiameter = 61.0;
			attribute :>> beamWidth = 3.8;
			attribute :>> antennaEfficiency = 0.82;
		}
		
		part receivers: ReceiverChannel[7] {
			attribute :>> channelFrequency = 19.35e9;
			attribute :>> channelBandwidth = 0.35e9;
			attribute :>> noiseFigure = 4.5;
		}
		
		part radiometers: RadiometerSubsystem[7] {
			attribute :>> integrationTime = 7.95e-3;
			attribute :>> numberOfChannels = 1;
		}
		
		part scanner: ScanningMechanism[1] {
			attribute :>> scanRate = 31.6;
			attribute :>> swathWidth = 1400.0e3;
			attribute :>> crossTrackAngle = 51.2;
		}
		
		part processor: SignalProcessor[1] {
			attribute :>> processingMode = "Brightness Temperature Conversion";
			attribute :>> filteringEnabled = true;
		}
		
		part calibration: CalibrationSubsystem[1] {
			attribute :>> warmTargetTemperature = 290.0;
			attribute :>> coldTargetTemperature = 2.7;
			attribute :>> calibrationInterval = 1.0;
		}
		
		connect sceneObservation to antenna.sceneInput;
		flow from antenna.rfOutput.capturedRadiation to receivers.rfInput.radiation;
		flow from receivers.detectedOutput.detectedVoltage to radiometers.voltageInput.voltage;
		flow from calibration.calibrationOutput.calibrationData to radiometers.calibrationInput.calibrationData;
		flow from radiometers.temperatureOutput.calibratedTemperature to processor.rawDataInput.temperature;
		flow from scanner.positionOutput.currentPosition to processor.rawDataInput.position;
		flow from processor.processedOutput.measurement to measurementOutput.measurement;
	}
	
	action def CaptureRadiation {
		in scene: TargetScene;
		out radiation: MicrowaveRadiation;
	}
	
	action def DetectSignal {
		in radiation: MicrowaveRadiation;
		out voltage: Real;
	}
	
	action def ConvertToBrightnessTemperature {
		in voltage: Real;
		in calibration: CalibrationData;
		out brightnessTemp: BrightnessTemperature;
	}
	
	action def PerformScan {
		out scanPosition: ScanAngle;
	}
	
	action def ProcessMeasurement {
		in brightnessTemp: BrightnessTemperature;
		in scanPosition: ScanAngle;
		in frequency: MicrowaveFrequency;
		out measurement: SensorMeasurement;
	}
	
	action def PerformCalibration {
		in warmTarget: TemperatureValue;
		in coldTarget: TemperatureValue;
		out calibrationData: CalibrationData;
	}
	
	action def ExecuteSensing {
		in item targetScene: TargetScene;
		out item finalMeasurement: SensorMeasurement;
		
		bind captureRadiation.scene = targetScene;
		
		action captureRadiation: CaptureRadiation {
			in scene;
			out radiation;
		}
		
		succession flow from captureRadiation.radiation to detectSignal.radiation;
		
		action detectSignal: DetectSignal {
			in radiation;
			out voltage;
		}
		
		succession flow from detectSignal.voltage to convertTemperature.voltage;
		
		fork parallelProcessing;
		
		action performCalibration: PerformCalibration {
			in warmTarget;
			in coldTarget;
			out calibrationData;
		}
		
		then joinNode;
		
		action convertTemperature: ConvertToBrightnessTemperature {
			in voltage;
			in calibration;
			out brightnessTemp;
		}
		
		then joinNode;
		
		action performScan: PerformScan {
			out scanPosition;
		}
		
		then joinNode;
		
		flow from performCalibration.calibrationData to convertTemperature.calibration;
		flow from convertTemperature.brightnessTemp to processMeasurement.brightnessTemp;
		flow from performScan.scanPosition to processMeasurement.scanPosition;
		
		action processMeasurement: ProcessMeasurement {
			in brightnessTemp;
			in scanPosition;
			in frequency;
			out measurement;
		}
		
		then joinNode;
		
		join joinNode;
		
		bind processMeasurement.measurement = finalMeasurement;
	}
	
	state def SensorOperationalStates {
		entry; then powerOff;
		
		state powerOff;
		
		transition powerOff_to_initialization
			first powerOff
			accept powerOnCommand
			then initialization;
		
		state initialization;
		
		transition initialization_to_calibration
			first initialization
			if initializationComplete
			then calibration;
		
		state calibration;
		
		transition calibration_to_standby
			first calibration
			if calibrationSuccessful
			then standby;
		
		state standby;
		
		transition standby_to_sensing
			first standby
			accept startSensingCommand
			then sensing;
		
		state sensing;
		
		transition sensing_to_dataProcessing
			first sensing
			if dataAcquisitionComplete
			then dataProcessing;
		
		state dataProcessing;
		
		transition dataProcessing_to_standby
			first dataProcessing
			if processingComplete
			then standby;
		
		transition standby_to_recalibration
			first standby
			accept recalibrationRequest
			then calibration;
		
		transition standby_to_powerOff
			first standby
			accept shutdownCommand
			then powerOff;
		
		state fault;
		
		transition any_to_fault
			first initialization, calibration, standby, sensing, dataProcessing
			accept faultDetected
			then fault;
		
		transition fault_to_initialization
			first fault
			accept resetCommand
			then initialization;
	}
	
	part sensingUnit: SpecialSensorMicrowaveImager {
		attribute :>> instrumentId = "SSM/I-F17";
		attribute :>> operatingFrequencies = (19.35e9, 22.235e9, 37.0e9, 85.5e9);
		attribute :>> spatialResolution = 25.0e3;
		attribute :>> swathCoverage = 1400.0e3;
		
		ref item observedScene: TargetScene;
		part measurements: SensorMeasurement[*];
		
		exhibit state operationalState: SensorOperationalStates;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure brightness temperature with accuracy better than 1.0 K. */
		
		subject sensor: SpecialSensorMicrowaveImager;
		
		require constraint {
			sensor.receivers.noiseFigure < 5.0
		}
	}
	
	requirement def SpatialResolutionRequirement {
		doc /* The sensing unit shall provide spatial resolution of 25 km or better at the lowest frequency. */
		
		subject sensor: SpecialSensorMicrowaveImager;
		
		require constraint {
			sensor.spatialResolution <= 25.0e3
		}
	}
	
	requirement def SwathCoverageRequirement {
		doc /* The sensing unit shall provide a swath width of at least 1400 km. */
		
		subject sensor: SpecialSensorMicrowaveImager;
		
		require constraint {
			sensor.scanner.swathWidth >= 1400.0e3
		}
	}
	
	requirement def CalibrationRequirement {
		doc /* The sensing unit shall perform calibration using warm and cold reference targets with specified temperatures. */
		
		subject sensor: SpecialSensorMicrowaveImager;
		
		require constraint {
			sensor.calibration.warmTargetTemperature > 280.0 and
			sensor.calibration.coldTargetTemperature < 10.0
		}
	}
	
	requirement def FrequencyCoverageRequirement {
		doc /* The sensing unit shall operate at multiple microwave frequencies to measure atmospheric and surface properties. */
		
		subject sensor: SpecialSensorMicrowaveImager;
		
		require constraint {
			sensor.operatingFrequencies->size() >= 4
		}
	}
	
	requirement sensingUnitRequirements {
		doc /* Top-level requirements for the Special Sensor Microwave/Imager sensing unit. */
		
		subject sensor: SpecialSensorMicrowaveImager;
		
		requirement accuracyReq: MeasurementAccuracyRequirement {
			subject sensor = sensingUnitRequirements::sensor;
		}
		
		requirement resolutionReq: SpatialResolutionRequirement {
			subject sensor = sensingUnitRequirements::sensor;
		}
		
		requirement swathReq: SwathCoverageRequirement {
			subject sensor = sensingUnitRequirements::sensor;
		}
		
		requirement calibrationReq: CalibrationRequirement {
			subject sensor = sensingUnitRequirements::sensor;
		}
		
		requirement frequencyReq: FrequencyCoverageRequirement {
			subject sensor = sensingUnitRequirements::sensor;
		}
	}
}
