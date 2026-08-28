package ProjectManagementSystem {
    import ScalarValues::*;
    
    // ===== Value Types with Units =====
    
    value type DurationMinutes :> Real { 
        attribute unit : String = "min"; 
    }
    
    value type ResponseTimeMs :> Real { 
        attribute unit : String = "ms"; 
    }
    
    value type StorageGB :> Real { 
        attribute unit : String = "GB"; 
    }
    
    value type AvailabilityPercent :> Real { 
        attribute unit : String = "%"; 
    }
    
    value type ThroughputTPS :> Real { 
        attribute unit : String = "tps"; 
    }
    
    value type LatencyMs :> Real { 
        attribute unit : String = "ms"; 
    }
    
    // ===== Enumerations =====
    
    enum def UserRole {
        admin;
        manager;
        member;
        viewer;
    }
    
    enum def Permission {
        createProject;
        updateProject;
        deleteProject;
        createTask;
        updateTask;
        assignTask;
        deleteTask;
        viewReports;
        downloadSource;
        manageCompliance;
        manageUsers;
    }
    
    enum def AuthenticationStatus {
        authenticated;
        unauthenticated;
        sessionExpired;
        invalidCredentials;
    }
    
    enum def RequestType {
        login;
        logout;
        createProject;
        updateProject;
        deleteProject;
        createTask;
        updateTask;
        deleteTask;
        listProjects;
        listTasks;
        downloadSource;
        viewCompliance;
    }
    
    enum def HttpMethod {
        GET;
        POST;
        PUT;
        DELETE;
        PATCH;
    }
    
    enum def ComplianceStatus {
        compliant;
        nonCompliant;
        pendingReview;
        violationDetected;
    }
    
    enum def AlertSeverity {
        info;
        warning;
        critical;
    }
    
    enum def DatabaseOperationalState {
        processingTransactions;
        replicatingData;
        underMaintenance;
        backup;
    }
    
    enum def ReplicationRole {
        primary;
        replica;
    }
    
    enum def TaskStatus {
        notStarted;
        inProgress;
        blocked;
        completed;
        cancelled;
    }
    
    // ===== Item Definitions =====
    
    item def Credentials {
        attribute username : String;
        attribute passwordHash : String;
    }
    
    item def UserAccount {
        attribute userId : String;
        attribute username : String;
        attribute email : String;
        attribute role : UserRole;
        attribute permissions : Permission[0..*];
        attribute active : Boolean;
    }
    
    item def Session {
        attribute sessionId : String;
        attribute userId : String;
        attribute role : UserRole;
        attribute issuedAt : String;
        attribute duration : DurationMinutes;
        attribute status : AuthenticationStatus;
    }
    
    item def Project {
        attribute projectId : String;
        attribute name : String;
        attribute description : String;
        attribute ownerId : String;
        attribute memberIds : String[0..*];
        attribute createdAt : String;
        attribute updatedAt : String;
    }
    
    item def Task {
        attribute taskId : String;
        attribute projectId : String;
        attribute title : String;
        attribute description : String;
        attribute assigneeId : String;
        attribute status : TaskStatus;
        attribute priority : Integer;
        attribute dueDate : String;
    }
    
    item def HttpRequest {
        attribute requestId : String;
        attribute method : HttpMethod;
        attribute path : String;
        attribute body : String;
        attribute sessionToken : String;
        attribute requestType : RequestType;
    }
    
    item def HttpResponse {
        attribute requestId : String;
        attribute statusCode : Integer;
        attribute body : String;
        attribute responseTime : ResponseTimeMs;
    }
    
    item def DatabaseQuery {
        attribute queryId : String;
        attribute queryType : String;
        attribute statement : String;
        attribute payload : String;
    }
    
    item def DatabaseResult {
        attribute queryId : String;
        attribute success : Boolean;
        attribute data : String;
        attribute affectedRows : Integer;
    }
    
    item def SourceCodePackage {
        attribute packageId : String;
        attribute version : String;
        attribute size : StorageGB;
        attribute checksum : String;
        attribute releaseDate : String;
        attribute completeCorrespondingSource : Boolean;
    }
    
    item def ComplianceReport {
        attribute reportId : String;
        attribute status : ComplianceStatus;
        attribute lastCheckedAt : String;
        attribute sourcePackageAvailable : Boolean;
        attribute downloadEndpointReachable : Boolean;
        attribute details : String;
    }
    
    item def AlertNotification {
        attribute alertId : String;
        attribute severity : AlertSeverity;
        attribute message : String;
        attribute timestamp : String;
        attribute recipientRole : UserRole;
    }
    
    // ===== Port Definitions =====
    
    port def HttpInterface {
        attribute protocol : String = "HTTPS";
        in attribute incomingRequest : HttpRequest;
        out attribute outgoingResponse : HttpResponse;
    }
    
    port def AuthenticationInterface {
        in attribute credentials : Credentials;
        out attribute session : Session;
        in attribute tokenToValidate : String;
        out attribute validationStatus : AuthenticationStatus;
    }
    
    port def ApplicationServiceInterface {
        in attribute serviceRequest : HttpRequest;
        out attribute serviceResponse : HttpResponse;
    }
    
    port def DataInterface {
        in attribute query : DatabaseQuery;
        out attribute result : DatabaseResult;
    }
    
    port def SourceDownloadInterface {
        out attribute package : SourceCodePackage;
        in attribute downloadRequest : HttpRequest;
    }
    
    port def ComplianceMonitorInterface {
        out attribute report : ComplianceReport;
        out attribute alert : AlertNotification;
        in attribute statusCheck : Boolean;
    }
    
    port def AdminAlertInterface {
        out attribute alert : AlertNotification;
    }
    
    // ===== Part Definitions =====
    
    part def WebFrontend {
        attribute maxConcurrentUsers : Integer = 10000;
        attribute targetResponseTime : ResponseTimeMs = 200;
        attribute enabled : Boolean = true;
        
        port httpEndpoint : HttpInterface;
        port authConnection : AuthenticationInterface;
        port appConnection : ApplicationServiceInterface;
        port sourceConnection : SourceDownloadInterface;
        
        state frontendState {
            entry { attribute initializationComplete = false; } 
            then idle;
            
            state idle;
            
            state authenticating;
            
            state routing;
            
            state responding;
            
            state errorHandling;
            
            transition idle -> authenticating 
                when httpEndpoint.incomingRequest.requestType == RequestType::login;
            
            transition authenticating -> routing 
                when authConnection.session.status == AuthenticationStatus::authenticated;
            
            transition authenticating -> errorHandling 
                when authConnection.session.status == AuthenticationStatus::invalidCredentials;
            
            transition routing -> idle 
                when appConnection.serviceResponse.statusCode == 200;
            
            transition routing -> responding 
                when appConnection.serviceResponse.responseTime >= 0;
            
            transition responding -> idle 
                when httpEndpoint.outgoingResponse.statusCode == 200;
            
            transition errorHandling -> idle 
                when httpEndpoint.outgoingResponse.statusCode >= 400;
        }
        
        action receiveRequest {
            in request : HttpRequest;
            out forwarded : HttpRequest;
        }
        
        action routeRequest {
            in request : HttpRequest;
            out routed : HttpRequest;
        }
        
        action sendResponse {
            in response : HttpResponse;
            out delivered : HttpResponse;
        }
    }
    
    part def AuthenticationService {
        attribute sessionTimeout : DurationMinutes = 60;
        attribute maxSessionsPerUser : Integer = 5;
        
        port authEndpoint : AuthenticationInterface;
        port dataLink : DataInterface;
        
        attribute activeSessions : Session[0..*];
        
        state authState {
            entry; then waiting;
            
            state waiting;
            
            state verifying;
            
            state issuingSession;
            
            state validatingToken;
            
            state revokingSession;
            
            transition waiting -> verifying 
                when authEndpoint.credentials is not null;
            
            transition verifying -> issuingSession 
                when dataLink.result.success == true;
            
            transition verifying -> waiting 
                when dataLink.result.success == false;
            
            transition issuingSession -> waiting 
                when authEndpoint.session.sessionId is not null;
            
            transition waiting -> validatingToken 
                when authEndpoint.tokenToValidate is not null;
            
            transition validatingToken -> waiting 
                when authEndpoint.validationStatus is not null;
            
            transition waiting -> revokingSession 
                when authEndpoint.credentials.username == "logout";
            
            transition revokingSession -> waiting 
                when activeSessions->size() == 0;
        }
        
        action authenticateUser {
            in cred : Credentials;
            out session : Session;
        }
        
        action validateToken {
            in token : String;
            out status : AuthenticationStatus;
        }
        
        action checkPermissions {
            in user : UserAccount;
            in requiredPermission : Permission;
            out allowed : Boolean;
        }
    }
    
    part def ApplicationCore {
        attribute supportedApiVersion : String = "2.0";
        attribute maxProjectsPerUser : Integer = 100;
        attribute maxTasksPerProject : Integer = 5000;
        
        port appEndpoint : ApplicationServiceInterface;
        port dataLink : DataInterface;
        
        state coreState {
            entry; then ready;
            
            state ready;
            
            state processingRequest;
            
            state persistingData;
            
            state returningResponse;
            
            transition ready -> processingRequest 
                when appEndpoint.serviceRequest.requestType is not null;
            
            transition processingRequest -> persistingData 
                when appEndpoint.serviceRequest.requestType in { RequestType::createProject, RequestType::updateProject, RequestType::deleteProject, RequestType::createTask, RequestType::updateTask, RequestType::deleteTask };
            
            transition processingRequest -> persistingData 
                when appEndpoint.serviceRequest.requestType in { RequestType::listProjects, RequestType::listTasks };
            
            transition persistingData -> returningResponse 
                when dataLink.result.queryId is not null;
            
            transition returningResponse -> ready 
                when appEndpoint.serviceResponse.statusCode is not null;
        }
        
        action createProject {
            in projectData : Project;
            out created : Project;
        }
        
        action updateProject {
            in projectData : Project;
            out updated : Project;
        }
        
        action deleteProject {
            in projectId : String;
            out success : Boolean;
        }
        
        action createTask {
            in taskData : Task;
            out created : Task;
        }
        
        action updateTask {
            in taskData : Task;
            out updated : Task;
        }
        
        action deleteTask {
            in taskId : String;
            out success : Boolean;
        }
        
        action listProjects {
            in userId : String;
            out projects : Project[0..*];
        }
        
        action listTasks {
            in projectId : String;
            out tasks : Task[0..*];
        }
    }
    
    part def DatabaseService {
        attribute storageCapacity : StorageGB = 1000;
        attribute throughputTarget : ThroughputTPS = 5000;
        attribute availabilityTarget : AvailabilityPercent = 99.9;
        attribute replicationRole : ReplicationRole;
        
        port dataEndpoint : DataInterface;
        
        state databaseState {
            entry; then processingTransactions;
            
            state processingTransactions {
                attribute currentThroughput : ThroughputTPS;
            }
            
            state replicatingData {
                attribute replicationLag : LatencyMs;
            }
            
            state underMaintenance {
                attribute maintenanceWindow : DurationMinutes;
            }
            
            state backup {
                attribute backupProgress : AvailabilityPercent;
            }
            
            transition processingTransactions -> replicatingData 
                when dataEndpoint.query.queryType == "replicate";
            
            transition replicatingData -> processingTransactions 
                when dataEndpoint.result.success == true;
            
            transition processingTransactions -> underMaintenance 
                when false;  // triggered by admin schedule
            
            transition underMaintenance -> processingTransactions 
                when dataEndpoint.result.success == true;
            
            transition processingTransactions -> backup 
                when dataEndpoint.query.queryType == "backup";
            
            transition backup -> processingTransactions 
                when dataEndpoint.result.success == true;
        }
        
        action executeQuery {
            in query : DatabaseQuery;
            out result : DatabaseResult;
        }
        
        action beginTransaction {
            out transactionId : String;
        }
        
        action commitTransaction {
            in transactionId : String;
            out success : Boolean;
        }
        
        action rollbackTransaction {
            in transactionId : String;
            out success : Boolean;
        }
        
        action replicateData {
            out replicaSynced : Boolean;
        }
    }
    
    part def SourceCodeRepository {
        attribute currentVersion : String;
        attribute packageSize : StorageGB;
        attribute repositoryEnabled : Boolean = true;
        attribute agplCompliant : Boolean = true;
        
        port downloadEndpoint : SourceDownloadInterface;
        port dataLink : DataInterface;
        
        state repositoryState {
            entry; then idle;
            
            state idle;
            
            state packaging;
            
            state verifying;
            
            state publishing;
            
            state serving;
            
            transition idle -> packaging 
                when downloadEndpoint.downloadRequest.requestType == RequestType::downloadSource;
            
            transition packaging -> verifying 
                when downloadEndpoint.package.packageId is not null;
            
            transition verifying -> publishing 
                when downloadEndpoint.package.checksum is not null;
            
            transition publishing -> serving 
                when downloadEndpoint.package.completeCorrespondingSource == true;
            
            transition serving -> idle 
                when downloadEndpoint.package is not null;
        }
        
        action packageSourceCode {
            in version : String;
            out package : SourceCodePackage;
        }
        
        action verifyCompleteness {
            in package : SourceCodePackage;
            out complete : Boolean;
        }
        
        action publishPackage {
            in package : SourceCodePackage;
            out url : String;
        }
        
        action provideDownload {
            in request : HttpRequest;
            out package : SourceCodePackage;
        }
    }
    
    part def ComplianceMonitor {
        attribute monitoringEnabled : Boolean = true;
        attribute checkInterval : DurationMinutes = 5;
        attribute currentStatus : ComplianceStatus = ComplianceStatus::compliant;
        attribute lastReport : ComplianceReport;
        
        port monitorEndpoint : ComplianceMonitorInterface;
        port adminAlerts : AdminAlertInterface;
        port repoLink : SourceDownloadInterface;
        
        state monitorState {
            entry; then idle;
            
            state idle;
            
            state checking;
            
            state evaluating;
            
            state alerting;
            
            state reporting;
            
            transition idle -> checking 
                when monitorEndpoint.statusCheck == true;
            
            transition checking -> evaluating 
                when monitorEndpoint.report is not null;
            
            transition evaluating -> reporting 
                when monitorEndpoint.report.status == ComplianceStatus::compliant;
            
            transition evaluating -> alerting 
                when monitorEndpoint.report.status == ComplianceStatus::violationDetected;
            
            transition evaluating -> alerting 
                when monitorEndpoint.report.status == ComplianceStatus::nonCompliant;
            
            transition alerting -> reporting 
                when adminAlerts.alert.alertId is not null;
            
            transition reporting -> idle 
                when monitorEndpoint.report.reportId is not null;
        }
        
        action checkSourceAvailability {
            out available : Boolean;
        }
        
        action verifyDownloadEndpoint {
            out reachable : Boolean;
        }
        
        action generateComplianceReport {
            out report : ComplianceReport;
        }
        
        action alertAdministrators {
            in severity : AlertSeverity;
            in message : String;
            out alert : AlertNotification;
        }
        
        action trackComplianceStatus {
            out status : ComplianceStatus;
        }
    }
    
    // ===== System (Top-Level) =====
    
    part def ProjectManagementSystem {
        attribute systemName : String = "CollaborativePMS";
        attribute licenseType : String = "AGPL-3.0";
        attribute targetAvailability : AvailabilityPercent = 99.9;
        attribute maxConcurrentUsers : Integer = 10000;
        
        part frontend : WebFrontend {
            attribute requestQueueSize : Integer = 0;
            attribute servedRequests : Integer = 0;
        }
        
        part authService : AuthenticationService {
            attribute issuedSessions : Integer = 0;
        }
        
        part appCore : ApplicationCore {
            attribute activeProjects : Integer = 0;
            attribute activeTasks : Integer = 0;
        }
        
        part database : DatabaseService {
            attribute totalRecords : Integer = 0;
            attribute currentConnections : Integer = 0;
        }
        
        part sourceRepository : SourceCodeRepository {
            attribute publishedVersions : Integer = 0;
        }
        
        part complianceMonitor : ComplianceMonitor {
            attribute checksPerformed : Integer = 0;
            attribute violationsDetected : Integer = 0;
        }
        
        // Connections
        connection def UserToFrontend {
            endpoint1 :>> :> port;
            endpoint2 :>> :> port;
        }
        
        connection frontToAuth 
            connect frontend.authConnection::port 
            to authService.authEndpoint::port;
        
        connection frontToApp 
            connect frontend.appConnection::port 
            to appCore.appEndpoint::port;
        
        connection frontToSource 
            connect frontend.sourceConnection::port 
            to sourceRepository.downloadEndpoint::port;
        
        connection authToDb 
            connect authService.dataLink::port 
            to database.dataEndpoint::port;
        
        connection appToDb 
            connect appCore.dataLink::port 
            to database.dataEndpoint::port;
        
        connection monitorToRepo 
            connect complianceMonitor.repoLink::port 
            to sourceRepository.downloadEndpoint::port;
        
        connection monitorAlerts 
            connect complianceMonitor.adminAlerts::port 
            to authService.authEndpoint::port;
        
        // System-level state machine
        state systemState {
            entry; then initializing;
            
            state initializing;
            
            state operational;
            
            state degraded;
            
            state offline;
            
            transition initializing -> operational 
                when frontend.enabled == true;
            
            transition operational -> degraded 
                when database.availabilityTarget < 99.0;
            
            transition degraded -> operational 
                when database.availabilityTarget >= 99.0;
            
            transition operational -> offline 
                when frontend.enabled == false;
            
            transition offline -> operational 
                when frontend.enabled == true;
        }
    }
    
    // ===== Requirements =====
    
    requirement def CollaborativePMRequirement {
        attribute id : String;
        attribute text : String;
    }
    
    requirement WebInterfaceRequirement : CollaborativePMRequirement {
        doc /* The system shall provide a web-based interface accessible to distributed teams. */
        attribute id = "REQ-001";
        attribute text = "Web Frontend shall handle all incoming network requests as the main entry point.";
        satisfy { ref part ProjectManagementSystem::frontend; }
    }
    
    requirement AuthenticationRequirement : CollaborativePMRequirement {
        doc /* The system shall authenticate users through a dedicated Authentication Service. */
        attribute id = "REQ-002";
        attribute text = "Authentication Service shall verify credentials and manage sessions with role and permission support.";
        satisfy { ref part ProjectManagementSystem::authService; }
    }
    
    requirement RolePermissionRequirement : CollaborativePMRequirement {
        doc /* The system shall support multiple user roles and permissions. */
        attribute id = "REQ-003";
        attribute text = "The system shall enforce at minimum admin, manager, member, and viewer roles with associated permissions.";
        satisfy { ref item UserAccount; ref enum UserRole; ref enum Permission; }
    }
    
    requirement ApplicationCoreRequirement : CollaborativePMRequirement {
        doc /* The Application Core shall process business logic for projects and tasks. */
        attribute id = "REQ-004";
        attribute text = "Application Core shall create, update, and process project and task data.";
        satisfy { ref part ProjectManagementSystem::appCore; }
    }
    
    requirement DatabaseRequirement : CollaborativePMRequirement {
        doc /* The database shall reliably store and retrieve all user and project information. */
        attribute id = "REQ-005";
        attribute text = "Database Service shall ensure data integrity and support high availability with transaction processing, replication, and maintenance states.";
        satisfy { ref part ProjectManagementSystem::database; }
    }
    
    requirement DatabaseHARequirement : CollaborativePMRequirement {
        doc /* The database shall maintain high availability with defined operational states. */
        attribute id = "REQ-006";
        attribute text = "Database Service shall operate in states for processing transactions, replicating data, and undergoing maintenance.";
        satisfy { ref part DatabaseService; ref state DatabaseService::databaseState; }
    }
    
    requirement AGPLComplianceRequirement : CollaborativePMRequirement {
        doc /* The system shall comply with the Affero General Public License (AGPL). */
        attribute id = "REQ-007";
        attribute text = "The system shall package and make available the complete corresponding source code to any user who interacts with the service.";
        satisfy { ref part ProjectManagementSystem::sourceRepository; }
    }
    
    requirement SourceRepositoryRequirement : CollaborativePMRequirement {
        doc /* The Source Code Repository shall provide downloadable source code. */
        attribute id = "REQ-008";
        attribute text = "Source Code Repository shall package the complete corresponding source code and make it available for download.";
        satisfy { ref part SourceCodeRepository; }
    }
    
    requirement ComplianceMonitorRequirement : CollaborativePMRequirement {
        doc /* The Compliance Monitor shall continuously monitor AGPL compliance. */
        attribute id = "REQ-009";
        attribute text = "Compliance Monitor shall run continuously, track compliance status, and alert administrators if a violation is detected.";
        satisfy { ref part ProjectManagementSystem::complianceMonitor; }
    }
    
    requirement AlertingRequirement : CollaborativePMRequirement {
        doc /* The system shall alert administrators on compliance violations. */
        attribute id = "REQ-010";
        attribute text = "Compliance Monitor shall generate AlertNotification objects addressed to admin-role users upon detecting a compliance violation.";
        satisfy { ref part ComplianceMonitor; ref item AlertNotification; }
    }
    
    requirement RealtimeRequirement : CollaborativePMRequirement {
        doc /* The system shall support real-time collaboration. */
        attribute id = "REQ-011";
        attribute text = "The Web Frontend shall process requests with a target response time of 200 ms or less under normal load.";
        satisfy { ref part WebFrontend; }
    }
    
    requirement DistributedTeamRequirement : CollaborativePMRequirement {
        doc /* The system shall be designed for distributed teams. */
        attribute id = "REQ-012";
        attribute text = "The system shall support up to 10000 concurrent users from distributed locations.";
        satisfy { ref part ProjectManagementSystem; }
    }
    
    // ===== Verification actions =====
    
    action verifyAuthentication {
        in credentials : Credentials;
        out session : Session;
        doc /* Verifies the authentication flow produces a valid session. */
    }
    
    action verifyCompliance {
        out report : ComplianceReport;
        doc /* Verifies the compliance monitor produces a valid compliance report. */
    }
    
    action verifyDatabaseHA {
        in state : DatabaseOperationalState;
        out success : Boolean;
        doc /* Verifies the database correctly transitions between operational states. */
    }
    
    action verifySourceDownload {
        in request : HttpRequest;
        out package : SourceCodePackage;
        doc /* Verifies the source code can be packaged and downloaded. */
    }
    
    // ===== Package binding =====
    
    part ProjectManagementSystemInstance : ProjectManagementSystem {
        override attribute systemName = "CollaborativePMS-Production";
        override attribute targetAvailability = 99.9;
        override attribute maxConcurrentUsers = 10000;
        
        part frontend : WebFrontend {
            override attribute maxConcurrentUsers = 10000;
            override attribute targetResponseTime = 150;
        }
        
        part authService : AuthenticationService {
            override attribute sessionTimeout = 90;
            override attribute maxSessionsPerUser = 5;
        }
        
        part appCore : ApplicationCore {
            override attribute maxProjectsPerUser = 100;
            override attribute maxTasksPerProject = 5000;
        }
        
        part database : DatabaseService {
            override attribute storageCapacity = 2000;
            override attribute throughputTarget = 5000;
            override attribute availabilityTarget = 99.9;
            override attribute replicationRole = ReplicationRole::primary;
        }
        
        part sourceRepository : SourceCodeRepository {
            override attribute currentVersion = "2.0.1";
            override attribute packageSize = 1.5;
            override attribute agplCompliant = true;
        }
        
        part complianceMonitor : ComplianceMonitor {
            override attribute monitoringEnabled = true;
            override attribute checkInterval = 5;
            override attribute currentStatus = ComplianceStatus::compliant;
        }
    }
    
    // ===== Requirements satisfaction binding =====
    
    requirement CollaborativePMSystemRequirement : CollaborativePMRequirement {
        doc /* Top-level requirement: the entire system satisfies the project management and AGPL compliance goals. */
        attribute id = "REQ-000";
        attribute text = "The system shall be a web-based, collaborative project management system for distributed teams that coordinates work by managing projects, tracking tasks, and sharing resources in real time through a web interface, while complying with AGPL licensing through source code availability and continuous compliance monitoring.";
        satisfy { 
            ref part ProjectManagementSystemInstance;
            ref part WebFrontend;
            ref part AuthenticationService;
            ref part ApplicationCore;
            ref part DatabaseService;
            ref part SourceCodeRepository;
            ref part ComplianceMonitor;
        }
    }
}
