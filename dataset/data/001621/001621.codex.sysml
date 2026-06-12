package VisionGuidedRoboticSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;
    import Time::*;

    attribute def Probability :> Real;
    attribute def Percent :> Real;
    attribute def PixelCount :> Integer;
    attribute def FrameRate :> Real;
    attribute def Confidence :> Real;
    attribute def Identifier :> String;
    attribute def StatusText :> String;

    enum def RobotOperatingMode {
        enum idle;
        enum calibrating;
        enum perceiving;
        enum planning;
        enum executing;
        enum verifying;
        enum faulted;
        enum emergencyStopped;
    }

    enum def ObjectClass {
        enum unknown;
        enum targetPart;
        enum fixture;
        enum obstacle;
        enum human;
        enum tool;
        enum bin;
    }

    enum def GraspState {
        enum noObject;
        enum objectDetected;
        enum graspPlanned;
        enum graspSecured;
        enum objectReleased;
        enum graspFailed;
    }

    enum def SafetyLevel {
        enum normal;
        enum reducedSpeed;
        enum protectiveStop;
        enum emergencyStop;
    }

    item def ImageFrame {
        attribute frameId : Identifier;
        attribute timestamp : TimeValue;
        attribute width : PixelCount;
        attribute height : PixelCount;
        attribute frameRate : FrameRate;
        attribute exposureTime : TimeValue;
        attribute illuminationLevel : IlluminanceValue;
    }

    item def DepthFrame {
        attribute frameId : Identifier;
        attribute timestamp : TimeValue;
        attribute width : PixelCount;
        attribute height : PixelCount;
        attribute minRange : LengthValue;
        attribute maxRange : LengthValue;
        attribute depthResolution : LengthValue;
    }

    item def ObjectHypothesis {
        attribute objectId : Identifier;
        attribute classification : ObjectClass;
        attribute confidence : Confidence;
        attribute centerX : LengthValue;
        attribute centerY : LengthValue;
        attribute centerZ : LengthValue;
        attribute roll : PlaneAngleValue;
        attribute pitch : PlaneAngleValue;
        attribute yaw : PlaneAngleValue;
        attribute boundingBoxWidth : LengthValue;
        attribute boundingBoxHeight : LengthValue;
        attribute boundingBoxDepth : LengthValue;
    }

    item def RobotPose {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute rx : PlaneAngleValue;
        attribute ry : PlaneAngleValue;
        attribute rz : PlaneAngleValue;
    }

    item def JointState {
        attribute joint1 : PlaneAngleValue;
        attribute joint2 : PlaneAngleValue;
        attribute joint3 : PlaneAngleValue;
        attribute joint4 : PlaneAngleValue;
        attribute joint5 : PlaneAngleValue;
        attribute joint6 : PlaneAngleValue;
        attribute jointVelocityLimit : AngularVelocityValue;
    }

    item def MotionPlan {
        attribute planId : Identifier;
        attribute targetPose : RobotPose;
        attribute approachPose : RobotPose;
        attribute retreatPose : RobotPose;
        attribute expectedDuration : TimeValue;
        attribute maximumTcpSpeed : SpeedValue;
        attribute minimumClearance : LengthValue;
        attribute collisionFree : Boolean;
    }

    item def GripperCommand {
        attribute closeCommanded : Boolean;
        attribute targetForce : ForceValue;
        attribute targetOpening : LengthValue;
        attribute timeout : TimeValue;
    }

    item def RobotCommand {
        attribute commandId : Identifier;
        attribute commandedPose : RobotPose;
        attribute commandedSpeed : SpeedValue;
        attribute commandedAcceleration : AccelerationValue;
        attribute blendRadius : LengthValue;
    }

    item def TaskResult {
        attribute taskId : Identifier;
        attribute success : Boolean;
        attribute cycleTime : TimeValue;
        attribute detectedClass : ObjectClass;
        attribute finalConfidence : Confidence;
        attribute errorMessage : StatusText;
    }

    item def SafetySignal {
        attribute safetyLevel : SafetyLevel;
        attribute emergencyStopActive : Boolean;
        attribute protectiveStopActive : Boolean;
        attribute humanDetected : Boolean;
        attribute nearestHumanDistance : LengthValue;
    }

    port def ImageOutputPort {
        out item frame : ImageFrame;
    }

    port def DepthOutputPort {
        out item frame : DepthFrame;
    }

    port def VisionInputPort {
        in item color : ImageFrame;
        in item depth : DepthFrame;
    }

    port def DetectionOutputPort {
        out item detection : ObjectHypothesis;
    }

    port def PoseOutputPort {
        out item pose : RobotPose;
    }

    port def MotionPlanPort {
        out item plan : MotionPlan;
    }

    port def MotionPlanInputPort {
        in item plan : MotionPlan;
    }

    port def RobotCommandPort {
        out item command : RobotCommand;
    }

    port def RobotCommandInputPort {
        in item command : RobotCommand;
    }

    port def GripperCommandPort {
        out item command : GripperCommand;
    }

    port def GripperCommandInputPort {
        in item command : GripperCommand;
    }

    port def JointStateOutputPort {
        out item state : JointState;
    }

    port def SafetySignalPort {
        out item signal : SafetySignal;
    }

    port def SafetySignalInputPort {
        in item signal : SafetySignal;
    }

    port def ResultOutputPort {
        out item result : TaskResult;
    }

    part def StereoVisionSensor {
        attribute baseline : LengthValue = 0.120 [m];
        attribute focalLength : LengthValue = 0.012 [m];
        attribute horizontalFieldOfView : PlaneAngleValue = 70 [deg];
        attribute verticalFieldOfView : PlaneAngleValue = 52 [deg];
        attribute nominalFrameRate : FrameRate = 60.0;
        attribute imageWidth : PixelCount = 1920;
        attribute imageHeight : PixelCount = 1200;
        attribute depthAccuracyAtOneMeter : LengthValue = 0.002 [m];
        attribute operatingRangeMinimum : LengthValue = 0.250 [m];
        attribute operatingRangeMaximum : LengthValue = 2.000 [m];

        port colorOut : ImageOutputPort;
        port depthOut : DepthOutputPort;

        action captureScene {
            out item colorFrame : ImageFrame;
            out item depthFrame : DepthFrame;
        }
    }

    part def StructuredLightProjector {
        attribute wavelength : LengthValue = 850 [nm];
        attribute radiantPower : PowerValue = 1.5 [W];
        attribute patternRefreshRate : FrequencyValue = 120 [Hz];
        attribute safeForHumanExposure : Boolean = true;
    }

    part def IlluminationArray {
        attribute whiteLightPower : PowerValue = 48 [W];
        attribute strobeDuration : TimeValue = 3 [ms];
        attribute illuminationUniformity : Percent = 92.0;
        attribute targetLuxAtWorkspace : IlluminanceValue = 850 [lx];

        action synchronizeStrobe {
            in item trigger : ImageFrame;
        }
    }

    part def VisionProcessor {
        attribute inferenceLatencyLimit : TimeValue = 80 [ms];
        attribute minimumDetectionConfidence : Confidence = 0.92;
        attribute poseErrorLimit : LengthValue = 0.003 [m];
        attribute angularPoseErrorLimit : PlaneAngleValue = 1.5 [deg];
        attribute calibrationAgeLimit : TimeValue = 8 [h];

        port visionIn : VisionInputPort;
        port detectionOut : DetectionOutputPort;
        port poseOut : PoseOutputPort;

        action preprocessImages {
            in item colorFrame : ImageFrame;
            in item depthFrame : DepthFrame;
            out item correctedColorFrame : ImageFrame;
            out item correctedDepthFrame : DepthFrame;
        }

        action segmentTargetObject {
            in item correctedColorFrame : ImageFrame;
            in item correctedDepthFrame : DepthFrame;
            out item hypothesis : ObjectHypothesis;
        }

        action estimateSixDegreePose {
            in item hypothesis : ObjectHypothesis;
            out item pose : RobotPose;
        }

        state def VisionProcessingStateMachine {
            state idle;
            state acquiringFrames;
            state correctingFrames;
            state detectingObjects;
            state estimatingPose;
            state publishingPose;
            state visionFault;

            transition first idle;
            transition idle_to_acquiring
                first idle
                then acquiringFrames;

            transition acquiring_to_correcting
                first acquiringFrames
                then correctingFrames;

            transition correcting_to_detecting
                first correctingFrames
                then detectingObjects;

            transition detecting_to_estimating
                first detectingObjects
                then estimatingPose;

            transition estimating_to_publishing
                first estimatingPose
                then publishingPose;

            transition publishing_to_acquiring
                first publishingPose
                then acquiringFrames;

            transition lowConfidence_to_fault
                first detectingObjects
                then visionFault;

            transition fault_to_idle
                first visionFault
                then idle;
        }
    }

    part def SixAxisRobotArm {
        attribute payloadCapacity : MassValue = 8 [kg];
        attribute reach : LengthValue = 0.920 [m];
        attribute repeatability : LengthValue = 0.0008 [m];
        attribute maximumTcpSpeed : SpeedValue = 2.0 [m/s];
        attribute maximumJointSpeed : AngularVelocityValue = 180 [deg/s];
        attribute positionControlPeriod : TimeValue = 4 [ms];

        port commandIn : RobotCommandInputPort;
        port jointStateOut : JointStateOutputPort;
        port safetyIn : SafetySignalInputPort;

        action moveToPose {
            in item command : RobotCommand;
            out item actualPose : RobotPose;
        }

        action holdPosition {
            out item actualPose : RobotPose;
        }

        action stopMotion {
            in item signal : SafetySignal;
        }
    }

    part def AdaptiveParallelGripper {
        attribute maximumOpening : LengthValue = 0.085 [m];
        attribute minimumOpening : LengthValue = 0.000 [m];
        attribute maximumGripForce : ForceValue = 120 [N];
        attribute forceResolution : ForceValue = 1 [N];
        attribute closingSpeed : SpeedValue = 0.080 [m/s];

        port commandIn : GripperCommandInputPort;

        action open {
            in item command : GripperCommand;
        }

        action close {
            in item command : GripperCommand;
            out item state : GraspState;
        }

        action verifyGrip {
            out item state : GraspState;
        }
    }

    part def MotionPlanner {
        attribute planningTimeLimit : TimeValue = 250 [ms];
        attribute minimumObstacleClearance : LengthValue = 0.030 [m];
        attribute approachOffset : LengthValue = 0.100 [m];
        attribute retreatOffset : LengthValue = 0.120 [m];
        attribute reducedSpeedLimit : SpeedValue = 0.250 [m/s];

        port poseIn {
            in item pose : RobotPose;
        }

        port detectionIn {
            in item detection : ObjectHypothesis;
        }

        port safetyIn : SafetySignalInputPort;
        port planOut : MotionPlanPort;

        action generatePickPlan {
            in item targetPose : RobotPose;
            in item detection : ObjectHypothesis;
            in item safety : SafetySignal;
            out item plan : MotionPlan;
        }

        action validateCollisionFreePath {
            in item plan : MotionPlan;
            out attribute valid : Boolean;
        }
    }

    part def RobotController {
        attribute servoCycle : TimeValue = 4 [ms];
        attribute nominalPickSpeed : SpeedValue = 0.450 [m/s];
        attribute nominalPlaceSpeed : SpeedValue = 0.550 [m/s];
        attribute maximumAcceleration : AccelerationValue = 2.5 [m/s^2];
        attribute taskTimeout : TimeValue = 15 [s];

        port planIn : MotionPlanInputPort;
        port robotCommandOut : RobotCommandPort;
        port gripperCommandOut : GripperCommandPort;
        port safetyIn : SafetySignalInputPort;
        port resultOut : ResultOutputPort;

        action executeMotionPlan {
            in item plan : MotionPlan;
            out item result : TaskResult;
        }

        action commandApproach {
            in item plan : MotionPlan;
            out item command : RobotCommand;
        }

        action commandGrasp {
            in item plan : MotionPlan;
            out item command : GripperCommand;
        }

        action commandRetreat {
            in item plan : MotionPlan;
            out item command : RobotCommand;
        }

        state def PickAndPlaceControllerStateMachine {
            state idle;
            state waitingForVision;
            state planReceived;
            state approachingTarget;
            state graspingTarget;
            state liftingTarget;
            state movingToPlace;
            state releasingTarget;
            state verifyingCompletion;
            state completed;
            state recoverableFault;
            state protectiveStopped;
            state emergencyStopped;

            transition initial_to_idle
                first idle;

            transition start_to_waiting
                first idle
                then waitingForVision;

            transition vision_plan_ready
                first waitingForVision
                then planReceived;

            transition begin_approach
                first planReceived
                then approachingTarget;

            transition approach_complete
                first approachingTarget
                then graspingTarget;

            transition grasp_verified
                first graspingTarget
                then liftingTarget;

            transition lift_complete
                first liftingTarget
                then movingToPlace;

            transition place_reached
                first movingToPlace
                then releasingTarget;

            transition release_complete
                first releasingTarget
                then verifyingCompletion;

            transition verification_passed
                first verifyingCompletion
                then completed;

            transition cycle_restart
                first completed
                then waitingForVision;

            transition failed_grasp
                first graspingTarget
                then recoverableFault;

            transition fault_recovered
                first recoverableFault
                then waitingForVision;

            transition protective_stop_any
                first approachingTarget
                then protectiveStopped;

            transition emergency_stop_any
                first protectiveStopped
                then emergencyStopped;
        }
    }

    part def SafetyController {
        attribute safetyScannerRange : LengthValue = 3.0 [m];
        attribute protectiveStopDistance : LengthValue = 0.750 [m];
        attribute reducedSpeedDistance : LengthValue = 1.250 [m];
        attribute emergencyStopResponseTime : TimeValue = 80 [ms];
        attribute protectiveStopResponseTime : TimeValue = 120 [ms];

        port safetyOut : SafetySignalPort;

        action evaluateWorkspaceSafety {
            out item signal : SafetySignal;
        }

        state def SafetyStateMachine {
            state normal;
            state reducedSpeed;
            state protectiveStop;
            state emergencyStop;

            transition initial_normal
                first normal;

            transition human_enters_reduced_zone
                first normal
                then reducedSpeed;

            transition human_enters_stop_zone
                first reducedSpeed
                then protectiveStop;

            transition emergency_button_pressed
                first normal
                then emergencyStop;

            transition protective_clear
                first protectiveStop
                then reducedSpeed;

            transition reduced_clear
                first reducedSpeed
                then normal;
        }
    }

    part def Workcell {
        attribute workspaceWidth : LengthValue = 1.800 [m];
        attribute workspaceDepth : LengthValue = 1.200 [m];
        attribute workspaceHeight : LengthValue = 1.000 [m];
        attribute targetBinCapacity : Integer = 200;
        attribute nominalCycleTime : TimeValue = 6.5 [s];

        part inputBin {
            attribute binWidth : LengthValue = 0.600 [m];
            attribute binDepth : LengthValue = 0.400 [m];
            attribute binHeight : LengthValue = 0.220 [m];
        }

        part outputFixture {
            attribute fixturePositionTolerance : LengthValue = 0.002 [m];
            attribute placementTolerance : LengthValue = 0.004 [m];
        }

        part calibrationTarget {
            attribute markerSpacing : LengthValue = 0.030 [m];
            attribute fiducialCount : Integer = 48;
            attribute poseKnownAccuracy : LengthValue = 0.0005 [m];
        }
    }

    part def VisionGuidedRobotSystem {
        attribute systemMode : RobotOperatingMode = RobotOperatingMode::idle;
        attribute availabilityTarget : Percent = 98.5;
        attribute nominalThroughput : Real = 540.0;
        attribute primaryTask : String = "Detect, pick, transfer, and place randomly oriented target parts using vision-guided robotic manipulation.";

        part workcell : Workcell;
        part camera : StereoVisionSensor;
        part projector : StructuredLightProjector;
        part lights : IlluminationArray;
        part visionProcessor : VisionProcessor;
        part planner : MotionPlanner;
        part robotController : RobotController;
        part robotArm : SixAxisRobotArm;
        part gripper : AdaptiveParallelGripper;
        part safetyController : SafetyController;

        connect camera.colorOut.frame to visionProcessor.visionIn.color;
        connect camera.depthOut.frame to visionProcessor.visionIn.depth;
        connect visionProcessor.poseOut.pose to planner.poseIn.pose;
        connect visionProcessor.detectionOut.detection to planner.detectionIn.detection;
        connect safetyController.safetyOut.signal to planner.safetyIn.signal;
        connect safetyController.safetyOut.signal to robotController.safetyIn.signal;
        connect safetyController.safetyOut.signal to robotArm.safetyIn.signal;
        connect planner.planOut.plan to robotController.planIn.plan;
        connect robotController.robotCommandOut.command to robotArm.commandIn.command;
        connect robotController.gripperCommandOut.command to gripper.commandIn.command;

        action performPrimaryTask {
            in item colorFrame : ImageFrame;
            in item depthFrame : DepthFrame;
            out item taskResult : TaskResult;

            action preprocess : VisionProcessor::preprocessImages;
            action segment : VisionProcessor::segmentTargetObject;
            action estimate : VisionProcessor::estimateSixDegreePose;
            action plan : MotionPlanner::generatePickPlan;
            action execute : RobotController::executeMotionPlan;
        }

        state def SystemOperationalStateMachine {
            state poweredOff;
            state booting;
            state idle;
            state calibratingVision;
            state acquiringScene;
            state detectingTarget;
            state planningMotion;
            state executingPick;
            state placingObject;
            state verifyingTask;
            state completedCycle;
            state recoverableFault;
            state protectiveStopped;
            state emergencyStopped;
            state maintenanceRequired;

            transition initial_powered_off
                first poweredOff;

            transition power_on
                first poweredOff
                then booting;

            transition boot_complete
                first booting
                then idle;

            transition calibration_requested
                first idle
                then calibratingVision;

            transition calibration_valid
                first calibratingVision
                then acquiringScene;

            transition start_cycle
                first idle
                then acquiringScene;

            transition scene_available
                first acquiringScene
                then detectingTarget;

            transition target_pose_available
                first detectingTarget
                then planningMotion;

            transition plan_valid
                first planningMotion
                then executingPick;

            transition object_secured
                first executingPick
                then placingObject;

            transition placement_commanded
                first placingObject
                then verifyingTask;

            transition verified_success
                first verifyingTask
                then completedCycle;

            transition next_cycle
                first completedCycle
                then acquiringScene;

            transition detection_failure
                first detectingTarget
                then recoverableFault;

            transition planning_failure
                first planningMotion
                then recoverableFault;

            transition recovery_complete
                first recoverableFault
                then acquiringScene;

            transition protective_stop_detected
                first executingPick
                then protectiveStopped;

            transition protective_reset
                first protectiveStopped
                then acquiringScene;

            transition emergency_stop_detected
                first acquiringScene
                then emergencyStopped;

            transition maintenance_limit_reached
                first completedCycle
                then maintenanceRequired;
        }
    }

    requirement def PrimaryTaskRequirement {
        subject system : VisionGuidedRobotSystem;

        require constraint {
            system.nominalThroughput >= 500.0
        }

        require constraint {
            system.workcell.outputFixture.placementTolerance <= 0.004 [m]
        }
    }

    requirement def VisionDetectionRequirement {
        subject processor : VisionProcessor;

        require constraint {
            processor.minimumDetectionConfidence >= 0.90
        }

        require constraint {
            processor.inferenceLatencyLimit <= 100 [ms]
        }

        require constraint {
            processor.poseErrorLimit <= 0.005 [m]
        }

        require constraint {
            processor.angularPoseErrorLimit <= 2 [deg]
        }
    }

    requirement def CameraPerformanceRequirement {
        subject camera : StereoVisionSensor;

        require constraint {
            camera.nominalFrameRate >= 30.0
        }

        require constraint {
            camera.operatingRangeMinimum <= 0.300 [m]
        }

        require constraint {
            camera.operatingRangeMaximum >= 1.500 [m]
        }

        require constraint {
            camera.depthAccuracyAtOneMeter <= 0.003 [m]
        }
    }

    requirement def RobotMotionRequirement {
        subject robot : SixAxisRobotArm;

        require constraint {
            robot.payloadCapacity >= 5 [kg]
        }

        require constraint {
            robot.repeatability <= 0.001 [m]
        }

        require constraint {
            robot.maximumTcpSpeed >= 1.5 [m/s]
        }
    }

    requirement def GripperRequirement {
        subject gripper : AdaptiveParallelGripper;

        require constraint {
            gripper.maximumOpening >= 0.080 [m]
        }

        require constraint {
            gripper.maximumGripForce >= 100 [N]
        }

        require constraint {
            gripper.forceResolution <= 2 [N]
        }
    }

    requirement def MotionPlanningRequirement {
        subject planner : MotionPlanner;

        require constraint {
            planner.planningTimeLimit <= 300 [ms]
        }

        require constraint {
            planner.minimumObstacleClearance >= 0.025 [m]
        }
    }

    requirement def SafetyRequirement {
        subject safety : SafetyController;

        require constraint {
            safety.emergencyStopResponseTime <= 100 [ms]
        }

        require constraint {
            safety.protectiveStopResponseTime <= 150 [ms]
        }

        require constraint {
            safety.protectiveStopDistance >= 0.700 [m]
        }
    }

    requirement def TaskCycleRequirement {
        subject system : VisionGuidedRobotSystem;

        require constraint {
            system.workcell.nominalCycleTime <= 7 [s]
        }

        require constraint {
            system.availabilityTarget >= 98.0
        }
    }

    satisfy PrimaryTaskRequirement by VisionGuidedRobotSystem;
    satisfy VisionDetectionRequirement by VisionProcessor;
    satisfy CameraPerformanceRequirement by StereoVisionSensor;
    satisfy RobotMotionRequirement by SixAxisRobotArm;
    satisfy GripperRequirement by AdaptiveParallelGripper;
    satisfy MotionPlanningRequirement by MotionPlanner;
    satisfy SafetyRequirement by SafetyController;
    satisfy TaskCycleRequirement by VisionGuidedRobotSystem;

}