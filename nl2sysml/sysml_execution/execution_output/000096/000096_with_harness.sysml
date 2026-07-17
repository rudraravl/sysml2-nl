package 'Documentation Example' {
	doc /* This is documentation of the owning 
	     * package.
	     */
	
	part def Automobile {
		doc Document1 /* This documentation of Automobile. */
	}
	
	alias Car for Automobile {
		doc /* This is documentation of the alias. */
	}
	alias Torque for ISQ::TorqueValue;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import 'Documentation Example'::*;
    part testSubject : Automobile;
}
