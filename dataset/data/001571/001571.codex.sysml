package SemiAutomationSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Percent :> Real {
    range = "0.0..100.0";
    unit = "%";
  }

  attribute def ConfidenceScore :> Real {
    range = "0.0..1.0";
  }

  attribute def Duration_s :> Real {
    unit = "s";
  }

  attribute def Force_N :> Real {
    unit = "N";
  }

  attribute def Speed_mps :> Real {
    unit = "m/s";
  }

  attribute def Voltage_V :> Real {
    unit = "V";
  }

  attribute def Current_A :> Real {
    unit = "A";
  }

  attribute def Temperature_C :> Real {
    unit = "degC";
  }

  enum def AutomationMode {
    enum manual;
    enum assisted;
    enum supervisedAutomatic;
    enum safeHold;
    enum fault;
  }

  enum def OperatorDecision {
    enum approve;
    enum modify;
    enum reject;
    enum emergencyStop;
  }

  enum def TaskStatus {
    enum idle;
    enum analyzing;
    enum awaitingHumanApproval;
    enum executing;
    enum completed;
    enum interrupted;
    enum failed;
  }

  item def WorkOrder {
    attribute orderId : String;
    attribute requestedOperation : String;
    attribute priority : Integer;
    attribute targetThroughputPerHour : Integer;
  }

  item def TaskPlan {
    attribute planId : String;
    attribute confidence : ConfidenceScore;
    attribute estimatedDuration : Duration_s;
    attribute requiresApproval : Boolean;
  }

  item def HumanCommand {
    attribute decision : OperatorDecision;
    attribute commandText : String;
    attribute issuedAt : Duration_s;
  }

  item def MachineCommand {
    attribute commandId : String;
    attribute targetSpeed : Speed_mps;
    attribute targetForce : Force_N;
    attribute enableMotion : Boolean;
  }

  item def SensorReading {
    attribute timestamp : Duration_s;
    attribute objectDetected : Boolean;
    attribute measuredForce : Force_N;
    attribute measuredSpeed : Speed_mps;
    attribute localTemperature : Temperature_C;
  }

  item def StatusReport {
    attribute mode : AutomationMode;
    attribute taskStatus : TaskStatus;
    attribute percentComplete : Percent;
    attribute activeFaultCode : String;
  }

  item def ElectricalPower {
    attribute voltage : Voltage_V;
    attribute current : Current_A;
  }

  port def WorkOrderInputPort {
    in item workOrder : WorkOrder;
  }

  port def HumanInteractionPort {
    out item recommendedPlan : TaskPlan;
    in item operatorCommand : HumanCommand;
    out item statusToOperator : StatusReport;
  }

  port def MachineControlPort {
    out item machineCommand : MachineCommand;
    in item sensorReading : SensorReading;
  }

  port def StatusOutputPort {
    out item statusReport : StatusReport;
  }

  port def PowerInputPort {
    in item electricalPower : ElectricalPower;
  }

  port def InternalPlanPort {
    out item taskPlan : TaskPlan;
  }

  port def InternalApprovalPort {
    in item humanCommand : HumanCommand;
  }

  part def SemiAutomationController {
    port orderInput : WorkOrderInputPort;
    port humanInterface : HumanInteractionPort;
    port machineControl : MachineControlPort;
    port statusOutput : StatusOutputPort;
    port powerInput : PowerInputPort;

    attribute currentMode : AutomationMode = AutomationMode::manual;
    attribute currentTaskStatus : TaskStatus = TaskStatus::idle;
    attribute automationConfidenceThreshold : ConfidenceScore = 0.82;
    attribute maximumExecutionSpeed : Speed_mps = 1.50;
    attribute maximumAppliedForce : Force_N = 250.0;
    attribute approvalTimeout : Duration_s = 45.0;

    perform action processSemiAutomatedTask;
  }

  part def TaskAnalyzer {
    port orderInput : WorkOrderInputPort;
    port planOutput : InternalPlanPort;

    attribute minimumPlanConfidence : ConfidenceScore = 0.70;
    attribute nominalAnalysisTime : Duration_s = 3.0;

    action analyzeWorkOrder {
      in item order : WorkOrder;
      out item generatedPlan : TaskPlan;
    }
  }

  part def HumanApprovalStation {
    port humanInterface : HumanInteractionPort;
    port approvalOutput : InternalApprovalPort;

    attribute displayRefreshPeriod : Duration_s = 0.25;
    attribute operatorResponseLimit : Duration_s = 45.0;

    action requestApproval {
      in item proposedPlan : TaskPlan;
      out item command : HumanCommand;
    }
  }

  part def ExecutionSupervisor {
    port planInput : InternalPlanPort;
    port approvalInput : InternalApprovalPort;
    port machineControl : MachineControlPort;
    port statusOutput : StatusOutputPort;

    attribute safeSpeedLimit : Speed_mps = 1.20;
    attribute safeForceLimit : Force_N = 200.0;
    attribute sensorTimeout : Duration_s = 0.50;
    attribute completionTolerance : Percent = 98.0;

    action executeApprovedPlan {
      in item approvedPlan : TaskPlan;
      out item command : MachineCommand;
    }

    action monitorExecution {
      in item feedback : SensorReading;
      out item report : StatusReport;
    }
  }

  part def SafetyManager {
    port machineControl : MachineControlPort;
    port statusOutput : StatusOutputPort;

    attribute emergencyStopLatency : Duration_s = 0.20;
    attribute maximumSafeTemperature : Temperature_C = 65.0;
    attribute maximumSafeForce : Force_N = 240.0;

    action evaluateSafety {
      in item feedback : SensorReading;
      out item safeToContinue : Boolean;
    }

    action enterSafeHold {
      out item stopCommand : MachineCommand;
    }
  }

  part def AssistedMachine {
    port controlPort : MachineControlPort;
    port powerPort : PowerInputPort;

    attribute ratedVoltage : Voltage_V = 48.0;
    attribute ratedCurrent : Current_A = 20.0;
    attribute achievableSpeed : Speed_mps = 1.80;
    attribute achievableForce : Force_N = 300.0;

    action performPhysicalOperation {
      in item command : MachineCommand;
      out item feedback : SensorReading;
    }
  }

  action def ProcessSemiAutomatedTask {
    in item workOrder : WorkOrder;
    in item operatorCommand : HumanCommand;
    in item sensorReading : SensorReading;
    out item statusReport : StatusReport;

    first start;
    then analyze;

    action analyze {
      out item proposedPlan : TaskPlan;
    }

    then requestHumanDecision;

    action requestHumanDecision {
      in item proposedPlan : TaskPlan;
      out item decision : HumanCommand;
    }

    then decide;

    action decide {
      in item decision : HumanCommand;
      out item approved : Boolean;
    }

    if approved then execute;
    else holdForRevision;

    action execute {
      in item proposedPlan : TaskPlan;
      out item machineCommand : MachineCommand;
    }

    then monitor;

    action monitor {
      in item sensorReading : SensorReading;
      out item statusReport : StatusReport;
    }

    then done;

    action holdForRevision {
      out item statusReport : StatusReport;
    }

    then done;
  }

  state def SemiAutomationOperatingStates {
    entry action initializeSystem;

    state off;
    state manualControl;
    state analyzingWorkOrder;
    state awaitingApproval;
    state supervisedExecution;
    state safeHold;
    state completed;
    state faulted;

    transition initial then off;

    transition powerApplied
      first off
      accept item electricalPower : ElectricalPower
      then manualControl;

    transition receiveWorkOrder
      first manualControl
      accept item workOrder : WorkOrder
      then analyzingWorkOrder;

    transition planPrepared
      first analyzingWorkOrder
      accept item taskPlan : TaskPlan
      if taskPlan.confidence >= 0.82
      then awaitingApproval;

    transition lowConfidencePlan
      first analyzingWorkOrder
      accept item taskPlan : TaskPlan
      if taskPlan.confidence < 0.82
      then manualControl;

    transition operatorApproves
      first awaitingApproval
      accept item command : HumanCommand
      if command.decision == OperatorDecision::approve
      then supervisedExecution;

    transition operatorModifies
      first awaitingApproval
      accept item command : HumanCommand
      if command.decision == OperatorDecision::modify
      then analyzingWorkOrder;

    transition operatorRejects
      first awaitingApproval
      accept item command : HumanCommand
      if command.decision == OperatorDecision::reject
      then manualControl;

    transition executionComplete
      first supervisedExecution
      accept item report : StatusReport
      if report.percentComplete >= 98.0
      then completed;

    transition unsafeCondition
      first supervisedExecution
      accept item reading : SensorReading
      if reading.measuredForce > 240.0 or reading.localTemperature > 65.0
      then safeHold;

    transition emergencyStop
      first manualControl
      accept item command : HumanCommand
      if command.decision == OperatorDecision::emergencyStop
      then safeHold;

    transition emergencyStopDuringApproval
      first awaitingApproval
      accept item command : HumanCommand
      if command.decision == OperatorDecision::emergencyStop
      then safeHold;

    transition resetFromHold
      first safeHold
      accept item command : HumanCommand
      if command.decision == OperatorDecision::approve
      then manualControl;

    transition unrecoverableFault
      first safeHold
      accept item report : StatusReport
      if report.activeFaultCode != "NONE"
      then faulted;
  }

  part def SemiAutomationSystem {
    doc /* 
     * Primary function: coordinate human judgment and automated machine execution so that a work order is analyzed, converted into a recommended task plan, approved or modified by an operator, and then executed under continuous supervision with safety limits enforced.
     */

    port workOrderInput : WorkOrderInputPort;
    port operatorInterface : HumanInteractionPort;
    port statusOutput : StatusOutputPort;
    port powerInput : PowerInputPort;

    part controller : SemiAutomationController;
    part analyzer : TaskAnalyzer;
    part approvalStation : HumanApprovalStation;
    part supervisor : ExecutionSupervisor;
    part safetyManager : SafetyManager;
    part machine : AssistedMachine;

    attribute nominalHumanApprovalTime : Duration_s = 20.0;
    attribute nominalTaskCycleTime : Duration_s = 120.0;
    attribute targetAutomationCoverage : Percent = 65.0;
    attribute minimumHumanOversightCoverage : Percent = 100.0;

    bind workOrderInput = controller.orderInput;
    bind operatorInterface = controller.humanInterface;
    bind statusOutput = controller.statusOutput;
    bind powerInput = machine.powerPort;

    connect controller.orderInput to analyzer.orderInput;
    connect analyzer.planOutput to supervisor.planInput;
    connect analyzer.planOutput to approvalStation.humanInterface;
    connect operatorInterface to approvalStation.humanInterface;
    connect approvalStation.approvalOutput to supervisor.approvalInput;
    connect supervisor.machineControl to machine.controlPort;
    connect machine.controlPort to safetyManager.machineControl;
    connect supervisor.statusOutput to controller.statusOutput;
    connect safetyManager.statusOutput to controller.statusOutput;

    perform action controller.processSemiAutomatedTask : ProcessSemiAutomatedTask;

    exhibit state operatingState : SemiAutomationOperatingStates;
  }

  requirement def SemiAutomationPrimaryFunctionRequirement {
    id = "REQ-SA-001";
    text = "The system shall perform semi-automated task execution by generating a machine-executable task plan from a work order, obtaining human approval before automated execution, and supervising the machine during execution.";
  }

  requirement def HumanAuthorityRequirement {
    id = "REQ-SA-002";
    text = "The system shall require an operator approval, modification, rejection, or emergency stop decision before transitioning from task planning to supervised automatic execution.";
  }

  requirement def SafetyLimitRequirement {
    id = "REQ-SA-003";
    text = "The system shall command safe hold within 0.20 s when measured force exceeds 240 N, local temperature exceeds 65 degC, or an emergency stop command is received.";
  }

  requirement def ConfidenceRequirement {
    id = "REQ-SA-004";
    text = "The system shall submit only task plans with confidence greater than or equal to 0.82 for approval; lower confidence plans shall remain under manual control or be replanned.";
  }

  requirement def StatusVisibilityRequirement {
    id = "REQ-SA-005";
    text = "The system shall report automation mode, task status, completion percentage, and active fault code to the operator throughout planning, approval, execution, completion, safe hold, and fault states.";
  }

  requirement def MachineCommandLimitRequirement {
    id = "REQ-SA-006";
    text = "The system shall limit supervised automatic machine commands to speeds no greater than 1.20 m/s and applied forces no greater than 200 N during approved execution.";
  }

  satisfy SemiAutomationPrimaryFunctionRequirement by SemiAutomationSystem;
  satisfy HumanAuthorityRequirement by HumanApprovalStation;
  satisfy SafetyLimitRequirement by SafetyManager;
  satisfy ConfidenceRequirement by TaskAnalyzer;
  satisfy StatusVisibilityRequirement by SemiAutomationController;
  satisfy MachineCommandLimitRequirement by ExecutionSupervisor;

  concern def HumanSupervisedAutomationConcern {
    doc /*
     * The design balances automated planning and execution with human authority over task release, exception handling, and emergency intervention.
     */
  }

  viewpoint def OperationalViewpoint {
    concern HumanSupervisedAutomationConcern;
    frame SemiAutomationSystem;
  }

  view def HighLevelSemiAutomationOperationalView {
    viewpoint OperationalViewpoint;
    expose SemiAutomationSystem::controller;
    expose SemiAutomationSystem::analyzer;
    expose SemiAutomationSystem::approvalStation;
    expose SemiAutomationSystem::supervisor;
    expose SemiAutomationSystem::safetyManager;
    expose SemiAutomationSystem::machine;
  }
}