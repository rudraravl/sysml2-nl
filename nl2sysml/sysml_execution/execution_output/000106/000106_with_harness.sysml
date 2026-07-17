package 'Items Example' {
	private import ScalarValues::*;
	
	item def Fuel;
	item def Person;
	
	part def Vehicle {
		attribute mass : Real;
		
		ref item driver : Person;

		part fuelTank {
			item fuel: Fuel;
		}		
	}
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import 'Items Example'::*;
    part testSubject : Vehicle;
    // TODO(human): define boundary input values for: mass
}
