package 'High Precision Positioning System' {
	private import ISQ::*;
	private import ScalarValues::*;

	item def TargetPosition {
		attribute x : ISQ::length;
		attribute y : ISQ::length;
		attribute z : ISQ::length;
	}

	item def ActualPosition {
		attribute x : ISQ::length;
		attribute y : ISQ::length;
		attribute z : ISQ::length;
	}

	item def DriveSignal {
		attribute magnitude : ISQ::length;
	}

	item def Power;

	part def MotionController {
		attribute tolerance : ISQ::length = 0.001 [mm];
		port commandPort {
			in target : TargetPosition;
		}
		port feedbackPort {
			in actual : ActualPosition;
		}
		port xDrivePort {
			out xDrive : DriveSignal;
		}
		port yDrivePort {
			out yDrive : DriveSignal;
		}
		port zDrivePort {
			out zDrive : DriveSignal;
		}
		port powerPort {
			in power : Power;
		}

		state machine def ControllerStates {
			state Idle;
			state Moving;
			state PositionReached;
			state Error;

			transition from Idle to Moving;
			transition from Moving to PositionReached;
			transition from Moving to Error;
			transition from PositionReached to Idle;
			transition from Error to Idle;
		}

		action def closedLoopControl {
			in target : TargetPosition;
			in actual : ActualPosition;
			out xDrive : DriveSignal;
			out yDrive : DriveSignal;
			out zDrive : DriveSignal;

			attribute errorX : ISQ::length = target.x - actual.x;
			attribute errorY : ISQ::length = target.y - actual.y;
			attribute errorZ : ISQ::length = target.z - actual.z;

			assign xDrive.magnitude := errorX;
			assign yDrive.magnitude := errorY;
			assign zDrive.magnitude := errorZ;
		}
	}

	part def LinearActuator {
		attribute axis : String;
		port drivePort {
			in drive : DriveSignal;
		}
		port powerPort {
			in power : Power;
		}
	}

	part def ActuatorAssembly {
		part xActuator : LinearActuator {
			attribute axis = "X";
		}
		part yActuator : LinearActuator {
			attribute axis = "Y";
		}
		part zActuator : LinearActuator {
			attribute axis = "Z";
		}
	}

	part def Probe {
		attribute tipDiameter : ISQ::length = 1 [mm];
	}

	part def PositionSensor {
		port feedbackPort {
			out actual : ActualPosition;
		}
		port powerPort {
			in power : Power;
		}
	}

	part def PowerSupply {
		port powerPort {
			out power : Power;
		}
	}

	part def PositioningSystem {
		attribute workspaceX : ISQ::length = 500 [mm];
		attribute workspaceY : ISQ::length = 500 [mm];
		attribute workspaceZ : ISQ::length = 300 [mm];

		part controller : MotionController;
		part actuators : ActuatorAssembly;
		part probe : Probe;
		part sensor : PositionSensor;
		part powerSupply : PowerSupply;

		flow powerFlow1 of Power from powerSupply.powerPort.power to controller.powerPort.power;
		flow powerFlow2 of Power from powerSupply.powerPort.power to sensor.powerPort.power;
		flow powerFlow3 of Power from powerSupply.powerPort.power to actuators.xActuator.powerPort.power;
		flow powerFlow4 of Power from powerSupply.powerPort.power to actuators.yActuator.powerPort.power;
		flow powerFlow5 of Power from powerSupply.powerPort.power to actuators.zActuator.powerPort.power;

		flow feedbackFlow of ActualPosition from sensor.feedbackPort.actual to controller.feedbackPort.actual;

		flow driveFlowX of DriveSignal from controller.xDrivePort.xDrive to actuators.xActuator.drivePort.drive;
		flow driveFlowY of DriveSignal from controller.yDrivePort.yDrive to actuators.yActuator.drivePort.drive;
		flow driveFlowZ of DriveSignal from controller.zDrivePort.zDrive to actuators.zActuator.drivePort.drive;
	}

	requirement def PositioningAccuracy {
		subject system : PositioningSystem;
		doc :>> "The system shall position the probe to the target coordinate within a tolerance of 0.001 mm.";
	}

	requirement def WorkspaceDimensions {
		subject system : PositioningSystem;
		doc :>> "The system workspace shall be 500mm x 500mm x 300mm.";
		attribute xDimension : ISQ::length = 500 [mm];
		attribute yDimension : ISQ::length = 500 [mm];
		attribute zDimension : ISQ::length = 300 [mm];
	}

	requirement def ProbeTipDiameter {
		subject probe : Probe;
		doc :>> "The contact probe tip diameter shall be 1mm.";
		attribute tipDiameter : ISQ::length = 1 [mm];
	}

	satisfy PositioningAccuracy by PositioningSystem;
	satisfy WorkspaceDimensions by PositioningSystem;
	satisfy ProbeTipDiameter by Probe;
}
