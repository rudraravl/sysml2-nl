package 'Variation Usages' {
	private import 'Variation Definitions'::*;
	
	part def Vehicle;
	part def Transmission;
	part manualTransmission;
	part automaticTransmission;
	
	abstract part vehicleFamily : Vehicle {
		part engine : EngineChoices[1];
		
		variation part transmission : Transmission[1] {
			variant manualTransmission;
			variant automaticTransmission;
		}
		
		assert constraint {
			(engine == engine::'4cylEngine' and
			 transmission == transmission::manualTransmission) xor
			(engine == engine::'6cylEngine' and 
			 transmission == transmission::automaticTransmission)
		}	
	}
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import 'Variation Definitions'::*;
    private import 'Variation Usages'::*;
    part testSubject : Vehicle;
    // TODO(human): assert constraint assert_constraint_16 { testSubject.<attr> <= <limit> }
}
