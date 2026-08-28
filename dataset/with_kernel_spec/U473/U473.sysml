package 'Industrial Fluid Pumping Subsystem' {
	private import ScalarValues::Real;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		item def Fluid;

		port def FluidPort {
			out item fluid : Fluid;
			attribute pressure : Real;
		}

		part def SourceTank {
			port fluidOutPort : FluidPort;
			attribute capacity : Real;
			attribute fluidLevel : Real;
			item storedFluid : Fluid {
				attribute volume : Real;
			}
		}

		part def DestinationTank {
			port fluidInPort : ~FluidPort;
			attribute capacity : Real;
			attribute fluidLevel : Real;
			item storedFluid : Fluid {
				attribute volume : Real;
			}
		}

		action def PumpFluid {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
		}

		state machine def PumpStateMachine {
			state stopped;
			state starting;
			state operating;
			state faulted;

			transition t1 from stopped to starting;
			transition t2 from starting to operating;
			transition t3 from operating to faulted;
			transition t4 from faulted to stopped;
			transition t5 from operating to stopped;
		}

		part def BigPump {
			port suctionPort : ~FluidPort;
			port dischargePort : FluidPort;

			attribute ratedFlowRate : Real;
			attribute maxSafeDischargePressure : Real;
			attribute motorPower : Real;

			perform action pumpFluid : PumpFluid {
				in fluidIn = suctionPort.fluid;
				out fluidOut = dischargePort.fluid;
			}

			state machine pumpStates : PumpStateMachine;
		}

		requirement def FluidTransferRequirement {
			doc /* The pump shall transfer fluid at or above the required flow rate. */
			subject pump : BigPump;
			attribute requiredFlowRate : Real;
			require constraint {
				pump.ratedFlowRate >= requiredFlowRate
			}
		}

		requirement def SafeOperationRequirement {
			doc /* The pump discharge pressure shall not exceed the maximum safe pressure. */
			subject pump : BigPump;
			attribute maxAllowedPressure : Real;
			require constraint {
				pump.maxSafeDischargePressure <= maxAllowedPressure
			}
		}
	}

	package Usages {
		public import Definitions::*;

		part subsystem {
			part sourceTank : SourceTank {
				port :>> fluidOutPort;
				attribute :>> capacity = 10 [m^3];
				attribute :>> fluidLevel = 8.5 [m^3];
			}

			part bigPump : BigPump {
				port :>> suctionPort;
				port :>> dischargePort;
				attribute :>> ratedFlowRate = 0.5 [m^3/s];
				attribute :>> maxSafeDischargePressure = 1000000 [Pa];
				attribute :>> motorPower = 15000 [W];
			}

			part destTank : DestinationTank {
				port :>> fluidInPort;
				attribute :>> capacity = 10 [m^3];
				attribute :>> fluidLevel = 2 [m^3];
			}

			flow of fluid : Fluid
				from sourceTank.fluidOutPort.fluid to bigPump.suctionPort.fluid;

			flow of fluid : Fluid
				from bigPump.dischargePort.fluid to destTank.fluidInPort.fluid;

			require fluidTransfer : FluidTransferRequirement {
				subject :>> pump = bigPump;
				attribute :>> requiredFlowRate = 0.4 [m^3/s];
			}

			require safeOperation : SafeOperationRequirement {
				subject :>> pump = bigPump;
				attribute :>> maxAllowedPressure = 1200000 [Pa];
			}
		}
	}
}
