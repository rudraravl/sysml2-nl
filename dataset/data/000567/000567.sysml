package 'Caustic Pencil System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ChemicalConcentration {
		attribute value : Real;
		attribute unit : String;
	}
	
	item def SilverNitrate {
		attribute concentration : ChemicalConcentration;
		attribute purity : Real;
	}
	
	item def TissueType {
		attribute cellType : String;
		attribute sensitivity : Real;
	}
	
	attribute def ApplicationForce :> ISQ::force;
	attribute def ApplicationDuration :> ISQ::time;
	attribute def TreatmentDepth :> ISQ::length;
	
	part def SilverNitrateTip {
		attribute activeAgent : SilverNitrate;
		port applicatorSurface;
	}
	
	part def ProtectiveHolder {
		attribute material : String;
		port gripSurface;
		port tipMounting;
	}
	
	part def CausticPencil {
		part tip : SilverNitrateTip {
			attribute activeAgent : SilverNitrate {
				attribute concentration : ChemicalConcentration {
					attribute value = 95.0;
					attribute unit = "percent";
				}
				attribute purity = 0.95;
			}
		}
		
		part holder : ProtectiveHolder {
			attribute material = "plastic";
		}
		
		connection tipToHolder connect tip to holder;
		
		perform action treatTissue[*] ordered;
	}
	
	action def PrepareApplication {
		in targetTissue : TissueType;
		out readyForApplication : Boolean;
	}
	
	action def ApplyCausticAgent {
		in force : ApplicationForce;
		in duration : ApplicationDuration;
		in tissue : TissueType;
		out depth : TreatmentDepth;
		out chemicalTransferred : Real;
	}
	
	action def CauterizeTissue {
		in chemicalAmount : Real;
		in tissueType : TissueType;
		out cauterizationDepth : TreatmentDepth;
		out proteinCoagulation : Boolean;
	}
	
	action def MonitorTreatment {
		in currentDepth : TreatmentDepth;
		in targetDepth : TreatmentDepth;
		out treatmentComplete : Boolean;
	}
	
	action def TissueTreatment {
		first start;
		
		then action prepare : PrepareApplication {
			in targetTissue : TissueType;
			out readyForApplication : Boolean;
		}
		
		then merge continueTreatment;
		
		then action apply : ApplyCausticAgent {
			in force : ApplicationForce;
			in duration : ApplicationDuration;
			in tissue : TissueType = prepare.targetTissue;
			out depth : TreatmentDepth;
			out chemicalTransferred : Real;
		}
		
		then action cauterize : CauterizeTissue {
			in chemicalAmount : Real = apply.chemicalTransferred;
			in tissueType : TissueType = prepare.targetTissue;
			out cauterizationDepth : TreatmentDepth;
			out proteinCoagulation : Boolean;
		}
		
		then action monitor : MonitorTreatment {
			in currentDepth : TreatmentDepth = cauterize.cauterizationDepth;
			in targetDepth : TreatmentDepth;
			out treatmentComplete : Boolean;
		}
		
		then decide;
			if monitor.treatmentComplete then endTreatment;
			if not monitor.treatmentComplete then continueTreatment;
		
		action endTreatment;
		then done;
	}
	
	state def CausticPencilStates {
		entry; then idle;
		
		state idle;
		
		transition idle_to_active
			first idle
			accept ApplicationStartEvent
			then active;
		
		state active {
			state applying {
				do action applyAgent : ApplyCausticAgent;
			}
			
			state cauterizing {
				do action cauterizeTissue : CauterizeTissue;
			}
			
			transition applying_to_cauterizing
				first applying
				then cauterizing;
		}
		
		transition active_to_idle
			first active
			accept ApplicationEndEvent
			then idle;
		
		state stored;
		
		transition idle_to_stored
			first idle
			accept StorageEvent
			then stored;
	}
	
	event ApplicationStartEvent;
	event ApplicationEndEvent;
	event StorageEvent;
	
	part causticPencilInstance : CausticPencil {
		exhibit state pencilBehavior : CausticPencilStates;
	}
	
	requirement def MedicalDeviceRequirement;
	
	requirement <'1'> silverNitrateConcentrationRequirement : MedicalDeviceRequirement {
		doc /* The silver nitrate concentration shall be between 75% and 95% for effective cauterization. */
		
		subject pencil : CausticPencil;
		
		require constraint {
			pencil.tip.activeAgent.concentration.value >= 75.0 and
			pencil.tip.activeAgent.concentration.value <= 95.0
		}
	}
	
	requirement <'2'> safeApplicationRequirement : MedicalDeviceRequirement {
		doc /* The caustic pencil shall provide controlled application to prevent excessive tissue damage. */
		
		subject treatment : TissueTreatment;
		
		require constraint {
			treatment.apply.force <= 5.0 [SI::N] and
			treatment.apply.duration <= 30.0 [SI::s]
		}
	}
	
	requirement <'3'> tissueTargetingRequirement : MedicalDeviceRequirement {
		doc /* The caustic pencil shall effectively cauterize abnormal tissue while minimizing damage to healthy tissue. */
		
		subject cauterization : CauterizeTissue;
		
		assume constraint {
			cauterization.tissueType.cellType == "abnormal" or
			cauterization.tissueType.cellType == "granulation"
		}
		
		require constraint {
			cauterization.proteinCoagulation == true and
			cauterization.cauterizationDepth >= 0.5 [SI::mm] and
			cauterization.cauterizationDepth <= 2.0 [SI::mm]
		}
	}
	
	requirement <'4'> primaryFunctionRequirement : MedicalDeviceRequirement {
		doc /* The caustic pencil system shall chemically cauterize tissue through controlled application of silver nitrate to achieve hemostasis and remove abnormal tissue. */
		
		subject system : CausticPencil;
		
		require silverNitrateConcentrationRequirement;
		require safeApplicationRequirement;
		require tissueTargetingRequirement;
	}
}
