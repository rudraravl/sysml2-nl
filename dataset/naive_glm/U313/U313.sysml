package HpcSandboxModel {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type CoreCount :> Real {
        doc "Number of compute cores available, requested, or consumed.";
    }

    value type GigaByte :> Real {
        doc "Memory capacity expressed in gigabytes.";
    }

    value type GigaFLOPS :> Real {
        doc "Compute throughput expressed in giga-FLOPS.";
    }

    value type Second :> Real {
        doc "Elapsed wall-clock time in seconds.";
    }

    value type Percent :> Real {
        doc "Utilization ratio expressed as a percentage in the range 0..100.";
    }

    value type PriorityLevel :> Integer {
        doc "User-defined job priority; 1 is lowest, 100 is highest.";
    }

    value type JobId :> String {
        doc "Globally unique job identifier.";
    }

    value type UserId :> String {
        doc "Submitting user identifier.";
    }

    // ===== Enumerations =====
    enum def JobStatus {
        value PENDING;
        value RUNNING;
        value COMPLETED;
        value FAILED;
        value CANCELLED;
        value TIMEOUT;
    }

    enum def SchedulingPolicy {
        value PRIORITY_BASED;
        value FIFO;
        value FAIR_SHARE;
        value BACKFILL;
    }

    enum def EngineStateKind {
        value IDLE;
        value ACTIVE;
        value OVERLOADED;
    }

    // ===== Item Definitions =====
    item def JobRequest {
        doc "Specification of a user-submitted computational workload.";
        attribute id : JobId;
        attribute userId : UserId;
        attribute requiredCores : CoreCount;
        attribute requiredMemory : GigaByte;
        attribute priority : PriorityLevel;
        attribute estimatedRuntime : Second;
        attribute submissionTime : Second;
    }

    item def JobResult {
        doc "Outcome descriptor for a completed or failed job.";
        attribute id : JobId;
        attribute status : JobStatus;
        attribute executionTime : Second;
        attribute coresUsed : CoreCount;
        attribute memoryUsed : GigaByte;
        attribute errorMessage : String;
    }

    item def ResourceStatus {
        doc "Snapshot of resource availability and utilization at a given time.";
        attribute coresAvailable : CoreCount;
        attribute memoryAvailable : GigaByte;
        attribute computeUtilization : Percent;
        attribute memoryUtilization : Percent;
        attribute jobsRunning : Integer;
        attribute timestamp : Second;
    }

    item def PerformanceMetrics {
        doc "System-wide performance summary produced by the aggregator.";
        attribute totalJobs : Integer;
        attribute successfulJobs : Integer;
        attribute failedJobs : Integer;
        attribute averageExecutionTime : Second;
        attribute successRate : Percent;
        attribute totalCpuTime : Second;
        attribute peakUtilization : Percent;
    }

    // ===== Requirements =====
    requirement def AutomatedLifecycleRequirement {
        doc "The HPC sandbox shall manage the entire lifecycle of a job automatically, from submission to result aggregation.";
    }

    requirement def SchedulerRequirement {
        doc "The Workload Scheduler shall validate incoming job requests and dispatch them per the configured priority-based policy.";
        attribute maxQueueSize : Integer = 1000;
        attribute defaultPolicy : SchedulingPolicy = SchedulingPolicy::PRIORITY_BASED;
        subject scheduler : WorkloadScheduler;
        requirement {
            doc "Queue depth shall not exceed maxQueueSize.";
            predicate { scheduler.currentQueueSize <= scheduler.maxQueueSize; }
        }
        requirement {
            doc "All incoming jobs shall be validated before being queued or dispatched.";
            predicate { scheduler.validationEnabled == true; }
        }
    }

    requirement def ExecutionEngineRequirement {
        doc "The Execution Engine shall run up to 50 jobs concurrently and throttle new tasks when overloaded.";
        attribute maxConcurrentJobs : Integer = 50;
        subject engine : ExecutionEngine;
        requirement {
            predicate { engine.maxConcurrentJobs == 50; }
        }
        requirement {
            doc "The engine shall enter the OVERLOADED state when compute utilization exceeds 90 percent.";
            predicate { engine.throttleThreshold == 90; }
        }
    }

    requirement def MonitoringRequirement {
        doc "The Resource Monitor shall provide current compute and memory utilization to the scheduler.";
        subject monitor : ResourceMonitor;
        requirement {
            predicate { monitor.samplingPeriod > 0; }
        }
    }

    requirement def AggregationRequirement {
        doc "The Result Aggregator shall log every job outcome and compute the system success rate.";
        subject aggregator : ResultAggregator;
        requirement {
            predicate { aggregator.successRate >= 0 and aggregator.successRate <= 100; }
        }
    }

    requirement def IsolationRequirement {
        doc "Jobs shall execute within an isolated sandbox environment to prevent cross-contamination.";
    }

    // ===== Port Definitions =====
    port def JobSubmissionPort {
        doc "Inbound port receiving user job submissions.";
        attribute job : JobRequest;
    }

    port def JobDispatchPort {
        doc "Port carrying validated jobs from the scheduler to the execution engine.";
        attribute job : JobRequest;
    }

    port def ResourceStatusPort {
        doc "Port conveying current resource status between monitor and scheduler.";
        attribute status : ResourceStatus;
    }

    port def JobResultPort {
        doc "Port carrying completed job results.";
        attribute result : JobResult;
    }

    port def MetricsPort {
        doc "Outbound port providing aggregated performance metrics.";
        attribute metrics : PerformanceMetrics;
    }

    // ===== Part Definitions =====

    part def WorkloadScheduler {
        doc "Central coordinator that validates, queues, and dispatches job requests according to a scheduling policy.";

        attribute policy : SchedulingPolicy = SchedulingPolicy::PRIORITY_BASED;
        attribute maxQueueSize : Integer = 1000;
        attribute currentQueueSize : Integer = 0;
        attribute activeJobCount : Integer = 0;
        attribute validationEnabled : Boolean = true;
        attribute validationFailures : Integer = 0;
        attribute lastError : String;
        attribute lastStatus : ResourceStatus;
        attribute capacityAvailable : Boolean = false;
        attribute pendingQueue : JobRequest[0..1000] ordered;
        attribute completedIds : JobId[0..*];

        port in submission : JobSubmissionPort;
        port out dispatch : JobDispatchPort;
        port in resourceStatus : ResourceStatusPort;
        port in jobResult : JobResultPort;

        action def validateRequest {
            in request : JobRequest;
            out isValid : Boolean;
        }

        action def enqueue {
            in request : JobRequest;
        }

        action def dispatchNext {
            in status : ResourceStatus;
        }

        action def handleResult {
            in result : JobResult;
        }

        state machine SchedulerBehavior {
            state awaitingSubmission;
            state validating {
                entry / validateRequest(submission.job);
            }
            state checkingCapacity;
            state dispatching {
                entry / dispatchNext(lastStatus);
            }
            state queuing {
                entry / enqueue(submission.job);
            }
            state idle;

            transition from awaitingSubmission to validating
                when submission.job != null;
            transition from validating to checkingCapacity;
            transition from validating to awaitingSubmission
                when validationEnabled == false;
            transition from checkingCapacity to dispatching
                when capacityAvailable == true;
            transition from checkingCapacity to queuing
                when capacityAvailable == false;
            transition from queuing to awaitingSubmission;
            transition from dispatching to awaitingSubmission;
            transition from idle to awaitingSubmission;
        }
    }

    part def ExecutionEngine {
        doc "Sandboxed execution unit running up to 50 concurrent jobs with overload throttling.";

        attribute maxConcurrentJobs : Integer = 50;
        attribute runningJobs : Integer = 0;
        attribute totalCores : CoreCount = 256;
        attribute totalMemory : GigaByte = 1024;
        attribute utilizedCores : CoreCount = 0;
        attribute utilizedMemory : GigaByte = 0;
        attribute throttleThreshold : Percent = 90;
        attribute recoveryThreshold : Percent = 80;
        attribute stateKind : EngineStateKind = EngineStateKind::IDLE;
        attribute runningJobSet : JobId[0..50];

        port in dispatch : JobDispatchPort;
        port out result : JobResultPort;
        port out utilization : ResourceStatusPort;
        port out engineResultToAggregator : JobResultPort;

        action def executeJob {
            in job : JobRequest;
            out result : JobResult;
        }

        action def throttle {
            in job : JobRequest;
        }

        action def releaseResources {
            in job : JobRequest;
        }

        action def reportUtilization {
            out status : ResourceStatus;
        }

        state machine EngineStateMachine {
            state idle {
                entry / { stateKind = EngineStateKind::IDLE; }
            }
            state active {
                entry / { stateKind = EngineStateKind::ACTIVE; }
                do / executeJob(dispatch.job);
            }
            state overloaded {
                entry / { stateKind = EngineStateKind::OVERLOADED; }
                do / throttle(dispatch.job);
            }

            transition from idle to active
                when runningJobs > 0;
            transition from active to overloaded
                when (utilizedCores / totalCores) * 100 > throttleThreshold;
            transition from active to idle
                when runningJobs == 0;
            transition from overloaded to active
                when (utilizedCores / totalCores) * 100 <= recoveryThreshold;
        }
    }

    part def ResourceMonitor {
        doc "Continuously tracks compute and memory utilization and publishes status to the scheduler.";

        attribute samplingPeriod : Second = 1;
        attribute coresTotal : CoreCount = 256;
        attribute memoryTotal : GigaByte = 1024;
        attribute currentStatus : ResourceStatus;

        port out statusOut : ResourceStatusPort;
        port in utilizationIn : ResourceStatusPort;

        action def sample {
            out status : ResourceStatus;
        }

        action def publishStatus {
            in status : ResourceStatus;
        }

        state machine MonitorBehavior {
            state monitoring {
                do / sample(currentStatus);
                entry / publishStatus(currentStatus);
            }
            state degraded;
            state offline;

            transition from monitoring to degraded
                when samplingPeriod > 5;
            transition from degraded to monitoring
                when samplingPeriod <= 1;
            transition from monitoring to offline
                when coresTotal <= 0;
            transition from offline to monitoring;
        }
    }

    part def ResultAggregator {
        doc "Collects completed job outcomes and computes system-wide performance metrics.";

        attribute totalJobs : Integer = 0;
        attribute successfulJobs : Integer = 0;
        attribute failedJobs : Integer = 0;
        attribute totalExecutionTime : Second = 0;
        attribute totalCpuTime : Second = 0;
        attribute successRate : Percent = 0;
        attribute peakUtilization : Percent = 0;
        attribute log : JobResult[0..*] ordered;

        port in resultIn : JobResultPort;
        port out metricsOut : MetricsPort;

        action def recordResult {
            in result : JobResult;
        }

        action def computeMetrics {
            out metrics : PerformanceMetrics;
        }

        action def reportMetrics {
            in metrics : PerformanceMetrics;
        }

        state machine AggregatorBehavior {
            state idle;
            state recording {
                entry / recordResult(resultIn.result);
            }
            state aggregating {
                entry / computeMetrics();
            }
            state reporting {
                entry / reportMetrics(metricsOut.metrics);
            }

            transition from idle to recording
                when resultIn.result != null;
            transition from recording to aggregating;
            transition from aggregating to reporting;
            transition from reporting to idle;
        }
    }

    // ===== Top-Level Sandbox =====
    part def HpcSandbox {
        doc "High-performance computing sandbox orchestrating the complete job lifecycle.";

        attribute name : String = "HPC-Sandbox";
        attribute policy : SchedulingPolicy = SchedulingPolicy::PRIORITY_BASED;
        attribute maxConcurrentJobs : Integer = 50;
        attribute maxQueueSize : Integer = 1000;
        attribute isolationEnabled : Boolean = true;

        part scheduler : WorkloadScheduler;
        part engine : ExecutionEngine;
        part monitor : ResourceMonitor;
        part aggregator : ResultAggregator;

        port in externalSubmission : JobSubmissionPort;
        port out externalMetrics : MetricsPort;

        connection extToScheduler connect externalSubmission to scheduler.submission;
        connection schedulerToEngine connect scheduler.dispatch to engine.dispatch;
        connection monitorToScheduler connect monitor.statusOut to scheduler.resourceStatus;
        connection engineToMonitor connect engine.utilization to monitor.utilizationIn;
        connection engineResultToScheduler connect engine.result to scheduler.jobResult;
        connection engineResultToAggregator connect engine.engineResultToAggregator to aggregator.resultIn;
        connection aggregatorMetricsOut connect aggregator.metricsOut to externalMetrics;

        satisfy AutomatedLifecycleRequirement by HpcSandbox;
        satisfy SchedulerRequirement by scheduler;
        satisfy ExecutionEngineRequirement by engine;
        satisfy MonitoringRequirement by monitor;
        satisfy AggregationRequirement by aggregator;
        satisfy IsolationRequirement by engine;
    }
}
