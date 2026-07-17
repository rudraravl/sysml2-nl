package 'State Definition Example-2' {
	
	attribute def VehicleStartSignal;
	attribute def VehicleOnSignal;
	attribute def VehicleOffSignal;
		
	state def VehicleStates {
		entry; then off;
		
		state off;
		accept VehicleStartSignal 
			then starting;
			
		state starting;
		accept VehicleOnSignal
			then on;
			
		state on;
		accept VehicleOffSignal
			then off;
	}
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import 'State Definition Example-2'::*;

    // TODO(human): no part def found for state machine VehicleStates; cannot instantiate subject
}
