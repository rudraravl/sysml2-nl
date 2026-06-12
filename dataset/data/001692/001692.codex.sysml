package Apache2LicensedSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    doc /* 
     * This model describes a software system released under the Apache License, Version 2.0.
     * Primary function: provide a reusable, cloud-deployable document processing service that
     * accepts text documents, validates requests, extracts metadata, indexes searchable content,
     * and returns structured processing results while preserving Apache 2.0 licensing notices,
     * attribution, patent grant terms, and NOTICE-file obligations.
     */

    attribute def URI;
    attribute def VersionString;
    attribute def LicenseText;
    attribute def SPDXIdentifier;
    attribute def Hash256;
    attribute def Millisecond :> time;
    attribute def RequestCount;
    attribute def DocumentCount;
    attribute def ConfidenceScore {
        value score : Real;
        constraint scoreRange {
            score >= 0.0 and score <= 1.0
        }
    }

    item def Document {
        attribute id : String;
        attribute sourceUri : URI;
        attribute mediaType : String;
        attribute byteSize : Integer;
        attribute sha256 : Hash256;
        attribute receivedAt : String;
    }

    item def ValidatedDocument :> Document {
        attribute validationStatus : String = "valid";
        attribute detectedEncoding : String;
    }

    item def RejectedDocument :> Document {
        attribute reason : String;
        attribute statusCode : Integer;
    }

    item def MetadataRecord {
        attribute documentId : String;
        attribute title : String;
        attribute author : String;
        attribute language : String;
        attribute keywordCount : Integer;
        attribute extractionConfidence : ConfidenceScore;
    }

    item def SearchIndexEntry {
        attribute documentId : String;
        attribute normalizedTerms : String;
        attribute termCount : Integer;
        attribute indexedAt : String;
    }

    item def ProcessingResult {
        attribute documentId : String;
        attribute accepted : Boolean;
        attribute status : String;
        attribute elapsedTime : Millisecond;
        attribute metadata : MetadataRecord;
        attribute indexEntry : SearchIndexEntry;
        attribute licenseIdentifier : SPDXIdentifier = "Apache-2.0";
    }

    item def ErrorReport {
        attribute documentId : String;
        attribute errorCode : String;
        attribute message : String;
        attribute recoverable : Boolean;
    }

    item def LicenseNotice {
        attribute licenseName : String = "Apache License, Version 2.0";
        attribute spdxId : SPDXIdentifier = "Apache-2.0";
        attribute copyrightStatement : String;
        attribute noticeText : LicenseText;
        attribute licenseUrl : URI = "https://www.apache.org/licenses/LICENSE-2.0";
    }

    port def DocumentInPort {
        in item document : Document;
    }

    port def ValidatedDocumentPort {
        out item validatedDocument : ValidatedDocument;
        out item rejectedDocument : RejectedDocument;
    }

    port def MetadataPort {
        out item metadataRecord : MetadataRecord;
    }

    port def IndexPort {
        out item indexEntry : SearchIndexEntry;
    }

    port def ResultOutPort {
        out item result : ProcessingResult;
        out item error : ErrorReport;
    }

    port def LicenseInfoPort {
        out item notice : LicenseNotice;
    }

    port def AuditPort {
        out item auditEvent : String;
    }

    action def ReceiveDocument {
        in item inboundDocument : Document;
        out item receivedDocument : Document;
    }

    action def ValidateDocument {
        in item candidate : Document;
        out item validDocument : ValidatedDocument;
        out item invalidDocument : RejectedDocument;
    }

    action def ExtractMetadata {
        in item validDocument : ValidatedDocument;
        out item metadata : MetadataRecord;
    }

    action def BuildSearchIndexEntry {
        in item validDocument : ValidatedDocument;
        out item entry : SearchIndexEntry;
    }

    action def ComposeProcessingResult {
        in item validDocument : ValidatedDocument;
        in item metadata : MetadataRecord;
        in item entry : SearchIndexEntry;
        out item result : ProcessingResult;
    }

    action def ComposeErrorReport {
        in item rejectedDocument : RejectedDocument;
        out item error : ErrorReport;
    }

    action def EmitApache2Notice {
        out item notice : LicenseNotice;
    }

    state def ProcessingLifecycle {
        entry; then Idle;

        state Idle;
        state Receiving;
        state Validating;
        state ExtractingMetadata;
        state IndexingContent;
        state ReturningResult;
        state ReturningError;
        state RecordingAudit;
        state Completed;

        transition Idle_to_Receiving
            first Idle
            accept Document
            then Receiving;

        transition Receiving_to_Validating
            first Receiving
            then Validating;

        transition Validating_to_ExtractingMetadata
            first Validating
            if validationPassed
            then ExtractingMetadata;

        transition Validating_to_ReturningError
            first Validating
            if validationFailed
            then ReturningError;

        transition ExtractingMetadata_to_IndexingContent
            first ExtractingMetadata
            then IndexingContent;

        transition IndexingContent_to_ReturningResult
            first IndexingContent
            then ReturningResult;

        transition ReturningResult_to_RecordingAudit
            first ReturningResult
            then RecordingAudit;

        transition ReturningError_to_RecordingAudit
            first ReturningError
            then RecordingAudit;

        transition RecordingAudit_to_Completed
            first RecordingAudit
            then Completed;
    }

    part def ApiGateway {
        attribute maxDocumentBytes : Integer = 10485760;
        attribute requestTimeout : Millisecond = 30000;
        attribute supportedMediaTypes : String = "text/plain, text/markdown, application/json";

        port documentInput : DocumentInPort;
        port validatedOutput : ValidatedDocumentPort;
        port auditOutput : AuditPort;

        perform action receive : ReceiveDocument;
        perform action validate : ValidateDocument;
    }

    part def MetadataExtractor {
        attribute defaultLanguage : String = "en";
        attribute minimumConfidence : ConfidenceScore = (score = 0.75);

        port validatedInput : ValidatedDocumentPort;
        port metadataOutput : MetadataPort;
        port auditOutput : AuditPort;

        perform action extract : ExtractMetadata;
    }

    part def SearchIndexer {
        attribute indexName : String = "apache2_document_index";
        attribute maxTermsPerDocument : Integer = 50000;

        port validatedInput : ValidatedDocumentPort;
        port indexOutput : IndexPort;
        port auditOutput : AuditPort;

        perform action buildEntry : BuildSearchIndexEntry;
    }

    part def ResultComposer {
        attribute serviceVersion : VersionString = "1.0.0";
        attribute targetLatency : Millisecond = 250;

        port validatedInput : ValidatedDocumentPort;
        port metadataInput : MetadataPort;
        port indexInput : IndexPort;
        port resultOutput : ResultOutPort;
        port auditOutput : AuditPort;

        perform action composeSuccess : ComposeProcessingResult;
        perform action composeFailure : ComposeErrorReport;
    }

    part def Apache2LicenseManager {
        attribute licenseName : String = "Apache License, Version 2.0";
        attribute spdxId : SPDXIdentifier = "Apache-2.0";
        attribute licenseUrl : URI = "https://www.apache.org/licenses/LICENSE-2.0";
        attribute noticeRequired : Boolean = true;
        attribute patentGrantIncluded : Boolean = true;
        attribute trademarkGrantIncluded : Boolean = false;
        attribute sourceRedistributionPermitted : Boolean = true;
        attribute binaryRedistributionPermitted : Boolean = true;
        attribute modificationPermitted : Boolean = true;
        attribute sublicensePermitted : Boolean = true;

        port licenseOutput : LicenseInfoPort;
        port auditOutput : AuditPort;

        perform action emitNotice : EmitApache2Notice;
    }

    part def AuditLogger {
        attribute retentionDays : Integer = 365;
        attribute immutableLog : Boolean = true;

        port auditInput : AuditPort;
    }

    part def Apache2DocumentProcessingService {
        attribute serviceName : String = "Apache2 Document Processing Service";
        attribute primaryFunction : String = "Accept documents, validate them, extract metadata, index searchable content, return structured results, and expose Apache 2.0 license obligations.";
        attribute releaseLicense : SPDXIdentifier = "Apache-2.0";
        attribute availabilityTargetPercent : Real = 99.9;
        attribute peakThroughput : RequestCount = 1000;
        attribute maxStoredDocuments : DocumentCount = 10000000;

        port documentInput : DocumentInPort;
        port resultOutput : ResultOutPort;
        port licenseOutput : LicenseInfoPort;

        part gateway : ApiGateway;
        part extractor : MetadataExtractor;
        part indexer : SearchIndexer;
        part composer : ResultComposer;
        part licenseManager : Apache2LicenseManager;
        part auditLogger : AuditLogger;

        exhibit state lifecycle : ProcessingLifecycle;

        connect documentInput to gateway.documentInput;
        connect gateway.validatedOutput to extractor.validatedInput;
        connect gateway.validatedOutput to indexer.validatedInput;
        connect gateway.validatedOutput to composer.validatedInput;
        connect extractor.metadataOutput to composer.metadataInput;
        connect indexer.indexOutput to composer.indexInput;
        connect composer.resultOutput to resultOutput;
        connect licenseManager.licenseOutput to licenseOutput;

        connect gateway.auditOutput to auditLogger.auditInput;
        connect extractor.auditOutput to auditLogger.auditInput;
        connect indexer.auditOutput to auditLogger.auditInput;
        connect composer.auditOutput to auditLogger.auditInput;
        connect licenseManager.auditOutput to auditLogger.auditInput;
    }

    requirement def LicensedUnderApache2 {
        subject service : Apache2DocumentProcessingService;
        require constraint {
            service.releaseLicense == "Apache-2.0"
        }
        doc /* The released system shall be licensed under the Apache License, Version 2.0. */
    }

    requirement def PreserveCopyrightAndNotice {
        subject manager : Apache2LicenseManager;
        require constraint {
            manager.noticeRequired == true
        }
        doc /* The system shall preserve copyright statements, license text, and NOTICE content in source and binary redistributions. */
    }

    requirement def PermitUseModificationDistribution {
        subject manager : Apache2LicenseManager;
        require constraint {
            manager.sourceRedistributionPermitted == true and
            manager.binaryRedistributionPermitted == true and
            manager.modificationPermitted == true and
            manager.sublicensePermitted == true
        }
        doc /* The license model shall represent Apache 2.0 permissions for use, modification, distribution, and sublicensing. */
    }

    requirement def IncludePatentGrant {
        subject manager : Apache2LicenseManager;
        require constraint {
            manager.patentGrantIncluded == true
        }
        doc /* The license model shall include the Apache 2.0 patent grant. */
    }

    requirement def ExcludeTrademarkGrant {
        subject manager : Apache2LicenseManager;
        require constraint {
            manager.trademarkGrantIncluded == false
        }
        doc /* The license model shall indicate that Apache 2.0 does not grant trademark rights. */
    }

    requirement def ValidateInboundDocuments {
        subject gateway : ApiGateway;
        require constraint {
            gateway.maxDocumentBytes <= 10485760
        }
        doc /* The API gateway shall reject documents larger than 10 MiB and reject unsupported media types. */
    }

    requirement def ReturnStructuredResults {
        subject service : Apache2DocumentProcessingService;
        require constraint {
            service.primaryFunction != ""
        }
        doc /* The service shall return a structured processing result containing document status, metadata, index information, elapsed time, and license identifier. */
    }

    requirement def MeetResponseLatency {
        subject composer : ResultComposer;
        require constraint {
            composer.targetLatency <= 250
        }
        doc /* The result composer shall support a nominal target response composition latency of no more than 250 ms. */
    }

    requirement def AuditProcessingAndLicenseEvents {
        subject logger : AuditLogger;
        require constraint {
            logger.retentionDays >= 365 and logger.immutableLog == true
        }
        doc /* The system shall retain immutable audit events for document processing and license notice generation for at least 365 days. */
    }

    satisfy LicensedUnderApache2 by Apache2DocumentProcessingService;
    satisfy PreserveCopyrightAndNotice by Apache2LicenseManager;
    satisfy PermitUseModificationDistribution by Apache2LicenseManager;
    satisfy IncludePatentGrant by Apache2LicenseManager;
    satisfy ExcludeTrademarkGrant by Apache2LicenseManager;
    satisfy ValidateInboundDocuments by ApiGateway;
    satisfy ReturnStructuredResults by Apache2DocumentProcessingService;
    satisfy MeetResponseLatency by ResultComposer;
    satisfy AuditProcessingAndLicenseEvents by AuditLogger;
}