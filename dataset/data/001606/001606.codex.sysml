package ThreadBasedExecutionModel {

  import ScalarValues::*;
  import SI::*;

  attribute def TimeMs :> Real {
    doc /* elapsed time measured in milliseconds */
  }

  attribute def FrequencyHz :> Real {
    doc /* scheduling frequency measured in hertz */
  }

  attribute def Percent :> Real {
    doc /* utilization percentage from 0 to 100 */
  }

  attribute def ByteCount :> Integer {
    doc /* memory size measured in bytes */
  }

  attribute def PriorityLevel :> Integer {
    doc /* scheduler priority where larger values indicate higher priority */
  }

  enum def ThreadStateKind {
    enum idle;
    enum ready;
    enum running;
    enum blocked;
    enum suspended;
    enum terminated;
    enum faulted;
  }

  enum def WorkResultKind {
    enum accepted;
    enum completed;
    enum rejected;
    enum timedOut;
    enum failed;
  }

  item def WorkItem {
    attribute id : String;
    attribute payloadBytes : ByteCount;
    attribute requestedDeadline : TimeMs;
    attribute requiredPriority : PriorityLevel;
  }

  item def WorkResult {
    attribute workId : String;
    attribute result : WorkResultKind;
    attribute executionTime : TimeMs;
    attribute outputBytes : ByteCount;
  }

  item def ThreadControl {
    attribute startRequested : Boolean;
    attribute suspendRequested : Boolean;
    attribute resumeRequested : Boolean;
    attribute stopRequested : Boolean;
  }

  item def ThreadStatus {
    attribute state : ThreadStateKind;
    attribute currentPriority : PriorityLevel;
    attribute cpuUtilization : Percent;
    attribute stackUsed : ByteCount;
    attribute lastError : String;
  }

  port def WorkInputPort {
    in item work : WorkItem;
  }

  port def ResultOutputPort {
    out item result : WorkResult;
  }

  port def ControlPort {
    in item command : ThreadControl;
  }

  port def StatusPort {
    out item status : ThreadStatus;
  }

  port def SchedulerRequestPort {
    out item status : ThreadStatus;
    in item command : ThreadControl;
  }

  port def MemoryAccessPort {
    out item allocationRequest : ByteCount;
    in item allocationGranted : ByteCount;
  }

  port def ClockPort {
    in attribute tickPeriod : TimeMs;
  }

  action def AcceptWork {
    in item work : WorkItem;
    out item acceptedWork : WorkItem;
  }

  action def AllocateStackFrame {
    in item work : WorkItem;
    in attribute availableStack : ByteCount;
    out attribute grantedStack : ByteCount;
  }

  action def ExecuteWork {
    in item work : WorkItem;
    in attribute timeSlice : TimeMs;
    out item result : WorkResult;
  }

  action def PublishStatus {
    in attribute state : ThreadStateKind;
    in attribute priority : PriorityLevel;
    in attribute stackUsed : ByteCount;
    out item status : ThreadStatus;
  }

  action def HandleFault {
    in item failedWork : WorkItem;
    in attribute reason : String;
    out item result : WorkResult;
  }

  state def ThreadLifecycle {
    attribute currentState : ThreadStateKind;

    entry action PublishStatus;

    state idle;
    state ready;
    state running;
    state blocked;
    state suspended;
    state terminated;
    state faulted;

    transition initial then idle;

    transition idle_to_ready
      first idle
      accept WorkItem
      then ready;

    transition ready_to_running
      first ready
      accept ThreadControl
      if command.startRequested
      then running;

    transition running_to_blocked
      first running
      if currentState == ThreadStateKind::blocked
      then blocked;

    transition blocked_to_ready
      first blocked
      if currentState == ThreadStateKind::ready
      then ready;

    transition running_to_suspended
      first running
      accept ThreadControl
      if command.suspendRequested
      then suspended;

    transition suspended_to_ready
      first suspended
      accept ThreadControl
      if command.resumeRequested
      then ready;

    transition running_to_terminated
      first running
      accept ThreadControl
      if command.stopRequested
      then terminated;

    transition any_to_faulted
      first idle
      then faulted;

    transition faulted_to_terminated
      first faulted
      then terminated;
  }

  part def Scheduler {
    attribute schedulingRate : FrequencyHz;
    attribute defaultTimeSlice : TimeMs;
    attribute maxPriority : PriorityLevel;

    port threadControl : ControlPort;
    port threadStatus : StatusPort;
  }

  part def StackMemory {
    attribute totalCapacity : ByteCount;
    attribute reservedCapacity : ByteCount;
    attribute usedCapacity : ByteCount;

    port access : MemoryAccessPort;
  }

  part def SystemClock {
    attribute tickPeriod : TimeMs;
    attribute monotonicTime : TimeMs;

    port clockOut : ClockPort;
  }

  part def Thread {
    attribute threadId : String;
    attribute priority : PriorityLevel;
    attribute state : ThreadStateKind;
    attribute stackLimit : ByteCount;
    attribute stackUsed : ByteCount;
    attribute timeSlice : TimeMs;
    attribute cpuUtilization : Percent;

    port workIn : WorkInputPort;
    port resultOut : ResultOutputPort;
    port controlIn : ControlPort;
    port statusOut : StatusPort;
    port schedulerLink : SchedulerRequestPort;
    port memoryLink : MemoryAccessPort;
    port clockIn : ClockPort;

    perform action acceptWork : AcceptWork;
    perform action allocateStackFrame : AllocateStackFrame;
    perform action executeWork : ExecuteWork;
    perform action publishStatus : PublishStatus;
    perform action handleFault : HandleFault;

    exhibit state lifecycle : ThreadLifecycle;
  }

  part def ThreadBasedSystem {
    doc /* Primary function: execute one independent logical flow of work concurrently with the rest of the system while reporting status, honoring scheduling control, and isolating stack memory usage. */

    attribute systemName : String = "Thread Based Work Execution System";
    attribute maximumAcceptedWorkBytes : ByteCount = 1048576;
    attribute nominalThreadPeriod : TimeMs = 10.0;
    attribute requiredAvailability : Percent = 99.9;

    part workerThread : Thread {
      attribute threadId = "worker-thread-01";
      attribute priority = 5;
      attribute state = ThreadStateKind::idle;
      attribute stackLimit = 262144;
      attribute stackUsed = 0;
      attribute timeSlice = 10.0;
      attribute cpuUtilization = 0.0;
    }

    part scheduler : Scheduler {
      attribute schedulingRate = 100.0;
      attribute defaultTimeSlice = 10.0;
      attribute maxPriority = 10;
    }

    part stackMemory : StackMemory {
      attribute totalCapacity = 524288;
      attribute reservedCapacity = 262144;
      attribute usedCapacity = 0;
    }

    part clock : SystemClock {
      attribute tickPeriod = 1.0;
      attribute monotonicTime = 0.0;
    }

    port externalWork : WorkInputPort;
    port externalResult : ResultOutputPort;
    port externalControl : ControlPort;
    port externalStatus : StatusPort;

    connect externalWork to workerThread.workIn;
    connect workerThread.resultOut to externalResult;
    connect externalControl to workerThread.controlIn;
    connect workerThread.statusOut to externalStatus;

    connect scheduler.threadControl to workerThread.controlIn;
    connect workerThread.statusOut to scheduler.threadStatus;
    connect workerThread.memoryLink to stackMemory.access;
    connect clock.clockOut to workerThread.clockIn;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : ThreadBasedSystem;

    doc /* The system shall provide a thread-based execution capability that accepts work items, executes them within an independently scheduled thread context, and returns completion results with status visibility. */

    require constraint {
      system.maximumAcceptedWorkBytes <= 1048576
    }
  }

  requirement def SchedulingRequirement {
    subject system : ThreadBasedSystem;

    doc /* The worker thread shall receive scheduler control at a nominal period of 10 milliseconds or less. */

    require constraint {
      system.nominalThreadPeriod <= 10.0
    }
  }

  requirement def StackIsolationRequirement {
    subject system : ThreadBasedSystem;

    doc /* The worker thread shall execute using reserved stack memory and shall not exceed its configured stack limit. */

    require constraint {
      system.workerThread.stackUsed <= system.workerThread.stackLimit
    }
  }

  requirement def StatusReportingRequirement {
    subject system : ThreadBasedSystem;

    doc /* The system shall report thread state, priority, CPU utilization, stack usage, and last error information through its external status port. */
  }

  requirement def ControlledShutdownRequirement {
    subject system : ThreadBasedSystem;

    doc /* When a stop command is received, the worker thread shall transition to terminated after completing or rejecting the current work item. */
  }

  requirement def FaultContainmentRequirement {
    subject system : ThreadBasedSystem;

    doc /* If work execution fails, the worker thread shall publish a failed result and enter the faulted state without corrupting scheduler, clock, or stack memory parts. */
  }

  satisfy PrimaryFunctionRequirement by ThreadBasedSystem;
  satisfy SchedulingRequirement by ThreadBasedSystem::scheduler;
  satisfy StackIsolationRequirement by ThreadBasedSystem::stackMemory;
  satisfy StatusReportingRequirement by ThreadBasedSystem::workerThread;
  satisfy ControlledShutdownRequirement by ThreadBasedSystem::workerThread;
  satisfy FaultContainmentRequirement by ThreadBasedSystem::workerThread;
}