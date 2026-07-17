package DefaultValueTest {
	
	part def V {
		attribute m default = 10;
		attribute n = 20;
	}
	
	part v1 : V {
		attribute :>> m = 20;
	}
	
	part def W :> V {
		attribute :>> m default = n;
	}
	
	part v2 = new W();
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import DefaultValueTest::*;
    part testSubject : V;
}
