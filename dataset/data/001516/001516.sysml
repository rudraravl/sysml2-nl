package OpenSourceModelSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def LicenseType {
        attribute licenseId : String;
        attribute licenseName : String;
        attribute isOSIApproved : Boolean;
    }
    
    attribute def VersionIdentifier {
        attribute major : Integer;
        attribute minor : Integer;
        attribute patch : Integer;
    }
    
    value def DataRateValue :> ISQ::PowerValue;
    value def FrequencyValue :> ISQ::frequency;
    value def TemperatureValue :> ISQ::thermodynamicTemperature;
    
    item def DataPacket {
        attribute packetId : String;
        attribute timestamp : Real;
        attribute payload : String;
        attribute size : Integer;
    }
    
    item def ConfigurationData {
        attribute modelParameters : String;
        attribute optimizationSettings : String;
        attribute resourceAllocation : Integer;
    }
    
    port def DataInputPort {
        in dataStream : DataPacket;
    }
    
    port def DataOutputPort {
        out processedData : DataPacket;
    }
    
    port def ControlPort {
        in controlSignal : String;
        out statusResponse : String;
    }
    
    port def MonitoringPort {
        out performanceMetrics : Real;
        out healthStatus : Boolean;
    }
    
    part def OpenSourceRepository {
        attribute repositoryUrl : String;
        attribute license : LicenseType;
        attribute version : VersionIdentifier;
        attribute contributorCount : Integer;
        attribute forkCount : Integer;
        attribute starCount : Integer;
        attribute lastUpdateTimestamp : Real;
    }
    
    part def ModelCore {
        attribute modelName : String;
        attribute architecture : String;
        attribute parameterCount : Integer;
        attribute trainingDataset : String;
        attribute accuracy : Real;
        port dataIn : DataInputPort;
        port dataOut : DataOutputPort;
        port control : ControlPort;
    }
    
    part def InferenceEngine {
        attribute engineType : String;
        attribute batchSize : Integer;
        attribute throughput : DataRateValue;
        attribute latency : Real;
        port modelInterface : DataInputPort;
        port resultInterface : DataOutputPort;
    }
    
    part def DataPreprocessor {
        attribute normalizationMethod : String;
        attribute filteringEnabled : Boolean;
        attribute validationRules : String;
        port rawDataIn : DataInputPort;
        port cleanDataOut : DataOutputPort;
    }
    
    part def ResultPostprocessor {
        attribute formattingRules : String;
        attribute aggregationMethod : String;
        port inferenceIn : DataInputPort;
        port finalOut : DataOutputPort;
    }
    
    part def MonitoringSubsystem {
        attribute samplingRate : FrequencyValue;
        attribute alertThreshold : Real;
        attribute logRetentionPeriod : Real;
        port systemMonitor : MonitoringPort;
    }
    
    part def CommunityInterface {
        attribute issueTrackerUrl : String;
        attribute discussionForumUrl : String;
        attribute contributionGuidelinesUrl : String;
        attribute activeContributors : Integer;
        attribute openIssues : Integer;
        attribute mergedPullRequests : Integer;
    }
    
    action def LoadModel {
        in repositorySource : String;
        in versionTag : VersionIdentifier;
        out modelInstance : String;
        out loadStatus : Boolean;
    }
    
    action def PreprocessInput {
        in rawInput : DataPacket;
        out normalizedInput : DataPacket;
    }
    
    action def ExecuteInference {
        in inputData : DataPacket;
        out inferenceResult : DataPacket;
    }
    
    action def PostprocessResult {
        in rawResult : DataPacket;
        out formattedResult : DataPacket;
    }
    
    action def MonitorPerformance {
        in systemMetrics : Real;
        out healthCheck : Boolean;
    }
    
    action def UpdateModel {
        in newVersion : VersionIdentifier;
        in updateSource : String;
        out updateSuccess : Boolean;
    }
    
    state def SystemOperationalState {
        entry; then initializing;
        
        state initializing {
            entry; then loadingModel;
            state loadingModel;
            state configuringPipeline;
            transition loadingModel_to_configuringPipeline
                first loadingModel
                then configuringPipeline;
        }
        
        transition initializing_to_ready
            first initializing
            then ready;
        
        state ready {
            entry; then idle;
            
            state idle;
            state processing;
            state monitoring;
            
            transition idle_to_processing
                first idle
                then processing;
            
            transition processing_to_monitoring
                first processing
                then monitoring;
            
            transition monitoring_to_idle
                first monitoring
                then idle;
        }
        
        state updating;
        transition ready_to_updating
            first ready
            then updating;
        
        transition updating_to_initializing
            first updating
            then initializing;
        
        state maintenance;
        transition ready_to_maintenance
            first ready
            then maintenance;
        
        transition maintenance_to_ready
            first maintenance
            then ready;
        
        state error;
        transition ready_to_error
            first ready
            then error;
        
        transition error_to_initializing
            first error
            then initializing;
    }
    
    action def OperateOpenSourceSystem {
        first start;
        
        then action loadModelAction : LoadModel;
        
        then merge processingCycle;
        
        then action preprocessAction : PreprocessInput;
        
        then action inferenceAction : ExecuteInference;
        
        then action postprocessAction : PostprocessResult;
        
        then action monitorAction : MonitorPerformance;
        
        then decide;
            if monitorAction.healthCheck == true then continueProcessing;
            if monitorAction.healthCheck == false then handleError;
        
        action continueProcessing;
        then checkUpdate;
        
        action handleError;
        then processingCycle;
        
        action checkUpdate;
        then decide;
            if checkUpdate then performUpdate;
        
        action performUpdate : UpdateModel;
        
        then processingCycle;
        then done;
    }
    
    part openSourceInferenceSystem {
        attribute systemIdentifier : String = "OSS-ML-Platform-v2";
        attribute deploymentEnvironment : String = "Cloud-Native";
        attribute maxConcurrentRequests : Integer = 1000;
        attribute averageResponseTime : Real = 45.0;
        attribute systemUptime : Real = 99.7;
        
        part repository : OpenSourceRepository {
            attribute :>> repositoryUrl = "https://github.com/ml-community/inference-platform";
            attribute :>> license : LicenseType {
                attribute licenseId = "MIT";
                attribute licenseName = "MIT License";
                attribute isOSIApproved = true;
            }
            attribute :>> version : VersionIdentifier {
                attribute major = 2;
                attribute minor = 5;
                attribute patch = 3;
            }
            attribute :>> contributorCount = 342;
            attribute :>> forkCount = 1567;
            attribute :>> starCount = 8924;
            attribute :>> lastUpdateTimestamp = 1704067200.0;
        }
        
        part modelCore : ModelCore {
            attribute :>> modelName = "TransformerNet-OSS";
            attribute :>> architecture = "Transformer-based Neural Network";
            attribute :>> parameterCount = 175000000;
            attribute :>> trainingDataset = "CommonCrawl-2023";
            attribute :>> accuracy = 94.8;
        }
        
        part preprocessor : DataPreprocessor {
            attribute :>> normalizationMethod = "Z-score";
            attribute :>> filteringEnabled = true;
            attribute :>> validationRules = "JSON-Schema-v7";
        }
        
        part inferenceEngine : InferenceEngine {
            attribute :>> engineType = "ONNX-Runtime";
            attribute :>> batchSize = 32;
            attribute :>> throughput = 500.0 [kg];
            attribute :>> latency = 12.5;
        }
        
        part postprocessor : ResultPostprocessor {
            attribute :>> formattingRules = "REST-API-Standard";
            attribute :>> aggregationMethod = "Weighted-Average";
        }
        
        part monitor : MonitoringSubsystem {
            attribute :>> samplingRate = 10.0 [Hz];
            attribute :>> alertThreshold = 0.95;
            attribute :>> logRetentionPeriod = 2592000.0;
        }
        
        part community : CommunityInterface {
            attribute :>> issueTrackerUrl = "https://github.com/ml-community/inference-platform/issues";
            attribute :>> discussionForumUrl = "https://discuss.ml-community.org";
            attribute :>> contributionGuidelinesUrl = "https://github.com/ml-community/inference-platform/CONTRIBUTING.md";
            attribute :>> activeContributors = 87;
            attribute :>> openIssues = 23;
            attribute :>> mergedPullRequests = 1456;
        }
        
        connection preprocessToModel connect preprocessor.cleanDataOut to modelCore.dataIn;
        connection modelToInference connect modelCore.dataOut to inferenceEngine.modelInterface;
        connection inferenceToPostprocess connect inferenceEngine.resultInterface to postprocessor.inferenceIn;
        connection monitoringConnection connect monitor.systemMonitor to modelCore.control;
        
        exhibit systemBehavior : OperateOpenSourceSystem;
    }
    
    requirement <'REQ-OSS-001'> openSourceCompliance {
        doc /* The system shall be based on an open-source model 
             * with a recognized OSI-approved license to ensure 
             * transparency, community collaboration, and legal 
             * compliance for derivative works.
            */
        subject system :>> openSourceInferenceSystem;
        
        assert constraint {
            system.repository.license.isOSIApproved == true
        }
    }
    
    requirement <'REQ-OSS-002'> communityEngagement {
        doc /* The system shall maintain active community engagement 
             * with at least 50 active contributors to ensure 
             * continuous improvement and sustainability.
            */
        subject community :>> openSourceInferenceSystem.community;
        
        assert constraint {
            community.activeContributors >= 50
        }
    }
    
    requirement <'REQ-OSS-003'> modelAccuracy {
        doc /* The open-source model shall maintain a minimum 
             * accuracy of 90% to ensure reliable inference 
             * results for production deployments.
            */
        subject model :>> openSourceInferenceSystem.modelCore;
        
        assert constraint {
            model.accuracy >= 90.0
        }
    }
    
    requirement <'REQ-OSS-004'> systemThroughput {
        doc /* The inference engine shall process at least 
             * 400 requests per second to meet performance 
             * requirements for high-traffic applications.
            */
        subject engine :>> openSourceInferenceSystem.inferenceEngine;
        
        assert constraint {
            engine.throughput >= 400.0 [kg]
        }
    }
    
    requirement <'REQ-OSS-005'> systemReliability {
        doc /* The system shall maintain an uptime of at least 
             * 99.5% to ensure reliable service availability 
             * for production users.
            */
        subject system :>> openSourceInferenceSystem;
        
        assert constraint {
            system.systemUptime >= 99.5
        }
    }
    
    requirement <'REQ-OSS-006'> responseLatency {
        doc /* The system shall maintain an average response 
             * latency below 50 milliseconds to provide 
             * acceptable user experience.
            */
        subject system :>> openSourceInferenceSystem;
        
        assert constraint {
            system.averageResponseTime <= 50.0
        }
    }
    
    requirement primarySystemFunction {
        doc /* The open-source inference system shall provide 
             * a collaborative, transparent, and high-performance 
             * platform for deploying machine learning models, 
             * enabling community-driven development while 
             * maintaining production-grade reliability, accuracy, 
             * and throughput for real-world applications.
            */
        
        assume constraint communitySupport {
            openSourceInferenceSystem.repository.contributorCount > 100
        }
        
        require openSourceCompliance;
        require communityEngagement;
        require modelAccuracy;
        require systemThroughput;
        require systemReliability;
        require responseLatency;
    }
    
    satisfy primarySystemFunction by openSourceInferenceSystem;
}
