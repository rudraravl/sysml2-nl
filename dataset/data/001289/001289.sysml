package TimePressureGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WorkloadMetrics {
        attribute totalTasks : Integer;
        attribute completedTasks : Integer;
        attribute remainingTasks : Integer;
        attribute estimatedEffort :> ISQ::time;
        attribute actualEffort :> ISQ::time;
    }
    
    attribute def TemporalConstraints {
        attribute deadline :> ISQ::time;
        attribute currentTime :> ISQ::time;
        attribute timeRemaining :> ISQ::time;
        attribute timeElapsed :> ISQ::time;
    }
    
    attribute def PressureMetrics {
        attribute workloadPressure : Real;
        attribute temporalPressure : Real;
        attribute combinedPressure : Real;
        attribute pressureRate : Real;
    }
    
    enum def PressureLevel {
        enum minimal;
        enum low;
        enum moderate;
        enum high;
        enum critical;
    }
    
    port def WorkloadInputPort {
        in attribute taskCount : Integer;
        in attribute completionRate : Real;
        in attribute effortEstimate :> ISQ::time;
    }
    
    port def TimeInputPort {
        in attribute currentTimestamp :> ISQ::time;
        in attribute deadlineTimestamp :> ISQ::time;
    }
    
    port def PressureOutputPort {
        out attribute pressureValue : Real;
        out attribute pressureCategory : PressureLevel;
        out attribute trend : Real;
    }
    
    port def AlertOutputPort {
        out attribute alertActive : Boolean;
        out attribute alertLevel : PressureLevel;
        out attribute alertMessage : String;
    }
    
    part def WorkloadMonitor {
        attribute metrics : WorkloadMetrics;
        port workloadIn : WorkloadInputPort;
        
        action def UpdateWorkload {
            in taskTotal : Integer;
            in tasksDone : Integer;
            in effort :> ISQ::time;
            out updatedMetrics : WorkloadMetrics;
            
            first start;
            then action calculateRemaining {
                in total = taskTotal;
                in completed = tasksDone;
                out remaining : Integer = total - completed;
            }
            then action updateMetrics {
                out result : WorkloadMetrics;
            }
            then assign updatedMetrics := updateMetrics.result;
            then done;
        }
    }
    
    part def TemporalMonitor {
        attribute constraints : TemporalConstraints;
        port timeIn : TimeInputPort;
        
        action def UpdateTimeConstraints {
            in current :> ISQ::time;
            in deadline :> ISQ::time;
            out updatedConstraints : TemporalConstraints;
            
            first start;
            then action calculateTimeRemaining {
                in currentTime = current;
                in deadlineTime = deadline;
                out remaining :> ISQ::time = deadlineTime - currentTime;
            }
            then action updateConstraints {
                out result : TemporalConstraints;
            }
            then assign updatedConstraints := updateConstraints.result;
            then done;
        }
    }
    
    part def PressureCalculator {
        attribute thresholds : PressureThresholds;
        
        attribute def PressureThresholds {
            attribute minimalThreshold : Real = 0.2;
            attribute lowThreshold : Real = 0.4;
            attribute moderateThreshold : Real = 0.6;
            attribute highThreshold : Real = 0.8;
            attribute criticalThreshold : Real = 1.0;
        }
        
        action def ComputePressure {
            in workload : WorkloadMetrics;
            in temporal : TemporalConstraints;
            out metrics : PressureMetrics;
            out level : PressureLevel;
            
            first start;
            then action calculateWorkloadPressure {
                in remaining = workload.remainingTasks;
                in total = workload.totalTasks;
                out workPressure : Real = remaining / total;
            }
            then action calculateTemporalPressure {
                in timeLeft = temporal.timeRemaining;
                in effort = workload.estimatedEffort;
                out timePressure : Real = effort / timeLeft;
            }
            then action combinePressures {
                in workP = calculateWorkloadPressure.workPressure;
                in timeP = calculateTemporalPressure.timePressure;
                out combined : Real = (workP + timeP) / 2.0;
            }
            then action categorizePressure {
                in pressureValue = combinePressures.combined;
                in limits = thresholds;
                out category : PressureLevel;
            }
            then action buildMetrics {
                out result : PressureMetrics;
            }
            then assign metrics := buildMetrics.result;
            then assign level := categorizePressure.category;
            then done;
        }
    }
    
    part def AlertManager {
        attribute alertThreshold : PressureLevel = PressureLevel::high;
        
        state def AlertStates {
            entry; then inactive;
            
            state inactive {
                entry action deactivateAlert;
            }
            transition inactive_to_monitoring
                first inactive
                accept PressureUpdate
                then monitoring;
            
            state monitoring {
                entry action evaluatePressure;
            }
            transition monitoring_to_active
                first monitoring
                if pressureExceedsThreshold
                then active;
            transition monitoring_to_inactive
                first monitoring
                if pressureBelowThreshold
                then inactive;
            
            state active {
                entry action activateAlert;
                do action broadcastAlert;
            }
            transition active_to_monitoring
                first active
                then monitoring;
        }
        
        action def EvaluateAlert {
            in currentPressure : PressureLevel;
            in threshold : PressureLevel;
            out shouldAlert : Boolean;
            out message : String;
            
            first start;
            then decide;
                if currentPressure == PressureLevel::critical then criticalAlert;
                if currentPressure == PressureLevel::high then highAlert;
                else noAlert;
            
            action criticalAlert {
                out alert : Boolean = true;
                out msg : String = "CRITICAL: Time pressure has reached critical levels";
            }
            then assign shouldAlert := criticalAlert.alert;
            then assign message := criticalAlert.msg;
            then done;
            
            action highAlert {
                out alert : Boolean = true;
                out msg : String = "WARNING: Time pressure is high";
            }
            then assign shouldAlert := highAlert.alert;
            then assign message := highAlert.msg;
            then done;
            
            action noAlert {
                out alert : Boolean = false;
                out msg : String = "Normal operation";
            }
            then assign shouldAlert := noAlert.alert;
            then assign message := noAlert.msg;
            then done;
        }
    }
    
    part def PressureDisplay {
        attribute refreshRate :> ISQ::frequency = 1.0 [SI::Hz];
        port displayIn : PressureOutputPort;
        
        action def UpdateDisplay {
            in pressure : Real;
            in category : PressureLevel;
            in updateRate :> ISQ::frequency;
            
            first start;
            then merge continuousUpdate;
            
            action continuousUpdate;
            then action formatDisplay {
                in pressureVal = pressure;
                in level = category;
                out displayText : String;
            }
            then action renderDisplay {
                in text = formatDisplay.displayText;
            }
            then continuousUpdate;
        }
    }
    
    part def DataRecorder {
        attribute recordingInterval :> ISQ::time = 60.0 [SI::s];
        attribute maxRecords : Integer = 1000;
        
        attribute def PressureRecord {
            attribute timestamp :> ISQ::time;
            attribute pressureValue : Real;
            attribute pressureLevel : PressureLevel;
            attribute workloadSnapshot : WorkloadMetrics;
            attribute temporalSnapshot : TemporalConstraints;
        }
        
        action def RecordPressureData {
            in currentMetrics : PressureMetrics;
            in currentLevel : PressureLevel;
            in workload : WorkloadMetrics;
            in temporal : TemporalConstraints;
            in interval :> ISQ::time;
            out records : PressureRecord[*] := ();
            
            first start;
            then merge recordingLoop;
            
            action recordingLoop;
            then action createRecord {
                in metrics = currentMetrics;
                in level = currentLevel;
                out newRecord : PressureRecord;
            }
            then action storeRecord {
                in record = createRecord.newRecord;
            }
            then assign records := records->including(storeRecord.record);
            then recordingLoop;
        }
    }
    
    part def TimePressureGauge {
        attribute operationalMode : String = "continuous";
        attribute measurementCycle :> ISQ::time = 5.0 [SI::s];
        
        part workloadMonitor : WorkloadMonitor;
        part temporalMonitor : TemporalMonitor;
        part pressureCalculator : PressureCalculator;
        part alertManager : AlertManager;
        part display : PressureDisplay;
        part recorder : DataRecorder;
        
        port workloadInput : WorkloadInputPort;
        port timeInput : TimeInputPort;
        port pressureOutput : PressureOutputPort;
        port alertOutput : AlertOutputPort;
        
        connection workloadConnection connect workloadInput to workloadMonitor.workloadIn;
        connection timeConnection connect timeInput to temporalMonitor.timeIn;
        
        action def MonitorTimePressure {
            in cycleInterval :> ISQ::time;
            out currentPressure : PressureMetrics;
            out currentLevel : PressureLevel;
            out alertStatus : Boolean;
            
            first start;
            then merge monitoringCycle;
            
            action monitoringCycle;
            then action updateWorkload : workloadMonitor::UpdateWorkload {
                in taskTotal = workloadInput.taskCount;
                in tasksDone = workloadInput.completionRate * workloadInput.taskCount;
                in effort = workloadInput.effortEstimate;
                out updatedMetrics;
            }
            then action updateTemporal : temporalMonitor::UpdateTimeConstraints {
                in current = timeInput.currentTimestamp;
                in deadline = timeInput.deadlineTimestamp;
                out updatedConstraints;
            }
            then action calculatePressure : pressureCalculator::ComputePressure {
                in workload = updateWorkload.updatedMetrics;
                in temporal = updateTemporal.updatedConstraints;
                out metrics;
                out level;
            }
            then action evaluateAlert : alertManager::EvaluateAlert {
                in currentPressure = calculatePressure.level;
                in threshold = alertManager.alertThreshold;
                out shouldAlert;
                out message;
            }
            then action updateDisplay : display::UpdateDisplay {
                in pressure = calculatePressure.metrics.combinedPressure;
                in category = calculatePressure.level;
                in updateRate = display.refreshRate;
            }
            then action recordData : recorder::RecordPressureData {
                in currentMetrics = calculatePressure.metrics;
                in currentLevel = calculatePressure.level;
                in workload = updateWorkload.updatedMetrics;
                in temporal = updateTemporal.updatedConstraints;
                in interval = recorder.recordingInterval;
            }
            then assign currentPressure := calculatePressure.metrics;
            then assign currentLevel := calculatePressure.level;
            then assign alertStatus := evaluateAlert.shouldAlert;
            then monitoringCycle;
        }
    }
    
    part gaugeSystem : TimePressureGauge {
        attribute :>> measurementCycle = 10.0 [SI::s];
        
        perform action monitoring : MonitorTimePressure {
            in cycleInterval = measurementCycle;
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* 
            The Time Pressure Gauge system shall continuously monitor and quantify 
            the pressure exerted by temporal constraints on work completion, 
            providing real-time assessment of schedule stress and alerting when 
            critical thresholds are exceeded.
        */
        
        subject gauge : TimePressureGauge;
        
        require constraint {
            gauge.measurementCycle <= 30.0 [SI::s]
        }
    }
    
    requirement def PressureAccuracyRequirement {
        doc /* 
            The gauge shall compute pressure metrics with consideration of both 
            workload volume and time constraints, updating calculations within 
            the defined measurement cycle.
        */
        
        subject gauge : TimePressureGauge;
    }
    
    requirement def AlertResponsivenessRequirement {
        doc /* 
            The gauge shall evaluate alert conditions and activate notifications 
            within one measurement cycle of pressure threshold violation.
        */
        
        subject gauge : TimePressureGauge;
        
        require constraint {
            gauge.alertManager.alertThreshold >= PressureLevel::moderate
        }
    }
    
    requirement def DataRetentionRequirement {
        doc /* 
            The gauge shall maintain historical pressure records for trend analysis 
            and performance review.
        */
        
        subject gauge : TimePressureGauge;
        
        require constraint {
            gauge.recorder.maxRecords >= 100
        }
    }
}
