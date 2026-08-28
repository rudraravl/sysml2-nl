package 'Four-Bar Linkage System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	attribute def Efficiency :> Real;

	port def RevoluteJoint {
		attribute torque : TorqueValue;
		attribute angle : ISQ::AngleValue;
		attribute angularVelocity : AngularVelocityValue;
	}

	port def LinearOutputPort {
		attribute force : ForceValue;
		attribute displacement : LengthValue;
		attribute velocity : ISQ::VelocityValue;
	}

	part def GroundFrame {
		attribute pivotDistance : LengthValue;
		port groundPivot1 : RevoluteJoint;
		port groundPivot2 : RevoluteJoint;
	}

	part def Link {
		attribute length : LengthValue;
		port jointA : RevoluteJoint;
		port jointB : RevoluteJoint;
	}

	part def Crank :> Link {
		attribute initialAngle : ISQ::AngleValue;
	}

	part def Coupler :> Link;

	part def Rocker :> Link {
		port outputPoint : RevoluteJoint;
	}

	part def RotaryActuator {
		attribute ratedTorque : TorqueValue;
		attribute ratedSpeed : AngularVelocityValue;
		port outputDrive : RevoluteJoint;
	}

	part def OutputMechanism {
		attribute strokeLength : LengthValue;
		port inputJoint : RevoluteJoint;
		port linearOutput : LinearOutputPort;
	}

	item def TorqueTransfer {
		attribute magnitude : TorqueValue;
	}

	item def MotionTransfer {
		attribute angle : ISQ::AngleValue;
		attribute angularVelocity : AngularVelocityValue;
	}

	action def GenerateTorque {
		out torque : TorqueValue;
		out speed : AngularVelocityValue;
	}

	action def Oscillate {
		in torque : TorqueValue;
		in speed : AngularVelocityValue;
		out angle : ISQ::AngleValue;
		out angularVelocity : AngularVelocityValue;
	}

	action def TranslateOutput {
		in angle : ISQ::AngleValue;
		in angularVelocity : AngularVelocityValue;
		out force : ForceValue;
		out stroke : LengthValue;
		out velocity : ISQ::VelocityValue;
	}

	action def OperateLinkage {
		action generateTorque : GenerateTorque;
		action oscillateRocker : Oscillate;
		action translateOutput : TranslateOutput;
		flow torqueFlow : TorqueTransfer from generateTorque to oscillateRocker;
		flow motionFlow : MotionTransfer from oscillateRocker to translateOutput;
	}

	state machine def LinkageOperation {
		state Idle;
		state Rotating;
		state Oscillating;
		state Translating;
		transition start from Idle to Rotating { accept powerOn; }
		transition engage from Rotating to Oscillating { accept crankEngaged; }
		transition convert from Oscillating to Translating { accept rockerMoving; }
		transition stop from Translating to Idle { accept powerOff; }
	}

	part def FourBarLinkageSystem {
		attribute totalEfficiency : Efficiency;
		attribute actualStroke : LengthValue;

		part ground : GroundFrame;
		part motor : RotaryActuator;
		part crank : Crank;
		part coupler : Coupler;
		part rocker : Rocker;
		part output : OutputMechanism;

		connect motor.outputDrive to crank.jointA;
		connect crank.jointA to ground.groundPivot1;
		connect crank.jointB to coupler.jointA;
		connect coupler.jointB to rocker.jointA;
		connect rocker.jointB to ground.groundPivot2;
		connect rocker.outputPoint to output.inputJoint;

		perform operateLinkage : OperateLinkage;
		exhibit linkageOperation : LinkageOperation;
	}

	requirement def <'R1'> OutputStrokeRequirement {
		doc /* The output stroke shall be between 5 cm and 40 cm. */
		subject system : FourBarLinkageSystem;
		attribute minStroke : LengthValue = 0.05 [m];
		attribute maxStroke : LengthValue = 0.40 [m];
		require constraint { system.actualStroke >= minStroke and system.actualStroke <= maxStroke }
	}

	requirement def <'R2'> SmoothOperationRequirement {
		doc /* The system shall operate smoothly without jamming. */
		subject system : FourBarLinkageSystem;
		attribute jammingStatus : Boolean = false;
		require constraint { jammingStatus == false }
	}

	requirement def <'R3'> EfficiencyRequirement {
		doc /* The system shall convert at least 82% of input motor torque into usable linear force. */
		subject system : FourBarLinkageSystem;
		attribute minEfficiency : Efficiency = 0.82;
		require constraint { system.totalEfficiency >= minEfficiency }
	}

	part fourBarSystem : FourBarLinkageSystem;
}
