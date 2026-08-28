package OpenSourceDataPipeline {
    private import ScalarValues::*;

    package Definitions {
        private import ScalarValues::*;

        enumeration def CommandKind {
            value INIT;
            value START;
            value MAINTAIN;
            value RESUME;
            value SHUTDOWN;
        }

        enumeration def SystemState {
            value INITIALIZING;
            value OPERATING;
            value MAINTENANCE;
            value SHUTDOWN;
        }

        item def DataPacket {
            attribute packetId : String;
            attribute payload : String;
            attribute timestamp : Real;
            attribute size : Real;
        }

        item def ProcessedData :> DataPacket {
            attribute validated : Boolean = false;
            attribute transformed : Boolean = false;
            attribute enriched : Boolean = false;
            attribute transformationLog : String;
        }

        item def WorkflowDefinition {
            attribute orderedSteps : String[*];
            attribute strictOrdering : Boolean = true;
        }

        item def ControlCommand {
            attribute kind : CommandKind;
            attribute issuedAt : Real;
        }

        item def SystemStatus {
            attribute systemState : SystemState;
            attribute healthy : Boolean = true;
            attribute packetsProcessed : Integer = 0;
        }

        item def SourceCodeFile {
            attribute filePath : String;
            attribute content : String;
            attribute extension : String;
            attribute lineCount : Integer;
        }

        item def LicenseComplianceResult {
            attribute filePath : String;
            attribute headerPresent : Boolean = false;
            attribute patentGrantPresent : Boolean = false;
            attribute overallCompliance : Boolean = false;
        }

        item def LicenseReport {
            attribute licenseName : String = "Eclipse Public License 2.0";
            attribute totalFiles : Integer = 0;
            attribute compliantFiles : Integer = 0;
            attribute nonCompliantFiles : Integer = 0;
            attribute overallCompliance : Boolean = true;
        }

        port def DataPacketPort {
            out item data : DataPacket;
        }

        port def ProcessedDataPort {
            out item data : ProcessedData;
        }

        port def ControlPort {
            in item commandIn : ControlCommand;
            out item statusOut : SystemStatus;
        }

        port def SourceAnalysisPort {
            in item sourceFile : SourceCodeFile;
            out item result : LicenseComplianceResult;
        }

        port def ReportPort {
            out item report : LicenseReport;
        }

        port def SourceCodePort {
            out item sourceFile : SourceCodeFile;
        }

        action def IngestData {
            in dataIn : DataPacket;
            out dataOut : DataPacket;
        }

        action def ProcessDataWorkflow {
            in dataIn : DataPacket;
            out dataOut : ProcessedData;
            action validate;
            action transform;
            action enrich;
        }

        action def TransmitData {
            in dataIn : ProcessedData;
            out dataOut : ProcessedData;
        }

        action def CheckLicenseCompliance {
            in sourceFile : SourceCodeFile;
            out result : LicenseComplianceResult;
            out report : LicenseReport;
            action checkHeader;
            action checkPatentGrant;
        }

        part def DataReceiver {
            port dataInPort : ~DataPacketPort;
            port dataOutPort : DataPacketPort;
            port controlPort : ControlPort;
            attribute maxBufferSize : Real;
            attribute currentBufferCount : Integer = 0;
            item buffer : DataPacket[*];

            perform action ingest : IngestData {
                in dataIn = dataInPort.data;
                out dataOut = dataOutPort.data;
            }
        }

        part def DataValidator;
        part def DataTransformer;
        part def DataEnricher;

        part def DataProcessor {
            port dataInPort : ~DataPacketPort;
            port dataOutPort : ProcessedDataPort;
            port controlPort : ControlPort;
            attribute workflow : WorkflowDefinition;

            perform action processData : ProcessDataWorkflow {
                in dataIn = dataInPort.data;
                out dataOut = dataOutPort.data;
            }
            part validator : DataValidator {
                perform processData.validate;
            }
            part transformer : DataTransformer {
                perform processData.transform;
            }
            part enricher : DataEnricher {
                perform processData.enrich;
            }
        }

        part def DataTransmitter {
            port dataInPort : ~ProcessedDataPort;
            port dataOutPort : ProcessedDataPort;
            port controlPort : ControlPort;
            attribute transmissionRate : Real;

            perform action transmit : TransmitData {
                in dataIn = dataInPort.data;
                out dataOut = dataOutPort.data;
            }
        }

        part def SystemController {
            port controlPort1 : ~ControlPort;
            port controlPort2 : ~ControlPort;
            port controlPort3 : ~ControlPort;
            port controlPort4 : ~ControlPort;
            attribute currentCommand : ControlCommand;
            attribute currentState : SystemState = SystemState::INITIALIZING;

            state machine controllerBehavior {
                state initializing;
                state operating;
                state maintenance;
                state shutdown;

                transition initial to initializing;
                transition from initializing to operating
                    when currentCommand.kind == CommandKind::START;
                transition from operating to maintenance
                    when currentCommand.kind == CommandKind::MAINTAIN;
                transition from maintenance to operating
                    when currentCommand.kind == CommandKind::RESUME;
                transition from operating to shutdown
                    when currentCommand.kind == CommandKind::SHUTDOWN;
                transition from maintenance to shutdown
                    when currentCommand.kind == CommandKind::SHUTDOWN;
                transition from initializing to shutdown
                    when currentCommand.kind == CommandKind::SHUTDOWN;
            }
        }

        part def HeaderChecker;
        part def PatentGrantChecker;

        part def LicenseComplianceChecker {
            port controlPort : ControlPort;
            port sourceAnalysisPort : SourceAnalysisPort;
            port reportPort : ReportPort;
            attribute licenseIdentifier : String = "Eclipse Public License 2.0";
            attribute requiredHeaderText : String;
            attribute requiredPatentGrantText : String;

            perform action checkCompliance : CheckLicenseCompliance {
                in sourceFile = sourceAnalysisPort.sourceFile;
                out result = sourceAnalysisPort.result;
                out report = reportPort.report;
            }
            part headerChecker : HeaderChecker {
                perform checkCompliance.checkHeader;
            }
            part patentChecker : PatentGrantChecker {
                perform checkCompliance.checkPatentGrant;
            }
        }
    }

    package Requirements {
        private import Definitions::*;

        requirement def DataProcessingRequirement {
            doc { /* The system shall receive, process, and transmit data packets through an ordered pipeline. */ }
        }

        requirement def LicenseComplianceRequirement {
            attribute licenseName : String = "Eclipse Public License 2.0";
            doc { /* The License Compliance Checker shall verify that source code files contain EPL 2.0 license headers and patent grant statements. */ }
        }

        requirement def StateManagementRequirement {
            doc { /* The System Controller shall direct the system through initializing, operating, maintenance, and shutdown states. */ }
        }

        requirement def PerformanceRequirement {
            attribute maxProcessingLatency : Real = 100;
            doc { /* The data processor shall process each packet within 100 ms. */ }
        }

        requirement dataFlowReq : DataProcessingRequirement;
        requirement licenseReq : LicenseComplianceRequirement;
        requirement stateReq : StateManagementRequirement;
        requirement performanceReq : PerformanceRequirement;
    }

    package Usages {
        private import Definitions::*;
        private import Requirements::*;

        part def DataPipeline {
            port externalDataIn : ~DataPacketPort;
            port externalDataOut : ProcessedDataPort;
            port externalSourceIn : ~SourceCodePort;
            port externalReport : ReportPort;

            part dataReceiver : DataReceiver;
            part dataProcessor : DataProcessor;
            part dataTransmitter : DataTransmitter;
            part systemController : SystemController;
            part licenseChecker : LicenseComplianceChecker;

            flow of data : DataPacket
                from externalDataIn.data to dataReceiver.dataInPort.data;
            flow of data : DataPacket
                from dataReceiver.dataOutPort.data to dataProcessor.dataInPort.data;
            flow of data : ProcessedData
                from dataProcessor.dataOutPort.data to dataTransmitter.dataInPort.data;
            flow of data : ProcessedData
                from dataTransmitter.dataOutPort.data to externalDataOut.data;

            flow of sourceFile : SourceCodeFile
                from externalSourceIn.sourceFile to licenseChecker.sourceAnalysisPort.sourceFile;
            flow of report : LicenseReport
                from licenseChecker.reportPort.report to externalReport.report;

            connection controlToReceiver
                connect systemController.controlPort1 to dataReceiver.controlPort;
            connection controlToProcessor
                connect systemController.controlPort2 to dataProcessor.controlPort;
            connection controlToTransmitter
                connect systemController.controlPort3 to dataTransmitter.controlPort;
            connection controlToChecker
                connect systemController.controlPort4 to licenseChecker.controlPort;

            satisfy dataFlowReq by dataReceiver, dataProcessor, dataTransmitter;
            satisfy licenseReq by licenseChecker;
            satisfy stateReq by systemController;
            satisfy performanceReq by dataProcessor;
        }
    }
}
