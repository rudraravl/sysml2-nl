package 'Vision-Guided Robotic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	enum def RobotState {
		enum standby;
		enum imaging;
		enum processing;
		enum moving;
		enum grasping;
		enum placing;
		enum error;
	}

	enum def ObjectClass {
		enum cube;
		enum cylinder;
		enum sphere;
		enum custom;
	}

	attribute def ImageResolution {
		attribute width : Integer;
		attribute height : Integer;
	}

	attribute def Position3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}

	attribute def Orientation3D {
		attribute roll : Real;
		attribute pitch : Real;
		attribute yaw : Real;
	}

	attribute def Pose3D {
		attribute position : Position3D;
		attribute orientation : Orientation3D;
	}

	attribute def JointAngles {
		attribute joint1 : Real;
		attribute joint2 : Real;
		attribute joint3 : Real;
		attribute joint4 : Real;
		attribute joint5 : Real;
		attribute joint6 : Real;
	}

	item def CameraImage {
		attribute resolution : ImageResolution;
		attribute timestamp : TimeValue;
		attribute brightness : Real;
	}

	item def DetectedObject {
		attribute objectClass : ObjectClass;
		attribute pose : Pose3D;
		attribute confidence : Real;
		attribute boundingBoxSize : Position3D;
	}

	item def TrajectoryPlan {
		attribute waypoints : Pose3D[1..*];
		attribute jointPath : JointAngles[1..*];
		attribute duration : TimeValue;
	}

	item def GripperCommand {
		attribute openingWidth : LengthValue;
		attribute graspForce : ForceValue;
	}

	port def VisionOutputPort {
		out item image : CameraImage;
	}

	port def ObjectDetectionPort {
		in item image : CameraImage;
		out item detectedObjects : DetectedObject[*];
	}

	port def MotionControlPort {
		in item trajectory : TrajectoryPlan;
		out item currentPose : Pose3D;
	}

	port def GripperPort {
		in item command : GripperCommand;
		out item graspStatus : Boolean;
	}

	action def AcquireImage {
		out image : CameraImage;
	}

	action def ProcessVisionData {
		in rawImage : CameraImage;
		out processedImage : CameraImage;
	}

	action def DetectTargetObjects {
		in image : CameraImage;
		out objects : DetectedObject[*];
	}

	action def FilterDetections {
		in detections : DetectedObject[*];
		in minConfidence : Real;
		out validObjects : DetectedObject[*];
	}

	action def SelectPickTarget {
		in candidates : DetectedObject[*];
		out selectedObject : DetectedObject;
		out hasTarget : Boolean;
	}

	action def ComputeApproachPose {
		in objectPose : Pose3D;
		in objectClass : ObjectClass;
		out approachPose : Pose3D;
	}

	action def PlanTrajectory {
		in startPose : Pose3D;
		in goalPose : Pose3D;
		out trajectory : TrajectoryPlan;
	}

	action def ExecuteTrajectory {
		in trajectory : TrajectoryPlan;
		out success : Boolean;
	}

	action def ComputeGraspParameters {
		in objectClass : ObjectClass;
		in objectSize : Position3D;
		out gripperCommand : GripperCommand;
	}

	action def ExecuteGrasp {
		in command : GripperCommand;
		out graspSuccess : Boolean;
	}

	action def MoveToPlacementLocation {
		in placementPose : Pose3D;
		out success : Boolean;
	}

	action def ReleaseObject {
		out releaseSuccess : Boolean;
	}

	state def VisionGuidedOperationStateMachine {
		entry; then standby;

		state standby;

		transition standby_to_imaging
			first standby
			accept StartCycleSignal
			then imaging;

		state imaging;

		transition imaging_to_processing
			first imaging
			then processing;

		state processing;

		transition processing_to_moving
			first processing
			then moving;

		transition processing_to_error
			first processing
			then error;

		state moving;

		transition moving_to_grasping
			first moving
			then grasping;

		transition moving_to_error
			first moving
			then error;

		state grasping;

		transition grasping_to_placing
			first grasping
			then placing;

		transition grasping_to_error
			first grasping
			then error;

		state placing;

		transition placing_to_standby
			first placing
			then standby;

		transition placing_to_error
			first placing
			then error;

		state error;

		transition error_to_standby
			first error
			accept ResetSignal
			then standby;
	}

	part def VisionCamera {
		attribute frameRate : Real;
		attribute resolution : ImageResolution;
		attribute focalLength : LengthValue;

		port imageOutput : VisionOutputPort;

		perform action captureImages : AcquireImage;
	}

	part def VisionProcessor {
		attribute processingRate : Real;
		attribute detectionAlgorithm : String;

		port imageInput : ~VisionOutputPort;
		port detectionOutput : ObjectDetectionPort;

		perform action processImages : ProcessVisionData;
		perform action detectObjects : DetectTargetObjects;
		perform action filterDetections : FilterDetections;
	}

	part def MotionPlanner {
		attribute planningHorizon : TimeValue;
		attribute collisionCheckEnabled : Boolean;

		port objectInput : ~ObjectDetectionPort;
		port motionOutput : ~MotionControlPort;

		perform action selectTargets : SelectPickTarget;
		perform action computeApproaches : ComputeApproachPose;
		perform action planTrajectories : PlanTrajectory;
	}

	part def RobotArm {
		attribute numberOfJoints : Integer;
		attribute maxReach : LengthValue;
		attribute maxPayload : MassValue;
		attribute currentJointAngles : JointAngles;

		port motionInput : MotionControlPort;

		perform action executeTrajectories : ExecuteTrajectory;
	}

	part def EndEffectorGripper {
		attribute maxGripForce : ForceValue;
		attribute maxOpening : LengthValue;
		attribute currentOpening : LengthValue;

		port gripperInput : GripperPort;

		perform action executeGrasps : ExecuteGrasp;
		perform action releaseObjects : ReleaseObject;
	}

	part def WorkArea {
		attribute workspaceVolume : VolumeValue;
		attribute lightingLevel : Real;

		part targetObjects[*];
		part placementZone;
	}

	part def VisionGuidedRobotSystem {
		attribute systemIdentifier : String;
		attribute operationalMode : String;
		attribute cycleCount : Integer;

		part camera : VisionCamera {
			attribute :>> frameRate = 60.0;
			attribute :>> resolution = ImageResolution {
				attribute :>> width = 1920;
				attribute :>> height = 1200;
			}
			attribute :>> focalLength = 16.0 [mm];
		}

		part visionProcessor : VisionProcessor {
			attribute :>> processingRate = 30.0;
			attribute :>> detectionAlgorithm = "DeepLearningCNN";
		}

		part motionPlanner : MotionPlanner {
			attribute :>> planningHorizon = 2.0 [s];
			attribute :>> collisionCheckEnabled = true;
		}

		part robotArm : RobotArm {
			attribute :>> numberOfJoints = 6;
			attribute :>> maxReach = 900.0 [mm];
			attribute :>> maxPayload = 10.0 [kg];
		}

		part gripper : EndEffectorGripper {
			attribute :>> maxGripForce = 150.0 [N];
			attribute :>> maxOpening = 100.0 [mm];
		}

		part workArea : WorkArea {
			attribute :>> lightingLevel = 0.8;
		}

		connect camera.imageOutput to visionProcessor.imageInput;
		connect visionProcessor.detectionOutput to motionPlanner.objectInput;
		connect motionPlanner.motionOutput to robotArm.motionInput;

		exhibit state operationStateMachine : VisionGuidedOperationStateMachine;

		perform action visionGuidedPickAndPlace {
			first start;

			then action acquireImage : AcquireImage {
				out image;
			}

			then action processVision : ProcessVisionData {
				in rawImage = acquireImage.image;
				out processedImage;
			}

			then action detectObjects : DetectTargetObjects {
				in image = processVision.processedImage;
				out objects;
			}

			then action filterDetections : FilterDetections {
				in detections = detectObjects.objects;
				in minConfidence = 0.85;
				out validObjects;
			}

			then action selectTarget : SelectPickTarget {
				in candidates = filterDetections.validObjects;
				out selectedObject;
				out hasTarget;
			}

			then decide;
				if selectTarget.hasTarget then computeApproach;
				if !selectTarget.hasTarget then handleNoTarget;

			action computeApproach : ComputeApproachPose {
				in objectPose = selectTarget.selectedObject.pose;
				in objectClass = selectTarget.selectedObject.objectClass;
				out approachPose;
			}

			then action planPath : PlanTrajectory {
				in goalPose = computeApproach.approachPose;
				out trajectory;
			}

			then action executeMove : ExecuteTrajectory {
				in trajectory = planPath.trajectory;
				out success;
			}

			then decide;
				if executeMove.success then computeGrasp;
				if !executeMove.success then handleMoveFailure;

			action computeGrasp : ComputeGraspParameters {
				in objectClass = selectTarget.selectedObject.objectClass;
				in objectSize = selectTarget.selectedObject.boundingBoxSize;
				out gripperCommand;
			}

			then action executeGrasp : ExecuteGrasp {
				in command = computeGrasp.gripperCommand;
				out graspSuccess;
			}

			then decide;
				if executeGrasp.graspSuccess then moveToPlace;
				if !executeGrasp.graspSuccess then handleGraspFailure;

			action moveToPlace : MoveToPlacementLocation {
				out success;
			}

			then action release : ReleaseObject {
				out releaseSuccess;
			}

			then done;

			action handleNoTarget {
			}
			then done;

			action handleMoveFailure {
			}
			then done;

			action handleGraspFailure {
			}
			then done;
		}
	}

	requirement def VisionSystemRequirement {
		doc /* The vision system shall detect objects with minimum 85% confidence and process images at minimum 30 Hz */

		subject visionSystem : VisionCamera;

		require detectionConfidence {
			doc /* Object detection confidence shall be >= 0.85 */
		}

		require processingRate {
			doc /* Image processing rate shall be >= 30 Hz */
		}

		require imageQuality {
			doc /* Image brightness shall be >= 0.3 for reliable detection */
		}
	}

	requirement def MotionAccuracyRequirement {
		doc /* The robotic arm shall achieve positioning accuracy within +/- 0.5 mm */

		subject arm : RobotArm;

		require positioningAccuracy {
			doc /* Positioning accuracy shall be +/- 0.5 mm */
		}

		require repeatability {
			doc /* Repeatability shall be +/- 0.1 mm */
		}
	}

	requirement def GraspReliabilityRequirement {
		doc /* The gripper shall achieve successful grasp rate >= 95% */

		subject gripper : EndEffectorGripper;

		require graspSuccessRate {
			doc /* Grasp success rate shall be >= 95% */
		}

		require forceControl {
			doc /* Grip force control accuracy shall be +/- 5 N */
		}
	}

	requirement def SystemPerformanceRequirement {
		doc /* The complete vision-guided pick-and-place cycle shall be completed within 8 seconds */

		subject system : VisionGuidedRobotSystem;

		require cycleTime {
			doc /* Complete cycle time shall be <= 8 seconds */
		}

		require systemAvailability {
			doc /* System availability shall be >= 98% during operation */
		}

		require safetyCompliance {
			doc /* System shall comply with ISO 10218 and ISO/TS 15066 */
		}
	}

	part visionGuidedRobot : VisionGuidedRobotSystem {
		attribute :>> systemIdentifier = "VGR-SYS-001";
		attribute :>> operationalMode = "autonomous";
		attribute :>> cycleCount = 0;

		satisfy visionReq : VisionSystemRequirement by camera;
		satisfy motionReq : MotionAccuracyRequirement by robotArm;
		satisfy graspReq : GraspReliabilityRequirement by gripper;
		satisfy perfReq : SystemPerformanceRequirement by visionGuidedRobot;
	}
}
