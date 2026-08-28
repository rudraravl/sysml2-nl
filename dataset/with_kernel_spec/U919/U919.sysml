package TimePressureGauge {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def TaskCount :> Integer {
        doc /* Count of tasks. */
    }
    attribute def EffortHours :> Real {
        doc /* Estimated effort in person-hours. */
    }
    attribute def PressureScore :> Real {
        doc /* Quantitative pressure score, 0.0 to 1.0. */
        assert constraint { that >= 0.0 and that <= 1.0 }
    }

    enum def PressureCategory {
        doc /* Intuitive categories for pressure levels. */
        minimal;
        low;
        moderate;
        high;
        critical;
    }

    item def WorkloadStatus {
        attribute totalTasks : TaskCount;
        attribute completedTasks : TaskCount;
        attribute remainingEffort : EffortHours;
    }

    item def TemporalStatus {
        attribute currentTime : TimeValue;
        attribute deadline : TimeValue;
        attribute timeRemaining : TimeValue;
    }

    item def PressureReading {
        attribute score : PressureScore;
        attribute category : PressureCategory;
    }

    item def AlertNotification {
        attribute severity : PressureCategory;
        attribute alertText : String;
    }

    item def DataSnapshot {
        attribute pressure : PressureReading;
        attribute workload : WorkloadStatus;
        attribute temporal : TemporalStatus;
        attribute timestamp : TimeValue;
    }

    calc def ComputePressureScore {
        in remainingEffort : EffortHours;
        in timeRemaining : TimeValue;
        return score : PressureScore =
            if timeRemaining > 0.0 then remainingEffort / (remainingEffort + timeRemaining) else 1.0;
    }

    calc def CategorizePressure {
        in score : PressureScore;
        return category : PressureCategory =
            if score < 0.20 then PressureCategory::minimal
            else if score < 0.40 then PressureCategory::low
            else if score < 0.60 then PressureCategory::moderate
            else if score < 0.80 then PressureCategory::high
            else PressureCategory::critical;
    }

    part def WorkloadMonitor {
        port workloadOut {
            out workload : WorkloadStatus;
        }
        attribute totalTasks : TaskCount;
        attribute completedTasks : TaskCount;
        attribute remainingEffort : EffortHours;

        action def UpdateWorkload {
            in total : TaskCount;
            in completed : TaskCount;
            in effort : EffortHours;
            out status : WorkloadStatus;
        }
        action updateWorkload : UpdateWorkload {
            in total = totalTasks;
            in completed = completedTasks;
            in effort = remainingEffort;
            out status;
        }
        flow of WorkloadStatus
            from updateWorkload.status to workloadOut.workload;
    }

    part def TemporalMonitor {
        port temporalOut {
            out temporal : TemporalStatus;
        }
        attribute deadline : TimeValue;
        attribute currentTime : TimeValue;
        attribute timeRemaining : TimeValue = deadline - currentTime;

        action def UpdateTemporal {
            in current : TimeValue;
            in dl : TimeValue;
            in remaining : TimeValue;
            out status : TemporalStatus;
        }
        action updateTemporal : UpdateTemporal {
            in current = currentTime;
            in dl = deadline;
            in remaining = timeRemaining;
            out status;
        }
        flow of TemporalStatus
            from updateTemporal.status to temporalOut.temporal;
    }

    part def PressureCalculator {
        port workloadIn {
            in workload : WorkloadStatus;
        }
        port temporalIn {
            in temporal : TemporalStatus;
        }
        port pressureOut {
            out pressure : PressureReading;
        }

        action def ComputePressure {
            in workload : WorkloadStatus;
            in temporal : TemporalStatus;
            out reading : PressureReading;
        }
        action computePressure : ComputePressure {
            in workload;
            in temporal;
            out reading;
        }
        calc scoreCalc : ComputePressureScore {
            in remainingEffort = computePressure.workload.remainingEffort;
            in timeRemaining = computePressure.temporal.timeRemaining;
            return score;
        }
        calc categoryCalc : CategorizePressure {
            in score = scoreCalc.score;
            return category;
        }
        flow of WorkloadStatus
            from workloadIn.workload to computePressure.workload;
        flow of TemporalStatus
            from temporalIn.temporal to computePressure.temporal;
        flow of PressureReading
            from computePressure.reading to pressureOut.pressure;
    }

    part def AlertManager {
        port pressureIn {
            in pressure : PressureReading;
        }
        port alertOut {
            out alert : AlertNotification;
        }
        attribute alertThreshold : PressureCategory = PressureCategory::high;

        state machine def AlertingBehavior {
            in pressure : PressureReading;
            in threshold : PressureCategory;

            state Normal;
            state Alerting;

            transition from Normal to Alerting
                if pressure.category == threshold;
            transition from Alerting to Normal
                if pressure.category != threshold;
        }
        exhibit alerting : AlertingBehavior {
            in pressure = pressureIn.pressure;
            in threshold = alertThreshold;
        }

        action def IssueAlert {
            in pressure : PressureReading;
            out alert : AlertNotification;
        }
        action issueAlert : IssueAlert {
            in pressure = pressureIn.pressure;
            out alert;
        }
        flow of AlertNotification
            from issueAlert.alert to alertOut.alert;
    }

    part def PressureDisplay {
        port pressureIn {
            in pressure : PressureReading;
        }
        attribute refreshRate : TimeValue = 1.0 [s];

        action def RefreshDisplay {
            in pressure : PressureReading;
        }
        action refresh : RefreshDisplay {
            in pressure = pressureIn.pressure;
        }
    }

    part def DataRecorder {
        port pressureIn {
            in pressure : PressureReading;
        }
        port workloadIn {
            in workload : WorkloadStatus;
        }
        port temporalIn {
            in temporal : TemporalStatus;
        }
        attribute recordingInterval : TimeValue = 60.0 [s];
        attribute snapshots : DataSnapshot[0..*];

        action def RecordSnapshot {
            in pressure : PressureReading;
            in workload : WorkloadStatus;
            in temporal : TemporalStatus;
            out snapshot : DataSnapshot;
        }
        action record : RecordSnapshot {
            in pressure = pressureIn.pressure;
            in workload = workloadIn.workload;
            in temporal = temporalIn.temporal;
            out snapshot;
        }
        flow of DataSnapshot
            from record.snapshot to snapshots;
    }

    part def TimePressureGaugeSystem {
        port alertOutputPort {
            out alert : AlertNotification;
        }
        port displayOutputPort {
            out pressure : PressureReading;
        }

        part workloadMonitor : WorkloadMonitor {
            port workloadOut {
                out workload : WorkloadStatus;
            }
        }
        part temporalMonitor : TemporalMonitor {
            port temporalOut {
                out temporal : TemporalStatus;
            }
        }
        part pressureCalculator : PressureCalculator {
            port workloadIn {
                in workload : WorkloadStatus;
            }
            port temporalIn {
                in temporal : TemporalStatus;
            }
            port pressureOut {
                out pressure : PressureReading;
            }
        }
        part alertManager : AlertManager {
            port pressureIn {
                in pressure : PressureReading;
            }
            port alertOut {
                out alert : AlertNotification;
            }
        }
        part pressureDisplay : PressureDisplay {
            port pressureIn {
                in pressure : PressureReading;
            }
        }
        part dataRecorder : DataRecorder {
            port pressureIn {
                in pressure : PressureReading;
            }
            port workloadIn {
                in workload : WorkloadStatus;
            }
            port temporalIn {
                in temporal : TemporalStatus;
            }
        }

        interface workloadInterface
            connect workloadMonitor.workloadOut to pressureCalculator.workloadIn {
            flow of WorkloadStatus
                from workloadMonitor.workloadOut.workload
                to pressureCalculator.workloadIn.workload;
        }
        interface temporalInterface
            connect temporalMonitor.temporalOut to pressureCalculator.temporalIn {
            flow of TemporalStatus
                from temporalMonitor.temporalOut.temporal
                to pressureCalculator.temporalIn.temporal;
        }
        interface pressureToAlert
            connect pressureCalculator.pressureOut to alertManager.pressureIn {
            flow of PressureReading
                from pressureCalculator.pressureOut.pressure
                to alertManager.pressureIn.pressure;
        }
        interface pressureToDisplay
            connect pressureCalculator.pressureOut to pressureDisplay.pressureIn {
            flow of PressureReading
                from pressureCalculator.pressureOut.pressure
                to pressureDisplay.pressureIn.pressure;
        }
        interface pressureToRecorder
            connect pressureCalculator.pressureOut to dataRecorder.pressureIn {
            flow of PressureReading
                from pressureCalculator.pressureOut.pressure
                to dataRecorder.pressureIn.pressure;
        }
        interface workloadToRecorder
            connect workloadMonitor.workloadOut to dataRecorder.workloadIn {
            flow of WorkloadStatus
                from workloadMonitor.workloadOut.workload
                to dataRecorder.workloadIn.workload;
        }
        interface temporalToRecorder
            connect temporalMonitor.temporalOut to dataRecorder.temporalIn {
            flow of TemporalStatus
                from temporalMonitor.temporalOut.temporal
                to dataRecorder.temporalIn.temporal;
        }
        interface alertOutput
            connect alertManager.alertOut to alertOutputPort {
            flow of AlertNotification
                from alertManager.alertOut.alert
                to alertOutputPort.alert;
        }
        interface displayOutput
            connect pressureCalculator.pressureOut to displayOutputPort {
            flow of PressureReading
                from pressureCalculator.pressureOut.pressure
                to displayOutputPort.pressure;
        }
    }

    requirement def PressureMeasurementRequirement {
        doc /* The system shall compute a pressure score from workload and temporal data. */
        subject timePressureGauge : TimePressureGaugeSystem;
        objective {
            timePressureGauge.pressureCalculator.pressureOut.pressure.score >= 0.0 and
            timePressureGauge.pressureCalculator.pressureOut.pressure.score <= 1.0
        }
    }

    requirement def AlertThresholdRequirement {
        doc /* The system shall issue alerts when pressure reaches high or critical. */
        subject alertManager : AlertManager;
        objective {
            alertManager.alertOut.alert.severity == alertManager.alertThreshold
        }
    }

    requirement def DisplayRefreshRequirement {
        doc /* The display shall refresh at a regular rate. */
        subject display : PressureDisplay;
        objective {
            display.refreshRate <= 5.0 [s]
        }
    }

    requirement def DataRecordingRequirement {
        doc /* The recorder shall periodically save snapshots of system state. */
        subject recorder : DataRecorder;
        objective {
            recorder.recordingInterval <= 300.0 [s] and
            recorder.snapshots->size() >= 1
        }
    }

    requirement pressureMeasurementReq : PressureMeasurementRequirement {
        subject timePressureGauge : TimePressureGaugeSystem;
    }
    requirement alertThresholdReq : AlertThresholdRequirement {
        subject alertManager : AlertManager;
    }
    requirement displayRefreshReq : DisplayRefreshRequirement {
        subject display : PressureDisplay;
    }
    requirement dataRecordingReq : DataRecordingRequirement {
        subject recorder : DataRecorder;
    }

    part timePressureGauge : TimePressureGaugeSystem {
        satisfy pressureMeasurementReq;
        satisfy alertThresholdReq;
        satisfy displayRefreshReq;
        satisfy dataRecordingReq;
    }
}
