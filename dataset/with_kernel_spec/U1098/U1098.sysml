package RoboticsDigitalLibrary {
    private import ScalarValues::*;
    private import SI::*;

    item def Article {
        attribute id : String;
        attribute title : String;
        attribute content : String;
        attribute category : String;
        attribute publicationDate : String;
        attribute keywords : String [*];
    }

    attribute def Query {
        attribute text : String;
    }

    attribute def SearchResult {
        attribute articleId : String;
        attribute relevanceScore : Real;
    }

    attribute def UpdateNotification {
        attribute articleId : String;
        attribute updateType : String;
    }

    port def ArticleFlowPort {
        in article : Article;
    }

    port def IndexQueryPort {
        in keyword : String;
        out articleIds : String [*];
    }

    port def SearchRequestPort {
        in query : Query;
        out results : SearchResult [*];
    }

    port def NotificationPort {
        out notification : UpdateNotification;
    }

    part def ArticleRepository {
        attribute maxCapacity : Integer = 500000;
        attribute currentCount : Integer = 0;
        port intakePort : ArticleFlowPort;
        port outputPort : ~ArticleFlowPort;

        state RepositoryBehavior {
            entry; then Idle;
            state Idle;
            accept article : Article via intakePort
                do action storeArticle {
                    in articleToStore : Article = article;
                    first start;
                    then assign currentCount = currentCount + 1;
                    then send articleToStore via outputPort;
                    then done;
                }
            then Idle;
        }
    }

    part def CategoryClassifier {
        attribute categories : String [12] = ["manipulators", "sensors", "machine vision", "industrial automation", "mobile robotics", "AI", "medical robotics", "control systems", "human-robot interaction", "swarm robotics", "soft robotics", "bio-inspired robotics"];
        attribute accuracy : Real = 0.95;
        port intakePort : ArticleFlowPort;
        port outputPort : ~ArticleFlowPort;

        state ClassifierBehavior {
            entry; then Idle;
            state Idle;
            accept article : Article via intakePort
                do action classifyArticle {
                    in rawArticle : Article = article;
                    out classifiedArticle : Article;
                    first start;
                    then assign classifiedArticle = rawArticle;
                    then assign classifiedArticle.category = "manipulators";
                    then send classifiedArticle via outputPort;
                    then done;
                }
            then Idle;
        }
    }

    part def InvertedIndexEngine {
        port updatePort : ArticleFlowPort;
        port queryPort : IndexQueryPort;

        state IndexBehavior {
            entry; then Idle;
            state Idle;
            accept article : Article via updatePort
                then Indexing;
            accept keyword : String via queryPort
                do action processQuery {
                    first start;
                    then send "article1" via queryPort.articleIds;
                    then done;
                }
            then Idle;
            state Indexing;
            accept after 0.5 [s]
                then Updating;
            state Updating;
            accept after 0.2 [s]
                then Optimizing;
            state Optimizing;
            accept after 1 [min]
                then Idle;
        }
    }

    part def SearchEngine {
        attribute maxSimultaneousQueries : Integer = 100;
        attribute responseTimeLimit : Real = 1.0 [s];
        port searchPort : SearchRequestPort;
        port indexQueryPort : ~IndexQueryPort;

        state SearchBehavior {
            entry; then Idle;
            state Idle;
            accept query : Query via searchPort
                do action processQuery {
                    in userQuery : Query = query;
                    first start;
                    then send userQuery.text via indexQueryPort.keyword;
                    then accept ids : String [*] via indexQueryPort.articleIds;
                    then send new SearchResult("article1", 1.0) via searchPort.results;
                    then done;
                }
            then Idle;
        }
    }

    part def UpdateMonitor {
        attribute scanInterval : Real = 5.0 [min];
        port notifyPort : NotificationPort;

        state MonitorBehavior {
            entry; then Scanning;
            state Scanning;
            accept after 5 [min]
                do action checkUpdates {
                    first start;
                    then send new UpdateNotification("article123", "modified") via notifyPort.notification;
                    then done;
                }
            then Scanning;
        }
    }

    requirement def CapacityRequirement {
        doc /* The repository must hold up to 500,000 articles. */
        subject repo : ArticleRepository;
        assert repo.maxCapacity >= 500000;
    }

    requirement def ClassifierAccuracyRequirement {
        doc /* The classifier must assign articles to one of 12 categories with high accuracy. */
        subject classifier : CategoryClassifier;
        assert classifier.categories.size == 12;
        assert classifier.accuracy >= 0.90;
    }

    requirement def SearchPerformanceRequirement {
        doc /* The search engine must handle 100 simultaneous queries with less than 1 second response time. */
        subject engine : SearchEngine;
        assert engine.maxSimultaneousQueries >= 100;
        assert engine.responseTimeLimit <= 1.0 [s];
    }

    requirement def MonitorIntervalRequirement {
        doc /* The update monitor must scan for modifications every 5 minutes. */
        subject monitor : UpdateMonitor;
        assert monitor.scanInterval == 5.0 [min];
    }

    part librarySystem {
        requirement capReq : CapacityRequirement;
        requirement accReq : ClassifierAccuracyRequirement;
        requirement perfReq : SearchPerformanceRequirement;
        requirement intReq : MonitorIntervalRequirement;

        part classifier : CategoryClassifier {
            satisfy accReq;
        }
        part repository : ArticleRepository {
            satisfy capReq;
        }
        part indexEngine : InvertedIndexEngine;
        part searchEngine : SearchEngine {
            satisfy perfReq;
        }
        part monitor : UpdateMonitor {
            satisfy intReq;
        }

        port articleInput : ~ArticleFlowPort;
        port searchRequest : ~SearchRequestPort;
        port notificationOut : ~NotificationPort;

        connect articleInput to classifier.intakePort;
        connect classifier.outputPort to repository.intakePort;
        connect repository.outputPort to indexEngine.updatePort;
        connect searchEngine.indexQueryPort to indexEngine.queryPort;
        connect searchEngine.searchPort to searchRequest;
        connect monitor.notifyPort to notificationOut;
    }
}
