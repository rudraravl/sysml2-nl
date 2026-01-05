package PedorthistSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PatientID;
	
	attribute def FootMeasurement {
		attribute length : LengthValue;
		attribute width : LengthValue;
		attribute archHeight : LengthValue;
		attribute heelWidth : LengthValue;
	}
	
	attribute def GaitAnalysisData {
		attribute strideLength : LengthValue;
		attribute cadence : Real;
		attribute pronationAngle : Real;
		attribute supinationAngle : Real;
	}
	
	attribute def PressureDistribution {
		attribute forefoot : PressureValue;
		attribute midfoot : PressureValue;
		attribute heel : PressureValue;
		attribute peakPressure : PressureValue;
	}
	
	item def Prescription {
		attribute prescriptionID : String;
		attribute patientID : PatientID;
		attribute deviceType : String;
		attribute specifications : String;
		attribute issueDate : String;
	}
	
	item def FootOrthotic {
		attribute orthoticID : String;
		attribute material : String;
		attribute thickness : LengthValue;
		attribute archSupport : LengthValue;
		attribute mass : MassValue;
	}
	
	item def TherapeuticFootwear {
		attribute footwearID : String;
		attribute size : Real;
		attribute depth : LengthValue;
		attribute rockerType : String;
		attribute mass : MassValue;
	}
	
	part def Patient {
		attribute patientID : PatientID;
		attribute medicalHistory : String;
		attribute footCondition : String;
		port assessmentPort;
	}
	
	part def AssessmentEquipment {
		attribute equipmentID : String;
		port measurementPort;
		port gaitAnalysisPort;
		port pressurePort;
	}
	
	part def FabricationLab {
		attribute labID : String;
		port prescriptionInputPort;
		port deviceOutputPort;
	}
	
	action def ConductPatientAssessment {
		in patient : Patient;
		out footMeasurements : FootMeasurement;
		out gaitData : GaitAnalysisData;
		out pressureData : PressureDistribution;
	}
	
	action def AnalyzeFootBiomechanics {
		in footMeasurements : FootMeasurement;
		in gaitData : GaitAnalysisData;
		in pressureData : PressureDistribution;
		out biomechanicalAnalysis : String;
		out treatmentNeeds : String;
	}
	
	action def DevelopTreatmentPlan {
		in biomechanicalAnalysis : String;
		in treatmentNeeds : String;
		out treatmentPlan : String;
		out deviceRecommendation : String;
	}
	
	action def CreatePrescription {
		in treatmentPlan : String;
		in deviceRecommendation : String;
		in patientID : PatientID;
		out prescription : Prescription;
	}
	
	action def FabricateOrthotic {
		in prescription : Prescription;
		out orthotic : FootOrthotic;
	}
	
	action def FabricateFootwear {
		in prescription : Prescription;
		out footwear : TherapeuticFootwear;
	}
	
	action def FitDevice {
		in patient : Patient;
		out fitQuality : String;
		out adjustmentsNeeded : Boolean;
	}
	
	action def AdjustDevice {
		in fitQuality : String;
	}
	
	action def ProvidePatientEducation {
		in patient : Patient;
		out educationCompleted : Boolean;
	}
	
	action def ScheduleFollowUp {
		in patient : Patient;
		out followUpDate : String;
	}
	
	action def PedorthicCareProcess {
		in patient : Patient;
		
		first start;
		
		then action assess : ConductPatientAssessment {
			in patient = patient;
			out footMeasurements;
			out gaitData;
			out pressureData;
		}
		
		then action analyze : AnalyzeFootBiomechanics {
			in footMeasurements = assess.footMeasurements;
			in gaitData = assess.gaitData;
			in pressureData = assess.pressureData;
			out biomechanicalAnalysis;
			out treatmentNeeds;
		}
		
		then action plan : DevelopTreatmentPlan {
			in biomechanicalAnalysis = analyze.biomechanicalAnalysis;
			in treatmentNeeds = analyze.treatmentNeeds;
			out treatmentPlan;
			out deviceRecommendation;
		}
		
		then action prescribe : CreatePrescription {
			in treatmentPlan = plan.treatmentPlan;
			in deviceRecommendation = plan.deviceRecommendation;
			in patientID = patient.patientID;
			out prescription;
		}
		
		then decide deviceType;
			if prescribe.prescription.deviceType == "orthotic" then fabricateOrthoticPath;
			if prescribe.prescription.deviceType == "footwear" then fabricateFootwearPath;
		
		action fabricateOrthoticPath : FabricateOrthotic {
			in prescription = prescribe.prescription;
			out orthotic;
		}
		then mergeDeviceFabrication;
		
		action fabricateFootwearPath : FabricateFootwear {
			in prescription = prescribe.prescription;
			out footwear;
		}
		then mergeDeviceFabrication;
		
		merge mergeDeviceFabrication;
		
		then action fit : FitDevice {
			in patient = patient;
			out fitQuality;
			out adjustmentsNeeded;
		}
		
		then decide adjustmentRequired;
			if fit.adjustmentsNeeded then adjust;
			if not fit.adjustmentsNeeded then educate;
		
		action adjust : AdjustDevice {
			in fitQuality = fit.fitQuality;
		}
		then fit;
		
		action educate : ProvidePatientEducation {
			in patient = patient;
			out educationCompleted;
		}
		
		then action schedule : ScheduleFollowUp {
			in patient = patient;
			out followUpDate;
		}
		
		then done;
	}
	
	requirement def AssessmentAccuracyRequirement {
		doc /* All patient assessments shall include comprehensive foot measurements, 
		       gait analysis, and pressure distribution with measurement accuracy within 2mm. */
	}
	
	requirement def DeviceQualityRequirement {
		doc /* All fabricated devices shall meet prescribed specifications and 
		       provide appropriate biomechanical support for the patient's condition. */
	}
	
	requirement def PatientSafetyRequirement {
		doc /* All devices shall be fitted and adjusted to ensure patient comfort 
		       and safety, with proper education provided on usage and care. */
	}
	
	requirement def PedorthicServiceRequirement {
		doc /* The pedorthist system shall provide comprehensive foot care services 
		       including assessment, prescription, fabrication, and fitting of 
		       custom foot orthotics and therapeutic footwear. */
		
		require assessmentAccuracyReq : AssessmentAccuracyRequirement;
		require deviceQualityReq : DeviceQualityRequirement;
		require patientSafetyReq : PatientSafetyRequirement;
	}
	
	part def Pedorthist {
		attribute licenseNumber : String;
		attribute specialization : String;
		port patientInteractionPort;
		port equipmentInterfacePort;
		port fabricationInterfacePort;
		
		perform action providePedorthicCare[*] ordered {
			in patient : Patient;
		}
		
		part assessmentTools : AssessmentEquipment;
		
		part fabricationPartner : FabricationLab;
	}
	
	part pedorthistSystem : Pedorthist {
		satisfy pedorthicServiceReq : PedorthicServiceRequirement;
	}
}
