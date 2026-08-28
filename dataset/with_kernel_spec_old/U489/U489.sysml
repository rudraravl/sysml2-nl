package 'Drum Pumping Subsystem' {
	private import ScalarValues::*;
	
	item def Fluid;
	
	action def MoveFluid {
		in item fluidIn : Fluid;
		out item fluidOut : Fluid;
	}
	
	part def DrumPump {
		perform action moveFluid : MoveFluid;
	}
	
	part drumPumpingSystem {
		part drumPump : DrumPump;
	}
}
