package AutonomousCloudInfrastructure {
    import ScalarValues::*;
    
    value def CoreCount :> Integer {
        attribute unit : String = "cores";
    }
    value def MemorySize :> Integer {
        attribute unit : String = "GB";
    }
    value def StorageSize :> Real {
        attribute unit : String = "TB";
    }
    value def DataRate :> Real {
        attribute unit : String = "Gbps";
    }
    value def Latency :> Real {
        attribute unit : String = "ms";
    }
    value def Efficiency :> Real {
        attribute unit : String = "percent";
    }
    value def TimeDuration :> Real {
        attribute unit : String = "s";
    }
    
    item def WorkloadRequest {
        attribute id : String;
        attribute requiredCores : CoreCount;
        attribute requiredMemory : MemorySize;
    }
    
    item def TelemetryData {
        attribute nodeId : String;
        attribute cpuUtilization : Efficiency;
        attribute memoryUtilization : Efficiency;
        attribute activeCores : CoreCount;
    }
    
    item def PredictiveInsight {
        attribute expectedDemandSpike : Boolean;
        attribute bottleneckNode : String;
        attribute trendAnalysis : String;
    }
    
    item def OptimizationCommand {
        attribute commandId : String;
        attribute actionType : String;
        attribute sourceNode : String;
        attribute targetNode : String;
    }
    
    part def ComputeNode {
        attribute nodeId : String;
        attribute coreCount : CoreCount = 64;
        attribute memoryCapacity : MemorySize = 256;
        attribute storageCapacity : StorageSize = 2.0;
        
        port in workloadRequest : WorkloadRequest;
        port out telemetryOutput : TelemetryData;
        port in optimizationCommand : OptimizationCommand;
        
        state nodeStates {
            state Idle;
            state Processing;
            state Optimizing;
            transition init -> Idle;
            transition startProcessing Idle -> Processing when workloadRequest ?workload;
            transition finishProcessing Processing -> Idle;
            transition startOptimizing Idle -> Optimizing when optimizationCommand ?cmd;
            transition finishOptimizing Optimizing -> Idle;
        }
    }
    
    part def NetworkFabric {
        attribute bandwidth : DataRate = 100.0;
        attribute latency : Latency = 0.01;
        
        port in loadBalancerInput : WorkloadRequest;
        port out computeNodeOutput : WorkloadRequest;
        
        port in computeNodeTelemetryInput : TelemetryData;
        port out analyticsEngineTelemetryOutput : TelemetryData;
        
        port in optimizationControllerCommandInput : OptimizationCommand;
        port out computeNodeCommandOutput : OptimizationCommand;
    }
    
    part def LoadBalancer {
        port in workloadInput : WorkloadRequest;
        port in telemetryInput : TelemetryData[*];
        port in commandInput : OptimizationCommand;
        port out workloadOutput : WorkloadRequest;
        
        action def PredictiveAssignment {
            in req : WorkloadRequest;
            in telemetry : TelemetryData[*];
            out assignedReq : WorkloadRequest;
        }
    }
    
    part def AnalyticsEngine {
        port in telemetryInput : TelemetryData;
        port out insightOutput : PredictiveInsight;
        
        action def GeneratePredictiveInsights {
            in telemetry : TelemetryData[*];
            out insight : PredictiveInsight;
        }
    }
    
    part def OptimizationController {
        attribute targetEfficiency : Efficiency = 85.0;
        attribute reviewInterval : TimeDuration = 10.0;
        
        port in insightInput : PredictiveInsight;
        port out commandOutput : OptimizationCommand;
        
        action def OptimizeSystem {
            in insight : PredictiveInsight;
            out cmd : OptimizationCommand;
        }
    }
    
    part def CloudInfrastructure {
        part computeNodes : ComputeNode[500];
        part networkFabric : NetworkFabric;
        part loadBalancer : LoadBalancer;
        part analyticsEngine : AnalyticsEngine;
        part optimizationController : OptimizationController;
        
        connection lbToFabric connect loadBalancer.workloadOutput to networkFabric.loadBalancerInput;
        connection fabricToNodes connect networkFabric.computeNodeOutput to computeNodes.workloadRequest;
        connection nodesToFabric connect computeNodes.telemetryOutput to networkFabric.computeNodeTelemetryInput;
        connection fabricToAnalytics connect networkFabric.analyticsEngineTelemetryOutput to analyticsEngine.telemetryInput;
        connection analyticsToOpt connect analyticsEngine.insightOutput to optimizationController.insightInput;
        connection optToFabric connect optimizationController.commandOutput to networkFabric.optimizationControllerCommandInput;
        connection fabricToNodesCmd connect networkFabric.computeNodeCommandOutput to computeNodes.optimizationCommand;
        connection optToLbCmd connect optimizationController.commandOutput to loadBalancer.commandInput;
        
        state machine platformStates {
            state Initialization;
            state NormalOperational;
            state Maintenance;
            
            transition initComplete Initialization -> NormalOperational;
            transition toMaintenance NormalOperational -> Maintenance;
            transition resumeOps Maintenance -> NormalOperational;
            
            state NormalOperational {
                state ProcessingWorkloads;
                state RunningAnalytics;
                state Optimizing;
                
                transition startAnalytics ProcessingWorkloads -> RunningAnalytics;
                transition startOptimization RunningAnalytics -> Optimizing;
                transition completeOptimization Optimizing -> ProcessingWorkloads;
            }
        }
    }
    
    requirement def SystemSpecs {
        subject system : CloudInfrastructure;
        doc computeReq : "The system shall consist of 500 compute nodes, each with 64 cores, 256 GB memory, and 2 TB storage.";
        doc networkReq : "The network fabric shall provide 100 Gbps bandwidth and low latency.";
        doc loadBalancerReq : "The load balancer shall use predictive analytics to select the optimal compute node for workloads.";
        doc analyticsReq : "The analytics engine shall monitor telemetry and generate predictive insights.";
        doc optimizationReq : "The optimization controller shall review every 10 seconds against an 85 percent efficiency goal and issue optimization commands.";
        doc statesReq : "The system shall operate in Initialization, Normal Operational, and Maintenance states.";
    }
}
