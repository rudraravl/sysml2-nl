package '15_12-Compound Value Type' {
	private import ScalarValues::*;
	private import USCustomaryUnits::'in';
	
	/*
	 * Real world user models would use quantity and vector types
	 * from library models. They are included here for the purpose
	 * of showing how such attribute defs can be defined.
	 */

    attribute def PositionVector {
        attribute x: Real[1];
        attribute y: Real[1];
        attribute z: Real[1];
    }
    
    attribute def LengthValue :> Real;

    attribute def TireInfo {
    	attribute manufacturer: String;
        attribute hubDiameter: LengthValue;
        attribute width: Integer;
        attribute placement: PositionVector[0..1];
    }
    
    attribute frenchTireInfo: TireInfo {
    	attribute :>> manufacturer = "Michelin";
    	attribute :>> hubDiameter = 18.0['in'];
    	attribute :>> width = 245;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import USCustomaryUnits::'in';
    private import '15_12-Compound Value Type'::*;
    // TODO(human): no part def found; cannot instantiate subject
    // TODO(human): define boundary input values for: x, y, z, manufacturer, hubDiameter, width, placement, frenchTireInfo
}
