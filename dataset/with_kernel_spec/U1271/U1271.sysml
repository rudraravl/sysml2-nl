package AlertMe {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::TimeInstantValue;
    private import SI::s;

    enum def AlertSeverity {
        warning;
        critical;
    }

    item def SensorReading {
        attribute sensorId : String;
        attribute timestamp : TimeInstantValue;
        attribute temperature : Real;
        attribute humidity : Real;
    }

    item def Alert {
        attribute alertId : String;
        attribute sensorId : String;
        attribute severity : AlertSeverity;
        attribute text : String;
        attribute timestamp : TimeInstantValue;
    }

    item def Acknowledgement {
        attribute alertId : String;
        attribute operatorId : String;
        attribute timestamp : TimeInstantValue;
    }

    port def ReadingOutPort {
        out reading : SensorReading;
    }

    port def ReadingInPort {
        in reading : SensorReading;
    }

    port def AlertOutPort {
        out alert : Alert;
    }

    port def AlertInPort {
        in alert : Alert;
    }

    port def AckOutPort {
        out ack : Acknowledgement;
    }

    port def AckInPort {
        in ack : Acknowledgement;
    }

    action def SenseEnvironment {
        out reading : SensorReading;
    }

    action def AnalyzeReading {
        in reading : SensorReading;
        in warningThreshold : Real;
        in criticalThreshold : Real;
        out alert : Alert;
    }

    action def DisplayAlertAction {
        in alert : Alert;
    }

    action def SendAcknowledgement {
        out ack : Acknowledgement;
    }

    action def StoreReadingAction {
        in reading : SensorReading;
    }

    action def StoreAlertAction {
        in alert : Alert;
    }

    state def SensorStates {
        action 'sense environment' : SenseEnvironment;
        entry; then sensing;
        state sensing {
            do 'sense environment';
        }
    }

    state def ControllerStates {
        action 'analyze reading' : AnalyzeReading;
        entry; then monitoring;
        state monitoring {
            do 'analyze reading';
        }
    }

    state def DispatcherStates {
        entry; then idle;
        state idle;
        accept Alert
            then dispatched;
        state dispatched;
        accept Acknowledgement
            then idle;
        accept after 60 [s]
            then escalated;
        state escalated;
        accept Acknowledgement
            then idle;
    }

    part def EnvironmentalSensor {
        attribute sensorId : String;
        port dataOut : ReadingOutPort;
        perform action 'sense environment' : SenseEnvironment;
        exhibit state sensorStates : SensorStates;
    }

    part def MonitoringController {
        port sensorIn : ReadingInPort;
        port alertOut : AlertOutPort;
        attribute warningThreshold : Real;
        attribute criticalThreshold : Real;
        perform action 'analyze reading' : AnalyzeReading;
        exhibit state controllerStates : ControllerStates;
    }

    part def NotificationDispatcher {
        port alertIn : AlertInPort;
        port displayOut : AlertOutPort;
        port ackIn : AckInPort;
        exhibit state dispatcherStates : DispatcherStates;
    }

    part def UserDisplay {
        port alertIn : AlertInPort;
        port ackOut : AckOutPort;
        perform action 'display alert' : DisplayAlertAction;
        perform action 'send ack' : SendAcknowledgement;
    }

    part def DataArchive {
        port readingIn : ReadingInPort;
        port alertIn : AlertInPort;
        perform action 'store reading' : StoreReadingAction;
        perform action 'store alert' : StoreAlertAction;
    }

    part def AlertMeSystem {
        part sensors : EnvironmentalSensor[1..*];
        part controller : MonitoringController;
        part dispatcher : NotificationDispatcher;
        part display : UserDisplay;
        part archive : DataArchive;

        connect sensors.dataOut to controller.sensorIn;
        connect sensors.dataOut to archive.readingIn;
        connect controller.alertOut to dispatcher.alertIn;
        connect controller.alertOut to archive.alertIn;
        connect dispatcher.displayOut to display.alertIn;
        connect display.ackOut to dispatcher.ackIn;
    }

    requirement def EnvironmentalMonitoring {
        doc /* The system shall continuously monitor environmental conditions including temperature and humidity. */
    }

    requirement def ThresholdAlerting {
        doc /* The system shall generate warning alerts when readings exceed warning thresholds and critical alerts when readings exceed critical thresholds. */
    }

    requirement def UserNotification {
        doc /* The system shall display alerts to an operator and track alert acknowledgements. */
    }

    requirement def CriticalEscalation {
        doc /* Unacknowledged alerts shall be escalated after a configured timeout period. */
    }

    requirement def HistoricalArchive {
        doc /* The system shall store all sensor readings and alert logs for audit and analysis. */
    }

    part alertMeSystem : AlertMeSystem {
        part :>> controller {
            attribute :>> warningThreshold = 30.0;
            attribute :>> criticalThreshold = 40.0;
        }
    }

    requirement envMonitoring : EnvironmentalMonitoring {
        subject :>> alertMeSystem;
    }

    requirement thresholdAlert : ThresholdAlerting {
        subject :>> alertMeSystem;
    }

    requirement userNotif : UserNotification {
        subject :>> alertMeSystem;
    }

    requirement critEscalation : CriticalEscalation {
        subject :>> alertMeSystem;
    }

    requirement histArchive : HistoricalArchive {
        subject :>> alertMeSystem;
    }
}
