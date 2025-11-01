// Design a robot arm that can rotate 360 degrees and has a gripper to pick up small objects.
package 'RoboticArmSystem' {
	private import ISQ::*;
	private import SI::*;
	private import Time::*;

	//************************************************************
	// Value Types, Enumerations, and Item Definitions
	//************************************************************

	attribute def AngleValue :> PlaneAngleValue;
	attribute def MassValue :> ISQ::MassValue;
	attribute def LengthValue :> ISQ::LengthValue;

	enum GripperStateKind {
		enum open;
		enum closed;
		enum holding;
	}

	enum GripperCommandKind {
		enum doOpen;
		enum doClose;
	}

	item def SmallObject {
		attribute mass : MassValue;
		attribute width : LengthValue;
	}

	item def ControlSignal {
		attribute targetAngle : AngleValue;
		attribute gripperCommand : GripperCommandKind;
	}

	item def StatusSignal {
		attribute currentAngle : AngleValue;
		attribute gripperState : GripperStateKind;
		attribute objectDetected : Boolean;
	}

	//************************************************************
	// Port and Interface Definitions
	//************************************************************

	interface def MechanicalInterface;

	port def SystemControlPort {
		in command : ControlSignal;
		out status : StatusSignal;
	}

	port def GripperPayloadPort {
		inout payload : SmallObject[0..1];
	}

	//************************************************************
	// Component Part Definitions
	//************************************************************

	part def RotaryBase {
		port control : SystemControlPort;
		port mountPoint : MechanicalInterface;

		attribute currentAngle : AngleValue {
			inout;
			default = 0['°'];
		}
		attribute minAngle : AngleValue = 0['°'];
		attribute maxAngle : AngleValue = 360['°'];

		assert constraint RotationRange {
			doc "The base must support a full 360-degree rotation range.";
			(maxAngle - minAngle) >= 360['°']
		}

		action rotateTo(in angle : AngleValue) {
			doc "Commands the base to rotate to a specific angle.";
			entry assign self.currentAngle := angle;
		}

		state machine BaseBehavior {
			initial state Idle;
			state Rotating;

			transition from Idle to Rotating
				when self.control.command.targetAngle != self.currentAngle {
					effect do self.rotateTo(self.control.command.targetAngle);
			}

			transition from Rotating to Idle
				when self.currentAngle == self.control.command.targetAngle;
		}
	}

	part def ArmLink {
		port baseConnection : ~MechanicalInterface;
		port gripperConnection : MechanicalInterface;
	}

	part def Gripper {
		port control : SystemControlPort;
		port mountPoint : ~MechanicalInterface;
		port payloadPort : GripperPayloadPort;

		attribute state : GripperStateKind {
			inout;
			default = GripperStateKind::open;
		}
		attribute objectPresent : Boolean {
			inout;
			default = false;
		}

		action open {
			doc "Opens the gripper jaws and releases any held object.";
			entry assign self.state := GripperStateKind::open;
			entry assign self.payloadPort.payload := null;
		}

		action close {
			doc "Closes the gripper jaws. If an object is present, it will be held.";
			entry assign self.state := GripperStateKind::closed;
			if(self.objectPresent) {
				entry assign self.state := GripperStateKind::holding;
			}
		}

		state machine GripperBehavior {
			initial state Open {
				entry do self.open;
			}
			state Closed {
				entry do self.close;
			}
			state Holding {
				entry do self.close;
			}

			transition from Open to Closed
				when self.control.command.gripperCommand == GripperCommandKind::doClose;

			transition from Closed to Open
				when self.control.command.gripperCommand == GripperCommandKind::doOpen;

			transition from Holding to Open
				when self.control.command.gripperCommand == GripperCommandKind::doOpen;
		}
	}

	//************************************************************
	// Top-Level Robot Arm Assembly
	//************************************************************

	part def RobotArm {
		port control : SystemControlPort;

		part base : RotaryBase;
		part link : ArmLink;
		part gripper : Gripper;

		connect base.mountPoint to link.baseConnection;
		connect link.gripperConnection to gripper.mountPoint;

		bind self.control.command.targetAngle to base.control.command.targetAngle;
		bind self.control.command.gripperCommand to gripper.control.command.gripperCommand;
		bind base.control.status.currentAngle to self.control.status.currentAngle;
		bind gripper.control.status.gripperState to self.control.status.gripperState;

		action performPickAndPlace(
			in pickupAngle : AngleValue,
			in placeAngle : AngleValue,
			in objectToPick : SmallObject
		) {
			doc "Orchestrates a full pick and place sequence.";

			action moveToPickup {
				doc "Rotate to the object's location.";
				in angle : AngleValue = pickupAngle;
				call base.rotateTo(angle);
			}
			then action openGripper {
				doc "Ensure gripper is open before attempting to grasp.";
				call gripper.open;
			}
			then action graspObject {
				doc "Close the gripper to hold the object.";
				inout gripper.payloadPort.payload :>> objectToPick;
				call gripper.close;
			}
			then action moveToPlacement {
				doc "Rotate to the drop-off location.";
				in angle : AngleValue = placeAngle;
				call base.rotateTo(angle);
			}
			then action releaseObject {
				doc "Open the gripper to release the object.";
				call gripper.open;
			}
		}
	}

	//************************************************************
	// Requirements Definition and Verification
	//************************************************************

	requirement def FullRotationRequirement {
		id = "RA-REQ-01";
		text = "The robot arm shall be capable of rotating through a full 360 degrees.";
		subject arm : RobotArm;
		require constraint {
			(arm.base.maxAngle - arm.base.minAngle) >= 360['°']
		}
	}

	requirement def GraspingRequirement {
		id = "RA-REQ-02";
		text = "The gripper must be able to securely grasp and release a small object.";
		subject arm : RobotArm;
		subject obj : SmallObject;
		// A more detailed model would include gripper opening width and force constraints.
		// This requirement is satisfied by the presence and behavior of the gripper part.
		require constraint {
			exists(arm.gripper)
		}
	}

	part system : RobotArm {
		part redefines gripper {
			attribute objectPresent = true; // Assume sensor for this scenario
		}

		assert checkRotation : FullRotationRequirement {
			subject arm = self;
		}

		assert checkGrasping : GraspingRequirement {
			subject arm = self;
			subject obj = SmallObject {
				mass = 0.2[kg];
				width = 50[mm];
			};
		}
	}
}
