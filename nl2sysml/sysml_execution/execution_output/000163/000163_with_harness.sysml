package 'Constraint Assertions-1' {
	private import ISQ::*;
	private import SI::*;
	private import NumericalFunctions::*;
	
	part def Engine;
	part def Transmission;
	
	constraint def MassConstraint {
		in partMasses : MassValue[0..*];
		in massLimit : MassValue;
			
		sum(partMasses) <= massLimit
	}
	
	part def Vehicle {
		assert constraint massConstraint : MassConstraint {
			in partMasses = (chassisMass, engine.mass, transmission.mass);
			in massLimit = 2500[kg];
		}
		
		attribute chassisMass : MassValue;
		
		part engine : Engine {
			attribute mass : MassValue;
		}
		
		part transmission : Engine {
			attribute mass : MassValue;
		}
	}	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import 'Constraint Assertions-1'::*;
    part testSubject : Engine;
    // TODO(human): define boundary input values for: chassisMass, mass, mass
    // TODO(human): assert constraint def { testSubject.<attr> <= <limit> }
    // TODO(human): assert constraint assert_constraint_16 { testSubject.<attr> <= <limit> }
}
