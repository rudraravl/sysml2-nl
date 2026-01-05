package RoboticsArticleIndexSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def ArticleID :> String;
    attribute def Keyword :> String;
    attribute def RelevanceScore :> Real {
        assert constraint { 0.0 <= that and that <= 1.0 }
    }
    attribute def IndexSize :> Integer;
    attribute def QueryLatency :> DurationValue;

    enum def ArticleCategory {
        industrialAutomation;
        mobileRobotics;
        manipulators;
        sensors;
        actuators;
        controlSystems;
        machineVision;
        artificialIntelligence;
        humanRobotInteraction;
        medicalRobotics;
        autonomousVehicles;
        swarmRobotics;
    }

    enum def IndexState {
        idle;
        indexing;
        querying;
        updating;
        optimizing;
        error;
    }

    item def Article {
        attribute id : ArticleID;
        attribute title : String;
        attribute authors : String[1..*];
        attribute category : ArticleCategory;
        attribute keywords : Keyword[1..*];
        attribute summary : String;
        attribute publicationDate : TimeInstantValue;
        attribute citationCount : Integer;
        attribute fullTextContent : String;
    }

    item def SearchQuery {
        attribute queryText : String;
        attribute keywords : Keyword[0..*];
        attribute categoryFilter : ArticleCategory[0..*];
        attribute maxResults : Integer = 50;
        attribute minRelevance : RelevanceScore = 0.3;
    }

    item def SearchResult {
        attribute article : Article;
        attribute relevanceScore : RelevanceScore;
        attribute matchedKeywords : Keyword[1..*];
        attribute snippets : String[0..*];
    }

    item def IndexEntry {
        attribute keyword : Keyword;
        attribute articleRefs : ArticleID[1..*];
        attribute termFrequency : Integer;
        attribute inverseDocFrequency : Real;
    }

    item def IndexStatistics {
        attribute totalArticles : Integer;
        attribute totalKeywords : Integer;
        attribute averageArticleLength : Integer;
        attribute indexSizeBytes : Integer;
        attribute lastUpdateTime : TimeInstantValue;
    }

    port def ArticleIngestionPort {
        in item newArticle : Article;
        out item ingestionStatus : Boolean;
    }

    port def QueryPort {
        in item query : SearchQuery;
        out item results : SearchResult[0..*];
        out item queryLatency : QueryLatency;
    }

    port def IndexManagementPort {
        in item rebuildCommand : Boolean;
        out item statistics : IndexStatistics;
        out item currentState : IndexState;
    }

    port def UpdateNotificationPort {
        out item updatedArticles : Article[0..*];
        out item updateTimestamp : TimeInstantValue;
    }

    part def ArticleRepository {
        attribute capacity : Integer = 500000;
        attribute currentCount : Integer = 0;
        attribute storageUtilization : Real;

        port ingestionPort : ArticleIngestionPort;
        port managementPort : IndexManagementPort;

        part storage {
            attribute articles : Article[0..*] ordered;
            attribute articlesByCategory : Article[0..*];
            attribute articlesByDate : Article[0..*] ordered;
        }

        action storeArticle {
            in article : Article;
            out success : Boolean;
            out updatedCount : Integer;
        }

        action retrieveArticle {
            in articleId : ArticleID;
            out article : Article;
        }

        action retrieveByCategory {
            in category : ArticleCategory;
            out articles : Article[0..*];
        }

        action getStatistics {
            out stats : IndexStatistics;
        }

        assert constraint capacityLimit {
            currentCount <= capacity
        }
    }

    part def InvertedIndexEngine {
        attribute indexedTermCount : Integer = 0;
        attribute indexingRate : Real = 5000.0;
        attribute compressionRatio : Real = 0.4;

        port ingestionPort : ArticleIngestionPort;
        port managementPort : IndexManagementPort;

        part indexStore {
            attribute invertedIndex : IndexEntry[0..*];
            attribute keywordMap : IndexEntry[0..*];
            attribute categoryIndex : IndexEntry[0..*];
        }

        action buildIndex {
            in article : Article;
            out indexEntries : IndexEntry[1..*];
        }

        action updateIndex {
            in article : Article;
            out modified : Boolean;
        }

        action optimizeIndex {
            inout indices : IndexEntry[0..*];
            out compressionAchieved : Real;
        }

        action lookupKeyword {
            in keyword : Keyword;
            out entries : IndexEntry[0..*];
        }

        state indexingStateMachine {
            entry; then idle;

            state idle {
                entry; 
            }

            state indexing {
                entry; do buildIndex;
            }

            state updating {
                entry; do updateIndex;
            }

            state optimizing {
                entry; do optimizeIndex;
            }

            state error;

            transition idle_to_indexing
                first idle
                accept at ingestionPort.newArticle
                then indexing;

            transition indexing_to_updating
                first indexing
                if indexedTermCount > 50000
                then updating;

            transition indexing_to_idle
                first indexing
                if indexedTermCount <= 50000
                then idle;

            transition updating_to_optimizing
                first updating
                then optimizing;

            transition optimizing_to_idle
                first optimizing
                then idle;

            transition any_to_error
                first idle
                then error;

            transition error_to_idle
                first error
                then idle;
        }
    }

    part def SearchEngine {
        attribute maxConcurrentQueries : Integer = 100;
        attribute averageQueryTime : QueryLatency = 0.8 [s];
        attribute cacheHitRate : Real = 0.65;

        port queryPort : QueryPort;
        port managementPort : IndexManagementPort;

        part queryProcessor {
            attribute activeQueries : Integer = 0;
        }

        part resultCache {
            attribute cachedResults : SearchResult[0..*];
            attribute cacheSize : Integer = 10000;
        }

        action parseQuery {
            in query : SearchQuery;
            out keywords : Keyword[1..*];
            out filters : ArticleCategory[0..*];
        }

        action executeSearch {
            in keywords : Keyword[1..*];
            in indexEntries : IndexEntry[0..*];
            out candidateArticles : Article[0..*];
        }

        action rankResults {
            in candidates : Article[0..*];
            in query : SearchQuery;
            out rankedResults : SearchResult[0..*];
        }

        action filterByRelevance {
            in results : SearchResult[0..*];
            in threshold : RelevanceScore;
            out filtered : SearchResult[0..*];
        }

        action cacheResults {
            in query : SearchQuery;
            in results : SearchResult[0..*];
        }

        assert constraint performanceTarget {
            averageQueryTime <= 2.0 [s]
        }

        assert constraint concurrencyLimit {
            queryProcessor.activeQueries <= maxConcurrentQueries
        }
    }

    part def CategoryClassifier {
        attribute classificationAccuracy : Real = 0.92;
        attribute supportedCategories : Integer = 12;

        action classifyArticle {
            in article : Article;
            out category : ArticleCategory;
            out confidence : Real;
        }

        action extractKeywords {
            in text : String;
            out keywords : Keyword[1..*];
            out weights : Real[1..*];
        }

        action getCategoryStatistics {
            in category : ArticleCategory;
            out articleCount : Integer;
            out averageCitations : Real;
            out topKeywords : Keyword[1..*];
        }
    }

    part def UpdateMonitor {
        attribute monitoringInterval : DurationValue = 300.0 [s];
        attribute lastCheckTime : TimeInstantValue;
        attribute changesDetected : Integer = 0;

        port notificationPort : UpdateNotificationPort;

        action detectChanges {
            in articles : Article[0..*];
            out changedArticles : Article[0..*];
        }

        action notifySubscribers {
            in updatedArticles : Article[0..*];
        }

        action scheduleNextCheck {
            in interval : DurationValue;
            out nextCheckTime : TimeInstantValue;
        }
    }

    part def RoboticsArticleIndexingSystem {
        attribute systemState : IndexState = IndexState::idle;
        attribute totalArticlesIndexed : Integer = 0;
        attribute totalQueriesProcessed : Integer = 0;
        attribute systemUptime : DurationValue;
        attribute averageQueryLatency : QueryLatency;

        port articleInput : ArticleIngestionPort;
        port searchInterface : QueryPort;
        port systemManagement : IndexManagementPort;
        port updateNotifications : UpdateNotificationPort;

        part repository : ArticleRepository {
            attribute :>> capacity = 500000;
            attribute :>> currentCount = 0;
        }

        part indexEngine : InvertedIndexEngine {
            attribute :>> indexingRate = 5000.0;
            attribute :>> compressionRatio = 0.4;
        }

        part searchEngine : SearchEngine {
            attribute :>> maxConcurrentQueries = 100;
            attribute :>> averageQueryTime = 0.8 [s];
        }

        part classifier : CategoryClassifier {
            attribute :>> classificationAccuracy = 0.92;
        }

        part monitor : UpdateMonitor {
            attribute :>> monitoringInterval = 300.0 [s];
        }

        connection articleIngestion connect
            articleInput to repository.ingestionPort;

        connection indexingPipeline connect
            repository.ingestionPort to indexEngine.ingestionPort;

        connection searchAccess connect
            searchInterface to searchEngine.queryPort;

        connection managementControl connect
            systemManagement to repository.managementPort;

        connection statusReporting connect
            indexEngine.managementPort to systemManagement;

        connection updateBroadcast connect
            monitor.notificationPort to updateNotifications;

        assert constraint repositoryCapacity {
            repository.currentCount <= repository.capacity
        }

        assert constraint queryPerformance {
            searchEngine.averageQueryTime <= 2.0 [s]
        }

        assert constraint indexingEfficiency {
            indexEngine.indexingRate >= 1000.0
        }
    }

    action def IngestAndIndexArticle {
        in article : Article;
        out indexed : Boolean;

        first start;

        then action validateArticle {
            in inputArticle : Article = article;
            out valid : Boolean;
            out validationErrors : String[0..*];
        }

        then decide;
            if validateArticle.valid then classify;
            if not validateArticle.valid then reject;

        action classify {
            in articleToClassify : Article = article;
            out category : ArticleCategory;
            out keywords : Keyword[1..*];
        }

        then action store {
            in validatedArticle : Article = article;
            out stored : Boolean;
        }

        then action index {
            in storedArticle : Article = article;
            out indexEntries : IndexEntry[1..*];
        }

        then action updateStatistics {
            in indexedArticle : Article = article;
        }

        then success;

        action reject;
        then failure;

        action success {
            out result : Boolean = true;
        }
        then done;

        action failure {
            out result : Boolean = false;
        }
        then done;
    }

    action def PerformSearch {
        in query : SearchQuery;
        out results : SearchResult[0..*];
        out latency : QueryLatency;

        first start;

        then action recordStartTime {
            out startTime : TimeInstantValue;
        }

        then action parseAndValidate {
            in searchQuery : SearchQuery = query;
            out keywords : Keyword[1..*];
            out filters : ArticleCategory[0..*];
            out valid : Boolean;
        }

        then decide;
            if parseAndValidate.valid then checkCache;
            if not parseAndValidate.valid then returnEmpty;

        action checkCache {
            in searchQuery : SearchQuery = query;
            out cached : SearchResult[0..*];
            out cacheHit : Boolean;
        }

        then decide;
            if checkCache.cacheHit then returnCached;
            if not checkCache.cacheHit then executeQuery;

        action executeQuery {
            in keywords : Keyword[1..*] = parseAndValidate.keywords;
            out candidateArticles : Article[0..*];
        }

        then action rankAndScore {
            in candidates : Article[0..*] = executeQuery.candidateArticles;
            in searchQuery : SearchQuery = query;
            out scoredResults : SearchResult[0..*];
        }

        then action filterResults {
            in allResults : SearchResult[0..*] = rankAndScore.scoredResults;
            in minRelevance : RelevanceScore = query.minRelevance;
            in maxCount : Integer = query.maxResults;
            out filteredResults : SearchResult[0..*];
        }

        then action updateCache {
            in searchQuery : SearchQuery = query;
            in resultsToCache : SearchResult[0..*] = filterResults.filteredResults;
        }

        then returnResults;

        action returnCached {
            out finalResults : SearchResult[0..*] = checkCache.cached;
        }
        then returnResults;

        action returnEmpty {
            out finalResults : SearchResult[0..*];
        }
        then returnResults;

        action returnResults {
            in finalResults : SearchResult[0..*];
            out queryLatency : QueryLatency;
        }

        then done;
    }

    requirement <'REQ-001'> primaryFunction {
        doc /* The Robotics Article Indexing System shall provide comprehensive
             * indexing, search, and retrieval capabilities for a large collection
             * of robotics-related technical articles, enabling users to efficiently
             * discover relevant research and documentation across multiple robotics
             * domains including industrial automation, mobile robotics, sensors,
             * actuators, control systems, and artificial intelligence applications.
             */
        subject system : RoboticsArticleIndexingSystem;
    }

    requirement <'REQ-002'> indexingCapacity {
        doc /* The system shall support indexing and storage of at least 500,000
             * robotics articles with efficient retrieval and update capabilities.
             */
        subject repository :> RoboticsArticleIndexingSystem::repository;
        assert constraint {
            repository.capacity >= 500000
        }
    }

    requirement <'REQ-003'> searchPerformance {
        doc /* The system shall return search results with an average query
             * latency not exceeding 2 seconds for 95% of queries.
             */
        subject searchEngine :> RoboticsArticleIndexingSystem::searchEngine;
        assert constraint {
            searchEngine.averageQueryTime <= 2.0 [s]
        }
    }

    requirement <'REQ-004'> categorySupport {
        doc /* The system shall support automatic classification of articles
             * into at least 12 distinct robotics categories with a minimum
             * classification accuracy of 90%.
             */
        subject classifier :> RoboticsArticleIndexingSystem::classifier;
        assert constraint {
            classifier.supportedCategories >= 12 and
            classifier.classificationAccuracy >= 0.90
        }
    }

    requirement <'REQ-005'> indexingThroughput {
        doc /* The indexing engine shall process at least 1000 articles per
             * unit time to support rapid ingestion of new content.
             */
        subject indexEngine :> RoboticsArticleIndexingSystem::indexEngine;
        assert constraint {
            indexEngine.indexingRate >= 1000.0
        }
    }

    requirement <'REQ-006'> updateMonitoring {
        doc /* The system shall monitor for article updates and notify
             * subscribers within 5 minutes of detecting changes.
             */
        subject monitor :> RoboticsArticleIndexingSystem::monitor;
        assert constraint {
            monitor.monitoringInterval <= 300.0 [s]
        }
    }

    requirement <'REQ-007'> concurrentAccess {
        doc /* The search engine shall support at least 100 concurrent
             * query operations without performance degradation.
             */
        subject searchEngine :> RoboticsArticleIndexingSystem::searchEngine;
        assert constraint {
            searchEngine.maxConcurrentQueries >= 100
        }
    }

    part roboticsIndexSystem : RoboticsArticleIndexingSystem {
        attribute :>> systemState = IndexState::idle;
        attribute :>> totalArticlesIndexed = 0;
        attribute :>> totalQueriesProcessed = 0;
        attribute :>> averageQueryLatency = 0.8 [s];

        part :>> repository {
            attribute :>> capacity = 500000;
            attribute :>> currentCount = 0;
        }

        part :>> indexEngine {
            attribute :>> indexedTermCount = 0;
            attribute :>> indexingRate = 5000.0;
        }

        part :>> searchEngine {
            attribute :>> maxConcurrentQueries = 100;
            attribute :>> averageQueryTime = 0.8 [s];
            attribute :>> cacheHitRate = 0.65;
        }

        part :>> classifier {
            attribute :>> classificationAccuracy = 0.92;
            attribute :>> supportedCategories = 12;
        }

        part :>> monitor {
            attribute :>> monitoringInterval = 300.0 [s];
            attribute :>> changesDetected = 0;
        }
    }

    satisfy primaryFunction by roboticsIndexSystem;
    satisfy indexingCapacity by roboticsIndexSystem.repository;
    satisfy searchPerformance by roboticsIndexSystem.searchEngine;
    satisfy categorySupport by roboticsIndexSystem.classifier;
    satisfy indexingThroughput by roboticsIndexSystem.indexEngine;
    satisfy updateMonitoring by roboticsIndexSystem.monitor;
    satisfy concurrentAccess by roboticsIndexSystem.searchEngine;
}
