package 'IRIS Recognition Identification System' {
	private import ScalarValues::*;

	item def Eye;
	item def IlluminatedEye;
	item def IrisImage {
		attribute width : Integer = 1280;
		attribute height : Integer = 960;
	}
	item def EnhancedImage;
	item def SegmentedIris;
	item def NormalizedIris;
	item def IrisTemplate;
	item def StoredTemplate :> IrisTemplate;
	item def Identity;
	item def CaptureCommand {
		item identity : Identity;
	}
	item def MatchResult {
		attribute score : Real;
		attribute verified : Boolean;
	}

	attribute def Wavelength :> Real;
	attribute def WavelengthNm :> Wavelength;
	attribute def FocalLength :> Real;
	attribute def FocalLengthMm :> FocalLength;
	attribute def MatchScore :> Real;
	attribute def Threshold :> Real;
	attribute def RecordCount :> Integer;

	action def Illuminate {
		in item eye : Eye;
		out item illuminatedEye : IlluminatedEye;
	}
	action def FocusLight {
		in item illuminatedEye : IlluminatedEye;
		out item focusedEye : IlluminatedEye;
	}
	action def Capture {
		in item focusedEye : IlluminatedEye;
		out item image : IrisImage;
	}
	action def EnhanceImage {
		in item image : IrisImage;
		out item enhancedImage : EnhancedImage;
	}
	action def SegmentIris {
		in item enhancedImage : EnhancedImage;
		out item segmentedIris : SegmentedIris;
	}
	action def NormalizeIris {
		in item segmentedIris : SegmentedIris;
		out item normalizedIris : NormalizedIris;
	}
	action def ExtractFeatures {
		in item normalizedIris : NormalizedIris;
		out item template : IrisTemplate;
	}
	action def ProcessImage {
		in item image : IrisImage;
		out item template : IrisTemplate;
		first start;
		then action enhance : EnhanceImage {
			in item image;
			out item enhancedImage;
		}
		flow from enhance.enhancedImage to segment.enhancedImage;
		then action segment : SegmentIris {
			in item enhancedImage;
			out item segmentedIris;
		}
		flow from segment.segmentedIris to normalize.segmentedIris;
		then action normalize : NormalizeIris {
			in item segmentedIris;
			out item normalizedIris;
		}
		flow from normalize.normalizedIris to extract.normalizedIris;
		then action extract : ExtractFeatures {
			in item normalizedIris;
			out item template;
		}
		flow from extract.template to template;
	}
	action def RetrieveTemplate {
		in item identity : Identity;
		out item storedTemplate : StoredTemplate;
	}
	action def MatchTemplate {
		in item liveTemplate : IrisTemplate;
		in item storedTemplate : StoredTemplate;
		out item result : MatchResult;
	}
	action def VerifyIdentity {
		in item eye : Eye;
		in item command : CaptureCommand;
		out item result : MatchResult;
		first start;
		then action illuminate : Illuminate {
			in item eye;
			out item illuminatedEye;
		}
		flow from illuminate.illuminatedEye to focus.illuminatedEye;
		then action focus : FocusLight {
			in item illuminatedEye;
			out item focusedEye;
		}
		flow from focus.focusedEye to capture.focusedEye;
		then action capture : Capture {
			in item focusedEye;
			out item image;
		}
		flow from capture.image to process.image;
		then action process : ProcessImage {
			in item image;
			out item template;
		}
		flow from process.template to match.liveTemplate;
		then action retrieve : RetrieveTemplate {
			in item identity : command.identity;
			out item storedTemplate;
		}
		flow from retrieve.storedTemplate to match.storedTemplate;
		then action match : MatchTemplate {
			in item liveTemplate;
			in item storedTemplate;
			out item result;
		}
		flow from match.result to result;
	}

	part def NIRIlluminator {
		attribute wavelength : WavelengthNm = 850;
		in port commandIn : CaptureCommand;
		out port lightOut : IlluminatedEye;
		action illuminate : Illuminate {
			in item eye;
			out item illuminatedEye :> lightOut;
		}
	}

	part def OpticalSystem {
		attribute focalLength : FocalLengthMm = 50;
		in port lightIn : IlluminatedEye;
		out port focusedLightOut : IlluminatedEye;
		flow from lightIn to focusedLightOut;
	}

	part def ImageSensor {
		attribute width : Integer = 1280;
		attribute height : Integer = 960;
		in port focusedLightIn : IlluminatedEye;
		out port imageOut : IrisImage;
		action capture : Capture {
			in item focusedEye :> focusedLightIn;
			out item image :> imageOut;
		}
	}

	part def ImageProcessor {
		in port imageIn : IrisImage;
		out port templateOut : IrisTemplate;
		action process : ProcessImage {
			in item image :> imageIn;
			out item template :> templateOut;
		}
	}

	part def TemplateDatabase {
		attribute capacity : RecordCount = 100000;
		attribute recordCount : RecordCount;
		in port queryIn : Identity;
		out port storedTemplateOut : StoredTemplate;
		item storedTemplates : StoredTemplate[*] ordered;
		action retrieve : RetrieveTemplate {
			in item identity :> queryIn;
			out item storedTemplate :> storedTemplateOut;
		}
	}

	part def MatchingEngine {
		attribute threshold : Threshold = 0.85;
		in port liveTemplateIn : IrisTemplate;
		in port storedTemplateIn : StoredTemplate;
		out port resultOut : MatchResult;
		action match : MatchTemplate {
			in item liveTemplate :> liveTemplateIn;
			in item storedTemplate :> storedTemplateIn;
			out item result :> resultOut;
		}
	}

	state machine def ControllerStateMachine {
		state idle;
		state illuminating;
		state capturing;
		state processing;
		state matching;
		transition idle to illuminating;
		transition illuminating to capturing;
		transition capturing to processing;
		transition processing to matching;
		transition matching to idle;
	}

	part def SystemController {
		in port commandIn : CaptureCommand;
		in port matchResultIn : MatchResult;
		out port verificationResultOut : MatchResult;
		out port captureCommandOut : CaptureCommand;
		out port identityOut : Identity;
		state machine controllerStateMachine : ControllerStateMachine;
	}

	part irisSystem {
		ref item eye : Eye;
		in port commandIn : CaptureCommand;
		out port resultOut : MatchResult;

		part controller : SystemController;
		part illuminator : NIRIlluminator;
		part optics : OpticalSystem;
		part sensor : ImageSensor;
		part processor : ImageProcessor;
		part database : TemplateDatabase;
		part matcher : MatchingEngine;

		flow from commandIn to controller.commandIn;
		flow from controller.captureCommandOut to illuminator.commandIn;
		flow from controller.identityOut to database.queryIn;
		flow from illuminator.lightOut to optics.lightIn;
		flow from optics.focusedLightOut to sensor.focusedLightIn;
		flow from sensor.imageOut to processor.imageIn;
		flow from processor.templateOut to matcher.liveTemplateIn;
		flow from database.storedTemplateOut to matcher.storedTemplateIn;
		flow from matcher.resultOut to controller.matchResultIn;
		flow from controller.verificationResultOut to resultOut;

		action verify : VerifyIdentity;
	}

	requirement def WavelengthRequirement {
		subject illuminator : NIRIlluminator;
		attribute requiredWavelength : WavelengthNm = 850;
		requirement constraint { illuminator.wavelength == 850 }
	}

	requirement def ResolutionRequirement {
		subject sensor : ImageSensor;
		attribute requiredWidth : Integer = 1280;
		attribute requiredHeight : Integer = 960;
		requirement constraint { sensor.width == 1280 and sensor.height == 960 }
	}

	requirement def DatabaseCapacityRequirement {
		subject database : TemplateDatabase;
		attribute requiredCapacity : RecordCount = 100000;
		requirement constraint { database.capacity >= 100000 }
	}

	requirement def ThresholdRequirement {
		subject matcher : MatchingEngine;
		attribute requiredThreshold : Threshold = 0.85;
		requirement constraint { matcher.threshold >= 0.85 }
	}

	requirement def VerificationAccuracyRequirement {
		subject irisSystem;
		attribute minAccuracy : Real = 0.99;
		requirement constraint { irisSystem.verify.result.verified == true }
	}

	requirement wavelengthSpec : WavelengthRequirement {
		subject = irisSystem.illuminator;
	}

	requirement resolutionSpec : ResolutionRequirement {
		subject = irisSystem.sensor;
	}

	requirement databaseCapacitySpec : DatabaseCapacityRequirement {
		subject = irisSystem.database;
	}

	requirement thresholdSpec : ThresholdRequirement {
		subject = irisSystem.matcher;
	}

	requirement verificationAccuracySpec : VerificationAccuracyRequirement {
		subject = irisSystem;
	}

	satisfy wavelengthSpec by irisSystem.illuminator;
	satisfy resolutionSpec by irisSystem.sensor;
	satisfy databaseCapacitySpec by irisSystem.database;
	satisfy thresholdSpec by irisSystem.matcher;
	satisfy verificationAccuracySpec by irisSystem;
}
