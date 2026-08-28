package 'Doosan Collaborative Robot System' {
	private import ISQ::MassValue;
	private import ISQ::LengthValue;
	private import ISQ::TorqueValue;
	private import ISQ::PlaneAngleValue;
	private import ISQ::ForceValue;
	private import ISQ::AngularVelocityValue;
	private import ISQ::ElectricPotentialValue;
	private import ISQ::ElectricCurrentValue;
	private import ScalarValues::Boolean;
	private import ScalarValues::String;
	private import ScalarValues::Real;
	private import SI::kg;
	private import SI::mm;
	private import SI::N;
	private import SI::m;
	private import SI::V;
	private import SI::A;

	attribute def Pose3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
		attribute roll : PlaneAngleValue;
		attribute pitch : PlaneAngleValue;
		attribute yaw : PlaneAngleValue;
	}

	attribute def Workpiece {
		attribute id : String;
		attribute pose : Pose3D;
		attribute mass : MassValue;
	}

	attribute def Trajectory {
		attribute waypoints : Pose3D[1..*];
	}

	attribute def JointState {
		attribute angle : PlaneAngleValue;
		attribute velocity : AngularVelocityValue;
		attribute torque : TorqueValue;
	}

	attribute def GripperCommand {
		attribute targetForce : ForceValue;
		attribute isOpen : Boolean;
	}

	attribute def ObstacleDistance {
		attribute distance : LengthValue;
	}

	port def WorkpieceDataPort {
		out workpieces : Workpiece[0..*];
	}
	port def TrajectoryPort {
		out trajectory : Trajectory;
	}
	port def JointStatePort {
		out states : JointState[6];
	}
	port def GripperCommandPort {
		out command : GripperCommand;
	}
	port def TorqueDataPort {
		out torques : TorqueValue[6];
	}
	port def ObstacleDataPort {
		out obstacles : ObstacleDistance[0..*];
	}
	port def EStopSignalPort {
		out triggered : Boolean;
	}
	port def EmergencyStopCmdPort {
		out emergencyStop : Boolean;
	}

	part def ServoMotor {
		in attribute commandAngle : PlaneAngleValue;
		out attribute actualAngle : PlaneAngleValue;
	}

	part def AngleSensor {
		out attribute measuredAngle : PlaneAngleValue;
	}

	part def TorqueSensor {
		out attribute measuredTorque : TorqueValue;
	}

	part def RobotJoint {
		part motor : ServoMotor;
		part angleSensor : AngleSensor;
		part torqueSensor : TorqueSensor;
		out attribute jointState : JointState;
		bind angleSensor.measuredAngle = jointState.angle;
		bind torqueSensor.measuredTorque = jointState.torque;
	}

	part def SixAxisRobotArm {
		attribute maxPayload : MassValue default 15 [kg];
		attribute repeatability : LengthValue default 0.05 [mm];
		part joint1 : RobotJoint;
		part joint2 : RobotJoint;
		part joint3 : RobotJoint;
		part joint4 : RobotJoint;
		part joint5 : RobotJoint;
		part joint6 : RobotJoint;
		port trajectoryIn : ~TrajectoryPort;
		port stateOut : JointStatePort;
		port torqueOut : TorqueDataPort;
	}

	part def LinearActuator {
		in attribute commandPosition : LengthValue;
		out attribute actualPosition : LengthValue;
	}

	part def ForceSensor {
		out attribute measuredForce : ForceValue;
	}

	part def AdaptiveGripper {
		part actuator1 : LinearActuator;
		part actuator2 : LinearActuator;
		part forceSensor : ForceSensor;
		port commandIn : ~GripperCommandPort;
		out attribute appliedForce : ForceValue;
		bind forceSensor.measuredForce = appliedForce;
	}

	part def DepthCamera {
		out attribute detectedWorkpieces : Workpiece[0..*];
	}

	part def VisionSystem {
		part camera : DepthCamera;
		port workpieceOut : WorkpieceDataPort;
		bind camera.detectedWorkpieces = workpieceOut.workpieces;
	}

	action def ComputeTrajectory {
		in workpiece : Workpiece;
		out trajectory : Trajectory;
	}

	part def MainController {
		port workpieceIn : ~WorkpieceDataPort;
		port jointStateIn : ~JointStatePort;
		port emergencyStopIn : ~EmergencyStopCmdPort;
		port trajectoryOut : TrajectoryPort;
		port gripperCmdOut : GripperCommandPort;
	}

	part def LaserScanner {
		port obstacleOut : ObstacleDataPort;
	}

	part def EmergencyStopButton {
		port estopOut : EStopSignalPort;
	}

	part def SafetyController {
		port jointTorquesIn : ~TorqueDataPort;
		port obstacleDistancesIn : ~ObstacleDataPort;
		port estopTriggeredIn : ~EStopSignalPort;
		port emergencyStopOut : EmergencyStopCmdPort;
		attribute torqueLimit : TorqueValue default 80 [N*m];
		attribute safeDistance : LengthValue default 0.5 [m];
	}

	part def PowerSupplyUnit {
		attribute outputVoltage : ElectricPotentialValue default 48 [V];
		attribute maxCurrent : ElectricCurrentValue default 20 [A];
	}

	part def DoosanCobot {
		part arm : SixAxisRobotArm;
		part gripper : AdaptiveGripper;
		part vision : VisionSystem;
		part mainCtrl : MainController;
		part safetyCtrl : SafetyController;
		part laserScanner : LaserScanner;
		part estopButton : EmergencyStopButton;
		part psu : PowerSupplyUnit;

		connect vision.workpieceOut to mainCtrl.workpieceIn;
		connect mainCtrl.trajectoryOut to arm.trajectoryIn;
		connect mainCtrl.gripperCmdOut to gripper.commandIn;
		connect arm.stateOut to mainCtrl.jointStateIn;
		connect arm.torqueOut to safetyCtrl.jointTorquesIn;
		connect laserScanner.obstacleOut to safetyCtrl.obstacleDistancesIn;
		connect estopButton.estopOut to safetyCtrl.estopTriggeredIn;
		connect safetyCtrl.emergencyStopOut to mainCtrl.emergencyStopIn;

		state robotOperation {
			entry; then Idle;
			state Idle;
			accept StartSignal then Scanning;
			state Scanning;
			accept WorkpieceIdentified then Planning;
			state Planning;
			accept TrajectoryReady then MovingToPick;
			state MovingToPick;
			accept AtPickPosition then Grasping;
			state Grasping;
			accept ObjectGrasped then MovingToPlace;
			state MovingToPlace;
			accept AtPlacePosition then Placing;
			state Placing;
			accept ObjectPlaced then Verifying;
			state Verifying;
			accept PlacementVerified then Homing;
			state Homing;
			accept HomeReached then Idle;
			accept EmergencyStopSignal then EmergencyStopped;
			state EmergencyStopped;
			accept ResetSignal then Idle;
		}
	}

	attribute def StartSignal;
	attribute def WorkpieceIdentified;
	attribute def TrajectoryReady;
	attribute def AtPickPosition;
	attribute def ObjectGrasped;
	attribute def AtPlacePosition;
	attribute def ObjectPlaced;
	attribute def PlacementVerified;
	attribute def HomeReached;
	attribute def ResetSignal;
	attribute def EmergencyStopSignal;

	requirement def PayloadRequirement {
		doc /* The robotic arm shall be capable of handling payloads up to 15 kg. */
		subject arm : SixAxisRobotArm;
		assert constraint { arm.maxPayload >= 15 [kg] }
	}

	requirement def RepeatabilityRequirement {
		doc /* The robotic arm shall achieve a positioning repeatability of 0.05 mm or better. */
		subject arm : SixAxisRobotArm;
		assert constraint { arm.repeatability <= 0.05 [mm] }
	}

	requirement def SafetyStopRequirement {
		doc /* The safety controller shall trigger an emergency stop if unexpected torque is detected. */
		subject safety : SafetyController;
		assert constraint { safety.emergencyStopOut.emergencyStop == true }
	}
}
