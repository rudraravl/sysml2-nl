package 'Protective Medical Gown System' {
	private import ScalarValues::*;
	private import SI::Pa;

	item def Contaminant;
	item def BodyFluid :> Contaminant;
	item def Pathogen :> Contaminant;

	enumeration def ProtectionLevel {
		Level1;
		Level2;
		Level3;
		Level4;
	}

	attribute def BarrierEfficiency :> ScalarValues::Real;
	attribute def FluidResistance :> ScalarValues::Real;
	attribute def Breathability :> ScalarValues::Real;

	part def BarrierFabric {
		attribute barrierEfficiency : BarrierEfficiency;
		attribute fluidResistance : FluidResistance;
		attribute breathability : Breathability;
	}

	part def TorsoPanel;
	part def FrontTorsoPanel :> TorsoPanel {
		doc /* Front panel faces the highest risk of exposure, requiring higher fluid resistance. */
	}
	part def BackTorsoPanel :> TorsoPanel {
		doc /* Overlaps at the back to ensure a complete wrap-around shield. */
	}
	part def Sleeve;
	part def ElasticCuff;
	part def TieClosure;

	connection def SleeveAttachment {
		end torso : TorsoPanel;
		end sleeve : Sleeve;
	}
	connection def CuffAttachment {
		end sleeve : Sleeve;
		end cuff : ElasticCuff;
	}
	connection def TieAttachment {
		end panel : TorsoPanel;
		end tie : TieClosure;
	}

	port def ContaminantPort {
		in item contaminant : Contaminant;
	}

	connection def ContaminantTransfer {
		end source : ContaminantPort;
		end target : ContaminantPort;
	}

	action def DonGown {
		doc /* Unpack, insert arms, secure neck and waist ties. */
	}
	action def UseGown {
		doc /* Wear during clinical procedure. */
	}
	action def DoffGown {
		doc /* Untie waist then neck. Peel gown away, rolling contaminated side inward. */
	}
	action def DisposeGown {
		doc /* Place in biohazard container. */
	}

	part def MedicalGown {
		attribute protectionLevel : ProtectionLevel;
		part fabric : BarrierFabric;

		part frontPanel : FrontTorsoPanel;
		part backPanel : BackTorsoPanel;
		part leftSleeve : Sleeve;
		part rightSleeve : Sleeve;
		part leftCuff : ElasticCuff;
		part rightCuff : ElasticCuff;
		part neckTie : TieClosure;
		part waistTie : TieClosure;

		connection leftSleeveAttach : SleeveAttachment connect frontPanel to leftSleeve;
		connection rightSleeveAttach : SleeveAttachment connect frontPanel to rightSleeve;
		connection leftCuffAttach : CuffAttachment connect leftSleeve to leftCuff;
		connection rightCuffAttach : CuffAttachment connect rightSleeve to rightCuff;
		connection neckTieAttach : TieAttachment connect backPanel to neckTie;
		connection waistTieAttach : TieAttachment connect backPanel to waistTie;

		port externalSurface : ContaminantPort;
		port internalSurface : ContaminantPort;

		connection blockContaminant : ContaminantTransfer
			connect externalSurface to internalSurface;

		state machine {
			state packaged {
				doc /* Sterile, sealed in packaging. */
			}
			state donned {
				doc /* Put on by healthcare worker. */
			}
			state inUse {
				doc /* Active during medical procedure; barrier function engaged. */
			}
			state contaminated {
				doc /* Barrier breached or saturated with fluids/pathogens. */
			}
			state doffing {
				doc /* Removal process: rolling contaminated exterior inward. */
			}
			state disposed {
				doc /* Placed in biohazard container. */
			}

			transition donning from packaged to donned;
			transition beginProcedure from donned to inUse;
			transition barrierBreach from inUse to contaminated;
			transition procedureComplete from inUse to doffing;
			transition contaminationDetected from contaminated to doffing;
			transition disposal from doffing to disposed;
		}

		perform action donGown : DonGown;
		perform action useGown : UseGown;
		perform action doffGown : DoffGown;
		perform action disposeGown : DisposeGown;
	}

	part def Level1Gown :> MedicalGown {
		attribute :>> protectionLevel = ProtectionLevel::Level1;
		part redefines fabric {
			attribute :>> barrierEfficiency = 70;
			attribute :>> fluidResistance = 0 [Pa];
			attribute :>> breathability = 5000;
		}
	}
	part def Level2Gown :> MedicalGown {
		attribute :>> protectionLevel = ProtectionLevel::Level2;
		part redefines fabric {
			attribute :>> barrierEfficiency = 80;
			attribute :>> fluidResistance = 2000 [Pa];
			attribute :>> breathability = 4000;
		}
	}
	part def Level3Gown :> MedicalGown {
		attribute :>> protectionLevel = ProtectionLevel::Level3;
		part redefines fabric {
			attribute :>> barrierEfficiency = 90;
			attribute :>> fluidResistance = 5000 [Pa];
			attribute :>> breathability = 3000;
		}
	}
	part def Level4Gown :> MedicalGown {
		attribute :>> protectionLevel = ProtectionLevel::Level4;
		part redefines fabric {
			attribute :>> barrierEfficiency = 99;
			attribute :>> fluidResistance = 20000 [Pa];
			attribute :>> breathability = 2000;
		}
	}

	requirement def BarrierEfficiencyRequirement {
		doc /* The gown fabric must provide a barrier efficiency against contaminants. */
		subject gown : MedicalGown;
	}
	requirement def FluidResistanceRequirement {
		doc /* The gown must resist fluid penetration under pressure. */
		subject gown : MedicalGown;
	}
	requirement def BreathabilityRequirement {
		doc /* The gown must allow moisture vapor transmission for user comfort. */
		subject gown : MedicalGown;
	}
	requirement def ProtectionLevelRequirement {
		doc /* The gown shall be available in four protection levels corresponding to exposure risk. */
		subject gown : MedicalGown;
	}
	requirement def SingleUseRequirement {
		doc /* The gown shall be used only once and then disposed to prevent cross-contamination. */
		subject gown : MedicalGown;
	}

	requirement barrierEfficiencyReq : BarrierEfficiencyRequirement;
	requirement fluidResistanceReq : FluidResistanceRequirement;
	requirement breathabilityReq : BreathabilityRequirement;
	requirement protectionLevelReq : ProtectionLevelRequirement;
	requirement singleUseReq : SingleUseRequirement;

	satisfy barrierEfficiencyReq by Level1Gown, Level2Gown, Level3Gown, Level4Gown;
	satisfy fluidResistanceReq by Level1Gown, Level2Gown, Level3Gown, Level4Gown;
	satisfy breathabilityReq by Level1Gown, Level2Gown, Level3Gown, Level4Gown;
	satisfy protectionLevelReq by Level1Gown, Level2Gown, Level3Gown, Level4Gown;
	satisfy singleUseReq by MedicalGown;

	part def ClinicalEnvironment {
		port contaminantSource : ContaminantPort;
	}

	part 'clinical setup' {
		part environment : ClinicalEnvironment;
		part gown : Level3Gown;
		connection exposure : ContaminantTransfer
			connect environment.contaminantSource to gown.externalSurface;
	}
}
