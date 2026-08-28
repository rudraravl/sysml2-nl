package 'Automated Fluid Transfer Subsystem' {
	private import ScalarValues::*;
	public import Definitions::*;

	package Definitions {
		item def Fluid;

		item def PressureValue {
			attribute value : Real;
		}

		item def FlowRateValue {
			attribute value : Real;
		}

		item def ValveCommand {
			attribute opening : Real;
		}

		attribute def StartSignal;
		attribute def ShutdownSignal;
		attribute def PrimingCompleteSignal;
		attribute def AccelerationCompleteSignal;
		attribute def ShutdownCompleteSignal;
		attribute def PressureHighSignal;
		attribute def PressureNormalSignal;

		port def FluidPort {
			out item fluid : Fluid;
		}

		port def PressureOutPort {
			out item pressure : PressureValue;
		}

		port def FlowRateOutPort {
			out item flowRate : FlowRateValue;
		}

		port def ValveCmdInPort {
			in item command : ValveCommand;
		}

		port def ValveCmdOutPort {
			out item command : ValveCommand;
		}

		part def Motor {
			attribute powerRating : Real;
		}

		part def Shaft {
			attribute length : Real;
			attribute diameter : Real;
		}

		part def Bearing;

		part def Impeller {
			attribute diameter : Real;
		}

		part def Volute {
			attribute volume : Real;
		}

		part def Pump {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;

			part motor : Motor;
			part shaft : Shaft;
			part bearing : Bearing;
			part impeller : Impeller;
			part volute : Volute;

			exhibit state pumpStates : PumpStates;
		}

		part def HighCapacityPump :> Pump {
			part redefines motor : Motor {
				attribute redefines powerRating : Real = 15000;
			}
			part redefines impeller : Impeller {
				attribute redefines diameter : Real = 0.3;
			}
			part redefines shaft : Shaft {
				attribute redefines length : Real = 0.7;
				attribute redefines diameter : Real = 0.04;
			}
			part redefines volute : Volute {
				attribute redefines volume : Real = 0.025;
			}
		}

		part def SourceTank {
			port fluidOutPort : FluidPort;
			attribute capacity : Real;
		}

		part def DestinationTank {
			port fluidInPort : ~FluidPort;
			attribute capacity : Real;
		}

		part def PressureSensor {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port pressureOutPort : PressureOutPort;
		}

		part def FlowRateSensor {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port flowRateOutPort : FlowRateOutPort;
		}

		part def ControlValve {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port commandInPort : ValveCmdInPort;
			attribute opening : Real;
		}

		part def Controller {
			port pressureInPort : ~PressureOutPort;
			port flowRateInPort : ~FlowRateOutPort;
			port valveCmdOutPort : ValveCmdOutPort;

			attribute targetPressure : Real;
			attribute minPressure : Real;
			attribute maxPressure : Real;

			perform action controlLoop : ControlLoop {
				in measuredPressure = pressureInPort.pressure;
				in target = targetPressure;
				in min = minPressure;
				in max = maxPressure;
				out command = valveCmdOutPort.command;
			}
		}

		action def PrimePump;
		action def AcceleratePump;
		action def DeceleratePump;

		action def ControlLoop {
			in measuredPressure : PressureValue;
			in target : Real;
			in min : Real;
			in max : Real;
			out command : ValveCommand;
		}

		state def PumpStates {
			entry; then off;
			state off;
			accept StartSignal then priming;
			state priming {
				do action primePump : PrimePump;
			}
			accept PrimingCompleteSignal then acceleration;
			state acceleration {
				do action acceleratePump : AcceleratePump;
			}
			accept AccelerationCompleteSignal then operational;
			state operational {
				entry; then normalFlow;
				state normalFlow;
				accept PressureHighSignal then reducedFlow;
				state reducedFlow;
				accept PressureNormalSignal then normalFlow;
			}
			accept ShutdownSignal then shutdown;
			state shutdown {
				do action deceleratePump : DeceleratePump;
			}
			accept ShutdownCompleteSignal then off;
		}

		requirement def FluidTransferRequirement {
			doc /* The subsystem shall transfer fluid from a source tank to a destination tank using a pistonless pump. */
		}

		requirement def PressureControlRequirement {
			doc /* The system shall continuously monitor discharge pressure and automatically adjust the control valve to maintain pressure within the specified operating range. */
		}

		requirement def PumpLifecycleRequirement {
			doc /* The pump shall progress through off, startup, operational, and shutdown states, and shall switch between normalFlow and reducedFlow modes in response to pressure changes. */
		}

		requirement def ConfigurabilityRequirement {
			doc /* The subsystem architecture shall support different pump configurations, including a high-capacity variant with a more powerful motor and larger components. */
		}
	}

	package Usages {
		private import Definitions::*;

		requirement fluidTransferReq : FluidTransferRequirement;
		requirement pressureControlReq : PressureControlRequirement;
		requirement pumpLifecycleReq : PumpLifecycleRequirement;
		requirement configurabilityReq : ConfigurabilityRequirement;

		part standardSubsystem {
			part sourceTank : SourceTank {
				attribute capacity = 1000;
			}
			part pump : Pump {
				part motor : Motor {
					attribute powerRating = 5000;
				}
				part impeller : Impeller {
					attribute diameter = 0.2;
				}
				part shaft : Shaft {
					attribute length = 0.5;
					attribute diameter = 0.03;
				}
				part volute : Volute {
					attribute volume = 0.01;
				}
			}
			part pressureSensor : PressureSensor;
			part flowRateSensor : FlowRateSensor;
			part controlValve : ControlValve;
			part destinationTank : DestinationTank {
				attribute capacity = 500;
			}
			part controller : Controller {
				attribute targetPressure = 300000;
				attribute minPressure = 280000;
				attribute maxPressure = 320000;
			}

			flow of fluid : Fluid
				from sourceTank.fluidOutPort.fluid to pump.fluidInPort.fluid;
			flow of fluid : Fluid
				from pump.fluidOutPort.fluid to pressureSensor.fluidInPort.fluid;
			flow of fluid : Fluid
				from pressureSensor.fluidOutPort.fluid to flowRateSensor.fluidInPort.fluid;
			flow of fluid : Fluid
				from flowRateSensor.fluidOutPort.fluid to controlValve.fluidInPort.fluid;
			flow of fluid : Fluid
				from controlValve.fluidOutPort.fluid to destinationTank.fluidInPort.fluid;

			flow of pressure : PressureValue
				from pressureSensor.pressureOutPort.pressure to controller.pressureInPort.pressure;
			flow of flowRate : FlowRateValue
				from flowRateSensor.flowRateOutPort.flowRate to controller.flowRateInPort.flowRate;
			flow of command : ValveCommand
				from controller.valveCmdOutPort.command to controlValve.commandInPort.command;
		}

		satisfy fluidTransferReq by standardSubsystem;
		satisfy pressureControlReq by standardSubsystem.controller;
		satisfy pumpLifecycleReq by standardSubsystem.pump;
		satisfy configurabilityReq by standardSubsystem.pump;

		part highCapacitySubsystem {
			part sourceTank : SourceTank {
				attribute capacity = 2000;
			}
			part pump : HighCapacityPump;
			part pressureSensor : PressureSensor;
			part flowRateSensor : FlowRateSensor;
			part controlValve : ControlValve;
			part destinationTank : DestinationTank {
				attribute capacity = 1000;
			}
			part controller : Controller {
				attribute targetPressure = 500000;
				attribute minPressure = 480000;
				attribute maxPressure = 520000;
			}

			flow of fluid : Fluid
				from sourceTank.fluidOutPort.fluid to pump.fluidInPort.fluid;
			flow of fluid : Fluid
				from pump.fluidOutPort.fluid to pressureSensor.fluidInPort.fluid;
			flow of fluid : Fluid
				from pressureSensor.fluidOutPort.fluid to flowRateSensor.fluidInPort.fluid;
			flow of fluid : Fluid
				from flowRateSensor.fluidOutPort.fluid to controlValve.fluidInPort.fluid;
			flow of fluid : Fluid
				from controlValve.fluidOutPort.fluid to destinationTank.fluidInPort.fluid;

			flow of pressure : PressureValue
				from pressureSensor.pressureOutPort.pressure to controller.pressureInPort.pressure;
			flow of flowRate : FlowRateValue
				from flowRateSensor.flowRateOutPort.flowRate to controller.flowRateInPort.flowRate;
			flow of command : ValveCommand
				from controller.valveCmdOutPort.command to controlValve.commandInPort.command;
		}

		satisfy fluidTransferReq by highCapacitySubsystem;
		satisfy pressureControlReq by highCapacitySubsystem.controller;
		satisfy pumpLifecycleReq by highCapacitySubsystem.pump;
		satisfy configurabilityReq by highCapacitySubsystem.pump;
	}
}
