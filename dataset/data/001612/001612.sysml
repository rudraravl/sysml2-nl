package UniversalRoboticsSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def JointAngle :> AngleValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngleUnit = SI::rad;
	}
	
	attribute def JointVelocity :> AngularSpeedValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngularSpeedUnit;
	}
	
	attribute def JointTorque :> TorqueValue {
		attribute :>> num : Real;
		attribute :>> mRef : TorqueUnit;
	}
	
	attribute def GripperForce :> ForceValue {
		attribute :>> num : Real;
		attribute :>> mRef : ForceUnit = SI::N;
	}
	
	attribute def CartesianPosition {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	attribute def Orientation {
		attribute roll : AngleValue;
		attribute pitch : AngleValue;
		attribute yaw : AngleValue;
	}
	
	attribute def EndEffectorPose {
		attribute position : CartesianPosition;
		attribute orientation : Orientation;
	}
	
	item def MotionCommand {
		attribute targetPose : EndEffectorPose;
		attribute speed : SpeedValue;
		attribute acceleration : AccelerationValue;
		attribute blendRadius : LengthValue;
	}
	
	item def JointState {
		attribute angles : JointAngle[6];
		attribute velocities : JointVelocity[6];
		attribute torques : JointTorque[6];
	}
	
	item def SafetyStatus {
		attribute emergencyStopActive : Boolean;
		attribute protectiveStopActive : Boolean;
		attribute reducedModeActive : Boolean;
		attribute safeguardStopActive : Boolean;
	}
	
	item def WorkpieceData {
		attribute detectedPose : EndEffectorPose;
		attribute mass : MassValue;
		attribute identified : Boolean;
	}
	
	port def ControlPort {
		in item commandIn : MotionCommand;
		out item stateOut : JointState;
		out item poseOut : EndEffectorPose;
	}
	
	port def SafetyPort {
		in item emergencySignal;
		out item safetyStatusOut : SafetyStatus;
	}
	
	port def VisionPort {
		out item workpieceDataOut : WorkpieceData;
	}
	
	port def GripperPort {
		in item forceCommand : GripperForce;
		out item gripperState : Boolean;
	}
	
	enum def OperatingMode {
		enum idle;
		enum manual;
		enum automatic;
		enum teaching;
		enum emergencyStop;
	}
	
	part def RobotController {
		port controlInterface : ControlPort;
		port safetyInterface : SafetyPort;
		
		attribute currentMode : OperatingMode;
		attribute trajectoryQueue : MotionCommand[*];
		
		perform action processMotionCommands;
		perform action monitorSafety;
	}
	
	part def RobotArm {
		attribute numberOfJoints : Integer = 6;
		attribute reach : LengthValue;
		attribute payload : MassValue;
		
		part baseJoint : RevoluteJoint;
		part shoulderJoint : RevoluteJoint;
		part elbowJoint : RevoluteJoint;
		part wrist1Joint : RevoluteJoint;
		part wrist2Joint : RevoluteJoint;
		part wrist3Joint : RevoluteJoint;
		
		perform action executeTrajectory;
	}
	
	part def RevoluteJoint {
		attribute currentAngle : JointAngle;
		attribute targetAngle : JointAngle;
		attribute velocity : JointVelocity;
		attribute torque : JointTorque;
		attribute maxTorque : JointTorque;
		
		port motorControl;
		port encoderFeedback;
	}
	
	part def Gripper {
		port gripperInterface : GripperPort;
		
		attribute opening : LengthValue;
		attribute maxOpening : LengthValue;
		attribute graspForce : GripperForce;
		attribute maxForce : GripperForce;
		
		perform action actuateGripper;
	}
	
	part def VisionSensor {
		port visionInterface : VisionPort;
		
		attribute resolution : Integer = 1920;
		attribute fieldOfView : AngleValue;
		attribute detectionRange : LengthValue;
		
		perform action captureImage;
		perform action processImage;
	}
	
	part def SafetyController {
		port safetyMonitor : SafetyPort;
		
		attribute maxSpeed : SpeedValue;
		attribute maxForce : ForceValue;
		attribute safetyZoneRadius : LengthValue;
		
		perform action monitorCollision;
		perform action enforceSpeedLimits;
		perform action handleEmergencyStop;
	}
	
	action def PlanMotionPath {
		in startPose : EndEffectorPose;
		in goalPose : EndEffectorPose;
		in maxVelocity : SpeedValue;
		in maxAcceleration : AccelerationValue;
		out waypoints : EndEffectorPose[*];
		out pathValid : Boolean;
	}
	
	action def ExecuteJointMotion {
		in targetJointAngles : JointAngle[6];
		in velocity : JointVelocity;
		out finalJointState : JointState;
		out motionComplete : Boolean;
	}
	
	action def GraspObject {
		in targetForce : GripperForce;
		in approachPose : EndEffectorPose;
		out graspSuccessful : Boolean;
	}
	
	action def ReleaseObject {
		in releasePose : EndEffectorPose;
		out releaseComplete : Boolean;
	}
	
	action def DetectWorkpiece {
		in searchRegion : CartesianPosition;
		out workpieceFound : Boolean;
		out workpieceData : WorkpieceData;
	}
	
	state def RobotOperationalStates {
		entry; then initializing;
		
		state initializing {
			do action systemCheck;
		}
		
		transition init_to_idle
			first initializing
			then idle;
		
		state idle;
		
		transition idle_to_automatic
			first idle
			then automatic;
		
		transition idle_to_manual
			first idle
			then manual;
		
		state manual {
			do action manualControl;
		}
		
		state automatic {
			do action executeAutomatedSequence;
		}
		
		transition automatic_to_idle
			first automatic
			then idle;
		
		transition manual_to_idle
			first manual
			then idle;
		
		transition any_to_emergency_from_idle
			first idle
			then emergencyStop;
		
		transition any_to_emergency_from_manual
			first manual
			then emergencyStop;
		
		transition any_to_emergency_from_automatic
			first automatic
			then emergencyStop;
		
		state emergencyStop {
			do action haltAllMotion;
			do action lockJoints;
		}
		
		transition emergency_to_idle
			first emergencyStop
			then idle;
	}
	
	action def PickAndPlaceSequence {
		in pickPose : EndEffectorPose;
		in placePose : EndEffectorPose;
		in homePose : EndEffectorPose;
		in gripForce : GripperForce;
		
		first start;
		
		then action detectTarget : DetectWorkpiece {
			out workpieceFound;
			out workpieceData;
		}
		
		then decide;
			if detectTarget.workpieceFound then planApproach;
			if not detectTarget.workpieceFound then returnHome;
		
		action planApproach : PlanMotionPath {
			in startPose = homePose;
			in goalPose = detectTarget.workpieceData.detectedPose;
			out waypoints;
			out pathValid;
		}
		
		then action moveToPickPosition : ExecuteJointMotion {
			out finalJointState;
			out motionComplete;
		}
		
		then action performGrasp : GraspObject {
			in targetForce = gripForce;
			in approachPose = detectTarget.workpieceData.detectedPose;
			out graspSuccessful;
		}
		
		then decide;
			if performGrasp.graspSuccessful then planPlacement;
			if not performGrasp.graspSuccessful then retryGrasp;
		
		action retryGrasp : GraspObject {
			in targetForce = gripForce;
			in approachPose = detectTarget.workpieceData.detectedPose;
		}
		then planPlacement;
		
		merge planPlacement;
		then action planPlacePath : PlanMotionPath {
			in startPose = detectTarget.workpieceData.detectedPose;
			in goalPose = placePose;
			out waypoints;
			out pathValid;
		}
		
		then action moveToPlacePosition : ExecuteJointMotion {
			out finalJointState;
			out motionComplete;
		}
		
		then action performRelease : ReleaseObject {
			in releasePose = placePose;
			out releaseComplete;
		}
		
		action returnHome : PlanMotionPath {
			in startPose = placePose;
			in goalPose = homePose;
			out waypoints;
		}
		
		then action moveToHome : ExecuteJointMotion {
			out finalJointState;
		}
		
		then done;
	}
	
	part def UniversalRobotSystem {
		part controller : RobotController {
			port :>> controlInterface;
			port :>> safetyInterface;
		}
		
		part arm : RobotArm {
			part :>> baseJoint;
			part :>> shoulderJoint;
			part :>> elbowJoint;
			part :>> wrist1Joint;
			part :>> wrist2Joint;
			part :>> wrist3Joint;
		}
		
		part gripper : Gripper {
			port :>> gripperInterface;
		}
		
		part visionSensor : VisionSensor {
			port :>> visionInterface;
		}
		
		part safetyController : SafetyController {
			port :>> safetyMonitor;
		}
		
		connect controller.safetyInterface to safetyController.safetyMonitor;
		
		perform action primaryOperation : PickAndPlaceSequence[*] ordered;
		
		exhibit state operatingBehavior : RobotOperationalStates;
	}
	
	part universalRobot : UniversalRobotSystem;
	
	requirement def <'UR-REQ-001'> PrimaryFunctionRequirement {
		doc /* 
			The Universal Robotics system shall autonomously perform pick-and-place operations 
			by detecting workpieces using vision, planning collision-free motion paths, 
			executing precise movements with the 6-axis robotic arm, grasping objects with 
			controlled force, and placing them at designated locations while maintaining 
			safety compliance throughout the operation.
		*/
		
		subject robot : UniversalRobotSystem;
		
		require visionCapability : VisionDetectionRequirement;
		require motionCapability : MotionPlanningRequirement;
		require graspingCapability : GraspingRequirement;
		require safetyCompliance : SafetyRequirement;
	}
	
	requirement def VisionDetectionRequirement {
		doc /* The system shall detect and localize workpieces within the workspace with position accuracy of ±1mm. */
		
		subject sensor : VisionSensor;
	}
	
	requirement def MotionPlanningRequirement {
		doc /* The system shall plan and execute collision-free trajectories with repeatability of ±0.03mm. */
		
		subject arm : RobotArm;
	}
	
	requirement def GraspingRequirement {
		doc /* The system shall grasp objects with controlled force up to 120N and handle payloads up to 5kg. */
		
		subject gripper : Gripper;
	}
	
	requirement def SafetyRequirement {
		doc /* The system shall comply with ISO 10218 and ISO/TS 15066 for collaborative robot safety. */
		
		subject safety : SafetyController;
	}
	
	requirement <'UR-SYS-001'> systemRequirements {
		doc /* 
			The Universal Robotics system requirements specification defining the primary 
			function of autonomous pick-and-place operations with integrated vision, 
			motion control, grasping, and safety capabilities.
		*/
		
		subject universalRobot;
		
		require primaryFunction : PrimaryFunctionRequirement;
	}
}
