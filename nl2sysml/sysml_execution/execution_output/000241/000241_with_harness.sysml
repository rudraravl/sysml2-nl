package '15_08-Range Restriction' {
	private import ISQ::*;
	private import SI::*;
	private import '15_01-Constants'::'Mathematical Constants'::pi;
	
	part def HeadLightsTiltKnob {
		attribute headLightsTile : LightBeamTiltAngleValue[1];
	}
	
	attribute def LightBeamTiltAngleValue :> PlaneAngleValue {
		attribute angle: LightBeamTiltAngleValue :>> self {
			doc
			/*
			 * Tilt angle shall be limited to the range between 50 and 80 degrees (inclusive).
			 */
		}
		assert constraint { angle >= 50 ['°'] and angle <= 80 ['°'] }
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ISQ::*;
    private import SI::*;
    private import '15_01-Constants'::'Mathematical Constants'::pi;
    private import '15_08-Range Restriction'::*;
    part testSubject : HeadLightsTiltKnob;
    // TODO(human): define boundary input values for: headLightsTile, angle
    // TODO(human): assert constraint assert_constraint_16 { testSubject.<attr> <= <limit> }
}
