package 'Stirrup Pump Firefighting System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;

	attribute def Volume;
	attribute def Pressure;
	attribute def Force;

	item def Water {
		attribute pressure : Pressure;
		attribute volume : Volume;
	}

	port def WaterOutPort {
		out item water : Water;
	}

	port def WaterInPort {
		in item water : Water;
	}

	part def CheckValve {
		port inlet : WaterInPort;
		port outlet : WaterOutPort;
		attribute isOpen : Boolean;
	}

	part def FluidReservoir {
		attribute capacity : Volume;
		attribute currentLevel : Volume;
		port waterOut : WaterOutPort;
		item storedWater : Water;
	}

	part def DeliveryHose {
		port waterIn : WaterInPort;
		port nozzleOut : WaterOutPort;
		attribute length : Real;
	}

	part def StirrupPump {
		port reservoirIn : WaterInPort;
		port hoseOut : WaterOutPort;

		part footplate;
		part tHandle;
		part piston;
		part cylinder;
		part inletValve : CheckValve;
		part outletValve : CheckValve;
		item chamberWater : Water;

		connect reservoirIn to inletValve.inlet;
		connect outletValve.outlet to hoseOut;

		state def PumpCycle {
			state intakeStroke {
				entry action {
					inletValve.isOpen = true;
					outletValve.isOpen = false;
				}
			}
			state dischargeStroke {
				entry action {
					inletValve.isOpen = false;
					outletValve.isOpen = true;
				}
			}
			transition from intakeStroke to dischargeStroke;
			transition from dischargeStroke to intakeStroke;
		}

		perform action pumpOperation : PumpCycle;
	}

	part def StirrupPumpSystem {
		part reservoir : FluidReservoir;
		part pump : StirrupPump;
		part hose : DeliveryHose;

		connect reservoir.waterOut to pump.reservoirIn;
		connect pump.hoseOut to hose.waterIn;

		flow of water : Water from reservoir.waterOut.water to pump.reservoirIn.water;
		flow of water : Water from pump.hoseOut.water to hose.waterIn.water;
	}

	requirement def FirefightingCapability {
		subject pump : StirrupPump;
		objective {
			doc "The pump shall draw water from a local source and deliver it at high pressure to extinguish fires.";
		}
	}

	requirement def ManualOperation {
		subject pump : StirrupPump;
		objective {
			doc "An operator shall stand on the footplate and pump the T-handle up and down to drive the piston within the cylinder.";
		}
	}

	requirement def TwoStrokeCycle {
		subject pump : StirrupPump;
		objective {
			doc "The pump shall operate on a two-stroke cycle controlled by two one-way check valves, with the intake stroke drawing water from the reservoir and the discharge stroke expelling pressurized water into the delivery hose.";
		}
	}

	requirement def SteadyFlow {
		subject system : StirrupPumpSystem;
		objective {
			doc "The system shall repeat the pump cycle continuously to generate a steady flow of water at the delivery hose nozzle.";
		}
	}

	part systemInstance : StirrupPumpSystem;

	satisfy FirefightingCapability by systemInstance.pump;
	satisfy ManualOperation by systemInstance.pump;
	satisfy TwoStrokeCycle by systemInstance.pump;
	satisfy SteadyFlow by systemInstance;
}
