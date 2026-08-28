package 'StructuredLight3DScanner' {
	private import ScalarValues::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::size;

	item def StructuredLightPattern {
		attribute patternType : String;
		attribute patternIndex : Integer;
		attribute width : Integer;
		attribute height : Integer;
	}

	item def CapturedImage {
		attribute imageId : String;
		attribute cameraId : String;
		attribute width : Integer;
		attribute height : Integer;
		attribute timestamp : TimeValue;
	}

	attribute def Point3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}

	item def PointCloud {
		attribute points : Point3D[*];
		attribute pointCount : Integer = size(points);
	}

	attribute def ResolutionSpec {
		attribute width : Integer;
		attribute height : Integer;
	}

	attribute def WorkingVolumeSpec {
		attribute width : LengthValue;
		attribute depth : LengthValue;
		attribute height : LengthValue;
	}

	package ScannerRequirements {
		requirement def DepthAccuracyRequirement {
			attribute actualDepthAccuracy : LengthValue;
			attribute requiredDepthAccuracy : LengthValue;
			require constraint { actualDepthAccuracy <= requiredDepthAccuracy }
		}

		requirement def ResolutionRequirement {
			attribute actualResolution : ResolutionSpec;
			attribute requiredResolution : ResolutionSpec;
			require constraint {
				actualResolution.width >= requiredResolution.width &
				actualResolution.height >= requiredResolution.height
			}
		}

		requirement def WorkingVolumeRequirement {
			attribute actualWorkingVolume : WorkingVolumeSpec;
			attribute requiredWorkingVolume : WorkingVolumeSpec;
			require constraint {
				actualWorkingVolume.width >= requiredWorkingVolume.width &
				actualWorkingVolume.depth >= requiredWorkingVolume.depth &
				actualWorkingVolume.height >= requiredWorkingVolume.height
			}
		}

		requirement depthAccuracyReq : DepthAccuracyRequirement {
			:>> requiredDepthAccuracy = 0.5 ['mm'];
		}

		requirement resolutionReq : ResolutionRequirement {
			:>> requiredResolution.width = 1920;
			:>> requiredResolution.height = 1080;
		}

		requirement workingVolumeReq : WorkingVolumeRequirement {
			:>> requiredWorkingVolume.width = 30 ['cm'];
			:>> requiredWorkingVolume.depth = 30 ['cm'];
			:>> requiredWorkingVolume.height = 50 ['cm'];
		}
	}

	private import ScannerRequirements::*;

	calc def TriangulatePoints {
		in leftImage : CapturedImage;
		in rightImage : CapturedImage;
		in projectedPattern : StructuredLightPattern;
		in baseline : LengthValue;
		return : Point3D[*];
	}

	calc def GeneratePointCloud {
		in pointSets : PointCloud[*];
		return : PointCloud;
	}

	part def Projector {
		attribute resolution : ResolutionSpec;
		attribute workingDistance : LengthValue;
		attribute currentPatternIndex : Integer;
		port patternPort {
			out pattern : StructuredLightPattern;
		}
	}

	part def StereoCamera {
		attribute cameraName : String;
		attribute frameRate : Real;
		attribute resolution : ResolutionSpec;
		port imagePort {
			out image : CapturedImage;
		}
		port triggerPort {
			in trigger : Boolean;
		}
	}

	part def ProcessingUnit {
		attribute memoryCapacity : Real;
		attribute computingPower : Real;
		port leftImagePort {
			in image : CapturedImage;
		}
		port rightImagePort {
			in image : CapturedImage;
		}
		port patternPort {
			in pattern : StructuredLightPattern;
		}
		port pointCloudPort {
			out pointCloud : PointCloud;
		}
	}

	part def CalibrationTarget {
		attribute patternType : String;
		attribute featurePoints : Point3D[*];
	}

	part def ScannerSystem {
		attribute depthAccuracy : LengthValue;
		attribute resolution : ResolutionSpec;
		attribute workingVolume : WorkingVolumeSpec;
		attribute typicalDistance : LengthValue;
		attribute baseline : LengthValue;
		attribute enoughDataCollected : Boolean;
		attribute totalPatterns : Integer;
		attribute currentPatternIndex : Integer;

		part projector : Projector {
			:>> resolution.width = 1920;
			:>> resolution.height = 1080;
			:>> workingDistance = 80 ['cm'];
		}

		part leftCamera : StereoCamera {
			:>> cameraName = "Left";
			:>> frameRate = 60.0;
			:>> resolution.width = 1920;
			:>> resolution.height = 1080;
		}

		part rightCamera : StereoCamera {
			:>> cameraName = "Right";
			:>> frameRate = 60.0;
			:>> resolution.width = 1920;
			:>> resolution.height = 1080;
		}

		part processingUnit : ProcessingUnit {
			:>> memoryCapacity = 16.0;
			:>> computingPower = 100.0;
		}

		part calibrationTarget : CalibrationTarget {
			:>> patternType = "Checkerboard";
		}

		flow patternFlow of StructuredLightPattern
			from projector.patternPort.pattern to processingUnit.patternPort.pattern;

		flow leftImageFlow of CapturedImage
			from leftCamera.imagePort.image to processingUnit.leftImagePort.image;

		flow rightImageFlow of CapturedImage
			from rightCamera.imagePort.image to processingUnit.rightImagePort.image;

		exhibit state scanningStateMachine {
			entry; then 'Initializing';

			state 'Initializing';
			then 'Calibrating';

			state 'Calibrating';
			then 'ScanningLoop';

			state 'ScanningLoop' {
				entry; then 'ProjectingPattern';

				state 'ProjectingPattern';
				then 'CapturingImages';

				state 'CapturingImages';
				then 'ProcessingImages';

				state 'ProcessingImages';
				then 'ProjectingPattern';
			}
			then 'GeneratingPointCloud';

			state 'GeneratingPointCloud';
			then 'OutputtingPointCloud';

			state 'OutputtingPointCloud';
			then 'Complete';

			state 'Complete';
		}

		action calibrateSystem {
			in target : CalibrationTarget;
			out calibrationSuccess : Boolean;
		}

		action projectPattern {
			in patternIndex : Integer;
			out pattern : StructuredLightPattern;
		}

		action captureStereoImages {
			in trigger : Boolean;
			out leftImage : CapturedImage;
			out rightImage : CapturedImage;
		}

		action processAndTriangulate {
			in leftImage : CapturedImage;
			in rightImage : CapturedImage;
			in pattern : StructuredLightPattern;
			in baselineDistance : LengthValue;
			out surfacePoints : Point3D[*];
		}

		action generateFinalPointCloud {
			in allSurfacePoints : PointCloud[*];
			out finalPointCloud : PointCloud;
		}
	}

	part scannerInstance : ScannerSystem {
		:>> depthAccuracy = 0.5 ['mm'];
		:>> resolution.width = 1920;
		:>> resolution.height = 1080;
		:>> workingVolume.width = 30 ['cm'];
		:>> workingVolume.depth = 30 ['cm'];
		:>> workingVolume.height = 50 ['cm'];
		:>> typicalDistance = 80 ['cm'];
		:>> baseline = 20 ['cm'];
		:>> enoughDataCollected = false;
		:>> totalPatterns = 20;
		:>> currentPatternIndex = 0;
	}

	satisfy depthAccuracyReq by scannerInstance;
	satisfy resolutionReq by scannerInstance;
	satisfy workingVolumeReq by scannerInstance;
}
