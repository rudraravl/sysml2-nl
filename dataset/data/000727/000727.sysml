package PatientGownSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def CoveragePercentage :> Real;
	attribute def AccessibilityRating :> Real;
	
	item def FabricMaterial {
		attribute materialType : String;
		attribute breathability : Real;
		attribute durability : Real;
		attribute washTemperature : TemperatureValue;
	}
	
	item def FasteningMechanism {
		attribute mechanismType : String;
		attribute securityLevel : Real;
		attribute easeOfUse : Real;
	}
	
	item def BodyRegion {
		attribute regionName : String;
		attribute isCovered : Boolean;
		attribute isAccessible : Boolean;
	}
	
	part def PatientGown {
		attribute gownSize : String;
		attribute color : String;
		attribute isSecured : Boolean;
		attribute currentCoverage : CoveragePercentage;
		
		part fabricBody : FabricMaterial {
			attribute materialType = "cotton-polyester blend";
			attribute breathability = 0.85;
			attribute durability = 0.90;
			attribute washTemperature = 75.0 [SI::degC];
		}
		
		part neckTies : FasteningMechanism {
			attribute mechanismType = "tie strings";
			attribute securityLevel = 0.75;
			attribute easeOfUse = 0.80;
		}
		
		part waistTies : FasteningMechanism {
			attribute mechanismType = "tie strings";
			attribute securityLevel = 0.75;
			attribute easeOfUse = 0.80;
		}
		
		part frontCoverage : BodyRegion {
			attribute regionName = "front torso";
			attribute isCovered = true;
			attribute isAccessible = false;
		}
		
		part backCoverage : BodyRegion {
			attribute regionName = "back torso";
			attribute isCovered = false;
			attribute isAccessible = true;
		}
		
		port modestyInterface {
			doc /* Interface for maintaining patient dignity and privacy */
		}
		
		port clinicalAccessInterface {
			doc /* Interface for medical examination and treatment access */
		}
	}
	
	part def Patient {
		attribute patientID : String;
		attribute mobilityLevel : Real;
		attribute requiresAssistance : Boolean;
		attribute bodyTemperature : TemperatureValue;
		
		port wearingInterface {
			doc /* Interface for donning and doffing gown */
		}
		
		port comfortInterface {
			doc /* Interface for patient comfort and thermal regulation */
		}
	}
	
	part def ClinicalStaff {
		attribute staffID : String;
		attribute role : String;
		
		port examinationInterface {
			doc /* Interface for conducting medical procedures */
		}
		
		port assistanceInterface {
			doc /* Interface for helping patient with gown */
		}
	}
	
	part def SanitationSystem {
		attribute cycleTemperature : TemperatureValue;
		attribute cycleDuration : TimeValue;
		attribute detergentType : String;
		
		port cleaningInterface {
			doc /* Interface for gown laundering and sterilization */
		}
	}
	
	action def SecureGown {
		in gown : PatientGown;
		in patient : Patient;
		out secured : Boolean;
		
		first start;
		then action positionGown {
			doc /* Position gown on patient body */
		}
		then action tieNeckFasteners {
			doc /* Secure neck ties to hold gown in place */
		}
		then action tieWaistFasteners {
			doc /* Secure waist ties for additional security */
		}
		then action verifyCoverage {
			out coverageAdequate : Boolean;
		}
		then assign secured := verifyCoverage.coverageAdequate;
		then done;
	}
	
	action def ProvideExaminationAccess {
		in gown : PatientGown;
		in targetRegion : String;
		out accessProvided : Boolean;
		
		first start;
		then action identifyRegion {
			in region : String = targetRegion;
			out regionIdentified : Boolean;
		}
		then action adjustGownOpening {
			doc /* Adjust gown to expose required examination area */
		}
		then action maintainModesty {
			doc /* Ensure non-examined areas remain covered */
		}
		then action confirmAccess {
			out accessConfirmed : Boolean;
		}
		then assign accessProvided := confirmAccess.accessConfirmed;
		then done;
	}
	
	action def RemoveGown {
		in gown : PatientGown;
		in patient : Patient;
		out removed : Boolean;
		
		first start;
		then action releaseWaistTies {
			doc /* Unfasten waist ties */
		}
		then action releaseNeckTies {
			doc /* Unfasten neck ties */
		}
		then action removeFromBody {
			doc /* Remove gown from patient */
		}
		then action collectForLaundry {
			doc /* Place gown in designated laundry receptacle */
		}
		then assign removed := true;
		then done;
	}
	
	action def ProcessGownLaundry {
		in usedGown : PatientGown;
		in sanitationSystem : SanitationSystem;
		out cleanGown : PatientGown;
		
		first start;
		then action collectContaminatedGown {
			doc /* Collect used gown in biohazard container */
		}
		then action transportToLaundry {
			doc /* Transport to laundry facility */
		}
		then action prewashInspection {
			out inspectionPassed : Boolean;
		}
		then decide;
			if prewashInspection.inspectionPassed then washGown;
			if not prewashInspection.inspectionPassed then discardGown;
		action washGown {
			doc /* Wash at high temperature with medical-grade detergent */
		}
		then action dryGown {
			doc /* Dry at appropriate temperature */
		}
		then action postWashInspection {
			out qualityPassed : Boolean;
		}
		then decide;
			if postWashInspection.qualityPassed then packageGown;
			if not postWashInspection.qualityPassed then discardGown;
		action packageGown {
			doc /* Package clean gown for distribution */
		}
		then assign cleanGown := usedGown;
		then done;
		action discardGown {
			doc /* Discard damaged or contaminated gown */
		}
		then done;
	}
	
	event def GownIssuedEvent;
	event def GownSecuredEvent;
	event def AccessRequestedEvent;
	event def AccessCompletedEvent;
	event def GownRemovedEvent;
	event def LaundryStartedEvent;
	event def LaundryCompletedEvent;
	event def GownDamagedEvent;
	
	state def GownOperationalState {
		entry; then clean;
		
		state clean {
			doc /* Gown is sanitized and ready for patient use */
		}
		
		transition clean_to_issued
			first clean
			accept GownIssuedEvent
			then issued;
		
		state issued {
			doc /* Gown has been issued to patient care area */
		}
		
		transition issued_to_worn
			first issued
			accept GownSecuredEvent
			then worn;
		
		state worn {
			doc /* Gown is actively being worn by patient */
		}
		
		transition worn_to_accessProvided
			first worn
			accept AccessRequestedEvent
			then accessProvided;
		
		state accessProvided {
			doc /* Gown is adjusted to provide clinical access */
		}
		
		transition accessProvided_to_worn
			first accessProvided
			accept AccessCompletedEvent
			then worn;
		
		transition worn_to_soiled
			first worn
			accept GownRemovedEvent
			then soiled;
		
		state soiled {
			doc /* Gown has been used and requires laundering */
		}
		
		transition soiled_to_laundering
			first soiled
			accept LaundryStartedEvent
			then laundering;
		
		state laundering {
			doc /* Gown is undergoing sanitization process */
		}
		
		transition laundering_to_clean
			first laundering
			accept LaundryCompletedEvent
			then clean;
		
		transition laundering_to_discarded
			first laundering
			accept GownDamagedEvent
			then discarded;
		
		state discarded {
			doc /* Gown has been permanently removed from service */
		}
	}
	
	requirement def PatientGownSystemRequirements {
		doc /* Top-level requirements for patient gown system */
		
		requirement <'1'> maintainPatientModesty {
			doc /* The patient gown shall provide adequate coverage to maintain patient modesty and dignity during all non-examination periods. */
		}
		
		requirement <'2'> enableClinicalAccess {
			doc /* The patient gown shall enable rapid and convenient access to all body regions required for medical examination, treatment, and monitoring. */
		}
		
		requirement <'3'> ensurePatientComfort {
			doc /* The patient gown shall be constructed from breathable, soft fabric that maintains patient comfort during extended wear periods. */
			assume constraint {
				doc /* Fabric breathability must be at least 0.80 */
			}
		}
		
		requirement <'4'> facilitateInfectionControl {
			doc /* The patient gown shall be designed for effective laundering and sterilization to prevent cross-contamination between patients. */
			assume constraint {
				doc /* Wash temperature must be at least 70 degrees Celsius */
			}
		}
		
		requirement <'5'> simplifyDonningDoffing {
			doc /* The patient gown shall be designed for easy donning and doffing by patients with limited mobility or by clinical staff assisting patients. */
			assume constraint {
				doc /* Fastener ease of use must be at least 0.75 */
			}
		}
		
		requirement <'6'> provideSecureFastening {
			doc /* The patient gown fastening mechanisms shall securely hold the gown in place during normal patient movement and positioning. */
			assume constraint {
				doc /* Fastener security level must be at least 0.70 */
			}
		}
		
		requirement <'7'> supportThermalRegulation {
			doc /* The patient gown shall support patient thermal comfort by allowing adequate air circulation while providing coverage. */
		}
	}
	
	part hospitalGownSystem {
		part gown : PatientGown {
			attribute gownSize = "large";
			attribute color = "blue";
			attribute isSecured = false;
			attribute currentCoverage = 0.0;
		}
		
		part patient : Patient {
			attribute patientID = "PT-2024-001";
			attribute mobilityLevel = 0.65;
			attribute requiresAssistance = true;
			attribute bodyTemperature = 36.8 [SI::degC];
		}
		
		part nurse : ClinicalStaff {
			attribute staffID = "RN-456";
			attribute role = "registered nurse";
		}
		
		part physician : ClinicalStaff {
			attribute staffID = "MD-789";
			attribute role = "attending physician";
		}
		
		part laundrySystem : SanitationSystem {
			attribute cycleTemperature = 75.0 [SI::degC];
			attribute cycleDuration = 45.0 [SI::min];
			attribute detergentType = "medical-grade enzymatic";
		}
		
		connection gownToPatientWearing connect gown.modestyInterface to patient.wearingInterface;
		connection gownToPatientComfort connect gown to patient.comfortInterface;
		connection gownToNurseAssist connect gown to nurse.assistanceInterface;
		connection gownToPhysicianExam connect gown.clinicalAccessInterface to physician.examinationInterface;
		connection gownToLaundry connect gown to laundrySystem.cleaningInterface;
		
		perform action gownLifecycle {
			first start;
			then action secure : SecureGown {
				in gown = hospitalGownSystem.gown;
				in patient = hospitalGownSystem.patient;
				out secured;
			}
			then action provideAccess : ProvideExaminationAccess {
				in gown = hospitalGownSystem.gown;
				in targetRegion = "chest";
				out accessProvided;
			}
			then action remove : RemoveGown {
				in gown = hospitalGownSystem.gown;
				in patient = hospitalGownSystem.patient;
				out removed;
			}
			then action processLaundry : ProcessGownLaundry {
				in usedGown = hospitalGownSystem.gown;
				in sanitationSystem = hospitalGownSystem.laundrySystem;
				out cleanGown;
			}
			then done;
		}
		
		exhibit state gownState : GownOperationalState;
	}
	
	requirement hospitalGownRequirement : PatientGownSystemRequirements {
		doc /* Requirements for the hospital gown system */
		
		assume constraint breathabilityConstraint {
			hospitalGownSystem.gown.fabricBody.breathability >= 0.80
		}
		
		assume constraint washTemperatureConstraint {
			hospitalGownSystem.gown.fabricBody.washTemperature >= 70.0 [SI::degC]
		}
		
		assume constraint easeOfUseConstraint {
			hospitalGownSystem.gown.neckTies.easeOfUse >= 0.75 and 
			hospitalGownSystem.gown.waistTies.easeOfUse >= 0.75
		}
		
		assume constraint securityConstraint {
			hospitalGownSystem.gown.neckTies.securityLevel >= 0.70 and 
			hospitalGownSystem.gown.waistTies.securityLevel >= 0.70
		}
	}
}
