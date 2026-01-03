package VideoscopeSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ImageResolution {
		attribute width : Natural;
		attribute height : Natural;
	}
	
	attribute def IlluminationIntensity :> Real;
	
	item def VideoFrame {
		attribute resolution : ImageResolution;
		attribute timestamp : TimeValue;
		attribute brightness : IlluminationIntensity;
		attribute frameNumber : Natural;
	}
	
	item def InspectionCommand {
		attribute insertionDepth : LengthValue;
		attribute illuminationLevel : IlluminationIntensity;
		attribute articulationAngle : AngleValue;
	}
	
	item def InspectionData {
		attribute frames : VideoFrame[*];
		attribute defectsDetected : Boolean;
		attribute imageQualityScore : Real;
	}
	
	port def VideoOutputPort {
		out item videoSignal : VideoFrame;
	}
	
	port def ControlInputPort {
		in item command : InspectionCommand;
	}
	
	port def IlluminationPort {
		attribute intensity : IlluminationIntensity;
	}
	
	port def PowerPort {
		attribute voltage : VoltageValue;
		attribute current : ElectricCurrentValue;
	}
	
	part def LEDLightSource {
		port illuminationOut : IlluminationPort;
		port powerIn : PowerPort;
		attribute maxIntensity : IlluminationIntensity;
		attribute currentIntensity : IlluminationIntensity;
		
		action def SetIllumination {
			in targetIntensity : IlluminationIntensity;
			out actualIntensity : IlluminationIntensity;
		}
	}
	
	part def CMOSImageSensor {
		port videoOut : VideoOutputPort;
		port powerIn : PowerPort;
		attribute sensorResolution : ImageResolution;
		attribute frameRate : FrequencyValue;
		
		action def CaptureFrame {
			in ambientLight : IlluminationIntensity;
			out frame : VideoFrame;
		}
	}
	
	part def ArticulationMechanism {
		attribute currentAngle : AngleValue;
		attribute maxAngle : AngleValue;
		
		action def Articulate {
			in targetAngle : AngleValue;
			out achievedAngle : AngleValue;
		}
	}
	
	part def FlexibleInsertionTube {
		attribute length : LengthValue;
		attribute outerDiameter : LengthValue;
		attribute bendRadius : LengthValue;
		
		part ledLight : LEDLightSource {
			attribute :>> maxIntensity = 100.0;
		}
		
		part imageSensor : CMOSImageSensor {
			attribute :>> sensorResolution = ImageResolution {
				attribute :>> width = 1920;
				attribute :>> height = 1080;
			}
			attribute :>> frameRate = 30.0[Hz];
		}
		
		part articulation : ArticulationMechanism {
			attribute :>> maxAngle = 180.0[deg];
		}
		
		connect ledLight.illuminationOut to imageSensor.powerIn;
	}
	
	part def VideoProcessingUnit {
		port videoIn : ~VideoOutputPort;
		port videoOut : VideoOutputPort;
		
		action def ProcessVideo {
			in rawFrame : VideoFrame;
			out processedFrame : VideoFrame;
		}
		
		action def EnhanceImage {
			in frame : VideoFrame;
			out enhancedFrame : VideoFrame;
			out qualityScore : Real;
		}
		
		action def DetectDefects {
			in frame : VideoFrame;
			out defectsFound : Boolean;
		}
	}
	
	part def ControlConsole {
		port controlOut : ControlInputPort;
		port videoIn : ~VideoOutputPort;
		
		attribute operatorInput : InspectionCommand;
		
		action def IssueCommand {
			out command : InspectionCommand;
		}
	}
	
	part def DisplayMonitor {
		port videoIn : ~VideoOutputPort;
		attribute screenResolution : ImageResolution;
		attribute screenSize : LengthValue;
		
		action def DisplayFrame {
			in frame : VideoFrame;
		}
	}
	
	part def PowerSupply {
		port powerOut : PowerPort;
		attribute outputVoltage : VoltageValue;
		attribute maxCurrent : ElectricCurrentValue;
	}
	
	part def Videoscope {
		part insertionTube : FlexibleInsertionTube {
			attribute :>> length = 2.5[m];
			attribute :>> outerDiameter = 6.0[mm];
			attribute :>> bendRadius = 35.0[mm];
		}
		
		part processor : VideoProcessingUnit;
		part console : ControlConsole;
		part monitor : DisplayMonitor {
			attribute :>> screenResolution = ImageResolution {
				attribute :>> width = 1280;
				attribute :>> height = 720;
			}
			attribute :>> screenSize = 10.0[in];
		}
		
		part power : PowerSupply {
			attribute :>> outputVoltage = 12.0[V];
			attribute :>> maxCurrent = 2.0[A];
		}
		
		connect power.powerOut to insertionTube.ledLight.powerIn;
		connect power.powerOut to insertionTube.imageSensor.powerIn;
		connect insertionTube.imageSensor.videoOut to processor.videoIn;
		connect processor.videoOut to console.videoIn;
		connect processor.videoOut to monitor.videoIn;
		
		perform action executeInspection[*] ordered references performInspection;
	}
	
	action def PerformInspection {
		first start;
		
		then action receiveCommand {
			out cmd : InspectionCommand;
		}
		
		then action insertProbe {
			in targetDepth : LengthValue = receiveCommand.cmd.insertionDepth;
		}
		
		then action setArticulation {
			in angle : AngleValue = receiveCommand.cmd.articulationAngle;
			out actualAngle : AngleValue;
		}
		
		then action activateLight {
			in intensity : IlluminationIntensity = receiveCommand.cmd.illuminationLevel;
			out activeIntensity : IlluminationIntensity;
		}
		
		then merge captureLoop;
		
		action captureLoop;
		
		then action captureImage {
			in lightLevel : IlluminationIntensity = activateLight.activeIntensity;
			out rawFrame : VideoFrame;
		}
		
		then action processImage {
			in inputFrame : VideoFrame = captureImage.rawFrame;
			out outputFrame : VideoFrame;
		}
		
		then action enhanceImage {
			in frame : VideoFrame = processImage.outputFrame;
			out enhanced : VideoFrame;
			out quality : Real;
		}
		
		then action detectDefects {
			in frame : VideoFrame = enhanceImage.enhanced;
			out defects : Boolean;
		}
		
		then action displayImage {
			in frame : VideoFrame = enhanceImage.enhanced;
		}
		
		then decide evaluateCondition;
			if enhanceImage.quality >= 0.75 and not detectDefects.defects then continueCycle;
			if enhanceImage.quality < 0.75 or detectDefects.defects then finishInspection;
		
		action continueCycle;
		then captureLoop;
		
		action finishInspection {
			out inspectionData : InspectionData;
		}
		
		then action retractProbe;
		
		then action generateReport {
			in data : InspectionData = finishInspection.inspectionData;
		}
		
		then done;
	}
	
	part videoscopeSystem : Videoscope {
		perform action inspection : PerformInspection {
			first start;
			then receiveCommand;
			then insertProbe;
			then setArticulation;
			then activateLight;
			then captureLoop;
			then captureImage;
			then processImage;
			then enhanceImage;
			then detectDefects;
			then displayImage;
			then evaluateCondition;
			then continueCycle;
			then finishInspection;
			then retractProbe;
			then generateReport;
			then done;
		}
		
		part :>> insertionTube {
			perform inspection.insertProbe;
			perform inspection.retractProbe;
			
			part :>> ledLight {
				perform inspection.activateLight;
			}
			
			part :>> imageSensor {
				perform inspection.captureImage;
			}
			
			part :>> articulation {
				perform inspection.setArticulation;
			}
		}
		
		part :>> processor {
			perform inspection.processImage;
			perform inspection.enhanceImage;
			perform inspection.detectDefects;
		}
		
		part :>> console {
			perform inspection.receiveCommand;
			perform inspection.generateReport;
		}
		
		part :>> monitor {
			perform inspection.displayImage;
		}
	}
	
	requirement def ImageQualityRequirement {
		doc /* The videoscope shall provide sufficient image quality for accurate defect detection. */
		
		require constraint {
			videoscopeSystem.processor.EnhanceImage.qualityScore >= 0.75
		}
	}
	
	requirement def IlluminationRequirement {
		doc /* The videoscope shall provide adjustable illumination to ensure visibility in varying conditions. */
		
		require constraint {
			videoscopeSystem.insertionTube.ledLight.currentIntensity >= 0.0 and
			videoscopeSystem.insertionTube.ledLight.currentIntensity <= videoscopeSystem.insertionTube.ledLight.maxIntensity
		}
	}
	
	requirement def InsertionDepthRequirement {
		doc /* The videoscope insertion tube shall reach a minimum inspection depth of 2 meters. */
		
		require constraint {
			videoscopeSystem.insertionTube.length >= 2.0[m]
		}
	}
	
	requirement def ArticulationRequirement {
		doc /* The videoscope shall provide articulation capability to navigate complex geometries. */
		
		require constraint {
			videoscopeSystem.insertionTube.articulation.maxAngle >= 120.0[deg]
		}
	}
	
	requirement def ResolutionRequirement {
		doc /* The videoscope shall provide minimum HD resolution for clear imaging. */
		
		require constraint {
			videoscopeSystem.insertionTube.imageSensor.sensorResolution.width >= 1280 and
			videoscopeSystem.insertionTube.imageSensor.sensorResolution.height >= 720
		}
	}
	
	requirement videoscopeSystemRequirements {
		doc /* The videoscope system shall perform remote visual inspection of inaccessible or enclosed areas by capturing, processing, and displaying high-quality video imagery with adjustable illumination and articulation. */
		
		require ImageQualityRequirement;
		require IlluminationRequirement;
		require InsertionDepthRequirement;
		require ArticulationRequirement;
		require ResolutionRequirement;
	}
}
