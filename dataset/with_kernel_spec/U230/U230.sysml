package 'Obstetrical Forceps System' {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;

	attribute def TractionForce :> ISQ::ForceValue;
	attribute def BladePressure :> ISQ::PressureValue;
	attribute def RotationAngle :> ISQ::PlaneAngleValue;
	attribute def DescentDistance :> ISQ::LengthValue;

	item def FetalHead {
		attribute position : ISQ::LengthValue;
		attribute orientation : ISQ::PlaneAngleValue;
		attribute headSize : ISQ::LengthValue;
	}

	item def BirthCanal {
		attribute descentPath : ISQ::LengthValue;
	}

	port def ForcepsInterface {
		in attribute appliedPressure : BladePressure;
		out attribute traction : TractionForce;
		out attribute rotation : RotationAngle;
	}

	port def LockInterface {
		in attribute engage : Boolean;
		out attribute isEngaged : Boolean;
	}

	part def Blade {
		attribute curvature : ISQ::PlaneAngleValue;
		attribute maxSafePressure : BladePressure = 80[kPa];
		port bladeContact : ForcepsInterface;
	}

	part def Handle {
		attribute gripLength : ISQ::LengthValue;
		port gripPoint;
	}

	part def LockMechanism {
		attribute isEngaged : Boolean = false;
		port leftInterface : LockInterface;
		port rightInterface : LockInterface;
	}

	part def ForcepsHalf {
		part blade : Blade;
		part handle : Handle;
		attribute side : String;
		port lockPort : LockInterface;
	}

	part def ForcepsInstrument {
		part leftHalf : ForcepsHalf { :>> side = "left"; }
		part rightHalf : ForcepsHalf { :>> side = "right"; }
		part lock : LockMechanism;
		connect leftHalf.lockPort to lock.leftInterface;
		connect rightHalf.lockPort to lock.rightInterface;
		connect leftHalf.blade.bladeContact to rightHalf.blade.bladeContact;
		attribute isLocked : Boolean = lock.isEngaged;
	}

	part def Clinician;
	part def MaternalEffort {
		attribute pushingForce : ISQ::ForceValue;
	}

	action def AssessFetalPosition {
		in item fetalHead : FetalHead;
		in item birthCanal : BirthCanal;
		out attribute assessmentComplete : Boolean;
		out attribute forcepsAppropriate : Boolean;
	}

	action def ApplyBlade {
		in item fetalHead : FetalHead;
		in part forcepsHalf : ForcepsHalf;
		out attribute bladeApplied : Boolean;
	}

	action def EngageLock {
		in part forceps : ForcepsInstrument;
		out attribute lockEngaged : Boolean;
	}

	action def RotateHead {
		in item fetalHead : FetalHead;
		in part forceps : ForcepsInstrument;
		in attribute targetRotation : RotationAngle;
		out attribute rotationApplied : Boolean;
		out attribute updatedOrientation : ISQ::PlaneAngleValue;
	}

	action def ApplyTraction {
		in part forceps : ForcepsInstrument;
		in item fetalHead : FetalHead;
		in item birthCanal : BirthCanal;
		in attribute maternalPush : ISQ::ForceValue;
		out attribute tractionForce : TractionForce;
		out attribute descentDistance : DescentDistance;
		out attribute bladePressure : BladePressure;
	}

	action def ReleaseForceps {
		in part forceps : ForcepsInstrument;
		out attribute lockDisengaged : Boolean;
		out attribute bladesRemoved : Boolean;
	}

	action def ForcepsDeliveryProcedure {
		in item fetalHead : FetalHead;
		in item birthCanal : BirthCanal;
		in part forceps : ForcepsInstrument;
		in attribute maternalPush : ISQ::ForceValue;
		out attribute deliveryComplete : Boolean;

		private attribute safePressureLimit : BladePressure = 80[kPa];
		private attribute maxTraction : TractionForce = 50[N];

		action assess : AssessFetalPosition;
		action applyLeftBlade : ApplyBlade {
			in forcepsHalf = forceps.leftHalf;
		}
		action applyRightBlade : ApplyBlade {
			in forcepsHalf = forceps.rightHalf;
		}
		action lockBlades : EngageLock;
		action rotate : RotateHead {
			in targetRotation = 0[deg];
		}
		action traction : ApplyTraction;
		action release : ReleaseForceps;

		first assess;
		then applyLeftBlade;
		then applyRightBlade;
		then lockBlades;
		then rotate;
		then traction;
		then release;

		assert constraint { traction.bladePressure <= safePressureLimit }
		assert constraint { traction.tractionForce <= maxTraction }
	}

	state def ForcepsProcedureStates {
		first start;
		then assessment;
		state assessment;
		transition assessment_done first assessment then application;
		state application;
		transition application_done first application then locking;
		state locking;
		transition locking_done first locking then rotationAndTraction;
		state rotationAndTraction;
		transition traction_done first rotationAndTraction then release;
		state release;
		transition release_done first release then done;
		state done;
	}

	requirement def SafeBladePressureRequirement {
		doc "The pressure applied by forceps blades to the fetal head must not exceed safe limits to prevent trauma.";
		attribute maxPressure : BladePressure = 80[kPa];
	}

	requirement def ControlledTractionRequirement {
		doc "Traction force must be controlled and synchronized with maternal pushing efforts.";
		attribute maxTraction : TractionForce = 50[N];
	}

	requirement def SecureLockRequirement {
		doc "The lock mechanism must securely engage before any traction or rotation is applied.";
	}

	part obstetricalForceps : ForcepsInstrument {
		part :>> leftHalf {
			part :>> blade {
				:>> curvature = 120[deg];
				port :>> bladeContact {
					:>> appliedPressure = 0[kPa];
					:>> traction = 0[N];
					:>> rotation = 0[deg];
				}
			}
			part :>> handle {
				:>> gripLength = 15[cm];
			}
		}
		part :>> rightHalf {
			part :>> blade {
				:>> curvature = 120[deg];
				port :>> bladeContact {
					:>> appliedPressure = 0[kPa];
					:>> traction = 0[N];
					:>> rotation = 0[deg];
				}
			}
			part :>> handle {
				:>> gripLength = 15[cm];
			}
		}
		part :>> lock {
			:>> isEngaged = false;
		}
	}

	part clinician : Clinician;
	part maternalEffort : MaternalEffort {
		:>> pushingForce = 30[N];
	}
	item fetalHead : FetalHead {
		:>> position = 0[cm];
		:>> orientation = 0[deg];
		:>> headSize = 34[cm];
	}
	item birthCanal : BirthCanal {
		:>> descentPath = 12[cm];
	}

	action deliveryProcedure : ForcepsDeliveryProcedure {
		in fetalHead = fetalHead;
		in birthCanal = birthCanal;
		in forceps = obstetricalForceps;
		in maternalPush = maternalEffort.pushingForce;
	}

	requirement safePressureCheck : SafeBladePressureRequirement;
	requirement controlledTractionCheck : ControlledTractionRequirement;
	requirement secureLockCheck : SecureLockRequirement;
}
