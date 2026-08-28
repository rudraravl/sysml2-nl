package PreprintRepository {

    import ScalarValues::*;
    import Time::*;

    //==========================================================================
    // Value Types
    //==========================================================================
    value type StorageSize :> Real {
        doc / Storage capacity measured in terabytes (TB). /
    }

    value type DownloadCount :> Integer {
        doc / Cumulative count of downloads per paper. /
    }

    value type HitCount :> Integer {
        doc / Number of index hits matching a query. /
    }

    value type RelevanceScore :> Real {
        doc / Search relevance ranking score, bounded between 0 and 100. /
    }

    value type PlagiarismScore :> Real {
        doc / Automated plagiarism score, bounded between 0 and 100. /
    }

    value type CompressionRatio :> Real {
        doc / Achieved data compression ratio. /
    }

    //==========================================================================
    // Enumerations
    //==========================================================================
    enum def ModerationStatus {
        Pending;
        Approved;
        Flagged;
        Rejected;
    }

    enum def SubmissionStatus {
        Received;
        Validated;
        Assigned;
        Moderated;
        Archived;
        Indexed;
        Rejected;
    }

    enum def PaperCategory {
        Physics;
        Mathematics;
        ComputerScience;
        Biology;
        Chemistry;
        Economics;
        Other;
    }

    //==========================================================================
    // Item Definitions
    //==========================================================================
    item def BinaryData {
        attribute byteSize : Integer;
        attribute sha256 : String;
    }

    item def Manuscript {
        attribute id : String;
        attribute title : String;
        attribute authors : String[0..*];
        attribute abstractText : String;
        attribute keywords : String[0..*];
        attribute categories : PaperCategory[0..*];
        attribute pdfBlob : BinaryData;
        attribute sourceBlob : BinaryData;
        attribute submissionDate : DateTime;
        attribute fileSize : StorageSize;
        attribute status : SubmissionStatus;
    }

    item def Submission {
        attribute authorName : String;
        attribute authorEmail : String;
        attribute manuscript : Manuscript;
        attribute submittedAt : DateTime;
        attribute contactId : String;
    }

    item def Query {
        attribute keywords : String[0..*];
        attribute authors : String[0..*];
        attribute categories : PaperCategory[0..*];
        attribute dateFrom : DateTime;
        attribute dateTo : DateTime;
    }

    item def SearchResultItem {
        attribute paperId : String;
        attribute title : String;
        attribute authors : String[0..*];
        attribute relevance : RelevanceScore;
        attribute downloadURL : String;
    }

    item def PaperMetadata {
        attribute paperId : String;
        attribute title : String;
        attribute authors : String[0..*];
        attribute keywords : String[0..*];
        attribute categories : PaperCategory[0..*];
        attribute publicationDate : DateTime;
    }

    item def ModerationReport {
        attribute paperId : String;
        attribute plagiarismScore : PlagiarismScore;
        attribute formatCompliant : Boolean;
        attribute status : ModerationStatus;
        attribute comments : String;
        attribute reviewedAt : DateTime;
    }

    //==========================================================================
    // Port Definitions
    //==========================================================================
    port def SubmissionReceivePort {
        in submission : Submission;
    }

    port def ManuscriptSendPort {
        out manuscript : Manuscript;
    }

    port def ManuscriptReceivePort {
        in manuscript : Manuscript;
    }

    port def StorageRetrievePort {
        in paperId : String;
        out manuscript : Manuscript;
    }

    port def DownloadRequestPort {
        in paperId : String;
        out manuscript : Manuscript;
        out downloadCount : DownloadCount;
    }

    port def QueryExchangePort {
        in query : Query;
        out results : SearchResultItem[0..*];
    }

    port def ModerationReceivePort {
        in manuscript : Manuscript;
        out report : ModerationReport;
    }

    //==========================================================================
    // Submission Processor
    //==========================================================================
    part def SubmissionProcessor {
        port submissionPort : SubmissionReceivePort;
        port manuscriptOutPort : ManuscriptSendPort;

        attribute assignedPaperIds : String[0..*];
        attribute nextIdSequence : Integer = 1;
        attribute maxTitleLength : Integer = 300;
        attribute maxAbstractLength : Integer = 5000;

        action def validateSubmission {
            in sub : Submission;
            out valid : Boolean;
        }

        action def assignPaperId {
            in manuscript : Manuscript;
            out id : String;
        }

        action def routeToModeration {
            in manuscript : Manuscript;
        }

        action def generateArxivStyleId {
            in sequence : Integer;
            out id : String;
        }

        state Idle;
        state Validating;
        state AssigningId;
        state Routing;

        transition Idle -> Validating on submissionPort.submission;
        transition Validating -> AssigningId;
        transition AssigningId -> Routing;
        transition Routing -> Idle;
    }

    //==========================================================================
    // Moderation Service
    //==========================================================================
    part def ModerationService {
        port moderationPort : ModerationReceivePort;
        port approvedManuscriptPort : ManuscriptSendPort;

        attribute humanReviewQueue : Manuscript[0..*];
        attribute thresholdPlagiarism : PlagiarismScore = 10.0;
        attribute requiredFormatCompliant : Boolean = true;
        attribute maxQueueSize : Integer = 5000;

        action def scanForPlagiarism {
            in manuscript : Manuscript;
            out score : PlagiarismScore;
        }

        action def checkFormatCompliance {
            in manuscript : Manuscript;
            out compliant : Boolean;
        }

        action def evaluateReport {
            in plagiarism : PlagiarismScore;
            in compliant : Boolean;
            out status : ModerationStatus;
        }

        action def enqueueForManualReview {
            in manuscript : Manuscript;
        }

        action def routeApprovedPaper {
            in manuscript : Manuscript;
        }

        action def notifyAuthor {
            in manuscript : Manuscript;
            in status : ModerationStatus;
        }

        state Idle;
        state Scanning;
        state Deciding;
        state Approved;
        state Flagged;
        state Rejected;

        transition Idle -> Scanning on moderationPort.manuscript;
        transition Scanning -> Deciding;
        transition Deciding -> Approved;
        transition Deciding -> Flagged;
        transition Flagged -> Approved;
        transition Flagged -> Rejected;
        transition Approved -> Idle;
        transition Rejected -> Idle;
    }

    //==========================================================================
    // Storage System
    //==========================================================================
    part def StorageSystem {
        port storageInPort : ManuscriptReceivePort;
        port storageNotifyPort : ManuscriptSendPort;
        port retrievePort : StorageRetrievePort;

        attribute totalCapacity : StorageSize = 500;
        attribute usedCapacity : StorageSize = 0;
        attribute redundancyFactor : Integer = 3;
        attribute compressionEnabled : Boolean = true;
        attribute compressionRatio : CompressionRatio = 3.5;
        attribute storedPapers : Manuscript[0..*];
        attribute downloadCountByPaper : DownloadCount[0..*];
        attribute maxConcurrentRetrievals : Integer = 1000;

        action def compress {
            in manuscript : Manuscript;
            out compressed : Manuscript;
        }

        action def replicate3x {
            in manuscript : Manuscript;
        }

        action def persist {
            in manuscript : Manuscript;
        }

        action def notifyIndexing {
            in manuscript : Manuscript;
        }

        action def retrieve {
            in paperId : String;
            out manuscript : Manuscript;
        }

        action def incrementDownloadCount {
            in paperId : String;
            out count : DownloadCount;
        }

        action def verifyRedundancy {
            in manuscript : Manuscript;
            out verified : Boolean;
        }

        state Idle;
        state Receiving;
        state Compressing;
        state Replicating;
        state Persisting;
        state Notifying;

        transition Idle -> Receiving on storageInPort.manuscript;
        transition Receiving -> Compressing;
        transition Compressing -> Replicating;
        transition Replicating -> Persisting;
        transition Persisting -> Notifying;
        transition Notifying -> Idle;
    }

    //==========================================================================
    // Indexing Service
    //==========================================================================
    part def IndexingService {
        port indexingInPort : ManuscriptReceivePort;
        port queryPort : QueryExchangePort;

        attribute indexEntries : PaperMetadata[0..*];
        attribute totalIndexed : Integer = 0;
        attribute indexRebuildInterval : Integer = 3600;

        action def extractMetadata {
            in manuscript : Manuscript;
            out metadata : PaperMetadata;
        }

        action def updateIndex {
            in metadata : PaperMetadata;
        }

        action def executeQuery {
            in query : Query;
            out results : SearchResultItem[0..*];
        }

        action def tokenizeText {
            in text : String;
            out tokens : String[0..*];
        }

        action def rankByRelevance {
            in candidates : SearchResultItem[0..*];
            in query : Query;
            out ranked : SearchResultItem[0..*];
        }

        state Idle;
        state Extracting;
        state Indexing;
        state Available;

        transition Idle -> Extracting on indexingInPort.manuscript;
        transition Extracting -> Indexing;
        transition Indexing -> Available;
        transition Available -> Idle;
    }

    //==========================================================================
    // Search Engine
    //==========================================================================
    part def SearchEngine {
        port userQueryPort : QueryExchangePort;
        port indexQueryPort : QueryExchangePort;

        attribute maxResultsPerQuery : Integer = 200;
        attribute defaultRelevanceThreshold : RelevanceScore = 5.0;

        action def executeSearch {
            in query : Query;
            out results : SearchResultItem[0..*];
        }

        action def rankResults {
            in raw : SearchResultItem[0..*];
            out ranked : SearchResultItem[0..*];
        }

        action def filterByDateRange {
            in results : SearchResultItem[0..*];
            in dateFrom : DateTime;
            in dateTo : DateTime;
            out filtered : SearchResultItem[0..*];
        }

        state Idle;
        state Querying;
        state Ranking;
        state Returning;

        transition Idle -> Querying on userQueryPort.query;
        transition Querying -> Ranking;
        transition Ranking -> Returning;
        transition Returning -> Idle;
    }

    //==========================================================================
    // Download Service
    //==========================================================================
    part def DownloadService {
        port userDownloadPort : DownloadRequestPort;
        port storageAccessPort : StorageRetrievePort;

        attribute activeDownloads : Integer = 0;
        attribute totalDownloads : DownloadCount = 0;
        attribute maxConcurrentDownloads : Integer = 5000;

        action def handleDownload {
            in paperId : String;
            out manuscript : Manuscript;
        }

        action def logMetrics {
            in paperId : String;
            in count : DownloadCount;
        }

        action def incrementActiveDownloads {
            out count : Integer;
        }

        action def decrementActiveDownloads {
            out count : Integer;
        }

        state Idle;
        state Fetching;
        state Delivering;
        state Logging;

        transition Idle -> Fetching on userDownloadPort.paperId;
        transition Fetching -> Delivering;
        transition Delivering -> Logging;
        transition Logging -> Idle;
    }

    //==========================================================================
    // Repository System (Top Level)
    //==========================================================================
    part def RepositorySystem {
        part submissionProcessor : SubmissionProcessor;
        part moderationService : ModerationService;
        part storageSystem : StorageSystem;
        part indexingService : IndexingService;
        part searchEngine : SearchEngine;
        part downloadService : DownloadService;

        connect submissionProcessor.manuscriptOutPort to moderationService.moderationPort;
        connect moderationService.approvedManuscriptPort to storageSystem.storageInPort;
        connect storageSystem.storageNotifyPort to indexingService.indexingInPort;
        connect searchEngine.indexQueryPort to indexingService.queryPort;
        connect downloadService.storageAccessPort to storageSystem.retrievePort;
    }

    //==========================================================================
    // Requirements
    //==========================================================================
    requirement def AccelerateDissemination {
        doc / The system shall accelerate dissemination of new research findings within the scientific community by providing rapid submission, moderation, archival, search, and download workflows. /
    }

    requirement def ValidateAndAssignId {
        doc / The Submission Processor shall validate each submitted manuscript for completeness and format compliance, assign a unique paper identifier, and route the manuscript to the moderation service for quality control. /
    }

    requirement def ProvideReliableStorage {
        doc / The Storage System shall provide at least 500 terabytes of capacity with triple redundancy and data compression enabled, ensuring that no submitted papers are ever lost due to hardware failure. /
    }

    requirement def ProvideIndexing {
        doc / The Indexing Service shall automatically extract authors, keywords, and categories from each newly stored paper and maintain a fast-access search index supporting keyword, author, and category-based queries. /
    }

    requirement def ProvideSearch {
        doc / The Search Engine shall accept user queries based on keywords, authors, or date ranges, query the maintained search index, and return a ranked list of relevant results ordered by computed relevance score. /
    }

    requirement def ProvideDownload {
        doc / The Download Service shall retrieve requested manuscripts from the storage system, deliver the file to the requesting user, and track per-paper download counts for usage metrics. /
    }

    requirement def ProvideModeration {
        doc / The Moderation Service shall automatically scan every new submission for plagiarism and formatting compliance, approving compliant papers for archival and flagging non-compliant papers for manual review by human moderators. /
    }

    requirement def ProvideLifecycle {
        doc / The system shall provide a complete preprint workflow: an author submits a manuscript, the manuscript undergoes automated moderation, approved manuscripts are permanently archived in the storage system, indexed by the indexing service, and made searchable and downloadable to the global research community. /
    }

    requirement reqAccelerate : AccelerateDissemination;
    requirement reqSubmit : ValidateAndAssignId;
    requirement reqStorage : ProvideReliableStorage;
    requirement reqIndexing : ProvideIndexing;
    requirement reqSearch : ProvideSearch;
    requirement reqDownload : ProvideDownload;
    requirement reqModeration : ProvideModeration;
    requirement reqLifecycle : ProvideLifecycle;

    satisfy reqAccelerate by RepositorySystem;
    satisfy reqSubmit by SubmissionProcessor;
    satisfy reqStorage by StorageSystem;
    satisfy reqIndexing by IndexingService;
    satisfy reqSearch by SearchEngine;
    satisfy reqDownload by DownloadService;
    satisfy reqModeration by ModerationService;
    satisfy reqLifecycle by RepositorySystem;
}
