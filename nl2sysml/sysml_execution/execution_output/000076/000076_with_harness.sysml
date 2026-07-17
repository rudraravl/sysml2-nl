package TextualRepresentationTest {
	private import ScalarValues::Real;
	
	item def C {
	    attribute x: Real;
	    assert constraint x_constraint {
		    rep inOCL language "ocl" 
		        /* self.x > 0.0 */
	    }
	}
	
	action def setX {
		in c : C;
		in newX : Real;
		
	    language "alf" 
	        /* c.x = newX;
	         * WriteLine("Set new x");
	         */
	}
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::Real;
    private import TextualRepresentationTest::*;

    action orchestrator {
        item testC : C {
            attribute x = 0.0;
        }
        action actionProbe : setX {
            in c = testC;
            in newX = 0.0;
        }
        first actionProbe;
    }
}
