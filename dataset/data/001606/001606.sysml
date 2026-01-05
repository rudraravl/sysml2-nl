package ThreadBasedSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def ThreadIdentifier :> Integer;
	
	attribute def ThreadPriority :> Integer {
		doc /* Priority level from 0 (lowest) to 10 (highest) */
	}
	
	attribute def ExecutionTime :> ISQ::DurationValue;
	
	attribute def MemorySize :> ISQ::LengthValue;
	
	item def Instruction {
		attribute opcode : Integer;
		attribute operands : Integer[*];
		attribute executionCycles : Integer;
	}
	
	item def ThreadDescriptor {
		attribute threadId : ThreadIdentifier;
		attribute priority : ThreadPriority;
		attribute stackSize : MemorySize;
		attribute entryPoint : Integer;
	}
	
	item def ExecutionContext {
		attribute programCounter : Integer;
		attribute stackPointer : Integer;
		attribute registerValues : Integer[*];
		attribute statusFlags : Boolean[*];
	}
	
	item def ScheduleCommand {
		attribute targetThreadId : ThreadIdentifier;
		attribute timeQuantum : ExecutionTime;
		attribute preemptionAllowed : Boolean;
	}
	
	item def ThreadStatusReport {
		attribute threadId : ThreadIdentifier;
		attribute state : ThreadStateKind;
		attribute cpuTimeUsed : ExecutionTime;
		attribute memoryUsed : MemorySize;
	}
	
	enumeration def ThreadStateKind {
		enum created;
		enum ready;
		enum running;
		enum blocked;
		enum terminated;
	}
	
	port def SchedulerControlPort {
		in scheduleCmd : ScheduleCommand;
		out statusReport : ThreadStatusReport;
	}
	
	port def ExecutionPort {
		in instructions : Instruction[*];
		out executionComplete : Boolean;
	}
	
	port def MemoryAccessPort {
		out readRequest : Integer;
		in readData : Integer;
		out writeRequest : Integer;
		out writeData : Integer;
	}
	
	part def ThreadControlBlock {
		attribute descriptor : ThreadDescriptor;
		attribute context : ExecutionContext;
		attribute currentState : ThreadStateKind;
		
		port schedulerPort : SchedulerControlPort;
		
		action def UpdateState {
			in newState : ThreadStateKind;
			out updatedContext : ExecutionContext;
		}
	}
	
	part def ExecutionUnit {
		port execPort : ExecutionPort;
		port memPort : MemoryAccessPort;
		
		action def ProcessInstructions {
			in instructionStream : Instruction[*];
			in context : ExecutionContext;
			out resultContext : ExecutionContext;
			out completed : Boolean;
		}
	}
	
	part def ThreadScheduler {
		attribute readyQueue : ThreadIdentifier[*];
		attribute currentThread : ThreadIdentifier;
		attribute schedulingPolicy : String;
		
		port controlPort : SchedulerControlPort;
		
		action def SelectNextThread {
			in queue : ThreadIdentifier[*];
			in priorities : ThreadPriority[*];
			out selectedId : ThreadIdentifier;
		}
	}
	
	part def MemoryManager {
		attribute totalMemory : MemorySize;
		attribute allocatedMemory : MemorySize;
		
		port accessPort : MemoryAccessPort;
		
		action def AllocateStack {
			in requestedSize : MemorySize;
			out baseAddress : Integer;
			out success : Boolean;
		}
	}
	
	state def ThreadLifecycle {
		entry action initializeThread;
		
		state Created;
		state Ready;
		state Running;
		state Blocked;
		state Terminated;
		
		transition allocateResources first Created then Ready;
		transition scheduled first Ready then Running;
		transition preempt first Running then Ready;
		transition waitForResource first Running then Blocked;
		transition complete first Running then Terminated;
		transition resourceAvailable first Blocked then Ready;
		transition timeout first Blocked then Terminated;
		
		exit action cleanupResources;
	}
	
	action def ThreadExecutionCycle {
		doc /* Primary function: Execute a thread's instructions in a controlled, 
		     scheduled manner while managing its lifecycle and system resources. */
		
		first start;
		
		then action createThread {
			in descriptor : ThreadDescriptor;
			out tcb : ThreadControlBlock;
		}
		
		then action allocateMemory {
			in stackSize = createThread.descriptor.stackSize;
			out stackBase : Integer;
		}
		
		then action initializeContext {
			in entryPoint = createThread.descriptor.entryPoint;
			in stackBase = allocateMemory.stackBase;
			out initialContext : ExecutionContext;
		}
		
		then merge schedulingLoop;
		
		then action waitForScheduling {
			in threadId = createThread.tcb.descriptor.threadId;
			out scheduled : Boolean;
		}
		
		then decide;
			if waitForScheduling.scheduled then executeInstructions;
			if not waitForScheduling.scheduled then schedulingLoop;
		
		action executeInstructions {
			in context = initializeContext.initialContext;
			out updatedContext : ExecutionContext;
			out isComplete : Boolean;
		}
		
		then action saveContext {
			in context = executeInstructions.updatedContext;
			out savedContext : ExecutionContext;
		}
		
		then decide;
			if executeInstructions.isComplete then terminateThread;
			if not executeInstructions.isComplete then checkPreemption;
		
		action checkPreemption {
			out shouldYield : Boolean;
		}
		
		then decide;
			if checkPreemption.shouldYield then yieldProcessor;
			if not checkPreemption.shouldYield then continueExecution;
		
		action yieldProcessor {
			in context = saveContext.savedContext;
		}
		then schedulingLoop;
		
		action continueExecution;
		then executeInstructions;
		
		action terminateThread {
			in context = saveContext.savedContext;
		}
		
		then action releaseResources {
			in stackBase = allocateMemory.stackBase;
		}
		
		then done;
	}
	
	action def SchedulingOperation {
		first start;
		
		then merge schedulerLoop;
		
		then action examineReadyQueue {
			in queue : ThreadIdentifier[*];
			out hasReady : Boolean;
		}
		
		then decide;
			if examineReadyQueue.hasReady then selectThread;
			if not examineReadyQueue.hasReady then idleProcessor;
		
		action selectThread {
			in queue = examineReadyQueue.queue;
			out chosenThreadId : ThreadIdentifier;
		}
		
		then action performContextSwitch {
			in newThreadId = selectThread.chosenThreadId;
			out switchComplete : Boolean;
		}
		
		then action dispatchThread {
			in threadId = selectThread.chosenThreadId;
			out dispatched : Boolean;
		}
		
		then action monitorExecution {
			in threadId = selectThread.chosenThreadId;
			out timeExpired : Boolean;
		}
		
		then decide;
			if monitorExecution.timeExpired then preemptThread;
			if not monitorExecution.timeExpired then schedulerLoop;
		
		action preemptThread {
			in threadId = selectThread.chosenThreadId;
		}
		then schedulerLoop;
		
		action idleProcessor;
		then schedulerLoop;
	}
	
	part threadBasedSystem {
		doc /* A thread-based execution system that manages concurrent execution 
		     of multiple instruction streams through scheduling, context switching, 
		     and resource allocation. The primary function is to provide isolated, 
		     time-shared execution environments for multiple computational tasks. */
		
		attribute maxThreads : Integer = 16;
		attribute defaultTimeQuantum : ExecutionTime = 10[SI::ms];
		attribute totalSystemMemory : MemorySize = 1024[SI::m];
		
		part scheduler : ThreadScheduler {
			attribute :>> schedulingPolicy = "priority-based-round-robin";
			perform action scheduling : SchedulingOperation;
		}
		
		part executionUnit : ExecutionUnit {
			perform scheduling.dispatchThread;
		}
		
		part memoryManager : MemoryManager {
			attribute :>> totalMemory = totalSystemMemory;
		}
		
		part thread1 : ThreadControlBlock {
			attribute :>> descriptor.threadId = 1;
			attribute :>> descriptor.priority = 5;
			attribute :>> descriptor.stackSize = 64[SI::m];
			perform state lifecycle1 : ThreadLifecycle;
			perform action execution1 : ThreadExecutionCycle;
		}
		
		part thread2 : ThreadControlBlock {
			attribute :>> descriptor.threadId = 2;
			attribute :>> descriptor.priority = 7;
			attribute :>> descriptor.stackSize = 64[SI::m];
			perform state lifecycle2 : ThreadLifecycle;
			perform action execution2 : ThreadExecutionCycle;
		}
		
		part thread3 : ThreadControlBlock {
			attribute :>> descriptor.threadId = 3;
			attribute :>> descriptor.priority = 3;
			attribute :>> descriptor.stackSize = 64[SI::m];
			perform state lifecycle3 : ThreadLifecycle;
			perform action execution3 : ThreadExecutionCycle;
		}
		
		connection schedulerToThread1 connect scheduler.controlPort to thread1.schedulerPort;
		connection schedulerToThread2 connect scheduler.controlPort to thread2.schedulerPort;
		connection schedulerToThread3 connect scheduler.controlPort to thread3.schedulerPort;
		
		connection executionToMemory connect executionUnit.memPort to memoryManager.accessPort;
	}
	
	requirement def SystemRequirements {
		doc /* Top-level requirements for the thread-based execution system. */
		
		requirement <'REQ-001'> concurrentExecution {
			doc /* The system shall support concurrent execution of multiple threads 
			     with isolated execution contexts. */
		}
		
		requirement <'REQ-002'> fairScheduling {
			doc /* The scheduler shall allocate processor time fairly among ready 
			     threads according to their priority levels. */
		}
		
		requirement <'REQ-003'> contextIsolation {
			doc /* Each thread shall maintain independent execution context including 
			     program counter, stack pointer, and register values. */
		}
		
		requirement <'REQ-004'> resourceManagement {
			doc /* The system shall allocate and deallocate memory resources for 
			     thread stacks without fragmentation or leaks. */
		}
		
		requirement <'REQ-005'> stateTransitions {
			doc /* Threads shall transition through defined lifecycle states 
			     (created, ready, running, blocked, terminated) correctly. */
		}
		
		requirement <'REQ-006'> preemption {
			doc /* The system shall support preemptive multitasking with configurable 
			     time quantum for each thread. */
		}
	}
	
	requirement systemSpec : SystemRequirements {
		subject threadBasedSystem;
		
		require concurrentExecution;
		require fairScheduling;
		require contextIsolation;
		require resourceManagement;
		require stateTransitions;
		require preemption;
	}
	
	part systemInstance : threadBasedSystem {
		satisfy SystemRequirements::concurrentExecution;
		satisfy SystemRequirements::fairScheduling;
		satisfy SystemRequirements::contextIsolation;
		satisfy SystemRequirements::resourceManagement;
		satisfy SystemRequirements::stateTransitions;
		satisfy SystemRequirements::preemption;
	}
}
