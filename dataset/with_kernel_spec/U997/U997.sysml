package BibcodeLookupSystem {
    private import ScalarValues::String;
    private import ScalarValues::Boolean;
    private import ScalarValues::Integer;

    item def Bibcode {
        attribute code : String;
    }

    item def PublicationRecord {
        attribute bibcode : String;
        attribute title : String;
        attribute authors : String;
        attribute abstractText : String;
        attribute journal : String;
        attribute volume : String;
        attribute page : String;
        attribute year : Integer;
        attribute citationCount : Integer;
    }

    item def QueryRequest {
        ref bibcode : Bibcode;
    }

    item def QueryResponse {
        attribute success : Boolean;
        ref record : PublicationRecord[0..1];
        attribute errorDetail : String;
    }

    item def ValidationResult {
        attribute valid : Boolean;
        attribute detail : String;
    }

    item def CacheResult {
        attribute hit : Boolean;
        ref record : PublicationRecord[0..1];
    }

    item def RepositoryResult {
        attribute found : Boolean;
        ref record : PublicationRecord[0..1];
    }

    port def QueryPort {
        in ref request : QueryRequest;
        out ref response : QueryResponse;
    }

    port def ValidatorPort {
        in ref bibcode : Bibcode;
        out ref result : ValidationResult;
    }

    port def CacheLookupPort {
        in ref bibcode : Bibcode;
        out ref result : CacheResult;
    }

    port def CacheStorePort {
        in ref record : PublicationRecord;
        out ref stored : Boolean;
    }

    port def RepositoryPort {
        in ref bibcode : Bibcode;
        out ref result : RepositoryResult;
    }

    interface def QueryInterface {
        end source : ~QueryPort;
        end target : QueryPort;
    }

    interface def ValidatorInterface {
        end source : ~ValidatorPort;
        end target : ValidatorPort;
    }

    interface def CacheLookupInterface {
        end source : ~CacheLookupPort;
        end target : CacheLookupPort;
    }

    interface def CacheStoreInterface {
        end source : ~CacheStorePort;
        end target : CacheStorePort;
    }

    interface def RepositoryInterface {
        end source : ~RepositoryPort;
        end target : RepositoryPort;
    }

    part def User {
        port queryPort : ~QueryPort {
            out ref :>> request;
            in ref :>> response;
        }
        perform action userBehavior {
            action sendQuery {
                out ref request : QueryRequest;
            }
            action receiveResponse {
                in ref response : QueryResponse;
            }
        }
        flow queryOut from userBehavior.sendQuery.request to queryPort.request;
        flow responseIn from queryPort.response to userBehavior.receiveResponse.response;
    }

    part def BibcodeValidator {
        port validatorPort : ValidatorPort {
            in ref :>> bibcode;
            out ref :>> result;
        }
        perform action validateBehavior {
            action validate {
                in ref bibcode : Bibcode;
                out ref result : ValidationResult;
            }
        }
        flow bibcodeIn from validatorPort.bibcode to validateBehavior.validate.bibcode;
        flow resultOut from validateBehavior.validate.result to validatorPort.result;
    }

    part def ResponseCache {
        port lookupPort : CacheLookupPort {
            in ref :>> bibcode;
            out ref :>> result;
        }
        port storePort : CacheStorePort {
            in ref :>> record;
            out ref :>> stored;
        }
        perform action cacheBehavior {
            action lookup {
                in ref bibcode : Bibcode;
                out ref result : CacheResult;
            }
            action store {
                in ref record : PublicationRecord;
                out ref stored : Boolean;
            }
        }
        flow lookupBibcode from lookupPort.bibcode to cacheBehavior.lookup.bibcode;
        flow lookupResult from cacheBehavior.lookup.result to lookupPort.result;
        flow storeRecord from storePort.record to cacheBehavior.store.record;
        flow storeResult from cacheBehavior.store.stored to storePort.stored;
    }

    part def MetadataRepository {
        port repositoryPort : RepositoryPort {
            in ref :>> bibcode;
            out ref :>> result;
        }
        perform action repositoryBehavior {
            action fetch {
                in ref bibcode : Bibcode;
                out ref result : RepositoryResult;
            }
        }
        flow fetchBibcode from repositoryPort.bibcode to repositoryBehavior.fetch.bibcode;
        flow fetchResult from repositoryBehavior.fetch.result to repositoryPort.result;
    }

    part def QueryCoordinator {
        port queryPort : QueryPort {
            in ref :>> request;
            out ref :>> response;
        }
        port validatorPort : ~ValidatorPort {
            out ref :>> bibcode;
            in ref :>> result;
        }
        port cacheLookupPort : ~CacheLookupPort {
            out ref :>> bibcode;
            in ref :>> result;
        }
        port cacheStorePort : ~CacheStorePort {
            out ref :>> record;
            in ref :>> stored;
        }
        port repositoryPort : ~RepositoryPort {
            out ref :>> bibcode;
            in ref :>> result;
        }

        state coordinatorState {
            entry; then idle;
            state idle;
            accept request : QueryRequest via queryPort
                then validating;
            state validating;
            accept result : ValidationResult via validatorPort
                then checkingCache;
            state checkingCache;
            accept result : CacheResult via cacheLookupPort
                then queryingRepository;
            state queryingRepository;
            accept result : RepositoryResult via repositoryPort
                then updatingCache;
            state updatingCache;
            accept stored : Boolean via cacheStorePort
                then idle;
        }

        flow bibcodeToValidator from queryPort.request.bibcode to validatorPort.bibcode;
        flow bibcodeToCache from queryPort.request.bibcode to cacheLookupPort.bibcode;
        flow bibcodeToRepo from queryPort.request.bibcode to repositoryPort.bibcode;
        flow recordToStore from repositoryPort.result.record to cacheStorePort.record;
    }

    part def BibcodeSystem {
        part user : User;
        part coordinator : QueryCoordinator;
        part validator : BibcodeValidator;
        part cache : ResponseCache;
        part repository : MetadataRepository;

        interface queryInterface : QueryInterface connect user.queryPort to coordinator.queryPort {
            flow requestFlow from user.queryPort.request to coordinator.queryPort.request;
            flow responseFlow from coordinator.queryPort.response to user.queryPort.response;
        }

        interface validatorInterface : ValidatorInterface connect coordinator.validatorPort to validator.validatorPort {
            flow bibcodeFlow from coordinator.validatorPort.bibcode to validator.validatorPort.bibcode;
            flow resultFlow from validator.validatorPort.result to coordinator.validatorPort.result;
        }

        interface cacheLookupInterface : CacheLookupInterface connect coordinator.cacheLookupPort to cache.lookupPort {
            flow bibcodeFlow from coordinator.cacheLookupPort.bibcode to cache.lookupPort.bibcode;
            flow resultFlow from cache.lookupPort.result to coordinator.cacheLookupPort.result;
        }

        interface cacheStoreInterface : CacheStoreInterface connect coordinator.cacheStorePort to cache.storePort {
            flow recordFlow from coordinator.cacheStorePort.record to cache.storePort.record;
            flow storedFlow from cache.storePort.stored to coordinator.cacheStorePort.stored;
        }

        interface repositoryInterface : RepositoryInterface connect coordinator.repositoryPort to repository.repositoryPort {
            flow bibcodeFlow from coordinator.repositoryPort.bibcode to repository.repositoryPort.bibcode;
            flow resultFlow from repository.repositoryPort.result to coordinator.repositoryPort.result;
        }
    }

    requirement def BibcodeFormatRequirement {
        doc /* The system shall validate that every query contains a 19-character Bibcode conforming to the standardized bibliographic format. */
    }

    requirement def CacheHitRequirement {
        doc /* The system shall return the publication record from the response cache without querying the metadata repository when a cache hit occurs. */
    }

    requirement def CacheMissRequirement {
        doc /* The system shall query the metadata repository on a cache miss and update the response cache with the returned record before returning the result. */
    }

    requirement def ErrorHandlingRequirement {
        doc /* The system shall provide clear error messages if a Bibcode is invalid or if a corresponding publication record cannot be found in the repository. */
    }

    requirement def CompleteRecordRequirement {
        doc /* The system shall return a complete publication record including title, authors, abstract, journal, volume, page, and citation count for valid Bibcodes. */
    }

    requirement bibcodeFormatRequirement : BibcodeFormatRequirement;
    requirement cacheHitRequirement : CacheHitRequirement;
    requirement cacheMissRequirement : CacheMissRequirement;
    requirement errorHandlingRequirement : ErrorHandlingRequirement;
    requirement completeRecordRequirement : CompleteRecordRequirement;
}
