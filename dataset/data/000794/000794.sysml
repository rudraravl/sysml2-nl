package TongueDepressorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SterilityStatus;
	attribute def MaterialComposition;
	
	item def WoodMaterial :> MaterialComposition {
		attribute density : DensityValue;
		attribute grainPattern : String;
		attribute moistureLevel : Real;
	}
	
	part def TongueDepressor {
		attribute overallLength : LengthValue = 150[mm];
		attribute overallWidth : LengthValue = 18[mm];
		attribute overallThickness : LengthValue = 2[mm];
		attribute totalMass : MassValue = 5[g];
		attribute isSterile : Boolean = true;
		
		part blade {
			attribute bladeLength : LengthValue = 95[mm];
			attribute bladeWidth : LengthValue = 18[mm];
			attribute surfaceSmooth : Boolean = true;
			attribute contactArea : AreaValue = 1710[mm^2];
			port contactSurface;
		}
		
		part handle {
			attribute handleLength : LengthValue = 55[mm];
			attribute handleWidth : LengthValue = 18[mm];
			attribute textured : Boolean = false;
			port gripSurface;
		}
		
		part material : WoodMaterial {
			attribute :>> density = 580[kg/(m^3)];
			attribute :>> grainPattern = "longitudinal";
			attribute :>> moistureLevel = 7.5;
		}
		
		port tongueInterface;
		port handInterface;
	}
	
	part def Clinician {
		port hand;
		attribute gripForce : ForceValue;
	}
	
	part def Patient {
		port mouth;
		
		part tongue {
			attribute currentPosition : String;
			attribute flexibility : Real;
		}
		
		part oralCavity {
			attribute visibilityLevel : Real;
		}
		
		part throat {
			attribute accessibilityLevel : Real;
		}
	}
	
	action def PositionDepressor {
		in depressor : TongueDepressor;
		in targetArea : String;
		out isPositioned : Boolean;
	}
	
	action def ApplyDownwardPressure {
		in appliedForce : ForceValue;
		in bladeArea : AreaValue;
		out contactPressure : PressureValue;
		out tongueDepressed : Boolean;
	}
	
	action def HoldTongueDown {
		in sustainedForce : ForceValue;
		in holdDuration : TimeValue;
		out positionMaintained : Boolean;
	}
	
	action def VisuallyExamine {
		in targetStructure : String;
		out examinationData : String;
		out examinationComplete : Boolean;
	}
	
	action def WithdrawDepressor {
		in depressor : TongueDepressor;
		out isRemoved : Boolean;
	}
	
	action def ConductOralExamination {
		first start;
		
		then action checkReadiness {
			out depressorSterile : Boolean;
			out patientReady : Boolean;
		}
		
		then decide;
			if checkReadiness.depressorSterile and checkReadiness.patientReady 
				then proceedExamination;
			if not (checkReadiness.depressorSterile and checkReadiness.patientReady) 
				then cancelExamination;
		
		action proceedExamination {
			first action position : PositionDepressor {
				in targetArea = "posterior_tongue";
				out isPositioned;
			}
			
			then action applyPressure : ApplyDownwardPressure {
				in appliedForce = 2.5[N];
				in bladeArea = 1710[mm^2];
				out contactPressure;
				out tongueDepressed;
			}
			
			then merge maintainLoop;
			
			action hold : HoldTongueDown {
				in sustainedForce = 2.5[N];
				in holdDuration = 20[s];
				out positionMaintained;
			}
			
			then maintainLoop;
			
			then action examine : VisuallyExamine {
				in targetStructure = "oropharynx";
				out examinationData;
				out examinationComplete;
			}
			
			then decide;
				if examine.examinationComplete then withdraw;
				if not examine.examinationComplete then hold;
			
			action withdraw : WithdrawDepressor {
				out isRemoved;
			}
			
			then finishExamination;
		}
		
		action cancelExamination;
		
		action finishExamination;
		
		then done;
	}
	
	state def DepressorState {
		entry; then packaged;
		
		state packaged {
			entry assign sterileCondition = true;
		}
		accept at packageOpened;
		then ready;
		
		state ready;
		accept at beginUse;
		then active;
		
		state active {
			state positioning;
			then pressing;
			
			state pressing;
			then holding;
			
			state holding;
			then examining;
			
			state examining;
		}
		accept at endUse;
		then discarded;
		
		state discarded {
			entry assign sterileCondition = false;
		}
	}
	
	part oralExaminationSystem {
		attribute sterileCondition : Boolean;
		
		part clinician : Clinician;
		part patient : Patient;
		part depressor : TongueDepressor {
			exhibit state lifecycle : DepressorState;
		}
		
		connection clinicianGrip 
			connect clinician.hand to depressor.handInterface;
		
		connection tongueContact 
			connect depressor.tongueInterface to patient.mouth;
		
		perform action examination : ConductOralExamination;
	}
	
	requirement def SafetyRequirement;
	requirement def HygieneRequirement;
	requirement def StructuralRequirement;
	requirement def FunctionalRequirement;
	
	requirement <'TD-REQ-001'> materialSafety : SafetyRequirement {
		doc /* The tongue depressor shall be manufactured from medical-grade, 
		        non-toxic wood material safe for oral contact. */
		
		subject depressor : TongueDepressor;
		
		require constraint {
			depressor.material.density >= 500[kg/(m^3)] and
			depressor.material.density <= 650[kg/(m^3)]
		}
	}
	
	requirement <'TD-REQ-002'> sterilityControl : HygieneRequirement {
		doc /* The tongue depressor shall be sterile when packaged and shall 
		        be disposed of after single use to prevent cross-contamination. */
		
		subject depressor : TongueDepressor;
		
		assume constraint {
			depressor.lifecycle.sterileCondition = true
		}
		
		require constraint singleUseDisposal {
			depressor.lifecycle.discarded implies 
				not depressor.lifecycle.packaged
		}
	}
	
	requirement <'TD-REQ-003'> structuralStrength : StructuralRequirement {
		doc /* The tongue depressor shall withstand applied forces up to 5N 
		        without fracturing or splintering during normal use. */
		
		subject depressor : TongueDepressor;
		
		require constraint {
			depressor.blade.surfaceSmooth = true and
			depressor.overallThickness >= 1.8[mm]
		}
	}
	
	requirement <'TD-REQ-004'> effectiveTongueDepression : FunctionalRequirement {
		doc /* The tongue depressor shall provide adequate contact area and 
		        mechanical advantage to effectively depress the tongue and 
		        enable clear visualization of oral and pharyngeal structures. */
		
		subject system : oralExaminationSystem;
		
		require constraint {
			system.depressor.blade.contactArea >= 1500[mm^2] and
			system.depressor.overallLength >= 140[mm]
		}
		
		require examination : ConductOralExamination;
	}
	
	requirement primarySystemFunction {
		doc /* The primary function of the tongue depressor system is to 
		        temporarily displace the patient's tongue in a downward and 
		        forward direction, thereby providing the clinician with 
		        unobstructed visual and physical access to the oral cavity, 
		        oropharynx, and associated anatomical structures for 
		        diagnostic examination and assessment. */
		
		assume constraint patientCooperation {
			oralExaminationSystem.patient.tongue.flexibility >= 0.6
		}
		
		require materialSafety;
		require sterilityControl;
		require structuralStrength;
		require effectiveTongueDepression;
	}
}
