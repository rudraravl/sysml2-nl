package RiskMetadataExample {
	private import RiskMetadata::*;
	private import RiskLevelEnum::*;
	
    part engine4cyl{
        @Risk {
            totalRisk = high;
            technicalRisk = medium;
            scheduleRisk = medium;
        }
        @Risk {
        	totalRisk { 
        		probability = 0.3;
        		impact = 0.7;
        	}        	
        }
    }
        
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;
    private import RiskMetadataExample::*;
    part testSubject = engine4cyl;
}
