package 'Preprint Repository' {
	private import ScalarValues::*;
	
	package Definitions {
		attribute def DataSize :> Real {
			doc /* Storage capacity measured in terabytes (TB) */
		}
		attribute def Count :> Integer;
		attribute def Score :> Real;
		attribute def PaperId :> Integer;
		attribute def Seconds :> Real;
		
		item def File {
			attribute fileName : String;
			attribute fileSize : DataSize;
			attribute checksum : String;
		}
		
		item def Manuscript {
			attribute paperId : PaperId;
			attribute title : String;
			attribute authors : String;
			attribute abstractText : String;
			attribute keywords : String;
			attribute category : String;
			attribute submittedDate : String;
			attribute pdfFile : File;
			attribute sourceFile : File;
		}
		
		item def SubmissionRequest {
			attribute manuscript : Manuscript;
		}
		
		item def SubmissionResponse {
			attribute paperId : PaperId;
			attribute status : String;
		}
		
		item def SearchQuery {
			attribute keywords : String;
			attribute authors : String;
			attribute dateRange : String;
		}
		
		item def SearchResultItem {
			attribute paperId : PaperId;
			attribute title : String;
			attribute authors : String;
			attribute relevanceScore : Score;
		}
		
		item def SearchResults {
			attribute resultList : String;
		}
		
		item def DownloadRequest {
			attribute paperId : PaperId;
			attribute requester : String;
		}
		
		item def DownloadResponse {
			attribute paperId : PaperId;
			attribute pdfFileName : String;
			attribute fileSize : DataSize;
		}
		
		item def ModerationReport {
			attribute paperId : PaperId;
			attribute plagiarismScore : Real;
			attribute formattingCompliant : Boolean;
			attribute approved : Boolean;
			attribute flagReason : String;
		}
		
		item def IndexEntry {
			attribute paperId : PaperId;
			attribute authors : String;
			attribute keywords : String;
			attribute category : String;
			attribute dateIndexed : String;
		}
		
		port def SubmissionPort {
			in submission : SubmissionRequest;
			out response : SubmissionResponse;
		}
		
		port def ManuscriptEmitPort {
			out item manuscript : Manuscript;
		}
		
		port def ManuscriptSinkPort {
			in item manuscript : Manuscript;
		}
		
		port def PaperRetrievePort {
			in paperId : PaperId;
			out item file : File;
		}
		
		port def IndexEmitPort {
			out item indexEntry : IndexEntry;
		}
		
		port def IndexSinkPort {
			in item indexEntry : IndexEntry;
		}
		
		port def SearchQueryPort {
			in query : SearchQuery;
			out results : SearchResults;
		}
		
		port def DownloadReqPort {
			in request : DownloadRequest;
			out response : DownloadResponse;
		}
		
		action def AutoScanSubmission {
			in manuscript : Manuscript;
			out report : ModerationReport;
		}
		
		action def ExtractMetadata {
			in manuscript : Manuscript;
			out indexEntry : IndexEntry;
		}
		
		action def ExecuteSearch {
			in query : SearchQuery;
			out results : SearchResults;
		}
		
		part def SubmissionProcessor {
			port submissionPort : SubmissionPort;
			port manuscriptOutPort : ManuscriptEmitPort;
			attribute nextId : PaperId = 1;
			attribute processedCount : Count = 0;
			
			exhibit state Processing {
				entry; then Idle;
				state Idle;
				transition handleSubmission
					first Idle
					accept req : SubmissionRequest via submissionPort.submission
					do action {
						first start;
						then send req.manuscript via manuscriptOutPort;
						then send new SubmissionResponse(nextId, "queued") via submissionPort;
					}
					then Idle;
			}
		}
		
		part def StorageSystem {
			port writePort : ManuscriptSinkPort;
			port readPort : PaperRetrievePort;
			port indexedNotifyPort : ManuscriptEmitPort;
			attribute capacity : DataSize = 500;
			attribute usedSpace : DataSize = 0;
			attribute compressionEnabled : Boolean = true;
			attribute redundancyCopies : Count = 3;
			attribute storedCount : Count = 0;
			attribute lastStoredManuscript : Manuscript;
			
			exhibit state StorageOp {
				entry; then Ready;
				state Ready;
				transition storePaper
					first Ready
					accept m : Manuscript via writePort.manuscript
					do action {
						first start;
						then send m via indexedNotifyPort;
					}
					then Ready;
				transition retrievePaper
					first Ready
					accept pid : PaperId via readPort.paperId
					do send lastStoredManuscript.pdfFile via readPort
					then Ready;
			}
		}
		
		part def IndexingService {
			port manuscriptInPort : ManuscriptSinkPort;
			port indexOutPort : IndexEmitPort;
			attribute indexedCount : Count = 0;
			attribute lastIndexEntry : IndexEntry;
			
			exhibit state Indexing {
				entry; then Waiting;
				state Waiting;
				transition processPaper
					first Waiting
					accept m : Manuscript via manuscriptInPort.manuscript
					do action {
						first start;
						then action extract : ExtractMetadata {
							in manuscript = m;
							out indexEntry = lastIndexEntry;
						}
						then send lastIndexEntry via indexOutPort;
					}
					then Waiting;
			}
		}
		
		part def SearchEngine {
			port searchPort : SearchQueryPort;
			port indexInPort : IndexSinkPort;
			port storageRetrievePort : ~PaperRetrievePort;
			attribute indexedEntries : Count = 0;
			attribute queryCount : Count = 0;
			attribute lastSearchResults : SearchResults;
			
			exhibit state Searching {
				entry; then Ready;
				state Ready;
				transition receiveIndex
					first Ready
					accept e : IndexEntry via indexInPort.indexEntry
					do action {
						first start;
					}
					then Ready;
				transition handleQuery
					first Ready
					accept q : SearchQuery via searchPort.query
					do action {
						first start;
						then action search : ExecuteSearch {
							in query = q;
							out results = lastSearchResults;
						}
						then send lastSearchResults via searchPort;
					}
					then Ready;
			}
		}
		
		part def DownloadService {
			port downloadPort : DownloadReqPort;
			port storagePort : ~PaperRetrievePort;
			attribute totalDownloads : Count = 0;
			attribute pendingPaperId : PaperId;
			attribute retrievedFile : File;
			
			exhibit state Serving {
				entry; then Idle;
				state Idle;
				transition receiveRequest
					first Idle
					accept req : DownloadRequest via downloadPort.request
					do action {
						first start;
						then send req.paperId via storagePort;
					}
					then WaitingForRetrieval;
				state WaitingForRetrieval;
				transition deliverPaper
					first WaitingForRetrieval
					accept f : File via storagePort
					do action {
						first start;
						then send new DownloadResponse(pendingPaperId, f.fileName, f.fileSize) via downloadPort;
					}
					then Idle;
			}
		}
		
		part def ModerationService {
			port manuscriptInPort : ManuscriptSinkPort;
			port approvedOutPort : ManuscriptEmitPort;
			port flaggedOutPort : ManuscriptEmitPort;
			attribute manualQueueSize : Count = 0;
			attribute approvedCount : Count = 0;
			attribute flaggedCount : Count = 0;
			attribute pendingManuscript : Manuscript;
			attribute scanResult : ModerationReport;
			
			exhibit state Moderation {
				entry; then Awaiting;
				state Awaiting;
				transition scanSubmission
					first Awaiting
					accept m : Manuscript via manuscriptInPort.manuscript
					do action {
						first start;
						then pendingManuscript = m;
						then action scan : AutoScanSubmission {
							in manuscript = m;
							out report = scanResult;
						}
					}
					then Deciding;
				state Deciding;
				transition approve
					first Deciding
					if scanResult.approved
					do action {
						first start;
						then send pendingManuscript via approvedOutPort;
					}
					then Approved;
				state Approved;
				transition returnFromApproved
					first Approved
					then Awaiting;
				transition flag
					first Deciding
					if scanResult.approved == false
					do action {
						first start;
						then send pendingManuscript via flaggedOutPort;
					}
					then Flagged;
				state Flagged;
				transition returnFromFlagged
					first Flagged
					then Awaiting;
			}
		}
		
		part def Author {
			port submissionPort : ~SubmissionPort;
		}
		
		part def Reader {
			port searchPort : ~SearchQueryPort;
			port downloadPort : ~DownloadReqPort;
		}
		
		part def HumanModerator {
			port flaggedInPort : ManuscriptSinkPort;
			port approvedOutPort : ManuscriptEmitPort;
			attribute reviewedCount : Count = 0;
			
			exhibit state Review {
				entry; then Waiting;
				state Waiting;
				transition review
					first Waiting
					accept m : Manuscript via flaggedInPort.manuscript
					do action {
						first start;
						then send m via approvedOutPort;
					}
					then Waiting;
			}
		}
	}
	
	package Configuration {
		private import Definitions::*;
		
		part def PreprintSystem {
			part author : Author;
			part submissionProcessor : SubmissionProcessor;
			part moderationService : ModerationService;
			part storageSystem : StorageSystem;
			part indexingService : IndexingService;
			part searchEngine : SearchEngine;
			part downloadService : DownloadService;
			part reader : Reader;
			part humanModerator : HumanModerator;
			
			interface authorToSubmission connect author.submissionPort to submissionProcessor.submissionPort {
				flow submissionFlow of SubmissionRequest
					from author.submissionPort.submission to submissionProcessor.submissionPort.submission;
				flow responseFlow of SubmissionResponse
					from submissionProcessor.submissionPort.response to author.submissionPort.response;
			}
			
			interface submissionToModeration connect submissionProcessor.manuscriptOutPort to moderationService.manuscriptInPort {
				flow manuscriptToModeration of Manuscript
					from submissionProcessor.manuscriptOutPort.manuscript to moderationService.manuscriptInPort.manuscript;
			}
			
			interface submissionToStorage connect submissionProcessor.manuscriptOutPort to storageSystem.writePort {
				flow manuscriptToStorage of Manuscript
					from submissionProcessor.manuscriptOutPort.manuscript to storageSystem.writePort.manuscript;
			}
			
			interface moderationToStorage connect moderationService.approvedOutPort to storageSystem.writePort {
				flow approvedManuscript of Manuscript
					from moderationService.approvedOutPort.manuscript to storageSystem.writePort.manuscript;
			}
			
			interface moderationToFlagged connect moderationService.flaggedOutPort to humanModerator.flaggedInPort {
				flow flaggedManuscript of Manuscript
					from moderationService.flaggedOutPort.manuscript to humanModerator.flaggedInPort.manuscript;
			}
			
			interface manualReviewToStorage connect humanModerator.approvedOutPort to storageSystem.writePort {
				flow manualReviewedManuscript of Manuscript
					from humanModerator.approvedOutPort.manuscript to storageSystem.writePort.manuscript;
			}
			
			interface storageToIndexing connect storageSystem.indexedNotifyPort to indexingService.manuscriptInPort {
				flow storedManuscript of Manuscript
					from storageSystem.indexedNotifyPort.manuscript to indexingService.manuscriptInPort.manuscript;
			}
			
			interface indexingToSearch connect indexingService.indexOutPort to searchEngine.indexInPort {
				flow indexFlow of IndexEntry
					from indexingService.indexOutPort.indexEntry to searchEngine.indexInPort.indexEntry;
			}
			
			interface searchToStorage connect searchEngine.storageRetrievePort to storageSystem.readPort {
				flow searchRetrievalFlow of PaperId
					from searchEngine.storageRetrievePort.paperId to storageSystem.readPort.paperId;
				flow searchFileReturnFlow of File
					from storageSystem.readPort.file to searchEngine.storageRetrievePort.file;
			}
			
			interface readerToSearch connect reader.searchPort to searchEngine.searchPort {
				flow searchQueryFlow of SearchQuery
					from reader.searchPort.query to searchEngine.searchPort.query;
				flow searchResultsFlow of SearchResults
					from searchEngine.searchPort.results to reader.searchPort.results;
			}
			
			interface readerToDownload connect reader.downloadPort to downloadService.downloadPort {
				flow downloadRequestFlow of DownloadRequest
					from reader.downloadPort.request to downloadService.downloadPort.request;
				flow downloadResponseFlow of DownloadResponse
					from downloadService.downloadPort.response to reader.downloadPort.response;
			}
			
			interface downloadToStorage connect downloadService.storagePort to storageSystem.readPort {
				flow retrievalFlow of PaperId
					from downloadService.storagePort.paperId to storageSystem.readPort.paperId;
				flow fileReturnFlow of File
					from storageSystem.readPort.file to downloadService.storagePort.file;
			}
		}
		
		part system : PreprintSystem;
	}
	
	package Requirements {
		private import Definitions::*;
		private import Configuration::*;
		
		requirement def ReliabilityRequirement {
			doc /* Storage must use triple redundancy for fault tolerance */
			attribute redundancyLevel : Count;
			constraint { redundancyLevel >= 3 }
		}
		
		requirement def CapacityRequirement {
			doc /* Storage must have at least 500 TB capacity */
			attribute minimumCapacity : DataSize;
			constraint { minimumCapacity >= 500 }
		}
		
		requirement def CompressionRequirement {
			doc /* Storage must use data compression */
			attribute compressionEnabled : Boolean;
			constraint { compressionEnabled == true }
		}
		
		requirement def ModerationRequirement {
			doc /* All submissions must undergo automated moderation */
			attribute mandatoryModeration : Boolean;
			constraint { mandatoryModeration == true }
		}
		
		requirement def SearchPerformanceRequirement {
			doc /* Search must respond within 2 seconds */
			attribute maxResponseSeconds : Seconds;
			constraint { maxResponseSeconds <= 2.0 }
		}
		
		requirement def UniqueIdRequirement {
			doc /* Each submission shall receive a unique paper ID */
			attribute idAssigned : Boolean;
			constraint { idAssigned == true }
		}
		
		requirement def DownloadTrackingRequirement {
			doc /* Download service shall track download counts */
			attribute trackingEnabled : Boolean;
			constraint { trackingEnabled == true }
		}
		
		requirement StorageReliability : ReliabilityRequirement {
			:>> redundancyLevel = 3;
		}
		
		requirement StorageCapacity : CapacityRequirement {
			:>> minimumCapacity = 500;
		}
		
		requirement StorageCompression : CompressionRequirement {
			:>> compressionEnabled = true;
		}
		
		requirement MandatoryModeration : ModerationRequirement {
			:>> mandatoryModeration = true;
		}
		
		requirement SearchPerformance : SearchPerformanceRequirement {
			:>> maxResponseSeconds = 2.0;
		}
		
		requirement UniquePaperId : UniqueIdRequirement {
			:>> idAssigned = true;
		}
		
		requirement DownloadTracking : DownloadTrackingRequirement {
			:>> trackingEnabled = true;
		}
		
		satisfy StorageReliability by Configuration::system.storageSystem;
		satisfy StorageCapacity by Configuration::system.storageSystem;
		satisfy StorageCompression by Configuration::system.storageSystem;
		satisfy MandatoryModeration by Configuration::system.moderationService;
		satisfy SearchPerformance by Configuration::system.searchEngine;
		satisfy UniquePaperId by Configuration::system.submissionProcessor;
		satisfy DownloadTracking by Configuration::system.downloadService;
	}
}
