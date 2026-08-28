package ThreadManagementSystem {
	private import ScalarValues::*;

	enum def ThreadState {
		enum created;
		enum ready;
		enum running;
		enum blocked;
		enum terminated;
	}

	enum def PriorityLevel {
		enum low = 0;
		enum medium = 1;
		enum high = 2;
	}

	attribute def ThreadId :> ScalarValues::Integer;
	attribute def StackSize :> ScalarValues::Integer;
	attribute def Address :> ScalarValues::Integer;
	attribute def RegisterValue :> ScalarValues::Integer;

	attribute def ExecutionContext {
		attribute threadId : ThreadId;
		attribute programCounter : Address;
		attribute stackPointer : Address;
		attribute registers : RegisterValue[0..16];
		attribute flags : ScalarValues::Integer;
	}

	attribute def CreateThread {
		attribute threadId : ThreadId;
		attribute priority : PriorityLevel;
		attribute stackSize : StackSize;
	}

	attribute def DispatchSignal {
		attribute threadId : ThreadId;
		attribute context : ExecutionContext;
	}

	attribute def PreemptSignal {
		attribute threadId : ThreadId;
	}

	attribute def BlockSignal {
		attribute threadId : ThreadId;
	}

	attribute def UnblockSignal {
		attribute threadId : ThreadId;
	}

	attribute def TerminateSignal {
		attribute threadId : ThreadId;
	}

	attribute def ContextSaved {
		attribute threadId : ThreadId;
		attribute context : ExecutionContext;
	}

	attribute def AllocateRequest {
		attribute threadId : ThreadId;
		attribute size : StackSize;
	}

	attribute def DeallocateRequest {
		attribute threadId : ThreadId;
	}

	attribute def StackAllocated {
		attribute threadId : ThreadId;
		attribute baseAddress : Address;
		attribute size : StackSize;
	}

	attribute def StackDeallocated {
		attribute threadId : ThreadId;
	}

	port def ExecutionPort {
		in dispatch : DispatchSignal;
		in preempt : PreemptSignal;
		out contextSaved : ContextSaved;
	}

	port def MemoryPort {
		in alloc : AllocateRequest;
		in dealloc : DeallocateRequest;
		out allocated : StackAllocated;
		out deallocated : StackDeallocated;
	}

	port def ExternalPort {
		in create : CreateThread;
		in preempt : PreemptSignal;
		in block : BlockSignal;
		in unblock : UnblockSignal;
		in terminateReq : TerminateSignal;
		out dispatch : DispatchSignal;
		out contextSaved : ContextSaved;
	}

	part def ThreadControlBlock {
		attribute threadId : ThreadId;
		attribute priority : PriorityLevel := PriorityLevel::medium;
		attribute threadState : ThreadState := ThreadState::created;
		attribute context : ExecutionContext;
		attribute stackBase : Address := 0;
		attribute stackSize : StackSize := 0;
		attribute cpuTimeUsed : ScalarValues::Integer := 0;
		attribute waitTime : ScalarValues::Integer := 0;

		action markReady {
			assign threadState := ThreadState::ready;
		}
		action markRunning {
			assign threadState := ThreadState::running;
		}
		action markBlocked {
			assign threadState := ThreadState::blocked;
		}
		action markTerminated {
			assign threadState := ThreadState::terminated;
		}
	}

	state def ThreadLifecycle {
		entry; then state created;

		state created;
		accept a : StackAllocated
			then ready;

		state ready;
		accept d : DispatchSignal
			then running;

		state running;
		accept p : PreemptSignal
			then ready;
		accept b : BlockSignal
			then blocked;
		accept t : TerminateSignal
			then terminated;

		state blocked;
		accept u : UnblockSignal
			then ready;
		accept t2 : TerminateSignal
			then terminated;

		state terminated;
		then done;
	}

	part def ThreadScheduler {
		port executionPort : ~ExecutionPort;
		port memoryPort : ~MemoryPort;
		port externalPort : ExternalPort;

		ref readyQueue : ThreadControlBlock[0..*] := ();
		ref blockedQueue : ThreadControlBlock[0..*] := ();
		ref runningThread : ThreadControlBlock;
		attribute timeQuantum : Real := 0.01;
		attribute tickCount : ScalarValues::Integer := 0;

		action selectNextThread {
			assign runningThread := readyQueue[1];
		}

		state def Scheduling {
			entry; then state idle;

			state idle;
			accept c : CreateThread
				do send new AllocateRequest(c.threadId, c.stackSize) to memoryPort
				then creating;

			state creating;
			accept a : StackAllocated
				then ready;

			state ready;
			entry selectNextThread;
			then dispatching;

			state dispatching {
				entry assign runningThread.threadState := ThreadState::running;
				do send new DispatchSignal(runningThread.threadId, runningThread.context) to executionPort;
			}
			then running;

			state running;
			accept p : PreemptSignal
				then preempting;
			accept b : BlockSignal
				then blocking;
			accept t : TerminateSignal
				then terminating;

			state preempting {
				entry assign runningThread.threadState := ThreadState::ready;
			}
			then ready;

			state blocking {
				entry assign runningThread.threadState := ThreadState::blocked;
			}
			then ready;

			state terminating {
				entry assign runningThread.threadState := ThreadState::terminated;
				do send new DeallocateRequest(runningThread.threadId) to memoryPort;
			}
			then idle;
		}

		state scheduling : Scheduling;
	}

	part def ExecutionUnit {
		port executionPort : ExecutionPort;
		attribute currentContext : ExecutionContext;
		attribute cycleCount : ScalarValues::Integer := 0;

		action executeInstructions {
			assign cycleCount := cycleCount + 1;
		}

		state def Execution {
			entry; then state waiting;

			state waiting;
			accept d : DispatchSignal
				do assign currentContext := d.context
				then executing;

			state executing {
				do executeInstructions;
			}
			accept p : PreemptSignal
				do send new ContextSaved(currentContext.threadId, currentContext) to executionPort
				then waiting;
		}

		state execution : Execution;
	}

	part def MemoryManager {
		port memoryPort : MemoryPort;
		attribute heapBase : Address := 65536;
		attribute nextFree : Address := 65536;
		attribute allocatedCount : ScalarValues::Integer := 0;

		action allocateStack {
			assign nextFree := nextFree + 1024;
			assign allocatedCount := allocatedCount + 1;
		}

		action deallocateStack {
			assign allocatedCount := allocatedCount - 1;
		}

		state def MemoryManagement {
			entry; then state idle;

			state idle;
			accept a : AllocateRequest
				do send new StackAllocated(a.threadId, nextFree, a.size) to memoryPort
				then respondingAllocated;
			accept d : DeallocateRequest
				then respondingDeallocated;

			state respondingAllocated {
				entry allocateStack;
			}
			then idle;

			state respondingDeallocated {
				entry deallocateStack;
				do send new StackDeallocated(d.threadId) to memoryPort;
			}
			then idle;
		}

		state memoryMgmt : MemoryManagement;
	}

	part def ThreadManagementSystem {
		port externalPort : ExternalPort;

		part scheduler : ThreadScheduler;
		part executionUnit : ExecutionUnit;
		part memoryManager : MemoryManager;
		part threadPool : ThreadControlBlock[0..*];

		interface schedulerExecutionInterface
			connect scheduler.executionPort to executionUnit.executionPort {
			flow dispatchFlow of DispatchSignal
				from scheduler.executionPort.dispatch to executionUnit.executionPort.dispatch;
			flow preemptFlow of PreemptSignal
				from scheduler.executionPort.preempt to executionUnit.executionPort.preempt;
			flow contextSavedFlow of ContextSaved
				from executionUnit.executionPort.contextSaved to scheduler.executionPort.contextSaved;
		}

		interface schedulerMemoryInterface
			connect scheduler.memoryPort to memoryManager.memoryPort {
			flow allocateFlow of AllocateRequest
				from scheduler.memoryPort.alloc to memoryManager.memoryPort.alloc;
			flow deallocateFlow of DeallocateRequest
				from scheduler.memoryPort.dealloc to memoryManager.memoryPort.dealloc;
			flow allocatedFlow of StackAllocated
				from memoryManager.memoryPort.allocated to scheduler.memoryPort.allocated;
			flow deallocatedFlow of StackDeallocated
				from memoryManager.memoryPort.deallocated to scheduler.memoryPort.deallocated;
		}
	}

	requirement def ConcurrencySupport {
		text "The system shall support concurrent execution of multiple threads on a single processor.";
	}

	requirement def ContextSwitchLatency {
		text "The system shall complete a context switch within a bounded latency.";
		attribute maxLatency : Real := 0.001;
	}

	requirement def PriorityFairness {
		text "The scheduler shall use priority-based round-robin to prevent thread starvation.";
	}

	requirement def MemoryIsolation {
		text "Each thread shall have an isolated stack memory space.";
	}

	requirement def ThreadLifecycleManagement {
		text "Threads shall follow the lifecycle: created, ready, running, blocked, terminated.";
	}

	requirement def TimeQuantumEnforcement {
		text "The scheduler shall preempt running threads after their time quantum expires.";
		attribute quantum : Real := 0.01;
	}

	verification def VerifyContextSwitch {
		/* Verify that context switching completes within the maximum latency. */
	}

	verification def VerifyMemoryIsolation {
		/* Verify that each thread has an isolated stack memory space. */
	}

	verification def VerifyPriorityFairness {
		/* Verify that lower-priority threads are not starved under sustained load. */
	}
}
