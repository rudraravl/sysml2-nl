package 'Voltage Detector System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VoltageThreshold :> Real;
    attribute def AlarmState;
    attribute def DetectionMode;
    
    item def ElectricalSignal {
        attribute voltage :> Real;
        attribute current :> Real;
        attribute timestamp :> Real;
    }
    
    port def SensorPort {
        in item signal : ElectricalSignal;
    }
    
    port def AlarmPort {
        out attribute alarmActive : Boolean;
        out attribute alarmLevel : AlarmState;
    }
    
    port def ControlPort {
        in attribute thresholdSetting : VoltageThreshold;
        in attribute enableMonitoring : Boolean;
        out attribute systemStatus : DetectionMode;
    }
    
    part def VoltageSensor {
        port sensePort : SensorPort;
        out attribute measuredVoltage :> Real;
        
        action def MeasureVoltage {
            in item inputSignal : ElectricalSignal;
            out attribute voltage :> Real;
        }
    }
    
    part def ThresholdComparator {
        in attribute inputVoltage :> Real;
        in attribute lowerThreshold :> Real;
        in attribute upperThreshold :> Real;
        out attribute withinRange : Boolean;
        out attribute violationType : AlarmState;
        
        action def CompareThresholds {
            in attribute measured :> Real;
            in attribute lower :> Real;
            in attribute upper :> Real;
            out attribute inRange : Boolean;
            out attribute violation : AlarmState;
        }
    }
    
    part def AlarmController {
        in attribute triggerCondition : Boolean;
        in attribute violationType : AlarmState;
        port alarmOutput : AlarmPort;
        
        action def ActivateAlarm {
            in attribute condition : Boolean;
            in attribute alarmType : AlarmState;
            out attribute alarmStatus : Boolean;
        }
    }
    
    action def MonitorVoltageLevel {
        in attribute lowerLimit :> Real;
        in attribute upperLimit :> Real;
        in item inputSignal : ElectricalSignal;
        out attribute detectionStatus : DetectionMode;
        out attribute alarmTriggered : Boolean;
        
        private attribute currentVoltage :> Real;
        private attribute rangeViolation : Boolean;
        private attribute violationMode : AlarmState;
        
        first start;
        then merge continuousMonitoring;
        
        then action measureInput {
            in item signal = inputSignal;
            out attribute voltage :> Real;
        }
        then assign currentVoltage := measureInput.voltage;
        
        then action evaluateThresholds {
            in attribute measured = currentVoltage;
            in attribute lower = lowerLimit;
            in attribute upper = upperLimit;
            out attribute withinBounds : Boolean;
            out attribute violationCategory : AlarmState;
        }
        then assign rangeViolation := !evaluateThresholds.withinBounds;
        then assign violationMode := evaluateThresholds.violationCategory;
        
        then decide;
            if rangeViolation then triggerAlarm;
            if !rangeViolation then normalOperation;
        
        action triggerAlarm {
            then assign detectionStatus := "ALARM_ACTIVE";
            then assign alarmTriggered := true;
        }
        then continuousMonitoring;
        
        action normalOperation {
            then assign detectionStatus := "NORMAL_OPERATION";
            then assign alarmTriggered := false;
        }
        then continuousMonitoring;
    }
    
    state def VoltageDetectorStateMachine {
        entry; then initialization;
        
        state initialization {
            entry assign statusIndicator := "Initializing";
        }
        
        transition init_to_standby
            first initialization
            accept systemReadyEvent
            then standby;
        
        state standby {
            entry assign statusIndicator := "Standby";
        }
        
        transition standby_to_active
            first standby
            accept monitoringEnabledEvent
            then activeMonitoring;
        
        state activeMonitoring {
            entry assign statusIndicator := "Active Monitoring";
            do action performMonitoring : MonitorVoltageLevel;
        }
        
        transition active_to_alarm
            first activeMonitoring
            if thresholdViolationDetected
            then alarmState;
        
        state alarmState {
            entry assign statusIndicator := "Alarm Triggered";
            do action raiseAlarm;
        }
        
        transition alarm_to_active
            first alarmState
            accept alarmClearedEvent
            then activeMonitoring;
        
        transition active_to_standby
            first activeMonitoring
            accept monitoringDisabledEvent
            then standby;
        
        attribute statusIndicator : String;
        attribute thresholdViolationDetected : Boolean;
        event systemReadyEvent;
        event monitoringEnabledEvent;
        event monitoringDisabledEvent;
        event alarmClearedEvent;
        action raiseAlarm;
    }
    
    part def VoltageDetectorSystem {
        doc /* A voltage detector system that continuously monitors electrical voltage levels,
               compares them against configurable safety thresholds, and automatically triggers
               protective alarms when voltage deviations are detected to prevent equipment damage
               and ensure operational safety. */
        
        attribute nominalVoltage :> Real;
        attribute lowerThreshold :> Real;
        attribute upperThreshold :> Real;
        attribute samplingRate :> Real;
        
        port inputPort : SensorPort;
        port alarmPort : AlarmPort;
        port controlPort : ControlPort;
        
        part sensor : VoltageSensor {
            port :>> sensePort = inputPort;
        }
        
        part comparator : ThresholdComparator {
            in :>> inputVoltage = sensor.measuredVoltage;
            in :>> lowerThreshold = VoltageDetectorSystem::lowerThreshold;
            in :>> upperThreshold = VoltageDetectorSystem::upperThreshold;
        }
        
        part alarmUnit : AlarmController {
            in :>> triggerCondition = !comparator.withinRange;
            in :>> violationType = comparator.violationType;
            port :>> alarmOutput = alarmPort;
        }
        
        connection sensorToComparator connect sensor.measuredVoltage to comparator.inputVoltage;
        connection comparatorToAlarm connect comparator.withinRange to alarmUnit.triggerCondition;
        connection alarmToOutput connect alarmUnit.alarmOutput to alarmPort;
        
        perform action voltageMonitoring : MonitorVoltageLevel {
            in lowerLimit = lowerThreshold;
            in upperLimit = upperThreshold;
            in inputSignal = inputPort.signal;
            out detectionStatus;
            out alarmTriggered;
        }
        
        exhibit state detectorBehavior : VoltageDetectorStateMachine;
    }
    
    part voltageDetector : VoltageDetectorSystem {
        attribute :>> nominalVoltage = 24.0;
        attribute :>> lowerThreshold = 20.0;
        attribute :>> upperThreshold = 28.0;
        attribute :>> samplingRate = 1000.0;
    }
    
    requirement def VoltageMonitoringRequirement {
        doc /* The voltage detector system shall provide continuous real-time monitoring
               of electrical voltage levels and automatically trigger protective alarms
               when measured voltages deviate from predefined safety thresholds. */
        
        subject detectorSystem : VoltageDetectorSystem;
        
        require constraint monitoringAccuracy {
            doc /* The system shall detect voltage threshold violations with accuracy
                   within ±1% of the configured threshold values. */
        }
        
        require constraint responseTime {
            doc /* The system shall generate an alarm signal within 5 milliseconds
                   of detecting a threshold violation. */
        }
        
        require constraint continuousOperation {
            doc /* The system shall operate continuously with minimum sampling rate
                   of 1 kHz during active monitoring state. */
        }
    }
    
    requirement <'VD-REQ-001'> primaryVoltageDetection : VoltageMonitoringRequirement {
        doc /* The Voltage Detector System shall continuously monitor input voltage levels,
               compare them against configurable upper and lower safety thresholds, and
               automatically activate protective alarms when voltage deviations are detected,
               thereby preventing equipment damage and ensuring safe operation of connected
               electrical systems. */
        
        subject voltageDetector;
        
        assume constraint validInputRange {
            doc /* Input electrical signals shall be within the measurable range
                   of 0V to 100V DC. */
        }
        
        require constraint thresholdConfigurability {
            doc /* Voltage thresholds shall be configurable within the range
                   of 5V to 95V with 0.1V resolution. */
        }
        
        require constraint alarmReliability {
            doc /* The alarm system shall have a reliability of 99.9% over
                   the operational lifetime. */
        }
    }
}
