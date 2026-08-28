package WebArchivingSystem {
    import ScalarValues::*;

    // ======== Units ========
    unit petabyte;
    unit terabyte;
    unit byte;
    unit second;
    unit millisecond;
    unit count;
    unit pages_per_second;
    unit requests_per_second;

    // ======== Value Types ========
    value type DataSize :> Real {
        :>> unit = petabyte;
    }
    value type CrawlRate :> Real {
        :>> unit = pages_per_second;
    }
    value type ResponseTime :> Real {
        :>> unit = millisecond;
    }
    value type Quantity :> Real {
        :>> unit = count;
    }
    value type Throughput :> Real {
        :>> unit = requests_per_second;
    }

    // ======== Item Definitions ========
    item def URL {
        attribute urlString : String;
        attribute protocol : String = "https";
        attribute domainName : String;
        attribute resourcePath : String;
    }

    item def WebPage {
        attribute url : URL;
        attribute captureTimestamp : String;
        attribute htmlContent : String;
        attribute mediaFileUrls : String[*];
        attribute httpStatusCode : Integer;
        attribute contentType : String;
        attribute contentSizeBytes : Quantity;
    }

    item def ArchivedSnapshot {
        attribute snapshotId : String;
        attribute originalUrl : URL;
        attribute captureDate : String;
        attribute compressedData : String;
        attribute archiveRecordId : String;
        attribute compressionRatio : Real;
        attribute originalSizeBytes : Quantity;
        attribute compressedSizeBytes : Quantity;
    }

    item def IndexEntry {
        attribute originalUrl : URL;
        attribute captureDate : String;
        attribute archiveRecordId : String;
        attribute snapshotId : String;
    }

    item def UserQuery {
        attribute queryId : String;
        attribute requestedUrl : URL;
        attribute targetDate : String;
        attribute userId : String;
    }

    item def QueryResponse {
        attribute queryId : String;
        attribute archiveRecordId : String;
        attribute decompressedContent : String;
        attribute found : Boolean;
        attribute responseTime : ResponseTime;
        attribute errorMessage : String;
    }

    // ======== Port Definitions ========
    port def CrawlOutputPort {
        out crawledPages : WebPage[*];
    }
    port def StorageInputPort {
        in incomingPages : WebPage[*];
    }
    port def MetadataOutputPort {
        out metadataEntries : IndexEntry[*];
    }
    port def MetadataInputPort {
        in indexEntries : IndexEntry[*];
    }
    port def QueryOutputPort {
        out outgoingQueries : UserQuery[*];
    }
    port def QueryInputPort {
        in incomingQueries : UserQuery[*];
    }
    port def RecordIdOutputPort {
        out recordIds : String[*];
    }
    port def RecordIdInputPort {
        in recordIds : String[*];
    }
    port def SnapshotReqOutputPort {
        out snapshotRequests : String[*];
    }
    port def SnapshotReqInputPort {
        in snapshotRequests : String[*];
    }
    port def SnapshotOutputPort {
        out retrievedSnapshots : ArchivedSnapshot[*];
    }
    port def SnapshotInputPort {
        in retrievedSnapshots : ArchivedSnapshot[*];
    }
    port def UserQueryInputPort {
        in userQueries : UserQuery[*];
    }
    port def UserResponseOutputPort {
        out responses : QueryResponse[*];
    }

    // ======== Action Definitions ========
    action def DiscoverUrls {
        in seedUrls : URL[*];
        out discoveredUrls : URL[*];
    }
    action def FetchPage {
        in targetUrl : URL;
        out fetchedPage : WebPage;
    }
    action def CompressPage {
        in page : WebPage;
        out snapshot : ArchivedSnapshot;
    }
    action def StoreSnapshot {
        in snapshot : ArchivedSnapshot;
        out recordId : String;
    }
    action def RetrieveSnapshot {
        in recordId : String;
        out snapshot : ArchivedSnapshot;
    }
    action def DecompressSnapshot {
        in snapshot : ArchivedSnapshot;
        out content : String;
    }
    action def AddIndexEntry {
        in entry : IndexEntry;
        out success : Boolean;
    }
    action def SearchIndex {
        in query : UserQuery;
        out recordId : String;
        out found : Boolean;
    }
    action def ProcessUserQuery {
        in query : UserQuery;
        out response : QueryResponse;
    }

    // ======== State Machine Definitions ========
    state def CrawlerStateMachine {
        state Idle;
        state Discovering;
        state Fetching;
        state Paused;
        transition from Idle to Discovering when startCrawling;
        transition from Discovering to Fetching when urlsDiscovered;
        transition from Fetching to Discovering when pageFetchComplete;
        transition from Fetching to Paused when pauseRequested;
        transition from Discovering to Paused when pauseRequested;
        transition from Paused to Discovering when resumeRequested;
    }

    state def StorageStateMachine {
        state Receiving;
        state Compressing;
        state Storing;
        state Replicating;
        transition from Receiving to Compressing when pageReceived;
        transition from Compressing to Storing when compressionComplete;
        transition from Storing to Replicating when storageComplete;
        transition from Replicating to Receiving when replicationComplete;
    }

    state def IndexingStateMachine {
        state Ingesting;
        state Processing;
        state Indexing;
        state Querying;
        transition from Ingesting to Processing when metadataReceived;
        transition from Processing to Indexing when metadataParsed;
        transition from Indexing to Ingesting when entryIndexed;
        transition from Indexing to Querying when searchRequested;
        transition from Querying to Ingesting when searchComplete;
    }

    state def UIStateMachine {
        state Listening;
        state ProcessingQuery;
        state Retrieving;
        state Responding;
        transition from Listening to ProcessingQuery when userQueryReceived;
        transition from ProcessingQuery to Retrieving when recordIdLocated;
        transition from Retrieving to Responding when contentRetrieved;
        transition from Responding to Listening when responseDelivered;
    }

    // ======== Part Definitions ========
    part def WebCrawler {
        attribute crawlerId : String;
        attribute isActive : Boolean = true;
        attribute fetchRate : CrawlRate;
        attribute assignedDomains : String[*];
        attribute pagesCrawled : Quantity;
        port crawlOut : CrawlOutputPort;
        action fetchPage : FetchPage;
        action discoverUrls : DiscoverUrls;
        state CrawlerStateMachine;
    }

    part def WebCrawlerModule {
        attribute moduleActive : Boolean = true;
        attribute totalCrawlRate : CrawlRate;
        attribute activeCrawlerCount : Quantity;
        attribute maxCrawlerCount : Quantity;
        port crawlOutput : CrawlOutputPort;
        part crawlerFleet : WebCrawler[*];
        action crawlWeb {
            out discoveredPages : WebPage[*];
        }
        state {
            state Inactive;
            state Active;
            transition from Inactive to Active when moduleActivated;
            transition from Active to Inactive when moduleDeactivated;
        }
    }

    part def CompressionUnit {
        attribute algorithm : String = "gzip";
        attribute targetRatio : Real = 0.3;
        attribute processingQueueDepth : Quantity;
        action compress : CompressPage;
    }

    part def StorageCluster {
        attribute clusterId : String;
        attribute capacity : DataSize;
        attribute usedSpace : DataSize;
        attribute redundancyLevel : Integer = 3;
        attribute snapshotCount : Quantity;
        action store : StoreSnapshot;
        action retrieve : RetrieveSnapshot;
    }

    part def StorageModule {
        attribute totalCapacity : DataSize;
        attribute redundancyFactor : Integer = 3;
        attribute totalSnapshotCount : Quantity;
        attribute isOperational : Boolean = true;
        attribute compressionAlgorithm : String = "gzip";
        port storageInput : StorageInputPort;
        port metadataOutput : MetadataOutputPort;
        port snapshotRequestInput : SnapshotReqInputPort;
        port snapshotOutput : SnapshotOutputPort;
        part compressionUnit : CompressionUnit;
        part storageClusters : StorageCluster[*];
        action compressPage : CompressPage;
        action storeSnapshot : StoreSnapshot;
        action retrieveSnapshot : RetrieveSnapshot;
        state StorageStateMachine;
    }

    part def IndexDatabase {
        attribute dbType : String = "temporal";
        attribute entryCount : Quantity;
        attribute maxEntries : Quantity;
        action add : AddIndexEntry;
        action search : SearchIndex;
    }

    part def IndexingModule {
        attribute isOperational : Boolean = true;
        attribute indexEntryCount : Quantity;
        attribute averageQueryTime : ResponseTime;
        port indexInput : MetadataInputPort;
        port queryInput : QueryInputPort;
        port recordIdOutput : RecordIdOutputPort;
        part indexDatabase : IndexDatabase;
        action addIndexEntry : AddIndexEntry;
        action searchIndex : SearchIndex;
        state IndexingStateMachine;
    }

    part def QueryProcessor {
        attribute activeQueryCount : Quantity;
        attribute maxConcurrentQueries : Quantity;
        attribute totalProcessedQueries : Quantity;
        action processQuery : ProcessUserQuery;
    }

    part def UserInterfaceModule {
        attribute isOperational : Boolean = true;
        attribute maxRequestRate : Throughput;
        attribute averageResponseTime : ResponseTime;
        attribute activeConnections : Quantity;
        port userQueryInput : UserQueryInputPort;
        port userResponseOutput : UserResponseOutputPort;
        port indexQueryOutput : QueryOutputPort;
        port recordIdInput : RecordIdInputPort;
        port snapshotRequestOutput : SnapshotReqOutputPort;
        port snapshotInput : SnapshotInputPort;
        part queryProcessor : QueryProcessor;
        action decompressSnapshot : DecompressSnapshot;
        state UIStateMachine;
    }

    // ======== Top-Level System Assembly ========
    part def WebArchiveSystem {
        attribute systemName : String = "WebArchive";
        attribute systemActive : Boolean = true;
        attribute totalStorageCapacity : DataSize;
        attribute totalCrawlRate : CrawlRate;
        part crawlerModule : WebCrawlerModule;
        part storageModule : StorageModule;
        part indexingModule : IndexingModule;
        part userInterfaceModule : UserInterfaceModule;
        connect crawlerModule.crawlOutput to storageModule.storageInput;
        connect storageModule.metadataOutput to indexingModule.indexInput;
        connect userInterfaceModule.indexQueryOutput to indexingModule.queryInput;
        connect indexingModule.recordIdOutput to userInterfaceModule.recordIdInput;
        connect userInterfaceModule.snapshotRequestOutput to storageModule.snapshotRequestInput;
        connect storageModule.snapshotOutput to userInterfaceModule.snapshotInput;
        state {
            state Offline;
            state Online;
            transition from Offline to Online when systemStartup;
            transition from Online to Offline when systemShutdown;
        }
    }

    // ======== Requirement Definitions ========
    requirement def CrawlRateRequirement {
        attribute minimumCrawlRate : CrawlRate;
        doc {
            The web crawler module shall continuously crawl the World Wide Web
            at a high rate using a large number of active crawlers to discover
            and fetch the content of web pages including text images and other
            media files capturing new and updated content.
        }
    }

    requirement def StorageCapacityRequirement {
        attribute minimumCapacity : DataSize;
        attribute minimumRedundancy : Integer;
        attribute minimumSnapshotCount : Quantity;
        doc {
            The storage module shall provide petabyte-scale capacity with high
            redundancy to prevent data loss storing billions of individual
            web page snapshots as time-stamped archival records with
            compression to save space.
        }
    }

    requirement def IndexingRequirement {
        attribute maximumQueryResponseTime : ResponseTime;
        doc {
            The indexing module shall create and maintain a sophisticated
            temporal index processing metadata from each archived snapshot
            such as original URL and capture date enabling fast search to
            locate the correct archival record ID for a requested site and date.
        }
    }

    requirement def UIRequirement {
        attribute maximumConcurrentRequests : Throughput;
        attribute maximumResponseTime : ResponseTime;
        doc {
            The user interface module shall accept a user query consisting of
            a website URL and a target date coordinating with indexing and
            storage modules to find retrieve and decompress the requested
            web page snapshot delivering historical content back to the user
            browser handling tens of thousands of simultaneous requests.
        }
    }

    requirement def PreservationRequirement {
        doc {
            The system shall ensure long-term digital preservation of web
            content maintaining the history of the internet for research
            education and cultural heritage purposes.
        }
    }

    requirement def ContinuousOperationRequirement {
        doc {
            The system shall operate in a continuous cycle simultaneously
            crawling the web storing new content updating the index and
            serving historical content to users without interruption.
        }
    }

    // ======== Specific Requirements ========
    requirement CrawlRateReq :> CrawlRateRequirement {
        :>> minimumCrawlRate = 10000 [pages_per_second];
    }

    requirement StorageCapReq :> StorageCapacityRequirement {
        :>> minimumCapacity = 100 [petabyte];
        :>> minimumRedundancy = 3;
        :>> minimumSnapshotCount = 10000000000 [count];
    }

    requirement IndexSearchReq :> IndexingRequirement {
        :>> maximumQueryResponseTime = 500 [millisecond];
    }

    requirement UIConcurReq :> UIRequirement {
        :>> maximumConcurrentRequests = 50000 [requests_per_second];
        :>> maximumResponseTime = 2000 [millisecond];
    }

    // ======== Satisfaction ========
    satisfy CrawlRateReq by WebCrawlerModule;
    satisfy StorageCapReq by StorageModule;
    satisfy IndexSearchReq by IndexingModule;
    satisfy UIConcurReq by UserInterfaceModule;
    satisfy PreservationRequirement by WebArchiveSystem;
    satisfy ContinuousOperationRequirement by WebArchiveSystem;
}
