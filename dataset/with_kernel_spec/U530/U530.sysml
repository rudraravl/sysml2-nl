package 'Kearny Air Pump System' {
	private import ScalarValues::*;
	private import SI::*;

	package Definitions {
		item def Fluid;
		item def Air;

		port def FluidPort {
			out item fluid : Fluid;
		}

		port def AirPort {
			out item air : Air;
		}

		part def Person {
			attribute strength :> ISQ::force;
		}

		part def SourceReservoir {
			port fluidOutPort : FluidPort;
			item storedFluid : Fluid;
		}

		part def DestinationTank {
			port fluidInPort : ~FluidPort;
			attribute capacity :> ISQ::volume;
			item storedFluid : Fluid;
		}

		part def CheckValve {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute crackPressure :> ISQ::pressure;
		}

		part def ManualBellows {
			port airOutPort : AirPort;
			attribute maxVolume :> ISQ::volume;
			attribute compressionForce :> ISQ::force;
		}

		part def PressureChamber {
			port fluidInPort : ~FluidPort;
			port airInPort : ~AirPort;
			port fluidOutPort : FluidPort;
			attribute volume :> ISQ::volume;
			attribute currentPressure :> ISQ::pressure;
			item fluid : Fluid;
			item air : Air;
		}

		part def SupplyReservoir {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute volume :> ISQ::volume;
			item storedFluid : Fluid;
		}

		action def CompressBellows {
			in force :> ISQ::force;
			out airPulse : Air;
		}

		action def DrawFluid {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
		}

		action def DischargeFluid {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
		}

		state machine def PumpCycle {
			state Intake;
			state Compression;
			state Discharge;

			transition t1 first Intake then Compression;
			transition t2 first Compression then Discharge;
			transition t3 first Discharge then Intake;
		}

		part def KearnyAirPump {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port airInPort : ~AirPort;

			part bellows : ManualBellows;
			part supplyReservoir : SupplyReservoir;
			part pressureChamber : PressureChamber;
			part inletValve : CheckValve;
			part outletValve : CheckValve;

			flow of air : Air
				from bellows.airOutPort.air to airInPort.air;

			flow of air : Air
				from airInPort.air to pressureChamber.airInPort.air;

			flow of fluid : Fluid
				from fluidInPort.fluid to inletValve.fluidInPort.fluid;

			flow of fluid : Fluid
				from inletValve.fluidOutPort.fluid to supplyReservoir.fluidInPort.fluid;

			flow of fluid : Fluid
				from supplyReservoir.fluidOutPort.fluid to pressureChamber.fluidInPort.fluid;

			flow of fluid : Fluid
				from pressureChamber.fluidOutPort.fluid to outletValve.fluidInPort.fluid;

			flow of fluid : Fluid
				from outletValve.fluidOutPort.fluid to fluidOutPort.fluid;

			attribute flowRate :> ISQ::volumeFlowRate;
			attribute dischargePressure :> ISQ::pressure;
			attribute operationTime :> ISQ::time;

			state machine cycle : PumpCycle;
		}

		requirement def SystemRequirement {
			doc /* Base requirement for the Kearny Air Pump System. */
			subject pump : KearnyAirPump;
		}

		requirement def FlowRateRequirement :> SystemRequirement {
			doc /* The system must achieve a minimum flow rate. */
			attribute actualFlowRate :> ISQ::volumeFlowRate;
			attribute requiredFlowRate :> ISQ::volumeFlowRate;
			require constraint { actualFlowRate >= requiredFlowRate }
		}

		requirement def PressureRequirement :> SystemRequirement {
			doc /* The system must achieve a minimum operating pressure. */
			attribute actualPressure :> ISQ::pressure;
			attribute requiredPressure :> ISQ::pressure;
			require constraint { actualPressure >= requiredPressure }
		}

		requirement def ReliabilityRequirement :> SystemRequirement {
			doc /* The system must operate continuously for at least 2 hours. */
			attribute actualDuration :> ISQ::time;
			attribute requiredDuration :> ISQ::time;
			require constraint { actualDuration >= requiredDuration }
		}
	}

	package Usages {
		part context {
			part operator : Person;

			part source : SourceReservoir;
			part destination : DestinationTank;

			part pump : KearnyAirPump;

			flow of fluid : Fluid
				from source.fluidOutPort.fluid to pump.fluidInPort.fluid;

			flow of fluid : Fluid
				from pump.fluidOutPort.fluid to destination.fluidInPort.fluid;

			requirement flowRateReq : FlowRateRequirement {
				subject = pump;
				attribute actualFlowRate = pump.flowRate;
				attribute requiredFlowRate = 0.5 [L/s];
			}

			requirement pressureReq : PressureRequirement {
				subject = pump;
				attribute actualPressure = pump.dischargePressure;
				attribute requiredPressure = 50 [kPa];
			}

			requirement reliabilityReq : ReliabilityRequirement {
				subject = pump;
				attribute actualDuration = pump.operationTime;
				attribute requiredDuration = 2 [h];
			}
		}
	}
}
