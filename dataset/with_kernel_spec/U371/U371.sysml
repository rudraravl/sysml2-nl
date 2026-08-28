package 'Safety Syringe System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def Medication;

		attribute def Volume :> Real;

		attribute def PlungerDepressed;
		attribute def InjectionComplete;
		attribute def ShieldExtended;
		attribute def ShieldLocked;

		enum def NeedleStatus {
			enum exposed;
			enum shielded;
			enum locked;
		}

		part def Barrel {
			attribute capacity : Volume;
			item medication : Medication;
			port medicationOut : Medication;
		}

		part def Plunger {
			port pushIn : Medication;
			attribute depressed : Boolean := false;
		}

		part def Needle {
			attribute sterile : Boolean := true;
			attribute status : NeedleStatus := NeedleStatus::exposed;
			port medicationIn : Medication;
		}

		part def SafetyShield {
			attribute extended : Boolean := false;
			attribute locked : Boolean := false;
			port triggerIn : Medication;
		}

		action def InjectMedication {
			in dose : Volume;
			in med : Medication;
		}

		action def ExtendShield;
		action def LockShield;

		state def SyringeLifecycle;

		part def SafetySyringe {
			attribute prescribedDose : Volume := 5.0;

			part barrel : Barrel;
			part plunger : Plunger;
			part needle : Needle;
			part shield : SafetyShield;

			connect barrel.medicationOut to needle.medicationIn;

			exhibit state syringeLifecycle : SyringeLifecycle {
				entry; then ready;
				state ready;
				accept PlungerDepressed
					do action inject : InjectMedication {
						in dose = prescribedDose;
						in med = barrel.medication;
					}
					then exposed;
				state exposed;
				accept ShieldExtended
					then shielded;
				state shielded;
				accept ShieldLocked
					then locked;
				state locked;
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part safetySyringe : SafetySyringe;
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def PreventNeedlestickInjuries {
			subject syringe : SafetySyringe;
			doc /* The syringe shall prevent needlestick injuries after use. */
			require shieldLocked : syringe.shield.locked == true;
		}

		requirement def PreventReuse {
			subject syringe : SafetySyringe;
			doc /* The syringe shall be rendered unusable after a single injection. */
			require reusePrevented : syringe.shield.locked == true;
		}

		requirement def DeliverPreciseDose {
			subject syringe : SafetySyringe;
			doc /* The syringe shall deliver the prescribed dose accurately. */
			require positiveDose : syringe.prescribedDose > 0;
		}
	}
}
