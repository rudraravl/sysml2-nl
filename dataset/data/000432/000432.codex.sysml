package AnneChamneySystemModel {

  import ScalarValues::*;
  import ISQ::*;

  item def Goal {
    attribute title : String;
    attribute priority : PriorityLevel;
  }

  enum def PriorityLevel {
    enum low;
    enum medium;
    enum high;
    enum critical;
  }

  item def ContextRecord {
    attribute source : String;
    attribute capturedAt : DateTime;
    attribute confidence : Real;
  }

  item def Decision {
    attribute summary : String;
    attribute rationale : String;
    attribute approvalState : ApprovalState;
  }

  enum def ApprovalState {
    enum proposed;
    enum accepted;
    enum deferred;
    enum rejected;
  }

  item def Message {
    attribute subject : String;
    attribute body : String;
    attribute urgency : PriorityLevel;
  }

  item def WorkOutput {
    attribute name : String;
    attribute qualityScore : Real;
    attribute completed : Boolean;
  }

  value def minute :> ISQ::TimeUnit;
  value def hour :> ISQ::TimeUnit;
  value def taskCount;
  value def percent;

  port def GoalInputPort {
    in item goal : Goal;
  }

  port def ContextInputPort {
    in item context : ContextRecord;
  }

  port def DecisionOutputPort {
    out item decision : Decision;
  }

  port def CommunicationPort {
    inout item message : Message;
  }

  port def WorkOutputPort {
    out item output : WorkOutput;
  }

  part def AnneChamneyBasedSystem {
    doc /* Primary function: convert Anne Chamney's goals, contextual information, and stakeholder exchanges into prioritized decisions, coordinated communications, and completed work outputs. */

    attribute systemAvailability : Real = 0.995;
    attribute maximumResponseTime : minute = 15 [minute];
    attribute dailyTaskCapacity : taskCount = 24;
    attribute targetCompletionRate : percent = 92 [percent];

    port goals : GoalInputPort;
    port context : ContextInputPort;
    port decisions : DecisionOutputPort;
    port communications : CommunicationPort;
    port outputs : WorkOutputPort;

    part profile : AnneChamneyProfile;
    part intake : GoalAndContextIntake;
    part prioritizer : PriorityAssessmentEngine;
    part decisionSupport : DecisionSupportModule;
    part communicationCoordinator : CommunicationCoordinator;
    part workManager : WorkExecutionManager;
    part qualityMonitor : QualityMonitor;

    connect goals to intake.goalReceiver;
    connect context to intake.contextReceiver;
    connect intake.normalizedGoals to prioritizer.goalFeed;
    connect intake.normalizedContext to prioritizer.contextFeed;
    connect prioritizer.prioritizedGoals to decisionSupport.goalQueue;
    connect profile.preferencePort to decisionSupport.preferenceInput;
    connect decisionSupport.decisionPort to decisions;
    connect decisionSupport.communicationNeedPort to communicationCoordinator.requestPort;
    connect communications to communicationCoordinator.externalMessagePort;
    connect decisionSupport.workDirectivePort to workManager.directivePort;
    connect workManager.outputPort to qualityMonitor.inputPort;
    connect qualityMonitor.acceptedOutputPort to outputs;

    perform behavior AnneChamneyOperatingCycle;
  }

  part def AnneChamneyProfile {
    attribute name : String = "Anne Chamney";
    attribute decisionStyle : String = "context-aware, priority-driven, accountable";
    attribute preferredResponseTime : minute = 10 [minute];
    attribute maximumConcurrentInitiatives : taskCount = 5;

    port preferencePort {
      out item preferenceContext : ContextRecord;
    }
  }

  part def GoalAndContextIntake {
    port goalReceiver : GoalInputPort;
    port contextReceiver : ContextInputPort;

    port normalizedGoals {
      out item goal : Goal;
    }

    port normalizedContext {
      out item context : ContextRecord;
    }

    action normalizeInputs {
      in item rawGoal : Goal;
      in item rawContext : ContextRecord;
      out item normalizedGoal : Goal;
      out item normalizedContext : ContextRecord;
    }
  }

  part def PriorityAssessmentEngine {
    attribute minimumConfidence : Real = 0.70;
    attribute escalationThreshold : PriorityLevel = PriorityLevel::critical;

    port goalFeed {
      in item goal : Goal;
    }

    port contextFeed {
      in item context : ContextRecord;
    }

    port prioritizedGoals {
      out item goal : Goal;
    }

    action assessPriority {
      in item candidateGoal : Goal;
      in item currentContext : ContextRecord;
      out item assessedGoal : Goal;
    }
  }

  part def DecisionSupportModule {
    port goalQueue {
      in item goal : Goal;
    }

    port preferenceInput {
      in item preferenceContext : ContextRecord;
    }

    port decisionPort : DecisionOutputPort;

    port communicationNeedPort {
      out item message : Message;
    }

    port workDirectivePort {
      out item directive : Goal;
    }

    action generateDecision {
      in item goal : Goal;
      in item preferenceContext : ContextRecord;
      out item decision : Decision;
      out item directive : Goal;
    }
  }

  part def CommunicationCoordinator {
    attribute maximumDraftTime : minute = 5 [minute];

    port requestPort {
      in item message : Message;
    }

    port externalMessagePort : CommunicationPort;

    action composeMessage {
      in item communicationNeed : Message;
      out item preparedMessage : Message;
    }

    action routeMessage {
      in item preparedMessage : Message;
      out item deliveredMessage : Message;
    }
  }

  part def WorkExecutionManager {
    attribute normalWorkLimit : hour = 8 [hour];
    attribute criticalWorkLimit : hour = 2 [hour];

    port directivePort {
      in item directive : Goal;
    }

    port outputPort {
      out item output : WorkOutput;
    }

    action executeWork {
      in item directive : Goal;
      out item result : WorkOutput;
    }
  }

  part def QualityMonitor {
    attribute minimumQualityScore : Real = 0.85;

    port inputPort {
      in item output : WorkOutput;
    }

    port acceptedOutputPort : WorkOutputPort;

    action evaluateOutput {
      in item candidateOutput : WorkOutput;
      out item acceptedOutput : WorkOutput;
    }
  }

  action def AnneChamneyOperatingCycle {
    in item incomingGoal : Goal;
    in item incomingContext : ContextRecord;
    out item completedOutput : WorkOutput;

    first start;
    then collectInputs;
    then rankPriorities;
    then decide;
    then coordinate;
    then execute;
    then verify;
    then done;

    action collectInputs;
    action rankPriorities;
    action decide;
    action coordinate;
    action execute;
    action verify;

    succession start then collectInputs;
    succession collectInputs then rankPriorities;
    succession rankPriorities then decide;
    succession decide then coordinate;
    succession coordinate then execute;
    succession execute then verify;
    succession verify then done;
  }

  state def AnneChamneySystemStateMachine {
    state idle;
    state receiving;
    state analyzing;
    state deciding;
    state coordinating;
    state executing;
    state validating;
    state completed;
    state exceptionHandling;

    transition first idle;
    transition idle_to_receiving
      first idle
      then receiving;

    transition receiving_to_analyzing
      first receiving
      then analyzing;

    transition analyzing_to_deciding
      first analyzing
      then deciding;

    transition deciding_to_coordinating
      first deciding
      then coordinating;

    transition coordinating_to_executing
      first coordinating
      then executing;

    transition executing_to_validating
      first executing
      then validating;

    transition validating_to_completed
      first validating
      then completed;

    transition validation_rework
      first validating
      then executing;

    transition fault_response
      first analyzing
      then exceptionHandling;

    transition exception_recovery
      first exceptionHandling
      then receiving;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall support Anne Chamney by transforming goals and context into prioritized decisions, coordinated communications, and completed work outputs. */
    subject system : AnneChamneyBasedSystem;
    require constraint {
      system.targetCompletionRate >= 90 [percent]
    }
  }

  requirement def ResponsivenessRequirement {
    doc /* The system shall produce an accepted decision within the maximum response time for high or critical priority goals. */
    subject system : AnneChamneyBasedSystem;
    require constraint {
      system.maximumResponseTime <= 15 [minute]
    }
  }

  requirement def CapacityRequirement {
    doc /* The system shall manage a practical daily workload without exceeding Anne Chamney's preferred concurrent initiative limit. */
    subject system : AnneChamneyBasedSystem;
    require constraint {
      system.dailyTaskCapacity >= 20
    }
  }

  requirement def QualityRequirement {
    doc /* The system shall release only work outputs meeting the defined quality threshold. */
    subject monitor : QualityMonitor;
    require constraint {
      monitor.minimumQualityScore >= 0.85
    }
  }

  part anneChamneyOperationalSystem : AnneChamneyBasedSystem;

}