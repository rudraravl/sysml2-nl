package 'FANUC Robotic Work Cell' {
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		private import ISQ::*;
		private import SI::*;
		private import ScalarValues::*;

		attribute def Position3D {
			attribute x : LengthValue;
			attribute y : LengthValue;
			attribute z : LengthValue;
		}
		attribute def Orientation3D {
			attribute roll : PlaneAngleValue;
			attribute pitch : PlaneAngleValue;
			attribute yaw : PlaneAngleValue;
		}
		attribute def WorkpiecePose {
			attribute position : Position3D;
			attribute orientation : Orientation3D;
		}

		attribute def MotionCmd {
			attribute targetPose : WorkpiecePose;
			attribute speed : SpeedValue;
		}
		attribute def GripCmd {
			attribute gripForce : ForceValue;
		}
		attribute def ReleaseCmd;
		attribute def HaltCmd;

		item def Workpiece {
			attribute weight : MassValue;
		}
		item def DetectedWorkpiece :> Workpiece {
			attribute pose : WorkpiecePose;
		}

		part def ServoMotor {
			attribute maxTorque : TorqueValue;
		}
		part def Joint {
			attribute index : Integer;
			part motor : ServoMotor;
		}
		part def AdaptiveGripper {
			attribute maxGripForce : ForceValue;
			port gripCmdPort { in gripCmd : GripCmd; }
			port releaseCmdPort { in releaseCmd : ReleaseCmd; }
			port gripStatusPort { out isGripped : Boolean; }
		}
		part def RobotArm {
			attribute maxReach : LengthValue = 1.8 [m];
			attribute maxPayload : MassValue = 25 [kg];
			part joints : Joint[6];
			part gripper : AdaptiveGripper;
			port motionCmdPort { in motionCmd : MotionCmd; }
			port haltCmdPort { in haltCmd : HaltCmd; }
			port placedWorkpiecePort { out placedWorkpiece : Workpiece; }
		}
		part def VisionSensor {
			port workpiecePresentPort { in workpiecePresent : Workpiece; }
			port detectedWorkpiecePort { out detectedWorkpiece : DetectedWorkpiece; }
		}
		part def Conveyor {
			port workpiecePresentPort { out workpiecePresent : Workpiece; }
		}
		part def Workstation {
			port placedWorkpiecePort { in placedWorkpiece : Workpiece; }
		}
		part def RobotController {
			port detectedWorkpiecePort { in detectedWorkpiece : DetectedWorkpiece; }
			port motionCmdPort { out motionCmd : MotionCmd; }
			port gripCmdPort { out gripCmd : GripCmd; }
			port releaseCmdPort { out releaseCmd : ReleaseCmd; }
			port haltCmdPort { in haltCmd : HaltCmd; }
		}
		part def SafetyController {
			port haltCmdPort { out haltCmd : HaltCmd; }
			attribute lightCurtainTripped : Boolean;
			attribute eStopPressed : Boolean;
		}

		action def 'Detect Workpiece' {
			in workpiece : Workpiece;
			out detectedWorkpiece : DetectedWorkpiece;
		}
		action def 'Calculate Motion' {
			in detectedWorkpiece : DetectedWorkpiece;
			out motionCmd : MotionCmd;
		}
		action def 'Execute Pick' {
			in motionCmd : MotionCmd;
			out grippedWorkpiece : Workpiece;
		}
		action def 'Execute Move' {
			in grippedWorkpiece : Workpiece;
			out movedWorkpiece : Workpiece;
		}
		action def 'Execute Place' {
			in movedWorkpiece : Workpiece;
			out placedWorkpiece : Workpiece;
		}
		action def 'Production Cycle' {
			in workpiece : Workpiece;
			out placedWorkpiece : Workpiece;

			action 'detect workpiece' : 'Detect Workpiece' {
				in workpiece = 'Production Cycle'::workpiece;
				out detectedWorkpiece : DetectedWorkpiece;
			}
			flow 'detect workpiece'.detectedWorkpiece to 'calculate motion'.detectedWorkpiece;

			action 'calculate motion' : 'Calculate Motion' {
				in detectedWorkpiece : DetectedWorkpiece;
				out motionCmd : MotionCmd;
			}
			flow 'calculate motion'.motionCmd to 'execute pick'.motionCmd;

			action 'execute pick' : 'Execute Pick' {
				in motionCmd : MotionCmd;
				out grippedWorkpiece : Workpiece;
			}
			flow 'execute pick'.grippedWorkpiece to 'execute move'.grippedWorkpiece;

			action 'execute move' : 'Execute Move' {
				in grippedWorkpiece : Workpiece;
				out movedWorkpiece : Workpiece;
			}
			flow 'execute move'.movedWorkpiece to 'execute place'.movedWorkpiece;

			action 'execute place' : 'Execute Place' {
				in movedWorkpiece : Workpiece;
				out placedWorkpiece : Workpiece;
			}
			flow 'execute place'.placedWorkpiece to 'Production Cycle'::placedWorkpiece;
		}

		requirement def 'Payload Requirement' {
			doc /* The robot arm must handle parts weighing up to 25 kg. */
			subject arm : RobotArm;
			constraint { arm.maxPayload >= 25 [kg] }
		}
		requirement def 'Reach Requirement' {
			doc /* The robot arm must have a reach of at least 1.8 meters. */
			subject arm : RobotArm;
			constraint { arm.maxReach >= 1.8 [m] }
		}
		requirement def 'Safety Requirement' {
			doc /* The safety controller shall halt robot motion upon safety device trigger. */
			subject safetyController : SafetyController;
			constraint { safetyController.eStopPressed or safetyController.lightCurtainTripped }
		}
	}

	package Usages {
		part 'Work Cell' {
			part robotController : RobotController;
			part robotArm : RobotArm;
			part visionSensor : VisionSensor;
			part conveyor : Conveyor;
			part workstation : Workstation;
			part safetyController : SafetyController;

			flow 'workpieceArrivalFlow' of Workpiece
				from conveyor.workpiecePresentPort.workpiecePresent to visionSensor.workpiecePresentPort.workpiecePresent;
			flow 'visionDataFlow' of DetectedWorkpiece
				from visionSensor.detectedWorkpiecePort.detectedWorkpiece to robotController.detectedWorkpiecePort.detectedWorkpiece;
			flow 'motionCmdFlow' of MotionCmd
				from robotController.motionCmdPort.motionCmd to robotArm.motionCmdPort.motionCmd;
			flow 'gripCmdFlow' of GripCmd
				from robotController.gripCmdPort.gripCmd to robotArm.gripper.gripCmdPort.gripCmd;
			flow 'releaseCmdFlow' of ReleaseCmd
				from robotController.releaseCmdPort.releaseCmd to robotArm.gripper.releaseCmdPort.releaseCmd;
			flow 'controllerHaltFlow' of HaltCmd
				from safetyController.haltCmdPort.haltCmd to robotController.haltCmdPort.haltCmd;
			flow 'armHaltFlow' of HaltCmd
				from safetyController.haltCmdPort.haltCmd to robotArm.haltCmdPort.haltCmd;
			flow 'placedWorkpieceFlow' of Workpiece
				from robotArm.placedWorkpiecePort.placedWorkpiece to workstation.placedWorkpiecePort.placedWorkpiece;

			perform action 'productionCycle' : 'Production Cycle';

			state 'safetyMonitoring' {
				state 'Monitoring';
				state 'Halted';
				transition from 'Monitoring' to 'Halted'
					when safetyController.lightCurtainTripped || safetyController.eStopPressed;
				transition from 'Halted' to 'Monitoring'
					when !safetyController.eStopPressed && !safetyController.lightCurtainTripped;
			}

			requirement 'payloadReq' : 'Payload Requirement' {
				subject :>> arm = robotArm;
			}
			requirement 'reachReq' : 'Reach Requirement' {
				subject :>> arm = robotArm;
			}
			requirement 'safetyReq' : 'Safety Requirement' {
				subject :>> safetyController = safetyController;
			}
		}
	}
}
