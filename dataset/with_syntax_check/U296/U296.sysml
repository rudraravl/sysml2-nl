package 'Medical Encyclopedia System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def ArticleID;
    attribute def UserID;
    attribute def SearchTerm;
    attribute def CategoryName;
    attribute def ConfidenceScore;
    
    item def ArticleMetadata {
        attribute id : ArticleID;
        attribute title : String;
        attribute category : CategoryName;
        attribute lastReviewed : String;
        attribute medicalAccuracy : ConfidenceScore;
        attribute readingLevel : Integer;
    }
    
    item def SearchQuery {
        attribute terms : SearchTerm[1..*];
        attribute filters : CategoryName[0..*];
        attribute maxResults : Integer;
    }
    
    item def SearchResults {
        attribute matches : ArticleMetadata[0..*] ordered;
        attribute totalFound : Integer;
        attribute relevanceScores : ConfidenceScore[0..*];
    }
    
    item def MedicalArticle {
        attribute metadata : ArticleMetadata;
        attribute content : String;
        attribute references : String[0..*];
        attribute relatedArticles : ArticleID[0..*];
        attribute illustrations : String[0..*];
        attribute lastUpdated : String;
    }
    
    port def QueryPort {
        in searchQuery : SearchQuery;
        out searchResults : SearchResults;
    }
    
    port def ContentPort {
        in articleRequest : ArticleID;
        out article : MedicalArticle;
    }
    
    port def DataPort {
        in query : SearchQuery;
        out matches : ArticleMetadata[0..*];
        in retrieveRequest : ArticleID;
        out retrievedArticle : MedicalArticle;
    }
    
    port def UpdatePort {
        in newArticle : MedicalArticle;
        in updateRequest : MedicalArticle;
        out updateStatus : Boolean;
    }
    
    part def UserInterfaceModule {
        port queryPort : QueryPort;
        port contentPort : ContentPort;
        
        action displaySearchInterface {
            out query : SearchQuery;
        }
        
        action presentSearchResults {
            in results : SearchResults;
        }
        
        action displayArticle {
            in article : MedicalArticle;
        }
    }
    
    part def SearchModule {
        port inputPort : ~QueryPort;
        port dataAccessPort : DataPort;
        
        action processQuery {
            in query : SearchQuery;
            out processedQuery : SearchQuery;
        }
        
        action rankResults {
            in rawMatches : ArticleMetadata[0..*];
            in originalQuery : SearchQuery;
            out rankedResults : SearchResults;
        }
    }
    
    part def ContentDatabase {
        port accessPort : ~DataPort;
        port updatePort : ~UpdatePort;
        
        attribute articles : MedicalArticle[0..*];
        attribute index : ArticleMetadata[0..*];
        
        action searchArticles {
            in criteria : SearchQuery;
            out matches : ArticleMetadata[0..*];
        }
        
        action retrieveArticle {
            in id : ArticleID;
            out article : MedicalArticle;
        }
        
        action storeArticle {
            in article : MedicalArticle;
            out success : Boolean;
        }
    }
    
    part def ContentReviewModule {
        port reviewPort : UpdatePort;
        port databasePort : ~DataPort;
        
        action validateArticle {
            in article : MedicalArticle;
            out isValid : Boolean;
            out validationReport : String;
        }
        
        action approveUpdate {
            in article : MedicalArticle;
            out approved : Boolean;
        }
    }
    
    action def ProvideInformation {
        in userQuery : SearchQuery;
        out information : MedicalArticle;
        out results : SearchResults;
        
        first start;
        then action parseQuery {
            in query = userQuery;
            out parsedQuery : SearchQuery;
        }
        then action searchDatabase {
            in searchCriteria = parseQuery.parsedQuery;
            out foundArticles : ArticleMetadata[0..*];
        }
        then action rankMatches {
            in matches = searchDatabase.foundArticles;
            in query = parseQuery.parsedQuery;
            out rankedResults : SearchResults;
        }
        then assign results := rankMatches.rankedResults;
        then action selectArticle {
            in topResult : ArticleMetadata;
            out selectedID : ArticleID;
        }
        then action retrieveContent {
            in articleID = selectArticle.selectedID;
            out fullArticle : MedicalArticle;
        }
        then assign information := retrieveContent.fullArticle;
        then done;
    }
    
    part medicalEncyclopedia {
        doc /* 
            The Medical Encyclopedia System provides comprehensive, 
            evidence-based medical information to users through an 
            integrated search and content delivery platform.
        */
        
        part ui : UserInterfaceModule {
            perform action handleUserRequests;
        }
        
        part search : SearchModule {
            perform action executeSearchOperations;
        }
        
        part database : ContentDatabase {
            perform action manageContent;
        }
        
        part reviewer : ContentReviewModule {
            perform action maintainQuality;
        }
        
        connect ui.queryPort to search.inputPort;
        connect search.dataAccessPort to database.accessPort;
        connect reviewer.reviewPort to database.updatePort;
        
        perform action provideInformation : ProvideInformation {
            first start;
            then merge awaitRequest;
            then accept incomingRequest : SearchQuery;
            then action processSearch {
                action normalizeQuery {
                    in rawQuery = incomingRequest;
                    out normalized : SearchQuery;
                }
                then action queryDatabase {
                    in searchTerms = normalizeQuery.normalized;
                    out matches : ArticleMetadata[0..*];
                }
                then action computeRelevance {
                    in results = queryDatabase.matches;
                    in originalQuery = normalizeQuery.normalized;
                    out scored : SearchResults;
                }
                then action deliverResults {
                    in results = computeRelevance.scored;
                }
            }
            then decide;
                if processSearch.deliverResults.results.totalFound > 0 then retrieveArticle;
                else awaitRequest;
            
            action retrieveArticle {
                in selectedID : ArticleID;
                action fetchArticle {
                    in id = selectedID;
                    out article : MedicalArticle;
                }
                then action displayArticle {
                    in article = fetchArticle.article;
                }
            }
            then awaitRequest;
        }
        
        action handleUserRequests {
            loop {
                accept requestInput : SearchQuery;
                then decide;
                    if requestInput.terms->size() > 0 then processSearch;
                    else retrieveContent;
                
                action processSearch {
                    in query : SearchQuery;
                    out results : SearchResults;
                }
                then done;
                
                action retrieveContent {
                    in articleID : ArticleID;
                    out content : MedicalArticle;
                }
                then done;
            }
        }
        
        action executeSearchOperations {
            first start;
            then action receiveQuery {
                in query : SearchQuery;
            }
            then action expandQuery {
                in original : SearchQuery;
                out expanded : SearchQuery;
            }
            then action searchIndex {
                in criteria = expandQuery.expanded;
                out matches : ArticleMetadata[0..*];
            }
            then action rankByRelevance {
                in candidates = searchIndex.matches;
                in query = expandQuery.expanded;
                out ranked : SearchResults;
            }
            then action returnResults {
                in results = rankByRelevance.ranked;
            }
            then done;
        }
        
        action manageContent {
            loop {
                accept operationRequest : SearchQuery;
                then decide;
                    if operationRequest.maxResults > 0 then handleSearch;
                    else handleRetrieval;
                
                action handleSearch {
                    in criteria : SearchQuery;
                    out results : ArticleMetadata[0..*];
                }
                then done;
                
                action handleRetrieval {
                    in id : ArticleID;
                    out article : MedicalArticle;
                }
                then done;
                
                action handleUpdate {
                    in article : MedicalArticle;
                    out success : Boolean;
                }
                then done;
            }
        }
        
        action maintainQuality {
            loop {
                accept articleSubmission : MedicalArticle;
                then action validateMedicalAccuracy {
                    in content = articleSubmission;
                    out isAccurate : Boolean;
                    out report : String;
                }
                then decide;
                    if validateMedicalAccuracy.isAccurate then approveArticle;
                    else rejectArticle;
                
                action approveArticle {
                    in article = articleSubmission;
                    out approved : Boolean;
                }
                then action publishArticle {
                    in article = articleSubmission;
                }
                then done;
                
                action rejectArticle {
                    in article = articleSubmission;
                    in reason = validateMedicalAccuracy.report;
                }
                then done;
            }
        }
    }
    
    requirement def SystemRequirement;
    
    requirement <'MES-REQ-001'> comprehensiveCoverage : SystemRequirement {
        doc /* 
            The medical encyclopedia shall provide comprehensive coverage 
            of medical topics including diseases, treatments, anatomy, 
            medications, diagnostic procedures, and preventive care.
        */
        
        subject system : medicalEncyclopedia;
    }
    
    requirement <'MES-REQ-002'> medicalAccuracy : SystemRequirement {
        doc /* 
            All medical content shall be reviewed and validated by 
            qualified medical professionals and based on peer-reviewed 
            scientific literature.
        */
        
        subject reviewer : medicalEncyclopedia.reviewer;
    }
    
    requirement <'MES-REQ-003'> searchPerformance : SystemRequirement {
        doc /* 
            The system shall return relevant search results within 
            2 seconds for 95% of user queries under normal load.
        */
        
        subject searchModule : medicalEncyclopedia.search;
    }
    
    requirement <'MES-REQ-004'> contentFreshness : SystemRequirement {
        doc /* 
            Medical content shall be reviewed and updated at least 
            annually to reflect current medical knowledge and standards.
        */
        
        subject db : medicalEncyclopedia.database;
    }
    
    requirement <'MES-REQ-005'> accessibility : SystemRequirement {
        doc /* 
            The system shall present medical information at appropriate 
            reading levels for general public understanding while 
            maintaining medical accuracy.
        */
        
        subject userInterface : medicalEncyclopedia.ui;
    }
    
    requirement missionRequirement {
        doc /* 
            The Medical Encyclopedia System shall provide users with 
            accurate, comprehensive, and accessible medical information 
            to support informed health decisions and medical education.
        */
        
        require comprehensiveCoverage;
        require medicalAccuracy;
        require searchPerformance;
        require contentFreshness;
        require accessibility;
    }
}
