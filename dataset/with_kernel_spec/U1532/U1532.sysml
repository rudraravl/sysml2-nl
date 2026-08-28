package WebArchivingSystem {
	private import ScalarValues::String;
	private import ScalarValues::Real;
	private import ScalarValues::Integer;
	private import SI::s;
	private import Time::DateTime;

	package Definitions {
		item def WebPageContent {
			attribute url : String;
			attribute capturedAt : DateTime;
			attribute textContent : String;
			attribute mediaURIs : String [0..*];
		}

		item def CompressedData {
			attribute compressedPayload : String;
		}

		item def ArchivedSnapshot {
			attribute recordID : String;
			attribute sourceURL : String;
			attribute captureDate : DateTime;
			item compressedContent : CompressedData;
		}

		item def IndexEntry {
			attribute url : String;
			attribute captureDate : DateTime;
			attribute recordID : String;
		}

		item def UserQuery {
			attribute targetURL : String;
			attribute targetDate : DateTime;
		}

		item def ArchivedPageResponse {
			attribute sourceURL : String;
			attribute captureDate : DateTime;
			item content : WebPageContent;
		}

		port def PageOutPort {
			out item page : WebPageContent;
		}
		port def PageInPort {
			in item page : WebPageContent;
		}
		port def IndexEntryOutPort {
			out item idxEntry : IndexEntry;
		}
		port def IndexEntryInPort {
			in item idxEntry : IndexEntry;
		}
		port def SnapshotOutPort {
			out item archSnapshot : ArchivedSnapshot;
		}
		port def SnapshotInPort {
			in item archSnapshot : ArchivedSnapshot;
		}
		port def QueryOutPort {
			out item query : UserQuery;
		}
		port def QueryInPort {
			in item query : UserQuery;
		}
		port def RecordIDOutPort {
			out item recordID : String;
		}
		port def RecordIDInPort {
			in item recordID : String;
		}
		port def ResponseOutPort {
			out item response : ArchivedPageResponse;
		}
		port def ResponseInPort {
			in item response : ArchivedPageResponse;
		}

		action def CrawlWebPage {
			out page : WebPageContent;
		}
		action def CompressAndStore {
			in page : WebPageContent;
			out idxEntry : IndexEntry;
		}
		action def UpdateIndex {
			in idxEntry : IndexEntry;
		}
		action def SearchIndex {
			in query : UserQuery;
			out recordID : String;
		}
		action def RetrieveSnapshot {
			in recordID : String;
			out archSnapshot : ArchivedSnapshot;
		}
		action def DecompressAndDeliver {
			in archSnapshot : ArchivedSnapshot;
			out response : ArchivedPageResponse;
		}

		state machine def ArchivingCycle {
			state Idle;
			state Crawling;
			state Storing;
			state Indexing;
			state Serving;
			transition from Idle to Crawling;
			transition from Crawling to Storing;
			transition from Storing to Indexing;
			transition from Indexing to Serving;
			transition from Serving to Idle;
		}

		part def WebCrawlerModule {
			doc
			/*
			 * Continuously crawls the web to capture new and updated content
			 * using thousands of active crawlers operating at a high rate.
			 */
			port pageOutPort : PageOutPort;
			attribute activeCrawlers : Integer = 10000;
			attribute crawlRate : Real = 1000 [1/s];
		}

		part def StorageModule {
			doc
			/*
			 * Compresses and stores time-stamped archival snapshots with
			 * petabyte-scale capacity and high redundancy to prevent data loss.
			 */
			port pageInPort : PageInPort;
			port indexEntryOutPort : IndexEntryOutPort;
			port recordIDInPort : RecordIDInPort;
			port snapshotOutPort : SnapshotOutPort;
			attribute capacityPB : Real = 100;
			attribute redundancyFactor : Integer = 3;
			attribute snapshotCount : Integer = 1000000000;
		}

		part def IndexingModule {
			doc
			/*
			 * Maintains a temporal index keyed by URL and capture date
			 * for fast lookup of archival record IDs.
			 */
			port indexEntryInPort : IndexEntryInPort;
			port queryInPort : QueryInPort;
			port recordIDOutPort : RecordIDOutPort;
			attribute indexSize : Integer = 1000000000;
			attribute lookupTime : Real = 0.05 [s];
		}

		part def UserInterfaceModule {
			doc
			/*
			 * Accepts user queries and coordinates retrieval and decompression
			 * to deliver historical web content with high concurrency and low latency.
			 */
			port queryInPort : QueryInPort;
			port queryOutPort : QueryOutPort;
			port recordIDInPort : RecordIDInPort;
			port recordIDOutPort : RecordIDOutPort;
			port snapshotInPort : SnapshotInPort;
			port responseOutPort : ResponseOutPort;
			attribute maxConcurrentUsers : Integer = 50000;
			attribute avgResponseTime : Real = 0.2 [s];
		}

		part def ArchiveUser {
			doc
			/*
			 * A user who queries the archive by URL and target date
			 * and receives the corresponding historical web content.
			 */
			port queryOutPort : QueryOutPort;
			port responseInPort : ResponseInPort;
		}

		part def WebArchivingSystem {
			doc
			/*
			 * A large-scale digital web archiving system that continuously
			 * captures, stores, indexes, and serves historical web content
			 * for long-term preservation and public access.
			 */
			part crawler : WebCrawlerModule;
			part storage : StorageModule;
			part indexer : IndexingModule;
			part ui : UserInterfaceModule;
			part user : ArchiveUser;
		}
	}

	package Requirements {
		requirement def ContinuousCrawlingReq {
			doc
			/*
			 * The Web Crawler Module shall continuously crawl the web
			 * to capture new and updated content at a high rate.
			 */
			attribute minActiveCrawlers : Integer = 10000;
			attribute minCrawlRate : Real = 1000 [1/s];
		}

		requirement def MassiveStorageReq {
			doc
			/*
			 * The Storage Module shall compress and store time-stamped
			 * snapshots with petabyte-scale capacity and high redundancy.
			 */
			attribute minCapacityPB : Real = 50;
			attribute minRedundancy : Integer = 3;
			attribute minSnapshotCount : Integer = 1000000000;
		}

		requirement def TemporalIndexingReq {
			doc
			/*
			 * The Indexing Module shall maintain a temporal index keyed
			 * by URL and capture date for fast record lookup.
			 */
			attribute maxLookupTime : Real = 0.1 [s];
		}

		requirement def HighConcurrencyReq {
			doc
			/*
			 * The User Interface Module shall handle tens of thousands
			 * of simultaneous requests with fast response time.
			 */
			attribute minConcurrentUsers : Integer = 10000;
			attribute maxResponseTime : Real = 0.5 [s];
		}

		requirement def LongTermPreservationReq {
			doc
			/*
			 * The system shall preserve web content for long-term access
			 * for research, education, and cultural heritage.
			 */
		}
	}

	package Usages {
		public import Definitions::*;
		public import Requirements::*;

		part webArchive : WebArchivingSystem {
			part crawler : WebCrawlerModule {
				perform action crawlWebPage : CrawlWebPage {
					out page = pageOutPort.page;
				}
			}

			flow of WebPageContent
				from crawler.pageOutPort.page to storage.pageInPort.page;

			part storage : StorageModule {
				perform action compressAndStore : CompressAndStore {
					in page = pageInPort.page;
					out idxEntry = indexEntryOutPort.idxEntry;
				}
				perform action retrieveSnapshot : RetrieveSnapshot {
					in recordID = recordIDInPort.recordID;
					out archSnapshot = snapshotOutPort.archSnapshot;
				}
			}

			flow of IndexEntry
				from storage.indexEntryOutPort.idxEntry to indexer.indexEntryInPort.idxEntry;

			part indexer : IndexingModule {
				perform action updateIndex : UpdateIndex {
					in idxEntry = indexEntryInPort.idxEntry;
				}
				perform action searchIndex : SearchIndex {
					in query = queryInPort.query;
					out recordID = recordIDOutPort.recordID;
				}
			}

			part ui : UserInterfaceModule {
				bind queryOutPort.query = queryInPort.query;
				bind recordIDOutPort.recordID = recordIDInPort.recordID;
				perform action decompressAndDeliver : DecompressAndDeliver {
					in archSnapshot = snapshotInPort.archSnapshot;
					out response = responseOutPort.response;
				}
			}

			flow of UserQuery
				from user.queryOutPort.query to ui.queryInPort.query;
			flow of UserQuery
				from ui.queryOutPort.query to indexer.queryInPort.query;
			flow of String
				from indexer.recordIDOutPort.recordID to ui.recordIDInPort.recordID;
			flow of String
				from ui.recordIDOutPort.recordID to storage.recordIDInPort.recordID;
			flow of ArchivedSnapshot
				from storage.snapshotOutPort.archSnapshot to ui.snapshotInPort.archSnapshot;
			flow of ArchivedPageResponse
				from ui.responseOutPort.response to user.responseInPort.response;

			state machine operationCycle : ArchivingCycle;

			satisfy ContinuousCrawlingReq by crawler;
			satisfy MassiveStorageReq by storage;
			satisfy TemporalIndexingReq by indexer;
			satisfy HighConcurrencyReq by ui;
			satisfy LongTermPreservationReq by this;
		}
	}
}
