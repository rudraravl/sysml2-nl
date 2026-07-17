package AnalysisAnnotation {
	private import ScalarValues::Real;
	private import AnalysisTooling::*;
	private import ISQ::*;
	
	action def ComputeDynamics {
		metadata ToolExecution {
			toolName = "ModelCenter";
			uri = "aserv://localhost/Vehicle/Equation1";
		}
			
		in dt : TimeValue             { @ToolVariable { name = "deltaT"; } }
		in whlpwr : PowerValue        { @ToolVariable { name = "power"; } }
		in Cd : Real                  { @ToolVariable { name = "C_D"; } }
		in Cf: Real                   { @ToolVariable { name = "C_F"; } }
		in tm : MassValue             { @ToolVariable { name = "mass"; } }
		in v_in : SpeedValue          { @ToolVariable { name = "v0"; } }
		in x_in : LengthValue         { @ToolVariable { name = "x0"; } }
		
		out a_out : AccelerationValue { @ToolVariable { name = "a"; } }
		out v_out : SpeedValue        { @ToolVariable { name = "v"; } }
		out x_out : LengthValue       { @ToolVariable { name = "x"; } }
			
	}

}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::Real;
    private import AnalysisTooling::*;
    private import ISQ::*;
    private import AnalysisAnnotation::*;

    action orchestrator {
        attribute testDt : TimeValue;
        attribute testWhlpwr : PowerValue;
        attribute testTm : MassValue;
        attribute testV_in : SpeedValue;
        attribute testX_in : LengthValue;
        action actionProbe : ComputeDynamics {
            in dt = testDt;
            in whlpwr = testWhlpwr;
            in Cd = 0.0;
            in Cf = 0.0;
            in tm = testTm;
            in v_in = testV_in;
            in x_in = testX_in;
        }
        first actionProbe;
    }
}
