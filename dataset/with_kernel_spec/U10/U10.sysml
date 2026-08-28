package 'Robotic Work Cell' {
	private import ScalarValues::*;

	package Definitions {
		attribute def Length :> Real;
		attribute def Force :> Real;
		attribute def Voltage :> Real;
		attribute def Frequency :> Real;

		attribute def TaskCommand;
		attribute def ObjectLocated;
		attribute def ObstacleDetected;
		attribute def GraspSuccess;
		attribute def GraspFailure;
		attribute def ProcessingComplete;
		attribute def ResetCommand;

		item def Workpiece;
		item def ProcessedWorkpiece :> Workpiece;

		port def PowerPort {
			out voltage : Voltage;
		}
		port def ControlPort {
			in command : TaskCommand;
			out status : Boolean;
		}
		port def VisionDataPort {
			out objectLocation : Length[3];
			out objectDetected : Boolean;
		}
		port def ForceDataPort {
			out contactForce : Force;
			out contactDetected : Boolean;
		}
		port def JointControlPort {
			in targetAngle : Real;
		}
		port def GripperControlPort {
			in gripCommand : String;
		}
		port def GripPort {
			in item workpiece : Workpiece;
			out item heldWorkpiece : Workpiece;
		}

		part def PowerSupply {
			attribute outputVoltage : Voltage = 24;
			port powerOut : PowerPort;
		}

		part def Joint {
			port powerIn : ~PowerPort;
			port controlIn : JointControlPort;
		}

		part def RobotArm {
			attribute maxReach : Length = 1.2;
			part base : Joint;
			part shoulder : Joint;
			part elbow : Joint;
			part wrist : Joint;
			port powerIn : ~PowerPort;
			port controlIn : JointControlPort;
		}

		part def Gripper {
			attribute maxForce : Force = 150;
			attribute fingerCount : Integer = 2;
			port powerIn : ~PowerPort;
			port controlIn : GripperControlPort;
			port gripPort : GripPort;
		}

		part def VisionSensor {
			attribute resolution : String = "high-resolution";
			port dataOut : VisionDataPort;
		}

		part def ForceSensor {
			attribute sensitivity : String = "high";
			port dataOut : ForceDataPort;
		}

		part def RobotController {
			attribute clockFrequency : Frequency = 1000;
			port powerIn : ~PowerPort;
			port commandIn : ControlPort;
			port visionIn : ~VisionDataPort;
			port forceIn : ~ForceDataPort;
			port armControlOut : JointControlPort;
			port gripperControlOut : GripperControlPort;
		}

		part def IndustrialRobot {
			part arm : RobotArm;
			part gripper : Gripper;
			part visionSensor : VisionSensor;
			part forceSensor : ForceSensor;
			part controller : RobotController;
			part powerSupply : PowerSupply;
		}

		action def PerceiveWorkArea;
		action def PlanTrajectory;
		action def MoveToTarget;
		action def GripWorkpiece;
		action def ProcessWorkpiece;
		action def MoveToRelease;
		action def ReleaseWorkpiece;
		action def SafeStop;

		state def RobotStates;

		state robotStates : RobotStates {
			in robot : IndustrialRobot;

			entry; then idle;

			state idle;
			accept TaskCommand then perceiving;

			state perceiving {
				entry action perceive : PerceiveWorkArea;
			}
			accept ObjectLocated then planning;
			accept ObstacleDetected then errorState;

			state planning {
				entry action plan : PlanTrajectory;
			}
			then movingToTarget;

			state movingToTarget {
				entry action move : MoveToTarget;
			}
			then gripping;

			state gripping {
				entry action grip : GripWorkpiece;
			}
			accept GraspSuccess then processing;
			accept GraspFailure then errorState;
			accept ObstacleDetected then errorState;

			state processing {
				entry action process : ProcessWorkpiece;
			}
			accept ProcessingComplete then movingToRelease;

			state movingToRelease {
				entry action moveRelease : MoveToRelease;
			}
			then releasing;

			state releasing {
				entry action release : ReleaseWorkpiece;
			}
			then idle;

			state errorState {
				entry action safeStop : SafeStop;
			}
			accept ResetCommand then idle;
		}

		requirement def ReachRequirement {
			doc /* The robot arm shall have a minimum reach of 1.2 meters. */
			subject arm : RobotArm;
		}

		requirement def GripForceRequirement {
			doc /* The gripper shall be capable of exerting up to 150 Newtons of force. */
			subject gripper : Gripper;
		}

		requirement def PowerRequirement {
			doc /* The system shall operate on a 24-volt power supply. */
			subject powerSupply : PowerSupply;
		}

		requirement def ErrorHandlingRequirement {
			doc /* The system shall enter a safe error state upon detecting grasp failure or obstacle. */
			subject robot : IndustrialRobot;
		}
	}

	package Usages {
		private import Definitions::*;

		part roboticWorkCell : IndustrialRobot {
			connect powerSupply.powerOut to arm.powerIn;
			connect powerSupply.powerOut to gripper.powerIn;
			connect powerSupply.powerOut to controller.powerIn;
			connect visionSensor.dataOut to controller.visionIn;
			connect forceSensor.dataOut to controller.forceIn;
			connect controller.armControlOut to arm.controlIn;
			connect controller.gripperControlOut to gripper.controlIn;

			exhibit robotStates {
				in robot = roboticWorkCell;
			}
		}

		requirement workCellReachReq : ReachRequirement {
			subject arm = roboticWorkCell.arm;
		}
		requirement workCellGripForceReq : GripForceRequirement {
			subject gripper = roboticWorkCell.gripper;
		}
		requirement workCellPowerReq : PowerRequirement {
			subject powerSupply = roboticWorkCell.powerSupply;
		}
		requirement workCellErrorHandlingReq : ErrorHandlingRequirement {
			subject robot = roboticWorkCell;
		}
	}
}
