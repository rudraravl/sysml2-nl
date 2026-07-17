package CarWithEnvelopingShape {
	private import ShapeItems::Box;
	private import SI::mm;

	part def Car {
		doc
		/*
		 * Example car with simple enveloping shape that is a solid box
		 */
	
		item boundingBox : Box [1] :> boundingShapes {
			:>> length = 4800 [mm];
			:>> width  = 1840 [mm];
			:>> height = 1350 [mm];
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ShapeItems::Box;
    private import SI::mm;
    private import CarWithEnvelopingShape::*;
    part testSubject : Car;
}
