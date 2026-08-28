package ShockDetectionSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value def Acceleration :> Real {
        ref unit :>> unit = g;
    }

    value def Duration :> Real {
        ref unit :>> unit = SI::s;
    }

    value def Frequency :> Real {
        ref unit :>> unit = SI::Hz;
    }

    value def Voltage :> Real {
        ref unit :>> unit = SI::V;
    }

    value def Timestamp :> Real {
        ref unit :>> unit = SI::s;
    }

    value def RecordId :> Integer;

    // ===== Enumerations =====

    enum def SeverityLevel {
        none;
        minor;
        moderate;
        severe;
        critical;
    }

    enum def AlertChannel {
        none;
        visual;
        audible;
        remote;
    }

    enum def SensorStatus {
        idle;
        active;
        fault;
    }

    enum def ProcessorState {
        monitoring;
        evaluating;
        eventConfirmed;
        idle;
    }

    enum def LoggerState {
        ready;
        writing;
        full;
        error;
    }

    enum def NotificationState {
        standby;
        alerting;
        fault;
    }

    // ===== Item Definitions =====

    item def RawAccelerationData {
        ref value magnitude : Acceleration;
        ref value timestamp : Timestamp;
        ref value noiseLevel : Voltage;
    }

    item def ConditionedAccelerationData {
        ref value magnitude : Acceleration;
        ref value timestamp : Timestamp;
        ref value confidence : Real; // 0.0 to 1.0
    }

    item def ShockEvent {
        ref value eventId : RecordId;
        ref value startTime : Timestamp;
        ref value duration : Duration;
        ref value peakAcceleration : Acceleration;
        ref severity : SeverityLevel;
    }

    item def EventLogRecord {
        ref value recordId : RecordId;
        ref value timestamp : Timestamp;
        ref value peakAcceleration : Acceleration;
        ref value duration : Duration;
        ref severity : SeverityLevel;
    }

    item def AlertCommand {
        ref severity : SeverityLevel;
        ref value peakAcceleration : Acceleration;
        ref value timestamp : Timestamp;
        ref value eventId : RecordId;
    }

    item def NotificationMessage {
        ref value messageId : RecordId;
        ref value timestamp : Timestamp;
        ref severity : SeverityLevel;
        ref value peakAcceleration : Acceleration;
        ref value duration : Duration;
        ref targetDevice : String;
    }

    // ===== Port Definitions =====

    port def RawDataOut {
        out item raw : RawAccelerationData;
    }

    port def RawDataIn {
        in item raw : RawAccelerationData;
    }

    port def ConditionedDataOut {
        out item data : ConditionedAccelerationData;
    }

    port def ConditionedDataIn {
        in item data : ConditionedAccelerationData;
    }

    port def ShockEventOut {
        out item event : ShockEvent;
    }

    port def ShockEventIn {
        in item event : ShockEvent;
    }

    port def AlertCommandOut {
        out item alert : AlertCommand;
    }

    port def AlertCommandIn {
        in item alert : AlertCommand;
    }

    port def LogRecordOut {
        out item record : EventLogRecord;
    }

    port def LogRecordIn {
        in item record : EventLogRecord;
    }

    port def NotificationOut {
        out item message : NotificationMessage;
    }

    port def NotificationIn {
        in item message : NotificationMessage;
    }

    // ===== Interfaces =====

    interface def RawDataFlow
        :> RawDataOut, RawDataIn {
        end supplier : RawDataOut;
        end consumer : RawDataIn;
    }

    interface def ConditionedDataFlow
        :> ConditionedDataOut, ConditionedDataIn {
        end supplier : ConditionedDataOut;
        end consumer : ConditionedDataIn;
    }

    interface def ShockEventFlow
        :> ShockEventOut, ShockEventIn {
        end supplier : ShockEventOut;
        end consumer : ShockEventIn;
    }

    interface def AlertCommandFlow
        :> AlertCommandOut, AlertCommandIn {
        end supplier : AlertCommandOut;
        end consumer : AlertCommandIn;
    }

    interface def LogRecordFlow
        :> LogRecordOut, LogRecordIn {
        end supplier : LogRecordOut;
        end consumer : LogRecordIn;
    }

    interface def NotificationFlow
        :> NotificationOut, NotificationIn {
        end supplier : NotificationOut;
        end consumer : NotificationIn;
    }

    // ===== Part Definitions =====

    part def AccelerationSensor {
        port rawOut : RawDataOut;

        ref value samplingRate : Frequency = 1000 [SI::Hz];
        ref value measurementRange : Acceleration = 200 [g];
        ref value sensitivity : Voltage = 0.01 [SI::V];

        attribute status : SensorStatus = SensorStatus::idle;

        state sensorBehavior {
            entry; then idle;
            state idle {
                entry action { status = SensorStatus::idle; }
            }
            state active {
                entry action { status = SensorStatus::active; }
                do action produceRawData {
                    // Continuously sample physical acceleration
                    // and emit raw data on rawOut
                }
            }
            state fault {
                entry action { status = SensorStatus::fault; }
            }
            transition idle_to_active
                first idle
                accept PowerOn
                then active;
            transition active_to_idle
                first active
                accept PowerOff
                then idle;
            transition active_to_fault
                first active
                accept SensorFault
                then fault;
            transition fault_to_idle
                first fault
                accept Reset
                then idle;
        }
    }

    part def SignalConditioner {
        port rawIn : RawDataIn;
        port conditionedOut : ConditionedDataOut;

        ref value cutoffFrequency : Frequency = 50 [SI::Hz];
        ref value filterGain : Real = 1.0;

        action filterSignal {
            in item raw : RawAccelerationData;
            out item conditioned : ConditionedAccelerationData;
            // Apply low-pass filter to remove noise
            // Produce clean acceleration reading
        }

        state conditionerBehavior {
            entry; then ready;
            state ready {
                do action {
                    // Accept raw data and filter continuously
                }
            }
            state bypass {
                // Pass-through mode for diagnostics
            }
            transition ready_to_bypass
                first ready
                accept EnableBypass
                then bypass;
            transition bypass_to_ready
                first bypass
                accept DisableBypass
                then ready;
        }
    }

    part def ShockDetectionProcessor {
        port conditionedIn : ConditionedDataIn;
        port eventOut : ShockEventOut;
        port alertOut : AlertCommandOut;

        ref value minorThreshold : Acceleration = 2.0 [g];
        ref value moderateThreshold : Acceleration = 5.0 [g];
        ref value severeThreshold : Acceleration = 10.0 [g];
        ref value criticalThreshold : Acceleration = 20.0 [g];
        ref value minEventDuration : Duration = 0.001 [SI::s];

        ref value nextEventId : RecordId = 1;

        attribute currentState : ProcessorState = ProcessorState::idle;

        action classifySeverity {
            in value peak : Acceleration;
            out severity : SeverityLevel;
            // Compare peak against thresholds
        }

        action detectShockEvent {
            in item data : ConditionedAccelerationData;
            out item event : ShockEvent;
            // Analyze signal, determine duration, classify severity
        }

        action generateAlert {
            in item event : ShockEvent;
            out item alert : AlertCommand;
            // Create alert command based on event
        }

        state processorBehavior {
            entry; then idle;
            state idle {
                entry action { currentState = ProcessorState::idle; }
            }
            state monitoring {
                entry action { currentState = ProcessorState::monitoring; }
                do action {
                    // Continuously receive conditioned data
                    // and monitor for threshold crossings
                }
            }
            state evaluating {
                entry action { currentState = ProcessorState::evaluating; }
                do action {
                    // Determine event duration and peak
                    // Classify severity
                }
            }
            state eventConfirmed {
                entry action { currentState = ProcessorState::eventConfirmed; }
                do action {
                    // Emit ShockEvent on eventOut
                    // Emit AlertCommand on alertOut
                }
                then monitoring;
            }
            transition idle_to_monitoring
                first idle
                accept StartMonitoring
                then monitoring;
            transition monitoring_to_evaluating
                first monitoring
                accept ThresholdExceeded
                then evaluating;
            transition evaluating_to_eventConfirmed
                first evaluating
                accept EventValidated
                then eventConfirmed;
            transition evaluating_to_monitoring
                first evaluating
                accept EventRejected
                then monitoring;
            transition monitoring_to_idle
                first monitoring
                accept StopMonitoring
                then idle;
        }
    }

    part def EventLogger {
        port eventIn : ShockEventIn;
        port recordOut : LogRecordOut;

        ref value maxRecords : Integer = 100000;
        ref value recordCount : Integer = 0;
        ref value nextRecordId : RecordId = 1;

        attribute currentState : LoggerState = LoggerState::ready;

        action logEvent {
            in item event : ShockEvent;
            out item record : EventLogRecord;
            // Convert shock event to log record
            // Store in persistent storage
        }

        state loggerBehavior {
            entry; then ready;
            state ready {
                entry action { currentState = LoggerState::ready; }
                do action {
                    // Accept events and write records
                }
            }
            state writing {
                entry action { currentState = LoggerState::writing; }
                do action {
                    // Persist record to storage
                }
                then ready;
            }
            state full {
                entry action { currentState = LoggerState::full; }
                // Storage full; oldest records may be overwritten
            }
            state error {
                entry action { currentState = LoggerState::error; }
            }
            transition ready_to_writing
                first ready
                accept LogRequest
                then writing;
            transition ready_to_full
                first ready
                accept StorageFull
                then full;
            transition full_to_ready
                first full
                accept StorageCleared
                then ready;
            transition ready_to_error
                first ready
                accept WriteError
                then error;
            transition error_to_ready
                first error
                accept Reset
                then ready;
        }
    }

    part def AlertNotificationSystem {
        port alertIn : AlertCommandIn;
        port notificationOut : NotificationOut;

        part visualIndicator {
            ref value active : Boolean = false;
            ref value color : String = "green";
            action activate {
                in severity : SeverityLevel;
                // Set indicator color and pattern based on severity
            }
            action deactivate { }
        }

        part audibleAlarm {
            ref value active : Boolean = false;
            ref value volume : Real = 85.0; // dB
            action sound {
                in severity : SeverityLevel;
                // Set alarm pattern based on severity
            }
            action silence { }
        }

        part remoteNotifier {
            ref value connected : Boolean = false;
            ref value targetAddress : String = "control-center";
            action sendNotification {
                in item message : NotificationMessage;
                // Transmit to control center or operator device
            }
        }

        attribute currentState : NotificationState = NotificationState::standby;

        action processAlert {
            in item alert : AlertCommand;
            // Determine which channels to activate based on severity
        }

        action determineChannels {
            in severity : SeverityLevel;
            out channels : AlertChannel[0..*];
            // minor -> visual only
            // moderate -> visual + audible
            // severe/critical -> visual + audible + remote
        }

        state notificationBehavior {
            entry; then standby;
            state standby {
                entry action { currentState = NotificationState::standby; }
                do action {
                    // Wait for alert commands
                }
            }
            state alerting {
                entry action { currentState = NotificationState::alerting; }
                do action {
                    // Activate appropriate alert channels
                    // based on severity tier
                }
                then standby;
            }
            state fault {
                entry action { currentState = NotificationState::fault; }
            }
            transition standby_to_alerting
                first standby
                accept AlertReceived
                then alerting;
            transition standby_to_fault
                first standby
                accept NotificationFault
                then fault;
            transition fault_to_standby
                first fault
                accept Reset
                then standby;
        }
    }

    // ===== Top-Level System =====

    part def ShockDetectionSystem {

        part accelerationSensor : AccelerationSensor {
            port redefines rawOut;
        }

        part signalConditioner : SignalConditioner {
            port redefines rawIn;
            port redefines conditionedOut;
        }

        part shockDetectionProcessor : ShockDetectionProcessor {
            port redefines conditionedIn;
            port redefines eventOut;
            port redefines alertOut;
        }

        part eventLogger : EventLogger {
            port redefines eventIn;
            port redefines recordOut;
        }

        part alertNotificationSystem : AlertNotificationSystem {
            port redefines alertIn;
            port redefines notificationOut;
        }

        // External receiver of remote notifications
        part controlCenter {
            port notificationIn : NotificationIn;
            action receiveNotification {
                in item message : NotificationMessage;
                // Operator reviews and responds
            }
        }

        // External consumer of log records (analysis tool)
        part analysisTool {
            port recordIn : LogRecordIn;
            action analyzeRecord {
                in item record : EventLogRecord;
                // Historical data analysis
            }
        }

        // ===== Connections =====

        interface rawDataLink : RawDataFlow
            connect accelerationSensor.rawOut
            to signalConditioner.rawIn;

        interface conditionedDataLink : ConditionedDataFlow
            connect signalConditioner.conditionedOut
            to shockDetectionProcessor.conditionedIn;

        interface shockEventLink : ShockEventFlow
            connect shockDetectionProcessor.eventOut
            to eventLogger.eventIn;

        interface alertCommandLink : AlertCommandFlow
            connect shockDetectionProcessor.alertOut
            to alertNotificationSystem.alertIn;

        interface logRecordLink : LogRecordFlow
            connect eventLogger.recordOut
            to analysisTool.recordIn;

        interface notificationLink : NotificationFlow
            connect alertNotificationSystem.notificationOut
            to controlCenter.notificationIn;
    }

    // ===== Requirements =====

    requirement def ShallMonitorAcceleration {
        subject : ShockDetectionSystem;
        doc /*
         * The system shall continuously monitor physical acceleration
         * using an acceleration sensor with a sampling rate of at least
         * 1000 Hz and a measurement range of at least 200 g.
         */
        assume { subject.accelerationSensor.samplingRate >= 1000 [SI::Hz]; }
        assume { subject.accelerationSensor.measurementRange >= 200 [g]; }
    }

    requirement def ShallConditionSignal {
        subject : ShockDetectionSystem;
        doc /*
         * The system shall filter raw sensor data to remove electrical
         * noise and produce a conditioned acceleration signal with
         * a cutoff frequency of 50 Hz.
         */
        assume { subject.signalConditioner.cutoffFrequency == 50 [SI::Hz]; }
    }

    requirement def ShallClassifySeverity {
        subject : ShockDetectionSystem;
        doc /*
         * The processor shall classify each detected shock event into
         * one of five severity levels: none, minor, moderate, severe,
         * or critical, based on configurable acceleration thresholds.
         */
        assume { subject.shockDetectionProcessor.minorThreshold > 0 [g]; }
        assume { subject.shockDetectionProcessor.moderateThreshold > subject.shockDetectionProcessor.minorThreshold; }
        assume { subject.shockDetectionProcessor.severeThreshold > subject.shockDetectionProcessor.moderateThreshold; }
        assume { subject.shockDetectionProcessor.criticalThreshold > subject.shockDetectionProcessor.severeThreshold; }
    }

    requirement def ShallLogEvents {
        subject : ShockDetectionSystem;
        doc /*
         * The event logger shall record the time, severity, peak
         * acceleration, and duration of every confirmed shock event
         * into a historical log capable of storing at least 100,000
         * records.
         */
        assume { subject.eventLogger.maxRecords >= 100000; }
    }

    requirement def ShallProvideTieredAlerts {
        subject : ShockDetectionSystem;
        doc /*
         * The alert notification system shall provide tiered responses:
         * - minor: visual indicator only
         * - moderate: visual indicator + audible alarm
         * - severe: visual + audible + remote notification
         * - critical: visual + audible + remote notification
         */
        assume { subject.alertNotificationSystem.visualIndicator.active or subject.alertNotificationSystem.audibleAlarm.active or subject.alertNotificationSystem.remoteNotifier.connected; }
    }

    requirement def ShallSendRemoteNotificationForSevere {
        subject : ShockDetectionSystem;
        doc /*
         * For severe and critical events, the system shall send a
         * remote notification to a control center or operator's
         * device within 1 second of event confirmation.
         */
    }

    requirement def ShallProcessInRealTime {
        subject : ShockDetectionSystem;
        doc /*
         * The shock detection processor shall analyze conditioned
         * signals in real time and confirm shock events within
         * 100 milliseconds of threshold crossing.
         */
    }

    requirement ShockDetectionRequirements {
        subject : ShockDetectionSystem;
        satisfy r1 : ShallMonitorAcceleration;
        satisfy r2 : ShallConditionSignal;
        satisfy r3 : ShallClassifySeverity;
        satisfy r4 : ShallLogEvents;
        satisfy r5 : ShallProvideTieredAlerts;
        satisfy r6 : ShallSendRemoteNotificationForSevere;
        satisfy r7 : ShallProcessInRealTime;
    }

    // ===== Verification =====

    verification def VerifySeverityClassification {
        subject : ShockDetectionSystem;
        objective {
            doc /* Verify that the processor correctly classifies
             * shock events into the five severity levels. */
        }
        method {
            doc /* Inject known acceleration profiles and verify
             * classification output matches expected severity. */
        }
    }

    verification def VerifyTieredAlerts {
        subject : ShockDetectionSystem;
        objective {
            doc /* Verify that alert channels activate correctly
             * for each severity level. */
        }
        method {
            doc /* Trigger events at each severity level and confirm
             * visual, audible, and remote channels respond as
             * specified. */
        }
    }

    verification def VerifyLoggingCapacity {
        subject : ShockDetectionSystem;
        objective {
            doc /* Verify that the event logger can store at least
             * 100,000 records without data loss. */
        }
        method {
            doc /* Populate logger to capacity and verify record
             * integrity. */
        }
    }

}
