package EclipsePublicLicense2System {
    attribute def startCommand;
    attribute def maintenanceRequest;
    attribute def shutdownCommand;
    attribute def maintenanceComplete;

    private import ScalarValues::*;
    private import ISQ::*;
    private import Metaobjects::SemanticMetadata;
    
    metadata def LicenseMetadata :> SemanticMetadata {
        attribute licenseName : String;
        attribute licenseVersion : String;
        attribute licenseURL : String;
        attribute copyleftScope : String;
        attribute patentGrantIncluded : Boolean;
        attribute commercialUseAllowed : Boolean;
        attribute modificationAllowed : Boolean;
        attribute distributionAllowed : Boolean;
        attribute requiresSourceDisclosure : Boolean;
    }
    
    metadata def EPL_2_0 : LicenseMetadata {
        licenseName = "Eclipse Public License";
        licenseVersion = "2.0";
        licenseURL = "https://www.eclipse.org/legal/epl-2.0/";
        copyleftScope = "weak";
        patentGrantIncluded = true;
        commercialUseAllowed = true;
        modificationAllowed = true;
        distributionAllowed = true;
        requiresSourceDisclosure = true;
    }
    
    attribute def DataSize :> Real;
    attribute def ProcessingRate :> Real;
    attribute def ComplianceStatus :> Boolean;
    
    item def DataPacket {
        attribute packetId : String;
        attribute payloadSize : DataSize;
        attribute timestamp : String;
        attribute sourceAddress : String;
        attribute destinationAddress : String;
    }
    
    item def LicenseNotice {
        attribute noticeText : String;
        attribute copyrightHolder : String;
        attribute licenseVersion : String;
        attribute patentGrantStatement : String;
    }
    
    item def SourceCodeModule {
        attribute moduleName : String;
        attribute codeSize : DataSize;
        attribute licenseHeader : String;
        attribute contributors : String[1..*];
    }
    
    port def DataInputPort {
        in item incomingData : DataPacket;
    }
    
    port def DataOutputPort {
        out item outgoingData : DataPacket;
    }
    
    port def ControlPort {
        in attribute controlSignal : String;
        out attribute statusSignal : String;
    }
    
    port def LicenseCompliancePort {
        in item sourceModule : SourceCodeModule;
        out attribute complianceResult : ComplianceStatus;
    }
    
    part def DataReceiver {
        port dataIn : DataInputPort;
        port control : ControlPort;
        
        attribute bufferCapacity : DataSize;
        attribute receivedPacketCount : Integer;
        
        action def ReceiveData {
            in packet : DataPacket;
            out bufferedPacket : DataPacket;
            out receiveStatus : Boolean;
        }
    }
    
    part def DataProcessor {
        port processorIn : DataInputPort;
        port processorOut : DataOutputPort;
        port control : ControlPort;
        
        attribute processingCapacity : ProcessingRate;
        attribute queueSize : Integer;
        
        action def ProcessData {
            in rawData : DataPacket;
            out processedData : DataPacket;
            
            first start;
            then action validateInput {
                in data : DataPacket = rawData;
                out valid : Boolean;
            }
            then decide;
            if validateInput.valid then transformData;
            if not validateInput.valid then rejectData;
            
            action transformData {
                in data : DataPacket = rawData;
                out transformed : DataPacket;
            }
            then enrichData;
            
            action enrichData {
                in data : DataPacket = transformData.transformed;
                out enriched : DataPacket = processedData;
            }
            then done;
            
            action rejectData {
                out rejected : Boolean;
            }
            then done;
        }
    }
    
    part def DataTransmitter {
        port dataOut : DataOutputPort;
        port control : ControlPort;
        
        attribute transmissionRate : ProcessingRate;
        attribute transmittedPacketCount : Integer;
        
        action def TransmitData {
            in packet : DataPacket;
            out transmitted : Boolean;
        }
    }
    
    part def LicenseComplianceChecker {
        port compliancePort : LicenseCompliancePort;
        
        action def ValidateLicenseHeader {
            in module : SourceCodeModule;
            out headerValid : Boolean;
        }
        
        action def VerifyPatentGrant {
            in module : SourceCodeModule;
            out patentGrantPresent : Boolean;
        }
        
        action def CheckNoticeFile {
            in notice : LicenseNotice;
            out noticeComplete : Boolean;
        }
        
        action def PerformComplianceCheck {
            in sourceModule : SourceCodeModule;
            out compliant : ComplianceStatus;
            
            first start;
            then action checkHeader : ValidateLicenseHeader {
                in module = sourceModule;
                out headerValid;
            }
            then action checkPatent : VerifyPatentGrant {
                in module = sourceModule;
                out patentGrantPresent;
            }
            then action evaluateCompliance {
                in headerOk : Boolean = checkHeader.headerValid;
                in patentOk : Boolean = checkPatent.patentGrantPresent;
                out result : ComplianceStatus = compliant;
            }
            then done;
        }
    }
    
    part def SystemController {
        port controlOut : ControlPort[3];
        
        attribute systemState : String;
        attribute operationalMode : String;
        
        state def ControlStateMachine {
            entry; then Initializing;
            
            state Initializing;
            transition first Initializing then Ready;
            
            state Ready;
            transition ReadyToOperating first Ready accept startCommand then Operating;
            
            state Operating;
            transition OperatingToMaintenance first Operating accept maintenanceRequest then Maintenance;
            transition OperatingToShutdown first Operating accept shutdownCommand then ShuttingDown;
            
            state Maintenance;
            transition MaintenanceToReady first Maintenance accept maintenanceComplete then Ready;
            
            state ShuttingDown;
            transition ShuttingDownToStopped first ShuttingDown then Stopped;
            
            state Stopped;
        }
    }
    
    #EPL_2_0
    part def OpenSourceDataProcessingSystem {
        doc /* An open-source data processing system licensed under Eclipse Public License 2.0.
               The system receives data packets from external sources, processes them through
               a configurable pipeline, and transmits the processed results. The EPL 2.0 license
               permits commercial use, modification, and distribution while requiring source
               disclosure and including patent grants. The weak copyleft nature allows integration
               with proprietary components. */
        
        port systemInput : DataInputPort;
        port systemOutput : DataOutputPort;
        port systemControl : ControlPort;
        port complianceInterface : LicenseCompliancePort;
        
        part receiver : DataReceiver;
        part processor : DataProcessor;
        part transmitter : DataTransmitter;
        part controller : SystemController;
        part complianceChecker : LicenseComplianceChecker;
        
        connect systemInput to receiver.dataIn;
        connect receiver.control to controller.controlOut[1];
        connect receiver.dataIn to processor.processorIn;
        connect processor.processorOut to transmitter.dataOut;
        connect processor.control to controller.controlOut[2];
        connect transmitter.control to controller.controlOut[3];
        connect transmitter.dataOut to systemOutput;
        connect complianceInterface to complianceChecker.compliancePort;
        
        perform action primaryOperation : ExecuteDataProcessing;
    }
    
    action def ExecuteDataProcessing {
        first start;
        then merge continueProcessing;
        
        then action receivePacket {
            out packet : DataPacket;
        }
        then action processPacket : DataProcessor::ProcessData {
            in rawData = receivePacket.packet;
            out processedData;
        }
        then action transmitPacket : DataTransmitter::TransmitData {
            in packet = processPacket.processedData;
            out transmitted;
        }
        then decide;
        if transmitPacket.transmitted then continueProcessing;
        if not transmitPacket.transmitted then handleError;
        
        action handleError {
            out errorLogged : Boolean;
        }
        then continueProcessing;
    }
    
    requirement def LicenseComplianceRequirement {
        doc /* All distributed software components must comply with Eclipse Public License 2.0 terms */
        
        subject distributedSoftware : SourceCodeModule;
        
        require constraint licenseHeaderRequired {
            doc /* Each source file must contain EPL 2.0 license header */
        }
        
        require constraint noticeFileRequired {
            doc /* Distribution must include NOTICE file with copyright and license information */
        }
        
        require constraint patentGrantRequired {
            doc /* Contributors must grant patent rights as specified in EPL 2.0 Section 2 */
        }
        
        require constraint sourceAvailabilityRequired {
            doc /* Source code must be made available for distributed binaries */
        }
    }
    
    requirement def SystemFunctionalRequirements {
        doc /* Functional requirements for the open-source data processing system */
        
        requirement <'SYS-001'> dataReceptionRequirement {
            doc /* The system shall receive data packets from external sources via standard interfaces */
            
            require constraint validInputFormat {
                doc /* Input data must conform to defined packet structure */
            }
        }
        
        requirement <'SYS-002'> dataProcessingRequirement {
            doc /* The system shall process received data through configurable transformation pipeline */
            
            require constraint processingAccuracy {
                doc /* Data processing must maintain integrity and accuracy */
            }
            
            require constraint processingThroughput {
                doc /* System must process minimum 1000 packets per second */
            }
        }
        
        requirement <'SYS-003'> dataTransmissionRequirement {
            doc /* The system shall transmit processed data to designated destinations */
            
            require constraint transmissionReliability {
                doc /* Transmission success rate must exceed 99.9% */
            }
        }
        
        requirement <'SYS-004'> licenseComplianceRequirement : LicenseComplianceRequirement {
            doc /* The system shall comply with all EPL 2.0 license terms */
            
            assume constraint validContributors {
                doc /* All contributors have rights to contribute code */
            }
            
            require constraint continuousCompliance {
                doc /* Compliance must be verified for each release */
            }
        }
        
        requirement <'SYS-005'> modularityRequirement {
            doc /* The system shall support modular extension and modification */
            
            require constraint pluginArchitecture {
                doc /* System must support plugin-based extensions */
            }
            
            require constraint apiStability {
                doc /* Public APIs must maintain backward compatibility */
            }
        }
    }
    
    part systemInstance : OpenSourceDataProcessingSystem {
        satisfy SystemFunctionalRequirements::dataReceptionRequirement;
        satisfy SystemFunctionalRequirements::dataProcessingRequirement;
        satisfy SystemFunctionalRequirements::dataTransmissionRequirement;
        satisfy SystemFunctionalRequirements::licenseComplianceRequirement;
        satisfy SystemFunctionalRequirements::modularityRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Metaobjects::SemanticMetadata;
    private import EclipsePublicLicense2System::*;

    part testSubject : DataReceiver {
        exhibit state sm : ControlStateMachine;
    }

    action orchestrator {
        item testPacket : DataPacket {
            attribute packetId = "";
            attribute payloadSize : DataSize = 0.0;
            attribute timestamp = "";
            attribute sourceAddress = "";
            attribute destinationAddress = "";
        }
        action actionProbe : ReceiveData {
            in packet = testPacket;
        }
        attribute testStartCommand : startCommand;
        attribute testMaintenanceRequest : maintenanceRequest;
        attribute testMaintenanceComplete : maintenanceComplete;
        action triggerstartCommand send testStartCommand to testSubject;
        action triggermaintenanceRequest send testMaintenanceRequest to testSubject;
        action triggermaintenanceComplete send testMaintenanceComplete to testSubject;
        first actionProbe;
        then triggerstartCommand;
        then triggermaintenanceRequest;
        then triggermaintenanceComplete;
    }
}
