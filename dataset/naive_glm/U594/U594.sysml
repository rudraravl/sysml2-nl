package TemperatureMonitoringSystem {

    import ScalarValues::*;
    import Quantities::*;
    import Units::*;

    // ============================================================
    // Value types
    // ============================================================
    value def TemperatureValue :> Real {
        unit '°C';
    }

    value def TimeValue :> Real {
        unit 'ms';
    }

    value def HysteresisValue :> TemperatureValue;

    // ============================================================
    // Enumerations
    // ============================================================
    enum def AlarmSeverity {
        normal;
        warning;
        critical;
    }

    enum def SensorMode {
        standby;
        active;
        measuring;
    }

    // ============================================================
    // Item definitions
    // ============================================================
    item def TemperatureReading {
        attribute sensorId : String;
        attribute value : TemperatureValue;
        attribute timestamp : TimeValue;
        attribute calibrated : Boolean;
    }

    item def AlarmStatus {
        attribute severity : AlarmSeverity;
        attribute active : Boolean;
        attribute timestamp : TimeValue;
        attribute measuredTemp : TemperatureValue;
        attribute sensorId : String;
    }

    item def ConfigCommand {
        attribute enable : Boolean;
        attribute threshold : TemperatureValue;
        attribute hysteresis : HysteresisValue;
        attribute criticalThreshold : TemperatureValue;
    }

    // ============================================================
    // Port definitions
    // ============================================================
    port def TemperatureOutPort {
        out item reading : TemperatureReading;
    }

    port def AlarmOutPort {
        out item status : AlarmStatus;
    }

    port def ConfigInPort {
        in item config : ConfigCommand;
    }

    // ============================================================
    // Action definitions
    // ============================================================
    action def AcquireReading {
        in attribute sensorId : String;
        in attribute calibrationOffset : TemperatureValue;
        out item reading : TemperatureReading;
    }

    action def EvaluateAlarm {
        in item reading : TemperatureReading;
        in attribute warningThreshold : TemperatureValue;
        in attribute criticalThreshold : TemperatureValue;
        in attribute hysteresis : HysteresisValue;
        in attribute currentSeverity : AlarmSeverity;
        out item status : AlarmStatus;
    }

    // ============================================================
    // State machine: Sensor
    // ============================================================
    state def SensorStateMachine {
        attribute mode : SensorMode := SensorMode::standby;
        attribute sampleTimer : TimeValue := 0 ['ms'];
        attribute samplePeriod : TimeValue := 100 ['ms'];

        state standby {
            entry action { mode := SensorMode::standby; }
        }
        state active {
            entry action { mode := SensorMode::active; }
        }
        state measuring {
            entry action { mode := SensorMode::measuring; }
        }

        transition standby_to_active
            first standby
            when enabled
            then active;

        transition active_to_measuring
            first active
            when sampleTimer >= samplePeriod
            then measuring;

        transition measuring_to_active
            first measuring
            when readingComplete
            then active {
                action { sampleTimer := 0 ['ms']; }
            }

        transition active_to_standby
            first active
            when !enabled
            then standby;

        transition standby_to_standby
            first standby
            then standby;
    }

    // ============================================================
    // State machine: Alarm Evaluator
    // ============================================================
    state def AlarmStateMachine {
        attribute currentSeverity : AlarmSeverity := AlarmSeverity::normal;
        attribute lastTemp : TemperatureValue := 0 ['°C'];
        attribute responseTime : TimeValue := 0 ['ms'];

        state normal {
            entry action { currentSeverity := AlarmSeverity::normal; }
        }
        state warning {
            entry action { currentSeverity := AlarmSeverity::warning; }
        }
        state critical {
            entry action { currentSeverity := AlarmSeverity::critical; }
        }

        transition normal_to_warning
            first normal
            when lastTemp >= warningThreshold
            then warning;

        transition warning_to_critical
            first warning
            when lastTemp >= criticalThreshold
            then critical;

        transition critical_to_warning
            first critical
            when lastTemp < criticalThreshold - hysteresis
            then warning;

        transition warning_to_normal
            first warning
            when lastTemp < warningThreshold - hysteresis
            then normal;
    }

    // ============================================================
    // Parts
    // ============================================================
    part def TemperatureSensor {
        attribute sensorId : String;
        attribute calibrationOffset : TemperatureValue := 0 ['°C'];
        attribute enabled : Boolean := false;
        attribute samplePeriod : TimeValue := 100 ['ms'];
        attribute accuracy : TemperatureValue := 1.5 ['°C'];

        port tempOut : TemperatureOutPort;

        exhibit state sensorBehavior : SensorStateMachine {
            attribute warningThreshold : TemperatureValue := 50 ['°C'];
            attribute criticalThreshold : TemperatureValue := 80 ['°C'];
            attribute hysteresis : HysteresisValue := 2 ['°C'];
        }

        action acquire : AcquireReading {
            in attribute sensorId = self.sensorId;
            in attribute calibrationOffset = self.calibrationOffset;
            out item reading = self.tempOut.reading;
        }
    }

    part def AlarmEvaluator {
        attribute warningThreshold : TemperatureValue := 50 ['°C'];
        attribute criticalThreshold : TemperatureValue := 80 ['°C'];
        attribute hysteresis : HysteresisValue := 2 ['°C'];
        attribute enabled : Boolean := false;

        port tempIn : ~TemperatureOutPort;
        port alarmOut : AlarmOutPort;
        port configIn : ConfigInPort;

        exhibit state alarmBehavior : AlarmStateMachine {
            attribute warningThreshold := self.warningThreshold;
            attribute criticalThreshold := self.criticalThreshold;
            attribute hysteresis := self.hysteresis;
        }

        action evaluate : EvaluateAlarm {
            in item reading = self.tempIn.reading;
            in attribute warningThreshold = self.warningThreshold;
            in attribute criticalThreshold = self.criticalThreshold;
            in attribute hysteresis = self.hysteresis;
            in attribute currentSeverity = self.alarmBehavior.currentSeverity;
            out item status = self.alarmOut.status;
        }
    }

    // ============================================================
    // Top-level system
    // ============================================================
    part def TemperatureMonitor {
        attribute systemEnabled : Boolean := false;
        attribute configuredThreshold : TemperatureValue := 50 ['°C'];
        attribute configuredCriticalThreshold : TemperatureValue := 80 ['°C'];
        attribute configuredHysteresis : HysteresisValue := 2 ['°C'];

        port configIn : ConfigInPort;
        port alarmOut : AlarmOutPort;

        part sensor : TemperatureSensor {
            attribute sensorId := "TS-001";
            attribute calibrationOffset := 0 ['°C'];
        }

        part evaluator : AlarmEvaluator {
            attribute warningThreshold := self.configuredThreshold;
            attribute criticalThreshold := self.configuredCriticalThreshold;
            attribute hysteresis := self.configuredHysteresis;
        }

        connect sensor.tempOut to evaluator.tempIn;
        connect evaluator.alarmOut to self.alarmOut;
        connect self.configIn to evaluator.configIn;

        action updateConfiguration {
            in item config : ConfigCommand = self.configIn.config;
            action {
                self.systemEnabled := config.enable;
                self.configuredThreshold := config.threshold;
                self.configuredCriticalThreshold := config.criticalThreshold;
                self.configuredHysteresis := config.hysteresis;
                self.evaluator.warningThreshold := config.threshold;
                self.evaluator.criticalThreshold := config.criticalThreshold;
                self.evaluator.hysteresis := config.hysteresis;
                self.sensor.enabled := config.enable;
                self.evaluator.enabled := config.enable;
            }
        }
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def TemperatureAccuracyRequirement {
        subject monitor : TemperatureMonitor;
        attribute maxError : TemperatureValue := 1.5 ['°C'];
        objective {
            doc "The system shall provide temperature readings accurate to within ±1.5°C of the true ambient temperature."
        }
        require monitor.sensor.accuracy <= maxError;
    }

    requirement def AlarmResponseTimeRequirement {
        subject monitor : TemperatureMonitor;
        attribute maxResponseTime : TimeValue := 200 ['ms'];
        objective {
            doc "The system shall activate an alarm within 200 milliseconds of a threshold breach."
        }
        require monitor.evaluator.alarmBehavior.responseTime <= maxResponseTime;
    }

    requirement def HysteresisRequirement {
        subject monitor : TemperatureMonitor;
        objective {
            doc "The system shall prevent alarm oscillation by requiring the temperature to drop below the threshold by the configured hysteresis value before deactivating."
        }
        require monitor.evaluator.hysteresis > 0 ['°C'];
    }

    requirement def ConfigurableThresholdRequirement {
        subject monitor : TemperatureMonitor;
        objective {
            doc "The system shall allow external reconfiguration of the operating temperature threshold and hysteresis."
        }
        require monitor.configIn.config.threshold assignable;
        require monitor.configIn.config.hysteresis assignable;
    }

    requirement def UniqueSensorIdRequirement {
        subject monitor : TemperatureMonitor;
        objective {
            doc "Each temperature sensor shall have a unique identifier."
        }
        require monitor.sensor.sensorId != "";
    }

    requirement def AlarmSeverityRequirement {
        subject monitor : TemperatureMonitor;
        objective {
            doc "The system shall classify alarm conditions as warning or critical based on the configured thresholds."
        }
        require monitor.evaluator.alarmBehavior.currentSeverity in {AlarmSeverity::warning, AlarmSeverity::critical, AlarmSeverity::normal};
    }

    requirement def TimestampRequirement {
        subject monitor : TemperatureMonitor;
        objective {
            doc "Every alarm status issued by the system shall include a time stamp."
        }
        require monitor.evaluator.alarmOut.status.timestamp >= 0 ['ms'];
    }

}
