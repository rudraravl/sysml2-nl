package 'ArXiv Preprint Repository System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PaperID;
    attribute def AuthorName;
    attribute def PaperTitle;
    attribute def AbstractText;
    attribute def CategoryCode;
    attribute def SubmissionTimestamp;
    attribute def ReviewStatus;
    attribute def DownloadCount;
    attribute def CitationCount;
    
    attribute def StorageCapacity {
        attribute capacity : Real;
        attribute unit : String default "TB";
    }
    
    attribute def ProcessingRate {
        attribute rate : Real;
        attribute unit : String default "Hz";
    }
    
    attribute def LatencyTime {
        attribute duration : Real;
        attribute unit : String default "s";
    }
    
    item def Manuscript {
        attribute paperID : PaperID;
        attribute title : PaperTitle;
        attribute authors : AuthorName[1..*];
        attribute abstractText : AbstractText;
        attribute categories : CategoryCode[1..*];
        attribute submissionDate : SubmissionTimestamp;
        attribute pdfFile : String;
        attribute sourceFiles : String[0..*];
        attribute version : Integer;
    }
    
    item def Submission {
        attribute manuscript : Manuscript;
        attribute status : ReviewStatus;
        attribute timestamp : SubmissionTimestamp;
        attribute submitterEmail : String;
    }
    
    item def SearchQuery {
        attribute keywords : String[1..*];
        attribute categories : CategoryCode[0..*];
        attribute authors : AuthorName[0..*];
        attribute dateRangeStart : SubmissionTimestamp[0..1];
        attribute dateRangeEnd : SubmissionTimestamp[0..1];
    }
    
    item def SearchResult {
        attribute matchedPapers : Manuscript[*];
        attribute relevanceScores : Real[*];
        attribute totalMatches : Integer;
        attribute queryTime : LatencyTime;
    }
    
    item def DownloadRequest {
        attribute paperID : PaperID;
        attribute requestTimestamp : SubmissionTimestamp;
        attribute userID : String;
    }
    
    port def SubmissionPort {
        in item submissionRequest : Submission;
        out item submissionConfirmation : PaperID;
    }
    
    port def SearchPort {
        in item query : SearchQuery;
        out item results : SearchResult;
    }
    
    port def DownloadPort {
        in item downloadRequest : DownloadRequest;
        out item paper : Manuscript;
    }
    
    port def StoragePort {
        in item storeRequest : Manuscript;
        out item storageConfirmation : Boolean;
        in item retrieveRequest : PaperID;
        out item retrievedPaper : Manuscript;
    }
    
    port def IndexPort {
        in item indexRequest : Manuscript;
        out item indexConfirmation : Boolean;
    }
    
    part def SubmissionProcessor {
        port submissionInterface : SubmissionPort;
        port storageInterface : ~StoragePort;
        port indexInterface : ~IndexPort;
        
        attribute processingRate : ProcessingRate;
        attribute maxConcurrentSubmissions : Integer;
        
        perform action processSubmission {
            in submission : Submission;
            out paperID : PaperID;
            
            first start;
            then action validateSubmission {
                in sub : Submission = submission;
                out valid : Boolean;
                out validationErrors : String[*];
            }
            then decide;
                if validateSubmission.valid then acceptSubmission;
                if not validateSubmission.valid then rejectSubmission;
            action acceptSubmission {
                action assignID {
                    out id : PaperID;
                }
                then action storeManuscript {
                    in manuscript : Manuscript = submission.manuscript;
                    in id : PaperID = assignID.id;
                    out stored : Boolean;
                }
                then action indexManuscript {
                    in manuscript : Manuscript = submission.manuscript;
                    in id : PaperID = assignID.id;
                    out indexed : Boolean;
                }
                then action notifyAuthor {
                    in id : PaperID = assignID.id;
                    out confirmation : PaperID = id;
                }
            }
            then assign paperID := acceptSubmission.notifyAuthor.confirmation;
            then done;
            action rejectSubmission {
                action sendRejectionNotice {
                    in errors : String[*] = validateSubmission.validationErrors;
                }
            }
            then done;
        }
    }
    
    part def SearchEngine {
        port searchInterface : SearchPort;
        port storageInterface : ~StoragePort;
        
        attribute indexSize : Integer;
        attribute queryProcessingRate : ProcessingRate;
        attribute maxResultsPerQuery : Integer;
        
        perform action executeSearch {
            in query : SearchQuery;
            out results : SearchResult;
            
            first start;
            then action parseQuery {
                in q : SearchQuery = query;
                out parsedTerms : String[*];
                out categoryFilters : CategoryCode[*];
                out authorFilters : AuthorName[*];
            }
            then action searchIndex {
                in terms : String[*] = parseQuery.parsedTerms;
                in categories : CategoryCode[*] = parseQuery.categoryFilters;
                in authors : AuthorName[*] = parseQuery.authorFilters;
                out matchedIDs : PaperID[*];
            }
            then action retrieveManuscripts {
                in ids : PaperID[*] = searchIndex.matchedIDs;
                out papers : Manuscript[*];
            }
            then action rankResults {
                in papers : Manuscript[*] = retrieveManuscripts.papers;
                in originalQuery : SearchQuery = query;
                out rankedResults : SearchResult;
            }
            then assign results := rankResults.rankedResults;
            then done;
        }
    }
    
    part def StorageSystem {
        port storageInterface : StoragePort;
        
        attribute capacity : StorageCapacity;
        attribute currentUsage : StorageCapacity;
        attribute redundancyLevel : Integer;
        attribute compressionEnabled : Boolean;
        
        private attribute storedPapers : Manuscript[*] := ();
        
        perform action managePapers {
            loop {
                accept storageRequest;
                then action handleRequest {
                    action storePaper {
                        in paper : Manuscript;
                        
                        action checkCapacity {
                            in current : StorageCapacity = currentUsage;
                            in total : StorageCapacity = capacity;
                            out available : Boolean;
                        }
                        then decide;
                            if checkCapacity.available then writeToStorage;
                            if not checkCapacity.available then expandStorage;
                        action writeToStorage {
                            action writePrimary {
                                in manuscript : Manuscript = paper;
                            }
                            then action writeBackup {
                                in manuscript : Manuscript = paper;
                                in level : Integer = redundancyLevel;
                            }
                            then action updateMetadata {
                                in manuscript : Manuscript = paper;
                            }
                        }
                        then done;
                        action expandStorage {
                            action allocateAdditionalStorage;
                            then writeToStorage;
                        }
                    }
                }
            }
        }
    }
    
    part def DownloadService {
        port downloadInterface : DownloadPort;
        port storageInterface : ~StoragePort;
        
        attribute downloadCount : DownloadCount;
        attribute bandwidthLimit : Real;
        attribute concurrentDownloads : Integer;
        
        perform action serveDownload {
            in request : DownloadRequest;
            out paper : Manuscript;
            
            first start;
            then action authenticateRequest {
                in req : DownloadRequest = request;
                out authorized : Boolean;
            }
            then decide;
                if authenticateRequest.authorized then retrievePaper;
                if not authenticateRequest.authorized then denyAccess;
            action retrievePaper {
                action fetchFromStorage {
                    in id : PaperID = request.paperID;
                    out manuscript : Manuscript;
                }
                then action incrementCounter {
                    in id : PaperID = request.paperID;
                }
                then action logDownload {
                    in req : DownloadRequest = request;
                }
                then action deliverPaper {
                    in manuscript : Manuscript = fetchFromStorage.manuscript;
                    out deliveredPaper : Manuscript = manuscript;
                }
            }
            then assign paper := retrievePaper.deliverPaper.deliveredPaper;
            then done;
            action denyAccess {
                action logUnauthorizedAttempt {
                    in req : DownloadRequest = request;
                }
            }
            then done;
        }
    }
    
    part def ModerationService {
        attribute reviewQueue : Submission[*];
        attribute moderators : AuthorName[*];
        attribute autoApprovalThreshold : Real;
        
        perform action moderateSubmissions {
            loop {
                accept submissionEvent;
                then action reviewContent {
                    in submission : Submission;
                    
                    action checkPlagiarism {
                        in manuscript : Manuscript = submission.manuscript;
                        out plagiarismScore : Real;
                    }
                    then action checkQuality {
                        in manuscript : Manuscript = submission.manuscript;
                        out qualityScore : Real;
                    }
                    then action checkCompliance {
                        in manuscript : Manuscript = submission.manuscript;
                        out compliant : Boolean;
                    }
                    then decide;
                        if checkCompliance.compliant and 
                           checkPlagiarism.plagiarismScore < 0.2 and 
                           checkQuality.qualityScore > 0.7 
                        then approveSubmission;
                        else flagForReview;
                    action approveSubmission {
                        action updateStatus {
                            in sub : Submission = submission;
                        }
                        then action notifyApproval {
                            in sub : Submission = submission;
                        }
                    }
                    action flagForReview {
                        action assignToModerator {
                            in sub : Submission = submission;
                        }
                        then action addToQueue {
                            in sub : Submission = submission;
                        }
                    }
                }
            }
        }
    }
    
    part def IndexingService {
        port indexInterface : IndexPort;
        
        attribute indexUpdateRate : ProcessingRate;
        attribute totalIndexedPapers : Integer;
        
        perform action indexPaper {
            in manuscript : Manuscript;
            out indexed : Boolean;
            
            first start;
            then action extractKeywords {
                in paper : Manuscript = manuscript;
                out keywords : String[*];
            }
            then action extractCategories {
                in paper : Manuscript = manuscript;
                out categories : CategoryCode[*];
            }
            then action extractAuthors {
                in paper : Manuscript = manuscript;
                out authors : AuthorName[*];
            }
            then action updateIndex {
                in keywords : String[*] = extractKeywords.keywords;
                in categories : CategoryCode[*] = extractCategories.categories;
                in authors : AuthorName[*] = extractAuthors.authors;
                in paper : Manuscript = manuscript;
                out success : Boolean;
            }
            then assign indexed := updateIndex.success;
            then done;
        }
    }
    
    part def ArxivRepositorySystem {
        doc /* 
            The ArXiv preprint repository system provides a comprehensive platform for researchers 
            to submit, store, search, and download scientific preprints across multiple disciplines. 
            
            The system's primary function is to facilitate rapid dissemination of research findings 
            by accepting manuscript submissions from authors worldwide, organizing them into 
            categorized collections, enabling efficient search and retrieval through a powerful 
            indexing engine, and serving papers to users with high availability while maintaining 
            data integrity, redundancy, and quality through automated moderation processes.
        */
        
        part submissionProcessor : SubmissionProcessor {
            perform processSubmission;
            attribute :>> processingRate = ProcessingRate { rate = 100.0; unit = "Hz"; }
            attribute :>> maxConcurrentSubmissions = 50;
        }
        
        part searchEngine : SearchEngine {
            perform executeSearch;
            attribute :>> queryProcessingRate = ProcessingRate { rate = 1000.0; unit = "Hz"; }
            attribute :>> maxResultsPerQuery = 100;
        }
        
        part storageSystem : StorageSystem {
            perform managePapers;
            attribute :>> capacity = StorageCapacity { capacity = 500.0; unit = "TB"; }
            attribute :>> currentUsage = StorageCapacity { capacity = 250.0; unit = "TB"; }
            attribute :>> redundancyLevel = 3;
            attribute :>> compressionEnabled = true;
        }
        
        part downloadService : DownloadService {
            perform serveDownload;
            attribute :>> bandwidthLimit = 10000.0;
            attribute :>> concurrentDownloads = 1000;
        }
        
        part moderationService : ModerationService {
            perform moderateSubmissions;
            attribute :>> autoApprovalThreshold = 0.8;
        }
        
        part indexingService : IndexingService {
            perform indexPaper;
            attribute :>> indexUpdateRate = ProcessingRate { rate = 50.0; unit = "Hz"; }
        }
        
        connection submissionToStorage 
            connect submissionProcessor.storageInterface to storageSystem.storageInterface;
        
        connection submissionToIndex 
            connect submissionProcessor.indexInterface to indexingService.indexInterface;
        
        connection searchToStorage 
            connect searchEngine.storageInterface to storageSystem.storageInterface;
        
        connection downloadToStorage 
            connect downloadService.storageInterface to storageSystem.storageInterface;
    }
    
    part arxivSystem : ArxivRepositorySystem;
    
    requirement <'REQ-001'> acceptSubmissions {
        doc /* The system shall accept manuscript submissions from authors 
               and assign unique identifiers within 24 hours. */
        
        subject system : ArxivRepositorySystem;
        
        require constraint {
            system.submissionProcessor.processingRate.rate >= 100.0
        }
    }
    
    requirement <'REQ-002'> provideSearch {
        doc /* The system shall enable users to search the repository using 
               keywords, categories, authors, and date ranges with sub-second response time. */
        
        subject system : ArxivRepositorySystem;
        
        require constraint {
            system.searchEngine.queryProcessingRate.rate >= 1000.0
        }
    }
    
    requirement <'REQ-003'> ensureAvailability {
        doc /* The system shall maintain 99.9% uptime and provide redundant 
               storage for all manuscripts with at least triple redundancy. */
        
        subject system : ArxivRepositorySystem;
        
        require constraint {
            system.storageSystem.redundancyLevel >= 3
        }
    }
    
    requirement <'REQ-004'> enableDownloads {
        doc /* The system shall serve manuscript downloads to users with 
               minimal latency and track download statistics for analytics. */
        
        subject system : ArxivRepositorySystem;
        
        require constraint {
            system.downloadService.concurrentDownloads >= 1000
        }
    }
    
    requirement <'REQ-005'> moderateContent {
        doc /* The system shall review submissions for quality, plagiarism, 
               and compliance with repository policies before publication. */
        
        subject system : ArxivRepositorySystem;
    }
    
    requirement <'REQ-006'> maintainIndex {
        doc /* The system shall maintain a searchable index of all manuscripts 
               updated in near real-time as new papers are submitted. */
        
        subject system : ArxivRepositorySystem;
        
        require constraint {
            system.indexingService.indexUpdateRate.rate >= 50.0
        }
    }
    
    requirement systemMission {
        doc /* The ArXiv system shall facilitate open access to scientific 
               research by providing a reliable, searchable, and highly available 
               repository of preprint manuscripts across all scientific disciplines. */
        
        subject system : ArxivRepositorySystem;
        
        assume constraint {
            system.storageSystem.capacity.capacity > 0.0
        }
        
        require acceptSubmissions;
        require provideSearch;
        require ensureAvailability;
        require enableDownloads;
        require moderateContent;
        require maintainIndex;
    }
}
