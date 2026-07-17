package 'Port Conjugation Example' {
	
	attribute def Temp;
	
	part def Fuel;
	
	port def FuelPort {
		attribute temperature : Temp;
		out item fuelSupply : Fuel;
		in item fuelReturn : Fuel;
	}
	
	part def FuelTank {
		port fuelTankPort : FuelPort;
	}
	
	part def Engine {
		port engineFuelPort : ~FuelPort;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import 'Port Conjugation Example'::*;
    part testSubject : Fuel;
    // TODO(human): define boundary input values for: temperature
}
