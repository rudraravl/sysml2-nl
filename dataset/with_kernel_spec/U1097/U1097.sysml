package HomeAutomationArticleIndexSystem {
    private import ScalarValues::*;
    
    enum def HomeAutomationCategory {
        lighting;
        climate;
        security;
        energy;
    }
    
    item def Article {
        attribute title : String;
        attribute url : String;
        attribute category : HomeAutomationCategory;
        attribute publicationDate : String;
        attribute content : String;
    }
    
    item def SearchQuery {
        attribute keywords : String;
        attribute categoryFilter : HomeAutomationCategory[0..1];
        attribute dateFilter : String;
    }
    
    item def SearchResult {
        attribute query : SearchQuery;
        attribute articles : Article[0..*];
        attribute relevanceScores : Real[0..*];
    }
    
    item def Alert {
        attribute alertText : String;
        attribute newArticles : Article[0..*];
    }
    
    item def SystemMetrics {
        attribute totalArticles : Integer;
        attribute lastCrawlTime : String;
    }
    
    port def ArticlePort {
        in article : Article;
    }
    
    port def QueryPort {
        in query : SearchQuery;
        out result : SearchResult;
    }
    
    port def AlertPort {
        in alert : Alert;
    }
    
    port def MetricsPort {
        in metrics : SystemMetrics;
    }
    
    part def ArticleCrawler {
        port articlePort : ~ArticlePort;
        attribute crawlInterval : Integer = 3600;
        
        exhibit state CrawlBehavior {
            entry send new Article() via articlePort;
            then Idle;
            state Idle;
        }
    }
    
    part def IndexEngine {
        port articlePort : ArticlePort;
        port queryPort : QueryPort;
        port metricsPort : ~MetricsPort;
        
        attribute totalArticles : Integer = 0;
        
        exhibit state EngineState {
            entry; then Idle;
            state Idle;
            transition receiveArticle
                first Idle
                accept art : Article via articlePort
                do send new SystemMetrics() via metricsPort
                then Idle;
            transition receiveQuery
                first Idle
                accept q : SearchQuery via queryPort
                do send new SearchResult() via queryPort
                then Idle;
        }
    }
    
    part def CacheManager {
        port uiQueryPort : QueryPort;
        port indexQueryPort : ~QueryPort;
        
        exhibit state CacheState {
            entry; then Ready;
            state Ready;
            transition handleQuery
                first Ready
                accept q : SearchQuery via uiQueryPort
                do send q via indexQueryPort
                then WaitForIndex;
            state WaitForIndex;
            transition receiveResult
                first WaitForIndex
                accept r : SearchResult via indexQueryPort
                do send r via uiQueryPort
                then Ready;
        }
    }
    
    part def UserInterface {
        port queryPort : ~QueryPort;
        port alertPort : AlertPort;
        port metricsPort : MetricsPort;
        
        exhibit state UIBehavior {
            entry send new SearchQuery() via queryPort;
            then Ready;
            state Ready;
            transition displayResults
                first Ready
                accept r : SearchResult via queryPort
                do send new SearchQuery() via queryPort
                then Ready;
            transition displayAlert
                first Ready
                accept a : Alert via alertPort
                then Ready;
            transition displayMetrics
                first Ready
                accept m : SystemMetrics via metricsPort
                then Ready;
        }
    }
    
    part def NotificationManager {
        port articlePort : ArticlePort;
        port alertPort : ~AlertPort;
        
        exhibit state NotifyBehavior {
            entry; then Idle;
            state Idle;
            transition monitorArticles
                first Idle
                accept art : Article via articlePort
                do send new Alert() via alertPort
                then Idle;
        }
    }
    
    part def System {
        part crawler : ArticleCrawler;
        part indexEngine : IndexEngine;
        part cacheManager : CacheManager;
        part ui : UserInterface;
        part notifier : NotificationManager;
        
        interface crawler.articlePort to indexEngine.articlePort;
        interface crawler.articlePort to notifier.articlePort;
        interface ui.queryPort to cacheManager.uiQueryPort;
        interface cacheManager.indexQueryPort to indexEngine.queryPort;
        interface indexEngine.metricsPort to ui.metricsPort;
        interface notifier.alertPort to ui.alertPort;
    }
    
    requirement def SystemRequirement {
        doc /* The system shall aggregate, organize, and provide searchable access to online content about smart home technology. */
        subject system : System;
    }
}
