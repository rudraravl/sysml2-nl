package WaybackMachineSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def URLString :> String;
    attribute def TimestampString :> String;
    attribute def HTMLContent :> String;
    
    attribute def DataSizeValue :> Real;
    attribute def CrawlRateValue :> Real;

    item def WebPage {
        attribute url : URLString;
        attribute captureTimestamp : TimestampString;
        attribute htmlData : HTMLContent;
        attribute sizeBytes : DataSizeValue;
        attribute mediaFiles : String[0..*];
    }

    item def ArchiveSnapshot {
        attribute snapshotId : String;
        attribute originalURL : URLString;
        attribute captureDate : TimestampString;
        attribute storedSize : DataSizeValue;
        attribute compressionRatio : Real;
    }

    item def UserQuery {
        attribute requestedURL : URLString;
        attribute targetTimestamp : TimestampString;
    }

    port def CrawlOutputPort {
        out item discoveredPage : WebPage;
    }

    port def StorageInputPort {
        in item pageToStore : WebPage;
    }

    port def StorageOutputPort {
        out item retrievedSnapshot : ArchiveSnapshot;
    }

    port def QueryInputPort {
        in item userRequest : UserQuery;
    }

    port def QueryOutputPort {
        out item queryResult : WebPage;
    }

    action def CrawlWebPages {
        in targetURL : URLString;
        out discoveredPages : WebPage[1..*];
        
        first start;
        then action fetchPage {
            in url : URLString;
            out pageContent : HTMLContent;
        }
        then action extractLinks {
            in content : HTMLContent;
            out links : URLString[0..*];
        }
        then action createSnapshot {
            in url : URLString;
            in content : HTMLContent;
            out page : WebPage;
        }
        then done;
    }

    action def StoreArchive {
        in webPage : WebPage;
        out archiveRecord : ArchiveSnapshot;
        
        first start;
        then action compressContent {
            in rawPage : WebPage;
            out compressedData : Real;
        }
        then action writeToStorage {
            in data : Real;
            out recordId : String;
        }
        then action createRecord {
            in id : String;
            in page : WebPage;
            out snapshot : ArchiveSnapshot;
        }
        then done;
    }

    action def RetrieveArchive {
        in query : UserQuery;
        out result : WebPage;
        
        first start;
        then action searchIndex {
            in url : URLString;
            in timestamp : TimestampString;
            out matchedId : String;
        }
        then action fetchFromStorage {
            in recordId : String;
            out snapshot : ArchiveSnapshot;
        }
        then action decompressContent {
            in snapshot : ArchiveSnapshot;
            out page : WebPage;
        }
        then done;
    }

    part def WebCrawlerModule {
        attribute crawlFrequency : CrawlRateValue;
        attribute maxCrawlDepth : Integer;
        attribute activeCrawlers : Integer;
        
        port crawlOutput : CrawlOutputPort;
        
        perform action executeCrawl[*] ordered;
    }

    part def StorageModule {
        attribute totalCapacityGB : DataSizeValue;
        attribute usedCapacityGB : DataSizeValue;
        attribute compressionEnabled : Boolean;
        attribute redundancyLevel : Integer;
        
        port storageInput : StorageInputPort;
        port storageOutput : StorageOutputPort;
        
        perform action storeData[*] ordered;
    }

    part def IndexingModule {
        attribute indexEntries : Integer;
        attribute indexingRate : Real;
        
        perform action buildIndex {
            in snapshots : ArchiveSnapshot[1..*];
            out indexComplete : Boolean;
            
            first start;
            then action parseMetadata {
                in records : ArchiveSnapshot[1..*];
                out metadata : String[1..*];
            }
            then action createTemporalIndex {
                in data : String[1..*];
                out indexStructure : String;
            }
            then action optimizeIndex {
                in structure : String;
                out optimized : Boolean;
            }
            then done;
        }
        
        perform action queryIndex {
            in searchQuery : UserQuery;
            out matchedRecordId : String;
            
            first start;
            then action parseQuery {
                in query : UserQuery;
                out searchParams : String;
            }
            then action findClosestMatch {
                in params : String;
                out recordId : String;
            }
            then done;
        }
    }

    part def UserInterfaceModule {
        attribute maxConcurrentUsers : Integer;
        attribute responseTimeMs : Real;
        
        port queryInput : QueryInputPort;
        port queryOutput : QueryOutputPort;
        
        perform action handleUserRequest[*] ordered;
    }

    part waybackMachine : WaybackMachineSystem {
        attribute systemName : String = "Internet Archive Wayback Machine";
        attribute operationalSince : String = "1996";
        attribute totalPagesArchived : Integer;
        
        part crawler : WebCrawlerModule {
            attribute :>> crawlFrequency = 500.0;
            attribute :>> maxCrawlDepth = 10;
            attribute :>> activeCrawlers = 100;
        }
        
        part storage : StorageModule {
            attribute :>> totalCapacityGB = 100000000.0;
            attribute :>> usedCapacityGB = 75000000.0;
            attribute :>> compressionEnabled = true;
            attribute :>> redundancyLevel = 3;
        }
        
        part indexer : IndexingModule {
            attribute :>> indexEntries = 500000000;
            attribute :>> indexingRate = 10000.0;
        }
        
        part userInterface : UserInterfaceModule {
            attribute :>> maxConcurrentUsers = 50000;
            attribute :>> responseTimeMs = 200.0;
        }
        
        connection crawlerToStorage connect crawler.crawlOutput to storage.storageInput;
        connection storageToUI connect storage.storageOutput to userInterface.queryOutput;
        
        perform action archiveWebContent {
            first start;
            then merge continuousArchiving;
            then action crawlPhase : CrawlWebPages;
            then action storePhase : StoreArchive;
            then action indexPhase : indexer.buildIndex;
            then continuousArchiving;
        }
        
        perform action serveHistoricalContent {
            first start;
            then action receiveQuery : RetrieveArchive;
            then action searchPhase : indexer.queryIndex;
            then action retrievePhase : RetrieveArchive;
            then action deliverResult;
            then done;
        }
        
        exhibit state machine OperationalStates {
            initial state Initializing;
            state Crawling {
                entry perform archiveWebContent.crawlPhase;
            }
            state Storing {
                entry perform archiveWebContent.storePhase;
            }
            state Indexing {
                entry perform archiveWebContent.indexPhase;
            }
            state Serving {
                entry perform serveHistoricalContent;
            }
            state Maintenance;
            
            transition from Initializing to Crawling;
            transition from Crawling to Storing;
            transition from Storing to Indexing;
            transition from Indexing to Crawling;
            transition from Crawling to Serving;
            transition from Serving to Crawling;
            transition from Crawling to Maintenance;
            transition from Maintenance to Crawling;
        }
    }

    requirement <'REQ-WM-001'> primaryArchiveFunction {
        doc /* The Wayback Machine system shall continuously crawl, capture, and archive 
             * web pages from the internet, preserving their content and structure as 
             * digital snapshots at specific points in time for historical preservation.
             */
        subject system :> waybackMachine;
        
        require constraint {
            system.crawler.crawlFrequency > 0.0 and
            system.storage.compressionEnabled == true
        }
    }

    requirement <'REQ-WM-002'> temporalRetrievalFunction {
        doc /* The system shall enable users to retrieve and view archived versions of 
             * web pages as they appeared at specific dates and times in the past, 
             * providing temporal navigation through internet history.
             */
        subject system :> waybackMachine;
        
        require constraint {
            system.userInterface.responseTimeMs <= 500.0 and
            system.indexer.indexEntries > 0
        }
    }

    requirement <'REQ-WM-003'> storageCapacityRequirement {
        doc /* The archive storage shall maintain sufficient capacity to store billions 
             * of compressed web page snapshots with efficient retrieval capabilities.
             */
        subject storage :> waybackMachine.storage;
        
        assert constraint {
            storage.usedCapacityGB <= storage.totalCapacityGB and
            storage.redundancyLevel >= 2
        }
    }

    requirement <'REQ-WM-004'> crawlPerformanceRequirement {
        doc /* The web crawler shall maintain continuous operation with multiple 
             * concurrent crawlers to maximize web coverage and archival completeness.
             */
        subject crawler :> waybackMachine.crawler;
        
        assert constraint {
            crawler.activeCrawlers >= 50 and
            crawler.maxCrawlDepth >= 5
        }
    }

    requirement <'REQ-WM-005'> userAccessRequirement {
        doc /* The user interface shall support high-volume concurrent access by 
             * multiple users requesting historical web page snapshots simultaneously.
             */
        subject ui :> waybackMachine.userInterface;
        
        assert constraint {
            ui.maxConcurrentUsers >= 10000
        }
    }

    requirement overallMission {
        doc /* The Wayback Machine system shall provide a comprehensive digital archive 
             * of the World Wide Web, enabling long-term preservation of internet history 
             * and universal access to historical web content for research, education, 
             * and cultural preservation purposes.
             */
        
        assume constraint internetAccessible {
            doc /* Web content is accessible via standard internet protocols for crawling. */
        }
        
        require primaryArchiveFunction;
        require temporalRetrievalFunction;
        require storageCapacityRequirement;
        require crawlPerformanceRequirement;
        require userAccessRequirement;
    }

    satisfy overallMission by waybackMachine;
    satisfy primaryArchiveFunction by waybackMachine.archiveWebContent;
    satisfy temporalRetrievalFunction by waybackMachine.serveHistoricalContent;
}
