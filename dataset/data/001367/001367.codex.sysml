package BibcodeBasedSystemSpecification {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Bibcode {
        attribute year : Integer;
        attribute journalCode : String;
        attribute volumeCode : String;
        attribute pageCode : String;
        attribute authorInitial : String;
        attribute canonicalText : String;
    }

    attribute def ConfidenceScore : Real {
        :>> range = "0.0..1.0";
    }

    attribute def LatencyValue : Real {
        :>> unit = ms;
    }

    attribute def TextLength : Integer {
        :>> unit = character;
    }

    attribute def RecordCount : Integer;

    attribute def ProcessingStatus {
        attribute code : String;
        attribute message : String;
    }

    item def BibcodeQuery {
        attribute requestedBibcode : Bibcode;
        attribute requestTimestamp : DateTime;
    }

    item def BibliographicRecord {
        attribute bibcode : Bibcode;
        attribute title : String;
        attribute authors : String;
        attribute publicationYear : Integer;
        attribute sourceTitle : String;
        attribute abstractText : String;
        attribute keywords : String;
        attribute doi : String;
        attribute citationCount : RecordCount;
    }

    item def FunctionSummary {
        attribute sourceBibcode : Bibcode;
        attribute primaryFunctionText : String;
        attribute abstractionLevel : String;
        attribute confidence : ConfidenceScore;
        attribute textLength : TextLength;
    }

    item def ValidationReport {
        attribute validatedBibcode : Bibcode;
        attribute isStructurallyValid : Boolean;
        attribute normalizedBibcodeText : String;
        attribute diagnostic : String;
    }

    item def RetrievalRequest {
        attribute bibcode : Bibcode;
        attribute includeAbstract : Boolean;
        attribute includeCitations : Boolean;
    }

    item def RetrievalResponse {
        attribute status : ProcessingStatus;
        item record : BibliographicRecord;
    }

    item def SummaryRequest {
        item record : BibliographicRecord;
        attribute targetAbstractionLevel : String;
        attribute maximumLength : TextLength;
    }

    item def SummaryResponse {
        attribute status : ProcessingStatus;
        item summary : FunctionSummary;
    }

    port def BibcodeInputPort {
        in item query : BibcodeQuery;
    }

    port def SummaryOutputPort {
        out item summary : FunctionSummary;
        out item report : ValidationReport;
    }

    port def BibliographicRepositoryPort {
        out item request : RetrievalRequest;
        in item response : RetrievalResponse;
    }

    port def SummarizerPort {
        out item request : SummaryRequest;
        in item response : SummaryResponse;
    }

    port def MonitoringPort {
        out item status : ProcessingStatus;
        out attribute processingLatency : LatencyValue;
    }

    action def ValidateBibcode {
        in item query : BibcodeQuery;
        out item report : ValidationReport;

        first start;
        then checkLength;
        then checkYearField;
        then checkJournalField;
        then checkLocatorFields;
        then normalize;
        then finish;

        action checkLength;
        action checkYearField;
        action checkJournalField;
        action checkLocatorFields;
        action normalize;
    }

    action def RetrieveBibliographicRecord {
        in item report : ValidationReport;
        out item retrievalRequest : RetrievalRequest;
        in item retrievalResponse : RetrievalResponse;
        out item record : BibliographicRecord;

        first prepareRequest;
        then sendRequest;
        then receiveResponse;
        then extractRecord;
        then finish;

        action prepareRequest;
        action sendRequest;
        action receiveResponse;
        action extractRecord;
    }

    action def DerivePrimaryFunction {
        in item record : BibliographicRecord;
        out item summaryRequest : SummaryRequest;
        in item summaryResponse : SummaryResponse;
        out item summary : FunctionSummary;

        first identifyDomain;
        then extractSystemSubject;
        then inferPrimaryFunction;
        then constrainToHighLevelDescription;
        then scoreConfidence;
        then finish;

        action identifyDomain;
        action extractSystemSubject;
        action inferPrimaryFunction;
        action constrainToHighLevelDescription;
        action scoreConfidence;
    }

    action def PublishFunctionSummary {
        in item report : ValidationReport;
        in item summary : FunctionSummary;
        out item publishedReport : ValidationReport;
        out item publishedSummary : FunctionSummary;

        first packageResult;
        then emitResult;
        then finish;

        action packageResult;
        action emitResult;
    }

    state def DescriptorLifecycle {
        entry action initialize;

        state Idle;
        state Validating;
        state InvalidBibcode;
        state RetrievingRecord;
        state RecordUnavailable;
        state SummarizingFunction;
        state PublishingResult;
        state Completed;
        state Failed;

        transition first Idle;

        transition acceptQuery
            first Idle
            then Validating;

        transition validationRejected
            first Validating
            then InvalidBibcode;

        transition validationAccepted
            first Validating
            then RetrievingRecord;

        transition retrievalFailed
            first RetrievingRecord
            then RecordUnavailable;

        transition retrievalSucceeded
            first RetrievingRecord
            then SummarizingFunction;

        transition summarizationFailed
            first SummarizingFunction
            then Failed;

        transition summarizationSucceeded
            first SummarizingFunction
            then PublishingResult;

        transition resultPublished
            first PublishingResult
            then Completed;

        transition resetAfterInvalid
            first InvalidBibcode
            then Idle;

        transition resetAfterUnavailable
            first RecordUnavailable
            then Idle;

        transition resetAfterCompleted
            first Completed
            then Idle;

        transition resetAfterFailure
            first Failed
            then Idle;
    }

    part def BibcodeValidator {
        port input : BibcodeInputPort;
        port output;
        perform action validate : ValidateBibcode;
    }

    part def BibliographicRecordRetriever {
        port repository : BibliographicRepositoryPort;
        perform action retrieve : RetrieveBibliographicRecord;
    }

    part def PrimaryFunctionInterpreter {
        port summarizer : SummarizerPort;
        perform action derive : DerivePrimaryFunction;
    }

    part def ResultPublisher {
        port output : SummaryOutputPort;
        perform action publish : PublishFunctionSummary;
    }

    part def HealthMonitor {
        port monitor : MonitoringPort;
        attribute lastLatency : LatencyValue;
        attribute processedRequests : RecordCount;
        attribute failedRequests : RecordCount;
    }

    part def BibliographicRepository {
        port service : BibliographicRepositoryPort;
        attribute indexedRecords : RecordCount;
        attribute availability : ConfidenceScore;
    }

    part def LanguageUnderstandingService {
        port service : SummarizerPort;
        attribute modelName : String;
        attribute maximumInputLength : TextLength;
        attribute nominalLatency : LatencyValue;
    }

    part def BibcodeBasedSystemDescriptor {
        port userInput : BibcodeInputPort;
        port userOutput : SummaryOutputPort;
        port monitoring : MonitoringPort;

        part validator : BibcodeValidator;
        part retriever : BibliographicRecordRetriever;
        part interpreter : PrimaryFunctionInterpreter;
        part publisher : ResultPublisher;
        part monitor : HealthMonitor;
        part repository : BibliographicRepository;
        part summarizer : LanguageUnderstandingService;

        attribute maximumResponseLatency : LatencyValue = 2500.0;
        attribute minimumSummaryConfidence : ConfidenceScore = 0.75;
        attribute maximumSummaryLength : TextLength = 600;
        attribute targetAbstractionLevel : String = "high-level primary function";

        exhibit state lifecycle : DescriptorLifecycle;

        connect userInput to validator.input;
        connect retriever.repository to repository.service;
        connect interpreter.summarizer to summarizer.service;
        connect publisher.output to userOutput;
        connect monitor.monitoring to monitoring;

        flow validationFlow
            from validator.output
            to retriever.repository;

        flow recordFlow
            from retriever.repository
            to interpreter.summarizer;

        flow summaryFlow
            from interpreter.summarizer
            to publisher.output;

        flow statusFlow
            from validator.output
            to monitor.monitor;
    }

    requirement def BibcodeAcceptanceRequirement {
        subject system : BibcodeBasedSystemDescriptor;

        require constraint {
            system.userInput.query.requestedBibcode.canonicalText != ""
        }

        doc /* The system shall accept a canonical astronomical bibliographic code as the identifying basis for the described source system. */
    }

    requirement def BibcodeValidationRequirement {
        subject system : BibcodeBasedSystemDescriptor;

        require constraint {
            system.validator.validate.report.isStructurallyValid == true
        }

        doc /* The system shall validate the received bibcode structure before attempting bibliographic retrieval. */
    }

    requirement def RecordRetrievalRequirement {
        subject system : BibcodeBasedSystemDescriptor;

        require constraint {
            system.repository.indexedRecords > 0
        }

        doc /* The system shall retrieve bibliographic metadata associated with the validated bibcode, including title, authors, publication source, abstract, DOI when available, and citation count. */
    }

    requirement def PrimaryFunctionDescriptionRequirement {
        subject system : BibcodeBasedSystemDescriptor;

        require constraint {
            system.interpreter.derive.summary.confidence >= system.minimumSummaryConfidence
        }

        doc /* The system shall derive a concise high-level description of the primary function of the system, instrument, mission, method, or artifact represented by the bibcode record. */
    }

    requirement def SummaryLengthRequirement {
        subject system : BibcodeBasedSystemDescriptor;

        require constraint {
            system.interpreter.derive.summary.textLength <= system.maximumSummaryLength
        }

        doc /* The generated primary function description shall remain short enough for direct display in discovery, cataloging, and review workflows. */
    }

    requirement def TraceabilityRequirement {
        subject system : BibcodeBasedSystemDescriptor;

        require constraint {
            system.interpreter.derive.summary.sourceBibcode.canonicalText ==
            system.validator.validate.report.normalizedBibcodeText
        }

        doc /* Every primary function summary shall be explicitly traceable to the normalized bibcode used as its source identifier. */
    }

    requirement def LatencyRequirement {
        subject system : BibcodeBasedSystemDescriptor;

        require constraint {
            system.monitor.lastLatency <= system.maximumResponseLatency
        }

        doc /* The system shall produce a validation report and high-level primary function summary within the configured response latency for normal repository availability. */
    }

    requirement def FailureReportingRequirement {
        subject system : BibcodeBasedSystemDescriptor;

        require constraint {
            system.userOutput.report.diagnostic != ""
        }

        doc /* When validation, retrieval, or summarization cannot be completed, the system shall return a diagnostic report instead of an empty result. */
    }

    satisfy BibcodeAcceptanceRequirement by BibcodeBasedSystemDescriptor;
    satisfy BibcodeValidationRequirement by BibcodeBasedSystemDescriptor.validator;
    satisfy RecordRetrievalRequirement by BibcodeBasedSystemDescriptor.retriever;
    satisfy PrimaryFunctionDescriptionRequirement by BibcodeBasedSystemDescriptor.interpreter;
    satisfy SummaryLengthRequirement by BibcodeBasedSystemDescriptor.interpreter;
    satisfy TraceabilityRequirement by BibcodeBasedSystemDescriptor.publisher;
    satisfy LatencyRequirement by BibcodeBasedSystemDescriptor.monitor;
    satisfy FailureReportingRequirement by BibcodeBasedSystemDescriptor.publisher;

}