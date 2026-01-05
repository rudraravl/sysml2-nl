package FiberscopeSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ImageResolution {
		attribute horizontalPixels : Integer;
		attribute verticalPixels : Integer;
	}
	
	attribute def IlluminationIntensity :> ISQ::LuminousIntensityValue;
	
	attribute def ArticulationAngle :> ISQ::PlaneAngleValue;
	
	attribute def InsertionDepth :> ISQ::LengthValue;
	
	item def OpticalSignal {
		attribute intensity : IlluminationIntensity;
		attribute wavelength : ISQ::LengthValue;
	}
	
	item def VisualImage {
		attribute resolution : ImageResolution;
		attribute brightness : Real;
	}
	
	item def ControlSignal {
		attribute tipAngle : ArticulationAngle;
		attribute focusAdjustment : ISQ::LengthValue;
	}
	
	port def OpticalPort {
		out light : OpticalSignal;
	}
	
	port def ImagePort {
		in image : VisualImage;
	}
	
	port def ControlPort {
		out control : ControlSignal;
	}
	
	part def IlluminationSource {
		out port lightOutput : OpticalPort;
		attribute powerRating : ISQ::PowerValue;
		attribute colorTemperature : ISQ::ThermodynamicTemperatureValue;
		
		action def GenerateLight {
			out illumination : OpticalSignal;
		}
	}
	
	part def ObjectiveLensAssembly {
		in port lightInput {
			in illumination : OpticalSignal;
		}
		in port controlInput {
			in control : ControlSignal;
		}
		out port imageOutput {
			out capturedImage : VisualImage;
		}
		attribute fieldOfView : ISQ::PlaneAngleValue;
		attribute workingDistance : ISQ::LengthValue;
		
		action def CaptureImage {
			in illumination : OpticalSignal;
			in focusControl : ControlSignal;
			out image : VisualImage;
		}
	}
	
	part def FlexibleInsertionTube {
		in port proximalImageInput {
			in image : VisualImage;
		}
		in port proximalLightInput {
			in light : OpticalSignal;
		}
		out port distalImageOutput {
			out image : VisualImage;
		}
		out port distalLightOutput {
			out light : OpticalSignal;
		}
		attribute tubeLength : ISQ::LengthValue;
		attribute outerDiameter : ISQ::LengthValue;
		attribute minimumBendRadius : ISQ::LengthValue;
		attribute fiberCount : Integer;
		
		action def TransmitOpticalSignals {
			in inputLight : OpticalSignal;
			in inputImage : VisualImage;
			out outputLight : OpticalSignal;
			out outputImage : VisualImage;
		}
	}
	
	part def EyepieceViewer {
		in port imageInput {
			in image : VisualImage;
		}
		out port viewOutput {
			out displayedImage : VisualImage;
		}
		attribute magnification : Real;
		attribute eyeRelief : ISQ::LengthValue;
		attribute diopter : Real;
		
		action def MagnifyImage {
			in sourceImage : VisualImage;
			in magnificationFactor : Real;
			out magnifiedImage : VisualImage;
		}
	}
	
	part def ArticulationControl {
		out port controlOutput {
			out control : ControlSignal;
		}
		attribute maxDeflection : ArticulationAngle;
		attribute controlType : String;
		
		action def GenerateControlSignal {
			in userInput : Real;
			out controlSignal : ControlSignal;
		}
	}
	
	action def IlluminateTargetArea {
		in lightSource : OpticalSignal;
		in targetDepth : InsertionDepth;
		out illuminatedRegion : ISQ::AreaValue;
	}
	
	action def AcquireOpticalImage {
		in sceneIllumination : OpticalSignal;
		in focusDistance : ISQ::LengthValue;
		out rawImage : VisualImage;
	}
	
	action def TransmitThroughFiberBundle {
		in proximalImage : VisualImage;
		in transmissionLength : ISQ::LengthValue;
		out distalImage : VisualImage;
	}
	
	action def DisplayToOperator {
		in transmittedImage : VisualImage;
		in viewerMagnification : Real;
		out operatorView : VisualImage;
	}
	
	action def PerformRemoteVisualInspection {
		in targetLocation : String;
		in requiredDepth : InsertionDepth;
		in minimumResolution : ImageResolution;
		out inspectionStatus : String;
		
		first start;
		then action illuminate : IlluminateTargetArea {
			in lightSource;
			in targetDepth = requiredDepth;
			out illuminatedRegion;
		}
		then action acquire : AcquireOpticalImage {
			in sceneIllumination = illuminate.lightSource;
			in focusDistance = requiredDepth;
			out rawImage;
		}
		then action transmit : TransmitThroughFiberBundle {
			in proximalImage = acquire.rawImage;
			in transmissionLength;
			out distalImage;
		}
		then action display : DisplayToOperator {
			in transmittedImage = transmit.distalImage;
			in viewerMagnification;
			out operatorView;
		}
		then action evaluate {
			in evaluatedImage : VisualImage = display.operatorView;
			in requiredRes : ImageResolution = minimumResolution;
			out meetsRequirement : Boolean;
		}
		then decide;
			if evaluate.meetsRequirement then recordSuccess;
			else recordAdjustmentNeeded;
		action recordSuccess {
			assign inspectionStatus := "Inspection completed successfully";
		}
		then done;
		action recordAdjustmentNeeded {
			assign inspectionStatus := "Image quality adjustment required";
		}
		then done;
	}
	
	state def FiberscopeOperationalStates {
		entry; then idle;
		state idle;
		state inserting;
		state positioning;
		state imaging;
		state withdrawing;
		
		transition first idle to inserting
			accept insertionCommand;
		transition inserting to positioning
			accept depthReached;
		transition positioning to imaging
			accept targetAcquired;
		transition imaging to positioning
			accept repositionRequest;
		transition imaging to withdrawing
			accept inspectionComplete;
		transition positioning to withdrawing
			accept abortSignal;
		transition withdrawing to idle
			accept extractionComplete;
	}
	
	part fiberscopeSystem {
		attribute systemLength : ISQ::LengthValue;
		attribute workingChannelDiameter : ISQ::LengthValue;
		attribute operatingTemperatureRange : ISQ::ThermodynamicTemperatureValue[2];
		
		perform action remoteInspection[*] ordered references PerformRemoteVisualInspection;
		
		part illuminator : IlluminationSource {
			attribute :>> powerRating = 150[W];
			attribute :>> colorTemperature = 5500[K];
			perform action generateLight : GenerateLight;
		}
		
		part distalOptics : ObjectiveLensAssembly {
			attribute :>> fieldOfView = 75[deg];
			attribute :>> workingDistance = 30[mm];
			perform remoteInspection.acquire;
		}
		
		part insertionSection : FlexibleInsertionTube {
			attribute :>> tubeLength = 1200[mm];
			attribute :>> outerDiameter = 5.5[mm];
			attribute :>> minimumBendRadius = 25[mm];
			attribute :>> fiberCount = 18000;
			perform remoteInspection.transmit;
		}
		
		part eyepiece : EyepieceViewer {
			attribute :>> magnification = 12.0;
			attribute :>> eyeRelief = 14[mm];
			attribute :>> diopter = -2.0;
			perform remoteInspection.display;
		}
		
		part articulationController : ArticulationControl {
			attribute :>> maxDeflection = 120[deg];
			attribute :>> controlType = "Four-way lever";
			perform action generateControl : GenerateControlSignal;
		}
		
		connection illuminationPath : FlowConnection
			connect illuminator.lightOutput to insertionSection.proximalLightInput;
		
		connection distalIllumination : FlowConnection
			connect insertionSection.distalLightOutput to distalOptics.lightInput;
		
		connection imageCapture : FlowConnection
			connect distalOptics.imageOutput to insertionSection.distalImageOutput;
		
		connection imageTransmission : FlowConnection
			connect insertionSection.proximalImageInput to eyepiece.imageInput;
		
		connection articulationLink : FlowConnection
			connect articulationController.controlOutput to distalOptics.controlInput;
		
		state operationalState : FiberscopeOperationalStates;
	}
	
	requirement def AccessibilityRequirement {
		doc /* The fiberscope shall enable visual inspection of confined spaces 
		       and internal cavities that are inaccessible to direct observation. */
		
		require constraint minimumInsertionLength {
			fiberscopeSystem.insertionSection.tubeLength >= 800[mm]
		}
		
		require constraint maximumDiameter {
			fiberscopeSystem.insertionSection.outerDiameter <= 8[mm]
		}
		
		require constraint flexibilityRequirement {
			fiberscopeSystem.insertionSection.minimumBendRadius <= 30[mm]
		}
	}
	
	requirement def ImageQualityRequirement {
		doc /* The fiberscope shall provide sufficient image resolution and 
		       illumination for detailed visual examination of target surfaces. */
		
		require constraint minimumFiberCount {
			fiberscopeSystem.insertionSection.fiberCount >= 10000
		}
		
		require constraint illuminationPower {
			fiberscopeSystem.illuminator.powerRating >= 100[W]
		}
		
		require constraint fieldOfViewRequirement {
			fiberscopeSystem.distalOptics.fieldOfView >= 60[deg]
		}
		
		require constraint magnificationRange {
			fiberscopeSystem.eyepiece.magnification >= 8.0 and fiberscopeSystem.eyepiece.magnification <= 15.0
		}
	}
	
	requirement def ManeuverabilityRequirement {
		doc /* The fiberscope shall provide articulation control to position 
		       the distal tip for optimal viewing angles. */
		
		require constraint articulationRange {
			fiberscopeSystem.articulationController.maxDeflection >= 100[deg]
		}
	}
	
	requirement primaryFunctionRequirement {
		doc /* The fiberscope system shall perform non-destructive remote visual 
		       inspection by transmitting illumination through optical fibers to 
		       a target area, capturing the reflected image, and relaying it back 
		       through a coherent fiber bundle to provide a magnified view to the 
		       operator for examination of otherwise inaccessible locations. */
		
		subject fiberscopeSystem;
		
		require accessibility : AccessibilityRequirement;
		require imageQuality : ImageQualityRequirement;
		require maneuverability : ManeuverabilityRequirement;
		
		assume constraint operationalEnvironment {
			doc /* The fiberscope operates within specified temperature ranges 
			       with trained operators following standard inspection protocols. */
		}
	}
}
