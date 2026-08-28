package 'Rotodynamic Pumping Subsystem' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ScalarValues::Integer;
	private import ScalarValues::String;

	attribute def Pressure :> Real;
	attribute def FlowRate :> Real;
	attribute def RotationalSpeed :> Real;
	attribute def Power :> Real;
	attribute def Efficiency :> Real;
	attribute def Duration :> Real;

	item def Fluid;

	attribute def StartCommand;
	attribute def StopCommand;
	attribute def EmergencyStopCommand;
	attribute def MotorAtSpeed;
	attribute def CriticalPressureCondition;

	attribute def TargetFlowRateCommand {
		attribute targetFlow : FlowRate;
	}

	attribute def PressureReading {
		attribute pressure : Pressure;
	}

	attribute def FlowReading {
		attribute flowValue : FlowRate;
	}

	attribute def ValvePositionCommand {
		attribute position : Real;
	}

	attribute def MotorSpeedCommand {
		attribute speed : RotationalSpeed;
	}

	port def FluidOutPort {
		out fluid : Fluid;
	}

	port def FluidInPort {
		in fluid : Fluid;
	}

	port def PressureSignalOutPort {
		out pressureReading : PressureReading;
	}

	port def FlowSignalOutPort {
		out flowReading : FlowReading;
	}

	port def ValveControlInPort {
		in valvePosition : ValvePositionCommand;
	}

	port def MotorControlInPort {
		in motorSpeedCommand : MotorSpeedCommand;
	}

	port def ControllerCommandInPort {
		in startCommand : StartCommand;
		in stopCommand : StopCommand;
		in emergencyStopCommand : EmergencyStopCommand;
		in targetFlowRateCommand : TargetFlowRateCommand;
	}

	part def SupplyReservoir {
		port fluidOut : FluidOutPort;
		attribute fluidLevel : Real;
	}

	part def DischargeReservoir {
		port fluidIn : FluidInPort;
		attribute fluidLevel : Real;
	}

	part def Impeller {
		attribute bladeCount : Integer;
		attribute rotationalSpeed : RotationalSpeed;
		attribute diameter : Real;
	}

	part def VoluteCasing {
		port fluidIn : FluidInPort;
		port fluidOut : FluidOutPort;
	}

	part def Shaft {
		attribute material : String = "Stainless Steel";
		attribute diameter : Real;
	}

	part def BallBearings {
		attribute loadRating : Real;
		attribute ratedLife : Duration;
	}

	part def MechanicalSeal {
		attribute maxLeakRate : FlowRate;
		attribute ratedPressure : Pressure;
	}

	part def ElectricMotor {
		port motorControl : MotorControlInPort;
		attribute outputPower : Power;
		attribute nominalSpeed : RotationalSpeed;
		attribute currentSpeed : RotationalSpeed;
	}

	part def RotodynamicPump {
		port fluidIn : FluidInPort;
		port fluidOut : FluidOutPort;
		port motorControl : MotorControlInPort;

		part impeller : Impeller {
			:>> bladeCount = 7;
		}
		part volute : VoluteCasing;
		part shaft : Shaft;
		part bearings : BallBearings;
		part seal : MechanicalSeal;
		part motor : ElectricMotor;

		bind fluidIn = volute.fluidIn;
		bind fluidOut = volute.fluidOut;
		bind motorControl = motor.motorControl;

		attribute inletPressure : Pressure;
		attribute outletPressure : Pressure;
		attribute generatedHead : Pressure;
		attribute pumpFlowRate : FlowRate;
		attribute efficiency : Efficiency;
	}

	part def PressureSensor {
		port fluidIn : FluidInPort;
		port fluidOut : FluidOutPort;
		port pressureSignal : PressureSignalOutPort;
		attribute measuredPressure : Pressure;
	}

	part def FlowMeter {
		port fluidIn : FluidInPort;
		port fluidOut : FluidOutPort;
		port flowSignal : FlowSignalOutPort;
		attribute measuredFlow : FlowRate;
	}

	part def ControlValve {
		port fluidIn : FluidInPort;
		port fluidOut : FluidOutPort;
		port valveControl : ValveControlInPort;
		attribute position : Real;
	}

	part def PumpController {
		port commandPort : ControllerCommandInPort;
		port inletPressureIn {
			in pressureReading : PressureReading;
		}
		port outletPressureIn {
			in pressureReading : PressureReading;
		}
		port flowMeterIn {
			in flowReading : FlowReading;
		}
		port valveControlOut {
			out valvePosition : ValvePositionCommand;
		}
		port motorControlOut {
			out motorSpeedCommand : MotorSpeedCommand;
		}

		attribute targetFlow : FlowRate;
		attribute minInletPressure : Pressure;
		attribute maxOutletPressure : Pressure;
		attribute criticalPressure : Pressure;

		action calculateValvePosition {
			in measuredFlow : FlowRate;
			in targetFlowRate : FlowRate;
			out valveCommand : ValvePositionCommand;
		}

		action checkPressureSafety {
			in inletPressure : Pressure;
			in outletPressure : Pressure;
			out isCritical : Boolean;
		}
	}

	part def PumpingSubsystem {
		part supplyReservoir : SupplyReservoir;
		part dischargeReservoir : DischargeReservoir;
		part pump : RotodynamicPump;
		part inletPressureSensor : PressureSensor;
		part outletPressureSensor : PressureSensor;
		part flowMeter : FlowMeter;
		part controlValve : ControlValve;
		part controller : PumpController;

		flow supplyToInletSensor of Fluid
			from supplyReservoir.fluidOut.fluid to inletPressureSensor.fluidIn.fluid;
		flow inletSensorToPump of Fluid
			from inletPressureSensor.fluidOut.fluid to pump.fluidIn.fluid;
		flow pumpToOutletSensor of Fluid
			from pump.fluidOut.fluid to outletPressureSensor.fluidIn.fluid;
		flow outletSensorToFlowMeter of Fluid
			from outletPressureSensor.fluidOut.fluid to flowMeter.fluidIn.fluid;
		flow flowMeterToValve of Fluid
			from flowMeter.fluidOut.fluid to controlValve.fluidIn.fluid;
		flow valveToDischarge of Fluid
			from controlValve.fluidOut.fluid to dischargeReservoir.fluidIn.fluid;

		flow inletPressureSignal of PressureReading
			from inletPressureSensor.pressureSignal.pressureReading to controller.inletPressureIn.pressureReading;
		flow outletPressureSignal of PressureReading
			from outletPressureSensor.pressureSignal.pressureReading to controller.outletPressureIn.pressureReading;
		flow flowSignal of FlowReading
			from flowMeter.flowSignal.flowReading to controller.flowMeterIn.flowReading;
		flow valveControlSignal of ValvePositionCommand
			from controller.valveControlOut.valvePosition to controlValve.valveControl.valvePosition;
		flow motorControlSignal of MotorSpeedCommand
			from controller.motorControlOut.motorSpeedCommand to pump.motorControl.motorSpeedCommand;
	}

	part pumpingSystem : PumpingSubsystem;

	action performRampUp {
		in motor : ElectricMotor;
	}

	action performRampDown {
		in motor : ElectricMotor;
	}

	action performMonitoring {
		in inletPressure : Pressure;
		in outletPressure : Pressure;
	}

	action performFlowRegulation {
		in measuredFlow : FlowRate;
		in targetFlow : FlowRate;
	}

	action performSafetyCheck {
		in pumpingSubsystem : PumpingSubsystem;
	}

	state def PumpOperationalStates;
	state pumpOperationalStates : PumpOperationalStates {
		in subsystem : PumpingSubsystem;
		in controller : PumpController;
		entry; then off;

		state off {
			entry action powerOff { /* System powered off, control valve closed */ }
		}

		accept StartCommand
			do send new MotorSpeedCommand() to subsystem.pump.motor
			then starting;

		state starting {
			do performRampUp { in motor = subsystem.pump.motor; }
		}

		accept MotorAtSpeed
			if subsystem.inletPressureSensor.measuredPressure > controller.minInletPressure
			then operating;

		state operating {
			entry action beginMonitoring { /* Begin active monitoring and flow regulation */ }
			do performMonitoring {
				in inletPressure = subsystem.inletPressureSensor.measuredPressure;
				in outletPressure = subsystem.outletPressureSensor.measuredPressure;
			}
			do performFlowRegulation {
				in measuredFlow = subsystem.flowMeter.measuredFlow;
				in targetFlow = controller.targetFlow;
			}
		}

		accept StopCommand
			do send new MotorSpeedCommand() to subsystem.pump.motor
			then shuttingDown;

		accept CriticalPressureCondition
			do send new EmergencyStopCommand() to controller
			then emergencyShutdown;

		state shuttingDown {
			do performRampDown { in motor = subsystem.pump.motor; }
		}
		then off;

		state emergencyShutdown {
			entry action emergencyStop { /* Immediately stop motor, close control valve */ }
			do performSafetyCheck { in pumpingSubsystem = subsystem; }
		}
		then off;
	}

	requirement def MinimumFlowRateRequirement {
		attribute minFlowRate : FlowRate;
	}

	requirement def HeadPressureRequirement {
		attribute minHeadPressure : Pressure;
	}

	requirement def EfficiencyRequirement {
		attribute minEfficiency : Efficiency;
	}

	requirement def ReliabilityRequirement {
		attribute mtbf : Duration;
	}

	requirement PumpPerformanceRequirements {
		requirement minFlow : MinimumFlowRateRequirement {
			:>> minFlowRate = 0.05;
		}
		requirement headPressure : HeadPressureRequirement {
			:>> minHeadPressure = 300000;
		}
		requirement efficiency : EfficiencyRequirement {
			:>> minEfficiency = 0.80;
		}
		requirement reliability : ReliabilityRequirement {
			:>> mtbf = 10000;
		}
	}

	satisfy PumpPerformanceRequirements by pumpingSystem;
}
