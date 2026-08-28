package IndustrialRoboticSystem {
	private import ScalarValues::*;

	attribute def Voltage :> ScalarValues::Real;
	attribute def Length :> ScalarValues::Real;
	attribute def Force :> ScalarValues::Real;
	attribute def Velocity :> ScalarValues::Real;
	attribute def CompletionRate :> ScalarValues::Real;

	item def Workpiece;
	item def AnalogCommandSignal {
		attribute voltage : Voltage;
	}
	item def FeedbackSignal {
		attribute position : Length;
		attribute force : Force;
		attribute velocity : Velocity;
	}

	item def StartCalibration;
	item def CalibrationComplete;
	item def TaskComplete;
	item def ErrorDetected;
	item def Reset;
	item def GripperClose;
	item def GripperOpen;
	item def ObjectDetected;

	requirement def PerformanceRequirements {
		attribute taskCompletionRate : CompletionRate;
		attribute positioningAccuracy : Length;
		attribute controlVoltageMin : Voltage;
		attribute controlVoltageMax : Voltage;

		constraint { taskCompletionRate > 0.95 }
		constraint { positioningAccuracy < 0.5 }
		constraint { controlVoltageMin >= 0.0 and controlVoltageMax <= 10.0 }
	}

	requirement performanceReq : PerformanceRequirements {
		attribute :>> taskCompletionRate = 0.96;
		attribute :>> positioningAccuracy = 0.4;
		attribute :>> controlVoltageMin = 0.0;
		attribute :>> controlVoltageMax = 10.0;
	}

	part def ControlStation {
		part operatorInterface {
			attribute displayActive : ScalarValues::Boolean;
			attribute inputActive : ScalarValues::Boolean;
			out port commandOut : AnalogCommandSignal;
		}
		part dataAcquisitionSystem {
			in port feedbackIn : FeedbackSignal;
		}
	}

	part def WorkCell {
		part workpiece : Workpiece;
		part fixture;
		part safetyEnclosure;
	}

	action def ControlLoop {
		in cmd : Voltage;
		in fb : Length;
		out controlVoltage : Voltage;
		first start;
		then action compareError {
			in c : Voltage;
			in f : Length;
			out error : Voltage;
		}
		then action amplify {
			in err : Voltage;
			out amplified : Voltage;
		}
		then action filterSignal {
			in amp : Voltage;
			out filt : Voltage;
		}
		then done;
		flow cmd to compareError.c;
		flow fb to compareError.f;
		flow compareError.error to amplify.err;
		flow amplify.amplified to filterSignal.amp;
		bind controlVoltage = filterSignal.filt;
	}

	action def PrimaryTask {
		first start;
		then action moveToPick;
		then action graspWorkpiece;
		then action moveToTarget;
		then action releaseWorkpiece;
		then done;
	}

	part def RobotArm {
		attribute taskCompletionRate : CompletionRate;
		attribute positioningAccuracy : Length;

		part powerSupply;

		part sensorSystem {
			attribute position : Length;
			attribute force : Force;
			attribute velocity : Velocity;
			out port feedbackOut : FeedbackSignal;
		}

		part actuatorAssembly {
			part servoMotor;
			part gearReduction;
			part gripper {
				state def GripperStates {
					entry;
						then open;
					state open;
					transition open_to_closed
						first open
						accept GripperClose
						then closed;
					state closed;
					transition closed_to_gripping
						first closed
						accept ObjectDetected
						then gripping;
					state gripping;
					transition gripping_to_open
						first gripping
						accept GripperOpen
						then open;
				}
				exhibit GripperStates;
			}
		}

		part analogControlCircuit {
			in port commandIn : AnalogCommandSignal;
			in port feedbackIn : FeedbackSignal;
			out port controlVoltageOut : Voltage;
			perform controlLoop : ControlLoop {
				in cmd = commandIn.voltage;
				in fb = feedbackIn.position;
				out controlVoltage = controlVoltageOut;
			}
		}

		in port commandPort : AnalogCommandSignal;
		out port feedbackPort : FeedbackSignal;

		state def RobotStates {
			entry;
				then idle;
			state idle;
			transition idle_to_calibrating
				first idle
				accept StartCalibration
				then calibrating;
			state calibrating;
			transition calibrating_to_executing
				first calibrating
				accept CalibrationComplete
				then executing;
			state executing {
				perform task : PrimaryTask;
			}
			transition executing_to_completed
				first executing
				accept TaskComplete
				then completed;
			transition executing_to_fault
				first executing
				accept ErrorDetected
				then fault;
			state completed;
			transition completed_to_idle
				first completed
				accept Reset
				then idle;
			state fault;
			transition fault_to_idle
				first fault
				accept Reset
				then idle;
		}

		exhibit RobotStates;
	}

	part robotSystem {
		part controlStation : ControlStation;
		part workCell : WorkCell;
		part robot : RobotArm;

		connect controlStation.operatorInterface.commandOut to robot.commandPort;
		connect robot.feedbackPort to controlStation.dataAcquisitionSystem.feedbackIn;
		connect robot.sensorSystem.feedbackOut to robot.analogControlCircuit.feedbackIn;
		connect robot.commandPort to robot.analogControlCircuit.commandIn;
	}
}
