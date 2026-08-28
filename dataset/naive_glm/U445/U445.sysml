package VistA_Imaging_System {
    import ScalarValues::*;
    import ISQ::*;
    
    value type Megabytes :> Real {
        unit "MB";
    }
    
    value type PatientId :> String;
    value type StudyId :> String;
    
    item def DicomImage {
        attribute studyId : StudyId;
        attribute patientId : PatientId;
        attribute size : Megabytes;
        attribute isEncrypted : Boolean = false;
        attribute isVerified : Boolean = false;
    }
    
    item def PatientDemographics {
        attribute patientId : PatientId;
        attribute name : String;
    }
    
    item def ImagingOrder {
        attribute orderId : String;
        attribute patientId : PatientId;
        attribute modalityType : String;
    }
    
    item def AuditLogEntry {
        attribute timestamp : String;
        attribute userId : String;
        attribute action : String;
        attribute patientId : PatientId;
    }
    
    port def DicomInPort {
        in image : DicomImage;
    }
    
    port def DicomOutPort {
        out image : DicomImage;
    }
    
    port def SecureImageInPort {
        in image : DicomImage;
    }
    
    port def SecureImageOutPort {
        out image : DicomImage;
    }
    
    port def EhrOrderInPort {
        in order : ImagingOrder;
    }
    
    port def EhrUpdateOutPort {
        out demographics : PatientDemographics;
        out studyId : StudyId;
    }
    
    port def RequestInPort {
        in patientId : PatientId;
    }
    
    port def RequestOutPort {
        out patientId : PatientId;
    }
    
    port def ResponseInPort {
        in images : DicomImage[*];
    }
    
    port def ResponseOutPort {
        out images : DicomImage[*];
    }
    
    port def AuditOutPort {
        out auditLog : AuditLogEntry;
    }
    
    requirement def SystemRequirements {
        subject system : VistA_Imaging_System;
        
        requirement AcquireImages {
            subject system;
            doc /* The system shall acquire medical images from various clinical sources. */
        }
        
        requirement SecureStorage {
            subject system;
            doc /* The system shall securely store medical images with redundancy and integrity verification. */
        }
        
        requirement EhrIntegration {
            subject system;
            doc /* The system shall integrate imaging data with the VistA EHR. */
        }
        
        requirement AccessControl {
            subject system;
            doc /* The system shall authenticate users and authorize access to patient images. */
        }
        
        requirement ImageRetrieval {
            subject system;
            doc /* The system shall retrieve and deliver images to clinical workstations. */
        }
    }
    
    part def ModalityInterface {
        port dicomIn : DicomInPort;
        port validatedOut : DicomOutPort;
        
        attribute imageReceived : Boolean = false;
        attribute imageValidated : Boolean = false;
        
        action def ValidateImage {
            in image : DicomImage;
            out validatedImage : DicomImage;
        }
        
        state def ModalityInterfaceBehavior {
            entry; 
            state Receiving;
            state Validating;
            state Forwarding;
            transition Receiving to Validating when imageReceived;
            transition Validating to Forwarding when imageValidated;
            transition Forwarding to Receiving;
        }
    }
    
    part def ImageArchive {
        port secureImageIn : SecureImageInPort;
        port requestIn : RequestInPort;
        port responseOut : ResponseOutPort;
        
        attribute storedImages : DicomImage[*];
        attribute imageStored : Boolean = false;
        attribute requestReceived : Boolean = false;
        
        action def StoreImage {
            in image : DicomImage;
        }
        
        action def VerifyIntegrity {
            in image : DicomImage;
            out isVerified : Boolean;
        }
        
        state def ArchiveBehavior {
            state Idle;
            state Storing;
            state Verifying;
            state Retrieving;
            transition Idle to Storing when imageStored;
            transition Storing to Verifying;
            transition Verifying to Idle;
            transition Idle to Retrieving when requestReceived;
            transition Retrieving to Idle;
        }
    }
    
    part def VistAIntegrationBridge {
        port ehrOrderIn : EhrOrderInPort;
        port ehrUpdateOut : EhrUpdateOutPort;
        port imageStoredIn : SecureImageInPort;
        
        action def SyncDemographics {
            in demographics : PatientDemographics;
        }
        
        action def UpdateEhr {
            in studyId : StudyId;
            in patientId : PatientId;
        }
    }
    
    part def SecurityAndAuditModule {
        port rawImageIn : DicomInPort;
        port secureImageOut : SecureImageOutPort;
        port auditLogOut : AuditOutPort;
        
        action def AuthenticateUser {
            in userId : String;
            out isAuthenticated : Boolean;
        }
        
        action def AuthorizeAccess {
            in userId : String;
            in patientId : PatientId;
            out isAuthorized : Boolean;
        }
        
        action def EncryptImage {
            in image : DicomImage;
            out encryptedImage : DicomImage;
        }
        
        action def LogAction {
            in action : String;
            in patientId : PatientId;
            out logEntry : AuditLogEntry;
        }
    }
    
    part def ImageRetrievalEngine {
        port requestIn : RequestInPort;
        port archiveRequestOut : RequestOutPort;
        port archiveResponseIn : ResponseInPort;
        port responseOut : ResponseOutPort;
        
        attribute cache : DicomImage[*];
        
        action def SearchArchive {
            in patientId : PatientId;
            out images : DicomImage[*];
        }
        
        action def AssembleStudy {
            in images : DicomImage[*];
            out study : DicomImage[*];
        }
    }
    
    part def ClinicalWorkstation {
        port requestOut : RequestOutPort;
        port responseIn : ResponseInPort;
        
        action def RequestStudy {
            in patientId : PatientId;
        }
        
        action def RenderImage {
            in image : DicomImage;
        }
        
        action def AdjustBrightnessContrast {
            in image : DicomImage;
        }
        
        action def MeasureImage {
            in image : DicomImage;
        }
    }
    
    part def VistA_Imaging_System {
        satisfy SystemRequirements;
        
        port externalModality : DicomOutPort;
        port externalEhrOrder : EhrOrderInPort;
        port externalEhrUpdate : EhrUpdateOutPort;
        port externalAudit : AuditOutPort;
        
        part modalityInterface : ModalityInterface;
        part imageArchive : ImageArchive;
        part vistaBridge : VistAIntegrationBridge;
        part securityModule : SecurityAndAuditModule;
        part retrievalEngine : ImageRetrievalEngine;
        part workstation : ClinicalWorkstation;
        
        connection extToModality connect externalModality to modalityInterface.dicomIn;
        connection modalityToSecurity connect modalityInterface.validatedOut to securityModule.rawImageIn;
        connection securityToArchive connect securityModule.secureImageOut to imageArchive.secureImageIn;
        connection securityToBridge connect securityModule.secureImageOut to vistaBridge.imageStoredIn;
        connection extToBridge connect externalEhrOrder to vistaBridge.ehrOrderIn;
        connection bridgeToExt connect vistaBridge.ehrUpdateOut to externalEhrUpdate;
        connection securityToExtAudit connect securityModule.auditLogOut to externalAudit;
        connection workstationToRetrieval connect workstation.requestOut to retrievalEngine.requestIn;
        connection retrievalToArchiveReq connect retrievalEngine.archiveRequestOut to imageArchive.requestIn;
        connection archiveToRetrievalRes connect imageArchive.responseOut to retrievalEngine.archiveResponseIn;
        connection retrievalToWorkstation connect retrievalEngine.responseOut to workstation.responseIn;
    }
}
