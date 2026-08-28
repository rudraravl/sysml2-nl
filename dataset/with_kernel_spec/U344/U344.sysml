package ECMO_System {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        value type PressureValue :> ISQ::Pressure;
        value type TemperatureValue :> ISQ::Temperature;
        value type FlowRateValue :> ISQ::VolumeFlowRate;
        value type OxygenSaturationValue :> Real;
        
        item def Blood;
        item def Oxygen;
        item def Saline;
        item def WasteGas;
        
        port def BloodPort {
            in blood : Blood;
            out blood : Blood;
        }
        port def GasPort {
            in oxygen : Oxygen;
            out wasteGas : WasteGas;
        }
        port def SignalPort {
            out pressure : PressureValue;
            out temp : TemperatureValue;
            out flow : FlowRateValue;
            out o2sat : OxygenSaturationValue;
        }
        port def ControlPort {
            out speed : Real;
            out flow : FlowRateValue;
        }
        
        part def ECMOSystem {
            exhibit state ecmoStates : ECMOStates;
        }
        part def HollowFiberMembrane {
            port venousBlood : BloodPort;
            port oxygenatedBlood : BloodPort;
            port oxygenIn : GasPort;
            port wasteGasOut : GasPort;
            perform action exchangeGas : ExchangeGas;
        }
        part def BloodPump {
            port bloodIn : BloodPort;
            port bloodOut : BloodPort;
            port controlIn : ControlPort;
            attribute pumpSpeed : Real;
            perform action pumpBlood : PumpBlood;
        }
        part def HeatExchanger {
            port bloodIn : BloodPort;
            port bloodOut : BloodPort;
            perform action regulateTemp : RegulateTemperature;
        }
        part def GasFlowRegulator {
            port oxygenOut : GasPort;
            port controlIn : ControlPort;
            attribute flowRate : FlowRateValue;
            perform action regulateOxygenFlow : RegulateOxygenFlow;
        }
        part def SafetyValve {
            port bloodIn : BloodPort;
            port bloodOut : BloodPort;
            attribute thresholdPressure : PressureValue;
            perform action releasePressure : ReleasePressure;
        }
        part def ControlModule {
            port sensorData : SignalPort;
            port pumpControl : ControlPort;
            port gasControl : ControlPort;
            port alarmOut : SignalPort;
            exhibit state controllerStates : ControllerStates;
            perform action monitorSensors : MonitorSensors;
            perform action triggerAlarm : TriggerAlarm;
        }
        part def Sensor {
            attribute value : Real;
            port dataOut : SignalPort;
            perform action sense : Sense;
        }
        
        action def PumpBlood { in blood : Blood; out pumpedBlood : Blood; }
        action def ExchangeGas { in blood : Blood; in oxygen : Oxygen; out oxygenatedBlood : Blood; out wasteGas : WasteGas; }
        action def RegulateTemperature { in blood : Blood; out warmedBlood : Blood; }
        action def ReleasePressure { in blood : Blood; out releasedBlood : Blood; }
        action def RegulateOxygenFlow { in oxygen : Oxygen; out regulatedOxygen : Oxygen; }
        action def MonitorSensors { out pressure : PressureValue; out temp : TemperatureValue; out flow : FlowRateValue; out o2sat : OxygenSaturationValue; }
        action def TriggerAlarm { in condition : String; }
        action def Sense { out value : Real; }
        action def PrimeCircuit { in saline : Saline; out primedCircuit : Saline; }
        
        attribute def StartSignal;
        attribute def StopSignal;
        attribute def EmergencyStopSignal;
        attribute def PrimeCompleteSignal;
        attribute def AlarmSignal;
        
        state def ECMOStates;
        state def ControllerStates;
    }
    
    package Usages {
        private import Definitions::*;
        
        part ecmoSystem : ECMOSystem {
            part controlModule : ControlModule;
            part bloodPump : BloodPump;
            part heatExchanger : HeatExchanger;
            part membrane : HollowFiberMembrane;
            part gasFlowRegulator : GasFlowRegulator;
            part safetyValve : SafetyValve;
            part pressureSensor : Sensor;
            part tempSensor : Sensor;
            part flowSensor : Sensor;
            part o2Sensor : Sensor;
            
            port patientVenousLine : BloodPort;
            port patientArterialLine : BloodPort;
            
            connect patientVenousLine to bloodPump.bloodIn;
            connect bloodPump.bloodOut to heatExchanger.bloodIn;
            connect heatExchanger.bloodOut to safetyValve.bloodIn;
            connect safetyValve.bloodOut to membrane.venousBlood;
            connect membrane.oxygenatedBlood to patientArterialLine;
            
            connect gasFlowRegulator.oxygenOut to membrane.oxygenIn;
            
            connect pressureSensor.dataOut to controlModule.sensorData;
            connect tempSensor.dataOut to controlModule.sensorData;
            connect flowSensor.dataOut to controlModule.sensorData;
            connect o2Sensor.dataOut to controlModule.sensorData;
            
            connect controlModule.pumpControl to bloodPump.controlIn;
            connect controlModule.gasControl to gasFlowRegulator.controlIn;
            
            exhibit state ecmoStates : ECMOStates {
                entry; then Standby;
                state Standby;
                accept StartSignal then Priming;
                state Priming {
                    do action primeCircuit : PrimeCircuit;
                }
                accept PrimeCompleteSignal then Operating;
                state Operating {
                    do action monitorSensors : MonitorSensors;
                    do action pumpBlood : PumpBlood;
                    do action exchangeGas : ExchangeGas;
                    do action regulateTemp : RegulateTemperature;
                }
                accept StopSignal then Stopped;
                accept EmergencyStopSignal then EmergencyShutdown;
                state Stopped;
                state EmergencyShutdown {
                    do action triggerAlarm : TriggerAlarm;
                }
            }
            
            exhibit state controllerStates : ControllerStates {
                entry; then Monitoring;
                state Monitoring {
                    do action monitorSensors : MonitorSensors;
                }
                accept when controlModule.sensorData.pressure > 300.0 
                    do send new AlarmSignal() to controlModule.alarmOut
                    then Alarming;
                accept when controlModule.sensorData.o2sat < 90.0 
                    do send new AlarmSignal() to controlModule.alarmOut
                    then Alarming;
                state Alarming {
                    do action triggerAlarm : TriggerAlarm;
                }
                accept StopSignal then Monitoring;
            }
        }
    }
    
    package Requirements {
        private import Definitions::*;
        requirement def SafeOperation {
            subject ecmo : ECMOSystem;
            requirement pressureRelief {
                subject ecmo;
                doc /* The system must release pressure if it exceeds a critical threshold. */
            }
            requirement alarmTrigger {
                subject ecmo;
                doc /* The system must trigger alarms for low oxygen saturation, high pressure, or temperature anomalies. */
            }
            requirement temperatureRegulation {
                subject ecmo;
                doc /* The Heat Exchanger shall regulate blood temperature to normal body temperature before returning to patient. */
            }
        }
    }
}
