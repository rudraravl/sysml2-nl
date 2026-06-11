package VistAImagingHighLevelModel {

  private import ScalarValues::*;
  private import ISQ::*;
  private import SI::*;

  attribute def StudyIdentifier :> String;
  attribute def PatientIdentifier :> String;
  attribute def UserIdentifier :> String;
  attribute def AccessionNumber :> String;
  attribute def DicomUid :> String;
  attribute def Uri :> String;

  enum def StudyStatus {
    enum pending;
    enum acquired;
    enum indexed;
    enum available;
    enum archived;
    enum unavailable;
  }

  enum def ImageModality {
    enum radiography;
    enum computedTomography;
    enum magneticResonance;
    enum ultrasound;
    enum pathology;
    enum clinicalPhoto;
    enum scannedDocument;
    enum waveform;
  }

  enum def AccessDecision {
    enum permit;
    enum deny;
    enum emergencyOverride;
  }

  item def PatientContext {
    attribute patientId : PatientIdentifier;
    attribute fullName : String;
    attribute dateOfBirth : String;
    attribute facilityCode : String;
  }

  item def ClinicalOrder {
    attribute orderId : String;
    attribute patientId : PatientIdentifier;
    attribute accession : AccessionNumber;
    attribute requestedModality : ImageModality;
    attribute orderingProviderId : UserIdentifier;
    attribute clinicalIndication : String;
  }

  item def ImageStudy {
    attribute studyId : StudyIdentifier;
    attribute patientId : PatientIdentifier;
    attribute accession : AccessionNumber;
    attribute modality : ImageModality;
    attribute studyInstanceUid : DicomUid;
    attribute status : StudyStatus;
    attribute imageCount : Integer;
    attribute totalSize : ISQ::MassValue;
    attribute acquiredAt : String;
  }

  item def ImageObject {
    attribute sopInstanceUid : DicomUid;
    attribute studyInstanceUid : DicomUid;
    attribute modality : ImageModality;
    attribute frameCount : Integer;
    attribute compressedSize : ISQ::MassValue;
    attribute checksum : String;
    attribute contentUri : Uri;
  }

  item def DiagnosticReport {
    attribute reportId : String;
    attribute studyId : StudyIdentifier;
    attribute patientId : PatientIdentifier;
    attribute authorId : UserIdentifier;
    attribute impression : String;
    attribute signedAt : String;
  }

  item def AuditEvent {
    attribute eventId : String;
    attribute userId : UserIdentifier;
    attribute patientId : PatientIdentifier;
    attribute studyId : StudyIdentifier;
    attribute actionName : String;
    attribute decision : AccessDecision;
    attribute eventTime : String;
  }

  item def DisplayRequest {
    attribute requesterId : UserIdentifier;
    attribute patientId : PatientIdentifier;
    attribute studyId : StudyIdentifier;
    attribute clinicalPurpose : String;
    attribute emergencyAccessRequested : Boolean;
  }

  item def DisplaySession {
    attribute sessionId : String;
    attribute requesterId : UserIdentifier;
    attribute studyId : StudyIdentifier;
    attribute viewportCount : Integer;
    attribute startedAt : String;
  }

  port def OrderPort {
    in item order : ClinicalOrder;
  }

  port def PatientContextPort {
    inout item patient : PatientContext;
  }

  port def ImageAcquisitionPort {
    in item image : ImageObject;
    out item study : ImageStudy;
  }

  port def StudyQueryPort {
    in item request : DisplayRequest;
    out item study : ImageStudy;
  }

  port def ImageRetrievalPort {
    in item request : DisplayRequest;
    out item image : ImageObject;
  }

  port def ReportPort {
    inout item report : DiagnosticReport;
  }

  port def AuditPort {
    out item audit : AuditEvent;
  }

  port def DisplayPort {
    in item image : ImageObject;
    out item session : DisplaySession;
  }

  part def ClinicalInformationSystem {
    port orders : OrderPort;
    port patients : PatientContextPort;
    port reports : ReportPort;
  }

  part def ImagingModalityGateway {
    port orders : OrderPort;
    port acquisition : ImageAcquisitionPort;

    action acquireStudy {
      in item order : ClinicalOrder;
      out item study : ImageStudy;
      out item image : ImageObject;

      first start;
      then validateOrder;
      then captureImageObjects;
      then assignDicomIdentifiers;
      then transmitToArchive;
      then done;

      action validateOrder;
      action captureImageObjects;
      action assignDicomIdentifiers;
      action transmitToArchive;
    }
  }

  part def ImageArchive {
    attribute availableCapacity : ISQ::MassValue;
    attribute retentionPeriod : ISQ::TimeValue;
    attribute replicatedCopies : Integer;

    port acquisition : ImageAcquisitionPort;
    port query : StudyQueryPort;
    port retrieval : ImageRetrievalPort;
    port audit : AuditPort;

    state archiveState {
      entry; then online;

      state online;
      state ingesting;
      state indexing;
      state serving;
      state degraded;
      state offline;

      transition online_to_ingesting
        first online
        accept item image : ImageObject
        then ingesting;

      transition ingesting_to_indexing
        first ingesting
        then indexing;

      transition indexing_to_online
        first indexing
        then online;

      transition online_to_serving
        first online
        accept item request : DisplayRequest
        then serving;

      transition serving_to_online
        first serving
        then online;

      transition online_to_degraded
        first online
        if availableCapacity < 500 ['GB']
        then degraded;

      transition degraded_to_offline
        first degraded
        if replicatedCopies < 1
        then offline;
    }

    action ingestAndIndexStudy {
      in item image : ImageObject;
      out item study : ImageStudy;
      out item audit : AuditEvent;

      first receiveImageObject;
      then verifyChecksum;
      then storeImmutableObject;
      then createPatientStudyIndex;
      then publishAvailability;
      then recordAuditEvent;
      then done;

      action receiveImageObject;
      action verifyChecksum;
      action storeImmutableObject;
      action createPatientStudyIndex;
      action publishAvailability;
      action recordAuditEvent;
    }
  }

  part def AccessControlService {
    port patientContext : PatientContextPort;
    port audit : AuditPort;

    action authorizeDisplay {
      in item request : DisplayRequest;
      in item patient : PatientContext;
      out decision : AccessDecision;
      out item audit : AuditEvent;

      first identifyRequester;
      then verifyClinicalRelationship;
      then evaluateEmergencyOverride;
      then issueDecision;
      then recordAuthorizationAudit;
      then done;

      action identifyRequester;
      action verifyClinicalRelationship;
      action evaluateEmergencyOverride;
      action issueDecision;
      action recordAuthorizationAudit;
    }
  }

  part def DiagnosticViewer {
    attribute maximumOpenViewports : Integer;
    attribute supportedWindowLevel : Boolean;
    attribute supportsMeasurements : Boolean;

    port retrieval : ImageRetrievalPort;
    port display : DisplayPort;
    port reports : ReportPort;
    port audit : AuditPort;

    state viewerState {
      entry; then idle;

      state idle;
      state requestingAccess;
      state loadingStudy;
      state displayingStudy;
      state documentingFindings;
      state closed;

      transition idle_to_requestingAccess
        first idle
        accept item request : DisplayRequest
        then requestingAccess;

      transition requestingAccess_to_loadingStudy
        first requestingAccess
        if true
        then loadingStudy;

      transition loadingStudy_to_displayingStudy
        first loadingStudy
        accept item image : ImageObject
        then displayingStudy;

      transition displayingStudy_to_documentingFindings
        first displayingStudy
        accept item report : DiagnosticReport
        then documentingFindings;

      transition documentingFindings_to_closed
        first documentingFindings
        then closed;
    }

    action displayStudyForClinicalUse {
      in item request : DisplayRequest;
      out item session : DisplaySession;
      out item report : DiagnosticReport;

      first requestAuthorization;
      then retrieveStudyManifest;
      then streamImageObjects;
      then renderDiagnosticView;
      then supportMeasurementsAndAnnotations;
      then createOrUpdateReport;
      then recordViewingAudit;
      then done;

      action requestAuthorization;
      action retrieveStudyManifest;
      action streamImageObjects;
      action renderDiagnosticView;
      action supportMeasurementsAndAnnotations;
      action createOrUpdateReport;
      action recordViewingAudit;
    }
  }

  part def AuditRepository {
    attribute minimumRetentionPeriod : ISQ::TimeValue;
    port auditIn : AuditPort;

    action retainAuditEvent {
      in item audit : AuditEvent;

      first validateAuditEvent;
      then appendToTamperEvidentLog;
      then makeSearchableByPatientStudyAndUser;
      then done;

      action validateAuditEvent;
      action appendToTamperEvidentLog;
      action makeSearchableByPatientStudyAndUser;
    }
  }

  part def VistAImagingSystem {
    attribute primaryFunction : String = "Acquire, associate, store, retrieve, display, and audit clinical images and related reports in the patient care context.";
    attribute targetStudyAvailabilityTime : ISQ::TimeValue = 120 ['s'];
    attribute minimumArchiveAvailability : Real = 0.995;
    attribute defaultImageRetention : ISQ::TimeValue = 7 ['a'];

    part clinicalSystem : ClinicalInformationSystem;
    part modalityGateway : ImagingModalityGateway;
    part archive : ImageArchive {
      :>> availableCapacity = 100 ['TB'];
      :>> retentionPeriod = 7 ['a'];
      :>> replicatedCopies = 2;
    }
    part accessControl : AccessControlService;
    part viewer : DiagnosticViewer {
      :>> maximumOpenViewports = 4;
      :>> supportedWindowLevel = true;
      :>> supportsMeasurements = true;
    }
    part auditRepository : AuditRepository {
      :>> minimumRetentionPeriod = 7 ['a'];
    }

    connect clinicalSystem.orders to modalityGateway.orders;
    connect modalityGateway.acquisition to archive.acquisition;
    connect clinicalSystem.patients to accessControl.patientContext;
    connect archive.query to viewer.retrieval;
    connect archive.retrieval to viewer.retrieval;
    connect viewer.reports to clinicalSystem.reports;
    connect archive.audit to auditRepository.auditIn;
    connect accessControl.audit to auditRepository.auditIn;
    connect viewer.audit to auditRepository.auditIn;

    action provideImagingRecord {
      in item order : ClinicalOrder;
      in item patient : PatientContext;
      in item request : DisplayRequest;
      out item study : ImageStudy;
      out item session : DisplaySession;
      out item report : DiagnosticReport;

      first receiveClinicalOrder;
      then acquireImages;
      then associateImagesWithPatientAndOrder;
      then archiveAndIndexStudy;
      then authorizeClinicianAccess;
      then retrieveImagesForDisplay;
      then displayImagesWithClinicalTools;
      then documentFindings;
      then auditAllAccessAndChanges;
      then done;

      action receiveClinicalOrder;
      action acquireImages;
      action associateImagesWithPatientAndOrder;
      action archiveAndIndexStudy;
      action authorizeClinicianAccess;
      action retrieveImagesForDisplay;
      action displayImagesWithClinicalTools;
      action documentFindings;
      action auditAllAccessAndChanges;
    }
  }

  requirement def ImagingPrimaryFunctionRequirement {
    doc
    /*
     * The system shall provide an enterprise clinical imaging capability that links images and reports to the correct patient context, supports diagnostic and clinical review, and preserves auditable access to the imaging record.
     */
    subject system : VistAImagingSystem;
    require constraint {
      system.minimumArchiveAvailability >= 0.995
    }
  }

  requirement def PatientAssociationRequirement {
    doc
    /*
     * Each acquired image object shall be associated with exactly one patient identifier, one study identifier, and one accession number before it is made available for clinical display.
     */
    subject study : ImageStudy;
    require constraint {
      study.patientId != "" and study.studyId != "" and study.accession != ""
    }
  }

  requirement def TimelyAvailabilityRequirement {
    doc
    /*
     * A newly acquired study shall be indexed and available for authorized retrieval within the target study availability time.
     */
    subject system : VistAImagingSystem;
    require constraint {
      system.targetStudyAvailabilityTime <= 120 ['s']
    }
  }

  requirement def AuthorizationRequirement {
    doc
    /*
     * The system shall permit image retrieval only after a user is authorized by clinical relationship or emergency override, and shall deny unauthorized display requests.
     */
    subject decision : AccessDecision;
  }

  requirement def AuditRequirement {
    doc
    /*
     * The system shall record acquisition, indexing, retrieval, display, reporting, authorization, denial, and emergency override events in a searchable audit repository.
     */
    subject auditStore : AuditRepository;
    require constraint {
      auditStore.minimumRetentionPeriod >= 7 ['a']
    }
  }

  requirement def ViewerCapabilityRequirement {
    doc
    /*
     * The diagnostic viewer shall render retrieved image objects and provide clinical review capabilities including window and level adjustment, measurements, annotations, and report creation or update.
     */
    subject viewer : DiagnosticViewer;
    require constraint {
      viewer.supportedWindowLevel == true and viewer.supportsMeasurements == true
    }
  }

  satisfy ImagingPrimaryFunctionRequirement by VistAImagingSystem;
  satisfy TimelyAvailabilityRequirement by VistAImagingSystem;
  satisfy AuditRequirement by AuditRepository;
  satisfy ViewerCapabilityRequirement by DiagnosticViewer;

}