package 'Vaginal Dilator System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TherapySession;
	attribute def ComfortLevel;
	attribute def TissueCondition;
	
	part def VaginalDilator {
		doc /* Medical device for progressive vaginal tissue expansion and rehabilitation therapy */
		
		attribute serialNumber : String;
		attribute sizeGrade : Integer;
		attribute overallLength : LengthValue;
		attribute insertableLength : LengthValue;
		attribute diameter : LengthValue;
		attribute material : String;
		attribute surfaceFinish : String;
		attribute sterilizationStatus : Boolean;
		
		port therapeuticInterface {
			doc /* Interface for tissue contact and therapeutic expansion */
		}
		
		part dilatorBody {
			attribute bodyLength : LengthValue;
			attribute bodyDiameter : LengthValue;
			attribute taperAngle : Real;
			attribute surfaceTexture : String;
		}
		
		part handleSection {
			attribute handleLength : LengthValue;
			attribute gripDiameter : LengthValue;
			attribute ergonomicDesign : Boolean;
		}
		
		part biocompatibleCoating {
			attribute coatingThickness : LengthValue;
			attribute smoothnessRating : Real;
			attribute hypoallergenicCertified : Boolean;
		}
	}
	
	part def Patient {
		doc /* Individual receiving vaginal dilation therapy */
		
		attribute patientID : String;
		attribute currentComfortLevel : ComfortLevel;
		attribute tissueElasticity : Real;
		attribute therapyProgress : Real;
		
		port vaginalCanal {
			doc /* Anatomical interface for dilator insertion */
		}
	}
	
	part def Lubricant {
		doc /* Medical-grade lubricant to facilitate insertion and reduce friction */
		
		attribute volumeApplied : VolumeValue;
		attribute viscosity : Real;
		attribute waterBased : Boolean;
		attribute pHBalanced : Boolean;
	}
	
	part def TherapyProtocol {
		doc /* Clinical guidelines for progressive dilation therapy */
		
		attribute sessionDuration : TimeValue;
		attribute sessionFrequency : String;
		attribute progressionSchedule : String;
		attribute targetDiameter : LengthValue;
	}
	
	action def PrepareDevice {
		in dilator : VaginalDilator;
		in lubricant : Lubricant;
		out preparedDilator : VaginalDilator;
		out readyForUse : Boolean;
	}
	
	action def AssessComfort {
		in patient : Patient;
		in currentDilatorSize : LengthValue;
		out comfortScore : Real;
		out proceedWithTherapy : Boolean;
	}
	
	action def InsertDilator {
		in dilator : VaginalDilator;
		in patient : Patient;
		in insertionDepth : LengthValue;
		in insertionAngle : Real;
		out insertionComplete : Boolean;
		out tissueResponse : TissueCondition;
	}
	
	action def MaintainPosition {
		in dilator : VaginalDilator;
		in holdDuration : TimeValue;
		in patient : Patient;
		out therapeuticEffectAchieved : Boolean;
	}
	
	action def RemoveDilator {
		in dilator : VaginalDilator;
		in patient : Patient;
		out removalComplete : Boolean;
		out postTherapyAssessment : TissueCondition;
	}
	
	action def CleanAndSterilize {
		in usedDilator : VaginalDilator;
		out sterilizedDilator : VaginalDilator;
		out readyForStorage : Boolean;
	}
	
	action def PerformDilationTherapy {
		doc /* Complete therapeutic cycle for vaginal tissue rehabilitation and expansion */
		
		in dilator : VaginalDilator;
		in patient : Patient;
		in protocol : TherapyProtocol;
		in lubricant : Lubricant;
		out therapyOutcome : TissueCondition;
		out sessionSuccessful : Boolean;
		
		first start;
		
		then action prepare : PrepareDevice {
			in dilator = PerformDilationTherapy::dilator;
			in lubricant = PerformDilationTherapy::lubricant;
			out preparedDilator;
			out readyForUse;
		}
		
		then action assess : AssessComfort {
			in patient = PerformDilationTherapy::patient;
			in currentDilatorSize = dilator.diameter;
			out comfortScore;
			out proceedWithTherapy;
		}
		
		then decide;
			if assess.proceedWithTherapy then insert;
			if !assess.proceedWithTherapy then abortTherapy;
		
		action insert : InsertDilator {
			in dilator = prepare.preparedDilator;
			in patient = PerformDilationTherapy::patient;
			in insertionDepth = dilator.insertableLength;
			in insertionAngle = 15.0;
			out insertionComplete;
			out tissueResponse;
		}
		
		then action maintain : MaintainPosition {
			in dilator = prepare.preparedDilator;
			in holdDuration = protocol.sessionDuration;
			in patient = PerformDilationTherapy::patient;
			out therapeuticEffectAchieved;
		}
		
		then action remove : RemoveDilator {
			in dilator = prepare.preparedDilator;
			in patient = PerformDilationTherapy::patient;
			out removalComplete;
			out postTherapyAssessment;
		}
		
		then action clean : CleanAndSterilize {
			in usedDilator = prepare.preparedDilator;
			out sterilizedDilator;
			out readyForStorage;
		}
		
		then assign therapyOutcome := remove.postTherapyAssessment;
		then assign sessionSuccessful := maintain.therapeuticEffectAchieved;
		then done;
		
		action abortTherapy {
			doc /* Terminate therapy if patient comfort threshold exceeded */
		}
		then done;
	}
	
	part vaginalDilatorSystem {
		doc /* Complete therapeutic system for progressive vaginal tissue rehabilitation */
		
		part dilatorSet : VaginalDilator[5] {
			doc /* Progressive set of dilators in graduated sizes */
		}
		
		part treatedPatient : Patient;
		
		part medicalLubricant : Lubricant;
		
		part clinicalProtocol : TherapyProtocol;
		
		perform action therapySession : PerformDilationTherapy[*] {
			in dilator;
			in patient = treatedPatient;
			in protocol = clinicalProtocol;
			in lubricant = medicalLubricant;
			out therapyOutcome;
			out sessionSuccessful;
		}
		
		connection vaginalInterface connect 
			dilatorSet.therapeuticInterface to treatedPatient.vaginalCanal;
	}
	
	requirement def SafetyRequirement {
		doc /* Device must meet biocompatibility and safety standards */
		subject device : VaginalDilator;
		require constraint {
			device.biocompatibleCoating.hypoallergenicCertified == true
		}
	}
	
	requirement def ComfortRequirement {
		doc /* Therapy must maintain patient comfort within acceptable range */
		subject therapy : PerformDilationTherapy;
		require constraint {
			therapy.assess.comfortScore >= 3.0 and therapy.assess.comfortScore <= 7.0
		}
	}
	
	requirement def SterilizationRequirement {
		doc /* Device must be properly sterilized before each use */
		subject device : VaginalDilator;
		require constraint {
			device.sterilizationStatus == true
		}
	}
	
	requirement def ProgressionRequirement {
		doc /* Therapy must follow graduated progression protocol */
		subject system : VaginalDilator;
		require constraint {
			system.sizeGrade >= 1 and system.sizeGrade <= 5
		}
	}
	
	requirement <'VD-001'> primaryTherapeuticFunction {
		doc /* The vaginal dilator system shall facilitate gradual tissue expansion and rehabilitation through controlled, progressive dilation therapy to restore or maintain vaginal capacity and function */
		
		assume constraint patientSuitability {
			doc /* Patient has been medically cleared for dilation therapy */
		}
		
		assume constraint deviceIntegrity {
			doc /* Dilator is undamaged and properly sterilized */
		}
		
		require deviceSafetyReq : SafetyRequirement;
		require patientComfortReq : ComfortRequirement;
		require deviceSterilizationReq : SterilizationRequirement;
		require therapyProgressionReq : ProgressionRequirement;
	}
}
