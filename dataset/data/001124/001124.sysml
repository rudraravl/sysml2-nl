package 'Littoral Airborne Sensor Hyperspectral System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import MeasurementReferences::*;
	private import Quantities::*;
	
	attribute def NanometerUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[1] {
			attribute :>> unit = NanometerUnit::self;
			attribute :>> exponent = 1;
		}
	}
	
	attribute nm : NanometerUnit;
	
	attribute def SpectralRadianceUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[4] ordered {
			[1] { attribute :>> unit = W; attribute :>> exponent = 1; }
			[2] { attribute :>> unit = sr; attribute :>> exponent = -1; }
			[3] { attribute :>> unit = m; attribute :>> exponent = -2; }
			[4] { attribute :>> unit = nm; attribute :>> exponent = -1; }
		}
	}
	
	attribute W_per_sr_m2_nm : SpectralRadianceUnit;
	
	attribute def SpectralRadianceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : SpectralRadianceUnit;
	}
	
	attribute def WavelengthValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : NanometerUnit;
	}
	
	attribute def ReflectanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
	}
	
	item def LittoralScene {
		attribute sceneType : String;
		attribute environmentalConditions : String;
		attribute targetCharacteristics : String;
	}
	
	item def SpectralBand {
		attribute centerWavelength : WavelengthValue;
		attribute bandwidth : WavelengthValue;
		attribute radiance : SpectralRadianceValue;
	}
	
	item def HyperspectralDataCube {
		attribute spectralBands : SpectralBand[1..*] ordered;
		attribute spatialDimensions : LengthValue[2];
		attribute acquisitionTime : String;
		attribute geolocation : String;
	}
	
	item def CalibrationData {
		attribute radiometricCoefficients : Real[*];
		attribute spectralCalibration : WavelengthValue[*];
		attribute darkCurrent : Real;
	}
	
	item def ScanCommandItem;
	item def RecalibrationCommandItem;
	item def ShutdownCommandItem;
	
	port def OpticalInputPort {
		in item incomingRadiation : LittoralScene;
	}
	
	port def DataOutputPort {
		out item hyperspectralData : HyperspectralDataCube;
	}
	
	port def ControlPort {
		in attribute scanCommand : String;
		in attribute calibrationCommand : String;
		out attribute systemStatus : String;
	}
	
	part def OpticalSubsystem {
		attribute focalLength : LengthValue;
		attribute aperture : LengthValue;
		attribute fieldOfView : Real;
		
		port opticalInput : OpticalInputPort;
		port focusedOutput;
	}
	
	part def SpectrographicDispersiveElement {
		attribute dispersiveType : String;
		attribute spectralRangeLower : WavelengthValue;
		attribute spectralRangeUpper : WavelengthValue;
		attribute spectralResolution : WavelengthValue;
		
		port dispersiveInput;
		port dispersedOutput;
	}
	
	part def FocalPlaneArray {
		attribute detectorType : String;
		attribute spatialPixels : Integer[2];
		attribute spectralChannels : Integer;
		attribute quantumEfficiency : Real;
		attribute integrationTime : TimeValue;
		
		port detectorInput;
		port rawDataOutput;
	}
	
	part def SignalProcessingUnit {
		attribute processingAlgorithm : String;
		attribute calibrationApplied : Boolean;
		
		port rawDataInput;
		port calibrationInput;
		port processedDataOutput : DataOutputPort;
	}
	
	part def ScanMechanism {
		attribute scanType : String;
		attribute scanRate : Real;
		attribute scanPattern : String;
		
		port scanControl;
	}
	
	part def CalibrationSubsystem {
		attribute calibrationSource : String;
		attribute calibrationFrequency : String;
		
		port calibrationControl;
		port calibrationDataOutput;
	}
	
	action def CaptureHyperspectralData {
		in item scene : LittoralScene;
		out item dataCube : HyperspectralDataCube;
	}
	
	action def FocusIncomingRadiation {
		in item incomingScene : LittoralScene;
		out item focusedBeam;
	}
	
	action def DisperseSpectrum {
		in item focusedBeam;
		out item dispersedSpectrum;
	}
	
	action def DetectPhotons {
		in item dispersedSpectrum;
		out item rawSignal;
	}
	
	action def ProcessRawData {
		in item rawSignal;
		in item calibration : CalibrationData;
		out item processedCube : HyperspectralDataCube;
	}
	
	action def PerformCalibration {
		in attribute calibrationSource : String;
		out item calibrationData : CalibrationData;
	}
	
	action def ExecuteScan {
		in attribute scanPattern : String;
		in attribute scanRate : Real;
	}
	
	state def SensorOperationalStates {
		entry; then powerUp;
		
		state powerUp;
		transition powerUp_to_initialization
			first powerUp
			then initialization;
		
		state initialization {
			entry action initializeSystem;
		}
		transition initialization_to_calibration
			first initialization
			then calibration;
		
		state calibration {
			entry action performCalibration : PerformCalibration;
		}
		transition calibration_to_ready
			first calibration
			then ready;
		
		state ready;
		transition ready_to_scanning
			first ready
			accept scanCmd : ScanCommandItem
			then scanning;
		
		state scanning {
			entry action startScan : ExecuteScan;
			do action captureData : CaptureHyperspectralData;
		}
		transition scanning_to_processing
			first scanning
			then processing;
		
		state processing {
			do action processData : ProcessRawData;
		}
		transition processing_to_ready
			first processing
			then ready;
		
		transition ready_to_calibration
			first ready
			accept recalCmd : RecalibrationCommandItem
			then calibration;
		
		transition ready_to_shutdown
			first ready
			accept shutCmd : ShutdownCommandItem
			then shutdown;
		
		state shutdown;
	}
	
	part def LittoralAirborneSensorHyperspectral {
		attribute sensorID : String;
		attribute operationalAltitude : LengthValue;
		attribute platformSpeed : Real;
		attribute spectralRangeLower : WavelengthValue;
		attribute spectralRangeUpper : WavelengthValue;
		attribute spectralResolution : WavelengthValue;
		attribute spatialResolution : LengthValue;
		attribute swathWidth : LengthValue;
		
		port opticalInput : OpticalInputPort;
		port dataOutput : DataOutputPort;
		port controlInterface : ControlPort;
		
		part optics : OpticalSubsystem[1] {
			attribute :>> focalLength {
				attribute :>> num = 600.0;
			}
			attribute :>> aperture {
				attribute :>> num = 200.0;
			}
			attribute :>> fieldOfView = 40.0;
		}
		
		part spectrograph : SpectrographicDispersiveElement[1] {
			attribute :>> dispersiveType = "Prism-Grating Hybrid";
			attribute :>> spectralRangeLower {
				attribute :>> num = 400.0;
			}
			attribute :>> spectralRangeUpper {
				attribute :>> num = 2500.0;
			}
			attribute :>> spectralResolution {
				attribute :>> num = 10.0;
			}
		}
		
		part fpa : FocalPlaneArray[1] {
			attribute :>> detectorType = "HgCdTe Array";
			attribute :>> spatialPixels = (1024, 1024);
			attribute :>> spectralChannels = 210;
			attribute :>> quantumEfficiency = 0.80;
			attribute :>> integrationTime {
				attribute :>> num = 0.01;
			}
		}
		
		part processor : SignalProcessingUnit[1] {
			attribute :>> processingAlgorithm = "Atmospheric Correction and Radiometric Calibration";
			attribute :>> calibrationApplied = true;
		}
		
		part scanner : ScanMechanism[1] {
			attribute :>> scanType = "Pushbroom";
			attribute :>> scanRate = 25.0;
			attribute :>> scanPattern = "Along-Track Linear";
		}
		
		part calibrator : CalibrationSubsystem[1] {
			attribute :>> calibrationSource = "Onboard Reference Standards";
			attribute :>> calibrationFrequency = "Pre-flight and Periodic In-flight";
		}
		
		connect opticalInput to optics.opticalInput;
		connect optics.focusedOutput to spectrograph.dispersiveInput;
		connect spectrograph.dispersedOutput to fpa.detectorInput;
		connect fpa.rawDataOutput to processor.rawDataInput;
		connect calibrator.calibrationDataOutput to processor.calibrationInput;
		connect processor.processedDataOutput to dataOutput;
		connect controlInterface to scanner.scanControl;
		connect controlInterface to calibrator.calibrationControl;
	}
	
	action def HyperspectralSensingOperation {
		in item targetScene : LittoralScene;
		out item hyperspectralOutput : HyperspectralDataCube;
		
		bind focusRadiation.incomingScene = targetScene;
		
		action focusRadiation : FocusIncomingRadiation {
			in item incomingScene;
			out item focusedBeam;
		}
		then succession flow from focusRadiation.focusedBeam to disperseLight.focusedBeam;
		
		action disperseLight : DisperseSpectrum {
			in item focusedBeam;
			out item dispersedSpectrum;
		}
		then succession flow from disperseLight.dispersedSpectrum to detectPhotons.dispersedSpectrum;
		
		action detectPhotons : DetectPhotons {
			in item dispersedSpectrum;
			out item rawSignal;
		}
		then succession flow from detectPhotons.rawSignal to processData.rawSignal;
		
		action calibrate : PerformCalibration {
			in attribute calibrationSource = "Reference Standards";
			out item calibrationData;
		}
		
		flow from calibrate.calibrationData to processData.calibration;
		
		action processData : ProcessRawData {
			in item rawSignal;
			in item calibration;
			out item processedCube;
		}
		
		bind processData.processedCube = hyperspectralOutput;
	}
	
	part sensingUnit : LittoralAirborneSensorHyperspectral {
		attribute :>> sensorID = "LASH-2025-001";
		attribute :>> operationalAltitude {
			attribute :>> num = 3500.0;
		}
		attribute :>> platformSpeed = 140.0;
		attribute :>> spectralRangeLower {
			attribute :>> num = 400.0;
		}
		attribute :>> spectralRangeUpper {
			attribute :>> num = 2500.0;
		}
		attribute :>> spectralResolution {
			attribute :>> num = 10.0;
		}
		attribute :>> spatialResolution {
			attribute :>> num = 2.5;
		}
		attribute :>> swathWidth {
			attribute :>> num = 6000.0;
		}
		
		perform action sensingOperation : HyperspectralSensingOperation;
	}
	
	requirement def SpectralCoverageRequirement {
		doc /* The sensor shall cover the visible through shortwave infrared spectrum from 400 nm to 2500 nm. */
		
		subject sensor : LittoralAirborneSensorHyperspectral;
		
		require constraint {
			sensor.spectralRangeLower.num <= 450.0 and
			sensor.spectralRangeUpper.num >= 2400.0
		}
	}
	
	requirement def SpectralResolutionRequirement {
		doc /* The sensor shall provide spectral resolution of 10 nm or better across the operational range. */
		
		subject sensor : LittoralAirborneSensorHyperspectral;
		
		require constraint {
			sensor.spectralResolution.num <= 10.0
		}
	}
	
	requirement def SpatialResolutionRequirement {
		doc /* The sensor shall achieve spatial resolution of 3 meters or better at operational altitude. */
		
		subject sensor : LittoralAirborneSensorHyperspectral;
		
		require constraint {
			sensor.spatialResolution.num <= 3.0
		}
	}
	
	requirement def SwathWidthRequirement {
		doc /* The sensor shall provide a swath width of at least 5 km at operational altitude. */
		
		subject sensor : LittoralAirborneSensorHyperspectral;
		
		require constraint {
			sensor.swathWidth.num >= 5000.0
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the Littoral Airborne Sensor Hyperspectral sensing unit. */
		
		subject sensor : LittoralAirborneSensorHyperspectral;
		
		requirement spectralCoverage : SpectralCoverageRequirement {
			subject :>> sensor;
		}
		
		requirement spectralResolution : SpectralResolutionRequirement {
			subject :>> sensor;
		}
		
		requirement spatialResolution : SpatialResolutionRequirement {
			subject :>> sensor;
		}
		
		requirement swathWidth : SwathWidthRequirement {
			subject :>> sensor;
		}
	}
}
