package 'Industrial Fluid Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		item def Fluid {
			attribute temperature : Real;
			attribute pressure : Real;
			attribute density : Real;
		}

		attribute def StartSignal;
		attribute def StopSignal;
		attribute def PumpReadySignal;
		attribute def StopCompleteSignal;
		attribute def FaultSignal;
		attribute def ResetSignal;

		attribute def ValveCommand {
			attribute openFraction : Real;
		}

		port def FluidPort {
			inout item fluid : Fluid;
		}

		port def FlowSignalPort {
			out flowRate : Real;
		}

		port def PressureSignalPort {
			out pressureValue : Real;
		}

		port def ValveCommandPort {
			in command : ValveCommand;
		}

		part def ElectricMotor {
			attribute powerRating : Real;
		}

		part def Shaft;
		part def RadialBearing;
		part def ThrustBearing;

		part def Inducer {
			port fluidInPort : FluidPort;
			port fluidOutPort : FluidPort;
		}

		part def Impeller {
			port fluidInPort : FluidPort;
			port fluidOutPort : FluidPort;
		}

		part def Casing {
			port fluidInPort : FluidPort;
			port fluidOutPort : FluidPort;
			attribute material : String = "StainlessSteel";
		}

		part def MechanicalSeal;

		part def MainPump {
			port fluidInPort : FluidPort;
			port fluidOutPort : FluidPort;

			part motor : ElectricMotor;
			part shaft : Shaft;
			part radialBearing : RadialBearing;
			part thrustBearing : ThrustBearing;
			part inducer : Inducer;
			part impeller : Impeller;
			part casing : Casing;
			part mechanicalSeal : MechanicalSeal;

			exhibit state pumpStates : PumpStates;
		}

		part def SupplyTank {
			port fluidOutPort : FluidPort;
			attribute volume : Real;
		}

		part def DischargeTank {
			port fluidInPort : FluidPort;
			attribute volume : Real;
			attribute maxPressure : Real;
		}

		part def FlowSensor {
			port fluidInPort : FluidPort;
			port fluidOutPort : FluidPort;
			port flowSignalOutPort : FlowSignalPort;
			attribute measuredFlowRate : Real;
		}

		part def PressureSensor {
			port fluidInPort : FluidPort;
			port fluidOutPort : FluidPort;
			port pressureSignalOutPort : PressureSignalPort;
			attribute measuredPressure : Real;
		}

		part def DischargeValve {
			port fluidInPort : FluidPort;
			port fluidOutPort : FluidPort;
			port commandInPort : ValveCommandPort;
			attribute openFraction : Real = 0.5;
		}

		part def PumpController {
			port flowSignalInPort : ~FlowSignalPort;
			port pressureSignalInPort : ~PressureSignalPort;
			port valveCommandOutPort : ValveCommandPort;
			attribute targetFlowRate : Real;
		}

		state def PumpStates {
			entry; then off;
			state off;
			accept StartSignal then starting;
			state starting;
			accept PumpReadySignal then operating;
			accept FaultSignal then fault;
			state operating {
				do action pumpFluid {
					/* Continuously pump fluid from inlet through inducer, impeller, and casing to outlet */
				}
			}
			accept StopSignal then shuttingDown;
			accept FaultSignal then fault;
			state shuttingDown;
			accept StopCompleteSignal then off;
			state fault;
			accept ResetSignal then off;
		}

		action def RegulateFlowAction {
			in measuredFlow : Real;
			in targetFlow : Real;
			out command : ValveCommand;
		}

		requirement def FlowRateAccuracy {
			doc /* The pumping subsystem shall maintain the discharge flow rate within plus or minus 2 percent of the target flow rate. */
		}

		requirement def CavitationPrevention {
			doc /* The inducer shall provide sufficient inlet pressure to prevent cavitation under all normal operating conditions. */
		}

		requirement def LeakPrevention {
			doc /* The mechanical seal shall prevent fluid leakage along the shaft during all operating states. */
		}
	}

	package Usages {
		private import Definitions::*;

		part pumpingSubsystem {
			part supplyTank : SupplyTank {
				attribute volume = 100.0;
			}

			flow of fluid : Fluid
				from supplyTank.fluidOutPort.fluid to mainPump.fluidInPort.fluid;

			part mainPump : MainPump {
				part motor : ElectricMotor {
					attribute powerRating = 15.0;
				}

				part shaft : Shaft;
				part radialBearing : RadialBearing;
				part thrustBearing : ThrustBearing;

				part inducer : Inducer;
				part impeller : Impeller;

				part casing : Casing {
					attribute material = "StainlessSteel";
				}

				part mechanicalSeal : MechanicalSeal;

				flow of fluid : Fluid
					from fluidInPort.fluid to inducer.fluidInPort.fluid;
				flow of fluid : Fluid
					from inducer.fluidOutPort.fluid to impeller.fluidInPort.fluid;
				flow of fluid : Fluid
					from impeller.fluidOutPort.fluid to casing.fluidInPort.fluid;
				flow of fluid : Fluid
					from casing.fluidOutPort.fluid to fluidOutPort.fluid;
			}

			flow of fluid : Fluid
				from mainPump.fluidOutPort.fluid to flowSensor.fluidInPort.fluid;

			part flowSensor : FlowSensor {
				attribute measuredFlowRate = 0.0;
			}

			flow of fluid : Fluid
				from flowSensor.fluidOutPort.fluid to pressureSensor.fluidInPort.fluid;

			part pressureSensor : PressureSensor {
				attribute measuredPressure = 0.0;
			}

			flow of fluid : Fluid
				from pressureSensor.fluidOutPort.fluid to dischargeValve.fluidInPort.fluid;

			part dischargeValve : DischargeValve {
				attribute openFraction = 0.5;
			}

			flow of fluid : Fluid
				from dischargeValve.fluidOutPort.fluid to dischargeTank.fluidInPort.fluid;

			part dischargeTank : DischargeTank {
				attribute volume = 50.0;
				attribute maxPressure = 500.0;
			}

			part controller : PumpController {
				attribute targetFlowRate = 0.05;

				perform action regulateFlow : RegulateFlowAction {
					in measuredFlow = flowSignalInPort.flowRate;
					in targetFlow = targetFlowRate;
					out command;
				}
			}

			connect flowSensor.flowSignalOutPort to controller.flowSignalInPort;
			connect pressureSensor.pressureSignalOutPort to controller.pressureSignalInPort;
			connect controller.valveCommandOutPort to dischargeValve.commandInPort;

			requirement flowRateAccuracy : FlowRateAccuracy;
			requirement cavitationPrevention : CavitationPrevention;
			requirement leakPrevention : LeakPrevention;
		}
	}
}
