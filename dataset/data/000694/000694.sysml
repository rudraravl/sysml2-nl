package MikegillerSandboxSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def SessionID :> String;
    attribute def ResourceUtilization :> Real;
    attribute def ExecutionStatus :> String;
    
    attribute def ComputeCapacity :> PowerValue;
    attribute def MemorySize :> Real;
    attribute def NetworkBandwidth :> Real;
    
    item def WorkloadRequest {
        attribute requestID : SessionID;
        attribute priority : Integer;
        attribute requiredCompute : ComputeCapacity;
        attribute requiredMemory : MemorySize;
        attribute estimatedDuration : TimeValue;
    }
    
    item def WorkloadResult {
        attribute resultID : SessionID;
        attribute completionStatus : ExecutionStatus;
        attribute executionTime : TimeValue;
        attribute resourcesUsed : ResourceUtilization;
    }
    
    item def ResourceAllocation {
        attribute allocatedCompute : ComputeCapacity;
        attribute allocatedMemory : MemorySize;
        attribute allocationTimestamp : TimeValue;
    }
    
    port def WorkloadInputPort {
        in item request : WorkloadRequest;
    }
    
    port def ResultOutputPort {
        out item result : WorkloadResult;
    }
    
    port def ResourceManagementPort {
        in attribute requestResources : ResourceAllocation;
        out attribute availableResources : ResourceAllocation;
    }
    
    port def MonitoringPort {
        out attribute utilization : ResourceUtilization;
        out attribute status : ExecutionStatus;
    }
    
    part def WorkloadScheduler {
        port workloadIn : WorkloadInputPort;
        port resourceMgmt : ResourceManagementPort;
        
        attribute queueDepth : Integer;
        attribute schedulingPolicy : String;
        attribute currentQueue : WorkloadRequest[*];
        
        perform action scheduleWorkloads references scheduleAndDispatch;
    }
    
    part def ExecutionEngine {
        port workloadExec : ~WorkloadInputPort;
        port resultOut : ResultOutputPort;
        port monitoring : MonitoringPort;
        
        attribute maxConcurrentJobs : Integer;
        attribute activeJobs : Integer;
        attribute totalComputeCapacity : ComputeCapacity;
        attribute totalMemoryCapacity : MemorySize;
        
        perform action executeWorkloads references processWorkload;
        exhibit state engineState : ExecutionEngineStateMachine;
    }
    
    part def ResourceMonitor {
        port resourceStatus : ~ResourceManagementPort;
        port metrics : ~MonitoringPort;
        
        attribute samplingInterval : TimeValue;
        attribute utilizationHistory : ResourceUtilization[*];
        
        perform action monitorResources {
            out currentUtilization : ResourceUtilization;
        }
    }
    
    part def ResultAggregator {
        port resultsIn : ~ResultOutputPort;
        
        attribute aggregatedResults : WorkloadResult[*];
        attribute successRate : Real;
        
        perform action aggregateResults {
            in result : WorkloadResult;
        }
    }
    
    action def ValidateWorkload {
        in request : WorkloadRequest;
        out isValid : Boolean;
        out validationMessage : String;
    }
    
    action def AllocateResources {
        in request : WorkloadRequest;
        in availableCapacity : ResourceAllocation;
        out allocation : ResourceAllocation;
        out allocationSuccess : Boolean;
    }
    
    action def ExecuteJob {
        in request : WorkloadRequest;
        in allocation : ResourceAllocation;
        out result : WorkloadResult;
    }
    
    action def ReleaseResources {
        in allocation : ResourceAllocation;
    }
    
    action def scheduleAndDispatch {
        first start;
        then merge awaitWorkload;
        
        then action receiveRequest {
            out workload : WorkloadRequest;
        }
        
        then action validate : ValidateWorkload {
            in request = receiveRequest.workload;
            out isValid;
            out validationMessage;
        }
        
        then decide;
            if validate.isValid then allocateAction;
            if not validate.isValid then rejectWorkload;
        
        action allocateAction : AllocateResources {
            in request = receiveRequest.workload;
            in availableCapacity;
            out allocation;
            out allocationSuccess;
        }
        
        then decide;
            if allocateAction.allocationSuccess then dispatchWorkload;
            if not allocateAction.allocationSuccess then queueWorkload;
        
        action dispatchWorkload {
            in workloadToDispatch = receiveRequest.workload;
            in resourceAllocation = allocateAction.allocation;
        }
        then awaitWorkload;
        
        action queueWorkload {
            in workloadToQueue = receiveRequest.workload;
        }
        then awaitWorkload;
        
        action rejectWorkload {
            in rejectedWorkload = receiveRequest.workload;
            in reason = validate.validationMessage;
        }
        then awaitWorkload;
    }
    
    action def processWorkload {
        in workloadQueue : WorkloadRequest[*];
        out results : WorkloadResult[*] := ( );
        
        private attribute processedCount : Integer := 0;
        
        for job in workloadQueue {
            perform action execute : ExecuteJob {
                in request = job;
                in allocation;
                out result;
            }
            then assign results := results->including(execute.result);
            then assign processedCount := processedCount + 1;
            
            then perform action release : ReleaseResources {
                in allocation = execute.allocation;
            }
        }
    }
    
    state def ExecutionEngineStateMachine {
        entry; then initializing;
        
        state initializing {
            entry action initializeEngine {
                out initStatus : Boolean;
            }
        }
        transition init_to_idle
            first initializing
            accept initComplete : Boolean
            if initComplete
            then idle;
        
        state idle;
        transition idle_to_active
            first idle
            accept workloadReceived : Boolean
            if workloadReceived
            then active;
        
        state active {
            entry; then executing;
            
            state executing {
                do action executeWorkloads;
            }
            
            transition executing_to_monitoring
                first executing
                accept checkResources : Boolean
                if checkResources
                then monitoring;
            
            state monitoring {
                do action monitorResources;
            }
            
            transition monitoring_to_executing
                first monitoring
                then executing;
        }
        
        transition active_to_idle
            first active
            accept noWorkload : Boolean
            if noWorkload
            then idle;
        
        transition active_to_overloaded
            first active
            accept resourceExhausted : Boolean
            if resourceExhausted
            then overloaded;
        
        state overloaded {
            entry action throttleWorkload;
        }
        
        transition overloaded_to_active
            first overloaded
            accept resourcesAvailable : Boolean
            if resourcesAvailable
            then active;
    }
    
    part def SandboxEnvironment;
    
    part sandboxSystem : SandboxEnvironment {
        attribute systemID : SessionID = "SANDBOX-MAIN-001";
        attribute overallUtilization : ResourceUtilization;
        attribute maxThroughput : Real = 1000.0;
        
        part scheduler : WorkloadScheduler {
            :>> queueDepth = 100;
            :>> schedulingPolicy = "PriorityBased";
        }
        
        part engine : ExecutionEngine {
            :>> maxConcurrentJobs = 50;
            :>> activeJobs = 0;
        }
        
        part monitor : ResourceMonitor;
        
        part aggregator : ResultAggregator {
            :>> successRate = 0.0;
        }
        
        connection workloadFlow connect scheduler.workloadIn to engine.workloadExec;
        connection resultFlow connect engine.resultOut to aggregator.resultsIn;
        connection resourceControl connect scheduler.resourceMgmt to monitor.resourceStatus;
        connection statusMonitoring connect engine.monitoring to monitor.metrics;
    }
    
    requirement <'REQ-SANDBOX-001'> primaryFunction {
        doc /* The Mikegiller Sandbox System shall provide an isolated, 
             * scalable execution environment for processing user-submitted 
             * workloads with automated resource management, scheduling, 
             * monitoring, and result aggregation capabilities.
             */
        subject system :> sandboxSystem;
        
        require workloadProcessing;
        require resourceManagement;
        require systemMonitoring;
        require resultHandling;
    }
    
    requirement <'REQ-SANDBOX-002'> workloadProcessing {
        doc /* The system shall validate, schedule, and execute workloads 
             * based on priority and resource availability, supporting up to 
             * 50 concurrent jobs.
             */
        subject engine :> sandboxSystem.engine;
        
        assert constraint {
            engine.maxConcurrentJobs >= 50 and
            engine.activeJobs <= engine.maxConcurrentJobs
        }
    }
    
    requirement <'REQ-SANDBOX-003'> resourceManagement {
        doc /* The system shall dynamically allocate and release compute and 
             * memory resources to workloads, maintaining total utilization 
             * below capacity limits.
             */
        subject scheduler :> sandboxSystem.scheduler;
        
        assert constraint {
            sandboxSystem.overallUtilization <= 1.0
        }
    }
    
    requirement <'REQ-SANDBOX-004'> systemMonitoring {
        doc /* The system shall continuously monitor resource utilization and 
             * execution status at regular intervals.
             */
        subject monitor :> sandboxSystem.monitor;
    }
    
    requirement <'REQ-SANDBOX-005'> resultHandling {
        doc /* The system shall aggregate all workload results and maintain 
             * success rate metrics for performance analysis.
             */
        subject aggregator :> sandboxSystem.aggregator;
    }
    
    requirement <'REQ-SANDBOX-006'> throughputCapacity {
        doc /* The system shall support a maximum throughput of at least 
             * 1000 workloads per time unit under normal operating conditions.
             */
        subject system :> sandboxSystem;
        
        assert constraint {
            sandboxSystem.maxThroughput >= 1000.0
        }
    }
    
    satisfy primaryFunction by sandboxSystem;
}
