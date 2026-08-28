package BarrettWAMSystem {
	doc
	/*
	 * Barrett Technology WAM (Whole-Arm Manipulator) robotic system.
	 * A collaborative 7-joint cable-driven arm with a 3-fingered BarrettHand,
	 * integrated motion control, and a dedicated safety controller.
	 */
	private import ISQ::*;
	private import ScalarValues::*;

	// Local value types for quantities not directly available in ISQ
	attribute def AngleValue :> ScalarValues::Real;
	attribute def AngularVelocityValue :> ScalarValues::Real;

	// ---- Data types ----
	attribute def JointState {
		angle : AngleValue;
		velocity : AngularVelocityValue;
		torque :> ISQ::torque;
	}

	attribute def CartesianPose {
		x :> ISQ::length;
		y :> ISQ::length;
		z :> ISQ::length;
		roll : AngleValue;
		pitch : AngleValue;
		yaw : AngleValue;
	}

	attribute def TrajectoryPoint {
		time :> ISQ::time;
		pose : CartesianPose;
		jointStates : JointState[7];
	}

	attribute def HandCommand {
		mode : ScalarValues::String;
		targetForce :> ISQ::force;
	}

	attribute def TactileReading {
		contact : ScalarValues::Boolean;
		force :> ISQ::force;
	}

	attribute def SafetyStatus {
		safe : ScalarValues::Boolean;
		reason : ScalarValues::String;
	}

	// ---- Signal types ----
	attribute def MoveCommand;
	attribute def GraspCommand;
	attribute def ReleaseCommand;
	attribute def EmergencyStop;
	attribute def Reset;
	attribute def ExcessiveForce;
	attribute def TrajectoryComplete;

	// ---- Port definitions ----
	port def PowerPort;
	port def JointCommandPort;
	port def JointStatePort;
	port def HandCommandPort;
	port def TactileReadingPort;
	port def CartesianPosePort;
	port def EstopPort;
	port def SafetyStatusPort;
	port def MountPort;

	// ---- Connection definitions ----
	connection def PowerConnection {
		end source : PowerPort;
		end target : PowerPort;
	}
	connection def JointCommandConnection {
		end source : JointCommandPort[*];
		end target : JointCommandPort[*];
	}
	connection def JointStateConnection {
		end source : JointStatePort[*];
		end target : JointStatePort[*];
	}
	connection def HandCommandConnection {
		end source : HandCommandPort;
		end target : HandCommandPort;
	}
	connection def TactileReadingConnection {
		end source : TactileReadingPort[*];
		end target : TactileReadingPort[*];
	}
	connection def CartesianPoseConnection {
		end source : CartesianPosePort;
		end target : CartesianPosePort;
	}
	connection def EstopConnection {
		end source : EstopPort;
		end target : EstopPort;
	}
	connection def SafetyStatusConnection {
		end source : SafetyStatusPort;
		end target : SafetyStatusPort;
	}
	connection def MountConnection {
		end source : MountPort;
		end target : MountPort;
	}

	// ---- Action definitions ----
	action def PlanTrajectory {
		in targetPose : CartesianPose;
		in currentState : JointState[7];
		out trajectory : TrajectoryPoint[1..*];
	}
	action def SolveInverseKinematics {
		in targetPose : CartesianPose;
		out jointAngles : AngleValue[7];
	}
	action def MoveArm {
		in trajectory : TrajectoryPoint[1..*];
		in currentStates : JointState[7];
		out commands : JointState[7];
	}
	action def ControlGrasp {
		in command : HandCommand;
		in tactile : TactileReading[3];
		out fingerCommands : HandCommand[3];
	}
	action def MonitorSafety {
		in jointStates : JointState[7];
		in tactileReadings : TactileReading[3];
		out status : SafetyStatus;
	}
	action def WaitForCommand;
	action def ExecuteMotion;
	action def PerformGrasp;
	action def ReleaseGrasp;
	action def EngageAllBrakes;
	action def MonitorJoints;

	// ---- Joint components ----
	part def BrushlessMotor {
		ratedTorque :> ISQ::torque;
		ratedSpeed : AngularVelocityValue;
	}

	part def ElectromagneticBrake {
		isEngaged : ScalarValues::Boolean = false;
		holdingTorque :> ISQ::torque;
		action engage;
		action disengage;
	}

	part def CableDrive {
		transmissionRatio : ScalarValues::Real;
		isBackdrivable : ScalarValues::Boolean = true;
		frictionCoefficient : ScalarValues::Real;
	}

	part def PositionEncoder {
		measuredAngle : AngleValue;
		resolution : AngleValue;
	}

	part def TorqueSensor {
		measuredTorque :> ISQ::torque;
	}

	part def MountingFlange;
	part def ToolFlange;

	// ---- Joint ----
	part def Joint {
		currentAngle : AngleValue;
		currentVelocity : AngularVelocityValue;
		currentTorque :> ISQ::torque;
		port power : PowerPort;
		port cmd : JointCommandPort;
		port feedback : JointStatePort;
		part motor : BrushlessMotor[1];
		part brake : ElectromagneticBrake[1];
		part transmission : CableDrive[1];
		part encoder : PositionEncoder[1];
		part torqueSensor : TorqueSensor[1];
	}

	// ---- Robotic arm ----
	part def RoboticArm {
		maxReach :> ISQ::length = 1.0;
		maxPayload :> ISQ::mass = 3.0;
		isBackdrivable : ScalarValues::Boolean = true;
		port powerIn : PowerPort;
		port jointCmd : JointCommandPort[7];
		port jointStateOut : JointStatePort[7];
		port toolMount : MountPort;
		part base : MountingFlange[1];
		part toolFlange : ToolFlange[1];
		part joints : Joint[7];
	}

	// ---- BarrettHand ----
	part def FingerLink {
		length :> ISQ::length;
	}

	part def TendonActuator {
		tension :> ISQ::force;
		port cmd : HandCommandPort;
	}

	part def TactileSensor {
		contactForce :> ISQ::force;
		isContact : ScalarValues::Boolean;
		port reading : TactileReadingPort;
	}

	part def SpreadMechanism {
		spreadAngle : AngleValue;
		port cmd : HandCommandPort;
	}

	part def Finger {
		fingerPosition : AngleValue;
		port cmd : HandCommandPort;
		port tactile : TactileReadingPort;
		part links : FingerLink[2..3];
		part tendon : TendonActuator[1];
		part sensor : TactileSensor[1];
		connection : HandCommandConnection connect cmd to tendon.cmd;
		connection : TactileReadingConnection connect sensor.reading to tactile;
	}

	part def BarrettHand {
		maxGripForce :> ISQ::force = 30.0;
		port mount : MountPort;
		port power : PowerPort;
		port cmd : HandCommandPort;
		port tactile : TactileReadingPort[3];
		part fingers : Finger[3];
		part spread : SpreadMechanism[1];
	}

	// ---- Control system ----
	part def MotionPlanner {
		action planTrajectory : PlanTrajectory;
	}

	part def KinematicsSolver {
		action solveInverseKinematics : SolveInverseKinematics;
	}

	part def ControlSystem {
		port targetPoseIn : CartesianPosePort;
		port jointCmdOut : JointCommandPort[7];
		port jointStateIn : JointStatePort[7];
		port handCmdOut : HandCommandPort;
		port handTactileIn : TactileReadingPort[3];
		part planner : MotionPlanner[1];
		part kinematics : KinematicsSolver[1];
	}

	// ---- Safety controller ----
	part def SafetyController {
		maxTorque :> ISQ::torque = 50.0;
		maxVelocity : AngularVelocityValue;
		emergencyStopTriggered : ScalarValues::Boolean = false;
		port jointStateIn : JointStatePort[7];
		port estopIn : EstopPort;
		port statusOut : SafetyStatusPort;
		port jointCmdOut : JointCommandPort[7];
		action monitorSafety : MonitorSafety;
		action engageAllBrakes : EngageAllBrakes;
	}

	// ---- State machines ----
	state def OperationalStateMachine {
		entry; then idle;
		state idle {
			do action WaitForCommand;
		}
		state moving {
			do action ExecuteMotion;
		}
		state grasping {
			do action PerformGrasp;
		}
		state holding;
		state releasing {
			do action ReleaseGrasp;
		}
		state halted {
			do action EngageAllBrakes;
		}
		transition first idle accept cmd : MoveCommand then moving;
		transition first moving accept done : TrajectoryComplete then grasping;
		transition first grasping then holding;
		transition first holding accept cmd : ReleaseCommand then releasing;
		transition first releasing then idle;
		transition first idle accept estop : EmergencyStop do action EngageAllBrakes then halted;
		transition first moving accept estop : EmergencyStop do action EngageAllBrakes then halted;
		transition first grasping accept estop : EmergencyStop do action EngageAllBrakes then halted;
		transition first holding accept estop : EmergencyStop do action EngageAllBrakes then halted;
		transition first releasing accept estop : EmergencyStop do action EngageAllBrakes then halted;
		transition first halted accept rst : Reset then idle;
	}

	state def SafetyStateMachine {
		entry; then monitoring;
		state monitoring {
			do action MonitorJoints;
		}
		state halted {
			do action EngageAllBrakes;
		}
		transition first monitoring accept estop : EmergencyStop do action EngageAllBrakes then halted;
		transition first monitoring accept force : ExcessiveForce do action EngageAllBrakes then halted;
		transition first halted accept rst : Reset then monitoring;
	}

	// ---- Requirements ----
	requirement def WAMSafetyRequirements {
		doc
		/*
		 * Safety and performance requirements for the Barrett WAM system.
		 */
		subject wam : WAMSystem;
		requirement emergencyStopRequirement {
			doc /* Upon receiving an emergency stop command, the system must halt motion and engage all brakes. */
		}
		requirement collisionPreventionRequirement {
			doc /* The system must detect excessive force or torque and halt motion to prevent collision. */
		}
		requirement backdriveSafetyRequirement {
			doc /* The cable-drive transmissions shall be backdrivable to allow manual guidance for safe human interaction. */
		}
		requirement payloadRequirement {
			doc /* The arm shall safely handle payloads up to 3 kg. */
		}
		requirement reachRequirement {
			doc /* The arm shall have a maximum reach of 1 meter. */
		}
	}

	// ---- Top-level system ----
	part def WAMSystem {
		part arm : RoboticArm[1];
		part hand : BarrettHand[1];
		part controller : ControlSystem[1];
		part safety : SafetyController[1];
		port powerIn : PowerPort;
		port targetPoseIn : CartesianPosePort;
		port estopIn : EstopPort;
		port statusOut : SafetyStatusPort;
		state operationalState : OperationalStateMachine;
		state safetyState : SafetyStateMachine;
		connection : MountConnection connect arm.toolMount to hand.mount;
		connection : PowerConnection connect powerIn to arm.powerIn;
		connection : PowerConnection connect powerIn to hand.power;
		connection : CartesianPoseConnection connect targetPoseIn to controller.targetPoseIn;
		connection : EstopConnection connect estopIn to safety.estopIn;
		connection : SafetyStatusConnection connect safety.statusOut to statusOut;
		connection : JointCommandConnection connect controller.jointCmdOut to arm.jointCmd;
		connection : JointStateConnection connect arm.jointStateOut to controller.jointStateIn;
		connection : JointStateConnection connect arm.jointStateOut to safety.jointStateIn;
		connection : HandCommandConnection connect controller.handCmdOut to hand.cmd;
		connection : TactileReadingConnection connect hand.tactile to controller.handTactileIn;
		connection : JointCommandConnection connect safety.jointCmdOut to arm.jointCmd;
	}

	part wam : WAMSystem;
}
