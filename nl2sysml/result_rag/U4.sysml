// Design a robot arm that can rotate 360 degrees and has a gripper to pick up small objects.
package RobotArmSystem {
	private import ISQ::*;
	private import SI::*;

	/******************************************************************
	 * Value and Item Types
	 ******************************************************************/
	value def AngleValue :> PlaneAngleValue;
	value def AngularVelocityValue :> AngularVelocity;
	value def TorqueValue :> Torque;

	item def SmallObject {
		attribute mass : MassValue;
	}

	enum GripperState {
		open,
		closed
	}

	/******************************************************************
	 * Requirement Definitions
	 ******************************************************************/
	requirement def FullRotationRequirement {
		doc "The robot arm must be capable of continuous 360-degree rotation about its base."
		subject arm : RobotArm;
		assert constraint { arm.armAssembly.rotationRange >= 360['°'] }
	}

	requirement def GraspingRequirement {
		doc "The robot arm's gripper must be able to securely pick up and hold small objects."
		subject arm : RobotArm;
		subject obj : SmallObject;
		assert constraint {
			exists(g in arm.armAssembly.gripper |
				   g.state == GripperState::closed implies g.isHoldingObject)
		}
	}

	/******************************************************************
	 * Interface and Behavior Definitions
	 ******************************************************************/
	interface def MotionCommands {
		inout command : CommandSignal;
	}

	item def CommandSignal {
		angle : AngleValue;
		state : GripperState;
	}

	action def RotateArm {
		in targetAngle : AngleValue;
		in motor : Motor;
		out finalAngle : AngleValue;
	}

	action def SetGripper {
		in targetState : GripperState;
		in gripper : Gripper;
	}

	state machine GripperStateMachine {
		initial state Open;
		state Open;
		state Closed;

		transition from Open to Closed on close;
		transition from Closed to Open on open;
	}

	/******************************************************************
	 * Component Part Definitions
	 ******************************************************************/
	part def Motor {
		attribute maxTorque : TorqueValue = 50 [N*m];
		attribute currentSpeed : AngularVelocityValue;
	}

	part def Finger;

	part def Gripper {
		port motionCmd;
		part finger1 : Finger;
		part finger2 : Finger;
		attribute isHoldingObject : Boolean = false;
		exhibit state : GripperStateMachine;

		action SetGripper {
			in targetState : GripperState;
			accept close when targetState == GripperState::closed & state == GripperStateMachine::Open {
				isHoldingObject = true;
			}
			accept open when targetState == GripperState::open & state == GripperStateMachine::Closed {
				isHoldingObject = false;
			}
		}
	}

	part def Base {
		port rotationCmd;
		part rotationMotor : Motor;
		attribute currentAngle : AngleValue = 0.0 ['°'];

		action RotateArm {
			in targetAngle : AngleValue;
			out finalAngle : AngleValue;
			// Action body would control the motor
			finalAngle = targetAngle;
			currentAngle = targetAngle;
		}
	}

	part def RotatingArm {
		port gripperCmd;
		part gripper : Gripper;
		attribute rotationRange : AngleValue = 360 ['°'];
	}

	part def ControlUnit {
		port armControl : MotionCommands;
		action issueCommands {
			out armControl.command;
		}
	}

	/******************************************************************
	 * Top-Level System Assembly
	 ******************************************************************/
	part def RobotArm {
		satisfy FullRotationRequirement { redefines arm = self; }
		satisfy GraspingRequirement { redefines arm = self; }

		part controlUnit : ControlUnit;
		part base : Base;
		part armAssembly : RotatingArm;

		port controlIn : MotionCommands;

		connection from controlUnit.armControl to controlIn;
		connection from controlIn to base.rotationCmd;
		connection from controlIn to armAssembly.gripperCmd;

		action operate {
			do controlUnit.issueCommands {
				while(true) {
					// Example sequence
					// 1. Rotate to 90 degrees
					armControl.command.angle = 90 ['°'];
					armControl.command.state = GripperState::open;
					perform base.RotateArm(armControl.command.angle);

					// 2. Close gripper
					armControl.command.state = GripperState::closed;
					perform armAssembly.gripper.SetGripper(armControl.command.state);

					// 3. Rotate to 0 degrees
					armControl.command.angle = 0 ['°'];
					perform base.RotateArm(armControl.command.angle);

					// 4. Open gripper
					armControl.command.state = GripperState::open;
					perform armAssembly.gripper.SetGripper(armControl.command.state);
				}
			}
		}
	}
}
}
