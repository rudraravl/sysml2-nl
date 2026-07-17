package 'Constraints Example-2' {
	private import ISQ::*;
	private import SI::*;
	private import NumericalFunctions::*;
	
	part def Engine;
	part def Transmission;
	
	constraint def MassConstraint {
		attribute partMasses : MassValue[0..*];
		attribute massLimit : MassValue;
			
		sum(partMasses) <= massLimit
	}
	
	part def Vehicle {
		constraint massConstraint : MassConstraint {
			redefines partMasses = (chassisMass, engine.mass, transmission.mass);
			redefines massLimit = 2500[kg];
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
    private import 'Constraints Example-2'::*;
    part testSubject : Engine;
    // TODO(human): define boundary input values for: partMasses, massLimit, chassisMass, mass, mass
    // TODO(human): assert constraint def { testSubject.<attr> <= <limit> }
    // TODO(human): assert constraint massConstraint { testSubject.<attr> <= <limit> }
}
