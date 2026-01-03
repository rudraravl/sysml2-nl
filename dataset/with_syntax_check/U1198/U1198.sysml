package 'S2CID Academic Citation System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def S2CID :> String {
        doc /* Semantic Scholar Corpus ID - unique persistent identifier for academic papers */
    }
    
    attribute def DOI :> String {
        doc /* Digital Object Identifier */
    }
    
    attribute def PaperTitle :> String;
    attribute def AuthorName :> String;
    attribute def PublicationYear :> Integer;
    attribute def VenueInfo :> String;
    attribute def CitationCount :> Integer;
    attribute def InfluenceScore :> Real;
    
    item def PaperMetadata {
        attribute identifier : S2CID;
        attribute doi : DOI;
        attribute title : PaperTitle;
        attribute authors : AuthorName[1..*];
        attribute year : PublicationYear;
        attribute venue : VenueInfo;
        attribute citations : CitationCount;
        attribute influence : InfluenceScore;
        attribute abstractText : String;
    }
    
    item def ValidationResult {
        attribute isValid : Boolean;
        attribute isResolvable : Boolean;
        attribute errorMessage : String;
        attribute timestamp : String;
    }
    
    item def QueryRequest {
        attribute requestedId : S2CID;
        attribute includeReferences : Boolean;
        attribute includeCitations : Boolean;
    }
    
    item def QueryResponse {
        attribute success : Boolean;
        attribute paperMetadata : PaperMetadata;
        attribute references : S2CID[*];
        attribute citations : S2CID[*];
    }
    
    item def AcademicPaper {
        attribute paperMetadata : PaperMetadata;
        attribute fullTextAvailable : Boolean;
        attribute pdfUrl : String;
        attribute referenceList : S2CID[*];
        attribute citationList : S2CID[*];
    }
    
    port def QueryPort {
        in attribute request : QueryRequest;
        out attribute response : QueryResponse;
    }
    
    port def ValidationPort {
        in attribute idToValidate : S2CID;
        out attribute validationResult : ValidationResult;
    }
    
    port def MetadataPort {
        in attribute s2cid : S2CID;
        out attribute paperMetadata : PaperMetadata;
    }
    
    port def CitationGraphPort {
        in attribute paperId : S2CID;
        out attribute citationData : CitationCount;
        out attribute influenceData : InfluenceScore;
    }
    
    part def IdentifierValidator {
        doc /* Validates S2CID format and verifies existence in corpus */
        
        port validationInterface : ValidationPort;
        
        action validateS2CID {
            in identifier : S2CID;
            out result : ValidationResult;
            
            first start;
            then action checkFormat {
                in id : S2CID = identifier;
                out formatValid : Boolean;
            }
            then decide;
                if checkFormat.formatValid then verifyInCorpus;
                if !checkFormat.formatValid then createInvalidResult;
            
            action verifyInCorpus {
                in id : S2CID = identifier;
                out exists : Boolean;
                out resolvable : Boolean;
            }
            then decide;
                if verifyInCorpus.exists then createValidResult;
                if !verifyInCorpus.exists then createNotFoundResult;
            
            action createValidResult {
                out validResult : ValidationResult;
            }
            then assign result := createValidResult.validResult;
            then done;
            
            action createInvalidResult {
                out invalidResult : ValidationResult;
            }
            then assign result := createInvalidResult.invalidResult;
            then done;
            
            action createNotFoundResult {
                out notFoundResult : ValidationResult;
            }
            then assign result := createNotFoundResult.notFoundResult;
            then done;
        }
    }
    
    part def MetadataResolver {
        doc /* Resolves S2CID to complete bibliographic metadata */
        
        port metadataInterface : MetadataPort;
        
        action resolveMetadata {
            in identifier : S2CID;
            out paperMetadata : PaperMetadata;
            
            first start;
            then action querySemanticScholar {
                in s2cid : S2CID = identifier;
                out rawMetadata : PaperMetadata;
            }
            then action enrichWithCrossref {
                in baseMetadata : PaperMetadata = querySemanticScholar.rawMetadata;
                out enrichedMetadata : PaperMetadata;
            }
            then action normalizeData {
                in inputMetadata : PaperMetadata = enrichWithCrossref.enrichedMetadata;
                out normalizedMetadata : PaperMetadata;
            }
            then assign paperMetadata := normalizeData.normalizedMetadata;
            then done;
        }
    }
    
    part def CitationAnalyzer {
        doc /* Analyzes citation relationships and computes influence metrics */
        
        port citationInterface : CitationGraphPort;
        attribute citationGraph : S2CID[*];
        
        action analyzeCitations {
            in paperId : S2CID;
            out citationCount : CitationCount;
            out influenceScore : InfluenceScore;
            
            first start;
            then action fetchDirectCitations {
                in id : S2CID = paperId;
                out directCitations : S2CID[*];
            }
            then action computeInfluence {
                in citationsList : S2CID[*] = fetchDirectCitations.directCitations;
                out influence : InfluenceScore;
            }
            then action countCitations {
                in citationsList : S2CID[*] = fetchDirectCitations.directCitations;
                out count : CitationCount;
            }
            then assign citationCount := countCitations.count;
            then assign influenceScore := computeInfluence.influence;
            then done;
        }
    }
    
    part def ReferenceExtractor {
        doc /* Extracts and resolves reference lists from papers */
        
        action extractReferences {
            in paperId : S2CID;
            out references : S2CID[*];
            
            first start;
            then action fetchPaperContent {
                in id : S2CID = paperId;
                out content : String;
            }
            then action parseReferences {
                in paperContent : String = fetchPaperContent.content;
                out rawReferences : String[*];
            }
            then action resolveToS2CID {
                in rawRefs : String[*] = parseReferences.rawReferences;
                out resolvedIds : S2CID[*];
            }
            then assign references := resolveToS2CID.resolvedIds;
            then done;
        }
    }
    
    part def PaperRepository {
        doc /* Stores and manages academic paper records */
        
        attribute papers : AcademicPaper[*];
        
        action storePaper {
            in paper : AcademicPaper;
            
            first start;
            then action validatePaper {
                in paperData : AcademicPaper = paper;
                out isValid : Boolean;
            }
            then decide;
                if validatePaper.isValid then addToRepository;
                if !validatePaper.isValid then rejectPaper;
            
            action addToRepository {
                in paperToAdd : AcademicPaper = paper;
            }
            then assign papers := papers->including(paper);
            then done;
            
            action rejectPaper {
                in invalidPaper : AcademicPaper = paper;
            }
            then done;
        }
        
        action retrievePaper {
            in identifier : S2CID;
            out paper : AcademicPaper;
            
            first start;
            then action searchRepository {
                in id : S2CID = identifier;
                out found : Boolean;
                out foundPaper : AcademicPaper;
            }
            then decide;
                if searchRepository.found then returnPaper;
                if !searchRepository.found then returnNull;
            
            action returnPaper {
                in retrievedPaper : AcademicPaper = searchRepository.foundPaper;
            }
            then assign paper := searchRepository.foundPaper;
            then done;
            
            action returnNull;
            then done;
        }
    }
    
    part def QueryProcessor {
        doc /* Processes user queries and orchestrates system components */
        
        port queryInterface : QueryPort;
        
        action processQuery {
            in request : QueryRequest;
            out response : QueryResponse;
            
            first start;
            then action validateRequest {
                in queryRequest : QueryRequest = request;
                out valid : Boolean;
            }
            then decide;
                if validateRequest.valid then executeQuery;
                if !validateRequest.valid then returnError;
            
            action executeQuery {
                action fetchMetadata {
                    in id : S2CID = request.requestedId;
                    out paperMetadata : PaperMetadata;
                }
                then action fetchReferences {
                    in id : S2CID = request.requestedId;
                    out refs : S2CID[*];
                }
                then action fetchCitations {
                    in id : S2CID = request.requestedId;
                    out cites : S2CID[*];
                }
                then action buildResponse {
                    in meta : PaperMetadata = fetchMetadata.paperMetadata;
                    in referencesList : S2CID[*] = fetchReferences.refs;
                    in citationsList : S2CID[*] = fetchCitations.cites;
                    out queryResponse : QueryResponse;
                }
                then assign response := buildResponse.queryResponse;
            }
            then done;
            
            action returnError {
                out errorResponse : QueryResponse;
            }
            then assign response := returnError.errorResponse;
            then done;
        }
    }
    
    part def 'S2CID Citation System' {
        doc /* 
            Academic citation management system based on Semantic Scholar Corpus IDs (S2CID).
            
            Primary Function: Enable comprehensive discovery, validation, and analysis of 
            academic literature by providing reliable resolution of S2CID identifiers to 
            complete bibliographic metadata, citation relationships, and influence metrics. 
            The system facilitates research by maintaining a queryable graph of scholarly 
            works, their references, and citation patterns, supporting literature review, 
            impact assessment, and knowledge discovery workflows.
        */
        
        part validator : IdentifierValidator;
        part resolver : MetadataResolver;
        part analyzer : CitationAnalyzer;
        part extractor : ReferenceExtractor;
        part repository : PaperRepository;
        part processor : QueryProcessor;
        
        connection validatorToProcessor connect 
            validator.validationInterface to processor.queryInterface;
        
        connection resolverToProcessor connect 
            resolver.metadataInterface to processor.queryInterface;
        
        connection analyzerToProcessor connect 
            analyzer.citationInterface to processor.queryInterface;
        
        perform action manageCitations {
            doc /* Main system behavior orchestrating citation management workflow */
            
            first start;
            then merge awaitRequest;
            
            then action receiveQuery {
                out query : QueryRequest;
            }
            
            then action validateIdentifier references validator.validateS2CID {
                in identifier = receiveQuery.query.requestedId;
                out result;
            }
            
            then decide;
                if validateIdentifier.result.isValid then processValidQuery;
                if !validateIdentifier.result.isValid then handleInvalidQuery;
            
            action processValidQuery {
                action checkCache references repository.retrievePaper {
                    in identifier = receiveQuery.query.requestedId;
                    out paper;
                }
                then action resolveData references resolver.resolveMetadata {
                    in identifier = receiveQuery.query.requestedId;
                    out paperMetadata;
                }
                then action analyzeImpact references analyzer.analyzeCitations {
                    in paperId = receiveQuery.query.requestedId;
                    out citationCount;
                    out influenceScore;
                }
                then action extractRefs references extractor.extractReferences {
                    in paperId = receiveQuery.query.requestedId;
                    out references;
                }
                then action createPaper {
                    in paperMetadata : PaperMetadata = resolveData.paperMetadata;
                    in refs : S2CID[*] = extractRefs.references;
                    out newPaper : AcademicPaper;
                }
                then action cachePaper references repository.storePaper {
                    in paper = createPaper.newPaper;
                }
                then action buildFreshResponse {
                    in freshPaper : AcademicPaper = createPaper.newPaper;
                    out response : QueryResponse;
                }
            }
            then awaitRequest;
            
            action handleInvalidQuery {
                action logInvalidRequest {
                    in invalidId : S2CID = receiveQuery.query.requestedId;
                    in validationError : ValidationResult = validateIdentifier.result;
                }
                then action returnErrorResponse {
                    out errorResponse : QueryResponse;
                }
            }
            then awaitRequest;
        }
    }
    
    requirement def FunctionalRequirements;
    requirement def PerformanceRequirements;
    requirement def DataQualityRequirements;
    
    requirement <'FR-001'> identifierResolution : FunctionalRequirements {
        doc /* System shall resolve valid S2CID identifiers to complete bibliographic metadata */
        subject system : 'S2CID Citation System';
    }
    
    requirement <'FR-002'> citationGraphConstruction : FunctionalRequirements {
        doc /* System shall construct bidirectional citation graphs including references and citations */
        subject system : 'S2CID Citation System';
    }
    
    requirement <'FR-003'> identifierValidation : FunctionalRequirements {
        doc /* System shall validate S2CID format and verify existence before processing */
        subject system : 'S2CID Citation System';
    }
    
    requirement <'PR-001'> queryResponseTime : PerformanceRequirements {
        doc /* System shall respond to queries within 3 seconds for cached entries */
        subject system : 'S2CID Citation System';
    }
    
    requirement <'PR-002'> throughput : PerformanceRequirements {
        doc /* System shall handle minimum 100 concurrent queries per second */
        subject system : 'S2CID Citation System';
    }
    
    requirement <'DQ-001'> metadataCompleteness : DataQualityRequirements {
        doc /* Resolved metadata shall include title, authors, year, and venue information */
        subject system : 'S2CID Citation System';
    }
    
    requirement <'DQ-002'> citationAccuracy : DataQualityRequirements {
        doc /* Citation counts shall be updated within 24 hours of new citations */
        subject system : 'S2CID Citation System';
    }
    
    requirement systemMission {
        doc /* 
            The S2CID Citation System shall provide a comprehensive platform for 
            academic literature discovery and analysis by enabling researchers to 
            reliably resolve Semantic Scholar Corpus IDs to complete bibliographic 
            records, navigate citation networks, assess research impact through 
            influence metrics, and support evidence-based literature review and 
            knowledge synthesis workflows.
        */
        
        require identifierResolution;
        require citationGraphConstruction;
        require identifierValidation;
        require queryResponseTime;
        require throughput;
        require metadataCompleteness;
        require citationAccuracy;
    }
}
