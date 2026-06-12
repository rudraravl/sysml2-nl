package AGPLBasedCollaborativeKnowledgeSystem {

  import ScalarValues::*;
  import SI::*;

  attribute def LicenseName : String;
  attribute def SPDXIdentifier : String;
  attribute def VersionText : String;
  attribute def URL : String;
  attribute def Count : Integer;
  attribute def Percent : Real;
  attribute def BooleanFlag : Boolean;

  item def SourceCodeArchive {
    attribute spdxId : SPDXIdentifier;
    attribute licenseName : LicenseName;
    attribute version : VersionText;
    attribute repositoryUrl : URL;
    attribute includesCorrespondingSource : BooleanFlag;
  }

  item def UserRequest {
    attribute requestId : String;
    attribute submittedAt : Time;
    attribute payloadSize : Mass;
  }

  item def KnowledgeArticle {
    attribute articleId : String;
    attribute title : String;
    attribute revision : Count;
    attribute size : Mass;
    attribute licenseNotice : LicenseName;
  }

  item def SearchQuery {
    attribute queryText : String;
    attribute maxResults : Count;
  }

  item def SearchResultSet {
    attribute resultCount : Count;
    attribute relevanceThreshold : Percent;
  }

  item def LicenseNotice {
    attribute licenseName : LicenseName = "GNU Affero General Public License";
    attribute spdxId : SPDXIdentifier = "AGPL-3.0-or-later";
    attribute licenseUrl : URL = "https://www.gnu.org/licenses/agpl-3.0.html";
    attribute networkSourceOfferRequired : BooleanFlag = true;
  }

  item def AuditRecord {
    attribute actorId : String;
    attribute operation : String;
    attribute recordedAt : Time;
    attribute retainedFor : Time;
  }

  port def WebClientPort {
    in request : UserRequest;
    in query : SearchQuery;
    out article : KnowledgeArticle;
    out results : SearchResultSet;
    out notice : LicenseNotice;
  }

  port def RepositoryPort {
    in articleWrite : KnowledgeArticle;
    in searchRead : SearchQuery;
    out articleRead : KnowledgeArticle;
    out resultSet : SearchResultSet;
  }

  port def SourceDistributionPort {
    in sourceRequest : UserRequest;
    out archive : SourceCodeArchive;
    out notice : LicenseNotice;
  }

  port def AuditPort {
    in record : AuditRecord;
  }

  part def AGPLBasedKnowledgePlatform {
    attribute publicNetworkService : BooleanFlag = true;
    attribute minimumAvailability : Percent = 99.5;
    attribute maxInteractiveLatency : Time = 2 [s];
    attribute license : SPDXIdentifier = "AGPL-3.0-or-later";

    port userInterface : WebClientPort;
    port sourceAccess : SourceDistributionPort;
    port complianceAudit : AuditPort;

    part webApplication : WebApplication;
    part knowledgeRepository : KnowledgeRepository;
    part searchIndexer : SearchIndexer;
    part licenseComplianceService : LicenseComplianceService;
    part auditLog : AuditLog;
    part authenticationService : AuthenticationService;

    connect userInterface to webApplication.clientApi;
    connect webApplication.repositoryAccess to knowledgeRepository.repositoryApi;
    connect webApplication.searchAccess to searchIndexer.repositoryQuery;
    connect searchIndexer.indexSource to knowledgeRepository.repositoryApi;
    connect webApplication.licenseAccess to licenseComplianceService.noticeApi;
    connect sourceAccess to licenseComplianceService.sourceApi;
    connect webApplication.auditOut to auditLog.auditIn;
    connect licenseComplianceService.auditOut to auditLog.auditIn;
    connect webApplication.authAccess to authenticationService.authApi;
  }

  part def WebApplication {
    attribute sessionTimeout : Time = 30 [min];
    attribute maxUploadSize : Mass = 20 [kg];

    port clientApi : WebClientPort;
    port repositoryAccess : RepositoryPort;
    port searchAccess : RepositoryPort;
    port licenseAccess : SourceDistributionPort;
    port auditOut : AuditPort;
    port authAccess : AuthenticationPort;

    action processArticleEdit {
      in request : UserRequest;
      in articleDraft : KnowledgeArticle;
      out savedArticle : KnowledgeArticle;
      first start;
      then validateAuthenticatedUser;
      then validateArticleLicenseNotice;
      then persistRevision;
      then emitAuditRecord;
      then done;

      action validateAuthenticatedUser;
      action validateArticleLicenseNotice;
      action persistRevision;
      action emitAuditRecord;
    }

    action executeSearch {
      in query : SearchQuery;
      out results : SearchResultSet;
      first receiveQuery;
      then normalizeQuery;
      then retrieveIndexedMatches;
      then rankResults;
      then returnResults;

      action receiveQuery;
      action normalizeQuery;
      action retrieveIndexedMatches;
      action rankResults;
      action returnResults;
    }

    state def RequestHandlingStateMachine {
      entry action initializeSession;
      state Idle;
      state Authenticating;
      state ServingArticle;
      state EditingArticle;
      state Searching;
      state ReturningLicenseNotice;
      state ErrorResponse;

      transition first Idle;
      transition Idle_to_Authenticating from Idle to Authenticating;
      transition Authenticating_to_ServingArticle from Authenticating to ServingArticle;
      transition Authenticating_to_EditingArticle from Authenticating to EditingArticle;
      transition Authenticating_to_Searching from Authenticating to Searching;
      transition ServingArticle_to_ReturningLicenseNotice from ServingArticle to ReturningLicenseNotice;
      transition EditingArticle_to_ReturningLicenseNotice from EditingArticle to ReturningLicenseNotice;
      transition Searching_to_ReturningLicenseNotice from Searching to ReturningLicenseNotice;
      transition ReturningLicenseNotice_to_Idle from ReturningLicenseNotice to Idle;
      transition Authenticating_to_ErrorResponse from Authenticating to ErrorResponse;
      transition ErrorResponse_to_Idle from ErrorResponse to Idle;
    }
  }

  port def AuthenticationPort {
    in request : UserRequest;
    out authenticated : BooleanFlag;
  }

  part def AuthenticationService {
    attribute passwordHashAlgorithm : String = "Argon2id";
    attribute maxFailedAttempts : Count = 5;

    port authApi : AuthenticationPort;

    state def AuthenticationStateMachine {
      state Ready;
      state VerifyingCredentials;
      state Authenticated;
      state Denied;
      transition first Ready;
      transition Ready_to_VerifyingCredentials from Ready to VerifyingCredentials;
      transition VerifyingCredentials_to_Authenticated from VerifyingCredentials to Authenticated;
      transition VerifyingCredentials_to_Denied from VerifyingCredentials to Denied;
      transition Authenticated_to_Ready from Authenticated to Ready;
      transition Denied_to_Ready from Denied to Ready;
    }
  }

  part def KnowledgeRepository {
    attribute replicatedCopies : Count = 3;
    attribute maximumArticleSize : Mass = 50 [kg];
    attribute revisionRetention : Time = 3650 [d];

    port repositoryApi : RepositoryPort;

    action storeArticleRevision {
      in article : KnowledgeArticle;
      out stored : KnowledgeArticle;
      first checkTitle;
      then appendImmutableRevision;
      then updateCurrentPointer;
      then publishRepositoryEvent;

      action checkTitle;
      action appendImmutableRevision;
      action updateCurrentPointer;
      action publishRepositoryEvent;
    }
  }

  part def SearchIndexer {
    attribute indexRefreshInterval : Time = 60 [s];
    attribute minimumRelevance : Percent = 70.0;

    port repositoryQuery : RepositoryPort;
    port indexSource : RepositoryPort;

    action refreshIndex {
      first readChangedArticles;
      then tokenizeContent;
      then updateInvertedIndex;
      then verifySearchHealth;

      action readChangedArticles;
      action tokenizeContent;
      action updateInvertedIndex;
      action verifySearchHealth;
    }
  }

  part def LicenseComplianceService {
    attribute managedLicense : SPDXIdentifier = "AGPL-3.0-or-later";
    attribute sourceArchiveRefreshInterval : Time = 24 [h];

    port sourceApi : SourceDistributionPort;
    port noticeApi : SourceDistributionPort;
    port auditOut : AuditPort;

    item currentNotice : LicenseNotice;
    item currentSource : SourceCodeArchive;

    action provideNetworkSourceOffer {
      in request : UserRequest;
      out archive : SourceCodeArchive;
      out notice : LicenseNotice;
      first verifyPublicNetworkInteraction;
      then selectCorrespondingSourceArchive;
      then attachAGPLNotice;
      then emitComplianceAuditRecord;
      then deliverSourceResponse;

      action verifyPublicNetworkInteraction;
      action selectCorrespondingSourceArchive;
      action attachAGPLNotice;
      action emitComplianceAuditRecord;
      action deliverSourceResponse;
    }

    state def ComplianceStateMachine {
      state SourceCurrent;
      state SourceRefreshRequired;
      state SourcePackaging;
      state SourcePublished;
      state ComplianceFault;

      transition first SourceCurrent;
      transition SourceCurrent_to_SourceRefreshRequired from SourceCurrent to SourceRefreshRequired;
      transition SourceRefreshRequired_to_SourcePackaging from SourceRefreshRequired to SourcePackaging;
      transition SourcePackaging_to_SourcePublished from SourcePackaging to SourcePublished;
      transition SourcePublished_to_SourceCurrent from SourcePublished to SourceCurrent;
      transition SourcePackaging_to_ComplianceFault from SourcePackaging to ComplianceFault;
      transition ComplianceFault_to_SourceRefreshRequired from ComplianceFault to SourceRefreshRequired;
    }
  }

  part def AuditLog {
    attribute retentionPeriod : Time = 2555 [d];
    attribute writeOnce : BooleanFlag = true;

    port auditIn : AuditPort;

    action appendAuditRecord {
      in record : AuditRecord;
      first validateRecordShape;
      then timestampRecord;
      then persistRecord;

      action validateRecordShape;
      action timestampRecord;
      action persistRecord;
    }
  }

  requirement def HighLevelFunctionRequirement {
    subject platform : AGPLBasedKnowledgePlatform;
    doc /* The system shall provide a public network accessible collaborative knowledge platform whose primary function is to let authenticated users create, revise, search, and retrieve knowledge articles while preserving complete AGPL license notices and source availability obligations. */
  }

  requirement def AGPLLicenseRequirement {
    subject platform : AGPLBasedKnowledgePlatform;
    doc /* The system shall identify its software license as GNU Affero General Public License version 3.0 or later using SPDX identifier AGPL-3.0-or-later. */
  }

  requirement def NetworkSourceAvailabilityRequirement {
    subject compliance : LicenseComplianceService;
    doc /* The system shall provide the complete corresponding source code to users interacting with the service over a network. */
  }

  requirement def ArticleRevisionRequirement {
    subject repository : KnowledgeRepository;
    doc /* The repository shall retain immutable article revisions for at least 3650 days. */
  }

  requirement def SearchPerformanceRequirement {
    subject platform : AGPLBasedKnowledgePlatform;
    doc /* The system shall return interactive search results within 2 seconds under nominal operating load. */
  }

  requirement def AuditabilityRequirement {
    subject audit : AuditLog;
    doc /* The system shall record article modification, authentication failure, and license source delivery events in a write-once audit log. */
  }

  satisfy HighLevelFunctionRequirement by AGPLBasedKnowledgePlatform;
  satisfy AGPLLicenseRequirement by AGPLBasedKnowledgePlatform;
  satisfy NetworkSourceAvailabilityRequirement by LicenseComplianceService;
  satisfy ArticleRevisionRequirement by KnowledgeRepository;
  satisfy SearchPerformanceRequirement by WebApplication;
  satisfy AuditabilityRequirement by AuditLog;

  part agplKnowledgeSystem : AGPLBasedKnowledgePlatform {
    attribute publicNetworkService = true;
    attribute minimumAvailability = 99.5;
    attribute maxInteractiveLatency = 2 [s];
    attribute license = "AGPL-3.0-or-later";
  }
}