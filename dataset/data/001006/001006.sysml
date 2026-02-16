package 'Catadioptric Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RadianceUnit :> ISQ::PowerPerAreaPerSolidAngleUnit;
	attribute def SolidAngleUnit :> ISQ::SolidAngleUnit;
	
	attribute def RadianceValue {
		attribute num : Real;
		attribute mRef : RadianceUnit;
	}
	
	attribute def SolidAngleValue {
		attribute num : Real;
		attribute mRef : SolidAngleUnit;
	}
	
	item def OpticalScene {
		attribute sceneRadiance : RadianceValue;
		attribute fieldOfView : SolidAngleValue;
		attribute wavelengthRange : LengthValue[2];
	}
	
	item def FocusedRadiation {
		attribute intensity : RadianceValue;
		attribute focalPosition : LengthValue;
		attribute timestamp : TimeValue;
	}
	
	item def DetectorSignal {
		attribute signalLevel : Real;
		attribute noiseLevel : Real;
		attribute integrationTime : TimeValue;
		attribute sensorTemperature : TemperatureValue;
	}
	
	item def RadianceMeasurement {
		attribute measuredRadiance : RadianceValue;
		attribute measurementTime : TimeValue;
		attribute uncertainty : Real;
		attribute isValid : Boolean;
	}
	
	port def OpticalPort {
		in item scene : OpticalScene;
	}
	
	port def MeasurementPort {
		out item measurement : RadianceMeasurement;
	}
	
	port def ControlPort {
		in attribute startMeasurement : Boolean;
		in attribute calibrate : Boolean;
		out attribute systemStatus : String;
	}
	
	part def PrimaryMirror {
		attribute diameter : LengthValue;
		attribute focalLength : LengthValue;
		attribute reflectivity : Real;
		attribute surfaceAccuracy : LengthValue;
	}
	
	part def SecondaryMirror {
		attribute diameter : LengthValue;
		attribute curvature : Real;
		attribute reflectivity : Real;
		attribute centralObstruction : Real;
	}
	
	part def RefractiveCorrector {
		attribute lensCount : Integer;
		attribute transmittance : Real;
		attribute chromaticCorrection : Boolean;
		attribute focalLength : LengthValue;
	}
	
	part def FocalPlaneArray {
		attribute pixelCount : Integer;
		attribute pixelSize : LengthValue;
		attribute quantumEfficiency : Real;
		attribute readoutNoise : Real;
		attribute darkCurrent : Real;
		
		action def AcquireSignal {
			in item radiation : FocusedRadiation;
			out item signal : DetectorSignal;
		}
	}
	
	part def SignalConditioner {
		attribute gain : Real;
		attribute bandwidth : Real;
		attribute noiseFloor : Real;
		
		action def ConditionSignal {
			in item rawSignal : DetectorSignal;
			out item conditionedSignal : DetectorSignal;
		}
	}
	
	part def DataProcessor {
		attribute processingRate : Real;
		attribute calibrationCoefficients : Real[*];
		
		action def ComputeRadiance {
			in item signal : DetectorSignal;
			in attribute calibrationData : Real[*];
			out item measurement : RadianceMeasurement;
		}
	}
	
	part def CatadioptricOpticalAssembly {
		part primary : PrimaryMirror[1] {
			attribute :>> diameter = 200.0[mm];
			attribute :>> focalLength = 800.0[mm];
			attribute :>> reflectivity = 0.96;
			attribute :>> surfaceAccuracy = 0.025[mm];
		}
		
		part secondary : SecondaryMirror[1] {
			attribute :>> diameter = 60.0[mm];
			attribute :>> curvature = 0.15;
			attribute :>> reflectivity = 0.94;
			attribute :>> centralObstruction = 0.30;
		}
		
		part corrector : RefractiveCorrector[1] {
			attribute :>> lensCount = 3;
			attribute :>> transmittance = 0.97;
			attribute :>> chromaticCorrection = true;
			attribute :>> focalLength = 400.0[mm];
		}
		
		action def CollectAndFocusRadiation {
			in item sceneInput : OpticalScene;
			out item focusedOutput : FocusedRadiation;
		}
	}
	
	state def SensorOperationStates {
		entry; then standby;
		
		state standby;
		
		transition standby_to_calibrating
			first standby
			accept calibrationRequest
			then calibrating;
		
		state calibrating;
		
		transition calibrating_to_ready
			first calibrating
			if calibrationSuccessful
			then ready;
		
		transition calibrating_to_fault
			first calibrating
			if calibrationFailed
			then fault;
		
		state ready;
		
		transition ready_to_acquiring
			first ready
			accept measurementTrigger
			then acquiring;
		
		state acquiring;
		
		transition acquiring_to_processing
			first acquiring
			if dataAcquired
			then processing;
		
		state processing;
		
		transition processing_to_ready
			first processing
			if processingComplete
			then ready;
		
		transition processing_to_fault
			first processing
			if processingError
			then fault;
		
		state fault;
		
		transition fault_to_standby
			first fault
			accept resetCommand
			then standby;
		
		attribute calibrationSuccessful : Boolean;
		attribute calibrationFailed : Boolean;
		attribute dataAcquired : Boolean;
		attribute processingComplete : Boolean;
		attribute processingError : Boolean;
	}
	
	action def CalibrateSystem {
		in attribute darkFrameCount : Integer;
		in attribute flatFieldCount : Integer;
		out attribute calibrationFactors : Real[*];
		out attribute calibrationValid : Boolean;
	}
	
	action def AcquireRadianceData {
		in item opticalInput : OpticalScene;
		out item detectorOutput : DetectorSignal;
	}
	
	action def ProcessMeasurement {
		in item rawData : DetectorSignal;
		in attribute calibration : Real[*];
		out item result : RadianceMeasurement;
	}
	
	action def MeasureRadiance {
		in item sceneInput : OpticalScene;
		in attribute triggerSignal : Boolean;
		out item radianceMeasurement : RadianceMeasurement;
		
		action collectLight : CatadioptricOpticalAssembly::CollectAndFocusRadiation {
			in item :>> sceneInput;
			out item focusedRadiation : FocusedRadiation;
		}
		
		then action detectRadiation : FocalPlaneArray::AcquireSignal {
			in item :>> radiation = collectLight.focusedRadiation;
			out item rawSignal : DetectorSignal;
		}
		
		then action conditionSignal : SignalConditioner::ConditionSignal {
			in item :>> rawSignal = detectRadiation.rawSignal;
			out item processedSignal : DetectorSignal;
		}
		
		then action computeResult : DataProcessor::ComputeRadiance {
			in item :>> signal = conditionSignal.processedSignal;
			out item :>> measurement;
		}
		
		flow from collectLight.focusedRadiation to detectRadiation.radiation;
		flow from detectRadiation.rawSignal to conditionSignal.rawSignal;
		flow from conditionSignal.processedSignal to computeResult.signal;
		bind computeResult.measurement = radianceMeasurement;
	}
	
	part def CatadioptricSensor {
		attribute sensorIdentifier : String;
		attribute operatingTemperatureRange : TemperatureValue[2];
		attribute spectralRange : LengthValue[2];
		attribute fieldOfView : SolidAngleValue;
		
		part opticalSystem : CatadioptricOpticalAssembly[1];
		part detector : FocalPlaneArray[1] {
			attribute :>> pixelCount = 2048;
			attribute :>> pixelSize = 0.015[mm];
			attribute :>> quantumEfficiency = 0.85;
			attribute :>> readoutNoise = 5.0;
			attribute :>> darkCurrent = 0.01;
		}
		part conditioner : SignalConditioner[1] {
			attribute :>> gain = 100.0;
			attribute :>> bandwidth = 1000.0;
			attribute :>> noiseFloor = 0.001;
		}
		part processor : DataProcessor[1] {
			attribute :>> processingRate = 10.0;
		}
		
		port opticalInput : OpticalPort[1];
		port measurementOutput : MeasurementPort[1];
		port controlInterface : ControlPort[1];
		
		exhibit state operationStateMachine : SensorOperationStates;
		
		perform action measurementOperation : MeasureRadiance;
	}
	
	part def SensingUnit {
		attribute unitIdentifier : String;
		attribute lastCalibrationDate : String;
		attribute measurementAccuracy : Real;
		attribute measurementPrecision : Real;
		
		part sensor : CatadioptricSensor[1] {
			attribute :>> sensorIdentifier = "CATA-001";
		}
		
		port opticalInterface : OpticalPort[1];
		port dataOutput : MeasurementPort[1];
		port controlInput : ControlPort[1];
		
		connect sensor.opticalInput to opticalInterface;
		connect sensor.measurementOutput to dataOutput;
		connect sensor.controlInterface to controlInput;
		
		action def PerformRadianceMeasurement {
			in item inputScene : OpticalScene;
			out item outputMeasurement : RadianceMeasurement;
			
			action captureScene {
				in item :>> inputScene;
				out item capturedScene : OpticalScene;
			}
			
			then action executeSensing : CatadioptricSensor::MeasureRadiance {
				in item :>> sceneInput = captureScene.capturedScene;
				out item sensorResult : RadianceMeasurement;
			}
			
			then action validateResult {
				in item inputResult : RadianceMeasurement;
				out item :>> outputMeasurement;
			}
			
			flow from captureScene.capturedScene to executeSensing.sceneInput;
			flow from executeSensing.radianceMeasurement to validateResult.inputResult;
			bind validateResult.outputMeasurement = outputMeasurement;
		}
		
		perform action unitMeasurement : PerformRadianceMeasurement;
	}
	
	requirement def CatadioptricSensorRequirement {
		doc /* The sensor shall use a catadioptric optical system combining reflective and refractive elements. */
		
		subject sensorSystem : CatadioptricSensor;
		
		require constraint opticalSystemRequirement {
			sensorSystem.opticalSystem.primary.reflectivity >= 0.90 and
			sensorSystem.opticalSystem.secondary.reflectivity >= 0.90 and
			sensorSystem.opticalSystem.corrector.transmittance >= 0.95
		}
		
		require constraint detectorRequirement {
			sensorSystem.detector.quantumEfficiency >= 0.80 and
			sensorSystem.detector.pixelCount >= 1024
		}
	}
	
	requirement def MeasurementPerformanceRequirement {
		doc /* The sensing unit shall measure radiance with specified accuracy and precision. */
		
		subject unit : SensingUnit;
		
		require constraint accuracyRequirement {
			unit.measurementAccuracy >= 0.95
		}
		
		require constraint precisionRequirement {
			unit.measurementPrecision >= 0.98
		}
		
		require constraint responseTimeRequirement {
			unit.sensor.detector.readoutNoise <= 10.0
		}
	}
	
	requirement def SensingUnitRequirement {
		doc /* The sensing unit shall measure the relevant quantity using a catadioptric sensor. */
		
		subject sensingSystem : SensingUnit;
		
		require sensorReq : CatadioptricSensorRequirement {
			subject catadioptricSystem :>> sensorSystem = sensingSystem.sensor;
		}
		
		require performanceReq : MeasurementPerformanceRequirement {
			subject measuringUnit :>> unit = sensingSystem;
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitIdentifier = "UNIT-CATA-001";
		attribute :>> lastCalibrationDate = "2025-01-20";
		attribute :>> measurementAccuracy = 0.97;
		attribute :>> measurementPrecision = 0.99;
		
		part :>> sensor {
			attribute :>> operatingTemperatureRange = (273.15[K], 323.15[K]);
			attribute :>> spectralRange = (400.0[nm], 900.0[nm]);
			
			part :>> opticalSystem {
				part :>> primary {
					attribute :>> diameter = 250.0[mm];
					attribute :>> focalLength = 1000.0[mm];
					attribute :>> reflectivity = 0.97;
				}
				part :>> secondary {
					attribute :>> diameter = 75.0[mm];
					attribute :>> reflectivity = 0.95;
				}
				part :>> corrector {
					attribute :>> lensCount = 4;
					attribute :>> transmittance = 0.98;
				}
			}
			part :>> detector {
				attribute :>> pixelCount = 4096;
				attribute :>> quantumEfficiency = 0.90;
				attribute :>> readoutNoise = 3.5;
			}
			part :>> conditioner {
				attribute :>> gain = 150.0;
			}
		}
		
		satisfy unitReq : SensingUnitRequirement {
			subject systemUnderTest :>> sensingSystem = sensingUnitInstance;
		}
	}
}
