package MTBFReliabilitySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FailureRate :> Real;
    attribute def ReliabilityMetric :> Real;
    
    item def FailureEvent {
        attribute timestamp : TimeValue;
        attribute componentId : String;
        attribute failureMode : String;
    }
    
    item def MaintenanceAction {
        attribute scheduledTime : TimeValue;
        attribute actionType : String;
        attribute duration : TimeValue;
    }
    
    item def MaintenanceScheduled;
    item def MaintenanceCompleted;
    item def ReliabilityThresholdBreached;
    item def SystemRestored;
    item def CatastrophicFailure;
    
    port def MonitoringPort {
        out statusData : FailureEvent;
    }
    
    port def ControlPort {
        in maintenanceCommand : MaintenanceAction;
    }
    
    port def DataPort {
        out reliabilityData : ReliabilityMetric;
    }
    
    part def CriticalComponent {
        attribute componentMTBF : TimeValue;
        attribute operationalHours : TimeValue;
        attribute failureCount : Integer;
        
        port statusPort : MonitoringPort;
        port controlPort : ControlPort;
    }
    
    part def ReliabilityMonitor {
        attribute systemMTBF : TimeValue;
        attribute totalUptime : TimeValue;
        attribute totalFailures : Integer;
        attribute currentReliability : ReliabilityMetric;
        
        port componentDataIn;
        port reliabilityDataOut : DataPort;
        port maintenanceSignal;
    }
    
    part def MaintenanceController {
        attribute maintenanceInterval : TimeValue;
        attribute nextScheduledMaintenance : TimeValue;
        
        port reliabilityInput;
        port maintenanceOutput;
    }
    
    part def DataRecorder {
        attribute failureLog : FailureEvent[*];
        attribute maintenanceLog : MaintenanceAction[*];
        
        port eventInput;
        port reportOutput;
    }
    
    action def ComputeSystemMTBF {
        in totalOperatingTime : TimeValue;
        in failureCount : Integer;
        out mtbf : TimeValue;
    }
    
    action def AssessReliability {
        in currentMTBF : TimeValue;
        in operatingHours : TimeValue;
        out reliabilityScore : ReliabilityMetric;
        out maintenanceNeeded : Boolean;
    }
    
    action def SchedulePreventiveMaintenance {
        in systemMTBF : TimeValue;
        in currentUptime : TimeValue;
        out maintenanceAction : MaintenanceAction;
    }
    
    action def RecordFailureEvent {
        in failure : FailureEvent;
        out updatedLog : FailureEvent[*];
    }
    
    state def OperationalLifecycle {
        entry action initializeMonitoring;
        
        state normalOperation {
            entry action startContinuousMonitoring;
            do action monitorReliability : AssessReliability;
        }
        
        transition normalToMaintenance
            first normalOperation
            accept event maintenanceScheduledEvent : MaintenanceScheduled
            then scheduledMaintenance;
        
        state scheduledMaintenance {
            entry action performPreventiveMaintenance;
            do action executeMaintenanceProcedures;
        }
        
        transition maintenanceToNormal
            first scheduledMaintenance
            accept event maintenanceCompletedEvent : MaintenanceCompleted
            then normalOperation;
        
        state degradedOperation {
            entry action activateRedundancy;
            do action operateWithReducedCapacity;
        }
        
        transition normalToDegraded
            first normalOperation
            accept event reliabilityBreachEvent : ReliabilityThresholdBreached
            then degradedOperation;
        
        transition degradedToNormal
            first degradedOperation
            accept event systemRestoredEvent : SystemRestored
            then normalOperation;
        
        state criticalFailure {
            entry action initiateEmergencyShutdown;
        }
        
        transition degradedToCritical
            first degradedOperation
            accept event catastrophicFailureEvent : CatastrophicFailure
            then criticalFailure;
    }
    
    action def MTBFManagementProcess {
        first start;
        
        then action initializeSystem {
            out baselineMTBF : TimeValue;
            out componentCount : Integer;
        }
        
        then merge continuousMonitoring;
        
        then action calculateMTBF : ComputeSystemMTBF {
            in totalOperatingTime;
            in failureCount;
            out mtbf;
        }
        
        then action evaluateReliability : AssessReliability {
            in currentMTBF = calculateMTBF.mtbf;
            in operatingHours;
            out reliabilityScore;
            out maintenanceNeeded;
        }
        
        then decide;
            if evaluateReliability.reliabilityScore < 0.90 then triggerMaintenance;
            if evaluateReliability.reliabilityScore >= 0.90 then continueMonitoring;
        
        action triggerMaintenance : SchedulePreventiveMaintenance {
            in systemMTBF = calculateMTBF.mtbf;
            in currentUptime;
            out maintenanceAction;
        }
        then action performMaintenance;
        then action recordMaintenanceEvent;
        then continuousMonitoring;
        
        action continueMonitoring;
        then action detectFailures {
            out failureDetected : Boolean;
        }
        
        then decide;
            if detectFailures.failureDetected then processFailure;
            if not detectFailures.failureDetected then continuousMonitoring;
        
        action processFailure {
            action logFailure : RecordFailureEvent {
                in failure;
                out updatedLog;
            }
            then action updateMTBFMetrics;
            then action initiateCorrectiveAction;
        }
        then continuousMonitoring;
        
        then done;
    }
    
    part reliabilitySystem {
        doc /* This system continuously monitors and manages the reliability 
             * of critical components based on Mean Time Between Failures (MTBF).
             * Its primary function is to predict and prevent failures through
             * proactive maintenance scheduling, ensuring high system availability
             * and minimizing unplanned downtime by maintaining MTBF above target thresholds.
            */
        
        attribute targetMTBF : TimeValue = 10000[SI::h];
        attribute minimumReliability : ReliabilityMetric = 0.90;
        attribute operationalThreshold : ReliabilityMetric = 0.95;
        
        part monitor : ReliabilityMonitor {
            attribute :>> systemMTBF = 10000[SI::h];
            attribute :>> totalUptime = 0[SI::h];
            attribute :>> totalFailures = 0;
            attribute :>> currentReliability = 1.0;
        }
        
        part primaryComponent : CriticalComponent {
            attribute :>> componentMTBF = 12000[SI::h];
            attribute :>> operationalHours = 0[SI::h];
            attribute :>> failureCount = 0;
        }
        
        part secondaryComponent : CriticalComponent {
            attribute :>> componentMTBF = 15000[SI::h];
            attribute :>> operationalHours = 0[SI::h];
            attribute :>> failureCount = 0;
        }
        
        part backupComponent : CriticalComponent {
            attribute :>> componentMTBF = 11000[SI::h];
            attribute :>> operationalHours = 0[SI::h];
            attribute :>> failureCount = 0;
        }
        
        part maintenanceController : MaintenanceController {
            attribute :>> maintenanceInterval = 8000[SI::h];
            attribute :>> nextScheduledMaintenance = 8000[SI::h];
        }
        
        part dataRecorder : DataRecorder {
            attribute :>> failureLog = ();
            attribute :>> maintenanceLog = ();
        }
        
        connection conn1 connect primaryComponent.statusPort to monitor.componentDataIn;
        connection conn2 connect secondaryComponent.statusPort to monitor.componentDataIn;
        connection conn3 connect backupComponent.statusPort to monitor.componentDataIn;
        connection conn4 connect monitor.reliabilityDataOut to maintenanceController.reliabilityInput;
        connection conn5 connect monitor.maintenanceSignal to maintenanceController.reliabilityInput;
        connection conn6 connect maintenanceController.maintenanceOutput to primaryComponent.controlPort;
        connection conn7 connect maintenanceController.maintenanceOutput to secondaryComponent.controlPort;
        connection conn8 connect maintenanceController.maintenanceOutput to backupComponent.controlPort;
        connection conn9 connect monitor.componentDataIn to dataRecorder.eventInput;
        connection conn10 connect maintenanceController.maintenanceOutput to dataRecorder.eventInput;
    }
    
    requirement <'REQ-MTBF-100'> systemMTBFRequirement {
        doc /* The system shall maintain a Mean Time Between Failures 
             * of at least 10,000 hours to ensure continuous operation 
             * and minimize service interruptions.
            */
        subject system :> reliabilitySystem;
        
        require constraint {
            system.targetMTBF >= 10000[SI::h]
        }
    }
    
    requirement <'REQ-MTBF-101'> reliabilityThresholdRequirement {
        doc /* The system shall maintain a reliability metric of at least 
             * 0.90 during normal operations to meet availability targets.
            */
        subject system :> reliabilitySystem;
        
        require constraint {
            system.minimumReliability >= 0.90
        }
    }
    
    requirement <'REQ-MTBF-102'> componentMTBFRequirement {
        doc /* Each critical component shall have an individual MTBF 
             * rating of at least 11,000 hours to support overall system reliability.
            */
        subject comp1 :> reliabilitySystem.primaryComponent;
        subject comp2 :> reliabilitySystem.secondaryComponent;
        subject comp3 :> reliabilitySystem.backupComponent;
        
        require constraint {
            comp1.componentMTBF >= 11000[SI::h] and
            comp2.componentMTBF >= 11000[SI::h] and
            comp3.componentMTBF >= 11000[SI::h]
        }
    }
    
    requirement <'REQ-MTBF-103'> preventiveMaintenanceRequirement {
        doc /* Preventive maintenance shall be scheduled at intervals 
             * not exceeding 80% of the system MTBF to prevent failures 
             * before they occur.
            */
        subject controller :> reliabilitySystem.maintenanceController;
        subject system :> reliabilitySystem;
        
        require constraint {
            controller.maintenanceInterval <= 0.8 * system.targetMTBF
        }
    }
    
    requirement <'REQ-MTBF-104'> failureLoggingRequirement {
        doc /* The system shall record all failure events with accurate 
             * timestamps and component identification to enable precise 
             * MTBF calculations and trend analysis.
            */
        subject recorder :> reliabilitySystem.dataRecorder;
    }
    
    satisfy systemMTBFRequirement by reliabilitySystem;
    satisfy reliabilityThresholdRequirement by reliabilitySystem;
    satisfy componentMTBFRequirement by reliabilitySystem.primaryComponent;
    satisfy componentMTBFRequirement by reliabilitySystem.secondaryComponent;
    satisfy componentMTBFRequirement by reliabilitySystem.backupComponent;
    satisfy preventiveMaintenanceRequirement by reliabilitySystem.maintenanceController;
    satisfy failureLoggingRequirement by reliabilitySystem.dataRecorder;
}
