package 'Visual Odometry System' {
	private import ISQ::*;
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ScalarValues::Natural;
	private import ScalarValues::String;
	private import Time::TimeValue;

	item def StereoImagePair {
		attribute leftImage : String;
		attribute rightImage : String;
		attribute timestamp : TimeValue;
	}

	item def ImageFeatures {
		attribute featureCount : Natural;
		attribute featureData : String;
	}

	item def Landmarks3D {
		attribute pointCount : Natural;
		attribute coordinates : String;
	}

	item def TrackedLandmarks {
		attribute trackedCount : Natural;
		attribute trackingData : String;
	}

	item def IncrementalMotion {
		attribute translation : Real[3];
		attribute rotation : Real[3];
	}

	item def Pose {
		attribute totalTranslation : Real[3];
		attribute totalRotation : Real[3];
	}

	part def StereoCamera {
		out port imageOut : StereoImagePair;
		exhibit state cameraStates {
			entry; then capturing;
			state capturing;
		}
	}

	part def FeatureDetector {
		in port imageIn : StereoImagePair;
		out port featuresOut : ImageFeatures;
	}

	part def DepthEstimator {
		in port imageIn : StereoImagePair;
		in port featuresIn : ImageFeatures;
		out port landmarksOut : Landmarks3D;
	}

	part def FeatureTracker {
		in port landmarksIn : Landmarks3D;
		out port trackedOut : TrackedLandmarks;
	}

	part def MotionEstimator {
		in port trackedIn : TrackedLandmarks;
		out port motionOut : IncrementalMotion;
	}

	part def PoseIntegrator {
		in port motionIn : IncrementalMotion;
		out port poseOut : Pose;
	}

	part def VisualOdometrySystem {
		part stereoCamera : StereoCamera;
		part featureDetector : FeatureDetector;
		part depthEstimator : DepthEstimator;
		part featureTracker : FeatureTracker;
		part motionEstimator : MotionEstimator;
		part poseIntegrator : PoseIntegrator;

		connect stereoCamera.imageOut to featureDetector.imageIn;
		connect stereoCamera.imageOut to depthEstimator.imageIn;
		connect featureDetector.featuresOut to depthEstimator.featuresIn;
		connect depthEstimator.landmarksOut to featureTracker.landmarksIn;
		connect featureTracker.trackedOut to motionEstimator.trackedIn;
		connect motionEstimator.motionOut to poseIntegrator.motionIn;

		exhibit state operationalStates {
			entry; then initializing;
			state initializing;
			then ready if initialized;
			state ready;
			then activeTracking if startTracking;
			state activeTracking;
			then ready if pauseSignal;
			then initializing if resetSignal;
		}
	}

	action def ProcessFrame {
		in imagePair : StereoImagePair;
		in previousLandmarks : Landmarks3D;
		out currentPose : Pose = integratePose.pose;

		action detectFeatures {
			in image = imagePair;
			out features;
		}
		action estimateDepth {
			in image = imagePair;
			in features = detectFeatures.features;
			out landmarks;
		}
		action trackFeatures {
			in currentLandmarks = estimateDepth.landmarks;
			in previousLandmarks = previousLandmarks;
			out trackedLandmarks;
		}
		action estimateMotion {
			in tracked = trackFeatures.trackedLandmarks;
			out motion;
		}
		action integratePose {
			in motion = estimateMotion.motion;
			out pose;
		}
	}

	requirement def UpdateRateRequirement {
		doc /* The system must provide at least 15 position updates per second. */
		attribute minUpdateRate : Real = 15.0;
	}

	requirement def AccuracyRequirement {
		doc /* The system must maintain an accuracy of within 2% of the total distance traveled. */
		attribute maxErrorPercentage : Real = 0.02;
	}

	requirement def RobustnessRequirement {
		doc /* The system must maintain tracking even if some visual features are lost. */
		attribute canHandleLostFeatures : Boolean = true;
	}

	requirement voRequirements {
		subject visualOdometrySystem : VisualOdometrySystem;
		requirement updateRate : UpdateRateRequirement;
		requirement accuracy : AccuracyRequirement;
		requirement robustness : RobustnessRequirement;
	}
}
