package HomeAutomationArticleIndexSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import RiskMetadata::*;
    private import ModelingMetadata::*;
    private import SequenceFunctions::*;
    
    attribute def RelevanceScore :> Real {
        assert constraint { that >= 0.0 and that <= 1.0 }
    }
    
    attribute def ArticleCount :> Integer {
        assert constraint { that >= 0 }
    }
    
    enum def IndexStatus {
        initializing;
        ready;
        updating;
        searching;
        error;
    }
    
    enum def ArticleCategory {
        lighting;
        climate;
        security;
        energy;
        integration;
        sensors;
    }
    
    item def Article {
        attribute articleId : String;
        attribute title : String;
        attribute content : String;
        attribute author : String;
        attribute category : ArticleCategory;
        attribute publishDate : TimeValue;
        attribute keywords : String[1..*];
        attribute url : String;
    }
    
    item def SearchQuery {
        attribute queryText : String;
        attribute categoryFilter : ArticleCategory[0..*];
        attribute dateFrom : TimeValue[0..1];
        attribute dateTo : TimeValue[0..1];
        attribute maxResults : Integer;
    }
    
    item def SearchResult {
        attribute article : Article;
        attribute relevanceScore : RelevanceScore;
        attribute matchedKeywords : String[0..*];
    }
    
    item def IndexMetrics {
        attribute totalArticles : ArticleCount;
        attribute lastUpdateTime : TimeValue;
        attribute averageRelevance : RelevanceScore;
        attribute categoryCounts : ArticleCount[6];
    }
    
    item def UpdateNotification {
        attribute newArticles : Article[1..*];
        attribute timestamp : TimeValue;
        attribute updateSource : String;
    }
    
    port def ArticleInputPort {
        in item newArticle : Article;
    }
    
    port def SearchPort {
        in item query : SearchQuery;
        out item results : SearchResult[0..*];
    }
    
    port def MetricsPort {
        out item metrics : IndexMetrics;
    }
    
    port def NotificationPort {
        out item notification : UpdateNotification;
    }
    
    part def ArticleCrawler {
        attribute crawlInterval : DurationValue;
        attribute sourceFeedUrls : String[1..*];
        port articleOutput : ArticleInputPort;
        
        action def CrawlSources {
            in feedUrls : String[1..*];
            out discoveredArticles : Article[0..*] := ( );
            
            for feedUrl in feedUrls {
                action fetchFeed {
                    in url : String = feedUrl;
                    out articles : Article[0..*];
                }
                then assign discoveredArticles := discoveredArticles->including(fetchFeed.articles);
            }
        }
        
        perform action crawlCycle[*] ordered;
    }
    
    part def IndexEngine {
        attribute indexedArticles : Article[0..*] := ( );
        attribute invertedIndex : String[0..*];
        attribute currentStatus : IndexStatus := IndexStatus::initializing;
        port articleInput : ArticleInputPort;
        port searchInterface : SearchPort;
        port metricsOutput : MetricsPort;
        
        action def AddArticleToIndex {
            in article : Article;
            inout currentIndex : Article[0..*];
            out updatedIndex : Article[0..*];
            
            assign updatedIndex := currentIndex->including(article);
        }
        
        action def SearchIndex {
            in query : SearchQuery;
            in articles : Article[0..*];
            out results : SearchResult[0..*] := ( );
            
            private attribute matchedArticles : Article[0..*] := ( );
            
            for article in articles {
                action evaluateMatch {
                    in candidate : Article = article;
                    in searchQuery : SearchQuery = query;
                    out isMatch : Boolean;
                    out score : RelevanceScore;
                }
                
                if evaluateMatch.isMatch then addResult;
                
                action addResult {
                    private attribute newResult : SearchResult {
                        attribute article = article;
                        attribute relevanceScore = evaluateMatch.score;
                        attribute matchedKeywords = article.keywords;
                    }
                    assign results := results->including(newResult);
                }
            }
            
            action sortResults {
                in unsortedResults : SearchResult[0..*] = results;
                out sortedResults : SearchResult[0..*];
            }
            
            then assign results := sortResults.sortedResults;
        }
        
        action def ComputeMetrics {
            in articles : Article[0..*];
            out metrics : IndexMetrics;
            
            assign metrics.totalArticles := articles->size();
        }
    }
    
    part def NotificationManager {
        attribute subscribers : String[0..*];
        port notificationOutput : NotificationPort;
        
        action def GenerateNotification {
            in articles : Article[1..*];
            out notification : UpdateNotification;
            
            assign notification.newArticles := articles;
        }
        
        action def DistributeNotifications {
            in notification : UpdateNotification;
            in subscriberList : String[0..*];
            
            for subscriber in subscriberList {
                action sendNotification {
                    in recipient : String = subscriber;
                    in message : UpdateNotification = notification;
                }
            }
        }
    }
    
    part def UserInterface {
        port searchInput : SearchPort;
        port metricsDisplay : MetricsPort;
        port notificationReceiver : NotificationPort;
        
        action def SubmitQuery {
            in userInput : String;
            out query : SearchQuery;
        }
        
        action def DisplayResults {
            in results : SearchResult[0..*];
        }
        
        action def ShowMetrics {
            in metrics : IndexMetrics;
        }
    }
    
    part def CacheManager {
        attribute cacheSize : Integer;
        attribute cachedQueries : SearchQuery[0..*];
        attribute cachedResults : SearchResult[0..*];
        
        action def CheckCache {
            in query : SearchQuery;
            out hit : Boolean;
            out cachedResult : SearchResult[0..*];
        }
        
        action def UpdateCache {
            in query : SearchQuery;
            in results : SearchResult[0..*];
        }
    }
    
    part def ArticleIndexSystem {
        part crawler : ArticleCrawler {
            attribute crawlInterval = 3600.0[s];
        }
        
        part indexEngine : IndexEngine;
        
        part notificationMgr : NotificationManager;
        
        part userInterface : UserInterface;
        
        part cache : CacheManager {
            attribute cacheSize = 1000;
        }
        
        connection crawlerToIndex connect 
            crawler.articleOutput to indexEngine.articleInput;
        
        connection userToIndex connect 
            userInterface.searchInput to indexEngine.searchInterface;
        
        connection indexToMetrics connect 
            indexEngine.metricsOutput to userInterface.metricsDisplay;
        
        connection notificationToUser connect 
            notificationMgr.notificationOutput to userInterface.notificationReceiver;
        
        action def OperateIndexSystem {
            first start;
            then merge continuousOperation;
            
            action crawlAndIndex {
                action crawl : ArticleCrawler::CrawlSources {
                    in feedUrls = crawler.sourceFeedUrls;
                    out discoveredArticles;
                }
                
                then action indexArticles {
                    for article in crawl.discoveredArticles {
                        action addToIndex : IndexEngine::AddArticleToIndex {
                            in article = article;
                            inout currentIndex = indexEngine.indexedArticles;
                            out updatedIndex;
                        }
                        then assign indexEngine.indexedArticles := addToIndex.updatedIndex;
                    }
                }
                
                then action notify : NotificationManager::GenerateNotification {
                    in articles = crawl.discoveredArticles;
                    out notification;
                }
            }
            then continuousOperation;
            
            then action handleUserQuery {
                action receiveQuery : UserInterface::SubmitQuery {
                    in userInput;
                    out query;
                }
                
                then action checkCache : CacheManager::CheckCache {
                    in query = receiveQuery.query;
                    out hit;
                    out cachedResult;
                }
                
                then decide;
                    if checkCache.hit then returnCached;
                    else performSearch;
                
                action returnCached {
                    action display : UserInterface::DisplayResults {
                        in results = checkCache.cachedResult;
                    }
                }
                then continuousOperation;
                
                action performSearch {
                    action search : IndexEngine::SearchIndex {
                        in query = receiveQuery.query;
                        in articles = indexEngine.indexedArticles;
                        out results;
                    }
                    
                    then action updateCache : CacheManager::UpdateCache {
                        in query = receiveQuery.query;
                        in results = search.results;
                    }
                    
                    then action displayResults : UserInterface::DisplayResults {
                        in results = search.results;
                    }
                }
                then continuousOperation;
            }
            then continuousOperation;
        }
        
        perform action systemOperation[*] ordered references OperateIndexSystem;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def UsabilityRequirement;
    
    requirement <'IDX-001'> primaryFunction : FunctionalRequirement {
        doc /* The Article Index System shall maintain a searchable index of home automation 
                articles, enabling users to discover relevant content through keyword-based queries, 
                category filtering, and date-range searches while providing automated notifications 
                for newly indexed articles. */
        
        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = RiskLevelEnum::medium;
                technicalRisk = RiskLevelEnum::medium;
                scheduleRisk = RiskLevelEnum::low;
                costRisk = RiskLevelEnum::medium;
            }
            originator = "Product Manager";
            owner = "System Architect";
        }
        
        require indexingCapability;
        require searchCapability;
        require notificationCapability;
    }
    
    requirement <'IDX-002'> indexingCapability : FunctionalRequirement {
        doc /* The system shall automatically crawl configured article sources at regular intervals 
                and add discovered articles to the searchable index within 5 minutes of publication. */
        
        subject crawler;
        
        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = RiskLevelEnum::low;
                technicalRisk = RiskLevelEnum::low;
                scheduleRisk = RiskLevelEnum::low;
                costRisk = RiskLevelEnum::low;
            }
            owner = "Backend Team Lead";
        }
    }
    
    requirement <'IDX-003'> searchCapability : FunctionalRequirement {
        doc /* The system shall return relevant search results ranked by relevance score 
                within 500 milliseconds for queries against an index of up to 100,000 articles. */
        
        subject indexEngine;
        
        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = RiskLevelEnum::high;
                technicalRisk = RiskLevelEnum::high;
                scheduleRisk = RiskLevelEnum::medium;
                costRisk = RiskLevelEnum::medium;
            }
            owner = "Search Team Lead";
        }
    }
    
    requirement <'IDX-004'> notificationCapability : FunctionalRequirement {
        doc /* The system shall generate and distribute notifications to subscribed users 
                within 1 minute of indexing new articles matching their interest profiles. */
        
        subject notificationMgr;
        
        @StatusInfo {
            status = StatusKind::inReview;
            risk {
                totalRisk = RiskLevelEnum::medium;
                technicalRisk = RiskLevelEnum::medium;
                scheduleRisk = RiskLevelEnum::low;
                costRisk = RiskLevelEnum::low;
            }
            owner = "Notification Team Lead";
        }
    }
    
    requirement <'IDX-005'> cachePerformance : PerformanceRequirement {
        doc /* The cache shall maintain a hit rate of at least 70% for repeated queries 
                to minimize index search operations and improve response time. */
        
        subject cache;
        
        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = RiskLevelEnum::low;
                technicalRisk = RiskLevelEnum::low;
                scheduleRisk = RiskLevelEnum::low;
                costRisk = RiskLevelEnum::low;
            }
            owner = "Performance Engineer";
        }
    }
    
    requirement <'IDX-006'> userExperience : UsabilityRequirement {
        doc /* The user interface shall provide intuitive search controls with real-time 
                suggestions and display results with clear relevance indicators and article previews. */
        
        subject userInterface;
        
        @StatusInfo {
            status = StatusKind::approved;
            risk {
                totalRisk = RiskLevelEnum::medium;
                technicalRisk = RiskLevelEnum::low;
                scheduleRisk = RiskLevelEnum::low;
                costRisk = RiskLevelEnum::medium;
            }
            owner = "UX Team Lead";
        }
    }
    
    part indexSystemInstance : ArticleIndexSystem {
        satisfy primaryFunction by indexSystemInstance;
        satisfy indexingCapability by crawler;
        satisfy searchCapability by indexEngine;
        satisfy notificationCapability by notificationMgr;
        satisfy cachePerformance by cache;
        satisfy userExperience by userInterface;
    }
}
