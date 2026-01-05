package 'Autonomous Mobile Manipulation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def JointPosition :> ISQ::PlaneAngleValue {
		doc /* Angular position of a robotic joint in radians */
	}

	attribute def JointVelocity :> ISQ::AngularVelocityValue {
		doc /* Angular velocity of a robotic joint */
	}

	attribute def JointTorque :> ISQ::TorqueValue {
		doc /* Torque applied at a robotic joint */
	}

	attribute def GripperForce :> ISQ::ForceValue {
		doc /* Force exerted by gripper jaws */
	}

	attribute def Pose3D {
		attribute x :> ISQ::length;
		attribute y :> ISQ::length;
		attribute z :> ISQ::length;
		attribute roll :> ISQ::planeAngle;
		attribute pitch :> ISQ::planeAngle;
		attribute yaw :> ISQ::planeAngle;
	}

	attribute def Twist3D {
		attribute linearX :> ISQ::speed;
		attribute linearY :> ISQ::speed;
		attribute linearZ :> ISQ::speed;
		attribute angularX :> ISQ::angularVelocity;
		attribute angularY :> ISQ::angularVelocity;
		attribute angularZ :> ISQ::angularVelocity;
	}

	item def NavigationGoal {
		attribute targetPose : Pose3D;
		attribute tolerance :> ISQ::length;
	}

	item def ManipulationGoal {
		attribute targetPose : Pose3D;
		attribute graspForce : GripperForce;
		attribute objectMass :> ISQ::mass;
	}

	item def LaserScanData {
		attribute ranges :> ISQ::length[*] ordered;
		attribute angleMin :> ISQ::planeAngle;
		attribute angleMax :> ISQ::planeAngle;
		attribute angleIncrement :> ISQ::planeAngle;
	}

	item def CameraImageData {
		attribute width : Integer;
		attribute height : Integer;
		attribute objectDetected : Boolean;
		attribute objectCentroid : Pose3D;
	}

	item def OdometryData {
		attribute pose : Pose3D;
		attribute twist : Twist3D;
	}

	item def JointStateData {
		attribute positions : JointPosition[*] ordered;
		attribute velocities : JointVelocity[*] ordered;
		attribute efforts : JointTorque[*] ordered;
	}

	item def VelocityCommand {
		attribute linear :> ISQ::speed;
		attribute angular :> ISQ::angularVelocity;
	}

	item def TrajectoryPoint {
		attribute jointPositions : JointPosition[*] ordered;
		attribute timeFromStart :> ISQ::time;
	}

	item def PathPlan {
		attribute waypoints : Pose3D[*] ordered;
		attribute totalDistance :> ISQ::length;
		attribute estimatedDuration :> ISQ::time;
	}

	port def LaserScanPort {
		out item scanData : LaserScanData;
	}

	port def CameraPort {
		out item imageData : CameraImageData;
	}

	port def OdometryPort {
		out item odomData : OdometryData;
	}

	port def VelocityCommandPort {
		in item velocityCmd : VelocityCommand;
	}

	port def JointStatePort {
		out item jointState : JointStateData;
	}

	port def JointCommandPort {
		in item trajectoryCmd : TrajectoryPoint[*] ordered;
	}

	port def GripperCommandPort {
		in attribute gripperCmd : GripperForce;
		out attribute gripperState : Boolean;
	}

	part def LiDARSensor {
		attribute scanRate :> ISQ::frequency;
		attribute maxRange :> ISQ::length;
		attribute fieldOfView :> ISQ::planeAngle;
		port scanOutput : LaserScanPort;

		action def AcquireScan {
			out scan : LaserScanData;
		}
	}

	part def RGBDCamera {
		attribute resolution : Integer[2] ordered;
		attribute frameRate :> ISQ::frequency;
		port imageOutput : CameraPort;

		action def CaptureFrame {
			out frame : CameraImageData;
		}

		action def DetectObject {
			in frame : CameraImageData;
			out detected : Boolean;
			out location : Pose3D;
		}
	}

	part def WheelEncoder {
		attribute ticksPerRevolution : Integer;
		attribute wheelRadius :> ISQ::length;
	}

	part def MobileBase {
		attribute maxLinearSpeed :> ISQ::speed;
		attribute maxAngularSpeed :> ISQ::angularVelocity;
		attribute wheelDiameter :> ISQ::length;
		attribute wheelSeparation :> ISQ::length;

		port velocityInput : VelocityCommandPort;
		port odometryOutput : OdometryPort;

		part leftWheel : WheelEncoder;
		part rightWheel : WheelEncoder;

		action def ExecuteVelocity {
			in cmd : VelocityCommand;
			out actualTwist : Twist3D;
		}

		action def ComputeOdometry {
			in leftTicks : Integer;
			in rightTicks : Integer;
			out odom : OdometryData;
		}
	}

	part def ManipulatorJoint {
		attribute jointIndex : Integer;
		attribute minPosition : JointPosition;
		attribute maxPosition : JointPosition;
		attribute maxVelocity : JointVelocity;
		attribute maxTorque : JointTorque;

		action def MoveToPosition {
			in target : JointPosition;
			in velocity : JointVelocity;
			out reached : Boolean;
		}
	}

	part def ManipulatorArm {
		attribute degreesOfFreedom : Integer = 7;
		attribute reachRadius :> ISQ::length;
		attribute payloadCapacity :> ISQ::mass;

		port jointStateOutput : JointStatePort;
		port jointCommandInput : JointCommandPort;

		part shoulder1 : ManipulatorJoint { attribute jointIndex = 1; }
		part shoulder2 : ManipulatorJoint { attribute jointIndex = 2; }
		part elbow : ManipulatorJoint { attribute jointIndex = 3; }
		part wrist1 : ManipulatorJoint { attribute jointIndex = 4; }
		part wrist2 : ManipulatorJoint { attribute jointIndex = 5; }
		part wrist3 : ManipulatorJoint { attribute jointIndex = 6; }
		part wristRoll : ManipulatorJoint { attribute jointIndex = 7; }

		action def ExecuteTrajectory {
			in trajectory : TrajectoryPoint[*] ordered;
			out success : Boolean;
		}

		action def ComputeForwardKinematics {
			in jointPositions : JointPosition[*] ordered;
			out endEffectorPose : Pose3D;
		}

		action def ComputeInverseKinematics {
			in targetPose : Pose3D;
			out jointPositions : JointPosition[*] ordered;
			out solutionFound : Boolean;
		}
	}

	part def ParallelGripper {
		attribute maxGripWidth :> ISQ::length;
		attribute maxGripForce : GripperForce;
		attribute fingerLength :> ISQ::length;

		port gripperControl : GripperCommandPort;

		action def Grasp {
			in force : GripperForce;
			out grasped : Boolean;
		}

		action def Release {
			out released : Boolean;
		}
	}

	part def NavigationPlanner {
		action def PlanPath {
			in start : Pose3D;
			in goal : Pose3D;
			in obstacles : LaserScanData;
			out plan : PathPlan;
			out feasible : Boolean;
		}

		action def ComputeVelocity {
			in currentPose : Pose3D;
			in targetPose : Pose3D;
			in obstacles : LaserScanData;
			out velocityCmd : VelocityCommand;
		}
	}

	part def ManipulationPlanner {
		action def PlanGrasp {
			in objectPose : Pose3D;
			in objectSize :> ISQ::length;
			out graspPose : Pose3D;
			out approachPose : Pose3D;
		}

		action def PlanArmMotion {
			in startJoints : JointPosition[*] ordered;
			in goalPose : Pose3D;
			out trajectory : TrajectoryPoint[*] ordered;
			out valid : Boolean;
		}
	}

	part def PerceptionSystem {
		part lidar : LiDARSensor;
		part camera : RGBDCamera;

		action def FuseData {
			in scanData : LaserScanData;
			in imageData : CameraImageData;
			out objectPose : Pose3D;
			out objectDetected : Boolean;
		}

		action def LocalizeRobot {
			in scanData : LaserScanData;
			in odomData : OdometryData;
			out estimatedPose : Pose3D;
		}
	}

	part def ControlSystem {
		part navPlanner : NavigationPlanner;
		part manipPlanner : ManipulationPlanner;

		action def CoordinateMotion {
			in navGoal : NavigationGoal;
			in manipGoal : ManipulationGoal;
			out baseCmd : VelocityCommand;
			out armCmd : TrajectoryPoint[*] ordered;
			out gripperCmd : GripperForce;
		}
	}

	requirement def <'REQ-NAV-001'> NavigationAccuracyRequirement {
		doc /* The mobile base shall reach navigation goals within 0.05 m positional accuracy */
		subject base : MobileBase;
		require constraint {
			base.ExecuteVelocity.actualTwist != null
		}
	}

	requirement def <'REQ-MANIP-001'> ManipulationReachRequirement {
		doc /* The manipulator arm shall reach targets within its workspace with 0.01 m accuracy */
		subject arm : ManipulatorArm;
		require constraint {
			arm.reachRadius >= 0.8 [m]
		}
	}

	requirement def <'REQ-GRASP-001'> GraspForceRequirement {
		doc /* The gripper shall apply controlled force between 10 N and 150 N */
		subject gripper : ParallelGripper;
		require constraint {
			gripper.maxGripForce >= 10.0 [N] and gripper.maxGripForce <= 150.0 [N]
		}
	}

	requirement def <'REQ-SAFE-001'> ObstacleAvoidanceRequirement {
		doc /* The system shall maintain minimum 0.3 m clearance from detected obstacles */
		subject controller : ControlSystem;
	}

	requirement def <'REQ-PERF-001'> CycleTimeRequirement {
		doc /* The system shall complete pick-and-place cycles within 60 seconds */
		subject system : MobileManipulationRobot;
	}

	part def MobileManipulationRobot;

	part mobileManipulator : MobileManipulationRobot {
		doc /* 
		An autonomous mobile manipulation system that navigates to target locations,
		perceives objects in its environment, plans collision-free motions for both
		base and arm, and executes coordinated pick-and-place operations.
		The system integrates wheeled mobility with a 7-DOF manipulator arm and
		parallel gripper, using LiDAR and RGB-D sensing for perception and localization.
		*/

		part base : MobileBase {
			attribute maxLinearSpeed = 1.0 [m/s];
			attribute maxAngularSpeed = 1.57 [rad/s];
			attribute wheelDiameter = 0.15 [m];
			attribute wheelSeparation = 0.4 [m];
		}

		part arm : ManipulatorArm {
			attribute reachRadius = 0.85 [m];
			attribute payloadCapacity = 5.0 [kg];
		}

		part gripper : ParallelGripper {
			attribute maxGripWidth = 0.12 [m];
			attribute maxGripForce = 100.0 [N];
			attribute fingerLength = 0.08 [m];
		}

		part perception : PerceptionSystem;
		part controller : ControlSystem;

		connect perception.lidar.scanOutput to controller;
		connect perception.camera.imageOutput to controller;
		connect base.odometryOutput to controller;
		connect arm.jointStateOutput to controller;
		connect controller to base.velocityInput;
		connect controller to arm.jointCommandInput;
		connect controller to gripper.gripperControl;

		perform action autonomousPickAndPlace : AutonomousPickAndPlaceOperation;

		satisfy <'REQ-NAV-001'> NavigationAccuracyRequirement by base;
		satisfy <'REQ-MANIP-001'> ManipulationReachRequirement by arm;
		satisfy <'REQ-GRASP-001'> GraspForceRequirement by gripper;
		satisfy <'REQ-SAFE-001'> ObstacleAvoidanceRequirement by controller;
		satisfy <'REQ-PERF-001'> CycleTimeRequirement by mobileManipulator;
	}

	action def ScanEnvironment {
		out scanData : LaserScanData;
		out imageData : CameraImageData;
	}

	action def DetectTargetObject {
		in imageData : CameraImageData;
		in scanData : LaserScanData;
		out objectFound : Boolean;
		out objectPose : Pose3D;
	}

	action def NavigateToObject {
		in targetPose : Pose3D;
		in currentPose : Pose3D;
		out arrived : Boolean;
	}

	action def PlanGraspApproach {
		in objectPose : Pose3D;
		out approachPose : Pose3D;
		out graspPose : Pose3D;
	}

	action def MoveArmToApproach {
		in approachPose : Pose3D;
		out armReady : Boolean;
	}

	action def ExecuteGrasp {
		in graspPose : Pose3D;
		in graspForce : GripperForce;
		out objectGrasped : Boolean;
	}

	action def NavigateToDropoff {
		in dropoffPose : Pose3D;
		out arrived : Boolean;
	}

	action def PlaceObject {
		in placePose : Pose3D;
		out objectPlaced : Boolean;
	}

	action def ReturnToHome {
		in homePose : Pose3D;
		out atHome : Boolean;
	}

	action def AutonomousPickAndPlaceOperation {
		in pickLocation : Pose3D;
		in placeLocation : Pose3D;
		in homePose : Pose3D;
		out missionSuccess : Boolean;

		first start;

		then action scan : ScanEnvironment {
			out environmentScan : LaserScanData;
			out cameraFrame : CameraImageData;
		}

		then action detect : DetectTargetObject {
			in imageData = scan.cameraFrame;
			in scanData = scan.environmentScan;
			out objectFound : Boolean;
			out objectPose : Pose3D;
		}

		then decide;
			if detect.objectFound then navigateToTarget;
			if not detect.objectFound then returnHome;

		action navigateToTarget : NavigateToObject {
			in targetPose = detect.objectPose;
			in currentPose = homePose;
			out arrived : Boolean;
		}

		then action planGrasp : PlanGraspApproach {
			in objectPose = detect.objectPose;
			out approachPose : Pose3D;
			out graspPose : Pose3D;
		}

		then action approachObject : MoveArmToApproach {
			in approachPose = planGrasp.approachPose;
			out armReady : Boolean;
		}

		then action grasp : ExecuteGrasp {
			in graspPose = planGrasp.graspPose;
			in graspForce = 50.0 [N];
			out objectGrasped : Boolean;
		}

		then decide;
			if grasp.objectGrasped then navigateToPlace;
			if not grasp.objectGrasped then returnHome;

		action navigateToPlace : NavigateToDropoff {
			in dropoffPose = placeLocation;
			out arrived : Boolean;
		}

		then action place : PlaceObject {
			in placePose = placeLocation;
			out objectPlaced : Boolean;
		}

		then action returnHome : ReturnToHome {
			in homePose = homePose;
			out atHome : Boolean;
		}

		then assign missionSuccess := place.objectPlaced and returnHome.atHome;

		then done;
	}

	state def RobotOperationalStates {
		entry; then idle;

		state idle {
			entry assign systemReady = true;
		}

		transition idle_to_scanning
			first idle
			accept MissionCommand
			then scanning;

		state scanning {
			entry do ScanEnvironment;
		}

		transition scanning_to_navigating
			first scanning
			if objectDetected
			then navigating;

		transition scanning_to_idle
			first scanning
			if not objectDetected
			then idle;

		state navigating {
			entry do NavigateToObject;
		}

		transition navigating_to_approaching
			first navigating
			if navigationComplete
			then approaching;

		state approaching {
			entry do MoveArmToApproach;
		}

		transition approaching_to_grasping
			first approaching
			if armInPosition
			then grasping;

		state grasping {
			entry do ExecuteGrasp;
		}

		transition grasping_to_transporting
			first grasping
			if graspSuccessful
			then transporting;

		transition grasping_to_idle
			first grasping
			if not graspSuccessful
			then idle;

		state transporting {
			entry do NavigateToDropoff;
		}

		transition transporting_to_placing
			first transporting
			if destinationReached
			then placing;

		state placing {
			entry do PlaceObject;
		}

		transition placing_to_returning
			first placing
			then returning;

		state returning {
			entry do ReturnToHome;
		}

		transition returning_to_idle
			first returning
			then idle;

		attribute systemReady : Boolean;
		attribute objectDetected : Boolean;
		attribute navigationComplete : Boolean;
		attribute armInPosition : Boolean;
		attribute graspSuccessful : Boolean;
		attribute destinationReached : Boolean;
	}

	occurrence def MobileManipulationMission {
		ref part robot :>> mobileManipulator;

		event occurrence missionStart;
		then event occurrence environmentScanned;
		then event occurrence objectLocated;
		then event occurrence baseNavigating;
		then event occurrence armApproaching;
		then event occurrence objectGrasped;
		then event occurrence baseTransporting;
		then event occurrence objectPlaced;
		then event occurrence robotReturning;
		then event occurrence missionComplete;
	}
}
