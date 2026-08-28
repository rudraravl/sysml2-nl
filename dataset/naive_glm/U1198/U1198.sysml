package CitationManagementSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value type S2CID > Integer {
        doc /* Semantic Scholar Corpus ID */
        constraint { self > 0 }
    }

    value type DOI specializes String {
        doc /* Digital Object Identifier */
    }

    value type Title specializes String;
    value type AbstractText specializes String;
    value type AuthorName specializes String;

    value type PublicationYear > Integer {
        constraint { self >= 1900 and self <= 2100 }
    }

    value type CitationCount > Integer {
        constraint { self >= 0 }
    }

    value type InfluenceScore > Real {
        doc /* Normalized academic influence score */
        constraint { self >= 0.0 }
    }

    value type ConfidenceScore > Real {
        constraint { self >= 0.0 and self <= 1.0 }
    }

    value type ResponseTime > Real {
        :> ISQ::TimeValue;
        unit s;
    }

    value type CacheHitRate > Real {
        constraint { self >= 0.0 and self <= 1.0 }
    }

    // ===== Item Types =====

    item def Author {
        attribute name : AuthorName;
        attribute affiliation : String[0..*] ordered;
    }

    item def BibliographicMetadata {
        attribute s2cid : S2CID;
        attribute doi : DOI[0..1];
        attribute title : Title;
        attribute authors : Author[0..*] ordered;
        attribute publicationYear : PublicationYear;
        attribute abstract : AbstractText[0..1];
        attribute venue : String[0..1];
        attribute source : String[0..*] ordered;
    }

    item def CitationMetrics {
        attribute s2cid : S2CID;
        attribute totalCitations : CitationCount;
        attribute influenceScore : InfluenceScore;
        attribute influentialCitationCount : CitationCount;
    }

    item def ReferenceEntry {
        attribute referencedS2cid : S2CID[0..1];
        attribute referencedTitle : Title[0..1];
        attribute referencedDoi : DOI[0..1];
        attribute confidence : ConfidenceScore;
    }

    item def ReferenceList {
        attribute s2cid : S2CID;
        attribute references : ReferenceEntry[0..*] ordered;
    }

    item def PaperRecord {
        attribute s2cid : S2CID;
        attribute metadata : BibliographicMetadata[0..1];
        attribute metrics : CitationMetrics[0..1];
        attribute references : ReferenceList[0..1];
        attribute lastUpdated : String;
        attribute cacheHit : Boolean;
    }

    item def QueryRequest {
        attribute s2cid : S2CID;
        attribute requesterId : String[0..1];
        attribute timestamp : String;
    }

    item def QueryResponse {
        attribute s2cid : S2CID;
        attribute record : PaperRecord;
        attribute success : Boolean;
        attribute message : String[0..1];
        attribute responseTime : ResponseTime;
    }

    item def ValidationResult {
        attribute s2cid : S2CID;
        attribute valid : Boolean;
        attribute reason : String[0..1];
    }

    // ===== Port Definitions =====

    port def QueryInPort {
        in item requests : QueryRequest[0..*];
    }

    port def QueryOutPort {
        out item responses : QueryResponse[0..*];
    }

    port def ValidationRequestPort {
        out item validationRequests : S2CID[0..*];
        in item validationResults : ValidationResult[0..*];
    }

    port def MetadataRequestPort {
        out item metadataRequests : S2CID[0..*];
        in item metadataResponses : BibliographicMetadata[0..*];
    }

    port def CitationAnalysisPort {
        out item analysisRequests : S2CID[0..*];
        in item analysisResponses : CitationMetrics[0..*];
    }

    port def ReferenceExtractionPort {
        out item extractionRequests : S2CID[0..*];
        in item extractionResponses : ReferenceList[0..*];
    }

    port def RepositoryPort {
        out item storeRequests : PaperRecord[0..*];
        out item retrieveRequests : S2CID[0..*];
        in item retrieveResponses : PaperRecord[0..*];
    }

    // ===== Interfaces =====

    interface def QueryInterface {
        end supplier : QueryInPort;
        end consumer : QueryOutPort;
    }

    interface def ValidationInterface {
        end requester : ValidationRequestPort;
        end responder : ValidationRequestPort;
    }

    interface def MetadataInterface {
        end requester : MetadataRequestPort;
        end responder : MetadataRequestPort;
    }

    interface def CitationAnalysisInterface {
        end requester : CitationAnalysisPort;
        end responder : CitationAnalysisPort;
    }

    interface def ReferenceExtractionInterface {
        end requester : ReferenceExtractionPort;
        end responder : ReferenceExtractionPort;
    }

    interface def RepositoryInterface {
        end client : RepositoryPort;
        end store : RepositoryPort;
    }

    // ===== Requirements =====

    requirement def ValidatedS2CIDRequirement {
        subject s2cid : S2CID;
        doc /* The S2CID must be a positive integer corresponding to a real paper. */
        constraint { s2cid > 0 }
    }

    requirement def MetadataCompletenessRequirement {
        subject metadata : BibliographicMetadata;
        doc /* Fetched metadata must include title, at least one author, and publication year. */
        constraint { metadata.title != null }
        constraint { size(metadata.authors) >= 1 }
        constraint { metadata.publicationYear != null }
    }

    requirement def CitationMetricsRequirement {
        subject metrics : CitationMetrics;
        doc /* Citation metrics must include total citations and influence score. */
        constraint { metrics.totalCitations >= 0 }
        constraint { metrics.influenceScore >= 0.0 }
    }

    requirement def ReferenceExtractionRequirement {
        subject references : ReferenceList;
        doc /* Reference list must contain zero or more reference entries with confidence scores. */
        constraint { size(references.references) >= 0 }
    }

    requirement def CachePerformanceRequirement {
        subject cacheHitRate : CacheHitRate;
        doc /* Subsequent requests for the same paper should achieve at least 80% cache hit rate. */
        constraint { cacheHitRate >= 0.80 }
    }

    requirement def ResponseTimeRequirement {
        subject responseTime : ResponseTime;
        doc /* System should respond within 5 seconds for cached papers and 30 seconds for fresh fetches. */
        constraint { responseTime <= 30.0 }
    }

    requirement def PaperRecordCompletenessRequirement {
        subject record : PaperRecord;
        doc /* A complete paper record must contain metadata, metrics, and references. */
        constraint { record.metadata != null }
        constraint { record.metrics != null }
        constraint { record.references != null }
    }

    // ===== Component Parts =====

    part def IdentifierValidator {
        port validationPort : ValidationRequestPort;

        attribute validatedIds : S2CID[0..*];

        action def validateIdentifier {
            in s2cid : S2CID;
            out result : ValidationResult;
        }

        state validationStateMachine {
            entry;
            state Idle;
            state Validating {
                entry {
                    // Check format and corpus existence
                }
            }
            state Validated;
            state Rejected;
            transition idle_to_validating
                from Idle to Validating
                when validationPort.validationRequests->notEmpty();
            transition validating_to_validated
                from Validating to Validated
                when true;
            transition validating_to_rejected
                from Validating to Rejected
                when true;
            transition back_to_idle
                from {Validated, Rejected} to Idle
                when true;
        }
    }

    part def MetadataResolver {
        port metadataPort : MetadataRequestPort;

        attribute semanticScholarEndpoint : String = "https://api.semanticscholar.org";
        attribute crossrefEndpoint : String = "https://api.crossref.org";

        action def resolveMetadata {
            in s2cid : S2CID;
            out metadata : BibliographicMetadata;
        }

        action def fetchFromSemanticScholar {
            in s2cid : S2CID;
            out partialMetadata : BibliographicMetadata;
        }

        action def fetchFromCrossref {
            in doi : DOI[0..1];
            out partialMetadata : BibliographicMetadata;
        }

        action def mergeMetadata {
            in sourceA : BibliographicMetadata;
            in sourceB : BibliographicMetadata;
            out merged : BibliographicMetadata;
        }

        state resolutionStateMachine {
            entry;
            state Idle;
            state FetchingSemanticScholar;
            state FetchingCrossref;
            state Merging;
            state Complete;
            transition start_fetch
                from Idle to FetchingSemanticScholar
                when metadataPort.metadataRequests->notEmpty();
            transition ss_to_crossref
                from FetchingSemanticScholar to FetchingCrossref
                when true;
            transition crossref_to_merge
                from FetchingCrossref to Merging
                when true;
            transition merge_to_complete
                from Merging to Complete
                when true;
            transition complete_to_idle
                from Complete to Idle
                when true;
        }
    }

    part def CitationAnalyzer {
        port analysisPort : CitationAnalysisPort;

        action def analyzeCitations {
            in s2cid : S2CID;
            out metrics : CitationMetrics;
        }

        action def calculateTotalCitations {
            in s2cid : S2CID;
            out count : CitationCount;
        }

        action def calculateInfluenceScore {
            in s2cid : S2CID;
            out score : InfluenceScore;
        }

        action def identifyInfluentialCitations {
            in s2cid : S2CID;
            out count : CitationCount;
        }

        state analysisStateMachine {
            entry;
            state Idle;
            state CalculatingCitations;
            state CalculatingInfluence;
            state IdentifyingInfluential;
            state Aggregating;
            state Complete;
            transition start_analysis
                from Idle to CalculatingCitations
                when analysisPort.analysisRequests->notEmpty();
            transition citations_to_influence
                from CalculatingCitations to CalculatingInfluence
                when true;
            transition influence_to_identifying
                from CalculatingInfluence to IdentifyingInfluential
                when true;
            transition identifying_to_aggregating
                from IdentifyingInfluential to Aggregating
                when true;
            transition aggregating_to_complete
                from Aggregating to Complete
                when true;
            transition complete_to_idle
                from Complete to Idle
                when true;
        }
    }

    part def ReferenceExtractor {
        port extractionPort : ReferenceExtractionPort;

        action def extractReferences {
            in s2cid : S2CID;
            out referenceList : ReferenceList;
        }

        action def parsePaperContent {
            in s2cid : S2CID;
            out rawReferences : String[0..*] ordered;
        }

        action def matchToCorpus {
            in rawReferences : String[0..*] ordered;
            out matchedReferences : ReferenceEntry[0..*] ordered;
        }

        action def assignConfidence {
            in matchedReferences : ReferenceEntry[0..*] ordered;
            out scoredReferences : ReferenceEntry[0..*] ordered;
        }

        state extractionStateMachine {
            entry;
            state Idle;
            state Parsing;
            state Matching;
            state Scoring;
            state Complete;
            transition start_extraction
                from Idle to Parsing
                when extractionPort.extractionRequests->notEmpty();
            transition parsing_to_matching
                from Parsing to Matching
                when true;
            transition matching_to_scoring
                from Matching to Scoring
                when true;
            transition scoring_to_complete
                from Scoring to Complete
                when true;
            transition complete_to_idle
                from Complete to Idle
                when true;
        }
    }

    part def PaperRepository {
        port repositoryPort : RepositoryPort;

        attribute cache : PaperRecord[0..*];
        attribute maxCacheSize : Integer = 10000;

        action def storeRecord {
            in record : PaperRecord;
        }

        action def retrieveRecord {
            in s2cid : S2CID;
            out record : PaperRecord[0..1];
        }

        action def evictOldest {
        }

        state repositoryStateMachine {
            entry;
            state Idle;
            state Storing;
            state Retrieving;
            state Evicting;
            transition idle_to_storing
                from Idle to Storing
                when repositoryPort.storeRequests->notEmpty();
            transition idle_to_retrieving
                from Idle to Retrieving
                when repositoryPort.retrieveRequests->notEmpty();
            transition storing_to_idle
                from Storing to Idle
                when true;
            transition retrieving_to_idle
                from Retrieving to Idle
                when true;
            transition to_evicting
                from Storing to Evicting
                when size(cache) >= maxCacheSize;
            transition evicting_to_storing
                from Evicting to Storing
                when true;
        }
    }

    part def QueryProcessor {
        port queryInPort : QueryInPort;
        port queryOutPort : QueryOutPort;

        port validationPort : ValidationRequestPort;
        port metadataPort : MetadataRequestPort;
        port analysisPort : CitationAnalysisPort;
        port extractionPort : ReferenceExtractionPort;
        port repositoryPort : RepositoryPort;

        attribute activeRequests : QueryRequest[0..*];

        action def processQuery {
            in request : QueryRequest;
            out response : QueryResponse;
        }

        action def checkCache {
            in s2cid : S2CID;
            out cachedRecord : PaperRecord[0..1];
        }

        action def orchestrateWorkflow {
            in request : QueryRequest;
            out record : PaperRecord;
        }

        action def assembleResponse {
            in record : PaperRecord;
            in request : QueryRequest;
            out response : QueryResponse;
        }

        state queryProcessorStateMachine {
            entry;
            state Idle;
            state CheckingCache;
            state ValidatingId;
            state ResolvingMetadata;
            state AnalyzingCitations;
            state ExtractingReferences;
            state StoringRecord;
            state AssemblingResponse;
            state Complete;
            state Error;

            transition idle_to_cache_check
                from Idle to CheckingCache
                when queryInPort.requests->notEmpty();

            transition cache_hit_to_assemble
                from CheckingCache to AssemblingResponse
                when repositoryPort.retrieveResponses->notEmpty()
                    and repositoryPort.retrieveResponses->first().cacheHit == true;

            transition cache_miss_to_validate
                from CheckingCache to ValidatingId
                when repositoryPort.retrieveResponses->isEmpty()
                    or repositoryPort.retrieveResponses->first().cacheHit == false;

            transition validate_to_metadata
                from ValidatingId to ResolvingMetadata
                when validationPort.validationResults->notEmpty()
                    and validationPort.validationResults->first().valid == true;

            transition validate_to_error
                from ValidatingId to Error
                when validationPort.validationResults->notEmpty()
                    and validationPort.validationResults->first().valid == false;

            transition metadata_to_analysis
                from ResolvingMetadata to AnalyzingCitations
                when metadataPort.metadataResponses->notEmpty();

            transition analysis_to_extraction
                from AnalyzingCitations to ExtractingReferences
                when analysisPort.analysisResponses->notEmpty();

            transition extraction_to_store
                from ExtractingReferences to StoringRecord
                when extractionPort.extractionResponses->notEmpty();

            transition store_to_assemble
                from StoringRecord to AssemblingResponse
                when true;

            transition assemble_to_complete
                from AssemblingResponse to Complete
                when true;

            transition complete_to_idle
                from Complete to Idle
                when true;

            transition error_to_idle
                from Error to Idle
                when true;
        }
    }

    // ===== Top-Level System =====

    part def CitationManagementSystem {

        port queryInPort : QueryInPort;
        port queryOutPort : QueryOutPort;

        part queryProcessor : QueryProcessor;
        part identifierValidator : IdentifierValidator;
        part metadataResolver : MetadataResolver;
        part citationAnalyzer : CitationAnalyzer;
        part referenceExtractor : ReferenceExtractor;
        part paperRepository : PaperRepository;

        // External connections to system boundary
        connection queryInputConnection
            connect queryInPort::requests to queryProcessor::queryInPort::requests;
        connection queryOutputConnection
            connect queryProcessor::queryOutPort::responses to queryOutPort::responses;

        // QueryProcessor to IdentifierValidator
        connection validationConnection : ValidationInterface
            connect queryProcessor::validationPort to identifierValidator::validationPort;

        // QueryProcessor to MetadataResolver
        connection metadataConnection : MetadataInterface
            connect queryProcessor::metadataPort to metadataResolver::metadataPort;

        // QueryProcessor to CitationAnalyzer
        connection analysisConnection : CitationAnalysisInterface
            connect queryProcessor::analysisPort to citationAnalyzer::analysisPort;

        // QueryProcessor to ReferenceExtractor
        connection extractionConnection : ReferenceExtractionInterface
            connect queryProcessor::extractionPort to referenceExtractor::extractionPort;

        // QueryProcessor to PaperRepository
        connection repositoryConnection : RepositoryInterface
            connect queryProcessor::repositoryPort to paperRepository::repositoryPort;

        requirement satisfaction {
            subject record : PaperRecord;
            satisfy PaperRecordCompletenessRequirement by queryProcessor;
        }

        requirement satisfaction {
            subject cacheHitRate : CacheHitRate;
            satisfy CachePerformanceRequirement by paperRepository;
        }

        requirement satisfaction {
            subject responseTime : ResponseTime;
            satisfy ResponseTimeRequirement by queryProcessor;
        }
    }

    // ===== System Usage Example =====

    part def SystemDeployment {
        part system : CitationManagementSystem;

        attribute targetCacheHitRate : CacheHitRate = 0.85;
        attribute maxResponseTime : ResponseTime = 20.0;

        requirement satisfaction {
            subject cacheHitRate : CacheHitRate;
            satisfy CachePerformanceRequirement by system::paperRepository;
        }

        requirement satisfaction {
            subject responseTime : ResponseTime;
            satisfy ResponseTimeRequirement by system::queryProcessor;
        }
    }

}
