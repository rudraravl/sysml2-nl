package 'Robotic Juggling System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	// Value types with units
	attribute def BallCount :> Integer;
	attribute def SuccessRate :> Real;
	attribute def ThrowHeight :> LengthValue;
	attribute def ThrowVelocity :> SpeedValue;
	attribute def JointAngle :> Real;
	attribute def CycleTime :> TimeValue;
	attribute def GripForce :> ForceValue;

	// Item definitions
	item def JugglingBall {
		attribute mass : MassValue = 0.15[SI::kg];
		attribute diameter : LengthValue = 0.065[SI::m];
	}

	// Enumeration types
	enum def OperationalMode {
		enum idle;
		enum initializing;
		enum calibrating;
		enum juggling;
		enum recovering;
		enum shutdown;
	}

	enum def BallStatus {
		enum inLeftHand;
		enum inRightHand;
		enum inFlight;
		enum caught;
		enum dropped;
	}

	// Port definitions
	port def VisionDataPort {
		out trackingQuality : SuccessRate;
	}

	port def ArmCommandPort {
		in targetVelocity : SpeedValue;
		out executionStatus : Boolean;
	}

	port def GripperPort {
		in gripCommand : Boolean;
		out isHolding : Boolean;
	}

	port def ControlDataPort {
		out gripperCommands : Boolean;
	}

	// Action definitions
	action def InitializeRobot {
		in ballCount : BallCount;
		out initialized : Boolean;
	}

	action def CalibrateVisionSystem {
		out calibrated : Boolean;
		out accuracy : SuccessRate;
	}

	action def TrackBalls {
		in expectedBalls : BallCount;
	}

	action def ComputeTrajectory {
		out interceptTime : TimeValue;
	}

	action def PlanThrow {
		in targetHeight : ThrowHeight;
		in currentBalls : BallCount;
		out throwVelocity : ThrowVelocity;
		out throwAngle : JointAngle;
	}

	action def MoveArmToPosition {
		out reached : Boolean;
	}

	action def CatchBall {
		out caughtBall : JugglingBall;
		out success : Boolean;
	}

	action def ThrowBall {
		in ball : JugglingBall;
		in throwHeight : ThrowHeight;
		in throwVelocity : ThrowVelocity;
		out releasedBall : JugglingBall;
	}

	action def RecoverFromError {
		in errorType : BallStatus;
		out recovered : Boolean;
	}

	// State machine for juggling behavior
	state def JugglingBehavior {
		entry; then idle;

		state idle;
		accept at idle then initializing;

		state initializing {
			do action init : InitializeRobot;
		}
		accept init.initialized then calibrating;

		state calibrating {
			do action calibrate : CalibrateVisionSystem;
		}
		accept calibrate.calibrated then ready;

		state ready;
		accept at ready then activeJuggling;

		state activeJuggling {
			state tracking {
				do action trackBalls : TrackBalls;
			}

			state catching {
				do action catchBall : CatchBall;
			}

			state throwing {
				do action throwBall : ThrowBall;
			}

			first tracking;
			transition tracking to catching;
			transition catching to throwing
				if catchBall.success == true;
			transition catching to recovering
				if catchBall.success == false;
			transition throwing to tracking;
		}

		state recovering {
			do action recover : RecoverFromError;
		}

		transition recovering to activeJuggling
			if recover.recovered == true;
		transition recovering to shutdown
			if recover.recovered == false;

		accept at activeJuggling then shutdown;

		state shutdown;
	}

	// Part definitions
	part def VisionSystem {
		attribute frameRate : Real = 120.0;
		attribute trackingAccuracy : SuccessRate = 0.98;
		port visionOut : VisionDataPort;

		perform action trackBalls : TrackBalls;
	}

	part def ControlProcessor {
		attribute processingCycle : CycleTime = 0.008[SI::s];
		port visionIn : ~VisionDataPort;
		port leftArmOut : ControlDataPort;
		port rightArmOut : ControlDataPort;

		perform action computeTrajectory : ComputeTrajectory;
		perform action planThrow : PlanThrow;
	}

	part def RoboticArm {
		attribute maxReach : LengthValue = 0.85[SI::m];
		attribute maxSpeed : SpeedValue = 3.2[SI::'m/s'];
		attribute jointCount : Integer = 6;
		port commandIn : ~ArmCommandPort;
		port gripperPort : GripperPort;

		part gripper : Gripper;

		perform action moveToPosition : MoveArmToPosition;
		perform action executeCatch : CatchBall;
		perform action executeThrow : ThrowBall;
	}

	part def Gripper {
		attribute maxForce : GripForce = 8.0[SI::N];
		attribute isHoldingBall : Boolean = false;
		port gripControl : ~GripperPort;

		action grasp {
			in ball : JugglingBall;
			out held : Boolean;
		}

		action release {
			in velocity : ThrowVelocity;
			out ball : JugglingBall;
		}
	}

	part def PowerSupply {
		attribute voltage : Real = 24.0;
		attribute capacity : Real = 5000.0;
	}

	// Main juggling robot part
	part def JugglingRobot {
		attribute operatingMode : OperationalMode;
		attribute numberOfBalls : BallCount = 3;
		attribute targetHeight : ThrowHeight = 1.2[SI::m];
		attribute performanceScore : SuccessRate;

		part visionSystem : VisionSystem;
		part controller : ControlProcessor;
		part leftArm : RoboticArm;
		part rightArm : RoboticArm;
		part powerSupply : PowerSupply;

		item balls : JugglingBall[3];

		connect visionSystem.visionOut to controller.visionIn;
		connect controller.leftArmOut to leftArm.commandIn;
		connect controller.rightArmOut to rightArm.commandIn;

		state behavior : JugglingBehavior;

		perform action executeJugglingTask : PerformJugglingTask;
	}

	// Primary task action
	action def PerformJugglingTask {
		in ballCount : BallCount;
		in throwHeight : ThrowHeight;
		out taskComplete : Boolean;
		out successRate : SuccessRate;
	}

	action performJugglingTask : PerformJugglingTask {
		in item ballCount;
		in item throwHeight;
		out item taskComplete;
		out item successRate;

		first start;

		then action initialize : InitializeRobot {
			in ballCount = performJugglingTask::ballCount;
			out initialized;
		}

		then action calibrate : CalibrateVisionSystem {
			out calibrated;
			out accuracy;
		}

		then merge jugglingLoop;

		then action track : TrackBalls {
			in expectedBalls = performJugglingTask::ballCount;
		}

		then action computeTraj : ComputeTrajectory {
			out interceptTime;
		}

		then action catchLeft : CatchBall {
			out caughtBall;
			out success;
		}

		then decide;
			if catchLeft.success == true then planThrowAction;
			if catchLeft.success == false then recover;

		action planThrowAction : PlanThrow {
			in targetHeight = performJugglingTask::throwHeight;
			in currentBalls = performJugglingTask::ballCount;
			out throwVelocity;
			out throwAngle;
		}

		flow from catchLeft.caughtBall to throwLeft.ball;
		flow from planThrowAction.throwVelocity to throwLeft.throwVelocity;

		then action throwLeft : ThrowBall {
			in ball;
			in throwHeight = performJugglingTask::throwHeight;
			in throwVelocity;
			out releasedBall;
		}

		then jugglingLoop;

		action recover : RecoverFromError {
			in errorType = BallStatus::dropped;
			out recovered;
		}

		then decide;
			if recover.recovered == true then jugglingLoop;
			if recover.recovered == false then finalize;

		action finalize {
			assign performJugglingTask::taskComplete = true;
		}

		then done;
	}

	// Logical model for allocation
	package LogicalModel {
		action def ExecutePrimaryTask;
		action def PerformJugglingRoutine;

		part def PrimaryTaskExecutor;

		action executePrimaryTask : ExecutePrimaryTask {
			action performJuggling : PerformJugglingRoutine;
		}

		part primaryExecutor : PrimaryTaskExecutor {
			perform executePrimaryTask.performJuggling;
		}
	}

	// Physical model with allocation
	package PhysicalModel {
		private import LogicalModel::*;

		part robotSystem : JugglingRobot {
			perform executePrimaryTask.performJuggling;
		}

		allocate primaryExecutor to robotSystem {
			allocate primaryExecutor.performJuggling to robotSystem.executeJugglingTask;
		}
	}

	// Requirements
	requirement def JugglingCapabilityRequirement {
		doc /* The robotic system shall continuously juggle at least 3 balls with 95% success rate. */

		require minBalls : BallCount = 3;
		require minSuccessRate : SuccessRate = 0.95;
		require maxCycleTime : CycleTime = 0.01[SI::s];
	}

	requirement def SafetyRequirement {
		doc /* The robotic system shall operate safely within workspace constraints. */

		require maxArmSpeed : SpeedValue = 3.5[SI::'m/s'];
		require maxGripForce : GripForce = 10.0[SI::N];
		require workspaceRadius : LengthValue = 1.0[SI::m];
	}

	requirement def ReliabilityRequirement {
		doc /* The robotic system shall recover from errors and maintain operation. */

		require recoveryTime : TimeValue = 2.0[SI::s];
		require maxConsecutiveDrops : Integer = 2;
	}

	requirement jugglingCapability : JugglingCapabilityRequirement {
		subject robot : JugglingRobot;
	}

	requirement safety : SafetyRequirement {
		subject robot : JugglingRobot;
	}

	requirement reliability : ReliabilityRequirement {
		subject robot : JugglingRobot;
	}

	// System instance
	part roboticJugglingSystem : JugglingRobot {
		:>> numberOfBalls = 3;
		:>> targetHeight = 1.2[SI::m];

		satisfy jugglingCapability by roboticJugglingSystem.executeJugglingTask;
		satisfy safety by roboticJugglingSystem;
		satisfy reliability by roboticJugglingSystem.behavior;
	}
}
