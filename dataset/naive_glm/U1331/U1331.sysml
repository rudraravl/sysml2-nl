package DataProcessingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    value type DataRate :> Real { unit 'kb/s'; }
    value type PacketSize :> Integer { unit 'byte'; }
    value type BufferCapacity :> Integer { unit 'packet'; }
    value type ProcessingTime :> Real { unit 'ms'; }
    value type Latency :> Real { unit 'ms'; }

    // ---------- Item Types ----------
    item def RawDataPacket {
        attribute id : String;
        attribute payload : String;
        attribute timestamp : DateTime;
        attribute sourceId : String;
        attribute size : PacketSize;
    }

    item def ProcessedDataPacket {
        attribute id : String;
        attribute payload : String;
        attribute timestamp : DateTime;
        attribute sourceId : String;
        attribute enrichedMetadata : String;
        attribute validationStatus : ValidationStatus;
    }

    enum def ValidationStatus { valid; invalid; warning; }

    item def ControlCommand {
        attribute commandType : CommandType;
        attribute target : String;
        attribute params : String;
    }

    enum def CommandType { start; stop; pause; resume; reconfigure; }

    item def SourceFile {
        attribute filePath : String;
        attribute content : String;
        attribute language : String;
    }

    item def ComplianceReport {
        attribute totalFiles : Integer;
        attribute compliantFiles : Integer;
        attribute nonCompliantFiles : Integer;
        attribute missingHeaders : Integer;
        attribute missingPatentStatements : Integer;
        attribute details : String;
    }

    item def WorkflowDefinition {
        attribute name : String;
        attribute steps : String;
        attribute version : String;
    }

    // ---------- Port Definitions ----------
    port def RawDataInPort {
        in item rawPackets : RawDataPacket;
    }

    port def ProcessedDataOutPort {
        out item processedPackets : ProcessedDataPacket;
    }

    port def InternalDataPort {
        in item rawPackets : RawDataPacket;
        out item processedPackets : ProcessedDataPacket;
    }

    port def ControlPort {
        in item commands : ControlCommand;
        out item status : SystemStatus;
    }

    port def SourceCodePort {
        out item sourceFiles : SourceFile;
    }

    port def ComplianceReportPort {
        out item reports : ComplianceReport;
    }

    item def SystemStatus {
        attribute stateName : String;
        attribute uptime : Real;
        attribute packetsProcessed : Integer;
        attribute errors : Integer;
    }

    // ---------- Data Receiver ----------
    part def DataReceiver {
        port rawIn : RawDataInPort;
        port dataOut : InternalDataPort;
        port ctrlIn : ControlPort;

        attribute maxBufferCapacity : BufferCapacity = 1000;
        attribute currentBufferCount : Integer = 0;
        attribute receiveRate : DataRate;

        item buffer : RawDataPacket[0..*];

        action def receivePacket {
            in item incoming : RawDataPacket;
            out item buffered : RawDataPacket;
            // Buffer the incoming packet
        }

        action def forwardPacket {
            in item buffered : RawDataPacket;
            out item forwarded : RawDataPacket;
            // Forward packet to processor
        }

        state def ReceiverBehavior {
            entry; then Idle;
            state Idle;
            state Receiving;
            state Forwarding;
            state BufferFull;
            transition idle_to_receiving
                first Idle
                then Receiving
                accept rawIn.rawPackets;
            transition receiving_to_forwarding
                first Receiving
                then Forwarding
                when currentBufferCount > 0;
            transition forwarding_to_idle
                first Forwarding
                then Idle
                when currentBufferCount == 0;
            transition receiving_to_bufferfull
                first Receiving
                then BufferFull
                when currentBufferCount >= maxBufferCapacity;
            transition bufferfull_to_receiving
                first BufferFull
                then Receiving
                when currentBufferCount < maxBufferCapacity;
        }

        exhibit ReceiverBehavior;
    }

    // ---------- Data Processor ----------
    part def DataProcessor {
        port dataIn : InternalDataPort;
        port dataOut : InternalDataPort;
        port ctrlIn : ControlPort;

        attribute processingLatency : ProcessingTime = 5.0;
        attribute activeWorkflow : WorkflowDefinition;

        action def validate {
            in item raw : RawDataPacket;
            out item validated : RawDataPacket;
            out item status : ValidationStatus;
            // Validate packet structure and content
        }

        action def transform {
            in item raw : RawDataPacket;
            out item transformed : RawDataPacket;
            // Transform data format
        }

        action def enrich {
            in item raw : RawDataPacket;
            out item enriched : ProcessedDataPacket;
            // Add metadata and enrichment
        }

        action def processPacket {
            in item raw : RawDataPacket;
            out item processed : ProcessedDataPacket;
            // Full processing pipeline
            first validate;
            then transform;
            then enrich;
        }

        state def ProcessorBehavior {
            entry; then Ready;
            state Ready;
            state Validating;
            state Transforming;
            state Enriching;
            state Error;
            transition ready_to_validating
                first Ready
                then Validating
                accept dataIn.rawPackets;
            transition validating_to_transforming
                first Validating
                then Transforming
                when true;
            transition transforming_to_enriching
                first Transforming
                then Enriching
                when true;
            transition enriching_to_ready
                first Enriching
                then Ready
                when true;
            transition any_to_error
                first {Validating, Transforming, Enriching}
                then Error
                when false;
            transition error_to_ready
                first Error
                then Ready
                accept ctrlIn.commands;
        }

        exhibit ProcessorBehavior;
    }

    // ---------- Data Transmitter ----------
    part def DataTransmitter {
        port dataIn : InternalDataPort;
        port dataOut : ProcessedDataOutPort;
        port ctrlIn : ControlPort;

        attribute transmitRate : DataRate;
        attribute destinationEndpoint : String;
        attribute retryCount : Integer = 0;
        attribute maxRetries : Integer = 3;

        action def transmitPacket {
            in item processed : ProcessedDataPacket;
            // Transmit to final destination
        }

        action def retryTransmission {
            in item processed : ProcessedDataPacket;
            // Retry failed transmission
        }

        state def TransmitterBehavior {
            entry; then Standby;
            state Standby;
            state Transmitting;
            state Retrying;
            state Failed;
            transition standby_to_transmitting
                first Standby
                then Transmitting
                accept dataIn.processedPackets;
            transition transmitting_to_standby
                first Transmitting
                then Standby
                when true;
            transition transmitting_to_retrying
                first Transmitting
                then Retrying
                when retryCount < maxRetries;
            transition retrying_to_transmitting
                first Retrying
                then Transmitting
                when retryCount < maxRetries;
            transition retrying_to_failed
                first Retrying
                then Failed
                when retryCount >= maxRetries;
            transition failed_to_standby
                first Failed
                then Standby
                accept ctrlIn.commands;
        }

        exhibit TransmitterBehavior;
    }

    // ---------- System Controller ----------
    part def SystemController {
        port ctrlOut1 : ControlPort;
        port ctrlOut2 : ControlPort;
        port ctrlOut3 : ControlPort;
        port ctrlIn : ControlPort;
        port statusOut : ControlPort;

        attribute systemState : String;
        attribute uptime : Real = 0.0;
        attribute packetsProcessed : Integer = 0;
        attribute errorCount : Integer = 0;

        action def initializeSystem {
            // Initialize all subsystems
        }

        action def shutdownSystem {
            // Graceful shutdown
        }

        action def enterMaintenance {
            // Enter maintenance mode
        }

        action def resumeOperation {
            // Resume from maintenance
        }

        state def ControllerBehavior {
            entry; then Initializing;
            state Initializing {
                entry action initializeSystem;
            }
            state Operating;
            state Maintenance;
            state Shutdown {
                entry action shutdownSystem;
            }
            transition init_to_operating
                first Initializing
                then Operating
                when true;
            transition operating_to_maintenance
                first Operating
                then Maintenance
                accept ctrlIn.commands;
            transition maintenance_to_operating
                first Maintenance
                then Operating
                accept ctrlIn.commands;
            transition operating_to_shutdown
                first Operating
                then Shutdown
                accept ctrlIn.commands;
            transition maintenance_to_shutdown
                first Maintenance
                then Shutdown
                accept ctrlIn.commands;
        }

        exhibit ControllerBehavior;
    }

    // ---------- License Compliance Checker ----------
    part def LicenseComplianceChecker {
        port sourceIn : SourceCodePort;
        port reportOut : ComplianceReportPort;
        port ctrlIn : ControlPort;

        attribute licenseName : String = "Eclipse Public License 2.0";
        attribute licenseHeaderTemplate : String = "EPL-2.0 header text";
        attribute patentGrantText : String = "patent grant statement";
        attribute scanInterval : Real = 3600.0;

        action def scanSourceFiles {
            in item files : SourceFile[0..*];
            out item report : ComplianceReport;
            // Scan all source files for compliance
        }

        action def checkLicenseHeader {
            in item file : SourceFile;
            out item hasHeader : Boolean;
            // Verify EPL 2.0 header presence
        }

        action def checkPatentGrant {
            in item file : SourceFile;
            out item hasPatentStatement : Boolean;
            // Verify patent grant statement presence
        }

        action def generateReport {
            in item totalFiles : Integer;
            in item compliantFiles : Integer;
            in item missingHeaders : Integer;
            in item missingPatentStatements : Integer;
            out item report : ComplianceReport;
            // Generate compliance report
        }

        state def ComplianceCheckerBehavior {
            entry; then Inactive;
            state Inactive;
            state Scanning;
            state Reporting;
            state Alerting;
            transition inactive_to_scanning
                first Inactive
                then Scanning
                accept sourceIn.sourceFiles;
            transition scanning_to_reporting
                first Scanning
                then Reporting
                when true;
            transition reporting_to_inactive
                first Reporting
                then Inactive
                when true;
            transition reporting_to_alerting
                first Reporting
                then Alerting
                when false;
            transition alerting_to_inactive
                first Alerting
                then Inactive
                accept ctrlIn.commands;
        }

        exhibit ComplianceCheckerBehavior;
    }

    // ---------- Top-level System ----------
    part def DataProcessingSystem {
        port externalDataIn : RawDataInPort;
        port externalDataOut : ProcessedDataOutPort;
        port systemControl : ControlPort;
        port complianceReport : ComplianceReportPort;
        port sourceCodeAccess : SourceCodePort;

        part receiver : DataReceiver {
            port rawIn : RawDataInPort;
            port dataOut : InternalDataPort;
            port ctrlIn : ControlPort;
        }

        part processor : DataProcessor {
            port dataIn : InternalDataPort;
            port dataOut : InternalDataPort;
            port ctrlIn : ControlPort;
        }

        part transmitter : DataTransmitter {
            port dataIn : InternalDataPort;
            port dataOut : ProcessedDataOutPort;
            port ctrlIn : ControlPort;
        }

        part controller : SystemController {
            port ctrlOut1 : ControlPort;
            port ctrlOut2 : ControlPort;
            port ctrlOut3 : ControlPort;
            port ctrlIn : ControlPort;
            port statusOut : ControlPort;
        }

        part licenseChecker : LicenseComplianceChecker {
            port sourceIn : SourceCodePort;
            port reportOut : ComplianceReportPort;
            port ctrlIn : ControlPort;
        }

        // External data input to receiver
        connect externalDataIn to receiver.rawIn;
        // Receiver to processor data flow
        connect receiver.dataOut to processor.dataIn;
        // Processor to transmitter data flow
        connect processor.dataOut to transmitter.dataIn;
        // Transmitter to external output
        connect transmitter.dataOut to externalDataOut;

        // Controller commands to subsystems
        connect controller.ctrlOut1 to receiver.ctrlIn;
        connect controller.ctrlOut2 to processor.ctrlIn;
        connect controller.ctrlOut3 to transmitter.ctrlIn;
        // Controller also manages license checker
        connect controller.statusOut to licenseChecker.ctrlIn;

        // External control input
        connect systemControl to controller.ctrlIn;

        // Source code access to license checker
        connect sourceCodeAccess to licenseChecker.sourceIn;
        // Compliance report output
        connect licenseChecker.reportOut to complianceReport;
    }

    // ---------- Requirements ----------
    requirement def SystemRequirements {
        subject system : DataProcessingSystem;

        requirement ReceiveDataPackets {
            subject :>> system;
            doc /* The system shall receive data packets from external sources. */
        }

        requirement BufferDataPackets {
            subject :>> system;
            doc /* The Data Receiver shall buffer incoming data packets up to a maximum capacity. */
        }

        requirement ProcessDataPackets {
            subject :>> system;
            doc /* The Data Processor shall validate, transform, and enrich data packets according to a defined workflow. */
        }

        requirement TransmitProcessedData {
            subject :>> system;
            doc /* The Data Transmitter shall send processed data packets to a final destination. */
        }

        requirement ManageSystemStates {
            subject :>> system;
            doc /* The System Controller shall transition the system through initializing, operating, maintenance, and shutdown states. */
        }

        requirement CheckLicenseCompliance {
            subject :>> system;
            doc /* The License Compliance Checker shall analyze the system's own source code for compliance with the Eclipse Public License 2.0. */
        }

        requirement VerifyLicenseHeaders {
            subject :>> system;
            doc /* The License Compliance Checker shall verify that source code files contain correct EPL 2.0 license headers. */
        }

        requirement VerifyPatentGrants {
            subject :>> system;
            doc /* The License Compliance Checker shall verify that required patent grant statements are present in source code files. */
        }

        requirement ConfigurablePipeline {
            subject :>> system;
            doc /* The system shall operate as a configurable data pipeline with definable workflows. */
        }

        requirement DistributableProject {
            subject :>> system;
            doc /* The system shall represent a complete, distributable open-source project, not just a running application. */
        }
    }

    // ---------- Verification ----------
    verification VerifyDataFlow {
        subject : DataProcessingSystem;
        doc /* Verify that data flows correctly from receiver through processor to transmitter. */
    }

    verification VerifyStateTransitions {
        subject : DataProcessingSystem;
        doc /* Verify that the system controller transitions through all required states. */
    }

    verification VerifyLicenseChecking {
        subject : DataProcessingSystem;
        doc /* Verify that the license compliance checker correctly identifies EPL 2.0 compliance issues. */
    }

}
