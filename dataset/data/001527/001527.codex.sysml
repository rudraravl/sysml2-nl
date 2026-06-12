package PMIDBasedSystemSpecification {
  import ScalarValues::*;
  import ISQ::*;

  item def PMID {
    attribute value : Integer;
  }

  item def ArticleMetadata {
    attribute title : String;
    attribute journal : String;
    attribute publicationYear : Integer;
    attribute doi : String;
  }

  item def AbstractText {
    attribute text : String;
    attribute language : String;
  }

  item def FunctionSummary {
    attribute description : String;
    attribute confidence : Real;
  }

  item def ErrorReport {
    attribute code : String;
    attribute message : String;
  }

  attribute def Latency {
    :>> unit = "s";
    :>> quantityKind = ISQ::time;
  }

  attribute def Availability {
    :>> unit = "%";
  }

  port def PMIDInputPort {
    in item requestedPMID : PMID;
  }

  port def MetadataServicePort {
    out item pmidQuery : PMID;
    in item articleMetadata : ArticleMetadata;
    in item abstractText : AbstractText;
    in item retrievalError : ErrorReport;
  }

  port def SummaryOutputPort {
    out item highLevelFunction : FunctionSummary;
    out item failure : ErrorReport;
  }

  part def PMIDFunctionSpecificationSystem {
    attribute maxLookupLatency : Latency = 3.0;
    attribute targetAvailability : Availability = 99.5;

    port pmidInput : PMIDInputPort;
    port metadataService : MetadataServicePort;
    port summaryOutput : SummaryOutputPort;

    part validator : PMIDValidator;
    part retriever : PublicationRetriever;
    part analyzer : FunctionAnalyzer;
    part summarizer : FunctionSummarizer;

    connect pmidInput.requestedPMID to validator.inputPMID;
    connect validator.validPMID to retriever.lookupPMID;
    connect retriever.metadata to analyzer.metadataIn;
    connect retriever.abstractText to analyzer.abstractIn;
    connect analyzer.extractedFunction to summarizer.functionIn;
    connect summarizer.summaryOut to summaryOutput.highLevelFunction;
    connect validator.validationError to summaryOutput.failure;
    connect retriever.retrievalError to summaryOutput.failure;
    connect analyzer.analysisError to summaryOutput.failure;

    perform action specifyPrimaryFunction;
    exhibit state lifecycle;
  }

  part def PMIDValidator {
    in item inputPMID : PMID;
    out item validPMID : PMID;
    out item validationError : ErrorReport;

    action def ValidatePMID {
      in item candidate : PMID;
      out item accepted : PMID;
      out item rejected : ErrorReport;
    }
  }

  part def PublicationRetriever {
    in item lookupPMID : PMID;
    out item metadata : ArticleMetadata;
    out item abstractText : AbstractText;
    out item retrievalError : ErrorReport;

    port externalPublicationIndex : MetadataServicePort;

    connect lookupPMID to externalPublicationIndex.pmidQuery;
    connect externalPublicationIndex.articleMetadata to metadata;
    connect externalPublicationIndex.abstractText to abstractText;
    connect externalPublicationIndex.retrievalError to retrievalError;
  }

  part def FunctionAnalyzer {
    in item metadataIn : ArticleMetadata;
    in item abstractIn : AbstractText;
    out item extractedFunction : FunctionSummary;
    out item analysisError : ErrorReport;

    action def ExtractPrimaryFunction {
      in item sourceMetadata : ArticleMetadata;
      in item sourceAbstract : AbstractText;
      out item primaryFunction : FunctionSummary;
    }
  }

  part def FunctionSummarizer {
    in item functionIn : FunctionSummary;
    out item summaryOut : FunctionSummary;

    action def NormalizeHighLevelDescription {
      in item detailedFunction : FunctionSummary;
      out item highLevelFunction : FunctionSummary;
    }
  }

  action def specifyPrimaryFunction {
    in item pmid : PMID;
    out item summary : FunctionSummary;

    action validate : PMIDValidator::ValidatePMID {
      in candidate = pmid;
    }

    action retrieve : PublicationRetriever {
      in lookupPMID = validate.accepted;
    }

    action analyze : FunctionAnalyzer::ExtractPrimaryFunction {
      in sourceMetadata = retrieve.metadata;
      in sourceAbstract = retrieve.abstractText;
    }

    action summarize : FunctionSummarizer::NormalizeHighLevelDescription {
      in detailedFunction = analyze.primaryFunction;
      out highLevelFunction = summary;
    }
  }

  state def lifecycle {
    state Idle;
    state ValidatingPMID;
    state RetrievingPublication;
    state AnalyzingContent;
    state ProducingSummary;
    state Completed;
    state Failed;

    transition initial then Idle;
    transition Idle_to_Validating first Idle then ValidatingPMID;
    transition Validating_to_Retrieving first ValidatingPMID then RetrievingPublication;
    transition Retrieving_to_Analyzing first RetrievingPublication then AnalyzingContent;
    transition Analyzing_to_Producing first AnalyzingContent then ProducingSummary;
    transition Producing_to_Completed first ProducingSummary then Completed;
    transition AnyValidationFailure first ValidatingPMID then Failed;
    transition AnyRetrievalFailure first RetrievingPublication then Failed;
    transition AnyAnalysisFailure first AnalyzingContent then Failed;
  }

  requirement def PMIDInputRequirement {
    subject system : PMIDFunctionSpecificationSystem;
    require constraint {
      system.pmidInput.requestedPMID.value > 0
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : PMIDFunctionSpecificationSystem;
    require constraint {
      system.summaryOutput.highLevelFunction.description != ""
    }
  }

  requirement def ConfidenceRequirement {
    subject system : PMIDFunctionSpecificationSystem;
    require constraint {
      system.summaryOutput.highLevelFunction.confidence >= 0.70
    }
  }

  requirement def LatencyRequirement {
    subject system : PMIDFunctionSpecificationSystem;
    require constraint {
      system.maxLookupLatency <= 3.0
    }
  }

  requirement def AvailabilityRequirement {
    subject system : PMIDFunctionSpecificationSystem;
    require constraint {
      system.targetAvailability >= 99.5
    }
  }

  part system : PMIDFunctionSpecificationSystem;
}