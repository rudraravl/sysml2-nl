package 'Medical Calculator System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PatientID :> String;
	
	attribute def BodyMassIndex :> Real;
	attribute def GlomerularFiltrationRate :> Real;
	attribute def RiskPercentage :> Real;
	
	item def PatientData {
		attribute patientID : PatientID;
		attribute age : Real;
		attribute weight : MassValue;
		attribute height : LengthValue;
		attribute gender : String;
		attribute serumCreatinine : Real;
		attribute systolicBP : Real;
		attribute diastolicBP : Real;
		attribute totalCholesterol : Real;
		attribute hdlCholesterol : Real;
		attribute isSmoker : Boolean;
		attribute isDiabetic : Boolean;
	}
	
	item def CalculationResult {
		attribute calculationType : String;
		attribute resultValue : Real;
		attribute resultUnit : String;
		attribute timestamp : String;
		attribute interpretation : String;
		attribute isAbnormal : Boolean;
	}
	
	port def PatientDataInputPort {
		in item patientData : PatientData;
	}
	
	port def CalculationResultOutputPort {
		out item result : CalculationResult;
	}
	
	part def InputModule {
		port dataInput : PatientDataInputPort;
		port dataOutput : ~PatientDataInputPort;
	}
	
	part def ValidationModule {
		port validationIn : ~PatientDataInputPort;
		port validationOut : PatientDataInputPort;
		attribute validationStatus : Boolean;
	}
	
	part def ComputationEngine {
		port computeInput : ~PatientDataInputPort;
		port computeOutput : CalculationResultOutputPort;
	}
	
	part def DisplayModule {
		port displayInput : ~CalculationResultOutputPort;
	}
	
	part def StorageModule {
		port storageIn : ~CalculationResultOutputPort;
		attribute resultHistory : CalculationResult[*];
	}
	
	action def ValidatePatientData {
		in patientData : PatientData;
		out validatedData : PatientData;
		out isValid : Boolean;
		
		first start;
		then action checkAge {
			attribute ageValid : Boolean;
		}
		then action checkWeight {
			attribute weightValid : Boolean;
		}
		then action checkHeight {
			attribute heightValid : Boolean;
		}
		then decide;
			if checkAge.ageValid and checkWeight.weightValid and checkHeight.heightValid then markValid;
			else markInvalid;
		action markValid {
			then assign isValid := true;
			then assign validatedData := patientData;
		}
		then merge complete;
		action markInvalid {
			then assign isValid := false;
		}
		then merge complete;
		merge complete;
		then done;
	}
	
	action def CalculateBMI {
		in weight : MassValue;
		in height : LengthValue;
		out bmi : BodyMassIndex;
		
		first start;
		then action computeBMI;
		then done;
	}
	
	action def CalculateGFR {
		in age : Real;
		in serumCreatinine : Real;
		in gender : String;
		in weight : MassValue;
		out gfr : GlomerularFiltrationRate;
		
		first start;
		then decide;
			if gender == "male" then maleFormula;
			if gender == "female" then femaleFormula;
		action maleFormula;
		then merge complete;
		action femaleFormula;
		then merge complete;
		merge complete;
		then done;
	}
	
	action def CalculateCardiacRisk {
		in age : Real;
		in gender : String;
		in systolicBP : Real;
		in totalCholesterol : Real;
		in hdlCholesterol : Real;
		in isSmoker : Boolean;
		in isDiabetic : Boolean;
		out riskScore : RiskPercentage;
		
		first start;
		then action assessRiskFactors;
		then action computeFraminghamScore;
		then done;
	}
	
	action def CalculateMedicationDose {
		in weight : MassValue;
		in gfr : GlomerularFiltrationRate;
		in baselineDose : Real;
		out adjustedDose : Real;
		
		first start;
		then action determineRenalFunction {
			attribute renalImpairment : Boolean;
		}
		then decide;
			if determineRenalFunction.renalImpairment then reduceDose;
			else standardDose;
		action reduceDose;
		then merge complete;
		action standardDose;
		then merge complete;
		merge complete;
		then done;
	}
	
	action def PerformClinicalCalculation {
		in patientData : PatientData;
		in calculationType : String;
		out result : CalculationResult;
		
		first start;
		then action validate : ValidatePatientData {
			in patientData = PerformClinicalCalculation::patientData;
			out validatedData;
			out isValid;
		}
		then decide;
			if validate.isValid then selectCalculation;
			else action handleError;
		
		action selectCalculation {
			first start;
			then decide;
				if PerformClinicalCalculation::calculationType == "bmi" then performBMI;
				if PerformClinicalCalculation::calculationType == "gfr" then performGFR;
				if PerformClinicalCalculation::calculationType == "cardiacRisk" then performCardiacRisk;
				if PerformClinicalCalculation::calculationType == "medicationDose" then performMedicationDose;
			
			action performBMI : CalculateBMI {
				in weight = validate.validatedData.weight;
				in height = validate.validatedData.height;
				out bmi;
			}
			then merge assembleResult;
			
			action performGFR : CalculateGFR {
				in age = validate.validatedData.age;
				in serumCreatinine = validate.validatedData.serumCreatinine;
				in gender = validate.validatedData.gender;
				in weight = validate.validatedData.weight;
				out gfr;
			}
			then merge assembleResult;
			
			action performCardiacRisk : CalculateCardiacRisk {
				in age = validate.validatedData.age;
				in gender = validate.validatedData.gender;
				in systolicBP = validate.validatedData.systolicBP;
				in totalCholesterol = validate.validatedData.totalCholesterol;
				in hdlCholesterol = validate.validatedData.hdlCholesterol;
				in isSmoker = validate.validatedData.isSmoker;
				in isDiabetic = validate.validatedData.isDiabetic;
				out riskScore;
			}
			then merge assembleResult;
			
			action performMedicationDose {
				first action calcGFR : CalculateGFR {
					in age = validate.validatedData.age;
					in serumCreatinine = validate.validatedData.serumCreatinine;
					in gender = validate.validatedData.gender;
					in weight = validate.validatedData.weight;
					out gfr;
				}
				then action calcDose : CalculateMedicationDose {
					in weight = validate.validatedData.weight;
					in gfr = calcGFR.gfr;
					in baselineDose = 100.0;
					out adjustedDose;
				}
			}
			then merge assembleResult;
			
			merge assembleResult;
			then action formatResult;
			then done;
		}
		then merge complete;
		
		merge complete;
		then done;
	}
	
	state def CalculatorOperationalState {
		entry; then idle;
		
		state idle;
		accept when PatientDataReceived
		then validating;
		
		state validating {
			do action validate : ValidatePatientData;
		}
		accept when ValidationComplete
		if validate.isValid then computing;
		if not validate.isValid then error;
		
		state computing {
			do action compute : PerformClinicalCalculation;
		}
		accept when ComputationComplete
		then presenting;
		
		state presenting;
		accept when ResultDisplayed
		then storing;
		
		state storing;
		accept when ResultStored
		then idle;
		
		state error;
		accept when ErrorAcknowledged
		then idle;
	}
	
	part medicalCalculatorSystem {
		part inputInterface : InputModule {
			perform action receivePatientData;
		}
		
		part validator : ValidationModule {
			perform action validateData : ValidatePatientData;
		}
		
		part computationEngine : ComputationEngine {
			perform action executeCalculation : PerformClinicalCalculation;
			state operation : CalculatorOperationalState;
		}
		
		part display : DisplayModule {
			perform action showResult;
		}
		
		part storage : StorageModule {
			perform action storeResult;
		}
		
		connect inputInterface.dataOutput to validator.validationIn;
		connect validator.validationOut to computationEngine.computeInput;
		connect computationEngine.computeOutput to display.displayInput;
		connect computationEngine.computeOutput to storage.storageIn;
		
		flow of PatientData from inputInterface.dataOutput to validator.validationIn;
		flow of PatientData from validator.validationOut to computationEngine.computeInput;
		flow of CalculationResult from computationEngine.computeOutput to display.displayInput;
		flow of CalculationResult from computationEngine.computeOutput to storage.storageIn;
	}
	
	requirement def FunctionalRequirement;
	requirement def AccuracyRequirement;
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	
	requirement <'MCS-REQ-001'> primaryFunctionRequirement : FunctionalRequirement {
		doc /* The medical calculator system shall perform accurate clinical calculations 
		     to support healthcare decision-making by computing body mass index, 
		     estimated glomerular filtration rate, cardiovascular risk assessment, 
		     and medication dosage adjustments based on validated patient data. */
		
		subject medicalCalculatorSystem;
		
		require <'MCS-REQ-001.1'> calculationCapability : FunctionalRequirement {
			doc /* The system shall support multiple calculation types including BMI, GFR, 
			     cardiac risk scores, and medication dosing algorithms. */
		}
		
		require <'MCS-REQ-001.2'> dataValidation : FunctionalRequirement {
			doc /* All patient data shall be validated for completeness and clinical 
			     plausibility before processing calculations. */
		}
		
		require <'MCS-REQ-001.3'> resultPresentation : FunctionalRequirement {
			doc /* Calculation results shall be presented with appropriate units, 
			     interpretation guidance, and abnormal value indicators. */
		}
	}
	
	requirement <'MCS-REQ-002'> accuracyRequirement : AccuracyRequirement {
		doc /* All calculations shall maintain clinical accuracy within established 
		     medical standards and validated formulas. */
		
		assume constraint validatedFormulas {
			doc /* Calculation algorithms are based on peer-reviewed medical literature 
			     and clinical guidelines. */
		}
	}
	
	requirement <'MCS-REQ-003'> safetyRequirement : SafetyRequirement {
		doc /* The system shall implement safety checks to prevent calculation errors 
		     that could impact patient care decisions. */
		
		require constraint rangeValidation {
			doc /* Input values shall be validated against clinically acceptable ranges. */
		}
		
		require constraint errorHandling {
			doc /* Invalid inputs shall be rejected with clear error messages and 
			     shall not produce misleading results. */
		}
	}
	
	requirement <'MCS-REQ-004'> performanceRequirement : PerformanceRequirement {
		doc /* The system shall complete calculations and display results within 
		     2 seconds of receiving validated patient data. */
	}
	
	satisfy primaryFunctionRequirement by medicalCalculatorSystem;
	satisfy accuracyRequirement by medicalCalculatorSystem.computationEngine;
	satisfy safetyRequirement by medicalCalculatorSystem.validator;
	satisfy performanceRequirement by medicalCalculatorSystem.computationEngine;
}
