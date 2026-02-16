package AGPLLicensedSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	metadata def LicenseMetadata {
		attribute licenseName : String;
		attribute licenseVersion : String;
		attribute copyleftStrength : String;
		attribute networkProvisionTrigger : Boolean;
		attribute sourceDistributionRequirement : String;
		attribute compatibleLicenses : String[*];
	}
	
	@LicenseMetadata {
		licenseName = "GNU Affero General Public License";
		licenseVersion = "3.0";
		copyleftStrength = "strong";
		networkProvisionTrigger = true;
		sourceDistributionRequirement = "Source code must be made available to all network users";
		compatibleLicenses = ("GPLv3", "AGPLv3");
	}
	
	requirement def LicenseComplianceRequirement {
		doc /* System shall comply with AGPL v3 license obligations. */
	}
	
	requirement <'LIC-001'> agplCompliance : LicenseComplianceRequirement {
		doc /* The system shall be licensed under GNU Affero General Public License version 3.0 
		       and provide complete corresponding source code to all users interacting with it 
		       remotely through a computer network. */
	}
	
	requirement <'LIC-002'> networkSourceProvision : LicenseComplianceRequirement {
		doc /* When the system is accessed over a network, users shall be offered the opportunity 
		       to receive the complete corresponding source code from a network server at no charge. */
		
		require agplCompliance;
	}
	
	requirement def FunctionalRequirement {
		doc /* System functional requirements. */
	}
	
	requirement <'FUNC-001'> primarySystemFunction : FunctionalRequirement {
		doc /* The system shall provide real-time collaborative project management services 
		       accessible via web interface, enabling distributed teams to coordinate tasks, 
		       track progress, and share resources. */
		
		require agplCompliance;
	}
	
	requirement <'FUNC-002'> multiUserSupport : FunctionalRequirement {
		doc /* The system shall support concurrent access by multiple authenticated users 
		       with role-based permissions. */
		
		require primarySystemFunction;
	}
	
	requirement <'FUNC-003'> dataIntegrity : FunctionalRequirement {
		doc /* The system shall maintain data consistency across all concurrent operations 
		       and persist state reliably. */
		
		require primarySystemFunction;
	}
	
	attribute def UserCount :> Integer;
	attribute def SessionDuration :> ISQ::time;
	attribute def DataVolume :> ISQ::mass;
	
	item def UserCredentials {
		attribute username : String;
		attribute passwordHash : String;
		attribute role : String;
	}
	
	item def ProjectData {
		attribute projectId : String;
		attribute projectName : String;
		attribute createdTimestamp : Real;
		attribute lastModified : Real;
		attribute ownerUserId : String;
	}
	
	item def TaskItem {
		attribute taskId : String;
		attribute description : String;
		attribute assignedTo : String;
		attribute status : String;
		attribute priority : Integer;
		attribute dueDate : Real;
	}
	
	item def NetworkRequest {
		attribute requestId : String;
		attribute userId : String;
		attribute requestType : String;
		attribute payload : String;
		attribute timestamp : Real;
	}
	
	item def NetworkResponse {
		attribute responseId : String;
		attribute statusCode : Integer;
		attribute responseBody : String;
		attribute sourceCodeAccessUrl : String;
	}
	
	item def SourceCodePackage {
		attribute version : String;
		attribute packageFormat : String;
		attribute downloadUrl : String;
		attribute checksumSHA256 : String;
		attribute licenseTextIncluded : Boolean;
	}
	
	port def WebServicePort {
		in item request : NetworkRequest;
		out item response : NetworkResponse;
	}
	
	port def DatabasePort {
		inout item projectData : ProjectData;
		inout item taskData : TaskItem;
	}
	
	port def AuthenticationPort {
		in item credentials : UserCredentials;
		out attribute authenticated : Boolean;
	}
	
	port def SourceRepositoryPort {
		out item sourcePackage : SourceCodePackage;
		out attribute licenseInfo : String;
	}
	
	action def AuthenticateUser {
		in credentials : UserCredentials;
		out isAuthenticated : Boolean;
		out userRole : String;
	}
	
	action def ProcessProjectRequest {
		in request : NetworkRequest;
		in userRole : String;
		out projectResponse : ProjectData;
	}
	
	action def ProcessTaskRequest {
		in request : NetworkRequest;
		in userRole : String;
		out taskResponse : TaskItem;
	}
	
	action def ProvideSourceCode {
		in userRequest : NetworkRequest;
		out sourcePackage : SourceCodePackage;
	}
	
	action def ValidateRequest {
		in request : NetworkRequest;
		out isValid : Boolean;
		out validationMessage : String;
	}
	
	part def WebFrontend {
		port servicePort : WebServicePort;
		attribute activeConnections : UserCount;
		attribute averageResponseTime : ISQ::TimeValue;
		
		perform action handleIncomingRequests;
	}
	
	part def AuthenticationService {
		port authPort : AuthenticationPort;
		attribute sessionTimeout : SessionDuration;
		
		perform action authenticateUser : AuthenticateUser;
		
		state machine def AuthenticationStateMachine {
			state unauthenticated;
			state authenticating;
			state authenticated;
			state sessionExpired;
			
			transition login first unauthenticated then authenticating;
			transition success first authenticating then authenticated;
			transition failure first authenticating then unauthenticated;
			transition timeout first authenticated then sessionExpired;
			transition logout first authenticated then unauthenticated;
		}
	}
	
	part def ApplicationCore {
		port dbPort : DatabasePort;
		attribute processingCapacity : UserCount;
		
		perform action processProjectRequest : ProcessProjectRequest;
		perform action processTaskRequest : ProcessTaskRequest;
		
		action coordinateOperations {
			first start;
			then merge processLoop;
			
			then action receiveOperation {
				out operationType : String;
				out operationData : String;
			}
			
			then decide;
				if receiveOperation.operationType == "project" then handleProject;
				if receiveOperation.operationType == "task" then handleTask;
				else processLoop;
			
			action handleProject {
				perform action processProjectRequest {
					in request.payload = receiveOperation.operationData;
					out projectResponse;
				}
			}
			then persistChanges;
			
			action handleTask {
				perform action processTaskRequest {
					in request.payload = receiveOperation.operationData;
					out taskResponse;
				}
			}
			then persistChanges;
			
			action persistChanges;
			then processLoop;
		}
	}
	
	part def DatabaseService {
		port dataPort : DatabasePort;
		attribute storageCapacity : DataVolume;
		attribute replicationEnabled : Boolean;
		
		state machine def DatabaseStateMachine {
			state offline;
			state initializing;
			state ready;
			state processing;
			state replicating;
			state maintenance;
			
			transition startup first offline then initializing;
			transition initialized first initializing then ready;
			transition beginTransaction first ready then processing;
			transition commitTransaction first processing then ready;
			transition startReplication first ready then replicating;
			transition replicationComplete first replicating then ready;
			transition enterMaintenance first ready then maintenance;
			transition exitMaintenance first maintenance then ready;
			transition shutdown first ready then offline;
		}
	}
	
	part def SourceCodeRepository {
		port repositoryPort : SourceRepositoryPort;
		attribute repositoryUrl : String;
		attribute currentVersion : String;
		attribute buildTimestamp : Real;
		
		perform action provideSourceCode : ProvideSourceCode;
		
		action packageSourceForDistribution {
			first start;
			then action gatherSourceFiles {
				out sourceFiles : String;
			}
			then action includeLicenseTexts {
				in files = gatherSourceFiles.sourceFiles;
				out packagedFiles : String;
			}
			then action generateChecksum {
				in package = includeLicenseTexts.packagedFiles;
				out checksum : String;
			}
			then action createDownloadLink {
				in checksumValue = generateChecksum.checksum;
				out downloadUrl : String;
			}
			then action buildSourcePackage {
				in url = createDownloadLink.downloadUrl;
				out finalPackage : SourceCodePackage;
			}
			then done;
		}
	}
	
	part def ComplianceMonitor {
		attribute complianceStatus : Boolean;
		attribute lastAuditTimestamp : Real;
		attribute violationCount : Integer;
		
		state machine def ComplianceStateMachine {
			state compliant {
				entry action logComplianceStatus;
			}
			
			state monitoring {
				do action continuousMonitoring;
			}
			
			state violation {
				entry action logViolation;
				do action notifyAdministrators;
			}
			
			state remediation {
				do action correctViolation;
			}
			
			transition startMonitoring first compliant then monitoring;
			transition detectViolation first monitoring then violation;
			transition beginRemediation first violation then remediation;
			transition remediationComplete first remediation then monitoring;
			transition confirmCompliance first monitoring then compliant;
		}
		
		action continuousMonitoring {
			first start;
			then merge checkLoop;
			
			then action checkSourceAvailability {
				out isAvailable : Boolean;
			}
			
			then decide;
				if checkSourceAvailability.isAvailable then checkLoop;
				else raiseAlert;
			
			action raiseAlert;
			then checkLoop;
		}
	}
	
	part def CollaborativeProjectManagementSystem {
		doc /* AGPL-licensed collaborative project management system providing network-accessible 
		       services for distributed team coordination, task tracking, and resource sharing. */
		
		satisfy primarySystemFunction;
		satisfy multiUserSupport;
		satisfy dataIntegrity;
		satisfy agplCompliance;
		satisfy networkSourceProvision;
		
		part frontend : WebFrontend {
			:>> activeConnections = 0;
		}
		
		part authService : AuthenticationService {
			:>> sessionTimeout = 3600.0;
		}
		
		part appCore : ApplicationCore {
			:>> processingCapacity = 1000;
		}
		
		part database : DatabaseService {
			:>> replicationEnabled = true;
		}
		
		part sourceRepo : SourceCodeRepository {
			:>> repositoryUrl = "https://source.example.org/agpl-pm-system";
			:>> currentVersion = "2.1.0";
		}
		
		part complianceMonitor : ComplianceMonitor {
			:>> complianceStatus = true;
			:>> violationCount = 0;
		}
		
		connection userToFrontend connect frontend.servicePort;
		connection frontendToAuth connect frontend.servicePort to authService.authPort;
		connection frontendToCore connect frontend.servicePort to appCore.dbPort;
		connection coreToDatabase connect appCore.dbPort to database.dataPort;
		connection frontendToSource connect frontend.servicePort to sourceRepo.repositoryPort;
		
		action provideCollaborativeServices {
			first start;
			then merge serviceLoop;
			
			then action receiveUserRequest {
				out incomingRequest : NetworkRequest;
			}
			
			then action validateRequest : ValidateRequest {
				in request = receiveUserRequest.incomingRequest;
				out isValid;
				out validationMessage;
			}
			
			then decide;
				if not validateRequest.isValid then rejectRequest;
				if validateRequest.isValid then routeRequest;
			
			action routeRequest;
			then decide;
				if receiveUserRequest.incomingRequest.requestType == "authentication" then authenticate;
				if receiveUserRequest.incomingRequest.requestType == "project_operation" then processProject;
				if receiveUserRequest.incomingRequest.requestType == "task_operation" then processTask;
				if receiveUserRequest.incomingRequest.requestType == "source_code_request" then provideSource;
				else serviceLoop;
			
			action authenticate {
				perform action authService.authenticateUser {
					in credentials.username = receiveUserRequest.incomingRequest.userId;
					out isAuthenticated;
					out userRole;
				}
			}
			then sendAuthResponse;
			
			action processProject {
				perform action appCore.processProjectRequest {
					in request = receiveUserRequest.incomingRequest;
					out projectResponse;
				}
			}
			then sendProjectResponse;
			
			action processTask {
				perform action appCore.processTaskRequest {
					in request = receiveUserRequest.incomingRequest;
					out taskResponse;
				}
			}
			then sendTaskResponse;
			
			action provideSource {
				perform action sourceRepo.provideSourceCode {
					in userRequest = receiveUserRequest.incomingRequest;
					out sourcePackage;
				}
			}
			then sendSourceResponse;
			
			action rejectRequest;
			then serviceLoop;
			
			action sendAuthResponse;
			then serviceLoop;
			
			action sendProjectResponse;
			then serviceLoop;
			
			action sendTaskResponse;
			then serviceLoop;
			
			action sendSourceResponse;
			then serviceLoop;
		}
		
		attribute systemVersion : String := "2.1.0";
		attribute deploymentEnvironment : String := "production";
		attribute licenseCompliant : Boolean := true;
		attribute maxConcurrentUsers : UserCount := 5000;
		attribute uptimeTarget : Real := 99.9;
	}
	
	part agplSystem : CollaborativeProjectManagementSystem;
}
