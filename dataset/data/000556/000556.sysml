package BorescopyInspectionSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def InspectionStatus {
		attribute code : String;
		attribute timestamp : TimeValue;
	}

	item def ImageFrame {
		attribute resolution : Integer;
		attribute brightness : Real;
		attribute timestamp : TimeValue;
	}

	item def IlluminationControl {
		attribute intensity : Real;
		attribute colorTemperature : ThermodynamicTemperatureValue;
	}

	item def ProbePosition {
		attribute insertionDepth : LengthValue;
		attribute articulationAngle : Real;
		attribute rotationAngle : Real;
	}

	item def DefectData {
		attribute defectType : String;
		attribute location : ProbePosition;
		attribute severity : String;
		attribute dimensions : LengthValue;
	}

	port def ImagePort {
		out item imageStream : ImageFrame;
	}

	port def LightControlPort {
		in item lightCommand : IlluminationControl;
	}

	port def PositionControlPort {
		in item positionCommand : ProbePosition;
		out item currentPosition : ProbePosition;
	}

	port def DataPort {
		out item inspectionData : DefectData;
	}

	part def InsertionProbe {
		attribute probeLength : LengthValue;
		attribute outerDiameter : LengthValue;
		attribute articulationRange : Real;
		attribute workingChannelDiameter : LengthValue;

		port imageOutput : ImagePort;
		port lightControl : LightControlPort;
		port positionControl : PositionControlPort;

		part imagingSensor {
			attribute sensorResolution : Integer;
			attribute fieldOfView : Real;
			perform action captureFrame {
				out frame : ImageFrame;
			}
		}

		part ledIllumination {
			attribute maxIntensity : LuminousIntensityValue;
			attribute currentIntensity : Real;
			perform action setIllumination {
				in command : IlluminationControl;
			}
		}

		part articulationMechanism {
			attribute currentAngle : Real;
			attribute maxBendAngle : Real;
			perform action articulate {
				in targetAngle : Real;
				out achievedAngle : Real;
			}
		}

		part insertionTube {
			attribute flexibility : Real;
			attribute bendRadius : LengthValue;
		}
	}

	part def ProcessingUnit {
		port imageInput {
			in item rawImage : ImageFrame;
		}
		port processedOutput {
			out item enhancedImage : ImageFrame;
		}

		perform action enhanceImage {
			in inputFrame : ImageFrame;
			out outputFrame : ImageFrame;
		}

		perform action detectDefects {
			in processedFrame : ImageFrame;
			out detectedDefects : DefectData[*];
		}
	}

	part def AnalysisModule {
		port analysisInput {
			in item imageData : ImageFrame;
		}
		port defectOutput {
			out item defects : DefectData;
		}

		perform action analyzeImage {
			in image : ImageFrame;
			out defectList : DefectData[*];
		}

		perform action classifyDefect {
			in defect : DefectData;
			out classification : String;
		}
	}

	part def DisplayConsole {
		attribute screenDiagonal : LengthValue;
		attribute displayResolution : Integer;

		port videoInput {
			in item liveVideo : ImageFrame;
		}
		port defectInput {
			in item defectInfo : DefectData;
		}

		perform action renderDisplay {
			in videoStream : ImageFrame;
			in defectOverlay : DefectData[*];
		}
	}

	part def OperatorInterface {
		port probeControl {
			out item probeCommand : ProbePosition;
		}
		port illuminationControl {
			out item lightCommand : IlluminationControl;
		}

		perform action handleInput {
			in userCommand : String;
			out probePosition : ProbePosition;
			out lightSetting : IlluminationControl;
		}
	}

	part def RecordingSystem {
		attribute storageCapacity : Real;
		attribute recordingFormat : String;

		port dataInput {
			in item imageData : ImageFrame;
			in item defectData : DefectData;
		}

		perform action recordSession {
			in images : ImageFrame[*];
			in defects : DefectData[*];
			out sessionFile : String;
		}
	}

	action def PerformInspection {
		first start;

		then action initialize {
			out systemReady : Boolean;
		}

		then action insertProbe {
			in targetDepth : LengthValue;
			out inserted : Boolean;
		}

		then action enableIllumination {
			in intensity : Real;
			out illuminated : Boolean;
		}

		then merge inspectionCycle;

		then action acquireImage {
			out capturedFrame : ImageFrame;
		}

		then action enhanceImage {
			in rawFrame : ImageFrame;
			out enhancedFrame : ImageFrame;
		}

		then action analyzeFrame {
			in processedFrame : ImageFrame;
			out foundDefects : DefectData[*];
		}

		then action displayLive {
			in videoFrame : ImageFrame;
			in defectMarkers : DefectData[*];
		}

		then action saveData {
			in frameData : ImageFrame;
			in defectData : DefectData[*];
		}

		then decide;
			if inspectionComplete then finalize;
			if continueScanning then adjustProbe;

		action adjustProbe {
			in newPosition : ProbePosition;
			out repositioned : Boolean;
		}
		then inspectionCycle;

		action finalize {
			out finalReport : DefectData[*];
		}

		then action retractProbe {
			out retracted : Boolean;
		}

		then done;

		private attribute inspectionComplete : Boolean;
		private attribute continueScanning : Boolean;
	}

	state def InspectionStates {
		entry; then idle;
		
		state idle;
		accept powerOn
		then preparing;
		
		state preparing;
		accept systemReady
		then inserting;
		
		state inserting;
		accept probeInserted
		then scanning;
		
		state scanning;
		accept imageAcquired
		then analyzing;
		
		state analyzing;
		accept analysisComplete
		then recording;
		
		state recording;
		accept continueInspection
		then scanning;
		accept inspectionComplete
		then retracting;
		
		state retracting;
		accept probeRetracted
		then idle;
	}

	part inspectionProbe : InsertionProbe {
		attribute :>> probeLength = 1.2 [m];
		attribute :>> outerDiameter = 6.0 [mm];
		attribute :>> articulationRange = 120.0;
		attribute :>> workingChannelDiameter = 2.0 [mm];
	}

	part processor : ProcessingUnit;
	part analyzer : AnalysisModule;
	part console : DisplayConsole {
		attribute :>> screenDiagonal = 10.0 [in];
		attribute :>> displayResolution = 1920;
	}
	part controls : OperatorInterface;
	part recorder : RecordingSystem {
		attribute :>> storageCapacity = 512.0;
		attribute :>> recordingFormat = "MP4";
	}

	part borescopeSystem {
		ref part probe : InsertionProbe = inspectionProbe;
		ref part imageProcessor : ProcessingUnit = processor;
		ref part defectAnalyzer : AnalysisModule = analyzer;
		ref part displayUnit : DisplayConsole = console;
		ref part operatorControls : OperatorInterface = controls;
		ref part dataRecorder : RecordingSystem = recorder;

		perform action inspection : PerformInspection;
		exhibit state operatingStates : InspectionStates;

		connection probeToProcessor connect
			probe.imageOutput.imageStream to imageProcessor.imageInput.rawImage;

		connection processorToAnalyzer connect
			imageProcessor.processedOutput.enhancedImage to defectAnalyzer.analysisInput.imageData;

		connection analyzerToDisplay connect
			defectAnalyzer.defectOutput.defects to displayUnit.defectInput.defectInfo;

		connection probeToDisplay connect
			probe.imageOutput.imageStream to displayUnit.videoInput.liveVideo;

		connection controlsToProbe connect
			operatorControls.probeControl.probeCommand to probe.positionControl.positionCommand;

		connection controlsToLight connect
			operatorControls.illuminationControl.lightCommand to probe.lightControl.lightCommand;

		connection imageToRecorder connect
			probe.imageOutput.imageStream to dataRecorder.dataInput.imageData;

		connection defectToRecorder connect
			defectAnalyzer.defectOutput.defects to dataRecorder.dataInput.defectData;
	}

	requirement def VisualInspectionCapability {
		doc /* The borescope system shall provide real-time visual inspection of internal 
		       surfaces, cavities, and confined spaces that are inaccessible to direct 
		       human observation. */

		subject inspectionSystem : InsertionProbe;

		require constraint accessConstraint {
			doc /* The probe shall access confined spaces with minimum clearance of 6mm diameter. */
		}

		require constraint imagingConstraint {
			doc /* The system shall capture and display high-resolution images at minimum 30 frames per second. */
		}

		require constraint articulationConstraint {
			doc /* The probe tip shall articulate at least 120 degrees in all directions. */
		}
	}

	requirement def DefectIdentificationCapability {
		doc /* The system shall detect, identify, classify, and document surface defects 
		       including cracks, corrosion, erosion, foreign object debris, and material degradation. */

		subject analysisSystem : AnalysisModule;

		require constraint detectionSensitivity {
			doc /* The system shall detect defects with minimum dimension of 0.3mm under adequate illumination. */
		}

		require constraint classificationAccuracy {
			doc /* Defect classification accuracy shall exceed 90% for trained defect types. */
		}
	}

	requirement <'BRS-SYS-001'> primaryInspectionRequirement : VisualInspectionCapability {
		doc /* Primary functional requirement for borescope inspection system capability. */

		assume constraint environmentalConditions {
			doc /* System operates in temperature range -10°C to 80°C and humidity up to 95% non-condensing. */
		}

		require defectCapability : DefectIdentificationCapability;
	}

	requirement <'BRS-SYS-002'> documentationRequirement {
		doc /* The system shall record and store all inspection data including video, still images, 
		       defect annotations, probe position history, and operator notes for compliance documentation 
		       and post-inspection analysis. */

		subject recordingSystem : RecordingSystem;

		require constraint storageCapacity {
			doc /* The system shall store minimum 4 hours of continuous inspection video at full resolution. */
		}

		require constraint dataIntegrity {
			doc /* Recorded data shall include timestamp, probe position, and illumination settings for each frame. */
		}
	}

	requirement <'BRS-SYS-003'> operatorInterfaceRequirement {
		doc /* The system shall provide intuitive operator controls for probe manipulation, 
		       illumination adjustment, image capture, and defect annotation during live inspection. */

		subject operatorInterface : OperatorInterface;
	}
}
