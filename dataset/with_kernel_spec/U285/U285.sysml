package ExtracorporealLiverSupportSystem {
    private import ScalarValues::*;

    value type FlowRateValue :> Real;
    value type PressureValue :> Real;
    value type TemperatureValue :> Real;
    value type ConcentrationValue :> Real;

    item def Blood;
    item def WasteFluid;

    attribute def PrimeCommand;
    attribute def TreatCommand;
    attribute def StopCommand;
    attribute def RinseComplete;
    attribute def AlarmResetCommand;
    attribute def AlarmSignal;

    action def primeCircuit;
    action def treatBlood;
    action def rinseCircuit;
    action def triggerAlarm;
    action def haltProcedure;

    part def Patient {
        out port bloodOut : Blood;
        in port bloodIn : Blood;
    }

    part def BloodPump {
        in port bloodIn : Blood;
        out port bloodOut : Blood;
        attribute enable : Boolean;
        attribute flowRate : FlowRateValue;
    }

    part def DialysisFilter {
        in port bloodIn : Blood;
        out port bloodOut : Blood;
        out port wasteOut : WasteFluid;
    }

    part def TemperatureRegulator {
        in port bloodIn : Blood;
        out port bloodOut : Blood;
        attribute currentTemp : TemperatureValue;
        attribute setPoint : TemperatureValue;
    }

    part def ToxinSensor {
        in port bloodIn : Blood;
        out port bloodOut : Blood;
        attribute reading : ConcentrationValue;
    }

    part def PressureMonitor {
        in port bloodIn : Blood;
        out port bloodOut : Blood;
        attribute pressure : PressureValue;
    }

    part def WasteContainer {
        in port wasteIn : WasteFluid;
    }

    part def ControlUnit {
        attribute toxinLevel : ConcentrationValue;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
        attribute pumpEnable : Boolean;
        attribute alarmOut : AlarmSignal;

        attribute maxToxin : ConcentrationValue = 100;
        attribute maxPressure : PressureValue = 150;
        attribute minFlow : FlowRateValue = 50;
        attribute maxFlow : FlowRateValue = 300;
        attribute targetTemp : TemperatureValue = 37;
        attribute tempTolerance : TemperatureValue = 1;

        action prime : primeCircuit;
        action treat : treatBlood;
        action rinse : rinseCircuit;
        action soundAlarm : triggerAlarm;
        action halt : haltProcedure;

        exhibit state controlStates {
            entry; then idle;

            state idle;
            accept PrimeCommand then priming;

            state priming {
                do prime;
            }
            accept TreatCommand then treating;
            accept when pressure > maxPressure then alarmState;

            state treating {
                do treat;
            }
            accept StopCommand then rinsing;
            accept when pressure > maxPressure or toxinLevel > maxToxin then alarmState;

            state rinsing {
                do rinse;
            }
            accept RinseComplete then idle;

            state alarmState {
                entry soundAlarm;
                do halt;
            }
            accept AlarmResetCommand then idle;
        }
    }

    part def LiverSupportSystem {
        out port patientConnectionOut : Blood;
        in port patientConnectionIn : Blood;

        part pump : BloodPump;
        part dialysisFilter : DialysisFilter;
        part toxinSensor : ToxinSensor;
        part pressureMonitor : PressureMonitor;
        part regulator : TemperatureRegulator;
        part controller : ControlUnit;
        part wasteContainer : WasteContainer;

        connect patientConnectionOut to pump.bloodIn;
        connect pump.bloodOut to dialysisFilter.bloodIn;
        connect dialysisFilter.bloodOut to toxinSensor.bloodIn;
        connect toxinSensor.bloodOut to pressureMonitor.bloodIn;
        connect pressureMonitor.bloodOut to regulator.bloodIn;
        connect regulator.bloodOut to patientConnectionIn;

        connect dialysisFilter.wasteOut to wasteContainer.wasteIn;

        bind toxinSensor.reading = controller.toxinLevel;
        bind pressureMonitor.pressure = controller.pressure;
        bind pump.flowRate = controller.flowRate;
        bind regulator.currentTemp = controller.temperature;
        bind controller.pumpEnable = pump.enable;
    }

    requirement def BloodFlowSafety {
        doc /* Blood flow rate shall be maintained between 50 and 300 mL/min during treatment. */;
        subject pump : BloodPump;
        constraint { pump.flowRate >= 50 and pump.flowRate <= 300 }
    }

    requirement def PressureSafety {
        doc /* Circuit pressure shall not exceed 150 mmHg to prevent hemolysis or vessel damage. */;
        subject monitor : PressureMonitor;
        constraint { monitor.pressure <= 150 }
    }

    requirement def TemperatureSafety {
        doc /* Blood temperature returned to patient shall be maintained at 37 plus or minus 1 degC. */;
        subject regulator : TemperatureRegulator;
        constraint { regulator.currentTemp >= 36 and regulator.currentTemp <= 38 }
    }
}
