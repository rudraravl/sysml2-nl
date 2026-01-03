package 'Medical Glove System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MaterialThickness :> ISQ::LengthValue;
	attribute def BarrierIntegrity :> Real;
	attribute def TactileSensitivity :> Real;
	attribute def ContaminationLevel :> Real;
	attribute def GripStrength :> Real;
	
	enum def GloveSize {
		small;
		medium;
		large;
		extraLarge;
	}
	
	enum def MaterialType {
		latex;
		nitrile;
		vinyl;
		neoprene;
	}
	
	item def Contaminant {
		attribute pathogenicity : Real;
		attribute concentration : Real;
	}
	
	item def BodyFluid;
	item def ChemicalAgent;
	item def Pathogen :> Contaminant;
	
	part def Hand {
		attribute size : GloveSize;
		port skinInterface;
	}
	
	part def BarrierMaterial {
		attribute thickness : MaterialThickness;
		attribute integrity : BarrierIntegrity;
		attribute materialType : MaterialType;
		attribute permeability : Real;
		port innerSurface;
		port outerSurface;
	}
	
	part def CuffSection {
		attribute length : ISQ::LengthValue;
		attribute rollResistance : Real;
		port wristInterface;
	}
	
	part def TexturedSurface {
		attribute gripCoefficient : GripStrength;
		attribute patternDepth : ISQ::LengthValue;
	}
	
	part def MedicalGlove {
		attribute gloveSize : GloveSize;
		attribute sterile : Boolean;
		attribute powdered : Boolean;
		attribute ambidextrous : Boolean;
		
		part barrier : BarrierMaterial {
			attribute thickness = 0.12[mm];
			attribute integrity = 0.995;
			attribute materialType = MaterialType::nitrile;
			attribute permeability = 0.02;
		}
		
		part cuff : CuffSection {
			attribute length = 280.0[mm];
			attribute rollResistance = 0.85;
		}
		
		part texture : TexturedSurface {
			attribute gripCoefficient = 0.92;
			attribute patternDepth = 0.05[mm];
		}
		
		port innerInterface {
			attribute comfort : Real;
			attribute tactileFeedback : TactileSensitivity;
		}
		
		port outerInterface {
			attribute contamination : ContaminationLevel;
			attribute wetGrip : GripStrength;
		}
		
		connection barrierToInner connect barrier.innerSurface to innerInterface;
		connection barrierToOuter connect barrier.outerSurface to outerInterface;
		connection cuffToWrist connect cuff.wristInterface to innerInterface;
	}
	
	action def AssessContamination {
		in exposureLevel : ContaminationLevel;
		in barrierIntegrity : BarrierIntegrity;
		out riskLevel : Real;
	}
	
	action def PreventTransmission {
		in contaminantPresent : Boolean;
		in barrierQuality : BarrierIntegrity;
		in materialPermeability : Real;
		out protectionProvided : Boolean;
	}
	
	action def MaintainDexterity {
		in thickness : MaterialThickness;
		in texturePattern : Real;
		out tactileResponse : TactileSensitivity;
		out gripQuality : GripStrength;
	}
	
	action def ProvideBarrierProtection {
		in attribute externalExposure : ContaminationLevel;
		in attribute barrierIntegrity : BarrierIntegrity;
		in attribute materialPermeability : Real;
		in attribute materialThickness : MaterialThickness;
		out attribute userProtected : Boolean;
		out attribute functionalityMaintained : Boolean;
		
		first start;
		then merge protectionLoop;
		
		then action assessRisk : AssessContamination {
			in exposureLevel = externalExposure;
			in barrierIntegrity = barrierIntegrity;
			out riskLevel;
		}
		
		then decide;
			if assessRisk.riskLevel > 0.3 then blockContaminant;
			else maintainFunction;
		
		action blockContaminant : PreventTransmission {
			in contaminantPresent = true;
			in barrierQuality = barrierIntegrity;
			in materialPermeability = materialPermeability;
			out protectionProvided;
		}
		then assign userProtected := blockContaminant.protectionProvided;
		then protectionLoop;
		
		action maintainFunction : MaintainDexterity {
			in thickness = materialThickness;
			in texturePattern = 0.92;
			out tactileResponse;
			out gripQuality;
		}
		then assign functionalityMaintained := (maintainFunction.tactileResponse > 0.65 and maintainFunction.gripQuality > 0.80);
		then protectionLoop;
	}
	
	state def GloveOperationalStates {
		in attribute gloveIsSterile : Boolean;
		in attribute currentBarrierIntegrity : BarrierIntegrity;
		out attribute protectionActive : Boolean;
		
		entry; then packaged;
		
		state packaged {
			entry assign gloveIsSterile := true;
		}
		
		transition packaged_to_donning
			first packaged
			accept OpenPackage
			then donning;
		
		state donning;
		
		transition donning_to_inUse
			first donning
			accept GloveDonned
			then inUse;
		
		state inUse {
			entry assign gloveIsSterile := false;
			do action provideProtection : ProvideBarrierProtection;
		}
		
		transition inUse_to_compromised
			first inUse
			if currentBarrierIntegrity < 0.90
			then compromised;
		
		state compromised {
			entry assign protectionActive := false;
		}
		
		transition compromised_to_disposed
			first compromised
			accept RemoveGlove
			then disposed;
		
		transition inUse_to_disposed
			first inUse
			accept RemoveGlove
			then disposed;
		
		state disposed;
	}
	
	action def OpenPackage;
	action def GloveDonned;
	action def RemoveGlove;
	
	part medicalGloveSystem : MedicalGlove {
		attribute gloveSize = GloveSize::medium;
		attribute sterile = true;
		attribute powdered = false;
		attribute ambidextrous = true;
		
		part wearer : Hand {
			attribute size = GloveSize::medium;
		}
		
		perform action protectWearer : ProvideBarrierProtection {
			in externalExposure : ContaminationLevel = 0.75;
			in barrierIntegrity : BarrierIntegrity = barrier.integrity;
			in materialPermeability : Real = barrier.permeability;
			in materialThickness : MaterialThickness = barrier.thickness;
			out userProtected : Boolean;
			out functionalityMaintained : Boolean;
		}
		
		exhibit state gloveLifecycle : GloveOperationalStates {
			in gloveIsSterile = medicalGloveSystem.sterile;
			in currentBarrierIntegrity = medicalGloveSystem.barrier.integrity;
			out protectionActive;
		}
		
		connection handToGlove connect wearer.skinInterface to innerInterface;
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	
	requirement <'GLV-REQ-001'> barrierIntegrityRequirement : PerformanceRequirement {
		doc /* The medical glove barrier shall maintain structural integrity 
		       greater than or equal to 99.5% to prevent pathogen and fluid 
		       penetration during clinical procedures. */
		subject medicalGloveSystem;
		require constraint {
			medicalGloveSystem.barrier.integrity >= 0.995
		}
	}
	
	requirement <'GLV-REQ-002'> tactileSensitivityRequirement : PerformanceRequirement {
		doc /* The medical glove shall provide tactile sensitivity greater than 
		       65% to enable precise manipulation and diagnostic palpation. */
		subject medicalGloveSystem;
		require constraint {
			medicalGloveSystem.innerInterface.tactileFeedback > 0.65
		}
	}
	
	requirement <'GLV-REQ-003'> gripPerformanceRequirement : PerformanceRequirement {
		doc /* The medical glove outer surface shall maintain grip coefficient 
		       greater than 80% in both dry and wet conditions. */
		subject medicalGloveSystem;
		require constraint {
			medicalGloveSystem.outerInterface.wetGrip > 0.80
		}
	}
	
	requirement <'GLV-REQ-004'> materialThicknessRequirement : PerformanceRequirement {
		doc /* The barrier material thickness shall be between 0.08mm and 0.20mm 
		       to balance protection and dexterity. */
		subject medicalGloveSystem;
		require constraint {
			medicalGloveSystem.barrier.thickness >= 0.08[mm] and 
			medicalGloveSystem.barrier.thickness <= 0.20[mm]
		}
	}
	
	requirement <'GLV-REQ-005'> primaryProtectionRequirement : FunctionalRequirement {
		doc /* The medical glove system shall provide a physical barrier between 
		       the wearer and external contaminants including pathogens, body fluids, 
		       and chemical agents while maintaining sufficient tactile sensitivity 
		       and grip for clinical procedures. */
		subject medicalGloveSystem;
		assume constraint {
			medicalGloveSystem.sterile and 
			not medicalGloveSystem.powdered
		}
		require barrierIntegrityRequirement;
		require tactileSensitivityRequirement;
		require gripPerformanceRequirement;
		require materialThicknessRequirement;
	}
	
	requirement <'GLV-REQ-006'> safetyRequirement : SafetyRequirement {
		doc /* The medical glove shall prevent cross-contamination and protect 
		       both healthcare worker and patient from infectious transmission. */
		subject medicalGloveSystem;
		require constraint {
			medicalGloveSystem.barrier.permeability < 0.05
		}
	}
}
