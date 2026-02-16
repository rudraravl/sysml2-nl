package 'AI Healthcare Diagnostic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PatientID :> String;
	attribute def ConfidenceScore :> Real;
	attribute def RiskLevel :> Real;
	attribute def AlertSeverity :> Integer;
	
	item def VitalSignsData {
		attribute heartRate : FrequencyValue;
		attribute bloodPressureSystolic : PressureValue;
		attribute bloodPressureDiastolic : PressureValue;
		attribute bodyTemperature : TemperatureValue;
		attribute respiratoryRate : FrequencyValue;
		attribute oxygenSaturation : Real;
		attribute timestamp : TimeValue;
	}
	
	item def MedicalImageData {
		attribute patientID : PatientID;
		attribute imageType : String;
		attribute resolution : Integer[2];
		attribute acquisitionTimestamp : TimeValue;
		attribute modalityType : String;
	}
	
	item def LabResultData {
		attribute patientID : PatientID;
		attribute testType : String;
		attribute resultValue : Real;
		attribute normalRange : Real[2];
		attribute timestamp : TimeValue;
	}
	
	item def PatientRecord {
		attribute patientID : PatientID;
		attribute age : Integer;
		attribute gender : String;
		attribute medicalHistory : String;
		attribute currentMedications : String;
		attribute allergies : String;
	}
	
	item def DiagnosticResult {
		attribute patientID : PatientID;
		attribute diagnosisCode : String;
		attribute diagnosisDescription : String;
		attribute confidence : ConfidenceScore;
		attribute supportingEvidence : String;
		attribute timestamp : TimeValue;
	}
	
	item def RiskAssessment {
		attribute patientID : PatientID;
		attribute riskLevel : RiskLevel;
		attribute riskFactors : String[*];
		attribute predictedOutcome : String;
		attribute timeHorizon : TimeValue;
	}
	
	item def TreatmentRecommendation {
		attribute patientID : PatientID;
		attribute recommendedInterventions : String[*];
		attribute priorityLevel : Integer;
		attribute expectedOutcome : String;
		attribute contraindications : String[*];
	}
	
	item def ClinicalAlert {
		attribute patientID : PatientID;
		attribute severity : AlertSeverity;
		attribute alertMessage : String;
		attribute requiredAction : String;
		attribute timestamp : TimeValue;
	}
	
	part def DataAcquisitionModule {
		out port vitalSignsOut : VitalSignsData;
		out port medicalImageOut : MedicalImageData;
		out port labResultsOut : LabResultData;
		out port patientRecordOut : PatientRecord;
	}
	
	part def DataPreprocessingEngine {
		in port vitalSignsIn : VitalSignsData;
		in port medicalImageIn : MedicalImageData;
		in port labResultsIn : LabResultData;
		in port patientRecordIn : PatientRecord;
		out port normalizedVitalsOut : VitalSignsData;
		out port processedImageOut : MedicalImageData;
		out port validatedLabsOut : LabResultData;
		out port enrichedRecordOut : PatientRecord;
	}
	
	part def AIInferenceEngine {
		in port normalizedVitalsIn : VitalSignsData;
		in port processedImageIn : MedicalImageData;
		in port validatedLabsIn : LabResultData;
		in port enrichedRecordIn : PatientRecord;
		out port diagnosisOut : DiagnosticResult;
		out port riskAssessmentOut : RiskAssessment;
	}
	
	part def ClinicalDecisionSupportModule {
		in port diagnosisIn : DiagnosticResult;
		in port riskAssessmentIn : RiskAssessment;
		in port patientContextIn : PatientRecord;
		out port treatmentRecommendationOut : TreatmentRecommendation;
		out port clinicalAlertOut : ClinicalAlert;
	}
	
	part def PhysicianInterface {
		in port diagnosisReviewIn : DiagnosticResult;
		in port treatmentRecommendationIn : TreatmentRecommendation;
		in port clinicalAlertIn : ClinicalAlert;
		in port riskAssessmentIn : RiskAssessment;
		out port approvedDecisionOut : TreatmentRecommendation;
		out port feedbackOut : String;
	}
	
	part def MonitoringDashboard {
		in port realTimeVitalsIn : VitalSignsData;
		in port activeAlertsIn : ClinicalAlert;
		in port patientStatusIn : DiagnosticResult;
	}
	
	action def AcquirePatientData {
		out vitalSigns : VitalSignsData;
		out medicalImage : MedicalImageData;
		out labResults : LabResultData;
		out patientRecord : PatientRecord;
	}
	
	action def PreprocessData {
		in rawVitals : VitalSignsData;
		in rawImage : MedicalImageData;
		in rawLabs : LabResultData;
		in rawRecord : PatientRecord;
		out normalizedVitals : VitalSignsData;
		out processedImage : MedicalImageData;
		out validatedLabs : LabResultData;
		out enrichedRecord : PatientRecord;
	}
	
	action def PerformAIInference {
		in normalizedVitals : VitalSignsData;
		in processedImage : MedicalImageData;
		in validatedLabs : LabResultData;
		in enrichedRecord : PatientRecord;
		out diagnosis : DiagnosticResult;
		out riskAssessment : RiskAssessment;
	}
	
	action def GenerateClinicalDecisions {
		in diagnosis : DiagnosticResult;
		in riskAssessment : RiskAssessment;
		in patientContext : PatientRecord;
		out treatmentRecommendation : TreatmentRecommendation;
		out clinicalAlert : ClinicalAlert;
	}
	
	action def ReviewAndApprove {
		in diagnosis : DiagnosticResult;
		in treatmentRecommendation : TreatmentRecommendation;
		in clinicalAlert : ClinicalAlert;
		in riskAssessment : RiskAssessment;
		out approvedDecision : TreatmentRecommendation;
		out feedback : String;
	}
	
	action def ContinuousMonitoring {
		in realTimeVitals : VitalSignsData;
		in activeAlerts : ClinicalAlert;
		out monitoringStatus : String;
	}
	
	action def AIAssistedDiagnosticWorkflow {
		first start;
		then action acquireData : AcquirePatientData {
			out vitalSigns : VitalSignsData;
			out medicalImage : MedicalImageData;
			out labResults : LabResultData;
			out patientRecord : PatientRecord;
		}
		then action preprocessData : PreprocessData {
			in rawVitals = acquireData.vitalSigns;
			in rawImage = acquireData.medicalImage;
			in rawLabs = acquireData.labResults;
			in rawRecord = acquireData.patientRecord;
			out normalizedVitals : VitalSignsData;
			out processedImage : MedicalImageData;
			out validatedLabs : LabResultData;
			out enrichedRecord : PatientRecord;
		}
		then action performInference : PerformAIInference {
			in normalizedVitals = preprocessData.normalizedVitals;
			in processedImage = preprocessData.processedImage;
			in validatedLabs = preprocessData.validatedLabs;
			in enrichedRecord = preprocessData.enrichedRecord;
			out diagnosis : DiagnosticResult;
			out riskAssessment : RiskAssessment;
		}
		then action generateDecisions : GenerateClinicalDecisions {
			in diagnosis = performInference.diagnosis;
			in riskAssessment = performInference.riskAssessment;
			in patientContext = preprocessData.enrichedRecord;
			out treatmentRecommendation : TreatmentRecommendation;
			out clinicalAlert : ClinicalAlert;
		}
		then decide;
			if generateDecisions.clinicalAlert.severity >= 3 then urgentReview;
			if generateDecisions.clinicalAlert.severity < 3 then routineReview;
		action urgentReview : ReviewAndApprove {
			in diagnosis = performInference.diagnosis;
			in treatmentRecommendation = generateDecisions.treatmentRecommendation;
			in clinicalAlert = generateDecisions.clinicalAlert;
			in riskAssessment = performInference.riskAssessment;
			out approvedDecision : TreatmentRecommendation;
			out feedback : String;
		}
		then done;
		action routineReview : ReviewAndApprove {
			in diagnosis = performInference.diagnosis;
			in treatmentRecommendation = generateDecisions.treatmentRecommendation;
			in clinicalAlert = generateDecisions.clinicalAlert;
			in riskAssessment = performInference.riskAssessment;
			out approvedDecision : TreatmentRecommendation;
			out feedback : String;
		}
		then done;
	}
	
	part def AIHealthcareDiagnosticSystem {
		part dataAcquisition : DataAcquisitionModule;
		part dataPreprocessing : DataPreprocessingEngine;
		part aiInference : AIInferenceEngine;
		part clinicalDecisionSupport : ClinicalDecisionSupportModule;
		part physicianInterface : PhysicianInterface;
		part monitoringDashboard : MonitoringDashboard;
		
		connect dataAcquisition.vitalSignsOut to dataPreprocessing.vitalSignsIn;
		connect dataAcquisition.medicalImageOut to dataPreprocessing.medicalImageIn;
		connect dataAcquisition.labResultsOut to dataPreprocessing.labResultsIn;
		connect dataAcquisition.patientRecordOut to dataPreprocessing.patientRecordIn;
		
		connect dataPreprocessing.normalizedVitalsOut to aiInference.normalizedVitalsIn;
		connect dataPreprocessing.processedImageOut to aiInference.processedImageIn;
		connect dataPreprocessing.validatedLabsOut to aiInference.validatedLabsIn;
		connect dataPreprocessing.enrichedRecordOut to aiInference.enrichedRecordIn;
		
		connect aiInference.diagnosisOut to clinicalDecisionSupport.diagnosisIn;
		connect aiInference.riskAssessmentOut to clinicalDecisionSupport.riskAssessmentIn;
		connect dataPreprocessing.enrichedRecordOut to clinicalDecisionSupport.patientContextIn;
		
		connect aiInference.diagnosisOut to physicianInterface.diagnosisReviewIn;
		connect clinicalDecisionSupport.treatmentRecommendationOut to physicianInterface.treatmentRecommendationIn;
		connect clinicalDecisionSupport.clinicalAlertOut to physicianInterface.clinicalAlertIn;
		connect aiInference.riskAssessmentOut to physicianInterface.riskAssessmentIn;
		
		connect dataAcquisition.vitalSignsOut to monitoringDashboard.realTimeVitalsIn;
		connect clinicalDecisionSupport.clinicalAlertOut to monitoringDashboard.activeAlertsIn;
		connect aiInference.diagnosisOut to monitoringDashboard.patientStatusIn;
		
		perform action diagnosticWorkflow[*] ordered references AIAssistedDiagnosticWorkflow;
	}
	
	part aiHealthcareSystem : AIHealthcareDiagnosticSystem;
	
	requirement def PrimaryFunctionRequirement {
		doc /* The AI Healthcare Diagnostic System shall continuously analyze multi-modal patient data 
		        including vital signs, medical images, and laboratory results to provide real-time diagnostic 
		        insights, risk assessments, and evidence-based treatment recommendations to clinicians, 
		        thereby enhancing diagnostic accuracy, reducing time to treatment, and improving patient outcomes. */
		
		subject system : AIHealthcareDiagnosticSystem;
		
		require constraint {
			doc /* The system shall process patient data and generate diagnostic results within 5 minutes 
			        of data acquisition for 95% of cases. */
		}
	}
	
	requirement def DiagnosticAccuracyRequirement {
		doc /* The AI inference engine shall achieve a minimum diagnostic accuracy of 92% for common conditions 
		        and 85% for rare conditions when compared to expert physician consensus. */
		
		subject inferenceEngine : AIInferenceEngine;
		
		require constraint {
			doc /* Diagnostic confidence scores shall be calibrated such that predictions with confidence >= 0.90 
			        achieve actual accuracy >= 0.90. */
		}
	}
	
	requirement def RiskPredictionRequirement {
		doc /* The system shall predict patient deterioration risk with a minimum sensitivity of 85% 
		        and specificity of 80% within a 24-hour time horizon. */
		
		subject inferenceEngine : AIInferenceEngine;
	}
	
	requirement def ClinicalSafetyRequirement {
		doc /* All AI-generated diagnostic results and treatment recommendations must be reviewed and approved 
		        by a licensed physician before implementation to ensure patient safety. */
		
		subject system : AIHealthcareDiagnosticSystem;
		
		require constraint {
			doc /* No treatment recommendation shall be executed without explicit physician approval 
			        documented in the system. */
		}
	}
	
	requirement def AlertingRequirement {
		doc /* The system shall generate clinical alerts for critical conditions within 30 seconds of detection 
		        and ensure delivery to on-duty clinicians. */
		
		subject decisionSupport : ClinicalDecisionSupportModule;
		
		require constraint {
			doc /* High-severity alerts (severity >= 3) shall trigger immediate notification to multiple 
			        clinical staff members. */
		}
	}
	
	requirement def DataIntegrityRequirement {
		doc /* The system shall validate and preprocess all input data to ensure quality, completeness, 
		        and consistency before AI inference. */
		
		subject preprocessingEngine : DataPreprocessingEngine;
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for AI Healthcare Diagnostic System. */
		
		subject system : AIHealthcareDiagnosticSystem;
		
		requirement primaryFunction : PrimaryFunctionRequirement;
		requirement diagnosticAccuracy : DiagnosticAccuracyRequirement;
		requirement riskPrediction : RiskPredictionRequirement;
		requirement clinicalSafety : ClinicalSafetyRequirement;
		requirement alerting : AlertingRequirement;
		requirement dataIntegrity : DataIntegrityRequirement;
	}
}
