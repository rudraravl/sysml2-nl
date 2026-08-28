package ECMOSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    import Definitions::*;
    import StateDefinitions::*;

    package Definitions {
        item def Blood;
        item def Oxygen;
        item def CarbonDioxide;

        attribute def FlowRateValue :> Real;
        attribute def PressureValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def OxygenSaturationValue :> Real;
        attribute def PumpSpeedValue :> Real;

        attribute def StartPrime;
        attribute def PrimeComplete;
        attribute def StartTherapy;
        attribute def StopTherapy;
        attribute def Shutdown;
        attribute def AlarmTrigger;
        attribute def AlarmClear;
        attribute def TargetSettings {
            targetFlow : FlowRateValue;
            targetOxygen : OxygenSaturationValue;
            targetTemp : TemperatureValue;
        }

        port def BloodPort {
            out blood : Blood;
        }
        port def GasPort {
            in oxygen : Oxygen;
            out carbonDioxide : CarbonDioxide;
        }
        port def FlowDataPort {
            out flowRate : FlowRateValue;
        }
        port def OxygenDataPort {
            out oxygenSaturation : OxygenSaturationValue;
        }
        port def PressureDataPort {
            out pressure : PressureValue;
        }
        port def TemperatureDataPort {
            out temperature : TemperatureValue;
        }
        port def PumpControlPort {
            in pumpSpeed : PumpSpeedValue;
        }
        port def AlarmPort {
            in alarm : AlarmTrigger;
        }

        part def Patient {
            port venousOutlet : ~BloodPort;
            port arterialInlet : BloodPort;
        }

        part def VenousCannula {
            port inBlood : ~BloodPort;
            port outBlood : BloodPort;
        }

        part def CentrifugalPump {
            port inBlood : ~BloodPort;
            port outBlood : BloodPort;
            port controlPort : ~PumpControlPort;
            attribute pumpSpeed : PumpSpeedValue;
            perform action 'drive blood' {
                in speed : PumpSpeedValue;
                out bloodFlow : FlowRateValue;
            }
        }

        part def MembraneOxygenator {
            port inBlood : ~BloodPort;
            port outBlood : BloodPort;
            port gasPort : GasPort;
            perform action 'oxygenate blood' {
                in deoxygenatedBlood : Blood;
                in oxygen : Oxygen;
                out oxygenatedBlood : Blood;
                out carbonDioxide : CarbonDioxide;
            }
        }

        part def HeatExchanger {
            port inBlood : ~BloodPort;
            port outBlood : BloodPort;
            port waterInlet {
                in warmWater : TemperatureValue;
            }
            port waterOutlet {
                out coolWater : TemperatureValue;
            }
            perform action 'regulate temperature' {
                in bloodTemp : TemperatureValue;
                in waterTemp : TemperatureValue;
                out regulatedTemp : TemperatureValue;
            }
        }

        part def ArterialCannula {
            port inBlood : ~BloodPort;
            port outBlood : BloodPort;
        }

        part def Sensor {
            attribute enabled : Boolean;
        }

        part def FlowSensor :> Sensor {
            port dataPort : FlowDataPort;
            attribute flowRate : FlowRateValue;
            perform action 'sense flow' {
                out rate : FlowRateValue;
            }
        }

        part def OxygenSensor :> Sensor {
            port dataPort : OxygenDataPort;
            attribute oxygenSaturation : OxygenSaturationValue;
            perform action 'sense oxygen' {
                out saturation : OxygenSaturationValue;
            }
        }

        part def PressureSensor :> Sensor {
            port dataPort : PressureDataPort;
            attribute pressure : PressureValue;
            perform action 'sense pressure' {
                out pressure : PressureValue;
            }
        }

        part def TemperatureSensor :> Sensor {
            port dataPort : TemperatureDataPort;
            attribute temperature : TemperatureValue;
            perform action 'sense temperature' {
                out temp : TemperatureValue;
            }
        }

        part def AlarmSystem {
            port alarmPort : ~AlarmPort;
            perform action 'sound alarm' {
                in signal : AlarmTrigger;
            }
        }

        state def ECMOStates;

        part def ControlUnit {
            port flowSensorPort : ~FlowDataPort;
            port oxygenSensorPort : ~OxygenDataPort;
            port pressureSensorPort : ~PressureDataPort;
            port tempSensorPort : ~TemperatureDataPort;
            port pumpControlPort : PumpControlPort;
            port alarmControlPort : AlarmPort;
            port settingsPort {
                in settings : TargetSettings;
            }
            attribute maxPressure : PressureValue = 300.0;
            attribute minFlowRate : FlowRateValue = 0.5;
            attribute maxFlowRate : FlowRateValue = 7.0;
            attribute targetTemp : TemperatureValue = 37.0;
            exhibit state ecmoStates : ECMOStates;
            perform action 'monitor and control' {
                in currentFlow : FlowRateValue;
                in currentO2 : OxygenSaturationValue;
                in currentPressure : PressureValue;
                in currentTemp : TemperatureValue;
                in target : TargetSettings;
                out command : PumpSpeedValue;
            }
            perform action 'evaluate safety' {
                in pressure : PressureValue;
                in flowRate : FlowRateValue;
                in bloodTemp : TemperatureValue;
                out alarm : AlarmTrigger;
            }
        }

        action def PrimeCircuit;
        action def FlushCircuit;
        action def MaintainReadiness;
        action def ProvideTherapy;
        action def TerminateTherapy;
    }

    package StateDefinitions {
        private import Definitions::*;

        state def ECMOStates {
            entry; then off;
            state off;
            accept StartPrime then priming;
            state priming {
                entry action primeCircuit : PrimeCircuit;
                do action flushCircuit : FlushCircuit;
            }
            accept PrimeComplete then standby;
            state standby {
                do action maintainReadiness : MaintainReadiness;
            }
            accept StartTherapy then active;
            state active {
                entry action provideTherapy : ProvideTherapy;
                exit action terminateTherapy : TerminateTherapy;
            }
            accept StopTherapy then standby;
            accept Shutdown then off;
        }
    }

    package Usages {
        private import Definitions::*;
        private import StateDefinitions::*;

        part ecmoSystem {
            part patient : Patient;
            part venousCannula : VenousCannula;
            part centrifugalPump : CentrifugalPump;
            part membraneOxygenator : MembraneOxygenator;
            part heatExchanger : HeatExchanger;
            part arterialCannula : ArterialCannula;

            part controlUnit : ControlUnit {
                exhibit state operationalStates : ECMOStates;
            }
            part alarmSystem : AlarmSystem;

            part flowSensor : FlowSensor;
            part oxygenSensor : OxygenSensor;
            part pressureSensor : PressureSensor;
            part temperatureSensor : TemperatureSensor;

            flow venousFlow of Blood
                from patient.venousOutlet.blood to venousCannula.inBlood.blood;
            flow cannulaToPumpFlow of Blood
                from venousCannula.outBlood.blood to centrifugalPump.inBlood.blood;
            flow pumpToOxygenatorFlow of Blood
                from centrifugalPump.outBlood.blood to membraneOxygenator.inBlood.blood;
            flow oxygenatorToHeatExchangerFlow of Blood
                from membraneOxygenator.outBlood.blood to heatExchanger.inBlood.blood;
            flow heatExchangerToArterialFlow of Blood
                from heatExchanger.outBlood.blood to arterialCannula.inBlood.blood;
            flow arterialFlow of Blood
                from arterialCannula.outBlood.blood to patient.arterialInlet.blood;

            interface flowSensorToControl
                connect flowSensor.dataPort to controlUnit.flowSensorPort;
            interface oxygenSensorToControl
                connect oxygenSensor.dataPort to controlUnit.oxygenSensorPort;
            interface pressureSensorToControl
                connect pressureSensor.dataPort to controlUnit.pressureSensorPort;
            interface tempSensorToControl
                connect temperatureSensor.dataPort to controlUnit.tempSensorPort;

            interface controlToPump
                connect controlUnit.pumpControlPort to centrifugalPump.controlPort;
            interface controlToAlarm
                connect controlUnit.alarmControlPort to alarmSystem.alarmPort;

            state monitoringStates {
                entry; then normal;
                state normal;
                accept when pressureSensor.pressure > controlUnit.maxPressure
                    do send new AlarmTrigger() to alarmSystem
                    then alarm;
                accept when flowSensor.flowRate < controlUnit.minFlowRate
                    do send new AlarmTrigger() to alarmSystem
                    then alarm;
                state alarm;
                accept AlarmClear then normal;
            }
        }
    }

    package Requirements {
        private import Definitions::*;
        private import Usages::*;

        requirement def CirculationRequirement {
            doc /* The ECMO system shall circulate blood through a closed-loop circuit comprising a venous cannula, centrifugal pump, membrane oxygenator, heat exchanger, and arterial cannula. */
        }

        requirement def OxygenationRequirement {
            doc /* The membrane oxygenator shall oxygenate deoxygenated blood and remove carbon dioxide by diffusion across a semipermeable membrane. */
        }

        requirement def TemperatureRegulationRequirement {
            doc /* The heat exchanger shall regulate blood temperature to a target of 37 degrees Celsius before returning blood to the patient. */
        }

        requirement def FlowControlRequirement {
            doc /* The control unit shall continuously adjust centrifugal pump speed based on sensor data to maintain target blood flow between 0.5 and 7.0 L/min. */
        }

        requirement def SafetyAlarmRequirement {
            doc /* The system shall trigger an immediate alarm if blood pressure exceeds 300 mmHg or flow rate drops below 0.5 L/min. */
        }

        requirement def StateOperationRequirement {
            doc /* The ECMO system shall operate through off, priming, standby, and active states, with transitions controlled by clinical staff commands. */
        }
    }
}
