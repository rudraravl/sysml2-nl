package MassRollup2 {
	private import NumericalFunctions::*;
	
	part def MassedThing {
		attribute simpleMass :> ISQ::mass; 
		attribute totalMass :> ISQ::mass default simpleMass;
	}
	
	part compositeThing : MassedThing {
		part subcomponents: MassedThing[*];		
		attribute :>> totalMass default
			simpleMass + sum(subcomponents.totalMass); 
	}
	
	part filteredMassThing :> compositeThing {
		attribute minMass :> ISQ::mass;		
		attribute :>> totalMass =
			simpleMass + sum(subcomponents.totalMass.?{in p:>ISQ::mass; p >= minMass});
	}

}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import NumericalFunctions::*;
    private import MassRollup2::*;
    part testSubject : MassedThing;
    // TODO(human): define boundary input values for: simpleMass, totalMass, totalMass, minMass, totalMass
}
