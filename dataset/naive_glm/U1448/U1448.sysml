package ReliabilityManagementSystem {
    import ScalarValues::*;

    // ===== Unit Definitions =====

    unit hour {
        doc "Unit of time equal to 3600 seconds.";
    }

    // ===== Value Types =====

    value def OperationalHours :> Real {
        doc "Accumulated operational time of a component.";
        unit hour;
    }

    value def MTBFValue :> Real {
        doc "Mean Time Between Failures expressed in hours.";
        unit hour;
    }

    value def ReliabilityValue :> Real {
        doc "Probability of failure-free operation over a specified period, range 0.0 to 1.0.";
    }

    value def FailureRate :> Real {
        doc "Number of failures per operational hour.";
    }

    value def MaintenanceDuration :> Real {
        doc "Duration of a maintenance activity.";
        unit hour;
    }

    value def ThresholdValue :> Real {
        doc "Configurable threshold for reliability-based decisions.";
    }

    // ===== Item Definitions =====

    item def FailureEvent {
        attribute componentId : String;
        attribute timestamp : String;
        attribute failureType : String;
        attribute operationalHoursAtFailure : OperationalHours;
        attribute severity : Integer;
        attribute description : String;
    }

    item def OperationalData {
        attribute componentId : String;
        attribute currentOperationalHours : OperationalHours;
        attribute isFunctional : Boolean;
        attribute isActive : Boolean;
        attribute componentRole : String;
    }

    item def ReliabilityReport {
        attribute systemReliability : ReliabilityValue;
        attribute systemMTBF : MTBFValue;
        attribute timestamp : String;
        attribute totalFailures : Integer;
        attribute totalOperationalHours : OperationalHours;
        attribute componentWithLowestReliability : String;
    }

    item def MaintenanceCommand {
        attribute componentId : String;
        attribute maintenanceType : String;
        attribute priority : Integer;
        attribute scheduledTime : String;
        attribute estimatedDuration : MaintenanceDuration;
    }

    item def MaintenanceActivity {
        attribute componentId : String;
        attribute activityType : String;
        attribute timestamp : String;
        attribute duration : MaintenanceDuration;
        attribute technicianId : String;
        attribute outcome : String;
    }

    item def LogEntry {
        attribute entryId : String;
        attribute entryType : String;
        attribute timestamp : String;
        attribute description : String;
        attribute componentId : String;
        attribute severity : Integer;
    }

    // ===== Port Definitions =====

    port def FailureReportingPort {
        out item failureEvent : FailureEvent;
        out item operationalData : OperationalData;
    }

    port def DataIngestionPort {
        in item failureEvent : FailureEvent;
        in item operationalData : OperationalData;
    }

    port def ReliabilityOutputPort {
        out item reliabilityReport : ReliabilityReport;
    }

    port def ReliabilityInputPort {
        in item reliabilityReport : ReliabilityReport;
    }

    port def MaintenanceCommandOutputPort {
        out item maintenanceCommand : MaintenanceCommand;
    }

    port def MaintenanceCommandInputPort {
        in item maintenanceCommand : MaintenanceCommand;
    }

    port def MaintenanceActivityOutputPort {
        out item maintenanceActivity : MaintenanceActivity;
    }

    port def MaintenanceActivityInputPort {
        in item maintenanceActivity : MaintenanceActivity;
    }

    port def LoggingInputPort {
        in item logEntry : LogEntry;
    }

    port def LoggingOutputPort {
        out item logEntry : LogEntry;
    }

    // ===== Critical Component =====

    part def CriticalComponent {
        doc "Represents a critical piece of equipment being monitored for reliability.";

        attribute componentId : String;
        attribute componentRole : String;
        attribute expectedMTBF : MTBFValue;
        attribute reliabilityThreshold : ReliabilityValue := 0.95;

        port failureReporting : FailureReportingPort;
        port maintenanceCommandIn : MaintenanceCommandInputPort;
        port maintenanceActivityOut : MaintenanceActivityOutputPort;
        port loggingOut : LoggingOutputPort;

        attribute currentOperationalHours : OperationalHours := 0;
        attribute failureCount : Integer := 0;
        attribute isFunctional : Boolean := true;
        attribute isActive : Boolean := true;
        attribute lastMaintenanceHours : OperationalHours := 0;
        attribute currentReliability : ReliabilityValue := 1.0;

        action reportOperationalData {
            doc "Periodically sends current operational hours and status to the reliability monitor.";
            out item data : OperationalData;
        }

        action reportFailure {
            doc "Generates and sends a failure event when a failure is detected.";
            out item event : FailureEvent;
        }

        action performMaintenance {
            doc "Executes maintenance based on a received command.";
            in item command : MaintenanceCommand;
            out item activity : MaintenanceActivity;
        }

        action updateOperationalHours {
            doc "Increments the accumulated operational hours.";
            in item deltaHours : OperationalHours;
        }

        action calculateComponentReliability {
            doc "Calculates component reliability using R(t) = exp(-t / MTBF).";
            out item reliability : ReliabilityValue;
        }

        action generateLogEntry {
            doc "Creates a log entry for a significant component event.";
            out item entry : LogEntry;
        }

        state componentLifecycle {
            state Operational {
                doc "Component is functioning normally.";
            }
            state UnderMaintenance {
                doc "Component is undergoing preventive or corrective maintenance.";
            }
            state Failed {
                doc "Component has experienced a failure.";
            }
            state Standby {
                doc "Component is available but not active (e.g., backup).";
            }

            transition Operational -> Failed
                accept FailureEvent;

            transition Failed -> UnderMaintenance
                accept MaintenanceCommand;

            transition UnderMaintenance -> Operational
                accept MaintenanceActivity;

            transition Standby -> Operational
                accept MaintenanceCommand;

            transition Operational -> Standby
                [isActive == false];
        }
    }

    // ===== Reliability Monitor =====

    part def ReliabilityMonitor {
        doc "Central monitoring unit that collects data from all critical components and calculates system reliability and MTBF.";

        attribute monitorId : String;
        attribute calculationIntervalHours : OperationalHours := 1;

        port dataIngestion : DataIngestionPort;
        port reliabilityOutput : ReliabilityOutputPort;
        port loggingOut : LoggingOutputPort;

        attribute totalFailures : Integer := 0;
        attribute totalOperationalHours : OperationalHours := 0;
        attribute currentSystemReliability : ReliabilityValue := 1.0;
        attribute currentSystemMTBF : MTBFValue := 0;
        attribute componentCount : Integer := 0;
        attribute dataCollected : Boolean := false;
        attribute calculationComplete : Boolean := false;

        action ingestData {
            doc "Receives failure events and operational data from critical components.";
            in item failureEvent : FailureEvent;
            in item operationalData : OperationalData;
        }

        action calculateMTBF {
            doc "Calculates system MTBF as total operational hours divided by total failures.";
            out item mtbf : MTBFValue;
        }

        action calculateReliability {
            doc "Calculates system reliability using the exponential failure model.";
            out item reliability : ReliabilityValue;
        }

        action generateReliabilityReport {
            doc "Compiles reliability metrics into a report for the maintenance controller.";
            out item report : ReliabilityReport;
        }

        action logMonitoringEvent {
            doc "Generates a log entry for monitoring activities.";
            out item entry : LogEntry;
        }

        state monitorOperation {
            state Idle {
                doc "Waiting for new data from components.";
            }
            state Collecting {
                doc "Actively collecting operational data and failure events.";
            }
            state Calculating {
                doc "Computing MTBF and reliability metrics.";
            }
            state Reporting {
                doc "Sending reliability report to maintenance controller.";
            }

            transition Idle -> Collecting
                accept OperationalData;

            transition Collecting -> Calculating
                [dataCollected == true];

            transition Calculating -> Reporting
                [calculationComplete == true];

            transition Reporting -> Idle
                accept ReliabilityReport;
        }
    }

    // ===== Maintenance Controller =====

    part def MaintenanceController {
        doc "Decision-making unit that evaluates reliability reports and schedules preventive maintenance.";

        attribute controllerId : String;
        attribute reliabilityThreshold : ReliabilityValue := 0.85;
        attribute degradedThreshold : ReliabilityValue := 0.70;
        attribute criticalThreshold : ReliabilityValue := 0.50;
        attribute componentFailureWindow : OperationalHours := 100;

        port reliabilityInput : ReliabilityInputPort;
        port maintenanceCommandOutput : MaintenanceCommandOutputPort;
        port maintenanceActivityIn : MaintenanceActivityInputPort;
        port loggingOut : LoggingOutputPort;

        attribute pendingMaintenanceCount : Integer := 0;
        attribute maintenanceScheduled : Boolean := false;
        attribute reliabilityBelowThreshold : Boolean := false;
        attribute componentNearingFailure : Boolean := false;

        action evaluateReliability {
            doc "Compares the received reliability report against configured thresholds.";
            in item report : ReliabilityReport;
        }

        action checkComponentHealth {
            doc "Determines if any component is nearing its expected failure point.";
            in item operationalData : OperationalData;
        }

        action scheduleMaintenance {
            doc "Creates a maintenance command for a specific component.";
            in item componentId : String;
            in item maintenanceType : String;
            out item command : MaintenanceCommand;
        }

        action dispatchMaintenanceCommand {
            doc "Sends the maintenance command to the target component.";
            in item command : MaintenanceCommand;
        }

        action confirmMaintenanceComplete {
            doc "Processes maintenance activity confirmation.";
            in item activity : MaintenanceActivity;
        }

        action logControllerEvent {
            doc "Generates a log entry for controller decisions.";
            out item entry : LogEntry;
        }

        state controllerDecision {
            state Monitoring {
                doc "Waiting for reliability reports.";
            }
            state Evaluating {
                doc "Analyzing reliability against thresholds.";
            }
            state Scheduling {
                doc "Creating maintenance commands.";
            }
            state Dispatching {
                doc "Sending commands to components.";
            }
            state Confirming {
                doc "Verifying maintenance completion.";
            }

            transition Monitoring -> Evaluating
                accept ReliabilityReport;

            transition Evaluating -> Scheduling
                [reliabilityBelowThreshold == true or componentNearingFailure == true];

            transition Evaluating -> Monitoring
                [reliabilityBelowThreshold == false and componentNearingFailure == false];

            transition Scheduling -> Dispatching
                accept MaintenanceCommand;

            transition Dispatching -> Confirming
                accept MaintenanceCommand;

            transition Confirming -> Monitoring
                accept MaintenanceActivity;
        }
    }

    // ===== Data Recorder =====

    part def DataRecorder {
        doc "Logs all significant events including failures, maintenance activities, and reliability reports.";

        attribute recorderId : String;
        attribute maxEntries : Integer := 100000;

        port loggingInput : LoggingInputPort;

        attribute entryCount : Integer := 0;
        attribute storageUsed : Real := 0;
        attribute entryLogged : Boolean := false;
        attribute archiveComplete : Boolean := false;

        action logEvent {
            doc "Records a generic log entry.";
            in item entry : LogEntry;
        }

        action logFailure {
            doc "Creates and stores a log entry for a component failure.";
            in item failureEvent : FailureEvent;
        }

        action logMaintenance {
            doc "Creates and stores a log entry for a maintenance activity.";
            in item activity : MaintenanceActivity;
        }

        action retrieveHistory {
            doc "Queries historical log entries for analysis.";
            in item query : String;
            out item entries : LogEntry;
        }

        action archiveLogs {
            doc "Archives old log entries to long-term storage.";
        }

        state recorderOperation {
            state Listening {
                doc "Waiting for incoming log entries.";
            }
            state Recording {
                doc "Actively writing a log entry to storage.";
            }
            state Archiving {
                doc "Moving old entries to archive.";
            }

            transition Listening -> Recording
                accept LogEntry;

            transition Recording -> Listening
                [entryLogged == true];

            transition Recording -> Archiving
                [entryCount > maxEntries];

            transition Archiving -> Listening
                [archiveComplete == true];
        }
    }

    // ===== System-Level State Machine =====

    state def ReliabilitySystemStates {
        doc "Defines the operational states of the entire reliability management system.";

        state NormalOperation {
            doc "System is continuously monitoring the health of all critical components.";
        }

        state ScheduledMaintenance {
            doc "System is performing preventive service on one or more components.";
        }

        state DegradedOperation {
            doc "System operates with reduced capability; backup component may be activated.";
        }

        state CriticalFailure {
            doc "Catastrophic failure detected; emergency shutdown initiated.";
        }

        transition NormalOperation -> ScheduledMaintenance
            accept MaintenanceCommand
            [systemReliability < reliabilityThreshold] {
                doc "Reliability drops below threshold; preventive maintenance scheduled.";
            }

        transition ScheduledMaintenance -> NormalOperation
            accept MaintenanceActivity {
                doc "Maintenance completed; return to normal monitoring.";
            }

        transition NormalOperation -> DegradedOperation
            [systemReliability < degradedThreshold] {
                doc "Unexpected reliability degradation; activate backup if available.";
            }

        transition DegradedOperation -> NormalOperation
            [backupActivated and systemStable] {
                doc "Backup component activated and system stabilized.";
            }

        transition DegradedOperation -> ScheduledMaintenance
            accept MaintenanceCommand {
                doc "Maintenance scheduled while in degraded mode.";
            }

        transition DegradedOperation -> CriticalFailure
            [systemReliability < criticalThreshold] {
                doc "Catastrophic problem detected from degraded state.";
            }

        transition NormalOperation -> CriticalFailure
            [systemReliability < criticalThreshold] {
                doc "Catastrophic failure detected during normal operation.";
            }

        transition CriticalFailure {
            doc "Terminal state: emergency shutdown completed.";
        }
    }

    // ===== Overall System =====

    part reliabilityManagementSystem {
        doc "Reliability Management System for monitoring critical equipment and proactively scheduling maintenance to prevent failures.";

        // --- Critical Components ---
        part primaryComponent : CriticalComponent {
            attribute componentId = "COMP-001";
            attribute componentRole = "Primary";
            attribute expectedMTBF = 2000;
        }

        part secondaryComponent : CriticalComponent {
            attribute componentId = "COMP-002";
            attribute componentRole = "Secondary";
            attribute expectedMTBF = 1800;
        }

        part backupComponent : CriticalComponent {
            attribute componentId = "COMP-003";
            attribute componentRole = "Backup";
            attribute expectedMTBF = 1500;
            attribute isActive = false;
        }

        // --- Core Processing Units ---
        part reliabilityMonitor : ReliabilityMonitor {
            attribute monitorId = "MON-001";
        }

        part maintenanceController : MaintenanceController {
            attribute controllerId = "CTRL-001";
        }

        part dataRecorder : DataRecorder {
            attribute recorderId = "REC-001";
        }

        // --- System-Level Attributes ---
        attribute systemReliability : ReliabilityValue := 1.0;
        attribute systemMTBF : MTBFValue := 0;
        attribute reliabilityThreshold : ReliabilityValue := 0.85;
        attribute degradedThreshold : ReliabilityValue := 0.70;
        attribute criticalThreshold : ReliabilityValue := 0.50;
        attribute backupActivated : Boolean := false;
        attribute systemStable : Boolean := true;
        attribute catastrophicFailure : Boolean := false;

        // --- System State Machine ---
        exhibit state systemStates : ReliabilitySystemStates;

        // --- Connections: Components to Monitor ---
        connection primaryToMonitor
            connect primaryComponent.failureReporting to reliabilityMonitor.dataIngestion;

        connection secondaryToMonitor
            connect secondaryComponent.failureReporting to reliabilityMonitor.dataIngestion;

        connection backupToMonitor
            connect backupComponent.failureReporting to reliabilityMonitor.dataIngestion;

        // --- Connections: Monitor to Controller ---
        connection monitorToController
            connect reliabilityMonitor.reliabilityOutput to maintenanceController.reliabilityInput;

        // --- Connections: Controller to Components ---
        connection controllerToPrimary
            connect maintenanceController.maintenanceCommandOutput to primaryComponent.maintenanceCommandIn;

        connection controllerToSecondary
            connect maintenanceController.maintenanceCommandOutput to secondaryComponent.maintenanceCommandIn;

        connection controllerToBackup
            connect maintenanceController.maintenanceCommandOutput to backupComponent.maintenanceCommandIn;

        // --- Connections: Components to Controller (Activity Confirmation) ---
        connection primaryActivityToController
            connect primaryComponent.maintenanceActivityOut to maintenanceController.maintenanceActivityIn;

        connection secondaryActivityToController
            connect secondaryComponent.maintenanceActivityOut to maintenanceController.maintenanceActivityIn;

        connection backupActivityToController
            connect backupComponent.maintenanceActivityOut to maintenanceController.maintenanceActivityIn;

        // --- Connections: All Units to Data Recorder ---
        connection primaryToRecorder
            connect primaryComponent.loggingOut to dataRecorder.loggingInput;

        connection secondaryToRecorder
            connect secondaryComponent.loggingOut to dataRecorder.loggingInput;

        connection backupToRecorder
            connect backupComponent.loggingOut to dataRecorder.loggingInput;

        connection monitorToRecorder
            connect reliabilityMonitor.loggingOut to dataRecorder.loggingInput;

        connection controllerToRecorder
            connect maintenanceController.loggingOut to dataRecorder.loggingInput;
    }

    // ===== Requirements =====

    requirement def ReliabilityMonitoringRequirement {
        doc "The system shall continuously monitor the reliability of all critical components.";
        subject system : reliabilityManagementSystem;
        objective {
            doc "Ensure high system availability by tracking component health in real time.";
        }
    }

    requirement def MTBFTrackingRequirement {
        doc "The system shall continuously calculate and track the Mean Time Between Failures (MTBF) for each component and for the overall system.";
        subject monitor : ReliabilityMonitor;
        assume {
            doc "Operational data and failure events are received from all critical components.";
        }
        objective {
            doc "Provide accurate MTBF metrics to support maintenance decisions.";
        }
    }

    requirement def PreventiveMaintenanceSchedulingRequirement {
        doc "The system shall automatically schedule preventive maintenance when the calculated system reliability drops below a predefined threshold or when a component nears its expected failure point.";
        subject controller : MaintenanceController;
        objective {
            doc "Minimize unplanned downtime by performing maintenance before failures occur.";
        }
    }

    requirement def DataRecordingRequirement {
        doc "The system shall log every significant event, including all component failures and maintenance activities, to create a complete historical record.";
        subject recorder : DataRecorder;
        objective {
            doc "Enable long-term performance analysis and improvement of maintenance strategies.";
        }
    }

    requirement def StateManagementRequirement {
        doc "The system shall operate through distinct states: Normal Operation, Scheduled Maintenance, Degraded Operation, and Critical Failure, transitioning based on reliability metrics and maintenance events.";
        subject system : reliabilityManagementSystem;
    }

    requirement def BackupActivationRequirement {
        doc "Upon entering Degraded Operation, the system shall activate a backup component to maintain system functionality.";
        subject system : reliabilityManagementSystem;
        objective {
            doc "Preserve operational capability during reliability degradation.";
        }
    }

    requirement def EmergencyShutdownRequirement {
        doc "Upon entering the Critical Failure state, the system shall initiate an emergency shutdown to prevent further damage.";
        subject system : reliabilityManagementSystem;
        objective {
            doc "Protect equipment and personnel from catastrophic consequences.";
        }
    }

    requirement def ComponentFailureReportingRequirement {
        doc "Each critical component shall report any failure that occurs, including the component identifier, timestamp, failure type, and operational hours at failure.";
        subject component : CriticalComponent;
    }

    requirement def OperationalHoursTrackingRequirement {
        doc "Each critical component shall track its own accumulated operational hours and report them to the reliability monitor.";
        subject component : CriticalComponent;
    }

    // ===== Requirement Satisfaction =====

    satisfy ReliabilityMonitoringRequirement by reliabilityManagementSystem;
    satisfy MTBFTrackingRequirement by reliabilityMonitor;
    satisfy PreventiveMaintenanceSchedulingRequirement by maintenanceController;
    satisfy DataRecordingRequirement by dataRecorder;
    satisfy StateManagementRequirement by reliabilityManagementSystem;
    satisfy BackupActivationRequirement by reliabilityManagementSystem;
    satisfy EmergencyShutdownRequirement by reliabilityManagementSystem;
    satisfy ComponentFailureReportingRequirement by primaryComponent;
    satisfy ComponentFailureReportingRequirement by secondaryComponent;
    satisfy ComponentFailureReportingRequirement by backupComponent;
    satisfy OperationalHoursTrackingRequirement by primaryComponent;
    satisfy OperationalHoursTrackingRequirement by secondaryComponent;
    satisfy OperationalHoursTrackingRequirement by backupComponent;
}
