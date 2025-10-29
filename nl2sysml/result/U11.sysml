// Design a patient monitoring device that tracks vital signs and sends alerts.
package PatientMonitoringSystem {
    value def HeartRateValue : Integer;
    value def TemperatureValue : Real;

    part def HeartRateSensor {
        out port heartRateOutput : HeartRateValue;
    }

    part def TemperatureSensor {
        out port temperatureOutput : TemperatureValue;
    }

    part def VitalSignProcessor {
        in port heartRateInput : HeartRateValue;
        in port temperatureInput : TemperatureValue;
        out port alertTrigger : Boolean;

        constraint {
            heartRateInput > 120 or temperatureInput > 38.5
        } subsets alertTrigger;
    }

    part def AlertSystem {
        in port alertCondition : Boolean;
        action def SendNotification;
    }

    part def PatientMonitoringDevice {
        part hrSensor : HeartRateSensor;
        part tempSensor : TemperatureSensor;
        part processor : VitalSignProcessor;
        part alerter : AlertSystem;

        item flow hrDataFlow from hrSensor.heartRateOutput to processor.heartRateInput;
        item flow tempDataFlow from tempSensor.temperatureOutput to processor.temperatureInput;
        item flow alertFlow from processor.alertTrigger to alerter.alertCondition;
    }
}
