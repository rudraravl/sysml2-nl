package 'Vision Guided Pick and Place Robot' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import SequenceFunctions::*;

	// ---- Item Definitions ----
	item def Image;

	item def PhysicalObject {
		attribute objectId : String;
		attribute position : LengthValue[3];
		attribute orientation : Real[4];
	}

	item def Cube :> PhysicalObject {
		attribute sideLength : LengthValue;
	}

	item def Cylinder :> PhysicalObject {
		attribute radius : LengthValue;
		attribute height : LengthValue;
	}

	item def Sphere :> PhysicalObject {
		attribute radius : LengthValue;
	}

	item def DetectedObject {
		ref item target : PhysicalObject;
		attribute classLabel : String;
		attribute confidence : Real;
		attribute pose : LengthValue[3];
		attribute orientation : Real[4];
	}

	item def SceneData {
		attribute timestamp : TimeValue;
		attribute detections : DetectedObject[*];
	}

	item def GraspPlan {
		attribute gripForce : ForceValue;
		attribute jawOpening : LengthValue;
		attribute approachPose : LengthValue[3];
	}

	item def TrajectoryPoint {
		attribute jointPositions : Real[6];
		attribute timestamp : TimeValue;
	}

	item def Trajectory {
		attribute points : TrajectoryPoint[*];
	}

	item def PlacementZone {
		attribute zoneId : String;
		attribute centerPosition : LengthValue[3];
	}

	// ---- Signal Items ----
	item def StartCommand;
	item def CaptureCompleteSignal;
	item def ProcessingCompleteSignal {
		attribute scene : SceneData;
	}
	item def PlanningCompleteSignal {
		attribute trajectory : Trajectory;
		attribute graspPlan : GraspPlan;
	}
	item def AtObjectSignal;
	item def GraspConfirmedSignal;
	item def AtPlaceSignal;
	item def PlacementCompleteSignal;
	item def ErrorSignal {
		attribute errorCode : String;
		attribute errorMessage : String;
	}
	item def ResetCommand;

	// ---- Port Definitions ----
	port def ImageOutputPort {
		out image : Image;
	}

	port def ImageInputPort {
		in image : Image;
	}

	port def SceneOutputPort {
		out sceneData : SceneData;
	}

	port def SceneInputPort {
		in sceneData : SceneData;
	}

	port def TrajectoryOutputPort {
		out trajectory : Trajectory;
		out graspPlan : GraspPlan;
	}

	port def CommandInputPort {
		in trajectory : Trajectory;
		in graspPlan : GraspPlan;
	}

	port def GripperCommandPort {
		in gripForce : ForceValue;
		in jawOpening : LengthValue;
		in gripperAction : String;
	}

	port def StatusOutputPort {
		out atObject : AtObjectSignal;
		out graspConfirmed : GraspConfirmedSignal;
		out atPlace : AtPlaceSignal;
		out placementComplete : PlacementCompleteSignal;
		out error : ErrorSignal;
	}

	port def SystemCommandPort {
		in startCmd : StartCommand;
		in resetCmd : ResetCommand;
	}

	port def SystemStatusPort {
		out systemStatus : String;
	}

	// ---- Action Definitions ----
	action def CaptureImageAction {
		out capturedImage : Image;
	}

	action def RunInferenceAction {
		in inputImage : Image;
		out detectedObjects : DetectedObject[*];
		out scene : SceneData;
	}

	action def SelectTargetAction {
		in detectedObjects : DetectedObject[*];
		out selectedObject : DetectedObject;
	}

	action def PlanPathAction {
		in targetPose : LengthValue[3];
		in currentJointPositions : Real[6];
		out plannedTrajectory : Trajectory;
	}

	action def ComputeGraspAction {
		in targetObject : DetectedObject;
		out graspPlan : GraspPlan;
	}

	action def ExecuteTrajectoryAction {
		in trajectory : Trajectory;
		out finalJointPositions : Real[6];
	}

	action def GraspObjectAction {
		in graspPlan : GraspPlan;
	}

	action def ReleaseObjectAction;

	action def TransportObjectAction {
		in destination : LengthValue[3];
	}

	// ---- Part Definitions ----
	part def Camera {
		attribute resolution : Real = 12.0;
		attribute frameRate : Real = 30.0;
		port imageOutput : ImageOutputPort;
		port captureCompletePort {
			out captureDone : CaptureCompleteSignal;
		}
	}

	part def VisionProcessor {
		attribute detectionThreshold : Real = 0.85;
		port imageInput : ImageInputPort;
		port sceneOutput : SceneOutputPort;
		port processingCompletePort {
			out processingDone : ProcessingCompleteSignal;
		}
	}

	part def MotionPlanner {
		attribute currentJointState : Real[6];
		port sceneInput : SceneInputPort;
		port planOutput : TrajectoryOutputPort;
		port planningCompletePort {
			out planningDone : PlanningCompleteSignal;
		}
	}

	part def Gripper {
		attribute maxJawOpening : LengthValue = 0.08;
		attribute maxGripForce : ForceValue = 40.0;
		attribute currentJawOpening : LengthValue;
		attribute currentGripForce : ForceValue;
		port gripperCommandInput : GripperCommandPort;
	}

	part def RoboticArm {
		attribute jointCount : Integer = 6;
		attribute jointAngles : Real[6];
		attribute maxReach : LengthValue = 0.85;
		port commandInput : CommandInputPort;
		port statusOutput : StatusOutputPort;
		part endEffector : Gripper;
	}

	// ---- State Machine Definition ----
	state def SystemStateMachine {
		in startCmd : StartCommand;
		in resetCmd : ResetCommand;
		in captureDone : CaptureCompleteSignal;
		in processingDone : ProcessingCompleteSignal;
		in planningDone : PlanningCompleteSignal;
		in atObject : AtObjectSignal;
		in graspConfirmed : GraspConfirmedSignal;
		in atPlace : AtPlaceSignal;
		in placementComplete : PlacementCompleteSignal;
		in systemError : ErrorSignal;
		out systemStatus : String;

		state standby {
			entry assign systemStatus := "STANDBY";
		}
		state imaging {
			entry assign systemStatus := "IMAGING";
		}
		state processing {
			entry assign systemStatus := "PROCESSING";
		}
		state planning {
			entry assign systemStatus := "PLANNING";
		}
		state moving {
			entry assign systemStatus := "MOVING";
		}
		state grasping {
			entry assign systemStatus := "GRASPING";
		}
		state placing {
			entry assign systemStatus := "PLACING";
		}
		state errorHandling {
			entry assign systemStatus := "ERROR";
		}

		transition from standby to imaging on startCmd;
		transition from imaging to processing on captureDone;
		transition from processing to planning on processingDone;
		transition from planning to moving on planningDone;
		transition from moving to grasping on atObject;
		transition from grasping to placing on graspConfirmed;
		transition from placing to standby on placementComplete;
		transition from standby to errorHandling on systemError;
		transition from imaging to errorHandling on systemError;
		transition from processing to errorHandling on systemError;
		transition from planning to errorHandling on systemError;
		transition from moving to errorHandling on systemError;
		transition from grasping to errorHandling on systemError;
		transition from placing to errorHandling on systemError;
		transition from errorHandling to standby on resetCmd;
	}

	// ---- System Part Definition ----
	part def PickAndPlaceSystem {
		attribute systemId : String;
		attribute placementZone : PlacementZone;

		port systemCommandPort : SystemCommandPort;
		port systemStatusPort : SystemStatusPort;

		part camera : Camera;
		part visionProcessor : VisionProcessor;
		part motionPlanner : MotionPlanner;
		part roboticArm : RoboticArm;

		exhibit systemSM : SystemStateMachine {
			in startCmd = systemCommandPort.startCmd;
			in resetCmd = systemCommandPort.resetCmd;
			in captureDone = camera.captureCompletePort.captureDone;
			in processingDone = visionProcessor.processingCompletePort.processingDone;
			in planningDone = motionPlanner.planningCompletePort.planningDone;
			in atObject = roboticArm.statusOutput.atObject;
			in graspConfirmed = roboticArm.statusOutput.graspConfirmed;
			in atPlace = roboticArm.statusOutput.atPlace;
			in placementComplete = roboticArm.statusOutput.placementComplete;
			in systemError = roboticArm.statusOutput.error;
			out systemStatus = systemStatusPort.systemStatus;
		}

		flow imageFlow of Image
			from camera.imageOutput.image to visionProcessor.imageInput.image;

		flow sceneFlow of SceneData
			from visionProcessor.sceneOutput.sceneData to motionPlanner.sceneInput.sceneData;

		flow trajectoryFlow of Trajectory
			from motionPlanner.planOutput.trajectory to roboticArm.commandInput.trajectory;

		flow graspFlow of GraspPlan
			from motionPlanner.planOutput.graspPlan to roboticArm.commandInput.graspPlan;
	}

	// ---- Requirements ----
	requirement def PickAndPlaceRequirement {
		id "REQ-001";
		text "The system shall autonomously identify, pick, and place objects in a workspace.";
		subject system : PickAndPlaceSystem;
	}

	requirement def VisionDetectionRequirement :> PickAndPlaceRequirement {
		id "REQ-002";
		text "The vision processor shall identify objects with confidence above 0.85.";
		subject visionProcessor : VisionProcessor;
		constraint { visionProcessor.detectionThreshold >= 0.85 }
	}

	requirement def MotionPlanningRequirement :> PickAndPlaceRequirement {
		id "REQ-003";
		text "The motion planner shall generate a collision-free trajectory for the robotic arm.";
		subject motionPlanner : MotionPlanner;
	}

	requirement def GraspRequirement :> PickAndPlaceRequirement {
		id "REQ-004";
		text "The gripper shall grasp objects with appropriate force based on object shape and size.";
		subject gripper : Gripper;
		constraint { gripper.currentGripForce <= gripper.maxGripForce }
	}

	requirement def StateMachineRequirement :> PickAndPlaceRequirement {
		id "REQ-005";
		text "The system shall cycle through standby, imaging, processing, planning, moving, grasping, and placing states.";
		subject controller : PickAndPlaceSystem;
	}

	requirement def ErrorHandlingRequirement :> PickAndPlaceRequirement {
		id "REQ-006";
		text "The system shall enter an error-handling state upon detection of any failure and return to standby after reset.";
		subject controller : PickAndPlaceSystem;
	}

	// ---- Top-level Action for Full Pick-and-Place Cycle ----
	action def PickAndPlaceCycle {
		in workspaceImage : Image;
		in placementTarget : PlacementZone;
		out success : Boolean;

		private attribute cycleComplete : Boolean := false;

		perform action capture : CaptureImageAction {
			out capturedImage;
		}

		then perform action process : RunInferenceAction {
			in inputImage = capture.capturedImage;
			out detectedObjects;
			out scene;
		}

		then perform action select : SelectTargetAction {
			in detectedObjects = process.detectedObjects;
			out selectedObject;
		}

		then perform action plan : PlanPathAction {
			in targetPose = select.selectedObject.pose;
			in currentJointPositions = ( 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 );
			out plannedTrajectory;
		}

		then perform action computeGrasp : ComputeGraspAction {
			in targetObject = select.selectedObject;
			out graspPlan;
		}

		then perform action execute : ExecuteTrajectoryAction {
			in trajectory = plan.plannedTrajectory;
			out finalJointPositions;
		}

		then perform action grasp : GraspObjectAction {
			in graspPlan = computeGrasp.graspPlan;
		}

		then perform action transport : TransportObjectAction {
			in destination = placementTarget.centerPosition;
		}

		then perform action release : ReleaseObjectAction;

		then assign cycleComplete := true;
		then assign success := cycleComplete;
	}

	// ---- System Instance ----
	part pickAndPlaceSystem : PickAndPlaceSystem {
		attribute systemId = "PAP-001";
		satisfy PickAndPlaceRequirement;
		satisfy VisionDetectionRequirement;
		satisfy MotionPlanningRequirement;
		satisfy GraspRequirement;
		satisfy StateMachineRequirement;
		satisfy ErrorHandlingRequirement;
	}
}
