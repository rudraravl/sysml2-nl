package BangBangRobotSystem {
	private import ISQ::*;
	private import ScalarValues::*;

	attribute def PositionValue :> ISQ::LengthValue;
	attribute def VelocityValue :> ISQ::SpeedValue;
	attribute def ForceValue :> ISQ::ForceValue;
	attribute def MassValue :> ISQ::MassValue;
	attribute def TimeValue :> ISQ::TimeValue;

	item def TargetPosition {
		attribute position : PositionValue;
	}
	item def MeasuredPosition {
		attribute position : PositionValue;
		attribute velocity : VelocityValue;
	}
	enum def CommandType {
		forward;
		reverse;
		off;
	}
	item def ControlCommand {
		attribute command : CommandType;
	}
	item def ActuatorForce {
		attribute force : ForceValue;
	}

	port def TargetInPort {
		in targetPosition : TargetPosition;
	}
	port def PositionOutPort {
		out measuredPosition : MeasuredPosition;
	}
	port def PositionInPort {
		in measuredPosition : MeasuredPosition;
	}
	port def CommandOutPort {
		out controlCommand : ControlCommand;
	}
	port def CommandInPort {
		in controlCommand : ControlCommand;
	}
	port def ForceOutPort {
		out actuatorForce : ActuatorForce;
	}
	port def ForceInPort {
		in actuatorForce : ActuatorForce;
	}

	part def PositionSensor {
		port positionOut : PositionOutPort;
	}
	part def BangBangController {
		port targetIn : TargetInPort;
		port positionIn : PositionInPort;
		port commandOut : CommandOutPort;
		attribute deadband : PositionValue = 0.05;
	}
	part def LinearActuator {
		port commandIn : CommandInPort;
		port forceOut : ForceOutPort;
		attribute maxForce : ForceValue = 100.0;
	}
	part def RoboticManipulator {
		port forceIn : ForceInPort;
	}
	part def TargetObject {
		attribute mass : MassValue = 2.0;
		attribute position : PositionValue;
		attribute velocity : VelocityValue;
	}

	state def BangBangRobotStates {
		state initializing;
		state standby;
		state executing;
		state holding;
		state safeShutdown;
		transition init_to_standby first initializing then standby;
		transition standby_to_executing first standby then executing;
		transition executing_to_holding first executing then holding;
		transition init_to_safe first initializing then safeShutdown;
		transition standby_to_safe first standby then safeShutdown;
		transition executing_to_safe first executing then safeShutdown;
		transition holding_to_safe first holding then safeShutdown;
	}

	part def BangBangRobot {
		port targetIn : TargetInPort;
		part positionSensor : PositionSensor;
		part controller : BangBangController;
		part actuator : LinearActuator;
		part manipulator : RoboticManipulator;
		part targetObject : TargetObject;

		bind targetIn = controller.targetIn;

		flow positionFlow of MeasuredPosition 
			from positionSensor.positionOut.measuredPosition to controller.positionIn.measuredPosition;
		flow commandFlow of ControlCommand 
			from controller.commandOut.controlCommand to actuator.commandIn.controlCommand;
		flow forceFlow of ActuatorForce 
			from actuator.forceOut.actuatorForce to manipulator.forceIn.actuatorForce;

		state machine robotStates : BangBangRobotStates;
	}

	requirement def PositioningPrecisionRequirement {
		doc "The system must position the object within a specified tolerance of the target."
		attribute precision : PositionValue = 0.05;
	}
	requirement def ForceCapabilityRequirement {
		doc "The actuator must be capable of providing a minimum maximum force."
		attribute minMaxForce : ForceValue = 50.0;
	}
	requirement def PayloadCapacityRequirement {
		doc "The manipulator must be able to handle a minimum payload mass."
		attribute minPayload : MassValue = 1.0;
	}
	requirement def ResponseTimeRequirement {
		doc "The system must respond to a command within a specified time."
		attribute maxResponseTime : TimeValue = 0.1;
	}

	part def BangBangRobotSystem {
		part robot : BangBangRobot {
			satisfy PositioningPrecisionRequirement;
			satisfy ForceCapabilityRequirement;
			satisfy PayloadCapacityRequirement;
			satisfy ResponseTimeRequirement;
		}
	}
}
