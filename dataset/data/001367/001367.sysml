package BibcodeResolutionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def BibcodeIdentifier :> String {
        doc /* 19-character bibliographic code format: YYYYJJJJJVVVVMPPPPA
             YYYY = publication year (4 digits)
             JJJJJ = journal abbreviation (5 characters)
             VVVV = volume number (4 characters)
             M = section indicator (1 character)
             PPPP = page number (4 characters)
             A = first author surname initial (1 character) */
    }
    
    attribute def PublicationYear :> Integer;
    attribute def JournalAbbreviation :> String;
    attribute def VolumeNumber :> String;
    attribute def PageNumber :> String;
    attribute def AuthorInitial :> String;
    
    item def PublicationRecord {
        attribute bibcode : BibcodeIdentifier;
        attribute title : String;
        attribute authors : String[1..*];
        attribute publicationYear : PublicationYear;
        attribute journal : JournalAbbreviation;
        attribute volume : VolumeNumber;
        attribute page : PageNumber;
        attribute abstractText : String;
        attribute doi : String;
        attribute citationCount : Integer;
    }
    
    item def QueryRequest {
        attribute requestId : String;
        attribute bibcode : BibcodeIdentifier;
        attribute timestamp : Real;
    }
    
    item def QueryResult {
        attribute requestId : String;
        attribute record : PublicationRecord;
        attribute success : Boolean;
        attribute errorMessage : String;
        attribute timestamp : Real;
    }
    
    item def CacheEntry {
        attribute bibcode : BibcodeIdentifier;
        attribute record : PublicationRecord;
        attribute lastAccessed : Real;
        attribute accessCount : Integer;
    }
    
    port def QueryInterfacePort {
        in attribute request : QueryRequest;
        out attribute result : QueryResult;
    }
    
    port def DatabasePort {
        in attribute lookupKey : BibcodeIdentifier;
        out attribute recordData : PublicationRecord;
        out attribute found : Boolean;
    }
    
    port def CachePort {
        in attribute cacheKey : BibcodeIdentifier;
        out attribute cachedRecord : PublicationRecord;
        out attribute cacheHit : Boolean;
    }
    
    part def BibcodeValidator {
        in attribute inputBibcode : BibcodeIdentifier;
        out attribute isValid : Boolean;
        out attribute year : PublicationYear;
        out attribute journal : JournalAbbreviation;
        out attribute volume : VolumeNumber;
        out attribute page : PageNumber;
        out attribute author : AuthorInitial;
        
        action validate {
            in bibcodeString : BibcodeIdentifier;
            out valid : Boolean;
            out parsedYear : PublicationYear;
            out parsedJournal : JournalAbbreviation;
            out parsedVolume : VolumeNumber;
            out parsedPage : PageNumber;
            out parsedAuthor : AuthorInitial;
        }
    }
    
    part def MetadataRepository {
        port dbPort : DatabasePort;
        attribute storedRecords : PublicationRecord[*];
        
        action queryRecord {
            in bibcodeKey : BibcodeIdentifier;
            out retrievedRecord : PublicationRecord;
            out querySuccess : Boolean;
        }
        
        action indexRecord {
            in newRecord : PublicationRecord;
            out indexed : Boolean;
        }
    }
    
    part def ResponseCache {
        port cachePort : CachePort;
        attribute cacheEntries : CacheEntry[*];
        attribute maxCacheSize : Integer;
        attribute currentSize : Integer;
        
        action lookupCache {
            in key : BibcodeIdentifier;
            out entry : PublicationRecord;
            out hit : Boolean;
        }
        
        action storeCache {
            in key : BibcodeIdentifier;
            in record : PublicationRecord;
            out stored : Boolean;
        }
        
        action evictLRU {
            out evicted : Boolean;
        }
    }
    
    part def QueryCoordinator {
        port queryPort : QueryInterfacePort;
        
        part validator : BibcodeValidator;
        
        action coordinateQuery {
            in queryReq : QueryRequest;
            out queryRes : QueryResult;
            
            first start;
            then action validateInput {
                in requestBibcode = queryReq.bibcode;
                out validationResult : Boolean;
                out parsedComponents : PublicationYear;
            }
            then decide;
                if validateInput.validationResult then checkCache;
                if not validateInput.validationResult then returnValidationError;
            
            action checkCache {
                in bibcodeKey = queryReq.bibcode;
                out cacheRecord : PublicationRecord;
                out foundInCache : Boolean;
            }
            then decide;
                if checkCache.foundInCache then formatCachedResult;
                if not checkCache.foundInCache then queryRepository;
            
            action queryRepository {
                in lookupBibcode = queryReq.bibcode;
                out repositoryRecord : PublicationRecord;
                out foundInRepository : Boolean;
            }
            then decide;
                if queryRepository.foundInRepository then updateCache;
                if not queryRepository.foundInRepository then returnNotFoundError;
            
            action updateCache {
                in bibcodeToCache = queryReq.bibcode;
                in recordToCache = queryRepository.repositoryRecord;
                out cacheUpdated : Boolean;
            }
            then formatRepositoryResult;
            
            action formatCachedResult {
                in cachedData = checkCache.cacheRecord;
                out cachedResponse : QueryResult;
            }
            then done;
            
            action formatRepositoryResult {
                in repositoryData = queryRepository.repositoryRecord;
                out repositoryResponse : QueryResult;
            }
            then done;
            
            action returnValidationError {
                out validationErrorResponse : QueryResult;
            }
            then done;
            
            action returnNotFoundError {
                out notFoundErrorResponse : QueryResult;
            }
            then done;
        }
    }
    
    state def SystemOperationalState {
        entry; then idle;
        
        state idle {
            doc /* System awaiting query request */
        }
        
        state processing {
            doc /* System actively resolving Bibcode query */
        }
        
        state caching {
            doc /* System updating cache with retrieved data */
        }
        
        state error {
            doc /* System encountered error during resolution */
        }
        
        transition first idle then processing;
        transition first processing then caching;
        transition first caching then idle;
        transition first processing then error;
        transition first error then idle;
    }
    
    part bibcodeResolutionSystem {
        doc /* The Bibcode Resolution System provides automated retrieval of scholarly
             publication metadata using standardized bibliographic codes (Bibcodes).
             
             The system's primary function is to accept a 19-character Bibcode identifier,
             validate its format and structure, resolve it to the corresponding publication
             record in a comprehensive metadata repository, and return complete bibliographic
             information including title, authors, journal details, abstract, and citation metrics.
             
             The system operates through an optimized query-response workflow with intelligent
             caching. When a query is received, the Bibcode is first validated against the
             standard format specification. Valid Bibcodes are checked against a local cache
             of recently accessed records. Cache misses trigger a lookup in the main metadata
             repository. Successfully retrieved records are cached for future requests and
             returned to the requester with full publication details. Invalid Bibcodes or
             missing records generate appropriate error responses.
             
             This architecture enables efficient, reliable access to astronomical and
             astrophysical literature metadata for research, citation management, and
             bibliometric analysis applications. */
        
        port externalInterface : QueryInterfacePort;
        
        part coordinator : QueryCoordinator;
        part repository : MetadataRepository;
        part cache : ResponseCache;
        
        state operationalState : SystemOperationalState;
        
        connection coordinatorToExternal connect externalInterface to coordinator.queryPort;
        connection coordinatorToRepository connect coordinator to repository;
        connection coordinatorToCache connect coordinator to cache;
        
        perform action resolveBibcodeQuery {
            in incomingRequest : QueryRequest;
            out outgoingResult : QueryResult;
            
            first start;
            then action validateBibcode {
                in bibcodeToValidate = incomingRequest.bibcode;
                out validBibcode : Boolean;
            }
            then decide;
                if validateBibcode.validBibcode then searchCache;
                if not validateBibcode.validBibcode then failValidation;
            
            action searchCache {
                in searchKey = incomingRequest.bibcode;
                out cacheData : PublicationRecord;
                out cacheSuccess : Boolean;
            }
            then decide;
                if searchCache.cacheSuccess then returnCached;
                if not searchCache.cacheSuccess then searchRepository;
            
            action searchRepository {
                in repositoryKey = incomingRequest.bibcode;
                out repositoryData : PublicationRecord;
                out repositorySuccess : Boolean;
            }
            then decide;
                if searchRepository.repositorySuccess then cacheAndReturn;
                if not searchRepository.repositorySuccess then failNotFound;
            
            action cacheAndReturn {
                in dataToCache = searchRepository.repositoryData;
                out finalResult : QueryResult;
            }
            then done;
            
            action returnCached {
                in cachedData = searchCache.cacheData;
                out cachedResult : QueryResult;
            }
            then done;
            
            action failValidation {
                out validationFailure : QueryResult;
            }
            then done;
            
            action failNotFound {
                out notFoundFailure : QueryResult;
            }
            then done;
        }
    }
    
    requirement <'REQ-BIB-001'> bibcodeFormatCompliance {
        doc /* The system shall accept and validate Bibcode identifiers conforming to
             the 19-character standard format YYYYJJJJJVVVVMPPPPA. */
        
        subject validatorComponent : bibcodeResolutionSystem.coordinator.validator;
    }
    
    requirement <'REQ-BIB-002'> metadataCompleteness {
        doc /* The system shall retrieve and return complete publication metadata including
             title, author list, journal information, volume, page, abstract, DOI, and
             citation count for all valid Bibcodes in the repository. */
        
        subject repositoryComponent : bibcodeResolutionSystem.repository;
    }
    
    requirement <'REQ-BIB-003'> cacheEfficiency {
        doc /* The system shall maintain a cache of recently queried records to minimize
             repository access latency and improve response time for repeated queries. */
        
        subject cacheComponent : bibcodeResolutionSystem.cache;
    }
    
    requirement <'REQ-BIB-004'> errorHandling {
        doc /* The system shall validate Bibcode format before repository queries and
             return descriptive error responses for invalid inputs or missing records. */
        
        subject coordinatorComponent : bibcodeResolutionSystem.coordinator;
    }
    
    requirement <'REQ-BIB-005'> queryResponseIntegrity {
        doc /* The system shall ensure that each query response includes the original
             request identifier, success status, and either complete publication data
             or a specific error message. */
        
        subject systemInterface : bibcodeResolutionSystem.externalInterface;
    }
    
    requirement bibcodeSystemMission {
        doc /* The Bibcode Resolution System shall provide reliable, efficient, and
             accurate access to scholarly publication metadata through standardized
             Bibcode identifier lookup, supporting research and bibliometric applications. */
        
        assume constraint repositoryAvailability {
            doc /* The metadata repository is accessible and contains indexed publication records. */
        }
        
        assume constraint bibcodeUniqueness {
            doc /* Each Bibcode uniquely identifies a single publication record. */
        }
        
        require bibcodeFormatCompliance;
        require metadataCompleteness;
        require cacheEfficiency;
        require errorHandling;
        require queryResponseIntegrity;
    }
}
