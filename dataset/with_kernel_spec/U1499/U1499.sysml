package SiphonSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def Fluid;

		port def FluidPort {
			out item fluid : Fluid;
		}

		part def UpperReservoir {
			attribute fluidLevel : LengthValue;
			attribute baseElevation : LengthValue;
			attribute baseArea : AreaValue;
			port fluidOutPort : FluidPort;
		}

		part def LowerReservoir {
			attribute fluidLevel : LengthValue;
			attribute baseElevation : LengthValue;
			attribute baseArea : AreaValue;
			port fluidInPort : ~FluidPort;
		}

		part def Tube {
			attribute diameter : LengthValue;
			attribute apexHeight : LengthValue;
			attribute intakeLevel : LengthValue;
			attribute outletLevel : LengthValue;
			attribute isPrimed : Boolean = false;
			port intakePort : ~FluidPort;
			port outletPort : FluidPort;
		}

		action def PrimeTube {
			in tube : Tube;
			out primed : Boolean;
		}

		action def CalculateFlowRate {
			in heightDifference : LengthValue;
			in tubeDiameter : LengthValue;
			out flowRate : VolumeFlowRateValue;
		}

		action def TransferFluid {
			in flowRate : VolumeFlowRateValue;
			in upperReservoir : UpperReservoir;
			in lowerReservoir : LowerReservoir;
		}

		attribute def StartPrimeSignal;
		attribute def StopSignal;

		state def SiphonStates;

		requirement def SiphonPhysicsRequirement {
			doc "The system shall rely entirely on gravitational potential energy and atmospheric pressure to transfer fluid without mechanical pumps.";
		}

		requirement def PrimingRequirement {
			doc "The siphon tube shall be completely filled with fluid to remove all air before continuous flow can initiate.";
		}

		requirement def AutoStopRequirement {
			doc "The system shall automatically stop flow if the upper reservoir level drops below the tube intake or if the height difference becomes zero.";
		}

		requirement def ManualStopRequirement {
			doc "An operator shall be able to manually stop the siphon flow at any time.";
		}
	}

	package Usages {
		private import Definitions::*;

		part context {
			part upperReservoir : UpperReservoir {
				attribute fluidLevel = 105.0;
				attribute baseElevation = 100.0;
				attribute baseArea = 10.0;
			}

			part tube : Tube {
				attribute diameter = 0.05;
				attribute apexHeight = 106.0;
				attribute intakeLevel = 100.0;
				attribute outletLevel = 85.0;
				attribute isPrimed = false;
			}

			part lowerReservoir : LowerReservoir {
				attribute fluidLevel = 80.0;
				attribute baseElevation = 80.0;
				attribute baseArea = 15.0;
			}

			flow of fluid : Fluid
				from upperReservoir.fluidOutPort.fluid to tube.intakePort.fluid;

			flow of fluid : Fluid
				from tube.outletPort.fluid to lowerReservoir.fluidInPort.fluid;

			attribute currentFlowRate : VolumeFlowRateValue;

			action doPrime : PrimeTube {
				in tube = tube;
				out primed = tube.isPrimed;
			}

			action calculateFlow : CalculateFlowRate {
				in heightDifference = upperReservoir.fluidLevel - lowerReservoir.fluidLevel;
				in tubeDiameter = tube.diameter;
				out flowRate = currentFlowRate;
			}

			action transfer : TransferFluid {
				in flowRate = currentFlowRate;
				in upperReservoir = upperReservoir;
				in lowerReservoir = lowerReservoir;
			}

			state siphonStates : SiphonStates {
				entry; then idle;

				state idle;
				accept StartPrimeSignal
					then priming;

				state priming {
					entry doPrime;
					accept when tube.isPrimed
						then flowing;
				}

				state flowing {
					do calculateFlow;
					do transfer;
					accept when upperReservoir.fluidLevel <= tube.intakeLevel
						then stopped;
					accept when upperReservoir.fluidLevel - lowerReservoir.fluidLevel <= 0
						then stopped;
					accept StopSignal
						then stopped;
				}

				state stopped;
			}

			satisfy siphonPhysicsRequirement : SiphonPhysicsRequirement;
			satisfy primingRequirement : PrimingRequirement;
			satisfy autoStopRequirement : AutoStopRequirement;
			satisfy manualStopRequirement : ManualStopRequirement;
		}
	}
}
