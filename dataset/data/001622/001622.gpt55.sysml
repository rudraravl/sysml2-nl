package VisualOdometrySystemModel {
    import ScalarValues::*;

    attribute def Pixel_px :> Integer;
    attribute def Count :> Integer;
    attribute def Ratio :> Real;
    attribute def Confidence_0to1 :> Real;
    attribute def Duration_s :> Real;
    attribute def Frequency_Hz :> Real;
    attribute def Length_m :> Real;
    attribute def Area_px2 :> Real;
    attribute def Angle_rad :> Real;
    attribute def AngularRate_radps :> Real;
    attribute def Velocity_mps :> Real;
    attribute def Acceleration_mps2 :> Real;
    attribute def Luminance_cdpm2 :> Real;
    attribute def Temperature_C :> Real;
    attribute def DataRate_Mbps :> Real;
    attribute def Memory_MB :> Real;

    enum def TrackingMode {
        enum idle;
        enum initializing;
        enum monocularTracking;
        enum stereoTracking;
        enum visualInertialTracking;
        enum relocalizing;
        enum degraded;
        enum lost;
        enum fault;
    }

    enum def FeatureKind {
        enum corner;
        enum blob;
        enum edgelet;
        enum learnedKeypoint;
    }

    enum def CoordinateFrameKind {
        enum cameraLeftOptical;
        enum cameraRightOptical;
        enum imuBody;
        enum platformBody;
        enum visualOdometryLocal;
        enum worldAligned;
    }

    enum def HealthLevel {
        enum nominal;
        enum caution;
        enum degraded;
        enum critical;
        enum failed;
    }

    enum def CommandKind {
        enum powerOn;
        enum powerOff;
        enum reset;
        enum startTracking;
        enum stopTracking;
        enum recalibrate;
        enum requestRelocalization;
    }

    item def TimeTag {
        attribute time_s : Duration_s;
        attribute sequenceId : Count;
    }

    item def CameraIntrinsics {
        attribute focalLengthX_px : Pixel_px;
        attribute focalLengthY_px : Pixel_px;
        attribute principalPointX_px : Pixel_px;
        attribute principalPointY_px : Pixel_px;
        attribute radialK1 : Ratio;
        attribute radialK2 : Ratio;
        attribute radialK3 : Ratio;
        attribute tangentialP1 : Ratio;
        attribute tangentialP2 : Ratio;
        attribute imageWidth_px : Pixel_px;
        attribute imageHeight_px : Pixel_px;
        attribute valid : Boolean;
    }

    item def CameraExtrinsics {
        attribute baseline_m : Length_m;
        attribute roll_rad : Angle_rad;
        attribute pitch_rad : Angle_rad;
        attribute yaw_rad : Angle_rad;
        attribute translationX_m : Length_m;
        attribute translationY_m : Length_m;
        attribute translationZ_m : Length_m;
        attribute sourceFrame : CoordinateFrameKind;
        attribute targetFrame : CoordinateFrameKind;
        attribute valid : Boolean;
    }

    item def ImageFrame {
        attribute tag : TimeTag;
        attribute width_px : Pixel_px;
        attribute height_px : Pixel_px;
        attribute exposure_s : Duration_s;
        attribute gain : Ratio;
        attribute meanLuminance_cdpm2 : Luminance_cdpm2;
        attribute motionBlurScore : Ratio;
        attribute dropped : Boolean;
    }

    item def StereoImagePair {
        attribute tag : TimeTag;
        attribute left : ImageFrame;
        attribute right : ImageFrame;
        attribute timeSkew_s : Duration_s;
        attribute rectified : Boolean;
    }

    item def ImuSample {
        attribute tag : TimeTag;
        attribute accelerationX_mps2 : Acceleration_mps2;
        attribute accelerationY_mps2 : Acceleration_mps2;
        attribute accelerationZ_mps2 : Acceleration_mps2;
        attribute angularRateX_radps : AngularRate_radps;
        attribute angularRateY_radps : AngularRate_radps;
        attribute angularRateZ_radps : AngularRate_radps;
        attribute temperature_C : Temperature_C;
    }

    item def FeatureObservation {
        attribute id : Count;
        attribute kind : FeatureKind;
        attribute x_px : Pixel_px;
        attribute y_px : Pixel_px;
        attribute scale_px : Pixel_px;
        attribute orientation_rad : Angle_rad;
        attribute descriptorDistance : Ratio;
        attribute response : Ratio;
        attribute ageFrames : Count;
    }

    item def FeatureTrackSet {
        attribute tag : TimeTag;
        attribute featureCount : Count;
        attribute trackedCount : Count;
        attribute inlierCount : Count;
        attribute meanReprojectionError_px : Pixel_px;
        attribute trackCoverage_px2 : Area_px2;
    }

    item def LandmarkMap {
        attribute landmarkCount : Count;
        attribute activeLandmarkCount : Count;
        attribute keyframeCount : Count;
        attribute averageParallax_rad : Angle_rad;
        attribute localMapRadius_m : Length_m;
        attribute memoryUse_MB : Memory_MB;
    }

    item def Pose6D {
        attribute tag : TimeTag;
        attribute frame : CoordinateFrameKind;
        attribute x_m : Length_m;
        attribute y_m : Length_m;
        attribute z_m : Length_m;
        attribute roll_rad : Angle_rad;
        attribute pitch_rad : Angle_rad;
        attribute yaw_rad : Angle_rad;
    }

    item def Velocity6D {
        attribute linearX_mps : Velocity_mps;
        attribute linearY_mps : Velocity_mps;
        attribute linearZ_mps : Velocity_mps;
        attribute angularX_radps : AngularRate_radps;
        attribute angularY_radps : AngularRate_radps;
        attribute angularZ_radps : AngularRate_radps;
    }

    item def PoseCovariance {
        attribute xx_m2 : Real;
        attribute yy_m2 : Real;
        attribute zz_m2 : Real;
        attribute rollroll_rad2 : Real;
        attribute pitchpitch_rad2 : Real;
        attribute yawyaw_rad2 : Real;
        attribute maxPositionSigma_m : Length_m;
        attribute maxAttitudeSigma_rad : Angle_rad;
    }

    item def OdometryEstimate {
        attribute tag : TimeTag;
        attribute pose : Pose6D;
        attribute velocity : Velocity6D;
        attribute covariance : PoseCovariance;
        attribute confidence : Confidence_0to1;
        attribute visualInlierCount : Count;
        attribute localDriftRate : Ratio;
        attribute valid : Boolean;
    }

    item def HealthReport {
        attribute tag : TimeTag;
        attribute level : HealthLevel;
        attribute mode : TrackingMode;
        attribute frameRate_Hz : Frequency_Hz;
        attribute featureCount : Count;
        attribute inlierRatio : Ratio;
        attribute timeSinceLastValidPose_s : Duration_s;
        attribute processingLatency_s : Duration_s;
        attribute dataRate_Mbps : DataRate_Mbps;
        attribute message : String;
    }

    item def VisualOdometryCommand {
        attribute tag : TimeTag;
        attribute kind : CommandKind;
        attribute requestedOutputRate_Hz : Frequency_Hz;
        attribute forceMapReset : Boolean;
    }

    port def ImageFrameOutPort {
        out item frame : ImageFrame;
    }

    port def ImageFrameInPort {
        in item frame : ImageFrame;
    }

    port def StereoPairOutPort {
        out item pair : StereoImagePair;
    }

    port def StereoPairInPort {
        in item pair : StereoImagePair;
    }

    port def ImuSampleInPort {
        in item sample : ImuSample;
    }

    port def ImuSampleOutPort {
        out item sample : ImuSample;
    }

    port def CalibrationInPort {
        in item intrinsics : CameraIntrinsics;
        in item extrinsics : CameraExtrinsics;
    }

    port def FeatureTrackOutPort {
        out item tracks : FeatureTrackSet;
    }

    port def FeatureTrackInPort {
        in item tracks : FeatureTrackSet;
    }

    port def MapOutPort {
        out item map : LandmarkMap;
    }

    port def MapInPort {
        in item map : LandmarkMap;
    }

    port def OdometryOutPort {
        out item odometry : OdometryEstimate;
    }

    port def OdometryInPort {
        in item odometry : OdometryEstimate;
    }

    port def HealthOutPort {
        out item health : HealthReport;
    }

    port def HealthInPort {
        in item health : HealthReport;
    }

    port def CommandInPort {
        in item command : VisualOdometryCommand;
    }

    port def CommandOutPort {
        out item command : VisualOdometryCommand;
    }

    constraint def MinimumFrameRateConstraint {
        in frameRate_Hz : Frequency_Hz;
        frameRate_Hz >= 20.0
    }

    constraint def MaximumLatencyConstraint {
        in latency_s : Duration_s;
        latency_s <= 0.050
    }

    constraint def MinimumFeatureConstraint {
        in trackedFeatureCount : Count;
        trackedFeatureCount >= 120
    }

    constraint def MinimumInlierRatioConstraint {
        in inlierRatio : Ratio;
        inlierRatio >= 0.55
    }

    constraint def PoseValidityConstraint {
        in confidence : Confidence_0to1;
        in covariancePositionSigma_m : Length_m;
        confidence >= 0.70 and covariancePositionSigma_m <= 0.25
    }

    action def CaptureStereoImages {
        out leftFrame : ImageFrame;
        out rightFrame : ImageFrame;
    }

    action def SynchronizeStereoPair {
        in leftFrame : ImageFrame;
        in rightFrame : ImageFrame;
        out synchronizedPair : StereoImagePair;

        action validateTimestamps;
        action pairFrames;
        action estimateTimeSkew;
        first validateTimestamps then pairFrames;
        then estimateTimeSkew;
    }

    action def RectifyAndNormalizeImages {
        in rawPair : StereoImagePair;
        in intrinsics : CameraIntrinsics;
        in extrinsics : CameraExtrinsics;
        out rectifiedPair : StereoImagePair;

        action undistort;
        action rectifyEpipolarGeometry;
        action normalizeBrightness;
        first undistort then rectifyEpipolarGeometry;
        then normalizeBrightness;
    }

    action def DetectAndTrackFeatures {
        in rectifiedPair : StereoImagePair;
        out tracks : FeatureTrackSet;

        action detectKeypoints;
        action computeDescriptors;
        action matchStereo;
        action trackTemporally;
        action rejectOutliers;
        first detectKeypoints then computeDescriptors;
        then matchStereo;
        then trackTemporally;
        then rejectOutliers;
    }

    action def EstimateRelativeMotion {
        in tracks : FeatureTrackSet;
        in previousMap : LandmarkMap;
        in imuSample : ImuSample;
        out poseDelta : Pose6D;
        out confidence : Confidence_0to1;

        action predictMotionFromPrior;
        action solveEpipolarGeometry;
        action triangulateLandmarks;
        action optimizePose;
        action computeConfidence;
        first predictMotionFromPrior then solveEpipolarGeometry;
        then triangulateLandmarks;
        then optimizePose;
        then computeConfidence;
    }

    action def UpdateLocalMap {
        in tracks : FeatureTrackSet;
        in poseDelta : Pose6D;
        in previousMap : LandmarkMap;
        out updatedMap : LandmarkMap;

        action selectKeyframes;
        action addNewLandmarks;
        action cullWeakLandmarks;
        action runLocalBundleAdjustment;
        first selectKeyframes then addNewLandmarks;
        then cullWeakLandmarks;
        then runLocalBundleAdjustment;
    }

    action def PublishVisualOdometry {
        in poseDelta : Pose6D;
        in updatedMap : LandmarkMap;
        in confidence : Confidence_0to1;
        out estimate : OdometryEstimate;
        out health : HealthReport;

        action integratePose;
        action estimateVelocity;
        action computeCovariance;
        action classifyHealth;
        action publishMessages;
        first integratePose then estimateVelocity;
        then computeCovariance;
        then classifyHealth;
        then publishMessages;
    }

    action def PerformVisualOdometry {
        in command : VisualOdometryCommand;
        in imuSample : ImuSample;
        out estimate : OdometryEstimate;
        out health : HealthReport;

        action capture : CaptureStereoImages;
        action synchronize : SynchronizeStereoPair;
        action rectify : RectifyAndNormalizeImages;
        action track : DetectAndTrackFeatures;
        action estimateMotion : EstimateRelativeMotion;
        action updateMap : UpdateLocalMap;
        action publish : PublishVisualOdometry;

        first capture then synchronize;
        then rectify;
        then track;
        then estimateMotion;
        then updateMap;
        then publish;

        flow capture.leftFrame to synchronize.leftFrame;
        flow capture.rightFrame to synchronize.rightFrame;
        flow synchronize.synchronizedPair to rectify.rawPair;
        flow rectify.rectifiedPair to track.rectifiedPair;
        flow track.tracks to estimateMotion.tracks;
        flow track.tracks to updateMap.tracks;
        flow estimateMotion.poseDelta to updateMap.poseDelta;
        flow estimateMotion.poseDelta to publish.poseDelta;
        flow estimateMotion.confidence to publish.confidence;
        flow updateMap.updatedMap to publish.updatedMap;
        flow publish.estimate to estimate;
        flow publish.health to health;
    }

    state def VisualOdometryLifecycle {
        state off;
        state booting;
        state calibrating;
        state ready;
        state tracking;
        state degradedTracking;
        state relocalizing;
        state lost;
        state faulted;
        state shuttingDown;

        transition powerOn first off then booting accept VisualOdometryCommand;
        transition bootComplete first booting then calibrating;
        transition calibrationValid first calibrating then ready;
        transition startTracking first ready then tracking accept VisualOdometryCommand;
        transition lowFeatureQuality first tracking then degradedTracking;
        transition qualityRecovered first degradedTracking then tracking;
        transition poseLost first degradedTracking then relocalizing;
        transition relocalizationSucceeded first relocalizing then tracking;
        transition relocalizationTimedOut first relocalizing then lost;
        transition resetFromLost first lost then calibrating accept VisualOdometryCommand;
        transition unrecoverableError first tracking then faulted;
        transition faultDuringAnyMode first degradedTracking then faulted;
        transition resetFault first faulted then booting accept VisualOdometryCommand;
        transition stopTracking first tracking then ready accept VisualOdometryCommand;
        transition powerOffFromReady first ready then shuttingDown accept VisualOdometryCommand;
        transition shutdownComplete first shuttingDown then off;
    }

    part def MonochromeGlobalShutterCamera {
        attribute name : String;
        attribute resolutionWidth_px : Pixel_px = 1280;
        attribute resolutionHeight_px : Pixel_px = 720;
        attribute maximumFrameRate_Hz : Frequency_Hz = 60.0;
        attribute exposure_s : Duration_s = 0.004;
        attribute focalLength_m : Length_m = 0.0036;
        attribute horizontalFieldOfView_rad : Angle_rad = 1.57;
        attribute dataRate_Mbps : DataRate_Mbps = 650.0;

        port frameOut : ImageFrameOutPort;
        port calibrationIn : CalibrationInPort;
        port healthOut : HealthOutPort;
    }

    part def StereoCameraRig {
        attribute baseline_m : Length_m = 0.120;
        attribute nominalFrameRate_Hz : Frequency_Hz = 30.0;
        attribute maxTimeSkew_s : Duration_s = 0.001;
        attribute rigidMountValid : Boolean = true;

        part leftCamera : MonochromeGlobalShutterCamera {
            :>> name = "left global shutter camera";
        }

        part rightCamera : MonochromeGlobalShutterCamera {
            :>> name = "right global shutter camera";
        }

        port leftFrameOut : ImageFrameOutPort;
        port rightFrameOut : ImageFrameOutPort;
        port calibrationIn : CalibrationInPort;
        port healthOut : HealthOutPort;

        connect leftCamera.frameOut to leftFrameOut;
        connect rightCamera.frameOut to rightFrameOut;
        connect calibrationIn to leftCamera.calibrationIn;
        connect calibrationIn to rightCamera.calibrationIn;
    }

    part def InertialMeasurementUnit {
        attribute sampleRate_Hz : Frequency_Hz = 200.0;
        attribute gyroNoise_radps : AngularRate_radps = 0.0015;
        attribute accelNoise_mps2 : Acceleration_mps2 = 0.020;
        attribute timeAlignmentError_s : Duration_s = 0.0005;

        port sampleOut : ImuSampleOutPort;
        port healthOut : HealthOutPort;
    }

    part def FrameSynchronizer {
        attribute acceptedMaxSkew_s : Duration_s = 0.002;
        attribute outputRate_Hz : Frequency_Hz = 30.0;
        attribute droppedFrameWindow : Count = 30;

        port leftImageIn : ImageFrameInPort;
        port rightImageIn : ImageFrameInPort;
        port stereoPairOut : StereoPairOutPort;
        port healthOut : HealthOutPort;

        perform action synchronizeBehavior : SynchronizeStereoPair;
    }

    part def ImagePreprocessor {
        attribute histogramClipLimit : Ratio = 0.020;
        attribute rectificationResidual_px : Pixel_px = 1;
        attribute minimumMeanLuminance_cdpm2 : Luminance_cdpm2 = 5.0;

        port stereoPairIn : StereoPairInPort;
        port calibrationIn : CalibrationInPort;
        port rectifiedPairOut : StereoPairOutPort;
        port healthOut : HealthOutPort;

        perform action preprocessingBehavior : RectifyAndNormalizeImages;
    }

    part def FeaturePipeline {
        attribute targetFeatureCount : Count = 850;
        attribute minimumTrackedFeatureCount : Count = 120;
        attribute pyramidLevels : Count = 4;
        attribute maximumReprojectionError_px : Pixel_px = 3;
        attribute minimumTrackAgeFrames : Count = 3;

        port rectifiedPairIn : StereoPairInPort;
        port trackSetOut : FeatureTrackOutPort;
        port healthOut : HealthOutPort;

        perform action featureBehavior : DetectAndTrackFeatures;
    }

    part def MotionEstimator {
        attribute solverMaxIterations : Count = 20;
        attribute ransacThreshold_px : Pixel_px = 2;
        attribute minimumInlierRatio : Ratio = 0.55;
        attribute maximumPoseJump_m : Length_m = 1.50;
        attribute maximumYawJump_rad : Angle_rad = 0.35;

        port trackSetIn : FeatureTrackInPort;
        port mapIn : MapInPort;
        port imuIn : ImuSampleInPort;
        port poseOut : OdometryOutPort;
        port healthOut : HealthOutPort;

        perform action motionBehavior : EstimateRelativeMotion;
    }

    part def LocalMapManager {
        attribute maximumActiveLandmarks : Count = 5000;
        attribute maximumKeyframes : Count = 30;
        attribute keyframeTranslationThreshold_m : Length_m = 0.20;
        attribute keyframeRotationThreshold_rad : Angle_rad = 0.10;
        attribute localBundleAdjustmentRate_Hz : Frequency_Hz = 5.0;
        attribute memoryBudget_MB : Memory_MB = 256.0;

        port tracksIn : FeatureTrackInPort;
        port odometryIn : OdometryInPort;
        port mapOut : MapOutPort;
        port healthOut : HealthOutPort;

        perform action mapBehavior : UpdateLocalMap;
    }

    part def QualityMonitor {
        attribute minimumOutputRate_Hz : Frequency_Hz = 20.0;
        attribute maximumLatency_s : Duration_s = 0.050;
        attribute minimumConfidence : Confidence_0to1 = 0.70;
        attribute maximumCovarianceSigma_m : Length_m = 0.25;
        attribute lostTimeout_s : Duration_s = 1.0;

        port odometryIn : OdometryInPort;
        port tracksIn : FeatureTrackInPort;
        port mapIn : MapInPort;
        port healthOut : HealthOutPort;
    }

    part def OdometryPublisher {
        attribute outputRate_Hz : Frequency_Hz = 30.0;
        attribute processingLatency_s : Duration_s = 0.035;
        attribute outputFrame : CoordinateFrameKind = CoordinateFrameKind::visualOdometryLocal;
        attribute publishCovariance : Boolean = true;

        port odometryIn : OdometryInPort;
        port healthIn : HealthInPort;
        port odometryOut : OdometryOutPort;
        port healthOut : HealthOutPort;

        perform action publishBehavior : PublishVisualOdometry;
    }

    part def VisualOdometrySystem {
        doc /* Primary high-level function: estimate the relative six-degree-of-freedom motion of a camera-equipped platform by observing changes in visual image features over time, maintaining a local landmark map, assessing confidence, and publishing timestamped pose and velocity odometry for navigation or perception consumers. */

        attribute operatingMode : TrackingMode = TrackingMode::idle;
        attribute designedOutputRate_Hz : Frequency_Hz = 30.0;
        attribute designedEndToEndLatency_s : Duration_s = 0.035;
        attribute designPoseConfidence : Confidence_0to1 = 0.80;
        attribute nominalBaseline_m : Length_m = 0.120;
        attribute maximumAllowedTimeSkew_s : Duration_s = 0.002;

        port commandIn : CommandInPort;
        port calibrationIn : CalibrationInPort;
        port externalImuIn : ImuSampleInPort;
        port odometryOut : OdometryOutPort;
        port healthOut : HealthOutPort;

        part stereoRig : StereoCameraRig;
        part imu : InertialMeasurementUnit;
        part synchronizer : FrameSynchronizer;
        part preprocessor : ImagePreprocessor;
        part featurePipeline : FeaturePipeline;
        part estimator : MotionEstimator;
        part mapManager : LocalMapManager;
        part monitor : QualityMonitor;
        part publisher : OdometryPublisher;

        state lifecycle : VisualOdometryLifecycle;

        perform action mainFunction : PerformVisualOdometry;

        connect calibrationIn to stereoRig.calibrationIn;
        connect stereoRig.leftFrameOut to synchronizer.leftImageIn;
        connect stereoRig.rightFrameOut to synchronizer.rightImageIn;
        connect synchronizer.stereoPairOut to preprocessor.stereoPairIn;
        connect calibrationIn to preprocessor.calibrationIn;
        connect preprocessor.rectifiedPairOut to featurePipeline.rectifiedPairIn;
        connect featurePipeline.trackSetOut to estimator.trackSetIn;
        connect featurePipeline.trackSetOut to mapManager.tracksIn;
        connect featurePipeline.trackSetOut to monitor.tracksIn;
        connect imu.sampleOut to estimator.imuIn;
        connect externalImuIn to estimator.imuIn;
        connect estimator.poseOut to mapManager.odometryIn;
        connect estimator.poseOut to publisher.odometryIn;
        connect estimator.poseOut to monitor.odometryIn;
        connect mapManager.mapOut to estimator.mapIn;
        connect mapManager.mapOut to monitor.mapIn;
        connect monitor.healthOut to publisher.healthIn;
        connect publisher.odometryOut to odometryOut;
        connect publisher.healthOut to healthOut;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall perform visual odometry by estimating timestamped relative 6-DoF pose and velocity from consecutive visual observations and shall publish the result as an odometry estimate with confidence and validity indicators. */
        subject vo : VisualOdometrySystem;
        require constraint {
            vo.designedOutputRate_Hz >= 20.0 and
            vo.designedEndToEndLatency_s <= 0.050 and
            vo.designPoseConfidence >= 0.70
        }
    }

    requirement def StereoAcquisitionRequirement {
        doc /* The stereo imaging subsystem shall provide synchronized global-shutter image pairs suitable for feature tracking. */
        subject rig : StereoCameraRig;
        require constraint {
            rig.nominalFrameRate_Hz >= 30.0 and
            rig.maxTimeSkew_s <= 0.002 and
            rig.baseline_m >= 0.080
        }
    }

    requirement def FeatureTrackingRequirement {
        doc /* The feature pipeline shall retain enough geometrically distributed visual tracks to support robust motion estimation. */
        subject pipeline : FeaturePipeline;
        require constraint {
            pipeline.targetFeatureCount >= 500 and
            pipeline.minimumTrackedFeatureCount >= 120 and
            pipeline.maximumReprojectionError_px <= 3
        }
    }

    requirement def MotionEstimationRequirement {
        doc /* The motion estimator shall reject outliers and produce a bounded pose update when sufficient inlier visual observations are available. */
        subject estimator : MotionEstimator;
        require constraint {
            estimator.minimumInlierRatio >= 0.55 and
            estimator.maximumPoseJump_m <= 1.50 and
            estimator.maximumYawJump_rad <= 0.35
        }
    }

    requirement def MapManagementRequirement {
        doc /* The local map manager shall maintain a bounded local landmark and keyframe set for real-time operation. */
        subject mapper : LocalMapManager;
        require constraint {
            mapper.maximumActiveLandmarks <= 5000 and
            mapper.maximumKeyframes <= 30 and
            mapper.memoryBudget_MB <= 256.0
        }
    }

    requirement def OutputQualityRequirement {
        doc /* The published odometry shall meet minimum real-time quality thresholds during nominal tracking. */
        subject publisher : OdometryPublisher;
        require constraint {
            publisher.outputRate_Hz >= 20.0 and
            publisher.processingLatency_s <= 0.050 and
            publisher.publishCovariance == true
        }
    }

    requirement def HealthMonitoringRequirement {
        doc /* The system shall report health state, tracking mode, frame rate, feature count, inlier ratio, latency, and time since last valid pose. */
        subject monitor : QualityMonitor;
        require constraint {
            monitor.minimumOutputRate_Hz >= 20.0 and
            monitor.maximumLatency_s <= 0.050 and
            monitor.lostTimeout_s <= 1.0
        }
    }

    part visualOdometrySystem : VisualOdometrySystem;

    satisfy PrimaryFunctionRequirement by visualOdometrySystem;
    satisfy StereoAcquisitionRequirement by visualOdometrySystem.stereoRig;
    satisfy FeatureTrackingRequirement by visualOdometrySystem.featurePipeline;
    satisfy MotionEstimationRequirement by visualOdometrySystem.estimator;
    satisfy MapManagementRequirement by visualOdometrySystem.mapManager;
    satisfy OutputQualityRequirement by visualOdometrySystem.publisher;
    satisfy HealthMonitoringRequirement by visualOdometrySystem.monitor;
}
