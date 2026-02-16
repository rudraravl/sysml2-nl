package VisualOdometrySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ImageFrame {
        attribute timestamp : TimeValue;
        attribute frameId : Integer;
        attribute width : Integer;
        attribute height : Integer;
    }
    
    attribute def FeaturePoint {
        attribute x : Real;
        attribute y : Real;
        attribute descriptor : Real[*];
    }
    
    attribute def FeatureSet {
        attribute points : FeaturePoint[*];
        attribute count : Integer;
    }
    
    value def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    value def Orientation3D {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    
    value def Pose {
        attribute position : Position3D;
        attribute orientation : Orientation3D;
        attribute timestamp : TimeValue;
        attribute confidence : Real;
    }
    
    value def RelativeMotion {
        attribute translation : Position3D;
        attribute rotation : Orientation3D;
    }
    
    port def ImageStreamPort {
        out item imageData : ImageFrame;
    }
    
    port def FeaturePort {
        out item features : FeatureSet;
    }
    
    port def MotionPort {
        out item motion : RelativeMotion;
    }
    
    port def PosePort {
        out item currentPose : Pose;
    }
    
    part def StereoCamera {
        attribute baseline : LengthValue;
        attribute frameRate : FrequencyValue;
        attribute focalLength : LengthValue;
        attribute resolution : Integer[2];
        
        port leftImageOut : ImageStreamPort;
        port rightImageOut : ImageStreamPort;
        
        action def CaptureStereoPair {
            out leftFrame : ImageFrame;
            out rightFrame : ImageFrame;
        }
    }
    
    part def FeatureDetector {
        attribute minFeatures : Integer;
        attribute maxFeatures : Integer;
        attribute qualityThreshold : Real;
        
        port leftImageIn {
            in item leftImage : ImageFrame;
        }
        port rightImageIn {
            in item rightImage : ImageFrame;
        }
        port leftFeaturesOut : FeaturePort;
        port rightFeaturesOut : FeaturePort;
        
        action def DetectFeatures {
            in image : ImageFrame;
            out features : FeatureSet;
        }
    }
    
    part def FeatureTracker {
        attribute trackingWindow : Integer;
        attribute maxTrackingError : Real;
        
        port currentFeaturesIn {
            in item currentFeatures : FeatureSet;
        }
        port previousFeaturesIn {
            in item previousFeatures : FeatureSet;
        }
        port trackedFeaturesOut {
            out item trackedPairs : FeatureSet;
        }
        
        action def TrackFeatures {
            in current : FeatureSet;
            in previous : FeatureSet;
            out tracked : FeatureSet;
        }
    }
    
    part def DepthEstimator {
        attribute baselineDistance : LengthValue;
        attribute focalLength : LengthValue;
        
        port leftFeaturesIn {
            in item leftFeatures : FeatureSet;
        }
        port rightFeaturesIn {
            in item rightFeatures : FeatureSet;
        }
        port depthFeaturesOut {
            out item features3D : FeatureSet;
        }
        
        action def ComputeDepth {
            in leftFeatures : FeatureSet;
            in rightFeatures : FeatureSet;
            out features3D : FeatureSet;
        }
    }
    
    part def MotionEstimator {
        attribute ransacIterations : Integer;
        attribute inlierThreshold : Real;
        
        port trackedFeaturesIn {
            in item trackedFeatures : FeatureSet;
        }
        port motionOut : MotionPort;
        
        action def EstimateMotion {
            in trackedFeatures : FeatureSet;
            out relativeMotion : RelativeMotion;
            out confidence : Real;
        }
    }
    
    part def PoseIntegrator {
        attribute initialPose : Pose;
        attribute driftCompensation : Boolean;
        
        port motionIn {
            in item motion : RelativeMotion;
        }
        port poseOut : PosePort;
        
        attribute currentPose : Pose := initialPose;
        
        action def IntegratePose {
            in deltaMotion : RelativeMotion;
            in previousPose : Pose;
            out updatedPose : Pose;
        }
    }
    
    part def VisualOdometryProcessor {
        part camera : StereoCamera;
        part featureDetector : FeatureDetector;
        part featureTracker : FeatureTracker;
        part depthEstimator : DepthEstimator;
        part motionEstimator : MotionEstimator;
        part poseIntegrator : PoseIntegrator;
        
        private attribute previousLeftFeatures : FeatureSet;
        private attribute previousRightFeatures : FeatureSet;
        
        port systemPoseOut : PosePort;
        
        bind camera.leftImageOut = featureDetector.leftImageIn;
        bind camera.rightImageOut = featureDetector.rightImageIn;
        bind featureDetector.leftFeaturesOut = depthEstimator.leftFeaturesIn;
        bind featureDetector.rightFeaturesOut = depthEstimator.rightFeaturesIn;
        bind featureDetector.leftFeaturesOut = featureTracker.currentFeaturesIn;
        bind featureTracker.trackedFeaturesOut = motionEstimator.trackedFeaturesIn;
        bind motionEstimator.motionOut = poseIntegrator.motionIn;
        bind poseIntegrator.poseOut = systemPoseOut;
    }
    
    action def ProcessVisualOdometry {
        in imageSequence : ImageFrame[*] ordered;
        in initialPose : Pose;
        out trajectory : Pose[*] ordered;
        
        private attribute currentPose : Pose := initialPose;
        private attribute previousFeatures : FeatureSet;
        private attribute poseSequence : Pose[*] := (initialPose);
        private attribute frameIndex : Integer := 0;
        
        first start;
        action initializeFirstFrame {
            in firstImage : ImageFrame;
            out initialFeatures : FeatureSet;
        }
        then assign previousFeatures := initializeFirstFrame.initialFeatures;
        then assign frameIndex := 1;
        then merge odometryLoop;
        
        for currentImage in imageSequence {
            action detectCurrentFeatures {
                in image : ImageFrame = currentImage;
                out features : FeatureSet;
            }
            then action trackBetweenFrames {
                in current : FeatureSet = detectCurrentFeatures.features;
                in previous : FeatureSet = previousFeatures;
                out tracked : FeatureSet;
            }
            then action estimateRelativeMotion {
                in trackedFeatures : FeatureSet = trackBetweenFrames.tracked;
                out motion : RelativeMotion;
                out confidence : Real;
            }
            then action updateCurrentPose {
                in deltaMotion : RelativeMotion = estimateRelativeMotion.motion;
                in lastPose : Pose = currentPose;
                out newPose : Pose;
            }
            then assign currentPose := updateCurrentPose.newPose;
            then assign poseSequence := poseSequence->including(currentPose);
            then assign previousFeatures := detectCurrentFeatures.features;
            then assign frameIndex := frameIndex + 1;
            then odometryLoop;
        }
        then assign trajectory := poseSequence;
        then done;
    }
    
    state def VisualOdometryOperationalState {
        entry; then initializing;
        
        state initializing {
            doc /* System initializes camera and calibration parameters */
        }
        accept calibrationComplete;
        then ready;
        
        state ready {
            doc /* System is ready to process images */
        }
        accept startTracking;
        then tracking;
        
        state tracking {
            entry; then captureFrame;
            
            state captureFrame {
                doc /* Capture stereo image pair */
            }
            then featureDetection;
            
            state featureDetection {
                doc /* Detect features in both images */
            }
            then depthEstimation;
            
            state featureTracking {
                doc /* Track features from previous frame */
            }
            
            state depthEstimation {
                doc /* Compute 3D positions of features */
            }
            then featureTracking;
            then motionEstimation;
            
            state motionEstimation {
                doc /* Estimate camera motion from tracked features */
            }
            then poseUpdate;
            
            state poseUpdate {
                doc /* Integrate motion to update pose estimate */
            }
            then captureFrame;
        }
        accept stopTracking;
        then ready;
        
        accept shutdown;
        then final;
    }
    
    requirement def VisualOdometryRequirements {
        doc /* The visual odometry system shall estimate the 6-DOF pose (position and orientation) 
             of a moving platform by analyzing sequential stereo camera images to track visual features 
             and compute incremental motion. */
        
        requirement <'VO-REQ-001'> primaryFunction {
            doc /* The system shall continuously estimate the position and orientation of the platform 
                 relative to its starting point by processing stereo image pairs. */
            
            subject voSystem : VisualOdometryProcessor;
        }
        
        requirement <'VO-REQ-002'> positionAccuracy {
            doc /* The system shall maintain position estimation accuracy within 2% of distance traveled 
                 over trajectories up to 100 meters under nominal lighting conditions. */
            
            subject voSystem : VisualOdometryProcessor;
            
            attribute distanceTraveled : LengthValue;
            attribute positionError : LengthValue;
            
            require constraint {
                positionError <= 0.02 * distanceTraveled
            }
        }
        
        requirement <'VO-REQ-003'> updateRate {
            doc /* The system shall provide pose updates at a minimum rate of 15 Hz to support 
                 real-time navigation applications. */
            
            subject voSystem : VisualOdometryProcessor;
            
            attribute poseUpdateRate : FrequencyValue;
            
            require constraint {
                poseUpdateRate >= 15.0[Hz]
            }
        }
        
        requirement <'VO-REQ-004'> featureTracking {
            doc /* The system shall maintain tracking of at least 50 feature points between 
                 consecutive frames under nominal conditions. */
            
            subject tracker : FeatureTracker;
            
            attribute trackedFeatureCount : Integer;
            
            require constraint {
                trackedFeatureCount >= 50
            }
        }
        
        requirement <'VO-REQ-005'> robustness {
            doc /* The system shall continue to provide pose estimates when at least 30% of 
                 features are successfully tracked between frames. */
            
            subject estimator : MotionEstimator;
            
            attribute trackingRatio : Real;
            
            require constraint {
                trackingRatio >= 0.30
            }
        }
        
        requirement <'VO-REQ-006'> initialization {
            doc /* The system shall initialize and begin providing pose estimates within 
                 5 frames from system start. */
            
            subject voSystem : VisualOdometryProcessor;
            
            attribute initializationFrames : Integer;
            
            require constraint {
                initializationFrames <= 5
            }
        }
    }
    
    part visualOdometrySystem : VisualOdometryProcessor {
        perform action processOdometry : ProcessVisualOdometry {
            in imageSequence;
            in initialPose = Pose {
                position = Position3D { x = 0.0[m]; y = 0.0[m]; z = 0.0[m]; }
                orientation = Orientation3D { roll = 0.0; pitch = 0.0; yaw = 0.0; }
                timestamp = 0.0[s];
                confidence = 1.0;
            }
            out trajectory;
        }
        
        exhibit state operationalState : VisualOdometryOperationalState;
        
        satisfy VisualOdometryRequirements::primaryFunction;
        satisfy VisualOdometryRequirements::positionAccuracy;
        satisfy VisualOdometryRequirements::updateRate;
        satisfy VisualOdometryRequirements::featureTracking;
        satisfy VisualOdometryRequirements::robustness;
        satisfy VisualOdometryRequirements::initialization;
    }
}
