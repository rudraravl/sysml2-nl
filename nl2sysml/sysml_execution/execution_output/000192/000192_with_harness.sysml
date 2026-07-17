package 'User Keyword Example' {
	private import ScalarValues::Real;
	private import 'Semantic Metadata Example'::*;
	private import RiskMetadata::LevelEnum;
	
	part def Device {
		part battery {
			attribute power : Real;
		}
	}
	
	#scenario def DeviceFailure {
		ref device : Device;
		attribute minPower : Real;
		
		#cause 'battery old' {
			:>> probability = 0.01;			
		}
		
		#causation connect 'battery old' to 'power low';
		
		#situation 'power low' {
			constraint { device.battery.power < minPower }			
		}
		
		#causation connect 'power low' to 'device shutoff';
		
		#failure 'device shutoff' {
			:>> severity = LevelEnum::high;
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::Real;
    private import 'Semantic Metadata Example'::*;
    private import RiskMetadata::LevelEnum;
    private import 'User Keyword Example'::*;
    part testSubject : Device;
    // TODO(human): define boundary input values for: power, minPower
    // TODO(human): constraints found but no boolean expression to assert
}
