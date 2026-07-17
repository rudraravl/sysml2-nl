package 'Opaque Action Example' {
	
	part def Sensor {
		attribute ready : ScalarValues::Boolean;
	}
	
	action def UpdateSensors {
		in sensors : Sensor[*];
		language "Alf" 
			/* 
			 * for (sensor in sensors) {
			 *     if (sensor.ready) {
			 *         Update(sensor);
			 *     }
			 * }
			 */
	}
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import 'Opaque Action Example'::*;

    action orchestrator {
        action actionProbe : UpdateSensors {
            // TODO(human): unsupported input type for sensors: Sensor[*] (type is not a primitive, enum, extracted payload def, or known value type)
            // TODO(human): unsupported input type for sensors: Sensor[*] (type is not a primitive, enum, extracted payload def, or known value type)
        }
        first actionProbe;
    }
}
