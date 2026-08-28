package 'Soft Robotic Work Cell' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def Fluid;
	item def Workpiece;

	port def FluidPort {
		out item pressurizedFluid : Fluid;
	}

	attribute def PowerOnSignal;
	attribute def InitCompleteSignal;
	attribute def StartTaskSignal;
	attribute def TaskCompleteSignal;
	attribute def TaskFailSignal;
	attribute def ResetSignal;

	part def OrganicSensor {
		attribute positionFeedback : LengthValue;
		attribute forceFeedback : ForceValue;
	}

	part def Joint {
		attribute currentForce : ForceValue;
	}

	part def Arm {
		attribute maxForce : ForceValue;
		part joints : Joint[4];
		port fluidInPort : ~FluidPort;
	}

	part def Gripper {
		attribute maxForce : ForceValue;
		attribute currentForce : ForceValue;
		port fluidInPort : ~FluidPort;
	}

	part def FluidicController {
		port fluidInPort : ~FluidPort;
		port armFluidOut : FluidPort;
		port gripperFluidOut : FluidPort;
	}

	action def SenseLocation {
		in sensorData : OrganicSensor;
		out objectPosition : LengthValue;
	}

	action def CalculatePath {
		in currentPosition : LengthValue;
		in targetPosition : LengthValue;
		out pathSteps : LengthValue[*];
	}

	action def GraspObject {
		in maxForce : ForceValue;
		out graspConfirmed : Boolean;
	}

	action def PickAndPlace {
		in workpieceLocation : LengthValue;
		in graspForceLimit : ForceValue;
		out success : Boolean;

		action senseLocation : SenseLocation;
		action calculatePath : CalculatePath;
		action moveToObject;
		action graspObject : GraspObject;
		action transportObject;
		action releaseObject;

		first senseLocation;
		then calculatePath;
		then moveToObject;
		then graspObject;
		then transportObject;
		then releaseObject;
	}

	state def RobotLifecycle {
		entry; then off;
		state off;
		transition off_to_init
			first off
			accept PowerOnSignal
			then init;
		state init;
		transition init_to_ready
			first init
			accept InitCompleteSignal
			then ready;
		state ready;
		transition ready_to_operating
			first ready
			accept StartTaskSignal
			then operating;
		state operating {
			perform action pickAndPlace : PickAndPlace;
		}
		transition operating_to_ready
			first operating
			accept TaskCompleteSignal
			then ready;
		transition operating_to_error
			first operating
			accept TaskFailSignal
			then error;
		state error;
		transition error_to_ready
			first error
			accept ResetSignal
			then ready;
	}

	part def SoftRobot {
		port fluidInPort : ~FluidPort;
		part arm : Arm;
		part gripper : Gripper;
		part sensors : OrganicSensor[4];
		part controller : FluidicController;

		flow of pressurizedFluid : Fluid
			from fluidInPort.pressurizedFluid to controller.fluidInPort.pressurizedFluid;
		flow of pressurizedFluid : Fluid
			from controller.armFluidOut.pressurizedFluid to arm.fluidInPort.pressurizedFluid;
		flow of pressurizedFluid : Fluid
			from controller.gripperFluidOut.pressurizedFluid to gripper.fluidInPort.pressurizedFluid;

		exhibit state lifecycle : RobotLifecycle;
	}

	part def FluidicPump {
		port fluidOutPort : FluidPort;
		attribute maxPressure : PressureValue;
	}

	part def PowerSupply {
		attribute outputVoltage : VoltageValue;
	}

	part workCell {
		part powerSupply : PowerSupply;
		part pump : FluidicPump;
		part robot : SoftRobot;

		flow of pressurizedFluid : Fluid
			from pump.fluidOutPort.pressurizedFluid to robot.fluidInPort.pressurizedFluid;
	}

	requirement def SafetyRequirements {
		subject softRobot : SoftRobot;
		requirement armForceLimit {
			constraint { softRobot.arm.maxForce <= 50 [N] }
		}
		requirement gripperForceLimit {
			constraint { softRobot.gripper.maxForce <= 20 [N] }
		}
	}
}
