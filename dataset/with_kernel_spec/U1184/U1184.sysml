package SixAxisIndustrialRobotSystem {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;

	attribute def Length :> Real { unit = 'mm'; }
	attribute def Angle :> Real { unit = 'deg'; }
	attribute def Torque :> Real { unit = 'N*m'; }
	attribute def Force :> Real { unit = 'N'; }
	attribute def Mass :> Real { unit = 'kg'; }
	attribute def ElectricPotential :> Real { unit = 'V'; }
	attribute def ElectricCurrent :> Real { unit = 'A'; }

	item def TargetPose {
		doc
		/*
		 * A target pose for the end-effector in Cartesian space,
		 * including position and orientation.
		 */
		attribute x : Length;
		attribute y : Length;
		attribute z : Length;
		attribute roll : Angle;
		attribute pitch : Angle;
		attribute yaw : Angle;
	}

	item def JointCommand {
		doc
		/*
		 * A command to a single rotary joint, specifying the desired
		 * angle and torque.
		 */
		attribute targetAngle : Angle;
		attribute targetTorque : Torque;
	}

	item def JointFeedback {
		doc
		/*
		 * Sensor feedback from a single rotary joint, providing the
		 * current angle and torque.
		 */
		attribute currentAngle : Angle;
		attribute currentTorque : Torque;
	}

	item def GripperCommand {
		doc
		/*
		 * A command to the end-effector gripper, specifying the grip
		 * force and whether the gripper should be closed or open.
		 */
		attribute gripForce : Force;
		attribute isClosed : Boolean;
	}

	item def GripperFeedback {
		doc
		/*
		 * Feedback from the end-effector gripper, including the actual
		 * grip force, payload mass, and grasp status.
		 */
		attribute actualForce : Force;
		attribute payloadMass : Mass;
		attribute isGrasped : Boolean;
	}

	item def ElectricalPower {
		doc
		/*
		 * Electrical power supply characteristics.
		 */
		attribute voltage : ElectricPotential;
		attribute current : ElectricCurrent;
	}

	part def Joint {
		doc
		/*
		 * A powered rotary joint with closed-loop command and feedback.
		 * Each joint can rotate to a commanded angle while applying a
		 * specific torque, and continuously sends sensor feedback.
		 */
		port commandPort {
			in command : JointCommand;
		}
		port feedbackPort {
			out feedback : JointFeedback;
		}
		port powerPort {
			in power : ElectricalPower;
		}
		attribute currentAngle : Angle;
		attribute currentTorque : Torque;

		action jointBehavior {
			action receiveCommand accept JointCommand via commandPort;
			then action actuateJoint;
			then action sendFeedback send new JointFeedback() to feedbackPort;
		}
	}

	part def Gripper {
		doc
		/*
		 * A two-finger gripping mechanism with force and payload sensing.
		 * Used to grasp, hold, and release objects with a specified force.
		 */
		port commandPort {
			in command : GripperCommand;
		}
		port feedbackPort {
			out feedback : GripperFeedback;
		}
		port powerPort {
			in power : ElectricalPower;
		}
		attribute appliedForce : Force;
		attribute closed : Boolean;
		attribute payloadMass : Mass;

		action gripperBehavior {
			action receiveCommand accept GripperCommand via commandPort;
			then action actuateGripper;
			then action sendFeedback send new GripperFeedback() to feedbackPort;
		}
	}

	part def EndEffector {
		doc
		/*
		 * End effector assembly with a controllable gripper.
		 * Delegates command, feedback, and power ports to the gripper.
		 */
		port commandPort {
			in command : GripperCommand;
		}
		port feedbackPort {
			out feedback : GripperFeedback;
		}
		port powerPort {
			in power : ElectricalPower;
		}
		part gripper : Gripper;
		bind commandPort = gripper.commandPort;
		bind powerPort = gripper.powerPort;
		bind gripper.feedbackPort = feedbackPort;
	}

	part def RobotController {
		doc
		/*
		 * Central robot controller. Receives high-level target pose
		 * commands, performs inverse kinematics to determine joint
		 * angles and torques, and dispatches commands to all six joints
		 * and the gripper. Monitors feedback in a closed loop.
		 */
		port targetPosePort {
			in targetPose : TargetPose;
		}
		port powerPort {
			in power : ElectricalPower;
		}
		port shoulderCmdPort {
			out command : JointCommand;
		}
		port upperArmCmdPort {
			out command : JointCommand;
		}
		port elbowCmdPort {
			out command : JointCommand;
		}
		port forearmCmdPort {
			out command : JointCommand;
		}
		port wrist1CmdPort {
			out command : JointCommand;
		}
		port wrist2CmdPort {
			out command : JointCommand;
		}
		port shoulderFbPort {
			in feedback : JointFeedback;
		}
		port upperArmFbPort {
			in feedback : JointFeedback;
		}
		port elbowFbPort {
			in feedback : JointFeedback;
		}
		port forearmFbPort {
			in feedback : JointFeedback;
		}
		port wrist1FbPort {
			in feedback : JointFeedback;
		}
		port wrist2FbPort {
			in feedback : JointFeedback;
		}
		port gripperCmdPort {
			out command : GripperCommand;
		}
		port gripperFbPort {
			in feedback : GripperFeedback;
		}
		attribute positionError : Length;
		attribute computedAngles : Angle[6];
		attribute computedTorques : Torque[6];

		action controllerBehavior {
			action receiveTarget accept TargetPose via targetPosePort;
			then action solveInverseKinematics;
			then action sendShoulderCmd send new JointCommand() to shoulderCmdPort;
			then action sendUpperArmCmd send new JointCommand() to upperArmCmdPort;
			then action sendElbowCmd send new JointCommand() to elbowCmdPort;
			then action sendForearmCmd send new JointCommand() to forearmCmdPort;
			then action sendWrist1Cmd send new JointCommand() to wrist1CmdPort;
			then action sendWrist2Cmd send new JointCommand() to wrist2CmdPort;
			then action sendGripperCmd send new GripperCommand() to gripperCmdPort;
		}

		action feedbackMonitor {
			action receiveShoulderFb accept JointFeedback via shoulderFbPort;
			then action receiveUpperArmFb accept JointFeedback via upperArmFbPort;
			then action receiveElbowFb accept JointFeedback via elbowFbPort;
			then action receiveForearmFb accept JointFeedback via forearmFbPort;
			then action receiveWrist1Fb accept JointFeedback via wrist1FbPort;
			then action receiveWrist2Fb accept JointFeedback via wrist2FbPort;
			then action receiveGripperFb accept GripperFeedback via gripperFbPort;
			then action monitorStatus;
		}
	}

	part def PowerSupply {
		doc
		/*
		 * Electrical power supply for the entire robot system.
		 */
		port outputPort {
			out power : ElectricalPower;
		}
	}

	part def SixAxisRobot {
		doc
		/*
		 * Complete six-axis industrial robotic arm system for precise,
		 * automated pick-and-place operations. Comprises a main articulated
		 * arm with six joints (shoulder, upper arm, elbow, forearm, and a
		 * two-axis wrist), an end-effector with gripper, a central controller,
		 * and a power supply.
		 */
		port targetInputPort {
			in targetPose : TargetPose;
		}

		part controller : RobotController;
		part shoulder : Joint;
		part upperArm : Joint;
		part elbow : Joint;
		part forearm : Joint;
		part wrist1 : Joint;
		part wrist2 : Joint;
		part endEffector : EndEffector;
		part powerSupply : PowerSupply;

		attribute positioningTolerance : Length = 0.0005;
		attribute maxPayload : Mass = 5;
		attribute maxGripperForce : Force = 100;

		flow targetFlow of TargetPose
			from targetInputPort.targetPose to controller.targetPosePort.targetPose;

		flow shoulderCmdFlow of JointCommand
			from controller.shoulderCmdPort.command to shoulder.commandPort.command;
		flow upperArmCmdFlow of JointCommand
			from controller.upperArmCmdPort.command to upperArm.commandPort.command;
		flow elbowCmdFlow of JointCommand
			from controller.elbowCmdPort.command to elbow.commandPort.command;
		flow forearmCmdFlow of JointCommand
			from controller.forearmCmdPort.command to forearm.commandPort.command;
		flow wrist1CmdFlow of JointCommand
			from controller.wrist1CmdPort.command to wrist1.commandPort.command;
		flow wrist2CmdFlow of JointCommand
			from controller.wrist2CmdPort.command to wrist2.commandPort.command;

		flow shoulderFbFlow of JointFeedback
			from shoulder.feedbackPort.feedback to controller.shoulderFbPort.feedback;
		flow upperArmFbFlow of JointFeedback
			from upperArm.feedbackPort.feedback to controller.upperArmFbPort.feedback;
		flow elbowFbFlow of JointFeedback
			from elbow.feedbackPort.feedback to controller.elbowFbPort.feedback;
		flow forearmFbFlow of JointFeedback
			from forearm.feedbackPort.feedback to controller.forearmFbPort.feedback;
		flow wrist1FbFlow of JointFeedback
			from wrist1.feedbackPort.feedback to controller.wrist1FbPort.feedback;
		flow wrist2FbFlow of JointFeedback
			from wrist2.feedbackPort.feedback to controller.wrist2FbPort.feedback;

		flow gripperCmdFlow of GripperCommand
			from controller.gripperCmdPort.command to endEffector.commandPort.command;
		flow gripperFbFlow of GripperFeedback
			from endEffector.feedbackPort.feedback to controller.gripperFbPort.feedback;

		flow controllerPowerFlow of ElectricalPower
			from powerSupply.outputPort.power to controller.powerPort.power;
		flow shoulderPowerFlow of ElectricalPower
			from powerSupply.outputPort.power to shoulder.powerPort.power;
		flow upperArmPowerFlow of ElectricalPower
			from powerSupply.outputPort.power to upperArm.powerPort.power;
		flow elbowPowerFlow of ElectricalPower
			from powerSupply.outputPort.power to elbow.powerPort.power;
		flow forearmPowerFlow of ElectricalPower
			from powerSupply.outputPort.power to forearm.powerPort.power;
		flow wrist1PowerFlow of ElectricalPower
			from powerSupply.outputPort.power to wrist1.powerPort.power;
		flow wrist2PowerFlow of ElectricalPower
			from powerSupply.outputPort.power to wrist2.powerPort.power;
		flow endEffectorPowerFlow of ElectricalPower
			from powerSupply.outputPort.power to endEffector.powerPort.power;

		assert constraint positioningConstraint {
			doc /* The gripper shall be positioned within 0.5 mm of the target pose. */
			controller.positionError <= positioningTolerance;
		}
		assert constraint payloadConstraint {
			doc /* The robot shall handle payload masses up to 5 kg. */
			endEffector.gripper.payloadMass <= maxPayload;
		}
		assert constraint safeForceConstraint {
			doc /* The gripper shall not exceed the maximum safe gripping force. */
			endEffector.gripper.appliedForce <= maxGripperForce;
		}

		action pickAndPlaceBehavior {
			action approachPick;
			then action grasp;
			then action lift;
			then action moveToPlace;
			then action approachPlace;
			then action release;
			then action retract;
		}
	}

	requirement def PositioningAccuracy {
		doc /* The robotic arm shall position its gripper within 0.5 mm of a target. */
		attribute maxError : Length = 0.0005;
		subject arm : SixAxisRobot;
		objective {
			arm.controller.positionError <= maxError;
		}
	}

	requirement def PayloadCapacity {
		doc /* The robotic arm shall handle payloads up to 5 kg. */
		attribute maxPayload : Mass = 5;
		subject arm : SixAxisRobot;
		objective {
			arm.endEffector.gripper.payloadMass <= maxPayload;
		}
	}

	requirement def SafeForceLimit {
		doc /* The robotic arm shall operate safely by limiting the forces it exerts. */
		attribute maxForce : Force = 100;
		subject arm : SixAxisRobot;
		objective {
			arm.endEffector.gripper.appliedForce <= maxForce;
		}
	}

	part robotSystem : SixAxisRobot {
		satisfy PositioningAccuracy;
		satisfy PayloadCapacity;
		satisfy SafeForceLimit;
	}
}
