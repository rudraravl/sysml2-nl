package 'Inclined Plane System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	attribute def FrictionCoefficient :> Real;
	attribute def EfficiencyValue :> Real;
	attribute def MechanicalAdvantageValue :> Real;

	item def LoadMaterial;

	attribute def 'Start Lifting';
	attribute def 'Load at Top';
	attribute def 'Sufficient Force';
	attribute def 'Instability Detected';
	attribute def 'Stabilized';

	port def EffortPort {
		attribute force : ForceValue;
	}
	port def MotionPort {
		attribute position : LengthValue;
		attribute velocity : SpeedValue;
	}
	port def ContactPort {
		attribute normalForce : ForceValue;
		attribute frictionForce : ForceValue;
	}
	port def RampPropertyPort {
		attribute angle : Real;
		attribute frictionCoeff : FrictionCoefficient;
		attribute length : LengthValue;
	}

	action def ApplyEffort {
		in appliedForce : ForceValue;
		out effort : ForceValue;
	}
	action def ResolveForces {
		in weight : ForceValue;
		in angle : Real;
		in frictionCoeff : FrictionCoefficient;
		out gravityComponent : ForceValue;
		out frictionComponent : ForceValue;
		out requiredEffort : ForceValue;
	}
	action def ComputeMotion {
		in netForce : ForceValue;
		in mass : MassValue;
		out acceleration : AccelerationValue;
		out velocity : SpeedValue;
		out position : LengthValue;
	}
	action def LiftLoad {
		in effort : ForceValue;
		out loadLifted : Boolean;
	}

	part def Load {
		attribute mass : MassValue;
		attribute weight : ForceValue;
		attribute position : LengthValue;
		attribute velocity : SpeedValue;
		attribute acceleration : AccelerationValue;
		attribute rampLength : LengthValue;
		item material : LoadMaterial;
		port motionOut : MotionPort;
		port contact : ContactPort;
		exhibit state loadStates {
			entry; then atRest;
			state atRest;
			accept 'Sufficient Force'
				then moving;
			state moving;
			accept when position >= rampLength
				then atTop;
			state atTop;
		}
	}

	part def InclinedPlane {
		attribute length : LengthValue;
		attribute height : LengthValue;
		attribute angle : Real;
		attribute surfaceFriction : FrictionCoefficient;
		port contactSurface : ContactPort;
		port propertyOut : RampPropertyPort;
		exhibit state rampStates {
			entry; then stable;
			state stable;
			accept 'Instability Detected'
				then unstable;
			state unstable;
			accept 'Stabilized'
				then stable;
		}
	}

	part def Operator {
		attribute maxForce : ForceValue;
		attribute appliedForce : ForceValue;
		port effortOut : EffortPort;
		exhibit state operatorStates {
			entry; then idle;
			state idle;
			accept 'Start Lifting'
				then exerting;
			state exerting;
			accept 'Load at Top'
				then idle;
		}
	}

	part def InclinedPlaneSystem {
		part load : Load;
		part ramp : InclinedPlane;
		part operator : Operator;

		action resolveForces : ResolveForces;
		action computeMotion : ComputeMotion;
		action applyEffort : ApplyEffort;
		action liftLoad : LiftLoad;

		flow operator.effortOut.force to load.contact.normalForce;

		exhibit state systemStates {
			entry; then initialized;
			state initialized;
			accept 'Sufficient Force'
				then active;
			state active;
			accept when load.position >= ramp.length
				then completed;
			state completed;
		}
	}

	requirement def MechanicalAdvantageRequirement {
		doc /* The system shall provide a mechanical advantage by reducing the required effort force compared to direct vertical lifting. */
		subject system : InclinedPlaneSystem;
		attribute directLiftForce : ForceValue;
		attribute requiredEffort : ForceValue;
		attribute mechanicalAdvantage : MechanicalAdvantageValue;
		require constraint { requiredEffort < directLiftForce }
		require constraint { mechanicalAdvantage > 1.0 }
	}

	requirement def EfficiencyRequirement {
		doc /* The system shall minimize energy loss due to friction to achieve acceptable efficiency. */
		subject system : InclinedPlaneSystem;
		attribute requiredEffort : ForceValue;
		attribute inputWork : EnergyValue;
		attribute usefulWork : EnergyValue;
		attribute efficiency : EfficiencyValue;
		attribute minEfficiency : EfficiencyValue = 0.70;
		require constraint { efficiency >= minEfficiency }
	}

	requirement def OperatorSafetyRequirement {
		doc /* The operator shall not be required to apply a force exceeding their safe maximum. */
		subject system : InclinedPlaneSystem;
		attribute requiredEffort : ForceValue;
		require constraint { requiredEffort <= system.operator.maxForce }
	}

	requirement def RampStabilityRequirement {
		doc /* The ramp angle shall be stable enough to prevent uncontrolled sliding of the load. */
		subject system : InclinedPlaneSystem;
		attribute frictionCoeff : FrictionCoefficient;
		attribute angle : Real;
		attribute maxAngle : Real = 30.0;
		require constraint { frictionCoeff >= 0.20 }
		require constraint { angle <= maxAngle }
	}

	requirement def <'1'> SystemMechanicalAdvantage :> MechanicalAdvantageRequirement {
		doc /* The inclined plane shall reduce the effort force needed to lift the load to the target height. */
		attribute redefines directLiftForce = system.load.weight;
		attribute redefines mechanicalAdvantage = system.ramp.length / system.ramp.height;
	}

	requirement def <'2'> SystemEfficiency :> EfficiencyRequirement {
		doc /* The system efficiency shall account for frictional losses on the ramp surface. */
		attribute redefines usefulWork = system.load.weight * system.ramp.height;
		attribute redefines inputWork = requiredEffort * system.ramp.length;
		attribute redefines efficiency = usefulWork / inputWork;
	}

	requirement def <'3'> OperatorForceSafety :> OperatorSafetyRequirement {
		doc /* The force required to move the load up the ramp shall not exceed the operator's maximum safe force. */
	}

	requirement def <'4'> RampAngleStability :> RampStabilityRequirement {
		doc /* The ramp shall maintain a stable angle to prevent the load from sliding back when force is removed. */
		attribute redefines frictionCoeff = system.ramp.surfaceFriction;
		attribute redefines angle = system.ramp.angle;
	}

	part inclineSystem : InclinedPlaneSystem {
		part load : Load {
			:>> mass = 100[kg];
			:>> weight = 981[N];
			:>> position = 0[m];
			:>> velocity = 0[m/s];
			:>> acceleration = 0[m/s^2];
			:>> rampLength = 5[m];
		}
		part ramp : InclinedPlane {
			:>> length = 5[m];
			:>> height = 2[m];
			:>> angle = 23.58;
			:>> surfaceFriction = 0.30;
		}
		part operator : Operator {
			:>> maxForce = 600[N];
			:>> appliedForce = 0[N];
		}

		action resolveForces : ResolveForces {
			in :>> weight = load.weight;
			in :>> angle = ramp.angle;
			in :>> frictionCoeff = ramp.surfaceFriction;
			out gravityComponent;
			out frictionComponent;
			out requiredEffort;
		}
		action computeMotion : ComputeMotion {
			in :>> netForce = operator.appliedForce - resolveForces.requiredEffort;
			in :>> mass = load.mass;
			out acceleration;
			out velocity;
			out position;
		}
		action applyEffort : ApplyEffort {
			in :>> appliedForce = operator.appliedForce;
			out effort;
		}
		action liftLoad : LiftLoad {
			in :>> effort = applyEffort.effort;
			out loadLifted;
		}
	}

	requirement systemMechAdv : SystemMechanicalAdvantage {
		subject :>> system = inclineSystem;
	}
	requirement systemEff : SystemEfficiency {
		subject :>> system = inclineSystem;
	}
	requirement operatorSafety : OperatorForceSafety {
		subject :>> system = inclineSystem;
	}
	requirement rampStability : RampAngleStability {
		subject :>> system = inclineSystem;
	}
}
