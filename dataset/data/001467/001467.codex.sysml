package RoboticsArticleIndexSystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def ArticleCount :> Integer;
    attribute def ConfidenceScore :> Real;
    attribute def RelevanceScore :> Real;
    attribute def QueryLatency :> Real {
        unit = s;
    }
    attribute def StorageSize :> Real {
        unit = MB;
    }
    attribute def ThroughputRate :> Real {
        unit = Hz;
    }

    item def RoboticsArticle {
        attribute title : String;
        attribute authors : String;
        attribute publicationYear : Integer;
        attribute sourceName : String;
        attribute abstractText : String;
        attribute fullText : String;
        attribute topicTags : String;
        attribute citationCount : ArticleCount;
    }

    item def ArticleMetadata {
        attribute title : String;
        attribute authors : String;
        attribute publicationYear : Integer;
        attribute sourceName : String;
        attribute doi : String;
    }

    item def SearchQuery {
        attribute queryText : String;
        attribute requestedTopic : String;
        attribute maxResults : ArticleCount;
    }

    item def SearchResult {
        attribute articleTitle : String;
        attribute summary : String;
        attribute relevance : RelevanceScore;
        attribute topicClassification : String;
    }

    item def IndexEntry {
        attribute articleId : String;
        attribute normalizedTerms : String;
        attribute topicVector : String;
        attribute citationWeight : RelevanceScore;
    }

    port def ArticleInPort {
        in item article : RoboticsArticle;
    }

    port def MetadataPort {
        inout item metadata : ArticleMetadata;
    }

    port def IndexPort {
        inout item entry : IndexEntry;
    }

    port def QueryPort {
        in item query : SearchQuery;
        out item result : SearchResult;
    }

    port def StatusPort {
        out attribute indexedArticles : ArticleCount;
        out attribute averageQueryLatency : QueryLatency;
        out attribute indexStorageUsed : StorageSize;
    }

    action def IngestArticle {
        in item rawArticle : RoboticsArticle;
        out item metadata : ArticleMetadata;
        out item articleForProcessing : RoboticsArticle;
    }

    action def NormalizeArticleText {
        in item article : RoboticsArticle;
        out item normalizedArticle : RoboticsArticle;
    }

    action def ClassifyRoboticsTopic {
        in item article : RoboticsArticle;
        out attribute topic : String;
        out attribute confidence : ConfidenceScore;
    }

    action def BuildIndexEntry {
        in item article : RoboticsArticle;
        in attribute topic : String;
        out item entry : IndexEntry;
    }

    action def ExecuteSearch {
        in item query : SearchQuery;
        in item entry : IndexEntry;
        out item result : SearchResult;
    }

    action def SummarizeArticle {
        in item article : RoboticsArticle;
        out attribute summaryText : String;
    }

    state def IndexLifecycle {
        state Empty;
        state Loading;
        state Classifying;
        state Indexed;
        state ServingQueries;
        state Rebuilding;
        state Faulted;

        entry action Empty {
            indexedArticles = 0;
        }

        transition first Empty then Loading
            accept RoboticsArticle;

        transition Loading then Classifying
            if rawArticle.fullText != "";

        transition Classifying then Indexed
            if confidence >= 0.70;

        transition Indexed then ServingQueries
            accept SearchQuery;

        transition ServingQueries then Rebuilding
            if indexStorageUsed > 50000.0;

        transition Rebuilding then Indexed
            if rebuildComplete == true;

        transition Loading then Faulted
            if rawArticle.title == "";

        transition Classifying then Faulted
            if confidence < 0.20;
    }

    part def ArticleIngestionService {
        port articleIn : ArticleInPort;
        port metadataOut : MetadataPort;

        attribute ingestionRate : ThroughputRate;
        attribute acceptedArticles : ArticleCount;

        perform action ingest : IngestArticle;
    }

    part def TextProcessingService {
        port articleIn : ArticleInPort;
        port articleOut : ArticleInPort;

        attribute normalizationLatency : QueryLatency;

        perform action normalize : NormalizeArticleText;
    }

    part def RoboticsTopicClassifier {
        port articleIn : ArticleInPort;
        port metadataOut : MetadataPort;

        attribute minimumConfidence : ConfidenceScore = 0.70;
        attribute classificationLatency : QueryLatency;

        perform action classify : ClassifyRoboticsTopic;
    }

    part def SearchIndexRepository {
        port indexAccess : IndexPort;
        port status : StatusPort;

        attribute storedEntries : ArticleCount;
        attribute storageUsed : StorageSize;
        attribute maxStorage : StorageSize = 50000.0;
    }

    part def IndexBuilder {
        port metadataIn : MetadataPort;
        port indexOut : IndexPort;

        attribute buildLatency : QueryLatency;

        perform action buildEntry : BuildIndexEntry;
    }

    part def QueryService {
        port queryAccess : QueryPort;
        port indexAccess : IndexPort;
        port status : StatusPort;

        attribute averageLatency : QueryLatency;
        attribute queryThroughput : ThroughputRate;

        perform action search : ExecuteSearch;
    }

    part def ArticleSummarizationService {
        port articleIn : ArticleInPort;
        port resultOut : QueryPort;

        attribute summaryLatency : QueryLatency;

        perform action summarize : SummarizeArticle;
    }

    part def RoboticsArticleIndexSystem {
        attribute primaryFunction : String =
            "Maintain a searchable, topic-aware index of robotics articles so users can discover relevant research by robot domain, method, application, and citation importance.";

        part ingestion : ArticleIngestionService;
        part processor : TextProcessingService;
        part classifier : RoboticsTopicClassifier;
        part builder : IndexBuilder;
        part repository : SearchIndexRepository;
        part query : QueryService;
        part summarizer : ArticleSummarizationService;

        port externalArticleFeed : ArticleInPort;
        port userSearchInterface : QueryPort;
        port operationalStatus : StatusPort;

        connect externalArticleFeed to ingestion.articleIn;
        connect ingestion.metadataOut to builder.metadataIn;
        connect ingestion.articleIn to processor.articleIn;
        connect processor.articleOut to classifier.articleIn;
        connect classifier.metadataOut to builder.metadataIn;
        connect builder.indexOut to repository.indexAccess;
        connect repository.indexAccess to query.indexAccess;
        connect userSearchInterface to query.queryAccess;
        connect query.status to operationalStatus;
        connect repository.status to operationalStatus;
        connect processor.articleOut to summarizer.articleIn;
        connect summarizer.resultOut to userSearchInterface;

        exhibit state indexLifecycle : IndexLifecycle;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : RoboticsArticleIndexSystem;

        doc
            "The system shall provide a high-level robotics article indexing capability that ingests articles, extracts metadata, classifies robotics topics, stores searchable index entries, and returns ranked search results.";

        require constraint {
            system.repository.storedEntries >= 1
        }
    }

    requirement def QueryPerformanceRequirement {
        subject system : RoboticsArticleIndexSystem;

        doc
            "The system shall return ranked robotics article search results with average query latency not greater than two seconds.";

        require constraint {
            system.query.averageLatency <= 2.0
        }
    }

    requirement def ClassificationRequirement {
        subject system : RoboticsArticleIndexSystem;

        doc
            "The system shall classify each indexed article into a robotics topic with confidence of at least 0.70 before making the article searchable.";

        require constraint {
            system.classifier.minimumConfidence >= 0.70
        }
    }

    requirement def StorageRequirement {
        subject system : RoboticsArticleIndexSystem;

        doc
            "The index repository shall store article index entries without exceeding fifty thousand megabytes of allocated storage.";

        require constraint {
            system.repository.storageUsed <= system.repository.maxStorage
        }
    }

    requirement def SearchResultRequirement {
        subject result : SearchResult;

        doc
            "Each search result shall include an article title, concise summary, relevance score, and robotics topic classification.";

        require constraint {
            result.articleTitle != "" and
            result.summary != "" and
            result.relevance >= 0.0 and
            result.topicClassification != ""
        }
    }

    satisfy PrimaryFunctionRequirement by RoboticsArticleIndexSystem;
    satisfy QueryPerformanceRequirement by RoboticsArticleIndexSystem;
    satisfy ClassificationRequirement by RoboticsArticleIndexSystem;
    satisfy StorageRequirement by RoboticsArticleIndexSystem;
}