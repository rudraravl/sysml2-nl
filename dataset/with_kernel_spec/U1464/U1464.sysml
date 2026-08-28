package PeaucellierLipkinLinkage {
	private import ScalarValues::Real;
	private import ScalarValues::String;
	private import ScalarValues::Boolean;

	unit def mm;
	unit def deg;

	attribute def Length :> Real;
	attribute def Angle :> Real;

	item def Force;
	item def Torque;
	item def KinematicState;

	port def PivotingJoint {
		in item appliedForce : Force;
		in item appliedTorque : Torque;
		out item jointState : KinematicState;
	}

	port def RotaryInputPort {
		out item inputAngle : Angle;
	}

	port def LinearOutputPort {
		out item tracerPosition : Length;
	}

	part def RigidBar {
		attribute length : Length;
		port endA : PivotingJoint;
		port endB : PivotingJoint;
	}

	part def BaseFrame {
		port fixedPivotO : PivotingJoint;
		port fixedPivotP : PivotingJoint;
		attribute baseSeparation : Length;
	}

	part def InputCrank :> RigidBar {
		doc
		/*
		 * The driving link that provides continuous rotary motion.
		 */
		port rotaryDrive : RotaryInputPort;
	}

	part def RhombusBar :> RigidBar {
		doc
		/*
		 * A rigid bar of equal length used to construct the rhombus assembly.
		 */
	}

	part def CouplerBar :> RigidBar {
		doc
		/*
		 * A rigid bar connecting the rhombus to the tracer point.
		 */
	}

	part def TracerPoint {
		port tracerJoint : PivotingJoint;
		port output : LinearOutputPort;
		attribute position : Length;
	}

	part def RhombusAssembly {
		port vertex1 : PivotingJoint;
		port vertex2 : PivotingJoint;
		port vertex3 : PivotingJoint;
		port vertex4 : PivotingJoint;
		attribute sideLength : Length;

		part bar12 : RhombusBar;
		part bar23 : RhombusBar;
		part bar34 : RhombusBar;
		part bar41 : RhombusBar;

		bind bar12.length = sideLength;
		bind bar23.length = sideLength;
		bind bar34.length = sideLength;
		bind bar41.length = sideLength;

		connect bar12.endA to vertex1;
		connect bar12.endB to vertex2;
		connect bar23.endA to vertex2;
		connect bar23.endB to vertex3;
		connect bar34.endA to vertex3;
		connect bar34.endB to vertex4;
		connect bar41.endA to vertex4;
		connect bar41.endB to vertex1;
	}

	requirement def StraightLineMotionRequirement {
		doc
		/*
		 * The tracer point shall move along a mathematically perfect straight line
		 * for a full rotation of the input crank.
		 */
	}

	requirement def NoSlidingContactsRequirement {
		doc
		/*
		 * The mechanism shall use only revolute joints and no sliding contacts
		 * to minimize friction and wear.
		 */
	}

	requirement def RotaryToLinearConversionRequirement {
		doc
		/*
		 * The mechanism shall convert continuous rotary motion of the input crank
		 * into straight-line motion of the tracer point.
		 */
	}

	action def ConvertRotaryToLinear {
		doc
		/*
		 * Converts the input crank's rotation into a linear displacement at the tracer.
		 */
		in inputRotation : Angle;
		out outputDisplacement : Length;
	}

	action def ApplyTorque {
		in torqueValue : Torque;
		out command : String;
	}

	action def MonitorLinearPath {
		in currentPosition : Length;
		out deviation : Length;
	}

	state machine def OperationState {
		state Idle;
		state CrankRotating;
		state TracingStraightLine;
		transition Idle -> CrankRotating;
		transition CrankRotating -> TracingStraightLine;
		transition TracingStraightLine -> CrankRotating;
		transition CrankRotating -> Idle;
	}

	part def PeaucellierLipkinMechanism {
		doc
		/*
		 * The complete Peaucellier-Lipkin linkage mechanism that converts
		 * continuous rotary motion into a perfectly straight line.
		 */

		part base : BaseFrame;
		part crank : InputCrank;
		part rhombus : RhombusAssembly;
		part coupler1 : CouplerBar;
		part coupler2 : CouplerBar;
		part tracer : TracerPoint;

		attribute crankLength : Length = 100.0;
		attribute rhombusSideLength : Length = 150.0;
		attribute couplerLength : Length = 200.0;
		attribute baseSeparation : Length = 160.0;

		bind crank.length = crankLength;
		bind rhombus.sideLength = rhombusSideLength;
		bind coupler1.length = couplerLength;
		bind coupler2.length = couplerLength;
		bind base.baseSeparation = baseSeparation;

		connect crank.endA to base.fixedPivotO;
		connect crank.endB to rhombus.vertex1;
		connect rhombus.vertex3 to base.fixedPivotP;
		connect coupler1.endA to rhombus.vertex2;
		connect coupler1.endB to tracer.tracerJoint;
		connect coupler2.endA to rhombus.vertex4;
		connect coupler2.endB to tracer.tracerJoint;

		assert constraint equalCouplerLengths {
			doc
			/*
			 * The two coupler bars must be of equal length for proper operation.
			 */
			coupler1.length == coupler2.length
		}

		assert constraint equalRhombusSides {
			doc
			/*
			 * All four bars of the rhombus must be of equal length.
			 */
			rhombus.bar12.length == rhombus.bar23.length
		}

		requirement :>> StraightLineMotionRequirement;
		requirement :>> NoSlidingContactsRequirement;
		requirement :>> RotaryToLinearConversionRequirement;

		action convertMotion : ConvertRotaryToLinear;
		action applyTorque : ApplyTorque;
		action monitorLinearPath : MonitorLinearPath;

		state machine operationState : OperationState;
	}

	part linkage : PeaucellierLipkinMechanism;

	satisfy StraightLineMotionRequirement by linkage;
	satisfy NoSlidingContactsRequirement by linkage;
	satisfy RotaryToLinearConversionRequirement by linkage;
}
