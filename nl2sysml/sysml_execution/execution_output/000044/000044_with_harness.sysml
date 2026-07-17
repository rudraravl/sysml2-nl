package Packets {
	private import ScalarValues::*;
	private import Time::DateTime;
	
	attribute 'packet header' { }
	
	attribute 'packet data field' {	
		attribute 'packet secondary header' redefines 'packet header';
		attribute 'user data field';
	}
	
	part def 'Data Packet' {
		attribute 'packet primary header' redefines 'packet header' {
			attribute 'packet version number': Integer;
			attribute 'packet identification': String;
			attribute 'packet data length': Integer;
		}
		attribute redefines 'packet data field';
	}
	
	part def 'Thermal Data Packet' :> 'Data Packet' {
		attribute 'packet data field' redefines Packets::'packet data field'{
			attribute 'packet secondary header' redefines 'packet header' {
				attribute 'packet timestamp': DateTime;
				attribute 'telemetry packet type': String;
			}
			
			attribute 'user data field' redefines Packets::'packet data field'::'user data field' {
				attribute timestamp: DateTime;
				attribute temperature: Real;
			}
		}
	}
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import Time::DateTime;
    private import Packets::*;
    part testSubject : 'Data Packet';
    // TODO(human): define boundary input values for: packet header, packet data field, packet secondary header, user data field, packet primary header, packet version number, packet identification, packet data length
}
