package 'Sail Propulsion System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def WindSpeed :> ISQ::SpeedValue;
	attribute def WindDirection :> ISQ::AngleValue;
	attribute def SailAngle :> ISQ::AngleValue;
	attribute def PropulsiveForce :> ISQ::ForceValue;
	attribute def VesselSpeed :> ISQ::SpeedValue;
	attribute def HeelAngle :> ISQ::AngleValue;

	port def WindPort {
		in windSpeed : WindSpeed;
		in windDirection : WindDirection;
	}

	port def ThrustPort {
		out propulsiveForce : PropulsiveForce;
		out lateralForce : ISQ::ForceValue;
	}

	port def ControlPort {
		in commandedAngle : SailAngle;
		out actualAngle : SailAngle;
	}

	port def VesselMotionPort {
		out speed : VesselSpeed;
		out heelAngle : HeelAngle;
	}

	part def SailFabric {
		attribute area : ISQ::AreaValue;
		attribute material : String;
		attribute maxLoad : ISQ::ForceValue;
	}

	part def Mast {
		attribute height : ISQ::LengthValue;
		attribute diameter : ISQ::LengthValue;
		attribute mass : ISQ::MassValue;
	}

	part def Boom {
		attribute length : ISQ::LengthValue;
		attribute mass : ISQ::MassValue;
	}

	part def Rigging {
		attribute tensileStrength : ISQ::ForceValue;
	}

	part def Sail {
		attribute sailArea : ISQ::AreaValue;
		attribute currentAngle : SailAngle;

		port windInput : WindPort;
		port thrustOutput : ThrustPort;
		port control : ControlPort;

		part fabric : SailFabric {
			attribute area = sailArea;
			attribute material = "Dacron";
			attribute maxLoad = 6000.0 [SI::N];
		}

		part mast : Mast {
			attribute height = 15.0 [SI::m];
			attribute diameter = 0.2 [SI::m];
			attribute mass = 60.0 [SI::kg];
		}

		part boom : Boom {
			attribute length = 5.0 [SI::m];
			attribute mass = 20.0 [SI::kg];
		}

		part rigging : Rigging {
			attribute tensileStrength = 10000.0 [SI::N];
		}
	}

	part def Hull {
		attribute displacement : ISQ::MassValue;
		attribute length : ISQ::LengthValue;

		port thrustInput : ThrustPort;
		port motionOutput : VesselMotionPort;
	}

	part def Rudder {
		attribute angle : ISQ::AngleValue;

		port steeringControl {
			in commandedAngle : ISQ::AngleValue;
		}
	}

	action def CaptureWind {
		in windSpeed : WindSpeed;
		in windDirection : WindDirection;
		in sailAngle : SailAngle;
		in sailArea : ISQ::AreaValue;
		out apparentWindSpeed : WindSpeed;
		out angleOfAttack : ISQ::AngleValue;
	}

	action def GenerateAerodynamicForces {
		in apparentWindSpeed : WindSpeed;
		in angleOfAttack : ISQ::AngleValue;
		in sailArea : ISQ::AreaValue;
		out liftForce : ISQ::ForceValue;
		out dragForce : ISQ::ForceValue;
	}

	action def ResolveForceComponents {
		in liftForce : ISQ::ForceValue;
		in dragForce : ISQ::ForceValue;
		in sailAngle : SailAngle;
		out propulsiveForce : PropulsiveForce;
		out lateralForce : ISQ::ForceValue;
		out heelMoment : ISQ::TorqueValue;
	}

	action def AdjustSailTrim {
		in commandedAngle : SailAngle;
		in currentAngle : SailAngle;
		in windSpeed : WindSpeed;
		out newAngle : SailAngle;
	}

	action def PropelVessel {
		in windSpeed : WindSpeed;
		in windDirection : WindDirection;
		in commandedSailAngle : SailAngle;
		in sailArea : ISQ::AreaValue;
		out propulsiveForce : PropulsiveForce;
		out lateralForce : ISQ::ForceValue;
		out currentSailAngle : SailAngle;

		private attribute sailAngle : SailAngle := 45.0;

		first start;
		then merge propulsionLoop;

		then action trimSail : AdjustSailTrim {
			in commandedAngle = commandedSailAngle;
			in currentAngle = sailAngle;
			in windSpeed = PropelVessel::windSpeed;
			out newAngle;
		}

		then assign sailAngle := trimSail.newAngle;

		then action captureWind : CaptureWind {
			in windSpeed = PropelVessel::windSpeed;
			in windDirection = PropelVessel::windDirection;
			in sailAngle = PropelVessel::sailAngle;
			in sailArea = PropelVessel::sailArea;
			out apparentWindSpeed;
			out angleOfAttack;
		}

		then action generateForces : GenerateAerodynamicForces {
			in apparentWindSpeed = captureWind.apparentWindSpeed;
			in angleOfAttack = captureWind.angleOfAttack;
			in sailArea = PropelVessel::sailArea;
			out liftForce;
			out dragForce;
		}

		then action resolveForces : ResolveForceComponents {
			in liftForce = generateForces.liftForce;
			in dragForce = generateForces.dragForce;
			in sailAngle = PropelVessel::sailAngle;
			out propulsiveForce;
			out lateralForce;
			out heelMoment;
		}

		then assign PropelVessel::propulsiveForce := resolveForces.propulsiveForce;
		then assign PropelVessel::lateralForce := resolveForces.lateralForce;
		then assign PropelVessel::currentSailAngle := sailAngle;

		then propulsionLoop;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The sail system shall harness wind energy to generate propulsive force 
		       for vessel movement across water surfaces. */

		subject sailSystem : Sail;

		require constraint generateThrust {
			doc /* The sail shall generate forward thrust by converting wind kinetic energy 
			       into aerodynamic lift and drag forces. */
		}
	}

	requirement def PerformanceRequirement {
		doc /* The sail system shall achieve specified performance under defined wind conditions. */

		require constraint minimumThrust {
			doc /* The sail shall generate minimum 800 N propulsive force at 12 m/s wind speed. */
		}

		require constraint operatingRange {
			doc /* The sail shall operate effectively in wind speeds from 3 m/s to 25 m/s. */
		}

		require constraint efficiency {
			doc /* The sail shall achieve minimum 40% efficiency in converting wind energy to thrust. */
		}
	}

	requirement def SafetyRequirement {
		doc /* The sail system shall maintain structural integrity and safe operation. */

		require constraint structuralIntegrity {
			doc /* Sail fabric and rigging shall withstand loads up to 150% of maximum rated capacity. */
		}

		require constraint heelLimit {
			doc /* Heel angle shall not exceed 35 degrees under normal operating conditions. */
		}

		require constraint emergencyRelease {
			doc /* The sail shall be capable of rapid furling in emergency conditions within 10 seconds. */
		}
	}

	requirement sailSystemRequirements {
		doc /* Top-level requirements for the sail propulsion system. */

		require primaryFunction : PrimaryFunctionRequirement;
		require performance : PerformanceRequirement;
		require safety : SafetyRequirement;
	}

	part def SailVessel {
		part mainSail : Sail {
			attribute sailArea = 40.0 [SI::m^2];
		}

		part hull : Hull {
			attribute displacement = 4000.0 [SI::kg];
			attribute length = 12.0 [SI::m];
		}

		part rudder : Rudder;

		connect mainSail.thrustOutput to hull.thrustInput;

		perform action propulsion : PropelVessel {
			in windSpeed;
			in windDirection;
			in commandedSailAngle;
			in sailArea = mainSail.sailArea;
			out propulsiveForce;
			out lateralForce;
			out currentSailAngle;
		}

		satisfy sailSystemRequirements;
	}

	part vessel : SailVessel;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Sail Propulsion System'::*;

    action orchestrator {
        attribute testWindSpeed : WindSpeed;
        attribute testWindDirection : WindDirection;
        attribute testSailAngle : SailAngle;
        attribute testSailArea : ISQ::AreaValue;
        action actionProbe : CaptureWind {
            in windSpeed = testWindSpeed;
            in windDirection = testWindDirection;
            in sailAngle = testSailAngle;
            in sailArea = testSailArea;
        }
        first actionProbe;
    }
}
