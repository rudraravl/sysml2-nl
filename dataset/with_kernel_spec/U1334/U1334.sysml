package ProjectManagementSystem {
	private import ScalarValues::*;

	attribute def UserId :> String;
	attribute def Timestamp :> Integer;
	attribute def SessionDuration :> Integer;

	enum def UserRole { ADMIN; MANAGER; CONTRIBUTOR; VIEWER; }
	enum def TaskStatus { TODO; IN_PROGRESS; REVIEW; DONE; BLOCKED; }
	enum def RequestAction { CREATE; UPDATE; DELETE; RETRIEVE; }
	enum def ComplianceStatus { COMPLIANT; NON_COMPLIANT; UNDER_REVIEW; }
	enum def AlertSeverity { INFO; WARNING; CRITICAL; }

	item def Credentials {
		attribute username : String;
		attribute passwordHash : String;
	}

	item def SessionToken {
		attribute token : String;
		attribute userId : UserId;
		attribute role : UserRole;
		attribute issuedAt : Timestamp;
		attribute duration : SessionDuration;
	}

	item def LoginRequest {
		attribute credentials : Credentials;
	}

	item def LoginResponse {
		attribute token : SessionToken;
		attribute success : Boolean;
	}

	item def Project {
		attribute projectId : String;
		attribute name : String;
		attribute description : String;
		attribute ownerId : UserId;
		attribute createdAt : Timestamp;
	}

	item def Task {
		attribute taskId : String;
		attribute projectId : String;
		attribute title : String;
		attribute description : String;
		attribute assigneeId : UserId;
		attribute status : TaskStatus;
	}

	item def ProjectOperation {
		attribute operationType : RequestAction;
		attribute project : Project;
	}

	item def TaskOperation {
		attribute operationType : RequestAction;
		attribute task : Task;
	}

	item def OperationResult {
		attribute data : String;
		attribute success : Boolean;
	}

	item def DataQuery {
		attribute query : String;
	}

	item def DataResult {
		attribute data : String;
		attribute success : Boolean;
	}

	item def SourceCodePackage {
		attribute version : String;
		attribute checksum : String;
		attribute downloadUrl : String;
		attribute packagedAt : Timestamp;
	}

	item def SourceRequest;

	item def ComplianceAlert {
		attribute severity : AlertSeverity;
		attribute alertText : String;
		attribute detectedAt : Timestamp;
	}

	item def ComplianceCheck {
		attribute timestamp : Timestamp;
	}

	item def ComplianceReport {
		attribute sourceAccessible : Boolean;
		attribute version : String;
	}

	item def LoginSignal;
	item def ProjectAccessSignal;
	item def TaskAccessSignal;
	item def SourceAccessSignal;
	item def MaintenanceSignal;
	item def ResumeSignal;
	item def ReplicationTrigger;
	item def ViolationSignal;
	item def ResolveSignal;

	port def HttpPort;
	port def AuthPort;
	port def BusinessPort;
	port def DataPort;
	port def SourcePort;
	port def CompliancePort;
	port def MonitoringPort;

	requirement def AuthenticationRequirement {
		doc /* The system shall verify user credentials and manage sessions with role-based permissions. */
	}

	requirement def DataIntegrityRequirement {
		doc /* The database service shall ensure data integrity under concurrent access. */
	}

	requirement def AGPLComplianceRequirement {
		doc /* The system shall make complete corresponding source code available to all users who interact with the service. */
	}

	requirement def HighAvailabilityRequirement {
		doc /* The database service shall maintain high availability through transaction processing, replication, and maintenance states. */
	}

	part def WebFrontend {
		port httpPort : HttpPort;
		port authPort : ~AuthPort;
		port corePort : ~BusinessPort;
		port sourcePort : ~SourcePort;

		exhibit state frontendBehavior {
			entry; then listening;
			state listening;
			transition handleLogin
				first listening
				accept sig : LoginSignal via httpPort
				do send new LoginRequest(new Credentials("user", "hash")) via authPort
				then awaitingAuth;
			state awaitingAuth;
			transition authComplete
				first awaitingAuth
				accept resp : LoginResponse via authPort
				then listening;
			transition handleProjectAccess
				first listening
				accept sig : ProjectAccessSignal via httpPort
				do send new ProjectOperation(RequestAction::CREATE, new Project()) via corePort
				then listening;
			transition handleTaskAccess
				first listening
				accept sig : TaskAccessSignal via httpPort
				do send new TaskOperation(RequestAction::CREATE, new Task()) via corePort
				then listening;
			transition handleSourceAccess
				first listening
				accept sig : SourceAccessSignal via httpPort
				do send new SourceRequest() via sourcePort
				then awaitingSource;
			state awaitingSource;
			transition sourceReceived
				first awaitingSource
				accept pkg : SourceCodePackage via sourcePort
				then listening;
		}
	}

	part def AuthenticationService {
		port authPort : AuthPort;
		attribute validUsers : Credentials[0..*];

		exhibit state authBehavior {
			entry; then waitingForCredentials;
			state waitingForCredentials;
			transition authenticate
				first waitingForCredentials
				accept req : LoginRequest via authPort
				do send new LoginResponse(new SessionToken("token", req.credentials.username, UserRole::ADMIN, 0, 3600), true) via authPort
				then waitingForCredentials;
		}
	}

	part def ApplicationCore {
		port corePort : BusinessPort;
		port dataPort : ~DataPort;

		exhibit state coreBehavior {
			entry; then waitingForOperation;
			state waitingForOperation;
			transition handleProjectOp
				first waitingForOperation
				accept pop : ProjectOperation via corePort
				do send new DataQuery("project") via dataPort
				then awaitingDataResult;
			transition handleTaskOp
				first waitingForOperation
				accept top : TaskOperation via corePort
				do send new DataQuery("task") via dataPort
				then awaitingDataResult;
			state awaitingDataResult;
			transition processDataResult
				first awaitingDataResult
				accept result : DataResult via dataPort
				do send new OperationResult(result.data, result.success) via corePort
				then waitingForOperation;
		}
	}

	part def DatabaseService {
		port dataPort : DataPort;
		attribute replicationEnabled : Boolean = true;

		exhibit state databaseBehavior {
			entry; then processingTransactions;
			state processingTransactions;
			transition handleQuery
				first processingTransactions
				accept query : DataQuery via dataPort
				do send new DataResult("data", true) via dataPort
				then processingTransactions;
			transition startReplication
				first processingTransactions
				accept sig : ReplicationTrigger
				if replicationEnabled
				then replicating;
			state replicating;
			transition replicationComplete
				first replicating
				then processingTransactions;
			transition maintenanceMode
				first processingTransactions
				accept sig : MaintenanceSignal
				then underMaintenance;
			state underMaintenance;
			transition maintenanceComplete
				first underMaintenance
				accept sig : ResumeSignal
				then processingTransactions;
		}
	}

	part def SourceCodeRepository {
		port sourcePort : SourcePort;
		port monitoringPort : MonitoringPort;
		attribute currentVersion : String = "1.0.0";
		attribute checksum : String = "abc123";

		exhibit state repositoryBehavior {
			entry; then idle;
			state idle;
			transition handleSourceRequest
				first idle
				accept req : SourceRequest via sourcePort
				do send new SourceCodePackage(currentVersion, checksum, "https://repo.example.com/download", 0) via sourcePort
				then idle;
			transition handleComplianceCheck
				first idle
				accept check : ComplianceCheck via monitoringPort
				do send new ComplianceReport(true, currentVersion) via monitoringPort
				then idle;
		}
	}

	part def ComplianceMonitor {
		port compliancePort : CompliancePort;
		port monitoringPort : ~MonitoringPort;
		attribute status : ComplianceStatus = ComplianceStatus::COMPLIANT;
		attribute adminContact : String = "admin@example.com";

		exhibit state monitoringBehavior {
			entry; then monitoring;
			state monitoring;
			transition checkCompliance
				first monitoring
				do send new ComplianceCheck(0) via monitoringPort
				then awaitingReport;
			state awaitingReport;
			transition receiveReportViolation
				first awaitingReport
				accept report : ComplianceReport via monitoringPort
				if report.sourceAccessible == false
				do send new ComplianceAlert(AlertSeverity::CRITICAL, "Source code not accessible", 0) via compliancePort
				then alerting;
			transition receiveReportOK
				first awaitingReport
				accept report : ComplianceReport via monitoringPort
				if report.sourceAccessible == true
				then monitoring;
			state alerting;
			transition resolveViolation
				first alerting
				accept sig : ResolveSignal
				then monitoring;
		}
	}

	part ProjectManagementSystemAssembly {
		part webFrontend : WebFrontend;
		part authenticationService : AuthenticationService;
		part applicationCore : ApplicationCore;
		part databaseService : DatabaseService;
		part sourceCodeRepository : SourceCodeRepository;
		part complianceMonitor : ComplianceMonitor;

		interface webFrontend.authPort to authenticationService.authPort;
		interface webFrontend.corePort to applicationCore.corePort;
		interface applicationCore.dataPort to databaseService.dataPort;
		interface webFrontend.sourcePort to sourceCodeRepository.sourcePort;
		interface complianceMonitor.monitoringPort to sourceCodeRepository.monitoringPort;

		requirement authReq : AuthenticationRequirement;
		requirement dataIntegReq : DataIntegrityRequirement;
		requirement agplReq : AGPLComplianceRequirement;
		requirement haReq : HighAvailabilityRequirement;

		satisfy authReq by webFrontend;
		satisfy dataIntegReq by databaseService;
		satisfy agplReq by sourceCodeRepository;
		satisfy haReq by databaseService;
	}
}
