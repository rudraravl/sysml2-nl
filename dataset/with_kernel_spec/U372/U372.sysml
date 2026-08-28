package SAHRA_Respirator_System {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def PressureValue :> Real;
        attribute def VolumeValue :> Real;
        attribute def FlowRateValue :> Real;
        attribute def OxygenConcentrationValue :> Real;
        attribute def RespiratoryRateValue :> Integer;

        item def AmbientAir;
        item def PureOxygen;
        item def GasMixture {
            attribute oxygenConcentration : OxygenConcentrationValue;
        }

        attribute def StartVentilation;
        attribute def StopVentilation;
        attribute def HighPressureAlarm;
        attribute def DisconnectionAlarm;
        attribute def AlarmReset;
        attribute def InspirationComplete;
        attribute def ExpirationComplete;

        port def GasInPort {
            in item gas;
        }
        port def GasOutPort {
            out item gas;
        }
        port def PressureReadingPort {
            out pressure : PressureValue;
        }
        port def FlowReadingPort {
            out flow : FlowRateValue;
        }
        port def ValveControlPort {
            in command : Boolean;
        }
        port def AlarmOutputPort {
            out audible : Boolean;
            out visual : Boolean;
        }
        port def SettingsInputPort {
            in tidalVolume : VolumeValue;
            in respiratoryRate : RespiratoryRateValue;
            in oxygenConcentration : OxygenConcentrationValue;
        }

        action def CompressAir;
        action def BlendGas;
        action def DeliverBreath;
        action def AllowExpiration;
        action def OpenInspiratoryValve;
        action def CloseInspiratoryValve;
        action def OpenExpiratoryValve;
        action def CloseExpiratoryValve;
        action def SensePressure {
            out pressure : PressureValue;
        }
        action def SenseFlow {
            out flow : FlowRateValue;
        }
        action def TriggerAlarm;
        action def HaltVentilation;
        action def MonitorSettings;

        part def Compressor {
            port gasIn : GasInPort;
            port gasOut : GasOutPort;
            perform action compress : CompressAir;
        }

        part def OxygenSupply {
            port oxygenOut : GasOutPort;
            attribute supplyLevel : VolumeValue;
        }

        part def GasBlender {
            port airIn : GasInPort;
            port oxygenIn : GasInPort;
            port mixtureOut : GasOutPort;
            perform action blend : BlendGas;
        }

        part def InspiratoryValve {
            port gasIn : GasInPort;
            port gasOut : GasOutPort;
            port control : ValveControlPort;
            attribute isOpen : Boolean;
        }

        part def ExpiratoryValve {
            port gasIn : GasInPort;
            port gasOut : GasOutPort;
            port control : ValveControlPort;
            attribute isOpen : Boolean;
        }

        part def BreathingCircuit {
            port machineIn : GasInPort;
            port patientOut : GasOutPort;
            port expiratoryReturn : GasInPort;
            part inspiratoryValve : InspiratoryValve;
            part expiratoryValve : ExpiratoryValve;
        }

        part def PressureSensor {
            port reading : PressureReadingPort;
            perform action sense : SensePressure;
        }

        part def FlowSensor {
            port reading : FlowReadingPort;
            perform action sense : SenseFlow;
        }

        part def AlarmModule {
            port alarmOutput : AlarmOutputPort;
            perform action trigger : TriggerAlarm;
        }

        part def Controller {
            port settings : SettingsInputPort;
            port pressureIn : PressureReadingPort;
            port flowIn : FlowReadingPort;
            port inspValveCtrl : ValveControlPort;
            port expValveCtrl : ValveControlPort;
            port alarmCmd : AlarmOutputPort;
            attribute tidalVolumeSetting : VolumeValue;
            attribute respiratoryRateSetting : RespiratoryRateValue;
            attribute oxygenConcentrationSetting : OxygenConcentrationValue;
            attribute maxPressureLimit : PressureValue;
            attribute minFlowLimit : FlowRateValue;
        }

        part def Patient {
            port airway : GasInPort;
        }

        state def VentilationStates;

        requirement def AdjustableOxygenRequirement {
            doc /* The SAHRA system shall deliver oxygen-enriched air with adjustable concentration from 21% to 100%. */
        }
        requirement def BreathingCycleRequirement {
            doc /* The controller shall orchestrate breathing cycles based on tidal volume and respiratory rate settings. */
        }
        requirement def HighPressureSafetyRequirement {
            doc /* If airway pressure exceeds the configured high-pressure limit, the system shall enter the alarm state and trigger audible and visual alerts. */
        }
        requirement def DisconnectionSafetyRequirement {
            doc /* If airway flow falls below the disconnection threshold, the system shall enter the alarm state and trigger audible and visual alerts. */
        }
        requirement def LifeSupportRequirement {
            doc /* The SAHRA system shall provide life-sustaining breathing support for patients with respiratory insufficiency. */
        }
    }

    package Usages {
        private import Definitions::*;

        action monitorSettings : MonitorSettings;
        action openInspValve : OpenInspiratoryValve;
        action closeInspValve : CloseInspiratoryValve;
        action openExpValve : OpenExpiratoryValve;
        action closeExpValve : CloseExpiratoryValve;
        action deliverBreath : DeliverBreath;
        action allowExpiration : AllowExpiration;
        action sensePressure : SensePressure;
        action senseFlow : SenseFlow;
        action triggerAlarm : TriggerAlarm;
        action haltVentilation : HaltVentilation;

        state ventilationStates : VentilationStates {
            in pressureSensor : PressureSensor;
            in flowSensor : FlowSensor;
            in alarmModule : AlarmModule;
            in inspiratoryValve : InspiratoryValve;
            in expiratoryValve : ExpiratoryValve;
            in maxPressureLimit : PressureValue;
            in minFlowLimit : FlowRateValue;

            entry; then standby;

            state standby {
                do monitorSettings;
            }
            accept StartVentilation
                then activeVentilation;

            state activeVentilation {
                entry; then inspiration;
                do sensePressure { out pressure; }
                do senseFlow { out flow; }

                state inspiration {
                    entry openInspValve;
                    do deliverBreath;
                    exit closeInspValve;
                }
                accept InspirationComplete
                    then expiration;
                accept when sensePressure.pressure > maxPressureLimit
                    do send new HighPressureAlarm() to alarmModule
                    then criticalAlarm;
                accept when senseFlow.flow < minFlowLimit
                    do send new DisconnectionAlarm() to alarmModule
                    then criticalAlarm;

                state expiration {
                    entry closeInspValve;
                    entry openExpValve;
                    do allowExpiration;
                    exit closeExpValve;
                }
                accept ExpirationComplete
                    then inspiration;
                accept when sensePressure.pressure > maxPressureLimit
                    do send new HighPressureAlarm() to alarmModule
                    then criticalAlarm;
                accept when senseFlow.flow < minFlowLimit
                    do send new DisconnectionAlarm() to alarmModule
                    then criticalAlarm;
            }
            accept StopVentilation
                then standby;

            state criticalAlarm {
                entry closeInspValve;
                entry openExpValve;
                entry triggerAlarm;
                do haltVentilation;
            }
            accept AlarmReset
                then standby;
        }

        part sahraSystem {
            part compressor : Compressor;
            part oxygenSupply : OxygenSupply;
            part gasBlender : GasBlender;
            part breathingCircuit : BreathingCircuit;
            part pressureSensor : PressureSensor;
            part flowSensor : FlowSensor;
            part alarmModule : AlarmModule;
            part controller : Controller;
            ref patient : Patient;

            connect compressor.gasOut to gasBlender.airIn;
            connect oxygenSupply.oxygenOut to gasBlender.oxygenIn;
            connect gasBlender.mixtureOut to breathingCircuit.machineIn;
            connect breathingCircuit.patientOut to patient.airway;
            connect pressureSensor.reading to controller.pressureIn;
            connect flowSensor.reading to controller.flowIn;
            connect controller.inspValveCtrl to breathingCircuit.inspiratoryValve.control;
            connect controller.expValveCtrl to breathingCircuit.expiratoryValve.control;
            connect controller.alarmCmd to alarmModule.alarmOutput;

            exhibit ventilationStates {
                in pressureSensor = pressureSensor;
                in flowSensor = flowSensor;
                in alarmModule = alarmModule;
                in inspiratoryValve = breathingCircuit.inspiratoryValve;
                in expiratoryValve = breathingCircuit.expiratoryValve;
                in maxPressureLimit = controller.maxPressureLimit;
                in minFlowLimit = controller.minFlowLimit;
            }
        }

        requirement adjustableOxygen : AdjustableOxygenRequirement;
        requirement breathingCycle : BreathingCycleRequirement;
        requirement highPressureSafety : HighPressureSafetyRequirement;
        requirement disconnectionSafety : DisconnectionSafetyRequirement;
        requirement lifeSupport : LifeSupportRequirement;
    }
}
