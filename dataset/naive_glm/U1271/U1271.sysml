package AlertMe {

    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type TemperatureValue :> Real {
        unit degC;
    }

    value type HumidityValue :> Real {
        unit percentRH;
    }

    value type DurationValue :> Real {
        unit sec;
    }

    value type TimestampValue :> Real {
        unit epochSec;
    }

    value type PercentValue :> Real {
        unit percent;
    }

    // ===== Enumerations =====
    enum def SensorKind {
        temperature;
        humidity;
        combined;
    }

    enum def AlertSeverity {
        info;
        warning;
        critical;
    }

    enum def AlertStatus {
        active;
        acknowledged;
        escalated;
        resolved;
    }

    enum def DispatchPhase {
        idle;
        dispatching;
        awaiting;
        escalating;
        completed;
    }

    // ===== Items =====
    item def SensorReading {
        attribute sensorId : String;
        attribute kind : SensorKind;
        attribute timestamp : TimestampValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute valid : Boolean = true;
    }

    item def Alert {
        attribute alertId : String;
        attribute severity : AlertSeverity;
        attribute sourceSensorId : String;
        attribute timestamp : TimestampValue;
        attribute measuredValue : Real;
        attribute thresholdValue : Real;
        attribute message : String;
        attribute status : AlertStatus = AlertStatus::active;
        attribute escalationCount : Integer = 0;
    }

    item def Acknowledgment {
        attribute alertId : String;
        attribute operatorId : String;
        attribute timestamp : TimestampValue;
        attribute note : String[0..1];
    }

    item def AlertLogEntry {
        attribute alert : Alert;
        attribute ack : Acknowledgment[0..1];
        attribute escalated : Boolean = false;
        attribute closedAt : TimestampValue[0..1];
    }

    item def ThresholdConfig {
        attribute warningTemperature : TemperatureValue = 30 [degC];
        attribute criticalTemperature : TemperatureValue = 40 [degC];
        attribute warningHumidity : HumidityValue = 70 [percentRH];
        attribute criticalHumidity : HumidityValue = 85 [percentRH];
        attribute ackTimeout : DurationValue = 300 [sec];
        attribute escalationTimeout : DurationValue = 600 [sec];
        attribute maxEscalations : Integer = 3;
    }

    // ===== Ports =====
    port def SensorReadingOut {
        out readings : SensorReading;
    }

    port def SensorReadingIn {
        in readings : SensorReading;
    }

    port def AlertOut {
        out alerts : Alert;
    }

    port def AlertIn {
        in alerts : Alert;
    }

    port def AckOut {
        out acks : Acknowledgment;
    }

    port def AckIn {
        in acks : Acknowledgment;
    }

    port def ArchiveIn {
        in readings : SensorReading;
        in alerts : Alert;
        in acks : Acknowledgment;
    }

    // ===== Environmental Sensor =====
    part def EnvironmentalSensor {
        attribute sensorId : String;
        attribute kind : SensorKind = SensorKind::combined;
        attribute location : String;
        attribute samplePeriod : DurationValue = 5 [sec];
        attribute enabled : Boolean = true;

        port sensorOutput : SensorReadingOut;

        state sensorState {
            state Off;
            state Idle;
            state Sampling {
                entry do acquireTemperature();
                do acquireHumidity();
                do stampReading();
            }
            state Transmitting {
                entry do sendReading();
            }

            transition from Off to Idle when sensorEnabled;
            transition from Idle to Sampling after samplePeriod;
            transition from Sampling to Transmitting;
            transition from Transmitting to Idle;
            transition from Idle to Off when sensorDisabled;
        }

        action acquireTemperature;
        action acquireHumidity;
        action stampReading;
        action sendReading;
    }

    // ===== Monitoring Controller =====
    part def MonitoringController {
        attribute controllerId : String;
        attribute config : ThresholdConfig;
        attribute alertCounter : Integer = 0;

        port controllerInput : SensorReadingIn;
        port alertOutput : AlertOut;
        port archiveReadingOut : SensorReadingOut;
        port archiveAlertOut : AlertOut;

        state controllerState {
            state Idle;
            state Evaluating {
                entry do compareReading();
                do checkTemperature();
                do checkHumidity();
                do decideSeverity();
            }
            state Alerting {
                entry do emitAlert();
            }
            state Archiving {
                entry do archiveReading();
                do archiveAlert();
            }

            transition from Idle to Evaluating when readingReceived;
            transition from Evaluating to Alerting when alertGenerated;
            transition from Evaluating to Archiving when noAlertGenerated;
            transition from Alerting to Archiving;
            transition from Archiving to Idle;
        }

        action compareReading;
        action checkTemperature;
        action checkHumidity;
        action decideSeverity;
        action emitAlert;
        action archiveReading;
        action archiveAlert;
    }

    // ===== Notification Dispatcher =====
    part def NotificationDispatcher {
        attribute dispatcherId : String;
        attribute ackTimeout : DurationValue = 300 [sec];
        attribute escalationTimeout : DurationValue = 600 [sec];
        attribute maxEscalations : Integer = 3;
        attribute activeAlerts : Alert[0..*];

        port dispatcherInput : AlertIn;
        port displayOutput : AlertOut;
        port ackInput : AckIn;
        port escalationOutput : AlertOut;
        port archiveAckOut : AckOut;

        state dispatcherState {
            state Idle;
            state Dispatching {
                entry do sendToDisplay();
            }
            state AwaitingAcknowledgment {
                entry do startAckTimer();
            }
            state Escalating {
                entry do escalateAlert();
            }
            state Completed {
                entry do finalizeAlert();
            }

            transition from Idle to Dispatching when dispatcherInput.alerts.available;
            transition from Dispatching to AwaitingAcknowledgment;
            transition from AwaitingAcknowledgment to Completed when ackInput.acks.available;
            transition from AwaitingAcknowledgment to Escalating after escalationTimeout;
            transition from Escalating to AwaitingAcknowledgment when escalationsRemaining;
            transition from Escalating to Completed when maxEscalationsReached;
        }

        action sendToDisplay;
        action startAckTimer;
        action escalateAlert;
        action finalizeAlert;
    }

    // ===== User Display =====
    part def UserDisplay {
        attribute displayId : String;
        attribute operatorId : String;
        attribute currentAlert : Alert[0..1];

        port displayInput : AlertIn;
        port ackOutput : AckOut;

        state displayState {
            state Idle;
            state Displaying {
                entry do renderAlert();
                do awaitOperator();
            }
            state Acknowledging {
                entry do recordAck();
                do sendAck();
            }

            transition from Idle to Displaying when displayInput.alerts.available;
            transition from Displaying to Acknowledging when operatorAcknowledges;
            transition from Acknowledging to Idle;
        }

        action renderAlert;
        action awaitOperator;
        action recordAck;
        action sendAck;
    }

    // ===== Data Archive =====
    part def DataArchive {
        attribute archiveId : String;
        attribute capacity : Integer = 1000000;
        attribute storedReadings : SensorReading[0..*];
        attribute storedAlerts : Alert[0..*];
        attribute storedAcks : Acknowledgment[0..*];
        attribute alertLog : AlertLogEntry[0..*];

        port archiveInput : ArchiveIn;

        state archiveState {
            state Idle;
            state StoringReading {
                entry do persistReading();
            }
            state StoringAlert {
                entry do persistAlert();
            }
            state StoringAck {
                entry do persistAck();
            }
            state Indexing {
                entry do indexEntry();
            }

            transition from Idle to StoringReading when archiveInput.readings.available;
            transition from Idle to StoringAlert when archiveInput.alerts.available;
            transition from Idle to StoringAck when archiveInput.acks.available;
            transition from StoringReading to Indexing;
            transition from StoringAlert to Indexing;
            transition from StoringAck to Indexing;
            transition from Indexing to Idle;
        }

        action persistReading;
        action persistAlert;
        action persistAck;
        action indexEntry;
    }

    // ===== AlertMe System =====
    part def AlertMeSystem {
        attribute systemId : String;
        attribute configuration : ThresholdConfig;
        attribute operational : Boolean = true;

        part sensors : EnvironmentalSensor[1..*];
        part controller : MonitoringController;
        part dispatcher : NotificationDispatcher;
        part display : UserDisplay;
        part archive : DataArchive;

        connect sensors.sensorOutput to controller.controllerInput;
        connect controller.alertOutput to dispatcher.dispatcherInput;
        connect dispatcher.displayOutput to display.displayInput;
        connect display.ackOutput to dispatcher.ackInput;
        connect dispatcher.escalationOutput to display.displayInput;
        connect controller.archiveReadingOut to archive.archiveInput;
        connect controller.archiveAlertOut to archive.archiveInput;
        connect dispatcher.archiveAckOut to archive.archiveInput;
    }

    // ===== Requirements =====
    requirement def EnvironmentalMonitoringRequirement {
        doc "The AlertMe system shall continuously monitor environmental temperature and humidity at one or more locations.";
    }

    requirement def ThresholdEvaluationRequirement {
        doc "The monitoring controller shall compare every incoming sensor reading against configurable warning and critical thresholds.";
    }

    requirement def AlertGenerationRequirement {
        doc "The controller shall generate an alert with severity proportional to the exceeded threshold and timestamp the alert.";
    }

    requirement def NotificationDispatchRequirement {
        doc "The notification dispatcher shall forward each generated alert to the user display for operator action.";
    }

    requirement def AcknowledgmentRequirement {
        doc "The system shall track the alert lifecycle and accept operator acknowledgments from the user display.";
    }

    requirement def EscalationRequirement {
        doc "If a critical alert is not acknowledged within the configured timeout, the dispatcher shall escalate the alert up to a maximum number of escalations.";
    }

    requirement def ArchiveRequirement {
        doc "The data archive shall persist every sensor reading, every alert, and every acknowledgment, providing a complete audit trail.";
    }

    requirement def TimestampRequirement {
        doc "Every sensor reading shall be time-stamped and identified by its source sensor identifier.";
    }

    requirement monitorReq : EnvironmentalMonitoringRequirement;
    requirement thresholdReq : ThresholdEvaluationRequirement;
    requirement alertGenReq : AlertGenerationRequirement;
    requirement notifyReq : NotificationDispatchRequirement;
    requirement ackReq : AcknowledgmentRequirement;
    requirement escReq : EscalationRequirement;
    requirement archiveReq : ArchiveRequirement;
    requirement tsReq : TimestampRequirement;

    satisfy monitorReq by AlertMeSystem::sensors;
    satisfy thresholdReq by AlertMeSystem::controller;
    satisfy alertGenReq by AlertMeSystem::controller;
    satisfy notifyReq by AlertMeSystem::dispatcher;
    satisfy ackReq by AlertMeSystem::dispatcher;
    satisfy escReq by AlertMeSystem::dispatcher;
    satisfy archiveReq by AlertMeSystem::archive;
    satisfy tsReq by AlertMeSystem::sensors;
}
