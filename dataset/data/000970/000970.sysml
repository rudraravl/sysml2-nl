package 'AlarmSensingUnitSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureThreshold :> TemperatureValue {
        attribute redefines num : Real;
        attribute redefines mRef : TemperatureUnit;
    }
    
    attribute def AlarmStatus {
        attribute isTriggered : Boolean;
        attribute severity : String;
        attribute timestamp : Real;
    }
    
    item def TemperatureMeasurement {
        attribute value : TemperatureValue;
        attribute measurementTime : Real;
        attribute isValid : Boolean;
    }
    
    port def SensorDataPort {
        out item measurement : TemperatureMeasurement;
    }
    
    port def AlarmOutputPort {
        out item status : AlarmStatus;
    }
    
    port def ConfigurationPort {
        in item thresholdConfig : TemperatureThreshold;
        in item enableCommand : Boolean;
    }
    
    part def AlarmSensor {
        attribute sensorIdentifier : String;
        attribute calibrationFactor : Real default = 1.0;
        attribute measurementThreshold : TemperatureThreshold;
        
        port dataOutput : SensorDataPort;
        
        action def AcquireTemperature {
            out measurement : TemperatureMeasurement;
        }
    }
    
    state def SensorStateMachine {
        entry; then standby;
        
        state standby;
        
        transition standby_to_active
            first standby
            accept ActivateSensor
            then active;
        
        state active;
        
        transition active_to_measuring
            first active
            accept TriggerMeasurement
            then measuring;
        
        state measuring;
        
        transition measuring_to_active
            first measuring
            accept MeasurementComplete
            then active;
        
        transition active_to_standby
            first active
            accept DeactivateSensor
            then standby;
    }
    
    part def AlarmEvaluator {
        attribute evaluationThreshold : TemperatureThreshold;
        attribute alarmHysteresis : TemperatureValue;
        
        port alarmSignal : AlarmOutputPort;
        
        action def EvaluateCondition {
            in measurement : TemperatureMeasurement;
            in threshold : TemperatureThreshold;
            out alarmStatus : AlarmStatus;
        }
    }
    
    state def AlarmStateMachine {
        entry; then normal;
        
        state normal;
        
        transition normal_to_warning
            first normal
            accept TemperatureAboveThreshold
            then warning;
        
        state warning;
        
        transition warning_to_critical
            first warning
            accept TemperatureCritical
            then critical;
        
        transition warning_to_normal
            first warning
            accept TemperatureBelowThreshold
            then normal;
        
        state critical;
        
        transition critical_to_warning
            first critical
            accept TemperatureDecreasing
            then warning;
    }
    
    part def SensingUnit {
        attribute unitIdentifier : String;
        attribute operatingThreshold : TemperatureThreshold;
        attribute isOperational : Boolean default = true;
        
        part sensor : AlarmSensor[1] {
            attribute :>> sensorIdentifier = "TEMP_ALARM_001";
            attribute :>> measurementThreshold = operatingThreshold;
        }
        
        part evaluator : AlarmEvaluator[1] {
            attribute :>> evaluationThreshold = operatingThreshold;
            attribute :>> alarmHysteresis {
                attribute :>> num = 5.0;
                attribute :>> mRef = K;
            }
        }
        
        port configPort : ConfigurationPort;
        port alarmPort : AlarmOutputPort;
        
        connection sensorToEvaluator
            connect sensor.dataOutput to evaluator;
        
        connection evaluatorToOutput
            connect evaluator.alarmSignal to alarmPort;
    }
    
    action def SensingCycleOperation {
        in thresholdSetting : TemperatureThreshold;
        out alarmResult : AlarmStatus;
        
        action acquireTemp : AlarmSensor::AcquireTemperature {
            out measurement;
        }
        
        flow from acquireTemp.measurement to evaluateCondition.measurement;
        
        action evaluateCondition : AlarmEvaluator::EvaluateCondition {
            in measurement;
            in threshold = thresholdSetting;
            out alarmStatus;
        }
        
        bind evaluateCondition.alarmStatus = alarmResult;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The alarm sensor shall measure temperature with accuracy within ±1.5°C. */
        
        subject alarmSensor : AlarmSensor;
        
        require constraint {
            alarmSensor.dataOutput.measurement.isValid == true
        }
    }
    
    requirement def AlarmResponseTimeRequirement {
        doc /* The alarm shall activate within 200ms when threshold is exceeded. */
        
        subject evaluator : AlarmEvaluator;
        
        require constraint {
            evaluator.alarmSignal.status.timestamp <= 0.2
        }
    }
    
    requirement def ThresholdMonitoringRequirement {
        doc /* The sensing unit shall continuously monitor temperature and trigger alarm when threshold is exceeded. */
        
        subject unit : SensingUnit;
        
        require constraint {
            unit.isOperational == true
        }
    }
    
    requirement def SystemFunctionalRequirement {
        doc /* The sensing unit shall measure the relevant quantity using an alarm sensor and provide alarm indication. */
        
        subject sensingSystem : SensingUnit;
        
        requirement accuracyReq : MeasurementAccuracyRequirement {
            subject alarmSensor = sensingSystem.sensor;
        }
        
        requirement responseReq : AlarmResponseTimeRequirement {
            subject evaluator = sensingSystem.evaluator;
        }
        
        requirement monitoringReq : ThresholdMonitoringRequirement {
            subject unit = sensingSystem;
        }
    }
    
    part alarmSensingUnitInstance : SensingUnit {
        attribute :>> unitIdentifier = "ASU_PRIMARY_001";
        attribute :>> operatingThreshold {
            attribute :>> num = 373.15;
            attribute :>> mRef = K;
        }
        
        part :>> sensor {
            attribute :>> calibrationFactor = 0.98;
        }
        
        part :>> evaluator {
            attribute :>> alarmHysteresis {
                attribute :>> num = 3.0;
            }
        }
        
        perform action sensingOperation : SensingCycleOperation {
            in thresholdSetting = alarmSensingUnitInstance.operatingThreshold;
            out alarmResult;
        }
        
        exhibit state sensorBehavior : SensorStateMachine;
        exhibit state alarmBehavior : AlarmStateMachine;
    }
    
    requirement systemRequirement : SystemFunctionalRequirement {
        subject sensingSystem = alarmSensingUnitInstance;
    }
}
