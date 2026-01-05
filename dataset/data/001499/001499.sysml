package 'Microsoft Research Intelligent Cloud Infrastructure' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def NodeCount :> Integer;
    attribute def DataRate :> Real;
    attribute def LatencyValue :> TimeValue;
    attribute def ThroughputValue :> Real;
    attribute def UtilizationPercentage :> Real;

    attribute def WorkloadRequest {
        attribute requestId : String;
        attribute priority : Integer;
        attribute resourceRequirement : ComputeCapacity;
        attribute deadline : TimeValue;
    }

    attribute def ComputeCapacity {
        attribute cpuCores : Integer;
        attribute memoryGB : Real;
        attribute storageGB : Real;
    }

    attribute def AnalyticsResult {
        attribute insights : String[*];
        attribute predictions : Real[*];
        attribute confidence : Real;
        attribute timestamp : TimeValue;
    }

    attribute def OptimizationDecision {
        attribute targetNodes : String[*];
        attribute action : String;
        attribute parameters : Real[*];
    }

    item def NetworkPacket {
        attribute source : String;
        attribute destination : String;
        attribute payload : String;
        attribute size : Real;
    }

    item def ComputeTask {
        attribute taskId : String;
        attribute workload : WorkloadRequest;
        attribute assignedNode : String;
    }

    port def WorkloadInputPort {
        in item request : WorkloadRequest;
    }

    port def DataStreamPort {
        in item dataPacket : NetworkPacket;
        out item processedData : NetworkPacket;
    }

    port def AnalyticsPort {
        out item analytics : AnalyticsResult;
    }

    port def ControlPort {
        in item decision : OptimizationDecision;
        out item status : String;
    }

    port def ResourcePort {
        out attribute available : ComputeCapacity;
        in item taskAllocation : ComputeTask;
    }

    part def LoadBalancer {
        attribute nodeCount : NodeCount;
        attribute balancingAlgorithm : String;
        port workloadIn : WorkloadInputPort;
        port resourceQuery : ResourcePort[*];
        port taskOut : ControlPort[*];
    }

    part def ComputeNode {
        attribute nodeId : String;
        attribute capacity : ComputeCapacity;
        attribute currentUtilization : UtilizationPercentage;
        port taskIn : ControlPort;
        port dataPort : DataStreamPort;
        port resourceStatus : ResourcePort;
    }

    part def AnalyticsEngine {
        attribute modelVersion : String;
        attribute trainingDataSize : Real;
        port dataIn : DataStreamPort[*];
        port analyticsOut : AnalyticsPort;
    }

    part def OptimizationController {
        attribute optimizationInterval : TimeValue;
        attribute targetEfficiency : Real;
        port analyticsIn : AnalyticsPort;
        port controlOut : ControlPort[*];
    }

    part def NetworkFabric {
        attribute bandwidth : DataRate;
        attribute latency : LatencyValue;
        port nodeConnections : DataStreamPort[*];
    }

    action def ReceiveWorkload {
        in request : WorkloadRequest;
        out validated : WorkloadRequest;
    }

    action def AnalyzeResources {
        in availableNodes : ComputeCapacity[*];
        in workload : WorkloadRequest;
        out selectedNode : String;
    }

    action def DistributeTask {
        in task : ComputeTask;
        in targetNode : String;
        out confirmation : Boolean;
    }

    action def ProcessData {
        in rawData : NetworkPacket;
        in computeResources : ComputeCapacity;
        out result : NetworkPacket;
    }

    action def GenerateAnalytics {
        in systemMetrics : Real[*];
        in historicalData : Real[*];
        out insights : AnalyticsResult;
    }

    action def OptimizeAllocation {
        in currentState : AnalyticsResult;
        in targetMetrics : Real[*];
        out decisions : OptimizationDecision;
    }

    action def ExecuteWorkloadManagement {
        in incomingRequest : WorkloadRequest;
        out completionStatus : String;

        first start;
        then action receive : ReceiveWorkload {
            in request = incomingRequest;
            out validated;
        }
        then action analyze : AnalyzeResources {
            in workload = receive.validated;
            out selectedNode;
        }
        then action distribute : DistributeTask {
            in targetNode = analyze.selectedNode;
            out confirmation;
        }
        then decide;
            if distribute.confirmation == true then processTask;
            if distribute.confirmation == false then retry;
        
        action processTask : ProcessData {
            out result;
        }
        then assign completionStatus := "Success";
        then done;

        action retry;
        then analyze;
    }

    state def CloudSystemStates {
        attribute systemOnline : Boolean;
        
        entry; then initializing;

        state initializing {
            entry assign systemOnline := false;
        }
        accept InitializationComplete;
        then operational;

        state operational {
            entry assign systemOnline := true;
            accept WorkloadReceived;
            then processing;
            
            accept AnalyticsTriggered;
            then analyzing;
            
            accept MaintenanceRequired;
            then maintenance;
        }

        state processing {
            do action handleWorkload : ExecuteWorkloadManagement;
            accept ProcessingComplete;
            then operational;
        }

        state analyzing {
            do action runAnalytics : GenerateAnalytics;
            accept AnalysisComplete;
            then optimizing;
        }

        state optimizing {
            do action optimize : OptimizeAllocation;
            accept OptimizationComplete;
            then operational;
        }

        state maintenance {
            entry assign systemOnline := false;
            accept MaintenanceComplete;
            then operational;
        }
    }

    requirement def IntelligentResourceManagement {
        doc /* The system shall intelligently manage and allocate computational resources 
               across distributed nodes based on real-time workload analysis. */

        require constraint dynamicAllocation {
            doc /* Resource allocation shall adapt within 100 milliseconds of workload changes. */
        }

        require constraint utilizationEfficiency {
            doc /* Average resource utilization shall exceed 75% during normal operation. */
        }
    }

    requirement def PredictiveAnalytics {
        doc /* The system shall provide predictive analytics to anticipate resource demands 
               and optimize infrastructure performance. */

        require constraint predictionAccuracy {
            doc /* Workload predictions shall achieve at least 85% accuracy over 1-hour horizon. */
        }

        require constraint analyticsLatency {
            doc /* Analytics generation shall complete within 5 seconds of data collection. */
        }
    }

    requirement def ScalablePerformance {
        doc /* The system shall scale horizontally to handle increasing workloads while 
               maintaining consistent performance. */

        require constraint throughputScaling {
            doc /* System throughput shall scale linearly with node count up to 1000 nodes. */
        }

        require constraint latencyBound {
            doc /* End-to-end request latency shall remain below 50 milliseconds at 80% capacity. */
        }
    }

    requirement systemRequirements {
        subject intelligentCloudSystem;

        require resourceManagement : IntelligentResourceManagement;
        require analytics : PredictiveAnalytics;
        require scalability : ScalablePerformance;
    }

    part intelligentCloudSystem {
        doc /*
        This system describes an intelligent cloud infrastructure platform based on 
        Microsoft Research's advances in distributed systems and machine learning.

        The primary function is to autonomously manage large-scale computational resources 
        by combining real-time workload distribution with predictive analytics. The system 
        continuously optimizes resource allocation across thousands of compute nodes to 
        maximize efficiency, minimize latency, and reduce operational costs.

        The system operates through an integrated control loop: A load balancer receives 
        incoming workload requests and queries available compute nodes for their current 
        capacity and utilization. Based on intelligent analysis, tasks are distributed to 
        optimal nodes through a high-speed network fabric. Simultaneously, an analytics 
        engine processes telemetry data from all nodes, generating insights about usage 
        patterns, performance trends, and potential bottlenecks. An optimization controller 
        uses these analytics to make proactive decisions, such as pre-allocating resources 
        for predicted demand spikes, migrating workloads to balance load, or scaling 
        capacity up or down. This continuous cycle of monitoring, analysis, and optimization 
        enables the infrastructure to adapt dynamically to changing conditions while 
        maintaining high performance and reliability.
        */

        part balancer : LoadBalancer {
            attribute :>> nodeCount = 500;
            attribute :>> balancingAlgorithm = "Predictive Least Loaded";
        }

        part nodes : ComputeNode[500] {
            attribute :>> capacity = ComputeCapacity {
                attribute :>> cpuCores = 64;
                attribute :>> memoryGB = 256.0;
                attribute :>> storageGB = 2000.0;
            }
            attribute :>> currentUtilization = 0.0;
        }

        part analytics : AnalyticsEngine {
            attribute :>> modelVersion = "v3.2.1";
            attribute :>> trainingDataSize = 1.0e12;
        }

        part optimizer : OptimizationController {
            attribute :>> optimizationInterval = 10.0 [SI::s];
            attribute :>> targetEfficiency = 0.85;
        }

        part network : NetworkFabric {
            attribute :>> bandwidth = 100.0e9;
            attribute :>> latency = 0.001 [SI::s];
        }

        connect balancer.resourceQuery to nodes.resourceStatus;
        connect balancer.taskOut to nodes.taskIn;
        connect nodes.dataPort to network.nodeConnections;
        connect network.nodeConnections to analytics.dataIn;
        connect analytics.analyticsOut to optimizer.analyticsIn;
        connect optimizer.controlOut to nodes.taskIn;

        perform action manageWorkloads : ExecuteWorkloadManagement;

        exhibit state systemBehavior : CloudSystemStates;
    }
}
