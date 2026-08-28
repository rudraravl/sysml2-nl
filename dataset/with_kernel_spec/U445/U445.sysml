package VistA_Imaging_System {
    private import ScalarValues::*;
    
    item def DicomImage {
        attribute studyId : String;
        attribute patientId : String;
        attribute modalityType : String;
        attribute size : Real;
    }
    
    item def EncryptedImage {
        attribute studyId : String;
        attribute patientId : String;
        attribute checksum : String;
        attribute size : Real;
    }
    
    item def ImagingOrder {
        attribute orderId : String;
        attribute patientId : String;
        attribute requestedModality : String;
    }
    
    item def PatientDemographics {
        attribute patientId : String;
        attribute name : String;
        attribute dob : String;
    }
    
    item def StudyRequest {
        attribute patientId : String;
        attribute studyId : String;
    }
    
    item def Study {
        attribute studyId : String;
        attribute patientId : String;
        attribute images : DicomImage[*];
    }
    
    item def AuditLogEntry {
        attribute userId : String;
        attribute actionType : String;
        attribute timestamp : String;
    }
    
    item def AuthRequest {
        attribute userId : String;
    }
    
    item def AuthToken {
        attribute userId : String;
        attribute role : String;
        attribute valid : Boolean;
    }
    
    part def VistA_EHR {
        port orderOut {
            out order : ImagingOrder;
        }
        port demographicsOut {
            out demographics : PatientDemographics;
        }
        port recordUpdateIn {
            in demographics : PatientDemographics;
        }
        exhibit state ehrBehavior {
            entry; then active;
            state active;
            transition generateOrder first active do send new ImagingOrder() via orderOut then active;
            transition generateDemographics first active do send new PatientDemographics() via demographicsOut then active;
            transition updateRecord first active accept demo : PatientDemographics via recordUpdateIn then active;
        }
    }
    
    part def ModalityInterface {
        port orderIn {
            in order : ImagingOrder;
        }
        port imageOut {
            out image : DicomImage;
        }
        exhibit state modalityBehavior {
            entry; then waitingForOrder;
            state waitingForOrder;
            transition receiveOrder first waitingForOrder accept order : ImagingOrder via orderIn then validating;
            state validating;
            transition validate first validating do send new DicomImage() via imageOut then waitingForOrder;
        }
    }
    
    part def ImageArchive {
        port imageIn {
            in image : EncryptedImage;
        }
        port auditIn {
            in log : AuditLogEntry;
        }
        port searchIn {
            in request : StudyRequest;
        }
        port imageOut {
            out image : EncryptedImage;
        }
        exhibit state archiveBehavior {
            entry; then idle;
            state idle;
            transition storeImage first idle accept img : EncryptedImage via imageIn then idle;
            transition logAudit first idle accept log : AuditLogEntry via auditIn then idle;
            transition searchImage first idle accept req : StudyRequest via searchIn do send new EncryptedImage() via imageOut then idle;
        }
    }
    
    part def VistAIntegrationBridge {
        port orderIn {
            in order : ImagingOrder;
        }
        port demographicsIn {
            in demographics : PatientDemographics;
        }
        port orderOut {
            out order : ImagingOrder;
        }
        port demographicsOut {
            out demographics : PatientDemographics;
        }
        port recordUpdateOut {
            out demographics : PatientDemographics;
        }
        exhibit state bridgeBehavior {
            entry; then idle;
            state idle;
            transition forwardOrder first idle accept order : ImagingOrder via orderIn do send new ImagingOrder() via orderOut then idle;
            transition forwardDemographics first idle accept demo : PatientDemographics via demographicsIn do send new PatientDemographics() via demographicsOut then idle;
            transition updateRecord first idle accept demo : PatientDemographics via demographicsIn do send new PatientDemographics() via recordUpdateOut then idle;
        }
    }
    
    part def SecurityAuditModule {
        port imageIn {
            in image : DicomImage;
        }
        port demographicsIn {
            in demographics : PatientDemographics;
        }
        port authRequestIn {
            in request : AuthRequest;
        }
        port encryptedImageOut {
            out image : EncryptedImage;
        }
        port auditOut {
            out log : AuditLogEntry;
        }
        port authOut {
            out token : AuthToken;
        }
        exhibit state securityBehavior {
            entry; then idle;
            state idle;
            transition secure first idle accept img : DicomImage via imageIn do send new EncryptedImage() via encryptedImageOut then idle;
            transition logAccess first idle accept img : DicomImage via imageIn do send new AuditLogEntry() via auditOut then idle;
            transition authenticate first idle accept req : AuthRequest via authRequestIn do send new AuthToken() via authOut then idle;
        }
    }
    
    part def ImageRetrievalEngine {
        port requestIn {
            in request : StudyRequest;
        }
        port searchOut {
            out request : StudyRequest;
        }
        port imageIn {
            in image : EncryptedImage;
        }
        port studyOut {
            out study : Study;
        }
        exhibit state retrievalBehavior {
            entry; then idle;
            state idle;
            transition handleRequest first idle accept req : StudyRequest via requestIn do send new StudyRequest() via searchOut then waitingForImage;
            state waitingForImage;
            transition assembleStudy first waitingForImage accept img : EncryptedImage via imageIn do send new Study() via studyOut then idle;
        }
    }
    
    part def ClinicalWorkstation {
        port authRequestOut {
            out request : AuthRequest;
        }
        port authIn {
            in token : AuthToken;
        }
        port requestOut {
            out request : StudyRequest;
        }
        port studyIn {
            in study : Study;
        }
        exhibit state workstationBehavior {
            entry; then unauthenticated;
            state unauthenticated;
            transition requestAuth first unauthenticated do send new AuthRequest() via authRequestOut then waitingForAuth;
            state waitingForAuth;
            transition authenticate first waitingForAuth accept token : AuthToken via authIn if token.valid then authenticated;
            state authenticated;
            transition requestStudy first authenticated do send new StudyRequest() via requestOut then waitingForStudy;
            state waitingForStudy;
            transition displayStudy first waitingForStudy accept study : Study via studyIn then viewing;
            state viewing;
            transition requestAnother first viewing then authenticated;
        }
    }
    
    requirement def DICOMCompliance {
        doc /* The system shall acquire and store images in DICOM format. */
    }
    requirement def DataEncryption {
        doc /* All image data shall be encrypted at rest and in transit. */
    }
    requirement def AuditLogging {
        doc /* The system shall maintain an audit log of all access and modifications. */
    }
    requirement def EHRIntegration {
        doc /* The system shall integrate with VistA EHR for orders and updates. */
    }
    requirement def ImageRetrieval {
        doc /* The system shall allow retrieval of images by patient and study. */
    }
    requirement def DiagnosticTools {
        doc /* The clinical workstation shall provide image manipulation tools. */
    }
    
    part def VistA_Imaging_System {
        part ehr : VistA_EHR;
        part modalityInterface : ModalityInterface {
            satisfy DICOMCompliance;
        }
        part imageArchive : ImageArchive;
        part vistaIntegrationBridge : VistAIntegrationBridge {
            satisfy EHRIntegration;
        }
        part securityAuditModule : SecurityAuditModule {
            satisfy DataEncryption;
            satisfy AuditLogging;
        }
        part imageRetrievalEngine : ImageRetrievalEngine {
            satisfy ImageRetrieval;
        }
        part clinicalWorkstation : ClinicalWorkstation {
            satisfy DiagnosticTools;
        }
        
        flow orderFlow of ImagingOrder from ehr.orderOut.order to vistaIntegrationBridge.orderIn.order;
        flow demographicsFlow of PatientDemographics from ehr.demographicsOut.demographics to vistaIntegrationBridge.demographicsIn.demographics;
        flow orderToModalityFlow of ImagingOrder from vistaIntegrationBridge.orderOut.order to modalityInterface.orderIn.order;
        flow demographicsToSecurityFlow of PatientDemographics from vistaIntegrationBridge.demographicsOut.demographics to securityAuditModule.demographicsIn.demographics;
        flow imageFlow of DicomImage from modalityInterface.imageOut.image to securityAuditModule.imageIn.image;
        flow encryptedImageFlow of EncryptedImage from securityAuditModule.encryptedImageOut.image to imageArchive.imageIn.image;
        flow auditFlow of AuditLogEntry from securityAuditModule.auditOut.log to imageArchive.auditIn.log;
        flow authRequestFlow of AuthRequest from clinicalWorkstation.authRequestOut.request to securityAuditModule.authRequestIn.request;
        flow authTokenFlow of AuthToken from securityAuditModule.authOut.token to clinicalWorkstation.authIn.token;
        flow studyRequestFlow of StudyRequest from clinicalWorkstation.requestOut.request to imageRetrievalEngine.requestIn.request;
        flow searchFlow of StudyRequest from imageRetrievalEngine.searchOut.request to imageArchive.searchIn.request;
        flow archiveImageFlow of EncryptedImage from imageArchive.imageOut.image to imageRetrievalEngine.imageIn.image;
        flow studyFlow of Study from imageRetrievalEngine.studyOut.study to clinicalWorkstation.studyIn.study;
        flow recordUpdateFlow of PatientDemographics from vistaIntegrationBridge.recordUpdateOut.demographics to ehr.recordUpdateIn.demographics;
    }
}
