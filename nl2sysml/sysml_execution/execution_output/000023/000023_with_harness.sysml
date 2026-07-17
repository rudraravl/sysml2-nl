package AliasImport {
	package Definitions {
	    part def Vehicle;
	    
	    alias Car for Vehicle;
	}
	
	package Usages {
	    private import Definitions::Car;
	
	    part vehicle : Car;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import AliasImport::*;
    part testSubject : Vehicle;
}
