package TimePressureGauge {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value type DurationValue :> Real {
        unit 'h';
    }
    value type EffortValue :> Real {
        unit 'h';
    }
    value type PressureScoreValue :> Real {
        unit '1';
    }
    value type TaskCountValue :> Integer;
    value type TimestampValue :> Real {
        unit 's';
    }
    value type RefreshRateValue :> Real {
        unit 'Hz';
    }

    // ---- Enumerations ----
    enum PressureLevel { minimal, low, moderate, high, critical }

    // ---- Item definitions ----
    item def WorkloadStatus {
        attribute totalTasks : TaskCountValue;
        attribute completedTasks : TaskCountValue;
        attribute remainingEffort : EffortValue;
    }

    item def TemporalStatus {
        attribute currentTime : TimestampValue;
        attribute deadline : TimestampValue;
        attribute timeRemaining : DurationValue;
    }

    item def PressureReport {
        attribute score : PressureScoreValue;
        attribute level : PressureLevel;
        attribute timestamp : TimestampValue;
    }

    item def AlertNotification {
        attribute level : PressureLevel;
        attribute message : String;
        attribute timestamp : TimestampValue;
    }

    item def DataSnapshot {
        attribute timestamp : TimestampValue;
        attribute pressure : PressureReport;
        attribute workload : WorkloadStatus;
        attribute temporal : TemporalStatus;
    }

    // ---- Port definitions ----
    port def WorkloadOut {
        out workload : WorkloadStatus;
    }
    port def TemporalOut {
        out temporal : TemporalStatus;
    }
    port def PressureOut {
        out pressure : PressureReport;
    }
    port def AlertOut {
        out alert : AlertNotification;
    }
    port def DisplayIn {
        in pressure : PressureReport;
    }
    port def RecorderIn {
        in snapshot : DataSnapshot;
    }

    // ---- Requirements ----
    requirement def MonitorWorkloadRequirement {
        subject gauge : TimePressureGauge;
        objective {
            The Workload Monitor shall track total tasks, completed tasks,
            and remaining effort in real time.
        }
    }

    requirement def MonitorTimeRequirement {
        subject gauge : TimePressureGauge;
        objective {
            The Temporal Monitor shall compute the time remaining until
            the project deadline.
        }
    }

    requirement def ComputePressureRequirement {
        subject gauge : TimePressureGauge;
        objective {
            The Pressure Calculator shall compute a pressure score and
            categorize it as minimal, low, moderate, high, or critical.
        }
    }

    requirement def IssueAlertsRequirement {
        subject gauge : TimePressureGauge;
        objective {
            The Alert Manager shall issue alerts when the pressure level
            reaches high or critical.
        }
    }

    requirement def DisplayPressureRequirement {
        subject gauge : TimePressureGauge;
        objective {
            The Pressure Display shall refresh the pressure visualization
            at a regular rate.
        }
    }

    requirement def RecordDataRequirement {
        subject gauge : TimePressureGauge;
        objective {
            The Data Recorder shall periodically save snapshots of pressure,
            workload, and temporal status.
        }
    }

    // ---- Workload Monitor ----
    part def WorkloadMonitor {
        port workloadOut : WorkloadOut;
        attribute totalTasks : TaskCountValue;
        attribute completedTasks : TaskCountValue;
        attribute remainingEffort : EffortValue;
        attribute refreshRate : RefreshRateValue = 0.2;

        action def UpdateWorkload {
            in newTotal : TaskCountValue;
            in newCompleted : TaskCountValue;
            in newEffort : EffortValue;
            out status : WorkloadStatus;
        }

        action updateWorkload : UpdateWorkload {
            // Computes remaining effort and emits status
        }

        state def WorkloadMonitorBehavior {
            entry;
            state Idle;
            state Tracking {
                entry { send WorkloadStatus(totalTasks, completedTasks, remainingEffort) to workloadOut; }
                do { updateWorkload; }
            }
            transition Idle to Tracking when true;
            transition Tracking to Tracking when true;
        }

        exhibit WorkloadMonitorBehavior;
    }

    // ---- Temporal Monitor ----
    part def TemporalMonitor {
        port temporalOut : TemporalOut;
        attribute currentTime : TimestampValue;
        attribute deadline : TimestampValue;
        attribute timeRemaining : DurationValue;
        attribute refreshRate : RefreshRateValue = 1.0;

        action def UpdateTemporal {
            in now : TimestampValue;
            out status : TemporalStatus;
        }

        action updateTemporal : UpdateTemporal {
            // Computes timeRemaining = deadline - currentTime
        }

        state def TemporalMonitorBehavior {
            entry;
            state Idle;
            state Tracking {
                entry { send TemporalStatus(currentTime, deadline, timeRemaining) to temporalOut; }
                do { updateTemporal; }
            }
            transition Idle to Tracking when true;
            transition Tracking to Tracking when true;
        }

        exhibit TemporalMonitorBehavior;
    }

    // ---- Pressure Calculator ----
    part def PressureCalculator {
        in port workloadIn : WorkloadOut;
        in port temporalIn : TemporalOut;
        port pressureOut : PressureOut;
        attribute score : PressureScoreValue;
        attribute level : PressureLevel;
        attribute lastWorkload : WorkloadStatus;
        attribute lastTemporal : TemporalStatus;

        action def ComputePressure {
            in workload : WorkloadStatus;
            in temporal : TemporalStatus;
            out report : PressureReport;
        }

        action computePressure : ComputePressure {
            // score = remainingEffort / max(timeRemaining, epsilon)
            // level derived from score thresholds
        }

        state def PressureCalculatorBehavior {
            entry;
            state Idle;
            state Computing {
                entry { send PressureReport(score, level, lastTemporal.currentTime) to pressureOut; }
                do { computePressure; }
            }
            transition Idle to Computing when workloadIn.workload->notEmpty();
            transition Computing to Computing when workloadIn.workload->notEmpty() or temporalIn.temporal->notEmpty();
        }

        exhibit PressureCalculatorBehavior;
    }

    // ---- Alert Manager ----
    part def AlertManager {
        in port pressureIn : PressureOut;
        port alertOut : AlertOut;
        attribute threshold : PressureLevel = high;
        attribute lastReport : PressureReport;

        action def EvaluatePressure {
            in report : PressureReport;
            out alert : AlertNotification;
        }

        action evaluatePressure : EvaluatePressure {
            // If report.level >= threshold, generate AlertNotification
        }

        state def AlertManagerBehavior {
            entry;
            state Idle;
            state Watching {
                do { evaluatePressure; }
            }
            state Alerting {
                entry { send AlertNotification(lastReport.level, "Pressure threshold exceeded", lastReport.timestamp) to alertOut; }
            }
            transition Idle to Watching when pressureIn.pressure->notEmpty();
            transition Watching to Alerting when lastReport.level == high or lastReport.level == critical;
            transition Alerting to Watching when lastReport.level == moderate or lastReport.level == low or lastReport.level == minimal;
        }

        exhibit AlertManagerBehavior;
    }

    // ---- Pressure Display ----
    part def PressureDisplay {
        in port displayIn : DisplayIn;
        attribute displayedScore : PressureScoreValue;
        attribute displayedLevel : PressureLevel;
        attribute refreshRate : RefreshRateValue = 0.5;

        action def RefreshDisplay {
            in report : PressureReport;
        }

        action refreshDisplay : RefreshDisplay {
            // Updates displayedScore and displayedLevel
        }

        state def DisplayBehavior {
            entry;
            state Off;
            state On {
                do { refreshDisplay; }
            }
            transition Off to On when displayIn.pressure->notEmpty();
        }

        exhibit DisplayBehavior;
    }

    // ---- Data Recorder ----
    part def DataRecorder {
        in port recorderIn : RecorderIn;
        attribute snapshots : DataSnapshot[0..*];
        attribute recordInterval : DurationValue = 60.0;

        action def RecordSnapshot {
            in snapshot : DataSnapshot;
        }

        action recordSnapshot : RecordSnapshot {
            // Appends snapshot to snapshots
        }

        state def RecorderBehavior {
            entry;
            state Idle;
            state Recording {
                do { recordSnapshot; }
            }
            transition Idle to Recording when recorderIn.snapshot->notEmpty();
            transition Recording to Recording when recorderIn.snapshot->notEmpty();
        }

        exhibit RecorderBehavior;
    }

    // ---- Top-level Time Pressure Gauge ----
    part def TimePressureGauge {
        attribute systemName : String = "TimePressureGauge";
        attribute deadline : TimestampValue;

        part workloadMonitor : WorkloadMonitor {
            attribute deadline redefines TimePressureGauge::deadline;
        }
        part temporalMonitor : TemporalMonitor {
            attribute deadline redefines TimePressureGauge::deadline;
        }
        part pressureCalculator : PressureCalculator;
        part alertManager : AlertManager;
        part pressureDisplay : PressureDisplay;
        part dataRecorder : DataRecorder;

        // Internal snapshot generator
        part snapshotGenerator {
            attribute interval : DurationValue = 60.0;
            port snapshotOut : RecorderIn;
        }

        satisfy MonitorWorkloadRequirement by workloadMonitor;
        satisfy MonitorTimeRequirement by temporalMonitor;
        satisfy ComputePressureRequirement by pressureCalculator;
        satisfy IssueAlertsRequirement by alertManager;
        satisfy DisplayPressureRequirement by pressureDisplay;
        satisfy RecordDataRequirement by dataRecorder;

        connection def WorkloadFlow {
            end src : WorkloadOut;
            end dst : WorkloadOut;
        }
        connection def TemporalFlow {
            end src : TemporalOut;
            end dst : TemporalOut;
        }
        connection def PressureFlow {
            end src : PressureOut;
            end dst : PressureOut;
        }
        connection def AlertFlow {
            end src : AlertOut;
            end dst : AlertOut;
        }
        connection def SnapshotFlow {
            end src : RecorderIn;
            end dst : RecorderIn;
        }

        connection workloadToCalculator : WorkloadFlow
            connect workloadMonitor.workloadOut to pressureCalculator.workloadIn;
        connection temporalToCalculator : TemporalFlow
            connect temporalMonitor.temporalOut to pressureCalculator.temporalIn;
        connection pressureToAlert : PressureFlow
            connect pressureCalculator.pressureOut to alertManager.pressureIn;
        connection pressureToDisplay : PressureFlow
            connect pressureCalculator.pressureOut to pressureDisplay.displayIn;
        connection pressureToSnapshot : PressureFlow
            connect pressureCalculator.pressureOut to snapshotGenerator.snapshotOut;
        connection snapshotToRecorder : SnapshotFlow
            connect snapshotGenerator.snapshotOut to dataRecorder.recorderIn;
        connection alertOutExternal : AlertFlow
            connect alertManager.alertOut to self.alertOutExternal;
    }

}
