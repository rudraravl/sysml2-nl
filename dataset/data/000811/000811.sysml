package UnnasBootTherapeuticSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def CompressionGrade :> Real;
	
	item def ZincOxidePaste {
		attribute concentration : Real;
		attribute viscosity : DynamicViscosityValue;
	}
	
	item def VenousBlood {
		attribute flowRate : VolumeFlowRateValue;
		attribute oxygenSaturation : Real;
	}
	
	item def Exudate {
		attribute volume : VolumeValue;
		attribute absorptionRate : VolumeFlowRateValue;
	}
	
	port def LimbInterfacePort {
		in attribute appliedPressure : PressureValue;
		out attribute tissueResponse : ForceValue;
	}
	
	port def WoundInterfacePort {
		in item paste : ZincOxidePaste;
		out item exudate : Exudate;
	}
	
	part def LowerLeg {
		attribute ankleCircumference : LengthValue;
		attribute calfCircumference : LengthValue;
		attribute edemaVolume : VolumeValue;
		attribute venousPooling : VolumeValue;
		
		part deepVeins {
			attribute bloodVolume : VolumeValue;
			port venousReturn {
				out item blood : VenousBlood;
			}
		}
		
		part superficialVeins {
			attribute incompetentValves : Boolean;
			attribute refluxVolume : VolumeValue;
		}
		
		part calfMuscle {
			attribute contractionForce : ForceValue;
			attribute pumpEfficiency : Real;
		}
		
		part subcutaneousTissue {
			attribute fluidAccumulation : VolumeValue;
		}
		
		port skinSurface : LimbInterfacePort;
	}
	
	part def VenousUlcer {
		attribute area : AreaValue;
		attribute depth : LengthValue;
		attribute healingRate : AreaValue;
		attribute exudateProduction : VolumeFlowRateValue;
		
		port woundBed : WoundInterfacePort;
	}
	
	part def ZincOxideImpregnatedGauze {
		attribute pasteContent : ZincOxidePaste;
		attribute coverage : AreaValue;
		attribute antimicrobialActivity : Real;
		
		port woundContact : WoundInterfacePort;
	}
	
	part def CompressionBandageLayer {
		attribute elasticity : Real;
		attribute width : LengthValue;
		attribute appliedTension : ForceValue;
		attribute wrappingTurns : Integer;
		
		port limbContact : LimbInterfacePort;
	}
	
	part def RigidOuterLayer {
		attribute rigidity : Real;
		attribute thickness : LengthValue;
		attribute counterPressure : PressureValue;
	}
	
	part def UnnasBootDressing {
		doc /* 
		Multi-layer compression dressing consisting of zinc oxide impregnated gauze
		and compression bandages that harden to form a semi-rigid boot.
		*/
		
		attribute totalCompressionGrade : CompressionGrade;
		attribute applicationDate : String;
		attribute wearDuration : DurationValue;
		
		part primaryLayer : ZincOxideImpregnatedGauze {
			attribute :>> pasteContent.concentration = 0.10;
			attribute :>> coverage;
		}
		
		part compressionLayer : CompressionBandageLayer {
			attribute :>> elasticity = 0.30;
			attribute :>> width = 0.10 [m];
			attribute :>> appliedTension;
		}
		
		part outerLayer : RigidOuterLayer {
			attribute :>> rigidity = 0.85;
			attribute :>> thickness = 0.003 [m];
		}
		
		assert constraint compressionGradeConstraint {
			totalCompressionGrade >= 2.0 and totalCompressionGrade <= 3.0
		}
	}
	
	part def Patient {
		attribute ambulationCapacity : Real;
		attribute complianceLevel : Real;
		
		part affectedLimb : LowerLeg {
			attribute :>> ankleCircumference = 0.25 [m];
			attribute :>> calfCircumference = 0.38 [m];
			attribute :>> edemaVolume;
		}
		
		part ulcer : VenousUlcer {
			attribute :>> area;
			attribute :>> depth;
		}
	}
	
	action def ApplyZincGauze {
		in ulcer : VenousUlcer;
		in gauze : ZincOxideImpregnatedGauze;
		out coverage : AreaValue;
		
		assert constraint adequateCoverage {
			coverage >= ulcer.area
		}
	}
	
	action def WrapCompressionBandage {
		in limb : LowerLeg;
		in bandage : CompressionBandageLayer;
		in targetPressure : PressureValue;
		out achievedPressure : PressureValue;
		
		attribute tensionCalculation : ForceValue;
		
		assign tensionCalculation := targetPressure * limb.ankleCircumference * bandage.width;
		assign achievedPressure := tensionCalculation / (bandage.width * limb.ankleCircumference);
	}
	
	action def HardenOuterLayer {
		in outerLayer : RigidOuterLayer;
		in curingTime : DurationValue;
		out finalRigidity : Real;
		
		assign finalRigidity := outerLayer.rigidity;
	}
	
	action def GenerateMusclePumpPressure {
		in calfMuscle : LowerLeg::calfMuscle;
		in bootRigidity : Real;
		out pumpPressure : PressureValue;
		
		attribute effectiveForce : ForceValue;
		attribute contactArea : AreaValue = 0.015 [m^2];
		
		assign effectiveForce := calfMuscle.contractionForce * bootRigidity;
		assign pumpPressure := effectiveForce / contactArea;
	}
	
	action def ReduceVenousHypertension {
		in pumpPressure : PressureValue;
		in baselinePressure : PressureValue;
		out pressureReduction : PressureValue;
		out improvedVenousReturn : VolumeFlowRateValue;
		
		assign pressureReduction := baselinePressure - pumpPressure;
		assign improvedVenousReturn := pressureReduction * 0.05 [m^3/s/Pa];
	}
	
	action def AbsorbExudate {
		in ulcer : VenousUlcer;
		in gauze : ZincOxideImpregnatedGauze;
		out absorbedVolume : VolumeValue;
		
		attribute absorptionCapacity : VolumeValue = 0.00005 [m^3];
		
		assign absorbedVolume := ulcer.exudateProduction * 86400.0 [s];
		
		assert constraint withinCapacity {
			absorbedVolume <= absorptionCapacity
		}
	}
	
	action def PromoteWoundHealing {
		in ulcer : VenousUlcer;
		in zincExposure : Real;
		in compressionTherapy : Boolean;
		out healingRate : AreaValue;
		
		attribute baseHealingRate : AreaValue = 0.00001 [m^2];
		attribute zincFactor : Real = 1.2;
		attribute compressionFactor : Real = 1.5;
		
		decide;
			if compressionTherapy then enhanced;
			else baseline;
		
		action enhanced {
			assign healingRate := baseHealingRate * zincFactor * compressionFactor;
		}
		
		action baseline {
			assign healingRate := baseHealingRate;
		}
	}
	
	action def TherapeuticCycle {
		in patient : Patient;
		in boot : UnnasBootDressing;
		out venousReturnImprovement : VolumeFlowRateValue;
		out edemaReduction : VolumeValue;
		out ulcerHealing : AreaValue;
		
		first start;
		then merge ambulationCycle;
		
		then action generatePressure : GenerateMusclePumpPressure {
			in calfMuscle = patient.affectedLimb.calfMuscle;
			in bootRigidity = boot.outerLayer.rigidity;
			out pumpPressure;
		}
		
		then action reduceHypertension : ReduceVenousHypertension {
			in pumpPressure = generatePressure.pumpPressure;
			in baselinePressure = 8000.0 [Pa];
			out pressureReduction;
			out improvedVenousReturn;
		}
		
		then action absorbFluid : AbsorbExudate {
			in ulcer = patient.ulcer;
			in gauze = boot.primaryLayer;
			out absorbedVolume;
		}
		
		then action healWound : PromoteWoundHealing {
			in ulcer = patient.ulcer;
			in zincExposure = boot.primaryLayer.antimicrobialActivity;
			in compressionTherapy = true;
			out healingRate;
		}
		
		then assign venousReturnImprovement := reduceHypertension.improvedVenousReturn;
		then assign edemaReduction := absorbFluid.absorbedVolume;
		then assign ulcerHealing := healWound.healingRate;
		
		then decide continueTreatment;
			if patient.ulcer.area > 0.0 [m^2] then ambulationCycle;
			else done;
	}
	
	state def BootLifecycleState {
		entry; then unworn;
		
		state unworn;
		transition unworn_to_application
			first unworn
			then application;
		
		state application {
			do action applyGauze : ApplyZincGauze;
			do action wrapBandage : WrapCompressionBandage;
			do action hardenLayer : HardenOuterLayer;
		}
		transition application_to_active
			first application
			then activeTherapy;
		
		state activeTherapy {
			do TherapeuticCycle;
		}
		transition activeTherapy_to_monitoring
			first activeTherapy
			then monitoring;
		
		state monitoring;
		transition monitoring_to_active
			first monitoring
			then activeTherapy;
		
		transition monitoring_to_removal
			first monitoring
			then removal;
		
		state removal;
		transition removal_to_unworn
			first removal
			then unworn;
	}
	
	requirement def VenousReturnEnhancement {
		doc /* 
		The system shall enhance venous return from the lower extremity by providing
		sustained compression that works synergistically with the calf muscle pump.
		*/
		
		subject system : UnnasBootTherapeuticSystem;
		
		require constraint {
			system.patient.affectedLimb.deepVeins.venousReturn.blood.flowRate > 
			0.00001 [m^3/s]
		}
	}
	
	requirement def EdemaReduction {
		doc /* 
		The system shall reduce lower extremity edema through sustained compression
		and improved venous drainage.
		*/
		
		subject limb : LowerLeg;
		
		attribute initialEdema : VolumeValue;
		attribute targetReduction : Real = 0.30;
		
		require constraint {
			limb.edemaVolume <= initialEdema * (1.0 - targetReduction)
		}
	}
	
	requirement def WoundHealingPromotion {
		doc /* 
		The system shall promote venous ulcer healing through zinc oxide's antimicrobial
		properties and compression-induced improvement in tissue perfusion.
		*/
		
		subject ulcer : VenousUlcer;
		
		require constraint {
			ulcer.healingRate > 0.0 [m^2]
		}
	}
	
	requirement def CompressionSafety {
		doc /* 
		The system shall provide therapeutic compression within safe physiological limits
		to avoid arterial compromise.
		*/
		
		subject boot : UnnasBootDressing;
		
		attribute maxSafePressure : PressureValue = 5500.0 [Pa];
		
		require constraint {
			boot.compressionLayer.limbContact.appliedPressure <= maxSafePressure
		}
	}
	
	requirement unnasBootSystemRequirement {
		doc /* 
		The Unna's boot system shall provide sustained graduated compression therapy
		for venous insufficiency and venous leg ulcers by combining zinc oxide-impregnated
		gauze with compression bandaging that hardens into a semi-rigid boot, working
		synergistically with the calf muscle pump during ambulation to enhance venous
		return, reduce edema, and promote wound healing.
		*/
		
		subject system : UnnasBootTherapeuticSystem;
		
		require venousReturnReq : VenousReturnEnhancement {
			subject system = system;
		}
		require edemaReductionReq : EdemaReduction {
			subject limb = system.patient.affectedLimb;
		}
		require woundHealingReq : WoundHealingPromotion {
			subject ulcer = system.patient.ulcer;
		}
		require safetyReq : CompressionSafety {
			subject boot = system.boot;
		}
	}
	
	part def UnnasBootTherapeuticSystem {
		doc /* 
		Complete therapeutic system for treating venous insufficiency and venous leg ulcers
		using an Unna's boot - a multi-layer compression dressing that combines zinc oxide
		paste for wound care with graduated compression that hardens to form a semi-rigid
		boot, enhancing the calf muscle pump mechanism during patient ambulation.
		*/
		
		attribute treatmentDuration : DurationValue = 604800.0 [s];
		attribute targetAnklePressure : PressureValue = 4000.0 [Pa];
		attribute lifecycleState : BootLifecycleState;
		
		part patient : Patient {
			attribute :>> ambulationCapacity = 0.75;
			attribute :>> complianceLevel = 0.90;
			
			part :>> affectedLimb {
				attribute :>> edemaVolume = 0.0008 [m^3];
				attribute :>> venousPooling = 0.0005 [m^3];
			}
			
			part :>> ulcer {
				attribute :>> area = 0.0015 [m^2];
				attribute :>> depth = 0.003 [m];
				attribute :>> exudateProduction = 0.000000005 [m^3/s];
			}
		}
		
		part boot : UnnasBootDressing {
			attribute :>> totalCompressionGrade = 2.5;
			attribute :>> wearDuration = 604800.0 [s];
			
			part :>> primaryLayer {
				attribute :>> coverage = 0.002 [m^2];
				attribute :>> antimicrobialActivity = 0.85;
			}
			
			part :>> compressionLayer {
				attribute :>> appliedTension = 10.0 [N];
				attribute :>> wrappingTurns = 8;
			}
			
			part :>> outerLayer {
				attribute :>> counterPressure = 4000.0 [Pa];
			}
		}
		
		connection woundDressing connect boot.primaryLayer.woundContact to patient.ulcer.woundBed;
		connection compressionInterface connect boot.compressionLayer.limbContact to patient.affectedLimb.skinSurface;
		
		perform action therapy : TherapeuticCycle {
			in patient = patient;
			in boot = boot;
			out venousReturnImprovement;
			out edemaReduction;
			out ulcerHealing;
		}
		
		satisfy unnasBootSystemRequirement by therapy;
	}
}
