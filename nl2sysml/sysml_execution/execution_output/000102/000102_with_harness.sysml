package 'Enumeration Definitions-1' {
	private import ScalarValues::Real;
	
	enum def TrafficLightColor {
		enum green;
		enum yellow;
		enum red;
	}
	
	part def TrafficLight {
		attribute currentColor : TrafficLightColor;
	}
	
	part def TrafficLightGo specializes TrafficLight {
		attribute redefines currentColor = TrafficLightColor::green;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::Real;
    private import 'Enumeration Definitions-1'::*;
    part testSubject : TrafficLight;
    // TODO(human): define boundary input values for: currentColor
}
