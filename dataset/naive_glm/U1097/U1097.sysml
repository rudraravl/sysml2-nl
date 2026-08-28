package HomeAutomationArticleIndexSystem {

    import ScalarValues::*;

    // ===== Value Types =====

    value def CountValue :> Integer {
        doc "A count of items, dimensionless.";
    }

    value def RelevanceScore :> Real {
        doc "A relevance score in the range [0.0, 1.0].";
    }

    value def DurationValue :> Real {
        doc "A duration measured in seconds.";
    }

    value def RatioValue :> Real {
        doc "A ratio in the range [0.0, 1.0].";
    }

    attribute def ArticleId :> String;
    attribute def Keyword :> String;
    attribute def Url :> String;
    attribute def UserId :> String;
    attribute def DateString :> String;

    // ===== Enumerations =====

    enum def ArticleCategory {
        enum lighting;
        enum climateControl;
        enum security;
        enum energyManagement;
    }

    enum def IndexEngineStatus {
        enum initializing;
        enum idle;
        enum updating;
        enum searching;
    }

    enum def CrawlerStatus {
        enum idle;
        enum scanning;
        enum error;
    }

    enum def CacheStatus {
        enum empty;
        enum populated;
        enum full;
    }

    // ===== Item Types =====

    item def Article {
        attribute id : ArticleId;
        attribute title : String;
        attribute url : Url;
        attribute category : ArticleCategory;
        attribute publicationDate : DateString;
        attribute summary : String;
        attribute keywords : Keyword[0..*];
    }

    item def SearchQuery {
        attribute queryId : String;
        attribute keywords : Keyword[0..*];
        attribute categoryFilter : ArticleCategory[0..1];
        attribute dateFrom : DateString[0..1];
        attribute dateTo : DateString[0..1];
    }

    item def SearchResult {
        attribute queryId : String;
        attribute article : Article;
        attribute score : RelevanceScore;
    }

    item def SearchResultList {
        attribute queryId : String;
        attribute results : SearchResult[0..*];
        attribute totalArticles : CountValue;
    }

    item def Notification {
        attribute notificationId : String;
        attribute userId : UserId;
        attribute message : String;
        attribute article : Article;
    }

    item def SystemMetrics {
        attribute totalArticles : CountValue;
        attribute totalCategories : CountValue;
        attribute lastUpdate : DateString;
        attribute cacheHitRatio : RatioValue;
    }

    // ===== Port Definitions =====

    port def ArticleOutPort {
        out article : Article[0..*];
    }

    port def ArticleInPort {
        in article : Article[0..*];
    }

    port def QueryInPort {
        in query : SearchQuery;
    }

    port def QueryOutPort {
        out query : SearchQuery;
    }

    port def ResultOutPort {
        out results : SearchResultList;
    }

    port def ResultInPort {
        in results : SearchResultList;
    }

    port def CacheRequestPort {
        in query : SearchQuery;
        out cachedResults : SearchResultList[0..1];
    }

    port def NotificationOutPort {
        out notification : Notification[0..*];
    }

    port def NotificationInPort {
        in notification : Notification[0..*];
    }

    port def MetricsOutPort {
        out metrics : SystemMetrics;
    }

    port def MetricsInPort {
        in metrics : SystemMetrics;
    }

    // ===== Part Definitions =====

    part def ArticleCrawler {
        port articleOut : ArticleOutPort;
        attribute status : CrawlerStatus = CrawlerStatus::idle;
        attribute sources : Url[0..*];
        attribute scanInterval : DurationValue = 3600;
        attribute articlesDiscovered : CountValue = 0;

        action def ScanSources {
            in sources : Url[0..*];
            out discovered : Article[0..*];
        }

        action def ExtractMetadata {
            in rawContent : String;
            out article : Article;
        }

        action def CategorizeArticle {
            in article : Article;
            out category : ArticleCategory;
        }

        state crawlerBehavior {
            initial idle;
            state idle {
                entry { status = CrawlerStatus::idle; }
            }
            state scanning {
                entry { status = CrawlerStatus::scanning; }
            }
            state error {
                entry { status = CrawlerStatus::error; }
            }
            transition first idle then scanning;
            transition first scanning then idle;
            transition first scanning then error;
            transition first error then idle;
        }
    }

    part def IndexEngine {
        port articleIn : ArticleInPort;
        port queryIn : QueryInPort;
        port resultOut : ResultOutPort;
        port metricsOut : MetricsOutPort;
        attribute status : IndexEngineStatus = IndexEngineStatus::initializing;
        attribute articleCount : CountValue = 0;
        attribute categoryCount : CountValue = 4;

        action def ProcessQuery {
            in query : SearchQuery;
            out results : SearchResultList;
        }

        action def UpdateIndex {
            in articles : Article[0..*];
        }

        action def RankResults {
            in articles : Article[0..*];
            in query : SearchQuery;
            out ranked : SearchResult[0..*];
        }

        action def ComputeMetrics {
            out metrics : SystemMetrics;
        }

        state engineBehavior {
            initial initializing;
            state initializing {
                entry { status = IndexEngineStatus::initializing; }
            }
            state idle {
                entry { status = IndexEngineStatus::idle; }
            }
            state updating {
                entry { status = IndexEngineStatus::updating; }
            }
            state searching {
                entry { status = IndexEngineStatus::searching; }
            }
            transition first initializing then idle;
            transition first idle then updating;
            transition first updating then idle;
            transition first idle then searching;
            transition first searching then idle;
        }
    }

    part def CacheManager {
        port cacheRequest : CacheRequestPort;
        port queryOut : QueryOutPort;
        port resultIn : ResultInPort;
        port resultOut : ResultOutPort;
        attribute cacheSize : CountValue = 100;
        attribute entryCount : CountValue = 0;
        attribute hitCount : CountValue = 0;
        attribute missCount : CountValue = 0;
        attribute status : CacheStatus = CacheStatus::empty;

        action def CheckCache {
            in query : SearchQuery;
            out cachedResult : SearchResultList[0..1];
        }

        action def StoreResult {
            in query : SearchQuery;
            in results : SearchResultList;
        }

        action def EvictOldest {
            doc "Remove the least recently used cache entry when cache is full.";
        }

        action def ComputeHitRatio {
            out ratio : RatioValue;
        }

        state cacheBehavior {
            initial empty;
            state empty {
                entry { status = CacheStatus::empty; }
            }
            state populated {
                entry { status = CacheStatus::populated; }
            }
            state full {
                entry { status = CacheStatus::full; }
            }
            transition first empty then populated;
            transition first populated then full;
            transition first full then populated;
            transition first populated then empty;
        }
    }

    part def UserInterface {
        port queryOut : QueryOutPort;
        port resultIn : ResultInPort;
        port metricsIn : MetricsInPort;
        port notificationIn : NotificationInPort;
        attribute activeUsers : CountValue = 0;
        attribute displayedResults : CountValue = 0;

        action def SubmitQuery {
            out query : SearchQuery;
        }

        action def DisplayResults {
            in results : SearchResultList;
        }

        action def DisplayMetrics {
            in metrics : SystemMetrics;
        }

        action def FilterByCategory {
            in category : ArticleCategory;
            in results : SearchResultList;
            out filtered : SearchResultList;
        }

        action def FilterByDate {
            in dateFrom : DateString;
            in dateTo : DateString;
            in results : SearchResultList;
            out filtered : SearchResultList;
        }

        action def ShowNotification {
            in notification : Notification;
        }
    }

    part def NotificationManager {
        port articleIn : ArticleInPort;
        port notificationOut : NotificationOutPort;
        attribute subscribedUsers : UserId[0..*];
        attribute notificationsSent : CountValue = 0;

        action def GenerateNotification {
            in article : Article;
            out notification : Notification;
        }

        action def DistributeNotification {
            in notification : Notification;
            in users : UserId[0..*];
        }

        action def SubscribeUser {
            in userId : UserId;
        }

        action def UnsubscribeUser {
            in userId : UserId;
        }

        state notificationBehavior {
            initial waiting;
            state waiting;
            state generating {
                entry { /* generate notification for new article */ }
            }
            state distributing {
                entry { /* distribute to subscribed users */ }
            }
            transition first waiting then generating;
            transition first generating then distributing;
            transition first distributing then waiting;
        }
    }

    // ===== System Definition =====

    part def HomeAutomationArticleIndexSystem {
        port externalQueryIn : QueryInPort;
        port externalResultOut : ResultOutPort;
        port externalNotificationOut : NotificationOutPort;

        part crawler : ArticleCrawler {
            attribute sources : Url[0..*] = [
                "https://smarthome.example.com/feed",
                "https://iotnews.example.com/rss",
                "https://homeautomation.example.com/articles"
            ];
        }
        part indexEngine : IndexEngine;
        part cacheManager : CacheManager;
        part userInterface : UserInterface;
        part notificationManager : NotificationManager;

        connection articleToIndex
            connect crawler.articleOut to indexEngine.articleIn;
        connection articleToNotifier
            connect crawler.articleOut to notificationManager.articleIn;
        connection queryToCache
            connect userInterface.queryOut to cacheManager.cacheRequest;
        connection cacheQueryToEngine
            connect cacheManager.queryOut to indexEngine.queryIn;
        connection engineResultToCache
            connect indexEngine.resultOut to cacheManager.resultIn;
        connection cacheResultToUI
            connect cacheManager.resultOut to userInterface.resultIn;
        connection engineMetricsToUI
            connect indexEngine.metricsOut to userInterface.metricsIn;
        connection notifierToUI
            connect notificationManager.notificationOut to userInterface.notificationIn;
    }

    // ===== Requirements =====

    requirement def DiscoverArticles {
        doc "The system shall automatically discover articles about home automation from predefined websites and data feeds.";
        subject system : HomeAutomationArticleIndexSystem;
        attribute scanInterval : DurationValue = 3600;
        require crawler.scanInterval <= scanInterval;
    }

    requirement def IndexDiscoveredArticles {
        doc "The system shall index all discovered articles within a specified time window.";
        subject system : HomeAutomationArticleIndexSystem;
        attribute maxIndexTime : DurationValue = 5;
        require maxIndexTime <= 5;
    }

    requirement def ProcessSearchQueries {
        doc "The system shall process user search queries and return ranked results based on keyword relevance.";
        subject system : HomeAutomationArticleIndexSystem;
        attribute maxResponseTime : DurationValue = 2;
        require maxResponseTime <= 2;
    }

    requirement def CacheSearchResults {
        doc "The system shall cache recent and common search results to improve response time.";
        subject system : HomeAutomationArticleIndexSystem;
        attribute minCacheHitRatio : RatioValue = 0.5;
        attribute minCacheSize : CountValue = 100;
        require cacheManager.cacheSize >= minCacheSize;
    }

    requirement def NotifySubscribedUsers {
        doc "The system shall notify subscribed users when new articles are added to the index.";
        subject system : HomeAutomationArticleIndexSystem;
        attribute maxNotificationDelay : DurationValue = 60;
        require maxNotificationDelay <= 60;
    }

    requirement def SupportArticleCategories {
        doc "The system shall support articles in lighting, climate control, security, and energy management categories.";
        subject system : HomeAutomationArticleIndexSystem;
        attribute supportedCategories : ArticleCategory[4] = [
            ArticleCategory::lighting,
            ArticleCategory::climateControl,
            ArticleCategory::security,
            ArticleCategory::energyManagement
        ];
    }

    requirement def DisplaySystemMetrics {
        doc "The user interface shall display the total number of articles and overall system metrics.";
        subject system : HomeAutomationArticleIndexSystem;
        require userInterface.metricsIn.metrics.totalArticles >= 0;
    }

    requirement def FilterSearchResults {
        doc "The user interface shall allow filtering search results by category and publication date.";
        subject system : HomeAutomationArticleIndexSystem;
    }

    requirement def IndexEngineStatusReporting {
        doc "The index engine shall report its current status as initializing, updating, searching, or idle.";
        subject system : HomeAutomationArticleIndexSystem;
        attribute validStatuses : IndexEngineStatus[4] = [
            IndexEngineStatus::initializing,
            IndexEngineStatus::updating,
            IndexEngineStatus::searching,
            IndexEngineStatus::idle
        ];
    }

    // ===== Requirement Satisfaction =====

    requirement satisfaction DiscoverArticles satisfiedBy HomeAutomationArticleIndexSystem::crawler;
    requirement satisfaction IndexDiscoveredArticles satisfiedBy HomeAutomationArticleIndexSystem::indexEngine;
    requirement satisfaction ProcessSearchQueries satisfiedBy HomeAutomationArticleIndexSystem::indexEngine;
    requirement satisfaction CacheSearchResults satisfiedBy HomeAutomationArticleIndexSystem::cacheManager;
    requirement satisfaction NotifySubscribedUsers satisfiedBy HomeAutomationArticleIndexSystem::notificationManager;
    requirement satisfaction SupportArticleCategories satisfiedBy HomeAutomationArticleIndexSystem::indexEngine;
    requirement satisfaction DisplaySystemMetrics satisfiedBy HomeAutomationArticleIndexSystem::userInterface;
    requirement satisfaction FilterSearchResults satisfiedBy HomeAutomationArticleIndexSystem::userInterface;
    requirement satisfaction IndexEngineStatusReporting satisfiedBy HomeAutomationArticleIndexSystem::indexEngine;

}
