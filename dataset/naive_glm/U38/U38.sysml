package ClinicalDecisionSupportSystem {
    public import ScalarValues::*;

    package Units {
        value type BeatsPerMin {
            unit bpm;
        }
        value type MillimetersOfMercury {
            unit mmHg;
        }
        value type Percent {
            unit percent;
        }
        value type Seconds {
            unit s;
        }
        value type Temperature {
            unit degC;
        }
        value type RespirationsPerMin {
            unit breathsPerMin;
        }
    }

    package Enums {
        enum SeverityLevel { low, moderate, high, critical }
        enum UrgencyLevel { routine, urgent, immediate }
        enum AlertStatus { inactive, active, acknowledged, resolved }
        enum ApprovalStatus { pending, approved, rejected }
        enum PatientStatus { stable, deteriorating, critical }
        enum ImageModality { xray, ct, mri, ultrasound }
    }

    package Items {
        import Units::*;
        import Enums::*;

        item def VitalSigns {
            attribute heartRate : BeatsPerMin;
            attribute systolicBP : MillimetersOfMercury;
            attribute diastolicBP : MillimetersOfMercury;
            attribute temperature : Temperature;
            attribute respiratoryRate : RespirationsPerMin;
            attribute oxygenSaturation : Percent;
            attribute timestamp : String;
        }

        item def MedicalImage {
            attribute modality : ImageModality;
            attribute bodyPart : String;
            attribute imageReference : String;
            attribute acquisitionTime : String;
        }

        item def LabResult {
            attribute testName : String;
            attribute value : Real;
            attribute unit : String;
            attribute referenceRangeLow : Real;
            attribute referenceRangeHigh : Real;
            attribute isAbnormal : Boolean;
            attribute collectionTime : String;
        }

        item def ElectronicHealthRecord {
            attribute patientId : String;
            attribute patientName : String;
            attribute age : Integer;
            attribute sex : String;
            attribute medicalHistory : String[0..*];
            attribute allergies : String[0..*];
            attribute currentMedications : String[0..*];
            attribute demographics : String;
        }

        item def RawPatientData {
            attribute vitalSigns : VitalSigns;
            attribute images : MedicalImage[0..*];
            attribute labResults : LabResult[0..*];
            attribute ehr : ElectronicHealthRecord;
            attribute acquisitionTime : String;
        }

        item def PreprocessedData {
            attribute normalizedVitalSigns : VitalSigns;
            attribute enhancedImages : MedicalImage[0..*];
            attribute validatedLabResults : LabResult[0..*];
            attribute consolidatedEHR : ElectronicHealthRecord;
            attribute dataQualityScore : Percent;
            attribute abnormalFlags : String[0..*];
            attribute preprocessingComplete : Boolean;
        }

        item def Diagnosis {
            attribute condition : String;
            attribute confidenceScore : Percent;
            attribute supportingEvidence : String[0..*];
            attribute differentialDiagnoses : String[0..*];
        }

        item def RiskAssessment {
            attribute predictedCondition : String;
            attribute riskScore : Percent;
            attribute timeHorizon : String;
            attribute riskFactors : String[0..*];
            attribute patientStatus : PatientStatus;
        }

        item def TreatmentRecommendation {
            attribute treatmentId : String;
            attribute description : String;
            attribute rationale : String;
            attribute priority : Integer;
            attribute contraindications : String[0..*];
        }

        item def ClinicalAlert {
            attribute alertId : String;
            attribute description : String;
            attribute severity : SeverityLevel;
            attribute urgency : UrgencyLevel;
            attribute status : AlertStatus;
            attribute triggeredAt : String;
        }

        item def AIOutput {
            attribute diagnosis : Diagnosis;
            attribute riskAssessment : RiskAssessment;
            attribute generatedAt : String;
        }

        item def DecisionSupportOutput {
            attribute aiOutput : AIOutput;
            attribute recommendations : TreatmentRecommendation[0..*];
            attribute alerts : ClinicalAlert[0..*];
            attribute generatedAt : String;
        }

        item def PhysicianReview {
            attribute reviewId : String;
            attribute decisionSupportOutput : DecisionSupportOutput;
            attribute approvalStatus : ApprovalStatus;
            attribute reviewerComments : String;
            attribute reviewerId : String;
            attribute reviewedAt : String;
        }
    }

    package Ports {
        import Items::*;

        port def RawDataOutPort {
            out attribute rawPatientData : RawPatientData;
        }
        port def RawDataInPort {
            in attribute rawPatientData : RawPatientData;
        }
        port def PreprocessedDataOutPort {
            out attribute preprocessedData : PreprocessedData;
        }
        port def PreprocessedDataInPort {
            in attribute preprocessedData : PreprocessedData;
        }
        port def AIOutputOutPort {
            out attribute aiOutput : AIOutput;
        }
        port def AIOutputInPort {
            in attribute aiOutput : AIOutput;
        }
        port def DecisionOutputOutPort {
            out attribute decisionSupportOutput : DecisionSupportOutput;
        }
        port def DecisionOutputInPort {
            in attribute decisionSupportOutput : DecisionSupportOutput;
        }
        port def ReviewOutPort {
            out attribute physicianReview : PhysicianReview;
        }
        port def VitalSignsStreamOutPort {
            out attribute vitalSigns : VitalSigns;
        }
        port def VitalSignsStreamInPort {
            in attribute vitalSigns : VitalSigns;
        }
        port def AlertStreamOutPort {
            out attribute alerts : ClinicalAlert[0..*];
        }
        port def AlertStreamInPort {
            in attribute alerts : ClinicalAlert[0..*];
        }
    }

    package Requirements {
        import Items::*;

        requirement def DataAcquisitionRequirement {
            doc /* The system shall acquire real-time vital signs, medical images, lab results, and EHR. */
            attribute id : String;
            attribute text : String;
        }

        requirement def PreprocessingRequirement {
            doc /* The system shall clean, validate, and normalize patient data. */
            attribute id : String;
            attribute text : String;
        }

        requirement def AIInferenceRequirement {
            doc /* The system shall generate a diagnosis with confidence score and risk assessment. */
            attribute id : String;
            attribute text : String;
        }

        requirement def DecisionSupportRequirement {
            doc /* The system shall formulate treatment recommendations and clinical alerts. */
            attribute id : String;
            attribute text : String;
        }

        requirement def HumanOversightRequirement {
            doc /* No treatment action shall be taken without explicit physician approval. */
            attribute id : String;
            attribute text : String;
        }

        requirement def MonitoringRequirement {
            doc /* The system shall provide real-time monitoring of vital signs and alerts. */
            attribute id : String;
            attribute text : String;
        }

        requirement dataAcqReq : DataAcquisitionRequirement {
            id = "REQ-001";
            text = "Acquire real-time vital signs, medical images, lab results, and EHR.";
        }
        requirement preprocessReq : PreprocessingRequirement {
            id = "REQ-002";
            text = "Clean, validate, and normalize patient data with quality scoring.";
        }
        requirement aiInferenceReq : AIInferenceRequirement {
            id = "REQ-003";
            text = "Generate diagnosis with confidence score and risk assessment.";
        }
        requirement decisionSupportReq : DecisionSupportRequirement {
            id = "REQ-004";
            text = "Formulate treatment recommendations and severity-based clinical alerts.";
        }
        requirement humanOversightReq : HumanOversightRequirement {
            id = "REQ-005";
            text = "Require explicit physician approval before any treatment action.";
        }
        requirement monitoringReq : MonitoringRequirement {
            id = "REQ-006";
            text = "Provide real-time monitoring dashboard for vital signs and active alerts.";
        }
    }

    package Behaviors {
        import Items::*;
        import Enums::*;

        action def AcquirePatientData {
            in patientId : String;
            out rawPatientData : RawPatientData;
        }

        action def CleanData {
            in rawPatientData : RawPatientData;
            out cleanedData : RawPatientData;
        }

        action def ValidateData {
            in cleanedData : RawPatientData;
            out validatedData : RawPatientData;
            out abnormalFlags : String[0..*];
        }

        action def NormalizeData {
            in validatedData : RawPatientData;
            out normalizedVitalSigns : VitalSigns;
        }

        action def EnhanceImages {
            in images : MedicalImage[0..*];
            out enhancedImages : MedicalImage[0..*];
        }

        action def ComputeQualityScore {
            in validatedData : RawPatientData;
            out qualityScore : Percent;
        }

        action def PreprocessData {
            in rawPatientData : RawPatientData;
            out preprocessedData : PreprocessedData;
        }

        action def ExtractFeatures {
            in preprocessedData : PreprocessedData;
            out featureVector : String;
        }

        action def GenerateDiagnosis {
            in featureVector : String;
            out diagnosis : Diagnosis;
        }

        action def AssessRisk {
            in featureVector : String;
            in diagnosis : Diagnosis;
            out riskAssessment : RiskAssessment;
        }

        action def RunAIInference {
            in preprocessedData : PreprocessedData;
            out aiOutput : AIOutput;
        }

        action def GenerateRecommendations {
            in aiOutput : AIOutput;
            out recommendations : TreatmentRecommendation[0..*];
        }

        action def GenerateAlerts {
            in aiOutput : AIOutput;
            out alerts : ClinicalAlert[0..*];
        }

        action def GenerateDecisionSupport {
            in aiOutput : AIOutput;
            out decisionSupportOutput : DecisionSupportOutput;
        }

        action def PresentFindings {
            in decisionSupportOutput : DecisionSupportOutput;
        }

        action def AwaitApproval {
            in decisionSupportOutput : DecisionSupportOutput;
            out physicianReview : PhysicianReview;
        }

        action def PhysicianReviewAction {
            in decisionSupportOutput : DecisionSupportOutput;
            out physicianReview : PhysicianReview;
        }

        action def UpdateDisplay {
            in vitalSigns : VitalSigns;
            in alerts : ClinicalAlert[0..*];
        }

        state def PreprocessingEngineStates {
            entry; then idle;
            state idle;
            transition idle to cleaning when rawDataReceived;
            state cleaning {
                do CleanData;
            }
            transition cleaning to validating;
            state validating {
                do ValidateData;
            }
            transition validating to normalizing;
            state normalizing {
                do NormalizeData;
            }
            transition normalizing to enhancing;
            state enhancing {
                do EnhanceImages;
            }
            transition enhancing to scoring;
            state scoring {
                do ComputeQualityScore;
            }
            transition scoring to dispatching;
            state dispatching;
            transition dispatching to idle when preprocessedDataSent;
        }

        state def AIInferenceStates {
            entry; then ready;
            state ready;
            transition ready to featureExtraction when preprocessedDataReceived;
            state featureExtraction {
                do ExtractFeatures;
            }
            transition featureExtraction to diagnosing;
            state diagnosing {
                do GenerateDiagnosis;
            }
            transition diagnosing to assessingRisk;
            state assessingRisk {
                do AssessRisk;
            }
            transition assessingRisk to outputReady;
            state outputReady;
            transition outputReady to ready when aiOutputSent;
        }

        state def DecisionSupportStates {
            entry; then awaiting;
            state awaiting;
            transition awaiting to generatingRecommendations when aiOutputReceived;
            state generatingRecommendations {
                do GenerateRecommendations;
            }
            transition generatingRecommendations to generatingAlerts;
            state generatingAlerts {
                do GenerateAlerts;
            }
            transition generatingAlerts to dispatching;
            state dispatching;
            transition dispatching to awaiting when decisionOutputSent;
        }

        state def PhysicianInterfaceStates {
            entry; then waitingForReview;
            state waitingForReview;
            transition waitingForReview to presentingFindings when decisionOutputReceived;
            state presentingFindings {
                do PresentFindings;
            }
            transition presentingFindings to awaitingApproval;
            state awaitingApproval {
                do AwaitApproval;
            }
            transition awaitingApproval to waitingForReview when reviewCompleted;
        }

        state def MonitoringDashboardStates {
            entry; then displaying;
            state displaying {
                do UpdateDisplay;
            }
            transition displaying to displaying after 2 [s];
        }

        state def DataAcquisitionStates {
            entry; then acquiring;
            state acquiring {
                do AcquirePatientData;
            }
            transition acquiring to acquiring after 1 [s];
        }
    }

    package Modules {
        import Items::*;
        import Ports::*;
        import Behaviors::*;
        import Enums::*;
        import Units::*;

        part def DataAcquisitionModule {
            port rawOut : RawDataOutPort;
            port vitalStreamOut : VitalSignsStreamOutPort;
            attribute acquisitionInterval : Seconds = 1;
            attribute patientId : String;
            attribute latestVitalSigns : VitalSigns;
            attribute latestRawData : RawPatientData;

            exhibit state DataAcquisitionStates;

            action acquireVitals : AcquirePatientData {
                in patientId = patientId;
                out rawPatientData = latestRawData;
            }
        }

        part def PreprocessingEngine {
            port rawIn : RawDataInPort;
            port preprocessedOut : PreprocessedDataOutPort;
            attribute qualityThreshold : Percent = 80;
            attribute abnormalFlagCount : Integer = 0;
            attribute latestPreprocessedData : PreprocessedData;

            exhibit state PreprocessingEngineStates;

            action preprocess : PreprocessData {
                in rawPatientData = rawIn.rawPatientData;
                out preprocessedData = latestPreprocessedData;
            }
        }

        part def AIInferenceEngine {
            port preprocessedIn : PreprocessedDataInPort;
            port aiOut : AIOutputOutPort;
            attribute modelVersion : String = "ClinicalAI-v2.4";
            attribute minConfidence : Percent = 70;
            attribute latestAIOutput : AIOutput;

            exhibit state AIInferenceStates;

            action infer : RunAIInference {
                in preprocessedData = preprocessedIn.preprocessedData;
                out aiOutput = latestAIOutput;
            }
        }

        part def ClinicalDecisionSupportModule {
            port aiIn : AIOutputInPort;
            port decisionOut : DecisionOutputOutPort;
            port alertStreamOut : AlertStreamOutPort;
            attribute criticalRiskThreshold : Percent = 85;
            attribute highRiskThreshold : Percent = 70;
            attribute latestDecisionOutput : DecisionSupportOutput;
            attribute activeAlerts : ClinicalAlert[0..*];

            exhibit state DecisionSupportStates;

            action generateSupport : GenerateDecisionSupport {
                in aiOutput = aiIn.aiOutput;
                out decisionSupportOutput = latestDecisionOutput;
            }
        }

        part def PhysicianInterface {
            port decisionIn : DecisionOutputInPort;
            port reviewOut : ReviewOutPort;
            attribute requiresApproval : Boolean = true;
            attribute latestReview : PhysicianReview;
            attribute physicianId : String;

            exhibit state PhysicianInterfaceStates;

            action review : PhysicianReviewAction {
                in decisionSupportOutput = decisionIn.decisionSupportOutput;
                out physicianReview = latestReview;
            }
        }

        part def MonitoringDashboard {
            port vitalStreamIn : VitalSignsStreamInPort;
            port alertStreamIn : AlertStreamInPort;
            attribute refreshRate : Seconds = 2;
            attribute displayedVitalSigns : VitalSigns;
            attribute displayedAlerts : ClinicalAlert[0..*];

            exhibit state MonitoringDashboardStates;

            action updateDisplay : UpdateDisplay {
                in vitalSigns = vitalStreamIn.vitalSigns;
                in alerts = alertStreamIn.alerts;
            }
        }
    }

    package System {
        import Modules::*;
        import Ports::*;
        import Items::*;
        import Requirements::*;
        import Enums::*;
        import Units.*;

        part def ClinicalDecisionSupportSystem {
            satisfy dataAcqReq;
            satisfy preprocessReq;
            satisfy aiInferenceReq;
            satisfy decisionSupportReq;
            satisfy humanOversightReq;
            satisfy monitoringReq;

            attribute systemId : String = "CDSS-001";
            attribute systemVersion : String = "1.0";
            attribute operational : Boolean = true;

            part dataAcquisition : DataAcquisitionModule {
                attribute patientId = "PT-00001";
            }
            part preprocessingEngine : PreprocessingEngine;
            part aiInferenceEngine : AIInferenceEngine;
            part decisionSupportModule : ClinicalDecisionSupportModule;
            part physicianInterface : PhysicianInterface {
                attribute physicianId = "DR-0042";
            }
            part monitoringDashboard : MonitoringDashboard;

            connect dataAcquisition.rawOut to preprocessingEngine.rawIn;
            connect preprocessingEngine.preprocessedOut to aiInferenceEngine.preprocessedIn;
            connect aiInferenceEngine.aiOut to decisionSupportModule.aiIn;
            connect decisionSupportModule.decisionOut to physicianInterface.decisionIn;
            connect dataAcquisition.vitalStreamOut to monitoringDashboard.vitalStreamIn;
            connect decisionSupportModule.alertStreamOut to monitoringDashboard.alertStreamIn;

            flow of RawPatientData from dataAcquisition.rawOut to preprocessingEngine.rawIn;
            flow of PreprocessedData from preprocessingEngine.preprocessedOut to aiInferenceEngine.preprocessedIn;
            flow of AIOutput from aiInferenceEngine.aiOut to decisionSupportModule.aiIn;
            flow of DecisionSupportOutput from decisionSupportModule.decisionOut to physicianInterface.decisionIn;
            flow of VitalSigns from dataAcquisition.vitalStreamOut to monitoringDashboard.vitalStreamIn;
            flow of ClinicalAlert[0..*] from decisionSupportModule.alertStreamOut to monitoringDashboard.alertStreamIn;
        }

        part cdssInstance : ClinicalDecisionSupportSystem;
    }
}
