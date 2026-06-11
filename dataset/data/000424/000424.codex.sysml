package AIHealthcareModel {

  import ScalarValues::*;
  import SI::*;

  value def BeatPerMinute :> Real;
  value def MillimeterMercury :> Real;
  value def MilligramPerDeciliter :> Real;
  value def Percent :> Real;
  value def Second :> Real;
  value def Millisecond :> Real;
  value def ConfidenceScore :> Real;
  value def RiskScore :> Real;

  item def PatientIdentifier {
    attribute medicalRecordNumber : String;
    attribute encounterId : String;
  }

  item def VitalSigns {
    attribute heartRate : BeatPerMinute;
    attribute systolicBloodPressure : MillimeterMercury;
    attribute diastolicBloodPressure : MillimeterMercury;
    attribute oxygenSaturation : Percent;
    attribute respiratoryRate : BeatPerMinute;
    attribute bodyTemperatureCelsius : Real;
    attribute measuredAt : String;
  }

  item def LabResult {
    attribute testCode : String;
    attribute testName : String;
    attribute numericValue : Real;
    attribute unitText : String;
    attribute referenceLow : Real;
    attribute referenceHigh : Real;
    attribute resultedAt : String;
  }

  item def ImagingStudy {
    attribute modality : String;
    attribute bodyRegion : String;
    attribute studyTimestamp : String;
    attribute imageUri : String;
  }

  item def MedicationOrder {
    attribute medicationName : String;
    attribute doseText : String;
    attribute route : String;
    attribute frequency : String;
    attribute startTime : String;
  }

  item def PatientRecord {
    attribute patientId : PatientIdentifier;
    attribute ageYears : Real;
    attribute sexAtBirth : String;
    attribute activeDiagnoses : String;
    attribute allergyList : String;
    attribute clinicalNotes : String;
  }

  item def ClinicalContext {
    attribute patientRecord : PatientRecord;
    attribute latestVitals : VitalSigns;
    attribute recentLabs : LabResult[0..*];
    attribute imagingStudies : ImagingStudy[0..*];
    attribute activeMedications : MedicationOrder[0..*];
  }

  item def RiskAssessment {
    attribute sepsisRisk : RiskScore;
    attribute deteriorationRisk : RiskScore;
    attribute readmissionRisk : RiskScore;
    attribute confidence : ConfidenceScore;
    attribute generatedAt : String;
  }

  item def Recommendation {
    attribute priority : String;
    attribute summary : String;
    attribute rationale : String;
    attribute suggestedAction : String;
    attribute confidence : ConfidenceScore;
  }

  item def ClinicalAlert {
    attribute alertId : String;
    attribute severity : String;
    attribute title : String;
    attribute message : String;
    attribute patientId : PatientIdentifier;
    attribute createdAt : String;
  }

  item def AuditEvent {
    attribute eventId : String;
    attribute actor : String;
    attribute actionName : String;
    attribute timestamp : String;
    attribute modelVersion : String;
    attribute explanationHash : String;
  }

  port def PatientDataInputPort {
    in item record : PatientRecord;
    in item vitals : VitalSigns;
    in item lab : LabResult;
    in item image : ImagingStudy;
    in item medication : MedicationOrder;
  }

  port def ClinicalContextPort {
    out item context : ClinicalContext;
  }

  port def ModelInferencePort {
    in item context : ClinicalContext;
    out item assessment : RiskAssessment;
    out item recommendation : Recommendation;
  }

  port def AlertPort {
    out item alert : ClinicalAlert;
  }

  port def ClinicianReviewPort {
    in item acknowledgement : String;
    out item recommendation : Recommendation;
    out item alert : ClinicalAlert;
  }

  port def AuditPort {
    out item event : AuditEvent;
  }

  part def ElectronicHealthRecordGateway {
    port patientDataOut : PatientDataInputPort;
    attribute maximumInterfaceLatency : Second = 2.0;
  }

  part def DataIngestionService {
    port patientDataIn : ~PatientDataInputPort;
    port clinicalContextOut : ClinicalContextPort;

    action ingestAndNormalize {
      in item record : PatientRecord;
      in item vitals : VitalSigns;
      in item lab : LabResult;
      in item image : ImagingStudy;
      in item medication : MedicationOrder;
      out item context : ClinicalContext;
    }
  }

  part def PrivacyAndSecurityService {
    port contextIn : ~ClinicalContextPort;
    port contextOut : ClinicalContextPort;
    attribute encryptionEnabled : Boolean = true;
    attribute accessControlPolicy : String = "leastPrivilegeClinicalAccess";

    action deidentifyForModelUse {
      in item context : ClinicalContext;
      out item protectedContext : ClinicalContext;
    }
  }

  part def ClinicalAIInferenceEngine {
    port inference : ModelInferencePort;
    attribute modelVersion : String = "clinical-risk-transformer-4.2";
    attribute targetInferenceLatency : Millisecond = 750.0;
    attribute minimumConfidenceForActionableOutput : ConfidenceScore = 0.72;

    action assessRisk {
      in item context : ClinicalContext;
      out item assessment : RiskAssessment;
    }

    action generateRecommendation {
      in item context : ClinicalContext;
      in item assessment : RiskAssessment;
      out item recommendation : Recommendation;
    }

    state def InferenceLifecycle {
      state Idle;
      state ValidatingInput;
      state RunningModel;
      state ExplainingOutput;
      state AwaitingReview;
      state Faulted;

      transition initial then Idle;
      transition receiveContext first Idle then ValidatingInput;
      transition validContext first ValidatingInput then RunningModel;
      transition invalidContext first ValidatingInput then Faulted;
      transition inferenceComplete first RunningModel then ExplainingOutput;
      transition explanationReady first ExplainingOutput then AwaitingReview;
      transition reviewClosed first AwaitingReview then Idle;
      transition runtimeError first RunningModel then Faulted;
      transition reset first Faulted then Idle;
    }
  }

  part def AlertingService {
    port inferenceIn : ~ModelInferencePort;
    port alertOut : AlertPort;
    attribute criticalSepsisRiskThreshold : RiskScore = 0.85;
    attribute highDeteriorationRiskThreshold : RiskScore = 0.80;

    action createAlert {
      in item assessment : RiskAssessment;
      in item recommendation : Recommendation;
      out item alert : ClinicalAlert;
    }
  }

  part def ClinicianWorkspace {
    port alertIn : ~AlertPort;
    port review : ClinicianReviewPort;
    attribute supportedRoles : String = "physician,nurse,pharmacist,careManager";

    action displayDecisionSupport {
      in item alert : ClinicalAlert;
      in item recommendation : Recommendation;
      out item acknowledgement : String;
    }
  }

  part def AuditAndMonitoringService {
    port auditIn : AuditPort;
    attribute retentionYears : Real = 7.0;

    action recordModelDecision {
      in item assessment : RiskAssessment;
      in item recommendation : Recommendation;
      out item event : AuditEvent;
    }
  }

  part def ArtificialIntelligenceHealthcareSystem {
    attribute primaryFunction : String = "Continuously analyzes patient data to detect clinical risk and provide explainable decision support recommendations to healthcare professionals.";
    attribute availabilityTarget : Percent = 99.9;

    part ehrGateway : ElectronicHealthRecordGateway;
    part ingestion : DataIngestionService;
    part security : PrivacyAndSecurityService;
    part aiEngine : ClinicalAIInferenceEngine;
    part alerting : AlertingService;
    part workspace : ClinicianWorkspace;
    part audit : AuditAndMonitoringService;

    connect ehrGateway.patientDataOut to ingestion.patientDataIn;
    connect ingestion.clinicalContextOut to security.contextIn;
    connect security.contextOut to aiEngine.inference;
    connect aiEngine.inference to alerting.inferenceIn;
    connect alerting.alertOut to workspace.alertIn;
    connect workspace.review to audit.auditIn;

    action performClinicalDecisionSupport {
      in item record : PatientRecord;
      in item vitals : VitalSigns;
      in item lab : LabResult;
      in item image : ImagingStudy;
      in item medication : MedicationOrder;
      out item alert : ClinicalAlert;
      out item recommendation : Recommendation;
      out item auditEvent : AuditEvent;

      first ingestAndNormalize;
      then deidentifyForModelUse;
      then assessRisk;
      then generateRecommendation;
      then createAlert;
      then displayDecisionSupport;
      then recordModelDecision;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : ArtificialIntelligenceHealthcareSystem;
    require constraint {
      system.primaryFunction == "Continuously analyzes patient data to detect clinical risk and provide explainable decision support recommendations to healthcare professionals."
    }
  }

  requirement def ClinicalRiskDetectionRequirement {
    subject assessment : RiskAssessment;
    require constraint {
      assessment.sepsisRisk >= 0.0 and assessment.sepsisRisk <= 1.0 and
      assessment.deteriorationRisk >= 0.0 and assessment.deteriorationRisk <= 1.0 and
      assessment.readmissionRisk >= 0.0 and assessment.readmissionRisk <= 1.0
    }
  }

  requirement def ExplainabilityRequirement {
    subject recommendation : Recommendation;
    require constraint {
      recommendation.rationale != "" and recommendation.confidence >= 0.72
    }
  }

  requirement def LatencyRequirement {
    subject engine : ClinicalAIInferenceEngine;
    require constraint {
      engine.targetInferenceLatency <= 1000.0
    }
  }

  requirement def PrivacyRequirement {
    subject security : PrivacyAndSecurityService;
    require constraint {
      security.encryptionEnabled == true
    }
  }

  requirement def HumanOversightRequirement {
    subject workspace : ClinicianWorkspace;
    require constraint {
      workspace.supportedRoles != ""
    }
  }

  requirement def AuditabilityRequirement {
    subject audit : AuditAndMonitoringService;
    require constraint {
      audit.retentionYears >= 7.0
    }
  }

  part healthcareAISystem : ArtificialIntelligenceHealthcareSystem;

}