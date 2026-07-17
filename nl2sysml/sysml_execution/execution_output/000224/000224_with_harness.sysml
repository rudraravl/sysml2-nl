package '12a-Dependency' {
	
	package 'Application Layer';
	package 'Service Layer';
	package 'Data Layer';
	
	dependency Use from 'Application Layer' to 'Service Layer';
	dependency from 'Service Layer' to 'Data Layer';
	
	attribute x;
	attribute y;
	attribute z;
	
	dependency z to x, y;
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import '12a-Dependency'::*;
    // TODO(human): no part def found; cannot instantiate subject
    // TODO(human): define boundary input values for: x, y, z
}
