package MedicalInfusionPumpSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def FlowRateValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def HeartRateValue :> Real;
    attribute def BloodPressureValue :> Real;
    attribute def BatteryLevelValue :> Real;

    attribute def StartTherapySignal;
    attribute def StopTherapySignal;
    attribute def PauseSignal;
    attribute def ResumeSignal;
    attribute def TherapyCompleteSignal;
    attribute def PrimingCompleteSignal;
    attribute def DismissAlarmSignal;
    attribute def StartPumpSignal;
    attribute def AlarmSignal {
        kind : ScalarValues::String;
        message : ScalarValues::String;
    }

    attribute def VitalSigns {
        heartRate : HeartRateValue;
        bloodPressure : BloodPressureValue;
        temperature : TemperatureValue;
    }
    attribute def PumpCommand {
        targetFlowRate : FlowRateValue;
        totalVolume : VolumeValue;
    }
    attribute def PumpStatus {
        deliveredVolume : VolumeValue;
        currentFlowRate : FlowRateValue;
        pumpState : ScalarValues::String;
    }
    attribute def BatteryStatus {
        chargeLevel : BatteryLevelValue;
        charging : ScalarValues::Boolean;
    }
    attribute def UIUpdate {
        message : ScalarValues::String;
        alarm : ScalarValues::Boolean;
    }

    port def PumpCommandPort {
        out pumpCommand : PumpCommand;
        in pumpStatus : PumpStatus;
    }
    port def VitalSignsPort {
        out vitals : VitalSigns;
    }
    port def BatteryStatusPort {
        out batteryStatus : BatteryStatus;
    }
    port def UIPort {
        in uiUpdate : UIUpdate;
    }
    port def AlarmPort {
        out alarm : AlarmSignal;
    }

    action def PrimePump;
    action def InfuseMedication {
        in command : PumpCommand;
        out status : PumpStatus;
    }
    action def MeasureVitals {
        out vitals : VitalSigns;
    }
    action def AnalyzeVitals {
        in vitals : VitalSigns;
        in maxHeartRate : HeartRateValue;
        in maxBloodPressure : BloodPressureValue;
        in maxTemperature : TemperatureValue;
        out abnormal : ScalarValues::Boolean;
    }
    action def DisplayAlarm {
        in alarm : AlarmSignal;
    }
    action def DisplayStatus {
        in update : UIUpdate;
    }
    action def DischargeBattery {
        out level : BatteryLevelValue;
    }
    action def ChargeBattery;

    state def BatteryStates;
    state def PumpStates;
    state def SensorStates;
    state def UIStates;
    state def DeviceStates;

    part def Battery {
        attribute maxCharge : BatteryLevelValue = 100;
        attribute lowThreshold : BatteryLevelValue = 20;
        attribute criticalThreshold : BatteryLevelValue = 5;
        port batteryStatusPort : BatteryStatusPort;
        action discharge : DischargeBattery;
        exhibit state batteryStates : BatteryStates {
            in battery : Battery;
            entry; then full;
            do battery.discharge;
            state full;
            accept when battery.discharge.level < battery.lowThreshold
                then low;
            state low;
            accept when battery.discharge.level < battery.criticalThreshold
                then critical;
            state critical;
            accept when battery.discharge.level >= battery.maxCharge
                then full;
        }
    }

    part def PumpMechanism {
        port pumpCommandPort : PumpCommandPort;
        attribute deliveredVolume : VolumeValue = 0;
        exhibit state pumpStates : PumpStates {
            in pump : PumpMechanism;
            entry; then idle;
            state idle;
            accept StartPumpSignal
                then priming;
            state priming {
                do action primePump : PrimePump;
            }
            accept PrimingCompleteSignal
                then infusing;
            state infusing {
                do action infuseMedication : InfuseMedication {
                    in command = pump.pumpCommandPort.pumpCommand;
                    out status = pump.pumpCommandPort.pumpStatus;
                }
            }
            accept PauseSignal
                then paused;
            state paused;
            accept ResumeSignal
                then infusing;
            accept StopTherapySignal
                then idle;
        }
    }

    part def Sensor {
        port vitalsPort : VitalSignsPort;
        exhibit state sensorStates : SensorStates {
            in sensor : Sensor;
            entry; then sensing;
            state sensing {
                do action measureVitals : MeasureVitals {
                    out vitals = sensor.vitalsPort.vitals;
                }
            }
        }
    }

    part def UserInterface {
        port uiPort : UIPort;
        port alarmPort : AlarmPort;
        exhibit state uiStates : UIStates {
            in ui : UserInterface;
            entry; then normal;
            state normal {
                do action displayStatus : DisplayStatus {
                    in update = ui.uiPort.uiUpdate;
                }
            }
            accept a : AlarmSignal via ui.alarmPort
                then alerting;
            state alerting {
                do action displayAlarm : DisplayAlarm {
                    in alarm = ui.alarmPort.alarm;
                }
            }
            accept DismissAlarmSignal
                then normal;
        }
    }

    part def ControlUnit {
        port pumpPort : PumpCommandPort;
        port vitalsPort : VitalSignsPort;
        port batteryPort : BatteryStatusPort;
        port uiPort : UIPort;
        port alarmPort : AlarmPort;
        attribute prescribedVolume : VolumeValue;
        attribute prescribedFlowRate : FlowRateValue;
        attribute maxHeartRate : HeartRateValue = 120;
        attribute maxBloodPressure : BloodPressureValue = 180;
        attribute maxTemperature : TemperatureValue = 38.5;
        attribute lowBatteryThreshold : BatteryLevelValue = 20;
    }

    part def MedicalInfusionPump {
        part controlUnit : ControlUnit;
        part battery : Battery;
        part pumpMechanism : PumpMechanism;
        part sensor : Sensor;
        part userInterface : UserInterface;
        connect controlUnit.pumpPort to pumpMechanism.pumpCommandPort;
        connect sensor.vitalsPort to controlUnit.vitalsPort;
        connect battery.batteryStatusPort to controlUnit.batteryPort;
        connect controlUnit.uiPort to userInterface.uiPort;
        connect controlUnit.alarmPort to userInterface.alarmPort;
        action analyzeVitals : AnalyzeVitals {
            in vitals = sensor.vitalsPort.vitals;
            in maxHeartRate = controlUnit.maxHeartRate;
            in maxBloodPressure = controlUnit.maxBloodPressure;
            in maxTemperature = controlUnit.maxTemperature;
        }
        exhibit state deviceStates : DeviceStates {
            entry; then standby;
            state standby;
            accept StartTherapySignal
                do send new StartPumpSignal() to pumpMechanism
                then activeTherapy;
            state activeTherapy {
                do analyzeVitals;
            }
            accept when analyzeVitals.abnormal == true
                do send new AlarmSignal() to userInterface
                then alarm;
            accept when battery.batteryStatusPort.batteryStatus.chargeLevel < controlUnit.lowBatteryThreshold
                do send new AlarmSignal() to userInterface
                then alarm;
            accept when pumpMechanism.deliveredVolume >= controlUnit.prescribedVolume
                then completed;
            accept PauseSignal
                do send new PauseSignal() to pumpMechanism
                then paused;
            state paused;
            accept ResumeSignal
                do send new ResumeSignal() to pumpMechanism
                then activeTherapy;
            state alarm;
            accept DismissAlarmSignal
                then activeTherapy;
            state completed;
            accept StopTherapySignal
                do send new StopTherapySignal() to pumpMechanism
                then standby;
        }
    }

    requirement def HighPrecisionDeliveryRequirement {
        doc /* The pump shall deliver medication at a flow rate accurate to within +/- 5% of the prescribed rate. */
        subject pump : PumpMechanism;
        attribute accuracy : Real = 5.0;
    }

    requirement def LongBatteryLifeRequirement {
        doc /* The battery shall support continuous infusion operation for at least 24 hours on a full charge. */
        subject battery : Battery;
        attribute minOperationalDuration : DurationValue = 24 [h];
    }

    requirement def RapidAlarmResponseRequirement {
        doc /* The system shall detect an unsafe condition and raise an alarm within 2 seconds. */
        subject device : MedicalInfusionPump;
        attribute maxResponseTime : DurationValue = 2 [s];
    }

    requirement def PatientSafetyRequirement {
        doc /* The system shall continuously monitor patient vitals and halt infusion if abnormal conditions are detected. */
        subject device : MedicalInfusionPump;
    }

    requirement hpdReq : HighPrecisionDeliveryRequirement;
    requirement lblReq : LongBatteryLifeRequirement;
    requirement rarReq : RapidAlarmResponseRequirement;
    requirement psReq : PatientSafetyRequirement;

    part infusionPumpSystem : MedicalInfusionPump {
        satisfy hpdReq by pumpMechanism;
        satisfy lblReq by battery;
        satisfy rarReq by infusionPumpSystem;
        satisfy psReq by infusionPumpSystem;
    }
}
