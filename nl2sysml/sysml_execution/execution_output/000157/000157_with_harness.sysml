package MassRollup1 {
	private import NumericalFunctions::*;
	
	part def MassedThing {
		attribute simpleMass :> ISQ::mass; 
		attribute totalMass :> ISQ::mass;
	}
	
	part simpleThing : MassedThing {
		attribute :>> totalMass = simpleMass;
	}
	
	part compositeThing : MassedThing {
		part subcomponents: MassedThing[*];		
		attribute :>> totalMass =
			simpleMass + sum(subcomponents.totalMass); 
	}
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import NumericalFunctions::*;
    private import MassRollup1::*;
    part testSubject : MassedThing;
    // TODO(human): define boundary input values for: simpleMass, totalMass, totalMass
}
