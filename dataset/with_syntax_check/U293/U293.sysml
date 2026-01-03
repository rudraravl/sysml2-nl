package MediastinoscopeSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ImageResolution {
		attribute width : Integer;
		attribute height : Integer;
	}
	
	attribute def IlluminationIntensity :> Real;
	
	item def VideoStream {
		attribute resolution : ImageResolution;
		attribute frameRate : FrequencyValue;
	}
	
	item def TissueSample {
		attribute mass :> ISQ::mass;
		attribute location : String;
		attribute timestamp : String;
	}
	
	attribute def PowerCommand;
	attribute def IlluminationCommand;
	attribute def BiopsyCommand;
	attribute def NavigationCommand;
	attribute def BiopsyNeededSignal;
	attribute def ExaminationCompleteSignal;
	
	port def VideoPort {
		out videoSignal : VideoStream;
	}
	
	port def IlluminationPort {
		in lightCommand : IlluminationCommand;
		out lightLevel : IlluminationIntensity;
	}
	
	port def BiopsyPort {
		in biopsyTrigger : BiopsyCommand;
		out sample : TissueSample;
	}
	
	port def ControlPort {
		in powerCmd : PowerCommand;
		in navCmd : NavigationCommand;
	}
	
	part def OpticalSystem {
		port videoOut : VideoPort;
		port lightIn : IlluminationPort;
		attribute lensAngle : ISQ::PlaneAngleValue;
		attribute focusRange : LengthValue;
	}
	
	part def LightSource {
		port illuminationControl : IlluminationPort;
		attribute maxIntensity : IlluminationIntensity;
		attribute colorTemperature : ThermodynamicTemperatureValue;
	}
	
	part def InsertionTube {
		attribute outerDiameter : LengthValue;
		attribute workingLength : LengthValue;
		attribute rigidity : Real;
	}
	
	part def BiopsyInstrument {
		port biopsyInterface : BiopsyPort;
		attribute channelDiameter : LengthValue;
		attribute maxSampleSize : MassValue;
	}
	
	part def VideoProcessor {
		port rawVideoIn : VideoPort;
		port processedVideoOut : VideoPort;
		attribute enhancementMode : String;
	}
	
	part def ControlConsole {
		port operatorControl : ControlPort;
		port displayOut : VideoPort;
		attribute displaySize : LengthValue;
	}
	
	action def ActivateIllumination {
		in intensityLevel : IlluminationIntensity;
		out lightOutput : IlluminationCommand;
	}
	
	action def CaptureVideo {
		in illumination : IlluminationIntensity;
		in focusDepth : LengthValue;
		out videoData : VideoStream;
	}
	
	action def EnhanceImage {
		in rawVideo : VideoStream;
		out enhancedVideo : VideoStream;
	}
	
	action def CollectTissueSample {
		in targetSite : String;
		out specimen : TissueSample;
	}
	
	action def PerformMediastinalExamination {
		doc /* Primary function: Enable minimally invasive visual examination and tissue sampling 
		       of mediastinal structures including lymph nodes, masses, and surrounding tissues 
		       for diagnostic and staging purposes. */
		
		in patientData;
		in biopsyNeeded : BiopsyNeededSignal;
		in examinationComplete : ExaminationCompleteSignal;
		out diagnosticVideo : VideoStream[*];
		out biopsySamples : TissueSample[*];
		
		first start;
		then action initializeSystem {
			doc /* Power on system and verify all components operational. */
		}
		then action insertScope {
			doc /* Insert mediastinoscope through suprasternal incision into mediastinum. */
		}
		then merge examinationLoop;
		then action performExamination {
			action activateLight : ActivateIllumination {
				in intensityLevel : IlluminationIntensity;
				out lightOutput : IlluminationCommand;
			}
			then action captureImages : CaptureVideo {
				in illumination = activateLight.intensityLevel;
				in focusDepth : LengthValue;
				out videoData : VideoStream;
			}
			then action enhanceImages : EnhanceImage {
				in rawVideo = captureImages.videoData;
				out enhancedVideo : VideoStream;
			}
			flow enhanceImages.enhancedVideo to diagnosticVideo;
		}
		then decide;
			if biopsyNeeded then takeBiopsy;
			if examinationComplete then withdrawInstrument;
			else examinationLoop;
		
		action takeBiopsy : CollectTissueSample {
			in targetSite : String;
			out specimen : TissueSample;
		}
		flow takeBiopsy.specimen to biopsySamples;
		then examinationLoop;
		
		action withdrawInstrument {
			doc /* Carefully withdraw mediastinoscope from mediastinum. */
		}
		then action shutdownSystem {
			doc /* Power down system and prepare for sterilization. */
		}
		then done;
	}
	
	part def Mediastinoscope {
		doc /* Rigid endoscopic instrument for examining the mediastinum through 
		       a suprasternal approach, enabling visualization and biopsy of mediastinal structures. */
		
		attribute scopeDiameter : LengthValue;
		attribute scopeLength : LengthValue;
		attribute viewingAngle : ISQ::PlaneAngleValue;
		
		part insertionTube : InsertionTube {
			attribute outerDiameter : LengthValue = 12.0 [mm];
			attribute workingLength : LengthValue = 180.0 [mm];
			attribute rigidity = 0.85;
		}
		
		part opticalSystem : OpticalSystem {
			port videoOut : VideoPort;
			port lightIn : IlluminationPort;
			attribute lensAngle : ISQ::PlaneAngleValue = 30.0 [deg];
			attribute focusRange : LengthValue = 50.0 [mm];
		}
		
		part lightSource : LightSource {
			port illuminationControl : IlluminationPort;
			attribute maxIntensity : IlluminationIntensity = 100.0;
			attribute colorTemperature : ThermodynamicTemperatureValue = 5500.0 [K];
		}
		
		part biopsyInstrument : BiopsyInstrument {
			port biopsyInterface : BiopsyPort;
			attribute channelDiameter : LengthValue = 5.0 [mm];
			attribute maxSampleSize : MassValue = 50.0 [mg];
		}
		
		part videoProcessor : VideoProcessor {
			port rawVideoIn : VideoPort;
			port processedVideoOut : VideoPort;
			attribute enhancementMode = "HD";
		}
		
		part controlConsole : ControlConsole {
			port operatorControl : ControlPort;
			port displayOut : VideoPort;
			attribute displaySize : LengthValue = 550.0 [mm];
		}
		
		connect lightSource.illuminationControl to opticalSystem.lightIn;
		connect opticalSystem.videoOut to videoProcessor.rawVideoIn;
		connect videoProcessor.processedVideoOut to controlConsole.displayOut;
		
		perform action examination : PerformMediastinalExamination {
			in patientData;
			in biopsyNeeded : BiopsyNeededSignal;
			in examinationComplete : ExaminationCompleteSignal;
			out diagnosticVideo : VideoStream[*];
			out biopsySamples : TissueSample[*];
		}
		
		part opticalSystem {
			perform examination.performExamination.captureImages;
		}
		
		part lightSource {
			perform examination.performExamination.activateLight;
		}
		
		part videoProcessor {
			perform examination.performExamination.enhanceImages;
		}
		
		part biopsyInstrument {
			perform examination.takeBiopsy;
		}
	}
	
	part mediastinoscopeSystem : Mediastinoscope {
		attribute scopeDiameter : LengthValue = 12.0 [mm];
		attribute scopeLength : LengthValue = 180.0 [mm];
		attribute viewingAngle : ISQ::PlaneAngleValue = 30.0 [deg];
	}
	
	requirement def VisualizationCapability {
		doc /* The system shall provide high-definition visualization of mediastinal structures. */
	}
	
	requirement def BiopsyCapability {
		doc /* The system shall enable tissue sampling of mediastinal structures. */
	}
	
	requirement def SafetyRequirement {
		doc /* The system shall minimize risk of injury to surrounding structures. */
	}
	
	requirement <'REQ-001'> highDefinitionImaging : VisualizationCapability {
		doc /* The mediastinoscope shall provide video resolution of at least 1920x1080 pixels 
		       at 60 frames per second for clear visualization of anatomical structures. */
		subject mediastinoscopeSystem.opticalSystem;
		require constraint {
			mediastinoscopeSystem.videoProcessor.rawVideoIn.videoSignal.resolution.width >= 1920 and
			mediastinoscopeSystem.videoProcessor.rawVideoIn.videoSignal.resolution.height >= 1080 and
			mediastinoscopeSystem.videoProcessor.rawVideoIn.videoSignal.frameRate >= 60.0 [Hz]
		}
	}
	
	requirement <'REQ-002'> adequateIllumination : VisualizationCapability {
		doc /* The illumination system shall provide sufficient light intensity 
		       for clear tissue visualization throughout the examination. */
		subject mediastinoscopeSystem.lightSource;
		require constraint {
			mediastinoscopeSystem.lightSource.maxIntensity >= 80.0
		}
	}
	
	requirement <'REQ-003'> biopsyChannelSize : BiopsyCapability {
		doc /* The biopsy channel shall accommodate standard biopsy instruments 
		       with minimum diameter of 4mm. */
		subject mediastinoscopeSystem.biopsyInstrument;
		require constraint {
			mediastinoscopeSystem.biopsyInstrument.channelDiameter >= 4.0 [mm]
		}
	}
	
	requirement <'REQ-004'> instrumentDimensions : SafetyRequirement {
		doc /* The insertion tube outer diameter shall not exceed 13mm 
		       to minimize tissue trauma during insertion. */
		subject mediastinoscopeSystem.insertionTube;
		require constraint {
			mediastinoscopeSystem.insertionTube.outerDiameter <= 13.0 [mm]
		}
	}
}
