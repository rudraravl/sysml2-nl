package BibcodeLookupSystem {

    import ScalarValues::*;
    import StringFunctions::*;

    // ------------------ Value Types ------------------
    value type BibcodeString :> String {
        doc /* 19-character astronomical bibliographic code */
        constraint { length(self) == 19 }
    }

    value type YearValue :> Integer {
        doc /* Publication year, e.g., 2024 */
        constraint { self >= 1800 and self <= 2100 }
    }

    value type CitationCount :> Integer {
        doc /* Number of citations received */
        constraint { self >= 0 }
    }

    value type DOIString :> String {
        doc /* Digital Object Identifier */
    }

    value type JournalCode :> String {
        doc /* Standardized journal abbreviation */
    }

    value type VolumeNumber :> String {
        doc /* Journal volume identifier */
    }

    value type PageOrQualifier :> String {
        doc /* Page identifier or article qualifier */
    }

    value type AuthorName :> String {
        doc /* Full author name */
    }

    value type TitleString :> String {
        doc /* Publication title */
    }

    value type AbstractText :> String {
        doc /* Abstract content */
    }

    attribute def PublicationRecord {
        attribute bibcode : BibcodeString;
        attribute title : TitleString;
        attribute authors : AuthorName[0..*]有序;
        attribute abstract : AbstractText;
        attribute journal : JournalCode;
        attribute volume : VolumeNumber;
        attribute year : YearValue;
        attribute page : PageOrQualifier;
        attribute doi : DOIString?;
        attribute citations : CitationCount;
    }

    attribute def QueryRequest {
        attribute bibcode : BibcodeString;
        attribute requestId : String;
    }

    attribute def QueryResponse {
        attribute requestId : String;
        attribute record : PublicationRecord?;
        attribute found : Boolean;
        attribute errorMessage : String?;
    }

    attribute def ValidationReport {
        attribute bibcode : BibcodeString;
        attribute valid : Boolean;
        attribute reason : String?;
        attribute parsedYear : YearValue?;
        attribute parsedJournal : JournalCode?;
        attribute parsedVolume : VolumeNumber?;
        attribute parsedPage : PageOrQualifier?;
    }

    attribute def CacheEntry {
        attribute record : PublicationRecord;
        attribute timestamp : String;
        attribute hitCount : Integer;
    }

    // ------------------ Item Flows ------------------
    item def LookupRequest {
        attribute bibcode : BibcodeString;
    }
    item def LookupResult {
        attribute record : PublicationRecord?;
        attribute success : Boolean;
    }
    item def ValidationRequest {
        attribute bibcode : BibcodeString;
    }
    item def ValidationResponse {
        attribute report : ValidationReport;
    }
    item def CacheQuery {
        attribute bibcode : BibcodeString;
    }
    item def CacheResult {
        attribute record : PublicationRecord?;
        attribute hit : Boolean;
    }
    item def RepositoryQuery {
        attribute bibcode : BibcodeString;
        attribute parsedYear : YearValue?;
        attribute parsedJournal : JournalCode?;
    }
    item def RepositoryResult {
        attribute record : PublicationRecord?;
        attribute found : Boolean;
    }
    item def StoreRecord {
        attribute record : PublicationRecord;
    }

    // ------------------ Ports ------------------
    port def UserInterfacePort {
        in item lookupRequests : LookupRequest;
        out item lookupResults : LookupResult;
    }

    port def ValidationPort {
        in item validationRequests : ValidationRequest;
        out item validationResponses : ValidationResponse;
    }

    port def CachePort {
        in item cacheQueries : CacheQuery;
        in item storeRecords : StoreRecord;
        out item cacheResults : CacheResult;
    }

    port def RepositoryPort {
        in item repositoryQueries : RepositoryQuery;
        out item repositoryResults : RepositoryResult;
    }

    // ------------------ Parts ------------------
    part def BibcodeValidator {
        port validationPort : ValidationPort;

        attribute def ValidationResult {
            attribute valid : Boolean;
            attribute reason : String?;
        }

        private attribute validationCount : Integer = 0;

        action def performValidation {
            in bibcode : BibcodeString;
            out report : ValidationReport;
        }

        perform performValidation {
            // Year positions 1-4, journal 7-9, volume 11-13, page/qualifier 15-19
            if (length(bibcode) != 19) {
                report.valid = false;
                report.reason = "Bibcode must be exactly 19 characters.";
            } else {
                // Simplified structural check using character classes
                if (substr(bibcode, 1, 4).matches("[0-9]{4}") and
                    substr(bibcode, 5, 2) == ".." and
                    substr(bibcode, 7, 3).matches("[A-Za-z0-9&.]{3}") and
                    substr(bibcode, 10, 1) == "." and
                    substr(bibcode, 11, 4).matches("[A-Za-z0-9.]{4}") and
                    substr(bibcode, 15, 1) == "." and
                    substr(bibcode, 16, 4).matches("[A-Za-z0-9.]{4}")) {
                    report.valid = true;
                    report.parsedYear = toInteger(substr(bibcode, 1, 4));
                    report.parsedJournal = substr(bibcode, 7, 3);
                    report.parsedVolume = substr(bibcode, 11, 4);
                    report.parsedPage = substr(bibcode, 16, 4);
                } else {
                    report.valid = false;
                    report.reason = "Bibcode does not match expected year/journal/volume/page structure.";
                }
            }
        }

        state validationStateMachine {
            entry; then idle;
            state idle;
            transition from idle to processing
                when validationPort.validationRequests.nonEmpty();
            state processing {
                entry {
                    validationCount = validationCount + 1;
                    performValidation(validationPort.validationRequests.front().bibcode) -> report;
                    validationPort.validationResponses.enqueue({report});
                    validationPort.validationRequests.dequeue();
                }
                then done;
            }
            state done;
            transition from done to idle;
        }
    }

    part def ResponseCache {
        port cachePort : CachePort;

        attribute maxEntries : Integer = 10000;
        attribute currentEntries : Integer = 0;
        attribute def CacheTable {
            attribute entries : CacheEntry[0..*];
        }
        private attribute cacheTable : CacheTable;

        action def cacheLookup {
            in bibcode : BibcodeString;
            out result : CacheResult;
        }

        perform cacheLookup {
            attribute foundEntry : CacheEntry?;
            for entry in cacheTable.entries {
                if (entry.record.bibcode == bibcode) {
                    foundEntry = entry;
                    entry.hitCount = entry.hitCount + 1;
                }
            }
            if (foundEntry != null) {
                result.record = foundEntry.record;
                result.hit = true;
            } else {
                result.record = null;
                result.hit = false;
            }
        }

        action def cacheStore {
            in record : PublicationRecord;
        }

        perform cacheStore {
            // Replace if exists, otherwise add
            attribute existing : Boolean = false;
            for entry in cacheTable.entries {
                if (entry.record.bibcode == record.bibcode) {
                    entry.record = record;
                    entry.timestamp = now();
                    existing = true;
                }
            }
            if (not existing) {
                if (currentEntries >= maxEntries) {
                    // Evict oldest entry (simplified LRU)
                    cacheTable.entries.removeAt(0);
                    currentEntries = currentEntries - 1;
                }
                cacheTable.entries.append({record, now(), 0});
                currentEntries = currentEntries + 1;
            }
        }

        state cacheStateMachine {
            entry; then idle;
            state idle;
            transition from idle to querying
                when cachePort.cacheQueries.nonEmpty();
            state querying {
                entry {
                    cacheLookup(cachePort.cacheQueries.front().bibcode) -> result;
                    cachePort.cacheResults.enqueue(result);
                    cachePort.cacheQueries.dequeue();
                }
                then checkStore;
            }
            state checkStore;
            transition from checkStore to storing
                when cachePort.storeRecords.nonEmpty();
            transition from checkStore to idle
                when not cachePort.storeRecords.nonEmpty();
            state storing {
                entry {
                    cacheStore(cachePort.storeRecords.front().record);
                    cachePort.storeRecords.dequeue();
                }
                then idle;
            }
        }
    }

    part def MetadataRepository {
        port repositoryPort : RepositoryPort;

        attribute def RepositoryEntry {
            attribute record : PublicationRecord;
        }
        private attribute records : RepositoryEntry[0..*];

        action def repositorySearch {
            in query : RepositoryQuery;
            out result : RepositoryResult;
        }

        perform repositorySearch {
            attribute foundRecord : PublicationRecord?;
            for entry in records {
                if (entry.record.bibcode == query.bibcode) {
                    foundRecord = entry.record;
                }
            }
            if (foundRecord != null) {
                result.record = foundRecord;
                result.found = true;
            } else {
                result.record = null;
                result.found = false;
            }
        }

        action def loadRecords {
            in recordsToLoad : PublicationRecord[0..*];
        }

        perform loadRecords {
            for r in recordsToLoad {
                records.append({r});
            }
        }

        state repositoryStateMachine {
            entry; then idle;
            state idle;
            transition from idle to searching
                when repositoryPort.repositoryQueries.nonEmpty();
            state searching {
                entry {
                    repositorySearch(repositoryPort.repositoryQueries.front()) -> result;
                    repositoryPort.repositoryResults.enqueue(result);
                    repositoryPort.repositoryQueries.dequeue();
                }
                then idle;
            }
        }
    }

    part def QueryCoordinator {
        port userPort : UserInterfacePort;
        port validationPort : ValidationPort;
        port cachePort : CachePort;
        port repositoryPort : RepositoryPort;

        attribute processedQueries : Integer = 0;
        attribute cacheHits : Integer = 0;
        attribute cacheMisses : Integer = 0;
        attribute validationFailures : Integer = 0;
        attribute repositoryMisses : Integer = 0;

        action def coordinateLookup {
            in request : LookupRequest;
            out result : LookupResult;
        }

        perform coordinateLookup {
            // Step 1: Validate
            validationPort.validationRequests.enqueue({request.bibcode});
            wait until validationPort.validationResponses.nonEmpty();
            attribute valResponse : ValidationResponse = validationPort.validationResponses.dequeue();

            if (not valResponse.report.valid) {
                result.record = null;
                result.success = false;
                validationFailures = validationFailures + 1;
                return;
            }

            // Step 2: Cache lookup
            cachePort.cacheQueries.enqueue({request.bibcode});
            wait until cachePort.cacheResults.nonEmpty();
            attribute cacheResp : CacheResult = cachePort.cacheResults.dequeue();

            if (cacheResp.hit) {
                result.record = cacheResp.record;
                result.success = true;
                cacheHits = cacheHits + 1;
                return;
            }

            cacheMisses = cacheMisses + 1;

            // Step 3: Repository lookup
            repositoryPort.repositoryQueries.enqueue({
                request.bibcode,
                valResponse.report.parsedYear,
                valResponse.report.parsedJournal
            });
            wait until repositoryPort.repositoryResults.nonEmpty();
            attribute repoResp : RepositoryResult = repositoryPort.repositoryResults.dequeue();

            if (not repoResp.found or repoResp.record == null) {
                result.record = null;
                result.success = false;
                repositoryMisses = repositoryMisses + 1;
                return;
            }

            // Step 4: Store in cache
            cachePort.storeRecords.enqueue({repoResp.record});

            result.record = repoResp.record;
            result.success = true;
            processedQueries = processedQueries + 1;
        }

        state coordinatorStateMachine {
            entry; then idle;
            state idle;
            transition from idle to validating
                when userPort.lookupRequests.nonEmpty();
            state validating {
                entry {
                    coordinateLookup(userPort.lookupRequests.front()) -> lookupResult;
                    userPort.lookupResults.enqueue(lookupResult);
                    userPort.lookupRequests.dequeue();
                }
                then idle;
            }
        }
    }

    // ------------------ Top-level System ------------------
    part def BibcodeLookupSystem {
        doc /*
            A system for retrieving detailed scholarly publication information
            using a standardized 19-character astronomical Bibcode.
        */

        port externalPort : UserInterfacePort;

        part coordinator : QueryCoordinator {
            port userPort : UserInterfacePort;
            port validationPort : ValidationPort;
            port cachePort : CachePort;
            port repositoryPort : RepositoryPort;
        }

        part validator : BibcodeValidator {
            port validationPort : ValidationPort;
        }

        part cache : ResponseCache {
            port cachePort : CachePort;
        }

        part repository : MetadataRepository {
            port repositoryPort : RepositoryPort;
        }

        // Connections
        connection externalPort to coordinator.userPort;

        connection coordinator.validationPort to validator.validationPort;
        connection validator.validationPort to coordinator.validationPort;

        connection coordinator.cachePort to cache.cachePort;
        connection cache.cachePort to coordinator.cachePort;

        connection coordinator.repositoryPort to repository.repositoryPort;
        connection repository.repositoryPort to coordinator.repositoryPort;
    }

    // ------------------ Requirements ------------------
    requirement def BibcodeLookupRequirements {
        doc /* Functional and non-functional requirements for the Bibcode lookup system. */

        requirement AcceptBibcodeInput {
            doc /* The system shall accept a 19-character Bibcode from the user. */
            subject : BibcodeLookupSystem;
            assume { externalPort.lookupRequests.bibcode->size() == 19 }
        }

        requirement ValidateBibcodeFormat {
            doc /*
                The system shall validate that the provided Bibcode conforms to the
                standardized 19-character format including year, journal, volume,
                and page components.
            */
            subject : BibcodeValidator;
            require { validationPort.validationResponses.report.valid == true }
        }

        requirement RejectInvalidBibcode {
            doc /*
                The system shall return a clear error message when the Bibcode
                does not conform to the expected format.
            */
            subject : QueryCoordinator;
            require { userPort.lookupResults.success == false }
            when { not validator.validationPort.validationResponses.report.valid }
        }

        requirement CheckCacheFirst {
            doc /*
                The system shall query the response cache before the metadata
                repository for any validated Bibcode lookup.
            */
            subject : QueryCoordinator;
            require { cache.cachePort.cacheQueries.nonEmpty() }
            before { repository.repositoryPort.repositoryQueries.nonEmpty() }
        }

        requirement ReturnCachedRecord {
            doc /*
                On a cache hit, the system shall return the cached publication
                record without querying the metadata repository.
            */
            subject : QueryCoordinator;
            assume { cache.cachePort.cacheResults.hit == true }
            require { userPort.lookupResults.record == cache.cachePort.cacheResults.record }
        }

        requirement QueryRepositoryOnMiss {
            doc /*
                On a cache miss, the system shall query the metadata repository
                for the complete publication record.
            */
            subject : QueryCoordinator;
            assume { cache.cachePort.cacheResults.hit == false }
            require { repository.repositoryPort.repositoryQueries.nonEmpty() }
        }

        requirement ReturnNotFoundError {
            doc /*
                If no matching record exists in the metadata repository, the
                system shall return a not-found indication to the user.
            */
            subject : QueryCoordinator;
            assume { repository.repositoryPort.repositoryResults.found == false }
            require { userPort.lookupResults.success == false }
        }

        requirement UpdateCacheAfterFetch {
            doc /*
                After retrieving a record from the metadata repository, the
                system shall store that record in the response cache for future
                lookups.
            */
            subject : QueryCoordinator;
            assume { repository.repositoryPort.repositoryResults.found == true }
            require { cache.cachePort.storeRecords.nonEmpty() }
        }

        requirement ReturnCompleteRecord {
            doc /*
                When a publication record is found, the returned record shall
                include the title, authors, abstract, journal information,
                and citation count.
            */
            subject : PublicationRecord;
            require {
                title != null and
                authors != null and
                abstract != null and
                journal != null and
                citations >= 0
            }
        }

        requirement ProvideIdleState {
            doc /* The system shall maintain an idle state while waiting for queries. */
            subject : QueryCoordinator;
            require { coordinatorStateMachine.idle.active }
            when { not externalPort.lookupRequests.nonEmpty() }
        }

        requirement ProcessConcurrently {
            doc /*
                The system shall process at most one lookup at a time to ensure
                consistency between cache and repository states.
            */
            subject : BibcodeLookupSystem;
            require { coordinator.coordinatorStateMachine.activeState <= 1 }
        }
    }

    // ------------------ Instance ------------------
    part bibcodeLookupSystem : BibcodeLookupSystem {
        satisfy BibcodeLookupRequirements;
    }
}
