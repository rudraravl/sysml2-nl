package 'VistA Imaging System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PatientID;
	attribute def ImageID;
	attribute def StudyID;
	attribute def AccessionNumber;
	attribute def DicomMetadata;
	attribute def HL7Message;
	attribute def AuditLogEntry;
	attribute def UserCredentials;
	attribute def AccessToken;
	
	enumeration def ModalityType {
		CT;
		MRI;
		XRay;
		Ultrasound;
		Mammography;
		NuclearMedicine;
		Fluoroscopy;
	}
	
	enumeration def ImageStatus {
		Acquired;
		Validated;
		Stored;
		Retrieved;
		Displayed;
	}
	
	attribute def ImageResolution {
		attribute width : Integer;
		attribute height : Integer;
		attribute bitsPerPixel : Integer;
	}
	
	attribute def ImageSizeValue :> ISQ::MassValue {
		attribute megabytes : Real;
	}
	
	item def MedicalImage {
		attribute imageID : ImageID;
		attribute patientID : PatientID;
		attribute studyID : StudyID;
		attribute accessionNumber : AccessionNumber;
		attribute modality : ModalityType;
		attribute metadata : DicomMetadata;
		attribute resolution : ImageResolution;
		attribute size : ImageSizeValue;
		attribute acquisitionTimestamp : ScalarValues::String;
		attribute status : ImageStatus;
		attribute pixelData : ScalarValues::String;
	}
	
	item def ImageStudy {
		attribute studyID : StudyID;
		attribute patientID : PatientID;
		attribute studyDate : ScalarValues::String;
		attribute studyDescription : ScalarValues::String;
		attribute images : MedicalImage[1..*] ordered;
		attribute totalSize : ImageSizeValue;
	}
	
	item def PatientRecord {
		attribute patientID : PatientID;
		attribute patientName : ScalarValues::String;
		attribute dateOfBirth : ScalarValues::String;
		attribute medicalRecordNumber : ScalarValues::String;
	}
	
	port def ImageAcquisitionPort {
		in item incomingImage : MedicalImage;
		out attribute acquisitionStatus : ScalarValues::String;
	}
	
	port def StoragePort {
		in item imageToStore : MedicalImage;
		out item storedImage : MedicalImage;
		out attribute storageLocation : ScalarValues::String;
	}
	
	port def RetrievalPort {
		in attribute queryParameters : StudyID;
		out item retrievedStudy : ImageStudy;
	}
	
	port def DisplayPort {
		in item imageToDisplay : MedicalImage;
		out attribute displayStatus : ScalarValues::String;
	}
	
	port def IntegrationPort {
		in attribute hl7Message : HL7Message;
		out attribute integrationStatus : ScalarValues::String;
	}
	
	port def SecurityPort {
		in attribute credentials : UserCredentials;
		out attribute accessToken : AccessToken;
		out attribute auditLog : AuditLogEntry;
	}
	
	part def ModalityInterface {
		port acquisitionPort : ImageAcquisitionPort;
		
		action def ReceiveImageFromModality {
			in item rawImage : MedicalImage;
			out item processedImage : MedicalImage;
		}
		
		action def ValidateDicomCompliance {
			in item image : MedicalImage;
			out attribute isCompliant : ScalarValues::Boolean;
			out attribute validationErrors : ScalarValues::String[*];
		}
		
		action acquireImage {
			first start;
			then action receive : ReceiveImageFromModality;
			then action validate : ValidateDicomCompliance {
				in image = receive.processedImage;
			}
			then decide;
				if validate.isCompliant then acceptAction;
				if not validate.isCompliant then rejectAction;
			action acceptAction {
				out item validImage : MedicalImage;
			}
			then done;
			action rejectAction {
				out attribute errorMessage : ScalarValues::String;
			}
			then done;
		}
	}
	
	part def ImageArchive {
		attribute storageCapacity : ImageSizeValue;
		attribute currentUsage : ImageSizeValue;
		attribute redundancyLevel : ScalarValues::Integer;
		
		port storagePort : StoragePort;
		
		action def StoreImage {
			in item image : MedicalImage;
			out attribute location : ScalarValues::String;
			out attribute success : ScalarValues::Boolean;
		}
		
		action def CreateIndex {
			in item image : MedicalImage;
			in attribute location : ScalarValues::String;
			out attribute indexEntry : ScalarValues::String;
		}
		
		action def VerifyIntegrity {
			in attribute location : ScalarValues::String;
			out attribute verified : ScalarValues::Boolean;
		}
		
		action def CreateBackup {
			in item image : MedicalImage;
			in attribute primaryLocation : ScalarValues::String;
			out attribute backupLocation : ScalarValues::String;
		}
		
		action archiveImage {
			first start;
			then action store : StoreImage;
			then action index : CreateIndex {
				in image = store.image;
				in location = store.location;
			}
			then action verify : VerifyIntegrity {
				in location = store.location;
			}
			then decide;
				if verify.verified then backup;
				if not verify.verified then retry;
			action backup : CreateBackup {
				in image = store.image;
				in primaryLocation = store.location;
			}
			then done;
			action retry;
			then store;
		}
	}
	
	part def ImageRetrievalEngine {
		port retrievalPort : RetrievalPort;
		
		action def SearchByStudyID {
			in attribute studyID : StudyID;
			out attribute foundLocations : ScalarValues::String[*];
			out attribute found : ScalarValues::Boolean;
		}
		
		action def SearchByPatientID {
			in attribute patientID : PatientID;
			out item studies : ImageStudy[*];
		}
		
		action def FetchFromArchive {
			in attribute location : ScalarValues::String;
			out item image : MedicalImage;
		}
		
		action def AssembleStudy {
			in item images : MedicalImage[*];
			out item study : ImageStudy;
		}
		
		action def CacheForPerformance {
			in item study : ImageStudy;
			out item cachedStudy : ImageStudy;
		}
		
		action retrieveStudy {
			first start;
			then action search : SearchByStudyID;
			then decide;
				if search.found then fetchImages;
				if not search.found then notFound;
			action fetchImages {
				private attribute currentIndex : ScalarValues::Integer := 0;
				for location in search.foundLocations {
					action fetch : FetchFromArchive {
						in location = location;
					}
				}
			}
			then action assemble : AssembleStudy;
			then action cache : CacheForPerformance {
				in study = assemble.study;
			}
			then done;
			action notFound;
			then done;
		}
	}
	
	part def ClinicalWorkstation {
		port displayPort : DisplayPort;
		
		action def RenderImage {
			in item image : MedicalImage;
			in attribute windowLevel : ScalarValues::Real;
			in attribute windowWidth : ScalarValues::Real;
			out item renderedImage : MedicalImage;
		}
		
		action def ApplyImageEnhancement {
			in item image : MedicalImage;
			in attribute enhancementType : ScalarValues::String;
			out item enhancedImage : MedicalImage;
		}
		
		action def EnableMeasurementTools {
			in item image : MedicalImage;
			out attribute toolsEnabled : ScalarValues::Boolean;
		}
		
		action def DisplayToClinicianScreen {
			in item image : MedicalImage;
			out attribute displaySuccess : ScalarValues::Boolean;
		}
		
		action displayImage {
			first start;
			then action render : RenderImage;
			then action enhance : ApplyImageEnhancement {
				in image = render.renderedImage;
			}
			then action enableTools : EnableMeasurementTools {
				in image = enhance.enhancedImage;
			}
			then action display : DisplayToClinicianScreen {
				in image = enhance.enhancedImage;
			}
			then done;
		}
	}
	
	part def SecurityAndAuditModule {
		port securityPort : SecurityPort;
		
		action def AuthenticateUser {
			in attribute credentials : UserCredentials;
			out attribute authenticated : ScalarValues::Boolean;
			out attribute userRole : ScalarValues::String;
		}
		
		action def AuthorizeImageAccess {
			in attribute userRole : ScalarValues::String;
			in attribute requestedImageID : ImageID;
			out attribute authorized : ScalarValues::Boolean;
		}
		
		action def LogAccessEvent {
			in attribute userRole : ScalarValues::String;
			in attribute imageID : ImageID;
			in attribute timestamp : ScalarValues::String;
			in attribute actionType : ScalarValues::String;
			out attribute logEntry : AuditLogEntry;
		}
		
		action def EncryptImageData {
			in item image : MedicalImage;
			out item encryptedImage : MedicalImage;
		}
		
		action secureAccess {
			first start;
			then action authenticate : AuthenticateUser;
			then decide;
				if authenticate.authenticated then authorize;
				if not authenticate.authenticated then denyAccess;
			action authorize : AuthorizeImageAccess {
				in userRole = authenticate.userRole;
			}
			then decide;
				if authorize.authorized then log;
				if not authorize.authorized then denyAccess;
			action log : LogAccessEvent {
				in userRole = authenticate.userRole;
			}
			then action encrypt : EncryptImageData;
			then grantAccess;
			action grantAccess;
			then done;
			action denyAccess;
			then done;
		}
	}
	
	part def VistAIntegrationBridge {
		port integrationPort : IntegrationPort;
		
		action def ReceiveHL7Order {
			in attribute hl7Message : HL7Message;
			out attribute orderDetails : ScalarValues::String;
			out attribute patientID : PatientID;
		}
		
		action def UpdateVistARecord {
			in attribute patientID : PatientID;
			in attribute studyID : StudyID;
			in attribute imageCount : ScalarValues::Integer;
			out attribute updateSuccess : ScalarValues::Boolean;
		}
		
		action def SendDicomStudy {
			in item study : ImageStudy;
			in attribute destinationAE : ScalarValues::String;
			out attribute transmissionStatus : ScalarValues::String;
		}
		
		action def SynchronizePatientData {
			in attribute patientID : PatientID;
			out item patientRecord : PatientRecord;
			out attribute syncSuccess : ScalarValues::Boolean;
		}
		
		action integrateWithVistA {
			first start;
			then action receiveOrder : ReceiveHL7Order;
			then action syncPatient : SynchronizePatientData {
				in patientID = receiveOrder.patientID;
			}
			then action updateRecord : UpdateVistARecord {
				in patientID = receiveOrder.patientID;
			}
			then action sendStudy : SendDicomStudy;
			then done;
		}
	}
	
	part def VistAImagingSystem;
	
	part vistaImagingSystem : VistAImagingSystem {
		part modalityInterface : ModalityInterface {
			perform acquireImage;
		}
		
		part imageArchive : ImageArchive {
			perform archiveImage;
		}
		
		part retrievalEngine : ImageRetrievalEngine {
			perform retrieveStudy;
		}
		
		part workstation : ClinicalWorkstation {
			perform displayImage;
		}
		
		part securityModule : SecurityAndAuditModule {
			perform secureAccess;
		}
		
		part integrationBridge : VistAIntegrationBridge {
			perform integrateWithVistA;
		}
		
		connect modalityInterface.acquisitionPort to imageArchive.storagePort;
		connect imageArchive.storagePort to retrievalEngine.retrievalPort;
		connect retrievalEngine.retrievalPort to workstation.displayPort;
		
		action manageMedicalImaging {
			doc /* 
				The VistA Imaging System provides comprehensive enterprise medical image 
				management for Veterans Health Administration facilities. Its primary function 
				is to capture medical images from clinical imaging modalities, securely store 
				them in a centralized archive, enable efficient retrieval based on clinical 
				queries, and display images to authorized clinicians through workstations, 
				while maintaining full integration with the VistA electronic health record 
				system and ensuring compliance with healthcare security and privacy regulations.
			*/
			
			first start;
			then merge continueProcessing;
			
			then action acquire {
				perform modalityInterface.acquireImage;
			}
			
			then action secure {
				perform securityModule.secureAccess;
			}
			
			then decide;
				if secure.secureAccess.grantAccess then archive;
			
			action archive {
				perform imageArchive.archiveImage;
			}
			
			then action integrate {
				perform integrationBridge.integrateWithVistA;
			}
			
			then action retrieve {
				perform retrievalEngine.retrieveStudy;
			}
			
			then action display {
				perform workstation.displayImage;
			}
			
			then continueProcessing;
		}
	}
	
	requirement <'VIS-REQ-001'> enterpriseImagingRequirement {
		doc /* 
			The VistA Imaging System shall provide enterprise-wide medical image lifecycle 
			management including acquisition from multiple modalities, secure archival storage, 
			efficient retrieval, clinical display, and seamless integration with VistA EHR.
		*/
		
		require imageAcquisitionRequirement;
		require imageStorageRequirement;
		require imageRetrievalRequirement;
		require clinicalDisplayRequirement;
		require securityComplianceRequirement;
		require vistaIntegrationRequirement;
	}
	
	requirement <'VIS-REQ-002'> imageAcquisitionRequirement {
		doc /* 
			The system shall acquire DICOM-compliant medical images from multiple imaging 
			modalities including CT, MRI, X-Ray, Ultrasound, Mammography, Nuclear Medicine, 
			and Fluoroscopy, validating image quality and metadata completeness before storage.
		*/
		
		attribute supportedModalities : ScalarValues::Integer = 7;
		attribute dicomComplianceLevel : ScalarValues::String = "Full";
	}
	
	requirement <'VIS-REQ-003'> imageStorageRequirement {
		doc /* 
			The system shall store medical images in a secure, redundant archive with 
			automatic indexing, metadata management, integrity verification, and backup 
			capabilities to ensure long-term preservation and accessibility.
		*/
		
		attribute minimumRedundancy : ScalarValues::Integer = 2;
		attribute integrityCheckFrequency : ScalarValues::String = "Daily";
	}
	
	requirement <'VIS-REQ-004'> imageRetrievalRequirement {
		doc /* 
			The system shall retrieve medical images and complete studies efficiently 
			based on patient ID, study ID, accession number, or other clinical criteria, 
			with caching mechanisms to optimize performance for frequently accessed studies.
		*/
		
		attribute maxRetrievalTime : ISQ::TimeValue = 3.0[SI::s];
		attribute cacheHitRateTarget : ScalarValues::Real = 0.85;
	}
	
	requirement <'VIS-REQ-005'> clinicalDisplayRequirement {
		doc /* 
			The system shall display medical images on clinical workstations with 
			diagnostic-quality rendering, image enhancement tools, measurement capabilities, 
			and adjustable window/level settings to support clinical interpretation.
		*/
		
		attribute minDisplayResolution : ScalarValues::String = "2048x2560";
		attribute supportedEnhancements : ScalarValues::Integer = 12;
	}
	
	requirement <'VIS-REQ-006'> securityComplianceRequirement {
		doc /* 
			The system shall enforce role-based access control, encrypt all image data 
			in transit and at rest, maintain comprehensive audit logs of all access and 
			modifications, and comply with HIPAA privacy and security regulations.
		*/
		
		attribute encryptionStandard : ScalarValues::String = "AES-256";
		attribute auditLogRetention : ISQ::TimeValue = 2555.0[SI::s];
	}
	
	requirement <'VIS-REQ-007'> vistaIntegrationRequirement {
		doc /* 
			The system shall integrate seamlessly with VistA EHR using HL7 messaging 
			for order management and patient demographics, DICOM protocols for image 
			exchange, and bidirectional synchronization of imaging results and reports.
		*/
		
		attribute hl7Version : ScalarValues::String = "2.5";
		attribute dicomVersion : ScalarValues::String = "3.0";
		attribute syncLatency : ISQ::TimeValue = 5.0[SI::s];
	}
}
