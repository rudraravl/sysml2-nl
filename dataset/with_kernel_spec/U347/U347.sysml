package HospitalPatientGownSystem {
	private import ISQ::TemperatureValue;
	private import SI::degC;
	private import ScalarValues::String;
	private import ScalarValues::Boolean;
	private import ScalarValues::Real;
	
	item def Detergent {
		attribute grade : String = "Medical-Grade";
	}
	
	item def Issue;
	item def CareRequired;
	item def CareComplete;
	item def Remove;
	item def LaundryStart;
	item def WashComplete;
	item def InspectionPass;
	item def InspectionFail;
	item def Damage;
	
	part def TieString {
		attribute length : Real;
		attribute material : String = "Cotton";
	}
	
	part def PatientGown {
		attribute material : String = "Cotton-Polyester Blend";
		attribute breathable : Boolean = true;
		attribute openBack : Boolean = true;
		attribute frontCovered : Boolean = true;
		attribute washTemperature : TemperatureValue = 70 [degC];
		
		part neckTie : TieString;
		part waistTie : TieString;
		
		state lifecycle : GownLifecycle;
	}
	
	state def GownLifecycle {
		entry; then clean;
		
		state clean;
		accept Issue then worn;
		state worn;
		accept CareRequired then adjusted;
		state adjusted;
		accept CareComplete then worn;
		accept Remove then soiled;
		state soiled;
		accept LaundryStart then washing;
		state washing;
		accept WashComplete then inspection;
		state inspection;
		accept InspectionPass then clean;
		accept InspectionFail then discarded;
		state discarded;
		
		accept Damage then discarded;
	}
	
	part def Patient {
		attribute mobilityLevel : String;
	}
	
	part def ClinicalStaff {
		attribute role : String;
	}
	
	part def SanitationSystem {
		attribute washTemperature : TemperatureValue = 70 [degC];
		attribute detergentGrade : String = "Medical-Grade";
		item detergent : Detergent;
	}
	
	action def IssueGown {
		in staff : ClinicalStaff;
		in patient : Patient;
		in gown : PatientGown;
	}
	
	action def AdjustGown {
		in staff : ClinicalStaff;
		in gown : PatientGown;
	}
	
	action def WashGown {
		in gown : PatientGown;
		in laundry : SanitationSystem;
	}
	
	part hospitalSystem {
		part gown : PatientGown;
		part patient : Patient;
		part staff : ClinicalStaff;
		part laundry : SanitationSystem;
		
		connect staff to patient;
		connect patient to gown;
		connect gown to laundry;
		
		action issueGown : IssueGown;
		action adjustGown : AdjustGown;
		action washGown : WashGown;
		
		perform issueGown;
		perform adjustGown;
		perform washGown;
	}
	
	requirement def ModestyRequirement {
		doc /* The gown must maintain patient modesty by covering the front. */
		subject gown : PatientGown;
		constraint { gown.frontCovered == true }
	}
	
	requirement def AccessibilityRequirement {
		doc /* The gown must allow clinical access to the back. */
		subject gown : PatientGown;
		constraint { gown.openBack == true }
	}
	
	requirement def SterilizationRequirement {
		doc /* The gown must withstand high temperature washing. */
		subject laundry : SanitationSystem;
		constraint { laundry.washTemperature >= 70 [degC] }
	}
}
