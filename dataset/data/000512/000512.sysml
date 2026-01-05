package 'TOPS System Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    enum def TaskPriority {
        low;
        medium;
        high;
        critical;
    }
    
    enum def PlanStatus {
        draft;
        validated;
        optimized;
        adjusted;
        executing;
        completed;
    }
    
    enum def ResourceState {
        available;
        allocated;
        unavailable;
        maintenance;
    }
    
    enum def ExecutionMode {
        manual;
        semiAutonomous;
        autonomous;
    }
    
    item def MissionGoal {
        attribute goalId : String;
        attribute description : String;
        attribute priority : TaskPriority;
        attribute deadline : ISQ::DurationValue;
    }
    
    item def SystemResource {
        attribute resourceId : String;
        attribute availablePower : ISQ::PowerValue;
        attribute availableEnergy : ISQ::EnergyValue;
        attribute resourceState : ResourceState;
        attribute capacity : ISQ::MassValue;
    }
    
    item def OperationalConstraint {
        attribute constraintId : String;
        attribute constraintType : String;
        attribute limitValue : Real;
    }
    
    item def ScheduledTask {
        attribute taskId : String;
        attribute description : String;
        attribute startTime : ISQ::DurationValue;
        attribute endTime : ISQ::DurationValue;
        attribute allocatedResource : String;
        attribute requiredPower : ISQ::PowerValue;
        attribute requiredEnergy : ISQ::EnergyValue;
    }
    
    item def ExecutionPlan {
        attribute planId : String;
        attribute planStatus : PlanStatus;
        attribute tasks : ScheduledTask[0..*] ordered;
        attribute totalDuration : ISQ::DurationValue;
        attribute totalEnergyUsed : ISQ::EnergyValue;
    }
    
    item def PerformanceMetrics {
        attribute efficiency : Real;
        attribute resourceUtilization : Real;
        attribute goalCompletionRate : Real;
    }
    
    port def DataInputPort {
        in item goals : MissionGoal[*];
        in item resources : SystemResource[*];
        in item constraints : OperationalConstraint[*];
    }
    
    port def PlanOutputPort {
        out item plan : ExecutionPlan;
    }
    
    port def MonitoringPort {
        in item executionStatus : ScheduledTask[*];
        out item metrics : PerformanceMetrics;
    }
    
    port def ControlPort {
        in attribute mode : ExecutionMode;
        out attribute planStatus : PlanStatus;
    }
    
    part def GoalAnalyzer {
        port goalInput : DataInputPort;
        port analyzedOutput : PlanOutputPort;
        
        action analyzeGoals {
            in goals : MissionGoal[*];
            out prioritizedGoals : MissionGoal[*] ordered;
        }
    }
    
    part def ResourceManager {
        port resourceInput : DataInputPort;
        port resourceOutput : PlanOutputPort;
        
        action assessResources {
            in resources : SystemResource[*];
            out availableResources : SystemResource[*];
        }
        
        action allocateResources {
            in tasks : ScheduledTask[*];
            in resources : SystemResource[*];
            out allocatedTasks : ScheduledTask[*];
        }
    }
    
    part def ConstraintValidator {
        port constraintInput : DataInputPort;
        port validationOutput : PlanOutputPort;
        
        action validateConstraints {
            in plan : ExecutionPlan;
            in constraints : OperationalConstraint[*];
            out isValid : Boolean;
            out violations : String[*];
        }
    }
    
    part def PlanGenerator {
        port planInput : DataInputPort;
        port planOutput : PlanOutputPort;
        
        action generateSchedule {
            in goals : MissionGoal[*];
            in resources : SystemResource[*];
            out draftPlan : ExecutionPlan;
        }
        
        action optimizePlan {
            in draftPlan : ExecutionPlan;
            out optimizedPlan : ExecutionPlan;
        }
    }
    
    part def ExecutionMonitor {
        port monitorInput : MonitoringPort;
        port monitorOutput : MonitoringPort;
        
        action trackExecution {
            in currentTasks : ScheduledTask[*];
            out completionStatus : Real;
        }
        
        action detectDeviations {
            in plannedTasks : ScheduledTask[*];
            in actualTasks : ScheduledTask[*];
            out deviations : Real[*];
        }
    }
    
    part def PlanAdjuster {
        port adjustmentInput : MonitoringPort;
        port adjustmentOutput : PlanOutputPort;
        
        action replan {
            in currentPlan : ExecutionPlan;
            in deviations : Real[*];
            out revisedPlan : ExecutionPlan;
        }
    }
    
    part def TOPSSystem {
        doc /* 
            Tactical Operations Planning System (TOPS) - 
            An autonomous planning and execution system that generates, validates, 
            and dynamically adjusts operational plans to achieve mission goals 
            while optimizing resource utilization and satisfying operational constraints.
        */
        
        part goalAnalyzer : GoalAnalyzer;
        part resourceManager : ResourceManager;
        part constraintValidator : ConstraintValidator;
        part planGenerator : PlanGenerator;
        part executionMonitor : ExecutionMonitor;
        part planAdjuster : PlanAdjuster;
        
        port missionInput : DataInputPort;
        port planOutput : PlanOutputPort;
        port executionMonitoring : MonitoringPort;
        port systemControl : ControlPort;
        
        connection goalToAnalyzer 
            connect missionInput to goalAnalyzer.goalInput;
        connection resourceToManager 
            connect missionInput to resourceManager.resourceInput;
        connection constraintToValidator 
            connect missionInput to constraintValidator.constraintInput;
        connection analyzerToGenerator 
            connect goalAnalyzer.analyzedOutput to planGenerator.planInput;
        connection managerToGenerator 
            connect resourceManager.resourceOutput to planGenerator.planInput;
        connection generatorToValidator 
            connect planGenerator.planOutput to constraintValidator.constraintInput;
        connection validatorToOutput 
            connect constraintValidator.validationOutput to planOutput;
        connection monitorToAdjuster 
            connect executionMonitor.monitorOutput to planAdjuster.adjustmentInput;
        connection adjusterToOutput 
            connect planAdjuster.adjustmentOutput to planOutput;
        
        perform action executeTOPSFunction;
    }
    
    action def AnalyzeGoals {
        in goals : MissionGoal[*];
        out prioritizedGoals : MissionGoal[*] ordered;
    }
    
    action def AssessResources {
        in resources : SystemResource[*];
        out resourceModel : SystemResource[*];
    }
    
    action def GeneratePlan {
        in goals : MissionGoal[*];
        in resources : SystemResource[*];
        out plan : ExecutionPlan;
    }
    
    action def ValidatePlan {
        in plan : ExecutionPlan;
        in constraints : OperationalConstraint[*];
        out isValid : Boolean;
    }
    
    action def OptimizePlan {
        in plan : ExecutionPlan;
        out optimizedPlan : ExecutionPlan;
    }
    
    action def MonitorExecution {
        in plan : ExecutionPlan;
        out executionMetrics : PerformanceMetrics;
    }
    
    action def AdjustPlan {
        in currentPlan : ExecutionPlan;
        in metrics : PerformanceMetrics;
        out adjustedPlan : ExecutionPlan;
    }
    
    action executeTOPSFunction {
        doc /* 
            Primary function: Autonomously generate, validate, optimize, and 
            dynamically adjust operational plans to achieve mission goals while 
            maximizing resource efficiency and maintaining compliance with all 
            operational constraints through continuous monitoring and replanning.
        */
        
        in goals : MissionGoal[*];
        in resources : SystemResource[*];
        in constraints : OperationalConstraint[*];
        out finalPlan : ExecutionPlan;
        
        private attribute currentPlan : ExecutionPlan;
        private attribute planValid : Boolean := false;
        
        first start;
        then merge planningCycle;
        
        action analyzeGoals : AnalyzeGoals {
            in goals = executeTOPSFunction::goals;
            out prioritizedGoals;
        }
        
        flow analyzeGoals.prioritizedGoals to assessResources.goals;
        
        action assessResources : AssessResources {
            in resources = executeTOPSFunction::resources;
            in goals : MissionGoal[*];
            out resourceModel;
        }
        
        flow assessResources.resourceModel to generatePlan.resources;
        flow analyzeGoals.prioritizedGoals to generatePlan.goals;
        
        action generatePlan : GeneratePlan {
            in goals : MissionGoal[*];
            in resources : SystemResource[*];
            out plan;
        }
        
        then assign currentPlan := generatePlan.plan;
        
        then action validatePlan : ValidatePlan {
            in plan = currentPlan;
            in constraints = executeTOPSFunction::constraints;
            out isValid;
        }
        
        then assign planValid := validatePlan.isValid;
        
        then decide;
            if planValid then optimizePlan;
            else regeneratePlan;
        
        action optimizePlan : OptimizePlan {
            in plan = currentPlan;
            out optimizedPlan;
        }
        
        then assign currentPlan := optimizePlan.optimizedPlan;
        then assign finalPlan := currentPlan;
        then monitorExecution;
        
        action regeneratePlan : GeneratePlan {
            in goals = analyzeGoals.prioritizedGoals;
            in resources = assessResources.resourceModel;
            out plan;
        }
        
        then assign currentPlan := regeneratePlan.plan;
        then planningCycle;
        
        action monitorExecution : MonitorExecution {
            in plan = currentPlan;
            out executionMetrics;
        }
        
        then decide;
            if monitorExecution.executionMetrics.efficiency < 0.8 then adjustPlan;
            else continueExecution;
        
        action adjustPlan : AdjustPlan {
            in currentPlan = currentPlan;
            in metrics = monitorExecution.executionMetrics;
            out adjustedPlan;
        }
        
        then assign currentPlan := adjustPlan.adjustedPlan;
        then assign finalPlan := currentPlan;
        then merge continueExecution;
        
        then continueExecution;
        then planningCycle;
    }
    
    requirement def PlanGenerationRequirement {
        doc /* The TOPS System shall generate valid operational plans that achieve all mission goals. */
        
        subject topsSystem : TOPSSystem;
    }
    
    requirement def ResourceOptimizationRequirement {
        doc /* The TOPS System shall optimize resource utilization to maximize efficiency. */
        
        subject topsSystem : TOPSSystem;
    }
    
    requirement def ConstraintComplianceRequirement {
        doc /* The TOPS System shall ensure all generated plans comply with operational constraints. */
        
        subject topsSystem : TOPSSystem;
    }
    
    requirement def AdaptiveReplanningRequirement {
        doc /* The TOPS System shall dynamically adjust plans in response to execution deviations. */
        
        subject topsSystem : TOPSSystem;
    }
    
    requirement systemOperationalRequirements {
        doc /* The TOPS System shall meet all planning, optimization, and execution requirements. */
        
        subject topsSystem : TOPSSystem;
    }
    
    part topsSystemInstance : TOPSSystem;
    
    satisfy systemOperationalRequirements by topsSystemInstance;
}
