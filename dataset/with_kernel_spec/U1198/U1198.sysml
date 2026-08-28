package 'Academic Citation Management System' {
	private import ScalarValues::*;

	item def PaperRequest {
		attribute s2cid : String;
	}

	item def PaperMetadata {
		attribute title : String;
		attribute authors : String[1..*];
		attribute publicationYear : Integer;
		attribute abstractText : String;
	}

	item def CitationMetrics {
		attribute citationCount : Integer;
		attribute influenceScore : Real;
	}

	item def ReferenceList {
		attribute citedPaperIds : String[0..*];
	}

	item def ValidationResult {
		attribute valid : Boolean;
		attribute reason : String;
	}

	item def PaperOverview {
		attribute s2cid : String;
		attribute paperMetadata : PaperMetadata[0..1];
		attribute citationMetrics : CitationMetrics[0..1];
		attribute referenceList : ReferenceList[0..1];
	}

	item def RepositoryLookupResult {
		attribute found : Boolean;
		attribute overview : PaperOverview[0..1];
	}

	requirement def S2CIDValidationRequirement {
		doc
		/*
		 * The system shall validate the format and existence of the provided
		 * S2CID before processing.
		 */
	}

	requirement def MetadataResolutionRequirement {
		doc
		/*
		 * The system shall resolve bibliographic metadata from Semantic Scholar
		 * and Crossref sources.
		 */
	}

	requirement def CitationAnalysisRequirement {
		doc
		/*
		 * The system shall compute citation count and influence score for
		 * validated papers.
		 */
	}

	requirement def ReferenceExtractionRequirement {
		doc
		/*
		 * The system shall extract the list of cited works from validated papers.
		 */
	}

	requirement def RepositoryCachingRequirement {
		doc
		/*
		 * The system shall cache paper overviews to accelerate subsequent
		 * queries for the same S2CID.
		 */
	}

	requirement def ProvidePaperOverviewRequirement {
		doc
		/*
		 * The system shall accept an S2CID and return a comprehensive paper
		 * overview including metadata, citation metrics, and references.
		 */
	}

	port def ValidationRequestPort {
		in s2cid : String;
	}
	port def ValidationResponsePort {
		out result : ValidationResult;
	}
	port def MetadataRequestPort {
		in s2cid : String;
	}
	port def MetadataResponsePort {
		out paperMetadata : PaperMetadata;
	}
	port def CitationRequestPort {
		in s2cid : String;
	}
	port def CitationResponsePort {
		out citationMetrics : CitationMetrics;
	}
	port def ReferenceRequestPort {
		in s2cid : String;
	}
	port def ReferenceResponsePort {
		out referenceList : ReferenceList;
	}
	port def RepositoryLookupRequestPort {
		in s2cid : String;
	}
	port def RepositoryLookupResultPort {
		out lookupResult : RepositoryLookupResult;
	}
	port def RepositoryStorePort {
		in overview : PaperOverview;
	}
	port def PaperRequestPort {
		in request : PaperRequest;
	}
	port def PaperOverviewPort {
		out overview : PaperOverview;
	}

	part def IdentifierValidator {
		port validationRequestPort : ValidationRequestPort;
		port validationResponsePort : ValidationResponsePort;
		perform action validateIdentifier {
			in s2cid : String;
			out result : ValidationResult;
			action checkFormat {
				in id : String;
				out valid : Boolean;
			}
			action checkExistence {
				in id : String;
				out exists : Boolean;
			}
			then action buildResult {
				in formatValid : Boolean;
				in exists : Boolean;
				out result : ValidationResult;
			}
		}
	}

	part def MetadataResolver {
		port metadataRequestPort : MetadataRequestPort;
		port metadataResponsePort : MetadataResponsePort;
		perform action resolveMetadata {
			in s2cid : String;
			out paperMetadata : PaperMetadata;
			action fetchFromSemanticScholar {
				in id : String;
				out partialMetadata : PaperMetadata;
			}
			action fetchFromCrossref {
				in id : String;
				out partialMetadata : PaperMetadata;
			}
			then action mergeMetadata {
				in fromSemanticScholar : PaperMetadata;
				in fromCrossref : PaperMetadata;
				out merged : PaperMetadata;
			}
		}
	}

	part def CitationAnalyzer {
		port citationRequestPort : CitationRequestPort;
		port citationResponsePort : CitationResponsePort;
		perform action analyzeCitations {
			in s2cid : String;
			out citationMetrics : CitationMetrics;
			action fetchCitationCount {
				in id : String;
				out count : Integer;
			}
			action computeInfluenceScore {
				in id : String;
				out score : Real;
			}
			then action assembleMetrics {
				in count : Integer;
				in score : Real;
				out citationMetrics : CitationMetrics;
			}
		}
	}

	part def ReferenceExtractor {
		port referenceRequestPort : ReferenceRequestPort;
		port referenceResponsePort : ReferenceResponsePort;
		perform action extractReferences {
			in s2cid : String;
			out referenceList : ReferenceList;
			action fetchPaperContent {
				in id : String;
				out content : String;
			}
			then action parseReferences {
				in content : String;
				out parsedIds : String[0..*];
			}
			then action buildReferenceList {
				in parsedIds : String[0..*];
				out referenceList : ReferenceList;
			}
		}
	}

	part def PaperRepository {
		port repositoryLookupRequestPort : RepositoryLookupRequestPort;
		port repositoryLookupResultPort : RepositoryLookupResultPort;
		port repositoryStorePort : RepositoryStorePort;
		attribute storedPapers : PaperOverview[0..*];
		perform action lookupPaper {
			in s2cid : String;
			out lookupResult : RepositoryLookupResult;
			action findInCache {
				in id : String;
				in papers : PaperOverview[0..*];
				out foundOverview : PaperOverview[0..1];
			}
			then action buildLookupResult {
				in foundOverview : PaperOverview[0..1];
				out lookupResult : RepositoryLookupResult;
			}
		}
		perform action storePaper {
			in overview : PaperOverview;
			then action addToCache {
				in overview : PaperOverview;
				inout papers : PaperOverview[0..*];
			}
		}
		exhibit state repositoryBehavior {
			entry; then idle;
			state idle;
			transition lookupRequested
				first idle
				accept req : PaperRequest via repositoryLookupRequestPort
				do lookupPaper
				then idle;
			transition storeRequested
				first idle
				accept ov : PaperOverview via repositoryStorePort
				do storePaper
				then idle;
		}
	}

	part def QueryProcessor {
		port paperRequestPort : PaperRequestPort;
		port paperOverviewPort : PaperOverviewPort;
		port validationRequestPort : ValidationRequestPort;
		port validationResponsePort : ValidationResponsePort;
		port metadataRequestPort : MetadataRequestPort;
		port metadataResponsePort : MetadataResponsePort;
		port citationRequestPort : CitationRequestPort;
		port citationResponsePort : CitationResponsePort;
		port referenceRequestPort : ReferenceRequestPort;
		port referenceResponsePort : ReferenceResponsePort;
		port repositoryLookupRequestPort : RepositoryLookupRequestPort;
		port repositoryLookupResultPort : RepositoryLookupResultPort;
		port repositoryStorePort : RepositoryStorePort;

		attribute currentRequest : PaperRequest;
		attribute currentMetadata : PaperMetadata;
		attribute currentMetrics : CitationMetrics;
		attribute currentReferences : ReferenceList;
		attribute currentOverview : PaperOverview;

		exhibit state queryProcessorBehavior {
			entry; then idle;

			state idle;
			transition receiveRequest
				first idle
				accept req : PaperRequest via paperRequestPort
				do currentRequest = req
				then awaitingCacheResult;

			state awaitingCacheResult;
			transition cacheHit
				first awaitingCacheResult
				accept cached : RepositoryLookupResult via repositoryLookupResultPort
				if cached.found
				do send cached.overview via paperOverviewPort
				then idle;
			transition cacheMiss
				first awaitingCacheResult
				accept cached : RepositoryLookupResult via repositoryLookupResultPort
				if !cached.found
				do send currentRequest.s2cid via validationRequestPort
				then awaitingValidation;

			state awaitingValidation;
			transition validationSucceeded
				first awaitingValidation
				accept validation : ValidationResult via validationResponsePort
				if validation.valid
				do send currentRequest.s2cid via metadataRequestPort
				then awaitingMetadata;
			transition validationFailed
				first awaitingValidation
				accept validation : ValidationResult via validationResponsePort
				if !validation.valid
				do send new PaperOverview(s2cid = currentRequest.s2cid) via paperOverviewPort
				then idle;

			state awaitingMetadata;
			transition metadataResolved
				first awaitingMetadata
				accept md : PaperMetadata via metadataResponsePort
				do currentMetadata = md
				then requestingCitations;

			state requestingCitations;
			transition citationRequestSent
				first requestingCitations
				do send currentRequest.s2cid via citationRequestPort
				then awaitingCitations;

			state awaitingCitations;
			transition citationsAnalyzed
				first awaitingCitations
				accept cm : CitationMetrics via citationResponsePort
				do currentMetrics = cm
				then requestingReferences;

			state requestingReferences;
			transition referenceRequestSent
				first requestingReferences
				do send currentRequest.s2cid via referenceRequestPort
				then awaitingReferences;

			state awaitingReferences;
			transition referencesExtracted
				first awaitingReferences
				accept rl : ReferenceList via referenceResponsePort
				do currentReferences = rl
				then assemblingOverview;

			state assemblingOverview;
			transition overviewAssembled
				first assemblingOverview
				do currentOverview = new PaperOverview(
						s2cid = currentRequest.s2cid,
						paperMetadata = currentMetadata,
						citationMetrics = currentMetrics,
						referenceList = currentReferences
					)
				then storingAndResponding;

			state storingAndResponding;
			transition storedAndResponded
				first storingAndResponding
				do send currentOverview via repositoryStorePort;
				send currentOverview via paperOverviewPort
				then idle;
		}
	}

	part def AcademicCitationSystem {
		port paperRequestPort : PaperRequestPort;
		port paperOverviewPort : PaperOverviewPort;

		part queryProcessor : QueryProcessor {
			port :>> paperRequestPort;
			port :>> paperOverviewPort;
		}
		part identifierValidator : IdentifierValidator;
		part metadataResolver : MetadataResolver;
		part citationAnalyzer : CitationAnalyzer;
		part referenceExtractor : ReferenceExtractor;
		part paperRepository : PaperRepository;

		interface validationRequestInterface connect queryProcessor.validationRequestPort to identifierValidator.validationRequestPort {
			flow validationRequestFlow of String
				from queryProcessor.validationRequestPort.s2cid to identifierValidator.validationRequestPort.s2cid;
		}
		interface validationResponseInterface connect identifierValidator.validationResponsePort to queryProcessor.validationResponsePort {
			flow validationResponseFlow of ValidationResult
				from identifierValidator.validationResponsePort.result to queryProcessor.validationResponsePort.result;
		}
		interface metadataRequestInterface connect queryProcessor.metadataRequestPort to metadataResolver.metadataRequestPort {
			flow metadataRequestFlow of String
				from queryProcessor.metadataRequestPort.s2cid to metadataResolver.metadataRequestPort.s2cid;
		}
		interface metadataResponseInterface connect metadataResolver.metadataResponsePort to queryProcessor.metadataResponsePort {
			flow metadataResponseFlow of PaperMetadata
				from metadataResolver.metadataResponsePort.paperMetadata to queryProcessor.metadataResponsePort.paperMetadata;
		}
		interface citationRequestInterface connect queryProcessor.citationRequestPort to citationAnalyzer.citationRequestPort {
			flow citationRequestFlow of String
				from queryProcessor.citationRequestPort.s2cid to citationAnalyzer.citationRequestPort.s2cid;
		}
		interface citationResponseInterface connect citationAnalyzer.citationResponsePort to queryProcessor.citationResponsePort {
			flow citationResponseFlow of CitationMetrics
				from citationAnalyzer.citationResponsePort.citationMetrics to queryProcessor.citationResponsePort.citationMetrics;
		}
		interface referenceRequestInterface connect queryProcessor.referenceRequestPort to referenceExtractor.referenceRequestPort {
			flow referenceRequestFlow of String
				from queryProcessor.referenceRequestPort.s2cid to referenceExtractor.referenceRequestPort.s2cid;
		}
		interface referenceResponseInterface connect referenceExtractor.referenceResponsePort to queryProcessor.referenceResponsePort {
			flow referenceResponseFlow of ReferenceList
				from referenceExtractor.referenceResponsePort.referenceList to queryProcessor.referenceResponsePort.referenceList;
		}
		interface repositoryLookupInterface connect queryProcessor.repositoryLookupRequestPort to paperRepository.repositoryLookupRequestPort {
			flow repositoryLookupRequestFlow of String
				from queryProcessor.repositoryLookupRequestPort.s2cid to paperRepository.repositoryLookupRequestPort.s2cid;
		}
		interface repositoryLookupResultInterface connect paperRepository.repositoryLookupResultPort to queryProcessor.repositoryLookupResultPort {
			flow repositoryLookupResultFlow of RepositoryLookupResult
				from paperRepository.repositoryLookupResultPort.lookupResult to queryProcessor.repositoryLookupResultPort.lookupResult;
		}
		interface repositoryStoreInterface connect queryProcessor.repositoryStorePort to paperRepository.repositoryStorePort {
			flow repositoryStoreFlow of PaperOverview
				from queryProcessor.repositoryStorePort.overview to paperRepository.repositoryStorePort.overview;
		}

		satisfy S2CIDValidationRequirement by identifierValidator;
		satisfy MetadataResolutionRequirement by metadataResolver;
		satisfy CitationAnalysisRequirement by citationAnalyzer;
		satisfy ReferenceExtractionRequirement by referenceExtractor;
		satisfy RepositoryCachingRequirement by paperRepository;
		satisfy ProvidePaperOverviewRequirement by queryProcessor;
	}

	part academicCitationSystem : AcademicCitationSystem;

	part externalUser {
		port userRequestPort : PaperRequestPort;
		port userResponsePort : PaperOverviewPort;
	}

	interface userToSystemInterface connect externalUser.userRequestPort to academicCitationSystem.paperRequestPort {
		flow requestFlow of PaperRequest
			from externalUser.userRequestPort.request to academicCitationSystem.paperRequestPort.request;
	}
	interface systemToUserInterface connect academicCitationSystem.paperOverviewPort to externalUser.userResponsePort {
		flow responseFlow of PaperOverview
			from academicCitationSystem.paperOverviewPort.overview to externalUser.userResponsePort.overview;
	}
}
