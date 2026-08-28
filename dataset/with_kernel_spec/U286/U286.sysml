package 'Low Dead Space Syringe System' {

	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ScalarValues::String;

	package Definitions {

		attribute def Volume :> Real;
		attribute def Pressure :> Real;
		attribute def Length :> Real;
		attribute def Percentage :> Real;

		item def Medication {
			attribute volume : Volume;
		}
		item def AirBubble {
			attribute volume : Volume;
		}

		port def FluidPort {
			inout item fluid : Medication;
		}
		port def NeedlePort {
			out item injectedMedication : Medication;
		}

		part def Barrel {
			attribute material : String = "Medical-grade polypropylene";
			attribute innerDiameter : Length;
			attribute length : Length;
			attribute capacity : Volume;
			port proximalPort : FluidPort;
			port distalPort : FluidPort;
			item containedMedication : Medication {
				attribute volume : Volume;
			}
		}

		part def Plunger {
			attribute material : String = "Medical-grade polypropylene";
			part seal : RubberSeal;
			attribute appliedForce : Pressure;
			port barrelInterface : FluidPort;
		}

		part def RubberSeal {
			attribute material : String = "Synthetic rubber";
			attribute sealIntegrity : Boolean = true;
		}

		part def LowDeadSpaceTip {
			attribute deadSpaceVolume : Volume;
			attribute maxDeadSpaceFraction : Percentage = 0.05;
			port barrelSide : FluidPort;
			port needleSide : FluidPort;
		}

		part def Needle {
			attribute gauge : Real;
			attribute length : Length;
			attribute isSharp : Boolean = true;
			port hubPort : FluidPort;
			port patientPort : NeedlePort;
		}

		part def Syringe {
			part barrel : Barrel;
			part plunger : Plunger;
			part tip : LowDeadSpaceTip;
			part needle : Needle;
		}

		connection def FluidConnection {
			end [1] part fromPort : FluidPort;
			end [1] part toPort : FluidPort;
		}
		connection def PlungerBarrelInterface {
			end [1] part plungerEnd : Plunger;
			end [1] part barrelInner : Barrel;
		}

		action def DrawMedication {
			in medicationIn : Medication;
			out medicationDrawn : Medication;
		}
		action def ExpelAir {
			in medicationWithAir : Medication;
			in air : AirBubble;
			out medicationClean : Medication;
		}
		action def InjectMedication {
			in medicationToInject : Medication;
			out injectedDose : Medication;
		}

		state def SyringeOperationalLifecycle {
			entry; then sterileIdle;
			state sterileIdle;
			transition sterileIdle_to_drawing
				first sterileIdle
				accept DrawStart
				then drawingMedication;
			state drawingMedication;
			transition drawing_to_primed
				first drawingMedication
				accept MedicationDrawn
				then primed;
			state primed;
			transition primed_to_expellingAir
				first primed
				accept ExpelAirStart
				then expellingAir;
			state expellingAir;
			transition expellingAir_to_ready
				first expellingAir
				accept AirExpelled
				then readyForInjection;
			state readyForInjection;
			transition ready_to_injecting
				first readyForInjection
				accept InjectStart
				then injecting;
			state injecting;
			transition injecting_to_complete
				first injecting
				accept DoseAdministered
				then injectionComplete;
			state injectionComplete;
			transition complete_to_disposed
				first injectionComplete
				accept DisposeSignal
				then disposed;
			state disposed;
		}

		attribute def DrawStart;
		attribute def MedicationDrawn;
		attribute def ExpelAirStart;
		attribute def AirExpelled;
		attribute def InjectStart;
		attribute def DoseAdministered;
		attribute def DisposeSignal;

		requirement def SterilityRequirement {
			doc /* The syringe must maintain sterility from manufacture through disposal. */
			subject syringe : Syringe;
		}

		requirement def DosingAccuracyRequirement {
			doc /* The syringe must deliver a highly accurate dose of medication. */
			subject syringe : Syringe;
			attribute targetDose : Volume;
			attribute deliveredDose : Volume;
		}

		requirement def WasteReductionRequirement {
			doc /* The syringe must achieve a waste reduction of at least 80% compared to standard syringes. */
			subject syringe : Syringe;
			attribute standardDeadSpace : Volume;
			attribute lowDeadSpace : Volume;
		}

		requirement def LowDeadSpaceSyringeSystemRequirement {
			doc /* The overall system requirement combining sterility, dosing accuracy, and waste reduction. */
			subject syringe : Syringe;
		}

		#derivation connection def SystemRequirementDerivation {
			end #original r1 : LowDeadSpaceSyringeSystemRequirement;
			end #derive r1_1 : SterilityRequirement;
			end #derive r1_2 : DosingAccuracyRequirement;
			end #derive r1_3 : WasteReductionRequirement;
		}
	}

	package Usages {

		part syringeSystem : Definitions::Syringe {

			part barrel : Definitions::Barrel {
				attribute innerDiameter = 8.0;
				attribute length = 60.0;
				attribute capacity = 3.0;
			}

			part plunger : Definitions::Plunger {
				part seal : Definitions::RubberSeal;
			}

			part tip : Definitions::LowDeadSpaceTip {
				attribute deadSpaceVolume = 0.01;
			}

			part needle : Definitions::Needle {
				attribute gauge = 25.0;
				attribute length = 25.0;
			}

			connection : Definitions::PlungerBarrelInterface
				connect plungerEnd references plunger
				to barrelInner references barrel;

			connection : Definitions::FluidConnection
				connect fromPort references barrel.distalPort
				to toPort references tip.barrelSide;

			connection : Definitions::FluidConnection
				connect fromPort references tip.needleSide
				to toPort references needle.hubPort;

			exhibit state lifecycle : Definitions::SyringeOperationalLifecycle;

			perform action drawMedication : Definitions::DrawMedication {
				in medicationIn = barrel.proximalPort.fluid;
				out medicationDrawn = barrel.containedMedication;
			}

			perform action expelAir : Definitions::ExpelAir {
				in medicationWithAir = barrel.containedMedication;
				in air = barrel.containedMedication;
				out medicationClean = barrel.containedMedication;
			}

			perform action injectMedication : Definitions::InjectMedication {
				in medicationToInject = barrel.containedMedication;
				out injectedDose = needle.patientPort.injectedMedication;
			}
		}

		part satisfactionContext {
			ref :>> syringeSystem;
			satisfy requirement req1 : Definitions::LowDeadSpaceSyringeSystemRequirement by syringeSystem;
			satisfy requirement req1_1 : Definitions::SterilityRequirement by syringeSystem;
			satisfy requirement req1_2 : Definitions::DosingAccuracyRequirement by syringeSystem;
			satisfy requirement req1_3 : Definitions::WasteReductionRequirement by syringeSystem.tip;
			#derivation connection : Definitions::SystemRequirementDerivation {
				end r1 ::> req1;
				end r1_1 ::> req1_1;
				end r1_2 ::> req1_2;
				end r1_3 ::> req1_3;
			}
		}
	}
}
