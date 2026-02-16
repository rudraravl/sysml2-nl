package 'Fine Guidance Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AngleValue {
		attribute num : Real;
		attribute unit : AngleUnit;
	}
	
	attribute def AngularVelocityValue {
		attribute num : Real;
		attribute unit : AngularVelocityUnit;
	}
	
	attribute def IntensityValue {
		attribute num : Real;
		attribute unit : IntensityUnit;
	}
	
	attribute def AngleUnit;
	attribute def AngularVelocityUnit;
	attribute def IntensityUnit;
	
	item def OpticalSignal {
		attribute intensity : IntensityValue;
		attribute wavelength : LengthValue;
		attribute coherence : Real;
	}
	
	item def GuidanceData {
		attribute azimuthAngle : AngleValue;
		attribute elevationAngle : AngleValue;
		attribute angularRate : AngularVelocityValue;
		attribute timestamp : TimeValue;
		attribute measurementQuality : Real;
	}
	
	item def CelestialTarget {
		attribute position : AngleValue[2];
		attribute brightness : IntensityValue;
		attribute catalogId : String;
	}
	
	item def CalibrationData {
		attribute calibrationMatrix : Real[16];
		attribute darkCurrent : IntensityValue;
		attribute flatField : Real[*];
	}
	
	item def SensorStatus {
		attribute operationalMode : OperationalMode;
		attribute temperature : TemperatureValue;
		attribute errorFlags : Integer;
		attribute lastCalibration : TimeValue;
	}
	
	enum def OperationalMode {
		enum standby;
		enum calibrating;
		enum acquiring;
		enum tracking;
		enum measuring;
		enum fault;
	}
	
	port def OpticalInputPort {
		in item signal : OpticalSignal;
	}
	
	port def GuidanceOutputPort {
		out item data : GuidanceData;
	}
	
	port def CalibrationPort {
		in item calibrationCommand : CalibrationData;
		out item calibrationStatus : SensorStatus;
	}
	
	port def StatusPort {
		out item status : SensorStatus;
	}
	
	action def CaptureOpticalSignal {
		in target : CelestialTarget;
		out signal : OpticalSignal;
	}
	
	action def ProcessOpticalSignal {
		in signal : OpticalSignal;
		in calibration : CalibrationData;
		out rawData : GuidanceData;
	}
	
	action def PerformCalibration {
		in referenceTarget : CelestialTarget;
		out calibrationData : CalibrationData;
	}
	
	action def RefineGuidanceData {
		in rawData : GuidanceData;
		in calibration : CalibrationData;
		out refinedData : GuidanceData;
	}
	
	action def ValidateMeasurement {
		in data : GuidanceData;
		out validatedData : GuidanceData;
		out qualityMetric : Real;
	}
	
	part def OpticalAssembly {
		attribute apertureDiameter : LengthValue;
		attribute focalLength : LengthValue;
		attribute transmittance : Real;
		
		port opticalIn : OpticalInputPort;
		port opticalOut : OpticalInputPort;
		
		part primaryMirror : Mirror[1];
		part secondaryMirror : Mirror[1];
		part filterAssembly : FilterAssembly[1];
		
		connect primaryMirror.reflectionPort to secondaryMirror.incidentPort;
		connect secondaryMirror.reflectionPort to filterAssembly.inputPort;
	}
	
	part def Mirror {
		attribute reflectivity : Real;
		attribute surfaceAccuracy : LengthValue;
		
		port incidentPort : OpticalInputPort;
		port reflectionPort : OpticalInputPort;
	}
	
	part def FilterAssembly {
		attribute filterCount : Integer;
		attribute currentFilter : Integer;
		
		port inputPort : OpticalInputPort;
		port outputPort : OpticalInputPort;
	}
	
	part def PhotoDetector {
		attribute pixelArray : Integer[2];
		attribute quantumEfficiency : Real;
		attribute readoutNoise : IntensityValue;
		attribute darkCurrent : IntensityValue;
		
		port opticalInput : OpticalInputPort;
		port dataOutput {
			out item detectorData : GuidanceData;
		}
	}
	
	part def SignalProcessor {
		attribute processingLatency : TimeValue;
		attribute algorithmVersion : String;
		
		port rawDataInput {
			in item rawSignal : GuidanceData;
		}
		port calibrationInput {
			in item calibration : CalibrationData;
		}
		port processedDataOutput : GuidanceOutputPort;
		
		part imageProcessor : ImageProcessor[1];
		part centroidEngine : CentroidEngine[1];
		part motionTracker : MotionTracker[1];
	}
	
	part def ImageProcessor {
		attribute noiseReductionLevel : Real;
	}
	
	part def CentroidEngine {
		attribute centroidPrecision : AngleValue;
		attribute subpixelAccuracy : Real;
	}
	
	part def MotionTracker {
		attribute trackingFilterOrder : Integer;
		attribute predictionHorizon : TimeValue;
	}
	
	part def CalibrationUnit {
		attribute calibrationInterval : TimeValue;
		attribute calibrationAccuracy : Real;
		
		port calibrationPort : CalibrationPort;
		
		part referenceDatabase : ReferenceDatabase[1];
		part calibrationProcessor : CalibrationProcessor[1];
	}
	
	part def ReferenceDatabase {
		attribute referenceStars : CelestialTarget[*];
		attribute catalogVersion : String;
	}
	
	part def CalibrationProcessor {
		attribute matrixSize : Integer;
	}
	
	part def ControlUnit {
		port statusPort : StatusPort;
		
		part thermalController : ThermalController[1];
		part modeController : ModeController[1];
	}
	
	part def ThermalController {
		attribute targetTemperature : TemperatureValue;
		attribute temperatureTolerance : TemperatureValue;
	}
	
	part def ModeController {
		attribute currentMode : OperationalMode;
	}
	
	action def MeasurementSequence {
		in target : CelestialTarget;
		in calibration : CalibrationData;
		out guidanceData : GuidanceData;
		
		bind captureSignal.target = target;
		
		action captureSignal : CaptureOpticalSignal {
			in target;
			out signal;
		}
		
		flow from captureSignal.signal to processSignal.signal;
		
		action processSignal : ProcessOpticalSignal {
			in signal;
			in calibration = MeasurementSequence::calibration;
			out rawData;
		}
		
		flow from processSignal.rawData to refineData.rawData;
		
		action refineData : RefineGuidanceData {
			in rawData;
			in calibration = MeasurementSequence::calibration;
			out refinedData;
		}
		
		flow from refineData.refinedData to validateData.data;
		
		action validateData : ValidateMeasurement {
			in data;
			out validatedData;
			out qualityMetric;
		}
		
		bind validateData.validatedData = guidanceData;
	}
	
	part def FineGuidanceSensor {
		attribute sensorId : String;
		attribute fieldOfView : AngleValue;
		attribute sensitivity : IntensityValue;
		attribute samplingRate : FrequencyValue;
		attribute measurementAccuracy : AngleValue;
		attribute currentStatus : SensorStatus;
		
		port opticalInput : OpticalInputPort;
		port guidanceOutput : GuidanceOutputPort;
		port calibrationInterface : CalibrationPort;
		port statusOutput : StatusPort;
		
		part optics : OpticalAssembly[1];
		part detector : PhotoDetector[1];
		part processor : SignalProcessor[1];
		part calibration : CalibrationUnit[1];
		part control : ControlUnit[1];
		
		connect optics.opticalIn to opticalInput;
		connect optics.opticalOut to detector.opticalInput;
		connect detector.dataOutput to processor.rawDataInput;
		connect calibration.calibrationPort to calibrationInterface;
		connect calibration.calibrationPort to processor.calibrationInput;
		connect processor.processedDataOutput to guidanceOutput;
		connect control.statusPort to statusOutput;
		
		state sensorStateMachine {
			entry; then standby;
			
			state standby;
			
			transition standby_to_calibrating
				first standby
				then calibrating;
			
			state calibrating {
				do action calibrationAction : PerformCalibration;
			}
			
			transition calibrating_to_acquiring
				first calibrating
				then acquiring;
			
			state acquiring {
				do action acquisitionAction : CaptureOpticalSignal;
			}
			
			transition acquiring_to_tracking
				first acquiring
				then tracking;
			
			state tracking {
				state coarseTracking;
				state fineTracking;
				
				transition coarse_to_fine
					first coarseTracking
					then fineTracking;
			}
			
			transition tracking_to_measuring
				first tracking
				then measuring;
			
			state measuring {
				do action measurementAction : MeasurementSequence;
			}
			
			transition measuring_to_standby
				first measuring
				then standby;
			
			transition any_to_fault
				first tracking
				then fault;
			
			state fault;
			
			transition fault_to_standby
				first fault
				then standby;
		}
	}
	
	part sensingUnit : FineGuidanceSensor {
		attribute :>> sensorId = "FGS-PRIMARY-001";
		
		part :>> optics {
			attribute :>> transmittance = 0.92;
			
			part :>> primaryMirror {
				attribute :>> reflectivity = 0.96;
			}
			
			part :>> secondaryMirror {
				attribute :>> reflectivity = 0.94;
			}
			
			part :>> filterAssembly {
				attribute :>> filterCount = 8;
				attribute :>> currentFilter = 1;
			}
		}
		
		part :>> detector {
			attribute :>> pixelArray = (2048, 2048);
			attribute :>> quantumEfficiency = 0.88;
		}
		
		part :>> processor {
			attribute :>> algorithmVersion = "v3.2.1";
			
			part :>> imageProcessor {
				attribute :>> noiseReductionLevel = 0.85;
			}
			
			part :>> centroidEngine {
				attribute :>> subpixelAccuracy = 0.05;
			}
			
			part :>> motionTracker {
				attribute :>> trackingFilterOrder = 6;
			}
		}
		
		part :>> calibration {
			attribute :>> calibrationAccuracy = 0.98;
			
			part :>> calibrationProcessor {
				attribute :>> matrixSize = 16;
			}
		}
	}
	
	requirement def AngularAccuracyRequirement {
		doc /* The Fine Guidance Sensor shall measure angular position with accuracy better than 0.001 arcseconds. */
		
		subject sensor : FineGuidanceSensor;
		
		require constraint {
			sensor.measurementAccuracy.num <= 0.001
		}
	}
	
	requirement def SamplingRateRequirement {
		doc /* The Fine Guidance Sensor shall acquire measurements at minimum rate of 100 Hz. */
		
		subject sensor : FineGuidanceSensor;
		
		require constraint {
			sensor.samplingRate.num >= 100.0
		}
	}
	
	requirement def SensitivityRequirement {
		doc /* The Fine Guidance Sensor shall detect targets with brightness down to specified threshold. */
		
		subject sensor : FineGuidanceSensor;
		
		require constraint {
			sensor.sensitivity.num <= 1.0e-6
		}
	}
	
	requirement def FieldOfViewRequirement {
		doc /* The Fine Guidance Sensor shall provide minimum field of view coverage. */
		
		subject sensor : FineGuidanceSensor;
		
		require constraint {
			sensor.fieldOfView.num >= 0.5
		}
	}
	
	requirement def CalibrationIntervalRequirement {
		doc /* The Fine Guidance Sensor shall perform calibration at specified intervals. */
		
		subject sensor : FineGuidanceSensor;
		
		require constraint {
			sensor.calibration.calibrationInterval.num <= 7200.0
		}
	}
	
	requirement sensingUnitRequirements {
		doc /* Top-level requirements for the Fine Guidance Sensor sensing unit. */
		
		subject unit : FineGuidanceSensor = sensingUnit;
		
		requirement accuracyReq : AngularAccuracyRequirement {
			subject sensor = unit;
		}
		
		requirement samplingReq : SamplingRateRequirement {
			subject sensor = unit;
		}
		
		requirement sensitivityReq : SensitivityRequirement {
			subject sensor = unit;
		}
		
		requirement fovReq : FieldOfViewRequirement {
			subject sensor = unit;
		}
		
		requirement calibrationReq : CalibrationIntervalRequirement {
			subject sensor = unit;
		}
	}
}
