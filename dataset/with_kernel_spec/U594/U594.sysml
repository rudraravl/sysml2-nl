package 'Temperature Monitoring and Alarm System' {
    private import ScalarValues::*;

    attribute def TemperatureValue :> Real;
    attribute def DurationValue :> Real;
    attribute def SensorId :> String;

    enum def AlarmSeverity {
        normal;
        warning;
        critical;
    }

    item def TemperatureReading {
        id : SensorId;
        value : TemperatureValue;
        timestamp : DurationValue;
    }

    item def AlarmStatus {
        severity : AlarmSeverity;
        timestamp : DurationValue;
        reading : TemperatureValue;
    }

    attribute def EnableSignal;
    attribute def DisableSignal;
    attribute def ReconfigureSignal {
        threshold : TemperatureValue;
        hysteresis : TemperatureValue;
    }
    attribute def MeasurementTrigger;
    attribute def MeasurementComplete;

    port def TempOutputPort {
        out reading : TemperatureReading;
    }
    port def TempInputPort {
        in reading : TemperatureReading;
    }
    port def AlarmOutputPort {
        out status : AlarmStatus;
    }
    port def ConfigPort {
        in enable : EnableSignal;
        in disable : DisableSignal;
        in reconfigure : ReconfigureSignal;
    }

    action def 'Acquire Temperature' {
        out reading : TemperatureReading;
    }
    action def 'Evaluate Temperature' {
        in reading : TemperatureReading;
        out status : AlarmStatus;
    }
    action def 'Calibrate Sensor' {
        in offset : TemperatureValue;
    }

    state def 'Sensor States';
    state def 'Alarm States';

    part def TemperatureSensor {
        id : SensorId;
        calibrationOffset : TemperatureValue = 0;
        attribute enabled : Boolean = false;
        port configPort : ConfigPort;
        port tempOut : TempOutputPort;
        perform action 'acquire temperature': 'Acquire Temperature';
        exhibit state 'sensor states': 'Sensor States';
    }

    part def AlarmEvaluator {
        threshold : TemperatureValue;
        hysteresis : TemperatureValue;
        warningThreshold : TemperatureValue;
        criticalThreshold : TemperatureValue;
        port tempIn : TempInputPort;
        port alarmOut : AlarmOutputPort;
        port configPort : ConfigPort;
        perform action 'evaluate temperature': 'Evaluate Temperature';
        exhibit state 'alarm states': 'Alarm States';
    }

    part def TemperatureMonitoringSystem {
        threshold : TemperatureValue = 75;
        hysteresis : TemperatureValue = 5;
        warningThreshold : TemperatureValue = 75;
        criticalThreshold : TemperatureValue = 90;
        port configPort : ConfigPort;
        port alarmOut : AlarmOutputPort;
        part temperatureSensor : TemperatureSensor {
            id = "TS-001";
        }
        part alarmEvaluator : AlarmEvaluator {
            threshold = TemperatureMonitoringSystem::threshold;
            hysteresis = TemperatureMonitoringSystem::hysteresis;
            warningThreshold = TemperatureMonitoringSystem::warningThreshold;
            criticalThreshold = TemperatureMonitoringSystem::criticalThreshold;
        }
        connect temperatureSensor.tempOut to alarmEvaluator.tempIn;
        connect configPort to temperatureSensor.configPort;
        connect configPort to alarmEvaluator.configPort;
        connect alarmEvaluator.alarmOut to alarmOut;
    }

    part monitoringSystem : TemperatureMonitoringSystem;

    action 'acquire temperature': 'Acquire Temperature';
    action 'evaluate temperature': 'Evaluate Temperature';
    action 'calibrate sensor': 'Calibrate Sensor';

    state 'sensor states': 'Sensor States' {
        entry; then standby;
        state standby {
            entry 'calibrate sensor';
        }
        accept EnableSignal
            then active;
        state active;
        accept MeasurementTrigger
            then measuring;
        accept DisableSignal
            then standby;
        state measuring {
            do 'acquire temperature' { out reading; }
        }
        accept MeasurementComplete
            then active;
    }

    state 'alarm states': 'Alarm States' {
        entry; then normal;
        state normal;
        accept r : TemperatureReading
            if r.value >= monitoringSystem.alarmEvaluator.warningThreshold
            do send new AlarmStatus(severity = AlarmSeverity::warning, timestamp = r.timestamp, reading = r.value) to monitoringSystem.alarmEvaluator.alarmOut
            then warning;
        state warning;
        accept r : TemperatureReading
            if r.value >= monitoringSystem.alarmEvaluator.criticalThreshold
            do send new AlarmStatus(severity = AlarmSeverity::critical, timestamp = r.timestamp, reading = r.value) to monitoringSystem.alarmEvaluator.alarmOut
            then critical;
        accept r : TemperatureReading
            if r.value < monitoringSystem.alarmEvaluator.warningThreshold - monitoringSystem.alarmEvaluator.hysteresis
            do send new AlarmStatus(severity = AlarmSeverity::normal, timestamp = r.timestamp, reading = r.value) to monitoringSystem.alarmEvaluator.alarmOut
            then normal;
        state critical;
        accept r : TemperatureReading
            if r.value < monitoringSystem.alarmEvaluator.criticalThreshold - monitoringSystem.alarmEvaluator.hysteresis
            do send new AlarmStatus(severity = AlarmSeverity::warning, timestamp = r.timestamp, reading = r.value) to monitoringSystem.alarmEvaluator.alarmOut
            then warning;
    }

    requirement def 'Temperature Accuracy Requirement' {
        subject : TemperatureSensor;
        in measuredValue : TemperatureValue;
        in actualValue : TemperatureValue;
        doc /* The temperature sensor must provide readings accurate to within 1.5 degrees Celsius. */
        constraint { measuredValue - actualValue <= 1.5 and actualValue - measuredValue <= 1.5 }
    }

    requirement def 'Alarm Response Time Requirement' {
        subject : TemperatureMonitoringSystem;
        in responseTime : DurationValue;
        doc /* The system must respond to a threshold breach by activating an alarm within 200 milliseconds. */
        constraint { responseTime <= 200 }
    }

    requirement 'temp accuracy req' : 'Temperature Accuracy Requirement' {
        subject = monitoringSystem.temperatureSensor;
    }
    requirement 'alarm response req' : 'Alarm Response Time Requirement' {
        subject = monitoringSystem;
    }
}
