package IndustrialBinPicking {

    import ScalarValues::*;

    // ========================================
    // UNITS
    // ========================================
    unit m;
    unit s;
    unit kg;
    unit N;
    unit m_s;
    unit rad;
    unit rad_s;
    unit W;
    unit lux;

    // ========================================
    // VALUE TYPES
    // ========================================
    value type LengthValue :> Real { unit m; }
    value type TimeValue :> Real { unit s; }
    value type MassValue :> Real { unit kg; }
    value type ForceValue :> Real { unit N; }
    value type VelocityValue :> Real { unit m_s; }
    value type AngularVelocityValue :> Real { unit rad_s; }
    value type AngleValue :> Real { unit rad; }
    value type PowerValue :> Real { unit W; }
    value type IlluminanceValue :> Real { unit lux; }
    value type ProbabilityValue :> Real;
    value type PercentageValue :> Real;

    value type Point3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    value type Quaternion {
        attribute w : Real;
        attribute x : Real;
        attribute y : Real;
        attribute z : Real;
    }

    value type Pose6D {
        attribute position : Point3D;
        attribute orientation : Quaternion;
    }

    value type Dimensions3D {
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
    }

    // ========================================
    // ITEMS
    // ========================================
    item def PointCloud {
        attribute points : Point3D[0..*];
        attribute resolution : LengthValue;
        attribute timestamp : TimeValue;
        attribute lightingCondition : IlluminanceValue;
        attribute isValid : Boolean;
    }

    item def ImageData {
        attribute width : Integer;
        attribute height : Integer;
        attribute depth : Integer;
        attribute pixelData : Real[0..*];
    }

    item def Workpiece {
        attribute id : String;
        attribute mass : MassValue;
        attribute isFragile : Boolean;
        attribute isPartiallyHidden : Boolean;
        attribute estimatedDimensions : Dimensions3D;
        attribute detectedPose : Pose6D;
        attribute graspDifficulty : ProbabilityValue;
    }

    item def DetectedObject {
        attribute workpiece : Workpiece;
        attribute confidence : ProbabilityValue;
        attribute occlusionLevel : ProbabilityValue;
    }

    item def GraspPose {
        attribute pose : Pose6D;
        attribute approachAngle : AngleValue;
        attribute requiredForce : ForceValue;
        attribute targetWorkpieceId : String;
        attribute confidence : ProbabilityValue;
        attribute isCollisionFree : Boolean;
    }

    item def Trajectory {
        attribute waypoints : Pose6D[0..*];
        attribute duration : TimeValue;
        attribute maxVelocity : VelocityValue;
        attribute isCollisionFree : Boolean;
        attribute waypointCount : Integer;
    }

    item def SceneAnalysis {
        attribute detectedObjects : DetectedObject[0..*];
        attribute bestGrasp : GraspPose;
        attribute timestamp : TimeValue;
        attribute objectCount : Integer;
    }

    item def Bin {
        attribute id : String;
        attribute dimensions : Dimensions3D;
        attribute contents : Workpiece[0..*];
        attribute fillLevel : PercentageValue;
    }

    item def PlacementLocation {
        attribute id : String;
        attribute targetPose : Pose6D;
        attribute isOccupied : Boolean;
    }

    item def Command {
        attribute type : CommandType;
        attribute targetPose : Pose6D;
        attribute force : ForceValue;
        attribute velocity : VelocityValue;
    }

    item def Status {
        attribute stateName : String;
        attribute isSuccess : Boolean;
        attribute errorCode : String;
        attribute timestamp : TimeValue;
    }

    item def SafetyEvent {
        attribute type : SafetyEventType;
        attribute severity : String;
        attribute timestamp : TimeValue;
        attribute description : String;
    }

    // ========================================
    // ENUMERATIONS
    // ========================================
    enum def CommandType {
        literal SCAN;
        literal PLAN;
        literal MOVE;
        literal GRASP;
        literal RELEASE;
        literal RETURN_HOME;
        literal ABORT;
        literal EMERGENCY_STOP;
    }

    enum def SafetyEventType {
        literal COLLISION_RISK;
        literal EXCESSIVE_FORCE;
        literal OBJECT_DROPPED;
        literal LIGHTING_FAILURE;
        literal PLANNING_FAILURE;
    }

    // ========================================
    // PORTS
    // ========================================
    port def VisualDataOutPort {
        out pointCloud : PointCloud;
        out image : ImageData;
    }

    port def VisualDataInPort {
        in pointCloud : PointCloud;
        in image : ImageData;
    }

    port def SceneAnalysisOutPort {
        out scene : SceneAnalysis;
    }

    port def SceneAnalysisInPort {
        in scene : SceneAnalysis;
    }

    port def GraspOutPort {
        out grasp : GraspPose;
    }

    port def GraspInPort {
        in grasp : GraspPose;
    }

    port def TrajectoryOutPort {
        out trajectory : Trajectory;
    }

    port def TrajectoryInPort {
        in trajectory : Trajectory;
    }

    port def ControlPort {
        in command : Command;
        out status : Status;
    }

    port def ControllerCommandPort {
        out command : Command;
        in status : Status;
    }

    port def SafetyOutPort {
        out safetyEvent : SafetyEvent;
    }

    port def SafetyInPort {
        in safetyEvent : SafetyEvent;
    }

    port def EndEffectorMountPort {
        attribute mountPose : Pose6D;
        attribute maxPayload : MassValue;
        attribute connectionRigidity : Real;
    }

    // ========================================
    // ACTIONS
    // ========================================
    action def ScanScene {
        in cameraConfig : Command;
        out pointCloud : PointCloud;
        out image : ImageData;
    }

    action def AnalyzeScene {
        in pointCloud : PointCloud;
        in image : ImageData;
        out scene : SceneAnalysis;
    }

    action def IdentifyWorkpieces {
        in pointCloud : PointCloud;
        out detectedObjects : DetectedObject[0..*];
    }

    action def SelectBestGrasp {
        in scene : SceneAnalysis;
        out grasp : GraspPose;
    }

    action def ComputeGraspForce {
        in workpiece : Workpiece;
        out force : ForceValue;
    }

    action def PlanTrajectory {
        in grasp : GraspPose;
        in currentPose : Pose6D;
        in binGeometry : Dimensions3D;
        out trajectory : Trajectory;
    }

    action def ExecuteApproach {
        in trajectory : Trajectory;
        out finalPose : Pose6D;
        out success : Boolean;
    }

    action def CloseGripper {
        in targetForce : ForceValue;
        in pose : Pose6D;
        out gripSuccess : Boolean;
    }

    action def VerifyGrip {
        in sensedForce : ForceValue;
        in sensedPosition : Pose6D;
        out gripSecure : Boolean;
    }

    action def LiftObject {
        in liftHeight : LengthValue;
        out success : Boolean;
    }

    action def TransportObject {
        in destinationPose : Pose6D;
        out success : Boolean;
    }

    action def ReleaseObject {
        out releaseSuccess : Boolean;
    }

    action def ReturnToHome {
        out success : Boolean;
    }

    // ========================================
    // STATE MACHINE
    // ========================================
    state def BinPickingCycleStates {
        attribute cycleStartTime : TimeValue;
        attribute currentCycleTime : TimeValue;
        attribute errorCount : Integer;

        state Idle {
            entry assign currentCycleTime = 0;
        }

        state Scanning {
            entry assign cycleStartTime = 0;
        }

        state Planning;

        state Approaching;

        state Grasping;

        state Lifting;

        state Transporting;

        state Releasing;

        state ErrorHandling {
            entry assign errorCount = errorCount + 1;
        }

        transition from Idle to Scanning on start;
        transition from Scanning to Planning on scanComplete;
        transition from Planning to Approaching on planComplete;
        transition from Planning to Idle on planningFailed;
        transition from Approaching to Grasping on approachComplete;
        transition from Approaching to ErrorHandling on collisionDetected;
        transition from Grasping to Lifting on gripConfirmed;
        transition from Grasping to Planning on gripFailed;
        transition from Lifting to Transporting on liftComplete;
        transition from Lifting to ErrorHandling on objectDropped;
        transition from Transporting to Releasing on transportComplete;
        transition from Transporting to ErrorHandling on collisionDetected;
        transition from Releasing to Idle on releaseComplete;
        transition from ErrorHandling to Idle on reset;
        transition from any to ErrorHandling on emergencyStop;
    }

    // ========================================
    // PARTS
    // ========================================
    part def DepthCamera {
        port visualOut : VisualDataOutPort;
        port controlIn : ControlPort;

        attribute resolution : Dimensions3D;
        attribute frameRate : Real;
        attribute fieldOfView : AngleValue;
        attribute minRange : LengthValue;
        attribute maxRange : LengthValue;
        attribute lightingTolerance : IlluminanceValue;
        attribute isCalibrated : Boolean;

        action scan() {
            out pointCloud : PointCloud;
            out image : ImageData;
        }

        action acquirePointCloud() {
            in lighting : IlluminanceValue;
            out pointCloud : PointCloud;
        }

        action compensateLighting() {
            in rawImage : ImageData;
            out correctedImage : ImageData;
        }
    }

    part def MotionPlanner {
        port visualIn : VisualDataInPort;
        port analysisOut : SceneAnalysisOutPort;
        port graspOut : GraspOutPort;
        port trajectoryOut : TrajectoryOutPort;
        port controlIn : ControlPort;

        attribute processingLatency : TimeValue;
        attribute maxPlanningTime : TimeValue;
        attribute collisionMargin : LengthValue;
        attribute graspDatabaseSize : Integer;

        action analyzeScene() {
            in pointCloud : PointCloud;
            in image : ImageData;
            out scene : SceneAnalysis;
        }

        action identifyWorkpieces() {
            in pointCloud : PointCloud;
            out detectedObjects : DetectedObject[0..*];
        }

        action selectBestGrasp() {
            in scene : SceneAnalysis;
            out grasp : GraspPose;
        }

        action planTrajectory() {
            in grasp : GraspPose;
            in currentPose : Pose6D;
            out trajectory : Trajectory;
        }

        action handleOcclusion() {
            in detectedObjects : DetectedObject[0..*];
            out adjustedObjects : DetectedObject[0..*];
        }
    }

    part def RobotArm {
        port controlIn : ControlPort;
        port endEffector : EndEffectorMountPort;

        attribute degreesOfFreedom : Integer;
        attribute maxPayload : MassValue;
        attribute maxReach : LengthValue;
        attribute repeatability : LengthValue;
        attribute maxVelocity : VelocityValue;
        attribute maxAngularVelocity : AngularVelocityValue;
        attribute jointLimits : AngleValue[6];
        attribute currentPose : Pose6D;

        action executeApproach() {
            in trajectory : Trajectory;
            out finalPose : Pose6D;
            out success : Boolean;
        }

        action liftObject() {
            in height : LengthValue;
            out success : Boolean;
        }

        action transportToPlacement() {
            in destinationPose : Pose6D;
            out success : Boolean;
        }

        action returnToHome() {
            out success : Boolean;
        }

        action checkCollision() {
            in trajectory : Trajectory;
            out isClear : Boolean;
        }
    }

    part def AdaptiveGripper {
        port controlIn : ControlPort;
        port mount : EndEffectorMountPort;
        port safetyOut : SafetyOutPort;

        attribute maxGripForce : ForceValue;
        attribute minGripForce : ForceValue;
        attribute isCompliant : Boolean;
        attribute fingerCount : Integer;
        attribute maxOpening : LengthValue;
        attribute sensedForce : ForceValue;
        attribute currentOpening : LengthValue;
        attribute forceThreshold : ForceValue;

        action close() {
            in targetForce : ForceValue;
            out gripSuccess : Boolean;
        }

        action open() {
            out opening : LengthValue;
        }

        action applyForce() {
            in requiredForce : ForceValue;
            out actualForce : ForceValue;
        }

        action releaseObject() {
            out releaseSuccess : Boolean;
        }

        action adjustGrip() {
            in objectShape : Dimensions3D;
            in isFragile : Boolean;
            out adjustedForce : ForceValue;
        }

        action detectSlip() {
            in sensedForce : ForceValue;
            out slipDetected : Boolean;
        }
    }

    part def SystemController {
        port cameraControl : ControllerCommandPort;
        port plannerControl : ControllerCommandPort;
        port armControl : ControllerCommandPort;
        port gripperControl : ControllerCommandPort;
        port sceneIn : SceneAnalysisInPort;
        port graspIn : GraspInPort;
        port trajectoryIn : TrajectoryInPort;
        port safetyIn : SafetyInPort;

        attribute currentCycleTime : TimeValue;
        attribute cyclesCompleted : Integer;
        attribute successfulPicks : Integer;
        attribute failedPicks : Integer;
        attribute maxCycleTime : TimeValue;
        attribute targetSuccessRate : ProbabilityValue;
        attribute emergencyStop : Boolean;
        attribute collisionDetected : Boolean;
        attribute startCommand : Boolean;

        state cycle : BinPickingCycleStates;

        action verifyGrip() {
            in sensedForce : ForceValue;
            out gripSecure : Boolean;
        }

        action logCycleTime() {
            in cycleTime : TimeValue;
        }

        action computeSuccessRate() {
            out rate : ProbabilityValue;
        }

        action handleSafetyEvent() {
            in event : SafetyEvent;
            out response : Command;
        }

        action monitorPerformance() {
            out cycleTime : TimeValue;
            out successRate : ProbabilityValue;
        }
    }

    // ========================================
    // TOP-LEVEL SYSTEM
    // ========================================
    part def BinPickingRobotSystem {
        part controller : SystemController {
            attribute maxCycleTime : TimeValue = 4.0;
            attribute targetSuccessRate : ProbabilityValue = 0.95;
            attribute cyclesCompleted : Integer = 0;
            attribute successfulPicks : Integer = 0;
            attribute failedPicks : Integer = 0;
            attribute emergencyStop : Boolean = false;
            attribute collisionDetected : Boolean = false;
            attribute startCommand : Boolean = false;
        }

        part camera : DepthCamera {
            attribute frameRate : Real = 30.0;
            attribute fieldOfView : AngleValue = 1.047;
            attribute minRange : LengthValue = 0.1;
            attribute maxRange : LengthValue = 2.0;
            attribute lightingTolerance : IlluminanceValue = 50000.0;
            attribute isCalibrated : Boolean = true;
        }

        part planner : MotionPlanner {
            attribute processingLatency : TimeValue = 0.05;
            attribute maxPlanningTime : TimeValue = 0.5;
            attribute collisionMargin : LengthValue = 0.01;
            attribute graspDatabaseSize : Integer = 10000;
        }

        part arm : RobotArm {
            attribute degreesOfFreedom : Integer = 6;
            attribute maxPayload : MassValue = 10.0;
            attribute maxReach : LengthValue = 1.5;
            attribute repeatability : LengthValue = 0.0001;
            attribute maxVelocity : VelocityValue = 2.0;
            attribute maxAngularVelocity : AngularVelocityValue = 3.14;
        }

        part gripper : AdaptiveGripper {
            attribute maxGripForce : ForceValue = 80.0;
            attribute minGripForce : ForceValue = 5.0;
            attribute isCompliant : Boolean = true;
            attribute fingerCount : Integer = 2;
            attribute maxOpening : LengthValue = 0.15;
            attribute forceThreshold : ForceValue = 60.0;
            attribute sensedForce : ForceValue = 0.0;
            attribute currentOpening : LengthValue = 0.15;
        }

        part bin : Bin {
            attribute id : String = "PrimaryBin";
        }

        part placementArea : PlacementLocation {
            attribute id : String = "OutputArea";
            attribute isOccupied : Boolean = false;
        }

        connection cameraVisualFlow connect camera.visualOut to planner.visualIn;
        connection plannerSceneFlow connect planner.analysisOut to controller.sceneIn;
        connection plannerGraspFlow connect planner.graspOut to controller.graspIn;
        connection plannerTrajectoryFlow connect planner.trajectoryOut to controller.trajectoryIn;
        connection cameraControlFlow connect controller.cameraControl to camera.controlIn;
        connection plannerControlFlow connect controller.plannerControl to planner.controlIn;
        connection armControlFlow connect controller.armControl to arm.controlIn;
        connection gripperControlFlow connect controller.gripperControl to gripper.controlIn;
        connection endEffectorMount connect arm.endEffector to gripper.mount;
        connection gripperSafetyFlow connect gripper.safetyOut to controller.safetyIn;

        satisfy CycleTimeRequirement;
        satisfy SuccessRateRequirement;
        satisfy RobustnessRequirement;
        satisfy SafetyRequirement;
        satisfy PerceptionRequirement;
        satisfy MotionPlanningRequirement;
        satisfy RobotArmRequirement;
        satisfy GripperRequirement;
    }

    // ========================================
    // REQUIREMENTS
    // ========================================
    requirement def CycleTimeRequirement {
        doc "The system shall complete a full bin-picking cycle (scan, plan, approach, grasp, lift, transport, release) in under four seconds.";
        subject system : BinPickingRobotSystem;
        attribute maxCycleTime : TimeValue = 4.0;
    }

    requirement def SuccessRateRequirement {
        doc "The system shall achieve a pick success rate of over 95% across operational cycles.";
        subject system : BinPickingRobotSystem;
        attribute minSuccessRate : ProbabilityValue = 0.95;
    }

    requirement def RobustnessRequirement {
        doc "The system shall robustly handle partially hidden objects and changing light conditions.";
        subject system : BinPickingRobotSystem;

        requirement occlusionHandling {
            doc "The system shall identify and grasp objects that are at least 50% occluded.";
            subject system : BinPickingRobotSystem;
            attribute minOcclusionTolerance : ProbabilityValue = 0.5;
        }

        requirement lightingRobustness {
            doc "The system shall operate under lighting conditions from 100 lux to 50,000 lux.";
            subject system : BinPickingRobotSystem;
            attribute minLighting : IlluminanceValue = 100.0;
            attribute maxLighting : IlluminanceValue = 50000.0;
        }
    }

    requirement def SafetyRequirement {
        doc "The system shall include safety features to prevent object damage and collisions.";
        subject system : BinPickingRobotSystem;

        requirement noObjectDamage {
            doc "The gripper shall not apply force exceeding the fragility threshold of any workpiece.";
            subject system : BinPickingRobotSystem;
            attribute maxSafeForce : ForceValue = 60.0;
        }

        requirement noCollision {
            doc "The robot arm shall not collide with bin walls, objects, or itself during motion.";
            subject system : BinPickingRobotSystem;
            attribute collisionMargin : LengthValue = 0.01;
        }

        requirement emergencyStopCapability {
            doc "The system shall support emergency stop to immediately halt all motion.";
            subject system : BinPickingRobotSystem;
        }
    }

    requirement def PerceptionRequirement {
        doc "The depth camera shall generate a 3D point cloud of bin contents with sufficient resolution for grasp planning.";
        subject system : BinPickingRobotSystem;
        attribute minResolution : LengthValue = 0.001;
        attribute minRange : LengthValue = 0.1;
        attribute maxRange : LengthValue = 2.0;
    }

    requirement def MotionPlanningRequirement {
        doc "The motion planner shall compute collision-free trajectories and optimal grasp poses in real-time.";
        subject system : BinPickingRobotSystem;
        attribute maxPlanningTime : TimeValue = 0.5;
        attribute collisionMargin : LengthValue = 0.01;
    }

    requirement def RobotArmRequirement {
        doc "The robot arm shall be a six-axis industrial arm with sufficient payload capacity and precision.";
        subject system : BinPickingRobotSystem;
        attribute requiredDoF : Integer = 6;
        attribute minPayload : MassValue = 5.0;
        attribute minRepeatability : LengthValue = 0.001;
    }

    requirement def GripperRequirement {
        doc "The gripper shall be adaptive and force-sensing to securely handle objects of varying shapes and fragility.";
        subject system : BinPickingRobotSystem;
        attribute isAdaptive : Boolean = true;
        attribute isForceSensing : Boolean = true;
        attribute isCompliant : Boolean = true;
    }

    // ========================================
    // VERIFICATION
    // ========================================
    verification CycleTimeVerification {
        subject system : BinPickingRobotSystem;
        objective {
            doc "Measure cycle time over 1000 pick cycles and verify all complete in under 4.0 seconds.";
        }
        requirement :>> CycleTimeRequirement;
    }

    verification SuccessRateVerification {
        subject system : BinPickingRobotSystem;
        objective {
            doc "Verify the system achieves over 95% pick success rate over 1000 cycles with varying object configurations.";
        }
        requirement :>> SuccessRateRequirement;
    }

    verification RobustnessVerification {
        subject system : BinPickingRobotSystem;
        objective {
            doc "Verify the system handles partially occluded objects and lighting conditions from 100 to 50,000 lux.";
        }
        requirement :>> RobustnessRequirement;
    }

    verification SafetyVerification {
        subject system : BinPickingRobotSystem;
        objective {
            doc "Verify no object damage occurs and no collisions are detected during 1000 pick cycles.";
        }
        requirement :>> SafetyRequirement;
    }
}
