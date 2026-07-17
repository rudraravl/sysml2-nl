package 'Derivation Constraints' {
	private import SI::*;
	private import 'Constraints Example-1'::*;
	
	part vehicle1 : Vehicle {
		attribute totalMass : MassValue;			
		assert constraint {totalMass == chassisMass + engine.mass + transmission.mass}	
	}
	
	part vehicle2 : Vehicle {
		attribute totalMass : MassValue = chassisMass + engine.mass + transmission.mass;
	}
	
	constraint def Dynamics {
		in mass: MassValue;
		in initialSpeed : SpeedValue;
		in finalSpeed : SpeedValue;
		in deltaT : TimeValue;
		in force : ForceValue;

		force * deltaT == mass * (finalSpeed - initialSpeed) and
		mass > 0[kg]
	}
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import SI::*;
    private import 'Constraints Example-1'::*;
    private import 'Derivation Constraints'::*;
    // TODO(human): no part def found; cannot instantiate subject
    // TODO(human): define boundary input values for: totalMass
    // TODO(human): assert constraint assert_constraint_6 { testSubject.<attr> <= <limit> }
    // TODO(human): assert constraint def { testSubject.<attr> <= <limit> }
}
