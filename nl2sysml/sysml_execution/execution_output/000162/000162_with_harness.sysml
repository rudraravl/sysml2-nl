package 'Analytical Constraints' {
	private import ISQ::*;
	private import 'Calculation Definitions'::*;
	
	constraint def StraightLineDynamicsEquations {
		in p : PowerValue;
		in m : MassValue;
		in dt : TimeValue;
		in x_i : LengthValue;
		in v_i : SpeedValue;
		in x_f : LengthValue;
		in v_f : SpeedValue;
		in a : AccelerationValue;
	
		attribute v_avg : SpeedValue = (v_i + v_f)/2;
		
		a == Acceleration(p, m, v_avg) and
		v_f == Velocity(dt, v_i, a) and
		x_f == Position(dt, x_i, v_avg)
	}
	
	action def StraightLineDynamics {
		in power : PowerValue;
		in mass : MassValue;
		in delta_t : TimeValue;
		in x_in : LengthValue;
		in v_in : SpeedValue;
		out x_out : LengthValue;
		out v_out : SpeedValue;
		out a_out : AccelerationValue;
	
	    assert constraint dynamics : StraightLineDynamicsEquations {
			in p = power;
			in m = mass;
			in dt = delta_t;
			in x_i = x_in;
			in v_i = v_in;
			in x_f = x_out;
			in v_f = v_out;
			in a = a_out;
	    }
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ISQ::*;
    private import 'Calculation Definitions'::*;
    private import 'Analytical Constraints'::*;

    action orchestrator {
        attribute testPower : PowerValue;
        attribute testMass : MassValue;
        attribute testDelta_t : TimeValue;
        attribute testX_in : LengthValue;
        attribute testV_in : SpeedValue;
        action actionProbe : StraightLineDynamics {
            in power = testPower;
            in mass = testMass;
            in delta_t = testDelta_t;
            in x_in = testX_in;
            in v_in = testV_in;
            // TODO(human): unsupported input type for p: unknown (missing declared type)
            // TODO(human): unsupported input type for m: unknown (missing declared type)
            // TODO(human): unsupported input type for dt: unknown (missing declared type)
            // TODO(human): unsupported input type for x_i: unknown (missing declared type)
            // TODO(human): unsupported input type for v_i: unknown (missing declared type)
            // TODO(human): unsupported input type for x_f: unknown (missing declared type)
            // TODO(human): unsupported input type for v_f: unknown (missing declared type)
            // TODO(human): unsupported input type for a: unknown (missing declared type)
        }
        first actionProbe;
    }
}
