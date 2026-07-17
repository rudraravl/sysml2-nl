package 'Part Definition Example' {
	private import ScalarValues::*;
	
	part def Vehicle {
		attribute mass : Real;
		attribute status : VehicleStatus;
		
		part eng : Engine;
		
		ref part driver : Person;
	}
	
	attribute def VehicleStatus {
		attribute gearSetting : Integer;
		attribute acceleratorPosition : Real;
	}
	
	part def Engine;	
	part def Person;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import 'Part Definition Example'::*;
    part testSubject : Vehicle;
    // TODO(human): define boundary input values for: mass, status, gearSetting, acceleratorPosition
}
