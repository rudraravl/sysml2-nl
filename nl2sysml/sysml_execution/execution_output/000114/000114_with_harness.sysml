package 'Flow Definition Example' {
	private import 'Port Example'::*;
	
	part def Vehicle;
	
	flow def FuelFlow {
		ref :>> payload : Fuel;
		end port supplierPort : FuelOutPort;
		end port consumerPort : FuelInPort;
	}
	
	part vehicle : Vehicle {
		part tankAssy : FuelTankAssembly;
		part eng : Engine;
		
		flow : FuelFlow of Fuel
		  from tankAssy.fuelTankPort.fuelSupply
			to eng.engineFuelPort.fuelSupply;
			
	} 
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import 'Port Example'::*;
    private import 'Flow Definition Example'::*;
    part testSubject : Vehicle;
}
