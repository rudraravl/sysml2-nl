package 'Packet Usage' {
	public import Packets::*;
	private import ScalarValues::Real;
	
	part packet1: 'Thermal Data Packet';
	part packet2: 'Thermal Data Packet';
	part packet3: 'Thermal Data Packet' {
		attribute 'special data field' redefines 'packet data field'{
			attribute redefines 'user data field' {
				attribute 'special data': Real;
			}
		}
	}
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    public import Packets::*;
    private import ScalarValues::Real;
    private import 'Packet Usage'::*;
    // TODO(human): no part def found; cannot instantiate subject
    // TODO(human): define boundary input values for: special data field, user data field, special data
}
