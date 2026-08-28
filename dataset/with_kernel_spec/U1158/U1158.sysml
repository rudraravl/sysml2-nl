package 'Permanent Magnet Motor Control System' {
	private import ISQ::*;
	private import ScalarValues::*;

	package Definitions {
		alias Torque for TorqueValue;
		alias Current for ElectricCurrentValue;
		alias Voltage for ElectricPotentialValue;
		alias Angle for AngleValue;
		alias AngularSpeed for AngularSpeedValue;

		attribute maxCurrent : Current = 10.0;

		item def MotorCommand {
			attribute targetPosition : Angle;
			attribute targetSpeed : AngularSpeed;
		}
		item def StopCommand;
		item def ResetCommand;
		item def CalibrateComplete;
		item def DecelerationComplete;
		item def OverCurrentFault;
		item def ControlSignal {
			attribute dutyCycle : Real;
		}
		item def PositionFeedback {
			attribute position : Angle;
			attribute speed : AngularSpeed;
		}
		item def CurrentFeedback {
			attribute current : Current;
		}

		port def CommandInPort {
			in command : MotorCommand;
			in stop : StopCommand;
			in reset : ResetCommand;
		}
		port def ControlOutPort {
			out signal : ControlSignal;
		}
		port def ControlInPort {
			in signal : ControlSignal;
		}
		port def PowerOutPort {
			out voltage : Voltage;
			out current : Current;
		}
		port def PowerInPort {
			in voltage : Voltage;
			in current : Current;
		}
		port def MechOutPort {
			out torque : Torque;
			out position : Angle;
			out speed : AngularSpeed;
		}
		port def MechInPort {
			in position : Angle;
			in speed : AngularSpeed;
		}
		port def FeedbackOutPort {
			out positionFeedback : PositionFeedback;
			out currentFeedback : CurrentFeedback;
			out fault : OverCurrentFault;
		}
		port def FeedbackInPort {
			in positionFeedback : PositionFeedback;
			in currentFeedback : CurrentFeedback;
			in fault : OverCurrentFault;
		}

		action def InitializeSensors;
		action def ControlledDeceleration {
			out signal : ControlSignal;
		}
		action def ComputePositionError {
			in target : MotorCommand;
			in actual : PositionFeedback;
			out error : Real;
		}
		action def CheckCurrentLimit {
			in current : CurrentFeedback;
			in limit : Current;
			out isSafe : Boolean;
		}
		action def GenerateControlSignal {
			in error : Real;
			in isSafe : Boolean;
			out signal : ControlSignal;
		}
		action def RunControlLoop {
			in command : MotorCommand;
			in positionFeedback : PositionFeedback;
			in currentFeedback : CurrentFeedback;
			out signal : ControlSignal;
			loop {
				action computeError : ComputePositionError {
					in target = command;
					in actual = positionFeedback;
					out error : Real;
				}
				action checkCurrent : CheckCurrentLimit {
					in current = currentFeedback;
					in limit = maxCurrent;
					out isSafe : Boolean;
				}
				flow computeError.error to generateSignal.error;
				flow checkCurrent.isSafe to generateSignal.isSafe;
				action generateSignal : GenerateControlSignal {
					in error : Real;
					in isSafe : Boolean;
					out signal : ControlSignal;
				}
			}
		}

		part def PowerSupply {
			port powerOut : PowerOutPort;
		}
		part def PowerStage {
			port powerIn : PowerInPort;
			port controlIn : ControlInPort;
			port motorPowerOut : PowerOutPort;
		}
		part def PermanentMagnetMotor {
			port motorPowerIn : PowerInPort;
			port mechanicalOut : MechOutPort;
		}
		part def EncoderSensor {
			port mechanicalIn : MechInPort;
			port feedbackOut : FeedbackOutPort;
		}
		part def CurrentSensor {
			port electricalIn : PowerInPort;
			port electricalOut : PowerOutPort;
			port feedbackOut : FeedbackOutPort;
		}
		part def MotorController {
			port commandIn : CommandInPort;
			port feedbackIn : FeedbackInPort;
			port controlOut : ControlOutPort;
			exhibit state 'controller states' {
				entry; then initializing;
				state initializing {
					entry action 'initialize sensors' : InitializeSensors;
				}
				accept CalibrateComplete then idle;
				state idle;
				accept command : MotorCommand then active;
				state active {
					do action 'run control loop' : RunControlLoop;
				}
				accept stop : StopCommand then decelerating;
				accept fault : OverCurrentFault then faulted;
				state decelerating {
					entry action 'controlled deceleration' : ControlledDeceleration;
				}
				accept DecelerationComplete then idle;
				state faulted;
				accept reset : ResetCommand then idle;
			}
		}

		part def PMCSystem {
			port externalCommand : CommandInPort;

			part powerSupply : PowerSupply;
			part powerStage : PowerStage;
			part motor : PermanentMagnetMotor;
			part encoder : EncoderSensor;
			part currentSensor : CurrentSensor;
			part controller : MotorController;

			bind externalCommand = controller.commandIn;

			interface powerInterface connect powerSupply.powerOut to powerStage.powerIn;
			interface controlInterface connect controller.controlOut to powerStage.controlIn;
			interface stageToCurrentSensorInterface connect powerStage.motorPowerOut to currentSensor.electricalIn;
			interface currentSensorToMotorInterface connect currentSensor.electricalOut to motor.motorPowerIn;
			interface motorToEncoderInterface connect motor.mechanicalOut to encoder.mechanicalIn;
			interface encoderFeedbackInterface connect encoder.feedbackOut to controller.feedbackIn;
			interface currentFeedbackInterface connect currentSensor.feedbackOut to controller.feedbackIn;
		}

		requirement def PrecisionControl {
			subject system : PMCSystem;
			doc /* The system shall precisely control the motor's position, speed, and torque based on external commands with high accuracy and responsiveness. */
		}
		requirement def SafetyOperation {
			subject system : PMCSystem;
			doc /* The system shall detect over-current conditions and enter a fault state, and shall execute controlled deceleration on stop commands before returning to idle. */
		}
	}

	public import Definitions::*;

	part pmcSystem : PMCSystem;

	requirement precisionControlReq : PrecisionControl {
		subject :>> system = pmcSystem;
	}
	requirement safetyOperationReq : SafetyOperation {
		subject :>> system = pmcSystem;
	}
}
