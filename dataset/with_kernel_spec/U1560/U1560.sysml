package MobileServicingSystem {
	private import ISQ::*;
	private import ScalarValues::*;

	value def AngleValue :> Real;

	item def MissionCommand;
	item def EmergencySignal;
	item def PowerSignal;
	item def MoveCommand;
	item def LatchCommand;
	item def UnlatchCommand;
	item def DetectCommand;
	item def BaseAtWorksite;
	item def TargetLocked;
	item def TaskComplete;
	item def HomeReached;
	item def SystemSecured;
	item def FaultDetected;
	item def FaultCleared;
	item def AtTarget;
	item def AtPose;
	item def LatchedComplete;
	item def UnlatchedComplete;
	item def TargetFound;

	item def TargetData {
		attribute position : LengthValue;
		attribute orientation : AngleValue;
	}
	item def HealthStatus {
		attribute healthy : Boolean;
		attribute temperature : TemperatureValue;
	}

	action def MoveTo { in target : LengthValue; }
	action def HoldPosition;
	action def MoveJoints { in targetPose : TargetData; }
	action def LatchAction { in targetFixture : TargetData; }
	action def UnlatchAction;
	action def DetectTarget { out target : TargetData; }
	action def PlanTrajectory;
	action def ProcessVision { in targetData : TargetData; }
	action def MonitorHealth;
	action def CoordinateServicing;
	action def RegulatePower;

	port def PowerPort { in pwr : PowerSignal; }
	port def CommandPort { in cmd : MissionCommand; }
	port def TelemetryPort { out status : HealthStatus; }
	port def VisionPort { out targetData : TargetData; }

	part def MobileBase {
		in port powerIn : PowerPort;
		in port commandIn : CommandPort;
		out port telemetryOut : TelemetryPort;
		attribute currentLocation : LengthValue;
		attribute targetLocation : LengthValue;
		exhibit state baseStates {
			entry; then idle;
			state idle;
			accept MoveCommand then moving;
			state moving {
				do MoveTo;
			}
			accept AtTarget then holding;
			state holding {
				do HoldPosition;
			}
			accept EmergencySignal then safe;
			state safe;
		}
	}

	part def ManipulatorArm {
		in port powerIn : PowerPort;
		in port commandIn : CommandPort;
		out port telemetryOut : TelemetryPort;
		attribute jointCount : Integer = 7;
		attribute maxReach : LengthValue = 17 [m];
		attribute maxPayloadMass : MassValue = 100000 [kg];
		attribute jointAngles : AngleValue[7];
		exhibit state armStates {
			entry; then idle;
			state idle;
			accept MoveCommand then moving;
			state moving {
				do MoveJoints;
			}
			accept AtPose then ready;
			state ready;
			accept EmergencySignal then safe;
			state safe;
		}
	}

	part def LatchingEndEffector {
		in port powerIn : PowerPort;
		in port commandIn : CommandPort;
		out port telemetryOut : TelemetryPort;
		attribute latchingForce : ForceValue;
		attribute maxLatchingForce : ForceValue = 100000 [N];
		exhibit state effectorStates {
			entry; then unlatched;
			state unlatched;
			accept LatchCommand then latching;
			state latching {
				do LatchAction;
			}
			accept LatchedComplete then latched;
			state latched;
			accept UnlatchCommand then unlatching;
			state unlatching {
				do UnlatchAction;
			}
			accept UnlatchedComplete then unlatched;
			accept EmergencySignal then safe;
			state safe;
		}
	}

	part def VisionSensor {
		in port powerIn : PowerPort;
		out port visionOut : VisionPort;
		out port telemetryOut : TelemetryPort;
		attribute resolution : String = "1920x1080";
		exhibit state sensorStates {
			entry; then idle;
			state idle;
			accept DetectCommand then detecting;
			state detecting {
				do DetectTarget;
			}
			accept TargetFound then idle;
		}
	}

	part def ControlComputer {
		in port powerIn : PowerPort;
		in port missionCommandIn : CommandPort;
		out port baseCommandOut : CommandPort;
		out port armCommandOut : CommandPort;
		out port endEffectorCommandOut : CommandPort;
		in port visionDataIn : VisionPort;
		in port baseTelemetryIn : TelemetryPort;
		in port armTelemetryIn : TelemetryPort;
		in port effectorTelemetryIn : TelemetryPort;
		in port sensorTelemetryIn : TelemetryPort;
		attribute missionPlan : String;
	}

	part def PowerDistributionUnit {
		in port primaryPowerIn : PowerPort;
		out port basePowerOut : PowerPort;
		out port armPowerOut : PowerPort;
		out port endEffectorPowerOut : PowerPort;
		out port sensorPowerOut : PowerPort;
		out port computerPowerOut : PowerPort;
	}

	state def MSSMissionStates parallel {
		state operationalStates {
			entry; then Standby;
			state Standby;
			accept MissionCommand then Active;
			state Active {
				entry; then Positioning;
				state Positioning;
				accept BaseAtWorksite then Acquiring;
				state Acquiring;
				accept TargetLocked then Servicing;
				state Servicing;
				accept TaskComplete then Returning;
				state Returning;
				accept HomeReached then Standby;
			}
			accept EmergencySignal then Safing;
			state Safing;
			accept SystemSecured then Standby;
		}
		state healthStates {
			entry; then Normal;
			state Normal {
				do MonitorHealth;
			}
			accept FaultDetected then Degraded;
			state Degraded {
				do MonitorHealth;
			}
			accept FaultCleared then Normal;
		}
	}

	part def MSS {
		part mobileBase : MobileBase;
		part manipulatorArm : ManipulatorArm;
		part latchingEndEffector : LatchingEndEffector;
		part visionSensor : VisionSensor;
		part controlComputer : ControlComputer;
		part powerDistributionUnit : PowerDistributionUnit;

		connection powerToBase connect powerDistributionUnit.basePowerOut to mobileBase.powerIn;
		connection powerToArm connect powerDistributionUnit.armPowerOut to manipulatorArm.powerIn;
		connection powerToEndEffector connect powerDistributionUnit.endEffectorPowerOut to latchingEndEffector.powerIn;
		connection powerToSensor connect powerDistributionUnit.sensorPowerOut to visionSensor.powerIn;
		connection powerToComputer connect powerDistributionUnit.computerPowerOut to controlComputer.powerIn;

		connection baseCommand connect controlComputer.baseCommandOut to mobileBase.commandIn;
		connection armCommand connect controlComputer.armCommandOut to manipulatorArm.commandIn;
		connection endEffectorCommand connect controlComputer.endEffectorCommandOut to latchingEndEffector.commandIn;

		flow visionDataFlow of TargetData from visionSensor.visionOut to controlComputer.visionDataIn;

		flow baseTelemetryFlow of HealthStatus from mobileBase.telemetryOut to controlComputer.baseTelemetryIn;
		flow armTelemetryFlow of HealthStatus from manipulatorArm.telemetryOut to controlComputer.armTelemetryIn;
		flow effectorTelemetryFlow of HealthStatus from latchingEndEffector.telemetryOut to controlComputer.effectorTelemetryIn;
		flow sensorTelemetryFlow of HealthStatus from visionSensor.telemetryOut to controlComputer.sensorTelemetryIn;

		exhibit state missionStates : MSSMissionStates;
	}

	requirement def ReachCapability {
		doc /* The Manipulator Arm shall have a reach of at least 17 meters. */
		subject arm : ManipulatorArm;
	}

	requirement def PayloadCapability {
		doc /* The Manipulator Arm shall handle payloads weighing over 100 metric tons. */
		subject arm : ManipulatorArm;
	}

	requirement def JointFlexibility {
		doc /* The Manipulator Arm shall have seven joints for flexibility. */
		subject arm : ManipulatorArm;
	}

	requirement def EmergencySafing {
		doc /* The system shall transition to Safing mode upon receiving an EmergencySignal. */
		subject mss : MSS;
	}

	requirement def LatchingForceCapability {
		doc /* The Latching End Effector shall apply controlled force up to 100000 N. */
		subject ee : LatchingEndEffector;
	}
}
