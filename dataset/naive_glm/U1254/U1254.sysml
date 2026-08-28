package VisualOdometrySystem {
    import ScalarValues::*;

    // ---- Units ----
    unit m;
    unit s;
    unit rad;
    unit Hz = 1 / s;
    unit percent;
    unit ms = 0.001 * s;

    // ---- Value Types ----
    value def Distance :> Real { unit m; }
    value def Duration :> Real { unit s; }
    value def TimeStamp :> Real { unit s; }
    value def Angle :> Real { unit rad; }
    value def Frequency :> Real { unit Hz; }
    value def Percentage :> Real { unit percent; }
    value def Confidence :> Real { unit percent; }

    // ---- Item Definitions ----
    item def ImageFrame {
        attribute timestamp : TimeStamp;
        attribute frameId : Integer;
        attribute width : Integer;
        attribute height : Integer;
        attribute pixelData : String;
    }

    item def StereoImagePair {
        attribute timestamp : TimeStamp;
        attribute frameId : Integer;
        item leftImage : ImageFrame;
        item rightImage : ImageFrame;
    }

    item def FeaturePoint {
        attribute id : Integer;
        attribute x : Real;
        attribute y : Real;
        attribute descriptor : String;
        attribute strength : Real;
    }

    item def FeatureSet {
        attribute frameId : Integer;
        attribute cameraSide : String;
        item features : FeaturePoint[0..*];
    }

    item def StereoFeatureSet {
        attribute frameId : Integer;
        item leftFeatures : FeatureSet;
        item rightFeatures : FeatureSet;
    }

    item def Landmark3D {
        attribute id : Integer;
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
        attribute depth : Distance;
        attribute confidence : Confidence;
    }

    item def LandmarkSet {
        attribute frameId : Integer;
        item landmarks : Landmark3D[0..*];
    }

    item def TrackedLandmarkSet {
        attribute currentFrameId : Integer;
        attribute previousFrameId : Integer;
        item trackedLandmarks : Landmark3D[0..*];
        attribute trackedCount : Integer;
        attribute lostCount : Integer;
    }

    item def IncrementalMotion {
        attribute dx : Distance;
        attribute dy : Distance;
        attribute dz : Distance;
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
        attribute timestamp : TimeStamp;
        attribute frameId : Integer;
    }

    item def Pose {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
        attribute timestamp : TimeStamp;
        attribute confidence : Confidence;
        attribute totalDistanceTraveled : Distance;
    }

    item def SystemStatus {
        attribute state : String;
        attribute featureCount : Integer;
        attribute updateRate : Frequency;
        attribute timestamp : TimeStamp;
    }

    // ---- Port Definitions ----
    port def ImageOutput {
        out image : ImageFrame;
    }

    port def StereoImageOutput {
        out stereoPair : StereoImagePair;
    }

    port def FeatureInput {
        in features : FeatureSet;
    }

    port def FeatureOutput {
        out features : FeatureSet;
    }

    port def StereoFeatureOutput {
        out stereoFeatures : StereoFeatureSet;
    }

    port def LandmarkInput {
        in landmarks : LandmarkSet;
    }

    port def LandmarkOutput {
        out landmarks : LandmarkSet;
    }

    port def TrackedLandmarkInput {
        in trackedLandmarks : TrackedLandmarkSet;
    }

    port def TrackedLandmarkOutput {
        out trackedLandmarks : TrackedLandmarkSet;
    }

    port def MotionInput {
        in motion : IncrementalMotion;
    }

    port def MotionOutput {
        out motion : IncrementalMotion;
    }

    port def PoseInput {
        in pose : Pose;
    }

    port def PoseOutput {
        out pose : Pose;
    }

    port def StatusOutput {
        out status : SystemStatus;
    }

    port def CommandInput {
        in startCommand : Boolean;
        in stopCommand : Boolean;
        in resetCommand : Boolean;
    }

    // ---- Action Definitions ----
    action def CaptureImage {
        out frame : ImageFrame;
    }

    action def CaptureStereoPair {
        out pair : StereoImagePair;
    }

    action def DetectFeatures {
        in image : ImageFrame;
        out features : FeatureSet;
    }

    action def AggregateStereoFeatures {
        in leftFeatures : FeatureSet;
        in rightFeatures : FeatureSet;
        out stereoFeatures : StereoFeatureSet;
    }

    action def EstimateDepth {
        in stereoFeatures : StereoFeatureSet;
        out landmarks : LandmarkSet;
    }

    action def TrackFeatures {
        in currentLandmarks : LandmarkSet;
        in previousLandmarks : LandmarkSet;
        out trackedLandmarks : TrackedLandmarkSet;
    }

    action def EstimateMotion {
        in trackedLandmarks : TrackedLandmarkSet;
        out motion : IncrementalMotion;
    }

    action def IntegrateMotion {
        in motion : IncrementalMotion;
        in previousPose : Pose;
        out updatedPose : Pose;
    }

    action def InitializeSystem {
        out initialized : Boolean;
    }

    action def ResetPose {
        out pose : Pose;
    }

    // ---- Part Definitions ----
    part def Camera {
        port imageOut : ImageOutput;
        attribute frameRate : Frequency = 30 [Hz];
        attribute isCalibrated : Boolean = false;
        attribute focalLength : Distance;
        attribute principalPointX : Real;
        attribute principalPointY : Real;

        action captureFrame : CaptureImage;
    }

    part def StereoCamera {
        part leftCamera : Camera {
            attribute focalLength = 0.008 [m];
            attribute principalPointX = 320.0;
            attribute principalPointY = 240.0;
        }
        part rightCamera : Camera {
            attribute focalLength = 0.008 [m];
            attribute principalPointX = 320.0;
            attribute principalPointY = 240.0;
        }
        port stereoOut : StereoImageOutput;
        attribute baseline : Distance = 0.12 [m];
        attribute frameRate : Frequency = 30 [Hz];

        action captureStereoPair : CaptureStereoPair;
    }

    part def FeatureDetector {
        port imageIn : ImageInput;
        port featureOut : FeatureOutput;
        attribute maxFeatures : Integer = 500;
        attribute detectorType : String = "FAST";
        attribute minFeatureQuality : Real = 0.01;

        action detectFeatures : DetectFeatures;
    }

    port def ImageInput {
        in image : ImageFrame;
    }

    part def StereoFeatureAggregator {
        port leftFeatureIn : FeatureInput;
        port rightFeatureIn : FeatureInput;
        port stereoFeatureOut : StereoFeatureOutput;

        action aggregate : AggregateStereoFeatures;
    }

    part def DepthEstimator {
        port stereoFeaturesIn : StereoFeatureOutput;
        port landmarkOut : LandmarkOutput;
        attribute baseline : Distance = 0.12 [m];
        attribute focalLength : Distance = 0.008 [m];
        attribute minDisparity : Real = 1.0;
        attribute maxDepth : Distance = 50.0 [m];

        action estimateDepth : EstimateDepth;
    }

    part def FeatureTracker {
        port landmarksIn : LandmarkInput;
        port trackedOut : TrackedLandmarkOutput;
        attribute maxLostFrames : Integer = 3;
        attribute minTrackedFeatures : Integer = 20;
        attribute previousLandmarks : LandmarkSet;
        attribute trackingActive : Boolean = false;

        action trackFeatures : TrackFeatures;
    }

    part def MotionEstimator {
        port trackedIn : TrackedLandmarkInput;
        port motionOut : MotionOutput;
        attribute minTrackedFeatures : Integer = 20;
        attribute motionModel : String = "PnP";

        action estimateMotion : EstimateMotion;
    }

    part def PoseIntegrator {
        port motionIn : MotionInput;
        port poseOut : PoseOutput;
        attribute currentPose : Pose;
        attribute totalDistanceTraveled : Distance = 0.0 [m];

        action integrateMotion : IntegrateMotion;
    }

    // ---- Main System ----
    part def VisualOdometrySystem {
        attribute systemName : String = "VisualOdometrySystem";
        attribute updateRate : Frequency = 30 [Hz];
        attribute minUpdateRate : Frequency = 15 [Hz];
        attribute maxProcessingTime : Duration = 66.0 [ms];
        attribute accuracyThreshold : Percentage = 2.0 [percent];

        port commandIn : CommandInput;
        port poseOutput : PoseOutput;
        port statusOutput : StatusOutput;

        part stereoCamera : StereoCamera {
            attribute baseline = 0.12 [m];
            attribute frameRate = 30 [Hz];
        }

        part featureDetectorLeft : FeatureDetector {
            attribute maxFeatures = 500;
            attribute detectorType = "FAST";
        }

        part featureDetectorRight : FeatureDetector {
            attribute maxFeatures = 500;
            attribute detectorType = "FAST";
        }

        part stereoAggregator : StereoFeatureAggregator;

        part depthEstimator : DepthEstimator {
            attribute baseline = 0.12 [m];
            attribute focalLength = 0.008 [m];
        }

        part featureTracker : FeatureTracker {
            attribute maxLostFrames = 3;
            attribute minTrackedFeatures = 20;
        }

        part motionEstimator : MotionEstimator {
            attribute minTrackedFeatures = 20;
            attribute motionModel = "PnP";
        }

        part poseIntegrator : PoseIntegrator {
            attribute currentPose : Pose = Pose {
                x = 0.0 [m];
                y = 0.0 [m];
                z = 0.0 [m];
                roll = 0.0 [rad];
                pitch = 0.0 [rad];
                yaw = 0.0 [rad];
                timestamp = 0.0 [s];
                confidence = 100.0 [percent];
                totalDistanceTraveled = 0.0 [m];
            };
        }

        // ---- Connections ----
        connection leftImageFlow connect stereoCamera.leftCamera.imageOut to featureDetectorLeft.imageIn;
        connection rightImageFlow connect stereoCamera.rightCamera.imageOut to featureDetectorRight.imageIn;
        connection leftFeatureFlow connect featureDetectorLeft.featureOut to stereoAggregator.leftFeatureIn;
        connection rightFeatureFlow connect featureDetectorRight.featureOut to stereoAggregator.rightFeatureIn;
        connection stereoFeatureFlow connect stereoAggregator.stereoFeatureOut to depthEstimator.stereoFeaturesIn;
        connection landmarkFlow connect depthEstimator.landmarkOut to featureTracker.landmarksIn;
        connection trackedLandmarkFlow connect featureTracker.trackedOut to motionEstimator.trackedIn;
        connection motionFlow connect motionEstimator.motionOut to poseIntegrator.motionIn;
        connection poseFlow connect poseIntegrator.poseOut to poseOutput;

        // ---- State Machine ----
        state def OdometryStateMachine {
            attribute initialized : Boolean = false;
            attribute ready : Boolean = false;
            attribute active : Boolean = false;

            state Initializing {
                entry action initializeAction : InitializeSystem {
                    bind out initialized to initialized;
                }
                transition init_to_ready
                    from Initializing
                    to Ready
                    when initialized;
            }

            state Ready {
                entry action resetAction : ResetPose {
                    bind out pose to poseIntegrator.currentPose;
                }
                transition ready_to_active
                    from Ready
                    to ActiveTracking
                    when commandIn.startCommand;
            }

            state ActiveTracking {
                entry;
                do action processingLoop {
                    // Continuous capture-and-process cycle
                    action capture : CaptureStereoPair {
                        bind out pair to stereoCamera.stereoOut.stereoPair;
                    }
                    action detectLeft : DetectFeatures {
                        bind in image to stereoCamera.stereoOut.stereoPair.leftImage;
                        bind out features to featureDetectorLeft.featureOut.features;
                    }
                    action detectRight : DetectFeatures {
                        bind in image to stereoCamera.stereoOut.stereoPair.rightImage;
                        bind out features to featureDetectorRight.featureOut.features;
                    }
                    action aggregate : AggregateStereoFeatures {
                        bind in leftFeatures to featureDetectorLeft.featureOut.features;
                        bind in rightFeatures to featureDetectorRight.featureOut.features;
                        bind out stereoFeatures to stereoAggregator.stereoFeatureOut.stereoFeatures;
                    }
                    action estimateDepthAction : EstimateDepth {
                        bind in stereoFeatures to stereoAggregator.stereoFeatureOut.stereoFeatures;
                        bind out landmarks to depthEstimator.landmarkOut.landmarks;
                    }
                    action track : TrackFeatures {
                        bind in currentLandmarks to depthEstimator.landmarkOut.landmarks;
                        bind in previousLandmarks to featureTracker.previousLandmarks;
                        bind out trackedLandmarks to featureTracker.trackedOut.trackedLandmarks;
                    }
                    action estimateMotionAction : EstimateMotion {
                        bind in trackedLandmarks to featureTracker.trackedOut.trackedLandmarks;
                        bind out motion to motionEstimator.motionOut.motion;
                    }
                    action integrate : IntegrateMotion {
                        bind in motion to motionEstimator.motionOut.motion;
                        bind in previousPose to poseIntegrator.currentPose;
                        bind out updatedPose to poseIntegrator.currentPose;
                    }
                    then capture;
                }
                transition active_to_ready
                    from ActiveTracking
                    to Ready
                    when commandIn.stopCommand;
                transition active_to_initializing
                    from ActiveTracking
                    to Initializing
                    when commandIn.resetCommand;
            }
        }

        attribute stateMachine : OdometryStateMachine;

        // ---- Requirements Satisfaction ----
        satisfy PositionUpdateRate by systemName;
        satisfy TrackingRobustness by featureTracker;
        satisfy AccuracyRequirement by poseIntegrator;
        satisfy RealTimeProcessing by systemName;
    }

    // ---- Requirements ----
    requirement def PositionUpdateRate {
        doc /* The system shall provide at least 15 position updates per second. */;
        subject system : VisualOdometrySystem;
        constraint {
            system.updateRate >= 15.0 [Hz];
        }
    }

    requirement def TrackingRobustness {
        doc /* The system shall maintain tracking even if some visual features are lost. */;
        subject tracker : FeatureTracker;
        constraint {
            tracker.maxLostFrames >= 3;
        }
    }

    requirement def AccuracyRequirement {
        doc /* The system shall maintain pose accuracy within 2% of total distance traveled. */;
        subject integrator : PoseIntegrator;
        constraint {
            // Position error bounded by 2% of total distance traveled
            integrator.currentPose.confidence >= 98.0 [percent];
        }
    }

    requirement def RealTimeProcessing {
        doc /* The system shall process each stereo image pair within 66 ms. */;
        subject system : VisualOdometrySystem;
        constraint {
            system.maxProcessingTime <= 66.0 [ms];
        }
    }

    requirement def StereoCameraRequirement {
        doc /* The system shall use a stereo camera with two lenses for depth perception. */;
        subject camera : StereoCamera;
        constraint {
            camera.leftCamera.isCalibrated == true;
            camera.rightCamera.isCalibrated == true;
            camera.baseline > 0.0 [m];
        }
    }

    requirement def OperationalStatesRequirement {
        doc /* The system shall support initializing, ready, and active tracking states. */;
        subject system : VisualOdometrySystem;
        constraint {
            system.stateMachine.initialized == true or
            system.stateMachine.ready == true or
            system.stateMachine.active == true;
        }
    }
}
