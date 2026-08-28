package 'HPC Sandbox Environment' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;

	item def JobRequest {
		attribute id : String;
		attribute computeRequirement : Real;
		attribute memoryRequirement : Real;
		attribute priority : Integer;
	}

	item def JobResult {
		attribute jobId : String;
		attribute success : Boolean;
		attribute duration : DurationValue;
		attribute computeUsed : Real;
		attribute memoryUsed : Real;
	}

	item def ResourceStatus {
		attribute computeUtilization : Real;
		attribute memoryUtilization : Real;
		attribute availableSlots : Integer;
	}

	item def PerformanceMetrics {
		attribute successRate : Real;
		attribute avgDuration : DurationValue;
		attribute totalJobs : Integer;
		attribute successfulJobs : Integer;
	}

	attribute def JobSubmitted;
	attribute def JobComplete;

	port def JobRequestPort {
		in jobRequest : JobRequest;
	}

	port def JobDispatchPort {
		in dispatchJob : JobRequest;
	}

	port def JobResultPort {
		in jobResult : JobResult;
	}

	port def ResourceStatusPort {
		in status : ResourceStatus;
	}

	port def MetricsPort {
		in metrics : PerformanceMetrics;
	}

	action def ValidateJob {
		in req : JobRequest;
		out isValid : Boolean;
	}

	action def ScheduleJob {
		in req : JobRequest;
		in status : ResourceStatus;
		out shouldDispatch : Boolean;
	}

	action def ExecuteJob {
		in job : JobRequest;
		out result : JobResult;
	}

	action def MonitorResources {
		out status : ResourceStatus;
	}

	action def AggregateResult {
		in res : JobResult;
		out metrics : PerformanceMetrics;
	}

	action def ThrottleTasks;

	part def WorkloadScheduler {
		attribute schedulingPolicy : String = "PriorityBased";
		attribute jobQueue : JobRequest[0..*] ordered;
		port jobRequestPort : JobRequestPort;
		port dispatchPort : ~JobDispatchPort;
		port resourceStatusPort : ResourceStatusPort;
		port resultPort : JobResultPort;
	}

	part def ExecutionEngine {
		attribute maxConcurrentJobs : Integer = 50;
		attribute activeJobs : Integer = 0;
		port dispatchPort : JobDispatchPort;
		port resultPort : ~JobResultPort;
	}

	part def ResourceMonitor {
		port statusPort : ~ResourceStatusPort;
	}

	part def ResultAggregator {
		attribute totalJobs : Integer = 0;
		attribute successfulJobs : Integer = 0;
		attribute successRate : Real;
		port resultPort : JobResultPort;
		port metricsPort : ~MetricsPort;
	}

	state schedulerStates {
		in scheduler : WorkloadScheduler;
		entry; then idle;
		state idle;
		accept JobSubmitted then validating;
		state validating;
		accept JobComplete then checkingResources;
		state checkingResources;
		accept JobSubmitted then dispatching;
		state dispatching;
		accept JobComplete then dequeueNext;
		state dequeueNext;
		accept JobSubmitted then idle;
	}

	state engineStates {
		in engine : ExecutionEngine;
		entry; then idle;
		state idle;
		accept JobSubmitted
			if engine.maxConcurrentJobs > engine.activeJobs
			do assign engine.activeJobs := engine.activeJobs + 1
			then active;
		accept JobSubmitted
			if engine.maxConcurrentJobs <= engine.activeJobs
			then overloaded;
		state active;
		accept JobComplete
			if engine.activeJobs > 1
			do assign engine.activeJobs := engine.activeJobs - 1
			then active;
		accept JobComplete
			if engine.activeJobs <= 1
			do assign engine.activeJobs := engine.activeJobs - 1
			then idle;
		accept JobSubmitted
			if engine.maxConcurrentJobs > engine.activeJobs
			do assign engine.activeJobs := engine.activeJobs + 1
			then active;
		state overloaded;
		accept JobComplete
			if engine.activeJobs > 1
			do assign engine.activeJobs := engine.activeJobs - 1
			then active;
		accept JobComplete
			if engine.activeJobs <= 1
			do assign engine.activeJobs := engine.activeJobs - 1
			then idle;
	}

	state monitorStates {
		in monitor : ResourceMonitor;
		entry; then monitoring;
		state monitoring;
		accept after 1 [s] then monitoring;
	}

	state aggregatorStates {
		in aggregator : ResultAggregator;
		entry; then collecting;
		state collecting;
		accept JobComplete then processing;
		state processing;
		accept JobComplete then collecting;
	}

	part def HPCSystem {
		part scheduler : WorkloadScheduler;
		part engine : ExecutionEngine;
		part monitor : ResourceMonitor;
		part aggregator : ResultAggregator;
		port externalJobIn : ~JobRequestPort;
		port externalMetricsOut : MetricsPort;
		connect externalJobIn to scheduler.jobRequestPort;
		connect scheduler.dispatchPort to engine.dispatchPort;
		connect engine.resultPort to aggregator.resultPort;
		connect engine.resultPort to scheduler.resultPort;
		connect monitor.statusPort to scheduler.resourceStatusPort;
		connect aggregator.metricsPort to externalMetricsOut;
		constraint { scheduler.schedulingPolicy == "PriorityBased" }
		constraint { engine.maxConcurrentJobs == 50 }
	}

	requirement def HPCRequirements {
		text "The system shall safely and efficiently execute user-submitted computational tasks in an isolated environment.";
	}

	requirement MaxConcurrency {
		subject engine : ExecutionEngine;
		text "The Execution Engine shall be capable of running up to 50 concurrent jobs.";
		assert constraint { engine.maxConcurrentJobs == 50 }
	}

	requirement PriorityScheduling {
		subject scheduler : WorkloadScheduler;
		text "The Workload Scheduler shall use a PriorityBased scheduling policy.";
		assert constraint { scheduler.schedulingPolicy == "PriorityBased" }
	}

	requirement ResourceMonitoringReq {
		subject monitor : ResourceMonitor;
		text "The Resource Monitor shall continuously track compute and memory utilization.";
	}

	requirement ResultAggregationReq {
		subject aggregator : ResultAggregator;
		text "The Result Aggregator shall log job outcomes and compute overall success rate.";
	}

	requirement OverloadProtection {
		subject engine : ExecutionEngine;
		text "The Execution Engine shall throttle new tasks when resource demand exceeds capacity.";
	}
}
