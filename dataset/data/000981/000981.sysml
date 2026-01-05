package AutomaticNumberPlateRecognitionSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PlateNumber {
		attribute country : String;
		attribute region : String;
		attribute characters : String;
		attribute confidence : Real;
	}
	
	attribute def ImageMetadata {
		attribute width : Integer;
		attribute height : Integer;
		attribute timestamp : DurationValue;
		attribute format : String;
	}
	
	item def RawImage {
		attribute imageMetadata : ImageMetadata;
		attribute data : String;
	}
	
	item def ProcessedImage {
		attribute imageMetadata : ImageMetadata;
		attribute plateRegion : String;
		attribute enhanced : Boolean;
	}
	
	item def RecognitionResult {
		attribute plateNumber : PlateNumber;
		attribute processingTime : DurationValue;
		attribute valid : Boolean;
		attribute timestamp : DurationValue;
	}
	
	item def VehicleRecord {
		attribute plateNumber : PlateNumber;
		attribute captureTime : DurationValue;
		attribute location : String;
		attribute vehicleSpeed : SpeedValue;
	}
	
	item def TriggerSignal;
	item def ImageCaptureCommand;
	item def ProcessingCommand;
	
	port def ImageInputPort {
		in item rawImage : RawImage;
	}
	
	port def ImageOutputPort {
		out item processedImage : ProcessedImage;
	}
	
	port def RecognitionOutputPort {
		out item result : RecognitionResult;
	}
	
	port def DatabasePort {
		out item record : VehicleRecord;
		in item confirmation : Boolean;
	}
	
	part def Camera {
		attribute resolution : Integer;
		attribute frameRate : Real;
		attribute fieldOfView : Real;
		
		port imageOut : ImageOutputPort;
		port commandIn;
		
		perform action captureImage {
			in command : ImageCaptureCommand;
			out image : RawImage;
		}
	}
	
	part def IlluminationUnit {
		attribute intensity : LuminousIntensityValue;
		attribute wavelength : LengthValue;
		
		port controlIn;
		
		perform action illuminate {
			in trigger : TriggerSignal;
			out lightOutput : LuminousIntensityValue;
		}
	}
	
	part def VehicleDetector {
		attribute detectionRange : LengthValue;
		attribute sensitivity : Real;
		
		port triggerOut;
		
		perform action detectVehicle {
			out trigger : TriggerSignal;
		}
	}
	
	part def ImageProcessor {
		port imageIn : ImageInputPort;
		port imageOut : ImageOutputPort;
		
		perform action processImage {
			in rawImage : RawImage;
			out processedImage : ProcessedImage;
			
			first start;
			then action enhanceContrast {
				in image : RawImage = rawImage;
				out enhanced : RawImage;
			}
			then action detectPlateRegion {
				in enhanced : RawImage = enhanceContrast.enhanced;
				out region : String;
			}
			then action extractPlate {
				in region : String = detectPlateRegion.region;
				out plateImage : ProcessedImage;
			}
			then done;
		}
	}
	
	part def OCREngine {
		attribute recognitionAccuracy : Real;
		
		port dataIn : ImageInputPort;
		port dataOut : RecognitionOutputPort;
		
		perform action recognizeCharacters {
			in plateImage : ProcessedImage;
			out result : RecognitionResult;
			
			first start;
			then action segmentCharacters {
				in image : ProcessedImage = plateImage;
				out segments : Integer;
			}
			then action classifyCharacters {
				in segments : Integer = segmentCharacters.segments;
				out recognizedText : String;
			}
			then action validateFormat {
				in text : String = classifyCharacters.recognizedText;
				out isValid : Boolean;
				out plateNumber : PlateNumber;
			}
			then action calculateConfidence {
				in plateNumber : PlateNumber = validateFormat.plateNumber;
				out finalResult : RecognitionResult;
			}
			then done;
		}
	}
	
	part def DatabaseManager {
		port dbPort : DatabasePort;
		
		perform action storeRecord {
			in record : VehicleRecord;
			out success : Boolean;
		}
		
		perform action queryRecord {
			in plateNumber : PlateNumber;
			out found : Boolean;
		}
	}
	
	part def ControlUnit {
		attribute operatingMode : String;
		
		port detectorIn;
		port cameraControl;
		port illuminationControl;
		port processorControl;
		port ocrControl;
		port databaseControl;
		
		perform action controlOperation {
			first start;
			then action idle;
			then action detecting;
			then action capturing;
			then action processing;
			then action recognizing;
			then action validating;
			then action storing;
			then done;
		}
	}
	
	part def ANPRSystem;
	
	part anprSystem : ANPRSystem {
		attribute systemId : String;
		attribute location : String;
		attribute operationalStatus : Boolean;
		
		port externalTrigger;
		port resultOutput : RecognitionOutputPort;
		port databaseInterface : DatabasePort;
		
		part detector : VehicleDetector {
			attribute :>> detectionRange = 50.0 [m];
			attribute :>> sensitivity = 0.95;
		}
		
		part camera : Camera {
			attribute :>> resolution = 1920;
			attribute :>> frameRate = 30.0;
			attribute :>> fieldOfView = 45.0;
		}
		
		part illumination : IlluminationUnit {
			attribute :>> intensity = 1000.0 [cd];
			attribute :>> wavelength = 850.0e-9 [m];
		}
		
		part processor : ImageProcessor;
		
		part ocrEngine : OCREngine {
			attribute :>> recognitionAccuracy = 0.98;
		}
		
		part database : DatabaseManager;
		
		part controller : ControlUnit {
			attribute :>> operatingMode = "automatic";
		}
		
		connection detectorToController connect detector.triggerOut to controller.detectorIn;
		connection controllerToCamera connect controller.cameraControl to camera.commandIn;
		connection controllerToIllumination connect controller.illuminationControl to illumination.controlIn;
		connection cameraToProcessor connect camera.imageOut to processor.imageIn;
		connection processorToOCR connect processor.imageOut to ocrEngine.dataIn;
		connection ocrToController connect ocrEngine.dataOut to controller.ocrControl;
		connection controllerToDatabase connect controller.databaseControl to database.dbPort;
		connection databaseToExternal connect database.dbPort to databaseInterface;
		connection ocrToExternal connect ocrEngine.dataOut to resultOutput;
	}
	
	action def CaptureAndRecognizePlate {
		in triggerSignal : TriggerSignal;
		out vehicleRecord : VehicleRecord;
		
		first start;
		then merge waitForTrigger;
		
		action waitForTrigger {
			in trigger : TriggerSignal = triggerSignal;
		}
		then decide;
			if triggerSignal then activateSystem;
			if not triggerSignal then waitForTrigger;
		
		action activateSystem {
			out activationComplete : Boolean;
		}
		then captureImage;
		
		action captureImage {
			out rawImage : RawImage;
		}
		then processImage;
		
		action processImage {
			in image : RawImage = captureImage.rawImage;
			out processedImage : ProcessedImage;
		}
		then recognizeCharacters;
		
		action recognizeCharacters {
			in plateImage : ProcessedImage = processImage.processedImage;
			out result : RecognitionResult;
		}
		then validateResult;
		
		action validateResult {
			in result : RecognitionResult = recognizeCharacters.result;
			out isValid : Boolean;
		}
		then decide;
			if validateResult.isValid then storeRecord;
			if not validateResult.isValid then waitForTrigger;
		
		action storeRecord {
			in result : RecognitionResult = recognizeCharacters.result;
			out record : VehicleRecord = vehicleRecord;
		}
		then done;
	}
	
	occurrence def ANPRInteraction {
		ref part system : ANPRSystem;
		
		message vehicleDetectedMessage of TriggerSignal
			from system.detector.triggerOut to system.controller.detectorIn;
		
		then message captureCommandMessage of ImageCaptureCommand
			from system.controller.cameraControl to system.camera.commandIn;
		
		then message illuminationCommandMessage of TriggerSignal
			from system.controller.illuminationControl to system.illumination.controlIn;
		
		then message rawImageMessage of RawImage
			from system.camera.imageOut to system.processor.imageIn;
		
		then message processedImageMessage of ProcessedImage
			from system.processor.imageOut to system.ocrEngine.dataIn;
		
		then message recognitionResultMessage of RecognitionResult
			from system.ocrEngine.dataOut to system.controller.ocrControl;
		
		then message storeRecordMessage of vehicleRecord : VehicleRecord
			from system.controller.databaseControl to system.database.dbPort;
		
		then message confirmationMessage of Boolean
			from system.database.dbPort to system.controller.databaseControl;
	}
	
	requirement def ANPRSystemRequirements {
		doc /* Requirements for Automatic Number Plate Recognition System */
		
		requirement <'1'> recognitionAccuracyRequirement {
			doc /* The system shall achieve a minimum recognition accuracy of 95% under normal lighting conditions. */
			subject anprSystem : ANPRSystem;
			require constraint {
				anprSystem.ocrEngine.recognitionAccuracy >= 0.95
			}
		}
		
		requirement <'2'> processingTimeRequirement {
			doc /* The system shall process and recognize a license plate within 500 milliseconds from image capture. */
		}
		
		requirement <'3'> operationalAvailabilityRequirement {
			doc /* The system shall maintain 99.5% operational availability during scheduled operating hours. */
		}
		
		requirement <'4'> imageQualityRequirement {
			doc /* The system shall capture images with minimum resolution of 1920x1080 pixels at 30 frames per second. */
			subject camera : Camera;
			require constraint {
				camera.resolution >= 1920 and camera.frameRate >= 30.0
			}
		}
		
		requirement <'5'> detectionRangeRequirement {
			doc /* The vehicle detector shall detect approaching vehicles at a minimum range of 50 meters. */
			subject detector : VehicleDetector;
			require constraint {
				detector.detectionRange >= 50.0 [m]
			}
		}
	}
	
	requirement primaryFunction {
		doc /* 
		The primary function of the Automatic Number Plate Recognition (ANPR) system is to 
		automatically detect, capture, and recognize vehicle license plate numbers from images 
		in real-time. The system detects approaching vehicles, captures high-quality images of 
		their license plates using a camera and illumination unit, processes these images to 
		locate and extract license plate regions, performs optical character recognition to 
		convert the plate image into alphanumeric text, validates the recognized characters 
		against known plate formats, and stores the results with associated metadata including 
		timestamp, location, and vehicle speed for law enforcement, toll collection, parking 
		management, or traffic monitoring applications.
		*/
		
		assume constraint normalOperatingConditions {
			doc /* System operates under adequate lighting and weather conditions with vehicles traveling at speeds up to 200 km/h. */
		}
		
		require ANPRSystemRequirements::recognitionAccuracyRequirement;
		require ANPRSystemRequirements::processingTimeRequirement;
		require ANPRSystemRequirements::operationalAvailabilityRequirement;
		require ANPRSystemRequirements::imageQualityRequirement;
		require ANPRSystemRequirements::detectionRangeRequirement;
	}
}
