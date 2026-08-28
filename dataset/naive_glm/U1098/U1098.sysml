package RoboticsDigitalLibrary {
    import ScalarValues::*;

    value def Count = Integer;
    value def Duration = Real;
    value def ResponseTime = Real;
    value def Accuracy = Real;

    item def Article {
        attribute id: String;
        attribute title: String;
        attribute content: String;
        attribute category: String;
        attribute publicationDate: String;
    }
    
    item def Keyword {
        attribute text: String;
    }
    
    item def Query {
        attribute text: String;
    }
    
    item def SearchResult {
        attribute articleId: String;
        attribute relevanceScore: Real;
    }
    
    item def Notification {
        attribute message: String;
        attribute timestamp: String;
    }

    enum def RoboticsCategory {
        manipulators;
        sensors;
        machine_vision;
        industrial_automation;
        mobile_robotics;
        ai;
        medical_robotics;
        control_systems;
        human_robot_interaction;
        swarm_robotics;
        slam;
        actuators;
    }

    requirement def RepositoryCapacityRequirement {
        doc /* The repository must store up to 500,000 articles */
        subject repository : ArticleRepository;
        requirement maxCapacity: repository.maxArticles >= 500000;
    }

    requirement def SearchPerformanceRequirement {
        doc /* The search engine must handle 100 simultaneous queries with <1s response time */
        subject searchEngine : SearchEngine;
        requirement maxConcurrent: searchEngine.maxConcurrentQueries >= 100;
        requirement maxResponseTime: searchEngine.avgResponseTime < 1.0;
    }

    requirement def UpdateMonitorIntervalRequirement {
        doc /* The update monitor must scan for modifications every 5 minutes */
        subject updateMonitor : UpdateMonitor;
        requirement scanInterval: updateMonitor.scanInterval == 5.0;
    }

    part def ArticleRepository {
        attribute maxArticles: Count = 500000;
        port in articleInput: Article;
        port out articleOutput: Article;
        port out articleUpdate: Article;
        
        attribute articles: Article[0..*];
        
        action def addArticle {
            in article: Article;
        }
        
        action def organizeArticles {
            in articles: Article[0..*];
        }
    }

    part def CategoryClassifier {
        attribute classificationAccuracy: Accuracy = 0.95;
        
        port in newArticle: Article;
        port out classifiedArticle: Article;
        port out extractedKeywords: Keyword[0..*];
        
        action def classify {
            in article: Article;
            out category: RoboticsCategory;
            out keywords: Keyword[0..*];
        }
    }

    part def InvertedIndexEngine {
        port in articleToIndex: Article;
        port in keywordsToIndex: Keyword[0..*];
        port in queryKeywords: Keyword[0..*];
        port out candidateArticles: Article[0..*];
        
        state engineStateMachine {
            state Indexing {
                entry // index new content
            }
            state Updating {
                entry // update existing entries
            }
            state Optimizing {
                entry // optimize data structures
            }
            transition from Indexing to Updating;
            transition from Updating to Optimizing;
            transition from Optimizing to Indexing;
        }
    }

    part def SearchEngine {
        attribute maxConcurrentQueries: Count = 100;
        attribute avgResponseTime: ResponseTime = 0.5;
        
        port in userQuery: Query;
        port out parsedKeywords: Keyword[0..*];
        port in candidateArticles: Article[0..*];
        port out results: SearchResult[0..*];
        
        part cache {
            attribute cachedResults: SearchResult[0..*];
        }
        
        action def processQuery {
            in query: Query;
            out keywords: Keyword[0..*];
            in candidates: Article[0..*];
            out searchResults: SearchResult[0..*];
        }
    }

    part def UpdateMonitor {
        attribute scanInterval: Duration = 5.0;
        
        port in repositoryUpdates: Article;
        port out notifications: Notification;
        
        state monitorStateMachine {
            state Monitoring {
                entry // scan for modifications
            }
            state Notifying {
                entry // send notifications
            }
            transition from Monitoring to Notifying;
            transition from Notifying to Monitoring;
        }
    }

    part def RoboticsLibrarySystem {
        part repository: ArticleRepository;
        part classifier: CategoryClassifier;
        part indexEngine: InvertedIndexEngine;
        part searchEngine: SearchEngine;
        part updateMonitor: UpdateMonitor;
        
        port in userQuery: Query;
        port out searchResults: SearchResult[0..*];
        port in newArticle: Article;
        port out updateNotification: Notification;
        
        connect newArticle to classifier.newArticle;
        connect classifier.classifiedArticle to repository.articleInput;
        connect classifier.extractedKeywords to indexEngine.keywordsToIndex;
        connect repository.articleOutput to indexEngine.articleToIndex;
        
        connect userQuery to searchEngine.userQuery;
        connect searchEngine.parsedKeywords to indexEngine.queryKeywords;
        connect indexEngine.candidateArticles to searchEngine.candidateArticles;
        connect searchEngine.results to searchResults;
        
        connect repository.articleUpdate to updateMonitor.repositoryUpdates;
        connect updateMonitor.notifications to updateNotification;
        
        satisfy RepositoryCapacityRequirement by repository;
        satisfy SearchPerformanceRequirement by searchEngine;
        satisfy UpdateMonitorIntervalRequirement by updateMonitor;
    }
}
