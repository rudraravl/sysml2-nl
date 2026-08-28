package FluidPumpingSubsystem {
	private import ScalarValues::*;
	public import Definitions::*;

	package Definitions {
		private import ScalarValues::*;

		item def Fluid;

		attribute def PressureValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def AngularVelocityValue :> Real;

		port def FluidInPort {
			in item fluid : Fluid;
		}
		port def FluidOutPort {
			out item fluid : Fluid;
		}
		port def CommandPort {
			in desiredFlowRate : FlowRateValue;
		}
		port def PressureSignalPort {
			out pressure : PressureValue;
		}
		port def FlowSignalPort {
			out flowRate : FlowRateValue;
		}
		port def MotorCmdPort {
			out speedCommand : AngularVelocityValue;
		}

		attribute def StartCommand;
		attribute def StopCommand;
		attribute def PrimedSignal;
		attribute def RunningReachedSignal;
		attribute def StoppedSignal;
		attribute def FaultSignal;
		attribute def ResetCommand;

		part def ElectricMotor {
			attribute speed : AngularVelocityValue;
			port commandPort : ~MotorCmdPort;
		}

		part def Impeller {
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
		}

		part def PumpHousing {
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
			part impeller : Impeller;
			connect inletPort to impeller.fluidInPort;
			connect impeller.fluidOutPort to outletPort;
		}

		part def PressureSensor {
			attribute pressure : PressureValue;
			port fluidPort : FluidInPort;
			port signalPort : PressureSignalPort;
		}

		part def FlowSensor {
			attribute flowRate : FlowRateValue;
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
			port signalPort : FlowSignalPort;
		}

		action def ControlLoop {
			in desiredFlowRate : FlowRateValue;
			in actualFlowRate : FlowRateValue;
			in inletPressure : PressureValue;
			in outletPressure : PressureValue;
			out motorCommand : AngularVelocityValue;
		}

		action def StopMotor {
			out motorCommand : AngularVelocityValue;
		}

		state def ControllerStates {
			entry; then off;
			state off;
			transition off_to_starting
				first off
				accept StartCommand
				then starting;

			state starting {
				entry; then priming;
				state priming;
				transition priming_to_accelerating
					first priming
					accept PrimedSignal
					then accelerating;
				state accelerating;
			}
			transition starting_to_running
				first starting
				accept RunningReachedSignal
				then running;

			state running;
			transition running_to_stopping
				first running
				accept StopCommand
				then stopping;

			state stopping;
			transition stopping_to_off
				first stopping
				accept StoppedSignal
				then off;

			transition off_to_fault
				first off
				accept FaultSignal
				then fault;
			transition starting_to_fault
				first starting
				accept FaultSignal
				then fault;
			transition running_to_fault
				first running
				accept FaultSignal
				then fault;
			transition stopping_to_fault
				first stopping
				accept FaultSignal
				then fault;
			state fault;
			transition fault_to_off
				first fault
				accept ResetCommand
				then off;
		}

		part def PumpController {
			port commandPort : CommandPort;
			port inletPressurePort : ~PressureSignalPort;
			port outletPressurePort : ~PressureSignalPort;
			port flowPort : ~FlowSignalPort;
			port motorCommandPort : MotorCmdPort;

			attribute desiredFlowRate : FlowRateValue;
			attribute actualFlowRate : FlowRateValue;
			attribute inletPressure : PressureValue;
			attribute outletPressure : PressureValue;

			exhibit state controllerStates : ControllerStates {
				state :>> running {
					do action controlLoop : ControlLoop {
						in desiredFlowRate = commandPort.desiredFlowRate;
						in actualFlowRate = flowPort.flowRate;
						in inletPressure = inletPressurePort.pressure;
						in outletPressure = outletPressurePort.pressure;
						out motorCommand = motorCommandPort.speedCommand;
					}
				}
				state :>> stopping {
					entry action stopMotor : StopMotor {
						out motorCommand = motorCommandPort.speedCommand;
					}
				}
			}
		}

		part def PumpDispenser {
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
			port commandPort : CommandPort;

			part housing : PumpHousing;
			part motor : ElectricMotor;
			part inletPressureSensor : PressureSensor;
			part outletPressureSensor : PressureSensor;
			part flowSensor : FlowSensor;
			part controller : PumpController;

			bind commandPort = controller.commandPort;

			connect inletPort to housing.inletPort;
			connect housing.outletPort to flowSensor.fluidInPort;
			connect flowSensor.fluidOutPort to outletPort;

			connect housing.inletPort to inletPressureSensor.fluidPort;
			connect housing.outletPort to outletPressureSensor.fluidPort;

			flow of pressureVal : PressureValue from inletPressureSensor.signalPort.pressure to controller.inletPressurePort.pressure;
			flow of pressureVal : PressureValue from outletPressureSensor.signalPort.pressure to controller.outletPressurePort.pressure;
			flow of flowVal : FlowRateValue from flowSensor.signalPort.flowRate to controller.flowPort.flowRate;
			flow of cmdVal : AngularVelocityValue from controller.motorCommandPort.speedCommand to motor.commandPort.speedCommand;
		}

		part def SourceReservoir {
			port outletPort : FluidOutPort;
		}

		part def DestinationPoint {
			port inletPort : FluidInPort;
		}

		part def Pipe {
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
		}

		requirement def FlowRateRequirement {
			doc /* The pump shall deliver a flow rate within +/- 5% of the desired setpoint. */
			attribute targetFlowRate : FlowRateValue;
			attribute actualFlowRate : FlowRateValue;
			attribute tolerance : Real = 0.05;
			assert constraint {
				actualFlowRate >= targetFlowRate * (1 - tolerance) and
				actualFlowRate <= targetFlowRate * (1 + tolerance)
			}
		}

		requirement def MinOutletPressureRequirement {
			doc /* The pump shall maintain a minimum outlet pressure of 2 bar. */
			attribute outletPressure : PressureValue;
			attribute minOutletPressure : PressureValue = 200000;
			assert constraint { outletPressure >= minOutletPressure }
		}

		requirement def ReliabilityRequirement {
			doc /* The system shall operate with a reliability of at least 0.999 over 1000 hours. */
			attribute requiredReliability : Real = 0.999;
			attribute missionTime : Real = 1000.0;
		}

		requirement def EfficiencyRequirement {
			doc /* The pump shall have an overall efficiency of at least 80%. */
			attribute efficiency : Real;
			attribute minEfficiency : Real = 0.80;
			assert constraint { efficiency >= minEfficiency }
		}
	}

	package Usages {
		private import Definitions::*;
		private import ScalarValues::*;

		part fluidCircuit {
			part source : SourceReservoir;
			part supplyPipe : Pipe;
			part pump : PumpDispenser;
			part dischargePipe : Pipe;
			part destination : DestinationPoint;

			port externalCommandPort : CommandPort;
			attribute desiredFlowRate : FlowRateValue = 10.0;

			bind externalCommandPort = pump.commandPort;

			flow of supplyFluid : Fluid from source.outletPort.fluid to supplyPipe.inletPort.fluid;
			flow of pumpInFluid : Fluid from supplyPipe.outletPort.fluid to pump.inletPort.fluid;
			flow of pumpOutFluid : Fluid from pump.outletPort.fluid to dischargePipe.inletPort.fluid;
			flow of dischargeFluid : Fluid from dischargePipe.outletPort.fluid to destination.inletPort.fluid;

			requirement flowRateReq : FlowRateRequirement {
				attribute :>> targetFlowRate = desiredFlowRate;
				attribute :>> actualFlowRate = pump.controller.actualFlowRate;
			}
			satisfy flowRateReq by pump;

			requirement outletPressureReq : MinOutletPressureRequirement {
				attribute :>> outletPressure = pump.controller.outletPressure;
			}
			satisfy outletPressureReq by pump;

			requirement reliabilityReq : ReliabilityRequirement;
			satisfy reliabilityReq by pump;

			requirement efficiencyReq : EfficiencyRequirement;
			satisfy efficiencyReq by pump;
		}
	}
}
