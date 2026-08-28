package IndustrialRobotCellHD {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def StartCommand;
	attribute def PauseCommand;
	attribute def ResumeCommand;
	attribute def FaultSignal;
	attribute def EmergencyStopSignal;
	attribute def ResetCommand;
	attribute def TaskCommand;
	attribute def InitializationComplete;
	attribute def WorkpieceLocated;
	attribute def TrajectoryReady;
	attribute def PositionReached;
	attribute def ObjectGrasped;
	attribute def ObjectReleased;
	attribute def HomeReached;

	item def Workpiece {
		attribute positionX : LengthValue;
		attribute positionY : LengthValue;
		attribute orientation : Real;
	}

	item def Power {
		attribute voltage : Real;
	}

	port def PowerInPort {
		in power : Power;
	}

	port def PowerOutPort {
		out power : Power;
	}

	action def PerformSafetyCheck;
	action def LocateWorkpiece;
	action def PlanTrajectory;
	action def MoveToPickup;
	action def GraspObject;
	action def MoveToDestination;
	action def ReleaseObject;
	action def ReturnToHome;

	part def ManipulatorArm {
		attribute reach : LengthValue = 1.7 [m];
		attribute payloadCapacity : MassValue = 25 [kg];
		attribute repeatability : LengthValue = 0.03 [mm];
		port power : PowerInPort;
		action move;
	}

	part def Gripper {
		attribute maxOpening : LengthValue = 180 [mm];
		attribute maxGripForce : ForceValue = 600 [N];
		action open;
		action close;
		action grasp;
		action release;
	}

	part def VisionSensor {
		port power : PowerInPort;
		action scan {
			out workpiece : Workpiece;
		}
	}

	part def RobotController {
		action processVisionData;
		action planPath;
		action sendCommands;
	}

	part def SafetyController {
		attribute safetyZoneRadius : LengthValue = 1.5 [m];
		action monitorMotion;
		action triggerEmergencyStop;
	}

	part def PowerDistribution {
		attribute inputVoltage : Real = 400;
		port powerIn : PowerInPort;
		port armPower : PowerOutPort;
		port sensorPower : PowerOutPort;
	}

	part def IndustrialRobotCell {
		part powerDist : PowerDistribution;
		part arm : ManipulatorArm {
			part gripper : Gripper;
		}
		part visionSensor : VisionSensor;
		part robotController : RobotController;
		part safetyController : SafetyController;

		connect powerDist.armPower to arm.power;
		connect powerDist.sensorPower to visionSensor.power;

		action performSafetyCheck : PerformSafetyCheck;
		action locateWorkpiece : LocateWorkpiece;
		action planTrajectory : PlanTrajectory;
		action moveToPickup : MoveToPickup;
		action graspObject : GraspObject;
		action moveToDestination : MoveToDestination;
		action releaseObject : ReleaseObject;
		action returnToHome : ReturnToHome;

		exhibit state robotStates {
			entry; then idle;
			state idle;
			transition first idle accept StartCommand then initializing;

			state initializing {
				do performSafetyCheck;
			}
			transition first initializing accept InitializationComplete then ready;

			state ready;
			transition first ready accept TaskCommand then operating;

			state operating {
				entry; then locating;
				state locating {
					do locateWorkpiece;
				}
				transition first locating accept WorkpieceLocated then planning;
				state planning {
					do planTrajectory;
				}
				transition first planning accept TrajectoryReady then movingToPickup;
				state movingToPickup {
					do moveToPickup;
				}
				transition first movingToPickup accept PositionReached then grasping;
				state grasping {
					do graspObject;
				}
				transition first grasping accept ObjectGrasped then movingToDestination;
				state movingToDestination {
					do moveToDestination;
				}
				transition first movingToDestination accept PositionReached then releasing;
				state releasing {
					do releaseObject;
				}
				transition first releasing accept ObjectReleased then returningHome;
				state returningHome {
					do returnToHome;
				}
				transition first returningHome accept HomeReached then ready;
			}

			state paused;
			transition first operating accept PauseCommand then paused;
			transition first ready accept PauseCommand then paused;
			transition first paused accept ResumeCommand then operating;

			state error;
			transition first operating accept FaultSignal then error;
			transition first ready accept FaultSignal then error;
			transition first initializing accept FaultSignal then error;
			transition first paused accept FaultSignal then error;
			transition first error accept ResetCommand then idle;

			state emergencyStop;
			transition first operating accept EmergencyStopSignal then emergencyStop;
			transition first ready accept EmergencyStopSignal then emergencyStop;
			transition first initializing accept EmergencyStopSignal then emergencyStop;
			transition first paused accept EmergencyStopSignal then emergencyStop;
			transition first error accept EmergencyStopSignal then emergencyStop;
			transition first emergencyStop accept ResetCommand then idle;
		}
	}

	requirement def IndustrialRobotCellSpec {
		subject robotCell : IndustrialRobotCell;
		doc /* The industrial robot cell shall autonomously identify, pick up, and move workpieces. */
		constraint { robotCell.arm.reach == 1.7 [m] }
		constraint { robotCell.arm.payloadCapacity <= 25 [kg] }
		constraint { robotCell.arm.repeatability <= 0.03 [mm] }
		constraint { robotCell.arm.gripper.maxOpening <= 180 [mm] }
		constraint { robotCell.arm.gripper.maxGripForce <= 600 [N] }
		constraint { robotCell.powerDist.inputVoltage == 400 }
	}
}
