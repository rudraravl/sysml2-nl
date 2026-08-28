package 'Wedge System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def Force {
		attribute magnitude : ForceValue;
	}

	port def ForceOutPort {
		out item force : Force;
	}
	port def ForceInPort {
		in item force : Force;
	}

	action def AmplifyForce {
		in inputForce : Force;
		out lateralForce : Force;
	}

	action def SplitMaterial {
		in splittingForce : Force;
	}

	part def Wedge {
		attribute angle : AngleValue;
		attribute length : LengthValue;
		attribute thickness : LengthValue;
		attribute materialHardness : Real;
		attribute materialStrength : PressureValue;

		port forceInPort : ~ForceInPort;
		port forceOutPort : ForceOutPort;

		perform action amplifyForce : AmplifyForce {
			in inputForce = forceInPort.force;
			out lateralForce = forceOutPort.force;
		}
	}

	part def AppliedLoad {
		attribute inputForce : ForceValue;
		port forceOutPort : ForceOutPort;
	}

	part def TargetMaterial {
		attribute hardness : Real;
		attribute internalStrength : PressureValue;
		port forceInPort : ~ForceInPort;

		perform action splitMaterial : SplitMaterial {
			in splittingForce = forceInPort.force;
		}
	}

	requirement def WedgeAngleRange {
		doc /* The wedge angle shall be between 5 and 40 degrees for optimal performance. */
		subject wedge : Wedge;
		require constraint { wedge.angle >= 5[deg] and wedge.angle <= 40[deg] }
	}

	requirement def WedgeMaterialStrength {
		doc /* The wedge material strength shall be sufficient to withstand operational forces. */
		subject wedge : Wedge;
		attribute operationalStress : PressureValue;
		require constraint { wedge.materialStrength > operationalStress }
	}

	requirement def ForceAmplification {
		doc /* The wedge shall amplify input force into larger perpendicular forces. */
		subject wedge : Wedge;
		attribute inputForce : ForceValue;
		attribute outputForce : ForceValue;
		require constraint { outputForce > inputForce }
	}

	part wedgeSystem {
		part appliedLoad : AppliedLoad;
		part wedge : Wedge;
		part targetMaterial : TargetMaterial;

		flow of force : Force
			from appliedLoad.forceOutPort.force to wedge.forceInPort.force;

		flow of force : Force
			from wedge.forceOutPort.force to targetMaterial.forceInPort.force;

		requirement wedgeAngleRequirement : WedgeAngleRange {
			subject wedge = wedge;
		}
	}
}
