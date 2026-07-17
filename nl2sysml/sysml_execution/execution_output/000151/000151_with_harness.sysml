package 'Time Slice and Snapshot Example' {
		
	attribute def Date;
	item def Person;
	
	part def Vehicle {
		timeslice assembly;
		
		first assembly then delivery;
		
		snapshot delivery {
			attribute deliveryDate : Date;
		}
		
		then timeslice ownership[0..*] ordered {
			snapshot sale = start;
			
			ref item owner : Person[1];
			
			timeslice driven[0..*] {
				ref item driver : Person[1];
			}
		}
		
		snapshot junked = done;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import 'Time Slice and Snapshot Example'::*;
    part testSubject : Vehicle;
    // TODO(human): define boundary input values for: deliveryDate
}
