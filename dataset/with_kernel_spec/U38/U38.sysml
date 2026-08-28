package 'AI Clinical Decision Support System' {
    private import Base::*;
    private import ScalarValues::*;

    unit def bpm;
    unit def mmHg;
    unit def breaths_per_min;
    unit def percent;
    unit def celsius;
    unit def second;
    unit def year;
    unit def centimeter;
    unit def kilogram;

    attribute def HeartRate :> Real {
        unit bpm;
        assert constraint { that >= 0.0 and that <= 300.0 }
    }
    attribute def SystolicBloodPressure :> Real {
        unit mmHg;
        assert constraint { that >= 0.0 and that <= 300.0 }
    }
    attribute def DiastolicBloodPressure :> Real {
        unit mmHg;
        assert constraint { that >= 0.0 and that <= 200.0 }
    }
    attribute def RespiratoryRate :> Real {
        unit breaths_per_min;
        assert constraint { that >= 0.0 and that <= 100.0 }
    }
    attribute def OxygenSaturation :> Real {
        unit percent;
        assert constraint { that >= 0.0 and that <= 100.0 }
    }
    attribute def BodyTemperature :> Real {
        unit celsius;
        assert constraint { that >= 25.0 and that <= 45.0 }
    }
    attribute def Timestamp :> Real {
        unit second;
    }
    attribute def ConfidenceScore :> Real {
        unit percent;
        assert constraint { that >= 0.0 and that <= 100.0 }
    }
    attribute def RiskScore :> Real {
        unit percent;
        assert constraint { that >= 0.0 and that <= 100.0 }
    }
    attribute def Age :> Real {
        unit year;
        assert constraint { that >= 0.0 and that <= 150.0 }
    }
    attribute def Height :> Real {
        unit centimeter;
        assert constraint { that >= 0.0 and that <= 250.0 }
    }
    attribute def Weight :> Real {
        unit kilogram;
        assert constraint { that >= 0.0 and that <= 500.0 }
    }
    attribute def PatientID :> String;
    attribute def ImageID :> String;
    attribute def LabTestName :> String;
    attribute def Modality :> String;

    item def VitalSigns {
        attribute heartRate : HeartRate;
        attribute systolicBP : SystolicBloodPressure;
        attribute diastolicBP : DiastolicBloodPressure;
        attribute respiratoryRate : RespiratoryRate;
        attribute oxygenSaturation : OxygenSaturation;
        attribute bodyTemperature : BodyTemperature;
        attribute timestamp : Timestamp;
    }
    item def MedicalImage {
        attribute imageID : ImageID;
        attribute modality : Modality;
        attribute bodyPart : String;
        attribute acquisitionTimestamp : Timestamp;
        attribute pixelData : Real [0..*];
    }
    item def LabResult {
        attribute testName : LabTestName;
        attribute value : Real;
        attribute unit : String;
        attribute normalLow : Real;
        attribute normalHigh : Real;
        attribute isAbnormal : Boolean;
        attribute collectionTimestamp : Timestamp;
    }
    item def PatientDemographics {
        attribute age : Age;
        attribute sex : String;
        attribute height : Height;
        attribute weight : Weight;
    }
    item def ElectronicHealthRecord {
        attribute patientID : PatientID;
        attribute demographics : PatientDemographics;
        attribute medicalHistory : String [0..*];
        attribute currentMedications : String [0..*];
        attribute allergies : String [0..*];
    }
    item def RawPatientData {
        attribute vitalSigns : VitalSigns [0..*];
        attribute medicalImages : MedicalImage [0..*];
        attribute labResults : LabResult [0..*];
        attribute ehr : ElectronicHealthRecord;
    }
    item def PreprocessedPatientData {
        attribute cleanedVitalSigns : VitalSigns [0..*];
        attribute enhancedImages : MedicalImage [0..*];
        attribute normalizedLabResults : LabResult [0..*];
        attribute validatedEHR : ElectronicHealthRecord;
        attribute dataQualityFlags : String [0..*];
    }
    item def DiagnosisResult {
        attribute conditionName : String;
        attribute confidenceScore : ConfidenceScore;
        attribute differentialDiagnoses : String [0..*];
    }
    item def RiskAssessment {
        attribute riskScore : RiskScore;
        attribute riskFactors : String [0..*];
        attribute predictedConditions : String [0..*];
    }
    enum def AlertSeverity {
        low;
        medium;
        high;
        critical;
    }
    item def ClinicalAlert {
        attribute alertID : String;
        attribute severity : AlertSeverity;
        attribute alertMessage : String;
        attribute timestamp : Timestamp;
        attribute source : String;
    }
    item def TreatmentRecommendation {
        attribute recommendationID : String;
        attribute medicationSuggestions : String [0..*];
        attribute procedureSuggestions : String [0..*];
        attribute lifestyleSuggestions : String [0..*];
        attribute urgency : AlertSeverity;
    }
    item def PhysicianApproval {
        attribute approvalID : String;
        attribute physicianID : String;
        attribute approvedTreatmentPlan : TreatmentRecommendation;
        attribute isApproved : Boolean;
        attribute approvalTime : Timestamp;
    }

    action def AcquirePatientDataAction {
        in patientDataRequest : String;
        out rawData : RawPatientData;
        out vitalSigns : VitalSigns;
    }
    action def CleanAndNormalizeDataAction {
        in raw : RawPatientData;
        out processed : PreprocessedPatientData;
        out flags : String [0..*];
    }
    action def RunInferenceAction {
        in processedData : PreprocessedPatientData;
        out diagnosis : DiagnosisResult;
        out riskAssessment : RiskAssessment;
    }
    action def FormulateRecommendationAction {
        in diagnosis : DiagnosisResult;
        in riskAssessment : RiskAssessment;
        out treatment : TreatmentRecommendation;
        out alert : ClinicalAlert;
    }
    action def ReviewAndApproveAction {
        in diagnosis : DiagnosisResult;
        in riskAssessment : RiskAssessment;
        in treatment : TreatmentRecommendation;
        in alert : ClinicalAlert;
        out approval : PhysicianApproval;
    }

    state def ClinicalWorkflowStateMachine {
        state Idle;
        state AcquiringData;
        state Preprocessing;
        state Analyzing;
        state Reviewing;
        state AwaitingApproval;
        state Alerting;
        transition toAcquiring {
            source Idle;
            target AcquiringData;
        }
        transition toPreprocessing {
            source AcquiringData;
            target Preprocessing;
        }
        transition toAnalyzing {
            source Preprocessing;
            target Analyzing;
        }
        transition toReviewing {
            source Analyzing;
            target Reviewing;
        }
        transition toAwaitingApproval {
            source Reviewing;
            target AwaitingApproval;
        }
        transition toIdleFromApproval {
            source AwaitingApproval;
            target Idle;
        }
        transition toAlerting {
            source Reviewing;
            target Alerting;
        }
        transition toIdleFromAlerting {
            source Alerting;
            target Idle;
        }
    }

    part def DataAcquisitionModule {
        port rawDataPort {
            out rawData : RawPatientData;
            out vitalSigns : VitalSigns;
        }
    }
    part def PreprocessingEngine {
        port rawDataPort {
            in rawData : RawPatientData;
        }
        port processedDataPort {
            out processedData : PreprocessedPatientData;
        }
        port flagsPort {
            out flags : String [0..*];
        }
    }
    part def AIInferenceEngine {
        port processedDataPort {
            in processedData : PreprocessedPatientData;
        }
        port diagnosisPort {
            out diagnosis : DiagnosisResult;
        }
        port riskAssessmentPort {
            out riskAssessment : RiskAssessment;
        }
    }
    part def ClinicalDecisionSupportModule {
        port diagnosisPort {
            in diagnosis : DiagnosisResult;
        }
        port riskAssessmentPort {
            in riskAssessment : RiskAssessment;
        }
        port approvalPort {
            in approval : PhysicianApproval;
        }
        port treatmentPort {
            out treatment : TreatmentRecommendation;
        }
        port alertPort {
            out alert : ClinicalAlert;
        }
    }
    part def PhysicianInterface {
        port diagnosisPort {
            in diagnosis : DiagnosisResult;
        }
        port riskAssessmentPort {
            in riskAssessment : RiskAssessment;
        }
        port treatmentPort {
            in treatment : TreatmentRecommendation;
        }
        port alertPort {
            in alert : ClinicalAlert;
        }
        port approvalPort {
            out approval : PhysicianApproval;
        }
    }
    part def RealTimeMonitoringDashboard {
        port vitalSignsPort {
            in vitalSigns : VitalSigns;
        }
        port alertPort {
            in alert : ClinicalAlert;
        }
    }

    actor Physician;
    actor HospitalStaff;

    part def ClinicalDecisionSupportSystem {
        part dataAcquisition : DataAcquisitionModule;
        part preprocessing : PreprocessingEngine;
        part inference : AIInferenceEngine;
        part cds : ClinicalDecisionSupportModule;
        part physicianInterface : PhysicianInterface;
        part dashboard : RealTimeMonitoringDashboard;

        state workflow : ClinicalWorkflowStateMachine;

        flow rawDataFlow of RawPatientData
            from dataAcquisition.rawDataPort.rawData
            to preprocessing.rawDataPort.rawData;
        flow vitalSignsFlow of VitalSigns
            from dataAcquisition.rawDataPort.vitalSigns
            to dashboard.vitalSignsPort.vitalSigns;
        flow processedDataFlow of PreprocessedPatientData
            from preprocessing.processedDataPort.processedData
            to inference.processedDataPort.processedData;
        flow diagnosisToCdsFlow of DiagnosisResult
            from inference.diagnosisPort.diagnosis
            to cds.diagnosisPort.diagnosis;
        flow diagnosisToInterfaceFlow of DiagnosisResult
            from inference.diagnosisPort.diagnosis
            to physicianInterface.diagnosisPort.diagnosis;
        flow riskToCdsFlow of RiskAssessment
            from inference.riskAssessmentPort.riskAssessment
            to cds.riskAssessmentPort.riskAssessment;
        flow riskToInterfaceFlow of RiskAssessment
            from inference.riskAssessmentPort.riskAssessment
            to physicianInterface.riskAssessmentPort.riskAssessment;
        flow treatmentFlow of TreatmentRecommendation
            from cds.treatmentPort.treatment
            to physicianInterface.treatmentPort.treatment;
        flow alertToInterfaceFlow of ClinicalAlert
            from cds.alertPort.alert
            to physicianInterface.alertPort.alert;
        flow alertToDashboardFlow of ClinicalAlert
            from cds.alertPort.alert
            to dashboard.alertPort.alert;
        flow approvalFlow of PhysicianApproval
            from physicianInterface.approvalPort.approval
            to cds.approvalPort.approval;
    }

    package Requirements {
        requirement def DataAcquisitionReq {
            doc
            /* The system shall acquire comprehensive patient data including real-time vital signs, medical images, lab results, and electronic health records. */
        }
        requirement def PreprocessingReq {
            doc
            /* The system shall clean, validate, and normalize acquired patient data to ensure high quality and consistency before AI analysis. */
        }
        requirement def DiagnosisReq {
            doc
            /* The system shall generate a potential diagnosis with a confidence score from the prepared patient data. */
        }
        requirement def RiskAssessmentReq {
            doc
            /* The system shall generate a risk assessment that predicts the likelihood of future health problems. */
        }
        requirement def TreatmentRecommendationReq {
            doc
            /* The system shall formulate specific treatment recommendations based on diagnosis and risk assessment. */
        }
        requirement def AlertReq {
            doc
            /* The system shall generate clinical alerts when a critical or rapidly deteriorating condition is detected. */
        }
        requirement def PhysicianApprovalReq {
            doc
            /* The system shall not execute any treatment plan without explicit physician approval. */
        }
        requirement def MonitoringDashboardReq {
            doc
            /* The system shall provide a real-time monitoring dashboard for patient vital signs and active alerts for hospital staff. */
        }
    }
}
