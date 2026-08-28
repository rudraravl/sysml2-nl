package 'Manual Hand Pump System' {
	private import SI::*;
	private import ISQ::*;
	private import ScalarValues::*;

	item def Fluid;

	port def FluidPort {
		in item fluidIn : Fluid;
		out item fluidOut : Fluid;
	}

	part def CheckValve {
		attribute crackingPressure : PressureValue;
		attribute isOpen : Boolean = false;
		port inlet : FluidPort;
		port outlet : FluidPort;
		perform action openValve;
		perform action closeValve;
	}

	part def HandleAssembly {
		attribute appliedForce : ForceValue;
		attribute strokeLength : LengthValue;
		perform action pullUp;
		perform action pushDown;
	}

	part def Piston {
		attribute position : LengthValue;
		perform action moveUp;
		perform action moveDown;
	}

	part def PumpCylinder {
		attribute internalPressure : PressureValue;
		attribute chamberVolume : VolumeValue;
		port inletPort : FluidPort;
		port outletPort : FluidPort;
		part piston : Piston;
	}

	part def HandPump {
		port pumpInlet : FluidPort;
		port pumpOutlet : FluidPort;

		part handle : HandleAssembly;
		part cylinder : PumpCylinder;
		part inletValve : CheckValve {
			attribute :>> crackingPressure = 5000[Pa];
		}
		part outletValve : CheckValve {
			attribute :>> crackingPressure = 20000[Pa];
		}

		flow from pumpInlet.fluidIn to cylinder.inletPort.fluidIn;
		flow from cylinder.outletPort.fluidOut to pumpOutlet.fluidOut;

		state machine pumpCycle {
			state idle {
				entry action {
					inletValve.isOpen = false;
					outletValve.isOpen = false;
				}
			}
			state upstroke {
				entry action {
					inletValve.isOpen = true;
					outletValve.isOpen = false;
				}
			}
			state downstroke {
				entry action {
					inletValve.isOpen = false;
					outletValve.isOpen = true;
				}
			}
			transition from idle to upstroke guard handle.appliedForce < 0[N];
			transition from upstroke to downstroke guard handle.appliedForce > 0[N];
			transition from downstroke to idle guard handle.appliedForce == 0[N];
			transition from downstroke to upstroke guard handle.appliedForce < 0[N];
		}
	}

	part def FluidReservoir {
		attribute fluidVolume : VolumeValue;
		port reservoirPort : FluidPort;
	}

	part def DischargeManifold {
		attribute outputPressure : PressureValue;
		port manifoldPort : FluidPort;
	}

	part def ManualPumpSystem {
		part reservoir : FluidReservoir;
		part pump : HandPump;
		part manifold : DischargeManifold;

		flow from reservoir.reservoirPort.fluidOut to pump.pumpInlet.fluidIn;
		flow from pump.pumpOutlet.fluidOut to manifold.manifoldPort.fluidIn;
	}

	requirement def PressureDeliveryRequirement {
		doc /* The pump must deliver fluid at or above a minimum pressure. */
		subject pump : HandPump;
		attribute minPressure : PressureValue;
		require constraint {
			pump.cylinder.internalPressure >= minPressure
		}
	}

	requirement def OperatingForceRequirement {
		doc /* The pump must be operable with a limited human force. */
		subject handle : HandleAssembly;
		attribute maxForce : ForceValue;
		require constraint {
			handle.appliedForce <= maxForce
		}
	}

	requirement def CrackingPressureRequirement {
		doc /* Each check valve must open only when cracking pressure is overcome. */
		subject valve : CheckValve;
		attribute requiredCrackingPressure : PressureValue;
		require constraint {
			valve.crackingPressure == requiredCrackingPressure
		}
	}

	requirement handPumpSpecification {
		doc /* Overall manual hand pump system requirements. */
		subject system : ManualPumpSystem;
		requirement outletPressure : PressureDeliveryRequirement {
			subject = system.pump;
			attribute :>> minPressure = 20000[Pa];
		}
		requirement userForceLimit : OperatingForceRequirement {
			subject = system.pump.handle;
			attribute :>> maxForce = 150[N];
		}
		requirement inletValveSpec : CrackingPressureRequirement {
			subject = system.pump.inletValve;
			attribute :>> requiredCrackingPressure = 5000[Pa];
		}
		requirement outletValveSpec : CrackingPressureRequirement {
			subject = system.pump.outletValve;
			attribute :>> requiredCrackingPressure = 20000[Pa];
		}
	}
}
