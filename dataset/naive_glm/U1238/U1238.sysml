package ThreadManagementSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Enumerations =====
    enum def ThreadState {
        created;
        ready;
        running;
        blocked;
        terminated;
    }

    enum def PriorityLevel {
        low;
        medium;
        high;
    }

    enum def PreemptReason {
        quantumExpired;
        resourceWait;
        higherPriorityArrival;
        voluntaryYield;
    }

    // ===== Value Types =====
    value type ThreadId :> Integer;
    value type StackSize :> Integer;
    value type RegisterValue :> Integer;
    value type MemoryAddress :> Integer;
    value type TimeQuantum :> Duration;

    // ===== Item Definitions =====
    item def Instruction {
        attribute address : MemoryAddress;
        attribute opcode : String;
        attribute operand : String;
    }

    item def RegisterSet {
        attribute generalRegisters : RegisterValue[16];
        attribute programCounter : MemoryAddress;
        attribute stackPointer : MemoryAddress;
        attribute statusRegister : RegisterValue;
    }

    item def ExecutionContext {
        attribute currentInstruction : Instruction;
        attribute registers : RegisterSet;
        attribute memoryBasePointer : MemoryAddress;
    }

    item def Stack {
        attribute baseAddress : MemoryAddress;
        attribute size : StackSize;
        attribute threadId : ThreadId;
        attribute inUse : Boolean = false;
    }

    item def DispatchSignal {
        attribute threadId : ThreadId;
        attribute quantum : TimeQuantum;
    }

    item def PreemptSignal {
        attribute threadId : ThreadId;
        attribute reason : PreemptReason;
        attribute savedContext : ExecutionContext;
    }

    item def AllocationRequest {
        attribute threadId : ThreadId;
        attribute requestedSize : StackSize;
    }

    item def DeallocationRequest {
        attribute threadId : ThreadId;
        attribute stack : Stack;
    }

    // ===== Port Definitions =====
    port def DispatchPort {
        out item dispatchSignal : DispatchSignal;
        in item savedContext : ExecutionContext;
    }

    port def PreemptPort {
        out item preemptSignal : PreemptSignal;
        in item restoredContext : ExecutionContext;
    }

    port def MemoryAccessPort {
        in item allocationRequest : AllocationRequest;
        out item allocatedStack : Stack;
        in item deallocationRequest : DeallocationRequest;
        out item deallocationConfirmed : Boolean;
    }

    // ===== Thread Control Block =====
    part def ThreadControlBlock {
        attribute threadId : ThreadId;
        attribute priority : PriorityLevel = PriorityLevel::medium;
        attribute state : ThreadState = ThreadState::created;
        attribute context : ExecutionContext;
        attribute stack : Stack;
        attribute quantumRemaining : TimeQuantum;
        attribute totalExecutionTime : TimeQuantum;

        port dispatchPort : DispatchPort;
        port preemptPort : PreemptPort;
        port memoryPort : MemoryAccessPort;

        action def initialize {
            in id : ThreadId;
            in prio : PriorityLevel;
            in stackSize : StackSize;
        }

        action def updateContext {
            in newContext : ExecutionContext;
        }

        action def changeState {
            in newState : ThreadState;
        }

        state machine threadLifecycle {
            initial start;

            state Created {
                entry action allocateResources;
                exit action markReady;
            }

            state Ready {
                entry action enqueue;
                do action waitforDispatch;
            }

            state Running {
                entry action restoreContext;
                do action executeInstructions;
                exit action saveContext;
            }

            state Blocked {
                entry action suspendExecution;
                do action waitForResource;
            }

            state Terminated {
                entry action releaseResources;
            }

            transition created_to_ready
                first Created
                accept AllocationComplete
                then Ready;

            transition ready_to_running
                first Ready
                accept Dispatch
                then Running;

            transition running_to_ready
                first Running
                accept QuantumExpired
                then Ready;

            transition running_to_ready_yield
                first Running
                accept Yield
                then Ready;

            transition running_to_blocked
                first Running
                accept WaitForResource
                then Blocked;

            transition blocked_to_ready
                first Blocked
                accept ResourceAvailable
                then Ready;

            transition running_to_terminated
                first Running
                accept Terminate
                then Terminated;

            transition ready_to_terminated
                first Ready
                accept Terminate
                then Terminated;

            transition blocked_to_terminated
                first Blocked
                accept Terminate
                then Terminated;
        }
    }

    // ===== Memory Manager =====
    part def MemoryManager {
        port memoryAccessPort : MemoryAccessPort;

        attribute allocatedStacks : Stack[0..*];
        attribute totalMemory : StackSize = 1048576;
        attribute availableMemory : StackSize = 1048576;
        attribute defaultStackSize : StackSize = 8192;

        action def allocateStack {
            in request : AllocationRequest;
            out stack : Stack;
        }

        action def deallocateStack {
            in request : DeallocationRequest;
            out confirmed : Boolean;
        }

        action def compactMemory {
            // Defragment available memory
        }

        action allocateAction : allocateStack {
            // Check available memory, create Stack, update availableMemory
        }

        action deallocateAction : deallocateStack {
            // Mark stack as not in use, return memory to pool
        }

        state machine memoryManagerState {
            initial start;
            state Idle;
            state Allocating;
            state Deallocating;

            transition idle_to_allocating
                first Idle
                accept AllocationRequest
                then Allocating;

            transition allocating_to_idle
                first Allocating
                accept Stack
                then Idle;

            transition idle_to_deallocating
                first Idle
                accept DeallocationRequest
                then Deallocating;

            transition deallocating_to_idle
                first Deallocating
                accept Boolean
                then Idle;
        }
    }

    // ===== Execution Unit =====
    part def ExecutionUnit {
        port contextInPort : DispatchPort;
        port contextOutPort : PreemptPort;
        port memoryAccessPort : MemoryAccessPort;

        attribute activeContext : ExecutionContext;
        attribute quantumDuration : TimeQuantum;
        attribute quantumRemaining : TimeQuantum;
        attribute instructionCount : Integer = 0;

        action def execute {
            in context : ExecutionContext;
            out updatedContext : ExecutionContext;
        }

        action def restoreContext {
            in context : ExecutionContext;
        }

        action def saveContext {
            out context : ExecutionContext;
        }

        action def tick {
            // Execute one instruction, decrement quantum
        }

        action def checkQuantum {
            // Check if quantum has expired
        }

        state machine executionCycle {
            initial start;
            state Idle;
            state Restoring;
            state Executing;
            state Saving;

            transition idle_to_restoring
                first Idle
                accept DispatchSignal
                then Restoring;

            transition restoring_to_executing
                first Restoring
                accept ContextRestored
                then Executing;

            transition executing_to_saving
                first Executing
                accept QuantumExpired
                then Saving;

            transition saving_to_idle
                first Saving
                accept ContextSaved
                then Idle;
        }
    }

    // ===== Thread Scheduler =====
    part def ThreadScheduler {
        port dispatchPort : DispatchPort;
        port preemptPort : PreemptPort;

        attribute readyQueue : ThreadControlBlock[0..*] ordered;
        attribute currentThread : ThreadControlBlock;
        attribute defaultQuantum : TimeQuantum;
        attribute schedulingPolicy : String = "priority-based round-robin";
        attribute threadCount : Integer = 0;
        attribute contextSwitchCount : Integer = 0;

        action def selectNextThread {
            out selectedThread : ThreadControlBlock;
        }

        action def preemptCurrentThread {
            in thread : ThreadControlBlock;
            in reason : PreemptReason;
        }

        action def contextSwitch {
            in oldThread : ThreadControlBlock;
            in newThread : ThreadControlBlock;
        }

        action def enqueueThread {
            in thread : ThreadControlBlock;
        }

        action def dequeueThread {
            out thread : ThreadControlBlock;
        }

        action def sortByPriority {
            // Reorder ready queue by priority, maintaining round-robin within same priority
        }

        action def checkStarvation {
            // Ensure low-priority threads get execution time
        }

        state machine schedulingCycle {
            initial start;
            state Idle;
            state Selecting;
            state Dispatching;
            state Monitoring;
            state Preempting;
            state Switching;

            transition idle_to_selecting
                first Idle
                accept ScheduleRequest
                then Selecting;

            transition selecting_to_dispatching
                first Selecting
                accept ThreadSelected
                then Dispatching;

            transition dispatching_to_monitoring
                first Dispatching
                accept DispatchComplete
                then Monitoring;

            transition monitoring_to_preempting
                first Monitoring
                accept QuantumExpired
                then Preempting;

            transition monitoring_to_preempting_wait
                first Monitoring
                accept ResourceWait
                then Preempting;

            transition preempting_to_switching
                first Preempting
                accept PreemptComplete
                then Switching;

            transition switching_to_idle
                first Switching
                accept SwitchComplete
                then Idle;
        }
    }

    // ===== Thread Management System =====
    part def ThreadManagementSystem {
        part scheduler : ThreadScheduler;
        part executionUnit : ExecutionUnit;
        part memoryManager : MemoryManager;
        part threadPool : ThreadControlBlock[0..*];

        attribute maxThreads : Integer = 256;
        attribute activeThreads : Integer = 0;

        connection dispatchToExecution
            connect scheduler.dispatchPort to executionUnit.contextInPort;

        connection preemptFromExecution
            connect executionUnit.contextOutPort to scheduler.preemptPort;

        connection executionToMemory
            connect executionUnit.memoryAccessPort to memoryManager.memoryAccessPort;

        connection schedulerToThreadPool
            connect scheduler.dispatchPort to threadPool.dispatchPort;

        connection schedulerPreemptToThreadPool
            connect scheduler.preemptPort to threadPool.preemptPort;

        connection threadPoolToMemory
            connect threadPool.memoryPort to memoryManager.memoryAccessPort;

        action def createThread {
            in id : ThreadId;
            in priority : PriorityLevel;
            in stackSize : StackSize;
            out thread : ThreadControlBlock;
        }

        action def destroyThread {
            in thread : ThreadControlBlock;
        }

        action def systemTick {
            // System-wide clock tick to drive scheduling
        }
    }

    // ===== Requirements =====
    requirement def ConcurrentExecutionRequirement {
        doc "The system shall enable multiple threads to execute concurrently on a single processor, providing the illusion of simultaneous execution through rapid context switching.";
        attribute maxConcurrentThreads : Integer;
        attribute minContextSwitchRate : Integer;
    }

    requirement def ContextSwitchingRequirement {
        doc "The system shall save and restore thread execution contexts during context switching to enable seamless thread pausing and resumption without data loss.";
        attribute maxSwitchTime : TimeQuantum;
        attribute contextIntegrity : Boolean;
    }

    requirement def PrioritySchedulingRequirement {
        doc "The scheduler shall use a priority-based round-robin policy that gives higher-priority threads preference while ensuring lower-priority threads eventually execute, preventing starvation.";
        attribute schedulingAlgorithm : String;
        attribute starvationPrevention : Boolean;
        attribute fairnessGuarantee : Boolean;
    }

    requirement def MemoryIsolationRequirement {
        doc "The memory manager shall allocate and deallocate private stacks for each thread to prevent data interference between threads and ensure thread-safe memory access.";
        attribute stackIsolation : Boolean;
        attribute minStackSize : StackSize;
    }

    requirement def ThreadLifecycleRequirement {
        doc "Each thread shall transition through a well-defined lifecycle: created, ready, running, blocked, and terminated, with appropriate resource allocation at creation and resource deallocation at termination.";
        attribute validStates : ThreadState[5];
    }

    requirement def TimeQuantumRequirement {
        doc "The scheduler shall allocate a specific time quantum to each running thread and preempt it when the quantum expires or when a higher-priority thread becomes ready.";
        attribute quantumDuration : TimeQuantum;
        attribute preemptOnHigherPriority : Boolean;
    }

    requirement def ExecutionContextRequirement {
        doc "Each Thread Control Block shall store a complete execution context including current instruction, register values, and memory pointers to support context switching.";
        attribute contextFields : String[3];
    }

    // ===== Requirement Satisfaction =====
    part threadManagementSystemInstance : ThreadManagementSystem {
        attribute maxThreads = 256;

        satisfy concurrentReq : ConcurrentExecutionRequirement {
            maxConcurrentThreads = 256;
            minContextSwitchRate = 100;
        }

        satisfy contextSwitchReq : ContextSwitchingRequirement {
            maxSwitchTime = 0.001;
            contextIntegrity = true;
        }

        satisfy prioritySchedReq : PrioritySchedulingRequirement {
            schedulingAlgorithm = "priority-based round-robin";
            starvationPrevention = true;
            fairnessGuarantee = true;
        }

        satisfy memoryIsoReq : MemoryIsolationRequirement {
            stackIsolation = true;
            minStackSize = 8192;
        }

        satisfy lifecycleReq : ThreadLifecycleRequirement {
            validStates = (ThreadState::created, ThreadState::ready, ThreadState::running, ThreadState::blocked, ThreadState::terminated);
        }

        satisfy quantumReq : TimeQuantumRequirement {
            quantumDuration = 0.01;
            preemptOnHigherPriority = true;
        }

        satisfy execContextReq : ExecutionContextRequirement {
            contextFields = ("currentInstruction", "registers", "memoryBasePointer");
        }
    }
}
