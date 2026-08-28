package SyretteModel {
	import ScalarValues::*;
	import ISQ::*;

	package Units {
		value def Volume :> Real { unit mL; }
		value def Length :> Real { unit mm; }
		value def Pressure :> Real { unit kPa; }
		value def Mass :> Real { unit mg; }
		value def Gauge :> Integer;
		value def DoseAccuracy :> Real { unit percent; }
	}

	package Items {
		item def Medication {
			attribute drugName : String;
			attribute concentration : Mass;
			attribute volume : Units::Volume;
		}

		item def Morphine :> Medication {
			rename drugName = "Morphine";
		}

		item def Atropine :> Medication {
			rename drugName = "Atropine";
		}
	}

	package Interfaces {
		port def MedicationFlow {
			in item med : Items::Medication;
			out item delivered : Items::Medication;
		}

		port def MechanicalPressure {
			in attribute appliedPressure : Units::Pressure;
		}

		port def SterilitySeal {
			in attribute sealed : Boolean;
		}
	}

	package Components {
		part def HousingBody {
			attribute material : String = "Medical-grade plastic";
			attribute sterile : Boolean = true;
		}

		part def Barrel {
			port medOut : Interfaces::MedicationFlow;
			attribute capacity : Units::Volume;
			item storedMedication : Items::Medication[0..1];
		}

		part def Needle {
			port fluidIn : Interfaces::MedicationFlow;
			port fluidOut : Interfaces::MedicationFlow;
			attribute length : Units::Length;
			attribute gauge : Units::Gauge;
			attribute sterile : Boolean = true;
		}

		part def SafetyCap {
			port sealPort : Interfaces::SterilitySeal;
			attribute attached : Boolean = true;
			attribute sterile : Boolean = true;
		}

		part def Plunger {
			port pressurePort : Interfaces::MechanicalPressure;
			attribute position : Real = 0.0;
		}
	}

	package SyrettePlatform {
		part def Syrette {
			part housing : Components::HousingBody;
			part barrel : Components::Barrel;
			part needle : Components::Needle;
			part cap : Components::SafetyCap;
			part plunger : Components::Plunger;

			port patientPort : Interfaces::MedicationFlow;

			attribute doseVolume : Units::Volume;
			attribute needleLength : Units::Length;
			attribute needleGauge : Units::Gauge;

			connection barrelToNeedle connect barrel.medOut to needle.fluidIn;
			connection needleToPatient connect needle.fluidOut to patientPort;
			connection plungerToBarrel connect plunger.pressurePort to barrel.medOut;
			connection capToNeedle connect cap.sealPort to needle.fluidOut;

			state machine def Operation {
				entry; then sealed;

				state sealed {
					entry; 
					assert cap.attached == true;
				}

				transition from sealed to ready
					when cap.attached == false
					do action removeCap { 
						cap.attached = false; 
						needle.sterile = true; 
					}

				state ready {
					entry;
				}

				transition from ready to delivering
					when plunger.position > 0.0
					do action beginDelivery { }

				state delivering {
					entry;
					do action deliverMedication {
						barrel.storedMedication := barrel.storedMedication->excludingHead();
					}
				}

				transition from delivering to empty
					when barrel.storedMedication->isEmpty()
					do action finalize { }

				state empty {
					entry;
				}

				transition from empty to disposed
					when true
					do action dispose { }

				state disposed {
					entry;
				}
			}

			exhibit state machine Operation;
		}

		part def MorphineSyrette :> Syrette {
			rename doseVolume = 1.0 [mL];
			rename needleLength = 25.0 [mm];
			rename needleGauge = 23;

			part barrel : Components::Barrel {
				attribute capacity = 1.0 [mL];
				item storedMedication : Items::Morphine {
					attribute drugName = "Morphine";
					attribute concentration = 10.0 [mg];
					attribute volume = 1.0 [mL];
				}
			}

			part needle : Components::Needle {
				attribute length = 25.0 [mm];
				attribute gauge = 23;
			}
		}

		part def AtropineSyrette :> Syrette {
			rename doseVolume = 2.0 [mL];
			rename needleLength = 35.0 [mm];
			rename needleGauge = 21;

			part barrel : Components::Barrel {
				attribute capacity = 2.0 [mL];
				item storedMedication : Items::Atropine {
					attribute drugName = "Atropine";
					attribute concentration = 2.0 [mg];
					attribute volume = 2.0 [mL];
				}
			}

			part needle : Components::Needle {
				attribute length = 35.0 [mm];
				attribute gauge = 21;
			}
		}
	}

	package Requirements {
		requirement def SterilityRequirement {
			doc /* The Syrette shall maintain sterility of the medication and needle until use. */
			subject syrette : SyrettePlatform::Syrette;
			predicate { syrette.housing.sterile == true and syrette.needle.sterile == true and syrette.cap.sterile == true; }
		}

		requirement def DoseAccuracyRequirement {
			doc /* The Syrette shall deliver the correct dose within specified accuracy. */
			subject syrette : SyrettePlatform::Syrette;
			attribute requiredAccuracy : Units::DoseAccuracy = 5.0 [percent];
			predicate { syrette.doseVolume > 0.0 [mL]; }
		}

		requirement def NeedleProtectionRequirement {
			doc /* The needle shall be protected by the safety cap to prevent accidental injury. */
			subject syrette : SyrettePlatform::Syrette;
			predicate { syrette.cap.attached == true; }
		}

		requirement def SingleUseRequirement {
			doc /* The Syrette shall be a single-use, pre-filled device requiring no assembly. */
			subject syrette : SyrettePlatform::Syrette;
			predicate { syrette.barrel.storedMedication->size() == 1; }
		}

		requirement sterilityReq : SterilityRequirement {
			subject = SyrettePlatform::MorphineSyrette;
		}

		requirement doseAccMorphine : DoseAccuracyRequirement {
			subject = SyrettePlatform::MorphineSyrette;
		}

		requirement needleProtMorphine : NeedleProtectionRequirement {
			subject = SyrettePlatform::MorphineSyrette;
		}

		requirement singleUseMorphine : SingleUseRequirement {
			subject = SyrettePlatform::MorphineSyrette;
		}

		requirement doseAccAtropine : DoseAccuracyRequirement {
			subject = SyrettePlatform::AtropineSyrette;
		}

		requirement needleProtAtropine : NeedleProtectionRequirement {
			subject = SyrettePlatform::AtropineSyrette;
		}

		requirement sterilityAtropine : SterilityRequirement {
			subject = SyrettePlatform::AtropineSyrette;
		}

		requirement singleUseAtropine : SingleUseRequirement {
			subject = SyrettePlatform::AtropineSyrette;
		}
	}

	part morphineSyretteInstance : SyrettePlatform::MorphineSyrette;
	part atropineSyretteInstance : SyrettePlatform::AtropineSyrette;
}
