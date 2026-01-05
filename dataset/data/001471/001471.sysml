package InfraredSensorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def InfraredWavelengthValue :> LengthValue {
		doc /* Wavelength in the infrared spectrum, typically 0.75 to 1000 micrometers */
	}
	
	attribute def RadiantFluxValue :> PowerValue {
		doc /* Radiant power emitted, reflected, transmitted or received */
	}
	
	attribute def DetectorSensitivityValue :> Real {
		doc /* Normalized sensitivity coefficient of the detector element */
	}
	
	attribute def PixelCountValue :> Integer {
		doc /* Number of detector pixels in the focal plane array */
	}
	
	item def InfraredRadiation {
		attribute wavelength : InfraredWavelengthValue;
		attribute radiantFlux : RadiantFluxValue;
		attribute sourceTemperature : ThermodynamicTemperatureValue;
	}
	
	item def RawDetectorSignal {
		attribute voltageLevel : Real;
		attribute pixelIndex : PixelCountValue;
		attribute timestamp : TimeValue;
	}
	
	item def ProcessedThermalData {
		attribute temperatureMap : ThermodynamicTemperatureValue[*];
		attribute maxTemperature : ThermodynamicTemperatureValue;
		attribute minTemperature : ThermodynamicTemperatureValue;
		attribute averageTemperature : ThermodynamicTemperatureValue;
	}
	
	item def ThermalImage {
		attribute imageData : ProcessedThermalData;
		attribute resolution : PixelCountValue;
		attribute captureTime : TimeValue;
	}
	
	attribute def PowerOnCommand;
	attribute def PowerOffCommand;
	attribute def CaptureCommand;
	attribute def CalibrationCommand;
	attribute def ReadySignal;
	attribute def ImageReadySignal;
	
	port def InfraredInputPort {
		in item radiation : InfraredRadiation;
	}
	
	port def DetectorOutputPort {
		out item signal : RawDetectorSignal;
	}
	
	port def ProcessedDataPort {
		in item rawSignal : RawDetectorSignal;
		out item thermalData : ProcessedThermalData;
	}
	
	port def ImageOutputPort {
		out item image : ThermalImage;
	}
	
	port def PowerPort {
		in item powerSupply : PowerValue;
	}
	
	port def ControlPort {
		in item command : String;
		out item status : String;
	}
	
	part def FocalPlaneArray {
		doc /* Array of infrared detector elements that convert thermal radiation to electrical signals */
		
		attribute detectorCount : PixelCountValue;
		attribute sensitivity : DetectorSensitivityValue;
		attribute operatingTemperature : ThermodynamicTemperatureValue;
		
		port irInput : InfraredInputPort;
		port signalOutput : DetectorOutputPort;
		port powerInput : PowerPort;
		
		perform action detectRadiation {
			in radiation : InfraredRadiation;
			out detectorSignal : RawDetectorSignal;
		}
	}
	
	part def CryogenicCooler {
		doc /* Cooling system to maintain detector at cryogenic temperature for optimal sensitivity */
		
		attribute targetTemperature : ThermodynamicTemperatureValue;
		attribute coolingPower : PowerValue;
		attribute currentTemperature : ThermodynamicTemperatureValue;
		
		port powerInput : PowerPort;
		
		perform action maintainTemperature {
			in target : ThermodynamicTemperatureValue;
			in current : ThermodynamicTemperatureValue;
			out coolingOutput : PowerValue;
		}
	}
	
	part def SignalProcessingUnit {
		doc /* Digital processor that converts raw detector signals into calibrated temperature data */
		
		attribute processingSpeed : FrequencyValue;
		attribute calibrationCoefficients : Real[*];
		
		port dataInput : ProcessedDataPort;
		port powerInput : PowerPort;
		
		perform action processSignals {
			in rawData : RawDetectorSignal;
			out processedData : ProcessedThermalData;
		}
	}
	
	part def ImageFormationModule {
		doc /* Module that assembles processed data into displayable thermal images */
		
		attribute imageResolution : PixelCountValue;
		attribute frameRate : FrequencyValue;
		
		port thermalDataInput {
			in item data : ProcessedThermalData;
		}
		port imageOutput : ImageOutputPort;
		port powerInput : PowerPort;
		
		perform action generateImage {
			in thermalData : ProcessedThermalData;
			out thermalImage : ThermalImage;
		}
	}
	
	part def OpticalSystem {
		doc /* Lens assembly that focuses infrared radiation onto the focal plane array */
		
		attribute focalLength : LengthValue;
		attribute apertureDiameter : LengthValue;
		attribute fieldOfView : Real;
		
		port irInput : InfraredInputPort;
		port irOutput {
			out item focusedRadiation : InfraredRadiation;
		}
		port powerInput : PowerPort;
		
		perform action focusRadiation {
			in incomingRadiation : InfraredRadiation;
			out focusedRadiation : InfraredRadiation;
		}
	}
	
	part def PowerManagementUnit {
		doc /* Manages power distribution to all subsystems */
		
		attribute inputVoltage : Real;
		attribute totalPowerBudget : PowerValue;
		
		port powerInput {
			in item externalPower : PowerValue;
		}
		port powerOutput1 : PowerPort;
		port powerOutput2 : PowerPort;
		port powerOutput3 : PowerPort;
		port powerOutput4 : PowerPort;
		port powerOutput5 : PowerPort;
		
		perform action distributePower {
			in totalPower : PowerValue;
			out detectorPower : PowerValue;
			out coolerPower : PowerValue;
			out processorPower : PowerValue;
			out imagingPower : PowerValue;
			out opticsPower : PowerValue;
		}
	}
	
	action def CaptureInfraredImage {
		doc /* Complete sequence to capture and process a thermal image */
		
		in sceneRadiation : InfraredRadiation;
		out finalImage : ThermalImage;
		
		action focusScene {
			in radiation : InfraredRadiation;
			out focused : InfraredRadiation;
		}
		flow focusScene.focused to detectScene.radiation;
		
		action detectScene {
			in radiation : InfraredRadiation;
			out rawSignals : RawDetectorSignal;
		}
		flow detectScene.rawSignals to processSignals.rawData;
		
		action processSignals {
			in rawData : RawDetectorSignal;
			out thermalData : ProcessedThermalData;
		}
		flow processSignals.thermalData to formImage.thermalData;
		
		action formImage {
			in thermalData : ProcessedThermalData;
			out image : ThermalImage;
		}
	}
	
	action def CalibrateSystem {
		doc /* Calibration procedure using reference temperature sources */
		
		in referenceTemperature : ThermodynamicTemperatureValue;
		out calibrationFactors : Real[*];
		
		action measureReference {
			in refTemp : ThermodynamicTemperatureValue;
			out measurement : RawDetectorSignal;
		}
		
		action computeCalibration {
			in measurements : RawDetectorSignal;
			in knownTemp : ThermodynamicTemperatureValue;
			out factors : Real[*];
		}
		
		flow measureReference.measurement to computeCalibration.measurements;
	}
	
	state def InfraredSystemStates {
		entry; then off;
		
		state off {
			doc /* System is powered down */
		}
		
		transition off_to_initializing
			first off
			accept powerOn : PowerOnCommand
			then initializing;
		
		state initializing {
			doc /* System is powering up and cooling detector */
			entry action coolDown;
			do action monitorTemperature;
		}
		
		state calibrating {
			doc /* System is performing calibration routine */
			entry action performCalibration : CalibrateSystem;
		}
		
		state ready {
			doc /* System is ready to capture images */
			do action maintainTemperature;
		}
		
		state capturing {
			doc /* System is actively capturing and processing thermal image */
			entry action captureImage : CaptureInfraredImage;
		}
	}
	
	part def InfraredSensorSystem {
		doc /* 
		 * An infrared sensor system that detects thermal radiation from objects 
		 * and converts it into visual thermal images. The system operates by 
		 * focusing infrared radiation onto a cooled detector array, processing 
		 * the electrical signals, and generating calibrated temperature maps.
		 */
		
		attribute systemOperatingWavelength : InfraredWavelengthValue;
		attribute detectorOperatingTemp : ThermodynamicTemperatureValue;
		attribute imageResolution : PixelCountValue;
		attribute systemPowerConsumption : PowerValue;
		attribute detectorAtOperatingTemp : Boolean;
		attribute calibrationComplete : Boolean;
		attribute imageCaptureComplete : Boolean;
		
		part optics : OpticalSystem;
		part fpa : FocalPlaneArray;
		part cooler : CryogenicCooler;
		part processor : SignalProcessingUnit;
		part imaging : ImageFormationModule;
		part powerMgmt : PowerManagementUnit;
		
		port sceneInput : InfraredInputPort;
		port imageOutput : ImageOutputPort;
		port systemPower {
			in item externalPower : PowerValue;
		}
		port control : ControlPort;
		
		connection opticsToFPA connect optics.irOutput to fpa.irInput;
		connection fpaToProcessor connect fpa.signalOutput to processor.dataInput;
		connection processorToImaging connect processor.dataInput to imaging.thermalDataInput;
		connection imagingToOutput connect imaging.imageOutput to imageOutput;
		
		connection powerToOptics connect powerMgmt.powerOutput1 to optics.powerInput;
		connection powerToFPA connect powerMgmt.powerOutput2 to fpa.powerInput;
		connection powerToCooler connect powerMgmt.powerOutput3 to cooler.powerInput;
		connection powerToProcessor connect powerMgmt.powerOutput4 to processor.powerInput;
		connection powerToImaging connect powerMgmt.powerOutput5 to imaging.powerInput;
		
		perform action operateSystem {
			first start;
			then merge awaitPower;
			
			accept powerOnCmd : PowerOnCommand;
			then action initializeSystem {
				action startCooling : cooler.maintainTemperature {
					in target = cooler.targetTemperature;
					in current = cooler.currentTemperature;
					out coolingOutput;
				}
			}
			then assign detectorAtOperatingTemp := true;
			
			then action calibrateSystem : CalibrateSystem {
				in referenceTemperature = 300.0 [K];
				out calibrationFactors;
			}
			then assign calibrationComplete := true;
			
			then merge readyLoop;
			
			action captureLoop {
				accept captureCmd : CaptureCommand;
				then action acquireImage : CaptureInfraredImage {
					in sceneRadiation;
					out finalImage;
				}
				then assign imageCaptureComplete := true;
				then readyLoop;
			}
			
			accept powerOffCmd : PowerOffCommand;
			then done;
		}
	}
	
	part infraredSensorSystem : InfraredSensorSystem {
		attribute systemOperatingWavelength = 10.0e-6 [m];
		attribute detectorOperatingTemp = 77.0 [K];
		attribute imageResolution = 640;
		attribute systemPowerConsumption = 25.0 [W];
		attribute detectorAtOperatingTemp = false;
		attribute calibrationComplete = false;
		attribute imageCaptureComplete = false;
		
		part optics : OpticalSystem {
			attribute focalLength = 50.0e-3 [m];
			attribute apertureDiameter = 25.0e-3 [m];
			attribute fieldOfView = 30.0;
		}
		
		part fpa : FocalPlaneArray {
			attribute detectorCount = 640;
			attribute sensitivity = 0.98;
			attribute operatingTemperature = 77.0 [K];
		}
		
		part cooler : CryogenicCooler {
			attribute targetTemperature = 77.0 [K];
			attribute coolingPower = 5.0 [W];
			attribute currentTemperature = 293.0 [K];
		}
		
		part processor : SignalProcessingUnit {
			attribute processingSpeed = 100.0e6 [Hz];
		}
		
		part imaging : ImageFormationModule {
			attribute imageResolution = 640;
			attribute frameRate = 30.0 [Hz];
		}
		
		part powerMgmt : PowerManagementUnit {
			attribute inputVoltage = 12.0;
			attribute totalPowerBudget = 25.0 [W];
		}
	}
	
	requirement <'IR-REQ-001'> primaryFunctionRequirement {
		doc /* 
		 * The infrared sensor system shall detect thermal radiation from objects 
		 * in its field of view and convert this radiation into calibrated thermal 
		 * images that represent the temperature distribution of the scene.
		 */
		
		subject infraredSensorSystem;
		
		require constraint wavelengthRange {
			infraredSensorSystem.systemOperatingWavelength >= 8.0e-6 [m] and
			infraredSensorSystem.systemOperatingWavelength <= 14.0e-6 [m]
		}
		
		require constraint imageQuality {
			infraredSensorSystem.imageResolution >= 320
		}
	}
	
	requirement <'IR-REQ-002'> detectorPerformanceRequirement {
		doc /* 
		 * The focal plane array shall operate at cryogenic temperature to 
		 * achieve the required sensitivity for thermal imaging applications.
		 */
		
		subject infraredSensorSystem.fpa;
		
		require constraint operatingTemperature {
			infraredSensorSystem.fpa.operatingTemperature <= 80.0 [K]
		}
		
		require constraint detectorSensitivity {
			infraredSensorSystem.fpa.sensitivity >= 0.95
		}
	}
	
	requirement <'IR-REQ-003'> systemOperationRequirement {
		doc /* 
		 * The system shall initialize, calibrate, and continuously capture 
		 * thermal images while maintaining detector temperature and processing 
		 * signals in real-time.
		 */
		
		subject infraredSensorSystem;
		
		assume constraint powerAvailable {
			infraredSensorSystem.systemPowerConsumption <= 30.0 [W]
		}
		
		require constraint frameRate {
			infraredSensorSystem.imaging.frameRate >= 25.0 [Hz]
		}
		
		require constraint calibrationAccuracy {
			infraredSensorSystem.calibrationComplete == true
		}
	}
	
	requirement <'IR-REQ-004'> opticalSystemRequirement {
		doc /* 
		 * The optical system shall focus infrared radiation onto the focal 
		 * plane array with sufficient field of view and aperture for the 
		 * intended application.
		 */
		
		subject infraredSensorSystem.optics;
		
		require constraint fieldOfView {
			infraredSensorSystem.optics.fieldOfView >= 20.0
		}
		
		require constraint aperture {
			infraredSensorSystem.optics.apertureDiameter >= 20.0e-3 [m]
		}
	}
	
	requirement <'IR-REQ-005'> thermalManagementRequirement {
		doc /* 
		 * The cryogenic cooler shall maintain the focal plane array at the 
		 * required operating temperature throughout system operation.
		 */
		
		subject infraredSensorSystem.cooler;
		
		require constraint coolingCapacity {
			infraredSensorSystem.cooler.coolingPower >= 3.0 [W]
		}
		
		require constraint temperatureStability {
			infraredSensorSystem.detectorAtOperatingTemp == true
		}
	}
}
