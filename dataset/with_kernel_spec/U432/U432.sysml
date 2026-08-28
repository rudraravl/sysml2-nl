package UnnasBootSystem {
	private import ISQ::PressureValue;
	private import ISQ::DurationValue;
	private import SI::h;
	private import SI::d;
	private import ScalarValues::Boolean;
	private import ScalarValues::Real;

	item def Exudate;
	item def Blood;
	item def ZincOxidePaste;

	part def VenousUlcer {
		out item exudate : Exudate;
		attribute healingProgress : Real;
	}

	part def CalfMuscle {
		action contract {
			out pressure : PressureValue;
		}
	}

	part def DeepVeins {
		item blood : Blood;
		attribute venousPressure : PressureValue;
		action returnBlood {
			in externalPressure : PressureValue;
		}
	}

	part def LowerLeg {
		part venousUlcer : VenousUlcer;
		part deepVeins : DeepVeins;
		part calfMuscle : CalfMuscle;
	}

	part def Patient {
		part lowerLeg : LowerLeg;
	}

	part def PrimaryLayer {
		in item exudate : Exudate;
		item paste : ZincOxidePaste;
		attribute antimicrobial : Boolean = true;
		attribute zincOxideConcentration : Real;
	}

	part def CompressionLayer {
		attribute sustainedPressure : PressureValue;
	}

	part def OuterLayer {
		attribute isRigid : Boolean = true;
		attribute hardeningDuration : DurationValue;
	}

	part def UnnasBootDressing {
		part primaryLayer : PrimaryLayer;
		part compressionLayer : CompressionLayer;
		part outerLayer : OuterLayer;
	}

	part def UnnasBootSystem {
		part patient : Patient;
		part dressing : UnnasBootDressing;

		flow of exudate : Exudate
			from patient.lowerLeg.venousUlcer.exudate to dressing.primaryLayer.exudate;

		state def BootLifecycle {
			in boot : UnnasBootDressing;
			in patient : Patient;
			entry; then application;
			state application;
			accept after 1 [h] then hardening;
			state hardening;
			accept after 24 [h] then activeTherapy;
			state activeTherapy {
				do patient.lowerLeg.calfMuscle.contract;
			}
			accept after 7 [d] then removal;
			state removal;
		}

		perform state lifecycle : BootLifecycle {
			in boot = dressing;
			in patient = patient;
		}
	}

	requirement def HealingRequirement {
		attribute maxHealingTime : DurationValue;
	}

	requirement bootHealingReq : HealingRequirement {
		:>> maxHealingTime = 7 [d];
	}

	requirement def CompressionRequirement {
		attribute minPressure : Real;
		attribute maxPressure : Real;
	}

	requirement bootCompressionReq : CompressionRequirement {
		:>> minPressure = 30;
		:>> maxPressure = 40;
	}

	requirement def AntimicrobialRequirement {
		attribute antimicrobialRequired : Boolean = true;
	}

	requirement antimicrobialReq : AntimicrobialRequirement;
}
